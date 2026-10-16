**free
//==============================================================================
// TEMPSV - iRPGUnit tests for service program NWEMPSV (EMPLOYEES)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TEMPSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWEMPSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TEMPSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWEMPPR

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
  Tst_exec('delete from EMPLOYEES where EMPLOYEEID = 9901');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from EMPLOYEES where EMPLOYEEID = 9901');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from EMPLOYEES where EMPLOYEEID = 9901');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(Employee_t);
  end-pi;
  dcl-ds r likeds(Employee_t) inz;

  r.EmployeeId = 9901;
  r.LastName = 'ZZZZ UNIT LASTNAME';
  r.FirstName = 'ZZZZ UNIT';
  r.Title = 'ZZZZ UNIT TITLE';
  r.TitleOfCourtesy = 'ZZZZ UNIT TITLEOFCOURTESY';
  r.BirthDate = d'1970-01-15';
  r.HireDate = d'1995-06-01';
  r.Address = 'ZZZZ UNIT ADDRESS';
  r.City = 'ZZZZ UNIT CITY';
  r.Region = 'ZZZZ UNIT REGIO';
  r.PostalCode = 'ZZZZ UNIT';
  r.Country = 'ZZZZ UNIT COUNT';
  r.HomePhone = 'ZZZZ UNIT HOMEPHONE';
  r.Extension = 'ZZZZ';
  r.ReportsTo = 2;
  r.Notes = 'Unit test text for EMPLOYEES. ' +
            'This sentence is long enough to need word wrapping.';
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Emp_create(r: err): 'Create failed: ' + err.text);
  assert(Emp_get(r.EmployeeId: g: err): 'Get failed: ' + err.text);
  iEqual(r.EmployeeId: g.EmployeeId);
  aEqual(r.LastName: g.LastName);
  aEqual(r.FirstName: g.FirstName);
  aEqual(r.Title: g.Title);
  aEqual(r.TitleOfCourtesy: g.TitleOfCourtesy);
  assert(r.BirthDate = g.BirthDate: 'BirthDate not returned as written');
  assert(r.HireDate = g.HireDate: 'HireDate not returned as written');
  aEqual(r.Address: g.Address);
  aEqual(r.City: g.City);
  aEqual(r.Region: g.Region);
  aEqual(r.PostalCode: g.PostalCode);
  aEqual(r.Country: g.Country);
  aEqual(r.HomePhone: g.HomePhone);
  aEqual(r.Extension: g.Extension);
  iEqual(r.ReportsTo: g.ReportsTo);
  aEqual(r.Notes: g.Notes);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_update export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Emp_create(r: err): 'Create failed: ' + err.text);
  r.LastName = 'ZZZZ UPDATED';
  assert(Emp_update(r: err): 'Update failed: ' + err.text);
  assert(Emp_get(r.EmployeeId: g: err): 'Get failed: ' + err.text);
  aEqual(r.LastName: g.LastName);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Emp_create(r: err): 'Create failed: ' + err.text);
  assert(Emp_delete(r.EmployeeId: err): 'Delete failed: ' + err.text);
  assert(not Emp_exists(r.EmployeeId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Emp_delete(r.EmployeeId: err): 'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_updateNotFound export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(not Emp_update(r: err): 'Update of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredLastName export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.LastName = '';
  assert(not Emp_validate(r: ACTION_CREATE: err): 'Missing last name accepted');
  aEqual('LastName': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredEmployeeId export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.EmployeeId = 0;
  assert(not Emp_validate(r: ACTION_CREATE: err): 'Missing key accepted');
  aEqual('EmployeeId': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_duplicateKey export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Emp_create(r: err): 'Create failed: ' + err.text);
  assert(not Emp_validate(r: ACTION_CREATE: err): 'Duplicate key accepted');
  aEqual('EmployeeId': err.field);
  aEqual(NWE_DUPLICATE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_invalidReportsTo export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.ReportsTo = 999999;
  assert(not Emp_validate(r: ACTION_CREATE: err): 'Invalid manager accepted');
  aEqual('ReportsTo': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_ReportsToDesc export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(%len(Emp_ReportsToDesc(r.ReportsTo)) > 0: 'No description for a valid manager');
  aEqual('': Emp_ReportsToDesc(999999));
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(Employee_t) inz;
  dcl-ds g     likeds(Employee_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Emp_create(r: err): 'Create failed: ' + err.text);
  assert(Emp_openList(r.LastName: err): 'openList failed: ' + err.text);
  found = Emp_fetchNext(g);
  Emp_closeList();
  assert(found: 'List returned no rows');
  iEqual(r.EmployeeId: g.EmployeeId);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_nextKey export;
  assert(Emp_nextKey() > 0: 'nextKey returned zero');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_hireBeforeBirth export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.HireDate = d'1960-01-01';
  assert(not Emp_validate(r: ACTION_CREATE: err): 'Hire < birth accepted');
  aEqual('HireDate': err.field);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_reportsToSelf export;
  dcl-ds r   likeds(Employee_t) inz;
  dcl-ds g   likeds(Employee_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.ReportsTo = r.EmployeeId;
  assert(not Emp_validate(r: ACTION_CREATE: err): 'Self-reporting accepted');
  aEqual('ReportsTo': err.field);
  aEqual(NWE_INVALID: err.code);
end-proc;

