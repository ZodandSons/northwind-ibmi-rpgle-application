**free
//==============================================================================
// WRKETR - Work with Employee Territories
//
// IBM i "Work with" panel for table EMPLOYEETERRITORIES:
//   List (subfile) with position-to, options 3=Copy 4=Delete 5=Display,
//   F6=Create, F5=Refresh, confirm-delete panel, detail panel.
//
// All database access is through service program NWETRSV.
//==============================================================================
ctl-opt main(Main) dftactgrp(*no) actgrp('NWAPP') bnddir('NWBNDDIR')
        option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f WRKETRD workstn usropn indds(dspInd)
        sfile(SFL01: rrn1) sfile(SFL02: rrn2);

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWETRPR

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

// Key of one employee territory
dcl-ds Key_t qualified template;
  EmployeeId like(EmpTerritory_t.EmployeeId);
  TerritoryId like(EmpTerritory_t.TerritoryId);
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

  if not %open(WRKETRD);
    open WRKETRD;
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

  close WRKETRD;
end-proc;

//------------------------------------------------------------------------------
// loadList - (re)load the list subfile from the position-to value
//------------------------------------------------------------------------------
dcl-proc loadList;
  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;

  dspInd.sflDsp    = *off;
  dspInd.sflDspCtl = *off;
  dspInd.sflClr    = *on;
  write CTL01;
  dspInd.sflClr = *off;
  rrn1 = 0;
  savedPos = C1POS;

  if not Etr_openList(C1POS: err);
    msg = err.text;
  else;
    dow rrn1 < NW_SFL_MAX and Etr_fetchNext(r);
      S1OPT = ' ';
      S1EMPID = r.EmployeeId;
      S1NEMPID = Etr_EmployeeIdDesc(r.EmployeeId);
      S1TERID = r.TerritoryId;
      S1NTERID = Etr_TerritoryIdDesc(r.TerritoryId);
      H1EMPID = r.EmployeeId;
      H1TERID = r.TerritoryId;
      rrn1 += 1;
      write SFL01;
    enddo;
    Etr_closeList();
  endif;

  dspInd.sflDsp    = (rrn1 > 0);
  dspInd.sflDspCtl = *on;
  dspInd.sflEnd    = *on;
  C1RRN = 1;
  if rrn1 = 0 and msg = '';
    msg = 'No employee territories found. Press F6 to create one.';
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
  dow not %eof(WRKETRD) and not gExit;
    key.EmployeeId = H1EMPID;
    key.TerritoryId = %trimr(H1TERID);
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
  dcl-ds r   likeds(EmpTerritory_t) inz;
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
    if not Etr_get(dltKey(i).EmployeeId: dltKey(i).TerritoryId: r: err);
      r.EmployeeId = dltKey(i).EmployeeId;
      r.TerritoryId = dltKey(i).TerritoryId;
    endif;
    X2OPT = '4';
    X2EMPID = r.EmployeeId;
    X2NEMPID = Etr_EmployeeIdDesc(r.EmployeeId);
    X2TERID = r.TerritoryId;
    X2NTERID = Etr_TerritoryIdDesc(r.TerritoryId);
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
    if Etr_delete(dltKey(i).EmployeeId: dltKey(i).TerritoryId: err);
      deleted += 1;
    else;
      failed += 1;
      lastErr = err.text;
    endif;
  endfor;

  if failed = 0;
    msg = %char(deleted) + ' employee territory(s) deleted.';
  else;
    msg = %char(deleted) + ' deleted, ' + %char(failed) + ' not deleted: ' + lastErr;
  endif;
end-proc;

//------------------------------------------------------------------------------
// showDetail - create / change / copy / display one employee territory
//   Returns *ON when the database was changed.
//------------------------------------------------------------------------------
dcl-proc showDetail;
  dcl-pi *n ind;
    mode char(1) const;
    key  likeds(Key_t) const;
  end-pi;

  dcl-ds r   likeds(EmpTerritory_t) inz;
  dcl-ds err likeds(NwError_t) inz;
  dcl-s  ok  ind;

  if mode <> MODE_CREATE;
    if not Etr_get(key.EmployeeId: key.TerritoryId: r: err);
      msg = err.text;
      return *off;
    endif;
  endif;

  select;
    when mode = MODE_CREATE;
      PTITLE = NwU_center('Create Employee territory': %len(PTITLE));
      PINSTR = 'Type information, press Enter.';
    when mode = MODE_CHANGE;
      PTITLE = NwU_center('Change Employee territory': %len(PTITLE));
      PINSTR = 'Type changes, press Enter.';
    when mode = MODE_COPY;
      PTITLE = NwU_center('Copy Employee territory': %len(PTITLE));
      PINSTR = 'Type information for the new employee territory, press Enter.';
    other;
      PTITLE = NwU_center('Display Employee territory': %len(PTITLE));
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

    ok = Etr_create(r: err);
    if not ok;
      showError(err);
      iter;
    endif;

    if mode = MODE_CHANGE;
      msg = 'Employee territory ' + keyText(r) + ' changed.';
    else;
      msg = 'Employee territory ' + keyText(r) + ' created.';
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
    r likeds(EmpTerritory_t) const;
  end-pi;

  DEMPID = r.EmployeeId;
  DTERID = r.TerritoryId;
  showDescs(r);
end-proc;

//------------------------------------------------------------------------------
// screenToRec - move the detail panel into a record (format checks)
//------------------------------------------------------------------------------
dcl-proc screenToRec;
  dcl-pi *n ind;
    r   likeds(EmpTerritory_t);
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  r.EmployeeId = DEMPID;
  r.TerritoryId = %trimr(DTERID);
  return *on;
end-proc;

//------------------------------------------------------------------------------
// showDescs - refresh descriptions of referenced records
//------------------------------------------------------------------------------
dcl-proc showDescs;
  dcl-pi *n;
    r likeds(EmpTerritory_t) const;
  end-pi;

  NEMPID = Etr_EmployeeIdDesc(r.EmployeeId);
  NTERID = Etr_TerritoryIdDesc(r.TerritoryId);
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
    when err.field = 'EmployeeId';
      dspInd.fldErr(1) = *on;
    when err.field = 'TerritoryId';
      dspInd.fldErr(2) = *on;
  endsl;
end-proc;

//------------------------------------------------------------------------------
// keyText - printable key for messages
//------------------------------------------------------------------------------
dcl-proc keyText;
  dcl-pi *n varchar(60);
    r likeds(EmpTerritory_t) const;
  end-pi;

  return %char(r.EmployeeId) + '/' + %trim(r.TerritoryId);
end-proc;
