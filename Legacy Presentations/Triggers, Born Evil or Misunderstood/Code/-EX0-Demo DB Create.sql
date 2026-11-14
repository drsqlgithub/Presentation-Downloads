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
if exists (select * from sys.databases where name = 'TriggerProsecution')
 exec ('
alter database  TriggerProsecution
	set single_user with rollback immediate;

drop database TriggerProsecution;')
GO

CREATE DATABASE TriggerProsecution  
 CONTAINMENT = NONE
 ON  PRIMARY 
(	NAME = N'TriggerProsecution', 
	FILENAME = N'd:\SQL\DATA\TriggerProsecution.mdf' , --ssd, quite fast
	SIZE = 500MB , FILEGROWTH = 0 )
 LOG ON 
( 
	NAME = N'TriggerProsecution_log', 
	FILENAME = N'd:\SQL\LOG\TriggerProsecution_log.ldf' , 
	SIZE = 250MB , FILEGROWTH = 0)
GO
ALTER DATABASE TriggerProsecution SET COMPATIBILITY_LEVEL = 110
GO
ALTER DATABASE TriggerProsecution SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE TriggerProsecution SET ANSI_NULLS OFF 
GO
ALTER DATABASE TriggerProsecution SET ANSI_PADDING OFF 
GO
ALTER DATABASE TriggerProsecution SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE TriggerProsecution SET ARITHABORT OFF 
GO
ALTER DATABASE TriggerProsecution SET AUTO_CLOSE OFF 
GO
ALTER DATABASE TriggerProsecution SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE TriggerProsecution SET AUTO_SHRINK OFF 
GO
ALTER DATABASE TriggerProsecution SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE TriggerProsecution SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE TriggerProsecution SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE TriggerProsecution SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE TriggerProsecution SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE TriggerProsecution SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE TriggerProsecution SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE TriggerProsecution SET  DISABLE_BROKER 
GO
ALTER DATABASE TriggerProsecution SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE TriggerProsecution SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE TriggerProsecution SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE TriggerProsecution SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE TriggerProsecution SET  READ_WRITE 
GO
ALTER DATABASE TriggerProsecution SET RECOVERY SIMPLE 
GO
ALTER DATABASE TriggerProsecution SET  MULTI_USER 
GO
ALTER DATABASE TriggerProsecution SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE TriggerProsecution SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
USE TriggerProsecution
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') 
ALTER DATABASE TriggerProsecution MODIFY FILEGROUP [PRIMARY] DEFAULT
GO
CREATE SCHEMA Demo
GO
CREATE SCHEMA Utility
GO
CREATE SCHEMA Tools
GO
