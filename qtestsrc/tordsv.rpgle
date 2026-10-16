**free
//==============================================================================
// TORDSV - iRPGUnit tests for service program NWORDSV (orders)
//
// Build: RUCRTRPG TSTPGM(NWAPP/TORDSV) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWORDSV) (NWAPP/NWUTIL) (NWAPP/NWTSTSV))
// Run:   RUCALLTST TSTPGM(NWAPP/TORDSV)
//
// Test orders are marked with ship-to name 'ZZZZ UNIT TEST' and removed
// before and after every test. They use existing master data:
// customer ALFKI, employee 1, shipper 1, products 1 and 2, and
// discontinued product 5.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWTSTPR
/copy QCPYSRC,NWORDPR

dcl-c TEST_SHIPNAME 'ZZZZ UNIT TEST';

//------------------------------------------------------------------------------
// Fixtures
//------------------------------------------------------------------------------
dcl-proc setUpSuite export;
  removeTestOrders();
end-proc;

dcl-proc tearDownSuite export;
  removeTestOrders();
end-proc;

dcl-proc setUp export;
  removeTestOrders();
end-proc;

dcl-proc tearDown export;
  removeTestOrders();
end-proc;

dcl-proc removeTestOrders;
  Tst_exec('delete from ORDERDETAILS where ORDERID in ' +
           '(select ORDERID from ORDERS where SHIPNAME = ''ZZZZ UNIT TEST'')');
  Tst_exec('delete from ORDERS where SHIPNAME = ''ZZZZ UNIT TEST''');
end-proc;

dcl-proc countTestOrders;
  dcl-pi *n int(10);
  end-pi;
  return Tst_count('select count(*) from ORDERS where SHIPNAME = ''ZZZZ UNIT TEST''');
end-proc;

// A valid order header
dcl-proc buildHeader;
  dcl-pi *n likeds(OrderHeader_t);
  end-pi;
  dcl-ds h likeds(OrderHeader_t) inz;

  h.CustomerId     = 'ALFKI';
  h.EmployeeId     = 1;
  h.OrderDate      = d'2026-01-15';
  h.RequiredDate   = d'2026-01-29';
  h.ShippedDate    = NW_NULL_DATE;
  h.ShipVia        = 1;
  h.Freight        = 10.50;
  h.ShipName       = TEST_SHIPNAME;
  h.ShipAddress    = 'Obere Str. 57';
  h.ShipCity       = 'Berlin';
  h.ShipPostalCode = '12209';
  h.ShipCountry    = 'Germany';
  return h;
end-proc;

// Two valid lines: 2 x product 1 @ 18.00, 3 x product 2 @ 19.00 less 10 %
dcl-proc buildLines;
  dcl-pi *n int(10);
    lines likeds(OrderLine_t) dim(ORD_MAX_LINES);
  end-pi;

  clear lines;
  lines(1).ProductId = 1;
  lines(1).UnitPrice = 18.00;
  lines(1).Quantity  = 2;
  lines(1).Discount  = 0;
  lines(2).ProductId = 2;
  lines(2).UnitPrice = 19.00;
  lines(2).Quantity  = 3;
  lines(2).Discount  = 0.10;
  return 2;
end-proc;

//------------------------------------------------------------------------------
// Pricing
//------------------------------------------------------------------------------
dcl-proc test_calcExtPrice export;
  assert(Ord_calcExtPrice(18.00: 2: 0) = 36.00: '18.00 x 2 should be 36.00');
  assert(Ord_calcExtPrice(19.00: 3: 0.10) = 51.30: '19.00 x 3 less 10% should be 51.30');
  assert(Ord_calcExtPrice(14.00: 12: 0.05) = 159.60: '14.00 x 12 less 5% should be 159.60');
  assert(Ord_calcExtPrice(9.65: 1: 1) = 0: '100% discount should be 0');
end-proc;

//------------------------------------------------------------------------------
// Create / read / delete
//------------------------------------------------------------------------------
dcl-proc test_createOrder export;
  dcl-ds h     likeds(OrderHeader_t) inz;
  dcl-ds g     likeds(OrderHeader_t) inz;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds ln    likeds(OrderLine_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  n     int(10);
  dcl-s  count int(10) inz(0);

  h = buildHeader();
  n = buildLines(lines);
  assert(Ord_create(h: lines: n: err): 'Create failed: ' + err.text);
  assert(h.OrderId > 0: 'No order number returned');

  assert(Ord_get(h.OrderId: g: err): 'Get failed: ' + err.text);
  aEqual('ALFKI': g.CustomerId);
  iEqual(1: g.EmployeeId);
  iEqual(1: g.ShipVia);
  assert(g.OrderDate = d'2026-01-15': 'Order date not stored');
  assert(g.ShippedDate = NW_NULL_DATE: 'New order should not be shipped');
  assert(g.Freight = 10.50: 'Freight not stored');
  aEqual(TEST_SHIPNAME: g.ShipName);

  assert(Ord_openLines(h.OrderId: err): 'openLines failed: ' + err.text);
  dow Ord_fetchLine(ln);
    count += 1;
    if ln.ProductId = 2;
      iEqual(3: ln.Quantity);
      assert(ln.ExtPrice = 51.30: 'Extended price of line 2 should be 51.30');
    endif;
  enddo;
  Ord_closeLines();
  iEqual(2: count);

  assert(Ord_subTotal(h.OrderId) = 87.30: 'Subtotal should be 87.30');
end-proc;

dcl-proc test_deleteOrder export;
  dcl-ds h     likeds(OrderHeader_t) inz;
  dcl-ds g     likeds(OrderHeader_t) inz;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  n     int(10);

  h = buildHeader();
  n = buildLines(lines);
  assert(Ord_create(h: lines: n: err): 'Create failed: ' + err.text);
  assert(Ord_delete(h.OrderId: err): 'Delete failed: ' + err.text);
  assert(not Ord_get(h.OrderId: g: err): 'Order still exists after delete');
  aEqual(NWE_NOTFOUND: err.code);
  iEqual(0: Tst_count('select count(*) from ORDERDETAILS where ORDERID = '
                      + %char(h.OrderId)));
end-proc;

dcl-proc test_deleteShippedOrderRejected export;
  dcl-ds h     likeds(OrderHeader_t) inz;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  n     int(10);

  h = buildHeader();
  n = buildLines(lines);
  assert(Ord_create(h: lines: n: err): 'Create failed: ' + err.text);
  assert(Tst_exec('update ORDERS set SHIPPEDDATE = ORDERDATE where ORDERID = '
                  + %char(h.OrderId)): 'Could not mark order shipped');
  assert(not Ord_delete(h.OrderId: err): 'Shipped order was deleted');
  aEqual(NWE_INVALID: err.code);
end-proc;

dcl-proc test_deleteMissingOrder export;
  dcl-ds err likeds(NwError_t) inz;

  assert(not Ord_delete(-1: err): 'Delete of a missing order succeeded');
  aEqual(NWE_NOTFOUND: err.code);
end-proc;

//------------------------------------------------------------------------------
// Transaction rules
//------------------------------------------------------------------------------
dcl-proc test_createRequiresLines export;
  dcl-ds h     likeds(OrderHeader_t) inz;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;

  h = buildHeader();
  assert(not Ord_create(h: lines: 0: err): 'Order without lines accepted');
  aEqual(NWE_REQUIRED: err.code);
  iEqual(0: countTestOrders());
end-proc;

dcl-proc test_createRejectsDuplicateProduct export;
  dcl-ds h     likeds(OrderHeader_t) inz;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  n     int(10);

  h = buildHeader();
  n = buildLines(lines);
  lines(2).ProductId = lines(1).ProductId;
  assert(not Ord_create(h: lines: n: err): 'Duplicate product accepted');
  aEqual(NWE_DUPLICATE: err.code);
  iEqual(0: countTestOrders());
end-proc;

dcl-proc test_badLineWritesNothing export;
  dcl-ds h     likeds(OrderHeader_t) inz;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  n     int(10);

  h = buildHeader();
  n = buildLines(lines);
  lines(2).Quantity = 0;
  assert(not Ord_create(h: lines: n: err): 'Order with a bad line accepted');
  aEqual('Quantity': err.field);
  iEqual(0: countTestOrders());
end-proc;

//------------------------------------------------------------------------------
// Header validation
//------------------------------------------------------------------------------
dcl-proc test_headerValid export;
  dcl-ds err likeds(NwError_t) inz;
  assert(Ord_validateHeader(buildHeader(): err): 'Valid header rejected: ' + err.text);
end-proc;

dcl-proc test_headerMissingCustomer export;
  dcl-ds h   likeds(OrderHeader_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  h = buildHeader();
  h.CustomerId = *blanks;
  assert(not Ord_validateHeader(h: err): 'Missing customer accepted');
  aEqual('CustomerId': err.field);
  aEqual(NWE_REQUIRED: err.code);
end-proc;

dcl-proc test_headerUnknownCustomer export;
  dcl-ds h   likeds(OrderHeader_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  h = buildHeader();
  h.CustomerId = 'ZZNOP';
  assert(not Ord_validateHeader(h: err): 'Unknown customer accepted');
  aEqual('CustomerId': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

dcl-proc test_headerUnknownEmployee export;
  dcl-ds h   likeds(OrderHeader_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  h = buildHeader();
  h.EmployeeId = 999999;
  assert(not Ord_validateHeader(h: err): 'Unknown employee accepted');
  aEqual('EmployeeId': err.field);
end-proc;

dcl-proc test_headerUnknownShipper export;
  dcl-ds h   likeds(OrderHeader_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  h = buildHeader();
  h.ShipVia = 999999;
  assert(not Ord_validateHeader(h: err): 'Unknown shipper accepted');
  aEqual('ShipVia': err.field);
end-proc;

dcl-proc test_headerRequiredBeforeOrderDate export;
  dcl-ds h   likeds(OrderHeader_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  h = buildHeader();
  h.RequiredDate = h.OrderDate - %days(1);
  assert(not Ord_validateHeader(h: err): 'Required date before order date accepted');
  aEqual('RequiredDate': err.field);
end-proc;

dcl-proc test_headerNegativeFreight export;
  dcl-ds h   likeds(OrderHeader_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  h = buildHeader();
  h.Freight = -1;
  assert(not Ord_validateHeader(h: err): 'Negative freight accepted');
  aEqual('Freight': err.field);
end-proc;

dcl-proc test_headerMissingShipName export;
  dcl-ds h   likeds(OrderHeader_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  h = buildHeader();
  h.ShipName = '';
  assert(not Ord_validateHeader(h: err): 'Missing ship-to name accepted');
  aEqual('ShipName': err.field);
end-proc;

//------------------------------------------------------------------------------
// Line validation
//------------------------------------------------------------------------------
dcl-proc test_lineValid export;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;

  buildLines(lines);
  assert(Ord_validateLine(lines(1): err): 'Valid line rejected: ' + err.text);
end-proc;

dcl-proc test_lineUnknownProduct export;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;

  buildLines(lines);
  lines(1).ProductId = 999999;
  assert(not Ord_validateLine(lines(1): err): 'Unknown product accepted');
  aEqual('ProductId': err.field);
  aEqual(NWE_REFERENCE: err.code);
end-proc;

dcl-proc test_lineDiscontinuedProduct export;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;

  buildLines(lines);
  lines(1).ProductId = 5;                 // Chef Anton's Gumbo Mix (discontinued)
  assert(not Ord_validateLine(lines(1): err): 'Discontinued product accepted');
  aEqual('ProductId': err.field);
  aEqual(NWE_INVALID: err.code);
end-proc;

dcl-proc test_lineZeroQuantity export;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;

  buildLines(lines);
  lines(1).Quantity = 0;
  assert(not Ord_validateLine(lines(1): err): 'Zero quantity accepted');
  aEqual('Quantity': err.field);
end-proc;

dcl-proc test_lineDiscountOver100 export;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;

  buildLines(lines);
  lines(1).Discount = 1.5;
  assert(not Ord_validateLine(lines(1): err): 'Discount over 100% accepted');
  aEqual('Discount': err.field);
end-proc;

dcl-proc test_lineNegativePrice export;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds err   likeds(NwError_t) inz;

  buildLines(lines);
  lines(1).UnitPrice = -1;
  assert(not Ord_validateLine(lines(1): err): 'Negative price accepted');
  aEqual('UnitPrice': err.field);
end-proc;

//------------------------------------------------------------------------------
// Defaults, lookups and the inquiry list
//------------------------------------------------------------------------------
dcl-proc test_defaultShipTo export;
  dcl-ds h   likeds(OrderHeader_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  assert(Ord_defaultShipTo('ALFKI': h: err): 'defaultShipTo failed: ' + err.text);
  aEqual('Alfreds Futterkiste': h.ShipName);
  aEqual('Berlin': h.ShipCity);
  aEqual('Germany': h.ShipCountry);
  assert(not Ord_defaultShipTo('ZZNOP': h: err): 'Unknown customer accepted');
end-proc;

dcl-proc test_names export;
  aEqual('Alfreds Futterkiste': Ord_customerName('ALFKI'));
  aEqual('Nancy Davolio': Ord_employeeName(1));
  aEqual('Speedy Express': Ord_shipperName(1));
  aEqual('': Ord_customerName('ZZNOP'));
  aEqual('': Ord_employeeName(0));
end-proc;

dcl-proc test_listOpenOrdersForCustomer export;
  dcl-ds h     likeds(OrderHeader_t) inz;
  dcl-ds lines likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
  dcl-ds f     likeds(OrderFilter_t) inz;
  dcl-ds row   likeds(OrderSummary_t) inz;
  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  n     int(10);
  dcl-s  found ind;

  h = buildHeader();
  n = buildLines(lines);
  assert(Ord_create(h: lines: n: err): 'Create failed: ' + err.text);

  f.CustomerId   = 'ALFKI';
  f.FromDate     = NW_NULL_DATE;
  f.ToDate       = NW_NULL_DATE;
  f.OpenOnly     = *on;
  f.StartOrderId = 0;
  assert(Ord_openList(f: err): 'openList failed: ' + err.text);
  found = Ord_fetchList(row);
  Ord_closeList();

  assert(found: 'List returned no rows');
  iEqual(h.OrderId: row.OrderId);              // newest first
  aEqual('Alfreds Futterkiste': row.CompanyName);
  assert(row.SubTotal = 87.30: 'List subtotal should be 87.30');
  assert(row.ShippedDate = NW_NULL_DATE: 'Open-only list returned a shipped order');
end-proc;
