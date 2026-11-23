USE MattersOfConcurrency;

-------------------------------------------------
-- Scenario 1:  Updating One Row, using an indexed column
--              Optimized Locking, but not READ COMMITTED SNAPSHOT
-------------------------------------------------

/* Connection A */
BEGIN TRANSACTION
UPDATE dbo.OptimizedLockingDemo
SET    SomeValue = SomeValue  
WHERE  OptimizedLockingDemoId < 30000


--stop

--****************************************************************
--***********************************************************  


ROLLBACK




-------------------------------------------------
-- Scenario 2.1 :  Updating One Row, using a non-indexed column
-------------------------------------------------

/* Connection A */
BEGIN TRANSACTION
UPDATE dbo.OptimizedLockingDemo
SET    SomeValue = SomeValue + 'UPD'
WHERE  SomeValue = '017324' --only one row


--stop

--****************************************************************
--***********************************************************  

ROLLBACK


-------------------------------------------------
-- Scenario 2.2 :  Updating One Row, using a non-indexed column
-- Now with Lock After Qualification
-------------------------------------------------

ALTER DATABASE MattersOfConcurrency 
    SET READ_COMMITTED_SNAPSHOT ON
    WITH ROLLBACK IMMEDIATE;
GO

--Now do 2.1 again.

-------------------------------------------------
-- Scenario 3:  Updating rows that are on the same
-- page 
-------------------------------------------------

--cleanup check
--check to make sure no rows were in both sets
--should return 10000 and 0 respectively.

SELECT COUNT(*)
FROM dbo.OptimizedLockingDemo

SELECT COUNT(*)
FROM dbo.OptimizedLockingDemo
WHERE SomeValue NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9]'


--UPDATE dbo.OptimizedLockingDemo
--SET    SomeValue = REPLACE(SomeValue,'UPD','')    


--Now, on connection A, I will update all the 

/* Connection A */
BEGIN TRANSACTION
UPDATE dbo.OptimizedLockingDemo
SET    SomeValue = SomeValue + 'UPD'
WHERE  OptimizedLockingDemoId % 2 = 1

SELECT *
FROM   dbo.OptimizedLockingDemo

--stop

--****************************************************************
--***********************************************************  


COMMIT

--and, both committed
SELECT *
FROM   dbo.OptimizedLockingDemo

