USE testTemporal;
GO
--Show table and history table metadata from sys.tables
SELECT tables.object_id, CONCAT(schemas.name, '.', tables.name) AS table_name,
       historyTableSchema.name + '.' + historyTable.name AS history_table_name, tables.temporal_type_desc
FROM   sys.tables
       JOIN sys.schemas
           ON TABLES.schema_id = schemas.schema_id
       LEFT OUTER JOIN sys.tables historyTable
                       JOIN sys.schemas historyTableSchema
                           ON historyTable.schema_id = historyTableSchema.schema_id
           ON historyTable.object_id = TABLES.history_table_id
WHERE  tables.temporal_type_desc <> 'HISTORY_TABLE';
GO

--if trying on your own, you may need to replace the table name
SELECT *
FROM   Demo.MSSQL_TemporalHistoryFor_565577053;
GO

--cannot update history table manually
UPDATE Demo.MSSQL_TemporalHistoryFor_565577053
SET    SysEndTime = SysEndTime
WHERE  SysStartTime = SysStartTime;

--to adjust history, you can do the following
ALTER table Demo.company 
    SET (SYSTEM_VERSIONING = OFF);
GO

--Now these are just plain old tables...
SELECT tables.object_id, CONCAT(schemas.name, '.', tables.name) AS table_name,
       historyTableSchema.name + '.' + historyTable.name AS history_table_name, tables.temporal_type_desc
FROM   sys.tables
       JOIN sys.schemas
           ON TABLES.schema_id = schemas.schema_id
       LEFT OUTER JOIN sys.tables historyTable
                       JOIN sys.schemas historyTableSchema
                           ON historyTable.schema_id = historyTableSchema.schema_id
           ON historyTable.object_id = TABLES.history_table_id
WHERE  tables.temporal_type_desc <> 'HISTORY_TABLE';
GO


--now you can go to town on the data if you want to .
UPDATE Demo.MSSQL_TemporalHistoryFor_565577053
SET    SysEndTime = DATEADD(DAY,-10,SysEndTime);

UPDATE Demo.MSSQL_TemporalHistoryFor_565577053
SET    SysStartTime = DATEADD(DAY,-10,SysStartTime);


INSERT INTO demo.MSSQL_TemporalHistoryFor_565577053 ( companyId, name,
                                                  companyNumber, SysStartTime,
                                                  SysEndTime )
SELECT  1, -- companyId - int
          'History I Just Made', -- name - varchar(30)
          'Last1', -- companyNumber - char(5)
		  --the last endtime in the temporal table (the time of delete)
          (SELECT MAX(SysEndTime) FROM Demo.MSSQL_TemporalHistoryFor_565577053 WHERE companyId = 1),
		  --The start time of the row in the live table.
          (SELECT SysStartTime FROM Demo.Company WHERE companyId = 1);
          

SELECT *, SysEndTime
FROM   Demo.Company;

SELECT *
FROM   Demo.MSSQL_TemporalHistoryFor_565577053
ORDER BY SysStartTime DESC;


ALTER TABLE Demo.Company 
    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE=demo.MSSQL_TemporalHistoryFor_565577053, DATA_CONSISTENCY_CHECK = ON));

SELECT *, SysEndTime
FROM    Demo.Company FOR SYSTEM_TIME ALL
ORDER BY SysStartTime DESC;

--Note, changing history should be usually be done using transactions (especially if you don't have exclusive access, causing the lock to be held 

BEGIN TRANSACTION

ALTER table Demo.Company 
    SET (SYSTEM_VERSIONING = OFF);
GO

UPDATE Demo.MSSQL_TemporalHistoryFor_565577053
SET    SysEndTime = SysEndTime
WHERE  SysStartTime = SysStartTime;

EXEC sp_rename 'Demo.MSSQL_TemporalHistoryFor_565577053','CompanyHistory';

ALTER TABLE Demo.Company 
    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE=Demo.CompanyHistory, DATA_CONSISTENCY_CHECK = ON));

COMMIT;
GO

--Show table and history table metadata from sys.tables
SELECT tables.object_id, CONCAT(schemas.name, '.', tables.name) AS table_name,
       historyTableSchema.name + '.' + historyTable.name AS history_table_name, tables.temporal_type_desc
FROM   sys.tables
       JOIN sys.schemas
           ON TABLES.schema_id = schemas.schema_id
       LEFT OUTER JOIN sys.tables historyTable
                       JOIN sys.schemas historyTableSchema
                           ON historyTable.schema_id = historyTableSchema.schema_id
           ON historyTable.object_id = TABLES.history_table_id
WHERE  tables.temporal_type_desc <> 'HISTORY_TABLE';