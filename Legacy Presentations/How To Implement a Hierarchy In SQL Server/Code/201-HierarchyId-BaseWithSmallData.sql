USE HowToOptimizeAHierarchyInSQLServer;
GO

/*
Note: Due to constraints of time, I will not be covering this set of code. However, I felt it important to include
for your and my use for hierarchies that use this method like those in filetable. (And for my performance numbers and 
presentation completeness.) It is identical to the other examples, but is quite slow to execute... 

*/

DROP PROCEDURE IF EXISTS HierarchyId.Company$Reparent;
DROP PROCEDURE IF EXISTS HierarchyId.Company$Insert;
DROP PROCEDURE IF EXISTS HierarchyId.Company$Delete;
DROP PROCEDURE IF EXISTS HierarchyId.Sale$InsertTestData;
DROP TABLE IF EXISTS HierarchyId.Sale;
DROP TABLE IF EXISTS HierarchyId.Company;
DROP SEQUENCE IF EXISTS HierarchyId.CompanyDataGenerator_SEQUENCE;

DROP SCHEMA IF EXISTS HierarchyId;
GO

CREATE SCHEMA HierarchyId;
GO

CREATE TABLE HierarchyId.Company
(
    CompanyOrgNode    Hierarchyid NOT NULL CONSTRAINT AKCompany UNIQUE,
    CompanyId         int         NOT NULL IDENTITY CONSTRAINT PKCompany PRIMARY KEY NONCLUSTERED,
    Name              varchar(20) NOT NULL CONSTRAINT AKCompany_Name UNIQUE,
    OrganizationLevel AS CompanyOrgNode.GetLevel()
);
GO

CREATE CLUSTERED INDEX Org_Breadth_First
ON HierarchyId.Company
(
    OrganizationLevel,
    CompanyOrgNode);
GO

--CREATE UNIQUE INDEX Org_Depth_First 
--ON Organization(BusinessEntityID) ;
--GO
GO

--for sale data
CREATE SEQUENCE HierarchyId.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE HierarchyId.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES HierarchyId.Company(CompanyId)
);
GO

CREATE INDEX XCompanyId
ON HierarchyId.Sale
(
    CompanyId,
    Amount);
GO

--slightly tricky code. Working with the Hierarchy id is not very "relational" and relies on
--the Hierarchy id interface...

CREATE PROCEDURE HierarchyId.Company$Insert
(
    @Name              varchar(20),
    @ParentCompanyName varchar(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    SET XACT_ABORT ON;

    --the last child will be used when generating the next node, 
    --and the parent is used to set the parent in the insert
    --note that nodes are ordered by their keys...
    DECLARE @LastChildofParentOrgNode Hierarchyid,
            @ParentCompanyOrgNode     Hierarchyid;

    IF @ParentCompanyName IS NOT NULL
    BEGIN
        SET @ParentCompanyOrgNode = (   SELECT Company.CompanyOrgNode
                                        FROM   HierarchyId.Company
                                        WHERE  Company.Name = @ParentCompanyName);

        IF @ParentCompanyOrgNode IS NULL
        BEGIN
            THROW 50000, 'Invalid ParentCompanyId passed in', 16;

            RETURN -100;
        END;
    END;

    BEGIN TRANSACTION;

    --get the last child of the parent you passed in if one exists
    SELECT @LastChildofParentOrgNode = MAX(Company.CompanyOrgNode)
    FROM   HierarchyId.Company(UPDLOCK) --compatibile with shared, but blocks
    --other connections trying to get an UPDLOCK 
    WHERE  Company.CompanyOrgNode.GetAncestor(1) = @ParentCompanyOrgNode;

    --GetAncestor parm indicates how far to go down in Hierarchy

    --getDecendant will give you the next node that is greater than 
    --the one passed in.  Since the value was the max in the table, the 
    --getDescendant Method returns the next one
    INSERT HierarchyId.Company(CompanyOrgNode, Name)
    --the coalesce puts the row as a NULL this will be a root node
    --Invalid ParentCompanyId values were tossed out earlier
    --GetDescendant call will always make this node the last child of ParentCompanyOrgNode
    SELECT COALESCE(@ParentCompanyOrgNode.GetDescendant(@LastChildofParentOrgNode, NULL), Hierarchyid::GetRoot()),
           @Name;

    -- http://msdn.microsoft.com/en-us/library/Bb677209(v=sql.110).aspx GetDescendantDoc
    --Returns one child node that is a descendant of the parent.
    --If parent is NULL, returns NULL.
    --If parent is not NULL, and both child1 and child2 are NULL, returns a child of parent.
    --If parent and child1 are not NULL, and child2 is NULL, returns a child of parent greater than child1.
    --If parent and child2 are not NULL and child1 is NULL, returns a child of parent less than child2.
    --If parent, child1, and child2 are not NULL, returns a child of parent greater than child1 and less than child2.
    --If child1 is not NULL and not a child of parent, an exception is raised.
    --If child2 is not NULL and not a child of parent, an exception is raised.
    --If child1 >= child2, an exception is raised.

    COMMIT;
END;
GO

--same as previous usage
CREATE PROCEDURE HierarchyId.Sale$InsertTestData
    @Name     varchar(20),
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO HierarchyId.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR HierarchyId.CompanyDataGenerator_SEQUENCE AS varchar(10)),
           CAST(NEXT VALUE FOR HierarchyId.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   HierarchyId.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO

EXEC HierarchyId.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC HierarchyId.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC HierarchyId.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC HierarchyId.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC HierarchyId.Sale$InsertTestData @Name = 'Nashville Branch';

EXEC HierarchyId.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC HierarchyId.Sale$InsertTestData @Name = 'Knoxville Branch';

EXEC HierarchyId.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC HierarchyId.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC HierarchyId.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC HierarchyId.Sale$InsertTestData @Name = 'Portland Branch';

EXEC HierarchyId.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC HierarchyId.Sale$InsertTestData @Name = 'Camden Branch';

SELECT Company.CompanyOrgNode, Company.CompanyId, Company.Name, Company.OrganizationLevel
FROM   HierarchyId.Company;
GO