USE HowToImplementDataIntegrity
GO
IF EXISTS (SELECT * FROM sys.tables WHERE OBJECT_ID = OBJECT_ID('Schools.Mascot'))
	DROP TABLE Schools.Mascot
go
IF EXISTS (SELECT * FROM sys.schemas WHERE SCHEMA_ID = schema_ID('Schools'))
	DROP SCHEMA Schools;
go

CREATE SCHEMA Schools;
go
CREATE TABLE Schools.Mascot
(
	MascotId  int identity CONSTRAINT PKMascot PRIMARY KEY, --<< Specify as part of the table declaration
	MascotName varchar(100) NOT NULL,
	ColorScheme varchar(50) NULL,
	SchoolName  varchar(50) NULL,
	MascotIdNumber CHAR(3) NULL, 
	
);
go

--create data that is all correct, but unprotectedly... Data is same here as in the slide plus MascotIdNumber
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Smokey','Black/Brown','UT','001')
go
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Smokey','Black/White','Central High',NULL)
go
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Smokey','Smoky','Less Central High',NULL)
go
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Smokey','Brown','Southwest Middle','002')
go

SELECT *
FROM   Schools.Mascot
go

--Now the real issues start:

--duplicate MascotIdNumber
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Scrappy the Mocking Bird','Brown','UTC','001');
go
--duplicate MascotIdNumber AND Name/School
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Smokey','Blackish','UT','001');
GO

--and lots of duplicates of the "right" one since a process accidentally did the insert 5
--more times before it was noticed
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Smokey','Black/Brown','UT','001');
go 5

SELECT *
FROM   Schools.Mascot


--Very common forum question: How do I remove duplicate data..
SELECT MascotName, SchoolName, MAX(MascotId) AS MascotId, COUNT(*) AS HowManyDuplicatesAreThere
FROM   Schools.Mascot
GROUP BY MascotName, SchoolName
HAVING COUNT(*) > 1

GO

BEGIN TRANSACTION 
--repeat until @@rowcount = 0
DELETE FROM Schools.Mascot
WHERE  MascotId IN (SELECT MAX(MascotId) AS MascotId
					FROM   Schools.Mascot
					GROUP BY MascotName, SchoolName
					HAVING COUNT(*) > 1)
SELECT @@rowcount

SELECT *
FROM   SChools.Mascot

--ROLLBACK TRANSACTION
COMMIT

GO

--then remove the possibility of a duplicate for the natural key
ALTER TABLE Schools.Mascot   --guess that school is more selective than MascotName
	ADD CONSTRAINT AKMascot_SchoolName__MascotName UNIQUE (SchoolName, MascotName)
Go
--denied
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Smokey','Gold','UT','001')
GO

--what about the next rows?
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Smokey',NULL, NULL, NULL)
GO
INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Smokey',NULL, NULL, NULL)
GO

SELECT *
FROM   Schools.Mascot

--point being, if you have multiple NULL rows they "could" be the same row, so prevent it.
--other RDBMs may treat NULL as different values and allow it... Either way, nulls are annoying.

--so what about:
SELECT *
FROM   Schools.Mascot
WHERE  MascotIdNumber IN (
						SELECT MascotIdNumber
						FROM   Schools.Mascot
						WHERE  MascotIdNumber IS NOT NULL 
						GROUP BY MascotIdNumber
						HAVING COUNT(*) > 1)

--oops, the mocs should be IDNumber = 'A01', but the typo was allowed even though it was a duplicate

--of course, this isn't the way to prevent typos, but checking for duplicates can help never the less...

--Fix the DATA, and protect (though not techinically with a constraint)

UPDATE Schools.Mascot
SET MascotIdNumber = 'M01'
	   --NOTE: The natural key is for the human. For programming, if we had the surrogate
	   --key value in the UI, we would use it
WHERE  MascotName = 'Scrappy the Mocking Bird'
  AND  SchoolName = 'UTC'
 

--Can't prevent with a constraint, but you can improvise with a 
--Filtered Alternate Key (AKF Prefix)
CREATE UNIQUE INDEX AKS_Mascot_MascotIdNumber ON
                                    Schools.Mascot(MascotIdNumber)
WHERE MascotIdNumber IS NOT NULL;
GO

--Fails

INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Squealing Archie','White','Fear Tech','M01')
GO

INSERT INTO Schools.Mascot (MascotName, ColorScheme, SchoolName, MascotIdNumber)
VALUES ('Squealing Archie','White','Fear Tech','F01')
GO
SELECT *
FROM   Schools.Mascot