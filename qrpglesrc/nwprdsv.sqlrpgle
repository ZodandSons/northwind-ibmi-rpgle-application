**free
//==============================================================================
// NWPRDSV - Data access service program for PRODUCTS
//
// All SQL for PRODUCTS lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWPRDPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWPRDSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWPRDSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWPRDPR

// Host variables for the list cursor
dcl-s  gPos like(Product_t.ProductName);
dcl-ds gRow likeds(Product_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare PRDLIST cursor for
  select PRODUCTID,
         PRODUCTNAME,
         COALESCE(SUPPLIERID, 0),
         COALESCE(CATEGORYID, 0),
         COALESCE(QUANTITYPERUNIT, ''),
         COALESCE(UNITPRICE, 0),
         COALESCE(UNITSINSTOCK, 0),
         COALESCE(UNITSONORDER, 0),
         COALESCE(REORDERLEVEL, 0),
         DISCONTINUED
    from PRODUCTS
   where UPPER(PRODUCTNAME) >= UPPER(:gPos)
   order by UPPER(PRODUCTNAME), PRODUCTID
   for read only;

//------------------------------------------------------------------------------
// Prd_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Prd_get export;
  dcl-pi *n ind;
    pProductId like(Product_t.ProductId) const;
    rec likeds(Product_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Product_t) inz;

  NwU_clearError(err);

  exec sql
    select PRODUCTID,
           PRODUCTNAME,
           COALESCE(SUPPLIERID, 0),
           COALESCE(CATEGORYID, 0),
           COALESCE(QUANTITYPERUNIT, ''),
           COALESCE(UNITPRICE, 0),
           COALESCE(UNITSINSTOCK, 0),
           COALESCE(UNITSONORDER, 0),
           COALESCE(REORDERLEVEL, 0),
           DISCONTINUED
      into :r
      from PRODUCTS
     where PRODUCTID = :pProductId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'ProductId': 'Product not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve product');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Prd_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Prd_exists export;
  dcl-pi *n ind;
    pProductId like(Product_t.ProductId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from PRODUCTS
            where PRODUCTID = :pProductId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Prd_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Prd_validate export;
  dcl-pi *n ind;
    rec    likeds(Product_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(Product_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    // identity key is assigned by the database
  else;
    if not Prd_exists(v.ProductId);
      return NwU_setError(err: NWE_NOTFOUND: 'ProductId':
                          'Product not found.');
    endif;
  endif;

  // Field checks
  if %len(%trim(v.ProductName)) = 0;
    return NwU_setError(err: NWE_REQUIRED: 'ProductName': 'Product name is required.');
  endif;
  if v.SupplierId <> 0;
    found = 0;
    exec sql select 1 into :found from SUPPLIERS
              where SUPPLIERID = :v.SupplierId fetch first 1 row only;
    if found <> 1;
      return NwU_setError(err: NWE_REFERENCE: 'SupplierId':
                          'Supplier not found.');
    endif;
  endif;
  if v.CategoryId <> 0;
    found = 0;
    exec sql select 1 into :found from CATEGORIES
              where CATEGORYID = :v.CategoryId fetch first 1 row only;
    if found <> 1;
      return NwU_setError(err: NWE_REFERENCE: 'CategoryId':
                          'Category not found.');
    endif;
  endif;
  if v.UnitPrice < 0;
    return NwU_setError(err: NWE_RANGE: 'UnitPrice':
                        'Unit price cannot be less than 0.');
  endif;
  if v.UnitsInStock < 0;
    return NwU_setError(err: NWE_RANGE: 'UnitsInStock':
                        'Units in stock cannot be less than 0.');
  endif;
  if v.UnitsOnOrder < 0;
    return NwU_setError(err: NWE_RANGE: 'UnitsOnOrder':
                        'Units on order cannot be less than 0.');
  endif;
  if v.ReorderLevel < 0;
    return NwU_setError(err: NWE_RANGE: 'ReorderLevel':
                        'Reorder level cannot be less than 0.');
  endif;
  if v.Discontinued <> 0 and v.Discontinued <> 1;
    return NwU_setError(err: NWE_RANGE: 'Discontinued':
                        'Discontinued must be 0 or 1.');
  endif;

  return *on;
end-proc;

//------------------------------------------------------------------------------
// Prd_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Prd_create export;
  dcl-pi *n ind;
    rec likeds(Product_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Product_t) inz;
  dcl-s  newId int(10) inz(0);

  if not Prd_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql select PRODUCTID into :newId
             from final table (
                  insert into PRODUCTS
                    (PRODUCTNAME, SUPPLIERID, CATEGORYID, QUANTITYPERUNIT, UNITPRICE,
                     UNITSINSTOCK, UNITSONORDER, REORDERLEVEL, DISCONTINUED)
                    values(:r.ProductName, NULLIF(:r.SupplierId, 0), NULLIF(:r.CategoryId, 0),
                           NULLIF(:r.QuantityPerUnit, ''), :r.UnitPrice, :r.UnitsInStock,
                           :r.UnitsOnOrder, :r.ReorderLevel, :r.Discontinued));

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create product');
  endif;
  rec.ProductId = newId;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Prd_update - validate and update all non-key columns
//------------------------------------------------------------------------------
dcl-proc Prd_update export;
  dcl-pi *n ind;
    rec likeds(Product_t) const;
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(Product_t) inz;

  if not Prd_validate(rec: ACTION_UPDATE: err);
    return *off;
  endif;
  r = rec;

  exec sql update PRODUCTS
              set PRODUCTNAME = :r.ProductName,
                  SUPPLIERID = NULLIF(:r.SupplierId, 0),
                  CATEGORYID = NULLIF(:r.CategoryId, 0),
                  QUANTITYPERUNIT = NULLIF(:r.QuantityPerUnit, ''),
                  UNITPRICE = :r.UnitPrice,
                  UNITSINSTOCK = :r.UnitsInStock,
                  UNITSONORDER = :r.UnitsOnOrder,
                  REORDERLEVEL = :r.ReorderLevel,
                  DISCONTINUED = :r.Discontinued
            where PRODUCTID = :r.ProductId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'ProductId': 'Product not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Update product');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Prd_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Prd_delete export;
  dcl-pi *n ind;
    pProductId like(Product_t.ProductId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from PRODUCTS
            where PRODUCTID = :pProductId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'ProductId': 'Product not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete product');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Prd_openList - open list cursor at a starting position
//   Ordered by UPPER(PRODUCTNAME), PRODUCTID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Prd_openList export;
  dcl-pi *n ind;
    positionTo like(Product_t.ProductName) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close PRDLIST;                      // ignore "not open"

  gPos = %trimr(positionTo);

  exec sql open PRDLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open product list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Prd_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Prd_fetchNext export;
  dcl-pi *n ind;
    rec likeds(Product_t);
  end-pi;

  exec sql fetch next from PRDLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Prd_closeList
//------------------------------------------------------------------------------
dcl-proc Prd_closeList export;
  exec sql close PRDLIST;
end-proc;

//------------------------------------------------------------------------------
// Prd_SupplierIdDesc - description of the supplier
//------------------------------------------------------------------------------
dcl-proc Prd_SupplierIdDesc export;
  dcl-pi *n varchar(50);
    value like(Product_t.SupplierId) const;
  end-pi;

  dcl-s v    like(Product_t.SupplierId);
  dcl-s desc varchar(50) inz('');

  v = value;
  if v = 0;
    return '';
  endif;
  exec sql select CAST(COMPANYNAME AS VARCHAR(50)) into :desc
             from SUPPLIERS
            where SUPPLIERID = :v
            fetch first 1 row only;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return '';
  endif;
  return %trimr(desc);
end-proc;

//------------------------------------------------------------------------------
// Prd_CategoryIdDesc - description of the category
//------------------------------------------------------------------------------
dcl-proc Prd_CategoryIdDesc export;
  dcl-pi *n varchar(50);
    value like(Product_t.CategoryId) const;
  end-pi;

  dcl-s v    like(Product_t.CategoryId);
  dcl-s desc varchar(50) inz('');

  v = value;
  if v = 0;
    return '';
  endif;
  exec sql select CAST(CATEGORYNAME AS VARCHAR(50)) into :desc
             from CATEGORIES
            where CATEGORYID = :v
            fetch first 1 row only;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return '';
  endif;
  return %trimr(desc);
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
