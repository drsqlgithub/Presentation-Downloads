USE HowToOptimizeAHierarchyInSQLServer
GO

DELETE HierarchyId.Sale
DELETE HierarchyId.Company 
go

SET IDENTITY_INSERT HierarchyId.Company ON 
GO
WITH CompanyLevels AS
 (
     SELECT
         CompanyId,
		 Name,
         CONVERT(VARCHAR(MAX), CompanyId) AS thePath,
		 CONVERT(VARCHAR(MAX), '/'+ CAST(CompanyId AS VARCHAR(10)) + '/') AS materializedPath,
         1 AS Level
     FROM AdjacencyList.Company
     WHERE ParentCompanyId IS NULL

     UNION ALL

     SELECT
         e.CompanyId,
		 e.Name,
         x.thePath + '.' + CONVERT(VARCHAR(MAX), e.CompanyId) AS thePath,
		 x.materializedPath  + CONVERT(VARCHAR(MAX), e.CompanyId) + '/' AS materializedPath,
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

 INSERT INTO HierarchyId.Company(CompanyId, Name, CompanyOrgNode)
 SELECT  ER.CompanyId,
		Er.Name,
        cast(MaterializedPath as HierarchyId)
 FROM CompanyRows ER
 ORDER BY thePath
 GO
 SET IDENTITY_INSERT HierarchyId.Company OFF
GO

SET IDENTITY_INSERT HierarchyId.Sale ON 
GO
INSERT INTO HierarchyId.Sale(SalesId, TransactionNumber, Amount, CompanyId)
 SELECT SalesId, TransactionNumber, Amount, CompanyId
 FROM   AdjacencyList.Sale
go
SET IDENTITY_INSERT HierarchyId.Sale OFF
GO
