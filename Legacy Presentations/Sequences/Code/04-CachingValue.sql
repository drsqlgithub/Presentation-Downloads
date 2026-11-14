--set up to show how using two sequences in the same statement works. And how does caching affect things

USE SequenceDemos
go
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.SlowSequence'))
		DROP table Demo.SlowSequence
GO
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.SlowSequence_SEQUENCE'))
		DROP SEQUENCE Demo.SlowSequence_SEQUENCE
GO

set nocount on

CREATE SEQUENCE Demo.SlowSequence_SEQUENCE 
START WITH 1 INCREMENT BY 1 
--NO CACHE;
--CACHE 10;
--CACHE 100;
CACHE 2000;
go

CREATE TABLE Demo.SlowSequence
(
	SlowSequenceId int NOT NULL PRIMARY KEY DEFAULT (NEXT VALUE FOR Demo.SlowSequence_SEQUENCE),
	Value int NOT NULL,
	InsertTime datetime2(3) DEFAULT (SYSDATETIME())
)
go
INSERT INTO Demo.SlowSequence (Value)
VALUES (-1)
INSERT INTO Demo.SlowSequence (Value)
SELECT top 8000 I
FROM  SequenceDemos.Tools.Number
INSERT INTO Demo.SlowSequence(Value)
VALUES(-2)
GO
SELECT datediff(millisecond,Min(InsertTime),Max(InsertTime)),
		max(insertTime), min(insertTime), count(*) as rows
from  Demo.SlowSequence