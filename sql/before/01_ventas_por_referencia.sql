-- ============================================================
-- QUERY 01 — Sales by product (SLOW version)
-- Anti-pattern: wrapping OrderDate in YEAR() / MONTH()
--   prevents index seek → full scan on SalesOrders (169K rows)
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
WHERE YEAR(o.OrderDate)  = 2024
  AND MONTH(o.OrderDate) = 1
  AND o.IsCancelled = 0
  AND l.IsCancelled = 0
ORDER BY o.OrderDate, l.ProductId;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
