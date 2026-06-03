-- ============================================================
-- Setup: public-facing views over the ERP schema
-- Run this once on the target database before executing
-- any queries in sql/before/ or sql/after/
-- ============================================================

CREATE OR ALTER VIEW SalesOrders AS
SELECT Numero AS OrderId, Fecha AS OrderDate, Nit AS CustomerId,
       Vendedor AS SalesRepId, Anulado AS IsCancelled
FROM SalesOrders;
GO

CREATE OR ALTER VIEW SalesOrderLines AS
SELECT Numero AS OrderId, IdReferencia AS ProductId,
       RTRIM(REPLACE(REPLACE(Descripcion, 'MEDICK', ''), '  ', ' ')) AS ProductName,
       Cantidad AS Quantity, Valor AS UnitPrice, Descuento AS Discount,
       IVA AS TaxRate, Anulado AS IsCancelled
FROM SalesOrderLines;
GO

CREATE OR ALTER VIEW AccountsReceivable AS
SELECT Numero AS DocumentId, Nit AS CustomerId, idvendedor AS SalesRepId,
       Fecha AS IssueDate, Vencimiento AS DueDate, SaldoInicial AS OriginalAmount,
       Debitos AS Charges, Creditos AS Payments, Anulado AS IsCancelled,
       BalanceDue
FROM AccountsReceivable;
GO

CREATE OR ALTER VIEW SalesReps AS
SELECT IdVendedor AS SalesRepId, Nombres AS FullName
FROM SalesReps;
GO

CREATE OR ALTER VIEW InventoryMonthlyBalance AS
SELECT mes AS PeriodId, idbodega AS WarehouseId, lote AS BatchId,
       idreferencia AS ProductId, saldoinicial AS OpeningBalance,
       compras AS Purchases, facturas AS Sales, entradas AS Inflows,
       salidas AS Outflows, notasclientes AS CustomerReturns,
       costoponderado AS WeightedCost, costoinicial AS OpeningCost,
       saldofinal AS ClosingBalance, cerrado AS IsClosed
FROM InventoryMonthlyBalance;
GO
