# Northwind Traders for IBM i

A green-screen Northwind application for the `NORTHWIND` Db2 for i schema in
`create-northwind-schema.sql` / `insert-data-northwind-db2.sql`. It is written in
fully free-form RPGLE and SQLRPGLE, with CLLE and DDS.

* **Service programs** hold all SQL and business rules, with one per table plus orders.
* **Display programs** are thin 5250 "Work with" panels that call the service programs.
* **iRPGUnit test suites** cover every service program.

## What's included

| Menu | Program | Display file | Service program | Test suite | Table |
|---|---|---|---|---|---|
| 1 | WRKCUST | WRKCUSTD | NWCUSTSV | TCUSTSV | CUSTOMERS |
| 2 | WRKEMP | WRKEMPD | NWEMPSV | TEMPSV | EMPLOYEES |
| 3 | WRKSUP | WRKSUPD | NWSUPSV | TSUPSV | SUPPLIERS |
| 4 | WRKCAT | WRKCATD | NWCATSV | TCATSV | CATEGORIES |
| 5 | WRKPRD | WRKPRDD | NWPRDSV | TPRDSV | PRODUCTS |
| 6 | WRKSHP | WRKSHPD | NWSHPSV | TSHPSV | SHIPPERS |
| 7 | WRKREG | WRKREGD | NWREGSV | TREGSV | REGION |
| 8 | WRKTER | WRKTERD | NWTERSV | TTERSV | TERRITORIES |
| 9 | WRKETR | WRKETRD | NWETRSV | TETRSV | EMPLOYEETERRITORIES |
| 10 | WRKDEM | WRKDEMD | NWDEMSV | TDEMSV | CUSTOMERDEMOGRAPHICS |
| 11 | WRKCDM | WRKCDMD | NWCDMSV | TCDMSV | CUSTOMERCUSTOMERDEMO |
| 20 | ORDENT | ORDENTD | NWORDSV | TORDSV | ORDERS + ORDERDETAILS (entry) |
| 21 | WRKORD | WRKORDD | NWORDSV | TORDSV | ORDERS + ORDERDETAILS (inquiry) |
| 90 | NWRUNTST | | | | runs every test suite |

Shared pieces:
* `NWUTIL` is a service program for errors, date conversion and text wrapping. Its tests are in `TNWUTIL`.
* `NWTSTSV` is a test-fixture helper used only by the tests.
* `NWMENU` (CLLE) and `NWMENUD` (DSPF) are the main menu.
* `NWBUILD` (CLLE) builds everything.
* `NWBNDDIR` is the binding directory.

`AGENTGUIDANCE` is not a Northwind business table, so it has no maintenance program.

## Folder layout = source files

```
qrpglesrc/  *.sqlrpgle  service programs (SQL)     *.rpgle  display programs, NWUTIL
qcpysrc/    *.rpgleinc  prototypes + record templates (one per service program)
qsrvsrc/    *.bnd       binder source (fixed signatures)
qddssrc/    *.dspf      display files
qcllesrc/   *.clle      NWMENU, NWBUILD, NWRUNTST
qtestsrc/   *.rpgle     iRPGUnit test suites
qsqlsrc/    nwidrst.sql identity-restart script (run once after loading data)
```

The folder names match the source physical files that NWBUILD creates, and
each file name matches its member name. You can therefore copy the members
into source files yourself, or build straight from the IFS with Code for IBM i
or BOB.

## Install

1. **Database.** Run the two Northwind scripts. Then run
   `qsqlsrc/nwidrst.sql` once. The data load inserts keys with `OVERRIDING
   SYSTEM VALUE`, which leaves the identity generators at 1. Without the restart,
   the first new order, product, supplier, category or shipper fails with a
   duplicate key.
   ```
   RUNSQLSTM SRCSTMF('/home/me/northwind-ibmi/qsqlsrc/nwidrst.sql') COMMIT(*NONE)
   ```
2. **Copy this folder to the IFS** in the root file system, for example
   `/home/me/northwind-ibmi`. The root file system is case-insensitive, which
   NWBUILD relies on.
3. **Bootstrap the build program**, then run it:
   ```
   CRTLIB NWAPP
   CRTSRCPF NWAPP/QCLLESRC RCDLEN(92)
   CPYFRMSTMF FROMSTMF('/home/me/northwind-ibmi/qcllesrc/nwbuild.clle') +
              TOMBR('/QSYS.LIB/NWAPP.LIB/QCLLESRC.FILE/NWBUILD.MBR') MBROPT(*REPLACE)
   CRTBNDCL NWAPP/NWBUILD SRCFILE(NWAPP/QCLLESRC)
   CALL NWAPP/NWBUILD PARM(('/home/me/northwind-ibmi' (*CHAR 128)) 'NWAPP' 'NORTHWIND')
   ```
   The `(*CHAR 128)` matters. A plain quoted literal on a command-line CALL is
   passed as only 32 bytes, so the rest of the 128-byte path parameter would
   contain junk.
   NWBUILD copies every stream file into a member and then compiles in this order:
   NWUTIL, the SQL service programs, the binding directory, the display files,
   the RPG programs, the CL programs and the tests. It sends a completion message
   with the error count. Failed steps are logged in the job log.
4. **Run:** `CALL NWAPP/NWMENU`. This adds NORTHWIND and NWAPP to the library list.
   You can pass a different data library as the parameter, for example
   `CALL NWAPP/NWMENU PARM(NWTEST)`. If you built into a library other than NWAPP,
   add it to the library list first.

Requirements:
* IBM i 7.3 or later (free-form RPG, `DCL-PROC`, CL subroutines).
* SQL Development Kit (`CRTSQLRPGI`).
* For the tests, [iRPGUnit](https://irpgunit.sourceforge.io/) in library `RPGUNIT`.

## Architecture

```
 NWMENU (CLLE)
   |-- WRKxxx  (RPGLE + DSPF)  --->  NWxxxSV  (SQLRPGLE)  --->  NORTHWIND.xxx
   |-- ORDENT  (RPGLE + DSPF)  --->  NWORDSV, NWCUSTSV, NWEMPSV, NWSHPSV, NWPRDSV
   '-- WRKORD  (RPGLE + DSPF)  --->  NWORDSV, NWCUSTSV
                                      all bind NWUTIL
```

* **Service program API.** Every table service program has the same shape:
  `xxx_get`, `xxx_exists`, `xxx_validate`, `xxx_create`, `xxx_update`, `xxx_delete`,
  `xxx_openList`, `xxx_fetchNext` and `xxx_closeList`. Some also have `xxx_nextKey`
  (user-entered integer keys) and `xxx_<Fk>Desc` (names of referenced rows). Each
  call returns `*ON`/`*OFF` and fills an `NwError_t` with a code, the field in
  error and a message. The panels use the field to highlight it.
* **Validation lives in the service program.** `create` and `update` always
  validate first, so a batch caller gets the same rules as a screen. The rules
  cover required fields, duplicate keys and foreign keys (with a readable
  message). They also cover the table's check constraints: price and stock `>= 0`,
  discontinued `0`/`1`, quantity `> 0` and discount `0-1`. Table-specific rules
  include hire date not before birth date and an employee not reporting to himself
  or herself.
* **Nulls.** Nullable columns are read with `COALESCE`. Blanks, zero (on
  foreign keys) and `0001-01-01` are written back as NULL with `NULLIF`.
* **CLOB columns.** These are `CATEGORIES.DESCRIPTION`, `EMPLOYEES.NOTES`,
  `SUPPLIERS.HOMEPAGE` and `CUSTOMERDEMOGRAPHICS.CUSTOMERDESC`. They are handled
  as `VARCHAR(1024)` and edited on a word-wrapped 12 x 76 text panel (F10). That
  holds about 900 characters, and the longest Northwind note is about 600.
* **Orders are transactional.** `NWORDSV` is compiled with `COMMIT=*CHG`.
  `Ord_create` writes the header (identity key returned with
  `SELECT ... FROM FINAL TABLE (INSERT ...)`) and all lines in one unit of work.
  Any failure triggers a `ROLLBACK`. `CREATE SCHEMA` journals the tables, which
  this requires.
* **Activation groups.** Programs run in `ACTGRP('NWAPP')` and service programs
  in `*CALLER`. SQL uses system naming, so the data library comes from the
  library list. You can run the application against a copy of NORTHWIND by
  changing the library list.

## The Work-with panels (IBM CUA style)

* **List panel.** It shows a position-to field and the options
  `2=Change 3=Copy 4=Delete 5=Display`. F3=Exit, F5=Refresh, F6=Create and
  F12=Cancel. "More.../Bottom" appears on the subfile, and messages show on line 24.
* **Detail panel.** One panel serves create, change, copy and display. Keys are
  protected in change mode, and the whole panel is protected in display mode.
  The field in error is shown in reverse image with the cursor on it.
  Descriptions of referenced rows (supplier name, category, region, manager)
  appear next to their IDs.
* **Confirm Delete panel.** It lists every row marked `4`. Enter deletes them and
  F12 cancels. A row still in use (for example a product on order lines) is
  reported, not deleted.
* **Junction tables.** Employee territories and customer demographic links have no
  change option, because both columns are the key.

## Order Entry (ORDENT)

1. **Header.** Enter the customer, employee, order and required dates (defaults are
   today and +14 days), ship via, freight and the ship-to address. F4 prompts
   Customer, Employee and Ship via. The ship-to address is copied from the
   customer when the customer changes, or when you press F5.
2. **Lines.** Up to 50 lines. Type a product (F4 prompts active products) and the
   name, price and quantity 1 are filled in. You can change the price, quantity
   and discount %. Enter validates and prices every line and shows the extended
   prices, subtotal, freight and total. Discontinued products, quantity 0,
   discounts over 100% and duplicate products are rejected on their line.
3. **Submit.** F10 creates the order and shows its number. F12 goes back to the
   header with the lines kept.

Inventory (`UNITSINSTOCK`) is not decremented. Northwind has no
allocation rule, and the table's `>= 0` check would reject back-orders. Add
it in `Ord_create` if you need it.

## Order Inquiry (WRKORD)

You can filter by customer (F4), order date range, open only (not shipped) and
"start at order number". The list is newest first and shows order date, shipped
date (or `Open`) and total. Option 5 shows the header, the lines with extended
prices, and the subtotal, freight and total.

## Unit tests

```
CALL NWAPP/NWRUNTST                     (all suites; also menu option 90)
RUCALLTST TSTPGM(NWAPP/TORDSV)          (one suite)
```

Each table suite tests these:
* create + get round trip of every column (including CLOBs and nullable dates)
* update
* delete
* delete or update of a missing row
* required fields and keys
* duplicate keys
* each foreign key (invalid value rejected, description lookup)
* each numeric range and allowed-values rule
* the position-to list
* table-specific rules

`TORDSV` tests these:
* pricing and rounding
* create/read/delete of a two-line order with totals
* rejecting deletes of shipped orders
* rollback behaviour: no order is written when a line is bad, there are no lines,
  or a product is duplicated
* every header and line rule
* ship-to defaults
* the inquiry filter

Fixture rows use reserved `ZZ...` keys and names and are removed before and after
each test. You can therefore run the suites against the live Northwind data.

The display programs contain no business logic. They move fields between the
screen and the service programs, and their behaviour is covered through those
service programs.

## Notes and assumptions

* `NWBUILD` compiles from source physical files. `RCDLEN(112)` gives 100 columns
  for RPG. DDS and CL use `RCDLEN(92)`.
* Test suites use `/include QINCLUDE,TESTCASE` and the iRPGUnit assertions
  `assert`, `aEqual`, `iEqual` and `fail`. They are compiled with `RUCRTRPG ... BNDSRVPGM(...)`.
* If `CPYFRMSTMF` produces garbled members, tag the stream files first. For example:
  `CHGATR OBJ('/home/me/northwind-ibmi') ATR(*CCSID) VALUE(1208) SUBTREE(*ALL)`.
