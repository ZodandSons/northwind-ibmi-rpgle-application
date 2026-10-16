**free
//==============================================================================
// WRKORD - Order Inquiry
//
// Work-with list of orders (newest first) filtered by customer, order date
// range and open (not shipped) status, with "start at order number".
// Option 5 displays the order header, its lines and totals.
// F4 on the Customer filter opens the customer select window.
//==============================================================================
ctl-opt main(Main) dftactgrp(*no) actgrp('NWAPP') bnddir('NWBNDDIR')
        option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f WRKORDD workstn usropn indds(dspInd)
        sfile(SFL01: rrn1) sfile(DSPSFL: rrn2) sfile(WINSFL: rrnW);

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWORDPR
/copy QCPYSRC,NWCUSTPR

// Display file indicators (INDARA)
dcl-ds dspInd len(99) qualified;
  kExit      ind pos(3);
  kPrompt    ind pos(4);
  kRefresh   ind pos(5);
  kCancel    ind pos(12);
  sflDsp     ind pos(31);
  sflDspCtl  ind pos(32);
  sflClr     ind pos(33);
  sflEnd     ind pos(34);
  sflDsp2    ind pos(35);
  sflDspCtl2 ind pos(36);
  sflClr2    ind pos(37);
  sflEnd2    ind pos(38);
  fltErr     ind pos(51) dim(3);
  winDsp     ind pos(71);
  winDspCtl  ind pos(72);
  winClr     ind pos(73);
  winEnd     ind pos(74);
end-ds;

dcl-s rrn1      packed(4:0);
dcl-s rrn2      packed(4:0);
dcl-s rrnW      packed(4:0);
dcl-s gExit     ind;
dcl-s msg       varchar(78) inz('');
dcl-s savedFlt  varchar(60);

//------------------------------------------------------------------------------
// Main - list loop
//------------------------------------------------------------------------------
dcl-proc Main;
  dcl-s code varchar(10);

  if not %open(WRKORDD);
    open WRKORDD;
  endif;
  gExit  = *off;
  msg    = '';
  FCUST  = *blanks;
  FFROM  = *blanks;
  FTO    = *blanks;
  FOPEN  = 'N';
  FSTART = 0;
  loadList();

  dow not gExit;
    MSG1 = msg;
    msg  = '';
    write FKEYS01;
    exfmt CTL01;
    clear dspInd.fltErr;

    select;
      when dspInd.kExit or dspInd.kCancel;
        leave;
      when dspInd.kPrompt;
        if C1FLD = 'FCUST';
          code = promptCustomer();
          if code <> '';
            FCUST = code;
          endif;
          loadList();
        else;
          msg = 'F4=Prompt is available on the Customer field.';
        endif;
      when dspInd.kRefresh or filterKey() <> savedFlt;
        loadList();
      other;
        processOptions();
    endsl;
  enddo;

  close WRKORDD;
end-proc;

//------------------------------------------------------------------------------
// filterKey - current filter values as one string (change detection)
//------------------------------------------------------------------------------
dcl-proc filterKey;
  dcl-pi *n varchar(60);
  end-pi;

  return FCUST + FFROM + FTO + FOPEN + %char(FSTART);
end-proc;

//------------------------------------------------------------------------------
// loadList - validate the filters and load the order list
//------------------------------------------------------------------------------
dcl-proc loadList;
  dcl-ds f   likeds(OrderFilter_t) inz;
  dcl-ds row likeds(OrderSummary_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  savedFlt = filterKey();

  dspInd.sflDsp    = *off;
  dspInd.sflDspCtl = *off;
  dspInd.sflClr    = *on;
  write CTL01;
  dspInd.sflClr = *off;
  rrn1 = 0;
  dspInd.sflDspCtl = *on;
  dspInd.sflEnd    = *on;
  C1RRN = 1;

  f.CustomerId = FCUST;
  if FCUST <> *blanks and Ord_customerName(FCUST) = '';
    dspInd.fltErr(1) = *on;
    msg = 'Customer ' + %trim(FCUST) + ' not found.';
    return;
  endif;
  if not NwU_toDate(FFROM: f.FromDate);
    dspInd.fltErr(2) = *on;
    msg = 'From date is not a valid date (YYYY-MM-DD).';
    return;
  endif;
  if not NwU_toDate(FTO: f.ToDate);
    dspInd.fltErr(3) = *on;
    msg = 'To date is not a valid date (YYYY-MM-DD).';
    return;
  endif;
  if f.FromDate <> NW_NULL_DATE and f.ToDate <> NW_NULL_DATE and f.ToDate < f.FromDate;
    dspInd.fltErr(3) = *on;
    msg = 'To date cannot be before from date.';
    return;
  endif;
  f.OpenOnly     = (FOPEN = 'Y');
  f.StartOrderId = FSTART;

  if not Ord_openList(f: err);
    msg = err.text;
    return;
  endif;
  dow rrn1 < NW_SFL_MAX and Ord_fetchList(row);
    S1OPT     = ' ';
    S1ORDID   = row.OrderId;
    S1CUSTID  = row.CustomerId;
    S1COMPANY = row.CompanyName;
    S1ORDDT   = NwU_fromDate(row.OrderDate);
    if row.ShippedDate = NW_NULL_DATE;
      S1SHPDT = 'Open';
    else;
      S1SHPDT = NwU_fromDate(row.ShippedDate);
    endif;
    S1TOTAL = row.SubTotal + row.Freight;
    rrn1 += 1;
    write SFL01;
  enddo;
  Ord_closeList();

  dspInd.sflDsp = (rrn1 > 0);
  if rrn1 = 0;
    msg = 'No orders match the selection.';
  elseif rrn1 = NW_SFL_MAX;
    msg = 'Only the first 9999 orders are listed. Narrow the selection.';
  endif;
end-proc;

//------------------------------------------------------------------------------
// processOptions - 5=Display
//------------------------------------------------------------------------------
dcl-proc processOptions;
  readc SFL01;
  dow not %eof(WRKORDD) and not gExit;
    if S1OPT = '5';
      displayOrder(S1ORDID);
    endif;
    S1OPT = ' ';
    update SFL01;
    readc SFL01;
  enddo;
end-proc;

//------------------------------------------------------------------------------
// displayOrder - header, lines and totals of one order
//------------------------------------------------------------------------------
dcl-proc displayOrder;
  dcl-pi *n;
    orderId int(10) const;
  end-pi;

  dcl-ds h   likeds(OrderHeader_t) inz;
  dcl-ds ln  likeds(OrderLine_t) inz;
  dcl-ds err likeds(NwError_t) inz;
  dcl-s  subTotal packed(19:4) inz(0);

  if not Ord_get(orderId: h: err);
    msg = err.text;
    return;
  endif;

  OORDID   = h.OrderId;
  OCUSTID  = h.CustomerId;
  OCUSTNM  = Ord_customerName(h.CustomerId);
  OEMPNM   = Ord_employeeName(h.EmployeeId);
  OSHPNM   = Ord_shipperName(h.ShipVia);
  OORDDT   = NwU_fromDate(h.OrderDate);
  OREQDT   = NwU_fromDate(h.RequiredDate);
  if h.ShippedDate = NW_NULL_DATE;
    OSHPDT = 'Not yet';
  else;
    OSHPDT = NwU_fromDate(h.ShippedDate);
  endif;
  OSHPNAME = h.ShipName;
  OSHPADDR = h.ShipAddress;
  OSHPCITY = h.ShipCity;
  OSHPREG  = h.ShipRegion;
  OSHPPOST = h.ShipPostalCode;
  OSHPCTRY = h.ShipCountry;

  dspInd.sflDsp2    = *off;
  dspInd.sflDspCtl2 = *off;
  dspInd.sflClr2    = *on;
  write DSPCTL;
  dspInd.sflClr2 = *off;
  rrn2 = 0;

  if Ord_openLines(orderId: err);
    dow rrn2 < NW_SFL_MAX and Ord_fetchLine(ln);
      DPRDID = ln.ProductId;
      DPRDNM = ln.ProductName;
      DPRICE = ln.UnitPrice;
      DQTY   = ln.Quantity;
      DDISC  = %dech(ln.Discount * 100: 5: 2);
      DEXT   = ln.ExtPrice;
      subTotal += ln.ExtPrice;
      rrn2 += 1;
      write DSPSFL;
    enddo;
    Ord_closeLines();
  else;
    MSG2 = err.text;
  endif;

  OSUBTOT = subTotal;
  OFRT    = h.Freight;
  OTOTAL  = subTotal + h.Freight;
  dspInd.sflDsp2    = (rrn2 > 0);
  dspInd.sflDspCtl2 = *on;
  dspInd.sflEnd2    = *on;
  if rrn2 = 0 and MSG2 = *blanks;
    MSG2 = 'This order has no lines.';
  endif;

  write DSPFTR;
  exfmt DSPCTL;
  MSG2 = *blanks;
  if dspInd.kExit;
    gExit = *on;
  endif;
end-proc;

//------------------------------------------------------------------------------
// promptCustomer - customer select window; returns customer ID or ''
//------------------------------------------------------------------------------
dcl-proc promptCustomer;
  dcl-pi *n varchar(10);
  end-pi;

  dcl-s savedPos like(WPOS);

  WTITLE = 'Select Customer';
  WHDR1  = 'Customer';
  WHDR2  = 'Company name';
  WPOS   = *blanks;
  savedPos = WPOS;
  loadWindow();

  dow *on;
    exfmt WINCTL;
    if dspInd.kExit or dspInd.kCancel;
      return '';
    endif;
    if WPOS <> savedPos;
      savedPos = WPOS;
      loadWindow();
      iter;
    endif;
    readc WINSFL;
    dow not %eof(WRKORDD);
      if WOPT = '1';
        return %trim(WCODE);
      endif;
      readc WINSFL;
    enddo;
  enddo;
  return '';
end-proc;

dcl-proc loadWindow;
  dcl-ds c   likeds(Customer_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  dspInd.winDsp    = *off;
  dspInd.winDspCtl = *off;
  dspInd.winClr    = *on;
  write WINCTL;
  dspInd.winClr = *off;
  rrnW = 0;

  if Cust_openList(%subst(WPOS: 1: 5): err);
    dow rrnW < 500 and Cust_fetchNext(c);
      WOPT  = ' ';
      WCODE = c.CustomerId;
      WDESC = c.CompanyName;
      rrnW += 1;
      write WINSFL;
    enddo;
    Cust_closeList();
  endif;

  dspInd.winDsp    = (rrnW > 0);
  dspInd.winDspCtl = *on;
  dspInd.winEnd    = *on;
end-proc;
