**free
//==============================================================================
// TPRDSV - iRPGUnit tests for service program NWPRDSV (PRODUCTS)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TPRDSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWPRDSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TPRDSV)
//
// Fixture rows use reserved keys/names (ZZ...) and are removed before
// and after every test, so the suite can run against live NORTHWIND data.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWPRDPR

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
  Tst_exec('delete from PRODUCTS where PRODUCTNAME like ''ZZZZ%''');
end-proc;

dcl-proc tearDown export;
  Tst_exec('delete from PRODUCTS where PRODUCTNAME like ''ZZZZ%''');
end-proc;

dcl-proc removeAll;
  Tst_exec('delete from PRODUCTS where PRODUCTNAME like ''ZZZZ%''');
end-proc;

// A valid record that does not exist yet
dcl-proc buildRec;
  dcl-pi *n likeds(Product_t);
  end-pi;
  dcl-ds r likeds(Product_t) inz;

  r.ProductName = 'ZZZZ UNIT PRODUCTNAME';
  r.SupplierId = 1;
  r.CategoryId = 1;
  r.QuantityPerUnit = 'ZZZZ UNIT QUANTITYPE';
  r.UnitPrice = 12.50;
  r.UnitsInStock = 40;
  r.UnitsOnOrder = 10;
  r.ReorderLevel = 5;
  r.Discontinued = 0;
  return r;
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_createAndGet export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Prd_create(r: err): 'Create failed: ' + err.text);
  assert(r.ProductId > 0: 'No identity value returned');
  assert(Prd_get(r.ProductId: g: err): 'Get failed: ' + err.text);
  iEqual(r.ProductId: g.ProductId);
  aEqual(r.ProductName: g.ProductName);
  iEqual(r.SupplierId: g.SupplierId);
  iEqual(r.CategoryId: g.CategoryId);
  aEqual(r.QuantityPerUnit: g.QuantityPerUnit);
  assert(r.UnitPrice = g.UnitPrice: 'UnitPrice not returned as written');
  iEqual(r.UnitsInStock: g.UnitsInStock);
  iEqual(r.UnitsOnOrder: g.UnitsOnOrder);
  iEqual(r.ReorderLevel: g.ReorderLevel);
  iEqual(r.Discontinued: g.Discontinued);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_update export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Prd_create(r: err): 'Create failed: ' + err.text);
  assert(r.ProductId > 0: 'No identity value returned');
  r.ProductName = 'ZZZZ UPDATED';
  assert(Prd_update(r: err): 'Update failed: ' + err.text);
  assert(Prd_get(r.ProductId: g: err): 'Get failed: ' + err.text);
  aEqual(r.ProductName: g.ProductName);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_delete export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(Prd_create(r: err): 'Create failed: ' + err.text);
  assert(r.ProductId > 0: 'No identity value returned');
  assert(Prd_delete(r.ProductId: err): 'Delete failed: ' + err.text);
  assert(not Prd_exists(r.ProductId): 'Record still exists after delete');
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_deleteNotFound export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.ProductId = -1;
  assert(not Prd_delete(r.ProductId: err): 'Delete of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_updateNotFound export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.ProductId = -1;
  assert(not Prd_update(r: err): 'Update of a missing record succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_requiredProductName export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.ProductName = '';
  assert(not Prd_validate(r: ACTION_CREATE: err): 'Missing product name accepted');
  aEqual('ProductName': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_invalidSupplierId export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.SupplierId = 999999;
  assert(not Prd_validate(r: ACTION_CREATE: err): 'Invalid supplier accepted');
  aEqual('SupplierId': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_SupplierIdDesc export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(%len(Prd_SupplierIdDesc(r.SupplierId)) > 0: 'No description for a valid supplier');
  aEqual('': Prd_SupplierIdDesc(999999));
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_invalidCategoryId export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.CategoryId = 999999;
  assert(not Prd_validate(r: ACTION_CREATE: err): 'Invalid category accepted');
  aEqual('CategoryId': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_CategoryIdDesc export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  assert(%len(Prd_CategoryIdDesc(r.CategoryId)) > 0: 'No description for a valid category');
  aEqual('': Prd_CategoryIdDesc(999999));
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_minUnitPrice export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.UnitPrice = -1;
  assert(not Prd_validate(r: ACTION_CREATE: err): 'Negative unit price accepted');
  aEqual('UnitPrice': err.field);
  aEqual(NWE_RANGE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_minUnitsInStock export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.UnitsInStock = -1;
  assert(not Prd_validate(r: ACTION_CREATE: err): 'Negative units in stock accepted');
  aEqual('UnitsInStock': err.field);
  aEqual(NWE_RANGE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_minUnitsOnOrder export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.UnitsOnOrder = -1;
  assert(not Prd_validate(r: ACTION_CREATE: err): 'Negative units on order accepted');
  aEqual('UnitsOnOrder': err.field);
  aEqual(NWE_RANGE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_minReorderLevel export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.ReorderLevel = -1;
  assert(not Prd_validate(r: ACTION_CREATE: err): 'Negative reorder level accepted');
  aEqual('ReorderLevel': err.field);
  aEqual(NWE_RANGE: err.code);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_valuesDiscontinued export;
  dcl-ds r   likeds(Product_t) inz;
  dcl-ds g   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  r = buildRec();
  r.Discontinued = 7;
  assert(not Prd_validate(r: ACTION_CREATE: err): 'Invalid discontinued accepted');
  aEqual('Discontinued': err.field);
end-proc;

//------------------------------------------------------------------------------
dcl-proc test_listPositionTo export;
  dcl-ds r     likeds(Product_t) inz;
  dcl-ds g     likeds(Product_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  found ind;

  r = buildRec();
  assert(Prd_create(r: err): 'Create failed: ' + err.text);
  assert(r.ProductId > 0: 'No identity value returned');
  assert(Prd_openList(r.ProductName: err): 'openList failed: ' + err.text);
  found = Prd_fetchNext(g);
  Prd_closeList();
  assert(found: 'List returned no rows');
  iEqual(r.ProductId: g.ProductId);
end-proc;

