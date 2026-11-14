SELECT 'IN SQLCMD Mode, this will keep you from running the entire script'
GO
EXIT
GO
------------------------------------------------------------------

USE TestRowLevelSecurity
GO

--Rights to modify data
GRANT INSERT,UPDATE,DELETE ON Demo.SaleItem TO SmallHat_Role, MedHat_Role, BigHat_Role; 
GO

--user can create data that they cannot then see
EXECUTE AS USER = 'SmallHat'; 
GO 
SELECT * FROM Demo.SaleItem; 
GO
INSERT INTO Demo.SaleItem (SaleItemId, ItemNumber, ManagedByRole,SaleItemType) 
VALUES (7,'00007','BigHat_Role','Big'); 
GO 
SELECT * FROM Demo.SaleItem; 
GO 

--NOTE that this is a possible security hole 
BEGIN TRANSACTION
INSERT INTO Demo.SaleItem (saleItemId, ItemNumber, ManagedByRole,SaleItemType) 
VALUES (7,'00007','BigHat_Role','Big'); 
ROLLBACK TRANSACTION
GO
REVERT
GO


--The row does exist
SELECT * FROM Demo.SaleItem WHERE saleItemId = 7 ;


--If the user can't see the row, they cannot change/delete it:
EXECUTE AS USER = 'SmallHat'; 
GO 
UPDATE Demo.SaleItem 
SET    ManagedByRole = 'SmallHat_Role' 
WHERE  SaleItemId = 7; --Give it back to me!

DELETE Demo.SaleItem 
WHERE  SaleItemId = 7; --or just delete it 
GO 
REVERT; 
GO 
SELECT * 
FROM   Demo.SaleItem 
WHERE  SaleItemId = 7;


DROP SECURITY POLICY IF EXISTS rowLevelSecurity.Demo_SaleItem_SecurityPolicy;
GO
--using a BLOCK prediate

CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
    --block user from inserting row they they cannot see after it is inserted
    ADD BLOCK PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) 
			ON Demo.saleItem AFTER INSERT, 

    --block update and delete of data you don't own (even if you can see it since we have removed the FILTER predicate
    ADD BLOCK PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) 
			ON Demo.saleItem BEFORE UPDATE, 
   
   --this is allowed (and updating only columns in the table that are not referenced by the predicate will mean
   --that the predicate function is not used in the plan.)
   -- ADD BLOCK PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) 
			--ON Demo.saleItem AFTER UPDATE, 
   --NOTE: Before and after are both allowed together
    ADD BLOCK PREDICATE rowLevelSecurity.ManagedByRole$SecurityPredicate(ManagedByRole) 
			ON Demo.saleItem BEFORE DELETE 
    WITH (STATE = ON, SCHEMABINDING = ON); 

GO

--can't insert it if you can't see it
EXECUTE AS USER = 'SmallHat'; 
GO 
 
INSERT INTO Demo.SaleItem (SaleItemId, ItemNumber, ManagedByRole,SaleItemType) 
VALUES (8,'00008','BigHat_Role','Big') 
GO

--in a multi-row operation, neither row is created
INSERT INTO Demo.SaleItem (SaleItemId, ItemNumber, ManagedByRole,SaleItemType) 
VALUES (8,'00008','BigHat_Role','Big'),
		(9,'00009','SmallHat_Role','Small'); 
GO

--can see all of the data:

SELECT * FROM Demo.SaleItem;
GO

--But can't make changes to the ManagedByRole, due to the BEFORE predicate:
SELECT USER_NAME();
UPDATE Demo.SaleItem 
SET    ManagedByRole = 'SmallHat_Role' 
WHERE  SaleItemId = 7; 

--or any other columns
UPDATE Demo.SaleItem
SET    ItemNumber = '11117'
WHERE  SaleItemId = 7;

--but can update the rows that they own
UPDATE Demo.SaleItem
SET    ItemNumber = ItemNumber
WHERE  SaleItem.ManagedByRole = 'SmallHat_Role';


GO 

--still can't update this row they created
DELETE FROM Demo.SaleItem WHERE SaleItemId = 7;
GO

REVERT;



