/*
================================================================================
TRANSACTION AND LOCKING DIAGNOSTIC QUERY - DMV DOCUMENTATION
================================================================================

PURPOSE:
--------
This query uses Dynamic Management Views (DMVs) to diagnose locking and blocking
issues in SQL Server. It shows what locks are being held by specific sessions
(or all sessions), what resources they're locking, and if any blocking is occurring.

WHAT ARE DMVs?
--------------
Dynamic Management Views (DMVs) are special system views in SQL Server that provide
real-time information about server state, resource usage, queries, connections,
and transactions. They're essential for monitoring and troubleshooting.

MAIN DMVs USED IN THIS QUERY:
------------------------------
1. sys.dm_tran_locks (DTL)
   - Shows all currently active locks in the database engine
   - Tells you: WHO has a lock, WHAT they're locking, and what TYPE of lock

2. sys.dm_exec_sessions (DES)
   - Contains one row per authenticated session
   - Provides session-level information like login name, connection time

3. sys.dm_exec_connections (DEC)
   - Shows information about connections to SQL Server
   - Used here to get the most recent SQL executed by the connection

4. sys.dm_exec_requests (DER)
   - Shows information about currently executing requests
   - Used here to identify blocking sessions

5. sys.partitions & sys.indexes
   - Catalog views to translate internal resource IDs to object/index names

6. sys.dm_exec_sql_text (DEST_C, DEST_R)
   - Table-valued function that returns the SQL text for a given SQL handle

HOW THIS QUERY WORKS:
---------------------
*/

USE MattersOfConcurrency;

-- Step 1: Create a table variable to store session IDs (SPIDs) we want to monitor
-- If this table is empty, the query will show ALL sessions in the database
DECLARE @spidToWatch table (spid int);

-- Step 2: Insert specific session IDs to monitor (77 and 66 in this example)
-- You can change these numbers or leave them out to monitor all sessions
INSERT INTO @spidToWatch(spid)
VALUES (74),(77)

-- Step 3: Main query to retrieve lock information
--query taken from: https://www.simple-talk.com/sql/database-administration/investigating-transactions-using-dynamic-management-objects/
--written by Timothy Ford (adapted from adapted from a chapter of 'Performance Tuning with SQL Server Dynamic Management' by Tim and myself..
--free ebook version available here: https://www.simple-talk.com/books/sql-books/performance-tuning-with-sql-server-dynamic-management-views/

SELECT   
         -- Column 1: Shows the session ID and if it's being blocked, shows "sessionID/blockerID"
         CONCAT(DTL.request_session_id,
                CASE WHEN COALESCE(DER.blocking_session_id, 0) <> 0
                         THEN '/' + CAST(DER.blocking_session_id AS varchar(10))
                     ELSE NULL
                END) AS [session/blocker],
         
         -- Column 2: Type of resource being locked (DATABASE, TABLE, PAGE, KEY, RID, etc.)
         DTL.resource_type,
         
         -- Column 3: The parent object name (table name) being locked
         -- Different logic based on resource type to translate internal IDs to names
         CASE WHEN DTL.resource_type IN ( 'DATABASE', 'FILE', 'METADATA' )
                  THEN DTL.resource_type
              WHEN DTL.resource_type = 'OBJECT'
                  THEN OBJECT_NAME(DTL.resource_associated_entity_id, DTL.resource_database_id)
              WHEN DTL.resource_type IN ( 'KEY', 'PAGE', 'RID' )
                  THEN (   SELECT TOP(1) OBJECT_NAME(object_id)
                           FROM   sys.partitions
                           WHERE  sys.partitions.hobt_id = DTL.resource_associated_entity_id)
              ELSE 'Unidentified'
         END AS [Parent Object],
         
         -- Column 4: Lock mode (S=Shared, X=Exclusive, U=Update, IS=Intent Shared, etc.)
         DTL.request_mode AS [Lock Type],
         
         -- Column 5: Whether the lock is GRANTED, WAITING, or CONVERT
         DTL.request_status AS [Request Status],
         
         -- Column 6: Object name (duplicates Parent Object in some cases)
         CASE WHEN DTL.resource_type = 'OBJECT'
                  THEN OBJECT_NAME(DTL.resource_associated_entity_id)
              ELSE OBJECT_NAME(partitions.object_id)
         END AS ObjectName,
         
         -- Column 7: Index ID (0=heap, 1=clustered index, >1=nonclustered index)
         partitions.index_id,
         
         -- Column 8: Index name
         indexes.name AS index_name,
         
         -- Column 9: Additional details about the locked resource (like page numbers)
         DTL.resource_description
             
                   
-- Main table: sys.dm_tran_locks - contains all active locks
FROM     sys.dm_tran_locks DTL
         
         -- Join to sessions to get session information
         INNER JOIN sys.dm_exec_sessions DES
             ON DTL.request_session_id = DES.session_id
         
         -- Join to connections to get SQL handle for query text
         INNER JOIN sys.dm_exec_connections DEC
             ON DTL.request_session_id = DEC.most_recent_session_id
         
         -- Join to partitions to resolve KEY/PAGE/RID locks to object names
         LEFT JOIN sys.partitions
             ON partitions.hobt_id = DTL.resource_associated_entity_id
         
         -- Join to indexes to get index names
         LEFT JOIN sys.indexes
             ON indexes.object_id = partitions.object_id
                 AND indexes.index_id = partitions.index_id
         
         -- Join to requests to identify blocking relationships
         LEFT JOIN sys.dm_exec_requests DER
             ON DTL.request_session_id = DER.session_id
         
         -- OUTER APPLY to get the SQL text (these are prepared for use but not currently displayed)
         OUTER APPLY sys.dm_exec_sql_text(DEC.most_recent_sql_handle) AS DEST_C
         OUTER APPLY sys.dm_exec_sql_text(DER.sql_handle) AS DEST_R

-- Filter to only show locks in the current database
WHERE    DTL.resource_database_id = DB_ID()
         -- Filter to show only the sessions we're watching, or ALL sessions if @spidToWatch is empty
    AND (   DTL.request_session_id IN (SELECT spid FROM @spidToWatch)
            OR NOT EXISTS (SELECT spid FROM @spidToWatch) )

-- Order results by session ID for easier reading
ORDER BY DTL.request_session_id;

/*
ADDITIONAL DIAGNOSTIC TOOL:
---------------------------
The DBCC PAGE command below can be used to examine the contents of a specific page
when you need to investigate page-level locking issues. 

Lookup the page:
DECLARE @databaseId int = db_id()
DBCC TRACEON(3604)  -- Sends DBCC output to the client (SSMS)
DBCC PAGE(@databaseId,1,284,3) -- Format: PAGE(database_id, file_id, page_number, print_option)
                               -- print_option 3 = detailed page dump
*/

/*
COMMON USE CASES:
-----------------
1. Finding blocking: Look for sessions with blocking_session_id > 0
2. Identifying hot resources: Look for many sessions waiting on the same object
3. Lock escalation: Check if page locks have escalated to table locks
4. Deadlock investigation: Run during suspected deadlock scenarios

TYPICAL LOCK TYPES:
-------------------
S   = Shared (reading data)
X   = Exclusive (modifying data)
U   = Update (may convert to X)
IS  = Intent Shared
IX  = Intent Exclusive
Sch-S = Schema Stability
Sch-M = Schema Modification
*/


