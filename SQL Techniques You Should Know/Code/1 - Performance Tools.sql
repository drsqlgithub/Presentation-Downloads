USE AdventureWorks2025
GO

--For more detail, Hugo Kornelis site: https://sqlserverfast.com/epr/
--Grant Fritchey Book: https://www.amazon.com/Server-2025-Query-Performance-Tuning/dp/B0FHJT2736/


--Estimated plans


/*
Highlight, show plan Query/Display Estimated Excution Plan menu (or Ctrl+l)
*/

SELECT Product.ProductID,
       Product.Name,
       Product.ProductNumber,
       Product.MakeFlag,
       Product.FinishedGoodsFlag,
       Product.Color
FROM   Sales.SalesOrderDetail
		 JOIN Production.Product
			ON Sales.SalesOrderDetail.ProductID = Production.Product.ProductID;
GO

/*
Run to get a textual plan
*/

SET SHOWPLAN_TEXT ON;
GO
SELECT Product.ProductID,
       Product.Name,
       Product.ProductNumber,
       Product.MakeFlag,
       Product.FinishedGoodsFlag,
       Product.Color
FROM   Sales.SalesOrderDetail
		 JOIN Production.Product
			ON Sales.SalesOrderDetail.ProductID = Production.Product.ProductID;
GO
SET SHOWPLAN_TEXT OFF;
GO

--you can also get the plan in XML using SET SHOWPLAN_XML ON; and in a grid it basically 
--will open up into the aforementioned viewer.

/*
Execution Information
*/

--highlight, choose Query/Include Actual Execution Plan (or Ctrl+M), then execute
--then show the Live Query Plan
SELECT Product.ProductID,
       Product.Name,
       Product.ProductNumber,
       Product.MakeFlag,
       Product.FinishedGoodsFlag,
       Product.Color
INTO #temp
FROM   Sales.SalesOrderDetail
		 JOIN Production.Product
			ON Sales.SalesOrderDetail.ProductID = Production.Product.ProductID;

--actual plan in text
SET STATISTICS PROFILE ON;
GO
SELECT Product.ProductID,
       Product.Name,
       Product.ProductNumber,
       Product.MakeFlag,
       Product.FinishedGoodsFlag,
       Product.Color
INTO #temp2
FROM   Sales.SalesOrderDetail
		 JOIN Production.Product
			ON Sales.SalesOrderDetail.ProductID = Production.Product.ProductID;
GO
SET STATISTICS PROFILE OFF;


--IO and CPU time needed to execute.
SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO
SELECT Product.ProductID,
       Product.Name,
       Product.ProductNumber,
       Product.MakeFlag,
       Product.FinishedGoodsFlag,
       Product.Color
FROM   Sales.SalesOrderDetail
		 JOIN Production.Product
			ON Sales.SalesOrderDetail.ProductID = Production.Product.ProductID;
GO
SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO


