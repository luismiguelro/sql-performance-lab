-- ============================================================
-- Index: covering index for date-range queries on SalesOrders
--
-- Problem: IX_SalesOrders_ExistingIndex has OrderDate
--   at key_ordinal 2 (after OrderId). A filter on OrderDate alone
--   cannot use this index as a seek → full clustered scan.
--
-- Fix: new index with OrderDate as the leading key + IsCancelled as
--   the filter key + INCLUDE for columns needed by Q01.
-- ============================================================

CREATE NONCLUSTERED INDEX IX_SalesOrders_Date_Covering
ON SalesOrders (OrderDate, IsCancelled)
INCLUDE (OrderId, CustomerId, SalesRepId);
GO
