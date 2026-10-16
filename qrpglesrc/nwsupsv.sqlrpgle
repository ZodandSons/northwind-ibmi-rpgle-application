**free
//==============================================================================
// NWSUPSV - Data access service program for SUPPLIERS
//
// All SQL for SUPPLIERS lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWSUPPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWSUPSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWSUPSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWSUPPR

// Host variables for the list cursor
dcl-s  gPos like(Supplier_t.CompanyName);
dcl-ds gRow likeds(Supplier_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare SUPLIST cursor for
  select SUPPLIERID,
         COMPANYNAME,
         COALESCE(CONTACTNAME, ''),
         COALESCE(CONTACTTITLE, ''),
         COALESCE(ADDRESS, ''),
         COALESCE(CITY, ''),
         COALESCE(REGION, ''),
         COALESCE(POSTALCODE, ''),
         COALESCE(COUNTRY, ''),
         COALESCE(PHONE, ''),
         COALESCE(FAX, ''),
         CAST(COALESCE(HOMEPAGE, '') AS VARCHAR(1024))
    from SUPPLIERS
   where UPPER(COMPANYNAME) >= UPPER(:gPos)
   order by UPPER(COMPANYNAME), SUPPLIERID
   for read only;

//------------------------------------------------------------------------------
// Sup_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Sup_get export;
  dcl-pi *n ind;
    pSupplierId like(Supplier_t.SupplierId) const;
    rec likeds(Supplier_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Supplier_t) inz;

  NwU_clearError(err);

  exec sql
    select SUPPLIERID,
           COMPANYNAME,
           COALESCE(CONTACTNAME, ''),
           COALESCE(CONTACTTITLE, ''),
           COALESCE(ADDRESS, ''),
           COALESCE(CITY, ''),
           COALESCE(REGION, ''),
           COALESCE(POSTALCODE, ''),
           COALESCE(COUNTRY, ''),
           COALESCE(PHONE, ''),
           COALESCE(FAX, ''),
           CAST(COALESCE(HOMEPAGE, '') AS VARCHAR(1024))
      into :r
      from SUPPLIERS
     where SUPPLIERID = :pSupplierId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'SupplierId': 'Supplier not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve supplier');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Sup_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Sup_exists export;
  dcl-pi *n ind;
    pSupplierId like(Supplier_t.SupplierId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from SUPPLIERS
            where SUPPLIERID = :pSupplierId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Sup_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Sup_validate export;
  dcl-pi *n ind;
    rec    likeds(Supplier_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(Supplier_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    // identity key is assigned by the database
  else;
    if not Sup_exists(v.SupplierId);
      return NwU_setError(err: NWE_NOTFOUND: 'SupplierId':
                          'Supplier not found.');
    endif;
  endif;

  // Field checks
  if %len(%trim(v.CompanyName)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'CompanyName': 'Company name is required.');
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Sup_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Sup_create export;
  dcl-pi *n ind;
    rec likeds(Supplier_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Supplier_t) inz;
  dcl-s  newId int(10) inz(0);

  if not Sup_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql select SUPPLIERID into :newId
             from final table (
                  insert into SUPPLIERS
                    (COMPANYNAME, CONTACTNAME, CONTACTTITLE, ADDRESS, CITY, REGION, POSTALCODE,
                     COUNTRY, PHONE, FAX, HOMEPAGE)
                    values(:r.CompanyName, NULLIF(:r.ContactName, ''),
                           NULLIF(:r.ContactTitle, ''), NULLIF(:r.Address, ''),
                           NULLIF(:r.City, ''), NULLIF(:r.Region, ''),
                           NULLIF(:r.PostalCode, ''), NULLIF(:r.Country, ''),
                           NULLIF(:r.Phone, ''), NULLIF(:r.Fax, ''), NULLIF(:r.HomePage, '')));

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create supplier');
  endif;
  rec.SupplierId = newId;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Sup_update - validate and update all non-key columns
//------------------------------------------------------------------------------
dcl-proc Sup_update export;
  dcl-pi *n ind;
    rec likeds(Supplier_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Supplier_t) inz;

  if not Sup_validate(rec: ACTION_UPDATE: err);
    return *off;
  endif;
  r = rec;

  exec sql update SUPPLIERS
              set COMPANYNAME = :r.CompanyName,
                  CONTACTNAME = NULLIF(:r.ContactName, ''),
                  CONTACTTITLE = NULLIF(:r.ContactTitle, ''),
                  ADDRESS = NULLIF(:r.Address, ''),
                  CITY = NULLIF(:r.City, ''),
                  REGION = NULLIF(:r.Region, ''),
                  POSTALCODE = NULLIF(:r.PostalCode, ''),
                  COUNTRY = NULLIF(:r.Country, ''),
                  PHONE = NULLIF(:r.Phone, ''),
                  FAX = NULLIF(:r.Fax, ''),
                  HOMEPAGE = NULLIF(:r.HomePage, '')
            where SUPPLIERID = :r.SupplierId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'SupplierId': 'Supplier not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Update supplier');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Sup_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Sup_delete export;
  dcl-pi *n ind;
    pSupplierId like(Supplier_t.SupplierId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from SUPPLIERS
            where SUPPLIERID = :pSupplierId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'SupplierId': 'Supplier not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete supplier');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Sup_openList - open list cursor at a starting position
//   Ordered by UPPER(COMPANYNAME), SUPPLIERID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Sup_openList export;
  dcl-pi *n ind;
    positionTo like(Supplier_t.CompanyName) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close SUPLIST;                      // ignore "not open"

  gPos = %trimr(positionTo);

  exec sql open SUPLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open supplier list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Sup_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Sup_fetchNext export;
  dcl-pi *n ind;
    rec likeds(Supplier_t);
  end-pi;

  exec sql fetch next from SUPLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Sup_closeList
//------------------------------------------------------------------------------
dcl-proc Sup_closeList export;
  exec sql close SUPLIST;
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
