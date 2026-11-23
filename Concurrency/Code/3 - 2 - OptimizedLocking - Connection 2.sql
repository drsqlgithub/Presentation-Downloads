USE MattersOfConcurrency;

-------------------------------------------------
-- Scenario 1:  Updating One Row, using an indexed column
--              Optimized Locking, but not READ COMMITTED SNAPSHOT
-------------------------------------------------

/* Connection B */
BEGIN TRANSACTION
UPDATE dbo.OptimizedLockingDemo
SET    SomeValue = SomeValue  
WHERE  OptimizedLockingDemoId >= 30000

--> without OptLocking or Versioning: blocked
--> with OptLocking but not Versioning: not blocked

--stop

--****************************************************************
--***********************************************************  

ROLLBACK




-------------------------------------------------
-- Scenario 2.1 :  Updating One Row, using a non-indexed column
-------------------------------------------------

--previously we showed this would be blocked because all rows in
--table would be touched

/* Connection B */
BEGIN TRANSACTION
UPDATE dbo.OptimizedLockingDemo
SET    SomeValue = SomeValue + 'UPD'
WHERE  SomeValue = '078054' --only one row

--> without OptLocking or Versioning: blocked
--> with OptLocking Only: Blocked 
--> with Versioning and OptLocking: Lock after qualification means
-->      means only only one row remains locked because it checks
-->      the data before locking.

--stop

--****************************************************************
--***********************************************************  

ROLLBACK

-------------------------------------------------
-- Scenario 2.2 :  Updating One Row, using a non-indexed column
-- Now with Lock After Qualification
-------------------------------------------------

-- Just do 2.1 again



-------------------------------------------------
-- Scenario 4:  Updating rows that are on the same
-- page 
-------------------------------------------------

/* Connection B */
BEGIN TRANSACTION
UPDATE dbo.OptimizedLockingDemo
SET    SomeValue = SomeValue + 'UPD'
WHERE  OptimizedLockingDemoId % 2 = 0

SELECT *
FROM   dbo.OptimizedLockingDemo

COMMIT


--> without OptLocking or Versioning: blocked

