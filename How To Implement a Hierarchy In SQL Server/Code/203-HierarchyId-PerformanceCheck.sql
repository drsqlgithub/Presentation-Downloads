USE HowToOptimizeAHierarchyInSQLServer
go

SET STATISTICS TIME ON
SET STATISTICS IO ON

DECLARE @CompanyName VARCHAR(20) = NULL
--DECLARE @CompanyName VARCHAR(20) = 'Tennessee HQ'
--DECLARE @CompanyName VARCHAR(20) = 'Node100'

--getting all of the children of a root node (I am assuming just one (another decent thing to require in your
--hierarchies, could call it "root" or "all), but it could be > 1 and it would require revising the query a bit
DECLARE @CompanyId int = (	SELECT CompanyId FROM AdjacencyList.Company 
							WHERE Name = @CompanyName 
							   OR (@CompanyName IS NULL AND ParentCompanyId IS NULL));

--get children of 1
SELECT Target.CompanyId, Target.Name, Target.CompanyOrgNode.ToString() as Hierarchy
FROM   HierarchyId.Company AS Target 
	       JOIN HierarchyId.Company AS SearchFor  --represents the one row that matches the search
		       ON SearchFor.CompanyId = @CompanyId
                          and Target.CompanyOrgNode.IsDescendantOf --gets target rows that are descendants of
                                                 (SearchFor.CompanyOrgNode) = 1
ORDER BY Target.CompanyId;
GO

--shows the break between queries
SELECT TOP 1 *
FROM  sys.objects

go
SET STATISTICS TIME ON
SET STATISTICS IO ON
;WITH ExpandedHierarchy AS --for every Company row, get that node and all children for the aggregating in a later CTE
(
SELECT Company.CompanyId as ParentCompanyId,ChildRows.CompanyId AS ChildCompanyId
FROM   HierarchyId.Company
	       JOIN HierarchyId.Company AS ChildRows  --represents the one row that matches the search
		       ON ChildRows.CompanyOrgNode.IsDescendantOf --gets target rows that are descendants of
                                                 (Company.CompanyOrgNode) = 1
)
,CompanyTotals AS
(
	SELECT CompanyId, SUM(Amount) AS TotalAmount
	FROM   HierarchyId.Sale
	GROUP BY CompanyId
)

,Aggregations AS 
(
	SELECT ExpandedHierarchy.ParentCompanyId,SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
	FROM   ExpandedHierarchy
			 JOIN CompanyTotals
				ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
	GROUP  BY ExpandedHierarchy.ParentCompanyId
)
SELECT Company.CompanyId, CompanyOrgNode.ToString(), Aggregations.TotalSalesAmount
FROM   HierarchyId.Company 
		JOIN Aggregations
  ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Company.CompanyId

