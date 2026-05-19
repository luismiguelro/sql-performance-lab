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

## Query 02 — Overdue Accounts by Sales Rep (non-sargable date + correlated subquery)

| Metric | BEFORE | AFTER |
|---|---|---|
| Elapsed time | 418 ms | 340 ms |
| CPU time | 153 ms | 0 ms |
| Logical reads (AccountsReceivable) | 4,958 | 38 |
| Logical reads (SalesReps) | 2 | 2 |
| Total logical reads | 4,960 | 40 |
| Rows returned | 1,868 | 1,872 |
| Index seek? | ❌ Full scan (scan count 9) | ✅ Index Seek (scan count 1) |

**Anti-patterns:**
1. `CONVERT(varchar(10), DueDate, 23)` en el WHERE → non-sargable, fuerza full scan sobre 182K filas
2. Correlated subquery en SELECT → lookup a SalesReps por cada fila devuelta

**Fix:**
- Columna calculada persistida: `BalanceDue AS (OriginalAmount + Charges - Payments) PERSISTED`
- Índice `IX_AccountsReceivable_Balance_Date (BalanceDue, DueDate, IsCancelled) INCLUDE (...)` con BalanceDue como leading key: SQL Server hace seek directo a las 1,872 filas con saldo, saltándose 180K filas con balance cero
- LEFT JOIN reemplaza la correlated subquery
- Direct date comparison replaces `CONVERT(varchar)`

Logical reads: **-99.2%** (4,958 → 38). Scan count: 9 → 1.

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
| Q2 — Overdue Accounts | 418 | 340 | -19% elapsed / -99.2% reads (4,958 → 38) |
| Q3 — Inventory Close | 6,121 | — | — |
