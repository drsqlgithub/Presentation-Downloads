USE HowToOptimizeAHierarchyInSQLServer;
GO

KimballHelper.[CompanyHierarchyHelper$Rebuild];

SET STATISTICS TIME ON;

SET STATISTICS IO ON;

DECLARE @CompanyName varchar(20) = NULL;
--DECLARE @CompanyName VARCHAR(20) = 'Tennessee HQ'
--DECLARE @CompanyName VARCHAR(20) = 'Node100'

--getting all of the children of a root node (I am assuming just one (another decent thing to require in your
--hierarchies, could call it "root" or "all), but it could be > 1 and it would require revising the query a bit
DECLARE @CompanyId int = (   SELECT Company.CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  Company.Name = @CompanyName
                                 OR (   @CompanyName IS NULL
                                        AND Company.ParentCompanyId IS NULL));

SELECT Company.CompanyId, Company.Name, Company.ParentCompanyId
FROM   AdjacencyList.Company
       JOIN KimballHelper.CompanyHierarchyHelper
           ON Company.CompanyId = CompanyHierarchyHelper.ChildCompanyId
WHERE  CompanyHierarchyHelper.ParentCompanyId = @CompanyId;
GO

--shows the break between queries
SELECT TOP 1
     objects.name,
     objects.object_id,
     objects.principal_id,
     objects.schema_id,
     objects.parent_object_id,
     objects.type,
     objects.type_desc,
     objects.create_date,
     objects.modify_date,
     objects.is_ms_shipped,
     objects.is_published,
     objects.is_schema_published
FROM sys.objects;
GO

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
             ON ISNULL(Company.CompanyId, Company.ParentCompanyId) = Aggregations.ParentCompanyId
ORDER BY Company.CompanyId, Company.ParentCompanyId;
GO