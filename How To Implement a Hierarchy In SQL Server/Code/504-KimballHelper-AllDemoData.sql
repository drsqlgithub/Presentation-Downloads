USE HowToOptimizeAHierarchyInSQLServer;
GO

--this function may be dropped when we recreate the adjacencyList table
IF EXISTS (SELECT * FROM sys.objects 
		   WHERE object_id = object_id('AdjacencyList.Company$returnHierarchyHelper')
		     AND type = 'TF')
	DROP FUNCTION AdjacencyList.Company$returnHierarchyHelper
go
--returns all of the children for a given row, using the same algorithm as previously, with a few mods to 
--include the additional metadata
CREATE function AdjacencyList.Company$returnHierarchyHelper
(@CompanyId int)
RETURNS @Output TABLE (ParentCompanyId int, ChildCompanyId int, Distance int, ParentRootNodeFlag bit, ChildLeafNodeFlag bit)
as
BEGIN
	;WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
	AS
	(
		 --gets the top level in Hierarchy we want. The Hierarchy column
		 --will show the row's place in the Hierarchy from this query only
		 --not in the overall reality of the row's place in the table
		 SELECT CompanyId, ParentCompanyId,
				1 as TreeLevel, CAST(CompanyId as varchar(max)) as Hierarchy
		 FROM   AdjacencyList.Company
		 WHERE  CompanyId=@CompanyId

		 UNION ALL

		 --joins back to the CTE to recursively retrieve the rows 
		 --note that TreeLevel is incremented on each iteration
		 SELECT Company.CompanyId, Company.ParentCompanyId,
				TreeLevel + 1 as TreeLevel,
				Hierarchy + '\' +cast(Company.CompanyId as varchar(20)) as Hierarchy
		 FROM   AdjacencyList.Company
				  INNER JOIN CompanyHierarchy
					--use to get children
					on Company.ParentCompanyId= CompanyHierarchy.CompanyId

	)
	--added to original tree example with distance, root and leaf node indicators
	insert into @Output (ParentCompanyId, ChildCompanyId, Distance, ParentRootNodeFlag, ChildLeafNodeFlag)
	select  @CompanyId as ParentCompanyId, CompanyHierarchy.CompanyId as ChildCompanyId, TreeLevel - 1 as Distance,
										   case when CompanyId = @CompanyId AND ParentCompanyId IS NULL then 1 else 0 end as ParentRootNodeFlag,
										   case when NOT exists(select *	
																from   AdjacencyList.Company
																where  Company.ParentCompanyId = CompanyHierarchy.CompanyId
															   ) then 1 else 0 end as ChildRootNodeFlag
	from   CompanyHierarchy

Return

END
GO

select sysdatetime() as startTime
into   #startTime
go

--just uses adjacency list.. Rebuild the table.

EXEC KimballHelper.CompanyHierarchyHelper$Rebuild
GO
select datediff(millisecond,startTime,sysdatetime()) / 1000.0 as executionTimeSeconds
from   #startTime
go
drop table #startTime