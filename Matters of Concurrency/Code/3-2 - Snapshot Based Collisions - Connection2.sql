PRINT 'You tried to run the entire file'
GO
:EXIT

USE MattersOfConcurrency;
GO

-------------------------------------------------
-- Scenario 2:  (*) Writer (1) Reader (2)
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo_Mem.SingleTable WITH (SNAPSHOT)
WHERE  Value = 'Fred';
GO

--**
--stop, run next after commit

BEGIN TRANSACTION;

SELECT *
FROM   Demo_Mem.SingleTable WITH(SNAPSHOT)
WHERE  Value = 'Fred';
GO

COMMIT;

COMMIT;
GO

--Using SNAPSHOT Isolation level, you can never
--see any other connection's changes

-------------------------------------------------
-- Scenario 3:  (*) Writer (1) Reader (2) - REPEATABLE READ
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo_Mem.SingleTable WITH(REPEATABLEREAD)
WHERE  Value = 'Fred';
GO

--stop

COMMIT; --If this commit happens first, it will always succeed
GO

-------------------------------------------------
-- Scenario 4:  (*) Writer (1) Reader (2)
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo_Mem.SingleTable WITH(REPEATABLEREAD)
WHERE  Value = 'Wilma';
GO

--stop

COMMIT;
GO

---------------------------------------------------
---- Scenario 5:  (*) Reader (1) Writer (2)
---------------------------------------------------
--if @@trancount > 0 ROLLBACK
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED
--BEGIN TRANSACTION

--UPDATE Demo_Mem.SingleTable WITH (SNAPSHOT)
--SET    Value = UPPER(Value)
--WHERE  Value = 'Fred'
--GO

--INSERT INTO Demo_Mem.SingleTable(Value)
--VALUES ('AlternateFred'),('AlternateBarney')

--COMMIT
--GO

----stop

---------------------------------------------------
---- Scenario 6:  (*) Reader (1) Writer (2)
---------------------------------------------------
--if @@trancount > 0 ROLLBACK
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED
--BEGIN TRANSACTION

----part 1
--INSERT INTO Demo_Mem.SingleTable(Value)
--VALUES ('AlternateFred'),('AlternateBarney')

--COMMIT
--GO

----stop, commit on other connection, then restart

----part 2

--BEGIN TRANSACTION

--UPDATE Demo_Mem.SingleTable WITH (SNAPSHOT)
--SET    Value = UPPER(Value)
--WHERE  Value = 'Fred'

--COMMIT
--GO

-------------------------------------------------
-- Scenario 7a:  (*) Reader (1) Writer (2)
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo_Mem.SingleTable WITH(SNAPSHOT)
SET    Value = Value;

COMMIT;
GO

-------------------------------------------------
-- Scenario 7b:  (*) Reader (1) Writer (2)
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

INSERT INTO Demo_Mem.SingleTable(Value)
VALUES('AlternateFred'), ('AlternateBarney');

COMMIT;
GO

--stop

-------------------------------------------------
-- Scenario 8:  (*) Writer (1) Writer (2)
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo_Mem.SingleTable WITH(SNAPSHOT)
SET    Value = 'Fred3'
WHERE  Value = 'Fred';

--stop
ROLLBACK;
GO

-------------------------------------------------
-- Scenario 9:  (*) Writer (1) Writer (2)
-------------------------------------------------

SELECT *
FROM   Demo_Mem.SingleTable WITH(SNAPSHOT);

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

INSERT INTO Demo_Mem.SingleTable(Value)
VALUES('AlternateFred'), ('AlternateBarney');
GO

SELECT   *
FROM     Demo_Mem.SingleTable WITH(SNAPSHOT)
ORDER BY singleTableId DESC;

COMMIT;
GO

--stop

-------------------------------------------------
-- Scenario 10:  Foreign Keys and Isolation Levels
-------------------------------------------------
--if @@trancount > 0 ROLLBACK
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED
--BEGIN TRANSACTION

--SELECT *
--FROM   Demo_Mem.Person WITH (SNAPSHOT)
--WHERE  PersonId = 1

--DELETE FROM Demo_Mem.Person WITH (SNAPSHOT)
--WHERE  PersonId = 1

--COMMIT --This commit should be first
--GO

--SELECT *
--FROM   Demo_Mem.Person WITH (SNAPSHOT)
--WHERE  PersonId = 1

----stop

-------------------------------------------------
-- Scenario 11:  Foreign Keys and Isolation Levels
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo_Mem.Person WITH(SNAPSHOT)
SET    Name = UPPER(Name)
WHERE  PersonId = 1;

SELECT *
FROM   Demo_Mem.Person WITH(SNAPSHOT)
WHERE  PersonId = 1;

COMMIT;
GO
--stop
