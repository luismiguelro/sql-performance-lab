-- ============================================================
-- QUERY 03 — Monthly inventory close (SLOW version)
-- Anti-pattern 1: SELECT * fetches all 14 columns, most unused
-- Anti-pattern 2: filter on unindexed columns → full scan
--                 on InventoryMonthlyBalance (506K rows)
-- ============================================================

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT *
FROM InventoryMonthlyBalance
WHERE IsClosed  = 1
  AND PeriodId >= '202401'
  AND PeriodId <= '202412'
ORDER BY PeriodId, WarehouseId, ProductId;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
