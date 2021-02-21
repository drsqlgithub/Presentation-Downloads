--Viewing data
USE MattersOfConcurrency;
GO
SELECT @@SPID;
GO

--Description: Show locks held by READ UNCOMMITTED read only transaction 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
BEGIN TRANSACTION

SELECT *
FROM   Demo.SingleTable

--**
--What will be locked?

ROLLBACK TRANSACTION
GO

--Description: Show locks held by READ COMMITTED read only transaction
SET TRANSACTION ISOLATION LEVEL READ COMMITTED
BEGIN TRANSACTION

SELECT *
FROM   Demo.SingleTable --(HOLDLOCK)

--**
--What will be locked?


--This will show you what was locked, by holding the locks for the transaction
SELECT *
FROM   Demo.SingleTable (HOLDLOCK)

--**

ROLLBACK TRANSACTION
GO


--Description: Show locks held by REPEATABLE READ read only transaction
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
BEGIN TRANSACTION

SELECT *
FROM   Demo.SingleTable

--**
--What will be locked?

ROLLBACK TRANSACTION
GO

--Description: Show locks held by SERIALIZABLE read only transaction
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
BEGIN TRANSACTION
GO
SELECT *
FROM   Demo.SingleTable

--**
--What will be locked?

ROLLBACK TRANSACTION
GO



--Description: Show locks held by SNAPSHOT (On Disk Tables) read only transaction

--must turn on Snapshot Isolation Capabilities
ALTER DATABASE MattersOfConcurrency
	SET ALLOW_SNAPSHOT_ISOLATION ON
GO


SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRANSACTION

SELECT *
FROM   Demo.SingleTable

--**
--What will be locked?

ROLLBACK TRANSACTION
GO



----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Modifying data
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

--Description: Show locks held by READ UNCOMMITTED modification transaction

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN TRANSACTION

UPDATE Demo.SingleTable
SET Value = UPPER(Value)
WHERE Value like 'F%'

--**
--What will be locked?

ROLLBACK TRANSACTION
GO


--Description: Show locks held by READ COMMITTED modification transaction

SET TRANSACTION ISOLATION LEVEL READ COMMITTED
BEGIN TRANSACTION

UPDATE Demo.SingleTable
SET Value = 'Fred' 
WHERE Value like 'F%'

--**
--What will be locked?

ROLLBACK TRANSACTION
GO


--Description: Show locks held by REPEATABLE READ modification transaction

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
BEGIN TRANSACTION

UPDATE Demo.SingleTable
SET Value = UPPER(Value)
WHERE Value like 'F%'

--**
--What will be locked? (Note the IX lock on the object...)

ROLLBACK TRANSACTION
GO

--Description: Show locks held by SERIALIZABLE modification transaction

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
BEGIN TRANSACTION

UPDATE Demo.SingleTable
SET Value = UPPER(Value)
WHERE Value like 'F%'

--**
--What will be locked? (Note that SERIALIZABLE applies to the read of the table, so no new
--rows could be created due to this requiring a table scan (no index on Value column)

ROLLBACK TRANSACTION
GO

--Description: Show locks held by SNAPSHOT (On Disk) modification transaction

SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRANSACTION

UPDATE Demo.SingleTable
SET Value = UPPER(Value)
WHERE Value like 'F%'

--**
--What will be locked? (The purpose this time is far different, but still is fairly a hefty cost)

ROLLBACK TRANSACTION
GO

