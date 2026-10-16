-- ==========================================================================
-- NWIDRST - Restart the identity columns after loading the Northwind data
--
-- insert-data-northwind-db2.sql loads rows with OVERRIDING SYSTEM VALUE,
-- which does not move the identity generators. Without this script the
-- first new order, product, supplier, category or shipper would get key 1
-- and fail with a duplicate-key error (SQLSTATE 23505).
--
-- Run once, after the data load:
--   RUNSQLSTM SRCSTMF('/home/me/northwind-ibmi/qsqlsrc/nwidrst.sql')
--             COMMIT(*NONE) NAMING(*SQL)
-- ==========================================================================
ALTER TABLE NORTHWIND.ORDERS     ALTER COLUMN ORDERID    RESTART WITH 11078;
ALTER TABLE NORTHWIND.CATEGORIES ALTER COLUMN CATEGORYID RESTART WITH 9;
ALTER TABLE NORTHWIND.SUPPLIERS  ALTER COLUMN SUPPLIERID RESTART WITH 30;
ALTER TABLE NORTHWIND.PRODUCTS   ALTER COLUMN PRODUCTID  RESTART WITH 78;
ALTER TABLE NORTHWIND.SHIPPERS   ALTER COLUMN SHIPPERID  RESTART WITH 4;
