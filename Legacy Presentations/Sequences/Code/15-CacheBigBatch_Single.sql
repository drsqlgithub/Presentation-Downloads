Use SequenceDemos;
GO
TRUNCATE TABLE Demo.CacheRowExample
ALTER SEQUENCE Demo.CacheRowExample_SEQUENCE RESTART
GO

--First on one connection
INSERT INTO Demo.CacheRowExample (ProcessId,OtherColumns)
SELECT TOP 20000 @@spid, REPLICATE('a',30)
FROM   Tools.Number
GO 5

SELECT ProcessId, 
	   COUNT(*) as NumRows, 
	   MIN(CacheRowExampleId) as MinCacheRowExampleid,
	   MAX(CacheRowExampleId) as MaxCacheRowExampleid,
	   MIN(RowCreateTime) as MinRowCreateTime, 
	   MAX(RowCreateTime) as MaxRowCreateTime,
	   DATEDIFF(millisecond,MIN(RowCreateTime),MAX(RowCreateTime) )
FROM   Demo.CacheRowExample (nolock)
GROUP  BY ProcessId WITH ROLLUP
GO 