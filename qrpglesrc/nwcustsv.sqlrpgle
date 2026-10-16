**free
//==============================================================================
// NWCUSTSV - Data access service program for CUSTOMERS
//
// All SQL for CUSTOMERS lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWCUSTPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWCUSTSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWCUSTSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWCUSTPR

// Host variables for the list cursor
dcl-s  gPos like(Customer_t.CustomerId);
dcl-ds gRow likeds(Customer_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare CUSTLIST cursor for
  select CUSTOMERID,
         COMPANYNAME,
         COALESCE(CONTACTNAME, ''),
         COALESCE(CONTACTTITLE, ''),
         COALESCE(ADDRESS, ''),
         COALESCE(CITY, ''),
         COALESCE(REGION, ''),
         COALESCE(POSTALCODE, ''),
         COALESCE(COUNTRY, ''),
         COALESCE(PHONE, ''),
         COALESCE(FAX, '')
    from CUSTOMERS
   where CUSTOMERID >= :gPos
   order by CUSTOMERID
   for read only;

//------------------------------------------------------------------------------
// Cust_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Cust_get export;
  dcl-pi *n ind;
    pCustomerId like(Customer_t.CustomerId) const;
    rec likeds(Customer_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Customer_t) inz;

  NwU_clearError(err);

  exec sql
    select CUSTOMERID,
           COMPANYNAME,
           COALESCE(CONTACTNAME, ''),
           COALESCE(CONTACTTITLE, ''),
           COALESCE(ADDRESS, ''),
           COALESCE(CITY, ''),
           COALESCE(REGION, ''),
           COALESCE(POSTALCODE, ''),
           COALESCE(COUNTRY, ''),
           COALESCE(PHONE, ''),
           COALESCE(FAX, '')
      into :r
      from CUSTOMERS
     where CUSTOMERID = :pCustomerId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CustomerId': 'Customer not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve customer');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cust_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Cust_exists export;
  dcl-pi *n ind;
    pCustomerId like(Customer_t.CustomerId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from CUSTOMERS
            where CUSTOMERID = :pCustomerId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Cust_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Cust_validate export;
  dcl-pi *n ind;
    rec    likeds(Customer_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(Customer_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    if %len(%trim(v.CustomerId)) = 0;
      return NwU_setError(err: NWE_REQUIRED: 'CustomerId': 'Customer ID is required.');
    endif;
    if Cust_exists(v.CustomerId);
      return NwU_setError(err: NWE_DUPLICATE: 'CustomerId':
                          'Customer already exists.');
    endif;
  else;
    if not Cust_exists(v.CustomerId);
      return NwU_setError(err: NWE_NOTFOUND: 'CustomerId':
                          'Customer not found.');
    endif;
  endif;

  // Field checks
  if %len(%trim(v.CompanyName)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'CompanyName': 'Company name is required.');
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cust_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Cust_create export;
  dcl-pi *n ind;
    rec likeds(Customer_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Customer_t) inz;

  if not Cust_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql insert into CUSTOMERS
                  (CUSTOMERID, COMPANYNAME, CONTACTNAME, CONTACTTITLE, ADDRESS, CITY, REGION,
                   POSTALCODE, COUNTRY, PHONE, FAX)
                  values(:r.CustomerId, :r.CompanyName, NULLIF(:r.ContactName, ''),
                         NULLIF(:r.ContactTitle, ''), NULLIF(:r.Address, ''),
                         NULLIF(:r.City, ''), NULLIF(:r.Region, ''), NULLIF(:r.PostalCode, ''),
                         NULLIF(:r.Country, ''), NULLIF(:r.Phone, ''), NULLIF(:r.Fax, ''));

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create customer');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cust_update - validate and update all non-key columns
//------------------------------------------------------------------------------
dcl-proc Cust_update export;
  dcl-pi *n ind;
    rec likeds(Customer_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Customer_t) inz;

  if not Cust_validate(rec: ACTION_UPDATE: err);
    return *off;
  endif;
  r = rec;

  exec sql update CUSTOMERS
              set COMPANYNAME = :r.CompanyName,
                  CONTACTNAME = NULLIF(:r.ContactName, ''),
                  CONTACTTITLE = NULLIF(:r.ContactTitle, ''),
                  ADDRESS = NULLIF(:r.Address, ''),
                  CITY = NULLIF(:r.City, ''),
                  REGION = NULLIF(:r.Region, ''),
                  POSTALCODE = NULLIF(:r.PostalCode, ''),
                  COUNTRY = NULLIF(:r.Country, ''),
                  PHONE = NULLIF(:r.Phone, ''),
                  FAX = NULLIF(:r.Fax, '')
            where CUSTOMERID = :r.CustomerId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CustomerId': 'Customer not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Update customer');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cust_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Cust_delete export;
  dcl-pi *n ind;
    pCustomerId like(Customer_t.CustomerId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from CUSTOMERS
            where CUSTOMERID = :pCustomerId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CustomerId': 'Customer not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete customer');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cust_openList - open list cursor at a starting position
//   Ordered by CUSTOMERID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Cust_openList export;
  dcl-pi *n ind;
    positionTo like(Customer_t.CustomerId) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close CUSTLIST;                      // ignore "not open"

  gPos = positionTo;

  exec sql open CUSTLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open customer list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cust_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Cust_fetchNext export;
  dcl-pi *n ind;
    rec likeds(Customer_t);
  end-pi;

  exec sql fetch next from CUSTLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cust_closeList
//------------------------------------------------------------------------------
dcl-proc Cust_closeList export;
  exec sql close CUSTLIST;
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
