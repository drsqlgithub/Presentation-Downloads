USE HowToOptimizeAHierarchyInSQLServer
GO

DELETE PathMethod.Sale
DELETE PathMethod.Company 
go


WITH CompanyLevels AS
 (
     SELECT
         CompanyId,
		 Name,
         CONVERT(VARCHAR(MAX), CompanyId) AS thePath,
		 CONVERT(VARCHAR(MAX), '\'+ CAST(CompanyId AS VARCHAR(10)) + '\') AS materializedPath,
         1 AS Level
     FROM AdjacencyList.Company
     WHERE ParentCompanyId IS NULL

     UNION ALL

     SELECT
         e.CompanyId,
		 e.Name,
         x.thePath + '.' + CONVERT(VARCHAR(MAX), e.CompanyId) AS thePath,
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

 INSERT INTO PathMethod.Company(CompanyId, Name, Path)
 SELECT  ER.CompanyId,
		Er.Name,
        MaterializedPath
 FROM CompanyRows ER
 ORDER BY thePath
 GO


SET IDENTITY_INSERT PathMethod.Sale ON 
GO
INSERT INTO PathMethod.Sale(SalesId, TransactionNumber, Amount, CompanyId)
 SELECT SalesId, TransactionNumber, Amount, CompanyId
 FROM   AdjacencyList.Sale
go
SET IDENTITY_INSERT PathMethod.Sale OFF
GO
