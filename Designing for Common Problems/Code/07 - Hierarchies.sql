use master
Go
set nocount on
GO
--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'Patterns_Hierarchy')
 exec ('
alter database  Patterns_Hierarchy
	set single_user with rollback immediate;

drop database Patterns_Hierarchy;')


CREATE DATABASE Patterns_Hierarchy;
GO
USE Patterns_Hierarchy;
GO
-----------------------------------------------------------------
--  Tools (Generally user facing that they can rely on)
-----------------------------------------------------------------
create schema Tools
GO
CREATE TABLE Tools.Number
(
    I   int CONSTRAINT PKTools_Number PRIMARY KEY
);
GO


;WITH DIGITS (I) as(--set up a set of numbers from 0-9
        SELECT I
        FROM   (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) as digits (I))
--builds a table from 0 to 999999
,Integers (I) as (
        SELECT D1.I + (10*D2.I) + (100*D3.I) + (1000*D4.I) + (10000*D5.I)
               --+ (100000*D6.I)
        FROM digits AS D1 CROSS JOIN digits AS D2 CROSS JOIN digits AS D3
                CROSS JOIN digits AS D4 CROSS JOIN digits AS D5
                --CROSS JOIN digits AS D6
				) 
INSERT INTO Tools.Number(I)
SELECT I
FROM   Integers;
GO


CREATE SCHEMA corporate;
GO

/********************
Simple adjacency list
********************/
CREATE TABLE corporate.company
(
    companyId   int identity (1,1) CONSTRAINT PKcompany primary key,
    name        varchar(20) CONSTRAINT AKcompany_name UNIQUE,
    parentCompanyId int null
      CONSTRAINT company$isParentOf$company REFERENCES corporate.company(companyId)
);  

create index XCorporate_Company_ParentCompanyId on Corporate.Company(ParentCompanyId)

GO

CREATE PROCEDURE corporate.company$insert(@name varchar(20), @parentCompanyName  varchar(20)) 
as
BEGIN
	INSERT INTO corporate.company (name, parentCompanyId)
	SELECT @name, (select companyId as parentCompanyId
				   from   corporate.company
				   where  company.name = @parentCompanyName)
END
GO
EXEC corporate.company$insert @name = 'Company HQ', @parentCompanyName = NULL;
EXEC corporate.company$insert @name = 'Maine HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.company$insert @name = 'Tennessee HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.company$insert @name = 'Nashville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.company$insert @name = 'Knoxville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.company$insert @name = 'Memphis Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.company$insert @name = 'Portland Branch', @parentCompanyName = 'Maine HQ';
EXEC corporate.company$insert @name = 'Camden Branch', @parentCompanyName = 'Maine HQ';

GO
SELECT *
FROM    corporate.company
GO

--getting the children of a row (or ancestors with slight mod to query)
DECLARE @companyId int = (select companyId from corporate.company where parentCompanyId is null);

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

CREATE PROCEDURE corporate.company$Reparent(@name varchar(20), @newParentCompanyName  varchar(20)) 
as
BEGIN
	UPDATE corporate.company 
	SET    ParentCompanyId = (select companyId as parentCompanyId
							   from   corporate.company
							   where  company.name = @newParentCompanyName)
	WHERE  name = @name
END
GO

EXEC corporate.company$Reparent @name = 'Maine HQ', @newParentCompanyName = 'Nashville Branch'
GO

--show entire tree
DECLARE @companyId int = (select companyId from corporate.company where parentCompanyId is null);;

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


--------------------------------------------------------------------
-- Using HierarchyId
--------------------------------------------------------------------

CREATE TABLE corporate.companyHierarchyId
(
    companyOrgNode hierarchyId not null 
                 CONSTRAINT AKcompany UNIQUE,
    companyId   int not null identity CONSTRAINT PKcompany2 primary key,
    name        varchar(20) not null CONSTRAINT AKcompany2_name UNIQUE,
);   

GO

CREATE PROCEDURE corporate.companyHierarchyId$insert(@name varchar(20), @parentCompanyName  varchar(20))
                                          
AS  --always inserts a root node
BEGIN
   SET NOCOUNT ON
   --the last child will be used when generating the next node, 
   --and the parent is used to set the parent in the insert
   DECLARE  @lastChildofParentOrgNode hierarchyid,
            @parentCompanyOrgNode hierarchyid; 
   IF @parentCompanyName is not null
     BEGIN
        SET @parentCompanyOrgNode = 
                            (  SELECT companyOrgNode 
                               FROM   corporate.companyHierarchyId
                               WHERE  name = @parentCompanyName)
	 IF  @parentCompanyOrgNode is null
           BEGIN
                THROW 50000, 'Invalid parentCompanyId passed in',16 
				RETURN -100;
            END
    END
   
   BEGIN TRANSACTION;

      --get the last child of the parent you passed in if one exists
      SELECT @lastChildofParentOrgNode = max(companyOrgNode) 
      FROM corporate.companyHierarchyId (UPDLOCK) --compatibile with shared, but blocks
                                       --other connections trying to get an UPDLOCK 
      WHERE companyOrgNode.GetAncestor(1) =@parentCompanyOrgNode ;

      --getDecendant will give you the next node that is greater than 
      --the one passed in.  Since the value was the max in the table, the 
      --getDescendant Method returns the next one
      INSERT corporate.companyHierarchyId (companyOrgNode, name)
             --the coalesce puts the row as a NULL this will be a root node
             --invalid parentCompanyId values were tossed out earlier
			 --GetDescendant call will always make this node the last child of ParentCompanyOrgNode
      SELECT COALESCE(@parentCompanyOrgNode.GetDescendant(@lastChildofParentOrgNode, NULL),
	               hierarchyid::GetRoot()),
                   @name;

	-- http://msdn.microsoft.com/en-us/library/Bb677209(v=sql.110).aspx GetDescendantDoc
	--Returns one child node that is a descendant of the parent.
	--If parent is NULL, returns NULL.
	--If parent is not NULL, and both child1 and child2 are NULL, returns a child of parent.
	--If parent and child1 are not NULL, and child2 is NULL, returns a child of parent greater than child1.
	--If parent and child2 are not NULL and child1 is NULL, returns a child of parent less than child2.
	--If parent, child1, and child2 are not NULL, returns a child of parent greater than child1 and less than child2.
	--If child1 is not NULL and not a child of parent, an exception is raised.
	--If child2 is not NULL and not a child of parent, an exception is raised.
	--If child1 >= child2, an exception is raised.
	
   COMMIT;
END 

GO

EXEC corporate.companyHierarchyId$insert @name = 'Company HQ', @parentCompanyName = NULL;
EXEC corporate.companyHierarchyId$insert @name = 'Maine HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.companyHierarchyId$insert @name = 'Tennessee HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.companyHierarchyId$insert @name = 'Nashville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.companyHierarchyId$insert @name = 'Knoxville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.companyHierarchyId$insert @name = 'Memphis Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.companyHierarchyId$insert @name = 'Portland Branch', @parentCompanyName = 'Maine HQ';
EXEC corporate.companyHierarchyId$insert @name = 'Camden Branch', @parentCompanyName = 'Maine HQ';

GO
SELECT  companyOrgNode, companyId,   name
FROM    corporate.companyHierarchyId;

GO
SELECT companyId, companyOrgNode.GetLevel() as level,
       name, companyOrgNode.ToString() as hierarchy 
FROM   corporate.companyHierarchyId
ORDER BY hierarchy

GO
--get children of 1
DECLARE @companyId int = 1;
SELECT Target.companyId, Target.name, Target.companyOrgNode.ToString() as hierarchy
FROM   corporate.companyHierarchyId AS Target 
	       JOIN corporate.companyHierarchyId AS SearchFor  --represents the one row that matches the search
		       ON SearchFor.companyId = @companyId
                          and Target.companyOrgNode.IsDescendantOf --gets target rows that are descendants of
                                                 (SearchFor.companyOrgNode) = 1;
GO
--get children of 3
DECLARE @companyId int = 3;
SELECT Target.companyId, Target.name, Target.companyOrgNode.ToString() as hierarchy
FROM   corporate.companyHierarchyId AS Target
	       JOIN corporate.companyHierarchyId AS SearchFor
		       ON SearchFor.companyId = @companyId
                          and Target.companyOrgNode.IsDescendantOf
                                                 (SearchFor.companyOrgNode) = 1;

GO
--get parents of 7
DECLARE @companyId int = 7;
SELECT Target.companyId, Target.name, Target.companyOrgNode.ToString() as hierarchy
FROM   corporate.companyHierarchyId AS Target
	       JOIN corporate.companyHierarchyId AS SearchFor --represents the one row that matches the search
		       ON SearchFor.companyId = @companyId
                          and SearchFor.companyOrgNode.IsDescendantOf  --gets rows where the target is a 
                                                 (Target.companyOrgNode) = 1 --descendent of the search row

--reparent Maine HQ to Child of Nashville
go
--use procedure, adapted from http://technet.microsoft.com/en-us/library/bb677212(SQL.105).aspx
CREATE PROCEDURE corporate.companyHierarchyId$Reparent
    (
      @Location VARCHAR(20) ,
      @newParentLocation VARCHAR(20)
    )
AS 
    BEGIN

        DECLARE @nnew HIERARCHYID ,--where we will put the rows
            @nold HIERARCHYID = ( SELECT    CompanyOrgNode --the parent of the node currently
                                  FROM      corporate.companyHierarchyId
                                  WHERE     name = @Location)

        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
        BEGIN TRANSACTION
        SELECT  @nnew = CompanyOrgNode --the hierarchy location of the of the new location
        FROM    corporate.companyHierarchyId
        WHERE   Name = @NewParentLocation;

        SELECT  @nnew = @nnew.GetDescendant(MAX(CompanyOrgNode), NULL) --get the location of the last ancestor of @nnew
        FROM    corporate.companyHierarchyId
        WHERE   CompanyOrgNode.GetAncestor(1) = @nnew;

        UPDATE  corporate.companyHierarchyId
        SET     CompanyOrgNode = CompanyOrgNode.GetReparentedValue(@nold, --update the hierarchyId to the reparented value
                                                              @nnew)
        WHERE   CompanyOrgNode.IsDescendantOf(@nold) = 1; --for all decendents of the @nold that we are moving

        COMMIT TRANSACTION
    END
go


EXEC corporate.companyHierarchyId$Reparent @Location = 'Maine HQ', @NewParentLocation = 'Nashville Branch'

SELECT companyId, companyOrgNode.GetLevel() as level,
       name, companyOrgNode.ToString() as hierarchy 
FROM   corporate.companyHierarchyId
order by hierarchy
Go

------------------------------------------------------------
--path method
------------------------------------------------------------
CREATE SEQUENCE corporate.companyPathMethod_SEQUENCE
AS int
START WITH 1
GO
CREATE TABLE corporate.companyPathMethod
(
    companyId   int not null CONSTRAINT PKcompany3 primary key,
    name        varchar(20) not null CONSTRAINT AKcompany3_name UNIQUE,
    path		varchar(900) not null 
);
create index Xpath on corporate.companyPathMethod (path)
GO


CREATE PROCEDURE corporate.companyPathMethod$insert(@name varchar(20), @parentCompanyName  varchar(20)) 
as --always inserts a root node
BEGIN
	--gets path, which looks like \key\key\...
	declare @parentPath varchar(900) = coalesce ((	select path
													from   corporate.companyPathMethod
													where  name = @parentCompanyName),'\');

	declare @newCompanyId int = NEXT VALUE FOR corporate.companyPathMethod_SEQUENCE;

	INSERT INTO corporate.companyPathMethod (companyId, name, path)
	SELECT @newCompanyId, @name, @parentPath + cast(@newCompanyId as varchar(10)) + '\'
END
GO
EXEC corporate.companyPathMethod$insert @name = 'Company HQ', @parentCompanyName = NULL;
EXEC corporate.companyPathMethod$insert @name = 'Maine HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.companyPathMethod$insert @name = 'Tennessee HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.companyPathMethod$insert @name = 'Nashville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.companyPathMethod$insert @name = 'Knoxville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.companyPathMethod$insert @name = 'Memphis Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.companyPathMethod$insert @name = 'Portland Branch', @parentCompanyName = 'Maine HQ';
EXEC corporate.companyPathMethod$insert @name = 'Camden Branch', @parentCompanyName = 'Maine HQ';

--GO

select *
from   corporate.companyPathMethod
order by path


--get all nodes in the Tennessee Hierarchy
select *
from   corporate.companyPathMethod
where  path like '\1\3\%'

--get all nodes under the Tennessee Hierarchy
select *
from   corporate.companyPathMethod
where  path like '\1\3\_%'

GO

--getting parents is a bit more difficult

--CREATE SCHEMA Tools;
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
		  join corporate.companyPathMethod
			on companyPathMethod.companyId = Ids.id
GO

--reparent Maine HQ to Child of Nashville


create procedure corporate.companyPathMethod$reparent
    (
      @Location VARCHAR(20) ,
      @newParentLocation VARCHAR(20)
    )
as 

declare @lenOldPath int = (	select len(path) --length of path to allow stuff to work
							from   corporate.companyPathMethod
							where  name = @location),
		@newPath varchar(2000) = (  select path --path of new location 
									from   corporate.companyPathMethod
									where  name = @newParentLocation),
		@newPathEnd varchar(10) = (	select cast(companyId as varchar(10))  --companyId and \ for end of new home path
							from   corporate.companyPathMethod
							where  name = @location) + '\'

update corporate.companyPathMethod 
	   --stuff new parent address into existing address, replacing old root path
set    path = stuff(path,1,@lenoldPath,@newPath + @newPathEnd) 
where  path like (	select path + '%' 
					from   corporate.companyPathMethod
					where  name = @Location)
GO

select *
from   corporate.companyPathMethod
order by path
GO

EXEC corporate.companyPathMethod$reparent @Location = 'Maine HQ', @NewParentLocation = 'Nashville Branch'

select *
from   corporate.companyPathMethod
order by path
GO


-------------------------------------------------------------------
--nested sets


CREATE TABLE corporate.companyNestedSets
(
    companyId   int identity CONSTRAINT PKcompany4 primary key,
    name        varchar(20) CONSTRAINT AKcompany4_name UNIQUE,
	hierarchyLeft int,
	hierarchyRight int,
	unique (hierarchyLeft,hierarchyRight)
);  
GO


CREATE PROCEDURE corporate.companyNestedSets$insert(@name varchar(20), @parentCompanyName  varchar(20)) 
as --always inserts a root node
BEGIN
	SET NOCOUNT ON;
	BEGIN TRANSACTION

	if @parentCompanyName is NULL
	 begin
		if exists (select * from corporate.companyNestedSets)
			THROW 50000,'More than one root node is not supported in this code',1;
		else
			insert into corporate.companyNestedSets (name, hierarchyLeft, hierarchyRight)
			values (@name, 1,2)
	 end 
	 ELSE
	 BEGIN

		--find the place in the hierarchy where you will add a node
		DECLARE @parentRight int = (select hierarchyRight from corporate.companyNestedSets where name = @parentCompanyName)
	
		--make room for the nodes you are moving by moving left and right over by 2
		UPDATE corporate.companyNestedSets 
		SET	   hierarchyLeft = companyNestedSets.hierarchyLeft + 2
		WHERE  hierarchyLeft > @parentRight

		UPDATE corporate.companyNestedSets 
		SET	   hierarchyRight = companyNestedSets.hierarchyRight + 2
		WHERE  hierarchyRight >= @parentRight

		--insert the 
		INSERT corporate.companyNestedSets (name, hierarchyLeft, hierarchyRight)
		SELECT @name, @parentRight, @parentRight + 1
	END

	commit transaction
END
GO

EXEC corporate.companyNestedSets$insert @name = 'Company HQ', @parentCompanyName = NULL;
EXEC corporate.companyNestedSets$insert @name = 'Maine HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.companyNestedSets$insert @name = 'Tennessee HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.companyNestedSets$insert @name = 'Nashville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.companyNestedSets$insert @name = 'Knoxville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.companyNestedSets$insert @name = 'Memphis Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.companyNestedSets$insert @name = 'Portland Branch', @parentCompanyName = 'Maine HQ';
EXEC corporate.companyNestedSets$insert @name = 'Camden Branch', @parentCompanyName = 'Maine HQ';

GO


select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   corporate.companyNestedSets
order by hierarchyLeft
GO

--tennessee children, including parent (tenn hq is 8 and 15)
select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   corporate.companyNestedSets
where  hierarchyLeft >= 8 and hierarchyRight <= 15
GO
--not including parent
select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   corporate.companyNestedSets
where  hierarchyLeft > 8 and hierarchyRight < 15
GO

--get parents of nashville branch
select * 
from   corporate.companyNestedSets as companyParent
		 join corporate.companyNestedSets as companyChild
				on companyChild.hierarchyLeft between companyParent.hierarchyLeft and companyParent.hierarchyRight
where  companyChild.name = 'Nashville Branch'
GO

--get parents of camden branch
select *
from   corporate.companyNestedSets as companyParent
		 join corporate.companyNestedSets as companyChild
				on companyChild.hierarchyLeft between companyParent.hierarchyLeft and companyParent.hierarchyRight
where  companyChild.name = 'Camden Branch'
GO


create procedure corporate.companyNestedSets$reparent
(
    @Location VARCHAR(20) ,
    @newParentLocation VARCHAR(20) 
) as
--freaky messy, may be an easier way, but I didn't see any examples online that were better!
if exists (select *
			from   corporate.companyNestedSets
						join corporate.companyNestedSets as searchFor
							on companyNestedSets.hierarchyLeft >= searchFor.hierarchyLeft 
							   and companyNestedSets.hierarchyRight <= searchFor.hierarchyRight
			where  searchFor.Name = @Location
			  and  companyNestedSets.name = @newParentLocation)
   BEGIN 
	     THROW 50000,'Cannot make a child node a node''s parent in a single pass. Move child node first',1;
	     Return 
   END

--do this work in a transaction. Lots of modifications
begin transaction

--get the information about the the nodes we are going to move, 
declare @numNodesToMove int, @startNode int 
SELECT @numNodesToMove = count(*),@startNode = min(searchFor.hierarchyLeft)  
from   corporate.companyNestedSets
			join corporate.companyNestedSets as searchFor
				on companyNestedSets.hierarchyLeft >= searchFor.hierarchyLeft 
					and companyNestedSets.hierarchyRight <= searchFor.hierarchyRight
where  searchFor.Name = @Location

--set the hierarchy values to -1 to remove them from the hierarchy. We'll put them back later
--in the process
UPDATE companyNestedSets
set    hierarchyLeft = -1 * companyNestedSets.hierarchyLeft,
	   hierarchyRight = -1 * companyNestedSets.hierarchyRight
from   corporate.companyNestedSets
			join corporate.companyNestedSets as searchFor
				on companyNestedSets.hierarchyLeft >= searchFor.hierarchyLeft 
				   and companyNestedSets.hierarchyRight <= searchFor.hierarchyRight
where  searchFor.Name = @Location

--refit the nodes to deal with the missing items. Now the positive values form a proper tree
UPDATE corporate.companyNestedSets 
SET	   hierarchyLeft = companyNestedSets.hierarchyLeft - (@numNodesToMove * 2)
WHERE  hierarchyLeft >= @startNode

--done in seperate statements because of the largest hierarchyRight value
UPDATE corporate.companyNestedSets 
SET	   hierarchyRight = companyNestedSets.hierarchyRight - (@numNodesToMove * 2)
WHERE  hierarchyRight >= @startNode


--get the position of the location where we are going to put the nodes we removed.
declare @targetLeft int, @targetRight int
select @targetLeft = hierarchyLeft, @targetRight = hierarchyRight
from   corporate.companyNestedSets
where  name =  @newParentLocation

--make room for the nodes you are moving
UPDATE corporate.companyNestedSets 
SET	   hierarchyLeft = companyNestedSets.hierarchyLeft + (@numNodesToMove * 2)
WHERE  hierarchyLeft > @targetLeft

UPDATE corporate.companyNestedSets 
SET	   hierarchyRight = companyNestedSets.hierarchyRight + (@numNodesToMove * 2)
WHERE  hierarchyRight > @targetLeft

--get the offset that we will use to make the negative rows look like a proper negative hierarchy
declare @moveFactor int
select @moveFactor = abs(max(hierarchyLeft) + 1)
from   corporate.companyNestedSets
where  hierarchyLeft < 0

--fix the negative rows to look like a proper hierarchy, 
update corporate.companyNestedSets
set    hierarchyLeft = (hierarchyLeft + @moveFactor) , 
		hierarchyRight = (hierarchyRight + @moveFactor) 
where  hierarchyLeft < 0

--then place rows into hierarchy
update corporate.companyNestedSets
set    hierarchyLeft = (abs(hierarchyLeft) + @targetLeft)
	   ,hierarchyRight = abs(hierarchyRight) + @targetLeft
where  hierarchyRight < 0

commit
go
select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   corporate.companyNestedSets
order by hierarchyLeft
go

corporate.companyNestedSets$reparent 'Maine HQ','Nashville Branch'
go
select *
from   corporate.companyNestedSets
order by hierarchyLeft
go

----------------------------------------------------------------------------------
-- kimball helper table

--reset the tree to original state
truncate table  corporate.company 
EXEC corporate.company$insert @name = 'Company HQ', @parentCompanyName = NULL;
EXEC corporate.company$insert @name = 'Maine HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.company$insert @name = 'Tennessee HQ', @parentCompanyName = 'Company HQ';
EXEC corporate.company$insert @name = 'Nashville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.company$insert @name = 'Knoxville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.company$insert @name = 'Memphis Branch', @parentCompanyName = 'Tennessee HQ';
EXEC corporate.company$insert @name = 'Portland Branch', @parentCompanyName = 'Maine HQ';
EXEC corporate.company$insert @name = 'Camden Branch', @parentCompanyName = 'Maine HQ';
GO

create table corporate.companyHiererarchyHelper
(
	ParentCompanyId	int, 
	ChildCompanyId  int, 
	Distance        int, 
	ParentRootNodeFlag bit, 
	ChildLeafNodeFlag  bit,
	CONSTRAINT PKcompanyHiererarchyHelper PRIMARY KEY (ParentCompanyId, ChildCompanyId)
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
	--added to original tree example with distance, root and leaf node indicators
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
--parent root node is about the parent, which for that call is always 1

select hierarchyHelper.ParentCompanyId, hierarchyHelper.ChildCompanyId, hierarchyHelper.Distance, 
	   hierarchyHelper.ParentRootNodeFlag, hierarchyHelper.ChildLeafNodeFlag
from   corporate.company
		cross apply corporate.company$returnHierarchyHelper(company.companyId) as hierarchyHelper
order by hierarchyHelper.ParentCompanyId


--save off the rows
insert into corporate.companyHiererarchyHelper(
	ParentCompanyId, ChildCompanyId, Distance, ParentRootNodeFlag, ChildLeafNodeFlag
	)
select hierarchyHelper.ParentCompanyId, hierarchyHelper.ChildCompanyId, hierarchyHelper.Distance, 
	   hierarchyHelper.ParentRootNodeFlag, hierarchyHelper.ChildLeafNodeFlag
from   corporate.company
		cross apply corporate.company$returnHierarchyHelper(company.companyId) as hierarchyHelper

GO


--Children of Tennessee
select company.*, companyHiererarchyHelper.*
from   corporate.companyHiererarchyHelper 
		 join corporate.Company
			on company.companyId = companyHiererarchyHelper.ChildCompanyId
where  companyHiererarchyHelper.parentCompanyId = (select companyId from corporate.company where name = 'Tennessee HQ')

--get children of Tennessee HQ including HQ
select getNodes.*
from   corporate.company --the target row we care about
		  join corporate.companyHiererarchyHelper --gets the hierarchy helper rows that are for the companyId that we searched for
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


--No need for reparent, as the helper table represents a view of the data, not the actual structure in use.