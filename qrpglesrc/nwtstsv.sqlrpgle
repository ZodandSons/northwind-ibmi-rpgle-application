**free
//==============================================================================
// NWTSTSV - Unit-test fixture helper (dynamic SQL)
//
// Used only by the iRPGUnit test suites in QTESTSRC to create and remove
// fixture rows. Never bound into production programs.
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endmod;

/copy QCPYSRC,NWTSTPR

dcl-s gStmt  varchar(2048);
dcl-s gState char(5) inz('00000');

//------------------------------------------------------------------------------
dcl-proc Tst_exec export;
  dcl-pi *n ind;
    statement varchar(2048) const;
  end-pi;

  gStmt = statement;
  exec sql execute immediate :gStmt;
  gState = sqlstate;
  return sqlcode >= 0;
end-proc;

//------------------------------------------------------------------------------
dcl-proc Tst_count export;
  dcl-pi *n int(10);
    statement varchar(2048) const;
  end-pi;

  dcl-s result int(10) inz(-1);

  gStmt = statement;
  exec sql prepare TSTCNTS from :gStmt;
  if sqlcode < 0;
    gState = sqlstate;
    return -1;
  endif;
  exec sql declare TSTCNTC cursor for TSTCNTS;
  exec sql open TSTCNTC;
  if sqlcode < 0;
    gState = sqlstate;
    return -1;
  endif;
  exec sql fetch TSTCNTC into :result;
  gState = sqlstate;
  if sqlcode <> 0;
    result = -1;
  endif;
  exec sql close TSTCNTC;
  return result;
end-proc;

//------------------------------------------------------------------------------
dcl-proc Tst_lastState export;
  dcl-pi *n char(5);
  end-pi;

  return gState;
end-proc;
