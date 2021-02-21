use master
go
set nocount on
go
--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'SequenceDemos')
 exec ('
alter database  SequenceDemos
	set single_user with rollback immediate;

drop database SequenceDemos;')
GO
--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'SequenceDemos_SLOW')
 exec ('
alter database  SequenceDemos_SLOW
	set single_user with rollback immediate;

drop database SequenceDemos_SLOW;')
GO

Use Master
go
CREATE DATABASE SequenceDemos_SLOW  
 CONTAINMENT = NONE
 ON  PRIMARY 
(	NAME = N'SequenceDemos_SLOW', 
	FILENAME = N'F:\SQL\DATA\SequenceDemos_SLOW.mdf' , --sd card, class 10
	SIZE = 50MB , FILEGROWTH = 0 )
 LOG ON 
( 
	NAME = N'SequenceDemos_log', 
	FILENAME = N'F:\SQL\LOG\SequenceDemos_SLOW_log.ldf' , 
	SIZE = 50MB , FILEGROWTH = 0)
GO
use SequenceDemos_SLOW
GO
CREATE SCHEMA Demo
GO

CREATE DATABASE SequenceDemos  
 CONTAINMENT = NONE
 ON  PRIMARY 
(	NAME = N'SequenceDemos', 
	FILENAME = N'd:\SQL\DATA\SequenceDemos.mdf' , --ssd, quite fast
	SIZE = 500MB , FILEGROWTH = 0 )
 LOG ON 
( 
	NAME = N'SequenceDemos_log', 
	FILENAME = N'd:\SQL\LOG\SequenceDemos_log.ldf' , 
	SIZE = 250MB , FILEGROWTH = 0)
GO
ALTER DATABASE SequenceDemos SET COMPATIBILITY_LEVEL = 110
GO
ALTER DATABASE SequenceDemos SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE SequenceDemos SET ANSI_NULLS OFF 
GO
ALTER DATABASE SequenceDemos SET ANSI_PADDING OFF 
GO
ALTER DATABASE SequenceDemos SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE SequenceDemos SET ARITHABORT OFF 
GO
ALTER DATABASE SequenceDemos SET AUTO_CLOSE OFF 
GO
ALTER DATABASE SequenceDemos SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE SequenceDemos SET AUTO_SHRINK OFF 
GO
ALTER DATABASE SequenceDemos SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE SequenceDemos SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE SequenceDemos SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE SequenceDemos SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE SequenceDemos SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE SequenceDemos SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE SequenceDemos SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE SequenceDemos SET  DISABLE_BROKER 
GO
ALTER DATABASE SequenceDemos SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE SequenceDemos SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE SequenceDemos SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE SequenceDemos SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE SequenceDemos SET  READ_WRITE 
GO
ALTER DATABASE SequenceDemos SET RECOVERY SIMPLE 
GO
ALTER DATABASE SequenceDemos SET  MULTI_USER 
GO
ALTER DATABASE SequenceDemos SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE SequenceDemos SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
USE SequenceDemos
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') 
ALTER DATABASE SequenceDemos MODIFY FILEGROUP [PRIMARY] DEFAULT
GO
CREATE SCHEMA Demo
GO
CREATE SCHEMA Utility
GO
CREATE SCHEMA Tools
GO

--requires a table to sync across multiple connections
CREATE TABLE Utility.WaitForSync
(
	WaitforDelayValue nchar(8) NOT NULL,
	StartTime		  datetime2(0) NOT NULL, --used to make sure you can do a waitfor that crosses a day boundry
    OnlyOneRow		  tinyint PRIMARY KEY DEFAULT (1) CHECK (OnlyOneRow = 1)  
);
GO

CREATE PROCEDURE Utility.WaitForSync$Reset
AS
----------------------------------------------------------------------------------------------
-- Louis Davidson		drsql.org
--
-- Simple enough, just delete the row from the table
----------------------------------------------------------------------------------------------
	DELETE FROM Utility.WaitForSync
GO


CREATE PROCEDURE Utility.WaitForSync$ViewTime

AS
------------------------------------------------------------------------------------------------
---- Louis Davidson		drsql.org
----
---- Either starts a new wait for session or uses the existing one
------------------------------------------------------------------------------------------------
SET NOCOUNT ON 
 BEGIN TRY
	DECLARE @StartTime datetime2(0),
			@WaitforDelayValue NCHAR(8),
			@msg nvarchar(1000),
			@ProcStartTime datetime2(0) = SYSDATETIME();
	--Get the row from the table where we hold the sync value. 
	SELECT  @StartTime = StartTime,
			@WaitforDelayValue = WaitforDelayValue
    FROM   Utility.WaitForSync;

	--if a value was not already stored, we are just starting
	IF @StartTime IS NULL
	  BEGIN
			PRINT 'WaitForSync: No wait session has been etablished. Use Utility.WaitForSync$StartWait to start'
	  END
	--if the time has already passed, we raise an error to the client that you can't piggy back on the
	--existing session, reset    
	ELSE IF @StartTime <= SYSDATETIME()
	  BEGIN
		SET @msg = N'WaitForSync: Expired session. DELAY time was '
				    + CAST(@startTime AS NVARCHAR(20)) + '.' 
		           + N'Use Utility.WaitForSync$reset to start new sessions';
		PRINT @msg;
	  END
	ELSE
	  BEGIN  
			SET @msg = N'WaitForSync: Active session. DELAY time is set at '
				    + CAST(@startTime AS NVARCHAR(20)) + '.' 
			PRINT @msg;
		END
  END TRY
  
  BEGIN CATCH
	--benign output that won't stop anything. Simply keep going
	PRINT 'WaitForSync:An error occurred. Message: '  + CHAR(13) + CHAR(10)+ QUOTENAME(ERROR_MESSAGE(),'"')
	RETURN -100 --The caller can use the return value to decide if they want to stop what they are doing
  END CATCH

GO
CREATE PROCEDURE Utility.WaitForSync$StartWait
(
	@WaitSeconds	int --minimum amount of time to wait. The WAITFOR statement
	                        --always starts as minute changes..
) 
AS
------------------------------------------------------------------------------------------------
---- Louis Davidson		drsql.org
----
---- Either starts a new wait for session or uses the existing one
------------------------------------------------------------------------------------------------
SET NOCOUNT ON 
 BEGIN TRY
	DECLARE @StartTime datetime2(0),
			@WaitforDelayValue NCHAR(8),
			@ProcStartTime datetime2(0) = SYSDATETIME();
	--Get the row from the table where we hold the sync value. 
	SELECT  @StartTime = StartTime,
			@WaitforDelayValue = WaitforDelayValue
    FROM   Utility.WaitForSync;

	--if a value was not already stored, we are just starting
	IF @StartTime IS NULL
	  BEGIN
			--set the startTime to the current time + the number of seconds in parame
	  		SET @StartTime = DATEADD(second,@waitSeconds,SYSDATETIME());

			--then I use a good old style convert with a format to get the time for the delay
			SET @WaitforDelayValue = CONVERT(nchar(8),@starttime, 108);

			--insert the value into the WaitForSyncing table. StartTime willbe used to make sure
			--the time is later, even if it crosses the day boundry 
     	    INSERT INTO Utility.WaitForSync(WaitforDelayValue, StartTime)
			VALUES (@WaitforDelayValue,@StartTime);
	  END
	--if the time has already passed, we raise an error to the client that you can't piggy back on the
	--existing session, reset    
	ELSE IF @StartTime <= SYSDATETIME()
	  BEGIN
		DECLARE @msg nvarchar(1000)
		SET @msg = N'Too late to start another WAITFOR session. Last session DELAY time was '
				    + CAST(@startTime AS NVARCHAR(20)) + '.' 
		           + N' Use Utility.WaitForSync$reset to start new sessions';
		RAISERROR (@msg,16,1);
	  END
	--finally, we take the delay value we created and use it in an execute statement
	--note that SSMS won't how the SELECT until after the batch resumes.
	DECLARE @queryText NVARCHAR(100) = 'WAITFOR TIME ' + QUOTENAME(@WaitforDelayValue,'''');
	
	EXECUTE (@queryText);
	PRINT 'WaitForSync: Starting at: ' + CAST(@startTime AS NVARCHAR(20)) + 
		   ' Waited for: ' + CAST(DATEDIFF(SECOND,@procStartTime, SYSDATETIME()) AS VARCHAR(10)) + ' seconds.'
  END TRY
  
  BEGIN CATCH
	--benign output that won't stop anything. Simply keep going
	PRINT 'WaitForSync: An error occurred. Message: ' + CHAR(13) + CHAR(10) 
			+ ERROR_MESSAGE()
	RETURN -100 --The caller can use the return value to decide if they want to stop what they are doing
  END CATCH
GO

-----------------------------------------------------------------
--  Tools (Generally user facing that they can rely on)
-----------------------------------------------------------------

CREATE TABLE Tools.Number
(
    I   int CONSTRAINT PKTools_Number PRIMARY KEY
);
GO


;WITH DIGITS (I) as(--set up a set of numbers from 0-9
        SELECT I
        FROM   (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) as digits (I))
--builds a table from 0 to 999999
,Integers (I) as (
        SELECT D1.I + (10*D2.I) + (100*D3.I) + (1000*D4.I) + (10000*D5.I)
               + (100000*D6.I)
        FROM digits AS D1 CROSS JOIN digits AS D2 CROSS JOIN digits AS D3
                CROSS JOIN digits AS D4 CROSS JOIN digits AS D5
                CROSS JOIN digits AS D6) 
INSERT INTO Tools.Number(I)
SELECT I
FROM   Integers;
GO



CREATE TRIGGER tr_server$noDboSchemaObjects
ON DATABASE
AFTER CREATE_TABLE, DROP_TABLE, ALTER_TABLE,
	  CREATE_PROCEDURE, ALTER_PROCEDURE,
	  CREATE_FUNCTION, ALTER_FUNCTION,
	  CREATE_SEQUENCE, ALTER_SEQUENCE,
	  CREATE_TRIGGER, ALTER_TRIGGER
AS
 BEGIN
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
 
	IF EXISTS ( SELECT *
				FROM   sys.objects
				WHERE  SCHEMA_ID = SCHEMA_ID('dbo')
				  AND  type_desc NOT IN ('SERVICE_QUEUE'))
		THROW 50000,'Get your hands off my filthy desert, I mean, dbo schema',16
    END TRY
   BEGIN CATCH 
             IF @@trancount > 0 
                ROLLBACK TRANSACTION

              DECLARE @ERROR_MESSAGE varchar(8000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO

