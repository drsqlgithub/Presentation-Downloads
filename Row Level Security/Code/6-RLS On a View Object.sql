SELECT 'IN SQLCMD Mode, this will keep you from running the entire script'
GO
EXIT
GO
------------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'TestRowLevelSecurity_View')
	ALTER DATABASE TestRowLevelSecurity_View SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE master
GO
DROP DATABASE IF EXISTS TestRowLevelSecurity_View
GO
CREATE DATABASE TestRowLevelSecurity_View
GO
USE TestRowLevelSecurity_View
GO



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

--user gets rights to table, for demo purposes
GRANT SELECT ON Demo.SaleItem TO SmallHat_Role, MedHat_Role, BigHat_Role;
GO
------------------------------------------------------------------------------------

--Note: Must be schemabound for RLS. Cannot be a simple user defined function
CREATE OR ALTER VIEW Demo.SaleItem_RLSView
WITH SCHEMABINDING
AS
	SELECT SaleItemId, ManagedByRole, SaleItemType
	FROM   Demo.SaleItem
WITH CHECK OPTION;
GO
GRANT SELECT ON Demo.SaleItem_RLSView TO SmallHat_Role, MedHat_Role, BigHat_Role;
GO

CREATE SCHEMA rowLevelSecurity
GO
--Implements a simple hierarchy using basic system functions
--NOTE: the function must be a simple table valued function
CREATE OR ALTER FUNCTION rowLevelSecurity.ManagedByRole$SecurityPredicate (@ManagedByRole AS sysname) 
    RETURNS TABLE --value of 1 means they have access... 
WITH SCHEMABINDING --if schemabound, users needn't have rights to the function
AS --must be a simple table valued function
    RETURN (SELECT 1 AS ManagedByRole$SecurityPredicate 
            WHERE IS_MEMBER(@ManagedByRole) = 1 --User is a member of the role 
             OR (IS_MEMBER('MedHat_Role') = 1 AND @ManagedByRole = 'SmallHat_Role')  --if the user is MedHat, and the row isn't managed by BigHat 
             OR (IS_MEMBER('BigHat_Role') = 1) ); --Or the user is the BigHat person, they can see everything 
GO

--simple, data viewing filter 
CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) 
			ON Demo.SaleItem_RLSView
    WITH (STATE = ON); --go ahead and make it apply
GO

--FROM THE VIEW
EXECUTE AS USER = 'SmallHat'; 
GO 
SELECT USER_NAME(), * FROM Demo.SaleItem_RLSView; 
GO 
REVERT; 
GO

EXECUTE AS USER = 'MedHat'; 
GO 
SELECT USER_NAME(),* FROM Demo.SaleItem_RLSView; 
GO 
REVERT; 

EXECUTE AS USER = 'BigHat'; 
GO 
SELECT USER_NAME(),* FROM Demo.SaleItem_RLSView; 
GO 
REVERT; 
GO

--FROM THE TABLE

EXECUTE AS USER = 'SmallHat'; 
GO 
SELECT USER_NAME(), * FROM Demo.SaleItem; 
GO 
REVERT; 
GO

EXECUTE AS USER = 'MedHat'; 
GO 
SELECT USER_NAME(),* FROM Demo.SaleItem; 
GO 
REVERT; 

EXECUTE AS USER = 'BigHat'; 
GO 
SELECT USER_NAME(),* FROM Demo.SaleItem; 
GO 
REVERT; 

--=============
--Note, cannot use BLOCK predicate on a view
DROP SECURITY POLICY IF EXISTS rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
    ADD BLOCK PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) 
			ON Demo.saleItem_RLSView BEFORE UPDATE
    WITH (STATE = ON); --go ahead and make it apply
GO



--==========================================================================
--Indexed View

DROP SECURITY POLICY IF EXISTS rowLevelSecurity.Demo_SaleItem_SecurityPolicy
GO

CREATE UNIQUE CLUSTERED INDEX IndexedView ON Demo.SaleItem_RLSView (SaleItemId);

--attempt to add to TABLE will fail
CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) 
			ON Demo.SaleItem
    WITH (STATE = ON); --go ahead and make it apply
GO

--still can add to the view
CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) 
			ON Demo.SaleItem_RLSView
    WITH (STATE = ON); --go ahead and make it apply
GO

--Note: Partitioned Views 
--   Block predicates cannot be defined on partitioned views, and partitioned views cannot be 
--   created on top of tables that use block predicates. Filter predicates are compatible with partitioned views.