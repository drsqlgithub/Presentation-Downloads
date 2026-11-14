SELECT 'IN SQLCMD Mode, this will keep you from running the entire script'
GO
EXIT
GO
------------------------------------------------------------------

-- http://sqlblog.com/blogs/louis_davidson/archive/tags/Row+Level+Security/default.aspx

--create a new database
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'TestRowLevelSecurity_alt')
	ALTER DATABASE TestRowLevelSecurity_alt SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE master
GO
DROP DATABASE IF EXISTS TestRowLevelSecurity_alt
GO
CREATE DATABASE TestRowLevelSecurity_alt
GO
USE TestRowLevelSecurity_alt
GO

--To do this, you MUST set context in every usage
SELECT SESSION_CONTEXT(N'UserRole'); --instead of USER_NAME()/IS_MEMBER() in the FUNCTION above
GO
EXEC sys.sp_set_session_context @key = N'UserRole', @value = 'SmallHat_Role'; 

SELECT SESSION_CONTEXT(N'UserRole'); 
GO
--clear the value
EXEC sys.sp_set_session_context @key = N'UserRole', @value = NULL; 
GO
SELECT SESSION_CONTEXT(N'UserRole'); 
GO


CREATE USER ApplicationUser WITHOUT LOGIN;
GO
GRANT SHOWPLAN TO ApplicationUser;
--The table, will look like the same as before:
GO
CREATE SCHEMA Demo; 
GO 
CREATE TABLE Demo.SaleItem 
( 
    SaleItemId    int CONSTRAINT PKSaleIitem PRIMARY KEY, 
    ManagedByRole nvarchar(15) --more typically would be sysname, but nvarchar(15) is easier to format for testing 
) 
INSERT INTO Demo.SaleItem 
VALUES (1,'BigHat_Role'),(2,'BigHat_Role'),(3,'MedHat_Role'),
		(4,'MedHat_Role'),(5,'SmallHat_Role'),(6,'SmallHat_Role'); 
GO 

--Usually, the application will have all every DML right to at least the schema
GRANT INSERT, UPDATE, DELETE, SELECT ON SCHEMA::Demo TO ApplicationUser;
GO
--We start out by creating a predicate function. It takes as a parameter, a value from a row in the table, that you will configure.
--the change is that we now use SESSION_CONTEXT
CREATE SCHEMA rowLevelSecurity;
GO

CREATE FUNCTION rowLevelSecurity.ManagedByRole$SecurityPredicate (@ManagedByRole AS sysname) 
    RETURNS TABLE --value of 1 means they have access... 
WITH SCHEMABINDING --if schemabound, users needn't have rights to the function
AS --must be a simple table valued function
    RETURN (SELECT 1 AS ManagedByRole$SecurityPredicate 
            WHERE @ManagedByRole = SESSION_CONTEXT(N'UserRole') --If the ManagedByRole = the database username 
               OR (SESSION_CONTEXT(N'UserRole') = 'MedHat_Role' and @ManagedByRole <> 'BigHat_Role') --if the user is MedHat, and the row isn't managed by BigHat 
               OR (SESSION_CONTEXT(N'UserRole') = 'BigHat_Role') --Or the user is the BigHat or dbo person, they can see everything 
			   OR IS_MEMBER('db_owner') = 1 
			   OR USER_NAME() = 'dbo'); 
GO
GRANT SELECT ON rowLevelSecurity.ManagedByRole$SecurityPredicate TO PUBLIC; --testing only               
GO



EXECUTE AS USER = 'ApplicationUser'; 
EXEC sys.sp_set_session_context @key = N'UserRole', @value = 'SmallHat_Role'; 
GO 
SELECT SESSION_CONTEXT(N'UserRole') AS testing,'BigHat_Role' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('BigHat_Role')
UNION ALL
SELECT SESSION_CONTEXT(N'UserRole') AS testing,'MedHat_Role' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('MedHat_Role')
UNION ALL
SELECT SESSION_CONTEXT(N'UserRole') AS testing,'SmallHat_Role' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('SmallHat_Role'); 
GO 


EXEC sys.sp_set_session_context @key = N'UserRole', @value = 'MedHat_Role'; 
GO 
SELECT SESSION_CONTEXT(N'UserRole') AS testing,'BigHat_Role' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('BigHat_Role')
UNION ALL
SELECT SESSION_CONTEXT(N'UserRole') AS testing,'MedHat_Role' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('MedHat_Role')
UNION ALL
SELECT SESSION_CONTEXT(N'UserRole') AS testing,'SmallHat_Role' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('SmallHat_Role'); 
GO 


EXEC sys.sp_set_session_context @key = N'UserRole', @value = 'BigHat_Role'; 
GO 
SELECT SESSION_CONTEXT(N'UserRole') AS testing,'BigHat_Role' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('BigHat_Role')
UNION ALL
SELECT SESSION_CONTEXT(N'UserRole') AS testing,'MedHat_Role' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('MedHat_Role')
UNION ALL
SELECT SESSION_CONTEXT(N'UserRole') AS testing,'SmallHat_Role' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('SmallHat_Role'); 
GO 
REVERT;
GO


REVOKE SELECT ON rowLevelSecurity.ManagedByRole$SecurityPredicate TO PUBLIC; --was for testing only
GO

--show no rights to access function
EXECUTE AS USER = 'ApplicationUser'; 
GO 
SELECT SESSION_CONTEXT(N'UserRole'),'bigHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('BigHat'); 
GO 
REVERT;
GO

--simple, data viewing filter 
CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) ON Demo.SaleItem 
    WITH (STATE = ON); --go ahead and make it apply
GO


--While executing as dbo, we will still see all data regardless of context
EXEC sys.sp_set_session_context @key = N'UserRole', @value = 'SmallHat'; 
GO 
SELECT USER_NAME() AS UserName, SESSION_CONTEXT(N'UserRole') AS Context, * FROM Demo.SaleItem; 
GO 
REVERT; 
GO

--Did i forget that I am dbo...again? The predicate (as written) checks session context, and ignores it for DBO

EXECUTE AS USER = 'ApplicationUser'; 

EXEC sys.sp_set_session_context @key = N'UserRole', @value = 'SmallHat_Role'; 
GO 
SELECT USER_NAME() AS UserName, SESSION_CONTEXT(N'UserRole') AS Context, * FROM Demo.SaleItem; 
GO 


EXEC sys.sp_set_session_context @key = N'UserRole', @value = 'MedHat_Role'; 
GO 
SELECT USER_NAME() AS UserName, SESSION_CONTEXT(N'UserRole') AS Context, * FROM Demo.SaleItem; 
GO 

EXEC sys.sp_set_session_context @key = N'UserRole', @value = 'BigHat_Role'; 
GO 
SELECT USER_NAME() AS UserName, SESSION_CONTEXT(N'UserRole') AS Context, * FROM Demo.SaleItem; 
GO 


REVERT; 


