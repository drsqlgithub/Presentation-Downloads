USE AdventureWorks2025;
GO

--

--just plain old COUNT(*)

SET SHOWPLAN_TEXT ON;
GO
SELECT COUNT(*)
FROM   Demo.SalesOrderDetail;
GO
SET SHOWPLAN_TEXT OFF;
GO
SET STATISTICS IO ON;
GO
SELECT COUNT(*)
FROM   Demo.SalesOrderDetail;
GO
SET STATISTICS IO OFF;
GO

--show the index
sp_helpindex '[Demo].[SalesOrderDetail]'

--not the one I initially expected



--show the IO from just querying all the data (is the same)
SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO
SELECT SalesOrderDetailID, ProductId
FROM   Demo.Salesorderdetail;
GO
SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO



--Simple Literal (will expand in the last item)

--Same as COUNT(*). Look at the plan
SET SHOWPLAN_TEXT ON;
GO
SELECT COUNT(1)
FROM   Demo.SalesOrderDetail;
GO
SET SHOWPLAN_TEXT OFF;
GO
SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO
SELECT COUNT(1)
FROM   Demo.SalesOrderDetail;
GO
SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO


--Reminder, SalesOrderDetailId is the the primary key of the table
EXEC sp_helpindex '[Demo].[SalesOrderDetail]'


SET SHOWPLAN_TEXT ON;
GO
SELECT COUNT(SalesOrderDetailId)
FROM   Demo.SalesOrderDetail;
GO
SET SHOWPLAN_TEXT OFF;
GO
SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO
SELECT COUNT(SalesOrderDetailId)
FROM   Demo.SalesOrderDetail;
GO
SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO

--Change the to have two parts. Now what if we are using part of the PK?
--part of the key for the table?
ALTER TABLE Demo.SalesOrderDetail
  DROP CONSTRAINT [PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID];

ALTER TABLE Demo.[SalesOrderDetail] 
  ADD CONSTRAINT [PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID]
     PRIMARY KEY CLUSTERED
     (
        [SalesOrderID] ASC,
        [SalesOrderDetailID] ASC
     );

--REminder, this will increase the size of the scanned data for things that use
--a clustered index scan because this key is larger.


--any not null column
SET SHOWPLAN_TEXT ON;
GO
SELECT COUNT(SalesOrderId)
FROM   Demo.SalesOrderDetail;

GO
SET SHOWPLAN_TEXT OFF;
GO
SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO
SELECT COUNT(SalesOrderId)
FROM   Demo.SalesOrderDetail;

SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO



--what about any not-nullable column?
SET SHOWPLAN_TEXT ON;
GO
SELECT COUNT(rowguid)
FROM   Demo.SalesOrderDetail;

SELECT COUNT(UnitPrice)
FROM   Demo.SalesOrderDetail;

GO
SET SHOWPLAN_TEXT OFF;
GO
SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO
SELECT COUNT(rowguid)
FROM   Demo.SalesOrderDetail;

SELECT COUNT(UnitPrice)
FROM   Demo.SalesOrderDetail;

GO
SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO



---Now, a column that allows NULLs (starts out, no index)

SET SHOWPLAN_TEXT ON;
GO
SELECT COUNT([CarrierTrackingNumber])
FROM   Demo.SalesOrderDetail;
GO
SET SHOWPLAN_TEXT OFF;
GO
SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO
SELECT COUNT([CarrierTrackingNumber])
FROM   Demo.SalesOrderDetail;
GO
SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO

--create index, try again
CREATE INDEX CarrierTrackingNumber ON Demo.SalesOrderDetail(CarrierTrackingNumber);





--then non-simple,. literal expressions.
SET SHOWPLAN_TEXT ON;
GO
SELECT COUNT(1+1)
FROM   Demo.SalesOrderDetail;

SELECT COUNT(COALESCE(NULL,2))
FROM   Demo.SalesOrderDetail;

DECLARE @value INT = 1
SELECT COUNT(@value)
FROM   Demo.SalesOrderDetail;

SET @value = NULL;

SELECT COUNT(@value)
FROM   Demo.Salesorderdetail;
GO
SET SHOWPLAN_TEXT OFF;
GO
SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO
SELECT COUNT(1+1)
FROM   Demo.SalesOrderDetail;

SELECT COUNT(COALESCE(NULL,2))
FROM   Demo.SalesOrderDetail;

DECLARE @value INT = 1
SELECT COUNT(@value)
FROM   Demo.SalesOrderDetail;

SET @value = NULL;

SELECT COUNT(@value)
FROM   Demo.Salesorderdetail;
GO
SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO





