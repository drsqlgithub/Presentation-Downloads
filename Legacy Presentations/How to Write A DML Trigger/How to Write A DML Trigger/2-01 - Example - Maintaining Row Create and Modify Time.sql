Use HowToWriteADmlTrigger;
go

IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Characters.Person')) 
		DROP TABLE Characters.Person;
go


--simple trigger that checks to make sure that some data fits a format
--best way to do this particular task is with a constraint, but it is a simple
--task that keeps the trigger simple
CREATE TABLE Characters.Person
    (
      PersonId INT NOT NULL IDENTITY PRIMARY KEY ,
      PersonNumber CHAR(2) UNIQUE ,
      FirstName NVARCHAR(20) NULL CHECK (len(FirstName) > 0), 
      LastName NVARCHAR(20) NOT NULL CHECK (len(LastName) > 0), 
      RowLastModifiedTime DATETIME2(3) NOT NULL
                                       DEFAULT ( SYSDATETIME() ) ,
      RowCreatedTime DATETIME2(3) NOT NULL
                                  DEFAULT ( SYSDATETIME() )
    )
GO

INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('FF','Fred', 'Flintstone');
GO

SELECT *, CASE WHEN RowLastModifiedTime <= '20000101' OR 
					RowCreatedTime <= '20000101' THEN '<--- Really?' ELSE '' END 
FROM   Characters.Person
GO


--trusting the user doesn't do this...
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName,RowLastModifiedTime,RowCreatedTime)
VALUES ('BR','Barney', 'Rubble','19950101','19950101'),
	   ('TR','Betty', 'Rubble','19950101','19950101');
GO

SELECT *, CASE WHEN RowLastModifiedTime <= '20000101' OR 
					RowCreatedTime <= '20000101' THEN '<--- Really?' ELSE '' END 
FROM   Characters.Person
GO


--or this
UPDATE Characters.Person
SET FirstName = 'Frederick',
	RowLastModifiedTime = '19910101',
	RowCreatedTime = '19910101'
WHERE  PersonNumber = 'FF'
go

SELECT *, CASE WHEN RowLastModifiedTime <= '20000101' OR 
					RowCreatedTime <= '20000101' THEN '<--- Really?' ELSE '' END 
FROM   Characters.Person
GO


CREATE TRIGGER Characters.Person$InsteadOfInsertTrigger
ON Characters.Person
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
   --@rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;


   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors

          --[modification section] In this section, the goal is no errors but do any data mods to other tables
		  --                       here. Rarely used for instead of triggers

          --<perform action>  In this section (generally the only one used in an instead of trigger), you
		                    --will usually cause the operation replaced by the trigger to occur

		  INSERT INTO Characters.Person(PersonNumber, FirstName, LastName, RowLastModifiedTime, RowCreatedTime)
		  SELECT PersonNumber, FirstName, LastName, SYSDATETIME(), SYSDATETIME() --<< Make sure system times enforced
		  FROM INSERTED;
						
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

CREATE TRIGGER Characters.Person$InsteadOfUpdateTrigger
ON Characters.Person
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

          --[modification section] In this section, the goal is no errors but do any data mods to other tables
		  --                       here. Rarely used for instead of triggers

          --<perform action>  In this section (generally the only one used in an instead of trigger), you
		                    --will usually cause the operation replaced by the trigger to occur

		  UPDATE Person
		  SET	PersonNumber = INSERTED.PersonNumber,
				FirstName = INSERTED.FirstName,
				LastName = INSERTED.LastName,
				RowLastModifiedTime = SYSDATETIME() --never use inputted time
				--RowCreatedTime Leave it alone, so it says as is
		  FROM  Characters.Person
					JOIN INSERTED
						ON Person.personId = INSERTED.personId;                  
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




TRUNCATE TABLE Characters.Person
GO

INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('FF','Fred', 'Flintstone');
GO

SELECT *, CASE WHEN RowLastModifiedTime <= '20000101' OR 
					RowCreatedTime <= '20000101' THEN '<--- Really?' ELSE '' END 
FROM   Characters.Person
GO

--Now it doesn't matter if user doesn't do this...
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName,RowLastModifiedTime,RowCreatedTime)
VALUES ('BR','Barney', 'Rubble','19950101','19950101'),
	   ('TR','Betty', 'Rubble','19950101','19950101');
GO

--or this
UPDATE Characters.Person
SET FirstName = 'Frederick',
	RowLastModifiedTime = '19910101',
	RowCreatedTime = '19910101'
WHERE  PersonNumber = 'FF'
go

SELECT *, CASE WHEN RowLastModifiedTime <= '20000101' OR 
					RowCreatedTime <= '20000101' THEN '<--- Really?' ELSE '' END 
FROM   Characters.Person
GO

/*********************
A few examples of caution
**********************/

--#1 instead of INSERT trigger and Scope_identity
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('SS','Sam', 'Slate');

SELECT SCOPE_IDENTITY()
GO

--Way around this, use the alternate key (works well with sequence based keys also)

INSERT INTO Characters.Person(PersonNumber, FirstName, LastName)
VALUES ('BB','Bamm-Bamm', 'Rubble');

SELECT PersonId
FROM   Characters.Person
WHERE  PersonNumber = 'BB'
GO



--#2 New columns and existing instead of triggers

ALTER TABLE Characters.Person
	ADD EyeColor VARCHAR(30) NULL CHECK (EyeColor IN ('Blue','Brown','Green','Mixed','Other'))
go

--all s e e m s ok
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName,EyeColor)
VALUES ('PF','Pebbles', 'Flintstone','Blue');
go

--why will this work?
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName,EyeColor)
VALUES ('PS','Pearl', 'Slaghoople','Who Cares?');
go

--run it again, and it fails the UNIQUE constraint...so something must be happening!
INSERT INTO Characters.Person(PersonNumber, FirstName, LastName,EyeColor)
VALUES ('PS','Pearl', 'Slaghoople','Who Cares?');
go

--whoops
SELECT *, CASE WHEN RowLastModifiedTime <= '20000101' OR 
					RowCreatedTime <= '20000101' THEN '<--- Really?' ELSE '' END 
FROM   Characters.Person
GO

UPDATE Characters.Person
SET    EyeColor = 'Blue'
WHERE  PersonNumber = 'PS'
go

--whoops (still)
SELECT *, CASE WHEN RowLastModifiedTime <= '20000101' OR 
					RowCreatedTime <= '20000101' THEN '<--- Really?' ELSE '' END 
FROM   Characters.Person
GO

--At this point of a Three Stooges short, Curly would smack himself on the head and whoop a few times...

/*****
Won't fix for time, but the problem is in the instead of triggers:

--insert doesn't reference eye color
		  INSERT INTO dbo.Person(PersonNumber, FirstName, LastName, RowLastModifiedTime, RowCreatedTime)
		  SELECT PersonNumber, FirstName, LastName, SYSDATETIME(), SYSDATETIME() --<< Make sure system times enforced
		  FROM INSERTED

--change to
		  INSERT INTO dbo.Person(PersonNumber, FirstName, LastName, EyeColor, RowLastModifiedTime, RowCreatedTime)
		  SELECT PersonNumber, FirstName, LastName, EyeColor, SYSDATETIME(), SYSDATETIME() --<< Make sure system times enforced
		  FROM INSERTED


--nor does the update one...
		  UPDATE Person
		  SET	PersonNumber = INSERTED.PersonNumber,
				FirstName = INSERTED.FirstName,
				LastName = INSERTED.LastName,
				RowLastModifiedTime = SYSDATETIME() --never use inputted time
				--RowCreatedTime Leave it alone, so it says as is
		  FROM  Characters.Person
					JOIN INSERTED
						ON person.personId = INSERTED.personId    
--change to
		  UPDATE Person
		  SET	PersonNumber = INSERTED.PersonNumber,
				FirstName = INSERTED.FirstName,
				LastName = INSERTED.LastName,
				EyeColor = INSERTED.EyeColor,
				RowLastModifiedTime = SYSDATETIME() --never use inputted time
				--RowCreatedTime Leave it alone, so it says as is
		  FROM  Characters.Person
					JOIN INSERTED
						ON person.personId = INSERTED.personId    

--so you need to go fix all instead of triggers when you modify the structures. I maintain most of my instead of triggers 
--using a tool like ERwin, and certainly some decent unit testing will help you avoid this problem in production :)

******/