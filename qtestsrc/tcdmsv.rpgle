**free
//==============================================================================
// TCDMSV - iRPGUnit tests for service program NWCDMSV (CUSTOMERCUSTOMERDEMO)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TCDMSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWCDMSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TCDMSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWCDMPR

//------------------------------------------------------------------------------
// Fixtures
//------------------------------------------------------------------------------
dcl-proc setUpSuite export;
  removeAll();
  if not Tst_exec('insert into CUSTOMERS (CUSTOMERID, COMPANYNAME) ' +
                  'values(''ZZTS2'', ''ZZZZ UNIT TEST'')');
    fail('Fixture setup failed, SQLSTATE ' + Tst_lastState());
  endif;
  if not Tst_exec('insert into CUSTOMERDEMOGRAPHICS (CUSTOMERTYPEID, ' +
                  'CUSTOMERDESC) values(''ZZTEST2'', ''Unit test type'')');
    fail('Fixture setup failed, SQLSTATE ' + Tst_lastState());
  endif;
end-proc;

dcl-proc tearDownSuite export;
  removeAll();
end-proc;

dcl-proc setUp export;
  Tst_exec('delete from CUSTOMERCUSTOMERDEMO where CUSTOMERID = ''ZZTS2''');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from CUSTOMERCUSTOMERDEMO where CUSTOMERID = ''ZZTS2''');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from CUSTOMERCUSTOMERDEMO where CUSTOMERID = ''ZZTS2''');
  Tst_exec('delete from CUSTOMERDEMOGRAPHICS where CUSTOMERTYPEID = ' +
           '''ZZTEST2''');
  Tst_exec('delete from CUSTOMERS where CUSTOMERID = ''ZZTS2''');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(CustCustDemo_t);
  end-pi;
  dcl-ds r likeds(CustCustDemo_t) inz;

  r.CustomerId = 'ZZTS2';
  r.CustomerTypeId = 'ZZTEST2';
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds g   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cdm_create(r: err): 'Create failed: ' + err.text);
  assert(Cdm_get(r.CustomerId: r.CustomerTypeId: g: err): 'Get failed: ' + err.text);
  aEqual(r.CustomerId: g.CustomerId);
  aEqual(r.CustomerTypeId: g.CustomerTypeId);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds g   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cdm_create(r: err): 'Create failed: ' + err.text);
  assert(Cdm_delete(r.CustomerId: r.CustomerTypeId: err): 'Delete failed: ' + err.text);
  assert(not Cdm_exists(r.CustomerId: r.CustomerTypeId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds g   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Cdm_delete(r.CustomerId: r.CustomerTypeId: err):
         'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_duplicateKey export;
  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds g   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cdm_create(r: err): 'Create failed: ' + err.text);
  assert(not Cdm_validate(r: ACTION_CREATE: err): 'Duplicate key accepted');
  aEqual('CustomerId': err.field);
  aEqual(NWE_DUPLICATE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_invalidCustomerId export;
  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds g   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CustomerId = 'ZZNOP';
  assert(not Cdm_validate(r: ACTION_CREATE: err): 'Invalid customer accepted');
  aEqual('CustomerId': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_CustomerIdDesc export;
  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds g   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(%len(Cdm_CustomerIdDesc(r.CustomerId)) > 0: 'No description for a valid customer');
  aEqual('': Cdm_CustomerIdDesc('ZZNOP'));
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_invalidCustomerTypeId export;
  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds g   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CustomerTypeId = 'ZZNOPE';
  assert(not Cdm_validate(r: ACTION_CREATE: err): 'Invalid customer type accepted');
  aEqual('CustomerTypeId': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_CustomerTypeIdDesc export;
  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds g   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(%len(Cdm_CustomerTypeIdDesc(r.CustomerTypeId)) > 0:
         'No description for a valid customer type');
  aEqual('': Cdm_CustomerTypeIdDesc('ZZNOPE'));
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(CustCustDemo_t) inz;
  dcl-ds g     likeds(CustCustDemo_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Cdm_create(r: err): 'Create failed: ' + err.text);
  assert(Cdm_openList(r.CustomerId: err): 'openList failed: ' + err.text);
  found = Cdm_fetchNext(g);
  Cdm_closeList();
  assert(found: 'List returned no rows');
  aEqual(r.CustomerId: g.CustomerId);
  aEqual(r.CustomerTypeId: g.CustomerTypeId);
end-proc;

