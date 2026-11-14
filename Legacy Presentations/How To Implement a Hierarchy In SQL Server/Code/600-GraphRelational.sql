USE HowToOptimizeAHierarchyInSQLServer;
GO

SET NOCOUNT ON;
GO


DROP PROCEDURE IF EXISTS Social.Person$Insert;
DROP PROCEDURE IF EXISTS Social.Person$InsertConnections;
DROP TABLE IF EXISTS Social.PersonConnection;
DROP TABLE IF EXISTS Social.PersonInterest;
DROP TABLE IF EXISTS Social.Person;

DROP SCHEMA IF EXISTS Social;
GO

CREATE SCHEMA Social;
GO

/********************
Simple adjacency list
********************/
CREATE TABLE Social.Person
(
    PersonId int          IDENTITY(1, 1) CONSTRAINT PKperson PRIMARY KEY,
    UserName nvarchar(30) NOT NULL CONSTRAINT AKperson_userName UNIQUE,
);

--person that a person is connected to explicitly
CREATE TABLE Social.PersonConnection
(
    PersonId            int NOT NULL CONSTRAINT PersonConnection$references$Person_PersonId REFERENCES Social.Person(PersonId),
    ConnectedToPersonId int NOT NULL CONSTRAINT PersonConnection$references$Person_ConnectedToPErsonId REFERENCES Social.Person
                                                                                                       (   PersonId),
    CONSTRAINT PKPersonConnection PRIMARY KEY
    (
        PersonId,
        ConnectedToPersonId),
    CONSTRAINT CKPersonConnection_NoSelfLove CHECK(PersonId <> ConnectedToPersonId)
);
GO

--interests that the person has
CREATE TABLE Social.PersonInterest
(
    PersonId     int          NOT NULL CONSTRAINT PersonInterest$references$Person REFERENCES Social.Person(PersonId),
    InterestName nvarchar(30) NOT NULL,
    CONSTRAINT PKPersonInterest PRIMARY KEY
    (
        PersonId,
        InterestName)
);
GO



CREATE PROCEDURE Social.Person$Insert
(
    @userName     nvarchar(60),
    @interestList varchar(8000)
)
AS
BEGIN
    INSERT INTO Social.Person(UserName)
    VALUES(@userName);

    DECLARE @PersonId int = (   SELECT Person.PersonId
                                FROM   Social.Person
                                WHERE  Person.UserName = @userName);

    INSERT INTO Social.PersonInterest(PersonId, InterestName)
    SELECT @PersonId, value
    FROM   STRING_SPLIT(@interestList, ',')
	WHERE  value <> '';

END;
GO

--SELECT Person.UserName, PersonInterest.InterestName
--FROM    Social.Person
--		 join Social.PersonInterest
--			on Person.PersonId = PersonInterest.PersonId
--Order by UserName
--GO

--Takes a list of interests and splits it up and makes each one a row

CREATE PROCEDURE Social.Person$InsertConnections
(
    @userName     nvarchar(60),
    @userNameList varchar(8000)
)
AS
BEGIN
    DECLARE @personId int = (   SELECT Person.PersonId
                                FROM   Social.Person
                                WHERE  Person.UserName = @userName);

    INSERT INTO Social.PersonConnection
    SELECT @personId, Person.PersonId
    FROM   Social.Person
           JOIN STRING_SPLIT(@userNameList, ',') AS PersonList
               ON Person.UserName = PersonList.value
			      AND value <> '';

END;
GO

EXEC Social.person$Insert @userName = 'Fred',
                          @interestList = 'Bowling,Violence,Fishing,Pet Dinosaurs,Water Buffalos,Rock Quarry';

EXEC Social.person$Insert @userName = 'Barney', @interestList = 'Bowling,Peace,Water Buffalos,Super Strong Kids';

EXEC Social.person$Insert @userName = 'Wilma', @interestList = 'Society';

EXEC Social.person$Insert @userName = 'Betty', @interestList = 'Pearls,Super Strong Kids';

EXEC Social.person$Insert @userName = 'Mr_Slate', @interestList = 'Water Buffalos,Rock Quarry';

EXEC Social.person$Insert @userName = 'Slagstone', @interestList = 'Water Buffalos,Bowling';

EXEC Social.person$Insert @userName = 'Gazoo', @interestList = 'Violence,Magic';

EXEC Social.person$Insert @userName = 'Hoppy', @interestList = 'Bowling';

EXEC Social.person$Insert @userName = 'Schmoo', @interestList = '';

EXEC Social.person$Insert @userName = 'Slaghoople', @interestList = '';

EXEC Social.person$Insert @userName = 'Pebbles', @interestList = '';

EXEC Social.person$Insert @userName = 'BamBam', @interestList = 'Magic,Super Strong Kids';

EXEC Social.person$Insert @userName = 'Rockhead', @interestList = 'Bowling';

EXEC Social.person$Insert @userName = 'Arnold', @interestList = '';

EXEC Social.person$Insert @userName = 'ArnoldMom', @interestList = '';

EXEC Social.person$Insert @userName = 'Tex', @interestList = '';

EXEC Social.person$Insert @userName = 'Dino', @interestList = '';

EXEC Social.Person$InsertConnections @userName = 'Fred', @userNameList = 'Barney,Wilma,Betty,Slagstone,Dino';

EXEC Social.Person$InsertConnections @userName = 'Barney', @userNameList = 'Wilma,Betty,Fred';

EXEC Social.Person$InsertConnections @userName = 'Wilma', @userNameList = 'Barney,Fred,Betty';

EXEC Social.Person$InsertConnections @userName = 'Betty', @userNameList = 'Barney,Wilma,Fred';

EXEC Social.Person$InsertConnections @userName = 'Mr_Slate', @userNameList = 'Fred';

EXEC Social.Person$InsertConnections @userName = 'Slagstone', @userNameList = 'Fred,Barney';

EXEC Social.Person$InsertConnections @userName = 'Gazoo', @userNameList = 'Fred,Barney';

EXEC Social.Person$InsertConnections @userName = 'Slaghoople', @userNameList = 'Wilma';

EXEC Social.Person$InsertConnections @userName = 'Dino', @userNameList = 'Fred';

EXEC Social.Person$InsertConnections @userName = 'Pebbles', @userNameList = 'Fred,Barney,BamBam,Dino';

EXEC Social.Person$InsertConnections @userName = 'BamBam', @userNameList = 'Barney,Betty,Pebbles,Hoppy';

EXEC Social.Person$InsertConnections @userName = 'Rockhead', @userNameList = 'Fred';

EXEC Social.Person$InsertConnections @userName = 'Arnold', @userNameList = 'Fred,Barney';

EXEC Social.Person$InsertConnections @userName = 'ArnoldMom', @userNameList = 'Arnold';

EXEC Social.Person$InsertConnections @userName = 'Tex', @userNameList = 'Fred,Wilma';

