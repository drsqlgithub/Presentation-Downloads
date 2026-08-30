USE SequenceDemos
GO

--run this on multiple connections
EXEC Utility.WaitForSync$StartWait @WaitSeconds = 10
GO
INSERT INTO Demo.CacheRowExample (ProcessId,OtherColumns)
SELECT TOP 20000 @@spid, REPLICATE('a',30)
FROM   Tools.Number
GO 5
--gets us the "how long did it take row"
INSERT INTO Demo.CacheRowExample (ProcessId,OtherColumns)
SELECT TOP 1 @@spid, REPLICATE('a',30)
FROM   Tools.Number
GO




