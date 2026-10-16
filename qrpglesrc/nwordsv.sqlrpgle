**free
//==============================================================================
// NWORDSV - Order service program (ORDERS, ORDERDETAILS)
//
// Business rules and SQL for Order Entry (ORDENT) and Order Inquiry (WRKORD).
// Order creation and deletion run under commitment control: the header and
// all lines are written in one unit of work (COMMIT on success, ROLLBACK on
// any failure). The NORTHWIND tables are journaled to QSQJRN by CREATE SCHEMA.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWORDSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWORDSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *chg, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWORDPR

// Host variables for the cursors
dcl-s  gOrderId  int(10);
dcl-s  gCust     char(5);
dcl-s  gFrom     date inz(NW_NULL_DATE);
dcl-s  gTo       date inz(NW_NULL_DATE);
dcl-s  gOpen     char(1);
dcl-s  gStart    int(10);
dcl-ds gLine     likeds(OrderLine_t) inz;
dcl-ds gRow      likeds(OrderSummary_t) inz;

// Lines of one order (WITH HOLD so a COMMIT elsewhere does not close it)
exec sql declare ORDLINES cursor with hold for
  select d.ORDERID,
         d.PRODUCTID,
         d.UNITPRICE,
         d.QUANTITY,
         d.DISCOUNT,
         COALESCE(p.PRODUCTNAME, ''),
         DEC(ROUND(d.UNITPRICE * d.QUANTITY * (1 - d.DISCOUNT), 2), 19, 4)
    from ORDERDETAILS d
    left join PRODUCTS p on p.PRODUCTID = d.PRODUCTID
   where d.ORDERID = :gOrderId
   order by d.PRODUCTID
   for read only;

// Order inquiry list, newest first
exec sql declare ORDLIST cursor with hold for
  select o.ORDERID,
         COALESCE(o.CUSTOMERID, ''),
         COALESCE(c.COMPANYNAME, ''),
         COALESCE(o.EMPLOYEEID, 0),
         COALESCE(o.ORDERDATE, DATE('0001-01-01')),
         COALESCE(o.REQUIREDDATE, DATE('0001-01-01')),
         COALESCE(o.SHIPPEDDATE, DATE('0001-01-01')),
         COALESCE(o.FREIGHT, 0),
         COALESCE((select SUM(DEC(ROUND(d.UNITPRICE * d.QUANTITY * (1 - d.DISCOUNT), 2), 19, 4))
                     from ORDERDETAILS d
                    where d.ORDERID = o.ORDERID), 0)
    from ORDERS o
    left join CUSTOMERS c on c.CUSTOMERID = o.CUSTOMERID
   where (:gCust = ' ' or o.CUSTOMERID = :gCust)
     and (:gFrom = DATE('0001-01-01') or o.ORDERDATE >= :gFrom)
     and (:gTo = DATE('0001-01-01') or o.ORDERDATE <= :gTo)
     and (:gOpen = '0' or o.SHIPPEDDATE is null)
     and (:gStart = 0 or o.ORDERID <= :gStart)
   order by o.ORDERID desc
   for read only;

//------------------------------------------------------------------------------
// Ord_calcExtPrice - price * quantity * (1 - discount), rounded to cents
//------------------------------------------------------------------------------
dcl-proc Ord_calcExtPrice export;
  dcl-pi *n packed(19:4);
    unitPrice packed(19:4) const;
    quantity  int(5) const;
    discount  float(4) const;
  end-pi;

  return %dech(unitPrice * quantity * (1 - discount): 17: 2);
end-proc;

//------------------------------------------------------------------------------
// Ord_defaultShipTo - copy name and address of the customer to the ship-to
//------------------------------------------------------------------------------
dcl-proc Ord_defaultShipTo export;
  dcl-pi *n ind;
    customerId char(5) const;
    hdr        likeds(OrderHeader_t);
    err        likeds(NwError_t);
  end-pi;

  dcl-ds r    likeds(OrderHeader_t) inz;
  dcl-s  cust char(5);

  NwU_clearError(err);
  r    = hdr;
  cust = customerId;

  exec sql
    select COMPANYNAME,
           COALESCE(ADDRESS, ''),
           COALESCE(CITY, ''),
           COALESCE(REGION, ''),
           COALESCE(POSTALCODE, ''),
           COALESCE(COUNTRY, '')
      into :r.ShipName, :r.ShipAddress, :r.ShipCity, :r.ShipRegion,
           :r.ShipPostalCode, :r.ShipCountry
      from CUSTOMERS
     where CUSTOMERID = :cust;

  if sqlcode = 100;
    return NwU_setError(err: NWE_REFERENCE: 'CustomerId': 'Customer not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve customer address');
  endif;

  hdr = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ord_validateHeader - rules for a new order header
//------------------------------------------------------------------------------
dcl-proc Ord_validateHeader export;
  dcl-pi *n ind;
    hdr likeds(OrderHeader_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds v     likeds(OrderHeader_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = hdr;

  if v.CustomerId = *blanks;
    return NwU_setError(err: NWE_REQUIRED: 'CustomerId': 'Customer is required.');
  endif;
  found = 0;
  exec sql select 1 into :found from CUSTOMERS
            where CUSTOMERID = :v.CustomerId fetch first 1 row only;
  if found <> 1;
    return NwU_setError(err: NWE_REFERENCE: 'CustomerId': 'Customer not found.');
  endif;

  if v.EmployeeId = 0;
    return NwU_setError(err: NWE_REQUIRED: 'EmployeeId': 'Employee is required.');
  endif;
  found = 0;
  exec sql select 1 into :found from EMPLOYEES
            where EMPLOYEEID = :v.EmployeeId fetch first 1 row only;
  if found <> 1;
    return NwU_setError(err: NWE_REFERENCE: 'EmployeeId': 'Employee not found.');
  endif;

  if v.OrderDate = NW_NULL_DATE;
    return NwU_setError(err: NWE_REQUIRED: 'OrderDate': 'Order date is required.');
  endif;
  if v.RequiredDate <> NW_NULL_DATE and v.RequiredDate < v.OrderDate;
    return NwU_setError(err: NWE_RANGE: 'RequiredDate':
                        'Required date cannot be before the order date.');
  endif;
  if v.ShippedDate <> NW_NULL_DATE and v.ShippedDate < v.OrderDate;
    return NwU_setError(err: NWE_RANGE: 'ShippedDate':
                        'Shipped date cannot be before the order date.');
  endif;

  if v.ShipVia = 0;
    return NwU_setError(err: NWE_REQUIRED: 'ShipVia': 'Ship via is required.');
  endif;
  found = 0;
  exec sql select 1 into :found from SHIPPERS
            where SHIPPERID = :v.ShipVia fetch first 1 row only;
  if found <> 1;
    return NwU_setError(err: NWE_REFERENCE: 'ShipVia': 'Shipper not found.');
  endif;

  if v.Freight < 0;
    return NwU_setError(err: NWE_RANGE: 'Freight': 'Freight cannot be negative.');
  endif;
  if %len(%trim(v.ShipName)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'ShipName': 'Ship-to name is required.');
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ord_validateLine - rules for one order line
//------------------------------------------------------------------------------
dcl-proc Ord_validateLine export;
  dcl-pi *n ind;
    line likeds(OrderLine_t) const;
    err  likeds(NwError_t);
  end-pi;

  dcl-s prodId int(10);
  dcl-s disc   int(5);

  NwU_clearError(err);

  if line.ProductId = 0;
    return NwU_setError(err: NWE_REQUIRED: 'ProductId': 'Product is required.');
  endif;
  prodId = line.ProductId;
  exec sql select DISCONTINUED into :disc from PRODUCTS where PRODUCTID = :prodId;
  if sqlcode = 100;
    return NwU_setError(err: NWE_REFERENCE: 'ProductId': 'Product not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve product');
  endif;
  if disc <> 0;
    return NwU_setError(err: NWE_INVALID: 'ProductId':
                        'Product is discontinued and cannot be ordered.');
  endif;

  if line.UnitPrice < 0;
    return NwU_setError(err: NWE_RANGE: 'UnitPrice': 'Unit price cannot be negative.');
  endif;
  if line.Quantity <= 0;
    return NwU_setError(err: NWE_RANGE: 'Quantity': 'Quantity must be greater than zero.');
  endif;
  if line.Discount < 0 or line.Discount > 1;
    return NwU_setError(err: NWE_RANGE: 'Discount':
                        'Discount must be between 0 and 100 percent.');
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ord_create - insert header and lines in one unit of work
//------------------------------------------------------------------------------
dcl-proc Ord_create export;
  dcl-pi *n ind;
    hdr       likeds(OrderHeader_t);
    lines     likeds(OrderLine_t) dim(ORD_MAX_LINES) const;
    lineCount int(10) const;
    err       likeds(NwError_t);
  end-pi;

  dcl-ds r     likeds(OrderHeader_t) inz;
  dcl-ds ln    likeds(OrderLine_t) inz;
  dcl-s  newId int(10) inz(0);
  dcl-s  i     int(10);
  dcl-s  j     int(10);

  NwU_clearError(err);

  if lineCount < 1;
    return NwU_setError(err: NWE_REQUIRED: 'ProductId':
                        'An order needs at least one line.');
  endif;
  if lineCount > ORD_MAX_LINES;
    return NwU_setError(err: NWE_RANGE: 'ProductId':
                        'An order can have at most ' + %char(ORD_MAX_LINES) + ' lines.');
  endif;

  if not Ord_validateHeader(hdr: err);
    return *off;
  endif;

  for i = 1 to lineCount;
    if not Ord_validateLine(lines(i): err);
      err.text = 'Line ' + %char(i) + ': ' + err.text;
      return *off;
    endif;
    for j = 1 to i - 1;
      if lines(j).ProductId = lines(i).ProductId;
        return NwU_setError(err: NWE_DUPLICATE: 'ProductId':
                            'Line ' + %char(i) + ': product is already on line '
                            + %char(j) + '.');
      endif;
    endfor;
  endfor;

  r = hdr;
  exec sql select ORDERID into :newId
             from final table (
                  insert into ORDERS
                    (CUSTOMERID, EMPLOYEEID, ORDERDATE, REQUIREDDATE, SHIPPEDDATE,
                     SHIPVIA, FREIGHT, SHIPNAME, SHIPADDRESS, SHIPCITY, SHIPREGION,
                     SHIPPOSTALCODE, SHIPCOUNTRY)
                    values(:r.CustomerId,
                           NULLIF(:r.EmployeeId, 0),
                           NULLIF(:r.OrderDate, DATE('0001-01-01')),
                           NULLIF(:r.RequiredDate, DATE('0001-01-01')),
                           NULLIF(:r.ShippedDate, DATE('0001-01-01')),
                           NULLIF(:r.ShipVia, 0),
                           :r.Freight,
                           NULLIF(:r.ShipName, ''),
                           NULLIF(:r.ShipAddress, ''),
                           NULLIF(:r.ShipCity, ''),
                           NULLIF(:r.ShipRegion, ''),
                           NULLIF(:r.ShipPostalCode, ''),
                           NULLIF(:r.ShipCountry, '')));
  if not NwU_sqlOk(sqlstate);
    return failAndRollback(err: 'Create order');
  endif;

  for i = 1 to lineCount;
    ln = lines(i);
    exec sql insert into ORDERDETAILS
                    (ORDERID, PRODUCTID, UNITPRICE, QUANTITY, DISCOUNT)
               values(:newId, :ln.ProductId, :ln.UnitPrice, :ln.Quantity, :ln.Discount);
    if not NwU_sqlOk(sqlstate);
      failAndRollback(err: 'Create order line ' + %char(i));
      err.text = 'Line ' + %char(i) + ': ' + err.text;
      return *off;
    endif;
  endfor;

  exec sql commit;
  if not NwU_sqlOk(sqlstate);
    return failAndRollback(err: 'Commit order');
  endif;

  hdr.OrderId = newId;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ord_get - retrieve an order header
//------------------------------------------------------------------------------
dcl-proc Ord_get export;
  dcl-pi *n ind;
    orderId int(10) const;
    hdr     likeds(OrderHeader_t);
    err     likeds(NwError_t);
  end-pi;

  dcl-ds r  likeds(OrderHeader_t) inz;
  dcl-s  id int(10);

  NwU_clearError(err);
  id = orderId;

  exec sql
    select ORDERID,
           COALESCE(CUSTOMERID, ''),
           COALESCE(EMPLOYEEID, 0),
           COALESCE(ORDERDATE, DATE('0001-01-01')),
           COALESCE(REQUIREDDATE, DATE('0001-01-01')),
           COALESCE(SHIPPEDDATE, DATE('0001-01-01')),
           COALESCE(SHIPVIA, 0),
           COALESCE(FREIGHT, 0),
           COALESCE(SHIPNAME, ''),
           COALESCE(SHIPADDRESS, ''),
           COALESCE(SHIPCITY, ''),
           COALESCE(SHIPREGION, ''),
           COALESCE(SHIPPOSTALCODE, ''),
           COALESCE(SHIPCOUNTRY, '')
      into :r
      from ORDERS
     where ORDERID = :id;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'OrderId': 'Order not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve order');
  endif;

  hdr = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ord_delete - delete an unshipped order (lines first, then header)
//------------------------------------------------------------------------------
dcl-proc Ord_delete export;
  dcl-pi *n ind;
    orderId int(10) const;
    err     likeds(NwError_t);
  end-pi;

  dcl-ds hdr likeds(OrderHeader_t) inz;
  dcl-s  id  int(10);

  if not Ord_get(orderId: hdr: err);
    return *off;
  endif;
  if hdr.ShippedDate <> NW_NULL_DATE;
    return NwU_setError(err: NWE_INVALID: 'OrderId':
                        'Order has shipped and cannot be deleted.');
  endif;

  id = orderId;
  exec sql delete from ORDERDETAILS where ORDERID = :id;
  if sqlcode <> 100 and not NwU_sqlOk(sqlstate);
    return failAndRollback(err: 'Delete order lines');
  endif;
  exec sql delete from ORDERS where ORDERID = :id;
  if not NwU_sqlOk(sqlstate);
    return failAndRollback(err: 'Delete order');
  endif;
  exec sql commit;
  if not NwU_sqlOk(sqlstate);
    return failAndRollback(err: 'Commit delete');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Ord_subTotal - sum of the extended prices of the order lines
//------------------------------------------------------------------------------
dcl-proc Ord_subTotal export;
  dcl-pi *n packed(19:4);
    orderId int(10) const;
  end-pi;

  dcl-s id    int(10);
  dcl-s total packed(19:4) inz(0);

  id = orderId;
  exec sql
    select COALESCE(SUM(DEC(ROUND(UNITPRICE * QUANTITY * (1 - DISCOUNT), 2), 19, 4)), 0)
      into :total
      from ORDERDETAILS
     where ORDERID = :id;
  if not NwU_sqlOk(sqlstate);
    total = 0;
  endif;
  return total;
end-proc;

//------------------------------------------------------------------------------
// Ord_openLines / Ord_fetchLine / Ord_closeLines
//------------------------------------------------------------------------------
dcl-proc Ord_openLines export;
  dcl-pi *n ind;
    orderId int(10) const;
    err     likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close ORDLINES;
  gOrderId = orderId;
  exec sql open ORDLINES;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open order lines');
  endif;
  return *on;
end-proc;

dcl-proc Ord_fetchLine export;
  dcl-pi *n ind;
    line likeds(OrderLine_t);
  end-pi;

  exec sql fetch next from ORDLINES into :gLine;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  line = gLine;
  return *on;
end-proc;

dcl-proc Ord_closeLines export;
  exec sql close ORDLINES;
end-proc;

//------------------------------------------------------------------------------
// Ord_openList / Ord_fetchList / Ord_closeList - order inquiry
//------------------------------------------------------------------------------
dcl-proc Ord_openList export;
  dcl-pi *n ind;
    filter likeds(OrderFilter_t) const;
    err    likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close ORDLIST;

  gCust  = filter.CustomerId;
  gFrom  = filter.FromDate;
  gTo    = filter.ToDate;
  gStart = filter.StartOrderId;
  if filter.OpenOnly;
    gOpen = '1';
  else;
    gOpen = '0';
  endif;

  exec sql open ORDLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open order list');
  endif;
  return *on;
end-proc;

dcl-proc Ord_fetchList export;
  dcl-pi *n ind;
    row likeds(OrderSummary_t);
  end-pi;

  exec sql fetch next from ORDLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  row = gRow;
  return *on;
end-proc;

dcl-proc Ord_closeList export;
  exec sql close ORDLIST;
end-proc;

//------------------------------------------------------------------------------
// Name lookups for panels
//------------------------------------------------------------------------------
dcl-proc Ord_customerName export;
  dcl-pi *n varchar(40);
    customerId char(5) const;
  end-pi;

  dcl-s id   char(5);
  dcl-s name varchar(40) inz('');

  id = customerId;
  if id = *blanks;
    return '';
  endif;
  exec sql select COMPANYNAME into :name from CUSTOMERS where CUSTOMERID = :id;
  if sqlcode <> 0 and not NwU_sqlOk(sqlstate);
    return '';
  endif;
  return name;
end-proc;

dcl-proc Ord_employeeName export;
  dcl-pi *n varchar(40);
    employeeId int(10) const;
  end-pi;

  dcl-s id   int(10);
  dcl-s name varchar(40) inz('');

  id = employeeId;
  if id = 0;
    return '';
  endif;
  exec sql select CAST(TRIM(FIRSTNAME) || ' ' || TRIM(LASTNAME) AS VARCHAR(40))
             into :name from EMPLOYEES where EMPLOYEEID = :id;
  if sqlcode <> 0 and not NwU_sqlOk(sqlstate);
    return '';
  endif;
  return name;
end-proc;

dcl-proc Ord_shipperName export;
  dcl-pi *n varchar(40);
    shipperId int(10) const;
  end-pi;

  dcl-s id   int(10);
  dcl-s name varchar(40) inz('');

  id = shipperId;
  if id = 0;
    return '';
  endif;
  exec sql select COMPANYNAME into :name from SHIPPERS where SHIPPERID = :id;
  if sqlcode <> 0 and not NwU_sqlOk(sqlstate);
    return '';
  endif;
  return name;
end-proc;

//------------------------------------------------------------------------------
// sqlFail - capture diagnostics for the last statement (internal)
//------------------------------------------------------------------------------
dcl-proc sqlFail;
  dcl-pi *n ind;
    err     likeds(NwError_t);
    context varchar(60) const;
  end-pi;

  dcl-s state   char(5);
  dcl-s code    int(10);
  dcl-s msgText varchar(512) inz('');

  state = sqlstate;
  code  = sqlcode;
  exec sql get diagnostics condition 1 :msgText = MESSAGE_TEXT;
  return NwU_sqlError(err: state: code: msgText: context);
end-proc;

//------------------------------------------------------------------------------
// failAndRollback - capture diagnostics, then roll back the unit of work
//------------------------------------------------------------------------------
dcl-proc failAndRollback;
  dcl-pi *n ind;
    err     likeds(NwError_t);
    context varchar(60) const;
  end-pi;

  sqlFail(err: context);
  exec sql rollback;
  return *off;
end-proc;
