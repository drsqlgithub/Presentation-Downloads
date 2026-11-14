USE HowToOptimizeAHierarchyInSQLServer;
GO

/********************
Path method
********************/
DROP PROCEDURE IF EXISTS NestedSets.Company$Reparent;
DROP PROCEDURE IF EXISTS NestedSets.Company$Insert;
DROP PROCEDURE IF EXISTS NestedSets.Company$delete;
DROP PROCEDURE IF EXISTS NestedSets.Sale$InsertTestData;
DROP TABLE IF EXISTS NestedSets.Sale;
DROP TABLE IF EXISTS NestedSets.Company;
DROP SEQUENCE IF EXISTS NestedSets.CompanyDataGenerator_SEQUENCE;
DROP SEQUENCE IF EXISTS NestedSets.Company_SEQUENCE;

DROP SCHEMA IF EXISTS NestedSets;
GO

CREATE SCHEMA NestedSets;
GO

CREATE TABLE NestedSets.Company
(
    CompanyId      int         IDENTITY CONSTRAINT PKCompany PRIMARY KEY,
    Name           varchar(20) CONSTRAINT AKCompany_Name UNIQUE,
    HierarchyLeft  int,
    HierarchyRight int,
    CONSTRAINT AKCompany_HierarchyLeft__HierarchyRight UNIQUE
    (
        HierarchyLeft,
        HierarchyRight)
);
GO

--create unique index HierarchyRight__HierarchyLeft on NestedSets.Company (HierarchyRight, HierarchyLeft)
--go

CREATE SEQUENCE NestedSets.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE NestedSets.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES NestedSets.Company(CompanyId)
);
GO

CREATE INDEX XCompanyId
ON NestedSets.Sale
(
    CompanyId,
    Amount);
GO

CREATE PROCEDURE NestedSets.Company$Insert
(
    @Name              varchar(20),
    @ParentCompanyName varchar(20)
)
AS
BEGIN
    --note, enhancement ideas I have seen include leaving gaps to make inserts cheaper, but 
    --this would be far more complex, and certainly make the demo unwieldy. The inserts are 
    --slow compared to all other methods, but not impossibly so...
    SET NOCOUNT ON;

    BEGIN TRANSACTION;

    IF @ParentCompanyName IS NULL
    BEGIN
        IF EXISTS (   SELECT *
                      FROM   NestedSets.Company)
            THROW 50000, 'More than one root node is not supported in this code', 1;
        ELSE
            INSERT INTO NestedSets.Company(Name, HierarchyLeft, HierarchyRight)
            VALUES(@Name, 1, 2);
    END;
    ELSE
    BEGIN
        IF NOT EXISTS (   SELECT *
                          FROM   NestedSets.Company)
            THROW 50000, 'You must start with a root node', 1;

        --find the place in the Hierarchy where you will add a node
        DECLARE @ParentRight int = (   SELECT Company.HierarchyRight
                                       FROM   NestedSets.Company
                                       WHERE  Company.Name = @ParentCompanyName);

        --make room for the new nodes.  
        UPDATE NestedSets.Company
        SET    Company.HierarchyRight = Company.HierarchyRight + 2, --for the parent node and all things right, add 2 to the hierachy right

                                                                    --for all nodes right of the parent (not incl the parent), add 2
               Company.HierarchyLeft = Company.HierarchyLeft + CASE WHEN Company.HierarchyLeft > @ParentRight
                                                                        THEN 2
                                                                    ELSE 0
                                                               END
        WHERE  Company.HierarchyRight >= @ParentRight;

        --insert the node
        INSERT NestedSets.Company(Name, HierarchyLeft, HierarchyRight)
        SELECT @Name, @ParentRight, @ParentRight + 1;
    END;

    COMMIT TRANSACTION;
END;
GO

CREATE PROCEDURE NestedSets.Sale$InsertTestData
    @Name     varchar(20),
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO NestedSets.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR NestedSets.CompanyDataGenerator_SEQUENCE AS varchar(10)),
           CAST(NEXT VALUE FOR NestedSets.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   NestedSets.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO

EXEC NestedSets.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC NestedSets.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC NestedSets.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC NestedSets.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC NestedSets.Sale$InsertTestData @Name = 'Nashville Branch';

EXEC NestedSets.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC NestedSets.Sale$InsertTestData @Name = 'Knoxville Branch';

EXEC NestedSets.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC NestedSets.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC NestedSets.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC NestedSets.Sale$InsertTestData @Name = 'Portland Branch';

EXEC NestedSets.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC NestedSets.Sale$InsertTestData @Name = 'Camden Branch';
GO

GO

SELECT   Company.CompanyId, Company.Name, Company.HierarchyLeft, Company.HierarchyRight
FROM     NestedSets.Company
ORDER BY Company.HierarchyLeft;
