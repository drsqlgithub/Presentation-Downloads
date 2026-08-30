USE HowToOptimizeAHierarchyInSQLServer;
GO

--get all nodes we use the Path in a like comparison 
--(hence the index)

DECLARE @CompanyPath varchar(900);

SELECT @CompanyPath = Path
FROM   PathMethod.Company
WHERE  Name = 'Company HQ';

SELECT @CompanyPath;

SELECT *
FROM   PathMethod.Company
WHERE  Path LIKE @CompanyPath + '%';
GO

--get all nodes in the Tennessee Hierarchy, we use the Path in a like comparison 
--(hence the index)

DECLARE @CompanyPath varchar(900);

SELECT @CompanyPath = Path
FROM   PathMethod.Company
WHERE  Name = 'Tennessee HQ';

SELECT *
FROM   PathMethod.Company
WHERE  Path LIKE @CompanyPath + '%';
GO

SELECT ChildRows.* -- with TN node
FROM   PathMethod.Company
       JOIN PathMethod.Company AS ChildRows
           ON ChildRows.Path LIKE Company.Path + '%'
WHERE  Company.Name = 'Tennessee HQ';

SELECT ChildRows.* --without TN node
FROM   PathMethod.Company
       JOIN PathMethod.Company AS ChildRows
           ON ChildRows.Path LIKE Company.Path + '%_'
WHERE  Company.Name = 'Tennessee HQ';

--getting parents is a slightly more interesting, uses this function that was included in the 
--database create (something I will commonly add to my databases...)

--parse based on the \ delimiter
SELECT value
FROM   STRING_SPLIT('\1\2\3\4\', '\');
GO

DECLARE @CompanyPath varchar(900);

SELECT @CompanyPath = Path
FROM   PathMethod.Company
WHERE  Name = 'Nashville Branch';

SELECT *
FROM   STRING_SPLIT(@CompanyPath, '\') AS Ids
       JOIN PathMethod.Company
           ON Company.CompanyId = Ids.value;
GO

--*---   Get 1 level deep from parent

DECLARE @CompanyPath varchar(900);

SELECT @CompanyPath = Path
FROM   PathMethod.Company
WHERE  Name = 'Company HQ';

SELECT @CompanyPath;

SELECT *
FROM   PathMethod.Company
WHERE  Path LIKE @CompanyPath + '%\'
    AND Path NOT LIKE @CompanyPath + '%\%\';

--*---   Get 1 level deep from parent

--reparent Maine HQ to Child of Nashville
GO

CREATE PROCEDURE PathMethod.Company$reparent
(
    @Location          varchar(20),
    @NewParentLocation varchar(20)
)
AS
--reparenting is more or less just stuffing the new parent's Path where the old parent's
--Path was.. Stuff is used so you can don't have to worry with any issues with replace
DECLARE @LenOldPath int           = (   SELECT LEN(Path) --length of Path to allow stuff to work
                                        FROM   PathMethod.Company
                                        WHERE  Name = @Location),
        @NewPath    varchar(2000) = (   SELECT Path --Path of new location 
                                        FROM   PathMethod.Company
                                        WHERE  Name = @NewParentLocation),
        @NewPathEnd varchar(10)   = (   SELECT CAST(CompanyId AS varchar(10)) --CompanyId and \ for end of new home Path
                                        FROM   PathMethod.Company --for the node that is moving..
                                        WHERE  Name = @Location) + '\';

UPDATE PathMethod.Company
--stuff new parent address into existing address, replacing old root Path
SET    Path = STUFF(Path, 1, @LenOldPath, @NewPath + @NewPathEnd)
WHERE  Path LIKE (   SELECT Path + '%'
                     FROM   PathMethod.Company
                     WHERE  Name = @Location);
GO

SELECT   *
FROM     PathMethod.Company
ORDER BY Path;
GO

EXEC PathMethod.Company$reparent @Location = 'Maine HQ', @NewParentLocation = 'Tennessee HQ';

SELECT   *
FROM     PathMethod.Company
ORDER BY Path;
GO

-------------------
--Deleting a node

CREATE PROCEDURE PathMethod.Company$Delete
    @Name                varchar(20),
    @DeleteChildRowsFlag bit = 0
AS

BEGIN
    DECLARE @CompanyId int = (   SELECT CompanyId
                                 FROM   PathMethod.Company
                                 WHERE  Name = @Name);

    IF @CompanyId IS NULL
    BEGIN
        THROW 50000, 'Invalid Company Name passed in', 1;

        RETURN -100;
    END;

    IF @DeleteChildRowsFlag = 0
    BEGIN
        IF EXISTS (   SELECT *
                      FROM   PathMethod.Company
                      WHERE  Path LIKE (   SELECT Path + '%_' --underscore eliminates the Company from 
                                           FROM   PathMethod.Company --@CompanyId from the query
                                           WHERE  CompanyId = @CompanyId))

        BEGIN
            THROW 50000, 'Child nodes exist for Company passed in to delete and parameter said to not delete them.', 1;

            RETURN -100;
        END;
    END;

    SET XACT_ABORT ON; --simple error management for ease of demo

    BEGIN TRANSACTION;

    --delete in either case is just this simple delete. Gate query earlier checks to make sure we are doing what we should be
    DELETE PathMethod.Company
    WHERE Path LIKE (   SELECT Path + '%' --include the Company from @Company and all children
                        FROM   PathMethod.Company
                        WHERE  CompanyId = @CompanyId);

    COMMIT TRANSACTION;
END;
GO

--add a few rows to test the delete. No activity rows because that would limit deletes
EXEC PathMethod.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';

EXEC PathMethod.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';

EXEC PathMethod.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';

EXEC PathMethod.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';

EXEC PathMethod.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';

EXEC PathMethod.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';

SELECT   *
FROM     PathMethod.Company
ORDER BY Path;
GO

EXEC PathMethod.Company$Delete @Name = 'Georgia HQ';
GO

EXEC PathMethod.Company$Delete @Name = 'Atlanta Branch';

SELECT   *
FROM     PathMethod.Company
ORDER BY Path;

EXEC PathMethod.Company$Delete @Name = 'Georgia HQ', @DeleteChildRowsFlag = 1;

SELECT   *
FROM     PathMethod.Company
ORDER BY Path;

EXEC PathMethod.Company$Delete @Name = 'Texas HQ', @DeleteChildRowsFlag = 1;

SELECT   *
FROM     PathMethod.Company
ORDER BY Path;

/*
SET STATISTICS TIME ON
SET STATISTICS IO ON
*/
GO

--aggregating over the Hierarchy

--Getting ALL OF the children for every row, to get the aggregation Hierarchy

SELECT Company.CompanyId AS ParentCompanyId, ChildRows.CompanyId AS ChildCompanyId
FROM   PathMethod.Company
       JOIN PathMethod.Company AS ChildRows
           ON ChildRows.Path LIKE Company.Path + '%';
GO

WITH ExpandedHierarchy
AS (SELECT Company.CompanyId AS ParentCompanyId, ChildRows.CompanyId AS ChildCompanyId
    FROM   PathMethod.Company
           JOIN PathMethod.Company AS ChildRows
               ON ChildRows.Path LIKE Company.Path + '%'),
     CompanyTotals
AS (SELECT   CompanyId, SUM(Amount) AS TotalAmount
    FROM     PathMethod.Sale
    GROUP BY CompanyId),

     Aggregations
AS (SELECT   ExpandedHierarchy.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
    FROM     ExpandedHierarchy
             JOIN CompanyTotals
                 ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
    GROUP BY ExpandedHierarchy.ParentCompanyId)
SELECT   Company.CompanyOrgNode,
         Company.CompanyId,
         Company.Name,
         Company.OrganizationLevel,
         Aggregations.TotalSalesAmount
FROM     PathMethod.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Company.Path;
