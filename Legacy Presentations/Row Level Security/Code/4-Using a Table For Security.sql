SELECT 'IN SQLCMD Mode, this will keep you from running the entire script'
GO
EXIT
GO
------------------------------------------------------------------

USE TestRowLevelSecurity
GO
SELECT *
FROM   Demo.SaleItem
GO
CREATE TABLE RowLevelSecurity.SaleItemTypeSecurity
(
   VisibleByRole nvarchar(15), --more typically would be sysname, but nvarchar(15) is easier to format for testing 
   SaleItemType  VARCHAR(10),
   CONSTRAINT PKSaleItemTypeSecurity PRIMARY KEY (SaleItemType, VisibleByRole)
)
GO

--Different config than original, strictly for demo sake. Big sees big, med med, etc
INSERT INTO rowLevelSecurity.SaleItemTypeSecurity (VisibleByRole,SaleItemType)
VALUES ('BigHat_Role','Big'),('MedHat_Role','Med'),('SmallHat_Role','Small');
GO

DROP SECURITY POLICY IF EXISTS rowLevelSecurity.Demo_SaleItem_SecurityPolicy;
GO

CREATE OR ALTER FUNCTION rowLevelSecurity.ManagedByRole$SecurityPredicate (@SaleItemType AS varchar(10)) 
    RETURNS TABLE --value of 1 means they have access... 
WITH SCHEMABINDING --if schemabound, users needn't have rights to the function
AS --must be a simple table valued function
    RETURN (SELECT 1 AS ManagedByRole$SecurityPredicate 
			WHERE  USER_NAME() = 'dbo'
				OR   IS_MEMBER('db_owner') = 1
				OR   EXISTS(SELECT 1
							FROM   RowLevelSecurity.SaleItemTypeSecurity
							WHERE  SaleItemType = @SaleItemType
							 AND  IS_MEMBER(VisibleByRole) = 1));
GO

CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
ADD FILTER PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(SaleItemType) ON Demo.SaleItem 
WITH (STATE = ON); 
GO

--show all data
SELECT * FROM Demo.SaleItem; 
SELECT * FROM RowLevelSecurity.SaleItemTypeSecurity


EXECUTE AS USER = 'SmallHat'; 
GO 
SELECT USER_NAME(), * FROM Demo.SaleItem; 
GO 
REVERT; 
GO


--Turn ON QUERY PLAN
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

--give medhat small hat too
INSERT INTO rowLevelSecurity.SaleItemTypeSecurity
VALUES ('MedHat_Role','Small');

EXECUTE AS USER = 'MedHat'; 
GO 
SELECT USER_NAME(),* FROM Demo.SaleItem; 
GO 
REVERT; 
GO

--just sees big!
EXECUTE AS USER = 'BigHat'; 
GO 
SELECT USER_NAME(),* FROM Demo.SaleItem; 
GO 
REVERT; 
GO

INSERT INTO rowLevelSecurity.SaleItemTypeSecurity
VALUES ('BigHat_Role','Small'),('BigHat_Role','Med');
GO

--now sees all!
EXECUTE AS USER = 'BigHat'; 
GO 
SELECT USER_NAME(),* FROM Demo.SaleItem; 
GO 
REVERT; 
GO