USE MattersOfConcurrency
GO
--turn on Accelerated database recovery and Optimized Locking
--rolling back may not be necessary, but it is easier when doing 
--demos!
ALTER DATABASE MattersOfConcurrency
    SET ACCELERATED_DATABASE_RECOVERY = ON
    WITH ROLLBACK IMMEDIATE;
ALTER DATABASE MattersOfConcurrency 
    SET OPTIMIZED_LOCKING = ON;

--This is off to show the effect of it being
--off.
ALTER DATABASE MattersOfConcurrency 
    SET READ_COMMITTED_SNAPSHOT OFF;


--all of these should generally be on for these demos
--except for is_read_committed_snapshot (to reduce the 
--effect of the effect of versions;
SELECT name,
       is_read_committed_snapshot_on,
       is_accelerated_database_recovery_on,
       is_optimized_locking_on
FROM sys.databases
WHERE name = DB_NAME();
GO
-- Get the current transaction isolation level
SELECT CASE transaction_isolation_level
           WHEN 0 THEN 'Unspecified'
           WHEN 1 THEN 'Read Uncommitted'
           WHEN 2 THEN 'Read Committed'
           WHEN 3 THEN 'Repeatable Read'
           WHEN 4 THEN 'Serializable'
           WHEN 5 THEN 'Snapshot'
       END AS IsolationLevel
FROM sys.dm_exec_sessions
WHERE session_id = @@SPID; 