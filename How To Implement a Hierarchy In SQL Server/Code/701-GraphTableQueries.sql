

USE HowToOptimizeAHierarchyInSQLServer
GO
--Show Fred
SELECT *
FROM   SocialGraph.Person
WHERE  UserName = 'Fred';
GO

 --What Fred Is Interested In
SELECT Person.UserName, Interest.InterestName
FROM   SocialGraph.Person, SocialGraph.Interest, SocialGraph.InterestedIn
WHERE  MATCH(Person-(InterestedIn)->Interest)
  AND   Person.UserName = 'Fred' --what fred is interested in


--Everyone's interest
SELECT Person.UserName, Interest.InterestName
FROM   SocialGraph.Person, SocialGraph.Interest AS Interest, SocialGraph.InterestedIn
WHERE  MATCH(Person-(InterestedIn)->Interest)
ORDER BY Person.UserName, Interest.InterestName;
 
 --Note: Join cannot even be a CROSS JOIN, or you will get:
 --Identifier 'Person' in a MATCH clause is used with a JOIN clause or APPLY operator. JOIN and APPLY are not supported with MATCH clauses.


  --who fred is connected to
 SELECT FromPerson.UserName AS FromUserName, ToPerson.UserName AS ToUserName
FROM    SocialGraph.Person AS FromPerson, SocialGraph.ConnectedTo AS ConnectedTo,
		SocialGraph.Person AS ToPerson
WHERE  MATCH(FromPerson-(ConnectedTo)->ToPerson)
 AND   FromPerson.UserName = 'Fred'
 ORDER BY FromUserName, ToUserName

--this query is nonsense... But it runs (it basically looks for rows connected to themselves, only
--and we stopped that with a check constraint)
SELECT FromPerson.UserName AS FromUserName
FROM  SocialGraph.Person AS FromPerson, SocialGraph.ConnectedTo AS ConnectedTo
WHERE MATCH(FromPerson-(ConnectedTo)->FromPerson)
ORDER BY FromUserName


--Everyone's Connections
SELECT FromPerson.UserName AS FromUserName, ToPerson.UserName AS ToUserName
FROM   SocialGraph.Person AS FromPerson, SocialGraph.ConnectedTo AS ConnectedTo, SocialGraph.Person AS ToPerson
WHERE  MATCH(FromPerson-(ConnectedTo)->ToPerson)
ORDER BY FromUserName, ToUserName


 --two people who like the same thing
SELECT Person1.UserName AS FromUserName, Person2.UserName AS ToUserName, Interest.InterestName AS SharedInterestName
FROM   SocialGraph.Person AS Person1, 
	   SocialGraph.Person AS Person2,
	   SocialGraph.Interest AS Interest, 
	   SocialGraph.InterestedIn,
	   SocialGraph.InterestedIn AS InterestedIn2
	   --person1 is interested in an interest, and person2 is also
WHERE  MATCH(Person1-(InterestedIn)->Interest<-(InterestedIn2)-Person2)
  AND  Person1.$node_id <> Person2.$node_id --not the same node
ORDER BY FromUserName, ToUserName, SharedInterestName;


--Shared Interest, and are connected
SELECT Person1.UserName AS FromUserName, Person2.UserName AS ToUserName, Interest.InterestName AS SharedInterestName
FROM   SocialGraph.Person AS Person1
	   ,SocialGraph.Person AS Person2
	   ,SocialGraph.Interest AS Interest
	   ,SocialGraph.InterestedIn
	   ,SocialGraph.InterestedIn AS InterestedIn2
	   ,SocialGraph.ConnectedTo
	   --person1 is interested in an interest, and person2 is also
WHERE  MATCH(Person1-(InterestedIn)->Interest<-(InterestedIn2)-Person2)
     --person1 is connected to person2
AND   MATCH(Person1-(ConnectedTo)->Person2)
ORDER BY FromUserName, ToUserName, SharedInterestName;

--Cannot do both directions using OR
SELECT Person1.UserName AS FromUserName, Person2.UserName AS ToUserName, Interest.InterestName AS SharedInterestName
FROM   SocialGraph.Person AS Person1
	   ,SocialGraph.Person AS Person2
	   ,SocialGraph.Interest AS Interest
	   ,SocialGraph.InterestedIn
	   ,SocialGraph.InterestedIn AS InterestedIn2
	   ,SocialGraph.ConnectedTo
	   ,SocialGraph.ConnectedTo AS ConnectedTo2
	   --person1 is interested in an interest, and person2 is also
WHERE  MATCH(Person1-(InterestedIn)->Interest<-(InterestedIn2)-Person2)
     --person1 is connected to person2
AND   (MATCH(Person1-(ConnectedTo)->Person2)
      OR MATCH(Person2-(ConnectedTo2)->Person1))
ORDER BY FromUserName, ToUserName, SharedInterestName;


--person connected to a person that the other person is connected to (so second level connections)
--	(distinct because there are different paths to the same node)
SELECT  DISTINCT Person1.UserName AS FromUserName, Person2.UserName AS ToUserName
FROM   SocialGraph.Person AS Person1,
		SocialGraph.ConnectedTo AS ConnectedTo, 
		SocialGraph.Person AS Person2
	   ,SocialGraph.ConnectedTo AS ConnectedTo2, 
	   SocialGraph.Person AS ThroughPerson
WHERE  MATCH(Person1-(ConnectedTo)->ThroughPerson-(ConnectedTo2)->Person2)
ORDER BY FromUserName, ToUserName

--2nd level connections for fred (distinct because there are different paths)
SELECT DISTINCT Person1.UserName AS FromUserName, Person2.UserName AS ToUserName
FROM   SocialGraph.Person AS Person1,
		SocialGraph.ConnectedTo AS ConnectedTo, 
		SocialGraph.Person AS Person2
	   ,SocialGraph.ConnectedTo AS ConnectedTo2, 
	   SocialGraph.Person AS ThroughPerson
WHERE  MATCH(Person1-(ConnectedTo)->ThroughPerson-(ConnectedTo2)->Person2)
  AND  Person1.UserName = 'Fred'
ORDER BY FromUserName, ToUserName

--2nd level connections for BamBam (distinct because there are different paths)
SELECT DISTINCT Person1.UserName AS FromUserName, Person2.UserName AS ToUserName
FROM   SocialGraph.Person AS Person1,
		SocialGraph.ConnectedTo AS ConnectedTo, 
		SocialGraph.Person AS Person2
	   ,SocialGraph.ConnectedTo AS ConnectedTo2, 
	   SocialGraph.Person AS ThroughPerson
WHERE  MATCH(Person1-(ConnectedTo)->ThroughPerson-(ConnectedTo2)->Person2)
  AND  Person1.UserName = 'BamBam'
ORDER BY FromUserName, ToUserName


--person connected to person indirectly at any level

--can't use MATCH on the CTE version of the object due to:

--Msg 13919, Level 16, State 1, Line 186
--Identifier 'PersonHierarchy' in a MATCH clause corresponds to a derived table. Derived tables are not supported in MATCH clauses.

--Hence we have to use one of the following methods.

--METHOD 1. Use Edge as a relational Many To Many

--DECLARE @UserName nvarchar(60) = 'Fred'
DECLARE @UserName nvarchar(60) = 'BamBam'

--based solely on connections
;WITH personHierarchy
AS
(
     --gets the top level in Hierarchy we want. The Hierarchy column
     --will show the row's place in the Hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT Person.$node_id AS node_id, 
			Person.UserName,
            0 as TreeLevel, '\' + CAST(UserName as varchar(max)) +'\' as Hierarchy
     FROM   SocialGraph.Person
     WHERE UserName = @UserName

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that TreeLevel is incremented on each iteration
     SELECT $node_id AS node_id, 
			ToPerson.UserName,
            TreeLevel + 1 as TreeLevel,
            Hierarchy + cast(ToPerson.UserName as varchar(20)) + '\'  as Hierarchy
     FROM   PersonHierarchy
				JOIN SocialGraph.ConnectedTo
					ON personHierarchy.node_id = ConnectedTo.$from_id
				JOIN SocialGraph.Person AS ToPerson
					ON ToPerson.$node_id = ConnectedTo.$to_id
     WHERE  personHierarchy.UserName <> ToPerson.UserName
	   --stop the loop for a connection if we circle back to the same person to deal with cycles
	   AND  Hierarchy not like '%\' + ToPerson.UserName + '\%'

)
--return results from the CTE, joining to the Person data to get the 
--Person Name
, formattingSection AS (
SELECT  Person.UserName, TreeLevel, PersonHierarchy.Hierarchy as Hierarchy
		--eliminates multiple MATCH paths
		, ROW_NUMBER() OVER (PARTITION BY Person.UserName ORDER BY TreeLevel) AS RankValue
FROM     SocialGraph.Person
         INNER JOIN PersonHierarchy
              ON Person.UserName = PersonHierarchy.UserName
where   TreeLevel > 0)

SELECT formattingSection.UserName, TreeLevel  AS Distance, Hierarchy AS Path
FROM   formattingSection
--Take this out to see the multiple paths
WHERE  RankValue = 1
ORDER BY Distance;
GO

--METHOD 2 - Use JOINS to get proper Node tables and use MATCH function

--DECLARE @UserName nvarchar(60) = 'Fred'
DECLARE @UserName nvarchar(60) = 'BamBam'

--based solely on connections
;WITH personHierarchy(UserName, TreeLevel, Hierarchy)
AS
(
     --gets the top level in Hierarchy we want. The Hierarchy column
     --will show the row's place in the Hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT Person.UserName, 
            0 as TreeLevel, '\' + CAST(UserName as varchar(max)) +'\' as Hierarchy
     FROM   SocialGraph.Person
     WHERE UserName = @UserName

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that TreeLevel is incremented on each iteration
     SELECT ToPerson.UserName, 
            TreeLevel + 1 as TreeLevel,
            Hierarchy + cast(ToPerson.UserName as varchar(20)) + '\'  as Hierarchy
     FROM   PersonHierarchy, SocialGraph.Person	AS FromPerson,
			 --Cannot mix joins
			 --JOIN SocialGraph.Person	AS FromPerson
				--ON FromPerson.UserName = PersonHierarchy.UserName,
			SocialGraph.ConnectedTo,SocialGraph.Person AS ToPerson
     WHERE  personHierarchy.UserName = FromPerson.UserName
	   AND MATCH(FromPerson-(ConnectedTo)->ToPerson)
	   --stop the loop for a connection if we circle back to the same person to deal with cycles
	   AND  Hierarchy not like '%\' + ToPerson.UserName + '\%'

)
--return results from the CTE, joining to the Person data to get the 
--Person Name
, formattingSection AS (
SELECT  Person.UserName, TreeLevel, PersonHierarchy.Hierarchy as Hierarchy
		--eliminates multiple MATCH paths
		, ROW_NUMBER() OVER (PARTITION BY Person.UserName ORDER BY TreeLevel) AS RankValue
FROM     SocialGraph.Person
         INNER JOIN PersonHierarchy
              ON Person.UserName = PersonHierarchy.UserName
where   TreeLevel > 0)

SELECT formattingSection.UserName, TreeLevel  AS Distance, Hierarchy AS Path
FROM   formattingSection
--Take this out to see the multiple paths
WHERE  RankValue = 1
ORDER BY Distance;


GO