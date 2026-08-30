Use HowToWriteADmlTrigger;
go



-------------------------------------------------------------------------
-- Instead of Trigger Making a View act Like a Table with Multiple Tables

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE Name = 'Example')
	EXEC ('CREATE SCHEMA Example;')
GO
IF EXISTS (SELECT * FROM sys.views where object_id = OBJECT_ID('Example.TableName'))
		DROP VIEW Example.TableName;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Example.TableName'))
		DROP TABLE Example.TableName;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Example.TableNameA'))
		DROP TABLE Example.TableNameA;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Example.TableNameB'))
		DROP TABLE Example.TableNameB;

--say you have a simple enough table...
create table Example.TableName
(
	TableNameId int PRIMARY KEY,
	ValueA	varchar(10) NULL,
	ValueB  varchar(10) NULL
)
go

--with some simple enough data
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (1, NULL, '10');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (2, '20', '20');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (3, '30', NULL);
GO       

select *
from   Example.TableName
GO

--Now say you need to partition the table for some reason...
CREATE TABLE Example.TableNameA
(
    TableNameId int PRIMARY KEY,
    ValueA  varchar(10) NULL
)
CREATE TABLE Example.TableNameB
(
    TableNameId int PRIMARY KEY,
    ValueB  varchar(10) NULL
)
GO

--split the data...Only put rows that are non-null...
insert into Example.TableNameA
select TableNameId, valueA
from   Example.TableName
where  valueA is not null

insert into Example.TableNameB
select TableNameId, ValueB
from   Example.TableName
where ValueB is not null;
GO

select *
from   Example.TableNameA
select *
from   Example.TableNameB

go

--get rid of the real table
drop table Example.TableName
go

CREATE VIEW Example.TableName
AS 
    SELECT  coalesce(tableNameA.tableNameId, tableNameB.tableNameId) AS TableNameId,
            TableNameA.ValueA, TableNameB.ValueB
    FROM    Example.TableNameA
                FULL OUTER JOIN Example.TableNameB
                    ON tableNameA.tableNameId = tableNameB.tableNameId
GO 

select *
from Example.Tablename
go

--now we want to use the view like a table, but this won't work 
--as is because the view isn't on just one table.
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (4, NULL, '10');
go
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (5, '20', '20');
go
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (6, '30', NULL);
GO              

--so we will create an instead of trigger that does the insert for us
CREATE TRIGGER Example.TableName$InsteadOfInsertTrigger
ON Example.TableName
INSTEAD OF INSERT AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

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
          --[validation section] In this section, you should just look for issues and THROW errors
          --[modification section] In this section, the goal is no errors but do any data mods here
          --<perform action>  In this section (generally the only one used in an instead of trigger), youi
		                    --will usually cause the operation replaced by the trigger to occur
		INSERT INTO Example.TableNameA(TableNameId,ValueA)
		SELECT TableNameId, ValueA
		FROM inserted
		WHERE ValueA IS NOT null; 

		INSERT INTO Example.TableNameB(TableNameId,ValueB)
		SELECT TableNameId, ValueB
		FROM inserted
		WHERE ValueB IS NOT null
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

      --[Error logging section]
      DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
               @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
               @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
      EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;

go

--now we want to use the view like a table, and the instead of 
--trigger allows that
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (4, NULL, '10');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (5, '20', '20');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (6, '30', NULL);
GO      

SELECT *
FROM   Example.TableName
GO 

--Now we try to do an update on the view:
UPDATE Example.TableName --seems to work but no rows modified (the row for A doesn't exist!)
SET    ValueA = 'U10'
WHERE  TableNameId = 1 

SELECT *
FROM   Example.TableName
WHERE  TableNameId = 1
GO 
UPDATE Example.TableName --updates both tables
SET    ValueA = 'U20',
       ValueB = 'U21'
WHERE  tableNameId = 2 
GO
UPDATE Example.TableName
SET    ValueB = 'U30'
WHERE  tableNameId = 3
GO 

SELECT *
FROM Example.TableName
GO 

--so to make this view updatable in a reasonable manner, we need to 
--use an insead of trigger
CREATE TRIGGER Example.TableName$InsteadOfUpdateTrigger 
ON Example.TableName
INSTEAD OF UPDATE AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

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
          --[validation section] In this section, you should just look for issues and THROW errors
          --[modification section] In this section, the goal is no errors but do any data mods here
          --<perform action>  In this section (generally the only one used in an instead of trigger), youi
		                    --will usually cause the operation replaced by the trigger to occur
		    UPDATE TableNameA
			SET    ValueA = inserted.ValueA
			FROM   Example.TableNameA
					  JOIN inserted
						  ON TableNameA.TableNameId = inserted.TableNameId
			IF @@rowcount <> @rowsAffected --there may still be rows to deal with
			  BEGIN
					INSERT INTO Example.TableNameA(TableNameId,ValueA)
					SELECT TableNameId, ValueA
					FROM inserted
					WHERE ValueA IS NOT NULL
					  AND NOT EXISTS (SELECT *
									  FROM   Example.TableNameA
									  WHERE  TableNameA.TableNameId = inserted.TableNameId)
			  END 

			UPDATE TableNameB
			SET    ValueB = inserted.ValueB
			FROM   Example.TableNameB
					  JOIN inserted
						  ON tableNameB.tableNameId = inserted.tableNameId 

			IF @@rowcount <> @rowsAffected  --there may still be rows to deal with
			  BEGIN
					INSERT INTO Example.TableNameB(TableNameId,ValueB)
					SELECT TableNameId, ValueB
					FROM inserted
					WHERE ValueB IS NOT NULL
					  AND NOT EXISTS (SELECT *
									  FROM   Example.TableNameB
									  WHERE  TableNameB.TableNameId = inserted.TableNameId)
			  END
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

	  --[Error logging section]
	  DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		      @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		      @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
      EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO 

UPDATE Example.TableName
SET    ValueA = 'U10'
WHERE  tableNameId = 4 

UPDATE Example.TableName
SET    ValueA = 'U20',
       ValueB = 'U21'
WHERE  tableNameId = 5 

UPDATE Example.TableName
SET    ValueB = 'U30'
WHERE  tableNameId = 6
GO 

SELECT *
FROM Example.TableName
go

UPDATE Example.TableName
SET    valueB = 'UAll'
GO

UPDATE Example.TableName
SET    valueA = 'UAll'
GO

SELECT *
FROM Example.TableName
go

--optimistic aren't I?
delete Example.TableName
go


CREATE TRIGGER Example.TableName$InsteadOfDeleteTrigger
ON Example.TableName
INSTEAD OF DELETE AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
    ---@rowsAffected int = (SELECT COUNT(*) FROM inserted);
			@rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;


   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors
          --[modification section] In this section, the goal is no errors but do any data mods here
          --<perform action>  In this section (generally the only one used in an instead of trigger), youi
		                    --will usually cause the operation replaced by the trigger to occur
		    DELETE tableNameA
			FROM   Example.tableNameA
					  JOIN deleted
						  ON tableNameA.tableNameId = deleted.tableNameId

			DELETE tableNameB
			FROM   Example.tableNameB
					  JOIN deleted
						  ON tableNameB.tableNameId = deleted.tableNameId 
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

      --[Error logging section]
	  DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
	          @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
	          @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
	  EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;
      
	  THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO 


select *
from   Example.TableName;
GO
--delete 1 row
delete Example.TableName
WHERE TableNameId = 6
go

SELECT *
FROM Example.tableName
go

--delete > 1 row
delete Example.TableName
WHERE tableNameId > 3
go

SELECT *
FROM Example.TableName
go

--Obviously this is unlikely
truncate table Example.Tablename
go

--but you could do:
truncate table Example.TablenameA
go
truncate table Example.TablenameB
go


--empty!
SELECT *
FROM Example.tableName
go

