**free
//==============================================================================
// WRKCDM - Work with Customer Demographic Links
//
// IBM i "Work with" panel for table CUSTOMERCUSTOMERDEMO:
//   List (subfile) with position-to, options 3=Copy 4=Delete 5=Display,
//   F6=Create, F5=Refresh, confirm-delete panel, detail panel.
//
// All database access is through service program NWCDMSV.
//==============================================================================
ctl-opt main(Main) dftactgrp(*no) actgrp('NWAPP') bnddir('NWBNDDIR')
        option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f WRKCDMD workstn usropn indds(dspInd)
        sfile(SFL01: rrn1) sfile(SFL02: rrn2);

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWCDMPR

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

// Key of one customer demographic
dcl-ds Key_t qualified template;
  CustomerId like(CustCustDemo_t.CustomerId);
  CustomerTypeId like(CustCustDemo_t.CustomerTypeId);
end-ds;

dcl-s  rrn1     packed(4:0);
dcl-s  rrn2     packed(4:0);
dcl-s  gExit    ind;
dcl-s  msg      varchar(78) inz('');
dcl-s  savedPos like(C1POS);
dcl-s  dltCount int(10);
dcl-ds dltKey   likeds(Key_t) dim(500);

//------------------------------------------------------------------------------
// Main - list loop
//------------------------------------------------------------------------------
dcl-proc Main;
  dcl-ds noKey likeds(Key_t) inz;

  if not %open(WRKCDMD);
    open WRKCDMD;
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

  close WRKCDMD;
end-proc;

//------------------------------------------------------------------------------
// loadList - (re)load the list subfile from the position-to value
//------------------------------------------------------------------------------
dcl-proc loadList;
  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  dspInd.sflDsp    = *off;
  dspInd.sflDspCtl = *off;
  dspInd.sflClr    = *on;
  write CTL01;
  dspInd.sflClr = *off;
  rrn1 = 0;
  savedPos = C1POS;

  if not Cdm_openList(C1POS: err);
    msg = err.text;
  else;
    dow rrn1 < NW_SFL_MAX and Cdm_fetchNext(r);
      S1OPT = ' ';
      S1CUSTID = r.CustomerId;
      S1NCUSTID = Cdm_CustomerIdDesc(r.CustomerId);
      S1TYPEID = r.CustomerTypeId;
      S1NTYPEID = Cdm_CustomerTypeIdDesc(r.CustomerTypeId);
      H1CUSTID = r.CustomerId;
      H1TYPEID = r.CustomerTypeId;
      rrn1 += 1;
      write SFL01;
    enddo;
    Cdm_closeList();
  endif;

  dspInd.sflDsp    = (rrn1 > 0);
  dspInd.sflDspCtl = *on;
  dspInd.sflEnd    = *on;
  C1RRN = 1;
  if rrn1 = 0 and msg = '';
    msg = 'No customer demographic links found. Press F6 to create one.';
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
  dow not %eof(WRKCDMD) and not gExit;
    key.CustomerId = H1CUSTID;
    key.CustomerTypeId = H1TYPEID;
    select;
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
  dcl-ds r   likeds(CustCustDemo_t) inz;
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
    if not Cdm_get(dltKey(i).CustomerId: dltKey(i).CustomerTypeId: r: err);
      r.CustomerId = dltKey(i).CustomerId;
      r.CustomerTypeId = dltKey(i).CustomerTypeId;
    endif;
    X2OPT = '4';
    X2CUSTID = r.CustomerId;
    X2NCUSTID = Cdm_CustomerIdDesc(r.CustomerId);
    X2TYPEID = r.CustomerTypeId;
    X2NTYPEID = Cdm_CustomerTypeIdDesc(r.CustomerTypeId);
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
    if Cdm_delete(dltKey(i).CustomerId: dltKey(i).CustomerTypeId: err);
      deleted += 1;
    else;
      failed += 1;
      lastErr = err.text;
    endif;
  endfor;

  if failed = 0;
    msg = %char(deleted) + ' customer demographic(s) deleted.';
  else;
    msg = %char(deleted) + ' deleted, ' + %char(failed) + ' not deleted: ' + lastErr;
  endif;
end-proc;

//------------------------------------------------------------------------------
// showDetail - create / change / copy / display one customer demographic
//   Returns *ON when the database was changed.
//------------------------------------------------------------------------------
dcl-proc showDetail;
  dcl-pi *n ind;
    mode char(1) const;
    key  likeds(Key_t) const;
  end-pi;

  dcl-ds r   likeds(CustCustDemo_t) inz;
  dcl-ds err likeds(NwError_t) inz;
  dcl-s  ok  ind;

  if mode <> MODE_CREATE;
    if not Cdm_get(key.CustomerId: key.CustomerTypeId: r: err);
      msg = err.text;
      return *off;
    endif;
  endif;

  select;
    when mode = MODE_CREATE;
      PTITLE = NwU_center('Create Customer demographic': %len(PTITLE));
      PINSTR = 'Type information, press Enter.';
    when mode = MODE_CHANGE;
      PTITLE = NwU_center('Change Customer demographic': %len(PTITLE));
      PINSTR = 'Type changes, press Enter.';
    when mode = MODE_COPY;
      PTITLE = NwU_center('Copy Customer demographic': %len(PTITLE));
      PINSTR = 'Type information for the new customer demographic, press Enter.';
    other;
      PTITLE = NwU_center('Display Customer demographic': %len(PTITLE));
      PINSTR = 'Press Enter to continue.';
  endsl;
  PKEYS = 'F3=Exit   F12=Cancel';
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
    if mode = MODE_DISPLAY;
      return *off;
    endif;

    if not screenToRec(r: err);
      showError(err);
      iter;
    endif;
    showDescs(r);

    ok = Cdm_create(r: err);
    if not ok;
      showError(err);
      iter;
    endif;

    if mode = MODE_CHANGE;
      msg = 'Customer demographic ' + keyText(r) + ' changed.';
    else;
      msg = 'Customer demographic ' + keyText(r) + ' created.';
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
    r likeds(CustCustDemo_t) const;
  end-pi;

  DCUSTID = r.CustomerId;
  DTYPEID = r.CustomerTypeId;
  showDescs(r);
end-proc;

//------------------------------------------------------------------------------
// screenToRec - move the detail panel into a record (format checks)
//------------------------------------------------------------------------------
dcl-proc screenToRec;
  dcl-pi *n ind;
    r   likeds(CustCustDemo_t);
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  r.CustomerId = DCUSTID;
  r.CustomerTypeId = DTYPEID;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// showDescs - refresh descriptions of referenced records
//------------------------------------------------------------------------------
dcl-proc showDescs;
  dcl-pi *n;
    r likeds(CustCustDemo_t) const;
  end-pi;

  NCUSTID = Cdm_CustomerIdDesc(r.CustomerId);
  NTYPEID = Cdm_CustomerTypeIdDesc(r.CustomerTypeId);
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
    when err.field = 'CustomerId';
      dspInd.fldErr(1) = *on;
    when err.field = 'CustomerTypeId';
      dspInd.fldErr(2) = *on;
  endsl;
end-proc;

//------------------------------------------------------------------------------
// keyText - printable key for messages
//------------------------------------------------------------------------------
dcl-proc keyText;
  dcl-pi *n varchar(60);
    r likeds(CustCustDemo_t) const;
  end-pi;

  return %trim(r.CustomerId) + '/' + %trim(r.CustomerTypeId);
end-proc;
