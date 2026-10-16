**free
//==============================================================================
// ORDENT - Order Entry
//
// Panel 1 (HDR)    : customer, employee, dates, ship via, freight, ship-to.
//                    Ship-to defaults from the customer (automatically when
//                    the customer changes, or F5). F4 prompts Customer,
//                    Employee and Ship via.
// Panel 2 (ENTCTL) : up to 50 order lines. Enter prices the order (product
//                    name/price defaulted, extended price and totals shown);
//                    F4 prompts products; F10 submits; F12 returns to header.
//
// The order is written by NWORDSV as one unit of work (commit / rollback).
//==============================================================================
ctl-opt main(Main) dftactgrp(*no) actgrp('NWAPP') bnddir('NWBNDDIR')
        option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f ORDENTD workstn usropn indds(dspInd)
        sfile(ENTSFL: rrnL) sfile(WINSFL: rrnW);

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWORDPR
/copy QCPYSRC,NWCUSTPR
/copy QCPYSRC,NWEMPPR
/copy QCPYSRC,NWSHPPR
/copy QCPYSRC,NWPRDPR

// Display file indicators (INDARA)
dcl-ds dspInd len(99) qualified;
  kExit     ind pos(3);
  kPrompt   ind pos(4);
  kDefaults ind pos(5);
  kSubmit   ind pos(10);
  kCancel   ind pos(12);
  sflDsp    ind pos(31);
  sflDspCtl ind pos(32);
  sflClr    ind pos(33);
  sflEnd    ind pos(34);
  hdrErr    ind pos(51) dim(12);
  winDsp    ind pos(71);
  winDspCtl ind pos(72);
  winClr    ind pos(73);
  winEnd    ind pos(74);
  lnErr     ind pos(81) dim(4);
end-ds;

// Prompt (F4) lookup kinds
dcl-c LK_CUST 'C';
dcl-c LK_EMP  'E';
dcl-c LK_SHIP 'S';
dcl-c LK_PROD 'P';

dcl-ds gHdr       likeds(OrderHeader_t) inz;
dcl-ds gLines     likeds(OrderLine_t) dim(ORD_MAX_LINES) inz;
dcl-s  gLineCount int(10);
dcl-s  gSubTotal  packed(19:4);
dcl-s  lastCust   char(5);
dcl-s  gExit      ind;
dcl-s  msg        varchar(78) inz('');
dcl-s  rrnL       packed(4:0);
dcl-s  rrnW       packed(4:0);

//------------------------------------------------------------------------------
// Main - header panel <-> lines panel until F3
//------------------------------------------------------------------------------
dcl-proc Main;
  dcl-s step char(1);

  if not %open(ORDENTD);
    open ORDENTD;
  endif;
  gExit = *off;
  msg   = '';
  newOrder();
  step = 'H';

  dow not gExit;
    if step = 'H';
      step = headerPanel();             // L = go to lines, H = stay
    else;
      step = linesPanel();              // H = back, N = order created
      if step = 'N';
        newOrder();
        step = 'H';
      endif;
    endif;
  enddo;

  close ORDENTD;
end-proc;

//------------------------------------------------------------------------------
// newOrder - reset header defaults and the 50 blank lines
//------------------------------------------------------------------------------
dcl-proc newOrder;
  clear gHdr;
  gHdr.OrderDate    = %date();
  gHdr.RequiredDate = %date() + %days(14);
  gHdr.ShippedDate  = NW_NULL_DATE;
  lastCust   = *blanks;
  gLineCount = 0;
  gSubTotal  = 0;
  clear gLines;
  hdrToScreen();

  dspInd.sflDsp    = *off;
  dspInd.sflDspCtl = *off;
  dspInd.sflClr    = *on;
  write ENTCTL;
  dspInd.sflClr = *off;

  clear dspInd.lnErr;
  for rrnL = 1 to ORD_MAX_LINES;
    LLINE   = rrnL;
    LPRDID  = 0;
    LPRDNM  = *blanks;
    LPRICE  = 0;
    LQTY    = 0;
    LDISC   = 0;
    LEXT    = 0;
    LPRVPRD = 0;
    write ENTSFL;
  endfor;
  LRRN = 1;
end-proc;

//------------------------------------------------------------------------------
// headerPanel - returns L (continue to lines) or H (stay on header)
//------------------------------------------------------------------------------
dcl-proc headerPanel;
  dcl-pi *n char(1);
  end-pi;

  dcl-ds err  likeds(NwError_t) inz;
  dcl-s  code varchar(10);

  dow *on;
    HMSG = msg;
    msg  = '';
    exfmt HDR;
    clear dspInd.hdrErr;

    if dspInd.kExit;
      gExit = *on;
      return 'X';
    endif;
    if dspInd.kCancel;
      newOrder();
      msg = 'Order cancelled. Type a new order or press F3 to exit.';
      return 'H';
    endif;

    if dspInd.kPrompt;
      select;
        when HFLD = 'HCUSTID';
          code = prompt(LK_CUST);
          if code <> '';
            HCUSTID = code;
          endif;
        when HFLD = 'HEMPID';
          code = prompt(LK_EMP);
          if code <> '';
            HEMPID = %int(code);
          endif;
        when HFLD = 'HSHPVIA';
          code = prompt(LK_SHIP);
          if code <> '';
            HSHPVIA = %int(code);
          endif;
        other;
          msg = 'F4=Prompt is available on Customer, Employee and Ship via.';
      endsl;
      hdrNames();
      iter;
    endif;

    if not screenToHdr(err);
      showHdrError(err);
      hdrNames();
      iter;
    endif;

    // New customer (or F5): copy the ship-to address and let the user review it
    if dspInd.kDefaults or (gHdr.CustomerId <> lastCust and gHdr.CustomerId <> *blanks);
      if Ord_defaultShipTo(gHdr.CustomerId: gHdr: err);
        lastCust = gHdr.CustomerId;
        hdrToScreen();
        msg = 'Ship-to copied from the customer. Press Enter to continue.';
      else;
        showHdrError(err);
        hdrNames();
      endif;
      iter;
    endif;

    hdrNames();
    if not Ord_validateHeader(gHdr: err);
      showHdrError(err);
      iter;
    endif;
    return 'L';
  enddo;
  return 'H';
end-proc;

//------------------------------------------------------------------------------
// linesPanel - returns H (back to header), N (order created) or X (exit)
//------------------------------------------------------------------------------
dcl-proc linesPanel;
  dcl-pi *n char(1);
  end-pi;

  dcl-s code varchar(10);

  LCUSTID = gHdr.CustomerId;
  LCUSTNM = Ord_customerName(gHdr.CustomerId);
  LORDDT  = NwU_fromDate(gHdr.OrderDate);
  LREQDT  = NwU_fromDate(gHdr.RequiredDate);
  if msg = '';
    msg = 'Type products and quantities. Enter=Price  F10=Submit order.';
  endif;

  dow *on;
    LCOUNT  = gLineCount;
    LSUBTOT = gSubTotal;
    LFRT    = gHdr.Freight;
    LTOTAL  = gSubTotal + gHdr.Freight;
    LMSG    = msg;
    msg     = '';
    write ENTFTR;
    dspInd.sflDsp    = *on;
    dspInd.sflDspCtl = *on;
    dspInd.sflEnd    = *on;
    if LRRN < 1 or LRRN > ORD_MAX_LINES;
      LRRN = 1;
    endif;
    exfmt ENTCTL;

    if dspInd.kExit;
      gExit = *on;
      return 'X';
    endif;
    if dspInd.kCancel;
      return 'H';
    endif;

    if dspInd.kPrompt;
      if LRCD = 'ENTSFL' and LFLD = 'LPRDID' and LCSRRRN > 0;
        code = prompt(LK_PROD);
        if code <> '';
          chain LCSRRRN ENTSFL;
          if %found(ORDENTD);
            LPRDID = %int(code);
            update ENTSFL;
          endif;
        endif;
        LRRN = LCSRRRN;
      else;
        msg = 'F4=Prompt is available on the Prod column.';
      endif;
      processLines();
      iter;
    endif;

    if not processLines();
      iter;
    endif;

    if dspInd.kSubmit;
      if gLineCount = 0;
        msg = 'Enter at least one product before submitting the order.';
        iter;
      endif;
      if submitOrder();
        return 'N';
      endif;
      iter;
    endif;

    if gLineCount > 0;
      msg = 'Order priced. Press F10 to submit, or change the lines.';
    endif;
  enddo;
  return 'H';
end-proc;

//------------------------------------------------------------------------------
// processLines - default, validate and price every line of the subfile
//   Returns *OFF when a line is in error (first error shown on line 24).
//------------------------------------------------------------------------------
dcl-proc processLines;
  dcl-pi *n ind;
  end-pi;

  dcl-ds p   likeds(Product_t) inz;
  dcl-ds ln  likeds(OrderLine_t) inz;
  dcl-ds err likeds(NwError_t) inz;
  dcl-s  i        int(10);
  dcl-s  j        int(10);
  dcl-s  ok       ind;
  dcl-s  anyError ind inz(*off);

  gLineCount = 0;
  gSubTotal  = 0;
  clear gLines;

  for i = 1 to ORD_MAX_LINES;
    chain i ENTSFL;
    if not %found(ORDENTD);
      iter;
    endif;
    clear dspInd.lnErr;

    // Blank product: clear whatever else is on the line
    if LPRDID = 0;
      LPRDNM  = *blanks;
      LPRICE  = 0;
      LQTY    = 0;
      LDISC   = 0;
      LEXT    = 0;
      LPRVPRD = 0;
      update ENTSFL;
      iter;
    endif;

    // New or changed product: default name, price and quantity
    if LPRDID <> LPRVPRD;
      if Prd_get(LPRDID: p: err);
        LPRDNM = p.ProductName;
        LPRICE = p.UnitPrice;
        if LQTY = 0;
          LQTY = 1;
        endif;
      else;
        LPRDNM = '*** Product not found';
        LPRICE = 0;
      endif;
      LPRVPRD = LPRDID;
    endif;

    clear ln;
    ln.ProductId = LPRDID;
    ln.UnitPrice = LPRICE;
    ln.Quantity  = LQTY;
    ln.Discount  = LDISC / 100;

    ok = Ord_validateLine(ln: err);
    if ok;
      for j = 1 to gLineCount;
        if gLines(j).ProductId = ln.ProductId;
          ok = NwU_setError(err: NWE_DUPLICATE: 'ProductId':
                            'Product is already on the order.');
          leave;
        endif;
      endfor;
    endif;

    if ok;
      LEXT = Ord_calcExtPrice(ln.UnitPrice: ln.Quantity: ln.Discount);
      gLineCount += 1;
      gLines(gLineCount) = ln;
      gSubTotal += LEXT;
    else;
      LEXT = 0;
      select;
        when err.field = 'ProductId';
          dspInd.lnErr(1) = *on;
        when err.field = 'UnitPrice';
          dspInd.lnErr(2) = *on;
        when err.field = 'Quantity';
          dspInd.lnErr(3) = *on;
        when err.field = 'Discount';
          dspInd.lnErr(4) = *on;
      endsl;
      if not anyError;
        anyError = *on;
        msg  = 'Line ' + %char(i) + ': ' + err.text;
        LRRN = i;
      endif;
    endif;
    update ENTSFL;
  endfor;

  clear dspInd.lnErr;
  return not anyError;
end-proc;

//------------------------------------------------------------------------------
// submitOrder - write the order through NWORDSV
//------------------------------------------------------------------------------
dcl-proc submitOrder;
  dcl-pi *n ind;
  end-pi;

  dcl-ds err   likeds(NwError_t) inz;
  dcl-s  total packed(15:2);

  if not Ord_create(gHdr: gLines: gLineCount: err);
    msg = err.text;
    return *off;
  endif;

  total = gSubTotal + gHdr.Freight;
  msg = 'Order ' + %char(gHdr.OrderId) + ' created for ' + %trim(gHdr.CustomerId)
      + ', total ' + %trim(%editc(total: '1')) + '.';
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Header <-> screen
//------------------------------------------------------------------------------
dcl-proc hdrToScreen;
  HCUSTID  = gHdr.CustomerId;
  HEMPID   = gHdr.EmployeeId;
  HORDDT   = NwU_fromDate(gHdr.OrderDate);
  HREQDT   = NwU_fromDate(gHdr.RequiredDate);
  HSHPVIA  = gHdr.ShipVia;
  HFREIGHT = gHdr.Freight;
  HSHPNAME = gHdr.ShipName;
  HSHPADDR = gHdr.ShipAddress;
  HSHPCITY = gHdr.ShipCity;
  HSHPREG  = gHdr.ShipRegion;
  HSHPPOST = gHdr.ShipPostalCode;
  HSHPCTRY = gHdr.ShipCountry;
  hdrNames();
end-proc;

dcl-proc hdrNames;
  HCUSTNM = Ord_customerName(HCUSTID);
  HEMPNM  = Ord_employeeName(HEMPID);
  HSHPNM  = Ord_shipperName(HSHPVIA);
  if HCUSTID <> *blanks and HCUSTNM = *blanks;
    HCUSTNM = '*** Customer not found';
  endif;
end-proc;

dcl-proc screenToHdr;
  dcl-pi *n ind;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  gHdr.CustomerId = HCUSTID;
  gHdr.EmployeeId = HEMPID;
  if not NwU_toDate(HORDDT: gHdr.OrderDate);
    return NwU_setError(err: NWE_INVALID: 'OrderDate':
                        'Order date is not a valid date (YYYY-MM-DD).');
  endif;
  if not NwU_toDate(HREQDT: gHdr.RequiredDate);
    return NwU_setError(err: NWE_INVALID: 'RequiredDate':
                        'Required date is not a valid date (YYYY-MM-DD).');
  endif;
  gHdr.ShipVia        = HSHPVIA;
  gHdr.Freight        = HFREIGHT;
  gHdr.ShipName       = %trimr(HSHPNAME);
  gHdr.ShipAddress    = %trimr(HSHPADDR);
  gHdr.ShipCity       = %trimr(HSHPCITY);
  gHdr.ShipRegion     = %trimr(HSHPREG);
  gHdr.ShipPostalCode = %trimr(HSHPPOST);
  gHdr.ShipCountry    = %trimr(HSHPCTRY);
  return *on;
end-proc;

dcl-proc showHdrError;
  dcl-pi *n;
    err likeds(NwError_t) const;
  end-pi;

  msg = err.text;
  select;
    when err.field = 'CustomerId';
      dspInd.hdrErr(1) = *on;
    when err.field = 'EmployeeId';
      dspInd.hdrErr(2) = *on;
    when err.field = 'OrderDate';
      dspInd.hdrErr(3) = *on;
    when err.field = 'RequiredDate';
      dspInd.hdrErr(4) = *on;
    when err.field = 'ShipVia';
      dspInd.hdrErr(5) = *on;
    when err.field = 'Freight';
      dspInd.hdrErr(6) = *on;
    when err.field = 'ShipName';
      dspInd.hdrErr(7) = *on;
    when err.field = 'ShipAddress';
      dspInd.hdrErr(8) = *on;
    when err.field = 'ShipCity';
      dspInd.hdrErr(9) = *on;
    when err.field = 'ShipRegion';
      dspInd.hdrErr(10) = *on;
    when err.field = 'ShipPostalCode';
      dspInd.hdrErr(11) = *on;
    when err.field = 'ShipCountry';
      dspInd.hdrErr(12) = *on;
  endsl;
end-proc;

//------------------------------------------------------------------------------
// prompt - F4 select window; returns the selected code or '' (cancelled)
//------------------------------------------------------------------------------
dcl-proc prompt;
  dcl-pi *n varchar(10);
    kind char(1) const;
  end-pi;

  dcl-s savedPos like(WPOS);

  select;
    when kind = LK_CUST;
      WTITLE = 'Select Customer';
      WHDR1  = 'Customer';
      WHDR2  = 'Company name';
    when kind = LK_EMP;
      WTITLE = 'Select Employee (position by last name)';
      WHDR1  = 'Employee';
      WHDR2  = 'Name';
    when kind = LK_SHIP;
      WTITLE = 'Select Shipper';
      WHDR1  = 'Shipper';
      WHDR2  = 'Company name';
    other;
      WTITLE = 'Select Product (active products only)';
      WHDR1  = 'Product';
      WHDR2  = 'Product name';
  endsl;

  WPOS = *blanks;
  savedPos = WPOS;
  loadWindow(kind);

  dow *on;
    exfmt WINCTL;
    if dspInd.kExit or dspInd.kCancel;
      return '';
    endif;
    if WPOS <> savedPos;
      savedPos = WPOS;
      loadWindow(kind);
      iter;
    endif;
    readc WINSFL;
    dow not %eof(ORDENTD);
      if WOPT = '1';
        return %trim(WCODE);
      endif;
      readc WINSFL;
    enddo;
  enddo;
  return '';
end-proc;

//------------------------------------------------------------------------------
// loadWindow - fill the select window from the matching service program
//------------------------------------------------------------------------------
dcl-proc loadWindow;
  dcl-pi *n;
    kind char(1) const;
  end-pi;

  dcl-ds c   likeds(Customer_t) inz;
  dcl-ds e   likeds(Employee_t) inz;
  dcl-ds s   likeds(Shipper_t) inz;
  dcl-ds p   likeds(Product_t) inz;
  dcl-ds err likeds(NwError_t) inz;
  dcl-s  startId int(10);
  dcl-c  MAX_ROWS 500;

  dspInd.winDsp    = *off;
  dspInd.winDspCtl = *off;
  dspInd.winClr    = *on;
  write WINCTL;
  dspInd.winClr = *off;
  rrnW = 0;

  select;
    when kind = LK_CUST;
      if Cust_openList(%subst(WPOS: 1: 5): err);
        dow rrnW < MAX_ROWS and Cust_fetchNext(c);
          addWindowRow(c.CustomerId: c.CompanyName);
        enddo;
        Cust_closeList();
      endif;
    when kind = LK_EMP;
      if Emp_openList(%trimr(WPOS): err);
        dow rrnW < MAX_ROWS and Emp_fetchNext(e);
          addWindowRow(%char(e.EmployeeId): %trim(e.FirstName) + ' ' + e.LastName);
        enddo;
        Emp_closeList();
      endif;
    when kind = LK_SHIP;
      monitor;
        startId = %int(%trim(WPOS));
      on-error;
        startId = 0;
      endmon;
      if Shp_openList(startId: err);
        dow rrnW < MAX_ROWS and Shp_fetchNext(s);
          addWindowRow(%char(s.ShipperId): s.CompanyName);
        enddo;
        Shp_closeList();
      endif;
    other;
      if Prd_openList(%trimr(WPOS): err);
        dow rrnW < MAX_ROWS and Prd_fetchNext(p);
          if p.Discontinued = 0;
            addWindowRow(%char(p.ProductId): p.ProductName);
          endif;
        enddo;
        Prd_closeList();
      endif;
  endsl;

  dspInd.winDsp    = (rrnW > 0);
  dspInd.winDspCtl = *on;
  dspInd.winEnd    = *on;
end-proc;

dcl-proc addWindowRow;
  dcl-pi *n;
    code varchar(10) const;
    desc varchar(60) const;
  end-pi;

  WOPT  = ' ';
  WCODE = code;
  WDESC = desc;
  rrnW += 1;
  write WINSFL;
end-proc;
