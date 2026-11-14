USE testTemporal
GO
CREATE SCHEMA Sales 
GO

CREATE TABLE Sales.SalesOrder 
(  
    SalesOrderId int NOT NULL CONSTRAINT PKSalesOrder PRIMARY KEY, 
    Data varchar(30) NOT NULL,    --just the piece of data I will be changing 

    ValidStartTime datetime2 (7) GENERATED ALWAYS AS ROW START, 
    ValidEndTime datetime2 (7) GENERATED ALWAYS AS ROW END, 
    PERIOD FOR SYSTEM_TIME (ValidStartTime, ValidEndTime) 
)  
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Sales.SalesOrderHistory)); --<-- Named the history table, didn't previously exist
GO

--Now, modify data in the transaction
BEGIN TRANSACTION 
INSERT INTO  Sales.SalesOrder (SalesOrderID, Data) 
VALUES (1,'Original');

SELECT * 
FROM    Sales.SalesOrder; 
SELECT * 
FROM   Sales.SalesOrderHistory;

--second batch, see the change
UPDATE Sales.SalesOrder 
SET    Data = 'First Change' 
WHERE  SalesOrderID = 1

SELECT * 
FROM    Sales.SalesOrder; 
SELECT * 
FROM   Sales.SalesOrderHistory;

--third batch, see the change
UPDATE Sales.SalesOrder 
SET    Data = 'Second Change' 
WHERE  SalesOrderID = 1

SELECT * 
FROM    Sales.SalesOrder; 
SELECT * 
FROM   Sales.SalesOrderHistory;

--fourth batch, see the change
UPDATE Sales.SalesOrder 
SET    Data = 'Third Change' 
WHERE  SalesOrderID = 1

SELECT * 
FROM    Sales.SalesOrder; 
SELECT * 
FROM   Sales.SalesOrderHistory;

--Finally commit it
COMMIT;

SELECT * 
FROM    Sales.SalesOrder; 
SELECT * 
FROM   Sales.SalesOrderHistory;

-------------------------------------------------
--Run together

--See the data at the starttime:
DECLARE @sysstarttime DATETIME2(7) = (SELECT MAX(validStartTime) FROM Sales.SalesOrder)

SELECT @sysstarttime AS LatestTime

SELECT * 
FROM   Sales.SalesOrder FOR SYSTEM_TIME  AS OF @sysstarttime;

--and over all time
SELECT * 
FROM   Sales.SalesOrder FOR SYSTEM_TIME ALL;


SELECT * 
FROM    Sales.SalesOrder; 
SELECT *, CASE WHEN ValidStartTime = ValidEndTime THEN 0 ELSE 1 END AS VisibleToTemporalArguments
FROM   Sales.SalesOrderHistory;

-------------------------------------------------


--When the start and end times are the same, the rows never show up in history, but they are preserved in your history table.

