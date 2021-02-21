USE HowToOptimizeAHierarchyInSQLServer;
GO

--===============================================================================
--getting all of the children of a  node (I am assuming just one (another decent thing to require in your
--hierarchies, could call it "root" or "all), but it could be > 1 and it would require revising the query a bit

DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  ParentCompanyId IS NULL);

--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          CASE WHEN Company.ParentCompanyId IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CompanyId

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy  + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row (always confuses me a bit :)
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
			--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
			--not the parent.
			--on Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     AdjacencyList.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO

--===============================================================================
--getting the children of a non-root row 
DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  Name = 'Tennessee HQ');

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          CASE WHEN Company.ParentCompanyId IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CompanyId

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy  + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row (always confuses me a bit :)
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
--not the parent.
--on Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     AdjacencyList.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO


--===============================================================================
--getting the children of a two non-root rows 

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          CASE WHEN Company.ParentCompanyId IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  Name IN ('Tennessee HQ','Maine HQ')

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy  + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row (always confuses me a bit :)
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
--not the parent.
--on Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     AdjacencyList.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY  CompanyHierarchy.Hierarchy;
GO


WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          CASE WHEN Company.ParentCompanyId IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  Name IN ('Tennessee HQ','Company HQ')

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy  + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row (always confuses me a bit :)
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
--not the parent.
--on Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     AdjacencyList.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY  CompanyHierarchy.Hierarchy;
GO
--===============================================================================
--getting the parents of CompanyId for Memphis (pretty much the same query with a small revision,
--which is included in all of these queries to be uncommented)

DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  Name = 'Memphis Branch');

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          '\' + CAST(CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CompanyId

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy  + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row (always confuses me a bit :)
              --ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
			  --use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
			  --not the parent.
			  ON Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     AdjacencyList.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO


--===============================================================================
--just like insert, the MOST simple method of reparenting by far!
CREATE PROCEDURE AdjacencyList.Company$Reparent
(
    @Name                 varchar(20),
    @NewParentCompanyName varchar(20)
)
AS
BEGIN
    --move the Company to a new parent. Very simple with adjacency list
    UPDATE AdjacencyList.Company
    SET    ParentCompanyId = (   SELECT CompanyId AS ParentCompanyId
                                 FROM   AdjacencyList.Company
                                 WHERE  Company.Name = @NewParentCompanyName)
    WHERE  Name = @Name;
END;
GO

EXEC AdjacencyList.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Tennessee HQ';
GO

--show entire tree
DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  ParentCompanyId IS NULL);

;WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          '\' + CAST(CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CompanyId

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
--not the parent.
--on Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.ParentCompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     AdjacencyList.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO

--put things back
EXEC AdjacencyList.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Company HQ'
GO

--===============================================================================
--Deleting a node

--our delete either delete a leaf node, or deletes everything along with the 
--node... --a bit more error handling here because it is a bit more complex in nature

CREATE OR ALTER PROCEDURE AdjacencyList.Company$Delete
    @Name                varchar(20),
    @DeleteChildRowsFlag bit = 0
AS

BEGIN
    DECLARE @CompanyId int = (   SELECT CompanyId
                                 FROM   AdjacencyList.Company
                                 WHERE  Name = @Name);

    IF @CompanyId IS NULL
    BEGIN
        THROW 50000, 'Invalid Company Name passed in', 1;
        RETURN -100;
    END;

    IF @DeleteChildRowsFlag = 0 --don't delete children
    BEGIN
        --we are trusting the foreign key constraint to make sure that there     
        --are no orphaned rows
        DELETE AdjacencyList.Company
        WHERE CompanyId = @CompanyId;
    END;
    ELSE
    BEGIN
        --deleting all of the child rows, just uses the recursive CTE with a DELETE rather than a 
        --SELECT
        ;WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
         AS (
            --gets the top level in Hierarchy we want. The Hierarchy column
            --will show the row's place in the Hierarchy from this query only
            --not in the overall reality of the row's place in the table
            SELECT CompanyId,
                   ParentCompanyId,
                   1 AS TreeLevel,
                   CAST(CompanyId AS varchar(MAX)) AS Hierarchy
            FROM   AdjacencyList.Company
            WHERE  CompanyId = @CompanyId

            UNION ALL

            --joins back to the CTE to recursively retrieve the rows 
            --note that TreeLevel is incremented on each iteration
            SELECT Company.CompanyId,
                   Company.ParentCompanyId,
                   TreeLevel + 1 AS TreeLevel,
                   Hierarchy + '\' + CAST(Company.CompanyId AS varchar(20)) AS Hierarchy
            FROM   AdjacencyList.Company
                   INNER JOIN CompanyHierarchy
                       --use to get children, since the ParentCompanyId of the child will be set the value
                       --of the current row
                       ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
         --use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
         --not the parent.
         --on Company.CompanyId= CompanyHierarchy.ParentCompanyId
         )
        --return results from the CTE, joining to the Company data to get the 
        --Company Name
        DELETE AdjacencyList.Company
        FROM AdjacencyList.Company
             INNER JOIN CompanyHierarchy
                 ON Company.CompanyId = CompanyHierarchy.CompanyId;

    END;


END;
GO

--add a few rows to test the delete. No activity rows because that would limit deletes
EXEC AdjacencyList.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';

EXEC AdjacencyList.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';

EXEC AdjacencyList.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';

EXEC AdjacencyList.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';

EXEC AdjacencyList.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';

EXEC AdjacencyList.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';
GO

--show entire tree
DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  ParentCompanyId IS NULL);;

;WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          CAST(CompanyId AS varchar(MAX)) AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CompanyId

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy + '\' + CAST(Company.CompanyId AS varchar(20)) AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
--not the parent.
--on Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.ParentCompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     AdjacencyList.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO

--===============================================================================

--try to delete Georgia
EXEC AdjacencyList.Company$Delete @Name = 'Georgia HQ';
GO

--delete Atlanta
EXEC AdjacencyList.Company$Delete @Name = 'Atlanta Branch';
GO

SELECT *
FROM   AdjacencyList.Company;

EXEC AdjacencyList.Company$Delete @Name = 'Georgia HQ', @DeleteChildRowsFlag = 1;

SELECT *
FROM   AdjacencyList.Company;

EXEC AdjacencyList.Company$Delete @Name = 'Texas HQ', @DeleteChildRowsFlag = 1;

SELECT *
FROM   AdjacencyList.Company;

-----------------------------------
--Aggregating along a Hierarchy

--Inspired by:
--http://go4answers.webhost4life.com/Example/Hierarchy-aggregation-41974.aspx
--Thanks to Alejandro Mesa (Hunchback)

--get an expanded Hierarchy view.
-- bascially for each parent, a list of all children (will look familiar later as this is the basis of another method)
WITH ExpandedHierarchy
AS (
   --just get all of the nodes of the Hierarchy
   SELECT ISNULL(CompanyId, ParentCompanyId) AS ParentCompanyId,
          ISNULL(CompanyId, ParentCompanyId) AS ChildCompanyId
   FROM   AdjacencyList.Company

   UNION ALL

   --get all of the children of each node for aggregating  

   SELECT Parent.ParentCompanyId, Child.CompanyId AS ChildCompanyId
   FROM   ExpandedHierarchy AS Parent
          JOIN AdjacencyList.Company AS Child
              ON Parent.ChildCompanyId = Child.ParentCompanyId
   WHERE  Child.CompanyId IS NOT NULL

)
SELECT   ExpandedHierarchy.ParentCompanyId, ExpandedHierarchy.ChildCompanyId
FROM     ExpandedHierarchy
ORDER BY 1;
GO

--take the expanded Hierarchy...
WITH ExpandedHierarchy
AS (
   --just get all of the nodes of the Hierarchy
   SELECT ISNULL(CompanyId, ParentCompanyId) AS ParentCompanyId,
          ISNULL(CompanyId, ParentCompanyId) AS ChildCompanyId
   FROM   AdjacencyList.Company

   UNION ALL

   --get all of the children of each node for aggregating  

   SELECT Parent.ParentCompanyId, Child.CompanyId AS ChildCompanyId
   FROM   ExpandedHierarchy AS Parent
          JOIN AdjacencyList.Company AS Child
              ON Parent.ChildCompanyId = Child.ParentCompanyId
   WHERE  Child.CompanyId IS NOT NULL

),
     --get totals for each Company for the aggregate
     CompanyTotals
AS (SELECT   CompanyId, SUM(Amount) AS TotalAmount
    FROM     AdjacencyList.Sale
    GROUP BY CompanyId),

     --aggregate each Company for the Company
     Aggregations
AS (SELECT   ExpandedHierarchy.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
    FROM     ExpandedHierarchy
             LEFT JOIN CompanyTotals
                 ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
    GROUP BY ExpandedHierarchy.ParentCompanyId)

--display the data...
SELECT   Company.CompanyId, Company.ParentCompanyId, Aggregations.TotalSalesAmount
FROM     AdjacencyList.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Company.CompanyId, Company.ParentCompanyId;
GO