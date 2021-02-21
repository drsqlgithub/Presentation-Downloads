Use SequenceDemos
GO
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.SalesOrder')) 
DROP TABLE Demo.SalesOrder;

IF EXISTS (SELECT * FROM sys.sequences WHERE object_id = object_id('Demo.SalesOrder_SEQUENCE')) 
DROP SEQUENCE Demo.SalesOrder_SEQUENCE
GO

CREATE TABLE Demo.SalesOrder
(
	SalesOrderId	int IDENTITY CONSTRAINT PKSalesOrder PRIMARY KEY,
	SalesOrderNumber char(10) NOT NULL CONSTRAINT AKSalesOrder UNIQUE,
	RowModifyDate datetime2(3) NOT NULL,
	RowCreateDate datetime2(3) NOT NULL,
)
GO

--this time the value is correct for the rowCreate and RowModifyDate
INSERT Demo.SalesOrder(SalesOrderNumber, RowCreateDate, RowModifyDate)
VALUES ('0000000001',SYSDATETIME(), SYSDATETIME());

SELECT * from Demo.SalesOrder
WHERE  salesOrderId = SCOPE_IDENTITY();
GO

--wildly inappropriate value
INSERT Demo.SalesOrder(SalesOrderNumber, RowCreateDate, RowModifyDate)
VALUES ('0000000002','2010-01-01', '2010-01-01');

SELECT * from Demo.SalesOrder
WHERE  salesOrderId = SCOPE_IDENTITY();
GO

--Silly coders
SELECT *
FROM   Demo.SalesOrder
GO

--So we force the issue!
CREATE TRIGGER Demo.SalesOrder$InsteadOfInsert_Trigger
ON Demo.SalesOrder
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
		  INSERT Demo.SalesOrder (SalesOrdernumber, RowModifyDate, RowCreateDate)
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


--"Curses, foiled again" said the coder!
INSERT Demo.SalesOrder(SalesOrderNumber, RowCreateDate, RowModifyDate)
VALUES ('0000000003','2010-01-01', '2010-01-01');
SELECT SCOPE_IDENTITY() as WhereIsMyValue;
SELECT * FROM Demo.SalesOrder where SalesOrderId = SCOPE_IDENTITY(); --huh? Why is this?
GO

--this will work, but why didn't the previous one work? Scope Identity was blown away by the trigger.
INSERT Demo.SalesOrder(SalesOrderNumber, RowCreateDate, RowModifyDate)
VALUES ('0000000004','2010-01-01', '2010-01-01');
SELECT SalesOrderId FROM Demo.SalesOrder where SalesOrderNumber = '0000000004';
GO
SELECT * FROM Demo.SalesOrder;

----------------------------------------------------------------------------
-- Change from identity to a sequence...
-- Here too is where identity columns are really inflexible.  We will have to 
-- drop the column...
----------------------------------------------------------------------------

--change the name of the identity column
ALTER TABLE Demo.SalesOrder DROP CONSTRAINT PKSalesOrder
EXEC sp_rename 'Demo.SalesOrder.SalesOrderId' , 'SalesOrderIdOld', 'COLUMN'
GO

--add what will be the new sequence number
ALTER TABLE Demo.SalesOrder
	ADD SalesOrderId int;
GO
--set the new value for the column to the old value
UPDATE Demo.SalesOrder
SET    SalesOrderId = SalesOrderIdOld
GO
--check it out
SELECT *
FROM   Demo.SalesOrder
GO
--drop the old column
ALTER TABLE Demo.SalesOrder
  DROP COLUMN SalesOrderIdOld
GO
--make the new value not null
ALTER TABLE Demo.SalesOrder
	ALTER COLUMN SalesOrderId int NOT NULL
GO
--next make the new column the PK
ALTER TABLE Demo.SalesOrder
   ADD CONSTRAINT PKSalesOrder PRIMARY KEY (SalesOrderId);
GO

--create a simple sequence
CREATE SEQUENCE Demo.SalesOrder_SEQUENCE
AS INT START WITH 1 INCREMENT BY 1;
GO
--set the default for the column to the sequence
ALTER TABLE Demo.SalesOrder
   ADD CONSTRAINT DFLTSalesOrder_SalesOrderId 
	DEFAULT (NEXT VALUE FOR Demo.SalesOrder_SEQUENCE) FOR SalesOrderId
GO

--this batch syncs the sequence to the table
DECLARE @SalesOrderId int
SELECT @salesOrderId = COALESCE(MAX(SalesOrderId),1) 
FROM   Demo.SalesOrder

--ALTER SEQUENCE wont work with a variable
DECLARE @queryText nvarchar(1000) = CONCAT('ALTER SEQUENCE Demo.SalesOrder_SEQUENCE
     RESTART WITH ',@salesOrderId)
EXEC (@queryText)
SELECT current_value
FROM   sys.sequences
where  object_id = object_id('Demo.SalesOrder_SEQUENCE')
GO

INSERT Demo.SalesOrder(SalesOrderNumber)
VALUES ('0000000005');
SELECT SalesOrderId FROM Demo.SalesOrder WHERE SalesOrderNumber = '0000000005';
GO
SELECT *
FROM   Demo.SalesOrder
GO

--now what should be the typical way
DECLARE @SalesOrderId int
SET @SalesOrderId = (NEXT VALUE FOR Demo.SalesOrder_SEQUENCE);

INSERT Demo.SalesOrder(SalesOrderId, SalesOrderNumber)
VALUES (@SalesOrderId, '0000000006');

SELECT * FROM Demo.SalesOrder WHERE SalesOrderId = @SalesOrderId -- guh?
GO


--wait, wait, wait. Why don't I see any data?
SELECT *
FROM   Demo.SalesOrder
GO

--Was there an error?  Try it again?
DECLARE @SalesOrderId int
SET @SalesOrderId = (NEXT VALUE FOR Demo.SalesOrder_SEQUENCE);

INSERT Demo.SalesOrder(SalesOrderId, SalesOrderNumber)
VALUES (@SalesOrderId, '0000000007');

SELECT * FROM Demo.SalesOrder WHERE SalesOrderId = @SalesOrderId
GO
--wait, wait, wait. Why don't I see any data?
SELECT *
FROM   Demo.SalesOrder
GO


--That silly trigger!
--So we force the issue!
alter TRIGGER Demo.SalesOrder$InsteadOfInsert_Trigger
ON Demo.SalesOrder
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
		  /*previously, didn't do SalesOrder because of identity
		  INSERT Demo.SalesOrder (SalesOrdernumber, RowModifyDate, RowCreateDate)
		  SELECT SalesOrderNumber,SYSDATETIME(), SYSDATETIME()
		  FROM   Inserted
		  */ 
		  INSERT Demo.SalesOrder (SalesOrderId,SalesOrdernumber, RowModifyDate, RowCreateDate)
		  SELECT SalesOrderId, SalesOrderNumber,SYSDATETIME(), SYSDATETIME()
		  FROM   Inserted
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--So we fix the silly trigger...
DECLARE @SalesOrderId int
SET @SalesOrderId = (NEXT VALUE FOR Demo.SalesOrder_SEQUENCE);

INSERT Demo.SalesOrder(SalesOrderId, SalesOrderNumber)
VALUES (@SalesOrderId, '0000000008');

SELECT * FROM Demo.SalesOrder WHERE SalesOrderId = @SalesOrderId


--Inserting a hundred rows
DECLARE @range_first_value sql_variant, @range_last_value sql_variant,
        @sequence_increment sql_variant;

EXEC sp_sequence_get_range @sequence_name = N'Demo.SalesOrder_SEQUENCE' 
     , @range_size = 100
     , @range_first_value = @range_first_value OUTPUT 
     , @range_last_value = @range_last_value OUTPUT 
     , @sequence_increment = @sequence_increment OUTPUT;

SELECT CAST(@range_first_value as int) as firstTopicId,
       CAST(@range_last_value as int) as lastTopicId, 
       CAST(@sequence_increment as int) as increment;

--id and sales order number sync'd for demo ease
INSERT Demo.SalesOrder(SalesOrderId, SalesOrderNumber)
SELECT (I * CAST(@sequence_increment as int)) + CAST(@range_first_value as int),
	   RIGHT('0000000000' + CAST((I * CAST(@sequence_increment as int)) + CAST(@range_first_value as int) as nvarchar(10)),10)
FROM   Tools.Number
WHERE  I between 0 and 99
GO

--Finally, make sure that one last row still works as expected
DECLARE @SalesOrderId int
SET @SalesOrderId = (NEXT VALUE FOR Demo.SalesOrder_SEQUENCE);
INSERT Demo.SalesOrder(SalesOrderId, SalesOrderNumber)
VALUES (@SalesOrderId, '0000000FIN');
SELECT @SalesOrderId;

SELECT *
FROM   Demo.SalesOrder;
GO