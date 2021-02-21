USE HowToOptimizeAHierarchyInSQLServer
go
SET STATISTICS TIME ON
SET STATISTICS IO ON
go

DECLARE @CompanyName VARCHAR(20) = NULL
--DECLARE @CompanyName VARCHAR(20) = 'Tennessee HQ'
--DECLARE @CompanyName VARCHAR(20) = 'Node100'

--single statement, including node asked for
select *, case when HierarchyLeft = HierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   GappedNestedSets.Company
where  exists (select *
				from GappedNestedSets.Company as startingPoint
				where Company.HierarchyLeft between startingPoint.HierarchyLeft
				  and startingPoint.HierarchyRight
				  and startingPoint.Name = @CompanyName
				  OR  (@CompanyName IS NULL AND HierarchyLeft = 1))
GO

--shows the break between queries
SELECT TOP 1 *
FROM  sys.objects

go
--aggregating over the Hierarchy
SET STATISTICS TIME ON
SET STATISTICS IO ON
go

;WITH ExpandedHierarchy AS
(
SELECT Company.CompanyId AS ParentCompanyId, Findrows.CompanyId AS ChildCompanyId
from   GappedNestedSets.Company
		 JOIN GappedNestedSets.Company AS FindRows
			ON FindRows.HierarchyLeft BETWEEN Company.HierarchyLeft AND Company.HierarchyRight)
,CompanyTotals AS
(
	SELECT CompanyId, SUM(Amount) AS TotalAmount
	FROM   GappedNestedSets.Sale
	GROUP BY CompanyId
),
Aggregations AS 
(
	SELECT ExpandedHierarchy.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
	FROM   ExpandedHierarchy
			 LEFT JOIN CompanyTotals
				ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
	GROUP  BY ExpandedHierarchy.ParentCompanyId
)
SELECT Company.*, Aggregations.TotalSalesAmount
FROM   GappedNestedSets.Company
		 JOIN Aggregations
		 ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY CompanyId
