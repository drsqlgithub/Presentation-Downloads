--15 seconds last run

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
if exists (select * from sys.databases where name = 'HowToWriteADmlTrigger')
 exec ('
alter database  HowToWriteADmlTrigger
	set single_user with rollback immediate;

drop database HowToWriteADmlTrigger;')
GO

CREATE DATABASE HowToWriteADmlTrigger
GO
USE HowToWriteADmlTrigger
go
--I rely on the default, no matter what the Model database may say
alter database HowToWriteADmlTrigger	
	set recursive_triggers off;
go
CREATE SCHEMA Utility;
go
GRANT EXECUTE ON SCHEMA::Utility TO PUBLIC
go
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
GO

