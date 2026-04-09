--NOTE: Before executing, change to SQLCMD mode
--takes about 7 seconds on my machine
--built to support rather large Hierarchy examples

--NOTE this is part of a larger presentation you can find on hierarchy processing you can find here:
--https://github.com/drsqlgithub/Presentation-Downloads/tree/main/How%20To%20Implement%20a%20Hierarchy%20In%20SQL%20Server


USE master;
GO

SET NOCOUNT ON;
GO

--drop db if you are recreating it, dropping all connections to existing database.
IF EXISTS (   SELECT *
              FROM   sys.databases
              WHERE  Name = 'HowToOptimizeAHierarchyInSQLServer')
    EXEC('
alter database  HowToOptimizeAHierarchyInSQLServer
 
	set single_user with rollback immediate;

drop database HowToOptimizeAHierarchyInSQLServer;');

/*
--can't parameterize the file location using variables. Find your locatiions using:

SELECT 
    SERVERPROPERTY('InstanceDefaultDataPath') AS DefaultDataPath,
    SERVERPROPERTY('InstanceDefaultLogPath') AS DefaultLogPath;
*/

:setvar dataFile "C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\DATA\"
:setvar logFile "C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\DATA\"

CREATE DATABASE HowToOptimizeAHierarchyInSQLServer CONTAINMENT = NONE
ON PRIMARY(Name = N'HowToOptimizeAHierarchyInSQLServer',
           FILEName = N'$(dataFile)HowToOptimizeAHierarchyInSQLServer.mdf',
           SIZE = 10GB,
           MAXSIZE = 20GB,
           FILEGROWTH = 2GB)

--If you want to do mem optimized tables in 2017, uncomment
-- ,FILEGROUP [MemoryOptimizedFG] CONTAINS MEMORY_OPTIMIZED_DATA  DEFAULT
--( Name = N'HowToOptimizeAHierarchyInSQLServer_inmemFiles', FILEName = N'$(dataFile)HowToOptimizeAHierarchyInSQLServerInMemfiles' , MAXSIZE = UNLIMITED)

LOG ON(Name = N'HowToOptimizeAHierarchyInSQLServer_log',
       FILEName = N'$(logFile)HowToOptimizeAHierarchyInSQLServer_log.ldf',
       SIZE = 2GB,
       MAXSIZE = 4GB,
       FILEGROWTH = 1GB);
GO

ALTER DATABASE HowToOptimizeAHierarchyInSQLServer SET RECOVERY SIMPLE;
GO

--This has proved VERY helpful on a desktop machine
ALTER DATABASE HowToOptimizeAHierarchyInSQLServer SET DELAYED_DURABILITY=FORCED;
GO

