USE HowToOptimizeAHierarchyInSQLServer;
GO

/********************
Path method
********************/
DROP PROCEDURE IF EXISTS PathMethod.Company$Reparent;
DROP PROCEDURE IF EXISTS PathMethod.Company$Insert;
DROP PROCEDURE IF EXISTS PathMethod.Company$delete;
DROP PROCEDURE IF EXISTS PathMethod.Sale$InsertTestData;
DROP TABLE IF EXISTS PathMethod.Sale;
DROP TABLE IF EXISTS PathMethod.Company;
DROP SEQUENCE IF EXISTS PathMethod.CompanyDataGenerator_SEQUENCE;
DROP SEQUENCE IF EXISTS PathMethod.Company_SEQUENCE;

DROP SCHEMA IF EXISTS PathMethod;
GO

CREATE SCHEMA PathMethod;
GO

--use for surrogate creation to make the insert eaasier...
CREATE SEQUENCE PathMethod.Company_SEQUENCE AS int START WITH 1;
GO

CREATE TABLE PathMethod.Company
(
    CompanyId int          NOT NULL CONSTRAINT PKCompany PRIMARY KEY,
    Name      varchar(20)  NOT NULL CONSTRAINT AKCompany_Name UNIQUE,
    Path      varchar(1700) NOT NULL --indexes max out at 1700 bytes. Allows for at least a 1600+ deep Hierarchy, which is very deep
									--for most uses, but is a limitation. Removing the index could really hurt perf.
);

CREATE INDEX XPath
ON PathMethod.Company(Path);
GO

--same demo stuff as before
CREATE SEQUENCE PathMethod.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE PathMethod.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES PathMethod.Company(CompanyId)
);
GO

CREATE INDEX XCompanyId
ON PathMethod.Sale
(
    CompanyId,
    Amount);
GO

CREATE PROCEDURE PathMethod.Company$Insert
(
    @Name              varchar(20),
    @ParentCompanyName varchar(20)
)
AS
BEGIN
    --gets Path, which looks like \CompanyId\CompanyId\...
    DECLARE @ParentPath varchar(1700) = COALESCE((  SELECT Company.Path
                                                    FROM   PathMethod.Company
                                                    WHERE  Company.Name = @ParentCompanyName), '\');
    --needn't use a SEQUENCE, but it made it easier to be able to do the next step 
    --in a single statement
    DECLARE @NewCompanyId int = NEXT VALUE FOR PathMethod.Company_SEQUENCE;

    --appends the new id to the parents Path 
    INSERT INTO PathMethod.Company(CompanyId, Name, Path)
    SELECT @NewCompanyId, @Name, @ParentPath + CAST(@NewCompanyId AS varchar(10)) + '\';
END;
GO

CREATE PROCEDURE PathMethod.Sale$InsertTestData
    @Name     varchar(20),
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO PathMethod.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR PathMethod.CompanyDataGenerator_SEQUENCE AS varchar(10)),
           CAST(NEXT VALUE FOR PathMethod.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   PathMethod.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO

EXEC PathMethod.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC PathMethod.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC PathMethod.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC PathMethod.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC PathMethod.Sale$InsertTestData @Name = 'Nashville Branch';

EXEC PathMethod.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC PathMethod.Sale$InsertTestData @Name = 'Knoxville Branch';

EXEC PathMethod.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC PathMethod.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC PathMethod.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC PathMethod.Sale$InsertTestData @Name = 'Portland Branch';

EXEC PathMethod.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC PathMethod.Sale$InsertTestData @Name = 'Camden Branch';
GO

--you can see that the Path uses the surrogate keys (which have little if any reason to change)
SELECT   Company.CompanyId, Company.Name, Company.Path
FROM     PathMethod.Company
ORDER BY Company.Path;
