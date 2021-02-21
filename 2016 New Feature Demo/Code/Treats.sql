--Shown:
   --CREATE OR ALTER
   --DROP IF EXISTS
   --sp_set_session_contaxt

   
--STRING_SPLIT

SELECT *
FROM   STRING_SPLIT(N'a,b,c,d,e,f,g,h',N',');


--FORMAT_MESSAGE

SELECT FORMATMESSAGE ('variables: int:%i, string %s, hexedecimal %X, https://docs.microsoft.com/en-us/sql/t-sql/functions/formatmessage-transact-sql', 1,'Fred',0x03E1);

USE WideWorldImporters;
GO

SELECT FORMATMESSAGE('For table ''%s'', column number: %i is named ''%s''',CONCAT(OBJECT_SCHEMA_NAME(object_id),'.',OBJECT_NAME(OBJECT_ID)),column_id,columns.name) AS Result
FROM   sys.columns;

--TRUNCATE TABLE with PARTITION --just telling you that it exists :)

--AT TIME ZONE
--Currently: Eastern Daylight Time is -4 (-5 for standard time)
--           Central Daylight Time is -5 (-6 for standard time)
SELECT  SYSDATETIME() AT TIME ZONE 'Central Standard Time';  
SELECT  SYSDATETIME() AT TIME ZONE 'Eastern Standard Time';  



DECLARE @TimeZone1 NVARCHAR(200) = 'Central Standard Time' 
DECLARE  @TimeZone2 NVARCHAR(200) = 'Eastern Standard Time'

SELECT  SYSDATETIME() AT TIME ZONE @TimeZone1 ;  
SELECT  SYSDATETIME() AT TIME ZONE @TimeZone2;  


SELECT  DATEPART(tz,SYSDATETIME() AT TIME ZONE @TimeZone1) AS Central
SELECT  DATEPART(tz,SYSDATETIME() AT TIME ZONE @TimeZone2) AS Eastern

SELECT DATEDIFF(MINUTE,SYSUTCDATETIME(),SYSDATETIME()) AS LocalFromUTC

SELECT  ABS(DATEPART(tz,SYSDATETIME() AT TIME ZONE @TimeZone1) - DATEPART(tz,SYSDATETIME() AT TIME ZONE @TimeZone2));





