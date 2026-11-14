USE HowToOptimizeAHierarchyInSQLServer;
GO

/********************
Simple adjacency list
********************/

IF EXISTS (SELECT * FROM sys.procedures WHERE OBJECT_ID = OBJECT_ID('InMemAdjacencyList.Company$Reparent'))
	DROP PROCEDURE InMemAdjacencyList.Company$Reparent
go
IF EXISTS (SELECT * FROM sys.procedures WHERE OBJECT_ID = OBJECT_ID('InMemAdjacencyList.Company$Delete'))
	DROP PROCEDURE InMemAdjacencyList.Company$Delete
go
IF EXISTS (SELECT * FROM sys.procedures WHERE OBJECT_ID = OBJECT_ID('InMemAdjacencyList.Company$Insert'))
	DROP PROCEDURE InMemAdjacencyList.Company$Insert
go
IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID('InMemAdjacencyList.Company$returnHierarchyHelper'))
	DROP FUNCTION InMemAdjacencyList.Company$returnHierarchyHelper
go


IF EXISTS (SELECT * FROM sys.procedures WHERE OBJECT_ID = OBJECT_ID('InMemAdjacencyList.Sale$InsertTestData'))
	DROP PROCEDURE InMemAdjacencyList.Sale$InsertTestData
go
IF EXISTS (SELECT * FROM sys.tables WHERE OBJECT_ID = OBJECT_ID('InMemAdjacencyList.Sale'))
	DROP TABLE InMemAdjacencyList.Sale
go

IF EXISTS (SELECT * FROM sys.tables WHERE OBJECT_ID = OBJECT_ID('InMemAdjacencyList.Company'))
	DROP TABLE InMemAdjacencyList.Company
go

IF EXISTS (SELECT * FROM sys.SEQUENCEs WHERE OBJECT_ID = OBJECT_ID('InMemAdjacencyList.CompanyDataGenerator_SEQUENCE'))
	DROP SEQUENCE InMemAdjacencyList.CompanyDataGenerator_SEQUENCE
go
IF EXISTS (SELECT * FROM sys.schemas WHERE SCHEMA_ID = schema_ID('InMemAdjacencyList'))
	DROP SCHEMA InMemAdjacencyList
go


CREATE SCHEMA InMemAdjacencyList
go
CREATE TABLE InMemAdjacencyList.Company
(
    CompanyId   int identity (1,1) ,
    Name        varchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL, --CONSTRAINT AKCompany_Name UNIQUE,
    ParentCompanyId int NOT NULL
      --CONSTRAINT FKCompany$isParentOf$InMemAdjacencyListCompany REFERENCES InMemAdjacencyList.Company(CompanyId),
	  INDEX ParentCompanyId NONCLUSTERED -- HASH 
	(
		ParentCompanyId
	) --WITH ( BUCKET_COUNT = 500000),
	,CONSTRAINT XPKCompany PRIMARY KEY NONCLUSTERED HASH 
	(
	    CompanyId
	)	WITH ( BUCKET_COUNT = 500000),
	INDEX Name HASH 
	(
	    Name
	)	WITH ( BUCKET_COUNT = 500000)
)WITH ( MEMORY_OPTIMIZED = ON , DURABILITY = SCHEMA_AND_DATA )

GO

--this object is simply used to generate a Company Name to make the demo a bit more textual.
--it would not be used for a "real" build
CREATE SEQUENCE InMemAdjacencyList.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1
GO
CREATE TABLE InMemAdjacencyList.Sale
(
	SalesId	int NOT NULL IDENTITY (1,1) CONSTRAINT PKSale PRIMARY KEY,
	TransactionNumber varchar(10) NOT NULL CONSTRAINT AKSale UNIQUE,
	Amount numeric(12,2) NOT NULL,
	CompanyId int NOT NULL -- REFERENCES InMemAdjacencyList.Company (CompanyId)
)
go
CREATE INDEX XCompanyId ON InMemAdjacencyList.Sale(CompanyId, Amount)
go

--the sale table is here for when we do aggregations to make the situation more "real".
--note that I just use a sequential number for the Amount. This makes sure that when we do aggregations
--on each type that the value is the exact same.
CREATE PROCEDURE InMemAdjacencyList.Sale$InsertTestData
@Name varchar(20), --Note that all procs use natural keys to make it easier for you to work with manually.
                   --If you are implementing this for a tool to manipulate, use the surrogate keys
@RowCount    int = 5
AS 
	SET NOCOUNT ON 
	WHILE @RowCount > 0
	  BEGIN
		INSERT INTO InMemAdjacencyList.Sale (TransactionNumber, Amount, CompanyId)
		SELECT	CAST (NEXT VALUE FOR InMemAdjacencyList.CompanyDataGenerator_SEQUENCE AS varchar(10)),
				CAST (NEXT VALUE FOR InMemAdjacencyList.CompanyDataGenerator_SEQUENCE AS numeric(12,2)), 
				(SELECT CompanyId FROM InMemAdjacencyList.Company WHERE Name = @Name)
		SET @rowCount = @rowCOunt - 1
	  END
GO


--the interesting for reuse stuff starts here!

--note that I have omitted error handling for clarity of the demos. THe code included is almost always strictly
--limited to the meaty bits

CREATE PROCEDURE InMemAdjacencyList.Company$Insert(@Name varchar(20), @ParentCompanyName  varchar(20)) 
as
BEGIN
	SET NOCOUNT ON 
	--Sparse error handling for readability, implement error handling if done for real

	declare @ParentCompanyId int = (select CompanyId as ParentCompanyId
								   from   InMemAdjacencyList.Company
								   where  Company.Name = @ParentCompanyName)

	if @ParentCompanyName is not null and @ParentCompanyId IS null
		throw 50000, 'Invalid parentCompanyName',1
	else
		--insert done by simply using the Name of the parent to get the key of 
		--the parent...
		INSERT INTO InMemAdjacencyList.Company (Name, ParentCompanyId)
		SELECT @Name, COALESCE(@ParentCompanyId, -1)
END
GO

--this is the exact same script as I will use for every type, with the only difference being the
--schema is Named for the technique. 

EXEC InMemAdjacencyList.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;
EXEC InMemAdjacencyList.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';
EXEC InMemAdjacencyList.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';
EXEC InMemAdjacencyList.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';

--To make it clearer for doing the math, I only put sale data on root nodes. This is also a very 
--reasonable expectation to have in the real world for many situations. It does not really affect the
--outcome if sale data was appended to the non-root nodes.
EXEC InMemAdjacencyList.Sale$InsertTestData @Name = 'Nashville Branch';
EXEC InMemAdjacencyList.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';
EXEC InMemAdjacencyList.Sale$InsertTestData @Name = 'Knoxville Branch';
EXEC InMemAdjacencyList.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';
EXEC InMemAdjacencyList.Sale$InsertTestData @Name = 'Memphis Branch';
EXEC InMemAdjacencyList.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';
EXEC InMemAdjacencyList.Sale$InsertTestData @Name = 'Portland Branch';
EXEC InMemAdjacencyList.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';
EXEC InMemAdjacencyList.Sale$InsertTestData @Name = 'Camden Branch';

GO
SELECT *
FROM    InMemAdjacencyList.Company
GO
SELECT *
FROM    InMemAdjacencyList.Sale
GO
