**free
//==============================================================================
// TSHPSV - iRPGUnit tests for service program NWSHPSV (SHIPPERS)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TSHPSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWSHPSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TSHPSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWSHPPR

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
  Tst_exec('delete from SHIPPERS where COMPANYNAME like ''ZZZZ%''');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from SHIPPERS where COMPANYNAME like ''ZZZZ%''');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from SHIPPERS where COMPANYNAME like ''ZZZZ%''');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(Shipper_t);
  end-pi;
  dcl-ds r likeds(Shipper_t) inz;

  r.CompanyName = 'ZZZZ UNIT COMPANYNAME';
  r.Phone = 'ZZZZ UNIT PHONE';
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(Shipper_t) inz;
  dcl-ds g   likeds(Shipper_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Shp_create(r: err): 'Create failed: ' + err.text);
  assert(r.ShipperId > 0: 'No identity value returned');
  assert(Shp_get(r.ShipperId: g: err): 'Get failed: ' + err.text);
  iEqual(r.ShipperId: g.ShipperId);
  aEqual(r.CompanyName: g.CompanyName);
  aEqual(r.Phone: g.Phone);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_update export;
  dcl-ds r   likeds(Shipper_t) inz;
  dcl-ds g   likeds(Shipper_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Shp_create(r: err): 'Create failed: ' + err.text);
  assert(r.ShipperId > 0: 'No identity value returned');
  r.CompanyName = 'ZZZZ UPDATED';
  assert(Shp_update(r: err): 'Update failed: ' + err.text);
  assert(Shp_get(r.ShipperId: g: err): 'Get failed: ' + err.text);
  aEqual(r.CompanyName: g.CompanyName);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(Shipper_t) inz;
  dcl-ds g   likeds(Shipper_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Shp_create(r: err): 'Create failed: ' + err.text);
  assert(r.ShipperId > 0: 'No identity value returned');
  assert(Shp_delete(r.ShipperId: err): 'Delete failed: ' + err.text);
  assert(not Shp_exists(r.ShipperId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(Shipper_t) inz;
  dcl-ds g   likeds(Shipper_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.ShipperId = -1;
  assert(not Shp_delete(r.ShipperId: err): 'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_updateNotFound export;
  dcl-ds r   likeds(Shipper_t) inz;
  dcl-ds g   likeds(Shipper_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.ShipperId = -1;
  assert(not Shp_update(r: err): 'Update of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredCompanyName export;
  dcl-ds r   likeds(Shipper_t) inz;
  dcl-ds g   likeds(Shipper_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CompanyName = '';
  assert(not Shp_validate(r: ACTION_CREATE: err): 'Missing company name accepted');
  aEqual('CompanyName': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(Shipper_t) inz;
  dcl-ds g     likeds(Shipper_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Shp_create(r: err): 'Create failed: ' + err.text);
  assert(r.ShipperId > 0: 'No identity value returned');
  assert(Shp_openList(r.ShipperId: err): 'openList failed: ' + err.text);
  found = Shp_fetchNext(g);
  Shp_closeList();
  assert(found: 'List returned no rows');
  iEqual(r.ShipperId: g.ShipperId);
end-proc;

