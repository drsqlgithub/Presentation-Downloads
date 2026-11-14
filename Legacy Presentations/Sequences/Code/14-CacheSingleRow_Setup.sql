---Show how caching affects ranges...

USE SequenceDemos
GO
SET NOCOUNT ON
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.InstrumentReadingIdentity')) DROP TABLE Demo.InstrumentReadingIdentity
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.InstrumentReading')) DROP TABLE  Demo.InstrumentReading

IF EXISTS (SELECT * FROM sys.sequences WHERE object_id = object_id('Demo.InstrumentReading_SEQUENCE')) DROP SEQUENCE Demo.InstrumentReading_SEQUENCE


CREATE SEQUENCE Demo.InstrumentReading_SEQUENCE
AS INT START WITH 1 INCREMENT BY 1 
--NO CACHE;
; --leave it to SQL Server
--CACHE 100;
--CACHE 1000;
GO
CREATE TABLE Demo.InstrumentReading
(
	InstrumentReadingId int NOT NULL PRIMARY KEY 
					DEFAULT (NEXT VALUE FOR Demo.InstrumentReading_SEQUENCE),
	ExternalProcessId	int NOT NULL DEFAULT (@@SPID),
	ReadingTime datetime2(7) DEFAULT (SYSDATETIME()),
	Value numeric (6,5)
);
GO

CREATE TABLE Demo.InstrumentReadingIdentity
(
	InstrumentReadingId int NOT NULL IDENTITY PRIMARY KEY,
	ExternalProcessId	int NOT NULL DEFAULT (@@SPID),
	ReadingTime datetime2(7) DEFAULT (SYSDATETIME()),
	Value numeric (6,5)
);
GO
--used for multiple connection test
EXECUTE Utility.WaitForSync$Reset; 


--then come back and check it out
select 'Sequence',MAX(ReadingTime), MIN(ReadingTime),
		DATEDIFF(millisecond,MIN(ReadingTime),MAX(ReadingTime) )as ExecutionTime
		, COUNT(*) as NumRows, 
		(SELECT  CASE WHEN is_cached = 0 then 'NOT CACHED'
				 ELSE COALESCE(CAST(cache_size as varchar(10)),'DEFAULT') END
		 FROM  sys.sequences 
		 WHERE object_id = object_id('Demo.InstrumentReading_SEQUENCE')) as CacheSize
FROM   Demo.InstrumentReading

select 'Identity',MAX(ReadingTime), MIN(ReadingTime),
		DATEDIFF(millisecond,MIN(ReadingTime),MAX(ReadingTime) )as ExecutionTime
		, COUNT(*) as NumRows
FROM   Demo.InstrumentReadingIdentity
		  