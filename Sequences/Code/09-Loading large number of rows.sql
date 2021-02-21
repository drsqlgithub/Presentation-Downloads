USE SequenceDemos
GO

IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.SalesOrder')) 
		DROP TABLE Demo.SalesOrder;

IF EXISTS (SELECT * FROM sys.sequences WHERE object_id = object_id('Demo.SalesOrder_SEQUENCE')) 
		DROP SEQUENCE Demo.SalesOrder_SEQUENCE;
GO

CREATE SEQUENCE Demo.SalesOrder_SEQUENCE
--AS INT START WITH 1 INCREMENT BY 1; --vary sequence for test
AS INT START WITH 42 INCREMENT BY 27; --vary sequence for test
GO

CREATE TABLE Demo.SalesOrder
(
	SalesOrderId	int CONSTRAINT PKSalesOrder PRIMARY KEY 
					    CONSTRAINT DFLTSalesOrder_SalesOrderId 
								DEFAULT(NEXT VALUE FOR Demo.SalesOrder_SEQUENCE),
	SalesOrderNumber char(10) NOT NULL CONSTRAINT AKSalesOrder UNIQUE,
	BatchId  CHAR(10)
)
GO


--Inserting a hundred rows
DECLARE @range_first_value sql_variant, 
		@range_last_value sql_variant,
        @sequence_increment sql_variant;

EXEC sp_sequence_get_range @sequence_name = N'Demo.SalesOrder_SEQUENCE' 
     , @range_size = 100
     , @range_first_value = @range_first_value OUTPUT 
     , @range_last_value = @range_last_value OUTPUT 
     , @sequence_increment = @sequence_increment OUTPUT;

SELECT CAST(@range_first_value as int) as firstTopicId,
       CAST(@range_last_value as int) as lastTopicId, 
       CAST(@sequence_increment as int) as increment;

INSERT Demo.SalesOrder(SalesOrderId, SalesOrderNumber, BatchId)
SELECT --(Position * Increment) + First Value
	   (I * CAST(@sequence_increment as int)) + CAST(@range_first_value as int),

	   --just add zeros to sales order number
	   RIGHT('0000000000' + CAST((I * CAST(@sequence_increment as int)) + CAST(@range_first_value as int) as nvarchar(10)),10),
	   CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65)+ CHAR(RAND() * 26 + 65)+
	   CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65)
FROM   Tools.Number
WHERE  I between 0 and 99
GO

SELECT *
FROM   Demo.SalesOrder

--inserting a second hundred rows

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

INSERT Demo.SalesOrder(SalesOrderId, SalesOrderNumber, BatchId)
SELECT (I * CAST(@sequence_increment as int)) + CAST(@range_first_value as int),
	   RIGHT('0000000000' + CAST((I * CAST(@sequence_increment as int)) + CAST(@range_first_value as int) as nvarchar(10)),10),
	   CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65)+ CHAR(RAND() * 26 + 65)+
	   CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65)
FROM   Tools.Number
WHERE  I between 0 and 99
GO

SELECT *
FROM   Demo.SalesOrder