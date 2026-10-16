**free
//==============================================================================
// NWUTIL - Northwind general utility service program
//
// Error handling, date conversion and text wrapping helpers shared by all
// data-access service programs and display programs.
//
// Build: CRTRPGMOD MODULE(NWAPP/NWUTIL) SRCFILE(NWAPP/QRPGLESRC)
//        CRTSRVPGM SRVPGM(NWAPP/NWUTIL) SRCFILE(NWAPP/QSRVSRC)
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

/copy QCPYSRC,NWUTILPR

//------------------------------------------------------------------------------
dcl-proc NwU_clearError export;
  dcl-pi *n;
    err likeds(NwError_t);
  end-pi;

  clear err;
end-proc;

//------------------------------------------------------------------------------
dcl-proc NwU_setError export;
  dcl-pi *n ind;
    err   likeds(NwError_t);
    code  char(7) const;
    field varchar(30) const;
    text  varchar(132) const;
  end-pi;

  clear err;
  err.code  = code;
  err.field = field;
  err.text  = text;
  return *off;
end-proc;

//------------------------------------------------------------------------------
dcl-proc NwU_sqlError export;
  dcl-pi *n ind;
    err      likeds(NwError_t);
    sqlState char(5) const;
    sqlCode  int(10) const;
    sqlMsg   varchar(512) const;
    context  varchar(60) const;
  end-pi;

  clear err;
  err.code     = NWE_SQL;
  err.sqlState = sqlState;
  err.sqlCode  = sqlCode;

  select;
    when sqlState = '23505';
      err.code = NWE_DUPLICATE;
      err.text = 'A record with this key already exists.';
    when sqlState = '23504';
      err.code = NWE_REFERENCE;
      err.text = 'Record is in use by other data and cannot be deleted.';
    when sqlState = '23503';
      err.code = NWE_REFERENCE;
      err.text = 'A referenced record does not exist.';
    when sqlState = '23513';
      err.code = NWE_RANGE;
      err.text = 'Value not allowed by a check constraint: ' + sqlMsg;
    when sqlState = '57033' or sqlCode = -913;
      err.text = 'Record is locked by another job. Try again later.';
    other;
      err.text = context + ' failed (SQLSTATE ' + sqlState + '): ' + sqlMsg;
  endsl;

  return *off;
end-proc;

//------------------------------------------------------------------------------
dcl-proc NwU_sqlOk export;
  dcl-pi *n ind;
    sqlState char(5) const;
  end-pi;

  return %subst(sqlState: 1: 2) = '00' or %subst(sqlState: 1: 2) = '01';
end-proc;

//------------------------------------------------------------------------------
dcl-proc NwU_toDate export;
  dcl-pi *n ind;
    text   char(10) const;
    result date;
  end-pi;

  dcl-s work varchar(10);

  work = %trim(text);
  if %len(work) = 0;
    result = NW_NULL_DATE;
    return *on;
  endif;

  monitor;
    select;
      when %len(work) = 10 and %subst(work: 3: 1) = '/';
        result = %date(work: *usa);
      when %len(work) = 10 and %subst(work: 5: 1) = '-';
        result = %date(work: *iso);
      when %len(work) = 8 and %check('0123456789': work) = 0;
        result = %date(work: *iso0);
      other;
        return *off;
    endsl;
  on-error;
    return *off;
  endmon;

  return *on;
end-proc;

//------------------------------------------------------------------------------
dcl-proc NwU_fromDate export;
  dcl-pi *n char(10);
    value date const;
  end-pi;

  if value = NW_NULL_DATE;
    return *blanks;
  endif;
  return %char(value: *iso);
end-proc;

//------------------------------------------------------------------------------
dcl-proc NwU_wrapText export;
  dcl-pi *n int(10);
    text  varchar(1024) const;
    lines like(NwTextLine_t) dim(12);
  end-pi;

  dcl-s work  varchar(1024);
  dcl-s pos   int(10) inz(1);
  dcl-s len   int(10);
  dcl-s brk   int(10);
  dcl-s i     int(10);
  dcl-s count int(10) inz(0);

  clear lines;
  work = %trim(text);
  len  = %len(work);

  dow pos <= len and count < NW_TEXT_LINES;
    if len - pos + 1 <= NW_TEXT_WIDTH;
      count += 1;
      lines(count) = %subst(work: pos);
      leave;
    endif;

    // Find the last blank that lets the line end within the width
    brk = 0;
    for i = (pos + NW_TEXT_WIDTH) downto (pos + 1);
      if %subst(work: i: 1) = ' ';
        brk = i;
        leave;
      endif;
    endfor;

    count += 1;
    if brk = 0;                                  // one long word: hard split
      lines(count) = %subst(work: pos: NW_TEXT_WIDTH);
      pos += NW_TEXT_WIDTH;
    else;
      lines(count) = %subst(work: pos: brk - pos);
      pos = brk + 1;
    endif;

    dow pos <= len and %subst(work: pos: 1) = ' ';
      pos += 1;
    enddo;
  enddo;

  return count;
end-proc;

//------------------------------------------------------------------------------
dcl-proc NwU_joinText export;
  dcl-pi *n varchar(1024);
    lines like(NwTextLine_t) dim(12) const;
  end-pi;

  dcl-s result varchar(1024) inz('');
  dcl-s i      int(10);

  for i = 1 to NW_TEXT_LINES;
    if lines(i) <> *blanks;
      if %len(result) > 0;
        result += ' ';
      endif;
      result += %trim(lines(i));
    endif;
  endfor;

  return result;
end-proc;

//------------------------------------------------------------------------------
dcl-proc NwU_center export;
  dcl-pi *n varchar(80);
    text  varchar(80) const;
    width int(10) const;
  end-pi;

  dcl-s blanks char(80) inz(*blanks);
  dcl-s work   varchar(80);
  dcl-s pad    int(10);

  work = %trim(text);
  if %len(work) >= width or width > 80;
    return work;
  endif;
  pad = %div(width - %len(work): 2);
  if pad = 0;
    return work;
  endif;
  return %subst(blanks: 1: pad) + work;
end-proc;
