USE HowToOptimizeAHierarchyInSQLServer;
GO

--returns all of the children for a given row, using the same algorithm as previously, with a few mods to 
--include the additional metadata

CREATE FUNCTION AdjacencyList.Company$returnHierarchyHelper(@CompanyId int)
RETURNS @Output table
(
    ParentCompanyId    int,
    ChildCompanyId     int,
    Distance           int,
    ParentRootNodeFlag bit,
    ChildLeafNodeFlag  bit
)
AS
BEGIN
    ;WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
     AS (
        --gets the top level in Hierarchy we want. The Hierarchy column
        --will show the row's place in the Hierarchy from this query only
        --not in the overall reality of the row's place in the table
        SELECT Company.CompanyId,
               Company.ParentCompanyId,
               1 AS TreeLevel,
               CAST(Company.CompanyId AS varchar(MAX)) AS Hierarchy
        FROM   AdjacencyList.Company
        WHERE  Company.CompanyId = @CompanyId

        UNION ALL

        --joins back to the CTE to recursively retrieve the rows 
        --note that TreeLevel is incremented on each iteration
        SELECT Company.CompanyId,
               Company.ParentCompanyId,
               CompanyHierarchy.TreeLevel + 1 AS TreeLevel,
               CompanyHierarchy.Hierarchy + '\' + CAST(Company.CompanyId AS varchar(20)) AS Hierarchy
        FROM   AdjacencyList.Company
               INNER JOIN CompanyHierarchy
                   --use to get children
                   ON Company.ParentCompanyId = CompanyHierarchy.CompanyId

     )
    --added to original tree example with distance, root and leaf node indicators
    INSERT INTO @Output(ParentCompanyId, ChildCompanyId, Distance, ParentRootNodeFlag, ChildLeafNodeFlag)
    SELECT @CompanyId AS ParentCompanyId,
           CompanyHierarchy.CompanyId AS ChildCompanyId,
           CompanyHierarchy.TreeLevel - 1 AS Distance,
           CASE WHEN CompanyHierarchy.CompanyId = @CompanyId
                    AND CompanyHierarchy.ParentCompanyId IS NULL
                    THEN 1
                ELSE 0
           END AS ParentRootNodeFlag,
           CASE WHEN NOT EXISTS (   SELECT *
                                    FROM   AdjacencyList.Company
                                    WHERE  Company.ParentCompanyId = CompanyHierarchy.CompanyId)
                    THEN 1
                ELSE 0
           END AS ChildRootNodeFlag
    FROM   CompanyHierarchy;

    RETURN;

END;
GO

DECLARE @CompanyId int = (   SELECT Company.CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  Company.ParentCompanyId IS NULL );

SELECT Company$returnHierarchyHelper.ParentCompanyId,
       Company$returnHierarchyHelper.ChildCompanyId,
       Company$returnHierarchyHelper.Distance,
       Company$returnHierarchyHelper.ParentRootNodeFlag,
       Company$returnHierarchyHelper.ChildLeafNodeFlag
FROM   AdjacencyList.Company$returnHierarchyHelper(@CompanyId);

--parent root node is about the parent, which for that call is always 1

--all nodes..
SELECT   HierarchyHelper.ParentCompanyId,
         HierarchyHelper.ChildCompanyId,
         HierarchyHelper.Distance,
         HierarchyHelper.ParentRootNodeFlag,
         HierarchyHelper.ChildLeafNodeFlag
FROM     AdjacencyList.Company
         CROSS APPLY AdjacencyList.Company$returnHierarchyHelper(Company.CompanyId) AS HierarchyHelper
ORDER BY HierarchyHelper.ParentCompanyId;
GO

CREATE PROCEDURE KimballHelper.CompanyHierarchyHelper$Rebuild
AS
SET XACT_ABORT ON;

BEGIN TRANSACTION;

TRUNCATE TABLE KimballHelper.CompanyHierarchyHelper;

--save off the rows in the Hierarchy helper table
INSERT INTO KimballHelper.CompanyHierarchyHelper(ParentCompanyId,
                                                 ChildCompanyId,
                                                 Distance,
                                                 ParentRootNodeFlag,
                                                 ChildLeafNodeFlag)
SELECT HierarchyHelper.ParentCompanyId,
       HierarchyHelper.ChildCompanyId,
       HierarchyHelper.Distance,
       HierarchyHelper.ParentRootNodeFlag,
       HierarchyHelper.ChildLeafNodeFlag
FROM   AdjacencyList.Company
       CROSS APPLY AdjacencyList.Company$returnHierarchyHelper(Company.CompanyId) AS HierarchyHelper;

COMMIT TRANSACTION;
GO

--Took 28 seconds with the 3400 row table
KimballHelper.CompanyHierarchyHelper$Rebuild;
GO

--get children of Tennessee HQ including HQ
SELECT getNodes.CompanyId, getNodes.Name, getNodes.ParentCompanyId
FROM   KimballHelper.CompanyHierarchyHelper --gets the Hierarchy helper rows that are for the CompanyId that we searched for
       JOIN AdjacencyList.Company AS getNodes --the tree data as it relates to the node
           ON getNodes.CompanyId = CompanyHierarchyHelper.childCompanyId
WHERE  EXISTS (   SELECT *
                  FROM   AdjacencyList.Company
                  WHERE  Company.Name = 'Tennessee HQ'
                      AND CompanyHierarchyHelper.ParentCompanyId = Company.CompanyId);

--this works because the query of the Hierarchy helper gives us a slice of the data.
SELECT   *
FROM     KimballHelper.CompanyHierarchyHelper
ORDER BY ParentCompanyId;
GO


--get children of Tennessee HQ not including HQ
SELECT getNodes.CompanyId, getNodes.Name, getNodes.ParentCompanyId
FROM   KimballHelper.CompanyHierarchyHelper --gets the Hierarchy helper rows that are for the CompanyId that we searched for
       JOIN AdjacencyList.Company AS getNodes --the tree data as it relates to the node
           ON getNodes.CompanyId = CompanyHierarchyHelper.childCompanyId
WHERE  EXISTS (   SELECT *
                  FROM   AdjacencyList.Company
                  WHERE  Company.Name = 'Tennessee HQ'
                      AND CompanyHierarchyHelper.ParentCompanyId = Company.CompanyId
                      AND CompanyHierarchyHelper.childCompanyId <> Company.CompanyId);

--get children of Company HQ 
SELECT getNodes.CompanyId, getNodes.Name, getNodes.ParentCompanyId
FROM   KimballHelper.CompanyHierarchyHelper --gets the Hierarchy helper rows that are for the CompanyId that we searched for
       JOIN AdjacencyList.Company AS getNodes --the tree data as it relates to the node
           ON getNodes.CompanyId = CompanyHierarchyHelper.childCompanyId
WHERE  EXISTS (   SELECT *
                  FROM   AdjacencyList.Company
                  WHERE  Company.Name = 'Company HQ'
                      AND CompanyHierarchyHelper.ParentCompanyId = Company.CompanyId);

--get children of Company HQ that are leaf nodes
SELECT getNodes.CompanyId, getNodes.Name, getNodes.ParentCompanyId
FROM   KimballHelper.CompanyHierarchyHelper --gets the Hierarchy helper rows that are for the CompanyId that we searched for
       JOIN AdjacencyList.Company AS getNodes --the tree data as it relates to the node
           ON getNodes.CompanyId = CompanyHierarchyHelper.childCompanyId
WHERE  EXISTS (   SELECT *
                  FROM   AdjacencyList.Company
                  WHERE  Company.Name = 'Company HQ'
                      AND CompanyHierarchyHelper.ParentCompanyId = Company.CompanyId)
    AND CompanyHierarchyHelper.ChildLeafNodeFlag = 1;
GO

--- get children of Company HQ that are the next N levels down (this is more complex than other methods)

SELECT getNodes.CompanyId, getNodes.Name, getNodes.ParentCompanyId
FROM   KimballHelper.CompanyHierarchyHelper --gets the Hierarchy helper rows that are for the CompanyId that we searched for
       JOIN AdjacencyList.Company AS getNodes --the tree data as it relates to the node
           ON getNodes.CompanyId = CompanyHierarchyHelper.childCompanyId
WHERE  EXISTS (   SELECT *
                  FROM   AdjacencyList.Company
                  WHERE  Company.Name = 'Company HQ'
                      AND CompanyHierarchyHelper.ParentCompanyId = Company.CompanyId)
    AND CompanyHierarchyHelper.Distance = (SELECT Distance + 1 --or how far you want to go, 1 is easier in base structures 
										FROM   KimballHelper.CompanyHierarchyHelper AS Helper2
												 JOIN AdjacencyList.Company
													ON Helper2.ParentCompanyId = Company.CompanyId  --Parent and ChildCompany are equal on their parent node
													   AND Helper2.ChildCompanyId = Company.CompanyId
										WHERE  Company.Name = 'Company HQ')

GO

--non leaf nodes
SELECT getNodes.CompanyId, getNodes.Name, getNodes.ParentCompanyId
FROM   KimballHelper.CompanyHierarchyHelper --gets the Hierarchy helper rows that are for the CompanyId that we searched for
       JOIN AdjacencyList.Company AS getNodes --the tree data as it relates to the node
           ON getNodes.CompanyId = CompanyHierarchyHelper.childCompanyId
WHERE  EXISTS (   SELECT *
                  FROM   AdjacencyList.Company
                  WHERE  Company.Name = 'Company HQ'
                      AND CompanyHierarchyHelper.ParentCompanyId = Company.CompanyId)
    AND CompanyHierarchyHelper.ChildLeafNodeFlag = 0;

--No need for Kimball Helper reparent, as the helper table represents a view of the data, not the actual structure in use.
--Reparent = complete rebuilt (at least of affected rows, but unless the structure is humongous,
--complete rebuild is perhpas easiest)


--No need for delete either, as we would simply rebuild the table. In fact, the rebuild table could be added
--to a trigger if one was to use this transactionally. Clearly your mileage may vary.
GO

--so the data looks like it did in other examples
EXEC AdjacencyList.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Tennessee HQ';
GO

EXEC KimballHelper.CompanyHierarchyHelper$Rebuild;
GO

--see that data has changed
select Company.*, CompanyHierarchyHelper.*
from   KimballHelper.CompanyHierarchyHelper 
		 join AdjacencyList.Company
			on Company.CompanyId = CompanyHierarchyHelper.ChildCompanyId
where  CompanyHierarchyHelper.ParentCompanyId = 
		(select CompanyId from AdjacencyList.Company where Name = 'Company HQ')

/*
SET STATISTICS TIME ON
SET STATISTICS IO ON
*/

WITH CompanyTotals
AS (SELECT   Sale.CompanyId, SUM(Sale.Amount) AS TotalAmount
    FROM     AdjacencyList.Sale
    GROUP BY Sale.CompanyId),
     Aggregations
AS (SELECT   CompanyHierarchyHelper.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
    FROM     KimballHelper.CompanyHierarchyHelper
             LEFT JOIN CompanyTotals
                 ON CompanyTotals.CompanyId = CompanyHierarchyHelper.ChildCompanyId
    GROUP BY CompanyHierarchyHelper.ParentCompanyId)
SELECT   Company.CompanyId, Company.ParentCompanyId, Aggregations.TotalSalesAmount
FROM     AdjacencyList.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Company.CompanyId, Company.ParentCompanyId;
go
EXEC KimballHelper.CompanyHierarchyHelper$Rebuild;
GO