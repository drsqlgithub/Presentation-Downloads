use master
go
set nocount on
go
--reset server settings to defaults...
exec sp_configure 'show advanced options',1
go
reconfigure
go
exec sp_configure 'nested triggers',1
exec sp_configure 'disallow results from triggers',0 --allow results
go
reconfigure
go

--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'TriggerDefense')
 exec ('
alter database  TriggerDefense
	set single_user with rollback immediate;

drop database TriggerDefense;')
GO

CREATE DATABASE TriggerDefense  
 CONTAINMENT = NONE
 ON  PRIMARY 
(	NAME = N'TriggerDefense', 
	FILENAME = N'd:\SQL\DATA\TriggerDefense.mdf' , --ssd, quite fast
	SIZE = 500MB , FILEGROWTH = 0 )
 LOG ON 
( 
	NAME = N'TriggerDefense_log', 
	FILENAME = N'd:\SQL\LOG\TriggerDefense_log.ldf' , 
	SIZE = 250MB , FILEGROWTH = 0)
GO
ALTER DATABASE TriggerDefense SET COMPATIBILITY_LEVEL = 110
GO
ALTER DATABASE TriggerDefense SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE TriggerDefense SET ANSI_NULLS OFF 
GO
ALTER DATABASE TriggerDefense SET ANSI_PADDING OFF 
GO
ALTER DATABASE TriggerDefense SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE TriggerDefense SET ARITHABORT OFF 
GO
ALTER DATABASE TriggerDefense SET AUTO_CLOSE OFF 
GO
ALTER DATABASE TriggerDefense SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE TriggerDefense SET AUTO_SHRINK OFF 
GO
ALTER DATABASE TriggerDefense SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE TriggerDefense SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE TriggerDefense SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE TriggerDefense SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE TriggerDefense SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE TriggerDefense SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE TriggerDefense SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE TriggerDefense SET  DISABLE_BROKER 
GO
ALTER DATABASE TriggerDefense SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE TriggerDefense SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE TriggerDefense SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE TriggerDefense SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE TriggerDefense SET  READ_WRITE 
GO
ALTER DATABASE TriggerDefense SET RECOVERY SIMPLE 
GO
ALTER DATABASE TriggerDefense SET  MULTI_USER 
GO
ALTER DATABASE TriggerDefense SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE TriggerDefense SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
USE TriggerDefense
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') 
ALTER DATABASE TriggerDefense MODIFY FILEGROUP [PRIMARY] DEFAULT
GO
CREATE SCHEMA Demo
GO
CREATE SCHEMA Utility
GO
CREATE SCHEMA Tools
GO


--simple object to capture errors...
CREATE TABLE Utility.ErrorLog(
        ErrorLogId int NOT NULL IDENTITY CONSTRAINT PKErrorLog PRIMARY KEY,
		Number int NOT NULL,
        Location sysname NOT NULL,
        Message varchar(4000) NOT NULL,
        LogTime datetime2(3) NULL
              CONSTRAINT dfltErrorLog_error_date  DEFAULT (sysdatetime()),
        ServerPrincipal sysname NOT NULL
              --use original_login to capture the user name of the actual user
              --not a user they have impersonated
              CONSTRAINT dfltErrorLog_error_user_name DEFAULT (original_login())
);
GO
CREATE PROCEDURE Utility.ErrorLog$Insert
(
        @ERROR_NUMBER int,
        @ERROR_LOCATION sysname,
        @ERROR_MESSAGE varchar(4000)
) as
 BEGIN
        SET NOCOUNT ON;
        BEGIN TRY
           INSERT INTO utility.ErrorLog(Number, Location,Message)
           SELECT @ERROR_NUMBER,COALESCE(@ERROR_LOCATION,'No Object'),@ERROR_MESSAGE;
        END TRY
        BEGIN CATCH
           INSERT INTO utility.ErrorLog(Number, Location, Message)
           VALUES (-100, 'utility.ErrorLog$insert',
                        'An invalid call was made to the error log procedure ' + ERROR_MESSAGE());
        END CATCH
END;



