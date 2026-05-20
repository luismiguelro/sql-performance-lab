-- ============================================================
-- QUERY 03 — Monthly inventory close (OPTIMIZED version)
-- Fixes:
--   1. Explicit column list replaces SELECT *
--      → only 10 columns fetched instead of 14
--   2. Covering index IX_InventoryMonthlyBalance_Period_Covering
--      (PeriodId, IsClosed) INCLUDE (all selected columns)
--      → SQL Server reads the slim nonclustered index,
--        skipping the wide clustered pages entirely
-- ============================================================

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    PeriodId,
    WarehouseId,
    BatchId,
    ProductId,
    OpeningBalance,
    Purchases,
    Sales,
    Inflows,
    Outflows,
    ClosingBalance,
    IsClosed
FROM InventoryMonthlyBalance
WHERE IsClosed  = 1
  AND PeriodId >= '202401'
  AND PeriodId <= '202412'
ORDER BY PeriodId, WarehouseId, ProductId;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
