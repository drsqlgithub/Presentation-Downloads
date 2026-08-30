--pre-created

--REBUILDING DEMOs.  Make sure to kill custom metrics
use master;
go
--kill any user in the way
ALTER DATABASE OurMonitor SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO 
drop database OurMonitor;
go
create database OurMonitor;
GO
