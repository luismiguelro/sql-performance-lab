# Anti-patterns and Fixes

Three SQL Server anti-patterns extracted from production queries on a pharmaceutical distributor ERP.
Each section shows the anti-pattern, why it breaks index use, and the targeted fix.

---

## Pattern 1 — Function wrapper on an indexed column

**Anti-pattern:**
```sql
WHERE YEAR(OrderDate) = 2024 AND MONTH(OrderDate) = 1
```

**Why it breaks index use:**
SQL Server evaluates `YEAR(OrderDate)` row by row. Even if there is an index on `OrderDate`,
the optimizer cannot map the function output to an index key — it must scan the full table.

**Fix — explicit date range:**
```sql
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2024-02-01'
```

With `OrderDate` as the leading key of a covering index, the optimizer issues an Index Seek
directly to the target month. Logical reads on SalesOrders: **2,856 → 19 (−99.3%)**.

**When this applies:** any scalar function wrapping a column in a WHERE clause
(`YEAR()`, `MONTH()`, `DATEPART()`, `CAST()`, `CONVERT()`, `ISNULL()`, `UPPER()`, etc.).

---

## Pattern 2 — Non-sargable predicate on a low-selectivity column

**Anti-pattern:**
```sql
WHERE CONVERT(varchar(10), DueDate, 23) < CONVERT(varchar(10), GETDATE(), 23)
  AND (OriginalAmount + Charges - Payments) > 0
```

**Why it breaks index use:**
`CONVERT` on `DueDate` makes the date predicate non-sargable (same as Pattern 1).
A direct `DueDate < GETDATE()` would be sargable but still nearly useless here:
**99.7% of rows have DueDate in the past** — the date filter eliminates almost nothing.
The real selective predicate is the balance expression, but SQL Server cannot index
an expression unless it is stored as a persisted computed column.

**Fix — persisted computed column as leading index key:**
```sql
-- Step 1: store the balance expression so it can be indexed
ALTER TABLE AccountsReceivable
  ADD BalanceDue AS (OriginalAmount + Charges - Payments) PERSISTED;

-- Step 2: index with BalanceDue as the leading key
CREATE NONCLUSTERED INDEX IX_AccountsReceivable_Balance_Date
ON AccountsReceivable (BalanceDue, DueDate, IsCancelled)
INCLUDE (...);
```

The optimizer now seeks directly to rows where `BalanceDue > 0` (1,872 of 182,070) before
checking the date. Also replaced the correlated subquery in SELECT with a `LEFT JOIN`.
Logical reads: **4,958 → 38 (−99.2%)**.

**When this applies:** any computed expression in WHERE that has high actual selectivity
but cannot be indexed because it is not a stored column (balance, age, duration, score, etc.).

---

## Pattern 3 — SELECT * with an implicit Sort

**Anti-pattern:**
```sql
SELECT *
FROM InventoryMonthlyBalance
WHERE IsClosed = 1 AND PeriodId >= '202401' AND PeriodId <= '202412'
ORDER BY PeriodId, WarehouseId, ProductId;
```

**Why it is slow:**
1. `SELECT *` forces SQL Server to read all 14 columns on every page, including 10 wide numeric
   columns that the consumer doesn't need — maximizing page reads.
2. No index on `IsClosed` or `PeriodId` → full clustered scan on 506K rows to find 49K.
3. `ORDER BY` introduces a Sort operator that buffers and sorts 49K rows after the scan.

**Fix — explicit column list + covering sorted index:**
```sql
SELECT PeriodId, WarehouseId, BatchId, ProductId,
       OpeningBalance, Purchases, Sales, Inflows, Outflows,
       ClosingBalance, WeightedCost
FROM InventoryMonthlyBalance
WHERE IsClosed = 1 AND PeriodId >= '202401' AND PeriodId <= '202412'
ORDER BY PeriodId, WarehouseId, ProductId;
```

```sql
CREATE NONCLUSTERED INDEX IX_InventoryMonthlyBalance_Period_Sorted
ON InventoryMonthlyBalance (PeriodId, IsClosed, WarehouseId, ProductId)
INCLUDE (BatchId, OpeningBalance, Purchases, Sales,
         Inflows, Outflows, ClosingBalance);
```

The index keys match the `ORDER BY` order exactly → SQL Server reads rows pre-sorted,
and the Sort operator is **eliminated entirely**. Narrower pages (11 of 14 columns stored)
reduce logical reads by 50%. Server time: **7,024 ms → 16 ms (−99.8%)**.

**When this applies:** any query with `SELECT *` + `ORDER BY` where the sort columns
can be made into index keys (covering sorted index pattern).

---

## Counterintuitive finding — an index that reduces reads but increases elapsed time

While tuning Q1, a covering index on `SalesOrderLines(OrderId, IsCancelled)` was tested:

| | Logical reads | Elapsed |
|---|---|---|
| Without index | 60,418 | 2,053 ms |
| With index | 7,450 | 4,119 ms |

Reads dropped **88%** but elapsed *doubled*. Cause: the optimizer switched from a
parallel **Hash Match** (9 threads, broad scan) to a **Nested Loop** (2,256 sequential seeks,
single-threaded). For a query returning 12,000 rows across a wide month, the parallel
plan wins on wall-clock time despite higher page reads.

**Rule of thumb:** benchmark elapsed time, not just logical reads.
An index that benefits point lookups can harm range scans on the same column.
