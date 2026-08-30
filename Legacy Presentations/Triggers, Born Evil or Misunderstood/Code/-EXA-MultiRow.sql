--This demo is here to demonstrate the intricacies of multi-row data operations. In it I 
--will do some things that aren't 100% best practice, but are reasonably normal to see people 
--do regularly. 

Use TriggerProsecution
go

--reset the objects for this section
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Person')) 
		DROP TABLE Person;
go


--simple trigger that checks to make sure that some data fits a format
--best way to do this particular task is with a constraint, but it is a simple
--task that keeps the trigger simple
create table Person
(
	PersonId	int NOT NULL IDENTITY PRIMARY KEY,
	FirstName	nvarchar(20) null, --CHECK (len(FirstName) > 0) would be best
	LastName	nvarchar(20) not null, --CHECK (len(LastName) > 0) would be best
	UNIQUE (FirstName, LastName)
)
go
--I’m going to demo code on a properly configured server with best practices code. 
--Then you’re all going to [complain] that it takes too long. --@peschkaj Jeremiah Peschka


CREATE TRIGGER dbo.Person$insertTrigger
ON dbo.Person
AFTER INSERT AS
--trigger used to make sure that all names have a first and last name that is non-empty
--in a very common and reasonable looking manner
BEGIN
    BEGIN TRY

 		  declare @FirstName nvarchar(20),
				  @LastName  nvarchar(20)
		  select @FirstName = FirstName,
		         @LastName = LastName
		  FROM   Inserted

		  if @FirstName = ''
			THROW 50000, N'First Name cannot be blank',1;
		  if @LastName = ''
			THROW 50000, N'Last Name cannot be blank',1;

   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;
      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--one correct row...
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Fred', 'Flintstone');
GO
--two correct rows...
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Barney', 'Rubble'),
	   ('Betty', 'Rubble');
GO
--one wrong row
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Dino', '');
go
--one wrong row with other correct rows, order doesn't matter in SQL, right?
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Dino', ''),
       ('Wilma','Flintstone'),
	   ('Pebbles','Flintstone');
GO
--bam... next task... right? SPOILER ALERT...You haven't tested enough...


--



--




--




--




--Will this fail?
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Wilma','Flintstone'),
	   ('Dino', ''),
	   ('Stone',''),
	   ('Rocky','')
Go

--Crud
select *
from   dbo.Person


--Because of our coding style ORDER did matter... Order should NEVER matter
truncate table dbo.Person;
GO

ALTER TRIGGER dbo.Person$insertTrigger
ON dbo.Person
AFTER INSERT AS
--trigger used to make sure that all names have a first and last name that is non-empty
--in an awkward, yet correct manner for triggers
BEGIN
   
   BEGIN TRY --could do both checks in one pass but this is often 
             --the easiest way to get best error messages
		  if exists (select *
					 from   Inserted
					 where  FirstName = '') 
			THROW 50000, N'First Name cannot be blank',1;

		  if exists (select *
					 from   Inserted
					 where  LastName = '') 
			THROW 50000, N'Last Name cannot be blank',1;

   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


--one correct row...
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Fred', 'Flintstone');
GO
--two correct rows...
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Barney', 'Rubble'),
	   ('Betty', 'Rubble');
GO
--one wrong row
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Dino', '');
go
--one wrong row with other correct rows, order doesn't matter in SQL, right?
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Dino', ''),
       ('Wilma','Flintstone'),
	   ('Pebbles','Flintstone');
GO
--Now will this fail?!?
INSERT INTO dbo.Person(FirstName, LastName)
VALUES ('Wilma','Flintstone'),
	   ('Dino', ''),
	   ('Stone',''),
	   ('Rocky','')
Go

--Yes..
select *
from   dbo.Person
GO
----------------------------------------------------------------------------------
-- show the complexity of doing a multi-row validation/balance

--WHEN CUTTING CONTENT FOR TIME, I REALLY WANTED TO EDIT OUT THIS SECTION!
--But it really is the most eye opening part of the presentation to me.

IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('AccountActivity')) 
		DROP TABLE AccountActivity;
go
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Account')) 
		DROP TABLE Account;
go


CREATE TABLE dbo.Account
(
        AccountNumber        char(10) NOT NULL
                  constraint PKAccounting_Account primary key,
	    --yet another non-optimimum solution that is so often done
		--OFTEN BECAUSE TRIGGERS allow it... If they are done RIGHT...
		Balance				 numeric(12,2) NOT NULL CONSTRAINT DFLTAccount$Balance DEFAULT (0)
        --would have other columns, but this is everything for clarity of the solution
);

--
CREATE TABLE dbo.AccountActivity
(
        AccountNumber                char(10) NOT NULL
            constraint Accounting_Account$has$Accounting_AccountActivity
                       foreign key references dbo.Account(AccountNumber),
       --this might be a value that each ATM/Teller generates
        TransactionNumber            char(20) NOT NULL,
        Date                         datetime2(3) NOT NULL,
        TransactionAmount            numeric(12,2) NOT NULL,
        constraint PKAccounting_AccountActivity
                      PRIMARY KEY (TransactionNumber)
);

GO

CREATE TRIGGER dbo.AccountActivity$InsertUpdateTrigger
ON dbo.AccountActivity
AFTER INSERT, UPDATE AS
--one generic trigger for inserts and updates to make sure that the net effect of an operation 
--isn't less than zero...and if not, maintain the balance
BEGIN
   set nocount on
   BEGIN TRY
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountActivity.AccountNumber
               FROM dbo.AccountActivity as AccountActivity
					 JOIN inserted --so we are only looking at accounts that have changed
                         ON inserted.AccountNumber = AccountActivity.AccountNumber
               GROUP BY AccountActivity.AccountNumber
               HAVING SUM(AccountActivity.TransactionAmount) < 0) -- sum of any account's activtity is non-negative

          THROW  50000, 'The modified row(s) would have caused a negative balance', 1;

	--maintain the balance for accounts that have been touched in the DML
	WITH AccountTotals as (
	    --calc new balance for touched accounts
		SELECT AccountActivity.AccountNumber, sum(AccountActivity.TransactionAmount) as Balance
        FROM dbo.AccountActivity as AccountActivity
				Join inserted
                    ON inserted.AccountNumber = AccountActivity.AccountNumber
        GROUP BY AccountActivity.AccountNumber )

	UPDATE Account
	SET    Balance =  AccountTotals.Balance
	from   Account	
			 join AccountTotals
				on Account.AccountNumber = AccountTotals.AccountNumber; 

   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;
GO


--create some set up test data
INSERT INTO dbo.Account(AccountNumber)
VALUES ('1111111111');

--two actions that keep it positive
INSERT INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                         Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000001','20050712',100)

INSERT INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                         Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000002','20050712',100)
GO

select *
from Account
where accountNumber = '1111111111'
select *
from AccountActivity
where accountNumber = '1111111111'
go

--now test a failure, as the balance would be -100
INSERT  INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                         Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000003','20050713',-300);
GO

select *
from Account
where accountNumber = '1111111111'
select *
from AccountActivity
where accountNumber = '1111111111'
go

--now insert another account to test multiple account modifications...
INSERT  INTO dbo.Account(AccountNumber)
VALUES ('2222222222');
GO
--Now, this data will violate the constraint for the new Account:
INSERT  INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000004','20050714',100),
       ('2222222222','A0000000000000000005','20050715',100),
       ('2222222222','A0000000000000000006','20050715',100),
       ('2222222222','A0000000000000000007','20050715',-201);
GO

select *
from Account
where accountNumber in ('1111111111','2222222222')
select *
from AccountActivity
where accountNumber in ('1111111111','2222222222')
go

--so, everyone happy that we are golden? This is the prosecution side, right? 
--Yeah, we are still really quite screwed up with quite a ways to go
--see the scroll bar over there?


insert into dbo.Account(AccountNumber)
Values ('3333333333');

INSERT  INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('3333333333','A0000000000000000008','20050714',100),
       ('3333333333','A0000000000000000009','20050715',100)

--guh?
select *
from Account
where accountNumber in ('3333333333')
select *
from AccountActivity
where accountNumber in ('3333333333')
go


INSERT  INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('3333333333','A0000000000000000010','20050714',100),
       ('3333333333','A0000000000000000011','20050715',100),
       ('3333333333','A0000000000000000012','20050715',100)
go
--gu.. uh?
select *
from Account
where accountNumber in ('3333333333')
select *
from AccountActivity
where accountNumber in ('3333333333')
go


--The problem lies here:
/*
	WITH AccountTotals as (
		SELECT AccountActivity.AccountNumber, sum(AccountActivity.TransactionAmount) as Balance
        FROM dbo.AccountActivity as AccountActivity
				Join inserted                      
				    --!!! The join makes us have (number of rows in inserted) * the actual balance...                                  
                    ON inserted.AccountNumber = AccountActivity.AccountNumber
        GROUP BY AccountActivity.AccountNumber )
		
	UPDATE Account
	SET    Balance =  AccountTotals.Balance
	from   Account	
			 join AccountTotals
				on Account.AccountNumber = AccountTotals.AccountNumber; 
*/
go
--so we have to change the code to:

ALTER TRIGGER dbo.AccountActivity$InsertUpdateTrigger
ON dbo.AccountActivity
AFTER INSERT, UPDATE AS
--one generic trigger for inserts and updates to make sure that the net effect of an operation 
--isn't less than zero...and if not, maintain the balance
BEGIN
   BEGIN TRY
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM dbo.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT * --use exists to keep cardinality correct in the outer set
                             FROM   inserted
                             WHERE  inserted.AccountNumber =
											AccountActivity.AccountNumber)
			   GROUP BY AccountNumber
			   HAVING SUM(TransactionAmount) < 0)

          THROW  50000, 'The modified row(s) would have caused a negative balance', 1;

	WITH AccountTotals as (
			   SELECT AccountNumber, SUM(TransactionAmount) as Balance
               FROM dbo.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT * --use exists to keep cardinality correct in the outer set, here too.
                             FROM   inserted
                             WHERE  inserted.AccountNumber =
									AccountActivity.AccountNumber)
               GROUP BY AccountNumber)
		
	UPDATE Account
	SET    Balance =  AccountTotals.Balance
	from   Account	
			 join AccountTotals
				on Account.AccountNumber = AccountTotals.AccountNumber; 
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;
GO

--Retest 3:

delete from dbo.AccountActivity where AccountNumber = '3333333333'
delete from dbo.Account where AccountNumber = '3333333333'
GO

insert into dbo.Account(AccountNumber)
Values ('3333333333');

--balance should be 200
INSERT  INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('3333333333','A0000000000000000008','20050714',100),
       ('3333333333','A0000000000000000009','20050715',100)

select *
from Account
where accountNumber in ('3333333333')
select *
from AccountActivity
where accountNumber in ('3333333333')
go

--balance should be 500
INSERT  INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('3333333333','A0000000000000000010','20050714',100),
       ('3333333333','A0000000000000000011','20050715',100),
       ('3333333333','A0000000000000000012','20050715',100)
go
select *
from Account
where accountNumber in ('3333333333')
select *
from AccountActivity
where accountNumber in ('3333333333')
go
go


--Now test changing the account number on a row:

--set up the data
insert into dbo.Account (AccountNumber)
values ('444444444'),('555555555');
insert into dbo.AccountActivity
VALUES ('444444444','A0000000000000000013','20050714',-100),
       ('444444444','A0000000000000000014','20050715',100)

select *
from Account
where AccountNumber in ('444444444','555555555')
select *
from AccountActivity
where AccountNumber in ('444444444','555555555')
go

--should have failed!
update AccountActivity
set    accountNumber = '555555555'
where  TransactionNumber = 'A0000000000000000014'
go

--oops
select *
from Account
where AccountNumber in ('444444444','555555555')
select *
from AccountActivity
where AccountNumber in ('444444444','555555555')
go

-- The problem here is:
/*
			   SELECT AccountNumber, SUM(TransactionAmount) as Balance
               FROM dbo.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT * 
                             FROM   inserted --<<-- you have to deal with the accounts that lost data
							                 --as well got data...
                             WHERE  inserted.AccountNumber =
									AccountActivity.AccountNumber)
               GROUP BY AccountNumber)
*/
--so we have to change to:

ALTER TRIGGER dbo.AccountActivity$InsertUpdateTrigger
ON dbo.AccountActivity
AFTER INSERT, UPDATE AS
--one generic trigger for inserts and updates to make sure that the net effect of an operation 
--isn't less than zero...and if not, maintain the balance
BEGIN
   BEGIN TRY
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM dbo.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT * --use exists to keep cardinality correct in the outer set
                             FROM   (select AccountNumber
							         from   inserted
									 union all  --<<-- for deletes, we need to handle the case where the grouping
									 select AccountNumber           --value can change...
									 from   deleted) as modified
                             WHERE  modified.AccountNumber =
									AccountActivity.AccountNumber)
			   GROUP BY AccountNumber
			   HAVING SUM(TransactionAmount) < 0)

          THROW  50000, 'The modified row(s) would have caused a negative balance', 1;

	WITH AccountTotals as (
			   SELECT AccountNumber, SUM(TransactionAmount) as Balance
               FROM dbo.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT * --use exists to keep cardinality correct in the outer set, here too.
                             FROM   (select AccountNumber
							         from   inserted
									 union all  --<<-- for deletes, we need to handle the case where the grouping
									 select AccountNumber           --value can change...
									 from   deleted) as modified
                             WHERE  modified.AccountNumber =
									AccountActivity.AccountNumber)
               GROUP BY AccountNumber)
		
	UPDATE Account
	SET    Balance =  AccountTotals.Balance
	from   Account	
			 join AccountTotals
				on Account.AccountNumber = AccountTotals.AccountNumber; 
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;
GO
--reset
delete from dbo.AccountActivity
where AccountNumber in ('444444444','555555555')
delete from dbo.Account
where AccountNumber in ('444444444','555555555')

--Now test changing the account number:
--start by resetting the data
insert into dbo.Account (AccountNumber)
values ('444444444'),('555555555');
insert into dbo.AccountActivity
VALUES ('444444444','A0000000000000000015','20050714',-100),
       ('444444444','A0000000000000000016','20050715',100)

select *
from Account
where AccountNumber in ('444444444','555555555')
select *
from AccountActivity
where AccountNumber in ('444444444','555555555')
go

--change the key of account of one of the transactions
update AccountActivity
set    accountNumber = '555555555'
where  TransactionNumber = 'A0000000000000000015'
go

select *
from Account
where AccountNumber in ('444444444','555555555')
select *
from AccountActivity
where AccountNumber in ('444444444','555555555')
go

--This however should work fine, leaving both 444444444 and 55555555 with a 100 balance
update AccountActivity
set    accountNumber = '555555555',
	   TransactionAmount = -1 * TransactionAmount
where  TransactionNumber = 'A0000000000000000015'

go

select *
from Account
where AccountNumber in ('444444444','555555555')
select *
from AccountActivity
where AccountNumber in ('444444444','555555555')
go

--so we are done right? No, still have to consider deletes...
--you also have to deal with deletes. In our example, we can just use the same trigger code for 
--deletes
drop trigger dbo.AccountActivity$InsertUpdateTrigger
go

--renaming the trigger because we changed what it does (we could have multiple triggers, and if 
--you forget to drop the other trigger they could both fire, causing issues we will discuss later)
CREATE TRIGGER dbo.AccountActivity$InsertUpdateDeleteTrigger
ON dbo.AccountActivity
AFTER INSERT, UPDATE, DELETE AS
--one generic trigger for inserts and updates to make sure that the net effect of an operation 
--isn't less than zero...and if not, maintain the balance
BEGIN
   BEGIN TRY

   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM dbo.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT * --use exists to keep cardinality correct in the outer set
                             FROM   (select AccountNumber
							         from   inserted
									 union all  --<<-- for deletes, we need to handle the case where the grouping
									 select AccountNumber           --value can change...
									 from   deleted) as modified
                             WHERE  modified.AccountNumber =
									AccountActivity.AccountNumber)
			   GROUP BY AccountNumber
			   HAVING SUM(TransactionAmount) < 0)

          THROW  50000, 'The modified row(s) would have caused a negative balance', 1;

	WITH AccountTotals as (
			   SELECT AccountNumber, SUM(TransactionAmount) as Balance
               FROM dbo.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT * --use exists to keep cardinality correct in the outer set, here too.
                             FROM   (select AccountNumber
							         from   inserted
									 union all  --<<-- for deletes, we need to handle the case where the grouping
									 select AccountNumber           --value can change...
									 from   deleted) as modified
                             WHERE  modified.AccountNumber =
									AccountActivity.AccountNumber)
               GROUP BY AccountNumber)
		
	UPDATE Account
	SET    Balance =  AccountTotals.Balance
	from   Account	
			 join AccountTotals
				on Account.AccountNumber = AccountTotals.AccountNumber; 
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;
GO

--add an account
INSERT  INTO dbo.Account(AccountNumber)
VALUES ('6666666666');
GO

--Now, this the account value after this will be 99
INSERT  INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('6666666666','A0000000000000000017','20050714',100),
       ('6666666666','A0000000000000000018','20050715',100),
       ('6666666666','A0000000000000000019','20050715',100),
       ('6666666666','A0000000000000000020','20050715',-201);
GO

--check the data
select *
from   dbo.Account
where  accountNumber = '6666666666'

select *
from   dbo.AccountActivity
where  accountNumber = '6666666666'
go



--this will cause a negative balance
delete from dbo.AccountActivity
where  accountNumber = '6666666666'
and   TransactionNUmber in ('A0000000000000000017')
go

--data still ok

select *
from   dbo.Account
where  accountNumber = '6666666666'

select *
from   dbo.AccountActivity
where  accountNumber = '6666666666'
go

delete from dbo.AccountActivity
where  accountNumber = '6666666666'
and   TransactionNUmber in ('A0000000000000000019','A0000000000000000020') -- 100 and -200 rows
go

--data still ok
select *
from   dbo.Account
where  accountNumber = '6666666666'

select *
from   dbo.AccountActivity
where  accountNumber = '6666666666'
go

--done testing right? Um No...








--delete all of the rows:
delete from   dbo.AccountActivity
where  accountNumber = '6666666666'
Go

--good grief, are there still problems?
select *
from   dbo.Account
where  accountNumber = '6666666666'

select *
from   dbo.AccountActivity
where  accountNumber = '6666666666'
go

--the problem now occurs if there is no activity left... The update only returns rows where accountActivity
--exists...
/*
	WITH AccountTotals as (
			   SELECT AccountNumber, SUM(TransactionAmount) as Balance
               FROM dbo.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT * --use exists to keep cardinality correct in the outer set, here too.
                             FROM   (select AccountNumber
							         from   inserted
									 union all  --<<-- for deletes, we need to handle the case where the grouping
									 select AccountNumber           --value can change...
									 from   deleted) as modified
                             WHERE  modified.AccountNumber =
									AccountActivity.AccountNumber)
               GROUP BY AccountNumber)
		
	UPDATE Account
	SET    Balance =  AccountTotals.Balance
	from   Account	
			 join AccountTotals
				on Account.AccountNumber = AccountTotals.AccountNumber; 
*/

ALTER TRIGGER dbo.AccountActivity$InsertUpdateDeleteTrigger
ON dbo.AccountActivity
AFTER INSERT, UPDATE, DELETE AS
--one generic trigger for inserts and updates to make sure that the net effect of an operation 
--isn't less than zero...and if not, maintain the balance
BEGIN
   BEGIN TRY
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber --THIS ONE STAYS THE SAME
               FROM   dbo.AccountActivity as AccountActivity
               WHERE  EXISTS (SELECT * --use exists to keep cardinality correct in the outer set
                             FROM   (select AccountNumber
							         from   inserted
									 union all  --<<-- for deletes, we need to handle the case where the grouping
									 select AccountNumber           --value can change...
									 from   deleted) as modified
                             WHERE  modified.AccountNumber =
									AccountActivity.AccountNumber)
			   GROUP BY AccountNumber
			   HAVING SUM(TransactionAmount) < 0)

          THROW  50000, 'The modified row(s) would have caused a negative balance', 1;

	set ansi_warnings off; --warning will be raised if there are no more activity rows...
	WITH AccountTotals as (
			   SELECT modified.AccountNumber, coalesce(SUM(AccountActivity.TransactionAmount),0) as Balance
               FROM   ( select AccountNumber
						from   inserted
						union  --this gives us one row per account...avoiding the bloat
								--from the earlier versions...
						select AccountNumber           
						from   deleted) as modified
						  --changed to use join instead of exists because we need to update 
						  --account activity even if no rows.
						  left outer join dbo.AccountActivity as AccountActivity
								on modified.AccountNumber = AccountActivity.AccountNumber
               GROUP BY modified.AccountNumber)
		
	UPDATE Account
	SET    Balance =  AccountTotals.Balance
	from   Account	
			 join AccountTotals
				on Account.AccountNumber = AccountTotals.AccountNumber; 

	set ansi_warnings on;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;
go

--check the data
select *
from   dbo.Account
where  accountNumber = '6666666666'

select *
from   dbo.AccountActivity
where  accountNumber = '6666666666'
go

--Now, this the account value after this will be 99
INSERT  INTO dbo.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('6666666666','A0000000000000000017','20050714',100),
       ('6666666666','A0000000000000000018','20050715',100),
       ('6666666666','A0000000000000000019','20050715',100),
       ('6666666666','A0000000000000000020','20050715',-201);
GO

--check the data, should be healed!
select *
from   dbo.Account
where  accountNumber = '6666666666'

select *
from   dbo.AccountActivity
where  accountNumber = '6666666666'
go



--this will cause a negative balance
delete from dbo.AccountActivity
where  accountNumber = '6666666666'
and   TransactionNUmber in ('A0000000000000000017')
go

--delete several of the rows...
delete from dbo.AccountActivity
where  accountNumber = '6666666666'
and   TransactionNUmber in ('A0000000000000000019','A0000000000000000020') -- 100 and -200 rows
go

--data still ok
select *
from   dbo.Account
where  accountNumber = '6666666666'

select *
from   dbo.AccountActivity
where  accountNumber = '6666666666'
go


--delete all of the rows:
delete from   dbo.AccountActivity
where  accountNumber = '6666666666'
Go

--good grief, are there still problems?
select *
from   dbo.Account
where  accountNumber = '6666666666'

select *
from   dbo.AccountActivity
where  accountNumber = '6666666666'
go

--no, it works

--News Alert: Merge Case Will be covered later...If you were wondering... (Without the nasty denormalization)
