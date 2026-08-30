USE HowToOptimizeAHierarchyInSQLServer;
GO

/********************
Simple adjacency list
********************/

DROP PROCEDURE IF EXISTS GraphTree.Company$Reparent;
DROP PROCEDURE IF EXISTS GraphTree.Company$Delete;
DROP PROCEDURE IF EXISTS GraphTree.Company$Insert;
DROP FUNCTION IF EXISTS GraphTree.Company$returnHierarchyHelper;
DROP PROCEDURE IF EXISTS GraphTree.Sale$InsertTestData;
DROP TABLE IF EXISTS GraphTree.Sale;
DROP TABLE IF EXISTS GraphTree.Company;
DROP TABLE IF EXISTS GraphTree.Manages;
DROP SEQUENCE IF EXISTS GraphTree.CompanyDataGenerator_SEQUENCE;

DROP SCHEMA IF EXISTS GraphTree;
GO

CREATE SCHEMA GraphTree;
GO

CREATE TABLE GraphTree.Company
(
    CompanyId       int         IDENTITY(1, 1) CONSTRAINT PKCompany PRIMARY KEY,
    Name            varchar(20) CONSTRAINT AKCompany_Name UNIQUE,
) AS Node;

CREATE TABLE GraphTree.Manages AS EDGE;

--This makes this table now a tree (Note that it does not prevent an invalid tree with a cycle.)
CREATE UNIQUE INDEX XConnectedTo_FromNode ON GraphTree.Manages($To_Id);
GO

--this object is simply used to generate a Company Name to make the demo a bit more textual.
--it would not be used for a "real" build

CREATE SEQUENCE GraphTree.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE GraphTree.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES GraphTree.Company(CompanyId),
	INDEX XCompanyId (CompanyId, Amount)
);
GO

--the sale table is here for when we do aggregations to make the situation more "real".
--note that I just use a sequential number for the Amount. This makes sure that when we do aggregations
--on each type that the value is the exact same.

CREATE PROCEDURE GraphTree.Sale$InsertTestData
    @Name     varchar(20), --Note that all procs use natural keys to make it easier for you to work with manually.
                           --If you are implementing this for a tool to manipulate, use the surrogate keys
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO GraphTree.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR GraphTree.CompanyDataGenerator_SEQUENCE AS varchar(10)),
           CAST(NEXT VALUE FOR GraphTree.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   GraphTree.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO

--the interesting for reuse stuff starts here!

--note that I have omitted error handling for clarity of the demos. The code included is almost always strictly
--limited to the meaty bits

CREATE PROCEDURE GraphTree.Company$Insert
(
    @Name              varchar(20),
    @ParentCompanyName varchar(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    --Sparse error handling for readability, implement error handling if done for real

    INSERT INTO GraphTree.Company(Name)
    SELECT @Name;
	
    IF @ParentCompanyName IS NOT NULL
		INSERT INTO GraphTree.Manages ($From_id, $To_id)
		SELECT (SELECT $NODE_ID FROM GraphTree.Company WHERE Name = @ParentCompanyName),
			   (SELECT $NODE_ID FROM GraphTree.Company WHERE Name = @Name)

END;
GO

--this is the exact same script as I will use for every type, with the only difference being the
--schema is Named for the technique. 

EXEC GraphTree.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC GraphTree.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC GraphTree.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC GraphTree.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';


SELECT *
FROM   GraphTree.Company;
SELECT *
FROM   GraphTree.Manages;

SELECT ParentCompany.Name, ChildCompany.Name AS ManagesCompanyName, 1 AS Level
FROM   GraphTree.Company AS ParentCompany, GraphTree.Manages, GraphTree.Company AS ChildCompany
WHERE  MATCH(ParentCompany-(Manages)->ChildCompany)
  AND  ParentCompany.Name = 'Company HQ';

SELECT ParentCompany.Name, ChildCompany2.Name AS ManagesCompanyName, 2 AS Level
FROM   GraphTree.Company AS ParentCompany, GraphTree.Manages, GraphTree.Company AS ChildCompany,
       GraphTree.Manages AS Manages2, GraphTree.Company AS ChildCompany2
WHERE  MATCH(ParentCompany-(Manages)->ChildCompany-(Manages2)->ChildCompany2)
  AND  ParentCompany.Name = 'Company HQ';

--To make it clearer for doing the math, I only put sale data on root nodes. This is also a very 
--reasonable expectation to have in the real world for many situations. It does not really affect the
--outcome if sale data was appended to the non-root nodes.
EXEC GraphTree.Sale$InsertTestData @Name = 'Nashville Branch';

EXEC GraphTree.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC GraphTree.Sale$InsertTestData @Name = 'Knoxville Branch';

EXEC GraphTree.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC GraphTree.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC GraphTree.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC GraphTree.Sale$InsertTestData @Name = 'Portland Branch';

EXEC GraphTree.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC GraphTree.Sale$InsertTestData @Name = 'Camden Branch';
GO

