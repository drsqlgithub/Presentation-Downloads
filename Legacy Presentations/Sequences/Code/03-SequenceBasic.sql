USE SequenceDemos
GO
SET NOCOUNT ON
GO

EXEC('USE tempDb;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID(''dbo.TEMP_SEQUENCE''))
		DROP SEQUENCE dbo.TEMP_SEQUENCE;');
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.Generic_SEQUENCE'))
		DROP SEQUENCE Demo.Generic_SEQUENCE;
GO
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('demo.Generic_WhoaDont_SEQUENCE'))
		DROP SEQUENCE demo.Generic_WhoaDont_SEQUENCE;
GO
IF EXISTS (SELECT * FROM sys.types where name = 'varchar20')
		DROP TYPE varchar20;
GO

--Nothing specified
CREATE SEQUENCE Demo.Generic_SEQUENCE
GO

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   userType.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO


PRINT 'Expected Errors'
GO
--Not allowed
SELECT NEXT VALUE FOR Demo.Generic_Sequence
UNION ALL
SELECT NEXT VALUE FOR Demo.Generic_Sequence
UNION ALL
SELECT NEXT VALUE FOR Demo.Generic_Sequence
UNION ALL
SELECT NEXT VALUE FOR Demo.Generic_Sequence
GO

--Not allowed
SELECT CASE WHEN 1=1 THEN NEXT VALUE FOR Demo.Generic_Sequence ELSE 1 END

--Choose?
SELECT CHOOSE (3, 10, 20, 30, 40, 50, 60, 70, 80) as CHOOSE1
SELECT CHOOSE (5, 10, 20, 30, 40, 50, 60, 70, 80) as CHOOSE2
--IIF?
SELECT IIF ( 1=1, 'Oh Yeah', 'Sadly No' ) as IIF1
SELECT IIF ( 1=2, 'Oh Yeah', 'Sadly No' ) as IIF2

--Tools.Number is a table of numbers from 0 to 99999 added in create script
SELECT *
FROM   Tools.Number
ORDER BY I

--Not allowed
SELECT NEXT VALUE FOR Demo.Generic_Sequence 
FROM   Tools.Number
WHERE  I between 1 and 100
ORDER BY I

--Finally!
SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I)
FROM   Tools.Number
WHERE  I between 1 and 100
ORDER BY I

--This time values are in reverse
SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I desc)
FROM   Tools.Number
WHERE  I between 1 and 100
ORDER BY I

--excellent error message
SELECT * 
FROM   (VALUES (NEXT VALUE FOR Demo.Generic_SEQUENCE),
			   (NEXT VALUE FOR Demo.Generic_SEQUENCE),
			   (NEXT VALUE FOR Demo.Generic_SEQUENCE),
			   (NEXT VALUE FOR Demo.Generic_SEQUENCE)) as Rows


--but this is acceptable
DECLARE @t TABLE (a bigint NULL)
INSERT  @t
OUTPUT inserted.a
VALUES 
       (NEXT VALUE FOR Demo.Generic_SEQUENCE),
       (NEXT VALUE FOR Demo.Generic_SEQUENCE),
       (NEXT VALUE FOR Demo.Generic_SEQUENCE),
       (NEXT VALUE FOR Demo.Generic_SEQUENCE)


--not gonna do it...no temporary sequences
CREATE SEQUENCE #Numberer AS INT
START WITH 1
GO




--can't do this "naturally"
CREATE SEQUENCE tempdb.dbo.TEMP_SEQUENCE AS INT
START WITH 1;
GO

--can using dynamic SQL 
EXECUTE ('USE tempDb;CREATE SEQUENCE dbo.TEMP_SEQUENCE AS INT
START WITH 1;')
GO

--if you find a very compelling use case...
SELECT NEXT VALUE FOR tempdb.dbo.TEMP_SEQUENCE ,
	  CONCAT(OBJECT_SCHEMA_NAME(OBJECT_ID),'.',name)
FROM   sys.objects

--but I pretty much wouldn't
EXEC('USE tempDb;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID(''dbo.TEMP_SEQUENCE''))
		DROP SEQUENCE dbo.TEMP_SEQUENCE;')
GO

--scale must be 0
CREATE SEQUENCE Demo.Generic_SEQUENCE2
AS numeric(20,3)
GO

--no really, it must be integer
CREATE SEQUENCE Demo.Generic_SEQUENCE2
AS varchar(20)
GO

--but that is what I meant
create type varchar20 from int
go
CREATE SEQUENCE Demo.Generic_WhoaDont_SEQUENCE
AS varchar20
GO

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   systemType.name as base_data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
            left outer JOIN sys.types AS systemType
                ON sequences.system_type_id = systemType.system_type_id
                    AND systemType.user_type_id = systemType.system_type_id
WHERE  sequences.name = 'Generic_WhoaDont_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'

--------------------------------------
GO
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.Generic_SEQUENCE'))
		DROP SEQUENCE Demo.Generic_SEQUENCE;
GO
CREATE SEQUENCE Demo.Generic_SEQUENCE
AS NUMERIC --18,0 by default
GO
SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I)
FROM   Tools.Number
WHERE  I between 1 and 100
ORDER BY I
GO

--------------------------------------


DROP SEQUENCE Demo.Generic_SEQUENCE
GO
CREATE SEQUENCE Demo.Generic_SEQUENCE
AS INT
START WITH 1
GO
SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I)
FROM   Tools.Number
WHERE  I between 1 and 101
ORDER BY I
GO

/*
DROP SEQUENCE Demo.Generic_SEQUENCE
GO
CREATE SEQUENCE Demo.Generic_SEQUENCE
AS INT
START WITH -1
MAXVALUE 100
MINVALUE 1
GO
*/

--------------------------------------

--TIP:
--For testing, it is a good idea (certainly not a bad idea), to test what happens when you hit the top
--value

DROP SEQUENCE Demo.Generic_SEQUENCE
GO
CREATE SEQUENCE Demo.Generic_SEQUENCE
AS INT
START WITH 1
MAXVALUE 100
MINVALUE 1
GO

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

--how many rows are we going to see returned?
SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I)
FROM   Tools.Number
WHERE  I between 1 and 101
ORDER BY I
GO

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

--how many rows are we going to see returned? comment on this
SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I DESC)
FROM   Tools.Number
WHERE  I between 1 and 101
ORDER BY I
GO

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

--------------------------------------

--give it a bit of a nappy
ALTER SEQUENCE Demo.Generic_SEQUENCE RESTART
GO

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

--note, going backwards now...
ALTER SEQUENCE Demo.Generic_SEQUENCE 
RESTART WITH 100 
INCREMENT BY -1;
GO

SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I)
FROM   Tools.Number
WHERE  I between 1 and 101
ORDER BY I
GO

--interesting warning
ALTER SEQUENCE Demo.Generic_SEQUENCE 
RESTART;
GO

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO


-----------------

--show how increments and max value work
ALTER SEQUENCE Demo.Generic_SEQUENCE 
RESTART WITH 0
INCREMENT BY 3
MINVALUE 0
MAXVALUE 10
CYCLE;
GO

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO
SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I)
FROM   Tools.Number
WHERE  I between 1 and 101
ORDER BY I
GO


ALTER SEQUENCE Demo.Generic_SEQUENCE 
RESTART WITH 0
INCREMENT BY 3
MINVALUE 0
MAXVALUE 12
CYCLE;
GO

SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I)
FROM   Tools.Number
WHERE  I between 1 and 101
ORDER BY I
GO

------------------------------------------

ALTER SEQUENCE Demo.Generic_SEQUENCE 
RESTART WITH 0
INCREMENT BY 1
MINVALUE 0
MAXVALUE 1000000000
CACHE 50000;
GO
SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

--stop here in live demo..

--restart server before touching sequence
SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO
--then get a few values
SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I)
FROM   Tools.Number
WHERE  I between 1 and 100
ORDER BY I
GO

--restart server
--guess what the output will be?

SELECT FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

--------------------------------
--show how transactions work with alter.

SELECT 'Before', FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
BEGIN TRANSACTION
ALTER SEQUENCE Demo.Generic_SEQUENCE 
RESTART WITH 10
--NOTE: THIS WILL BLOCK OTHER USERS
SELECT 'In Transaction',FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO
--to see run:
--SELECT NEXT VALUE FOR Demo.Generic_SEQUENCE 
--on another connection at this point

ROLLBACK TRANSACTION
SELECT 'After', FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO


--------------------------------------
--Show effects of transacton on usage and caching

ALTER SEQUENCE Demo.Generic_SEQUENCE 
RESTART WITH 1
INCREMENT BY 1
MINVALUE 0
MAXVALUE 1000000000
CACHE 50000;
GO


SELECT 'Before', FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

BEGIN TRANSACTION

--then get a few values
SELECT I, NEXT VALUE FOR Demo.Generic_Sequence OVER (ORDER BY I)
FROM   Tools.Number
WHERE  I between 1 and 100
ORDER BY I
GO

SELECT 'In Transaction',FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'

ROLLBACK TRANSACTION
GO


SELECT 'After', FORMAT (CAST(current_value as bigint),'N0') as current_value, 
	   FORMAT (CAST(start_value as bigint),'N0') as start_value, 
	   FORMAT (CAST(increment as bigint),'N0') as increment,  
	   FORMAT (CAST(minimum_value as bigint),'N0') as minimum_value,
	   FORMAT (CAST(maximum_value as bigint),'N0') as maximum_value,
	   FORMAT (CAST(cache_size as bigint),'N0') as cache_size,
	   is_cycling, is_cached, is_exhausted,
	   userType.name as data_type,
	   sequences.Precision as data_precision
FROM   sys.sequences
		   JOIN sys.types AS userType
               ON sequences.user_type_id = userType.user_type_id
WHERE  sequences.name = 'Generic_SEQUENCE'
  and  SCHEMA_NAME(sequences.schema_id) = 'Demo'
GO

---------------------------
