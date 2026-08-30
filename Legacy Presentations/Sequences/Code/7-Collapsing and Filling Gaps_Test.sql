USE SequenceDemos
GO
--run this on this connection 
EXEC Utility.WaitForSync$Reset
EXEC Utility.WaitForSync$StartWait @WaitSeconds = 10
GO
BEGIN TRANSACTION
	INSERT INTO Demo.TransactionExample (ProcessId,OtherColumns)
	SELECT TOP 50 @@spid, REPLICATE('a',30)
	FROM   Tools.Number
IF DATEPART(SECOND,SYSDATETIME()) % 5 = 0 
	ROLLBACK
ELSE 
	COMMIT
GO 250


/*
USE SequenceDemos
GO
EXEC Utility.WaitForSync$StartWait @WaitSeconds = 10
GO
BEGIN TRANSACTION
	INSERT INTO Demo.TransactionExample (ProcessId,OtherColumns)
	SELECT TOP 50 @@spid, REPLICATE('a',30)
	FROM   Tools.Number
IF DATEPART(SECOND,SYSDATETIME()) % 5 = 0 
	ROLLBACK
ELSE 
	COMMIT
GO 250

*/

SELECT ProcessId, 
	   COUNT(*) as NumRows, 
	   MIN(TransactionExampleId) as MinTransactionExampleid,
	   MAX(TransactionExampleId) as MaxTransactionExampleid,
	   MIN(RowCreateTime) as MinRowCreateTime, 
	   MAX(RowCreateTime) as MaxRowCreateTime,
	   DATEDIFF(millisecond,MIN(RowCreateTime),MAX(RowCreateTime) )
FROM   Demo.TransactionExample (nolock)
GROUP  BY ProcessId WITH ROLLUP
GO 