use master
Go
set nocount on
go
--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'Patterns_Graphs')
 exec ('
alter database  Patterns_Graphs
	set single_user with rollback immediate;

drop database Patterns_Graphs;')


CREATE DATABASE Patterns_Graphs;
GO
USE Patterns_Graphs;
GO
-----------------------------------------------------------------
--  Tools (Generally user facing that they can rely on)
-----------------------------------------------------------------

CREATE SCHEMA Tools
go
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

CREATE FUNCTION Tools.String$Parse (@list VARCHAR(8000),@delimiter char(1) =',') 
RETURNS @tbl TABLE ( id varchar(30)) 
AS 
  BEGIN 
      DECLARE @valuelen INT, 
              @pos      INT, 
              @nextpos  INT 

      SELECT @pos = 0, 
             @nextpos = 1 
	  
	  if left(@list,1) = @delimiter set @list = substring(@list,2,8000)
	  if left(reverse(@list),1) = @delimiter set @list = reverse(substring(reverse(@list),2,8000))

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


CREATE SCHEMA Social;
GO


/********************
Simple adjacency list
********************/
CREATE TABLE Social.Person
(
    PersonId   int identity (1,1) CONSTRAINT PKperson primary key,
    UserName   nvarchar(30) not null CONSTRAINT AKperson_userName UNIQUE,
);  

CREATE TABLE Social.PersonInterest
(
	PersonId  int not null,
	InterestName nvarchar(30) not null,
	CONSTRAINT PKPersonInterest primary key  (PersonId, InterestName)
)
GO
create table Social.PersonConnection
(
	PersonId	int not null,
	ConnectedToPersonId int not null,
	CONSTRAINT PKPersonConnection primary key  (PersonId, ConnectedToPersonId),
	CONSTRAINT CKPersonConnection_NoSelfLove CHECK (PersonId <> ConnectedToPersonId)
)
go
CREATE PROCEDURE Social.person$insert(@username nvarchar(60),@interestList varchar(8000))  
as
BEGIN
	INSERT INTO Social.Person (username) 
	values (@username)

	DECLARE @PersonId int = (SELECT personId
							 from   Social.Person
							 WHERE  userName = @username)

	insert into Social.PersonInterest(PersonId, InterestName)
	SELECT @PersonId, id
	FROM   Tools.String$Parse (@interestList,',') 

END
GO


--SELECT Person.UserName, PersonInterest.InterestName
--FROM    Social.Person
--		 join Social.PersonInterest
--			on Person.PersonId = PersonInterest.PersonId
--Order by UserName
--GO

create procedure Social.Person$InsertConnections(@username nvarchar(60),@userNameList varchar(8000))  
as
BEGIN
	declare @personId int = (SELECT PersonId from Social.Person where Username = @userName)

	INSERT INTO Social.PersonConnection
	SELECT @PersonId, PersonId
	from   Social.Person
			 join Tools.String$Parse (@userNameList,',')  as PersonList
				on Person.Username = PersonList.Id

END
GO


EXEC Social.Person$Insert @username = 'Fred',@interestList ='Bowling,Violence,Fishing,Pet Dinosaurs,Water Buffalos, Rock Quarry'
EXEC Social.Person$Insert @username = 'Barney',@interestList ='Bowling,Peace,Water Buffalos,Super Strong Kids'
EXEC Social.Person$Insert @username = 'Wilma',@interestList ='Charging,Society'
EXEC Social.Person$Insert @username = 'Betty',@interestList ='Charging,Pearls'
EXEC Social.Person$Insert @username = 'Mr_Slate',@interestList ='Water Buffalos,Rock Quarry'
EXEC Social.Person$Insert @username = 'Slagstone',@interestList ='Water Buffalos,Bowling'
EXEC Social.Person$Insert @username = 'Gazoo',@interestList =''
EXEC Social.Person$Insert @username = 'Hoppy',@interestList =''
EXEC Social.Person$Insert @username = 'Schmoo',@interestList =''
EXEC Social.Person$Insert @username = 'Slaghoople',@interestList =''
EXEC Social.Person$Insert @username = 'Pebbles',@interestList =''
EXEC Social.Person$Insert @username = 'BamBam',@interestList =''
EXEC Social.Person$Insert @username = 'Rockhead',@interestList ='Bowling'
EXEC Social.Person$Insert @username = 'Arnold',@interestList =''
EXEC Social.Person$Insert @username = 'ArnoldMom',@interestList =''
EXEC Social.Person$Insert @username = 'Tex',@interestList =''
EXEC Social.Person$Insert @username = 'NotReally',@interestList =''
EXEC Social.Person$Insert @username = 'FurtherOut',@interestList =''
EXEC Social.Person$Insert @username = 'WayOut',@interestList =''
EXEC Social.Person$Insert @username = 'WayWayOut',@interestList =''
EXEC Social.Person$Insert @username = 'WayWayWayOut',@interestList =''
EXEC Social.Person$Insert @username = 'WayWayWayWayOut',@interestList =''
EXEC Social.Person$Insert @username = 'WayWayWayWayWayOut',@interestList ='Bowling'
EXEC Social.Person$Insert @username = 'Dino',@interestList =''


Exec Social.Person$InsertConnections @userName = 'Fred', @userNameList = 'Barney,Wilma,Betty,Mr_Slate,Slagstone,Dino'
Exec Social.Person$InsertConnections @userName = 'Barney',@userNameList = 'Wilma,Betty,Fred'
Exec Social.Person$InsertConnections @userName = 'Wilma',@userNameList = 'Barney,Fred,Betty'
Exec Social.Person$InsertConnections @userName = 'Betty',@userNameList = 'Barney,Wilma,Fred'
Exec Social.Person$InsertConnections @userName = 'Mr_Slate',@userNameList = 'Fred'
Exec Social.Person$InsertConnections @userName = 'Slagstone',@userNameList = 'Fred,Barney'
Exec Social.Person$InsertConnections @userName = 'Gazoo', @userNameList = 'Fred,Barney'
Exec Social.Person$InsertConnections @userName = 'Slaghoople',@userNameList = 'Wilma'
Exec Social.Person$InsertConnections @userName = 'Dino',@userNameList = 'Fred'
Exec Social.Person$InsertConnections @userName = 'Pebbles',@userNameList = 'Fred,Barney,BamBam,Dino'
Exec Social.Person$InsertConnections @userName = 'BamBam',@userNameList = 'Barney,Betty,Pebbles,Hopy'
Exec Social.Person$InsertConnections @userName = 'Rockhead',@userNameList = 'Fred'
Exec Social.Person$InsertConnections @userName = 'Arnold',@userNameList = 'Fred,Barney'
Exec Social.Person$InsertConnections @userName = 'ArnoldMom',@userNameList = 'Arnold'
Exec Social.Person$InsertConnections @userName = 'Tex',@userNameList = 'Fred,Wilma'
Exec Social.Person$InsertConnections @userName = 'NotReally',@userNameList = 'Fred'
Exec Social.Person$InsertConnections @userName = 'FurtherOut',@userNameList = 'NotReally'
Exec Social.Person$InsertConnections @userName = 'WayOut',@userNameList = 'FurtherOut'
Exec Social.Person$InsertConnections @userName = 'WayWayOut',@userNameList = 'WayOut'
Exec Social.Person$InsertConnections @userName = 'WayWayWayOut',@userNameList = 'WayWayOut'
Exec Social.Person$InsertConnections @userName = 'WayWayWayWayOut',@userNameList = 'WayWayWayOut'
Exec Social.Person$InsertConnections @userName = 'WayWayWayWayWayOut',@userNameList = 'WayWayWayWayOut'


--getting the children of a row (or ancestors with slight mod to query)
DECLARE @personId int = (select personId from Social.Person where userName='Fred');


;WITH personHierarchy(personId, parentPersonId, treelevel, hierarchy)
AS
(
     --gets the top level in hierarchy we want. The hierarchy column
     --will show the row's place in the hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT personiD, connectedToPersonId,
            0 as treelevel, '\' + CAST(PersonId as varchar(max)) +'\' as hierarchy
     FROM   Social.PersonConnection
     WHERE PersonId=@PersonId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that treelevel is incremented on each iteration
     SELECT PersonConnection.PersonID, PersonConnection.ConnectedToPersonId,
            treelevel + 1 as treelevel,
            hierarchy + cast(PersonConnection.PersonId as varchar(20)) + '\'  as hierarchy
     FROM   Social.PersonConnection
              INNER JOIN PersonHierarchy
                on PersonConnection.ConnectedToPersonId= PersonHierarchy.PersonID 
	 where  hierarchy not like '%\' + cast(PersonConnection.PersonId as varchar(20)) + '\%'

)
--return results from the CTE, joining to the Person data to get the 
--Person name
SELECT  Person.PersonID,Person.Username, min(PersonHierarchy.treelevel) as distance
FROM     Social.Person
         INNER JOIN PersonHierarchy
              ON Person.PersonID = PersonHierarchy.PersonID
where   treelevel > 0
group by Person.PersonID,Person.Username
ORDER BY username;
GO


--getting the children of a row (or ancestors with slight mod to query)
DECLARE @personId int = (select personId from Social.Person where userName='Fred');
declare @personInterests table (interestName nvarchar(30))
insert into @personInterests
select interestName
from   Social.PersonInterest
where  personId = @personId

;WITH personHierarchy(personId, parentPersonId, treelevel, hierarchy)
AS
(
     --gets the top level in hierarchy we want. The hierarchy column
     --will show the row's place in the hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT personiD, connectedToPersonId,
            0 as treelevel, '\' + CAST(PersonId as varchar(max)) +'\' as hierarchy
     FROM   Social.PersonConnection
     WHERE PersonId=@PersonId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that treelevel is incremented on each iteration
     SELECT PersonConnection.PersonID, PersonConnection.ConnectedToPersonId,
            treelevel + 1 as treelevel,
            hierarchy + cast(PersonConnection.PersonId as varchar(20)) + '\'  as hierarchy
     FROM   Social.PersonConnection
              INNER JOIN PersonHierarchy
                on PersonConnection.ConnectedToPersonId= PersonHierarchy.PersonID 
	 where  hierarchy not like '%\' + cast(PersonConnection.PersonId as varchar(20)) + '\%'

)
--return results from the CTE, joining to the Person data to get the 
--Person name
select  *
FROM   (
		SELECT   Person.PersonID,Person.Username,min(treeLevel) as distance
		FROM     Social.Person
				 INNER JOIN PersonHierarchy
					  ON Person.PersonID = PersonHierarchy.PersonID
		where   treelevel > 0
		group by  Person.PersonID,Person.Username) as matches
WHERE exists (select *
					from   Social.PersonInterest
					where  PersonInterest.PersonId = matches.PersonId
					 and   InterestName in (select InterestName
											from  @personInterests))

ORDER BY username;
GO



----getting the children of a row 
--DECLARE @companyId int = 3;

--;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
--AS
--(
--     --gets the top level in hierarchy we want. The hierarchy column
--     --will show the row's place in the hierarchy from this query only
--     --not in the overall reality of the row's place in the table
--     SELECT companyID, parentCompanyId,
--            1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
--     FROM   corporate.company
--     WHERE companyId=@CompanyId

--     UNION ALL

--     --joins back to the CTE to recursively retrieve the rows 
--     --note that treelevel is incremented on each iteration
--     SELECT company.companyID, company.parentCompanyId,
--            treelevel + 1 as treelevel,
--            hierarchy + '\' +cast(company.companyId as varchar(20)) as hierarchy
--     FROM   corporate.company as company
--              INNER JOIN companyHierarchy
--                --use to get children, since the parentCompanyId of the child will be set the value
--				--of the current row
--                on company.parentCompanyId= companyHierarchy.companyID 
--                --use to get parents, since the parent of the companyHierarchy row will be the company, 
--				--not the parent.
--                --on company.CompanyId= companyHierarchy.parentcompanyID
--)
----return results from the CTE, joining to the company data to get the 
----company name
--SELECT  company.companyID,company.name,
--        companyHierarchy.treelevel, companyHierarchy.hierarchy
--FROM     corporate.company as company
--         INNER JOIN companyHierarchy
--              ON company.companyID = companyHierarchy.companyID
--ORDER BY hierarchy;

--GO

----getting the parents of companyId = 7
--DECLARE @companyId int = 7;

--;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
--AS
--(
--     --gets the top level in hierarchy we want. The hierarchy column
--     --will show the row's place in the hierarchy from this query only
--     --not in the overall reality of the row's place in the table
--     SELECT companyID, parentCompanyId,
--            1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
--     FROM   corporate.company
--     WHERE companyId=@CompanyId

--     UNION ALL

--     --joins back to the CTE to recursively retrieve the rows 
--     --note that treelevel is incremented on each iteration
--     SELECT company.companyID, company.parentCompanyId,
--            treelevel + 1 as treelevel,
--            hierarchy + '\' +cast(company.companyId as varchar(20)) as hierarchy
--     FROM   corporate.company as company
--              INNER JOIN companyHierarchy
--                --use to get children, since the parentCompanyId of the child will be set the value
--				--of the current row
--                --on company.parentCompanyId= companyHierarchy.companyID 
--                --use to get parents, since the parent of the companyHierarchy row will be the company, 
--				--not the parent.
--                on company.CompanyId= companyHierarchy.parentcompanyID
--)
----return results from the CTE, joining to the company data to get the 
----company name
--SELECT  company.companyID,company.name,
--        companyHierarchy.treelevel, companyHierarchy.hierarchy
--FROM     corporate.company as company
--         INNER JOIN companyHierarchy
--              ON company.companyID = companyHierarchy.companyID
--ORDER BY hierarchy;

--GO

--CREATE PROCEDURE corporate.company$Reparent(@name varchar(20), @newParentCompanyName  varchar(20)) 
--as
--BEGIN
--	UPDATE corporate.company 
--	SET    ParentCompanyId = (select companyId as parentCompanyId
--							   from   corporate.company
--							   where  company.name = @newParentCompanyName)
--	WHERE  name = @name
--END
--GO

--EXEC corporate.company$Reparent @name = 'Maine HQ', @newParentCompanyName = 'Nashville Branch'
--GO

