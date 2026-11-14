USE MattersOfConcurrency
GO

/*
create table Demo.SingleTable
(
	singleTableId int identity(1,1) CONSTRAINT PKsingleTable PRIMARY KEY,
	value varchar(100) CONSTRAINT AKsingleTable UNIQUE,
)
*/

--Description: ROLLBACK DEMO
BEGIN TRANSACTION
GO
SELECT 'Before Delete', *
FROM   Demo.SingleTable
GO
DELETE FROM Demo.SingleTable
GO
SELECT 'After Delete',*
FROM   Demo.SingleTable
GO
ROLLBACK TRANSACTION
GO
SELECT 'After Rollback',*
FROM   Demo.SingleTable
GO

--Autonomous Transaction
--Description: IDENTITY is not rolled back
BEGIN TRANSACTION
GO
INSERT INTO Demo.SingleTable(Value)
VALUES ('Not From Bedrock');

SELECT SCOPE_IDENTITY()
GO
ROLLBACK TRANSACTION
GO
INSERT INTO Demo.SingleTable(Value)
VALUES ('Perry_Masonite');
go
SELECT SCOPE_IDENTITY()
GO
SELECT *
FROM   Demo.SingleTable
ORDER  BY SingleTableId DESC
GO

--Clean up
DELETE FROM Demo.SingleTable
WHERE Value = 'Perry_Masonite';