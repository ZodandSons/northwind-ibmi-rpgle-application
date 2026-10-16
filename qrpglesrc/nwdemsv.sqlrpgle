**free
//==============================================================================
// NWDEMSV - Data access service program for CUSTOMERDEMOGRAPHICS
//
// All SQL for CUSTOMERDEMOGRAPHICS lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWDEMPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWDEMSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWDEMSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWDEMPR

// Host variables for the list cursor
dcl-s  gPos like(CustDemo_t.CustomerTypeId);
dcl-ds gRow likeds(CustDemo_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare DEMLIST cursor for
  select CUSTOMERTYPEID,
         CAST(COALESCE(CUSTOMERDESC, '') AS VARCHAR(1024))
    from CUSTOMERDEMOGRAPHICS
   where CUSTOMERTYPEID >= :gPos
   order by CUSTOMERTYPEID
   for read only;

//------------------------------------------------------------------------------
// Dem_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Dem_get export;
  dcl-pi *n ind;
    pCustomerTypeId like(CustDemo_t.CustomerTypeId) const;
    rec likeds(CustDemo_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(CustDemo_t) inz;

  NwU_clearError(err);

  exec sql
    select CUSTOMERTYPEID,
           CAST(COALESCE(CUSTOMERDESC, '') AS VARCHAR(1024))
      into :r
      from CUSTOMERDEMOGRAPHICS
     where CUSTOMERTYPEID = :pCustomerTypeId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CustomerTypeId': 'Demographic not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve demographic');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Dem_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Dem_exists export;
  dcl-pi *n ind;
    pCustomerTypeId like(CustDemo_t.CustomerTypeId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from CUSTOMERDEMOGRAPHICS
            where CUSTOMERTYPEID = :pCustomerTypeId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Dem_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Dem_validate export;
  dcl-pi *n ind;
    rec    likeds(CustDemo_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(CustDemo_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    if %len(%trim(v.CustomerTypeId)) = 0;
      return NwU_setError(err: NWE_REQUIRED: 'CustomerTypeId': 'Customer type is required.');
    endif;
    if Dem_exists(v.CustomerTypeId);
      return NwU_setError(err: NWE_DUPLICATE: 'CustomerTypeId':
                          'Demographic already exists.');
    endif;
  else;
    if not Dem_exists(v.CustomerTypeId);
      return NwU_setError(err: NWE_NOTFOUND: 'CustomerTypeId':
                          'Demographic not found.');
    endif;
  endif;

  // Field checks

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Dem_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Dem_create export;
  dcl-pi *n ind;
    rec likeds(CustDemo_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(CustDemo_t) inz;

  if not Dem_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql insert into CUSTOMERDEMOGRAPHICS
                  (CUSTOMERTYPEID, CUSTOMERDESC)
                  values(:r.CustomerTypeId, NULLIF(:r.CustomerDesc, ''));

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create demographic');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Dem_update - validate and update all non-key columns
//------------------------------------------------------------------------------
dcl-proc Dem_update export;
  dcl-pi *n ind;
    rec likeds(CustDemo_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(CustDemo_t) inz;

  if not Dem_validate(rec: ACTION_UPDATE: err);
    return *off;
  endif;
  r = rec;

  exec sql update CUSTOMERDEMOGRAPHICS
              set CUSTOMERDESC = NULLIF(:r.CustomerDesc, '')
            where CUSTOMERTYPEID = :r.CustomerTypeId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CustomerTypeId': 'Demographic not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Update demographic');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Dem_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Dem_delete export;
  dcl-pi *n ind;
    pCustomerTypeId like(CustDemo_t.CustomerTypeId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from CUSTOMERDEMOGRAPHICS
            where CUSTOMERTYPEID = :pCustomerTypeId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CustomerTypeId': 'Demographic not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete demographic');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Dem_openList - open list cursor at a starting position
//   Ordered by CUSTOMERTYPEID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Dem_openList export;
  dcl-pi *n ind;
    positionTo like(CustDemo_t.CustomerTypeId) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close DEMLIST;                      // ignore "not open"

  gPos = positionTo;

  exec sql open DEMLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open demographic list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Dem_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Dem_fetchNext export;
  dcl-pi *n ind;
    rec likeds(CustDemo_t);
  end-pi;

  exec sql fetch next from DEMLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Dem_closeList
//------------------------------------------------------------------------------
dcl-proc Dem_closeList export;
  exec sql close DEMLIST;
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
