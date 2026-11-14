PRINT 'You tried to run the entire file'
GO
:EXIT

USE MattersOfConcurrency;
GO

-------------------------------------------------
-- Scenario 1:  Reader (1) Versus (*) Reader (2)
-------------------------------------------------

--What will happen?

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no other open transactions

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.SingleTable;
GO

--stop 

ROLLBACK;
GO

----------------------------------------------------------------
-- Scenario 2:  (*) Reader (1) Versus Reader (2) WITH XLOCK hint
----------------------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.SingleTable;
GO

--stop

ROLLBACK;
GO

-------------------------------------------------
-- Scenario 3a:  (*) Writer (1) Reader (2)
--             Using READ UNCOMMITTED
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.SingleTable
WHERE  Value = 'Fred';
GO

--stop

ROLLBACK; --leave other transaction open
GO

-------------------------------------------------
-- Scenario 3b:  (*) Writer (1) Reader (2)
--             Using READ COMMITTED, Try all of the other rows
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.SingleTable
WHERE  Value = 'Barney';
GO

--stop, add the index (in other window) and then show what happens

ROLLBACK;
GO

--NOTE: Later, we will see READ COMMITTED SNAPSHOT setting that would
--eliminate the blocking, but would NOT eliminate the performance issues

-------------------------------------------------
-- Scenario 4a:  (*) Writer (1) Reader (2)
--				show what we can do with the other rows in the table
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.SingleTable
WHERE  Value = 'Fred';
GO

--stop, then run query again after adding rows in part 2

ROLLBACK;
GO

--don't roll back other connection... Go to 4b

-------------------------------------------------
-- Scenario 4b:  (*) Writer (1) Reader (2)
--			Show the mess that Read Uncommitted can be
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.SingleTable;
GO

--stop, rollback the other connection and run again

ROLLBACK;
GO

--note: it doesn't seem bad until a user says: "I got these weird results
-- yesterday, but it seems to work now

---------------------------------------------------
---- Scenario 5:  (*) Reader (1) Writer (2)
---------------------------------------------------
--if @@trancount > 0 ROLLBACK --make sure there's no open transactions
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED
--BEGIN TRANSACTION

----part 1
--UPDATE Demo.SingleTable
--SET    Value = UPPER(Value)
--WHERE  Value = 'Fred'
--GO

----stop, then go query the rest of the rows currently in table

----part 2
--INSERT INTO Demo.SingleTable(Value)
--VALUES ('AlternateFred'),('AlternateBarney')

----stop, then go try to run part 2 query again... 

--ROLLBACK 
--GO

-------------------------------------------------
-- Scenario 6:  (*) Reader (1) Writer (2)
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

--part 1, create and then commit changes
INSERT INTO Demo.SingleTable(Value)
VALUES('AlternateFred'), ('AlternateBarney');

COMMIT;
GO

--stop

--part 2

BEGIN TRANSACTION;

UPDATE Demo.SingleTable
SET    Value = UPPER(Value)
WHERE  Value = 'Fred';

--stop
ROLLBACK;

---------------------------------------------------
---- Scenario 7:  (*) Reader (1) Writer (2)
---------------------------------------------------
--if @@trancount > 0 ROLLBACK --make sure there's no open transactions
--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--BEGIN TRANSACTION

----part 1
--INSERT INTO Demo.SingleTable(Value)
--VALUES ('AlternateFred'),('AlternateBarney')

----stop

--ROLLBACK
--GO

-------------------------------------------------
-- Scenario 8:  Foreign Keys and Isolation Levels
-------------------------------------------------
IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo.Person
SET    Name = UPPER(Name);

--stop
ROLLBACK;
GO

-------------------------------------------------
-- Scenario 10a:  Foreign Keys and Isolation Levels  - CASCADE
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo.Interaction --this tries to use the locked row 
SET    PersonId = 14 --The personID for Arnold (select * from demo.person where personId =14)
WHERE  InteractionId = 1;

--stop
ROLLBACK;
GO

--all rows, no table lock
IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo.Interaction
SET    Subject = UPPER(Subject),
       Message = UPPER(Message);

--stop
ROLLBACK;
GO

--all rows, with table lock
IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo.Interaction WITH(TABLOCK)
SET    Subject = UPPER(Subject),
       Message = UPPER(Message);

--stop
ROLLBACK;


--all rows, with table lock
IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.Interaction 

--stop
ROLLBACK;

-------------------------------------------------
-- Scenario 11:  (*) Writer (1) Reader (2)
--				show the change with READ COMMITTED SNAPSHOT
-------------------------------------------------
USE MattersOfConcurrency;
GO

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.SingleTable;
GO

--stop

ROLLBACK;
GO

-------------------------------------------------
-- Scenario 12:  Deadlock
-------------------------------------------------

USE MattersOfConcurrency;

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

--part 1
UPDATE Demo.Person
SET    Name = LOWER(Name)
WHERE  Name = 'Arnold';

--stop, go to other connection

--part 2
UPDATE Demo.Person
SET    Name = UPPER(Name)
WHERE  Name = 'Fred';

--stop
ROLLBACK;