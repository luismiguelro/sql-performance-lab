# Benchmark Results — SQL Performance Lab

**Database:** Pharmaceutical distributor ERP (anonymized)
**Environment:** SQL Server 2022, local instance, cold cache (`DBCC DROPCLEANBUFFERS`)

---

## Query 01 — Sales by Product (date function anti-pattern)

| Metric | BEFORE | AFTER |
|---|---|---|
| Elapsed time | 5,056 ms | — |
| CPU time | 233 ms | — |
| Logical reads (SalesOrders) | 2,856 | — |
| Logical reads (SalesOrderLines) | 59,618 | — |
| Total logical reads | 62,474 | — |
| Rows returned | 12,448 | — |
| Index seek? | ❌ Full scan | — |

**Anti-pattern:** `WHERE YEAR(OrderDate) = 2024 AND MONTH(OrderDate) = 1`
wraps the indexed column in a function → SQL Server cannot use the index → full scan on 169K rows.

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

## Summary (to be completed after optimization)

| Query | Before (ms) | After (ms) | Improvement |
|---|---|---|---|
| Q1 — Sales by Product | 5,056 | — | — |
| Q2 — Overdue Accounts | 343 | — | — |
| Q3 — Inventory Close | 6,121 | — | — |
