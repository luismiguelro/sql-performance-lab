# Benchmark Results — SQL Performance Lab

**Database:** Pharmaceutical distributor ERP (anonymized)
**Environment:** SQL Server 2022, local instance, cold cache (`DBCC DROPCLEANBUFFERS`)

---

## Query 01 — Sales by Product (date function anti-pattern)

| Metric | BEFORE | AFTER |
|---|---|---|
| Elapsed time | 5,056 ms | 2,053 ms |
| CPU time | 233 ms | 812 ms* |
| Logical reads (SalesOrders) | 2,856 | 19 |
| Logical reads (SalesOrderLines) | 59,618 | 60,418 |
| Total logical reads | 62,474 | 60,437 |
| Rows returned | 12,448 | 12,448 |
| Index seek? | ❌ Full scan | ✅ Index Seek |

*CPU increased due to parallel plan (4 threads); elapsed time is the user-facing metric.

**Anti-pattern:** `WHERE YEAR(OrderDate) = 2024 AND MONTH(OrderDate) = 1`
wraps the indexed column in a function → SQL Server cannot use the index → full scan on 169K rows.

**Fix:** Explicit date range `>= '2024-01-01' AND < '2024-02-01'` + covering index
`IX_SalesOrders_Date_Covering (OrderDate, IsCancelled) INCLUDE (OrderId, CustomerId, SalesRepId)`.
SalesOrders logical reads dropped **99.3%** (2,856 → 19). Elapsed time **-59%**.
SalesOrderLines still full-scans (no index on OrderId + IsCancelled yet).

---

## Query 02 — Overdue Accounts by Sales Rep (correlated subquery)

| Metric | BEFORE | AFTER |
|---|---|---|
| Elapsed time | 343 ms | — |
| CPU time | 139 ms | — |
| Logical reads (AccountsReceivable) | 4,958 | — |
| Logical reads (SalesReps) | 2 | — |
| Total logical reads | 4,960 | — |
| Rows returned | 1,781 | — |

**Anti-pattern:** Correlated subquery in SELECT executes one lookup per row.
SQL Server partially optimized this case internally; the gain post-optimization
will be in plan stability and reads reduction, not raw elapsed time.

---

## Query 03 — Monthly Inventory Close (SELECT * + unindexed filter)

| Metric | BEFORE | AFTER |
|---|---|---|
| Elapsed time | 6,121 ms | — |
| CPU time | 172 ms | — |
| Logical reads | 1,543 | — |
| Rows returned | 49,780 | — |
| Index seek? | ❌ Full scan | — |

**Anti-pattern:** `SELECT *` fetches all 14 columns + filter on unindexed
`IsClosed` and `PeriodId` columns → full scan on 506K rows, heavy sort.

---

## Summary

| Query | Before (ms) | After (ms) | Improvement |
|---|---|---|---|
| Q1 — Sales by Product | 5,056 | 2,053 | -59% elapsed / -99.3% reads on SalesOrders |
| Q2 — Overdue Accounts | 343 | — | — |
| Q3 — Inventory Close | 6,121 | — | — |
