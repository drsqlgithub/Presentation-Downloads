PRINT 'You tried to run the entire file'
GO
:EXIT

USE MattersOfConcurrency;
GO

-------------------------------------------------
-- Scenario: 1 (*) Reader (1) Versus Reader (2)
--		After just adding the tables
-------------------------------------------------

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT * /* by default need isolation level hint 
                       in explicit transaction */
FROM   Demo_Mem.SingleTable WITH (REPEATABLEREAD);
GO

--show lock viewer, no locks on data at all... just schema locks

ROLLBACK; --I will always rollback/commit so we reset no matter how many transactions have been committed
GO

-------------------------------------------------
-- Scenario: 1a
--		SHOW DB setting that allows you to not set the 
--	    isolation level in the query
-------------------------------------------------
--not in a explicit transaction
SELECT *
FROM   Demo_Mem.SingleTable 
GO

--in an explicit transaction
BEGIN TRANSACTION;

SELECT *
FROM   Demo_Mem.SingleTable 

ROLLBACK TRANSACTION;
GO

--changes that behavior to allow it
ALTER DATABASE MattersOfConcurrency
  SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT ON;
GO

SET TRANSACTION ISOLATION LEVEL READ COMMITTED
BEGIN TRANSACTION
GO

SELECT *
FROM   Demo_Mem.SingleTable --WITH (SNAPSHOT)
GO

COMMIT 
GO

--in examples, I want to show isolation level explicitly and use the engine
--to make sure I do
ALTER DATABASE MattersOfConcurrency
 SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT OFF;

--I will leave it as obvious that readers don't block readers in MVCC any more than
--using locks

-------------------------------------------------
-- Scenario 2:  (*) Writer (1) Reader (2)
--		In SNAPSHOT Isolation level, show that the result is the same 
--      regardless of who commit first
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK; --make sure there's no open transactions

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo_Mem.SingleTable WITH (SNAPSHOT)
SET    Value = UPPER(Value)
WHERE  Value = 'Fred';
GO

--**
--stop

COMMIT;
GO

--Reset, before running scenario 3, because very few issues
--happen at execution, mostly at COMMIT

UPDATE Demo_Mem.SingleTable WITH(SNAPSHOT) --big difference between on disk and mem opt demos. You need to commit to see the outcome 
SET    Value = 'Fred'                      --which complicates matters
WHERE  Value = 'Fred';
GO

-------------------------------------------------
-- Scenario 3:  (*) Writer (1) Reader (2)
--			Show effects of the writer on the reader in REPEATABLE READ
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo_Mem.SingleTable WITH(SNAPSHOT)
SET    Value = LOWER(Value)
WHERE  Value = 'Fred';
GO

SELECT *
FROM   Demo_Mem.SingleTable WITH(SNAPSHOT)
WHERE  Value = 'Fred';

--stop
COMMIT; --commit this connection first... 
GO

--Reset
UPDATE Demo_Mem.SingleTable WITH(SNAPSHOT)
SET    Value = 'Fred'
WHERE  Value = 'Fred';
GO

-------------------------------------------------
-- Scenario 4:  (*) Writer (1) Reader (2)
--			Show effects of the writer on the reader
--          not using an index, still with reader in REPEATABLE READ
-------------------------------------------------

IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo_Mem.SingleTable WITH(SNAPSHOT)
SET    Value = UPPER(Value)
WHERE  Value = 'Fred'; --note, we didn't put a constraint/index here
GO

--stop

COMMIT;
GO

/* Add contraint (an index will work here just like for
   disk based, run 4 again
ALTER TABLE Demo_Mem.SingleTable 
	ADD CONSTRAINT AKsingleTable UNIQUE NONCLUSTERED(Value)
*/

--Reset

UPDATE Demo_Mem.SingleTable WITH(SNAPSHOT)
SET    Value = 'Fred'
WHERE  Value = 'Fred';
GO

---------------------------------------------------
---- Scenario 5:  (*) Reader (1) Writer (2)
----		show how the reader never changes in SNAPSHOT
---------------------------------------------------
--if @@trancount > 0 ROLLBACK
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED
--BEGIN TRANSACTION

--SELECT * 
--FROM   Demo_Mem.SingleTable WITH (SNAPSHOT)

----stop

--SELECT * 
--FROM   Demo_Mem.SingleTable WITH (SNAPSHOT)
--COMMIT
--GO
--SELECT * 
--FROM   Demo_Mem.SingleTable WITH (SNAPSHOT)
--GO

----stop

----Reset
--UPDATE Demo_Mem.SingleTable WITH (SNAPSHOT)
--SET    Value = 'Fred'
--WHERE  Value = 'Fred'

--DELETE FROM Demo_Mem.SingleTable
--WHERE  Value IN ('AlternateFred','AlternateBarney')

---------------------------------------------------
---- Scenario 6:  (*) Reader (1) Writer (2)
----		show how the reader is affected by the writers
---------------------------------------------------
--if @@trancount > 0 ROLLBACK
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED
--BEGIN TRANSACTION

--SELECT * 
--FROM   Demo_Mem.SingleTable WITH (REPEATABLEREAD)
--GO

----stop, run a batch on 2 and then commit

--COMMIT
--GO

----Reset
--UPDATE Demo_Mem.SingleTable WITH (SNAPSHOT)
--SET    Value = 'Fred'
--WHERE  Value = 'Fred'

--DELETE FROM Demo_Mem.SingleTable
--WHERE  Value IN ('AlternateFred','AlternateBarney')

-------------------------------------------------
-- Scenario 7:  (*) Reader (1) Writer (2)
-------------------------------------------------

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT *
FROM   Demo_Mem.SingleTable WITH(SERIALIZABLE);
GO

--stop

COMMIT; --mention scans and index dmv sys.dm_db_xtp_index_stats
--phantom scan
GO

--repeat for 7b too, to show different sorts of errors from
--SERIALIZABLE

--Show how INDEX has been used for phantom lookups
--which is how it looks for SERIALIZABLE issues

SELECT *
FROM   sys.dm_db_xtp_index_stats
       JOIN sys.indexes
           ON dm_db_xtp_index_stats.index_id = indexes.index_id
               AND dm_db_xtp_index_stats.object_id = indexes.object_id
WHERE  indexes.name = 'AKSingleTable';

--reset
DELETE FROM Demo_Mem.SingleTable
WHERE Value IN ( 'AlternateFred', 'AlternateBarney' );

-------------------------------------------------
-- Scenario 8:  (*) Writer (1) Writer (2)
--		show what happens when two connections try to write
--		the same physical resource
-------------------------------------------------
IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Demo_Mem.SingleTable WITH(SNAPSHOT)
SET    Value = 'Fred2'
WHERE  Value = 'Fred';

--stop
ROLLBACK;
GO

-------------------------------------------------
-- Scenario 9:  (*) Writer (1) Writer (2)
--		show what happens when a key violation (based on the key we
--      added) occurs during the transaction. This is an example of
--      a logical resource until commit time. It is not checked until commit
-------------------------------------------------

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

--stop
COMMIT;
GO

DELETE FROM Demo_Mem.SingleTable
WHERE Value IN ( 'AlternateFred', 'AlternateBarney' ); 

-------------------------------------------------
-- Scenario 10:  Foreign Keys and Isolation Levels
--		Show how the FK reference works in SNAPSHOT isolation level
--      Removing the data that the FK referenced 
-------------------------------------------------
--if @@trancount > 0 ROLLBACK
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED
--BEGIN TRANSACTION 

--INSERT INTO Demo_Mem.Interaction WITH (SNAPSHOT) (Subject, Message, InteractionTime, PersonId)									
--VALUES ('Hello','Hello There',SYSDATETIME(),1)
--GO

----stop

--SELECT *
--FROM   Demo_Mem.Interaction WITH (SNAPSHOT)
--WHERE  PersonId = 1

--SELECT *
--FROM   Demo_Mem.Person WITH (SNAPSHOT)
--WHERE  PersonId = 1

--COMMIT 
--GO

----reset
--SET IDENTITY_INSERT Demo_Mem.Person ON
--GO
--INSERT INTO Demo_Mem.Person (PersonId, Name)
--VALUES (1,'Tex')
--GO
--SET IDENTITY_INSERT Demo_Mem.Person OFF
--GO

-------------------------------------------------
-- Scenario 11:  Foreign Keys and Isolation Levels
--		Show what happens when a non-key column is updates on a FK reference
-------------------------------------------------
IF @@TRANCOUNT > 0
    ROLLBACK;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

INSERT INTO Demo_Mem.Interaction WITH(SNAPSHOT)
VALUES('Hello', 'Hello There', SYSDATETIME(), 1);
GO

--stop

SELECT *
FROM   Demo_Mem.Interaction WITH(SNAPSHOT)
WHERE  PersonId = 1;

SELECT *
FROM   Demo_Mem.Person WITH(SNAPSHOT)
WHERE  PersonId = 1;

--stop
COMMIT; --Other one first
GO

--reset
UPDATE Demo_Mem.Person WITH(SNAPSHOT)
SET    Name = 'Tex'
WHERE  PersonId = 1;