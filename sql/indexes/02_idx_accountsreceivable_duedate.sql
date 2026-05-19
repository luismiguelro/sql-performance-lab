-- ============================================================
-- Index: persisted computed column + covering index for Q02
--
-- Problem: 99.7% of AccountsReceivable rows have DueDate < GETDATE(),
--   so a date-range index has near-zero selectivity (181K of
--   182K rows pass). The real filter is the balance calculation
--   (OriginalAmount + Charges - Payments) > 0, which reduces to
--   only 1,872 rows — but it's a derived expression, not indexable.
--
-- Fix:
--   Step 1 — Persisted computed column so the balance is stored:
--     ALTER TABLE AccountsReceivable ADD BalanceDue AS
--       (OriginalAmount + Charges - Payments) PERSISTED;
--
--   Step 2 — Index with BalanceDue as leading key:
--     SQL Server can now seek directly to rows with BalanceDue > 0
--     (1,872 rows) before touching the date filter, skipping 180K rows.
-- ============================================================

-- Step 1: persisted computed column (run once)
ALTER TABLE AccountsReceivable ADD BalanceDue AS (OriginalAmount + Charges - Payments) PERSISTED;
GO

-- Step 2: covering index — BalanceDue as leading key
CREATE NONCLUSTERED INDEX IX_AccountsReceivable_Balance_Date
ON AccountsReceivable (BalanceDue, DueDate, IsCancelled)
INCLUDE (DocumentId, CustomerId, SalesRepId, IssueDate, OriginalAmount, Charges, Payments);
GO
