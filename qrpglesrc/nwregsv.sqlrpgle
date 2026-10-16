**free
//==============================================================================
// NWREGSV - Data access service program for REGION
//
// All SQL for REGION lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWREGPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWREGSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWREGSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWREGPR

// Host variables for the list cursor
dcl-s  gPos like(Region_t.RegionId);
dcl-ds gRow likeds(Region_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare REGLIST cursor for
  select REGIONID,
         REGIONDESCRIPTION
    from REGION
   where REGIONID >= :gPos
   order by REGIONID
   for read only;

//------------------------------------------------------------------------------
// Reg_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Reg_get export;
  dcl-pi *n ind;
    pRegionId like(Region_t.RegionId) const;
    rec likeds(Region_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Region_t) inz;

  NwU_clearError(err);

  exec sql
    select REGIONID,
           REGIONDESCRIPTION
      into :r
      from REGION
     where REGIONID = :pRegionId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'RegionId': 'Region not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve region');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Reg_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Reg_exists export;
  dcl-pi *n ind;
    pRegionId like(Region_t.RegionId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from REGION
            where REGIONID = :pRegionId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Reg_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Reg_validate export;
  dcl-pi *n ind;
    rec    likeds(Region_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(Region_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    if v.RegionId <= 0;
      return NwU_setError(err: NWE_REQUIRED: 'RegionId':
                          'Region ID must be greater than zero.');
    endif;
    if Reg_exists(v.RegionId);
      return NwU_setError(err: NWE_DUPLICATE: 'RegionId':
                          'Region already exists.');
    endif;
  else;
    if not Reg_exists(v.RegionId);
      return NwU_setError(err: NWE_NOTFOUND: 'RegionId':
                          'Region not found.');
    endif;
  endif;

  // Field checks
  if %len(%trim(v.RegionDescription)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'RegionDescription': 'Description is required.');
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Reg_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Reg_create export;
  dcl-pi *n ind;
    rec likeds(Region_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Region_t) inz;

  if not Reg_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql insert into REGION
                  (REGIONID, REGIONDESCRIPTION)
                  values(:r.RegionId, :r.RegionDescription);

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create region');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Reg_update - validate and update all non-key columns
//------------------------------------------------------------------------------
dcl-proc Reg_update export;
  dcl-pi *n ind;
    rec likeds(Region_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Region_t) inz;

  if not Reg_validate(rec: ACTION_UPDATE: err);
    return *off;
  endif;
  r = rec;

  exec sql update REGION
              set REGIONDESCRIPTION = :r.RegionDescription
            where REGIONID = :r.RegionId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'RegionId': 'Region not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Update region');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Reg_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Reg_delete export;
  dcl-pi *n ind;
    pRegionId like(Region_t.RegionId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from REGION
            where REGIONID = :pRegionId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'RegionId': 'Region not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete region');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Reg_openList - open list cursor at a starting position
//   Ordered by REGIONID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Reg_openList export;
  dcl-pi *n ind;
    positionTo like(Region_t.RegionId) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close REGLIST;                      // ignore "not open"

  gPos = positionTo;

  exec sql open REGLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open region list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Reg_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Reg_fetchNext export;
  dcl-pi *n ind;
    rec likeds(Region_t);
  end-pi;

  exec sql fetch next from REGLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Reg_closeList
//------------------------------------------------------------------------------
dcl-proc Reg_closeList export;
  exec sql close REGLIST;
end-proc;

//------------------------------------------------------------------------------
// Reg_nextKey - suggested next region id (MAX + 1)
//------------------------------------------------------------------------------
dcl-proc Reg_nextKey export;
  dcl-pi *n like(Region_t.RegionId);
  end-pi;

  dcl-s nextId int(10) inz(1);

  exec sql select COALESCE(MAX(REGIONID), 0) + 1 into :nextId from REGION;
  if not NwU_sqlOk(sqlstate);
    nextId = 1;
  endif;
  return nextId;
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
