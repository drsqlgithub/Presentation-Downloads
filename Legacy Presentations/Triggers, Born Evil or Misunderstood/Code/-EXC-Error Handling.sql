--Decent error handling requires coding to be done in a very straightforward manner
Use TriggerProsecution;
GO
SET NOCOUNT ON
GO
--reset the table we will use for this demo
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('errorHandlingTest')) 
		DROP TABLE errorHandlingTest;
go
CREATE TABLE ErrorHandlingTest
(
    errorHandlingTestId   int NOT NULL CONSTRAINT PKerrorHandlingTest PRIMARY KEY, --pk
    CONSTRAINT chkAlt_errorHandlingTest_errorHandlingTestId_greaterThanZero --make sure the ID > 0
           CHECK (errorHandlingTestId > 0)
);
GO

--now we add a very innocently evil looking trigger. The trigger will always throw an error if 
--the trigger code is reached...
--in this first iteration, using RAISERROR rather than THROW for the first example
CREATE TRIGGER ErrorHandlingTest$afterInsertTrigger
ON ErrorHandlingTest
AFTER INSERT
AS
    BEGIN TRY
          RAISERROR ('Test Error',16,1); --raises an error in all cases...
    END TRY
    BEGIN CATCH
         IF @@TRANCOUNT > 0
		        ROLLBACK TRANSACTION;

		 DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
         RAISERROR (@msg,16,1); --THROW will stop the batch, but RAISERROR will not always..., first we show RAISERROR
    END CATCH
GO


--NO Transaction, Constraint Error
INSERT ErrorHandlingTest
VALUES (-1);
SELECT 'continues';
GO

--error caught by the trigger, and raised via raiserror
INSERT ErrorHandlingTest
VALUES (1);
SELECT 'continues';
GO

--now we change to using 2012 version.. THROW
ALTER TRIGGER ErrorHandlingTest$afterInsertTrigger
ON ErrorHandlingTest
AFTER INSERT
AS
    BEGIN TRY
          THROW 50000, 'Test Error',16;
    END TRY
    BEGIN CATCH
         IF @@TRANCOUNT > 0
		        ROLLBACK TRANSACTION;
         THROW; -- 2012, this will stop the batch unless caught
    END CATCH
GO

--error caught by the trigger with no transaction... slightly different than before
INSERT ErrorHandlingTest
VALUES (1);
SELECT 'continues';
GO


--now we start with an external transaction (which is (or should be) a very common method of operation)
--error from constraint
BEGIN TRY
    BEGIN TRANSACTION
    INSERT ErrorHandlingTest
    VALUES (-1);
    COMMIT
END TRY
BEGIN CATCH
    SELECT  CASE XACT_STATE()
                WHEN 1 THEN 'Committable'
                WHEN 0 THEN 'No transaction'
                ELSE 'Uncommitable tran' END as XACT_STATE
			,ERROR_PROCEDURE() as ErrorSource
            ,ERROR_NUMBER() AS ErrorNumber
            ,ERROR_MESSAGE() as ErrorMessage;

    IF @@TRANCOUNT > 0
          ROLLBACK TRANSACTION;
END CATCH
select 'continues'
GO

--error handled in trigger, trigger does the rollback
BEGIN TRANSACTION
   BEGIN TRY
        INSERT ErrorHandlingTest
        VALUES (1);
       COMMIT TRANSACTION;
   END TRY
BEGIN CATCH
    SELECT  CASE XACT_STATE()
                WHEN 1 THEN 'Committable'
                WHEN 0 THEN 'No transaction'
                ELSE 'Uncommitable tran' END as XACT_STATE
			,ERROR_PROCEDURE() as ErrorSource
            ,ERROR_NUMBER() AS ErrorNumber
            ,ERROR_MESSAGE() as ErrorMessage;
    IF @@TRANCOUNT > 0
          ROLLBACK TRANSACTION;
END CATCH
select 'continues'
GO

--now we alter the trigger to just let the error get returned via throw, but not rolled back
ALTER TRIGGER ErrorHandlingTest$afterInsertTrigger
ON ErrorHandlingTest
AFTER INSERT
AS
    BEGIN TRY
          THROW 50000, 'Test Error',16;
    END TRY
    BEGIN CATCH
         --Commented out for test purposes
         --IF @@TRANCOUNT > 0
         --    ROLLBACK TRANSACTION;

         THROW;
    END CATCH
GO

--letting the error get handled by the trigger
BEGIN TRY
    BEGIN TRANSACTION
    INSERT ErrorHandlingTest
    VALUES (1);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SELECT  CASE XACT_STATE()
                WHEN 1 THEN 'Committable'
                WHEN 0 THEN 'No transaction'
                ELSE 'Uncommitable tran' END as XACT_STATE
			,ERROR_PROCEDURE() as ErrorSource
            ,ERROR_NUMBER() AS ErrorNumber
            ,ERROR_MESSAGE() as ErrorMessage;
     IF @@TRANCOUNT > 0
          ROLLBACK TRANSACTION;
END CATCH
select 'continues'
GO



/* Example Error Handling to give maximum effect */

--in order to really get value in your error handling, the error handling 
--code can get messy but you want the output to be consistent

--constraint error
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @errorMessage nvarchar(4000) = 'Error inserting data into ErrorHandlingTest';
    INSERT ErrorHandlingTest
    VALUES (-1);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    --I also add in the stored procedure or trigger where the error
    --occurred also when in a coded object
    SET @errorMessage = CONCAT(@errorMessage,
							   ' ( System Error: ',
							   CAST(ERROR_NUMBER() as varchar(10)), ':',
							   coalesce(' in object ' + ERROR_PROCEDURE() + ':',''),
							   ERROR_MESSAGE(),': Line Number:',
							   CAST(ERROR_LINE() as varchar(10)),')');
        THROW 50000,@errorMessage,16;
END CATCH
select 'continues'
GO


--Trigger Error
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @errorMessage nvarchar(4000) = 'Error inserting data into ErrorHandlingTest';
    INSERT ErrorHandlingTest
    VALUES (1);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    --I also add in the stored procedure or trigger where the error
    --occurred also when in a coded object
    SET @errorMessage = CONCAT(@errorMessage,
							   ' ( System Error: ',
							   CAST(ERROR_NUMBER() as varchar(10)), ':',
							   coalesce(' in object ' + ERROR_PROCEDURE() + ':',''),
							   ERROR_MESSAGE(),': Line Number:',
							   CAST(ERROR_LINE() as varchar(10)),')');
        THROW 50000,@errorMessage,16;
END CATCH
select 'continues';
GO