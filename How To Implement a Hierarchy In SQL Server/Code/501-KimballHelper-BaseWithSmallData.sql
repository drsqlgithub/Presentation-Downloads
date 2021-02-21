
--Uses AdjacencyList example as basis. Reset the example

USE HowToOptimizeAHierarchyInSQLServer;
GO

/*
--if you want to reset the tree to original state
DELETE AdjacencyList.Sale
DELETE AdjacencyList.Company 
DBCC CHECKIDENT ('AdjacencyList.Sale',RESEED,0)
DBCC CHECKIDENT ('AdjacencyList.Company',RESEED,0)
ALTER SEQUENCE AdjacencyList.CompanyDataGenerator_SEQUENCE RESTART
EXEC AdjacencyList.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;
EXEC AdjacencyList.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';
EXEC AdjacencyList.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';
EXEC AdjacencyList.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';
EXEC AdjacencyList.Sale$InsertTestData @Name = 'Nashville Branch';
EXEC AdjacencyList.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';
EXEC AdjacencyList.Sale$InsertTestData @Name = 'Knoxville Branch';
EXEC AdjacencyList.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';
EXEC AdjacencyList.Sale$InsertTestData @Name = 'Memphis Branch';
EXEC AdjacencyList.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';
EXEC AdjacencyList.Sale$InsertTestData @Name = 'Portland Branch';
EXEC AdjacencyList.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';
EXEC AdjacencyList.Sale$InsertTestData @Name = 'Camden Branch';
*/

DROP PROCEDURE IF EXISTS KimballHelper.CompanyHierarchyHelper$Rebuild;
DROP FUNCTION IF EXISTS AdjacencyList.Company$returnHierarchyHelper;
DROP TABLE IF EXISTS KimballHelper.CompanyHierarchyHelper;

DROP SCHEMA IF EXISTS KimballHelper;
GO

CREATE SCHEMA KimballHelper;
GO

CREATE TABLE KimballHelper.CompanyHierarchyHelper
(
    ParentCompanyId    int,
    ChildCompanyId     int,
    Distance           int,
    ParentRootNodeFlag bit,
    ChildLeafNodeFlag  bit,
    CONSTRAINT PKCompanyHierarchyHelper PRIMARY KEY
    (
        ParentCompanyId,
        ChildCompanyId)
);
GO

SELECT Company.CompanyId, Company.Name, Company.ParentCompanyId
FROM   AdjacencyList.Company;
GO