--WARNING: These reordering operations should not be done concurrently with other writing users. 

USE SequenceDemos
GO

IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.TransactionExample'))
		DROP TABLE Demo.TransactionExample

IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.TransactionExample_SEQUENCE'))
		DROP SEQUENCE Demo.TransactionExample_SEQUENCE

GO
CREATE SEQUENCE Demo.TransactionExample_SEQUENCE
AS INT 
START WITH 1
INCREMENT BY 1 
CACHE 100;
GO

CREATE TABLE Demo.TransactionExample
(
	TransactionExampleId	int PRIMARY KEY IDENTITY(1,1),
	TransactionSequence int UNIQUE DEFAULT (NEXT VALUE FOR Demo.TransactionExample_SEQUENCE),
	OtherColumns  char(30),
	ProcessId	int,
	RowCreateTime datetime2(7) DEFAULT (SYSDATETIME())
)
GO

TRUNCATE TABLE Demo.TransactionExample
ALTER SEQUENCE Demo.TransactionExample_SEQUENCE RESTART
GO 
--~15 seconds
--randomly remove rows from the table by rolling back rows where the second is divisible by 3
SET NOCOUNT ON
BEGIN TRANSACTION
	INSERT INTO Demo.TransactionExample (ProcessId,OtherColumns)
	SELECT TOP 20 @@spid, REPLICATE('a',30)
	FROM   Tools.Number
IF DATEPART(SECOND,SYSDATETIME()) % 3 = 0 
	ROLLBACK
ELSE 
	COMMIT
waitfor delay '00:00:00.003'
GO 500
--Add another row to be last so you can see it
INSERT INTO Demo.TransactionExample (ProcessId,OtherColumns)
SELECT TOP 1 @@spid, 'FindMe'
FROM   Tools.Number
GO

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted, name
FROM   sys.sequences
WHERE  name = 'TransactionExample_SEQUENCE'
  and  SCHEMA_NAME(schema_id) = 'Demo';


--note, the num rows may not correlate with the current_value if 
SELECT COUNT(*) as NumRows, 
	   MIN(TransactionExampleId) as MinTransactionExampleid,
	   MAX(TransactionExampleId) as MaxTransactionExampleid,
	   (MAX(TransactionExampleId) - MIN(TransactionExampleId) + 1) - COUNT(*) as GapRowCount,
	   MIN(RowCreateTime) as MinRowCreateTime, 
	   MAX(RowCreateTime) as MaxRowCreateTime,
	   DATEDIFF(millisecond,MIN(RowCreateTime),MAX(RowCreateTime) ) as createMilliseconds
FROM   Demo.TransactionExample (nolock)
WHERE  TransactionExampleId BETWEEN  (select MIN(TransactionSequence) FROM Demo.TransactionExample)
				   and (select MAX(TransactionSequence) FROM Demo.TransactionExample)
GO 
--note, the Identity values will suffer the same gaps
SELECT *
FROM   Demo.TransactionExample
ORDER BY TransactionSequence Desc
GO



--find the gaps using the Tools.Number table
--gaps will be larger here because ideal set starts at 1
SELECT I
FROM   Tools.Number
WHERE  I BETWEEN  1
				   and (select MAX(TransactionSequence) FROM Demo.TransactionExample)
EXCEPT
SELECT TransactionSequence
FROM   Demo.TransactionExample
GO

--Fill the gaps, starting with
declare @startWith int = 1
BEGIN TRANSACTION --test modification code in a transaction

;WITH FixNumbers AS(
SELECT TransactionSequence, ROW_NUMBER() OVER (ORDER BY TransactionSequence) as RowNumber
FROM   Demo.TransactionExample)

UPDATE FixNumbers
SET    TransactionSequence = RowNumber + (@startWith - 1)
WHERE  TransactionSequence <> RowNumber; --Start where values are different (performance
                                         --purposes only

select *
from   Demo.TransactionExample

--ALTER the sequence to have the next value
DECLARE @QueryText nvarchar(100) =
		CONCAT('ALTER SEQUENCE Demo.TransactionExample_SEQUENCE
		        RESTART WITH ',(select MAX(TransactionSequence) + 1 FROM Demo.TransactionExample))
EXEC   (@QueryText);

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   BaseType.name as data_type,
	   BaseType.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS baseType
               ON sequences.system_type_id = baseType.system_type_id
WHERE  sequences.name = 'TransactionExample_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo';



SELECT *
FROM   Demo.TransactionExample
ORDER BY TransactionSequence Desc

COMMIT -- To allow Filling the gaps
GO




--inserting a row into a hole
BEGIN TRANSACTION --not just for testing... the process of filling a gap takes
				  --multiple statements, so the transaction is needed

--make a gap
UPDATE Demo.TransactionExample
SET    TransactionSequence = TransactionSequence + 1
WHERE  TransactionSequence >= 11
--Fill it
INSERT INTO Demo.TransactionExample (ProcessId,OtherColumns,TransactionSequence)
SELECT TOP 1 @@spid, 'Oops. Missed One',11
FROM   Tools.Number

DECLARE @QueryText nvarchar(100) =
		CONCAT('ALTER SEQUENCE Demo.TransactionExample_SEQUENCE
		        RESTART WITH ',(select MAX(TransactionSequence) + 1 FROM Demo.TransactionExample))
EXEC   (@QueryText)

SELECT *
FROM   Demo.TransactionExample
ORDER BY TransactionSequence


ROLLBACK
--COMMIT

SELECT *
FROM   Demo.TransactionExample
ORDER BY TransactionSequence

