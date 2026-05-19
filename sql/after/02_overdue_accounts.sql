-- ============================================================
-- QUERY 02 — Overdue accounts by sales rep (OPTIMIZED version)
-- Fixes:
--   1. Direct date comparison replaces CONVERT(varchar, DueDate)
--      → SQL Server can seek on IX_AccountsReceivable_Balance_Date
--   2. JOIN replaces correlated subquery
--      → single pass over SalesReps instead of N lookups
--   3. BalanceDue persisted computed column as index leading key
--      → seek skips the 181K rows with zero balance immediately,
--        reducing from 181K candidates to 1,872 matching rows
-- ============================================================

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    ar.SalesRepId,
    sr.FullName                                                 AS SalesRepName,
    ar.CustomerId,
    ar.DocumentId,
    ar.IssueDate,
    ar.DueDate,
    ar.OriginalAmount,
    ar.Charges,
    ar.Payments,
    ar.BalanceDue,
    DATEDIFF(DAY, ar.DueDate, GETDATE())                        AS DaysOverdue
FROM AccountsReceivable ar
LEFT JOIN SalesReps sr ON sr.SalesRepId = ar.SalesRepId
WHERE ar.IsCancelled = 0
  AND ar.DueDate < GETDATE()
  AND ar.BalanceDue > 0
ORDER BY DaysOverdue DESC, ar.SalesRepId;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
