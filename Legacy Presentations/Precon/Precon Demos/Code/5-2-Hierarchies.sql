use master
Go

--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'HierarchyDemo')
 exec ('
alter database  HierarchyDemo
	set single_user with rollback immediate;

drop database HierarchyDemo;')


CREATE DATABASE HierarchyDemo;
GO
USE HierarchyDemo;
GO

CREATE SCHEMA corporate;
GO
CREATE TABLE corporate.company
(
    companyId   int CONSTRAINT PKcompany primary key,
    name        varchar(20) CONSTRAINT AKcompany_name UNIQUE,
    parentCompanyId int null
      CONSTRAINT company$isParentOf$company REFERENCES corporate.company(companyId)
);  

GO
INSERT INTO corporate.company (companyId, name, parentCompanyId)
VALUES (1, 'Company HQ', NULL),
       (2, 'Maine HQ',1),              (3, 'Tennessee HQ',1),
       (4, 'Nashville Branch',3),      (5, 'Knoxville Branch',3),
       (6, 'Memphis Branch',3),        (7, 'Portland Branch',2),
       (8, 'Camden Branch',2);

GO
SELECT *
FROM    corporate.company;
GO

--getting the children of a row (or ancestors with slight mod to query)
DECLARE @companyId int = 1;

;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
AS
(
     --gets the top level in hierarchy we want. The hierarchy column
     --will show the row's place in the hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT companyID, parentCompanyId,
            1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
     FROM   corporate.company
     WHERE companyId=@CompanyId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that treelevel is incremented on each iteration
     SELECT company.companyID, company.parentCompanyId,
            treelevel + 1 as treelevel,
            hierarchy + '\' +cast(company.companyId as varchar(20)) as hierarchy
     FROM   corporate.company
              INNER JOIN companyHierarchy
                --use to get children, since the parentCompanyId of the child will be set the value
				--of the current row
                on company.parentCompanyId= companyHierarchy.companyID 
                --use to get parents, since the parent of the companyHierarchy row will be the company, 
				--not the parent.
                --on company.CompanyId= companyHierarchy.parentcompanyID
)
--return results from the CTE, joining to the company data to get the 
--company name
SELECT  company.companyID,company.name,
        companyHierarchy.treelevel, companyHierarchy.hierarchy
FROM     corporate.company
         INNER JOIN companyHierarchy
              ON company.companyID = companyHierarchy.companyID
ORDER BY hierarchy ;
GO



--getting the children of a row 
DECLARE @companyId int = 3;

;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
AS
(
     --gets the top level in hierarchy we want. The hierarchy column
     --will show the row's place in the hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT companyID, parentCompanyId,
            1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
     FROM   corporate.company
     WHERE companyId=@CompanyId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that treelevel is incremented on each iteration
     SELECT company.companyID, company.parentCompanyId,
            treelevel + 1 as treelevel,
            hierarchy + '\' +cast(company.companyId as varchar(20)) as hierarchy
     FROM   corporate.company as company
              INNER JOIN companyHierarchy
                --use to get children, since the parentCompanyId of the child will be set the value
				--of the current row
                on company.parentCompanyId= companyHierarchy.companyID 
                --use to get parents, since the parent of the companyHierarchy row will be the company, 
				--not the parent.
                --on company.CompanyId= companyHierarchy.parentcompanyID
)
--return results from the CTE, joining to the company data to get the 
--company name
SELECT  company.companyID,company.name,
        companyHierarchy.treelevel, companyHierarchy.hierarchy
FROM     corporate.company as company
         INNER JOIN companyHierarchy
              ON company.companyID = companyHierarchy.companyID
ORDER BY hierarchy;

GO

--getting the parents of companyId = 7
DECLARE @companyId int = 7;

;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
AS
(
     --gets the top level in hierarchy we want. The hierarchy column
     --will show the row's place in the hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT companyID, parentCompanyId,
            1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
     FROM   corporate.company
     WHERE companyId=@CompanyId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that treelevel is incremented on each iteration
     SELECT company.companyID, company.parentCompanyId,
            treelevel + 1 as treelevel,
            hierarchy + '\' +cast(company.companyId as varchar(20)) as hierarchy
     FROM   corporate.company as company
              INNER JOIN companyHierarchy
                --use to get children, since the parentCompanyId of the child will be set the value
				--of the current row
                --on company.parentCompanyId= companyHierarchy.companyID 
                --use to get parents, since the parent of the companyHierarchy row will be the company, 
				--not the parent.
                on company.CompanyId= companyHierarchy.parentcompanyID
)
--return results from the CTE, joining to the company data to get the 
--company name
SELECT  company.companyID,company.name,
        companyHierarchy.treelevel, companyHierarchy.hierarchy
FROM     corporate.company as company
         INNER JOIN companyHierarchy
              ON company.companyID = companyHierarchy.companyID
ORDER BY hierarchy;

GO

--------------------------------------------------------------------
-- Using HierarchyId
--------------------------------------------------------------------

CREATE TABLE corporate.company2
(
    companyOrgNode hierarchyId not null 
                 CONSTRAINT AKcompany UNIQUE,
    companyId   int CONSTRAINT PKcompany2 primary key,
    name        varchar(20) CONSTRAINT AKcompany2_name UNIQUE,
);   

GO
INSERT corporate.company2 (companyOrgNode, CompanyId, Name)
VALUES (hierarchyid::GetRoot(), 1, 'Company HQ');


GO
CREATE PROCEDURE corporate.company2$insert(@companyId int, @parentCompanyId int, 
                                          @name varchar(20)) 
AS 
BEGIN
   SET NOCOUNT ON
   --the last child will be used when generating the next node, 
   --and the parent is used to set the parent in the insert
   DECLARE  @lastChildofParentOrgNode hierarchyid,
            @parentCompanyOrgNode hierarchyid; 
   IF @parentCompanyId is not null
     BEGIN
        SET @parentCompanyOrgNode = 
                            (  SELECT companyOrgNode 
                               FROM   corporate.company2
                               WHERE  companyID = @parentCompanyId)
	 IF  @parentCompanyOrgNode is null
           BEGIN
                THROW 50000, 'Invalid parentCompanyId passed in',16 
	         RETURN -100;
            END
    END
   
   BEGIN TRANSACTION;

      --get the last child of the parent you passed in if one exists
      SELECT @lastChildofParentOrgNode = max(companyOrgNode) 
      FROM corporate.company2 (UPDLOCK) --compatibile with shared, but blocks
                                       --other connections trying to get an UPDLOCK 
      WHERE companyOrgNode.GetAncestor(1) =@parentCompanyOrgNode ;

      --getDecendant will give you the next node that is greater than 
      --the one passed in.  Since the value was the max in the table, the 
      --getDescendant Method returns the next one
      INSERT corporate.company2 (companyOrgNode, companyId, name)
             --the coalesce puts the row as a NULL this will be a root node
             --invalid parentCompanyId values were tossed out earlier
      SELECT COALESCE(@parentCompanyOrgNode.GetDescendant(@lastChildofParentOrgNode, NULL),
	               hierarchyid::GetRoot())
                  ,@companyId, @name;
   COMMIT;
END 

GO
--exec corporate.company2$insert @companyId = 1, @parentCompanyId = NULL,
--                               @name = 'Company HQ'; --already created
exec corporate.company2$insert @companyId = 2, @parentCompanyId = 1,
                                 @name = 'Maine HQ';
exec corporate.company2$insert @companyId = 3, @parentCompanyId = 1, 
                                 @name = 'Tennessee HQ';
exec corporate.company2$insert @companyId = 4, @parentCompanyId = 3, 
                                 @name = 'Knoxville Branch';
exec corporate.company2$insert @companyId = 5, @parentCompanyId = 3, 
                                 @name = 'Memphis Branch';
exec corporate.company2$insert @companyId = 6, @parentCompanyId = 2, 
                                 @name = 'Portland Branch';
exec corporate.company2$insert @companyId = 7, @parentCompanyId = 2, 
                                 @name = 'Camden Branch';

GO
SELECT  companyOrgNode, companyId,   name
FROM    corporate.company2;

GO
SELECT companyId, companyOrgNode.GetLevel() as level,
       name, companyOrgNode.ToString() as hierarchy 
FROM   corporate.company2;

GO
--get children of 1
DECLARE @companyId int = 1;
SELECT Target.companyId, Target.name, Target.companyOrgNode.ToString() as hierarchy
FROM   corporate.company2 AS Target
	       JOIN corporate.company2 AS SearchFor
		       ON SearchFor.companyId = @companyId
                          and Target.companyOrgNode.IsDescendantOf
                                                 (SearchFor.companyOrgNode) = 1;

--get children of 3
DECLARE @companyId int = 3;
SELECT Target.companyId, Target.name, Target.companyOrgNode.ToString() as hierarchy
FROM   corporate.company2 AS Target
	       JOIN corporate.company2 AS SearchFor
		       ON SearchFor.companyId = @companyId
                          and Target.companyOrgNode.IsDescendantOf
                                                 (SearchFor.companyOrgNode) = 1;

GO
--get parents of 7
DECLARE @companyId int = 7;
SELECT Target.companyId, Target.name, Target.companyOrgNode.ToString() as hierarchy
FROM   corporate.company2 AS Target
	       JOIN corporate.company2 AS SearchFor
		       ON SearchFor.companyId = @companyId
                          and SearchFor.companyOrgNode.IsDescendantOf
                                                 (Target.companyOrgNode) = 1;

GO
**
------------------------------------------------------------
GO
--path method
CREATE TABLE corporate.company3
(
    companyId   int CONSTRAINT PKcompany3 primary key,
    name        varchar(20) CONSTRAINT AKcompany3_name UNIQUE,
    path		varchar(2000)
);  

GO
INSERT INTO corporate.company3 (companyId, name, path)
VALUES (1, 'Company HQ', '\1\'),
       (2, 'Maine HQ', '\1\2\'),              (3, 'Tennessee HQ', '\1\3\'),
       (4, 'Nashville Branch', '\1\3\4\'),      (5, 'Knoxville Branch', '\1\3\5\'),
       (6, 'Memphis Branch', '\1\3\6\'),        (7, 'Portland Branch', '\1\2\7\'),
       (8, 'Camden Branch', '\1\2\8\');
GO

--get all nodes in the Tennessee Hierarchy
select *
from   corporate.company3
where  path like '\1\3\%'

--get all nodes under the Tennessee Hierarchy
select *
from   corporate.company3
where  path like '\1\3\_%'

GO

--getting parents is a bit more difficult

CREATE SCHEMA Tools;
--adapted from http://www.sommarskog.se/arrays-in-sql-2005.html - iter$simple_intlist_to_tbl
--and adapted from SQL Server 2008 Bible by Paul Nielsen et al
go
CREATE FUNCTION Tools.String$Parse (@list VARCHAR(200),@delimiter char(1) ='/') 
RETURNS @tbl TABLE ( id INT) 
AS 
  BEGIN 
      DECLARE @valuelen INT, 
              @pos      INT, 
              @nextpos  INT 

      SELECT @pos = 0, 
             @nextpos = 1 
	  
	  if left(@list,1) = @delimiter set @list = substring(@list,2,2000)
	  if left(reverse(@list),1) = @delimiter set @list = reverse(substring(reverse(@list),2,2000))

      WHILE @nextpos > 0 
        BEGIN 
            SELECT @nextpos = Charindex(@delimiter, @list, @pos + 1) 

            SELECT @valuelen = CASE 
                                 WHEN @nextpos > 0 THEN @nextpos 
                                 ELSE Len(@list) + 1 
                               END - @pos - 1 

            INSERT @tbl (id) 
            VALUES (Substring(@list, @pos + 1, @valuelen)) 

            SELECT @pos = @nextpos 
        END 

      RETURN 
  END  
go 

--parse based on the \ delimiter
select *
from   Tools.String$Parse('\1\2\3\4\','\')
GO


--get the parents of 1\3\4 (which will be id's, 1, 3, and 4)
select *
from   Tools.String$Parse('\1\3\4\','\') as Ids
		  join corporate.company3
			on company3.companyId = Ids.id
GO

-------------------------------------------------------------------
--nested sets

CREATE TABLE corporate.company4
(
    companyId   int CONSTRAINT PKcompany4 primary key,
    name        varchar(20) CONSTRAINT AKcompany4_name UNIQUE,
	hierarchyLeft int,
	hierarchyRight int
);  
INSERT INTO corporate.company4 (companyId, name, hierarchyLeft, hierarchyRight)
VALUES (1, 'Company HQ', 1,16),
       (2, 'Maine HQ',2,7),              (3, 'Tennessee HQ',8,15),
       (4, 'Nashville Branch',9,10),      (5, 'Knoxville Branch',11,12),
       (6, 'Memphis Branch',13,14),        (7, 'Portland Branch',3,4),
       (8, 'Camden Branch',5,6);

GO
select *
from   corporate.company4
order by hierarchyLeft
GO

--tennessee children, including parent (tenn hq is 8 and 15)
select *
from   corporate.company4
where  hierarchyLeft >= 8 and hierarchyRight <= 15
GO
--not including parent
select *
from   corporate.company4
where  hierarchyLeft > 8 and hierarchyRight < 15
GO

--get parents of nashville branch
select *
from   corporate.company4 as companyParent
		 join corporate.company4 as companyChild
				on companyChild.hierarchyLeft between companyParent.hierarchyLeft and companyParent.hierarchyRight
where  companyChild.name = 'Nashville Branch'
GO

--get parents of camden branch
select *
from   corporate.company4 as companyParent
		 join corporate.company4 as companyChild
				on companyChild.hierarchyLeft between companyParent.hierarchyLeft and companyParent.hierarchyRight
where  companyChild.name = 'Camden Branch'
GO
----------------------------------------------------------------------------------
-- kimball helper table
/*
INSERT INTO corporate.company (companyId, name, parentCompanyId)
VALUES (1, 'Company HQ', NULL),
       (2, 'Maine HQ',1),              (3, 'Tennessee HQ',1),
       (4, 'Nashville Branch',3),      (5, 'Knoxville Branch',3),
       (6, 'Memphis Branch',3),        (7, 'Portland Branch',2),
       (8, 'Camden Branch',2);
*/

create table corporate.companyHiererarchyHelper
(
	ParentCompanyId	int, 
	ChildCompanyId  int, 
	Distance        int, 
	ParentRootNodeFlag bit, 
	ChildLeafNodeFlag  bit
)
GO
select *
from   corporate.company
GO

--returns all of the children for a given row, using the same algorithm as previously, with a few mods to 
--include the additional metadata
CREATE function corporate.company$returnHierarchyHelper
(@companyId int)
RETURNS @Output TABLE (ParentCompanyId int, ChildCompanyId int, Distance int, ParentRootNodeFlag bit, ChildLeafNodeFlag bit)
as
BEGIN
	;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
	AS
	(
		 --gets the top level in hierarchy we want. The hierarchy column
		 --will show the row's place in the hierarchy from this query only
		 --not in the overall reality of the row's place in the table
		 SELECT companyID, parentCompanyId,
				1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
		 FROM   corporate.company
		 WHERE companyId=@CompanyId

		 UNION ALL

		 --joins back to the CTE to recursively retrieve the rows 
		 --note that treelevel is incremented on each iteration
		 SELECT company.companyID, company.parentCompanyId,
				treelevel + 1 as treelevel,
				hierarchy + '\' +cast(company.companyId as varchar(20)) as hierarchy
		 FROM   corporate.company
				  INNER JOIN companyHierarchy
					--use to get children
					on company.parentCompanyId= companyHierarchy.companyID

	)
	insert into @Output (ParentCompanyId, ChildCompanyId, Distance, ParentRootNodeFlag, ChildLeafNodeFlag)
	select  @companyId as ParentCompanyId, companyHierarchy.companyId as ChildCompanyId, treeLevel - 1 as Distance,
										   case when exists(select *	
															from   corporate.company
															where  companyId = @companyId
															  and  parentCompanyId is null) then 1 else 0 end as ParentRootNodeFlag,
										   case when exists(select *	
															from   corporate.company
															where  company.ParentCompanyId = companyHierarchy.companyId
															  and  parentCompanyId is not null) then 0 else 1 end as ChildRootNodeFlag
	from   companyHierarchy

Return

END
GO
select * from corporate.company$returnHierarchyHelper (1)
select hierarchyHelper.ParentCompanyId, hierarchyHelper.ChildCompanyId, hierarchyHelper.Distance, 
	   hierarchyHelper.ParentRootNodeFlag, hierarchyHelper.ChildLeafNodeFlag
from   corporate.company
		cross apply corporate.company$returnHierarchyHelper(company.companyId) as hierarchyHelper
order by hierarchyHelper.ParentCompanyId

insert into corporate.companyHiererarchyHelper(
	ParentCompanyId, ChildCompanyId, Distance, ParentRootNodeFlag, ChildLeafNodeFlag
	)
select hierarchyHelper.ParentCompanyId, hierarchyHelper.ChildCompanyId, hierarchyHelper.Distance, 
	   hierarchyHelper.ParentRootNodeFlag, hierarchyHelper.ChildLeafNodeFlag
from   corporate.company
		cross apply corporate.company$returnHierarchyHelper(company.companyId) as hierarchyHelper
--order by hierarchyHelper.ParentCompanyId
GO

--get children of Tennessee HQ including HQ
select getNodes.*
from   corporate.company --the target row we care about
		  join corporate.companyHiererarchyHelper --gets the hierarchy helper rows
			on company.companyId = companyHiererarchyHelper.ParentCompanyId
		  join corporate.company as getNodes --the tree data as it relates to the node
			on getNodes.companyId = companyHiererarchyHelper.childCompanyId
where  company.name = 'Tennessee HQ'

--get children of Tennessee HQ not including HQ
select getNodes.*
from   corporate.company
		  join corporate.companyHiererarchyHelper
			on company.companyId = companyHiererarchyHelper.ParentCompanyId
		  join corporate.company as getNodes
			on getNodes.companyId = companyHiererarchyHelper.childCompanyId
where  company.name = 'Tennessee HQ'
  and  company.companyId <> companyHiererarchyHelper.childCompanyId
GO

--all children of Company HQ
select getNodes.*
from   corporate.company
		  join corporate.companyHiererarchyHelper
			on company.companyId = companyHiererarchyHelper.ParentCompanyId
		  join corporate.company as getNodes
			on getNodes.companyId = companyHiererarchyHelper.childCompanyId
where  company.name = 'Company HQ'
  and  company.companyId <> companyHiererarchyHelper.childCompanyId
GO

--all leaf nodes 
select getNodes.*
from   corporate.company
		  join corporate.companyHiererarchyHelper
			on company.companyId = companyHiererarchyHelper.ParentCompanyId
		  join corporate.company as getNodes
			on getNodes.companyId = companyHiererarchyHelper.childCompanyId
where  company.name = 'Company HQ'
  and  companyHiererarchyHelper.ChildLeafNodeFlag = 1
GO

--non leaf nodes
select getNodes.*
from   corporate.company
		  join corporate.companyHiererarchyHelper
			on company.companyId = companyHiererarchyHelper.ParentCompanyId
		  join corporate.company as getNodes
			on getNodes.companyId = companyHiererarchyHelper.childCompanyId
where  company.name = 'Company HQ'
  and  companyHiererarchyHelper.ChildLeafNodeFlag = 0