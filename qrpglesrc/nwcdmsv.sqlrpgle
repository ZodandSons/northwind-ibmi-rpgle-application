**free
//==============================================================================
// NWCDMSV - Data access service program for CUSTOMERCUSTOMERDEMO
//
// All SQL for CUSTOMERCUSTOMERDEMO lives here. Display programs and unit tests call
// these procedures through prototypes in QCPYSRC,NWCDMPR.
//
// Build: CRTSQLRPGI OBJ(NWAPP/NWCDMSV) SRCFILE(NWAPP/QRPGLESRC)
//          OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)
//        CRTSRVPGM SRVPGM(NWAPP/NWCDMSV) SRCFILE(NWAPP/QSRVSRC)
//          BNDSRVPGM((NWAPP/NWUTIL))
//==============================================================================
ctl-opt nomain option(*srcstmt:*nodebugio) datfmt(*iso) timfmt(*iso);

exec sql set option commit = *none, naming = *sys, datfmt = *iso,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy QCPYSRC,NWUTILPR
/copy QCPYSRC,NWCDMPR

// Host variables for the list cursor
dcl-s  gPos like(CustCustDemo_t.CustomerId);
dcl-ds gRow likeds(CustCustDemo_t) inz;

// List cursor (declared before any statement that references it)
exec sql declare CDMLIST cursor for
  select CUSTOMERID,
         CUSTOMERTYPEID
    from CUSTOMERCUSTOMERDEMO
   where CUSTOMERID >= :gPos
   order by CUSTOMERID, CUSTOMERTYPEID
   for read only;

//------------------------------------------------------------------------------
// Cdm_get - retrieve one row by key
//------------------------------------------------------------------------------
dcl-proc Cdm_get export;
  dcl-pi *n ind;
    pCustomerId like(CustCustDemo_t.CustomerId) const;
    pCustomerTypeId like(CustCustDemo_t.CustomerTypeId) const;
    rec likeds(CustCustDemo_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(CustCustDemo_t) inz;

  NwU_clearError(err);

  exec sql
    select CUSTOMERID,
           CUSTOMERTYPEID
      into :r
      from CUSTOMERCUSTOMERDEMO
     where CUSTOMERID = :pCustomerId and CUSTOMERTYPEID = :pCustomerTypeId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CustomerId': 'Customer demographic not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Retrieve customer demographic');
  endif;

  rec = r;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cdm_exists - *ON if the key exists
//------------------------------------------------------------------------------
dcl-proc Cdm_exists export;
  dcl-pi *n ind;
    pCustomerId like(CustCustDemo_t.CustomerId) const;
    pCustomerTypeId like(CustCustDemo_t.CustomerTypeId) const;
  end-pi;

  dcl-s found int(10) inz(0);

  exec sql select 1 into :found
             from CUSTOMERCUSTOMERDEMO
            where CUSTOMERID = :pCustomerId and CUSTOMERTYPEID = :pCustomerTypeId
            fetch first 1 row only;
  return sqlcode = 0 and found = 1;
end-proc;

//------------------------------------------------------------------------------
// Cdm_validate - business rules for create/update
//------------------------------------------------------------------------------
dcl-proc Cdm_validate export;
  dcl-pi *n ind;
    rec    likeds(CustCustDemo_t) const;
    action char(1) const;
    err    likeds(NwError_t);
  end-pi;

  dcl-ds v likeds(CustCustDemo_t) inz;
  dcl-s  found int(10);

  NwU_clearError(err);
  v = rec;

  // Key checks
  if action = ACTION_CREATE;
    if %len(%trim(v.CustomerId)) = 0;
      return NwU_setError(err: NWE_REQUIRED: 'CustomerId': 'Customer is required.');
    endif;
    if %len(%trim(v.CustomerTypeId)) = 0;
      return NwU_setError(err: NWE_REQUIRED: 'CustomerTypeId': 'Customer type is required.');
    endif;
    if %len(%trim(v.CustomerId)) > 0;
      found = 0;
      exec sql select 1 into :found from CUSTOMERS
                where CUSTOMERID = :v.CustomerId fetch first 1 row only;
      if found <> 1;
        return NwU_setError(err: NWE_REFERENCE: 'CustomerId':
                            'Customer not found.');
      endif;
    else;
      return NwU_setError(err: NWE_REQUIRED: 'CustomerId': 'Customer is required.');
    endif;
    if %len(%trim(v.CustomerTypeId)) > 0;
      found = 0;
      exec sql select 1 into :found from CUSTOMERDEMOGRAPHICS
                where CUSTOMERTYPEID = :v.CustomerTypeId fetch first 1 row only;
      if found <> 1;
        return NwU_setError(err: NWE_REFERENCE: 'CustomerTypeId':
                            'Customer type not found.');
      endif;
    else;
      return NwU_setError(err: NWE_REQUIRED: 'CustomerTypeId': 'Customer type is required.');
    endif;
    if Cdm_exists(v.CustomerId: v.CustomerTypeId);
      return NwU_setError(err: NWE_DUPLICATE: 'CustomerId':
                          'Customer demographic already exists.');
    endif;
  endif;


  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cdm_create - validate and insert
//------------------------------------------------------------------------------
dcl-proc Cdm_create export;
  dcl-pi *n ind;
    rec likeds(CustCustDemo_t);
    err likeds(NwError_t);
  end-pi;

  dcl-ds r likeds(CustCustDemo_t) inz;

  if not Cdm_validate(rec: ACTION_CREATE: err);
    return *off;
  endif;
  r = rec;

  exec sql insert into CUSTOMERCUSTOMERDEMO
                  (CUSTOMERID, CUSTOMERTYPEID)
                  values(:r.CustomerId, :r.CustomerTypeId);

  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Create customer demographic');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cdm_delete - delete by key (FK violations reported as "in use")
//------------------------------------------------------------------------------
dcl-proc Cdm_delete export;
  dcl-pi *n ind;
    pCustomerId like(CustCustDemo_t.CustomerId) const;
    pCustomerTypeId like(CustCustDemo_t.CustomerTypeId) const;
    err likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql delete from CUSTOMERCUSTOMERDEMO
            where CUSTOMERID = :pCustomerId and CUSTOMERTYPEID = :pCustomerTypeId;

  if sqlcode = 100;
    return NwU_setError(err: NWE_NOTFOUND: 'CustomerId': 'Customer demographic not found.');
  elseif not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Delete customer demographic');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cdm_openList - open list cursor at a starting position
//   Ordered by CUSTOMERID, CUSTOMERTYPEID; blank/zero position lists everything.
//------------------------------------------------------------------------------
dcl-proc Cdm_openList export;
  dcl-pi *n ind;
    positionTo like(CustCustDemo_t.CustomerId) const;
    err        likeds(NwError_t);
  end-pi;

  NwU_clearError(err);
  exec sql close CDMLIST;                      // ignore "not open"

  gPos = positionTo;

  exec sql open CDMLIST;
  if not NwU_sqlOk(sqlstate);
    return sqlFail(err: 'Open customer demographic list');
  endif;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cdm_fetchNext - next row of the list; *OFF at end
//------------------------------------------------------------------------------
dcl-proc Cdm_fetchNext export;
  dcl-pi *n ind;
    rec likeds(CustCustDemo_t);
  end-pi;

  exec sql fetch next from CDMLIST into :gRow;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return *off;
  endif;
  rec = gRow;
  return *on;
end-proc;

//------------------------------------------------------------------------------
// Cdm_closeList
//------------------------------------------------------------------------------
dcl-proc Cdm_closeList export;
  exec sql close CDMLIST;
end-proc;

//------------------------------------------------------------------------------
// Cdm_CustomerIdDesc - description of the customer
//------------------------------------------------------------------------------
dcl-proc Cdm_CustomerIdDesc export;
  dcl-pi *n varchar(50);
    value like(CustCustDemo_t.CustomerId) const;
  end-pi;

  dcl-s v    like(CustCustDemo_t.CustomerId);
  dcl-s desc varchar(50) inz('');

  v = value;
  if %len(%trim(v)) = 0;
    return '';
  endif;
  exec sql select CAST(COMPANYNAME AS VARCHAR(50)) into :desc
             from CUSTOMERS
            where CUSTOMERID = :v
            fetch first 1 row only;
  if sqlcode = 100 or not NwU_sqlOk(sqlstate);
    return '';
  endif;
  return %trimr(desc);
end-proc;

//------------------------------------------------------------------------------
// Cdm_CustomerTypeIdDesc - description of the customer type
//------------------------------------------------------------------------------
dcl-proc Cdm_CustomerTypeIdDesc export;
  dcl-pi *n varchar(50);
    value like(CustCustDemo_t.CustomerTypeId) const;
  end-pi;

  dcl-s v    like(CustCustDemo_t.CustomerTypeId);
  dcl-s desc varchar(50) inz('');

  v = value;
  if %len(%trim(v)) = 0;
    return '';
  endif;
  exec sql select CAST(CAST(COALESCE(CUSTOMERDESC, '') AS VARCHAR(50)) AS VARCHAR(50)) into :desc
             from CUSTOMERDEMOGRAPHICS
            where CUSTOMERTYPEID = :v
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
