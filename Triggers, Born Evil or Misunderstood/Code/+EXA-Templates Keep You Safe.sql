---After trigger template

Use TriggerDefense;
go

CREATE TRIGGER <schema>.<table>$<actions>Trigger
ON <schema>.<table>
AFTER <actions> AS 
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

          --[modification section] In this section, the goal is no errors but do any data mods here
 
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

			--[Error logging section] In this section, log any errors because you are outside of the transaction
								--due to the rollback
			--DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
			--        @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
			--        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
			--EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


GO


CREATE TRIGGER <schema>.<tablename>$InsteadOf<actions>Trigger
ON <schema>.<tablename>
INSTEAD OF <comma delimited actions> AS
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
	set rowModDate = sysdatetime()
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

      --[Error logging section]
      --DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
      --         @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
      --         @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
      --EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO
--simple error logging utility
--CREATE SCHEMA Utility; --should be created by default
--GO
use triggerDefense
go


--------------------------------------------------------
-- Previous Account Example Using Schemas and Templates (and no messy denormalization to deal with)
-- Note that the code is complex, there is no denying it, but the parts we have to change 
-- are quite straightforward...


IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Accounting.AccountActivity'))
		DROP TABLE Accounting.AccountActivity;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Accounting.Account'))
		DROP TABLE Accounting.Account;
IF EXISTS (SELECT * FROM sys.schemas where schema_id = schema_id('Accounting'))
		DROP SCHEMA Accounting;
GO

CREATE SCHEMA Accounting;
go
CREATE TABLE Accounting.Account
(
        AccountNumber        char(10) NOT NULL
                  constraint PKAccounting_Account primary key
        --would have other columns
		--NO BALANCE Denormalization...Not worth it!
);

CREATE TABLE Accounting.AccountActivity
(
        AccountNumber                char(10) NOT NULL
            constraint Accounting_Account$has$Accounting_AccountActivity
                       foreign key references Accounting.Account(AccountNumber),
       --this might be a value that each ATM/Teller generates
        TransactionNumber            char(20) NOT NULL,
        TransactionTime              datetime2(3) NOT NULL,
        TransactionAmount            numeric(12,2) NOT NULL,
        constraint PKAccounting_AccountActivity
                      PRIMARY KEY (TransactionNumber)
);

GO
CREATE TRIGGER Accounting.AccountActivity$insertTrigger
ON Accounting.AccountActivity
AFTER INSERT AS
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
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY

   --[validation section]
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT *
                             FROM   inserted
                             WHERE  inserted.AccountNumber =
									AccountActivity.AccountNumber)
                   GROUP BY AccountNumber
                   HAVING SUM(TransactionAmount) < 0)
      BEGIN
         IF @rowsAffected = 1
             SELECT @msg = CONCAT('Account: ', AccountNumber,
                  ' TransactionNumber:',
                   cast(TransactionNumber as varchar(36)),
                   ' for amount: ', cast(TransactionAmount as varchar(10)),
                   ' cannot be created as it will cause a negative balance')
             FROM   inserted;
        ELSE
		  --I don't pick a row because I would have to recheck the data and find a bad row
		  --if you want to be clever you could use variables in query instead of an exists
		  --query and filter for bad rows, but the performance costs could be a negative
		  --unless it saved enough debugging time when looking for bad rows.
          SELECT @msg = 'The rows inserted caused a negative balance';

        THROW  50000, @msg, 16;
      END

   --[modification section]
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION;

		--[Error logging section]
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
			@ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
			@ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH
END;
GO


CREATE TRIGGER Accounting.AccountActivity$updateTrigger
ON Accounting.AccountActivity
AFTER UPDATE AS
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
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY

   --[validation section]
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT *
                             FROM   (select AccountNumber
							         from   inserted
									 union all
									 select AccountNumber
									 from   deleted) as modified
                             WHERE  modified.AccountNumber =
									AccountActivity.AccountNumber)
                   GROUP BY AccountNumber
                   HAVING SUM(TransactionAmount) < 0)
      BEGIN
         IF @rowsAffected = 1 --use deleted, because for an update, the inserted values will match
		                      --what the user thought they were doing to the row.
             SELECT @msg = CONCAT('Account: ', AccountNumber,
                  ' TransactionNumber:',
                   cast(TransactionNumber as varchar(36)),
                   ' for amount: ', cast(TransactionAmount as varchar(10)),
                   ' cannot be modified as it will cause a negative balance')
             FROM   deleted;
        ELSE
          SELECT @msg = 'The modified rows caused a negative balance';
          THROW  50000, @msg, 16;
      END

   --[modification section]
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION;

		--[Error logging section]
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
			@ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
			@ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH
END;
GO

CREATE  TRIGGER Accounting.AccountActivity$deleteTrigger
ON Accounting.AccountActivity
AFTER DELETE AS
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
           --@rowsAffected int = (select count(*) from inserted)
             @rowsAffected int = (select count(*) from deleted)
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY

   --[validation section]

   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT *
                             FROM   deleted
                             WHERE  deleted.AccountNumber =
									AccountActivity.AccountNumber)
                   GROUP BY AccountNumber
                   HAVING SUM(TransactionAmount) < 0)
      BEGIN
         IF @rowsAffected = 1
             SELECT @msg = CONCAT('Account: ', AccountNumber,
                  ' TransactionNumber:',
                   cast(TransactionNumber as varchar(36)),
                   ' for amount: ', cast(TransactionAmount as varchar(10)),
                   ' cannot be deleted as it will cause a negative balance')
             FROM   deleted;
        ELSE
          SELECT @msg = 'Deleting these rows will cause a negative balance';
          THROW  50000, @msg, 1;
      END

   --[modification section]
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION;

		--[Error logging section]
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
			@ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
			@ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH
END;
GO

/* If you need to reset 
delete from Accounting.AccountActivity;
delete from Accounting.Account;
*/

/* demo will cut out the repeat stuff and just do the merge bit
--start 1111111111

--create some set up test data
INSERT INTO Accounting.Account(AccountNumber)
VALUES ('1111111111');

--two actions that keep it positive
INSERT INTO Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                         TransactionTime, TransactionAmount)
VALUES ('1111111111','A0000000000000000001','20050712',100),
       ('1111111111','A0000000000000000002','20050713',100);
GO

--now test a failure
INSERT  INTO Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                         TransactionTime, TransactionAmount)
VALUES ('1111111111','A0000000000000000003','20050713',-300);
GO

select *
from   Accounting.AccountActivity
go 



--start 2222222222

--now insert another account to test multiple account modifications...
INSERT  INTO Accounting.Account(AccountNumber)
VALUES ('2222222222');
GO
--Now, this data will violate the constraint for the new Account:
INSERT  INTO Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        TransactionTime, TransactionAmount)
VALUES ('1111111111','A0000000000000000004','20050714',100),
       ('2222222222','A0000000000000000005','20050715',100),
       ('2222222222','A0000000000000000006','20050715',100),
       ('2222222222','A0000000000000000007','20050715',-201);
GO

select *
from   Accounting.AccountActivity
where  accountNumber in ('1111111111', '222222222')
GO


--start 333333333

--add an account to test deletes
INSERT  INTO Accounting.Account(AccountNumber)
VALUES ('3333333333');
GO

--Now, this the account value after this will be 99
INSERT  INTO Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        TransactionTime, TransactionAmount)
VALUES ('3333333333','A0000000000000000008','20050714',100),
       ('3333333333','A0000000000000000009','20050715',100),
       ('3333333333','A0000000000000000010','20050715',100),
       ('3333333333','A0000000000000000011','20050715',-201);
GO

--this will cause a negative balance
delete from Accounting.AccountActivity
where  accountNumber = '3333333333'
and   TransactionNUmber in ('A0000000000000000009')
go

--data still ok
select *
from   Accounting.AccountActivity
where  accountNumber = '3333333333'
go

delete from Accounting.AccountActivity
where  accountNumber = '3333333333'
and   TransactionNUmber in ('A0000000000000000009','A0000000000000000011')
go

--data still ok
select *
from   Accounting.AccountActivity
where  accountNumber = '3333333333'
go



--Now test changing the account number
insert into Accounting.Account (AccountNumber)
values ('4444444444'),('5555555555');
insert into Accounting.AccountActivity
VALUES ('4444444444','A0000000000000000013','20050714',-100),
       ('4444444444','A0000000000000000014','20050715',100)

select *
from  Accounting.Account
where AccountNumber in ('4444444444','5555555555')
select *
from  Accounting.AccountActivity
where AccountNumber in ('4444444444','5555555555')
go

update Accounting.AccountActivity
set    accountNumber = '5555555555',
	   TransactionAmount = -1 * TransactionAmount
where  TransactionNumber = 'A0000000000000000013'
go

--solid
select *
from Accounting.Account
where AccountNumber in ('4444444444','5555555555')
select *
from Accounting.AccountActivity
where AccountNumber in ('4444444444','5555555555')
go


*/
--what about merge?


--add an account
INSERT  INTO Accounting.Account(AccountNumber)
VALUES ('6666666666');
GO

INSERT  INTO Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        TransactionTime, TransactionAmount)
VALUES ('6666666666','A0000000000000000015','20050714',100),
       ('6666666666','A0000000000000000016','20050715',100),
       ('6666666666','A0000000000000000017','20050715',-100);
GO
select *
from   Accounting.AccountActivity
where  accountNumber = '6666666666'
go



--first time, remove the positive rows, adds a larger inserted row.

select *
from   Accounting.AccountActivity
where  accountNumber = '6666666666'
go


WITH   testMerge as (SELECT *
                     FROM   (VALUES /*Update*/ ('6666666666','A0000000000000000015','20050714',-100),
								    /*Delete   ('6666666666','A0000000000000000016','20050715',100), */
								    /*Same*/   ('6666666666','A0000000000000000017','20050715',-100),
									/*Insert*/ ('6666666666','A0000000000000000018','20050715',1000))

							 as testMerge (AccountNumber, TransactionNumber,
                                        TransactionTime, TransactionAmount))
--select *
--from   testMerge
MERGE  Accounting.AccountActivity
USING  (SELECT AccountNumber, TransactionNumber, TransactionTime, TransactionAmount 
		FROM   testMerge) AS source (AccountNumber, TransactionNumber,
														TransactionTime, TransactionAmount)
        ON (AccountActivity.AccountNumber = source.AccountNumber
		    and AccountActivity.TransactionNumber = source.TransactionNumber)
WHEN MATCHED THEN  
	UPDATE SET	TransactionTime = source.TransactionTime,
				TransactionAmount = source.TransactionAmount
WHEN NOT MATCHED THEN
	INSERT (AccountNumber, TransactionNumber,TransactionTime, TransactionAmount) 
	VALUES (AccountNumber, TransactionNumber,TransactionTime, TransactionAmount)
WHEN NOT MATCHED BY SOURCE THEN 
        DELETE;

select *
from   Accounting.AccountActivity
where  accountNumber = '6666666666'



--second time, the insert would make it negative, but the update makes it positive.
select *
from   Accounting.AccountActivity
where  accountNumber = '6666666666'
go


WITH   testMerge as (SELECT *
                     FROM   (VALUES /*Update*/ ('6666666666','A0000000000000000015','20050714',1000),
								    /*Same*/   ('6666666666','A0000000000000000017','20050715',-150),
									/*Insert*/ ('6666666666','A0000000000000000019','20050715',-800))

							 as testMerge (AccountNumber, TransactionNumber,
                                        TransactionTime, TransactionAmount))
--select *
--from   testMerge
MERGE  Accounting.AccountActivity
USING  (SELECT AccountNumber, TransactionNumber,TransactionTime, TransactionAmount 
		FROM   testMerge) AS source (AccountNumber, TransactionNumber,
														TransactionTime, TransactionAmount)
        ON (AccountActivity.AccountNumber = source.AccountNumber
		    and AccountActivity.TransactionNumber = source.TransactionNumber)
WHEN MATCHED THEN  
	UPDATE SET	TransactionTime = source.TransactionTime,
				TransactionAmount = source.TransactionAmount
WHEN NOT MATCHED THEN
	INSERT (AccountNumber, TransactionNumber,TransactionTime, TransactionAmount) 
	VALUES (AccountNumber, TransactionNumber,TransactionTime, TransactionAmount)
WHEN NOT MATCHED BY SOURCE THEN 
        DELETE;

select *
from   Accounting.AccountActivity
where  accountNumber = '6666666666'


GO

--last time, the insert would make it an illegal situation
select *
from   Accounting.AccountActivity
where  accountNumber = '6666666666'
go


WITH   testMerge as (SELECT *
                     FROM   (VALUES /*Update*/ ('6666666666','A0000000000000000015','20050714',-1000),
								    /*Same*/   ('6666666666','A0000000000000000017','20050715', 150),
									/*Insert*/ ('6666666666','A0000000000000000019','20050715', 800))

							 as testMerge (AccountNumber, TransactionNumber,
                                        TransactionTime, TransactionAmount))
--select *
--from   testMerge
MERGE  Accounting.AccountActivity
USING  (SELECT AccountNumber, TransactionNumber,TransactionTime, TransactionAmount 
		FROM   testMerge) AS source (AccountNumber, TransactionNumber,
														TransactionTime, TransactionAmount)
        ON (AccountActivity.AccountNumber = source.AccountNumber
		    and AccountActivity.TransactionNumber = source.TransactionNumber)
WHEN MATCHED THEN  
	UPDATE SET	TransactionTime = source.TransactionTime,
				TransactionAmount = source.TransactionAmount
WHEN NOT MATCHED THEN
	INSERT (AccountNumber, TransactionNumber,TransactionTime, TransactionAmount) 
	VALUES (AccountNumber, TransactionNumber,TransactionTime, TransactionAmount)
WHEN NOT MATCHED BY SOURCE THEN 
        DELETE;

select *
from   Accounting.AccountActivity
where  accountNumber = '6666666666'


GO


select *
from   Utility.ErrorLog