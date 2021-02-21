USE TestRowLevelSecurity
GO

--Rights to modify data
GRANT INSERT,UPDATE,DELETE ON Demo.SaleItem TO SmallHat, MedHat,BigHat; 
GO

--user can create data that they cannot then see
EXECUTE AS USER = 'SmallHat'; 
GO 
INSERT INTO Demo.SaleItem (saleItemId, ManagedByUser) 
VALUES (7,'BigHat'); 
GO 
SELECT * FROM Demo.SaleItem; 
GO 
REVERT
GO


--The row does exist
SELECT * FROM Demo.SaleItem WHERE saleItemId = 7 ;


--If the user can't see the row, they cannot change/delete it:
EXECUTE AS USER = 'SmallHat'; 
GO 
UPDATE Demo.SaleItem 
SET    ManagedByUser = 'SmallHat' 
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

--using a BLOCK prediate

CREATE SECURITY POLICY rowLevelSecurity.Demo_SaleItem_SecurityPolicy 
    --block user from inserting row they they cannot see after it is inserted
    ADD BLOCK PREDICATE rowLevelSecurity.ManagedByUser$SecurityPredicate(ManagedByUser) ON Demo.saleItem AFTER INSERT, 

    --block update and delete of data you don't own (even if you can see it since we have removed the FILTER predicate
    ADD BLOCK PREDICATE rowLevelSecurity.ManagedByUser$SecurityPredicate(ManagedByUser) ON Demo.saleItem BEFORE UPDATE, 
    ADD BLOCK PREDICATE rowLevelSecurity.ManagedByUser$SecurityPredicate(ManagedByUser) ON Demo.saleItem BEFORE DELETE 
    WITH (STATE = ON, SCHEMABINDING = ON); 

GO

--cant insert it if you can't see it
EXECUTE AS USER = 'SmallHat'; 
GO 
INSERT INTO Demo.SaleItem (SaleItemId, ManagedByUser) 
VALUES (8,'BigHat'); 
GO

--can see all of the data:

SELECT * FROM Demo.SaleItem;
GO

--But can't make changes:

UPDATE Demo.SaleItem 
SET    ManagedByUser = 'SmallHat' 
WHERE  SaleItemId = 7; 
GO 
DELETE FROM Demo.SaleItem WHERE SaleItemId = 7;

REVERT;



