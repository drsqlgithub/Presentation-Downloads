USE HowToOptimizeAHierarchyInSQLServer
GO

DELETE NestedSets.Sale
DELETE NestedSets.Company 
go

--http://sqlblog.com/blogs/adam_machanic/archive/2006/07/12/swinging-from-tree-to-tree-using-ctes-part-1-adjacency-to-nested-sets.aspx



WITH CompanyLevels AS
 (
     SELECT
         CompanyId,
		 Name,
         CONVERT(VARCHAR(900), CompanyId) AS thePath,
		 CONVERT(VARCHAR(MAX), '\'+ CAST(CompanyId AS VARCHAR(10)) + '\') AS materializedPath,
         1 AS Level
     FROM AdjacencyList.Company
     WHERE ParentCompanyId IS NULL

     UNION ALL

     SELECT
         e.CompanyId,
		 e.Name,
         CAST(x.thePath + '.' + CONVERT(VARCHAR(900), e.CompanyId) AS VARCHAR(900)) AS thePath,
		 x.materializedPath  + CONVERT(VARCHAR(MAX), e.CompanyId) + '\' AS materializedPath,
         x.Level + 1 AS Level
     FROM CompanyLevels x
     JOIN AdjacencyList.Company e on e.ParentCompanyId = x.CompanyId
 ),
 CompanyRows AS
 (
     SELECT
          CompanyLevels.*,
          ROW_NUMBER() OVER (ORDER BY thePath) AS Row
     FROM CompanyLevels
 )
 SELECT *
 INTO #CompanyRows
 FROM   CompanyRows
 
 CREATE INDEX Path ON #CompanyRows (thePath)


 SET IDENTITY_INSERT NestedSets.Company ON 
GO

 INSERT INTO NestedSets.Company(CompanyId, Name, HierarchyLeft, HierarchyRight)
 SELECT  ER.CompanyId,
		Er.Name,
      (ER.Row * 2) - ER.Level AS Lft,
      ((ER.Row * 2) - ER.Level) + 
         (
             SELECT COUNT(*) * 2
             FROM #CompanyRows ER2 
             WHERE ER2.thePath LIKE ER.thePath + '.%'
         ) + 1 AS Rgt
 FROM #CompanyRows ER
 GO
 SET IDENTITY_INSERT NestedSets.Company OFF
 GO
 DROP table #CompanyRows
GO
SET IDENTITY_INSERT NestedSets.Sale ON 
GO
INSERT INTO NestedSets.Sale(SalesId, TransactionNumber, Amount, CompanyId)
 SELECT SalesId, TransactionNumber, Amount, CompanyId
 FROM   AdjacencyList.Sale
go
SET IDENTITY_INSERT NestedSets.Sale OFF
GO
