**free
//==============================================================================
// NWCATSV - Data access service program for CATEGORIES
//
// All SQL for CATEGORIES lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWCATPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWCATSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWCATSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWCATPR

// Host variables for the list cursor
dcl-s  gPos like(Category_t.CategoryName);
dcl-ds gRow likeds(Category_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare CATLIST cursor for
  select CATEGORYID,
         CATEGORYNAME,
         CAST(COALESCE(DESCRIPTION, '') AS VARCHAR(1024))
    from CATEGORIES
   where UPPER(CATEGORYNAME) >= UPPER(:gPos)
   order by UPPER(CATEGORYNAME), CATEGORYID
   for read only;

//------------------------------------------------------------------------------
// Cat_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Cat_get export;
  dcl-pi *n ind;
    pCategoryId like(Category_t.CategoryId) const;
    rec likeds(Category_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Category_t) inz;

  NwU_clearError(err);

  exec sql
    select CATEGORYID,
           CATEGORYNAME,
           CAST(COALESCE(DESCRIPTION, '') AS VARCHAR(1024))
      into :r
      from CATEGORIES
     where CATEGORYID = :pCategoryId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CategoryId': 'Category not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve category');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cat_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Cat_exists export;
  dcl-pi *n ind;
    pCategoryId like(Category_t.CategoryId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from CATEGORIES
            where CATEGORYID = :pCategoryId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Cat_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Cat_validate export;
  dcl-pi *n ind;
    rec    likeds(Category_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(Category_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    // identity key is assigned by the database
  else;
    if not Cat_exists(v.CategoryId);
      return NwU_setError(err: NWE_NOTFOUND: 'CategoryId':
                          'Category not found.');
    endif;
  endif;

  // Field checks
  if %len(%trim(v.CategoryName)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'CategoryName': 'Category name is required.');
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cat_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Cat_create export;
  dcl-pi *n ind;
    rec likeds(Category_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Category_t) inz;
  dcl-s  newId int(10) inz(0);

  if not Cat_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql select CATEGORYID into :newId
             from final table (
                  insert into CATEGORIES
                    (CATEGORYNAME, DESCRIPTION)
                    values(:r.CategoryName, NULLIF(:r.Description, '')));

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create category');
  endif;
  rec.CategoryId = newId;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cat_update - validate and update all non-key columns
//------------------------------------------------------------------------------
dcl-proc Cat_update export;
  dcl-pi *n ind;
    rec likeds(Category_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Category_t) inz;

  if not Cat_validate(rec: ACTION_UPDATE: err);
    return *off;
  endif;
  r = rec;

  exec sql update CATEGORIES
              set CATEGORYNAME = :r.CategoryName,
                  DESCRIPTION = NULLIF(:r.Description, '')
            where CATEGORYID = :r.CategoryId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CategoryId': 'Category not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Update category');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cat_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Cat_delete export;
  dcl-pi *n ind;
    pCategoryId like(Category_t.CategoryId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from CATEGORIES
            where CATEGORYID = :pCategoryId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CategoryId': 'Category not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete category');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cat_openList - open list cursor at a starting position
//   Ordered by UPPER(CATEGORYNAME), CATEGORYID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Cat_openList export;
  dcl-pi *n ind;
    positionTo like(Category_t.CategoryName) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close CATLIST;                      // ignore "not open"

  gPos = %trimr(positionTo);

  exec sql open CATLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open category list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cat_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Cat_fetchNext export;
  dcl-pi *n ind;
    rec likeds(Category_t);
  end-pi;

  exec sql fetch next from CATLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cat_closeList
//------------------------------------------------------------------------------
dcl-proc Cat_closeList export;
  exec sql close CATLIST;
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
