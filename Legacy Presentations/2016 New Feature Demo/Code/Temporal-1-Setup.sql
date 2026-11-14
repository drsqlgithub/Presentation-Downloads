--This presentation is culled from my blog series: http://sqlblog.com/blogs/louis_davidson/archive/tags/Temporal+Data/default.aspx
--Obviously I am just hitting the highlights, there is more detail to be found in the blogs

-- More Microsoft Documentation
-- https://docs.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables

--So if you have a row in a table, and it is created, updated, and then deleted, knowing how the row looked 
--at a given period of time can be very useful. I wanted to start with a very basic example, to show how 
--thing work, and later entries in this series will expand to multiple rows and tables.

select @@version; --Features are apt to change, this presentation built on SQL SERVER 2016 SP1

--First off, we need to create a workspace. I will just call the database testTemporal:

ALTER DATABASE TestTemporal SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE master
GO

DROP DATABASE testTemporal
GO
CREATE DATABASE TestTemporal;
GO
USE TestTemporal;
GO

--Nothing needed to be done to allow temporal, just create a database on the 2016 instance. The table needs to have a few new things, highlighted in the next example:
CREATE SCHEMA Demo;
GO
CREATE TABLE Demo.Company
(
    companyId INT IDENTITY(1, 1) CONSTRAINT PKCompany PRIMARY KEY, --Primary key is required
    name VARCHAR(30) CONSTRAINT AKCompany_Name UNIQUE,
    companyNumber CHAR(5) CONSTRAINT AKCompany_Number UNIQUE,

    --start and end time (can be named whatever you want)
    SysStartTime DATETIME2(7) GENERATED ALWAYS AS ROW START  NOT NULL, --the time when this row becomes in effect (note can be any datetime2 flavor 0-7
    SysEndTime DATETIME2(7) GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,     --the time when this row becomes no longer in effect 
        --notice I hid the end time, but not the start time, which shows you when the row was last modified

    --defines the start and end time for the system versioning
    PERIOD FOR SYSTEM_TIME(SysStartTime, SysEndTime))
WITH (SYSTEM_VERSIONING = ON); --Note that you can use a table of your own, preloaded with history. More on that later..
GO

--Note, the general format is:
	--SysStartTime		SysEndTime
	--Time				Time+1
	--Time+1			Time+2
	--Time+2			Infinity-ish

--Simple enough, and if you want to see more about the create table syntax, check BOL here (https://msdn.microsoft.com/en-us/library/ms174979.aspx) 

--create a row in the table:

INSERT INTO Demo.Company(name, companyNumber)
VALUES('Company1', '00001')

SELECT SCOPE_IDENTITY(); --If you don't mess up, this will be 1. We will use this in our examples 
GO

--Now we change something in the table a few times to let us have a few changes to see in the example:

UPDATE Demo.Company
SET    name = 'Company Name 1'
WHERE  companyId = 1;

--And update it again:

UPDATE Demo.Company
SET    name = 'Company Name 2'
WHERE  companyId = 1;

--This time update with no changes:

UPDATE Demo.Company
SET    name = 'Company Name 2'
WHERE  companyId = 1;

--To see the row exactly as it currently exists, just use a normal select statement:

SELECT *
FROM   Demo.Company
WHERE  companyId = 1;

--when you want to see the end time (which we usually will)
SELECT *,SysEndTime
FROM   Demo.Company
WHERE  companyId = 1;

--You will see that looks exactly as you expect:

--Using the FOR SYSTEM_TIME argument on the table, you can see changed data

SELECT   *, SysEndTime
FROM     Demo.Company FOR SYSTEM_TIME ALL --all changes (where time has passed, more on that in a sec)
ORDER BY SysEndTime DESC;

--this is equivalent to:
SELECT   *
FROM     Demo.Company FOR SYSTEM_TIME CONTAINED IN('1900-01-01', '9999-12-31 23:59:59.9999999')
ORDER BY SysEndTime DESC;

--(Others include AS OF (which I will use), FROM TO, BETWEEN AND). Read here  https://msdn.microsoft.com/en-us/library/dn935015(v=sql.130).aspx

--** Presentation Note: Make note of SysEndTime and SysStartTime precision here. 

--This returns all of the row versions that have been created:

-- Note: 
--  The first SysStartTime value will be when the row was created. 
--  The last row will be to 9999-12-31 23:59:59.9999999. 
--  When we updated the row with no actual data changes, we still get a new version.

--When working with the times and the FOR SYSTEM_TIME clause, be careful to include the time up to the fractional seconds or you may not get what you expect. 
--When using CONTAINED IN, if you don’t put the nines out to all seven decimal places, you won't get the current row due to roundoff:
SELECT   *,SysEndTime
FROM     Demo.Company FOR SYSTEM_TIME ALL --all changes (where time has passed, more on that in a sec)
ORDER BY SysEndTime DESC;

SELECT   *,SysEndTime
FROM     Demo.Company FOR SYSTEM_TIME CONTAINED IN('1900-01-01', '9999-12-31 23:59:59.999999') --Only six decimal places 
ORDER BY SysEndTime DESC;

--The more interesting use will be to work with a row (or rows) at a certain point in time, 
--Use FOR SYSTEM_TIME AS OF, which takes a datetime2 value, and returns the row where SysStartTime >= PassedValue > SysEndTime. (The PassedValue can also be a variable.)

--==============================
--Run Together

--all rows
SELECT   *,SysEndTime
FROM     Demo.company FOR SYSTEM_TIME ALL
ORDER BY SysEndTime DESC;

--get the third row
DECLARE @asOfTime DATETIME2(7) 
SELECT   TOP 3 @asOfTime = sysstarttime
FROM     Demo.company FOR SYSTEM_TIME ALL
ORDER BY SysEndTime DESC;

SELECT @asOfTime

--show the row we picked
SELECT priorCompany.*, priorCompany.SysEndTime
FROM   Demo.Company FOR SYSTEM_TIME AS OF @asOfTime priorCompany;

-- You can also use FOR SYSTEM_TIME in a JOIN criteria and see multiple versions of the row in your query:

SELECT Company.SysStartTime, Company.Name, priorCompany.SysStartTime as PriorSysStartTime, priorCompany.Name AS PriorName
FROM   Demo.Company
       JOIN Demo.Company FOR SYSTEM_TIME AS OF @asOfTime priorCompany
           ON Company.CompanyId = priorCompany.CompanyId;
GO 
--==============================


--Now, deleting all of the data, and then viewing it:

DELETE FROM Demo.Company
WHERE companyId = 1;

SELECT *, SysEndTime
FROM   Demo.Company FOR SYSTEM_TIME ALL
ORDER BY SysEndTime DESC;
GO


--==============================
--Run Together

--So looking for a row at a past time, the row did still exist:

SELECT *, SysEndTime
FROM   Demo.Company FOR SYSTEM_TIME ALL
ORDER BY SysEndTime DESC;

DECLARE @asOfTime DATETIME2(7) 
SELECT   TOP 3 @asOfTime = sysstarttime
FROM     Demo.company FOR SYSTEM_TIME ALL
ORDER BY SysEndTime DESC;

SELECT priorCompany.*
FROM   Demo.Company FOR SYSTEM_TIME AS OF @asOfTime priorCompany

--But looking at the table currently, no row:

SELECT *
FROM   Demo.Company;

--==============================
GO


--So finally, what happens when we replace the row using the same surrogate key value? (Not discussing here if this is a good idea, or bad idea…And this has led me to wonder if we can adjust history if the delete was accidental… Ah, fodder for later)

SET IDENTITY_INSERT Demo.Company ON
GO
INSERT INTO Demo.Company(companyId, name, companyNumber)
VALUES(1, 'Company One', '00001')
GO
SET IDENTITY_INSERT Demo.Company OFF
GO

--And then look at all of the row versions that exist now?
--You can see that the row now exists, but there is now a gap between the top two rows

--==============================
--Run Together

SELECT   *,SysEndTime
FROM     Demo.Company FOR SYSTEM_TIME ALL
ORDER BY SysStartTime DESC;

--Looking at the data at the current row’s SysStartTime:

DECLARE @asOfTime DATETIME2(7) 
SELECT   TOP 1 @asOfTime = sysstarttime
FROM     Demo.Company FOR SYSTEM_TIME ALL
ORDER BY SysEndTime DESC;

SELECT @asOfTime AS CurrentRowStartTime

SELECT  'Current Time', priorCompany.*, SysEndTime
FROM   Demo.Company FOR SYSTEM_TIME AS OF @asOfTime priorCompany

SELECT   TOP 2 @asOfTime = sysendtime --END TIME
FROM     Demo.Company FOR SYSTEM_TIME ALL
ORDER BY SysEndTime DESC;

SELECT @asOfTime AS [RowDeleteTime The end row of the row just before the latest row]

SELECT 'Deleted', priorCompany.*, SysEndTime
FROM   Demo.Company FOR SYSTEM_TIME AS OF @asOfTime priorCompany


--==============================
