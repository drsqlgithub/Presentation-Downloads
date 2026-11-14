USE HowToOptimizeAHierarchyInSQLServer;
GO

/********************
Simple adjacency list
********************/

DROP PROCEDURE IF EXISTS AdjacencyList.Company$Reparent;
DROP PROCEDURE IF EXISTS AdjacencyList.Company$Delete;
DROP PROCEDURE IF EXISTS AdjacencyList.Company$Insert;
DROP FUNCTION IF EXISTS AdjacencyList.Company$returnHierarchyHelper;
DROP PROCEDURE IF EXISTS AdjacencyList.Sale$InsertTestData;
DROP TABLE IF EXISTS AdjacencyList.Sale;
DROP TABLE IF EXISTS AdjacencyList.Company;
DROP SEQUENCE IF EXISTS AdjacencyList.CompanyDataGenerator_SEQUENCE;

DROP SCHEMA IF EXISTS AdjacencyList;
GO

CREATE SCHEMA AdjacencyList;
GO

CREATE TABLE AdjacencyList.Company
(
    CompanyId       int         IDENTITY(1, 1) CONSTRAINT PKCompany PRIMARY KEY,
    Name            varchar(20) NOT NULL CONSTRAINT AKCompany_Name UNIQUE,
    ParentCompanyId int         NULL 
	CONSTRAINT FKCompany$isParentOf$AdjacencyListCompany 
									REFERENCES AdjacencyList.Company( CompanyId),
     --used when fetching rows by their parentCompanyId
	INDEX XCorporate_Company_ParentCompanyId (ParentCompanyId)
);


--this object is simply used to generate a Company Name to make the demo a bit more textual.
--it would not be used for a "real" build

CREATE SEQUENCE AdjacencyList.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE AdjacencyList.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES AdjacencyList.Company(CompanyId),
	INDEX XCompanyId (CompanyId, Amount)
);
GO

--the sale table is here for when we do aggregations to make the situation more "real".
--note that I just use a sequential number for the Amount. This makes sure that when we do aggregations
--on each type that the value is the exact same.

CREATE PROCEDURE AdjacencyList.Sale$InsertTestData
    @Name     varchar(20), --Note that all procs use natural keys to make it easier for you to work with manually.
                           --If you are implementing this for a tool to manipulate, use the surrogate keys
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO AdjacencyList.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR AdjacencyList.CompanyDataGenerator_SEQUENCE AS varchar(10)),
           CAST(NEXT VALUE FOR AdjacencyList.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   AdjacencyList.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO

--the interesting for reuse stuff starts here!

--note that I have omitted error handling for clarity of the demos. The code included is almost always strictly
--limited to the meaty bits

CREATE PROCEDURE AdjacencyList.Company$Insert
(
    @Name              varchar(20),
    @ParentCompanyName varchar(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    --Sparse error handling for readability, implement error handling if done for real

    DECLARE @ParentCompanyId int = (   SELECT Company.CompanyId AS ParentCompanyId
                                       FROM   AdjacencyList.Company
                                       WHERE  Company.Name = @ParentCompanyName);

    IF @ParentCompanyName IS NOT NULL
        AND @ParentCompanyId IS NULL
        THROW 50000, 'Invalid parentCompanyName', 1;
    ELSE
        --insert done by simply using the Name of the parent to get the key of 
        --the parent...
        INSERT INTO AdjacencyList.Company(Name, ParentCompanyId)
        SELECT @Name, @ParentCompanyId;
END;
GO

--this is the exact same script as I will use for every type, with the only difference being the
--schema is Named for the technique. 

EXEC AdjacencyList.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC AdjacencyList.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC AdjacencyList.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC AdjacencyList.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';

SELECT * FROM AdjacencyList.Company;

--To make it clearer for doing the math, I only put sale data on root nodes. This is also a very 
--reasonable expectation to have in the real world for many situations. It does not really affect the
--outcome if sale data was appended to the non-root nodes.
EXEC AdjacencyList.Sale$InsertTestData @Name = 'Nashville Branch';


EXEC AdjacencyList.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC AdjacencyList.Sale$InsertTestData @Name = 'Knoxville Branch';

SELECT * FROM AdjacencyList.Sale;

EXEC AdjacencyList.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC AdjacencyList.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC AdjacencyList.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC AdjacencyList.Sale$InsertTestData @Name = 'Portland Branch';

EXEC AdjacencyList.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC AdjacencyList.Sale$InsertTestData @Name = 'Camden Branch';
GO

SELECT Company.CompanyId, Company.Name, Company.ParentCompanyId
FROM   AdjacencyList.Company;
GO

SELECT Sale.SalesId, Sale.TransactionNumber, Sale.Amount, Sale.CompanyId
FROM   AdjacencyList.Sale;
GO