USE AdventureWorks2025
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Demo')
    EXEC ('CREATE SCHEMA Demo;')
GO
DROP TABLE IF EXISTS Demo.SalesOrderDetail;

SELECT SalesOrderID,
       SalesOrderDetailID,
       CarrierTrackingNumber,
       OrderQty,
       ProductID,
       SpecialOfferID,
       UnitPrice,
       UnitPriceDiscount,
       rowguid,
       ModifiedDate
INTO Demo.SalesOrderDetail
FROM Sales.SalesOrderDetail;
GO

ALTER TABLE Demo.[SalesOrderDetail]
ADD
	[LineTotal]  AS (isnull(([UnitPrice]*
                     ((1.0)-[UnitPriceDiscount]))*[OrderQty],(0.0)));

--Different PK, since this is actually an identity column
ALTER TABLE Demo.[SalesOrderDetail]
  ADD CONSTRAINT [PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID] 
     PRIMARY KEY CLUSTERED 
     (
  	[SalesOrderDetailID] ASC
     );

CREATE UNIQUE NONCLUSTERED INDEX 
       [AK_SalesOrderDetail_rowguid] ON [Demo].[SalesOrderDetail]
(
	[rowguid] ASC
);

CREATE NONCLUSTERED INDEX 
       [IX_SalesOrderDetail_ProductID] ON [Demo].[SalesOrderDetail]
(
	[ProductID] ASC
);