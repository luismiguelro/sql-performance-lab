# SQL Performance Lab

> Three real-world SQL Server anti-patterns identified, diagnosed, and fixed on a live pharmaceutical ERP — with cold-cache benchmarks and execution plans to back every claim.

---

## Results

| Query | Anti-pattern | Before | After | Improvement |
|---|---|---|---|---|
| Q1 — Sales by Product | `YEAR()`/`MONTH()` on indexed column | 5,056 ms / 62,474 reads | 2,053 ms / 60,437 reads | **−59% elapsed · −99.3% reads (SalesOrders)** |
| Q2 — Overdue Accounts | Non-sargable date + correlated subquery | 418 ms / 4,960 reads | 340 ms / 40 reads | **−19% elapsed · −99.2% reads** |
| Q3 — Inventory Close | `SELECT *` + unindexed filter + Sort | 7,024 ms / 1,543 reads | 16 ms* / 766 reads | **−99.8% server time · −50% reads · Sort eliminated** |

\* Pure server-side execution measured via `COUNT(*)`. Full result set (49K rows) adds ~5 s of network transfer to sqlcmd — not the database.

All benchmarks run on cold cache (`DBCC DROPCLEANBUFFERS + FREEPROCCACHE`), SQL Server 2022, local instance.

---

## Anti-patterns covered

### Q1 — Function wrapper on indexed column
```sql
-- BEFORE: YEAR() prevents index seek → full scan on 169K rows
WHERE YEAR(OrderDate) = 2024 AND MONTH(OrderDate) = 1

-- AFTER: explicit range → Index Seek on IX_SalesOrders_Date_Covering
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2024-02-01'
```
**Fix:** covering index with `OrderDate` as leading key. SalesOrders logical reads: 2,856 → 19.

---

### Q2 — Non-sargable date conversion + correlated subquery
```sql
-- BEFORE: CONVERT wraps the column → cannot use any index on DueDate
WHERE CONVERT(varchar(10), DueDate, 23) < CONVERT(varchar(10), GETDATE(), 23)

-- + correlated subquery executes one lookup per row
SELECT (SELECT FullName FROM SalesReps WHERE SalesRepId = ar.SalesRepId), ...
```
**Root cause:** 99.7% of rows have `DueDate` in the past — date-range indexes are nearly useless here. The selective filter is `BalanceDue > 0` (only 1,872 of 182,070 rows).

**Fix:** persisted computed column `BalanceDue AS (OriginalAmount + Charges - Payments)` as the **leading index key** → SQL Server seeks directly to the 1,872 matching rows, skipping 180K. Correlated subquery replaced with `LEFT JOIN`. Reads: 4,960 → 40.

---

### Q3 — `SELECT *` + unindexed filter + implicit Sort
```sql
-- BEFORE: reads all 14 columns (incl. 10 wide numeric cols) on every page
SELECT * FROM InventoryMonthlyBalance
WHERE IsClosed = 1 AND PeriodId >= '202401' AND PeriodId <= '202412'
ORDER BY PeriodId, WarehouseId, ProductId
```
**Fix:** explicit column list (11 of 14) + covering index with `(PeriodId, IsClosed, WarehouseId, ProductId)` as keys — pages are narrower (−50% reads) and pre-sorted in `ORDER BY` order → **Sort operator eliminated entirely**.

---

## Key insight: not every index helps every query

Adding a covering index on `SalesOrderLines(OrderId, IsCancelled)` for Q1 reduced logical reads by **88%** (60,418 → 7,450) but *increased* elapsed time from 2,053 ms to 4,119 ms.

Why: the optimizer switched from a **parallel Hash Match** (9 threads) to a **Nested Loop** (2,256 sequential seeks). For a month-wide scan returning 12K rows, the parallel plan wins on wall-clock time despite reading more pages. The same index *would* benefit point lookups (single order) where Nested Loop is the right choice.

This is why query hints exist — and why you should benchmark before shipping any index to production.

---

## Repository structure

```
sql/
├── before/       # Slow queries with anti-patterns (SET STATISTICS IO/TIME ON)
├── after/        # Optimized versions
└── indexes/      # Index DDL with reasoning comments

benchmark_results.md   # Full metrics table (before vs after, cold cache)
```

> **Schema note:** queries run against views that map generic names (`SalesOrders`, `AccountsReceivable`, `InventoryMonthlyBalance`) to the underlying ERP tables. The view DDL is not published to avoid exposing internal schema.

---

## Environment

| Item | Detail |
|---|---|
| Database engine | SQL Server 2022 (16.0.1175.1) |
| Data | Pharmaceutical distributor ERP, anonymized |
| Row counts | SalesOrders 169K · SalesOrderLines 900K · AccountsReceivable 182K · InventoryMonthlyBalance 506K |
| Benchmark method | Cold cache (`DBCC DROPCLEANBUFFERS + FREEPROCCACHE`) before each run |
| Metrics | `SET STATISTICS IO ON` + `SET STATISTICS TIME ON` |
