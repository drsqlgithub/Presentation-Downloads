USE HowToOptimizeAHierarchyInSQLServer;
GO

SELECT   CompanyId,
         CompanyOrgNode.GetLevel() AS level,
         Name,
         CompanyOrgNode.ToString() AS Hierarchy
FROM     HierarchyId.Company
ORDER BY Hierarchy;
GO

--get children of Company HQ
DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   HierarchyId.Company
                             WHERE  Name = 'Company HQ');

SELECT Target.CompanyId, Target.Name, Target.CompanyOrgNode.ToString() AS Hierarchy
FROM   HierarchyId.Company AS Target
       JOIN HierarchyId.Company AS SearchFor

           --get the nodes that are decendents of the search for rows
           ON SearchFor.CompanyId = @CompanyId
               AND Target.CompanyOrgNode.IsDescendantOf(SearchFor.CompanyOrgNode) = 1;
GO

--get children of Tennessee
DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   HierarchyId.Company
                             WHERE  Name = 'Tennessee HQ');

SELECT Target.CompanyId, Target.Name, Target.CompanyOrgNode.ToString() AS Hierarchy
FROM   HierarchyId.Company AS Target
       JOIN HierarchyId.Company AS SearchFor
           ON SearchFor.CompanyId = @CompanyId
               AND Target.CompanyOrgNode.IsDescendantOf(SearchFor.CompanyOrgNode) = 1;
GO

--get parents of Portland Branch
DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   HierarchyId.Company
                             WHERE  Name = 'Portland Branch');

SELECT Target.CompanyId, Target.Name, Target.CompanyOrgNode.ToString() AS Hierarchy
FROM   HierarchyId.Company AS Target
       JOIN HierarchyId.Company AS SearchFor --represents the one row that matches the search
           ON SearchFor.CompanyId = @CompanyId

               --get the nodes where the searched item is the decendent instead of the target rows
               AND SearchFor.CompanyOrgNode.IsDescendantOf --gets rows where the target is a 
                   (   Target.CompanyOrgNode) = 1;

--descendent of the search row

--** New (Get 1 level of child from table)
DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   HierarchyId.Company
                             WHERE  Name = 'Company HQ');

SELECT Target.CompanyId, Target.Name, Target.CompanyOrgNode.ToString() AS Hierarchy, *
FROM   HierarchyId.Company AS Target
       JOIN HierarchyId.Company AS SearchFor
           ON SearchFor.CompanyId = @CompanyId
               AND Target.CompanyOrgNode.IsDescendantOf(SearchFor.CompanyOrgNode) = 1
               AND SearchFor.OrganizationLevel = Target.OrganizationLevel - 1;

--**

--reparent Maine HQ to Child of Nashville
GO

--use procedure, adapted from http://technet.microsoft.com/en-us/library/bb677212(SQL.105).aspx
CREATE PROCEDURE HierarchyId.Company$Reparent
(
    @Location          varchar(20),
    @NewParentLocation varchar(20)
)
AS
BEGIN

    DECLARE @nnew Hierarchyid, --where we will put the rows
            @nold Hierarchyid = (   SELECT CompanyOrgNode --the parent of the node currently
                                    FROM   HierarchyId.Company
                                    WHERE  Name = @Location);

    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRANSACTION;

    SELECT @nnew = CompanyOrgNode --the Hierarchy location of the of the new location
    FROM   HierarchyId.Company
    WHERE  Name = @NewParentLocation;

    SELECT @nnew = @nnew.GetDescendant(MAX(CompanyOrgNode), NULL) --get the location of the last ancestor of @nnew
    FROM   HierarchyId.Company
    WHERE  CompanyOrgNode.GetAncestor(1) = @nnew; --1 is the number of levels to get

    UPDATE HierarchyId.Company
    SET    CompanyOrgNode = CompanyOrgNode.GetReparentedValue(@nold, --update the HierarchyId to the reparented value
                                                              @nnew)
    WHERE  CompanyOrgNode.IsDescendantOf(@nold) = 1; --for all decendents of the @nold that we are moving

    COMMIT TRANSACTION;
END;
GO

EXEC HierarchyId.Company$Reparent @Location = 'Maine HQ', @NewParentLocation = 'Tennessee HQ';
GO

SELECT   CompanyId,
         CompanyOrgNode.GetLevel() AS level,
         Name,
         CompanyOrgNode.ToString() AS Hierarchy
FROM     HierarchyId.Company
ORDER BY Hierarchy;
GO

--Getting ALL OF the children for every row, which we will come back to for Hierarchy aggregation 
--big difference is that we don't limit the rows we are searching for to one. We do the expansion for 
--every row

SELECT Company.CompanyId AS ParentCompanyId, ChildRows.CompanyId AS ChildCompanyId
FROM   HierarchyId.Company
       JOIN HierarchyId.Company AS ChildRows --represents the one row that matches the search
           ON ChildRows.CompanyOrgNode.IsDescendantOf --gets target rows that are descendants of
              (   Company.CompanyOrgNode) = 1;
GO

-------------------
--Deleting a node

CREATE PROCEDURE HierarchyId.Company$Delete
    @Name                varchar(20),
    @DeleteChildRowsFlag bit = 0
AS

BEGIN
    DECLARE @CompanyId int = (   SELECT CompanyId
                                 FROM   HierarchyId.Company
                                 WHERE  Name = @Name);

    IF @CompanyId IS NULL
    BEGIN
        THROW 50000, 'Invalid Company Name passed in', 1;

        RETURN -100;
    END;

    IF @DeleteChildRowsFlag = 0
    BEGIN --check to see if child nodes exist
        IF EXISTS (   SELECT Target.CompanyId, Target.Name, Target.CompanyOrgNode.ToString() AS Hierarchy
                      FROM   HierarchyId.Company AS Target
                             JOIN HierarchyId.Company AS SearchFor
                                 ON SearchFor.CompanyId = @CompanyId
                                     AND Target.CompanyOrgNode.IsDescendantOf(SearchFor.CompanyOrgNode) = 1
                      WHERE  Target.CompanyId <> @CompanyId)

        BEGIN
            THROW 50000, 'Child nodes exist for Company passed in to delete and parameter said to not delete them.', 1;

            RETURN -100;
        END;
    END;

    SET XACT_ABORT ON; --simple transaction management for ease of demo

    BEGIN TRANSACTION;

    --we have already checked to see if child rows exist and shouldn't, so we can use the same delete for both
    --single and multi-row deletes...
    DELETE Target
    FROM HierarchyId.Company AS Target
         JOIN HierarchyId.Company AS SearchFor
             ON SearchFor.CompanyId = @CompanyId
                 AND Target.CompanyOrgNode.IsDescendantOf(SearchFor.CompanyOrgNode) = 1;

    COMMIT TRANSACTION;
END;
GO

--add a few rows to test the delete. No activity rows because that would limit deletes
EXEC HierarchyId.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';

EXEC HierarchyId.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';

EXEC HierarchyId.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';

EXEC HierarchyId.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';

EXEC HierarchyId.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';

EXEC HierarchyId.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';

SELECT   CompanyId,
         CompanyOrgNode.GetLevel() AS level,
         Name,
         CompanyOrgNode.ToString() AS Hierarchy
FROM     HierarchyId.Company
ORDER BY Hierarchy;

--errors due to child rows
EXEC HierarchyId.Company$Delete @Name = 'Georgia HQ';
GO

--works..
EXEC HierarchyId.Company$Delete @Name = 'Atlanta Branch';
GO

SELECT   CompanyId,
         CompanyOrgNode.GetLevel() AS level,
         Name,
         CompanyOrgNode.ToString() AS Hierarchy
FROM     HierarchyId.Company
ORDER BY Hierarchy;

--leaves a gap..., but that is fine (this is why I added new rows, to show the gap :)
EXEC HierarchyId.Company$Delete @Name = 'Georgia HQ', @DeleteChildRowsFlag = 1;

SELECT   CompanyId,
         CompanyOrgNode.GetLevel() AS level,
         Name,
         CompanyOrgNode.ToString() AS Hierarchy
FROM     HierarchyId.Company
ORDER BY Hierarchy;

--removes the Texas Node and its children
EXEC HierarchyId.Company$Delete @Name = 'Texas HQ', @DeleteChildRowsFlag = 1;

SELECT   CompanyId,
         CompanyOrgNode.GetLevel() AS level,
         Name,
         CompanyOrgNode.ToString() AS Hierarchy
FROM     HierarchyId.Company
ORDER BY Hierarchy;
GO

--aggregating the Hierarchy

WITH ExpandedHierarchy
AS --for every Company row, get that node and all children for the aggregating in a later CTE
(SELECT Company.CompanyId AS ParentCompanyId, ChildRows.CompanyId AS ChildCompanyId
 FROM   HierarchyId.Company
        JOIN HierarchyId.Company AS ChildRows --represents the one row that matches the search
            ON ChildRows.CompanyOrgNode.IsDescendantOf --gets target rows that are descendants of
               (   Company.CompanyOrgNode) = 1),
     CompanyTotals
AS (SELECT   CompanyId, SUM(Amount) AS TotalAmount
    FROM     HierarchyId.Sale
    GROUP BY CompanyId)

,
     Aggregations
AS (SELECT   ExpandedHierarchy.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
    FROM     ExpandedHierarchy
             JOIN CompanyTotals
                 ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
    GROUP BY ExpandedHierarchy.ParentCompanyId)
SELECT   Company.CompanyId, Company.ParentCompanyId, Aggregations.TotalSalesAmount
FROM     AdjacencyList.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Company.CompanyId;
