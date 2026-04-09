USE HowToOptimizeAHierarchyInSQLServer;
GO

--===============================================================================
--getting all of the children of a  node (I am assuming just one (another decent thing to require in your
--hierarchies, could call it "root" or "all), but it could be > 1 and it would require revising the query a bit

DECLARE @CompanyId INT = (   SELECT CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  ParentCompanyId IS NULL);

--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table

   --Referrred to as the anchor
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          CASE WHEN Company.ParentCompanyId IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(CompanyId AS VARCHAR(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CompanyId

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy  + CAST(Company.CompanyId AS VARCHAR(20)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row (always confuses me a bit, and it did again when I started this :)
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
			--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
			--not the parent.
			--on Company.CompanyId= CompanyHierarchy.ParentCompanyId


--Each iteration sees only the previous iteration!

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

---------------------------------------------------------------------
-- Rewritten as a classic loop (this is how we did it pre-CTE
-- And 

-- Using a temporary table approach with a loop instead of a CTE
DECLARE @CompanyHierarchy TABLE
(
    CompanyId INT,
    ParentCompanyId INT,
    TreeLevel INT,
    Hierarchy VARCHAR(MAX)
);

-- Insert the initial companies (The anchor)
INSERT INTO @CompanyHierarchy
(
    CompanyId,
    ParentCompanyId,
    TreeLevel,
    Hierarchy
)
SELECT CompanyId,
       ParentCompanyId,
       1 AS TreeLevel,
       CASE
           WHEN Company.ParentCompanyId IS NOT NULL THEN
               '..'
           ELSE
               ''
       END + '\' + CAST(CompanyId AS VARCHAR(MAX)) + '\' AS Hierarchy
FROM AdjacencyList.Company
WHERE ParentCompanyId IS NULL;
--WHERE Name IN ( 'Tennessee HQ', 'Maine HQ' );

-- Declare variables for the loop
DECLARE @RowsAdded int = 1;
DECLARE @CurrentLevel int = 1;

-- Loop until no more rows are added
WHILE @RowsAdded > 0
BEGIN
    SET @CurrentLevel = @CurrentLevel + 1;

    -- Try to add the next level
    INSERT INTO @CompanyHierarchy
    (
        CompanyId,
        ParentCompanyId,
        TreeLevel,
        Hierarchy
    )
    SELECT Company.CompanyId,
           Company.ParentCompanyId,
           @CurrentLevel AS TreeLevel,
           CH.Hierarchy + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
    FROM AdjacencyList.Company
        INNER JOIN @CompanyHierarchy CH
            ON Company.ParentCompanyId = CH.CompanyId
        LEFT JOIN @CompanyHierarchy ExistingCH
            ON Company.CompanyId = ExistingCH.CompanyId
    WHERE ExistingCH.CompanyId IS NULL
          AND CH.TreeLevel = @CurrentLevel - 1;

    -- Check if any rows were added
    SET @RowsAdded = @@ROWCOUNT;

    -- Safety check to prevent infinite loops (optional)
    IF @CurrentLevel > 100
        BREAK;
END;

-- Return results
SELECT Company.CompanyId,
       Company.Name,
       CH.TreeLevel,
       CH.Hierarchy
FROM AdjacencyList.Company
    INNER JOIN @CompanyHierarchy CH
        ON Company.CompanyId = CH.CompanyId
ORDER BY CH.Hierarchy;
GO



-----------------------------------
--Aggregating along a Hierarchy

--Inspired by:
--http://go4answers.webhost4life.com/Example/Hierarchy-aggregation-41974.aspx
--Thanks to Alejandro Mesa (Hunchback)

--------------------------------------------------
--First show the output:
--------------------------------------------------

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


--just the expanded Hierarchy...
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
SELECT *
FROM   ExpandedHierarchy
ORDER BY ExpandedHierarchy.ParentCompanyId,ExpandedHierarchy.ChildCompanyId;


--get totals for each Company for the aggregate
WITH     CompanyTotals
AS (SELECT   CompanyId, SUM(Amount) AS TotalAmount
    FROM     AdjacencyList.Sale
    GROUP BY CompanyId)
SELECT *
FROM   CompanyTotals;


--Now show the aggregations


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
--Then voila!
SELECT   Company.Name, Company.CompanyId, Company.ParentCompanyId,
         Aggregations.TotalSalesAmount,
         
FROM     AdjacencyList.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Company.CompanyId, Company.ParentCompanyId;
GO