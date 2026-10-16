**free
//==============================================================================
// TCATSV - iRPGUnit tests for service program NWCATSV (CATEGORIES)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TCATSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWCATSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TCATSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWCATPR

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
  Tst_exec('delete from CATEGORIES where CATEGORYNAME like ''ZZZZ%''');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from CATEGORIES where CATEGORYNAME like ''ZZZZ%''');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from CATEGORIES where CATEGORYNAME like ''ZZZZ%''');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(Category_t);
  end-pi;
  dcl-ds r likeds(Category_t) inz;

  r.CategoryName = 'ZZZZ UNIT CATEG';
  r.Description = 'Unit test text for CATEGORIES. ' +
            'This sentence is long enough to need word wrapping.';
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(Category_t) inz;
  dcl-ds g   likeds(Category_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cat_create(r: err): 'Create failed: ' + err.text);
  assert(r.CategoryId > 0: 'No identity value returned');
  assert(Cat_get(r.CategoryId: g: err): 'Get failed: ' + err.text);
  iEqual(r.CategoryId: g.CategoryId);
  aEqual(r.CategoryName: g.CategoryName);
  aEqual(r.Description: g.Description);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_update export;
  dcl-ds r   likeds(Category_t) inz;
  dcl-ds g   likeds(Category_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cat_create(r: err): 'Create failed: ' + err.text);
  assert(r.CategoryId > 0: 'No identity value returned');
  r.CategoryName = 'ZZZZ UPDATED';
  assert(Cat_update(r: err): 'Update failed: ' + err.text);
  assert(Cat_get(r.CategoryId: g: err): 'Get failed: ' + err.text);
  aEqual(r.CategoryName: g.CategoryName);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(Category_t) inz;
  dcl-ds g   likeds(Category_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Cat_create(r: err): 'Create failed: ' + err.text);
  assert(r.CategoryId > 0: 'No identity value returned');
  assert(Cat_delete(r.CategoryId: err): 'Delete failed: ' + err.text);
  assert(not Cat_exists(r.CategoryId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(Category_t) inz;
  dcl-ds g   likeds(Category_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CategoryId = -1;
  assert(not Cat_delete(r.CategoryId: err): 'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_updateNotFound export;
  dcl-ds r   likeds(Category_t) inz;
  dcl-ds g   likeds(Category_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CategoryId = -1;
  assert(not Cat_update(r: err): 'Update of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredCategoryName export;
  dcl-ds r   likeds(Category_t) inz;
  dcl-ds g   likeds(Category_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CategoryName = '';
  assert(not Cat_validate(r: ACTION_CREATE: err): 'Missing category name accepted');
  aEqual('CategoryName': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(Category_t) inz;
  dcl-ds g     likeds(Category_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Cat_create(r: err): 'Create failed: ' + err.text);
  assert(r.CategoryId > 0: 'No identity value returned');
  assert(Cat_openList(r.CategoryName: err): 'openList failed: ' + err.text);
  found = Cat_fetchNext(g);
  Cat_closeList();
  assert(found: 'List returned no rows');
  iEqual(r.CategoryId: g.CategoryId);
end-proc;

