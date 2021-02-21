-------------------------------------------------------------------
--Making it seem like something happens but it really hasn't

IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Version')) 
		DROP TABLE Version;
go

CREATE TABLE Version
(
    DatabaseVersion varchar(10)
);
go
CREATE TRIGGER Version$InsteadOfInsertUpdateDeleteTrigger
ON Version
INSTEAD OF INSERT, UPDATE, DELETE AS
BEGIN
   SET NOCOUNT ON;
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   --We just put the kibosh on the action and don't tell anyone... Adding the error would be better
   --THROW 50000, 'The System.Version table may not be modified in production', 16;
END;
go
set nocount off
go
--seems to work, right?
INSERT  into Version (DatabaseVersion)
VALUES ('1.0.12');
GO

--this justifies the elimination of triggers alone, right?
select *
from   Version
GO


-- stop here...

--simple merge calling three triggers

Use TriggerProsecution;
go
set nocount on
go

IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('test')) 
		DROP TABLE test;
go
--super simple table
create table test (testId int primary key)
go

--one trigger for all cases, to show that that the phenomena happens even with a single trigger
--object
CREATE TRIGGER test$InsertUpdateDeleteTrigger
ON test
AFTER INSERT, UPDATE, DELETE AS
BEGIN
	 DECLARE @rowcount int = @@rowcount,    --stores the number of rows affected by the DML
	         @rowcountInserted int = (select count(*) from inserted),
	         @rowcountDeleted int = (select count(*) from deleted);
     
	 SELECT @rowcount as [@@rowcount], 
	        @rowcountInserted as [@rowInInserted],
	        @rowcountDeleted as [@rowsInDeleted],
			CASE WHEN @rowcountInserted = 0 and @rowcountDeleted = 0 THEN 'Not Needed'
				 WHEN @rowcountInserted = 0 THEN 'DELETE'
			     WHEN @rowcountDeleted = 0 THEN 'INSERT'
				 ELSE 'UPDATE' END as Operation;
END

GO
--make sure you have allowed results from triggers
EXEC sp_configure 'disallow results from triggers',0 
RECONFIGURE;
GO

--put two rows into the table
INSERT INTO test
VALUES (1),(2),(3);
GO

--triggers called even when no changes...
WITH   testMerge as (SELECT *
                     FROM   (Values(1),(2),(3)) as testMerge (testId))
MERGE  test
USING  (SELECT testId FROM testMerge) AS source (testId)
        ON (test.testId = source.testId)
WHEN MATCHED THEN  
	UPDATE SET testId = source.testId
WHEN NOT MATCHED THEN
	INSERT (testId) VALUES (Source.testId)
WHEN NOT MATCHED BY SOURCE THEN 
     DELETE;
Go

--this would actually need to call all three...
WITH   testMerge as (SELECT *
                     FROM   (Values(2),(3),(4)) as testMerge (testId))
MERGE  test
USING  (SELECT testId FROM testMerge) AS source (testId)
        ON (test.testId = source.testId)
WHEN MATCHED THEN  
	UPDATE SET testId = source.testId
WHEN NOT MATCHED THEN
	INSERT (testId) VALUES (Source.testId)
WHEN NOT MATCHED BY SOURCE THEN 
     DELETE;
Go


--however, (as the prosecutor) I begrudgingly note that all triggers called AFTER the MERGE completed...
--added a select to see what rows are in the test table during each trigger call....
--adding an output of the test table to show this is the case...
ALTER TRIGGER test$InsertUpdateDeleteTrigger
ON test
AFTER INSERT, UPDATE, DELETE AS
BEGIN
	 DECLARE @rowcount int = @@rowcount,    --stores the number of rows affected
	         @rowcountInserted int = (select count(*) from inserted),
	         @rowcountDeleted int = (select count(*) from deleted);
     
	 SELECT @rowcount as [@@rowcount], 
	        @rowcountInserted as [@rowcountInserted],
	        @rowcountDeleted as [@rowcountDeleted],
			CASE WHEN @rowcountInserted = 0 and @rowcountDeleted = 0 THEN 'Not Needed'
				 WHEN @rowcountInserted = 0 THEN 'DELETE'
			     WHEN @rowcountDeleted = 0 THEN 'INSERT'
				 ELSE 'UPDATE' END as Operation;

	  select *  --<<-- output the rows so you can see the state of the table after the trigger..
	  From   test;
END

GO
--all three operations are required...
WITH   testMerge as (SELECT *
                     FROM   (Values(3),(4),(1)) as testMerge (testId))
MERGE  test
USING  (SELECT testId FROM testMerge) AS source (testId)
        ON (test.testId = source.testId)
WHEN MATCHED THEN  
	UPDATE SET testId = source.testId
WHEN NOT MATCHED THEN
	INSERT (testId) VALUES (Source.testId)
WHEN NOT MATCHED BY SOURCE THEN 
        DELETE;
Go




--basic gist: Since the insert is done in the instead of trigger, it is in a different
--			  scope than where you would regularly use scope_identity() function, leading
--			  to the scope_identity() function returing NULL and messing up all of the tools
--			  that have come to depend upon it. (This will also be an issue when changing to 
--			  using sequence objects as well)

--------------------------------------------------------------------

------------------------------------------------------
-- Scope identity and instead of triggers

IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('testIdentity'))
		DROP TABLE testIdentity;
GO
CREATE TABLE testIdentity
(
	testIdentityId int IDENTITY CONSTRAINT PKtestIdentity PRIMARY KEY,
	value varchar(30) CONSTRAINT AKtestIdentity UNIQUE,
);
GO


INSERT INTO testIdentity(value)
VALUES ('without trigger');

SELECT SCOPE_IDENTITY() as scopeIdentity;
GO

--now we create an instead of trigger that doesn't really do anything but just replicate the
--INSERT operation that caused the trigger to fire
CREATE TRIGGER testIdentity$InsteadOfInsertTrigger
ON testIdentity
INSTEAD OF INSERT AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --@rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
	  INSERT INTO testIdentity(value)
          SELECT value
          FROM   inserted;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]

      THROW ;--will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--try it again
INSERT INTO testIdentity(value)
VALUES ('with trigger');

SELECT scope_identity() as scopeIdentity;  --only experience really lets you know why this is happening!
GO


--the safest way to handle all surrogate keys is to use the alternate key value
--as it works for any form of 

declare @value varchar(30) = 'with trigger two'

INSERT INTO testIdentity(value)
VALUES (@value);

SELECT testIdentityId as scopeIdentity
FROM   testIdentity
WHERE  value = @value; --use an alternate key...as long as the trigger doesn't change *this* value
GO


---------------------------------------------------------------------------------
-- Probably Don't do in demo
-- Example is that with a default that uses a sequence object, you can call the 
-- default twice if you forget to use the default value that is passed in...

IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('SalesOrder'))
		DROP TABLE SalesOrder;
GO
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('SalesOrder_SEQUENCE'))
		DROP SEQUENCE SalesOrder_SEQUENCE;
GO
CREATE SEQUENCE SalesOrder_SEQUENCE
AS INT START WITH 1 INCREMENT BY 1;
GO

--simple table using a sequence for a PK
CREATE TABLE SalesOrder
(
	SalesOrderId	int  
		CONSTRAINT PKSalesOrder PRIMARY KEY
		CONSTRAINT DFLTSalesOrder_SalesOrderId DEFAULT (NEXT VALUE FOR SalesOrder_SEQUENCE), 
	SalesOrderNumber char(10) NOT NULL CONSTRAINT AKSalesOrder UNIQUE,
	RowModifyDate datetime2(3) NOT NULL,
	RowCreateDate datetime2(3) NOT NULL,
)
GO

--trigger to make sure that the Row Modify and Create Date Values are set
CREATE TRIGGER SalesOrder$InsteadOfInsert_Trigger
ON SalesOrder
INSTEAD OF INSERT AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --@rowsAffected = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  INSERT SalesOrder (SalesOrdernumber, RowModifyDate, RowCreateDate)
		  SELECT SalesOrderNumber,SYSDATETIME(), SYSDATETIME()
		  FROM   Inserted
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--truncate table SalesOrder;
--alter sequence SalesOrder_SEQUENCE restart;
INSERT SalesOrder(SalesOrderNumber)
VALUES ('0000000001');
SELECT SalesOrderId FROM SalesOrder WHERE SalesOrderNumber = '0000000001';
GO

INSERT SalesOrder(SalesOrderNumber)
VALUES ('0000000002'),('0000000003');
SELECT SalesOrderId FROM SalesOrder WHERE SalesOrderNumber in ('0000000002','0000000003');
GO

--seems to work...but... something seems wrong:

select *
from   SalesOrder

--maybe some more testing would help?

--try what should be the typical way using sequences
DECLARE @SalesOrderId int
SET @SalesOrderId = (NEXT VALUE FOR SalesOrder_SEQUENCE);

INSERT SalesOrder(SalesOrderId, SalesOrderNumber)
VALUES (@SalesOrderId, '0000000004');

SELECT * FROM SalesOrder WHERE SalesOrderId = @SalesOrderId -- guh?
GO
--but it did work...
SELECT SalesOrderId FROM SalesOrder WHERE SalesOrderNumber = '0000000004';
GO


--Use the safe version of surrogate key fetching...
DECLARE @SalesOrderId int
SET @SalesOrderId = (NEXT VALUE FOR SalesOrder_SEQUENCE);
select @SalesOrderId as salesOrderIdWeAreCreating

INSERT SalesOrder(SalesOrderId, SalesOrderNumber)
VALUES (@SalesOrderId, '0000000005');

SELECT SalesOrderId FROM SalesOrder WHERE SalesOrderNumber = '0000000005';
GO

--Default fired twice!... once for the original insert, and again during the trigger... 
--usually not a problem to do default twice because no other defaults maintain state
ALTER TRIGGER SalesOrder$InsteadOfInsert_Trigger
ON SalesOrder
INSTEAD OF INSERT AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --@rowsAffected = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action> --make sure you include the surrogate key so it uses the value 
							  --sent to it via the insert...
		  INSERT SalesOrder (SalesOrderId, SalesOrdernumber, RowModifyDate, RowCreateDate)
		  SELECT (SalesOrderId, SalesOrderNumber,SYSDATETIME(), SYSDATETIME()
		  FROM   Inserted
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO
