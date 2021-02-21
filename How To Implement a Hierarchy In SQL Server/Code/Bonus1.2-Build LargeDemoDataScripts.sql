/*
This file is used to generate a script that we will use in the 02 files to performance test 
the algorithms. This way we get the exact same "random" data to build our demo cases with so 
we are comparing oranges to oranges
*/
USE HowToOptimizeAHierarchyInSQLServer
go
SET NOCOUNT ON 

SELECT 'USE HowToOptimizeAHierarchyInSQLServer
GO'


SELECT 'SET NOCOUNT ON
GO'

DECLARE @query VARCHAR(MAX);
DECLARE @schemaName sysName = 'AdjacencyList';
--DECLARE @schemaName sysName = 'HierarchyId';
--DECLARE @schemaName sysName = 'PathMethod';
--DECLARE @schemaName sysName = 'NestedSets';

SELECT @query = '
DELETE ' + @schemaName + '.Sale
DELETE ' + @schemaName + '.Company 
DBCC CHECKIDENT (' + QUOTEName(@schemaName + '.Sale','''') + ',RESEED,0)
DBCC CHECKIDENT (' + QUOTEName(@schemaName + '.Company','''') + ',RESEED,0)
ALTER SEQUENCE ' + @schemaName + '.CompanyDataGenerator_SEQUENCE RESTART
go
'
SELECT @query

IF @schemaName = 'PathMethod'
  SELECT 'ALTER SEQUENCE PathMethod.Company_SEQUENCE RESTART
go'


SELECT 'EXEC ' + @schemaName + '.Company$Insert @Name = ' + QUOTEName(childName,'''') 
								+ ', @ParentCompanyName = ' + CASE WHEN ParentName IS NULL THEN 'NULL' ELSE QUOTEName(ParentName,'''') END + '
GO
' + CASE WHEN Hierarchy.RootNodeFlag = 1 THEN 'EXEC ' + @schemaName + '.Sale$InsertTestData @Name = ' + + QUOTEName(childName,'''') ELSE '' END + '
GO'
FROM   DemoCreator.Hierarchy
ORDER BY Level,parentName, ChildName




