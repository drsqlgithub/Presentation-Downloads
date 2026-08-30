
USE HowToOptimizeAHierarchyInSQLServer;
GO

--all data
select *, case when HierarchyLeft = HierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   NestedSets.Company
order by HierarchyLeft
GO

--tennessee children, including parent (tenn hq is 8 and 15)

DECLARE @HierarchyLeft INT, @HierarchyRight INT
SELECT @HierarchyLeft = HierarchyLeft, @HierarchyRight = HierarchyRight
FROM   NestedSets.Company
WHERE  Name = 'Tennessee HQ'

select *, case when HierarchyLeft = HierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   NestedSets.Company
where  HierarchyLeft >= @HierarchyLeft and HierarchyLeft <= @HierarchyRight
GO


--single statement, including node asked for
select *, case when HierarchyLeft = HierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   NestedSets.Company
where  exists (select *
				from NestedSets.Company as startingPoint
				where Company.HierarchyLeft >= startingPoint.HierarchyLeft
				  and Company.HierarchyLeft <= startingPoint.HierarchyRight
				  and startingPoint.Name = 'Tennessee HQ')
GO

--not including the node you asked for
select *, case when HierarchyLeft = HierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   NestedSets.Company
where  exists (select *
				from NestedSets.Company as startingPoint
				where Company.HierarchyLeft > startingPoint.HierarchyLeft
				  and Company.HierarchyLeft < startingPoint.HierarchyRight
				  and startingPoint.Name = 'Tennessee HQ')
GO

--for parents, need to look at left and right. This query will be more costly, but quite rare to
--do in bulk
select *, case when HierarchyLeft = HierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   NestedSets.Company
where  exists (select *
				from NestedSets.Company as startingPoint
				where Company.HierarchyLeft <= startingPoint.HierarchyLeft --left is less than
				  and Company.HierarchyRight >= startingPoint.HierarchyRight --right is greater than
				  and startingPoint.Name = 'Nashville Branch')               --those two whittle it down to the single Pathe
GO


--for parents only
select *, case when HierarchyLeft = HierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   NestedSets.Company
where  exists (select *
				from NestedSets.Company as startingPoint
				where Company.HierarchyLeft < startingPoint.HierarchyLeft
				  and Company.HierarchyRight > startingPoint.HierarchyRight
				  and startingPoint.Name = 'Nashville Branch')
GO

--using a join, if you needed both sets of data in output
select *
from   NestedSets.Company as CompanyParent
		 join NestedSets.Company as CompanyChild
				on CompanyChild.HierarchyLeft between CompanyParent.HierarchyLeft and CompanyParent.HierarchyRight
where  CompanyChild.Name = 'Camden Branch'
GO

--And for camden branch, parents
select *, case when HierarchyLeft = HierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   NestedSets.Company
where  exists (select *
				from NestedSets.Company as startingPoint
				where Company.HierarchyLeft <= startingPoint.HierarchyLeft
				  and Company.HierarchyRight >= startingPoint.HierarchyRight
				  and startingPoint.Name = 'Camden Branch')
GO

--**-- Get 1 level of parents below the node

--??? Not sure how to solve for this without more metadata stored...

--**--

CREATE PROCEDURE NestedSets.Company$reparent
(
    @Location VARCHAR(20) ,
    @NewParentLocation VARCHAR(20) 
) as
--freaky messy, may be an easier way, but I didn't see any examples online that were better!

	--makes sure that you aren't moving the node to be a child of another node in the same tree..
	if exists (select *
				from   NestedSets.Company
							join NestedSets.Company as searchFor
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
	declare @numNodesToMove int, @startNode int 
	SELECT @numNodesToMove = count(*),@startNode = min(searchFor.HierarchyLeft)  
	from   NestedSets.Company
				join NestedSets.Company as searchFor
					on Company.HierarchyLeft >= searchFor.HierarchyLeft 
						and Company.HierarchyRight <= searchFor.HierarchyRight
	where  searchFor.Name = @Location

	--set the Hierarchy values to be negative to remove them from the Hierarchy. We'll put them back later
	--in the process
	UPDATE Company
	set    HierarchyLeft = -1 * Company.HierarchyLeft,
		   HierarchyRight = -1 * Company.HierarchyRight
	from   NestedSets.Company
				join NestedSets.Company as searchFor
					on Company.HierarchyLeft >= searchFor.HierarchyLeft 
					   and Company.HierarchyRight <= searchFor.HierarchyRight
	where  searchFor.Name = @Location

	--refit the nodes to deal with the missing items. Now the positive values form a proper tree
	UPDATE NestedSets.Company 
	SET	   HierarchyLeft = Company.HierarchyLeft - (@numNodesToMove * 2)
	WHERE  HierarchyLeft >= @startNode

	--done in seperate statements because of the largest HierarchyRight value
	UPDATE NestedSets.Company 
	SET	   HierarchyRight = Company.HierarchyRight - (@numNodesToMove * 2)
	WHERE  HierarchyRight >= @startNode


	--get the position of the location where we are going to put the nodes we removed.
	declare @targetLeft int, @targetRight int
	select @targetLeft = HierarchyLeft, @targetRight = HierarchyRight
	from   NestedSets.Company
	where  Name =  @NewParentLocation

	--make room for the nodes you are moving
	UPDATE NestedSets.Company 
	SET	   HierarchyLeft = Company.HierarchyLeft + (@numNodesToMove * 2)
	WHERE  HierarchyLeft > @targetLeft

	UPDATE NestedSets.Company 
	SET	   HierarchyRight = Company.HierarchyRight + (@numNodesToMove * 2)
	WHERE  HierarchyRight > @targetLeft

	--get the offset that we will use to make the negative rows look like a proper negative Hierarchy
	declare @moveFactor int
	select @moveFactor = abs(max(HierarchyLeft) + 1)
	from   NestedSets.Company
	where  HierarchyLeft < 0

	--fix the negative rows to look like a proper Hierarchy, 
	update NestedSets.Company
	set    HierarchyLeft = (HierarchyLeft + @moveFactor) , 
			HierarchyRight = (HierarchyRight + @moveFactor) 
	where  HierarchyLeft < 0

	--then place rows into Hierarchy
	update NestedSets.Company
	set    HierarchyLeft = (abs(HierarchyLeft) + @targetLeft)
		   ,HierarchyRight = abs(HierarchyRight) + @targetLeft
	where  HierarchyRight < 0

commit
go

select *, case when HierarchyLeft = HierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   NestedSets.Company
order by HierarchyLeft
go

NestedSets.Company$reparent 'Maine HQ','Tennessee HQ'
go
select *
from   NestedSets.Company
order by HierarchyLeft
go
NestedSets.Company$reparent 'Maine HQ','Company HQ'
go
select *
from   NestedSets.Company
order by HierarchyLeft
go


-------------------
--Deleting a node

CREATE PROCEDURE NestedSets.Company$Delete
@Name VARCHAR(20),
@DeleteChildRowsFlag BIT = 0
AS

BEGIN
	SET NOCOUNT ON 
	DECLARE @CompanyId int = (select CompanyId 
							  from NestedSets.Company 
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
					from   NestedSets.Company
					where  exists (select *
									from NestedSets.Company as startingPoint
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
	
	--use numNodesToMove to figure out how much space to remove later
	declare @numNodesToMove INT
	--count the nodes we are going to delete      
	SELECT @numNodesToMove = count(*), @startNode = min(searchFor.HierarchyLeft)  
	from   NestedSets.Company
			join NestedSets.Company as searchFor
				on Company.HierarchyLeft >= searchFor.HierarchyLeft 
					and Company.HierarchyLeft <= searchFor.HierarchyRight
	where  searchFor.CompanyId = @CompanyId

	--delete all of the nodes that we are deleting, 1 only or children too has been settled
	DELETE NestedSets.Company
	from   NestedSets.Company
	where  exists (select *
					from NestedSets.Company as startingPoint
					where Company.HierarchyLeft >= startingPoint.HierarchyLeft
						and Company.HierarchyLeft <= startingPoint.HierarchyRight
						and startingPoint.CompanyId = @CompanyId)

	--move the left values over
	UPDATE NestedSets.Company 
	SET	   HierarchyLeft = Company.HierarchyLeft - (@numNodesToMove * 2)
	WHERE  HierarchyLeft >= @startNode

	--move the right values over
	--done in seperate statements because of the largest HierarchyRight value
	UPDATE NestedSets.Company 
	SET	   HierarchyRight = Company.HierarchyRight - (@numNodesToMove * 2)
	WHERE  HierarchyRight >= @startNode

COMMIT TRANSACTION
END
GO

--add a few rows to test the delete. No activity rows because that would limit deletes
EXEC NestedSets.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';
EXEC NestedSets.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';
EXEC NestedSets.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';

EXEC NestedSets.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';
EXEC NestedSets.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';
EXEC NestedSets.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';
GO
SELECT *
FROM   NestedSets.Company
GO
--fails, has child rows
EXEC NestedSets.Company$Delete @Name = 'Georgia HQ'
GO
--success
EXEC NestedSets.Company$Delete @Name = 'Atlanta Branch'
GO
SELECT *
FROM   NestedSets.Company
GO
EXEC NestedSets.Company$Delete @Name = 'Georgia HQ', @DeleteChildRowsFlag = 1
Go
SELECT *
FROM   NestedSets.Company
Go
EXEC NestedSets.Company$Delete @Name = 'Texas HQ', @DeleteChildRowsFlag = 1
GO

SELECT *
FROM   NestedSets.Company


go

--For all nodes, get all of the children of the nodes. This will be used again
--in the Aggregation section
SELECT Company.CompanyId AS ParentCompanyId, ChildRows.CompanyId AS ChildCompanyId
FROM   NestedSets.Company
		 JOIN NestedSets.Company AS ChildRows
				On Company.HierarchyLeft >= ChildRows.HierarchyLeft
				  and Company.HierarchyLeft <= ChildRows.HierarchyRight

go



--aggregating over the Hierarchy
WITH ExpandedHierarchy AS
(
SELECT Company.CompanyId AS ParentCompanyId, Findrows.CompanyId AS ChildCompanyId
from   NestedSets.Company
		 JOIN NestedSets.Company AS FindRows
			ON FindRows.HierarchyLeft BETWEEN Company.HierarchyLeft AND Company.HierarchyRight
),
CompanyTotals AS
(
	SELECT CompanyId, SUM(Amount) AS TotalAmount
	FROM   NestedSets.Sale
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
FROM   NestedSets.Company
		 JOIN Aggregations
		 ON Company.CompanyId = Aggregations.ParentCompanyId
