-- ============================================================
-- QUERY 02 — Overdue accounts by sales rep (SLOW version)
-- Anti-pattern: correlated subquery in SELECT executes one
--   lookup against SalesReps per row in AccountsReceivable
--   → N reads for 182K rows
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
    (ar.OriginalAmount + ar.Charges - ar.Payments)       AS BalanceDue,
    DATEDIFF(DAY, ar.DueDate, GETDATE())                 AS DaysOverdue
FROM AccountsReceivable ar
WHERE ar.IsCancelled = 0
  AND ar.DueDate < GETDATE()
  AND (ar.OriginalAmount + ar.Charges - ar.Payments) > 0
ORDER BY DaysOverdue DESC, ar.SalesRepId;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
