PRINT 'You tried to run the entire file'
GO
:EXIT

USE MattersOfConcurrency;
GO

-------------------------------------------------
-- Scenario 1:  (*) Reader
--              In tightest Isolation Level, can Reader block Reader?
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.SingleTable;
GO

--stop,  then run other query

ROLLBACK;
GO

----------------------------------------------------------------
-- Scenario 2:  (*) Reader (1) Versus Reader (2) WITH XLOCK hint
--				Show that XLOCK may be ignored for clean page
----------------------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

CHECKPOINT; --forces a flush to disk so all pages are clean since we have no activity
GO

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;

SELECT *
FROM   Demo.SingleTable WITH (XLOCK); --(adding PAGLOCK will cause blocking, AND PAGE locks!)
GO

--stop, show lock viewer

ROLLBACK;
GO

-------------------------------------------------
-- Scenario 3:  (*) Writer (1) Reader (2)
--				show how an update effects readers
-------------------------------------------------

--using READ COMMITTED because it is typical, and writers
--generally work the same in the different levels

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo.SingleTable
SET    Value = UPPER(Value)
WHERE  Value = 'Fred';
GO

--stop

ROLLBACK;
GO

/* Add index to SingleTable
CREATE INDEX Value on Demo.SingleTable (Value)

--Far better to use unique constraint IF the value is unique!
drop index Value on Demo.SingleTable;

ALTER TABLE Demo.SingleTable 
   ADD CONSTRAINT AKsingleTable UNIQUE(Value);
*/

-------------------------------------------------
-- Scenario 4:  (*) Writer (1) Reader (2)
--			Show how things work when we update and then add a row
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

--part 1
UPDATE Demo.SingleTable
SET    Value = UPPER(Value)
WHERE  Value <> 'Fred';
GO

--stop

--part 2

INSERT INTO Demo.SingleTable(Value)
VALUES('AlternateFred'), ('AlternateBarney');

--stop
ROLLBACK;
GO

---------------------------------------------------
---- Scenario 5:  (*) Reader (1) Writer (2)
----				Show effects a reader can have on writers, if any :)
----				Start with READ COMMITTED

--CUT FOR TIME: READ COMMITTED holds no locks (in essense, a RC isolalation
--                             level query can't hurt others after commpletion)
---------------------------------------------------
--if @@trancount > 0 ROLLBACK --make sure there's no open transactions
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED
--BEGIN TRANSACTION

----part 1
--SELECT * 
--FROM   Demo.SingleTable
--WHERE  Value = 'Fred'
--GO

----stop

----part 2
--SELECT * 
--FROM   Demo.SingleTable
--WHERE  Value <> 'Fred'
--GO

----stop then go run the insert

--ROLLBACK 
--GO

-------------------------------------------------
-- Scenario 6:  (*) Reader (1) Writer (2)
--				Show how changes to the table coexist with 
--              REPEATABLE READs
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

BEGIN TRANSACTION;

--part 1
SELECT *
FROM   Demo.SingleTable;
GO

--stop

--part 2

SELECT *,
       CASE WHEN Value LIKE 'Alternate%'
                THEN 'New'
            ELSE ''
       END status
FROM   Demo.SingleTable;
GO

--stop, then go back to change rows

ROLLBACK;
GO

--reset
DELETE FROM Demo.SingleTable
WHERE Value IN ( 'AlternateFred', 'AlternateBarney' );
GO

---------------------------------------------------
---- Scenario 7:  (*) Reader (1) Writer (2)
----				Show what the serializable tran doesn't allow
--
--CUT FOR TIME: SERIALIZABLE DOESN'T ALLOW ANY MODIFICIATION
---------------------------------------------------
--if @@trancount > 0 ROLLBACK --make sure there's no open transactions
--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
--BEGIN TRANSACTION

--SELECT * 
--FROM   Demo.SingleTable
--GO

----stop

--ROLLBACK 
--GO

-------------------------------------------------
-- Scenario 8:  Foreign Keys and Isolation Levels
--				Show locks that are caused by FK in READ COMMITTED
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

--note: personId is an FK
INSERT INTO Demo.Interaction(Subject,
                             Message,
                             InteractionTime,
                             PersonId)
VALUES('Hello', 'Hello There', SYSDATETIME(), 1);

--stop, run competing query

---then try to insert another row
INSERT INTO Demo.Interaction(Subject, Message, InteractionTime, PersonId)
VALUES('Hello', 'Hello There', SYSDATETIME(), 2);

ROLLBACK;
GO

-------------------------------------------------
-- Scenario 9:  Foreign Keys and Isolation Levels
--              USING SERIALIZABLE
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;

INSERT INTO Demo.Interaction(Subject, Message, InteractionTime, PersonId)
VALUES('Hello', 'Hello There', SYSDATETIME(), 1);

ROLLBACK;
GO

-------------------------------------------------
-- Scenario 10:  Foreign Keys and Isolation Levels
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;

DELETE FROM Demo.Person --Doesn't fail, so no child rows
WHERE Name = 'Arnold';

--stop, show locks 
ROLLBACK;
GO

-------------------------------------------------
-- Scenario 10a:  Foreign Keys and Isolation Levels - CASCADE
-------------------------------------------------

--Make the constraint CASCADE DELETE

ALTER TABLE Demo.Interaction
DROP CONSTRAINT FKInteraction$References$Demo_Person;
GO

ALTER TABLE Demo.Interaction
ADD CONSTRAINT FKInteraction$References$Demo_Person FOREIGN KEY(PersonId)REFERENCES Demo.Person(PersonId)ON DELETE CASCADE;
GO

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

DELETE FROM Demo.Person --Proved no child rows earlier
WHERE Name = 'Arnold';

--stop, show locks 
ROLLBACK;
GO

-------------------------------------------------
-- Scenario 11:  (*) Writer (1) Reader (2)
--			Show READ COMMITTED SNAPSHOT
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

--make sure there's no open transactions

--kills all other connections
ALTER DATABASE MattersOfConcurrency SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

ALTER DATABASE MattersOfConcurrency SET READ_COMMITTED_SNAPSHOT ON; --changes to allow snapshot for read committed transactions
GO

ALTER DATABASE MattersOfConcurrency SET MULTI_USER;
GO

--stop

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

--part 1
UPDATE Demo.SingleTable
SET    Value = UPPER(Value)
WHERE  Value <> 'Fred';
GO

--stop

--part 2

INSERT INTO Demo.SingleTable(Value)
VALUES('AlternateFred2'), ('AlternateBarney2');

--stop
COMMIT;
GO

/* Add read committed snapshot setting to db
--change other connection to different tb

ALTER DATABASE MattersOfConcurrency
SET READ_COMMITTED_SNAPSHOT OFF
GO
*/

-------------------------------------------------
-- Scenario 12:  Deadlock
--			Show common deadlock scenario
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET DEADLOCK_PRIORITY HIGH; --This will be the more likely coonection to be saved

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

--part 1
UPDATE Demo.Person
SET    Name = LOWER(Name)
WHERE  Name = 'Fred';

--stop, go to other connection

--part 2
UPDATE Demo.Person
SET    Name = UPPER(Name)
WHERE  Name = 'Arnold';

--stop, back go to other connection to cause deadlock
ROLLBACK;