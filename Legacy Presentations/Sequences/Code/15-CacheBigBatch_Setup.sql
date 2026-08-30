USE SequenceDemos
GO
--NOTE: We have identity AND sequence in here for a side by side test
--in this example, I will load batches of 20000 rows at a time

IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.CacheRowExample')) 
		DROP TABLE Demo.CacheRowExample;

IF EXISTS (SELECT * FROM sys.sequences WHERE object_id = object_id('Demo.CacheRowExample_SEQUENCE')) 
		DROP SEQUENCE Demo.CacheRowExample_SEQUENCE;
GO

CREATE SEQUENCE Demo.CacheRowExample_SEQUENCE
AS INT 
START WITH 0
INCREMENT BY 1 
--NO CACHE;
--; --leave it to SQL Server
--CACHE 100;
CACHE 20000;
GO

CREATE TABLE Demo.CacheRowExample
(
	CacheRowExampleId	int PRIMARY KEY DEFAULT (NEXT VALUE FOR Demo.CacheRowExample_SEQUENCE),
	--CacheRowExampleId   int IDENTITY PRIMARY KEY,
	OtherColumns  char(30),
	ProcessId	int,
	RowCreateTime datetime2(7) DEFAULT (SYSDATETIME())
)
GO
--sp_help 'demo.CacheRowExample'
GO

EXEC Utility.WaitForSync$Reset

--Then we come here and check it out

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

--look at data ordered by the CacheRowExampleId
select *
from   Demo.CacheRowExample
order by CacheRowExampleId
--order by ProcessId

