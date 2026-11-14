Use HowToWriteADmlTrigger;
go


IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Accounting.AccountActivity'))
		DROP TABLE Accounting.AccountActivity;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Accounting.Account'))
		DROP TABLE Accounting.Account;

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE Name = 'Accounting')
	EXEC ('CREATE SCHEMA Accounting;')
GO
CREATE TABLE Accounting.Account
(
        AccountNumber        char(10) NOT NULL
                  constraint PKAccounting_Account primary key
        --would have other columns
);

CREATE TABLE Accounting.AccountActivity
(
        AccountNumber                char(10) NOT NULL
            constraint Accounting_Account$has$Accounting_AccountActivity
                       foreign key references Accounting.Account(AccountNumber),
       --this might be a value that each ATM/Teller generates uniquely
        TransactionNumber            char(20) NOT NULL constraint PKAccounting_AccountActivity PRIMARY KEY,
        TransactionTime              datetime2(3) NOT NULL,
        TransactionAmount            numeric(12,2) NOT NULL,
        
);
--covers summing
create index AccountNumber on Accounting.AccountActivity(AccountNumber) INCLUDE (TransactionAmount); 
GO
/*
--basic process, write the query to validate the entire table:
 SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               GROUP BY AccountNumber
               HAVING SUM(TransactionAmount) < 0

THEN filter the ROWS WITH EXISTS IN a WHERE:

 SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT *
                             FROM   deleted
                             WHERE  deleted.AccountNumber =
									AccountActivity.AccountNumber)
               GROUP BY AccountNumber
               HAVING SUM(TransactionAmount) < 0
*/
SELECT AccountNumber
FROM Accounting.AccountActivity as AccountActivity
GROUP BY AccountNumber
HAVING SUM(TransactionAmount) < 0
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
               WHERE EXISTS (SELECT * --note, you must be careful with cardinality
									  --joining to the base table can lead to duplication
									  --internally
                             FROM   inserted
                             WHERE  inserted.AccountNumber = AccountActivity.AccountNumber)
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
			@ERROR_LOCATION sysname = ERROR_PROCEDURE(),
			@ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

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
   IF UPDATE (TransactionAmount) or UPDATE(AccountNumber)
	   BEGIN
	   IF EXISTS ( SELECT AccountNumber
				   FROM Accounting.AccountActivity as AccountActivity
				   WHERE EXISTS (SELECT * --now we need all accounts that were touched, in case a
										  --transaction was moved from one account to another
								 FROM   (select AccountNumber
										 from   inserted
										 UNION ALL --duplicate rows don't matter here, so use ALL
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
	END

   --[modification section]
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION;

		--[Error logging section]
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
			@ERROR_LOCATION sysname = ERROR_PROCEDURE(),
			@ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

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
			@ERROR_LOCATION sysname = ERROR_PROCEDURE(),
			@ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH
END;
GO

/* If you need to reset 
delete from Accounting.AccountActivity;
delete from Accounting.Account;
*/


--test your triggers, over and over...
--start with account 1111111111

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

--now 4444444444, 5555555555

--Now test changing the account number
insert into Accounting.Account (AccountNumber)
values ('4444444444'),('5555555555');
insert into Accounting.AccountActivity
VALUES ('4444444444','A0000000000000000013','20050714',-100),
       ('4444444444','A0000000000000000014','20050715',100)

select *
from   Accounting.AccountActivity
where  accountNumber = '4444444444'
go
go
--neither of these are possible
update Accounting.AccountActivity
set    accountNumber = '5555555555'
where  TransactionNumber = 'A0000000000000000013'
go
update Accounting.AccountActivity
set    accountNumber = '5555555555'
where  TransactionNumber = 'A0000000000000000014'
go
update Accounting.AccountActivity
set    AccountNumber = CASE WHEN TransactionAmount < 0 THEN '5555555555'
							 ELSE '4444444444' END
where  AccountNumber IN ('4444444444','5555555555')
go

select *
from  Accounting.Account
where AccountNumber in ('4444444444','5555555555')
select *
from  Accounting.AccountActivity
where AccountNumber in ('4444444444','5555555555')
go

--now make it positive and swap it
update Accounting.AccountActivity
set    accountNumber = '5555555555',
	   TransactionAmount = 100
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



--what about merge?

/*
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
                     FROM   (VALUES /*Update*/ ('6666666666','A0000000000000000015','20050714',-100), --was 100 
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
                     FROM   (VALUES /*Update*/ ('6666666666','A0000000000000000015','20050714',1000), --was -100
								    /*Same*/   ('6666666666','A0000000000000000017','20050715',-150), --was -100
																									  --delete 1000
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



--second time, the insert would make it negative, but the update makes it positive.
select *
from   Accounting.AccountActivity
where  accountNumber = '6666666666'
go


--fails as they are all negative now...
WITH   testMerge as (SELECT *
                     FROM   (VALUES /*Update*/ ('6666666666','A0000000000000000015','20050714', -1000), --was -100
								    /*Same*/   ('6666666666','A0000000000000000017','20050715',-150), --was -100
																									  --delete 1000
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
*/

