IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Utility')
	EXEC ('CREATE SCHEMA Utility')
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE object_id = OBJECT_ID('Utility.WaitForSync'))
	--requires a table to sync across multiple connections
CREATE TABLE Utility.WaitForSync
(
	WaitforDelayValue nchar(8) NOT NULL,
	StartTime		  datetime2(0) NOT NULL, --used to make sure you can do a waitfor that crosses a day boundry
	OnlyOneRow		  tinyint PRIMARY KEY DEFAULT (1) CHECK (OnlyOneRow = 1)  
);
GO

IF NOT EXISTS (SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('Utility.WaitForSync$Reset'))
	EXEC ('CREATE PROCEDURE Utility.WaitForSync$Reset as SELECT ''Hi''')
GO
ALTER PROCEDURE Utility.WaitForSync$Reset
AS
----------------------------------------------------------------------------------------------
-- Louis Davidson		drsql.org
--
-- Simple enough, just delete the row from the table
----------------------------------------------------------------------------------------------
	DELETE FROM Utility.WaitForSync
GO

IF NOT EXISTS (SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('Utility.WaitForSync$ViewTime'))
	EXEC ('CREATE PROCEDURE Utility.WaitForSync$ViewTime as SELECT ''Hi''')
GO
ALTER PROCEDURE Utility.WaitForSync$ViewTime

AS
------------------------------------------------------------------------------------------------
---- Louis Davidson		drsql.org
----
---- Views information about the session
---- Returns 1 for no session, 0 for active session, -100 for expired session
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
			RETURN 1
	  END
	--if the time has already passed, we raise an error to the client that you can't piggy back on the
	--existing session, reset    
	ELSE IF @StartTime <= SYSDATETIME()
	  BEGIN
		SET @msg = N'WaitForSync: Expired session. DELAY time was '
				    + CAST(@startTime AS NVARCHAR(20)) + '.' 
		           + N'Use Utility.WaitForSync$reset to start new sessions';
		PRINT @msg;
		RETURN -100
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

IF NOT EXISTS (SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('Utility.WaitForSync$StartWait'))
	EXEC ('CREATE PROCEDURE Utility.WaitForSync$StartWait as SELECT ''Hi''')
GO
ALTER PROCEDURE Utility.WaitForSync$StartWait
(
	@WaitSeconds	int --minimum amount of time to wait. The WAITFOR statement
	                        --always starts as minute changes..
) 
AS
------------------------------------------------------------------------------------------------
---- Louis Davidson		drsql.org
----
---- Either starts a new wait for session or uses the existing one
---- Returns 0 for active session, -100 for expired session
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
/* Reset Connection
 EXEC Utility.WaitForSync$Reset
*/
/* Simple WaitFOR starting in 20 seconds 
EXEC @RETVAL = Utility.WaitForSync$StartWait @WaitSeconds=10
*/
/* WaitFOR starting in 20 seconds with flow control
BEGIN TRY
DECLARE @RETVAL int
 EXEC @RETVAL = Utility.WaitForSync$StartWait @WaitSeconds=10
 IF @RETVAL = -100
	 RAISERROR ('Time Elapsed',16,1)

 --Other code

END TRY
BEGIN CATCH
	PRINT ERROR_MESSAGE()
END CATCH

WaitForSync: An error occurred. Message: 
Too late to start another WAITFOR session. Last session DELAY time was 2012-03-20 21:20:06. Use Utility.WaitForSync$reset to start new sessions
Time Elapse

*/

 /* Clients -- if you also want to view time
Exec Utility.WaitForSync$ViewTime
GO
EXEC Utility.WaitForSync$StartWait @WaitSeconds=20
 */
