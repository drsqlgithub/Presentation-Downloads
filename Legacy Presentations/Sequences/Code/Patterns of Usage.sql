IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.SalesOrder')) DROP TABLE Demo.SalesOrder;
GO

CREATE TABLE Demo.SalesOrder
(
	SalesOrderId	int IDENTITY CONSTRAINT PKSalesOrder PRIMARY KEY,
	SalesOrderNumber char(10) NOT NULL CONSTRAINT AKSalesOrder UNIQUE,
	RowModifyDate datetime2(3) NOT NULL,
	RowCreateDate datetime2(3) NOT NULL,
)
GO

INSERT Demo.SalesOrder(SalesOrderNumber, RowCreateDate, RowModifyDate)
VALUES ('0000000001',SYSDATETIME(), SYSDATETIME());

SELECT SCOPE_IDENTITY();
GO


INSERT Demo.SalesOrder(SalesOrderNumber, RowCreateDate, RowModifyDate)
VALUES ('0000000002','2010-01-01', '2010-01-01');

SELECT SCOPE_IDENTITY();
GO

SELECT *
FROM   Demo.SalesOrder
GO

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

INSERT Demo.SalesOrder(SalesOrderNumber)
VALUES ('0000000003');
SELECT SCOPE_IDENTITY();
GO

INSERT Demo.SalesOrder(SalesOrderNumber)
VALUES ('0000000004');
SELECT SalesOrderId FROM Demo.SalesOrder where SalesOrderNumber = '0000000004';
GO

----------------------------------------------------------------------------
-- Here too is where identity columns are really inflexible.  We will have to 
-- drop the column...
----------------------------------------------------------------------------

ALTER TABLE Demo.SalesOrder DROP CONSTRAINT PKSalesOrder
EXEC sp_rename 'Demo.SalesOrder.SalesOrderId' , 'SalesOrderIdOld', 'COLUMN'
GO

ALTER TABLE Demo.SalesOrder
	ADD SalesOrderId int;
GO
UPDATE Demo.SalesOrder
SET    SalesOrderId = SalesOrderIdOld
GO
SELECT *
FROM   Demo.SalesOrder
GO

ALTER TABLE Demo.SalesOrder
  DROP COLUMN SalesOrderIdOld
GO

ALTER TABLE Demo.SalesOrder
	ALTER COLUMN SalesOrderId int NOT NULL

ALTER TABLE Demo.SalesOrder
   ADD CONSTRAINT PKSalesOrder PRIMARY KEY (SalesOrderId);
GO

CREATE SEQUENCE Demo.SalesOrder_SEQ
AS INT START WITH 1 INCREMENT BY 1;
GO

ALTER TABLE Demo.SalesOrder
   ADD CONSTRAINT DFLTSalesOrder_SalesOrderId 
	DEFAULT (NEXT VALUE FOR Demo.SalesOrder_SEQ) FOR SalesOrderId
GO

DECLARE @SalesOrderId int
SELECT @salesOrderId = COALESCE(MAX(SalesOrderId),0) + 1
FROM   Demo.SalesOrder

--ALTER SEQUENCE wont work without a variable
DECLARE @queryText nvarchar(1000) = CONCAT('ALTER SEQUENCE Demo.SalesOrder_SEQ
     RESTART WITH ',@salesOrderId)

EXEC (@queryText)
SELECT current_value
FROM   sys.sequences
where  object_id = object_id('Demo.SalesOrder_SEQ')
GO

INSERT Demo.SalesOrder(SalesOrderNumber)
VALUES ('0000000005');
SELECT SalesOrderId FROM Demo.SalesOrder WHERE SalesOrderNumber = '0000000005';
GO
SELECT *
FROM   Demo.SalesOrder
GO

DECLARE @SalesOrderId int
SET @SalesOrderId = (NEXT VALUE FOR Demo.SalesOrder_SEQ);
INSERT Demo.SalesOrder(SalesOrderId, SalesOrderNumber)
VALUES (@SalesOrderId, '0000000006');
SELECT @SalesOrderId
GO

--Inserting a hundred rows
DECLARE @range_first_value sql_variant, @range_last_value sql_variant,
        @sequence_increment sql_variant;

EXEC sp_sequence_get_range @sequence_name = N'Demo.SalesOrder_SEQ' 
     , @range_size = 100
     , @range_first_value = @range_first_value OUTPUT 
     , @range_last_value = @range_last_value OUTPUT 
     , @sequence_increment = @sequence_increment OUTPUT;

SELECT CAST(@range_first_value as int) as firstTopicId,
       CAST(@range_last_value as int) as lastTopicId, 
       CAST(@sequence_increment as int) as increment;

INSERT Demo.SalesOrder(SalesOrderId, SalesOrderNumber)
SELECT (I * CAST(@sequence_increment as int)) + CAST(@range_first_value as int),
	   RIGHT('0000000000' + CAST((I * CAST(@sequence_increment as int)) + CAST(@range_first_value as int) as nvarchar(10)),10)
FROM   Tools.Number
WHERE  I between 0 and 99
GO

SELECT *
FROM   Demo.SalesOrder
