USE HowToOptimizeAHierarchyInSQLServer;
GO
DROP PROCEDURE IF EXISTS SocialGraph.person$Insert;
DROP PROCEDURE IF EXISTS SocialGraph.Person$InsertConnections;
DROP TABLE IF EXISTS SocialGraph.ConnectedTo;
DROP TABLE IF EXISTS SocialGraph.InterestedIn;
DROP TABLE IF EXISTS SocialGraph.Person;
DROP TABLE IF EXISTS SocialGraph.Interest;

DROP SCHEMA IF EXISTS SocialGraph;
GO
CREATE SCHEMA SocialGraph;
GO
CREATE TABLE SocialGraph.Person (UserName nvarchar(30) UNIQUE) AS NODE;
CREATE TABLE SocialGraph.ConnectedTo (CreateTime datetime2 DEFAULT SYSDATETIME()) AS EDGE;

--disallow duplicate nodes
CREATE UNIQUE INDEX uniqueNodes ON SocialGraph.ConnectedTo($from_id, $to_id);

CREATE TABLE SocialGraph.Interest (InterestName nvarchar(30) UNIQUE) AS NODE;
CREATE TABLE SocialGraph.InterestedIn AS EDGE;

--unique nodes
CREATE UNIQUE INDEX uniqueNodes ON SocialGraph.InterestedIn($from_id, $to_id);
GO

SELECT is_node, is_edge, *
FROM   sys.tables
WHERE  SCHEMA_NAME(tables.schema_id) = 'SocialGraph';

SELECT *
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  COLUMNS.TABLE_SCHEMA = 'SocialGraph'
ORDER BY COLUMNS.TABLE_NAME, ORDINAL_POSITION

GO

CREATE OR ALTER PROCEDURE SocialGraph.Person$Insert
(
    @UserName     nvarchar(60),
    @interestList varchar(8000)
)
AS
BEGIN
	--No error handling for cleanliness of demo... You should have error handling when you do this for realsville.

    INSERT INTO SocialGraph.Person(UserName)
    VALUES(@UserName);

	DECLARE @NodeId nvarchar(1000) 
	SET @NodeId = (SELECT $node_id FROM SocialGraph.Person WHERE userName = @UserName)

	--create any new interests
    INSERT INTO SocialGraph.Interest( InterestName)
    SELECT value
    FROM   STRING_SPLIT(@interestList, ',') AS list
	WHERE  list.value <> ''
	  AND  list.value NOT IN (SELECT InterestName
						      FROM    SocialGraph.Interest)

	INSERT INTO SocialGraph.InterestedIn($from_id, $to_id)
	SELECT @NodeId,
			(SELECT $NODE_ID FROM SocialGraph.Interest WHERE Interest.InterestName = list.value)
	FROM   STRING_SPLIT(@interestList, ',') AS list
	WHERE list.value <> ''
END
GO

CREATE OR ALTER PROCEDURE SocialGraph.Person$InsertConnections
(
    @userName     nvarchar(60),
    @userNameList varchar(8000)
)
AS
BEGIN
	DECLARE @NodeId nvarchar(1000)
	SET @NodeId = (SELECT $NODE_ID FROM SocialGraph.Person WHERE userName = @UserName)

	INSERT INTO SocialGraph.ConnectedTo($from_id, $to_id)
	SELECT @NodeId,
			(SELECT $NODE_ID FROM SocialGraph.Person WHERE userName = list.value)
	FROM   STRING_SPLIT(@userNameList, ',') AS list
	WHERE  value <> ''

END;
GO


EXEC SocialGraph.person$Insert @userName = 'Fred',
                          @interestList = 'Bowling,Violence,Fishing,Pet Dinosaurs,Water Buffalos,Rock Quarry';

EXEC SocialGraph.person$Insert @userName = 'Barney', @interestList = 'Bowling,Peace,Water Buffalos,Super Strong Kids';

EXEC SocialGraph.person$Insert @userName = 'Wilma', @interestList = 'Society';

EXEC SocialGraph.person$Insert @userName = 'Betty', @interestList = 'Pearls,Super Strong Kids';

EXEC SocialGraph.person$Insert @userName = 'Mr_Slate', @interestList = 'Water Buffalos,Rock Quarry';

EXEC SocialGraph.person$Insert @userName = 'Slagstone', @interestList = 'Water Buffalos,Bowling';

EXEC SocialGraph.person$Insert @userName = 'Gazoo', @interestList = 'Violence,Magic';

EXEC SocialGraph.person$Insert @userName = 'Hoppy', @interestList = 'Bowling';

EXEC SocialGraph.person$Insert @userName = 'Schmoo', @interestList = '';

EXEC SocialGraph.person$Insert @userName = 'Slaghoople', @interestList = '';

EXEC SocialGraph.person$Insert @userName = 'Pebbles', @interestList = '';

EXEC SocialGraph.person$Insert @userName = 'BamBam', @interestList = 'Magic,Super Strong Kids';

EXEC SocialGraph.person$Insert @userName = 'Rockhead', @interestList = 'Bowling';

EXEC SocialGraph.person$Insert @userName = 'Arnold', @interestList = '';

EXEC SocialGraph.person$Insert @userName = 'ArnoldMom', @interestList = '';

EXEC SocialGraph.person$Insert @userName = 'Tex', @interestList = '';

EXEC SocialGraph.person$Insert @userName = 'Dino', @interestList = '';

EXEC SocialGraph.Person$InsertConnections @userName = 'Fred', @userNameList = 'Barney,Wilma,Betty,Slagstone,Dino';

EXEC SocialGraph.Person$InsertConnections @userName = 'Barney', @userNameList = 'Wilma,Betty,Fred';

EXEC SocialGraph.Person$InsertConnections @userName = 'Wilma', @userNameList = 'Barney,Fred,Betty';

EXEC SocialGraph.Person$InsertConnections @userName = 'Betty', @userNameList = 'Barney,Wilma,Fred';

EXEC SocialGraph.Person$InsertConnections @userName = 'Mr_Slate', @userNameList = 'Fred';

EXEC SocialGraph.Person$InsertConnections @userName = 'Slagstone', @userNameList = 'Fred,Barney';

EXEC SocialGraph.Person$InsertConnections @userName = 'Gazoo', @userNameList = 'Fred,Barney';

EXEC SocialGraph.Person$InsertConnections @userName = 'Slaghoople', @userNameList = 'Wilma';

EXEC SocialGraph.Person$InsertConnections @userName = 'Dino', @userNameList = 'Fred';

EXEC SocialGraph.Person$InsertConnections @userName = 'Pebbles', @userNameList = 'Fred,Barney,BamBam,Dino';

EXEC SocialGraph.Person$InsertConnections @userName = 'BamBam', @userNameList = 'Barney,Betty,Pebbles,Hoppy';

EXEC SocialGraph.Person$InsertConnections @userName = 'Rockhead', @userNameList = 'Fred';

EXEC SocialGraph.Person$InsertConnections @userName = 'Arnold', @userNameList = 'Fred,Barney';

EXEC SocialGraph.Person$InsertConnections @userName = 'ArnoldMom', @userNameList = 'Arnold';


GO
SELECT *
FROM   SocialGraph.Person
SELECT *
FROM  SocialGraph.Interest
SELECT *
FROM  SocialGraph.ConnectedTo
SELECT *
FROM  SocialGraph.InterestedIn


