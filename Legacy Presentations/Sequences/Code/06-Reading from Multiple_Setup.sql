--set up to show how using two sequences in the same statement works. And how does caching affect things

USE SequenceDemos
go
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.First_SEQUENCE'))
		DROP SEQUENCE Demo.First_SEQUENCE
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.Second_SEQUENCE'))
		DROP SEQUENCE Demo.Second_SEQUENCE
GO


CREATE SEQUENCE Demo.First_SEQUENCE 
START WITH 1 INCREMENT BY 1 
NO CACHE;  --effect is much worse when caching lowest due to slower inserts
--CACHE 100;
--CACHE 2000;
go
CREATE SEQUENCE Demo.Second_SEQUENCE  
START WITH 1 INCREMENT BY 1
NO CACHE;
--CACHE 100;
--CACHE 2000;

GO

--used for multiple connection test
EXECUTE Utility.WaitForSync$Reset; 


SELECT Sequences.Name, 
		FORMAT (CAST(current_value as bigint),'N0') as current_value, 
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
WHERE  sequences.name in ('First_SEQUENCE','Second_SEQUENCE')
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'