**free
//==============================================================================
// NWETRSV - Data access service program for EMPLOYEETERRITORIES
//
// All SQL for EMPLOYEETERRITORIES lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWETRPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWETRSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWETRSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWETRPR

// Host variables for the list cursor
dcl-s  gPos like(EmpTerritory_t.EmployeeId);
dcl-ds gRow likeds(EmpTerritory_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare ETRLIST cursor for
  select EMPLOYEEID,
         TERRITORYID
    from EMPLOYEETERRITORIES
   where EMPLOYEEID >= :gPos
   order by EMPLOYEEID, TERRITORYID
   for read only;

//------------------------------------------------------------------------------
// Etr_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Etr_get export;
  dcl-pi *n ind;
    pEmployeeId like(EmpTerritory_t.EmployeeId) const;
    pTerritoryId like(EmpTerritory_t.TerritoryId) const;
    rec likeds(EmpTerritory_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(EmpTerritory_t) inz;

  NwU_clearError(err);

  exec sql
    select EMPLOYEEID,
           TERRITORYID
      into :r
      from EMPLOYEETERRITORIES
     where EMPLOYEEID = :pEmployeeId and TERRITORYID = :pTerritoryId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'EmployeeId': 'Employee territory not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve employee territory');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Etr_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Etr_exists export;
  dcl-pi *n ind;
    pEmployeeId like(EmpTerritory_t.EmployeeId) const;
    pTerritoryId like(EmpTerritory_t.TerritoryId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from EMPLOYEETERRITORIES
            where EMPLOYEEID = :pEmployeeId and TERRITORYID = :pTerritoryId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Etr_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Etr_validate export;
  dcl-pi *n ind;
    rec    likeds(EmpTerritory_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(EmpTerritory_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    if v.EmployeeId <= 0;
      return NwU_setError(err: NWE_REQUIRED: 'EmployeeId':
                          'Employee must be greater than zero.');
    endif;
    if %len(%trim(v.TerritoryId)) = 0;
      return NwU_setError(err: NWE_REQUIRED: 'TerritoryId': 'Territory is required.');
    endif;
    if v.EmployeeId <> 0;
      found = 0;
      exec sql select 1 into :found from EMPLOYEES
                where EMPLOYEEID = :v.EmployeeId fetch first 1 row only;
      if found <> 1;
        return NwU_setError(err: NWE_REFERENCE: 'EmployeeId':
                            'Employee not found.');
      endif;
    else;
      return NwU_setError(err: NWE_REQUIRED: 'EmployeeId': 'Employee is required.');
    endif;
    if %len(%trim(v.TerritoryId)) > 0;
      found = 0;
      exec sql select 1 into :found from TERRITORIES
                where TERRITORYID = :v.TerritoryId fetch first 1 row only;
      if found <> 1;
        return NwU_setError(err: NWE_REFERENCE: 'TerritoryId':
                            'Territory not found.');
      endif;
    else;
      return NwU_setError(err: NWE_REQUIRED: 'TerritoryId': 'Territory is required.');
    endif;
    if Etr_exists(v.EmployeeId: v.TerritoryId);
      return NwU_setError(err: NWE_DUPLICATE: 'EmployeeId':
                          'Employee territory already exists.');
    endif;
  endif;


  return *on;
end-proc;

//------------------------------------------------------------------------------
// Etr_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Etr_create export;
  dcl-pi *n ind;
    rec likeds(EmpTerritory_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(EmpTerritory_t) inz;

  if not Etr_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql insert into EMPLOYEETERRITORIES
                  (EMPLOYEEID, TERRITORYID)
                  values(:r.EmployeeId, :r.TerritoryId);

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create employee territory');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Etr_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Etr_delete export;
  dcl-pi *n ind;
    pEmployeeId like(EmpTerritory_t.EmployeeId) const;
    pTerritoryId like(EmpTerritory_t.TerritoryId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from EMPLOYEETERRITORIES
            where EMPLOYEEID = :pEmployeeId and TERRITORYID = :pTerritoryId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'EmployeeId': 'Employee territory not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete employee territory');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Etr_openList - open list cursor at a starting position
//   Ordered by EMPLOYEEID, TERRITORYID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Etr_openList export;
  dcl-pi *n ind;
    positionTo like(EmpTerritory_t.EmployeeId) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close ETRLIST;                      // ignore "not open"

  gPos = positionTo;

  exec sql open ETRLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open employee territory list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Etr_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Etr_fetchNext export;
  dcl-pi *n ind;
    rec likeds(EmpTerritory_t);
  end-pi;

  exec sql fetch next from ETRLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Etr_closeList
//------------------------------------------------------------------------------
dcl-proc Etr_closeList export;
  exec sql close ETRLIST;
end-proc;

//------------------------------------------------------------------------------
// Etr_EmployeeIdDesc - description of the employee
//------------------------------------------------------------------------------
dcl-proc Etr_EmployeeIdDesc export;
  dcl-pi *n varchar(50);
    value like(EmpTerritory_t.EmployeeId) const;
  end-pi;

  dcl-s v    like(EmpTerritory_t.EmployeeId);
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
// Etr_TerritoryIdDesc - description of the territory
//------------------------------------------------------------------------------
dcl-proc Etr_TerritoryIdDesc export;
  dcl-pi *n varchar(50);
    value like(EmpTerritory_t.TerritoryId) const;
  end-pi;

  dcl-s v    like(EmpTerritory_t.TerritoryId);
  dcl-s desc varchar(50) inz('');

  v = value;
  if %len(%trim(v)) = 0;
    return '';
  endif;
  exec sql select CAST(TERRITORYDESCRIPTION AS VARCHAR(50)) into :desc
             from TERRITORIES
            where TERRITORYID = :v
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
