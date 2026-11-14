DECLARE @session_id int = NULL

SELECT  DTL.[request_session_id] AS [session_id], DB_NAME(DTL.[resource_database_id]) AS [Database], DTL.resource_type,
        CASE WHEN DTL.resource_type IN ( 'DATABASE', 'FILE', 'METADATA' ) THEN DTL.resource_type
             WHEN DTL.resource_type = 'OBJECT' THEN OBJECT_NAME(DTL.resource_associated_entity_id, DTL.[resource_database_id])
             WHEN DTL.resource_type IN ( 'KEY', 'PAGE', 'RID' ) THEN ( SELECT   OBJECT_NAME([object_id])
                                                                       FROM     sys.partitions
                                                                       WHERE    sys.partitions.hobt_id = DTL.resource_associated_entity_id )
             ELSE 'Unidentified'
        END AS [Parent Object], DTL.request_mode AS [Lock Type], DTL.request_status AS [Request Status], DER.[blocking_session_id], DES.[login_name],
        CASE DTL.request_lifetime
          WHEN 0 THEN DEST_R.TEXT
          ELSE DEST_C.TEXT
        END AS [Statement]
FROM    sys.dm_tran_locks DTL
        LEFT JOIN sys.[dm_exec_requests] DER
            ON DTL.[request_session_id] = DER.[session_id]
        INNER JOIN sys.dm_exec_sessions DES
            ON DTL.request_session_id = DES.[session_id]
        INNER JOIN sys.dm_exec_connections DEC
            ON DTL.[request_session_id] = DEC.[most_recent_session_id]
        OUTER APPLY sys.dm_exec_sql_text(DEC.[most_recent_sql_handle]) AS DEST_C
        OUTER APPLY sys.dm_exec_sql_text(DER.sql_handle) AS DEST_R
WHERE   DTL.[resource_database_id] = DB_ID()
   AND  (DTL.[request_session_id] = @session_id OR @session_id IS NULL) 
ORDER BY DTL.[request_session_id]


SELECT  DTL.[request_session_id] AS [session_id], DB_NAME(DTL.[resource_database_id]) AS [Database], DTL.resource_type,
 DTL.request_mode AS [Lock Type], DTL.request_status AS [Request Status], DER.[blocking_session_id], DES.[login_name],
        CASE DTL.request_lifetime
          WHEN 0 THEN DEST_R.TEXT
          ELSE DEST_C.TEXT
        END AS [Statement]
FROM    sys.dm_tran_locks DTL
        LEFT JOIN sys.[dm_exec_requests] DER
            ON DTL.[request_session_id] = DER.[session_id]
        INNER JOIN sys.dm_exec_sessions DES
            ON DTL.request_session_id = DES.[session_id]
        INNER JOIN sys.dm_exec_connections DEC
            ON DTL.[request_session_id] = DEC.[most_recent_session_id]
        OUTER APPLY sys.dm_exec_sql_text(DEC.[most_recent_sql_handle]) AS DEST_C
        OUTER APPLY sys.dm_exec_sql_text(DER.sql_handle) AS DEST_R
WHERE   DTL.[resource_database_id] <> DB_ID() 
   AND  (DTL.[request_session_id] = @session_id OR @session_id IS NULL) 
ORDER BY DTL.[request_session_id]