use HowToWriteADmlTrigger;
go

IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Attendees.Account'))
		DROP TABLE Attendees.Account;
go
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Messages.ShortMessage')) 
		DROP TABLE Messages.ShortMessage;
go
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE Name = 'Attendees')
	EXEC ('CREATE SCHEMA Attendees')
go 
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE Name = 'Messages')
	EXEC ('CREATE SCHEMA Messages')
go 

CREATE TABLE Attendees.Account
(
	AccountId INT PRIMARY KEY,
	AccountName NVARCHAR(40) NOT NULL UNIQUE	
)
CREATE TABLE Messages.ShortMessage
(
	ShortMessageId INT PRIMARY KEY,
	FromAccountId   INT NOT NULL,
	ToAccountId  INT NULL,
	MessageValue VARCHAR(200) NOT NULL
)
go    
ALTER TABLE Messages.ShortMessage
  ADD CONSTRAINT ShortMessage$References$Account$$ForFromAccountId
	  FOREIGN KEY (FromAccountId) REFERENCES Attendees.Account(AccountId) ON DELETE CASCADE;

--second cascade op will cause an error
ALTER TABLE Messages.ShortMessage
  ADD CONSTRAINT ShortMessage$References$Account$$ForToAccountId
	  FOREIGN KEY (ToAccountId) REFERENCES Attendees.Account(AccountId) ON DELETE SET NULL;
go

/*
Msg 1785, Level 16, State 0, Line 6
Introducing FOREIGN KEY constraint 'ShortMessage$References$Account$$ForToAccountId' on table 'ShortMessage' may cause cycles or multiple cascade paths. Specify ON DELETE NO ACTION or ON UPDATE NO ACTION, or modify other FOREIGN KEY constraints.
Msg 1750, Level 16, State 0, Line 6
Could not create constraint. See previous errors.
GO
*/
ALTER TABLE Messages.ShortMessage
  DROP CONSTRAINT ShortMessage$References$Account$$ForFromAccountId
GO

--instead,use regular NO ACTION constraints and an instead of trigger:

ALTER TABLE Messages.ShortMessage
  ADD CONSTRAINT ShortMessage$References$Account$$ForFromAccountId
	  FOREIGN KEY (FromAccountId) REFERENCES Attendees.Account(AccountId);

ALTER TABLE Messages.ShortMessage
  ADD CONSTRAINT ShortMessage$References$Account$$ForToAccountId
	  FOREIGN KEY (ToAccountId) REFERENCES Attendees.Account(AccountId);
GO

--the instead of trigger allows you to delete the ShortMessageren rows before the
--Account rows hit
CREATE  TRIGGER Attendees.Account$InsteadOfDeleteTrigger
ON Attendees.Account
INSTEAD OF DELETE AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
   -- @rowsAffected int = (SELECT COUNT(*) FROM inserted);
      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;


   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors

          --[modification section] In this section, the goal is no errors but do any data mods to other tables
		  --                       here. Rarely used for instead of triggers

		  DELETE FROM Messages.ShortMessage
		  WHERE  FromAccountId IN (SELECT AccountId FROM DELETED);

		  UPDATE Messages.ShortMessage
		  SET    ToAccountId = NULL
		  WHERE  ToAccountId IN (SELECT AccountId FROM DELETED); 

          --<perform action>  In this section (generally the only one used in an instead of trigger), you
		                    --will usually cause the operation replaced by the trigger to occur

		  DELETE FROM Attendees.Account
		  WHERE  AccountId IN (SELECT AccountId FROM DELETED);
	

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

DELETE FROM Attendees.Account
go
INSERT INTO Attendees.Account (AccountId,AccountName)
VALUES (1,'Jim'),(2,'Pam'),(3,'Dwight'),(4,'Andy'),(5,'Kevin'),(6,'Michael');
GO
INSERT INTO Messages.ShortMessage (ShortMessageId, FromAccountId, ToAccountId,MessageValue)
VALUES (1,1,2,'Hi'),(2,3,4,'Hello'),(3,5,6,'Sup?')
GO



SELECT FromAccount.AccountName AS FromAccount, 
	   ToAccount.AccountName AS ToAccount,
	   ShortMessage.MessageValue
FROM   Messages.ShortMessage
		 JOIN Attendees.Account AS FromAccount
			ON ShortMessage.FromAccountId = FromAccount.AccountId
		 LEFT OUTER JOIN Attendees.Account AS ToAccount
			ON ShortMessage.ToAccountId = ToAccount.AccountId
go
DELETE FROM Attendees.Account --removes ShortMessage 1, since FromAccountId = 1
WHERE  AccountId = 1
go
SELECT FromAccount.AccountName AS FromAccount, 
	   ToAccount.AccountName AS ToAccount,
	   ShortMessage.MessageValue
FROM   Messages.ShortMessage
		 JOIN Attendees.Account AS FromAccount
			ON ShortMessage.FromAccountId = FromAccount.AccountId
		 LEFT OUTER JOIN Attendees.Account AS ToAccount
			ON ShortMessage.ToAccountId = ToAccount.AccountId
go

DELETE FROM Attendees.Account --sets ShortMessage 2's to account to NULL
WHERE AccountId = 4
go
SELECT FromAccount.AccountName AS FromAccount, 
	   ToAccount.AccountName AS ToAccount,
	   ShortMessage.MessageValue
FROM   Messages.ShortMessage
		 JOIN Attendees.Account AS FromAccount
			ON ShortMessage.FromAccountId = FromAccount.AccountId
		 LEFT OUTER JOIN Attendees.Account AS ToAccount
			ON ShortMessage.ToAccountId = ToAccount.AccountId
go


DELETE FROM Attendees.Account --clears both tables
go
SELECT *
FROM   Attendees.Account
SELECT *
FROM   Messages.ShortMessage
go