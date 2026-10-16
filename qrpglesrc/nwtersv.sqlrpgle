**free
//==============================================================================
// NWTERSV - Data access service program for TERRITORIES
//
// All SQL for TERRITORIES lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWTERPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWTERSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWTERSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTERPR

// Host variables for the list cursor
dcl-s  gPos like(Territory_t.TerritoryId);
dcl-ds gRow likeds(Territory_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare TERLIST cursor for
  select TERRITORYID,
         TERRITORYDESCRIPTION,
         REGIONID
    from TERRITORIES
   where TERRITORYID >= :gPos
   order by TERRITORYID
   for read only;

//------------------------------------------------------------------------------
// Ter_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Ter_get export;
  dcl-pi *n ind;
    pTerritoryId like(Territory_t.TerritoryId) const;
    rec likeds(Territory_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Territory_t) inz;

  NwU_clearError(err);

  exec sql
    select TERRITORYID,
           TERRITORYDESCRIPTION,
           REGIONID
      into :r
      from TERRITORIES
     where TERRITORYID = :pTerritoryId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'TerritoryId': 'Territory not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve territory');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ter_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Ter_exists export;
  dcl-pi *n ind;
    pTerritoryId like(Territory_t.TerritoryId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from TERRITORIES
            where TERRITORYID = :pTerritoryId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Ter_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Ter_validate export;
  dcl-pi *n ind;
    rec    likeds(Territory_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(Territory_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    if %len(%trim(v.TerritoryId)) = 0;
      return NwU_setError(err: NWE_REQUIRED: 'TerritoryId': 'Territory ID is required.');
    endif;
    if Ter_exists(v.TerritoryId);
      return NwU_setError(err: NWE_DUPLICATE: 'TerritoryId':
                          'Territory already exists.');
    endif;
  else;
    if not Ter_exists(v.TerritoryId);
      return NwU_setError(err: NWE_NOTFOUND: 'TerritoryId':
                          'Territory not found.');
    endif;
  endif;

  // Field checks
  if %len(%trim(v.TerritoryDescription)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'TerritoryDescription': 'Description is required.');
  endif;
  if v.RegionId <> 0;
    found = 0;
    exec sql select 1 into :found from REGION
              where REGIONID = :v.RegionId fetch first 1 row only;
    if found <> 1;
      return NwU_setError(err: NWE_REFERENCE: 'RegionId':
                          'Region not found.');
    endif;
  else;
    return NwU_setError(err: NWE_REQUIRED: 'RegionId': 'Region is required.');
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ter_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Ter_create export;
  dcl-pi *n ind;
    rec likeds(Territory_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Territory_t) inz;

  if not Ter_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql insert into TERRITORIES
                  (TERRITORYID, TERRITORYDESCRIPTION, REGIONID)
                  values(:r.TerritoryId, :r.TerritoryDescription, :r.RegionId);

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create territory');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ter_update - validate and update all non-key columns
//------------------------------------------------------------------------------
dcl-proc Ter_update export;
  dcl-pi *n ind;
    rec likeds(Territory_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Territory_t) inz;

  if not Ter_validate(rec: ACTION_UPDATE: err);
    return *off;
  endif;
  r = rec;

  exec sql update TERRITORIES
              set TERRITORYDESCRIPTION = :r.TerritoryDescription,
                  REGIONID = :r.RegionId
            where TERRITORYID = :r.TerritoryId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'TerritoryId': 'Territory not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Update territory');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ter_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Ter_delete export;
  dcl-pi *n ind;
    pTerritoryId like(Territory_t.TerritoryId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from TERRITORIES
            where TERRITORYID = :pTerritoryId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'TerritoryId': 'Territory not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete territory');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ter_openList - open list cursor at a starting position
//   Ordered by TERRITORYID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Ter_openList export;
  dcl-pi *n ind;
    positionTo like(Territory_t.TerritoryId) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close TERLIST;                      // ignore "not open"

  gPos = %trimr(positionTo);

  exec sql open TERLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open territory list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ter_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Ter_fetchNext export;
  dcl-pi *n ind;
    rec likeds(Territory_t);
  end-pi;

  exec sql fetch next from TERLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ter_closeList
//------------------------------------------------------------------------------
dcl-proc Ter_closeList export;
  exec sql close TERLIST;
end-proc;

//------------------------------------------------------------------------------
// Ter_RegionIdDesc - description of the region
//------------------------------------------------------------------------------
dcl-proc Ter_RegionIdDesc export;
  dcl-pi *n varchar(50);
    value like(Territory_t.RegionId) const;
  end-pi;

  dcl-s v    like(Territory_t.RegionId);
  dcl-s desc varchar(50) inz('');

  v = value;
  if v = 0;
    return '';
  endif;
  exec sql select CAST(REGIONDESCRIPTION AS VARCHAR(50)) into :desc
             from REGION
            where REGIONID = :v
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
