**free
//==============================================================================
// TETRSV - iRPGUnit tests for service program NWETRSV (EMPLOYEETERRITORIES)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TETRSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWETRSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TETRSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWETRPR

//------------------------------------------------------------------------------
// Fixtures
//------------------------------------------------------------------------------
dcl-proc setUpSuite export;
  removeAll();
  if not Tst_exec('insert into EMPLOYEES (EMPLOYEEID, LASTNAME, FIRSTNAME) ' +
                  'values(9902, ''ZZZZTEST'', ''UNIT'')');
    fail('Fixture setup failed, SQLSTATE ' + Tst_lastState());
  endif;
  if not Tst_exec('insert into TERRITORIES (TERRITORYID, TERRITORYDESCRIPTION, ' +
                  'REGIONID) values(''ZZT02'', ''ZZZZ UNIT TEST'', 1)');
    fail('Fixture setup failed, SQLSTATE ' + Tst_lastState());
  endif;
end-proc;

dcl-proc tearDownSuite export;
  removeAll();
end-proc;

dcl-proc setUp export;
  Tst_exec('delete from EMPLOYEETERRITORIES where EMPLOYEEID = 9902');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from EMPLOYEETERRITORIES where EMPLOYEEID = 9902');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from EMPLOYEETERRITORIES where EMPLOYEEID = 9902');
  Tst_exec('delete from TERRITORIES where TERRITORYID = ''ZZT02''');
  Tst_exec('delete from EMPLOYEES where EMPLOYEEID = 9902');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(EmpTerritory_t);
  end-pi;
  dcl-ds r likeds(EmpTerritory_t) inz;

  r.EmployeeId = 9902;
  r.TerritoryId = 'ZZT02';
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds g   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Etr_create(r: err): 'Create failed: ' + err.text);
  assert(Etr_get(r.EmployeeId: r.TerritoryId: g: err): 'Get failed: ' + err.text);
  iEqual(r.EmployeeId: g.EmployeeId);
  aEqual(r.TerritoryId: g.TerritoryId);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds g   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Etr_create(r: err): 'Create failed: ' + err.text);
  assert(Etr_delete(r.EmployeeId: r.TerritoryId: err): 'Delete failed: ' + err.text);
  assert(not Etr_exists(r.EmployeeId: r.TerritoryId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds g   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Etr_delete(r.EmployeeId: r.TerritoryId: err):
         'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_duplicateKey export;
  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds g   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Etr_create(r: err): 'Create failed: ' + err.text);
  assert(not Etr_validate(r: ACTION_CREATE: err): 'Duplicate key accepted');
  aEqual('EmployeeId': err.field);
  aEqual(NWE_DUPLICATE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_invalidEmployeeId export;
  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds g   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.EmployeeId = 999999;
  assert(not Etr_validate(r: ACTION_CREATE: err): 'Invalid employee accepted');
  aEqual('EmployeeId': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_EmployeeIdDesc export;
  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds g   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(%len(Etr_EmployeeIdDesc(r.EmployeeId)) > 0: 'No description for a valid employee');
  aEqual('': Etr_EmployeeIdDesc(999999));
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_invalidTerritoryId export;
  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds g   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.TerritoryId = 'ZZNOPE';
  assert(not Etr_validate(r: ACTION_CREATE: err): 'Invalid territory accepted');
  aEqual('TerritoryId': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_TerritoryIdDesc export;
  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds g   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(%len(Etr_TerritoryIdDesc(r.TerritoryId)) > 0: 'No description for a valid territory');
  aEqual('': Etr_TerritoryIdDesc('ZZNOPE'));
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(EmpTerritory_t) inz;
  dcl-ds g     likeds(EmpTerritory_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Etr_create(r: err): 'Create failed: ' + err.text);
  assert(Etr_openList(r.EmployeeId: err): 'openList failed: ' + err.text);
  found = Etr_fetchNext(g);
  Etr_closeList();
  assert(found: 'List returned no rows');
  iEqual(r.EmployeeId: g.EmployeeId);
  aEqual(r.TerritoryId: g.TerritoryId);
end-proc;

