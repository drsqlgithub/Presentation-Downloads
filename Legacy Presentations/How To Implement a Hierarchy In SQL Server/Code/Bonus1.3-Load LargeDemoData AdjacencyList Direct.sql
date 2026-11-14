USE HowToOptimizeAHierarchyInSQLServer
go
DELETE AdjacencyList.Sale
DELETE AdjacencyList.Company 
DBCC CHECKIDENT ('AdjacencyList.Sale',RESEED,0)
DBCC CHECKIDENT ('AdjacencyList.Company',RESEED,0)
ALTER SEQUENCE AdjacencyList.CompanyDataGenerator_SEQUENCE RESTART
go
SET IDENTITY_INSERT AdjacencyList.Company ON
go
INSERT INTO AdjacencyList.Company(CompanyId, ParentCompanyId, Name)
SELECT CAST(SUBSTRING(CHildName,5,10) AS INT) AS CompanyId,
	   CAST(SUBSTRING(ParentName,5,10) AS INT) AS ParentCompanyId,
	   ChildName AS Name
FROM DemoCreator.Hierarchy
go
SET IDENTITY_INSERT AdjacencyList.Company OFF
go

DECLARE @cursor CURSOR, @CompanyName VARCHAR(20)
SET @cursor = CURSOR FOR SELECT ChildName FROM DemoCreator.Hierarchy WHERE RootNodeFlag = 1 ORDER BY Level,parentName, ChildName
OPEN @cursor
WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @CompanyName
	IF @@FETCH_STATUS <> 0
		BREAK
    
	EXEC AdjacencyList.Sale$InsertTestData @Name = @CompanyName
 END
GO

SELECT COUNT(*)
FROM   adjacencyList.Company
SELECT COUNT(*)
FROM   adjacencyList.sale