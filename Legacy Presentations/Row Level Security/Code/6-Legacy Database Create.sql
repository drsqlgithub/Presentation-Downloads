-- http://sqlblog.com/blogs/louis_davidson/archive/tags/Row+Level+Security/default.aspx

ALTER DATABASE TestRowLevelSecurity_Legacy SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE master
GO
DROP DATABASE TestRowLevelSecurity_Legacy
GO
CREATE DATABASE TestRowLevelSecurity_Legacy
GO
USE TestRowLevelSecurity_Legacy
GO
ALTER DATABASE TestRowLevelSecurity_Legacy SET COMPATIBILITY_LEVEL = 100 --bad old days

DROP ROLE IF EXISTS BigHat_Role;
CREATE ROLE BigHat_Role;

DROP ROLE IF EXISTS MedHat_Role;
CREATE ROLE MedHat_Role;

DROP ROLE IF EXISTS SmallHat_Role;
CREATE ROLE SmallHat_Role;

--Scenario, you have the following three security principals:
DROP USER IF EXISTS BigHat; --DROP IF EXISTS works with users as well as objects: 
CREATE USER BigHat WITHOUT LOGIN; 

DROP USER IF EXISTS MedHat --MediumHat, which we want to get all of SmallHat's rights, but not BigHats 
CREATE USER MedHat WITHOUT LOGIN;

DROP USER IF EXISTS SmallHat -- gets a minimal amount of security 
CREATE USER SmallHat WITHOUT LOGIN;
GO

--Now put users in their roles
ALTER ROLE BigHat_Role ADD MEMBER BigHat;
ALTER ROLE MedHat_Role ADD MEMBER MedHat;
ALTER ROLE SmallHat_Role ADD MEMBER SmallHat;


--The table, will look like this:
GO
CREATE SCHEMA Demo; 
GO 
CREATE TABLE Demo.SaleItem 
( 
    SaleItemId    int CONSTRAINT PKSaleIitem PRIMARY KEY, 
    ManagedByRole nvarchar(15), --more typically would be sysname, but nvarchar(15) is easier to format for testing 
	SaleItemType  varchar(10)
) 
INSERT INTO Demo.SaleItem 
VALUES (1,'BigHat_Role','Big'),(2,'BigHat_Role','Big'),(3,'MedHat_Role','Med')
	  ,(4,'MedHat_Role','Med'),(5,'SmallHat_Role','Small'),(6,'SmallHat_Role','Small'); 
GO 
GRANT SELECT ON Demo.SaleItem TO SmallHat_Role, MedHat_Role, BigHat_Role;
GO