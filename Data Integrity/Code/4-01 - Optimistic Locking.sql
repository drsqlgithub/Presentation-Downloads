USE HowToImplementDataIntegrity
GO
IF EXISTS (SELECT * FROM sys.tables WHERE OBJECT_ID = OBJECT_ID('hr.person'))
	DROP TABLE hr.person
go
IF EXISTS (SELECT * FROM sys.schemas WHERE SCHEMA_ID = schema_ID('hr'))
	DROP SCHEMA hr
go

CREATE SCHEMA hr;
GO
CREATE TABLE hr.person
(
     personId int IDENTITY(1,1) CONSTRAINT PKperson primary key,
	 personNumber CHAR(3) NOT NULL CONSTRAINT AKperson UNIQUE,
     firstName varchar(60) NOT NULL,
     middleName varchar(60) NOT NULL,
     lastName varchar(60) NOT NULL,
 
     dateOfBirth date NOT NULL,

	 --physical columns, meant for implementation purposes only. 
	 --provides two ways of doing optimistic locking

     rowLastModifyTime datetime2(3) NOT NULL
         CONSTRAINT DFLTperson_rowLastModifyTime DEFAULT (SYSDATETIME()),
     rowModifiedByUserIdentifier nvarchar(128) NOT NULL
         CONSTRAINT DFLTperson_rowModifiedByUserIdentifier default suser_sname(),
	 rowversion rowversion --aka timestamp, binary value that increments on every change, 
	                       --unique at the database level
);
 
 
GO

--make sure that when the row is modified the RowLastModifyTime is changed...
CREATE TRIGGER hr.person$InsteadOfInsert
ON hr.person
INSTEAD OF INSERT AS
BEGIN
 
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON;
   SET ROWCOUNT 0; --in case the client has modified the rowcount
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --           @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --remember to inser ALL columns when building instead of triggers, except the ones you want to make
		  --sure are defaulted..
		INSERT hr.person (personNumber, firstName, middleName, lastName, dateOfBirth)
		SELECT personNumber, firstName, middleName, lastName, dateOfBirth
		FROM   inserted    
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION;

		--[Error logging section]
		--DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
	 --           @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		--        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		--EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END
 
GO


--make sure that when the row is modified the RowLastModifyTime is changed...
CREATE TRIGGER hr.person$InsteadOfUpdate
ON hr.person
INSTEAD OF UPDATE AS
BEGIN
  
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON;
   SET ROWCOUNT 0; --in case the client has modified the rowcount
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --           @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --remember to update ALL columns when building instead of triggers
          UPDATE hr.person
          SET    personNumber = inserted.personNumber,
				 firstName = inserted.firstName,
                 middleName = inserted.middleName,
                 lastName = inserted.lastName,
                 dateOfBirth = inserted.dateOfBirth,
                 rowLastModifyTime = default, -- set the value to the default
                 rowModifiedByUserIdentifier = default 
          FROM   hr.person                              
                     JOIN inserted
                             on hr.person.personId = inserted.personId;
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION;

		--[Error logging section]
		--DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
	 --           @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		--        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		--EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
 END
GO
 
 

INSERT INTO hr.person (personNumber,firstName, middleName, lastName, dateOfBirth)
VALUES ('P01','Paige','O','Anxtent','19391212');
 
SELECT *
FROM   hr.person;
 
GO
 
UPDATE hr.person
SET     middleName = 'Ona'
WHERE   PersonNumber = 'P01';
 
SELECT *
FROM   hr.person;
GO
 
--The problem: Two users have cached the sae version of the data
--The both want to act upon it...

--VERY optimistic, just let the last update win
UPDATE  hr.person
SET     firstName = 'Sam', --User 1 changes the value
        middleName = 'O' --ovewrites
WHERE   PersonNumber = 'P01';
GO

--and moments later, User 2 changes the value from their cached value
UPDATE  hr.person
SET     firstName = 'Paige', --no actual change occurs
        middleName = 'O'
WHERE   PersonNumber = 'P01';
GO
 
 
SELECT personId, rowversion,*
FROM   hr.person;
 
--======
--Four ways to deal with optimistic locking: (note that at this point, you will be using the surrogate key
--from the application)


--1. Just let it happen. And this will almost always be the case for multiple row updates...
UPDATE  hr.person
SET     firstName = 'Paige' --no actual change occurs
WHERE   personId = 1;

IF @@rowcount = 0
	--message that row did not exist

GO
 

--2, Use all columns in the table in the WHERE clause
UPDATE  hr.person
SET     firstName = 'Headley'
WHERE   personId = 1  --include the key
  AND   personNumber = 'P01'
  and   firstName = 'Paige'
  and   middleName = 'ona'
  and   lastName = 'Anxtent'
  and   dateOfBirth = '19391212';
IF @@rowcount = 0 THEN Figure OUT WHY (usually: SELECT * FROM TABLE WHERE personId = 1 AND check the DATA)
GO

--3. If trustable, use the rowLastModifyTime (or you own value that changes consistenly on modification)
UPDATE  hr.person
SET     firstName = 'Fred'
WHERE   personId = 1  --include the key
  and   rowLastModifyTime = '2013-09-14 22:05:58.970';
IF @@rowcount = 0 THEN Figure OUT WHY (usually: SELECT * FROM TABLE WHERE personId = 1 AND check the DATA)
 

--4. Use the rowversion
UPDATE  hr.person
SET     firstName = 'Fred'
WHERE   personId = 1
  and   rowversion = 0x00000000000007D9;
IF @@rowcount = 0 THEN Figure OUT WHY (usually: SELECT * FROM TABLE WHERE personId = 1 AND check the DATA)
 
GO
select *
from   hr.person
GO
 
