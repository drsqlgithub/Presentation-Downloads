-- http://sqlblog.com/blogs/louis_davidson/archive/tags/Row+Level+Security/default.aspx

ALTER DATABASE TestRowLevelSecurity SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE master
GO
DROP DATABASE TestRowLevelSecurity
GO
CREATE DATABASE TestRowLevelSecurity
GO
USE TestRowLevelSecurity
GO

--Scenario, you have the following two users:
DROP USER IF EXISTS BigHat; --DROP IF EXISTS works with users as well as objects: 
CREATE USER BigHat WITHOUT LOGIN; 

DROP USER IF EXISTS MedHat --MediumHat, which we want to get all of SmallHat's rights, but not BigHats 
CREATE USER MedHat WITHOUT LOGIN;

DROP USER IF EXISTS SmallHat -- gets a minimal amount of security 
CREATE USER SmallHat WITHOUT LOGIN;
GO

--And the dbo user, whoud generally can see anything

--The table, will look like this:

CREATE SCHEMA Demo; 
GO 
CREATE TABLE Demo.SaleItem 
( 
    SaleItemId    int CONSTRAINT PKSaleIitem PRIMARY KEY, 
    ManagedByUser nvarchar(15) --more typically would be sysname, but nvarchar(15) is easier to format for testing 
) 
INSERT INTO Demo.SaleItem 
VALUES (1,'BigHat'),(2,'BigHat'),(3,'MedHat'),(4,'MedHat'),(5,'SmallHat'),(6,'SmallHat'); 
GO 
GRANT SELECT ON Demo.SaleItem TO SmallHat, MedHat, BigHat;

--We start out by creating a predicate function. It takes as a parameter, a value from a row in the table, that you will configure.

CREATE SCHEMA rowLevelSecurity;
GO

CREATE FUNCTION rowLevelSecurity.ManagedByUser$SecurityPredicate (@ManagedByUser AS sysname) 
    RETURNS TABLE --value of 1 means they have access... 
WITH SCHEMABINDING --if schemabound, users needn't have rights to the function
AS --must be a simple table valued function
    RETURN (SELECT 1 AS ManagedByUser$SecurityPredicate 
            WHERE @ManagedByUser = USER_NAME() --If the ManagedByUser = the database username 
               OR (USER_NAME() = 'MedHat' and @ManagedByUser <> 'BigHat') --if the user is MedHat, and the row isn't managed by BigHat 
               OR (USER_NAME() = 'BigHat')); --Or the user is the BigHat person, they can see everything 
GO
GRANT SELECT ON rowLevelSecurity.ManagedByUser$SecurityPredicate TO PUBLIC; --testing only               
GO




EXECUTE AS USER = 'smallHat'; 
GO 
SELECT USER_NAME() AS testing,'BigHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('BigHat')
UNION ALL
SELECT USER_NAME() AS testing,'MedHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('MedHat')
UNION ALL
SELECT USER_NAME() AS testing,'SmallHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('SmallHat'); 
GO 
REVERT;


EXECUTE AS USER = 'medHat'; 
GO 
SELECT USER_NAME() AS testing,'BigHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('BigHat')
UNION ALL
SELECT USER_NAME() AS testing,'MedHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('MedHat')
UNION ALL
SELECT USER_NAME() AS testing,'SmallHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('SmallHat'); 
GO 
REVERT;


EXECUTE AS USER = 'bigHat'; 
GO 
SELECT USER_NAME() AS testing,'BigHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('BigHat')
UNION ALL
SELECT USER_NAME() AS testing,'MedHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('MedHat')
UNION ALL
SELECT USER_NAME() AS testing,'SmallHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('SmallHat'); 
GO 
REVERT;
GO

REVOKE SELECT ON rowLevelSecurity.ManagedByUser$SecurityPredicate TO PUBLIC; --was for testing only
GO

--show no rights to access function
EXECUTE AS USER = 'bigHat'; 
GO 
SELECT USER_NAME() AS testing,'bigHat' AS input,* FROM rowLevelSecurity.ManagedByUser$SecurityPredicate('BigHat'); 
GO 
REVERT;
GO

--simple, data viewing filter 
CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.ManagedByUser$SecurityPredicate(ManagedByUser) ON Demo.SaleItem 
    WITH (STATE = ON); --go ahead and make it apply
GO

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

SELECT USER_NAME();
SELECT * FROM  Demo.SaleItem;
GO

DROP SECURITY POLICY IF EXISTS rowLevelSecurity.Demo_SaleItem_SecurityPolicy; 
GO 

--this change in 2016 SP1 is almost stand up and cheerable CREATE OR ALTER
CREATE OR ALTER FUNCTION rowLevelSecurity.ManagedByUser$SecurityPredicate (@ManagedByUser AS sysname) 
    RETURNS TABLE 
WITH SCHEMABINDING 
AS 
    RETURN (SELECT 1 AS ManagedByUser$SecurityPredicate 
            WHERE @ManagedByUser = USER_NAME() 
               OR (USER_NAME() = 'MedHat' and @ManagedByUser <> 'BigHat') 
               OR (USER_NAME() IN ('BigHat','dbo'))); --give 'dbo' full rights 
GO 

CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
ADD FILTER PREDICATE rowLevelSecurity.ManagedByUser$SecurityPredicate(ManagedByUser) ON Demo.SaleItem 
WITH (STATE = ON); 
GO

SELECT USER_NAME(), * FROM  Demo.SaleItem;
GO


--Works EVEN using a procedure/view

CREATE PROCEDURE Demo.SaleItem$select 
AS 
    SET NOCOUNT ON;  
    SELECT USER_NAME(); --Show the userName so we can see the context 
    SELECT * FROM  Demo.SaleItem; 
GO 
GRANT EXECUTE ON   Demo.SaleItem$select to SmallHat, MedHat, BigHat; 
GO

EXECUTE AS USER = 'SmallHat'; 
GO 
EXEC Demo.SaleItem$select; 
GO 
REVERT;
GO

EXECUTE AS USER = 'MedHat'; 
GO 
EXEC Demo.SaleItem$select; 
GO 
REVERT;

GO


CREATE OR ALTER PROCEDURE Demo.SaleItem$select 
WITH EXECUTE AS 'BigHat' --use a similar user/role, and avoid dbo/owner if possible to avoid security holes. 
AS 
    SET NOCOUNT ON; 
    SELECT USER_NAME(),ORIGINAL_LOGIN(); 
    SELECT * FROM Demo.SaleItem;
GO

EXECUTE AS USER = 'SmallHat'; 
GO 
SELECT USER_NAME() AS userContext; 
EXEC Demo.SaleItem$select; 
GO 
REVERT;
GO


/* NOTE:  If you use a single login for an app, you can use the following new functions to set a context for the connection to 
           identify the user. */

EXEC sys.sp_set_session_context @key = N'UserName', @value = 'SmallHat'; 

SELECT SESSION_CONTEXT(N'UserName'); --instead of USER_NAME() in the FUNCTION above

*/