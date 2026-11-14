USE SequenceDemos
GO
set nocount on
GO
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.Object1'))
		DROP TABLE Demo.Object1
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.Object2'))
		DROP TABLE Demo.Object2
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.Object3'))
		DROP TABLE Demo.Object3
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.Object_ALL_SEQUENCE'))
		DROP SEQUENCE Demo.Object_ALL_SEQUENCE



GO
CREATE SEQUENCE Demo.Object_ALL_SEQUENCE
AS INT 
START WITH 1
INCREMENT BY 1 
CACHE 100;
GO

CREATE TABLE Demo.Object1
(
	ObjectId		int PRIMARY KEY DEFAULT (NEXT VALUE FOR Demo.Object_ALL_SEQUENCE),
	InsertTime	    datetime2(3)
)
GO
CREATE TABLE Demo.Object2
(
	ObjectId		int PRIMARY KEY DEFAULT (NEXT VALUE FOR Demo.Object_ALL_SEQUENCE),
	InsertTime	    datetime2(3)
)
GO
CREATE TABLE Demo.Object3
(
	ObjectId		int PRIMARY KEY DEFAULT (NEXT VALUE FOR Demo.Object_ALL_SEQUENCE),
	InsertTime	    datetime2(3)
)
GO

/*
SELECT I, I % 3
FROM   Tools.Number
*/
GO

--takes about 11 seconds
SET NOCOUNT ON 
IF  (DATEPART(MILLISECOND,sysdatetime()) % 3) = 0
	INSERT INTO Demo.Object1(InsertTime)
	VALUES (SYSDATETIME());
ELSE IF DATEPART(MILLISECOND,sysdatetime()) % 3 = 1
	INSERT INTO Demo.Object2 (InsertTime)
	VALUES (SYSDATETIME())
ELSE 
	INSERT INTO Demo.Object3 (InsertTime)
	VALUES (SYSDATETIME())
waitfor delay '00:00:00.003'
GO 1000


SELECT 'Demo.Object1', *
FROM   Demo.Object1
union all
SELECT 'Demo.Object2', *
FROM   Demo.Object2
union all
SELECT 'Demo.Object3', *
FROM   Demo.Object3
order by objectId

--Contrived because I can't think of a real world case where you wouldn't also want the 
--likely superclass Demo.Object table that could be the driver of the data. But there you have it :)