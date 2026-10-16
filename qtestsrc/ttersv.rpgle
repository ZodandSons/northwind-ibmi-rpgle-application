**free
//==============================================================================
// TTERSV - iRPGUnit tests for service program NWTERSV (TERRITORIES)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TTERSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWTERSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TTERSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWTERPR

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
  Tst_exec('delete from TERRITORIES where TERRITORYID = ''ZZT01''');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from TERRITORIES where TERRITORYID = ''ZZT01''');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from TERRITORIES where TERRITORYID = ''ZZT01''');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(Territory_t);
  end-pi;
  dcl-ds r likeds(Territory_t) inz;

  r.TerritoryId = 'ZZT01';
  r.TerritoryDescription = 'ZZZZ UNIT TERRITORYDESCRIPTION';
  r.RegionId = 1;
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Ter_create(r: err): 'Create failed: ' + err.text);
  assert(Ter_get(r.TerritoryId: g: err): 'Get failed: ' + err.text);
  aEqual(r.TerritoryId: g.TerritoryId);
  aEqual(r.TerritoryDescription: g.TerritoryDescription);
  iEqual(r.RegionId: g.RegionId);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_update export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Ter_create(r: err): 'Create failed: ' + err.text);
  r.TerritoryDescription = 'ZZZZ UPDATED';
  assert(Ter_update(r: err): 'Update failed: ' + err.text);
  assert(Ter_get(r.TerritoryId: g: err): 'Get failed: ' + err.text);
  aEqual(r.TerritoryDescription: g.TerritoryDescription);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Ter_create(r: err): 'Create failed: ' + err.text);
  assert(Ter_delete(r.TerritoryId: err): 'Delete failed: ' + err.text);
  assert(not Ter_exists(r.TerritoryId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Ter_delete(r.TerritoryId: err): 'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_updateNotFound export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Ter_update(r: err): 'Update of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredTerritoryDescription export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.TerritoryDescription = '';
  assert(not Ter_validate(r: ACTION_CREATE: err): 'Missing description accepted');
  aEqual('TerritoryDescription': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredTerritoryId export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.TerritoryId = '';
  assert(not Ter_validate(r: ACTION_CREATE: err): 'Missing key accepted');
  aEqual('TerritoryId': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_duplicateKey export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Ter_create(r: err): 'Create failed: ' + err.text);
  assert(not Ter_validate(r: ACTION_CREATE: err): 'Duplicate key accepted');
  aEqual('TerritoryId': err.field);
  aEqual(NWE_DUPLICATE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_invalidRegionId export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.RegionId = 999999;
  assert(not Ter_validate(r: ACTION_CREATE: err): 'Invalid region accepted');
  aEqual('RegionId': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_RegionIdDesc export;
  dcl-ds r   likeds(Territory_t) inz;
  dcl-ds g   likeds(Territory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(%len(Ter_RegionIdDesc(r.RegionId)) > 0: 'No description for a valid region');
  aEqual('': Ter_RegionIdDesc(999999));
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(Territory_t) inz;
  dcl-ds g     likeds(Territory_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Ter_create(r: err): 'Create failed: ' + err.text);
  assert(Ter_openList(r.TerritoryId: err): 'openList failed: ' + err.text);
  found = Ter_fetchNext(g);
  Ter_closeList();
  assert(found: 'List returned no rows');
  aEqual(r.TerritoryId: g.TerritoryId);
end-proc;

