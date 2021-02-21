
USE HowToOptimizeAHierarchyInSQLServer;
GO

--all data
--all data
SELECT  *,
        CASE WHEN NOT EXISTS 
			( SELECT   *
              FROM     GappedNestedSets.Company AS InCompany
              WHERE    EXISTS ( SELECT *
                                FROM   GappedNestedSets.Company AS startingPoint
                                WHERE  InCompany.HierarchyLeft > startingPoint.HierarchyLeft
                                  AND  InCompany.HierarchyLeft < startingPoint.HierarchyRight
                                  AND  startingPoint.CompanyId = Company.CompanyId ) )
             THEN 1 ELSE 0 END AS rootNodeFlag
FROM    GappedNestedSets.Company
GO

--Hence I am removing the rootNodeFlag from the queries going forward... 

--not including the node you asked for
select *
from   GappedNestedSets.Company
where  exists (select *
				from GappedNestedSets.Company as startingPoint
				where Company.HierarchyLeft > startingPoint.HierarchyLeft
				  and Company.HierarchyLeft < startingPoint.HierarchyRight
				  and startingPoint.Name = 'Tennessee HQ')
GO




--tennessee children, including parent (tenn hq is 8 and 15)

DECLARE @HierarchyLeft INT, @HierarchyRight INT
SELECT @HierarchyLeft = HierarchyLeft, @HierarchyRight = HierarchyRight
FROM   GappedNestedSets.Company
WHERE  Name = 'Tennessee HQ'

select *
from   GappedNestedSets.Company
where  HierarchyLeft >= @HierarchyLeft and HierarchyLeft <= @HierarchyRight
GO


--single statement, including node asked for
select *
from   GappedNestedSets.Company
where  exists (select *
				from GappedNestedSets.Company as startingPoint
				where Company.HierarchyLeft >= startingPoint.HierarchyLeft
				  and Company.HierarchyLeft <= startingPoint.HierarchyRight
				  and startingPoint.Name = 'Tennessee HQ')
GO

--not including the node you asked for
select *
from   GappedNestedSets.Company
where  exists (select *
				from GappedNestedSets.Company as startingPoint
				where Company.HierarchyLeft > startingPoint.HierarchyLeft
				  and Company.HierarchyLeft < startingPoint.HierarchyRight
				  and startingPoint.Name = 'Tennessee HQ')
GO

--for parents, need to look at left and right. This query will be more costly, but quite rare to
--do in bulk
select *
from   GappedNestedSets.Company
where  exists (select *
				from GappedNestedSets.Company as startingPoint
				where Company.HierarchyLeft <= startingPoint.HierarchyLeft --left is less than
				  and Company.HierarchyRight >= startingPoint.HierarchyRight --right is greater than
				  and startingPoint.Name = 'Nashville Branch')               --those two whittle it down to the single Pathe
GO


--for parents only
select *
from   GappedNestedSets.Company
where  exists (select *
				from GappedNestedSets.Company as startingPoint
				where Company.HierarchyLeft < startingPoint.HierarchyLeft
				  and Company.HierarchyRight > startingPoint.HierarchyRight
				  and startingPoint.Name = 'Nashville Branch')
GO

--using a join, if you needed both sets of data in output
select *
from   GappedNestedSets.Company as CompanyParent
		 join GappedNestedSets.Company as CompanyChild
				on CompanyChild.HierarchyLeft between CompanyParent.HierarchyLeft and CompanyParent.HierarchyRight
where  CompanyChild.Name = 'Camden Branch'
GO

--And for camden branch, parents
select *
from   GappedNestedSets.Company
where  exists (select *
				from GappedNestedSets.Company as startingPoint
				where Company.HierarchyLeft <= startingPoint.HierarchyLeft
				  and Company.HierarchyRight >= startingPoint.HierarchyRight
				  and startingPoint.Name = 'Camden Branch')
GO


Create PROCEDURE GappedNestedSets.Company$reparent
(
    @Location VARCHAR(20) ,
    @NewParentLocation VARCHAR(20) 
) as
--freaky messy, may be an easier way, but I didn't see any examples online that were better!
set nocount on
	--makes sure that you aren't moving the node to be a child of another node in the same tree..
	if exists (select *
				from   GappedNestedSets.Company
							join GappedNestedSets.Company as searchFor
								on Company.HierarchyLeft >= searchFor.HierarchyLeft 
								   and Company.HierarchyLeft <= searchFor.HierarchyRight
				where  searchFor.Name = @Location
				  and  Company.Name = @NewParentLocation)
	   BEGIN 
			 THROW 50000,'Cannot make a child node a node''s parent in a single pass. Move child node first',1;
			 Return 
	   END

	SET XACT_ABORT ON 
	--do this work in a transaction. Lots of modifications
	begin transaction

	--get the information about the the nodes we are going to move, 
	declare @numNodesToMove int, @startNode int, @endNode int
	SELECT @numNodesToMove = count(*),@startNode = min(searchFor.HierarchyLeft), @endNode = max(searchFor.HierarchyRight)
	from   GappedNestedSets.Company
				join GappedNestedSets.Company as searchFor
					on Company.HierarchyLeft >= searchFor.HierarchyLeft 
						and Company.HierarchyRight <= searchFor.HierarchyRight
	where  searchFor.Name = @Location

	--select @numNodesToMove, @startNode, @endNode

	--set the Hierarchy values to be negative to remove them from the Hierarchy. We'll put them back later
	--in the process
	UPDATE Company
	set    HierarchyLeft = -1 * Company.HierarchyLeft,
		   HierarchyRight = -1 * Company.HierarchyRight
	from   GappedNestedSets.Company
				join GappedNestedSets.Company as searchFor
					on Company.HierarchyLeft >= searchFor.HierarchyLeft 
					   and Company.HierarchyRight <= searchFor.HierarchyRight
	where  searchFor.Name = @Location

	--select 'check rows being moved', *
	--from   GappedNestedSets.Company
	--order by Hierarchyleft


	--get the position of the location where we are going to put the nodes we removed.
	declare @targetLeft int, @targetRight int
	select @targetLeft = HierarchyLeft, @targetRight = HierarchyRight
	from   GappedNestedSets.Company
	where  Name =  @NewParentLocation


	--select @numNodesToMove, @startNode, @endNode

	--make room for the nodes you are moving
	UPDATE GappedNestedSets.Company 
	SET	   HierarchyLeft = Company.HierarchyLeft + (1 + @numNodesToMove * ((@endNode - @startNode) / @numNodesToMove))
	WHERE  HierarchyLeft > @targetLeft

	UPDATE GappedNestedSets.Company 
	SET	   HierarchyRight = Company.HierarchyRight + (1 + @numNodesToMove * ((@endNode - @startNode) / @numNodesToMove))
	WHERE  HierarchyRight > @targetLeft


	--select 'room has been made', *
	--from   GappedNestedSets.Company
	--order by Hierarchyleft


	--get the offset that we will use to make the negative rows look like a proper negative Hierarchy
	declare @moveFactor int
	select @moveFactor = abs(max(HierarchyLeft) + 1)
	from   GappedNestedSets.Company
	where  HierarchyLeft < 0

	--fix the negative rows to look like a proper Hierarchy, 
	update GappedNestedSets.Company
	set    HierarchyLeft = (HierarchyLeft + @moveFactor) , 
			HierarchyRight = (HierarchyRight + @moveFactor) 
	where  HierarchyLeft < 0

	--then place rows into Hierarchy
	update GappedNestedSets.Company
	set    HierarchyLeft = (abs(HierarchyLeft) + @targetLeft)
		   ,HierarchyRight = abs(HierarchyRight) + @targetLeft
	where  HierarchyRight < 0

commit
go

--BEGIN TRANSACTION

select *
from   GappedNestedSets.Company
order by HierarchyLeft
GO
EXEC GappedNestedSets.Company$reparent 'Maine HQ','Tennessee HQ'
go

select *
from   GappedNestedSets.Company
order by HierarchyLeft
GO

--select *
--from   GappedNestedSets.Company
--order by HierarchyLeft

--EXEC GappedNestedSets.Company$reparent 'Maine HQ','Company HQ'
--go
--select *
--from   GappedNestedSets.Company
--order by HierarchyLeft
--GO
--EXEC GappedNestedSets.Company$reparent 'Nashville Branch','Maine HQ'
--go
--select *
--from   GappedNestedSets.Company
--order by HierarchyLeft
--GO
--EXEC GappedNestedSets.Company$reparent 'Nashville Branch','Company HQ'
--go
--select *
--from   GappedNestedSets.Company
--order by HierarchyLeft
--GO
--EXEC GappedNestedSets.Company$reparent 'Nashville Branch','Tennessee HQ'
--go
--select *
--from   GappedNestedSets.Company
--order by HierarchyLeft

--ROLLBACK 


-------------------
--Deleting a node

CREATE PROCEDURE GappedNestedSets.Company$Delete
@Name VARCHAR(20),
@DeleteChildRowsFlag BIT = 0
AS

BEGIN
	SET NOCOUNT ON 
	DECLARE @CompanyId int = (select CompanyId 
							  from GappedNestedSets.Company 
							  where Name = @Name);
  
	IF @CompanyId IS NULL	
	  BEGIN	
	   THROW 50000,'Invalid Company Name passed in',1;
	   RETURN -100;
	  END
  
    IF @DeleteChildRowsFlag = 0
	 BEGIN	
		IF EXISTS (	--see if the node has any children
					select *
					from   GappedNestedSets.Company
					where  exists (select *
									from GappedNestedSets.Company as startingPoint
									--uses >< and not <= >= since we only want children, not the node itself
									where Company.HierarchyLeft > startingPoint.HierarchyLeft
									  and Company.HierarchyLeft < startingPoint.HierarchyRight
									  and startingPoint.CompanyId = @CompanyId)
					)
																	    
		  BEGIN	
		   THROW 50000,'Child nodes exist for Company passed in to delete and parameter said to not delete them.',1;
		   RETURN -100;
		  END
	 END
     
	SET XACT_ABORT ON --simple error management for ease of demo
	BEGIN TRANSACTION

	DECLARE @startNode int
	
	----use numNodesToMove to figure out how much space to remove later
	--declare @numNodesToMove INT
	----count the nodes we are going to delete      
	--SELECT @numNodesToMove = count(*), @startNode = min(searchFor.HierarchyLeft)  
	--from   GappedNestedSets.Company
	--		join GappedNestedSets.Company as searchFor
	--			on Company.HierarchyLeft >= searchFor.HierarchyLeft 
	--				and Company.HierarchyLeft <= searchFor.HierarchyRight
	--where  searchFor.CompanyId = @CompanyId

	--delete all of the nodes that we are deleting, 1 only or children too has been settled
	DELETE GappedNestedSets.Company
	from   GappedNestedSets.Company
	where  exists (select *
					from GappedNestedSets.Company as startingPoint
					where Company.HierarchyLeft >= startingPoint.HierarchyLeft
						and Company.HierarchyLeft <= startingPoint.HierarchyRight
						and startingPoint.CompanyId = @CompanyId)

	--Don't repair the Hierarchy. Gaps are acceptable
	----move the left values over
	--UPDATE GappedNestedSets.Company 
	--SET	   HierarchyLeft = Company.HierarchyLeft - (@numNodesToMove * 2)
	--WHERE  HierarchyLeft >= @startNode

	----move the right values over
	----done in seperate statements because of the largest HierarchyRight value
	--UPDATE GappedNestedSets.Company 
	--SET	   HierarchyRight = Company.HierarchyRight - (@numNodesToMove * 2)
	--WHERE  HierarchyRight >= @startNode

COMMIT TRANSACTION
END
GO

--add a few rows to test the delete. No activity rows because that would limit deletes
EXEC GappedNestedSets.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';
EXEC GappedNestedSets.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';
EXEC GappedNestedSets.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';

EXEC GappedNestedSets.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';
EXEC GappedNestedSets.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';
EXEC GappedNestedSets.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';
GO
SELECT *
FROM   GappedNestedSets.Company
ORDER BY HierarchyLeft
GO
--fails, has child rows
EXEC GappedNestedSets.Company$Delete @Name = 'Georgia HQ'
GO
--success
EXEC GappedNestedSets.Company$Delete @Name = 'Atlanta Branch'
GO
SELECT *
FROM   GappedNestedSets.Company
ORDER BY HierarchyLeft
GO
EXEC GappedNestedSets.Company$Delete @Name = 'Georgia HQ', @DeleteChildRowsFlag = 1
Go
SELECT *
FROM   GappedNestedSets.Company
ORDER BY HierarchyLeft
Go
EXEC GappedNestedSets.Company$Delete @Name = 'Texas HQ', @DeleteChildRowsFlag = 1
GO

SELECT *
FROM   GappedNestedSets.Company
ORDER BY HierarchyLeft

go

--For all nodes, get all of the children of the nodes. This will be used again
--in the Aggregation section
SELECT Company.CompanyId AS ParentCompanyId, ChildRows.CompanyId AS ChildCompanyId
FROM   GappedNestedSets.Company
		 JOIN GappedNestedSets.Company AS ChildRows
				On Company.HierarchyLeft >= ChildRows.HierarchyLeft
				  and Company.HierarchyLeft <= ChildRows.HierarchyRight

go



--aggregating over the Hierarchy
WITH ExpandedHierarchy AS
(
SELECT Company.CompanyId AS ParentCompanyId, Findrows.CompanyId AS ChildCompanyId
from   GappedNestedSets.Company
		 JOIN GappedNestedSets.Company AS FindRows
			ON FindRows.HierarchyLeft BETWEEN Company.HierarchyLeft AND Company.HierarchyRight
),
CompanyTotals AS
(
	SELECT CompanyId, SUM(Amount) AS TotalAmount
	FROM   GappedNestedSets.Sale
	GROUP BY CompanyId
),
Aggregations AS 
(
	SELECT ExpandedHierarchy.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
	FROM   ExpandedHierarchy
			 LEFT JOIN CompanyTotals
				ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
	GROUP  BY ExpandedHierarchy.ParentCompanyId
)
SELECT Company.*, Aggregations.TotalSalesAmount
FROM   GappedNestedSets.Company
		 JOIN Aggregations
		 ON Company.CompanyId = Aggregations.ParentCompanyId
