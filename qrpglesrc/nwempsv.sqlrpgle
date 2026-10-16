**free
//==============================================================================
// NWEMPSV - Data access service program for EMPLOYEES
//
// All SQL for EMPLOYEES lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWEMPPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWEMPSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWEMPSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWEMPPR

// Host variables for the list cursor
dcl-s  gPos like(Employee_t.LastName);
dcl-ds gRow likeds(Employee_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare EMPLIST cursor for
  select EMPLOYEEID,
         LASTNAME,
         FIRSTNAME,
         COALESCE(TITLE, ''),
         COALESCE(TITLEOFCOURTESY, ''),
         COALESCE(BIRTHDATE, DATE('0001-01-01')),
         COALESCE(HIREDATE, DATE('0001-01-01')),
         COALESCE(ADDRESS, ''),
         COALESCE(CITY, ''),
         COALESCE(REGION, ''),
         COALESCE(POSTALCODE, ''),
         COALESCE(COUNTRY, ''),
         COALESCE(HOMEPHONE, ''),
         COALESCE(EXTENSION, ''),
         COALESCE(REPORTSTO, 0),
         CAST(COALESCE(NOTES, '') AS VARCHAR(1024))
    from EMPLOYEES
   where UPPER(LASTNAME) >= UPPER(:gPos)
   order by UPPER(LASTNAME), EMPLOYEEID
   for read only;

//------------------------------------------------------------------------------
// Emp_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Emp_get export;
  dcl-pi *n ind;
    pEmployeeId like(Employee_t.EmployeeId) const;
    rec likeds(Employee_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Employee_t) inz;

  NwU_clearError(err);

  exec sql
    select EMPLOYEEID,
           LASTNAME,
           FIRSTNAME,
           COALESCE(TITLE, ''),
           COALESCE(TITLEOFCOURTESY, ''),
           COALESCE(BIRTHDATE, DATE('0001-01-01')),
           COALESCE(HIREDATE, DATE('0001-01-01')),
           COALESCE(ADDRESS, ''),
           COALESCE(CITY, ''),
           COALESCE(REGION, ''),
           COALESCE(POSTALCODE, ''),
           COALESCE(COUNTRY, ''),
           COALESCE(HOMEPHONE, ''),
           COALESCE(EXTENSION, ''),
           COALESCE(REPORTSTO, 0),
           CAST(COALESCE(NOTES, '') AS VARCHAR(1024))
      into :r
      from EMPLOYEES
     where EMPLOYEEID = :pEmployeeId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'EmployeeId': 'Employee not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve employee');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Emp_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Emp_exists export;
  dcl-pi *n ind;
    pEmployeeId like(Employee_t.EmployeeId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from EMPLOYEES
            where EMPLOYEEID = :pEmployeeId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Emp_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Emp_validate export;
  dcl-pi *n ind;
    rec    likeds(Employee_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(Employee_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    if v.EmployeeId <= 0;
      return NwU_setError(err: NWE_REQUIRED: 'EmployeeId':
                          'Employee ID must be greater than zero.');
    endif;
    if Emp_exists(v.EmployeeId);
      return NwU_setError(err: NWE_DUPLICATE: 'EmployeeId':
                          'Employee already exists.');
    endif;
  else;
    if not Emp_exists(v.EmployeeId);
      return NwU_setError(err: NWE_NOTFOUND: 'EmployeeId':
                          'Employee not found.');
    endif;
  endif;

  // Table-specific rules
  if v.HireDate <> NW_NULL_DATE and v.BirthDate <> NW_NULL_DATE
     and v.HireDate < v.BirthDate;
    return NwU_setError(err: NWE_RANGE: 'HireDate':
                        'Hire date cannot be before birth date.');
  endif;
  if v.ReportsTo <> 0 and v.ReportsTo = v.EmployeeId;
    return NwU_setError(err: NWE_INVALID: 'ReportsTo':
                        'An employee cannot report to himself or herself.');
  endif;

  // Field checks
  if %len(%trim(v.LastName)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'LastName': 'Last name is required.');
  endif;
  if %len(%trim(v.FirstName)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'FirstName': 'First name is required.');
  endif;
  if v.ReportsTo <> 0;
    found = 0;
    exec sql select 1 into :found from EMPLOYEES
              where EMPLOYEEID = :v.ReportsTo fetch first 1 row only;
    if found <> 1;
      return NwU_setError(err: NWE_REFERENCE: 'ReportsTo':
                          'Manager not found.');
    endif;
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Emp_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Emp_create export;
  dcl-pi *n ind;
    rec likeds(Employee_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Employee_t) inz;

  if not Emp_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql insert into EMPLOYEES
                  (EMPLOYEEID, LASTNAME, FIRSTNAME, TITLE, TITLEOFCOURTESY, BIRTHDATE,
                   HIREDATE, ADDRESS, CITY, REGION, POSTALCODE, COUNTRY, HOMEPHONE, EXTENSION,
                   REPORTSTO, NOTES)
                  values(:r.EmployeeId, :r.LastName, :r.FirstName, NULLIF(:r.Title, ''),
                         NULLIF(:r.TitleOfCourtesy, ''),
                         NULLIF(:r.BirthDate, DATE('0001-01-01')),
                         NULLIF(:r.HireDate, DATE('0001-01-01')), NULLIF(:r.Address, ''),
                         NULLIF(:r.City, ''), NULLIF(:r.Region, ''), NULLIF(:r.PostalCode, ''),
                         NULLIF(:r.Country, ''), NULLIF(:r.HomePhone, ''),
                         NULLIF(:r.Extension, ''), NULLIF(:r.ReportsTo, 0), NULLIF(:r.Notes, ''));

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create employee');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Emp_update - validate and update all non-key columns
//------------------------------------------------------------------------------
dcl-proc Emp_update export;
  dcl-pi *n ind;
    rec likeds(Employee_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Employee_t) inz;

  if not Emp_validate(rec: ACTION_UPDATE: err);
    return *off;
  endif;
  r = rec;

  exec sql update EMPLOYEES
              set LASTNAME = :r.LastName,
                  FIRSTNAME = :r.FirstName,
                  TITLE = NULLIF(:r.Title, ''),
                  TITLEOFCOURTESY = NULLIF(:r.TitleOfCourtesy, ''),
                  BIRTHDATE = NULLIF(:r.BirthDate, DATE('0001-01-01')),
                  HIREDATE = NULLIF(:r.HireDate, DATE('0001-01-01')),
                  ADDRESS = NULLIF(:r.Address, ''),
                  CITY = NULLIF(:r.City, ''),
                  REGION = NULLIF(:r.Region, ''),
                  POSTALCODE = NULLIF(:r.PostalCode, ''),
                  COUNTRY = NULLIF(:r.Country, ''),
                  HOMEPHONE = NULLIF(:r.HomePhone, ''),
                  EXTENSION = NULLIF(:r.Extension, ''),
                  REPORTSTO = NULLIF(:r.ReportsTo, 0),
                  NOTES = NULLIF(:r.Notes, '')
            where EMPLOYEEID = :r.EmployeeId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'EmployeeId': 'Employee not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Update employee');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Emp_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Emp_delete export;
  dcl-pi *n ind;
    pEmployeeId like(Employee_t.EmployeeId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from EMPLOYEES
            where EMPLOYEEID = :pEmployeeId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'EmployeeId': 'Employee not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete employee');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Emp_openList - open list cursor at a starting position
//   Ordered by UPPER(LASTNAME), EMPLOYEEID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Emp_openList export;
  dcl-pi *n ind;
    positionTo like(Employee_t.LastName) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close EMPLIST;                      // ignore "not open"

  gPos = %trimr(positionTo);

  exec sql open EMPLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open employee list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Emp_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Emp_fetchNext export;
  dcl-pi *n ind;
    rec likeds(Employee_t);
  end-pi;

  exec sql fetch next from EMPLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Emp_closeList
//------------------------------------------------------------------------------
dcl-proc Emp_closeList export;
  exec sql close EMPLIST;
end-proc;

//------------------------------------------------------------------------------
// Emp_nextKey - suggested next employee id (MAX + 1)
//------------------------------------------------------------------------------
dcl-proc Emp_nextKey export;
  dcl-pi *n like(Employee_t.EmployeeId);
  end-pi;

  dcl-s nextId int(10) inz(1);

  exec sql select COALESCE(MAX(EMPLOYEEID), 0) + 1 into :nextId from EMPLOYEES;
  if not NwU_sqlOk(sqlstate);
    nextId = 1;
  endif;
  return nextId;
end-proc;

//------------------------------------------------------------------------------
// Emp_ReportsToDesc - description of the manager
//------------------------------------------------------------------------------
dcl-proc Emp_ReportsToDesc export;
  dcl-pi *n varchar(50);
    value like(Employee_t.ReportsTo) const;
  end-pi;

  dcl-s v    like(Employee_t.ReportsTo);
  dcl-s desc varchar(50) inz('');

  v = value;
  if v = 0;
    return '';
  endif;
  exec sql select CAST(TRIM(FIRSTNAME) || ' ' || TRIM(LASTNAME) AS VARCHAR(50)) into :desc
             from EMPLOYEES
            where EMPLOYEEID = :v
            fetch first 1 row only;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return '';
  endif;
  return %trimr(desc);
end-proc;

//------------------------------------------------------------------------------
// sqlFail - capture diagnostics for the last statement (internal)
//------------------------------------------------------------------------------
dcl-proc sqlFail;
  dcl-pi *n ind;
    err     likeds(NwError_t);
    context varchar(60) const;
  end-pi;

  dcl-s state   char(5);
  dcl-s code    int(10);
  dcl-s msgText varchar(512) inz('');

  state = sqlstate;
  code  = sqlcode;
  exec sql get diagnostics condition 1 :msgText = MESSAGE_TEXT;
  return NwU_sqlError(err: state: code: msgText: context);
end-proc;
