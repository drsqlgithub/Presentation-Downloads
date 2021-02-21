SELECT 'IN SQLCMD Mode, this will keep you from running the entire script'
GO
EXIT
GO
------------------------------------------------------------------

-- http://sqlblog.com/blogs/louis_davidson/archive/tags/Row+Level+Security/default.aspx

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'TestRowLevelSecurity_Legacy')
	ALTER DATABASE TestRowLevelSecurity_Legacy SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE master
GO
DROP DATABASE IF EXISTS TestRowLevelSecurity_Legacy
GO
CREATE DATABASE TestRowLevelSecurity_Legacy
GO
USE TestRowLevelSecurity_Legacy
GO


DROP ROLE IF EXISTS BigHat_Role;
CREATE ROLE BigHat_Role;

DROP ROLE IF EXISTS MedHat_Role;
CREATE ROLE MedHat_Role;

DROP ROLE IF EXISTS SmallHat_Role;
CREATE ROLE SmallHat_Role;

GRANT SHOWPLAN TO SmallHat_Role,MedHat_Role, BigHat_Role;
GO

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




--=================================
--Legacy Method 1 - Just let the dang application code handle things
--=================================

--Want to see the data, append the code needed:
USE TestRowLevelSecurity_Legacy
GO

--app context small hat
SELECT *
FROM    Demo.SaleItem
--app tacks on this:
WHERE   ManagedByRole = 'SmallHat_Role';

--app context med hat
SELECT *
FROM    Demo.SaleItem
--app tacks on this:
WHERE   ManagedByRole IN ('MedHat_Role','SmallHat_Role'); --this is VERY NOT SCALABLE coding-wise


--but we can steal the predicate code and make it "better"

CREATE SCHEMA rowLevelSecurity;
GO
--this does not include dbo out, since this is for the application to self manage
--the contextUser parameter is to demonstrate that this method has LOTS of flexibility
--to code in different ways. The downside is that the code has to be consistentently
--added to statements, rather than being part of a central object

CREATE FUNCTION rowLevelSecurity.ManagedByRole$SecurityPredicate_App (@ContextUser AS sysname,
																		 @ManagedByRole AS sysname) 
    RETURNS TABLE --value of 1 means they have access... 
WITH SCHEMABINDING --if schemabound, users needn't have rights to the function
AS --must be a simple table valued function
    RETURN (SELECT 1 AS ManagedByRole$SecurityPredicate 
            WHERE @ManagedByRole = @ContextUser --If the ManagedByRole = the database username 
               OR (@ContextUser = 'MedHat_Role' and @ManagedByRole <> 'BigHat_Role') --if the user is MedHat, and the row isn't managed by BigHat 
               OR (@ContextUser = 'BigHat_Role')); --Or the user is the BigHat person, they can see everything 
GO


SELECT SaleItem.*
FROM    Demo.SaleItem
		 --requires only a SINGLE row returned from predicate function
		 CROSS APPLY rowLevelSecurity.ManagedByRole$SecurityPredicate_App('SmallHat_Role', SaleItem.ManagedByRole)

--analgous to how it is built in RLS			
SELECT *
FROM    Demo.SaleItem
WHERE   EXISTS (SELECT * --allows > 1 rows to be output
				FROM rowLevelSecurity.ManagedByRole$SecurityPredicate_App('MedHat_Role', SaleItem.ManagedByRole))

SELECT *
FROM    Demo.SaleItem
		 CROSS APPLY rowLevelSecurity.ManagedByRole$SecurityPredicate_App('BigHat_Role', SaleItem.ManagedByRole)

--This way of coding will work nicely in stored procedures, etc. It is just tedious and you have to remember to 
--put the references "every where!"

--Show examples in our extended table structures using WideWorldImporter data


--===============================================================
-- View
--===============================================================

--The classic solution is to use a view. This will look exactly like the row-level security version, as long
--as you use the view only;

--Note that you can still do this with row level security feature, as well.

--same as original, using user context. All other methods are available.
CREATE OR ALTER FUNCTION rowLevelSecurity.ManagedByRole$SecurityPredicate_View (@ManagedByRole AS sysname) 
    RETURNS TABLE --value of 1 means they have access... 
WITH SCHEMABINDING --if schemabound, users needn't have rights to the function
AS --must be a simple table valued function
    RETURN (SELECT 1 AS ManagedByRole$SecurityPredicate 
            WHERE IS_MEMBER(@ManagedByRole) = 1 --User is a member of the role 
             OR (IS_MEMBER('MedHat_Role') = 1 AND @ManagedByRole = 'SmallHat_Role')  --if the user is MedHat, and the row isn't managed by BigHat 
             OR (IS_MEMBER('BigHat_Role') = 1) --Or the user is the BigHat person, they can see everything 
			 OR (IS_MEMBER('db_owner') = 1 OR USER_NAME() = 'dbo')) --dbo needs to see all for these demos to work :)!; 
GO


CREATE OR ALTER VIEW Demo.SaleItem_Interface
WITH SCHEMABINDING
AS
SELECT SaleItem.SaleItemId, SaleItem.ManagedByRole, SaleItem.SaleItemType
FROM   Demo.SaleItem
		 CROSS APPLY rowLevelSecurity.ManagedByRole$SecurityPredicate_View(SaleItem.ManagedByRole);
GO

REVOKE SELECT ON Demo.SaleItem TO SmallHat_Role, MedHat_Role, BigHat_Role;
GO
GRANT SELECT,INSERT,UPDATE,DELETE ON Demo.SaleItem_Interface TO SmallHat_Role, MedHat_Role, BigHat_Role;
GO

EXECUTE AS USER = 'SmallHat'; 
GO 
SELECT USER_NAME(), * FROM Demo.SaleItem_Interface; 
GO 
REVERT; 
GO

EXECUTE AS USER = 'MedHat'; 
GO 
SELECT USER_NAME(),* FROM Demo.SaleItem_Interface; 
GO 
REVERT; 

EXECUTE AS USER = 'BigHat'; 
GO 
SELECT USER_NAME(),* FROM Demo.SaleItem_Interface; 
GO 
REVERT; 
GO


--user can create data that they cannot then see
EXECUTE AS USER = 'SmallHat'; 
GO 
INSERT INTO Demo.SaleItem_Interface (saleItemId, ManagedByRole,SaleItemType) 
VALUES (7,'BigHat','Big'); 
GO 
SELECT * FROM Demo.SaleItem_Interface; 
GO 
REVERT
GO
SELECT * FROM Demo.SaleItem; 
GO 


--If the user can't see the row, they cannot change/delete it:
EXECUTE AS USER = 'SmallHat'; 
GO 
UPDATE Demo.SaleItem_Interface
SET    ManagedByRole = 'SmallHat' 
WHERE  SaleItemId = 7; --Give it back to me!

DELETE Demo.SaleItem_Interface 
WHERE  SaleItemId = 7; --or just delete it 
GO 
REVERT; 
GO 

--still exists
SELECT * 
FROM   Demo.SaleItem 
WHERE  SaleItemId = 7;


--With check option says that you can't create data that you can see after 
--it has been inserted
CREATE OR ALTER VIEW Demo.SaleItem_Interface
WITH SCHEMABINDING
AS
SELECT SaleItemId, ManagedByRole
FROM   Demo.SaleItem
		 CROSS APPLY rowLevelSecurity.ManagedByRole$SecurityPredicate_View(SaleItem.ManagedByRole)
WITH CHECK OPTION;
GO

--cant insert it if you can't see it
EXECUTE AS USER = 'SmallHat'; 
GO 
INSERT INTO Demo.SaleItem_Interface (SaleItemId, ManagedByRole) 
VALUES (8,'BigHat'); 
GO
REVERT;
GO



--Works in a stored procedure
CREATE PROCEDURE Demo.SaleItem$List
AS
	SELECT *
	FROM   Demo.SaleItem_Interface
GO
GRANT EXECUTE ON Demo.[SaleItem$List] TO SmallHat
GO

EXECUTE AS USER = 'SmallHat'; 
GO 
EXECUTE Demo.SaleItem$List
GO
REVERT;
GO

--HOWEVER... If you aren't careful, and forget to use the view....:

CREATE OR ALTER PROCEDURE Demo.SaleItem$List
AS
	SELECT *
	FROM   Demo.SaleItem
GO
GRANT EXECUTE ON Demo.SaleItem$List TO SmallHat
GO

EXECUTE AS USER = 'SmallHat'; 
GO 
EXECUTE Demo.SaleItem$List
GO
REVERT;
GO
