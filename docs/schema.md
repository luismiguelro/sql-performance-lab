# Public Schema — SQL Performance Lab

All queries in this repo run against views defined in `sql/setup/create_views.sql`.
The views map generic English names to the underlying Spanish-named ERP columns,
and strip internal brand strings from product names.

The raw ERP table names are not published to avoid exposing internal schema.

---

## Views

### SalesOrders
Cabecera de facturas de venta. 169,000 rows.

| Column | Type | Description |
|---|---|---|
| `OrderId` | int | Invoice/order identifier |
| `OrderDate` | datetime | Order date (indexed via IX_SalesOrders_Date_Covering) |
| `CustomerId` | varchar | Customer identifier |
| `SalesRepId` | int | Sales representative identifier |
| `IsCancelled` | bit | 1 = voided/cancelled |

---

### SalesOrderLines
Líneas de detalle de cada factura. 900,000 rows.

| Column | Type | Description |
|---|---|---|
| `OrderId` | int | FK → SalesOrders.OrderId |
| `ProductId` | varchar | Product/SKU identifier |
| `ProductName` | varchar | Product description (brand-stripped) |
| `Quantity` | decimal | Units sold |
| `UnitPrice` | decimal | Price per unit |
| `Discount` | decimal | Discount percentage |
| `TaxRate` | decimal | VAT rate |
| `IsCancelled` | bit | 1 = line voided |

---

### AccountsReceivable
Documentos de cuentas por cobrar. 182,000 rows.

| Column | Type | Description |
|---|---|---|
| `DocumentId` | varchar | Document identifier |
| `CustomerId` | varchar | Customer identifier |
| `SalesRepId` | int | Sales representative identifier |
| `IssueDate` | datetime | Document issue date |
| `DueDate` | datetime | Payment due date |
| `OriginalAmount` | decimal | Original billed amount |
| `Charges` | decimal | Additional charges |
| `Payments` | decimal | Payments received |
| `IsCancelled` | bit | 1 = voided |
| `BalanceDue` | decimal | Persisted computed column: `OriginalAmount + Charges - Payments` |

---

### SalesReps
Tabla maestra de vendedores.

| Column | Type | Description |
|---|---|---|
| `SalesRepId` | int | Sales representative identifier |
| `FullName` | varchar | Full name |

---

### InventoryMonthlyBalance
Saldos de inventario por bodega y período. 506,000 rows.

| Column | Type | Description |
|---|---|---|
| `PeriodId` | char(6) | Year-month key (`YYYYMM`) |
| `WarehouseId` | int | Warehouse identifier |
| `BatchId` | varchar | Batch/lot number |
| `ProductId` | varchar | Product/SKU identifier |
| `OpeningBalance` | decimal | Units at period open |
| `Purchases` | decimal | Units purchased |
| `Sales` | decimal | Units sold |
| `Inflows` | decimal | Other inflows |
| `Outflows` | decimal | Other outflows |
| `CustomerReturns` | decimal | Units returned by customers |
| `WeightedCost` | decimal | Weighted average cost |
| `OpeningCost` | decimal | Cost at period open |
| `ClosingBalance` | decimal | Units at period close |
| `IsClosed` | bit | 1 = period closed |

---

## Indexes created by this project

| Index | Table | Keys | INCLUDE |
|---|---|---|---|
| `IX_SalesOrders_Date_Covering` | SalesOrders | `OrderDate, IsCancelled` | `OrderId, CustomerId, SalesRepId` |
| `IX_AccountsReceivable_Balance_Date` | AccountsReceivable | `BalanceDue, DueDate, IsCancelled` | `DocumentId, CustomerId, SalesRepId, IssueDate, OriginalAmount, Charges, Payments` |
| `IX_InventoryMonthlyBalance_Period_Sorted` | InventoryMonthlyBalance | `PeriodId, IsClosed, WarehouseId, ProductId` | `BatchId, OpeningBalance, Purchases, Sales, Inflows, Outflows, ClosingBalance` |

Scripts: `sql/indexes/`
