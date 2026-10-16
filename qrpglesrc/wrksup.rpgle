**free
//==============================================================================
// WRKSUP - Work with Suppliers
//
// IBM i "Work with" panel for table SUPPLIERS:
//   List (subfile) with position-to, options 2=Change 3=Copy 4=Delete 5=Display,
//   F6=Create, F5=Refresh, confirm-delete panel, detail panel and F10 text editor.
//
// All database access is through service program NWSUPSV.
//==============================================================================
ctl-opt main(Main) dftactgrp(*no) actgrp('NWAPP') bnddir('NWBNDDIR')
        option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f WRKSUPD workstn usropn indds(dspInd)
        sfile(SFL01: rrn1) sfile(SFL02: rrn2);

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWSUPPR

// Display file indicators (INDARA)
dcl-ds dspInd len(99) qualified;
  kExit      ind pos(3);
  kRefresh   ind pos(5);
  kCreate    ind pos(6);
  kText      ind pos(10);
  kCancel    ind pos(12);
  sflDsp     ind pos(31);
  sflDspCtl  ind pos(32);
  sflClr     ind pos(33);
  sflEnd     ind pos(34);
  sflDsp2    ind pos(35);
  sflDspCtl2 ind pos(36);
  sflClr2    ind pos(37);
  sflEnd2    ind pos(38);
  protectAll ind pos(40);
  protectKey ind pos(41);
  fldErr     ind pos(51) dim(30);
end-ds;

// Key of one supplier
dcl-ds Key_t qualified template;
  SupplierId like(Supplier_t.SupplierId);
end-ds;

dcl-s  rrn1     packed(4:0);
dcl-s  rrn2     packed(4:0);
dcl-s  gExit    ind;
dcl-s  msg      varchar(78) inz('');
dcl-s  savedPos like(C1POS);
dcl-s  dltCount int(10);
dcl-ds dltKey   likeds(Key_t) dim(500);

// Text editor lines overlay the 12 screen fields TX01-TX12
dcl-ds txtBuf;
  TX01 char(76);
  TX02 char(76);
  TX03 char(76);
  TX04 char(76);
  TX05 char(76);
  TX06 char(76);
  TX07 char(76);
  TX08 char(76);
  TX09 char(76);
  TX10 char(76);
  TX11 char(76);
  TX12 char(76);
  txtArr char(76) dim(12) pos(1);
end-ds;

//------------------------------------------------------------------------------
// Main - list loop
//------------------------------------------------------------------------------
dcl-proc Main;
  dcl-ds noKey likeds(Key_t) inz;

  if not %open(WRKSUPD);
    open WRKSUPD;
  endif;
  gExit = *off;
  msg   = '';
  clear C1POS;
  savedPos = C1POS;
  loadList();

  dow not gExit;
    MSG1 = msg;
    msg  = '';
    write FKEYS01;
    exfmt CTL01;

    select;
      when dspInd.kExit or dspInd.kCancel;
        leave;
      when dspInd.kRefresh;
        loadList();
      when dspInd.kCreate;
        showDetail(MODE_CREATE: noKey);
        loadList();
      when C1POS <> savedPos;
        savedPos = C1POS;
        loadList();
      other;
        if processOptions();
          loadList();
        endif;
    endsl;
  enddo;

  close WRKSUPD;
end-proc;

//------------------------------------------------------------------------------
// loadList - (re)load the list subfile from the position-to value
//------------------------------------------------------------------------------
dcl-proc loadList;
  dcl-ds r   likeds(Supplier_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  dspInd.sflDsp    = *off;
  dspInd.sflDspCtl = *off;
  dspInd.sflClr    = *on;
  write CTL01;
  dspInd.sflClr = *off;
  rrn1 = 0;
  savedPos = C1POS;

  if not Sup_openList(C1POS: err);
    msg = err.text;
  else;
    dow rrn1 < NW_SFL_MAX and Sup_fetchNext(r);
      S1OPT = ' ';
      S1SUPID = r.SupplierId;
      S1COMPANY = r.CompanyName;
      S1CITY = r.City;
      S1COUNTRY = r.Country;
      H1SUPID = r.SupplierId;
      rrn1 += 1;
      write SFL01;
    enddo;
    Sup_closeList();
  endif;

  dspInd.sflDsp    = (rrn1 > 0);
  dspInd.sflDspCtl = *on;
  dspInd.sflEnd    = *on;
  C1RRN = 1;
  if rrn1 = 0 and msg = '';
    msg = 'No suppliers found. Press F6 to create one.';
  endif;
end-proc;

//------------------------------------------------------------------------------
// processOptions - handle options typed in the list
//   Returns *ON when at least one option was processed.
//------------------------------------------------------------------------------
dcl-proc processOptions;
  dcl-pi *n ind;
  end-pi;

  dcl-ds key   likeds(Key_t) inz;
  dcl-s  count int(10) inz(0);

  dltCount = 0;
  readc SFL01;
  dow not %eof(WRKSUPD) and not gExit;
    key.SupplierId = H1SUPID;
    select;
      when S1OPT = '2';
        count += 1;
        showDetail(MODE_CHANGE: key);
      when S1OPT = '3';
        count += 1;
        showDetail(MODE_COPY: key);
      when S1OPT = '4';
        count += 1;
        if dltCount < %elem(dltKey);
          dltCount += 1;
          dltKey(dltCount) = key;
        endif;
      when S1OPT = '5';
        count += 1;
        showDetail(MODE_DISPLAY: key);
    endsl;
    readc SFL01;
  enddo;

  if dltCount > 0 and not gExit;
    confirmDelete();
  endif;
  return count > 0;
end-proc;

//------------------------------------------------------------------------------
// confirmDelete - IBM style "Confirm Delete" panel, then delete
//------------------------------------------------------------------------------
dcl-proc confirmDelete;
  dcl-ds r   likeds(Supplier_t) inz;
  dcl-ds err likeds(NwError_t) inz;
  dcl-s  i       int(10);
  dcl-s  deleted int(10) inz(0);
  dcl-s  failed  int(10) inz(0);
  dcl-s  lastErr varchar(132) inz('');

  dspInd.sflDsp2    = *off;
  dspInd.sflDspCtl2 = *off;
  dspInd.sflClr2    = *on;
  write CTL02;
  dspInd.sflClr2 = *off;
  rrn2 = 0;

  for i = 1 to dltCount;
    clear r;
    if not Sup_get(dltKey(i).SupplierId: r: err);
      r.SupplierId = dltKey(i).SupplierId;
    endif;
    X2OPT = '4';
    X2SUPID = r.SupplierId;
    X2COMPANY = r.CompanyName;
    X2CITY = r.City;
    X2COUNTRY = r.Country;
    rrn2 += 1;
    write SFL02;
  endfor;

  dspInd.sflDsp2    = (rrn2 > 0);
  dspInd.sflDspCtl2 = *on;
  dspInd.sflEnd2    = *on;
  MSG2 = '';
  write FKEYS02;
  exfmt CTL02;

  if dspInd.kExit;
    gExit = *on;
    return;
  endif;
  if dspInd.kCancel;
    msg = 'Delete cancelled.';
    return;
  endif;

  for i = 1 to dltCount;
    if Sup_delete(dltKey(i).SupplierId: err);
      deleted += 1;
    else;
      failed += 1;
      lastErr = err.text;
    endif;
  endfor;

  if failed = 0;
    msg = %char(deleted) + ' supplier(s) deleted.';
  else;
    msg = %char(deleted) + ' deleted, ' + %char(failed) + ' not deleted: ' + lastErr;
  endif;
end-proc;

//------------------------------------------------------------------------------
// showDetail - create / change / copy / display one supplier
//   Returns *ON when the database was changed.
//------------------------------------------------------------------------------
dcl-proc showDetail;
  dcl-pi *n ind;
    mode char(1) const;
    key  likeds(Key_t) const;
  end-pi;

  dcl-ds r   likeds(Supplier_t) inz;
  dcl-ds err likeds(NwError_t) inz;
  dcl-s  ok  ind;

  if mode <> MODE_CREATE;
    if not Sup_get(key.SupplierId: r: err);
      msg = err.text;
      return *off;
    endif;
  endif;
  if mode = MODE_COPY;
    r.SupplierId = 0;                  // new identity on save
  endif;

  select;
    when mode = MODE_CREATE;
      PTITLE = NwU_center('Create Supplier': %len(PTITLE));
      PINSTR = 'Type information, press Enter.';
    when mode = MODE_CHANGE;
      PTITLE = NwU_center('Change Supplier': %len(PTITLE));
      PINSTR = 'Type changes, press Enter.';
    when mode = MODE_COPY;
      PTITLE = NwU_center('Copy Supplier': %len(PTITLE));
      PINSTR = 'Type information for the new supplier, press Enter.';
    other;
      PTITLE = NwU_center('Display Supplier': %len(PTITLE));
      PINSTR = 'Press Enter to continue.';
  endsl;
  PKEYS = 'F3=Exit   F10=Text   F12=Cancel';
  recToScreen(r);

  dow *on;
    dspInd.protectKey = (mode = MODE_CHANGE or mode = MODE_DISPLAY);
    dspInd.protectAll = (mode = MODE_DISPLAY);
    PMSG = msg;
    msg  = '';
    exfmt DETAIL;
    clear dspInd.fldErr;

    if dspInd.kExit;
      gExit = *on;
      return *off;
    endif;
    if dspInd.kCancel;
      return *off;
    endif;
    if dspInd.kText;
      editText(r.HomePage: mode = MODE_DISPLAY: 'Home page for ' + keyText(r));
      DHOMEPG = r.HomePage;
      if gExit;
        return *off;
      endif;
      iter;
    endif;
    if mode = MODE_DISPLAY;
      return *off;
    endif;

    if not screenToRec(r: err);
      showError(err);
      iter;
    endif;
    showDescs(r);

    if mode = MODE_CHANGE;
      ok = Sup_update(r: err);
    else;
      ok = Sup_create(r: err);
    endif;
    if not ok;
      showError(err);
      iter;
    endif;

    if mode = MODE_CHANGE;
      msg = 'Supplier ' + keyText(r) + ' changed.';
    else;
      msg = 'Supplier ' + keyText(r) + ' created.';
    endif;
    return *on;
  enddo;
  return *off;
end-proc;

//------------------------------------------------------------------------------
// recToScreen - move a record to the detail panel
//------------------------------------------------------------------------------
dcl-proc recToScreen;
  dcl-pi *n;
    r likeds(Supplier_t) const;
  end-pi;

  DSUPID = r.SupplierId;
  DCOMPANY = r.CompanyName;
  DCONTACT = r.ContactName;
  DCTITLE = r.ContactTitle;
  DADDRESS = r.Address;
  DCITY = r.City;
  DREGION = r.Region;
  DPOSTAL = r.PostalCode;
  DCOUNTRY = r.Country;
  DPHONE = r.Phone;
  DFAX = r.Fax;
  DHOMEPG = r.HomePage;
  showDescs(r);
end-proc;

//------------------------------------------------------------------------------
// screenToRec - move the detail panel into a record (format checks)
//------------------------------------------------------------------------------
dcl-proc screenToRec;
  dcl-pi *n ind;
    r   likeds(Supplier_t);
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  r.CompanyName = %trimr(DCOMPANY);
  r.ContactName = %trimr(DCONTACT);
  r.ContactTitle = %trimr(DCTITLE);
  r.Address = %trimr(DADDRESS);
  r.City = %trimr(DCITY);
  r.Region = %trimr(DREGION);
  r.PostalCode = %trimr(DPOSTAL);
  r.Country = %trimr(DCOUNTRY);
  r.Phone = %trimr(DPHONE);
  r.Fax = %trimr(DFAX);
  return *on;
end-proc;

//------------------------------------------------------------------------------
// showDescs - refresh descriptions of referenced records
//------------------------------------------------------------------------------
dcl-proc showDescs;
  dcl-pi *n;
    r likeds(Supplier_t) const;
  end-pi;

  // no foreign keys on this table
end-proc;

//------------------------------------------------------------------------------
// showError - message line text and field highlight
//------------------------------------------------------------------------------
dcl-proc showError;
  dcl-pi *n;
    err likeds(NwError_t) const;
  end-pi;

  msg = err.text;
  select;
    when err.field = 'SupplierId';
      dspInd.fldErr(1) = *on;
    when err.field = 'CompanyName';
      dspInd.fldErr(2) = *on;
    when err.field = 'ContactName';
      dspInd.fldErr(3) = *on;
    when err.field = 'ContactTitle';
      dspInd.fldErr(4) = *on;
    when err.field = 'Address';
      dspInd.fldErr(5) = *on;
    when err.field = 'City';
      dspInd.fldErr(6) = *on;
    when err.field = 'Region';
      dspInd.fldErr(7) = *on;
    when err.field = 'PostalCode';
      dspInd.fldErr(8) = *on;
    when err.field = 'Country';
      dspInd.fldErr(9) = *on;
    when err.field = 'Phone';
      dspInd.fldErr(10) = *on;
    when err.field = 'Fax';
      dspInd.fldErr(11) = *on;
    when err.field = 'HomePage';
      dspInd.fldErr(12) = *on;
  endsl;
end-proc;

//------------------------------------------------------------------------------
// keyText - printable key for messages
//------------------------------------------------------------------------------
dcl-proc keyText;
  dcl-pi *n varchar(60);
    r likeds(Supplier_t) const;
  end-pi;

  return %char(r.SupplierId);
end-proc;

//------------------------------------------------------------------------------
// editText - 12 x 76 word-wrapped editor for the HOMEPAGE column
//------------------------------------------------------------------------------
dcl-proc editText;
  dcl-pi *n;
    text    varchar(1024);
    protect ind const;
    title   varchar(70) const;
  end-pi;

  NwU_wrapText(text: txtArr);
  TTITLE = NwU_center('Home page': %len(TTITLE));
  TKEY   = title;
  if protect;
    TKEYS = 'F3=Exit   F12=Cancel';
  else;
    TKEYS = 'Enter=Accept   F3=Exit   F12=Cancel';
  endif;
  TMSG = '';
  dspInd.protectAll = protect;
  exfmt TEXT01;

  if dspInd.kExit;
    gExit = *on;
    return;
  endif;
  if dspInd.kCancel or protect;
    return;
  endif;
  text = NwU_joinText(txtArr);
end-proc;
