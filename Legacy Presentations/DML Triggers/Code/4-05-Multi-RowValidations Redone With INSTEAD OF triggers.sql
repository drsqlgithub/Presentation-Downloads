
--This demo is here to demonstrate the intricacies of multi-row data operations. In it I 
--will do some things that aren't 100% best practice, but are reasonably normal to see people 
--do regularly (and very easy to demo the multi-row principle)
Use HowToWriteADmlTrigger;
go


--reset the objects for this section
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Characters.Person')) 
		DROP TABLE Characters.Person;
go
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Characters')
	EXEC ('CREATE SCHEMA Characters')
GO

--simple trigger that checks to make sure that some data fits a format
--best way to do this particular task is with a constraint, but it is a simple
--task that keeps the trigger simple
create table Characters.Person
(
	PersonId	int NOT NULL IDENTITY PRIMARY KEY,
	PersonNumber CHAR(2) UNIQUE,
	FirstName	nvarchar(20) null, --CHECK (len(FirstName) > 0) would be best
	LastName	nvarchar(20) not null --CHECK (len(LastName) > 0) would be best
)
--I’m going to demo code on a properly configured server with best practices code. 
--Then you’re all going to [complain] that it takes too long. --@peschkaj Jeremiah Peschka
go
/* include an instead of trigger to the illustration */

/**************************************************************************
WARNING: Thes are strictly to show what happens and do nothing else
****************************************************************************/
CREATE TRIGGER Characters.Person$insteadeOfInsertTrigger
ON Characters.Person
INSTEAD OF  INSERT AS
--trigger used to make sure that all names have a first and last name that is non-empty
BEGIN
   --for demo/testing
   --IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   --for demo/testing
   --IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY	 
          --[validation section] In this section, you should just look for issues and THROW errors

		  --first to show what is in these tables
		  select '************************************************'
		  SELECT CASE WHEN (SELECT COUNT(*) FROM inserted) > 0 THEN 'INSTEAD OF INSERT' 
					  ELSE 'INSTEAD OF INSERT-Nothing Modified' END
		  SELECT 'deleted     ', *
		  FROM   DELETED;

		  SELECT 'inserted    ', *
		  FROM   INSERTED;
		  SELECT 'actual table - BEFORE PERFORMING OPERATION', *
		  FROM   Characters.Person
		  select '************************************************'

          --[modification section] In this section, the goal is no errors and do any data mods here
		  --Perform Action

		  insert into Characters.Person(PersonNumber,FirstName	,LastName)
		  select PersonNumber,FirstName	,LastName
		  from   inserted
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

CREATE TRIGGER Characters.Person$insteadeOfUpdateTrigger
ON Characters.Person
INSTEAD OF  UPDATE AS
--trigger used to make sure that all names have a first and last name that is non-empty
BEGIN
   --for demo/testing
   --IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   --for demo/testing
   --IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY	 
          --[validation section] In this section, you should just look for issues and THROW errors

		  --first to show what is in these tables
		  select '************************************************'
		  SELECT CASE WHEN (SELECT COUNT(*) FROM inserted) > 0 THEN 'INSTEAD OF UPDATE' 
					  ELSE 'INSTEAD OF UPDATE-Nothing Modified' END
		  SELECT 'deleted     ', *
		  FROM   DELETED;

		  SELECT 'inserted    ', *
		  FROM   INSERTED;
		  SELECT 'actual table - BEFORE PERFORMING OPERATION', *
		  FROM   Characters.Person
		  select '************************************************'

          --[modification section] In this section, the goal is no errors and do any data mods here
		  --Perform Action

		  UPDATE Characters.Person
		  Set PersonNumber = inserted.PersonNumber,
			  FirstName	 = inserted.FirstName, 
			  LastName = inserted.LastName
		  from   inserted
					join Characters.Person
						on inserted.PersonId = Person.PersonId
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


CREATE TRIGGER Characters.Person$insteadeOfDeleteTrigger
ON Characters.Person
INSTEAD OF  DELETE AS
--trigger used to make sure that all names have a first and last name that is non-empty
BEGIN
   --for demo/testing
   --IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   --for demo/testing
   --IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY	 
          --[validation section] In this section, you should just look for issues and THROW errors

		  --first to show what is in these tables
		  select '************************************************'
		  SELECT CASE WHEN (SELECT COUNT(*) FROM deleted) > 0 THEN 'INSTEAD OF DELETE' 
					  ELSE 'INSTEAD OF DELETE-Nothing Modified' END
		  SELECT 'deleted     ', *
		  FROM   DELETED;

		  SELECT 'inserted    ', *
		  FROM   INSERTED;
		  SELECT 'actual table - BEFORE PERFORMING OPERATION', *
		  FROM   Characters.Person
		  select '************************************************'

          --[modification section] In this section, the goal is no errors and do any data mods here
		  --Perform Action

		  DELETE Characters.Person
		  from   inserted
					join Characters.Person
						on inserted.PersonId = Person.PersonId
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO



/**************************************************************************
WARNING: This is an anti-example to show the dangers of procedural thinking
****************************************************************************/
CREATE TRIGGER Characters.Person$insertTrigger
ON Characters.Person
AFTER INSERT AS
--trigger used to make sure that all names have a first and last name that is non-empty
--in a very common and reasonable looking manner
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
		 
 		  declare @FirstName nvarchar(20),
				  @LastName  nvarchar(20)
		  select @FirstName = FirstName,
		         @LastName = LastName
		  FROM   Inserted

		  if @FirstName = ''
			THROW 50000, N'First Name cannot be blank',1;
		  if @LastName = ''
			THROW 50000, N'Last Name cannot be blank',1;
		  

         --[modification section] In this section, the goal is no errors and do any data mods here
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--test methodology:

--one correct row...
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('FF','Fred', 'Flintstone');
GO
--two correct rows...
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('BR','Barney', 'Rubble'),
	   ('TR','Betty', 'Rubble');
GO
--one wrong row
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('DO','Dino', '');
go
--one wrong row with other correct rows, order doesn't matter in SQL, right?
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('DO','Dino', ''),
	   ('WF','Wilma','Flintstone'),
	   ('PF','Pebbles','Flintstone');
GO


SELECT *
FROM   Characters.Person

--bam... next task... right? SPOILER ALERT...You haven't tested enough...
--and the only thing worse than NOT testing your code is POORLY testing your code.


--



--




--




--

/* Think: What will this section do:

 		  declare @FirstName nvarchar(20),
				  @LastName  nvarchar(20)
		  select @FirstName = FirstName,
		         @LastName = LastName
		  FROM   Inserted

		  if @FirstName = ''
			THROW 50000, N'First Name cannot be blank',1;
		  if @LastName = ''
			THROW 50000, N'Last Name cannot be blank',1;

*/


--Will this fail?
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('BB','Bamm-Bamm','Rubble'),
	   ('DO','Dino', ''),
	   ('S ','Stone',''),
	   ('R ','Rocky','')
Go

--Crud
SELECT  *
FROM    Characters.Person 
go

--Because of our coding style ORDER did matter... Order should NEVER matter
TRUNCATE TABLE Characters.Person;
GO

/**************************************************************************
The right way, thinking in sets!
****************************************************************************/

ALTER TRIGGER Characters.Person$insertTrigger
ON Characters.Person
AFTER INSERT AS
--trigger used to make sure that all names have a first and last name that is non-empty
BEGIN
   --for demo/testing
   --IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   --for demo/testing
   --IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY	 
          --[validation section] In this section, you should just look for issues and THROW errors

		  --first to show what is in these tables
		  select '************************************************'
		  SELECT CASE WHEN (SELECT COUNT(*) FROM inserted) > 0 THEN 'INSERT' 
					  ELSE 'INSERT-Nothing Modified' END
		  SELECT 'deleted     ', *
		  FROM   DELETED;

		  SELECT 'inserted    ', *
		  FROM   INSERTED;
		  SELECT 'actual table - BEFORE ERROR CHECKING', *
		  FROM   Characters.Person
		  select '************************************************'

          --could do both checks in one pass but this is often 
          --the easiest way to get best error messages
		  if exists (select *
					 from   Inserted
					 where  FirstName = '') 
			THROW 50000, N'First Name cannot be blank',1;

		  if exists (select *
					 from   Inserted
					 where  LastName = '') 
			THROW 50000, N'Last Name cannot be blank',1;
		  



          --[modification section] In this section, the goal is no errors and do any data mods here
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--one correct row...
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('FF','Fred', 'Flintstone');
GO
--two correct rows...
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('BR','Barney', 'Rubble'),
	   ('TR','Betty', 'Rubble');
GO
--one wrong row
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('DO','Dino', '');
go
--one wrong row with other correct rows, order doesn't matter in SQL, right?
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('DO','Dino', ''),
	   ('WF','Wilma','Flintstone'),
	   ('PF','Pebbles','Flintstone');
GO

--Will this fail?
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('BB','Bam Bam','Rubble'),
	   ('DO','Dino', ''),
	   ('S ','Stone',''),
	   ('R ','Rocky','')
Go

select *
from   Characters.Person 
go
SELECT *
FROM   Utility.ErrorLog

/*******************************
Quick Discussion: Do we NEED to test multiple row orders?

		  if exists (select *
					 from   Inserted
					 where  FirstName = '') 
			THROW 50000, N'First Name cannot be blank',1;

		  if exists (select *
					 from   Inserted
					 where  LastName = '') 
			THROW 50000, N'Last Name cannot be blank',1;

********************************/
go

--UPDATE, MERGE--
--Create the UPDATE trigger
CREATE TRIGGER Characters.Person$UpdateTrigger
ON Characters.Person
AFTER UPDATE AS
--trigger used to make sure that all names have a first and last name that is non-empty
BEGIN
   --removed for demo only
   --IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   --reoved for demo only
   --IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY	 
          --[validation section] In this section, you should just look for issues and THROW errors
		 
		  --first to show what is in these tables
		  select '************************************************'
		  SELECT CASE WHEN (SELECT COUNT(*) FROM inserted) > 0 THEN 'UPDATE' 
					  ELSE 'UPDATE-Nothing Modified' END
		  SELECT 'deleted     ', *
		  FROM   DELETED;
		  SELECT 'inserted    ', *
		  FROM   INSERTED;
		  SELECT 'actual table - BEFORE ERROR CHECKING', *
		  FROM   Characters.Person
		  select '************************************************'

		  if UPDATE (FirstName) 
		  BEGIN
			  --could do both checks in one pass but this is often 
			  --the easiest way to get best error messages
			  if exists (select *
						 from   Inserted
						 where  FirstName = '') 
				THROW 50000, N'First Name cannot be blank',1;
		  END
		  IF UPDATE(LastName)
		  BEGIN
		  if exists (select *
					 from   Inserted
					 where  LastName = '') 
			THROW 50000, N'Last Name cannot be blank',1;
		  END

          --[modification section] In this section, the goal is no errors and do any data mods here
		  
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO




select *
from   Characters.Person

update Characters.Person
set    FirstName = 'Frederick'
where  PersonNumber = 'FF'

update Characters.Person
set    FirstName = UPPER(FirstName)
where  LastName = 'Rubble'
go

--imagine how long this oops would take on a real table...
update Characters.Person
set    FirstName = ''
go



SELECT *
FROM   Characters.Person



--triggers called even when no changes...
;WITH   testMerge as (SELECT *
                     FROM   (Values('FF','Fred','Flintstone'), --Update (name was Frederick)
								   ('WF','Wilma','Flintstone'), --Insert
								   ('TR','Betty','Rubble'))  -- No change (case insensitive collation)
								    --Barney will be deleted
														as testMerge (PersonNumber,FirstName, LastName))
MERGE  Characters.Person
USING  (SELECT PersonNumber,FirstName, LastName FROM testMerge) AS source (PersonNumber,FirstName, LastName)
        ON (person.PersonNumber = source.personNumber
		    )
WHEN MATCHED AND (Person.FirstName <> source.FirstName 
                  OR (Person.FirstName IS NULL AND Source.FirstName IS NOT NULL)
				  OR (Person.FirstName IS NOT NULL AND Source.FirstName IS NULL)
				  OR Person.LastName <> Source.LastName) THEN  
	UPDATE SET FirstName = source.FirstName,
			 LastName = SOURCE.LastName
WHEN NOT MATCHED THEN
	INSERT (PersonNumber,FirstName,LastName) VALUES (Source.PersonNumber,Source.FirstName,Source.LastName)
WHEN NOT MATCHED BY SOURCE THEN 
     DELETE;
Go

SELECT *
FROM   Characters.Person

------------------------------------------------
--the problem with updatable keys. In this example, we scramble the unique key, and the only
--data we can use to figure out pre- and post- images is in the immutable surrogate key
UPDATE Characters.Person
SET    PersonNumber = CASE PersonNumber WHEN 'WF' THEN 'TR'
										WHEN 'FF' THEN 'WF'
										WHEN 'TR' THEN 'FF' END

