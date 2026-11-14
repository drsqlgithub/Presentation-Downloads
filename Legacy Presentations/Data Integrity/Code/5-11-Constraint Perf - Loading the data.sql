
--==============================================================================
-- Using Single Insert On Child Data 40000 child rows
--==============================================================================
SET NOCOUNT ON 
GO
USE HowToImplementDataIntegrity
Go

SELECT '--- Single Insert ---------------'
UNION ALL 
SELECT '---------------------------------------------------------------'

SELECT CONCAT(COUNT(*),' constraints on the Demo.HighlyFormattedData table')
FROM   sys.check_constraints
WHERE  parent_object_id = object_id('Demo.HighlyFormattedData')
SELECT CONCAT(COUNT(*),' triggers on the Demo.HighlyFormattedData table')
FROM   sys.triggers
WHERE  parent_id = object_id('Demo.HighlyFormattedData')
GO
DELETE FROM Demo.HighlyFormattedData

DECLARE @startTime DATETIME = GETDATE()

INSERT INTO Demo.HighlyFormattedData
           (HighlyFormattedData,AlternateKeyValue,FormattedValue1
           ,FormattedValue2,FormattedValue3,FormattedValue4,FormattedValue5,FormattedValue6
           ,FormattedValue7,FormattedValue8,FormattedValue9,FormattedValue10,FormattedValue11
           ,FormattedValue12,FormattedValue13,FormattedValue14,FormattedValue15)
SELECT HighlyFormattedData,AlternateKeyValue,FormattedValue1
           ,FormattedValue2,FormattedValue3,FormattedValue4,FormattedValue5,FormattedValue6
           ,FormattedValue7,FormattedValue8,FormattedValue9,FormattedValue10,FormattedValue11
           ,FormattedValue12,FormattedValue13,FormattedValue14,FormattedValue15
FROM   HowToImplementDataIntegrity_SourceData.Demo.HighlyFormattedData
           
SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS SolidDataProtection_InsertTimeSeconds
 SELECT COUNT(*) AS [Demo.HighlyFormattedData]
 FROM   Demo.HighlyFormattedData

GO
SELECT '--- Loop with Single Row Inserts Through Cursor ---------------'
UNION ALL 
SELECT '---------------------------------------------------------------'


 
TRUNCATE TABLE Demo.HighlyFormattedData

DECLARE @startTime DATETIME = GETDATE()

DECLARE @HighlyFormattedData int ,
	@AlternateKeyValue CHAR(10) , 
	@FormattedValue1 char(20) ,
	@FormattedValue2 char(20) ,
	@FormattedValue3 nvarchar(10) ,
	@FormattedValue4 int ,
	@FormattedValue5 char(20) ,
	@FormattedValue6 char(60) ,
	@FormattedValue7 float ,
	@FormattedValue8 char(10) ,
	@FormattedValue9 nchar(20) ,
	@FormattedValue10 nchar(15) ,
	@FormattedValue11 varchar(20) ,
	@FormattedValue12 varchar(20) ,
	@FormattedValue13 varchar(20) ,
	@FormattedValue14 date ,
	@FormattedValue15 DATETIME

DECLARE @cursor cursor
SET  @cursor = CURSOR FOR
SELECT HighlyFormattedData,AlternateKeyValue,FormattedValue1
           ,FormattedValue2,FormattedValue3,FormattedValue4,FormattedValue5,FormattedValue6
           ,FormattedValue7,FormattedValue8,FormattedValue9,FormattedValue10,FormattedValue11
           ,FormattedValue12,FormattedValue13,FormattedValue14,FormattedValue15
FROM   HowToImplementDataIntegrity_SourceData.Demo.HighlyFormattedData

OPEN @cursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @HighlyFormattedData,@AlternateKeyValue,
			@FormattedValue1,@FormattedValue2,@FormattedValue3,@FormattedValue4,@FormattedValue5,
			@FormattedValue6,@FormattedValue7,@FormattedValue8,@FormattedValue9,@FormattedValue10,
			@FormattedValue11,@FormattedValue12,@FormattedValue13,@FormattedValue14,@FormattedValue15
	IF @@fetch_status <> 0
	   BREAK
	   
	INSERT INTO Demo.HighlyFormattedData (HighlyFormattedData,AlternateKeyValue,
			FormattedValue1,FormattedValue2,FormattedValue3,FormattedValue4,FormattedValue5,
			FormattedValue6,FormattedValue7,FormattedValue8,FormattedValue9,FormattedValue10,
			FormattedValue11,FormattedValue12,FormattedValue13,FormattedValue14,FormattedValue15 )

	SELECT 
			@HighlyFormattedData,@AlternateKeyValue,
			@FormattedValue1,@FormattedValue2,@FormattedValue3,@FormattedValue4,@FormattedValue5,
			@FormattedValue6,@FormattedValue7,@FormattedValue8,@FormattedValue9,@FormattedValue10,
			@FormattedValue11,@FormattedValue12,@FormattedValue13,@FormattedValue14,@FormattedValue15
	
 END
 SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds
 SELECT COUNT(*) AS [Demo.HighlyFormattedData]
 FROM   Demo.HighlyFormattedData

 GO
 
 SELECT *
 FROM   Demo.HighlyFormattedData