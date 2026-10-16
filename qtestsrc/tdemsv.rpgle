**free
//==============================================================================
// TDEMSV - iRPGUnit tests for service program NWDEMSV (CUSTOMERDEMOGRAPHICS)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TDEMSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWDEMSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TDEMSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWDEMPR

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
  Tst_exec('delete from CUSTOMERDEMOGRAPHICS where CUSTOMERTYPEID = ''ZZTEST''');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from CUSTOMERDEMOGRAPHICS where CUSTOMERTYPEID = ''ZZTEST''');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from CUSTOMERDEMOGRAPHICS where CUSTOMERTYPEID = ' +
           '''ZZTEST''');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(CustDemo_t);
  end-pi;
  dcl-ds r likeds(CustDemo_t) inz;

  r.CustomerTypeId = 'ZZTEST';
  r.CustomerDesc = 'Unit test text for CUSTOMERDEMOGRAPHICS. ' +
            'This sentence is long enough to need word wrapping.';
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(CustDemo_t) inz;
  dcl-ds g   likeds(CustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Dem_create(r: err): 'Create failed: ' + err.text);
  assert(Dem_get(r.CustomerTypeId: g: err): 'Get failed: ' + err.text);
  aEqual(r.CustomerTypeId: g.CustomerTypeId);
  aEqual(r.CustomerDesc: g.CustomerDesc);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(CustDemo_t) inz;
  dcl-ds g   likeds(CustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Dem_create(r: err): 'Create failed: ' + err.text);
  assert(Dem_delete(r.CustomerTypeId: err): 'Delete failed: ' + err.text);
  assert(not Dem_exists(r.CustomerTypeId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(CustDemo_t) inz;
  dcl-ds g   likeds(CustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Dem_delete(r.CustomerTypeId: err): 'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_updateNotFound export;
  dcl-ds r   likeds(CustDemo_t) inz;
  dcl-ds g   likeds(CustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Dem_update(r: err): 'Update of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredCustomerTypeId export;
  dcl-ds r   likeds(CustDemo_t) inz;
  dcl-ds g   likeds(CustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CustomerTypeId = '';
  assert(not Dem_validate(r: ACTION_CREATE: err): 'Missing key accepted');
  aEqual('CustomerTypeId': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_duplicateKey export;
  dcl-ds r   likeds(CustDemo_t) inz;
  dcl-ds g   likeds(CustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Dem_create(r: err): 'Create failed: ' + err.text);
  assert(not Dem_validate(r: ACTION_CREATE: err): 'Duplicate key accepted');
  aEqual('CustomerTypeId': err.field);
  aEqual(NWE_DUPLICATE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(CustDemo_t) inz;
  dcl-ds g     likeds(CustDemo_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Dem_create(r: err): 'Create failed: ' + err.text);
  assert(Dem_openList(r.CustomerTypeId: err): 'openList failed: ' + err.text);
  found = Dem_fetchNext(g);
  Dem_closeList();
  assert(found: 'List returned no rows');
  aEqual(r.CustomerTypeId: g.CustomerTypeId);
end-proc;

