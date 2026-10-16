**free
//==============================================================================
// TREGSV - iRPGUnit tests for service program NWREGSV (REGION)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TREGSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWREGSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TREGSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWREGPR

//------------------------------------------------------------------------------
// Fixtures
//------------------------------------------------------------------------------
dcl-proc setUpSuite export;
  removeAll();
end-proc;

dcl-proc tearDownSuite export;
  removeAll();
end-proc;

dcl-proc setUp export;
  Tst_exec('delete from REGION where REGIONID = 9901');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from REGION where REGIONID = 9901');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from REGION where REGIONID = 9901');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(Region_t);
  end-pi;
  dcl-ds r likeds(Region_t) inz;

  r.RegionId = 9901;
  r.RegionDescription = 'ZZZZ UNIT REGIONDESCRIPTION';
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(Region_t) inz;
  dcl-ds g   likeds(Region_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Reg_create(r: err): 'Create failed: ' + err.text);
  assert(Reg_get(r.RegionId: g: err): 'Get failed: ' + err.text);
  iEqual(r.RegionId: g.RegionId);
  aEqual(r.RegionDescription: g.RegionDescription);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_update export;
  dcl-ds r   likeds(Region_t) inz;
  dcl-ds g   likeds(Region_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Reg_create(r: err): 'Create failed: ' + err.text);
  r.RegionDescription = 'ZZZZ UPDATED';
  assert(Reg_update(r: err): 'Update failed: ' + err.text);
  assert(Reg_get(r.RegionId: g: err): 'Get failed: ' + err.text);
  aEqual(r.RegionDescription: g.RegionDescription);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(Region_t) inz;
  dcl-ds g   likeds(Region_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Reg_create(r: err): 'Create failed: ' + err.text);
  assert(Reg_delete(r.RegionId: err): 'Delete failed: ' + err.text);
  assert(not Reg_exists(r.RegionId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(Region_t) inz;
  dcl-ds g   likeds(Region_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Reg_delete(r.RegionId: err): 'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_updateNotFound export;
  dcl-ds r   likeds(Region_t) inz;
  dcl-ds g   likeds(Region_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Reg_update(r: err): 'Update of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredRegionDescription export;
  dcl-ds r   likeds(Region_t) inz;
  dcl-ds g   likeds(Region_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.RegionDescription = '';
  assert(not Reg_validate(r: ACTION_CREATE: err): 'Missing description accepted');
  aEqual('RegionDescription': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredRegionId export;
  dcl-ds r   likeds(Region_t) inz;
  dcl-ds g   likeds(Region_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.RegionId = 0;
  assert(not Reg_validate(r: ACTION_CREATE: err): 'Missing key accepted');
  aEqual('RegionId': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_duplicateKey export;
  dcl-ds r   likeds(Region_t) inz;
  dcl-ds g   likeds(Region_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Reg_create(r: err): 'Create failed: ' + err.text);
  assert(not Reg_validate(r: ACTION_CREATE: err): 'Duplicate key accepted');
  aEqual('RegionId': err.field);
  aEqual(NWE_DUPLICATE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(Region_t) inz;
  dcl-ds g     likeds(Region_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Reg_create(r: err): 'Create failed: ' + err.text);
  assert(Reg_openList(r.RegionId: err): 'openList failed: ' + err.text);
  found = Reg_fetchNext(g);
  Reg_closeList();
  assert(found: 'List returned no rows');
  iEqual(r.RegionId: g.RegionId);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_nextKey export;
  assert(Reg_nextKey() > 0: 'nextKey returned zero');
end-proc;

