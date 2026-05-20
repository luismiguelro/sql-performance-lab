-- ============================================================
-- Index: covering + pre-sorted index for monthly inventory queries
--
-- Problem: SELECT * forces reading all 14 columns on every page.
--   The clustered PK (PeriodId, WarehouseId, BatchId, ProductId)
--   has no IsClosed filter key, so 506K rows are scanned to
--   find the 49K matching the period filter, then sorted.
--   Result: 1,543 logical reads + Sort operator on 49K rows.
--
-- Fix: nonclustered index with (PeriodId, IsClosed) as leading
--   keys — allows a tight range seek. Adding WarehouseId and
--   ProductId as additional keys pre-sorts the rows in ORDER BY
--   order → Sort operator eliminated entirely.
--   INCLUDE stores only the 7 numeric columns the query needs,
--   making pages narrower → 766 reads instead of 1,543.
-- ============================================================

CREATE NONCLUSTERED INDEX IX_InventoryMonthlyBalance_Period_Sorted
ON InventoryMonthlyBalance (PeriodId, IsClosed, WarehouseId, ProductId)
INCLUDE (BatchId, OpeningBalance, Purchases, Sales,
         Inflows, Outflows, ClosingBalance);
GO
