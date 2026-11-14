Use HowToWriteADmlTrigger;
go

IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.Child'))
		DROP TABLE Demo.Child;
go
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.Parent')) 
		DROP TABLE Demo.Parent;
go
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE Name = 'Demo')
	EXEC ('CREATE SCHEMA Demo')
go 

CREATE TABLE Demo.Parent
(
	ParentId	INT PRIMARY KEY,
	Name        VARCHAR(10) NOT NULL
)
CREATE TABLE Demo.Child
(
	ChildId     INT PRIMARY KEY,
	ParentId    INT NULL --REFERENCES Demo.Parent (ParentId), not possible because actual tables would be in 
					     --different databases
)
INSERT INTO Demo.Parent(ParentId,Name)
VALUES (1,'One'),(2,'Two')
INSERT INTO Demo.Child(ChildId,ParentId)
VALUES (1,1),(2,2),(3,2)

--validation query
SELECT 'No data returned from next query is good :)'
SELECT *
FROM   Demo.Child
WHERE  NOT EXISTS (SELECT *
					FROM  Demo.Parent 
					WHERE Parent.ParentId = Child.ParentId)

GO

/************************************************
Starting with the Child
*************************************************/

CREATE TRIGGER Demo.Child$insertTrigger
ON Demo.Child
AFTER INSERT AS 
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors

		  --@numrows is part of the standard template
		  DECLARE @nullcount int,
				  @validcount int

		  IF UPDATE(ParentId) --ParentId is nullable
		   BEGIN
			  --NOTE: The KEY to many INSERT validations is to make sure ALL rows are good, not just some
			  --this is not the only way to implement, but this is how to implement a "positive" 
			  --check rather than a negative one (first saw this in an ERwin generated trigger "years" ago)
           
			  --you can omit this check if nulls are not allowed
			  SELECT  @nullcount = count(*) --count the number of null rows
			  FROM    inserted    
			  WHERE   inserted.ParentId is null

			  --does not count include null values
			  SELECT  @validcount = count(*) --coount the number of rows that are correct and not null
			  FROM    inserted
						 JOIN Demo.Parent 
								ON  inserted.ParentId = Parent.ParentId
                
			  if @validcount + @nullcount != @rowsAffected
				BEGIN
					IF @rowsAffected = 1
					   SELECT @msg = 'The inserted ParentId: '
										+ cast(ParentId as varchar(10))
										+ ' is not valid in the Parent table.'
						FROM   INSERTED
					ELSE
						SELECT @msg = 'Invalid ParentId in the inserted rows.'
					 RAISERROR (@msg, 16, 1)
				 END
			END


          --[modification section] In this section, the goal is no errors and do any data mods here
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysName = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--Test

--bad rows
INSERT INTO Demo.Child(ChildId,ParentId)
VALUES (4,-1)
GO
INSERT INTO Demo.Child(ChildId,ParentId)
VALUES (4,1),(5,-1)
GO

--good rows
INSERT INTO Demo.Child(ChildId,ParentId)
VALUES (4,2)
GO
INSERT INTO Demo.Child(ChildId,ParentId)
VALUES (5,2),(6,1)
GO

--validation query
SELECT 'No data returned from next query is good :)'
SELECT *
FROM   Demo.Child
WHERE  NOT EXISTS (SELECT *
					FROM  Demo.Parent 
					WHERE Parent.ParentId = Child.ParentId)

GO


--basically same as the insert. I favor 1 trigger per action in most interactive code
CREATE TRIGGER Demo.Child$updateTrigger
ON Demo.Child
AFTER UPDATE AS 
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors

		  DECLARE @nullcount int,
				  @validcount int

		  IF UPDATE(ParentId)
		   BEGIN
			  --you can omit this check if nulls are not allowed
			  SELECT  @nullcount = count(*)
			  FROM    inserted    
			  WHERE   inserted.ParentId is null

			  --does not count include null values
			  SELECT  @validcount = count(*)
			  FROM    inserted
						 JOIN Demo.Parent 
								ON  inserted.ParentId = Parent.ParentId
                
			  if @validcount + @nullcount != @rowsAffected
				BEGIN
					IF @rowsAffected = 1
					   SELECT @msg = 'Updating ChildId: ' + 
									    + CAST (deleted.childId AS VARCHAR(10)) + 
										+ ' to ParentId: '
										+ cast(inserted.ParentId as varchar(10))
										+ ' is not valid in the Parent table.'
						FROM   DELETED
								CROSS JOIN INSERTED --we know 1 row each                      
					ELSE
						SELECT @msg = 'Invalid ParentId in the updated rows.'
					 RAISERROR (@msg, 16, 1)
				 END
			END


          --[modification section] In this section, the goal is no errors and do any data mods here
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysName = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

SELECT *
FROM   Demo.Parent
SELECT *
FROM   Demo.Child

UPDATE Demo.Child
SET    ParentId = -1
WHERE  ChildId = 1
go
UPDATE Demo.Child
SET    ParentId = -1
go

--set one row to a correct value
UPDATE Demo.Child
SET ParentId = 2
WHERE  ChildId = 6 
GO

--set multiple rows to a correct value
UPDATE Demo.Child
SET ParentId = 1
WHERE  ParentId = 2
GO

SELECT *
FROM   Demo.Parent
		 JOIN Demo.Child
			ON Parent.ParentId = Child.ParentId

--validation query
SELECT 'No data returned from next query is good :)'
SELECT *
FROM   Demo.Child
WHERE  NOT EXISTS (SELECT *
					FROM  Demo.Parent 
					WHERE Parent.ParentId = Child.ParentId)

GO



/************************************************
Parent Validations
*************************************************/

--Parent delete. I favor 1 trigger per action in most interactive code
CREATE TRIGGER Demo.Parent$deleteTrigger
ON Demo.Parent
AFTER DELETE AS 
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
   --    @rowsAffected int = (SELECT COUNT(*) FROM inserted);
         @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors
  
			IF EXISTS ( SELECT  * 
						FROM    Demo.Child
						WHERE   EXISTS (SELECT *
										FROM   DELETED
										WHERE  Child.ParentId = deleted.ParentId)
					)
			BEGIN
				IF @rowsAffected = 1
					SELECT @msg = CONCAT('Deleting ParentId: ',deleted.ParentId, ' will leave Child rows orphaned.')
					FROM   deleted
					ELSE
					SELECT @msg = 'Deleting one or more you Parent rows you attempted to will leave Child rows orphaned.'
				RAISERROR (@msg, 16, 1)
			END

          --[modification section] In this section, the goal is no errors and do any data mods here
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysName = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--fail, all Children are Children of 1
DELETE FROM Demo.Parent
WHERE  ParentId = 1

--see above
DELETE FROM Demo.Parent
go

--success
DELETE FROM Demo.Parent
WHERE  ParentId = 2
go

--double success
INSERT INTO Demo.Parent( ParentId, Name)
VALUES  ( 3, 'Three' ), ( 4, 'Four' ) 
go

DELETE FROM  Demo.Parent
WHERE  ParentId = 3 
  OR   ParentId = 4
GO


SELECT *
FROM   Demo.Parent
go


--Finally, Parent update. 
CREATE TRIGGER Demo.Parent$updateTrigger
ON Demo.Parent
AFTER UPDATE AS 
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
   --    @rowsAffected int = (SELECT COUNT(*) FROM inserted);
         @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors
  
		    IF UPDATE (ParentId)
			 BEGIN 
					IF EXISTS ( SELECT  * --see if any child rows exist
								FROM    Demo.Child --the exists gets us all of the child rows
								WHERE   EXISTS (SELECT * --that used to be related to the parent
												FROM   DELETED
												WHERE  DELETED.ParentId = Child.ParentId)
								  AND   NOT EXISTS (SELECT * --and make sure they now have a parent
													FROM   Demo.Parent
													WHERE  Child.ParentId = Parent.ParentId)
																
						)
					BEGIN
						IF @rowsAffected = 1
							SELECT @msg = CONCAT('Updating ParentId: ',deleted.ParentId, ' will leave Child rows orphaned.')
							FROM   deleted
							ELSE
							SELECT @msg = 'Updating one or more you Parent rows you attempted to will leave Child rows orphaned.'
						RAISERROR (@msg, 16, 1)
					END
		     END           

          --[modification section] In this section, the goal is no errors and do any data mods here
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysName = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--good example
INSERT INTO Demo.Parent( ParentId, Name)
VALUES  ( 5, 'Five' )
go

UPDATE Demo.Child
SET    ParentId = 5
WHERE  ChildId IN (4,5,6) 
GO
SELECT *
FROM  Demo.Parent
SELECT *
FROM   Demo.Child
GO

--would leave orphaned rows
UPDATE Demo.Parent
SET   ParentId = 6
WHERE  ParentId = 1
GO

--will fail
UPDATE Demo.Parent
SET   ParentId = CASE WHEN ParentId = 1 THEN 5 ELSE -1 END 
WHERE ParentId = 1
	  OR  ParentId = 5
go

SELECT *
FROM   Demo.Parent
SELECT *
FROM   Demo.Child
GO

--will succeed...
UPDATE Demo.Parent
SET   ParentId = CASE WHEN ParentId = 1 THEN 5 ELSE 1 END --swapping the values
WHERE ParentId = 1
	  OR  ParentId = 5
go

SELECT *
FROM   Demo.Parent
SELECT *
FROM   Demo.Child