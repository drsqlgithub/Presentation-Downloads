USE HowToOptimizeAHierarchyInSQLServer
go

SET STATISTICS TIME ON
SET STATISTICS IO ON 
go

DECLARE @CompanyName VARCHAR(20) = NULL
--DECLARE @CompanyName VARCHAR(20) = 'Tennessee HQ'
--DECLARE @CompanyName VARCHAR(20) = 'Node100'


--getting all of the children of a root node (I am assuming just one (another decent thing to require in your
--hierarchies, could call it "root" or "all), but it could be > 1 and it would require revising the query a bit
DECLARE @CompanyId int = (	SELECT CompanyId FROM InMemAdjacencyList.Company 
							WHERE Name = @CompanyName 
							   OR (@CompanyName IS NULL AND ParentCompanyId = -1));

--this is the MOST complex method of querying the Hierarchy, by far...

--algorithm is relational recursion
;WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS
(
     --gets the top level in Hierarchy we want. The Hierarchy column
     --will show the row's place in the Hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT CompanyId, ParentCompanyId,
            1 as TreeLevel, CAST(CompanyId as varchar(max)) as Hierarchy
     FROM   InMemAdjacencyList.Company
     WHERE CompanyId=@CompanyId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that TreeLevel is incremented on each iteration
     SELECT Company.CompanyId, Company.ParentCompanyId,
            TreeLevel + 1 as TreeLevel,
            Hierarchy + '\' +cast(Company.CompanyId as varchar(20)) as Hierarchy
     FROM   InMemAdjacencyList.Company
              INNER JOIN CompanyHierarchy
                --use to get children, since the ParentCompanyId of the child will be set the value
				--of the current row
                on Company.ParentCompanyId= CompanyHierarchy.CompanyId 
                --use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
				--not the parent.
                --on Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT  Company.CompanyId,Company.Name,
        CompanyHierarchy.TreeLevel, CompanyHierarchy.Hierarchy
FROM     InMemAdjacencyList.Company
         INNER JOIN CompanyHierarchy
              ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy ;
GO

--shows the break between queries
SELECT TOP 1 *
FROM  sys.objects
go

	SET STATISTICS TIME ON
	SET STATISTICS IO ON 
	go
	--take the expanded Hierarchy...
	WITH ExpandedHierarchy AS
	(
		--just get all of the nodes of the Hierarchy
		SELECT ISNULL(CompanyId, ParentCompanyId) AS ParentCompanyId,
			ISNULL(CompanyId, ParentCompanyId) AS ChildCompanyId
		FROM InMemAdjacencyList.Company

		UNION ALL
  
		--get all of the children of each node for aggregating  

		SELECT Parent.ParentCompanyId, Child.CompanyId AS ChildCompanyId
		FROM  ExpandedHierarchy AS Parent
				JOIN InMemAdjacencyList.Company AS Child
						ON Parent.ChildCompanyId = Child.ParentCompanyId
		WHERE  Child.CompanyId IS NOT NULL

	)
	,
	--get totals for each Company for the aggregate
	CompanyTotals AS
	(
		SELECT CompanyId, SUM(Amount) AS TotalAmount
		FROM   InMemAdjacencyList.Sale
		GROUP BY CompanyId
	),

	--aggregate each Company for the Company
	Aggregations AS (
	SELECT ExpandedHierarchy.ParentCompanyId,SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
	FROM   ExpandedHierarchy
			 LEFT JOIN CompanyTotals
				ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
	GROUP  BY ExpandedHierarchy.ParentCompanyId)

	--display the data...
	SELECT Company.CompanyId, Company.ParentCompanyId, Aggregations.TotalSalesAmount
	FROM   InMemAdjacencyList.Company 
			JOIN Aggregations
			ON Company.CompanyId = Aggregations.ParentCompanyId
	ORDER BY Company.CompanyId, Company.ParentCompanyId
	go


	--SET STATISTICS TIME ON
	--SET STATISTICS IO ON
	--go


