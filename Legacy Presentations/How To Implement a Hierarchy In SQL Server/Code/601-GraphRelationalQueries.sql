USE HowToOptimizeAHierarchyInSQLServer;
go

SELECT *
FROM   social.Person
WHERE  UserName = 'Fred';
GO

--what fred is interested in
SELECT Person.UserName, PersonInterest.InterestName
FROM   social.Person
		 JOIN Social.PersonInterest
			ON PersonInterest.PersonId = Person.PersonId
WHERE  Person.UserName = 'Fred' 
GO

--everyone's interest
SELECT Person.UserName, PersonInterest.InterestName
FROM   Social.Person
		 JOIN Social.PersonInterest
			ON PersonInterest.PersonId = Person.PersonId
GO

 --who fred is directly connected to
SELECT FromPerson.UserName AS FromUserName, ToPerson.UserName AS ToUserName
FROM   social.Person AS FromPerson
		 JOIN Social.PersonConnection
			ON PersonConnection.PersonId = FromPerson.PersonId
		 JOIN Social.Person AS ToPerson
			ON ToPerson.PersonId = PersonConnection.ConnectedToPersonId
WHERE  FromPerson.UserName = 'Fred'
GO


--connected to anyone
SELECT FromPerson.UserName AS FromUserName, ToPerson.UserName AS ToUserName
FROM   social.Person AS FromPerson
		 JOIN Social.PersonConnection
			ON PersonConnection.PersonId = FromPerson.PersonId
		 JOIN Social.Person AS ToPerson
			ON ToPerson.PersonId = PersonConnection.ConnectedToPersonId



--show relationships are directional
SELECT FromPerson.UserName AS FromUserName, ToPerson.UserName AS ToUserName
FROM   social.Person AS FromPerson
		 JOIN Social.PersonConnection
			ON PersonConnection.PersonId = FromPerson.PersonId
		 JOIN Social.Person AS ToPerson
			ON ToPerson.PersonId = PersonConnection.ConnectedToPersonId
WHERE  FromPerson.UserName = 'Barney' OR FromPerson.UserName = 'BamBam'


--Shared Interests
WITH PersonInterest AS (
--persons interest
SELECT Person.UserName, PersonInterest.InterestName
FROM   social.Person
		 JOIN Social.PersonInterest
			ON PersonInterest.PersonId = Person.PersonId)

--then shared
SELECT FromPersonInterest.UserName AS FromUserName, ToPersonInterest.UserName AS ToUserName, FromPersonInterest.InterestName
FROM   PersonInterest AS FromPersonInterest
		JOIN PersonInterest AS ToPersonInterest
			ON ToPersonInterest.InterestName = FromPersonInterest.InterestName
			   AND ToPersonInterest.UserName <> FromPersonInterest.UserName 
ORDER BY FromUserName, ToUserName, FromPersonInterest.InterestName
GO


--Shared Interest, and are connected

WITH PersonInterest AS (
SELECT Person.UserName, PersonInterest.InterestName, Person.PersonId
FROM   social.Person
		 JOIN Social.PersonInterest
			ON PersonInterest.PersonId = Person.PersonId)

SELECT FromPersonInterest.UserName AS FromUserName, ToPersonInterest.UserName AS ToUserName, FromPersonInterest.InterestName
FROM   PersonInterest AS FromPersonInterest --shared interest
		JOIN PersonInterest AS ToPersonInterest
			ON ToPersonInterest.InterestName = FromPersonInterest.InterestName
			   AND ToPersonInterest.UserName <> FromPersonInterest.UserName 

WHERE EXISTS (SELECT * --and are connected
			  FROM   Social.PersonConnection
			  WHERE  PersonConnection.PersonId = FromPersonInterest.PersonId
			    AND  PersonConnection.ConnectedToPersonId = ToPersonInterest.PersonId)
ORDER BY FromUserName, ToUserName, FromPersonInterest.InterestName



--DECLARE @personId int = (select personId from Social.Person where userName='Fred');
DECLARE @personId int = (select personId from Social.Person where userName='BamBam');

--based solely on connections
WITH personHierarchy(personId, connectedToPersonId, TreeLevel, Hierarchy)
AS
(
     --gets the top level in Hierarchy we want. The Hierarchy column
     --will show the row's place in the Hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT PersonID, PersonId,
            0 as TreeLevel, '\' + CAST(PersonId as varchar(max)) +'\' as Hierarchy
     FROM   Social.Person
     WHERE PersonId=@PersonId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that TreeLevel is incremented on each iteration
     SELECT PersonConnection.ConnectedToPersonId AS PersonID, PersonConnection.PersonId,
            TreeLevel + 1 as TreeLevel,
            Hierarchy + cast(PersonConnection.ConnectedToPersonId as varchar(20)) + '\'  as Hierarchy
     FROM   Social.PersonConnection
              INNER JOIN PersonHierarchy
                on PersonConnection.PersonId= PersonHierarchy.PersonID 
	 --stop the loop for a connection if we circle back to the same person to deal with cycles
	 where  Hierarchy not like '%\' + cast(PersonConnection.ConnectedToPersonId as varchar(20)) + '\%'

)

--return results from the CTE, joining to the Person data to get the 
--Person Name
, formattingSection AS (
SELECT  Person.PersonID,Person.UserName, TreeLevel, PersonHierarchy.Hierarchy as Hierarchy
		--eliminates multiple match paths
		, ROW_NUMBER() OVER (PARTITION BY Person.UserName ORDER BY TreeLevel) AS RankValue
FROM     Social.Person
         INNER JOIN PersonHierarchy
              ON Person.PersonID = PersonHierarchy.PersonID
where   TreeLevel > 0)

SELECT formattingSection.UserName, TreeLevel + 1 AS Distance, Hierarchy AS Path
FROM   formattingSection
WHERE  RankValue = 1
ORDER BY Distance


GO

