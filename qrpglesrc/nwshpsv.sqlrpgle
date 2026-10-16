**free
//==============================================================================
// NWSHPSV - Data access service program for SHIPPERS
//
// All SQL for SHIPPERS lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWSHPPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWSHPSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWSHPSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWSHPPR

// Host variables for the list cursor
dcl-s  gPos like(Shipper_t.ShipperId);
dcl-ds gRow likeds(Shipper_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare SHPLIST cursor for
  select SHIPPERID,
         COMPANYNAME,
         COALESCE(PHONE, '')
    from SHIPPERS
   where SHIPPERID >= :gPos
   order by SHIPPERID
   for read only;

//------------------------------------------------------------------------------
// Shp_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Shp_get export;
  dcl-pi *n ind;
    pShipperId like(Shipper_t.ShipperId) const;
    rec likeds(Shipper_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Shipper_t) inz;

  NwU_clearError(err);

  exec sql
    select SHIPPERID,
           COMPANYNAME,
           COALESCE(PHONE, '')
      into :r
      from SHIPPERS
     where SHIPPERID = :pShipperId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'ShipperId': 'Shipper not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve shipper');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Shp_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Shp_exists export;
  dcl-pi *n ind;
    pShipperId like(Shipper_t.ShipperId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from SHIPPERS
            where SHIPPERID = :pShipperId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Shp_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Shp_validate export;
  dcl-pi *n ind;
    rec    likeds(Shipper_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(Shipper_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    // identity key is assigned by the database
  else;
    if not Shp_exists(v.ShipperId);
      return NwU_setError(err: NWE_NOTFOUND: 'ShipperId':
                          'Shipper not found.');
    endif;
  endif;

  // Field checks
  if %len(%trim(v.CompanyName)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'CompanyName': 'Company name is required.');
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Shp_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Shp_create export;
  dcl-pi *n ind;
    rec likeds(Shipper_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Shipper_t) inz;
  dcl-s  newId int(10) inz(0);

  if not Shp_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql select SHIPPERID into :newId
             from final table (
                  insert into SHIPPERS
                    (COMPANYNAME, PHONE)
                    values(:r.CompanyName, NULLIF(:r.Phone, '')));

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create shipper');
  endif;
  rec.ShipperId = newId;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Shp_update - validate and update all non-key columns
//------------------------------------------------------------------------------
dcl-proc Shp_update export;
  dcl-pi *n ind;
    rec likeds(Shipper_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Shipper_t) inz;

  if not Shp_validate(rec: ACTION_UPDATE: err);
    return *off;
  endif;
  r = rec;

  exec sql update SHIPPERS
              set COMPANYNAME = :r.CompanyName,
                  PHONE = NULLIF(:r.Phone, '')
            where SHIPPERID = :r.ShipperId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'ShipperId': 'Shipper not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Update shipper');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Shp_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Shp_delete export;
  dcl-pi *n ind;
    pShipperId like(Shipper_t.ShipperId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from SHIPPERS
            where SHIPPERID = :pShipperId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'ShipperId': 'Shipper not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete shipper');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Shp_openList - open list cursor at a starting position
//   Ordered by SHIPPERID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Shp_openList export;
  dcl-pi *n ind;
    positionTo like(Shipper_t.ShipperId) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close SHPLIST;                      // ignore "not open"

  gPos = positionTo;

  exec sql open SHPLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open shipper list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Shp_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Shp_fetchNext export;
  dcl-pi *n ind;
    rec likeds(Shipper_t);
  end-pi;

  exec sql fetch next from SHPLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Shp_closeList
//------------------------------------------------------------------------------
dcl-proc Shp_closeList export;
  exec sql close SHPLIST;
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
