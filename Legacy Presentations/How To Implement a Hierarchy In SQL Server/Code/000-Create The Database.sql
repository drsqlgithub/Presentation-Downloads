--NOTE: Before executing, change to SQLCMD mode
--takes about 7 seconds on my machine
--built to support rather large Hierarchy examples

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

:setvar dataFile "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\"
:setvar logFile "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\"

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

