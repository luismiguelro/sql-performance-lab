-- ============================================================
-- QUERY 02 — Overdue accounts by sales rep (SLOW version)
-- Anti-patterns:
--   1. CONVERT on DueDate in WHERE → non-sargable, forces full
--      scan on 182K rows even if an index existed on DueDate
--   2. Correlated subquery in SELECT → one lookup against
--      SalesReps per row returned
-- ============================================================

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    ar.SalesRepId,
    (SELECT sr.FullName FROM SalesReps sr WHERE sr.SalesRepId = ar.SalesRepId) AS SalesRepName,
    ar.CustomerId,
    ar.DocumentId,
    ar.IssueDate,
    ar.DueDate,
    ar.OriginalAmount,
    ar.Charges,
    ar.Payments,
    (ar.OriginalAmount + ar.Charges - ar.Payments)              AS BalanceDue,
    DATEDIFF(DAY, ar.DueDate, GETDATE())                        AS DaysOverdue
FROM AccountsReceivable ar
WHERE ar.IsCancelled = 0
  AND CONVERT(varchar(10), ar.DueDate, 23) < CONVERT(varchar(10), GETDATE(), 23)
  AND (ar.OriginalAmount + ar.Charges - ar.Payments) > 0
ORDER BY DaysOverdue DESC, ar.SalesRepId;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
