USE HowToOptimizeAHierarchyInSQLServer;

SET STATISTICS TIME ON;

SET STATISTICS IO ON;
GO

DECLARE @CompanyPath varchar(900);

SELECT @CompanyPath = Path
FROM   PathMethod.Company
WHERE  LEN(Path) = 3;

SELECT *
FROM   PathMethod.Company
WHERE  Path LIKE @CompanyPath + '%';
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

SET STATISTICS TIME ON;

SET STATISTICS IO ON;
GO

--aggregating over the Hierarchy
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
             LEFT JOIN CompanyTotals
                 ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
    GROUP BY ExpandedHierarchy.ParentCompanyId)
SELECT  Company.CompanyId,
         Company.Name,
		 Company.Path,
         Aggregations.TotalSalesAmount
FROM     PathMethod.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Company.CompanyId;
GO