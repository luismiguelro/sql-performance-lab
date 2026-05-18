-- ============================================================
-- QUERY 01 — Sales by product (OPTIMIZED version)
-- Fix: explicit date range replaces YEAR()/MONTH() wrapper
--   → SQL Server can now seek on the new covering index
-- Index created: IX_SalesOrders_Date_Covering (OrderDate, IsCancelled)
--   INCLUDE (OrderId, CustomerId, SalesRepId)
-- ============================================================

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    o.OrderId,
    o.OrderDate,
    o.CustomerId,
    o.SalesRepId,
    l.ProductId,
    l.ProductName,
    l.Quantity,
    l.UnitPrice,
    l.Discount,
    l.TaxRate,
    (l.Quantity * l.UnitPrice) AS LineTotal
FROM SalesOrders o
INNER JOIN SalesOrderLines l ON o.OrderId = l.OrderId
WHERE o.OrderDate  >= '2024-01-01'
  AND o.OrderDate  <  '2024-02-01'
  AND o.IsCancelled = 0
  AND l.IsCancelled = 0
ORDER BY o.OrderDate, l.ProductId;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
