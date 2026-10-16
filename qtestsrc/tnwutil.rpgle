**free
//==============================================================================
// TNWUTIL - iRPGUnit tests for service program NWUTIL
//
// Build: RUCRTRPG TSTPGM(NWAPP/TNWUTIL) SRCFILE(NWAPP/QTESTSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
// Run:   RUCALLTST TSTPGM(NWAPP/TNWUTIL)
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso);

/include QINCLUDE,TESTCASE
/copy QCPYSRC,NWUTILPR

//------------------------------------------------------------------------------
// Dates
//------------------------------------------------------------------------------
dcl-proc test_toDateIso export;
  dcl-s d date;
  assert(NwU_toDate('2026-10-13': d): 'ISO date rejected');
  assert(d = d'2026-10-13': 'ISO date converted wrongly');
end-proc;

dcl-proc test_toDateUsa export;
  dcl-s d date;
  assert(NwU_toDate('10/13/2026': d): 'USA date rejected');
  assert(d = d'2026-10-13': 'USA date converted wrongly');
end-proc;

dcl-proc test_toDateCompact export;
  dcl-s d date;
  assert(NwU_toDate('20261013': d): 'YYYYMMDD date rejected');
  assert(d = d'2026-10-13': 'YYYYMMDD date converted wrongly');
end-proc;

dcl-proc test_toDateBlankIsNull export;
  dcl-s d date inz(d'2000-01-01');
  assert(NwU_toDate(' ': d): 'Blank date rejected');
  assert(d = NW_NULL_DATE: 'Blank date should give NW_NULL_DATE');
end-proc;

dcl-proc test_toDateInvalid export;
  dcl-s d date;
  assert(not NwU_toDate('2026-02-30': d): 'Feb 30 accepted');
  assert(not NwU_toDate('13/45/2026': d): 'Month 13 accepted');
  assert(not NwU_toDate('tomorrow': d): 'Text accepted as a date');
end-proc;

dcl-proc test_fromDate export;
  aEqual('2026-10-13': NwU_fromDate(d'2026-10-13'));
  aEqual(' ': NwU_fromDate(NW_NULL_DATE));
end-proc;

//------------------------------------------------------------------------------
// Text wrapping
//------------------------------------------------------------------------------
dcl-proc test_wrapShortText export;
  dcl-s lines like(NwTextLine_t) dim(12);
  iEqual(1: NwU_wrapText('Cheeses': lines));
  aEqual('Cheeses': lines(1));
  aEqual(' ': lines(2));
end-proc;

dcl-proc test_wrapAndJoinRoundTrip export;
  dcl-s lines like(NwTextLine_t) dim(12);
  dcl-s text  varchar(1024);
  dcl-s count int(10);
  dcl-s i     int(10);

  text = 'Education includes a BA in psychology from Colorado State University '
       + 'in 1970. She also completed The Art of the Cold Call. Nancy is a member '
       + 'of Toastmasters International.';
  count = NwU_wrapText(text: lines);
  assert(count = 3: 'Expected 3 lines, got ' + %char(count));
  for i = 1 to count;
    assert(%len(%trimr(lines(i))) <= NW_TEXT_WIDTH: 'Line too long');
    assert(%subst(lines(i): 1: 1) <> ' ': 'Line starts with a blank');
  endfor;
  aEqual(text: NwU_joinText(lines));
end-proc;

dcl-proc test_wrapLongWord export;
  dcl-s lines like(NwTextLine_t) dim(12);
  dcl-s word  varchar(120);

  // 104 characters without a single blank: must be split hard at 76
  word = 'http://www.example.com/1234567890/'
       + 'a-very-long-path-without-any-blanks-that-cannot-be-word-wrapped-at-all';
  iEqual(2: NwU_wrapText(word: lines));
  iEqual(NW_TEXT_WIDTH: %len(%trimr(lines(1))));
  aEqual(word: %trimr(lines(1)) + %trimr(lines(2)));
end-proc;

dcl-proc test_joinSkipsBlankLines export;
  dcl-s lines like(NwTextLine_t) dim(12);
  lines(1) = 'First';
  lines(3) = 'Third';
  aEqual('First Third': NwU_joinText(lines));
end-proc;

//------------------------------------------------------------------------------
// Errors
//------------------------------------------------------------------------------
dcl-proc test_setErrorReturnsOff export;
  dcl-ds err likeds(NwError_t) inz;
  assert(not NwU_setError(err: NWE_REQUIRED: 'CompanyName': 'Required.'):
         'setError should return *OFF');
  aEqual(NWE_REQUIRED: err.code);
  aEqual('CompanyName': err.field);
  aEqual('Required.': err.text);
  NwU_clearError(err);
  aEqual(' ': err.code);
end-proc;

dcl-proc test_sqlErrorMapping export;
  dcl-ds err likeds(NwError_t) inz;

  assert(not NwU_sqlError(err: '23505': -803: 'dup': 'Create'): 'should return *OFF');
  aEqual(NWE_DUPLICATE: err.code);
  NwU_sqlError(err: '23504': -532: 'fk': 'Delete');
  aEqual(NWE_REFERENCE: err.code);
  NwU_sqlError(err: '42704': -204: 'TABLE not found': 'Open');
  aEqual(NWE_SQL: err.code);
  aEqual('42704': err.sqlState);
  iEqual(-204: err.sqlCode);
end-proc;

dcl-proc test_sqlOk export;
  assert(NwU_sqlOk('00000'): '00000 should be OK');
  assert(NwU_sqlOk('01004'): 'Warnings should be OK');
  assert(not NwU_sqlOk('02000'): 'Not found is not OK');
  assert(not NwU_sqlOk('23505'): 'Errors are not OK');
end-proc;

dcl-proc test_center export;
  aEqual('   abc': NwU_center('abc': 10));
  aEqual('abcdefghij': NwU_center('abcdefghij': 10));
end-proc;
