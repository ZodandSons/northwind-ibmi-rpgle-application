**free
//==============================================================================
// TSUPSV - iRPGUnit tests for service program NWSUPSV (SUPPLIERS)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TSUPSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWSUPSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TSUPSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWSUPPR

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
  Tst_exec('delete from SUPPLIERS where COMPANYNAME like ''ZZZZ%''');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from SUPPLIERS where COMPANYNAME like ''ZZZZ%''');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from SUPPLIERS where COMPANYNAME like ''ZZZZ%''');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(Supplier_t);
  end-pi;
  dcl-ds r likeds(Supplier_t) inz;

  r.CompanyName = 'ZZZZ UNIT COMPANYNAME';
  r.ContactName = 'ZZZZ UNIT CONTACTNAME';
  r.ContactTitle = 'ZZZZ UNIT CONTACTTITLE';
  r.Address = 'ZZZZ UNIT ADDRESS';
  r.City = 'ZZZZ UNIT CITY';
  r.Region = 'ZZZZ UNIT REGIO';
  r.PostalCode = 'ZZZZ UNIT';
  r.Country = 'ZZZZ UNIT COUNT';
  r.Phone = 'ZZZZ UNIT PHONE';
  r.Fax = 'ZZZZ UNIT FAX';
  r.HomePage = 'Unit test text for SUPPLIERS. ' +
            'This sentence is long enough to need word wrapping.';
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(Supplier_t) inz;
  dcl-ds g   likeds(Supplier_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Sup_create(r: err): 'Create failed: ' + err.text);
  assert(r.SupplierId > 0: 'No identity value returned');
  assert(Sup_get(r.SupplierId: g: err): 'Get failed: ' + err.text);
  iEqual(r.SupplierId: g.SupplierId);
  aEqual(r.CompanyName: g.CompanyName);
  aEqual(r.ContactName: g.ContactName);
  aEqual(r.ContactTitle: g.ContactTitle);
  aEqual(r.Address: g.Address);
  aEqual(r.City: g.City);
  aEqual(r.Region: g.Region);
  aEqual(r.PostalCode: g.PostalCode);
  aEqual(r.Country: g.Country);
  aEqual(r.Phone: g.Phone);
  aEqual(r.Fax: g.Fax);
  aEqual(r.HomePage: g.HomePage);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_update export;
  dcl-ds r   likeds(Supplier_t) inz;
  dcl-ds g   likeds(Supplier_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Sup_create(r: err): 'Create failed: ' + err.text);
  assert(r.SupplierId > 0: 'No identity value returned');
  r.CompanyName = 'ZZZZ UPDATED';
  assert(Sup_update(r: err): 'Update failed: ' + err.text);
  assert(Sup_get(r.SupplierId: g: err): 'Get failed: ' + err.text);
  aEqual(r.CompanyName: g.CompanyName);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(Supplier_t) inz;
  dcl-ds g   likeds(Supplier_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Sup_create(r: err): 'Create failed: ' + err.text);
  assert(r.SupplierId > 0: 'No identity value returned');
  assert(Sup_delete(r.SupplierId: err): 'Delete failed: ' + err.text);
  assert(not Sup_exists(r.SupplierId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(Supplier_t) inz;
  dcl-ds g   likeds(Supplier_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.SupplierId = -1;
  assert(not Sup_delete(r.SupplierId: err): 'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_updateNotFound export;
  dcl-ds r   likeds(Supplier_t) inz;
  dcl-ds g   likeds(Supplier_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.SupplierId = -1;
  assert(not Sup_update(r: err): 'Update of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredCompanyName export;
  dcl-ds r   likeds(Supplier_t) inz;
  dcl-ds g   likeds(Supplier_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CompanyName = '';
  assert(not Sup_validate(r: ACTION_CREATE: err): 'Missing company name accepted');
  aEqual('CompanyName': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(Supplier_t) inz;
  dcl-ds g     likeds(Supplier_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Sup_create(r: err): 'Create failed: ' + err.text);
  assert(r.SupplierId > 0: 'No identity value returned');
  assert(Sup_openList(r.CompanyName: err): 'openList failed: ' + err.text);
  found = Sup_fetchNext(g);
  Sup_closeList();
  assert(found: 'List returned no rows');
  iEqual(r.SupplierId: g.SupplierId);
end-proc;

