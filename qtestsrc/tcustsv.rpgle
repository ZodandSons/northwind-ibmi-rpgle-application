**free
//==============================================================================
// TCUSTSV - iRPGUnit tests for service program NWCUSTSV (CUSTOMERS)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TCUSTSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWCUSTSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TCUSTSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWCUSTPR

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
  Tst_exec('delete from CUSTOMERS where CUSTOMERID = ''ZZTST''');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from CUSTOMERS where CUSTOMERID = ''ZZTST''');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from CUSTOMERS where CUSTOMERID = ''ZZTST''');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(Customer_t);
  end-pi;
  dcl-ds r likeds(Customer_t) inz;

  r.CustomerId = 'ZZTST';
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
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(Customer_t) inz;
  dcl-ds g   likeds(Customer_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cust_create(r: err): 'Create failed: ' + err.text);
  assert(Cust_get(r.CustomerId: g: err): 'Get failed: ' + err.text);
  aEqual(r.CustomerId: g.CustomerId);
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
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_update export;
  dcl-ds r   likeds(Customer_t) inz;
  dcl-ds g   likeds(Customer_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cust_create(r: err): 'Create failed: ' + err.text);
  r.CompanyName = 'ZZZZ UPDATED';
  assert(Cust_update(r: err): 'Update failed: ' + err.text);
  assert(Cust_get(r.CustomerId: g: err): 'Get failed: ' + err.text);
  aEqual(r.CompanyName: g.CompanyName);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(Customer_t) inz;
  dcl-ds g   likeds(Customer_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cust_create(r: err): 'Create failed: ' + err.text);
  assert(Cust_delete(r.CustomerId: err): 'Delete failed: ' + err.text);
  assert(not Cust_exists(r.CustomerId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(Customer_t) inz;
  dcl-ds g   likeds(Customer_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Cust_delete(r.CustomerId: err): 'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_updateNotFound export;
  dcl-ds r   likeds(Customer_t) inz;
  dcl-ds g   likeds(Customer_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Cust_update(r: err): 'Update of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredCompanyName export;
  dcl-ds r   likeds(Customer_t) inz;
  dcl-ds g   likeds(Customer_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CompanyName = '';
  assert(not Cust_validate(r: ACTION_CREATE: err): 'Missing company name accepted');
  aEqual('CompanyName': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredCustomerId export;
  dcl-ds r   likeds(Customer_t) inz;
  dcl-ds g   likeds(Customer_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CustomerId = '';
  assert(not Cust_validate(r: ACTION_CREATE: err): 'Missing key accepted');
  aEqual('CustomerId': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_duplicateKey export;
  dcl-ds r   likeds(Customer_t) inz;
  dcl-ds g   likeds(Customer_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cust_create(r: err): 'Create failed: ' + err.text);
  assert(not Cust_validate(r: ACTION_CREATE: err): 'Duplicate key accepted');
  aEqual('CustomerId': err.field);
  aEqual(NWE_DUPLICATE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(Customer_t) inz;
  dcl-ds g     likeds(Customer_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Cust_create(r: err): 'Create failed: ' + err.text);
  assert(Cust_openList(r.CustomerId: err): 'openList failed: ' + err.text);
  found = Cust_fetchNext(g);
  Cust_closeList();
  assert(found: 'List returned no rows');
  aEqual(r.CustomerId: g.CustomerId);
end-proc;

