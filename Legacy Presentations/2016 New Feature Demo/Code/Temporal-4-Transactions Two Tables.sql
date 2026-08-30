USE TestTemporal
GO
CREATE TABLE Sales.SalesOrderDetail
(
	SalesOrderId INT REFERENCES Sales.SalesOrder(SalesOrderId),
	SalesOrderDetailLineNumber INT,
	PRIMARY KEY (SalesOrderId,SalesOrderDetailLineNumber),
    ValidStartTime datetime2 (7) GENERATED ALWAYS AS ROW START, 
    ValidEndTime datetime2 (7) GENERATED ALWAYS AS ROW END, 
    PERIOD FOR SYSTEM_TIME (ValidStartTime, ValidEndTime) 
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Sales.SalesOrderDetailHistory)); --<-- Named the history table, didn't previously exist
GO

BEGIN TRANSACTION

INSERT INTO Sales.SalesOrderDetail (SalesOrderId, SalesOrderDetailLineNumber)
VALUES (1,1)

WAITFOR DELAY '00:00:01' -- 1 second

INSERT INTO Sales.SalesOrderDetail (SalesOrderId, SalesOrderDetailLineNumber)
VALUES (1,2)

WAITFOR DELAY '00:00:01' -- 1 second

UPDATE Sales.SalesOrder 
SET    Data = 'Final Change' 
WHERE  SalesOrderID = 1

COMMIT TRANSACTION;

SELECT *
FROM   Sales.SalesOrder
SELECT *
FROM   Sales.SalesOrderHistory
SELECT *
FROM   Sales.SalesOrderDetail
SELECT *
FROM   Sales.SalesOrderDetailHistory





--Finally, let's drop the table using the new super cool: DROP TABLE IF EXISTS
DROP TABLE IF EXISTS Sales.SalesOrder;


--have to sever the system versioning, then drop both tables:
ALTER table Sales.SalesOrder  SET (SYSTEM_VERSIONING = OFF);
GO
DROP TABLE IF EXISTS Sales.SalesOrderHistory
DROP TABLE IF EXISTS Sales.SalesOrder
GO

--Note: this works across multiple temporal tables as well. So if you have Sales.SalesOrder and 
-- Sales.SalesOrderDetail, both temporal, and both modified 
--in the transaction, their transaction times would be synced to thetime the transaction started.