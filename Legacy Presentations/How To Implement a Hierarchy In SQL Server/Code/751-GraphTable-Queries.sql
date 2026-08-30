USE HowToOptimizeAHierarchyInSQLServer;
GO

--===============================================================================
-- There is no syntactical way (currently?) to say give me all related rows by an edge
-- (Note, this was demoed at PASS Summit and will be coming in a future version)

-- One way this can be done is a level at a time, in syntax

--Root node
SELECT Company.Name AS Name, NULL AS ParentCompanyName, 0 AS Level
FROM   GraphTree.Company 
WHERE  NOT EXISTS (SELECT * 
				   FROM   GraphTree.Manages
				   WHERE  GraphTree.Manages.$to_id = Company.$node_id)

--direct reports
SELECT ParentCompany.Name, ChildCompany.Name AS ManagesCompanyName, 1 AS Level
FROM   GraphTree.Company AS ParentCompany, GraphTree.Manages, GraphTree.Company AS ChildCompany
WHERE  MATCH(ParentCompany-(Manages)->ChildCompany)
  AND  ParentCompany.Name = 'Company HQ';

--second level reports
SELECT ParentCompany.Name, ChildCompany2.Name AS ManagesCompanyName, 2 AS Level
FROM   GraphTree.Company AS ParentCompany, GraphTree.Manages, GraphTree.Company AS ChildCompany,
       GraphTree.Manages AS Manages2, GraphTree.Company AS ChildCompany2
WHERE  MATCH(ParentCompany-(Manages)->ChildCompany-(Manages2)->ChildCompany2)
  AND  ParentCompany.Name = 'Company HQ';

 --third level reports
SELECT ParentCompany.Name, ChildCompany3.Name AS ManagesCompanyName, 3 AS Level
FROM   GraphTree.Company AS ParentCompany, GraphTree.Manages, GraphTree.Company AS ChildCompany,
       GraphTree.Manages AS Manages2, GraphTree.Company AS ChildCompany2,
       GraphTree.Manages AS Manages3, GraphTree.Company AS ChildCompany3
WHERE  MATCH(ParentCompany-(Manages)->ChildCompany-(Manages2)->ChildCompany2-(Manages3)->ChildCompany3)
  AND  ParentCompany.Name = 'Company HQ';

  

--===============================================================================
--getting all of the children of a  node (I am assuming just one (another decent thing to require in your
--hierarchies, could call it "root" or "all), but it could be > 1 and it would require revising the query a bit

DECLARE @ParentCompanyName nvarchar(60)= 'Company HQ';

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
         NULL, --We will treat the top level node as not having a parent 
          1 AS TreeLevel,
          '\' + CAST(CompanyId as varchar(max)) +'\'
   FROM   GraphTree.Company
   WHERE  Name = @ParentCompanyName

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          ParentCompany.CompanyId AS ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   CompanyHierarchy, GraphTree.Company, GraphTree.Company AS ParentCompany, GraphTree.Manages
   WHERE  CompanyHierarchy.CompanyId = ParentCompany.CompanyId
	      --use to get children, since the ParentCompanyId of the child will be set the value
		  --of the current row (always confuses me a bit :)
	 AND  MATCH(ParentCompany-(Manages)->Company)
		  --Company.ParentCompanyId = CompanyHierarchy.CompanyId
          --use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
		  --not the parent.
	 --AND  MATCH(ParentCompany<-(Manages)-Company)
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
		 CompanyHierarchy.ParentCompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     GraphTree.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO



--===============================================================================
--
CREATE PROCEDURE GraphTree.Company$Reparent
(
    @Name                 varchar(20),
    @NewParentCompanyName varchar(20)
)
AS
BEGIN
	--Cannot update an edge, so you have to delete it

	DELETE FROM GraphTree.Manages
	WHERE  $to_id = (SELECT $node_id FROM GraphTree.Company WHERE Name = @name)

	INSERT INTO GraphTree.Manages ($From_id, $To_id)
	SELECT (SELECT $NODE_ID FROM GraphTree.Company WHERE Name = @NewParentCompanyName),
			(SELECT $NODE_ID FROM GraphTree.Company WHERE Name = @Name);

	IF @@ROWCOUNT = 0
		THROW 50000,'Something went wrong inserting new Manages edge',1;

END;
GO

EXEC GraphTree.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Tennessee HQ';
GO

--===============================================================================
--getting all of the children of a  node (I am assuming just one (another decent thing to require in your
--hierarchies, could call it "root" or "all), but it could be > 1 and it would require revising the query a bit

DECLARE @ParentCompanyName nvarchar(60)= 'Company HQ';



WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
         NULL, --We will treat the top level node as not having a parent 
          1 AS TreeLevel,
          '\' + CAST(CompanyId as varchar(max)) +'\'
   FROM   GraphTree.Company
   WHERE  Name = @ParentCompanyName

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          ParentCompany.CompanyId AS ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   CompanyHierarchy, GraphTree.Company, GraphTree.Company AS ParentCompany, GraphTree.Manages
   WHERE  CompanyHierarchy.CompanyId = ParentCompany.CompanyId
	      --use to get children, since the ParentCompanyId of the child will be set the value
		  --of the current row (always confuses me a bit :)
	 AND  MATCH(ParentCompany-(Manages)->Company)
		  --Company.ParentCompanyId = CompanyHierarchy.CompanyId
          --use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
		  --not the parent.
	 --AND  MATCH(ParentCompany<-(Manages)-Company)
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
		 CompanyHierarchy.ParentCompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     GraphTree.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO

--put it back
EXEC GraphTree.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Company HQ';
GO


--===============================================================================
--Deleting a node

--our delete either delete a leaf node, or deletes everything along with the 
--node... --a bit more error handling here because it is a bit more complex in nature

CREATE OR ALTER PROCEDURE GraphTree.Company$Delete
    @Name                varchar(20),
    @DeleteChildRowsFlag bit = 0
AS

BEGIN
    DECLARE @CompanyId int = (   SELECT CompanyId
                                 FROM   GraphTree.Company
                                 WHERE  Name = @Name);

    IF @CompanyId IS NULL
    BEGIN
        THROW 50000, 'Invalid Company Name passed in', 1;

        RETURN -100;
    END;

    SET XACT_ABORT ON; --simple error management for ease of demo

    BEGIN TRANSACTION;

    IF @DeleteChildRowsFlag = 0 --don't delete children
    BEGIN
		IF EXISTS (
			--just see if any direct reports exist
			SELECT ParentCompany.Name, ChildCompany.Name AS ManagesCompanyName, 1 AS Level
			FROM   GraphTree.Company AS ParentCompany, GraphTree.Manages, GraphTree.Company AS ChildCompany
			WHERE  MATCH(ParentCompany-(Manages)->ChildCompany)
			  AND  ParentCompany.CompanyId = @CompanyId)
		   THROW 50000,'Child rows exist for this company. Use @deleteChildRowsFlag to delete the child rows',1;
		
		DELETE GraphTree.Manages
		WHERE  $to_id = (SELECT $NODE_ID FROM GraphTree.Company WHERE CompanyId = @CompanyId)

        --we are trusting the foreign key constraint to make sure that there     
        --are no orphaned rows
        DELETE GraphTree.Company
        WHERE CompanyId = @CompanyId;
    END;
    ELSE
    BEGIN
        --deleting all of the child rows, just uses the recursive CTE with a DELETE rather than a 
        --SELECT

			DECLARE @deleteThese TABLE (CompanyId int);
        
			WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
			AS (
			   --gets the top level in Hierarchy we want. The Hierarchy column
			   --will show the row's place in the Hierarchy from this query only
			   --not in the overall reality of the row's place in the table
			   SELECT CompanyId,
					 NULL, --We will treat the top level node as not having a parent 
					  1 AS TreeLevel,
					  '\' + CAST(CompanyId as varchar(max)) +'\'
			   FROM   GraphTree.Company
			   WHERE CompanyId = @CompanyId

			   UNION ALL

			   --joins back to the CTE to recursively retrieve the rows 
			   --note that TreeLevel is incremented on each iteration
			   SELECT Company.CompanyId,
					  ParentCompany.CompanyId AS ParentCompanyId,
					  TreeLevel + 1 AS TreeLevel,
					  Hierarchy + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
			   FROM   CompanyHierarchy, GraphTree.Company, GraphTree.Company AS ParentCompany, GraphTree.Manages
			   WHERE  CompanyHierarchy.CompanyId = ParentCompany.CompanyId
					  --use to get children, since the ParentCompanyId of the child will be set the value
					  --of the current row (always confuses me a bit :)
				 AND  MATCH(ParentCompany-(Manages)->Company)
					  --Company.ParentCompanyId = CompanyHierarchy.CompanyId
					  --use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
					  --not the parent.
				 --AND  MATCH(ParentCompany<-(Manages)-Company)
			)
        INSERT INTO @deleteThese --uses a temp table because I need to delete the company and anything it manages
		SELECT CompanyId
        FROM CompanyHierarchy;

		DELETE GraphTree.Manages
		WHERE  $to_id IN (SELECT $NODE_ID 
						 FROM GraphTree.Company 
						 WHERE CompanyId IN (SELECT CompanyId FROM @deleteThese));

        DELETE GraphTree.Company
		WHERE CompanyId IN (SELECT CompanyId FROM @deleteThese);


    END;


    COMMIT TRANSACTION;
END;
GO

--add a few rows to test the delete. No activity rows because that would limit deletes
EXEC GraphTree.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';

EXEC GraphTree.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';

EXEC GraphTree.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';

EXEC GraphTree.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';

EXEC GraphTree.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';

EXEC GraphTree.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';
GO

-===============================================================================
--getting all of the children of a  node (I am assuming just one (another decent thing to require in your
--hierarchies, could call it "root" or "all), but it could be > 1 and it would require revising the query a bit

DECLARE @ParentCompanyName nvarchar(60)= 'Company HQ';



WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
         NULL, --We will treat the top level node as not having a parent 
          1 AS TreeLevel,
          '\' + CAST(CompanyId as varchar(max)) +'\'
   FROM   GraphTree.Company
   WHERE  Name = @ParentCompanyName

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          ParentCompany.CompanyId AS ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   CompanyHierarchy, GraphTree.Company, GraphTree.Company AS ParentCompany, GraphTree.Manages
   WHERE  CompanyHierarchy.CompanyId = ParentCompany.CompanyId
	      --use to get children, since the ParentCompanyId of the child will be set the value
		  --of the current row (always confuses me a bit :)
	 AND  MATCH(ParentCompany-(Manages)->Company)
		  --Company.ParentCompanyId = CompanyHierarchy.CompanyId
          --use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
		  --not the parent.
	 --AND  MATCH(ParentCompany<-(Manages)-Company)
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
		 CompanyHierarchy.ParentCompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     GraphTree.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO
--===============================================================================

--try to delete Georgia
EXEC GraphTree.Company$Delete @Name = 'Georgia HQ';
GO

--delete Atlanta
EXEC GraphTree.Company$Delete @Name = 'Atlanta Branch';
GO

SELECT *
FROM   GraphTree.Company;

EXEC GraphTree.Company$Delete @Name = 'Georgia HQ', @DeleteChildRowsFlag = 1;

SELECT *
FROM   GraphTree.Company;

EXEC GraphTree.Company$Delete @Name = 'Texas HQ', @DeleteChildRowsFlag = 1;

SELECT *
FROM   GraphTree.Company;

-----------------------------------
--Aggregating along a Hierarchy

--Inspired by:
--http://go4answers.webhost4life.com/Example/Hierarchy-aggregation-41974.aspx
--Thanks to Alejandro Mesa (Hunchback)


WITH ExpandedHierarchy
AS (
   --just get all of the nodes of the Hierarchy
   SELECT CompanyId AS AnchorCompanyId,
		  CompanyId AS ParentCompanyId,
		  CompanyId AS ChildCompanyId
   FROM   GraphTree.Company

   UNION ALL

   --get all of the children of each node for aggregating  

   SELECT AnchorCompanyId, ParentCompany.CompanyId AS ParentCompanyId, Company.CompanyId AS ChildCompanyId
   FROM   ExpandedHierarchy, GraphTree.Company, 
		  GraphTree.Company AS ParentCompany, GraphTree.Manages

   WHERE ExpandedHierarchy.ChildCompanyId = ParentCompany.CompanyId
     AND MATCH(ParentCompany-(Manages)->Company)
	 AND Company.CompanyId IS NOT NULL
)
SELECT AnchorCompanyId, ChildCompanyId
FROM   ExpandedHierarchy
ORDER BY AnchorCompanyId, ChildCompanyId;


--take the expanded Hierarchy...
WITH ExpandedHierarchy
AS (
   --just get all of the nodes of the Hierarchy
   SELECT CompanyId AS AnchorCompanyId,
		  CompanyId AS ParentCompanyId,
		  CompanyId AS ChildCompanyId
   FROM   GraphTree.Company

   UNION ALL

   --get all of the children of each node for aggregating  

   SELECT AnchorCompanyId, ParentCompany.CompanyId AS ParentCompanyId, Company.CompanyId AS ChildCompanyId
   FROM   ExpandedHierarchy, GraphTree.Company, 
		  GraphTree.Company AS ParentCompany, GraphTree.Manages

   WHERE ExpandedHierarchy.ChildCompanyId = ParentCompany.CompanyId
     AND MATCH(ParentCompany-(Manages)->Company)
	 AND Company.CompanyId IS NOT NULL
),
     --get totals for each Company for the aggregate
     CompanyTotals
AS (SELECT   CompanyId, SUM(Amount) AS TotalAmount
    FROM     GraphTree.Sale
    GROUP BY CompanyId),

     --aggregate each Company for the Company
     Aggregations
AS (SELECT   ExpandedHierarchy.AnchorCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
    FROM     ExpandedHierarchy
             LEFT JOIN CompanyTotals
                 ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
    GROUP BY ExpandedHierarchy.AnchorCompanyId)

--display the data...
SELECT   Company.CompanyId,  Aggregations.TotalSalesAmount
FROM     GraphTree.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.AnchorCompanyId
ORDER BY Company.CompanyId;
GO

