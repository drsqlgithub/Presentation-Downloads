use master
Go

--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'Patterns_BulkUniqueness')
 exec ('
alter database  Patterns_BulkUniqueness
	set single_user with rollback immediate;

drop database Patterns_BulkUniqueness;')

CREATE DATABASE Patterns_BulkUniqueness; --uses basic defaults from model databases
GO
USE Patterns_BulkUniqueness;
GO

CREATE SCHEMA Lego;
GO
CREATE TABLE Lego.Build
(
	BuildId int CONSTRAINT PKLegoBuild PRIMARY KEY,
	Name	varchar(30) NOT NULL CONSTRAINT AKLegoBuild_Name UNIQUE,
	LegoCode varchar(5) NULL, --five character set number
	InstructionsURL varchar(255) NULL --where you can get the PDF of the instructions
);
GO


CREATE TABLE Lego.BuildInstance
(
	BuildInstanceId Int CONSTRAINT PKLegoBuildInstance PRIMARY KEY ,
    --fix in book
	BuildId	Int NOT NULL CONSTRAINT FKLegoBuildInstance$isAVersionOf$LegoBuild 
	                REFERENCES Lego.Build (BuildId),
	BuildInstanceName varchar(30) NOT NULL, --brief description of item 
	Notes varchar(1000)  NULL, --longform notes. These could describe modifications 
                                   --for the instance of the model
	CONSTRAINT AKLegoBuildInstance UNIQUE(BuildId, BuildInstanceName)
);

GO

CREATE TABLE Lego.Piece
(
	PieceId	int constraint PKLegoPiece PRIMARY KEY,
	Type    varchar(15) NOT NULL,
	Name    varchar(30) NOT NULL,
	Color   varchar(20) NULL,
	Width int NULL,
	Length int NULL,
	Height int NULL,
	LegoInventoryNumber int NULL,
	OwnedCount int NOT NULL,
        CONSTRAINT AKLego_Piece_Definition UNIQUE (Type,Name,Color,Width,Length,Height),
        CONSTRAINT AKLego_Piece_LegoInventoryNumber UNIQUE (LegoInventoryNumber)
);

GO

CREATE TABLE Lego.BuildInstancePiece
(
	BuildInstanceId int NOT NULL,
	PieceId int NOT NULL,
	AssignedCount int NOT NULL,
	CONSTRAINT PKLegoBuildInstancePiece PRIMARY KEY (BuildInstanceId, PieceId),

	--fix in book
	CONSTRAINT FKBuildInstancePiece$References$Lego_Piece FOREIGN KEY (PieceId) REFERENCES Lego.Piece(PieceId),
    CONSTRAINT FKBuildInstancePiece$References$Lego_BuildInstance FOREIGN KEY (BuildInstanceId) REFERENCES Lego.BuildInstance(BuildInstanceId),


);


GO
INSERT Lego.Build (BuildId, Name, LegoCode, InstructionsURL)
VALUES  (1,'Small Car','3177',
           'http://cache.lego.com/bigdownloads/buildinginstructions/4584500.pdf');


Go

INSERT Lego.BuildInstance (BuildInstanceId, BuildId, BuildInstanceName, Notes)
VALUES (1,1,'Small Car for Book',NULL);

GO

INSERT Lego.Piece (PieceId, Type, Name, Color, Width, Length, Height, 
                   LegoInventoryNumber, OwnedCount)
VALUES  (1, 'Brick','Basic Brick','White',1,3,1,'362201',20),
	   (2, 'Slope','Slope','White',1,1,1,'4504369',2),
	   (3, 'Tile','Groved Tile','White',1,2,NULL,'306901',10),
	   (4, 'Plate','Plate','White',2,2,NULL,'302201',20),
	   (5, 'Plate','Plate','White',1,4,NULL,'371001',10),
	   (6, 'Plate','Plate','White',2,4,NULL,'302001',1),
	   (7, 'Bracket','1x2 Bracket with 2x2','White',2,1,2,'4277926',2),
	   (8, 'Mudguard','Vehicle Mudguard','White',2,4,NULL,'4289272',1),
	   (9, 'Door','Right Door','White',1,3,1,'4537987',1),
	   (10,'Door','Left Door','White',1,3,1,'45376377',1),
	   (11,'Panel','Panel','White',1,2,1,'486501',1),
	   (12,'Minifig Part','Minifig Torso , Sweatshirt','White',NULL,NULL,
                NULL,'4570026',1),
	   (13,'Steering Wheel','Steering Wheel','Blue',1,2,NULL,'9566',1),
	   (14,'Minifig Part','Minifig Head, Male Brown Eyes','Yellow',NULL, NULL, 
                NULL,'4570043',1),
	   (15,'Slope','Slope','Black',2,1,2,'4515373',2),
	   (16,'Mudguard','Vehicle Mudgard','Black',2,4,NULL,'4195378',1),
	   (17,'Tire','Vehicle Tire,Smooth','Black',NULL,NULL,NULL,'4508215',4),
	   (18,'Vehicle Base','Vehicle Base','Black',4,7,2,'244126',1),
	   (19,'Wedge','Wedge (Vehicle Roof)','Black',1,4,4,'4191191',1),
	   (20,'Plate','Plate','Lime Green',1,2,NULL,'302328',4),
	   (21,'Minifig Part','Minifig Legs','Lime Green',NULL,NULL,NULL,'74040',1),
	   (22,'Round Plate','Round Plate','Clear',1,1,NULL,'3005740',2),
	   (23,'Plate','Plate','Transparent Red',1,2,NULL,'4201019',1),
	   (24,'Briefcase','Briefcase','Reddish Brown',NULL,NULL,NULL,'4211235', 1),
	   (25,'Wheel','Wheel','Light Bluish Gray',NULL,NULL,NULL,'4211765',4),
	   (26,'Tile','Grilled Tile','Dark Bluish Gray',1,2,NULL,'4210631', 1),
	   (27,'Minifig Part','Brown Minifig Hair','Dark Brown',NULL,NULL,NULL,
               '4535553', 1),
	   (28,'Windshield','Windshield','Transparent Black',3,4,1,'4496442',1),
	   --and a few extra pieces to make the queries more interesting
	   (29,'Baseplate','Baseplate','Green',16,24,NULL,'3334',4),
	   (30,'Brick','Basic Brick','White',4,6,NULL,'2356',10 );


GO

INSERT INTO Lego.BuildInstancePiece (BuildInstanceId, PieceId, AssignedCount)
VALUES (1,1,2),(1,2,2),(1,3,1),(1,4,2),(1,5,1),(1,6,1),(1,7,2),(1,8,1),(1,9,1),
       (1,10,1),(1,11,1),(1,12,1),(1,13,1),(1,14,1),(1,15,2),(1,16,1),(1,17,4),
       (1,18,1),(1,19,1),(1,20,4),(1,21,1),(1,22,2),(1,23,1),(1,24,1),(1,25,4),
       (1,26,1),(1,27,1),(1,28,1);

	    
GO


INSERT Lego.Build (BuildId, Name, LegoCode, InstructionsURL)
VALUES  (2,'Brick Triangle',NULL,NULL);
GO
INSERT Lego.BuildInstance (BuildInstanceId, BuildId, BuildInstanceName, Notes)
VALUES (2,2,'Brick Triangle For Book','Simple build with 3 white bricks');
GO
INSERT INTO Lego.BuildInstancePiece (BuildInstanceId, PieceId, AssignedCount)
VALUES (2,1,3);
GO
INSERT Lego.BuildInstance (BuildInstanceId, BuildId, BuildInstanceName, Notes)
VALUES (3,2,'Brick Triangle For Book2','Simple build with 3 white bricks');
GO
INSERT INTO Lego.BuildInstancePiece (BuildInstanceId, PieceId, AssignedCount)
VALUES (3,1,3);

GO

--major difference is that 1 row <> 1 countable item, rather 1 type of countable item
SELECT COUNT(*) AS PieceCount ,SUM(OwnedCount) as InventoryCount
FROM  Lego.Piece;

GO

--grouped by type
SELECT Type, COUNT(*) as TypeCount, SUM(OwnedCount) as InventoryCount
FROM  Lego.Piece
GROUP BY Type;

GO


--count lego in build instances (actually being used)
SELECT  CASE WHEN GROUPING(Build.Name) = 1 THEN '--Total--' ELSE Build.Name END as BuildName,
		CASE WHEN GROUPING(BuildInstance.BuildInstanceName) = 1 THEN '--Total--' ELSE BuildInstance.BuildInstanceName END as BuildName,
		 SUM(BuildInstancePiece.AssignedCount) as AssignedCount
FROM   Lego.Build
		 JOIN Lego.BuildInstance	
			oN Build.BuildId = BuildInstance.BuildId
		 JOIN Lego.BuildInstancePiece
			on BuildInstance.BuildInstanceId = 
                                    BuildInstancePiece.BuildInstanceId
		 JOIN Lego.Piece
			ON BuildInstancePiece.PieceId = Piece.PieceId
GROUP BY Build.Name, BuildInstance.BuildInstanceName with rollup


--pieces allocated to the Small Car Build/Small Car For Book Build Instance
SELECT CASE WHEN GROUPING(Piece.Type) = 1 THEN '--Total--' ELSE Piece.Type END AS PieceType,
		Piece.Color,Piece.Height, Piece.Width, Piece.Length,
	   SUM(BuildInstancePiece.AssignedCount) as AssignedCount
FROM   Lego.Build
		 JOIN Lego.BuildInstance	
			oN Build.BuildId = BuildInstance.BuildId
		 JOIN Lego.BuildInstancePiece
			on BuildInstance.BuildInstanceId = 
                                    BuildInstancePiece.BuildInstanceId
		 JOIN Lego.Piece
			ON BuildInstancePiece.PieceId = Piece.PieceId
WHERE  Build.Name = 'Small Car'
       and  BuildInstanceName = 'Small Car for Book'
GROUP BY GROUPING SETS((Piece.Type,Piece.Color, Piece.Height, Piece.Width, Piece.Length),
                       ());

GO

--show unallocated legos
;WITH AssignedPieceCount
AS (
SELECT PieceId, SUM(AssignedCount) as TotalAssignedCount
FROM   Lego.BuildInstancePiece
GROUP  BY PieceId )

SELECT Type, Name,  Width, Length,Height, Piece.OwnedCount as OwnedCount,
       Piece.OwnedCount - Coalesce(TotalAssignedCount,0) as UnnallocatedCount
FROM   Lego.Piece
		 LEFT OUTER JOIN AssignedPieceCount
			on Piece.PieceId =  AssignedPieceCount.PieceId
WHERE Piece.OwnedCount - Coalesce(TotalAssignedCount,0) > 0; 

GO