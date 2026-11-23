SELECT @@VERSION
GO

--Turn on SQLCMD Mode to run this script


----locate where you want data and logs
:setvar dataFile "C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\"
:setvar logFile "C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\"

/* If you want to use the default, this is the query to find the details
-- Query to find default data and log directories
SELECT SERVERPROPERTY('InstanceDefaultDataPath') AS DefaultDataPath,
       SERVERPROPERTY('InstanceDefaultLogPath') AS DefaultLogPath;
GO
*/

--if no, and db exists, then it will fail
:setvar DROPEXISTING Yes

--stop script execution if an error occurs
:ON ERROR EXIT

--database name
:setvar DataBaseName MattersOfConcurrency

--SIMPLE FULL
:setvar RecoveryMode Simple

--ENABLED or DISABLED
:setvar DelayedDurabity DISABLED

:setvar ReadCommittedSnapshot OFF
:setvar SnapshotIsolationLevel OFF
:setvar AcceleratedDatabaseRecovery OFF
--REQUIRES AcceleratedDatabaseRecovery to be on;
:setvar OptimizedLocking2025 OFF

:setvar databaseSize 30MB
:setvar databaseMaxSize 2GB
:setvar logSize 1GB
:setvar logMaxSize 2GB


--YES to create in mem filegroup
:setvar IncludeInMem NO
:setvar MemOptimizedElevateToSnapshot OFF

USE master
GO

SET NOCOUNT ON
GO

--drop db if you are recreating it, dropping all connections to existing database.
IF EXISTS (   SELECT *
              FROM   sys.databases
              WHERE  name = '$(DataBaseName)')
    AND '$(DROPEXISTING)' = 'Yes'
    EXEC('
ALTER DATABASE $(DataBaseName) SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

DROP DATABASE $(DataBaseName);')

CREATE DATABASE $(DataBaseName)
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'$(DataBaseName)', FILENAME = N'$(dataFile)$(DataBaseName).mdf' , SIZE = $(databaseSize) , MAXSIZE = $(databaseMaxSize), FILEGROWTH = 10% )
  LOG ON																													  						
( NAME = N'$(DataBaseName)_log', FILENAME = N'$(logFile)$(DataBaseName)_log.ldf' , SIZE = $(logSize) , MAXSIZE = $(logMaxSize) , FILEGROWTH = 10%);
GO

IF '$(IncludeInMem)' = 'YES'
 BEGIN
		ALTER DATABASE $(DataBaseName) SET AUTO_CLOSE OFF

        ALTER DATABASE $(DataBaseName) ADD FILEGROUP [MemoryOptimizedFG] CONTAINS MEMORY_OPTIMIZED_DATA; 

		ALTER DATABASE $(DataBaseName)
		ADD FILE
		(
		 NAME= N'$(DataBaseName)_inmemFiles',
		 FILENAME = N'$(dataFile)$(DataBaseName)InMemfiles'
		)
		TO FILEGROUP [MemoryOptimizedFG];
 END
GO


GO

ALTER DATABASE $(DataBaseName)
	SET RECOVERY $(RecoveryMode)
GO

ALTER DATABASE $(DataBaseName) SET ACCELERATED_DATABASE_RECOVERY = $(AcceleratedDatabaseRecovery);
ALTER DATABASE $(DataBaseName) SET OPTIMIZED_LOCKING = $(OptimizedLocking2025)



ALTER DATABASE $(DataBaseName)
	SET READ_COMMITTED_SNAPSHOT $(ReadCommittedSnapshot)
GO
ALTER DATABASE $(DataBaseName)
	SET ALLOW_SNAPSHOT_ISOLATION $(SnapshotIsolationLevel)
GO
ALTER DATABASE $(DataBaseName)
  SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT $(MemOptimizedElevateToSnapshot)
GO
ALTER DATABASE $(DataBaseName) SET DELAYED_DURABILITY = $(DelayedDurabity)  
GO


GO

USE tempdb --if you forget sqlcmd mode, at least objects wont be in master!
GO

USE $(DataBaseName)
GO

SELECT CONCAT('Compatibility Level: ', compatibility_level)COLLATE DATABASE_DEFAULT AS SystemProperty
FROM   sys.databases
WHERE  name = '$(DatabaseName)'
UNION ALL
SELECT collation_name
FROM   sys.databases
WHERE  name = '$(DatabaseName)'
UNION ALL
SELECT 'READ_COMMITTED_SNAPSHOT Is On'
FROM   sys.databases
WHERE  name = '$(DatabaseName)'
    AND is_read_committed_snapshot_on = 1
UNION ALL
SELECT CONCAT('Recovery Model: ', recovery_model_desc)
FROM   sys.databases
WHERE  name = '$(DatabaseName)'
UNION ALL
SELECT 'Delayed Durability is on'
FROM   sys.databases
WHERE  name = '$(DatabaseName)'
    AND delayed_durability = 1
UNION ALL
SELECT CONCAT('Containment: ', containment_desc)
FROM   sys.databases
WHERE  name = '$(DatabaseName)'
    AND containment <> 0
UNION ALL
SELECT CONCAT('CreateTime: ', create_date)
FROM   sys.databases
WHERE  name = '$(DatabaseName)'
UNION ALL
SELECT 'Memory Optimized Operations Enabled'
WHERE  EXISTS (   SELECT *
                  FROM   sys.filegroups
                  WHERE  type_desc = 'MEMORY_OPTIMIZED_DATA_FILEGROUP')
UNION ALL
SELECT CASE DATABASEPROPERTYEX(DB_NAME(), 'IsOptimizedLockingOn')
        WHEN 1 THEN 'OptimizedLockingEnabled'
        WHEN 0 THEN 'OptimizedLockingDisabled'
        ELSE 'CheckResultsForOptimizeLockingSetup' END AS optimized_locking_enabled;

GO
CREATE SCHEMA Demo
GO

CREATE TABLE Demo.SingleTable
(
    SingleTableId int         IDENTITY(1, 1) CONSTRAINT PKSingleTable PRIMARY KEY,
    Value         varchar(100),                                                                --*******no key on value for demo purposes******
    Padding       char(4000)  CONSTRAINT DFTLSingleTable_Padding DEFAULT(REPLICATE('a', 4000)) --so all rows not on single page

)

INSERT INTO Demo.SingleTable(Value)
VALUES('Fred'),
('Barney'),
('Wilma'),
('Betty'),
('Mr_Slate'),
('Slagstone'),
('Gazoo'),
('Hoppy'),
('Schmoo'),
('Slaghoople'),
('Pebbles'),
('BamBam'),
('Rockhead'),
('Arnold'),
('ArnoldMom'),
('Tex'),
('Dino')

CREATE TABLE Demo.Person
(
    PersonId int          NOT NULL IDENTITY(1, 1) CONSTRAINT PKPerson PRIMARY KEY,
    Name     varchar(100) CONSTRAINT AKPerson UNIQUE,
)

INSERT INTO Demo.Person(Name)
SELECT Value
FROM   Demo.SingleTable
GO

CREATE TABLE Demo.Interaction
(
    InteractionId   int          IDENTITY(1, 1) CONSTRAINT PKInteraction PRIMARY KEY,
    Subject         nvarchar(20),
    Message         nvarchar(100),
    InteractionTime datetime2(0),
    PersonId        int          CONSTRAINT FKInteraction$References$Demo_Person REFERENCES Demo.Person(PersonId),
    CONSTRAINT AKInteraction UNIQUE
    (
        PersonId,
        Subject,
        Message)
)

--add an insert first that loads other rows
INSERT INTO Demo.Interaction(Subject,
                             Message,
                             InteractionTime,
                             PersonId)
VALUES('Hello1', 'Hello There', SYSDATETIME(), 10)

INSERT INTO Demo.Interaction(Subject,
                             Message,
                             InteractionTime,
                             PersonId)
VALUES('Hello2', 'Hello There', SYSDATETIME(), 9)

INSERT INTO Demo.Interaction(Subject,
                             Message,
                             InteractionTime,
                             PersonId)
VALUES('Hello3', 'Hello There', SYSDATETIME(), 8)
GO


CREATE TABLE dbo.OptimizedLockingDemo
(
    OptimizedLockingDemoId int NOT NULL PRIMARY KEY,
    SomeValue VARCHAR(10) NOT NULL,
    --padding to make more real data size
    Padding CHAR(1000) DEFAULT 'padding' 
);
INSERT INTO dbo.OptimizedLockingDemo (OptimizedLockingDemoId,SomeValue)
SELECT value, RIGHT(CONCAT('000000',value),6)
FROM   GENERATE_SERIES(1,100000);
GO


SELECT 'Database Created!'