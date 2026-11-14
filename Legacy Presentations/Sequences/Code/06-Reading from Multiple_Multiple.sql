USE SequenceDemos; --run and note the execution time
GO
EXECUTE Utility.WaitForSync$StartWait 10;

DECLARE @StartTime datetime2(7) = SYSDATETIME();
DECLARE @Hold table (First Int, Second Int);

INSERT INTO @hold (First, Second)
SELECT NEXT VALUE FOR Demo.First_SEQUENCE as First,
		NEXT VALUE FOR Demo.Second_SEQUENCE as Second
FROM    Tools.Number
WHERE   I between 1 and 1000;

SELECT *
FROM   @hold
WHERE  First <> Second

SELECT OBJECT_SCHEMA_NAME(object_id) + '.' + name, current_value
FROM   sys.sequences
WHERE  OBJECT_ID = OBJECT_ID('Demo.First_SEQUENCE')
   OR  OBJECT_ID = OBJECT_ID('Demo.Second_SEQUENCE');

SELECT DATEDIFF(Millisecond,@StartTime,GETDATE()) as lengthOfTime