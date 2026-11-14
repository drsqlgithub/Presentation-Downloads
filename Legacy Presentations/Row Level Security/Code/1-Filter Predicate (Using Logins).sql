SELECT 'IN SQLCMD Mode, this will keep you from running the entire script'
GO
EXIT
GO
------------------------------------------------------------------

-- http://sqlblog.com/blogs/louis_davidson/archive/tags/Row+Level+Security/default.aspx


USE TestRowLevelSecurity
GO

--Some roles that we will be using for the "simple" demo
--Use roles, because roles go in source control as they are the same in DEV/PROD/TEST/QA
DROP ROLE IF EXISTS BigHat_Role; -- sees all
CREATE ROLE BigHat_Role;

DROP ROLE IF EXISTS MedHat_Role; -- sees theirs and small hat
CREATE ROLE MedHat_Role;

DROP ROLE IF EXISTS SmallHat_Role; -- see only own stuff
CREATE ROLE SmallHat_Role;

--we need to be able to show the plan for queries occaionally, not a guaranteed right
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
    SaleItemId    int CONSTRAINT PKSaleItem PRIMARY KEY, 
	ItemNumber    char(5) NOT NULL CONSTRAINT AKSaleItem_ItemNumber UNIQUE,
    ManagedByRole nvarchar(15), --more typically would be sysname, but nvarchar(15) is easier to format for testing 
	SaleItemType  varchar(10)
) 
GRANT SELECT ON Demo.SaleItem TO SmallHat_Role, MedHat_Role, BigHat_Role;
GO


INSERT INTO Demo.SaleItem 
VALUES (1,'00001','BigHat_Role','Big'),(2,'00002','BigHat_Role','Big'),(3,'00003','MedHat_Role','Med')
	  ,(4,'00004','MedHat_Role','Med'),(5,'00005','SmallHat_Role','Small'),(6,'00006','SmallHat_Role','Small'); 
GO 


SELECT *
FROM   Demo.SaleItem;
GO
-------------------------------------------------------------------------------

--We start out by creating a predicate function. It takes as a parameter, 
--a value from a row in the table, that you will configure. Put in own schema that we will not give
--users access to
CREATE SCHEMA rowLevelSecurity;
GO

--The rules:
	--Big Hat Role sees all data
	--Med Hat Role sees rows owned by Med Hat or Small Hat
	--Small Hat sees only owned

--Implement a simple hierarchy using basic system functions
--The following seems natural (but isn't right):

CREATE OR ALTER FUNCTION rowLevelSecurity.ManagedByRole$SecurityPredicate (@ManagedByRole AS sysname)
RETURNS int
AS
  BEGIN
	IF IS_MEMBER(@ManagedByRole) = 1 --Is an actual member of the role past in
		RETURN 1;
	ELSE IF (IS_MEMBER('MedHat_Role') = 1 AND @ManagedByRole = 'SmallHat_Role') -- role smallhat and this user is a member of medhat
		RETURN 1;
	ELSE IF (IS_MEMBER('BigHat_Role') = 1) -- or they are part of the bighat 
		RETURN 1;
	
	RETURN 0;
  END;
GO
GRANT EXECUTE ON rowLevelSecurity.ManagedByRole$SecurityPredicate TO PUBLIC --we revoke later
GO

--Because this is how you expect that row level security would behave
EXECUTE AS USER = 'MedHat'; 
GO 
SELECT *
FROM   Demo.SaleItem
WHERE  rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) = 1
GO
REVERT;
GO


--NOTE: THIS WILL PERFORM GREAT ON VERY VERY SMALL TABLES/VERY SIMPLE FUNCTIONS :)

--The function must be a simple table valued function (simple meaning a single SQL Statement), so complex predicates 
--need to be encoded into some form of single query, likely with a parameter
--for input from a column (note CREATE OR ALTER requires it to be the same type of FUNCTION)
DROP FUNCTION IF EXISTS rowLevelSecurity.ManagedByRole$SecurityPredicate 
GO
CREATE FUNCTION rowLevelSecurity.ManagedByRole$SecurityPredicate (@ManagedByRole AS sysname) 
    RETURNS TABLE --value of 1 means they have access... (really any result does, but 1 is the convention)
WITH SCHEMABINDING --if schemabound, users needn't have rights to the function
AS --must be a simple table valued function
    RETURN (SELECT 1 AS ManagedByRole$SecurityPredicate
			--this will work too:
			--SELECT 'yes' AS ManagedByRole$SecurityPredicate , 'another columns' AS test
            WHERE IS_MEMBER(@ManagedByRole) = 1 --User is a member of the role 
             OR (IS_MEMBER('MedHat_Role') = 1 AND @ManagedByRole = 'SmallHat_Role')  --if the user is MedHat, and the row isn't managed by BigHat 
             OR (IS_MEMBER('BigHat_Role') = 1) --Or the user is the BigHat person, they can see everything
			 --UNION ALL --this function could return > 1 row and it will be fine
			 --SELECT 1
			  ); --Or the user is the BigHat person, they can see everything 
GO

--testing only
GRANT SELECT ON rowLevelSecurity.ManagedByRole$SecurityPredicate TO PUBLIC;               
GO




EXECUTE AS USER = 'smallHat'; 
GO 
SELECT USER_NAME() AS testing,'BigHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('BigHat_Role')
UNION ALL
SELECT USER_NAME() AS testing,'MedHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('MedHat_Role')
UNION ALL
SELECT USER_NAME() AS testing,'SmallHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('SmallHat_Role'); 
GO 
REVERT;


EXECUTE AS USER = 'medHat'; 
GO 
SELECT USER_NAME() AS testing,'BigHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('BigHat_Role')
UNION ALL
SELECT USER_NAME() AS testing,'MedHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('MedHat_Role')
UNION ALL
SELECT USER_NAME() AS testing,'SmallHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('SmallHat_Role'); 
GO
REVERT;


EXECUTE AS USER = 'bigHat'; 
GO 
SELECT USER_NAME() AS testing,'BigHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('BigHat_Role')
UNION ALL
SELECT USER_NAME() AS testing,'MedHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('MedHat_Role')
UNION ALL
SELECT USER_NAME() AS testing,'SmallHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('SmallHat_Role'); 
GO 
REVERT;
GO




REVOKE SELECT ON rowLevelSecurity.ManagedByRole$SecurityPredicate TO PUBLIC; --was for testing only
GO

--show no rights to access function
EXECUTE AS USER = 'bigHat'; 
GO 
SELECT USER_NAME() AS testing,'bigHat' AS input,* FROM rowLevelSecurity.ManagedByRole$SecurityPredicate('BigHat'); 
GO 
REVERT;
GO

--simple, data viewing filter 
CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) 
			ON Demo.SaleItem 
    WITH (STATE = ON); --go ahead and make it apply
GO

EXECUTE AS USER = 'SmallHat'; 
GO 
SELECT USER_NAME(), * FROM Demo.SaleItem; 
GO 
REVERT; 
GO

--TURN ON QUERY PLAN, show the filter in the plan
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

--TURN OFF QUERY PLAN 

--big difference in RLS to core security functionality is: dbo is not immune
SELECT USER_NAME();
SELECT * FROM  Demo.SaleItem;
GO

DROP SECURITY POLICY IF EXISTS rowLevelSecurity.Demo_SaleItem_SecurityPolicy; 
GO 


CREATE OR ALTER FUNCTION rowLevelSecurity.ManagedByRole$SecurityPredicate (@ManagedByRole AS sysname) 
    RETURNS TABLE --value of 1 means they have access... 
WITH SCHEMABINDING --if schemabound, users needn't have rights to the function
AS --must be a simple table valued function
    RETURN (SELECT 1 AS ManagedByRole$SecurityPredicate 
            WHERE IS_MEMBER(@ManagedByRole) = 1 --User is a member of the role 
             OR (IS_MEMBER('MedHat_Role') = 1 AND @ManagedByRole = 'SmallHat_Role')  --if the user is MedHat, and the row isn't managed by BigHat 
             OR (IS_MEMBER('BigHat_Role') = 1) --Or the user is the BigHat person, they can see everything 
			 OR (IS_MEMBER('db_owner') = 1 OR USER_NAME() = 'dbo')) --dbo needs to see all for these demos to work :)!; 
GO

CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
ADD FILTER PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) ON Demo.SaleItem 
WITH (STATE = ON); 
GO

SELECT USER_NAME(), * FROM  Demo.SaleItem;
GO


--Works EVEN using a procedure/view (ownership chaining is very different)
--AND if the user doesn't have direct rights to query the table
REVOKE SELECT ON Demo.SaleItem TO SmallHat_Role, MedHat_Role, BigHat_Role; --take away rights to query data
GO
CREATE PROCEDURE Demo.SaleItem$select 
AS 
    SET NOCOUNT ON;  
    SELECT USER_NAME(); --Show the userName so we can see the context 
	SELECT SaleItemId, ManagedByRole, SaleItemType
	FROM   Demo.SaleItem;
GO 
GRANT EXECUTE ON   Demo.SaleItem$select to SmallHat_Role, MedHat_Role, BigHat_Role; 
GO

EXECUTE AS USER = 'SmallHat'; 
GO 
SELECT * FROM Demo.SaleItem --gives ERROR
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

--if you use EXECUTE AS, the security context can be altered, allowing the user elevated rows
CREATE OR ALTER PROCEDURE Demo.SaleItem$select 
WITH EXECUTE AS 'BigHat' --use a similar user/role, and avoid dbo/owner if possible to avoid security holes. 
AS 
    SET NOCOUNT ON; 
    SELECT USER_NAME() AS UserName,SUSER_SNAME() AS SystemUserName, 
			ORIGINAL_LOGIN() AS PreExecuteAs; 
    SELECT * FROM Demo.SaleItem;
GO

EXECUTE AS USER = 'SmallHat'; 
GO 
SELECT USER_NAME() AS userContext; 
EXEC Demo.SaleItem$select; 
GO 
REVERT;
GO

--Replace SELECT rights
GRANT SELECT ON Demo.SaleItem TO SmallHat_Role, MedHat_Role, BigHat_Role; --take away rights to query data
GO

