
USE [HowToImplementDataIntegrity]
go
--part of db create, and from a set of scripts I have here: http://www.drsql.org/Pages/DownloadablePackages.aspx
--under Procedures to drop all types of objects in a database.
EXEC utility.relationships$remove @table_schema = 'demo', @child_table_name = 'Great%'
EXEC utility.relationships$remove @table_schema = 'demo', @child_table_name = 'Parent'
EXEC utility.relationships$remove @table_schema = 'demo', @child_table_name = 'Child'
go
EXEC utility.table$remove @table_schema = 'demo', @table_name = 'Child'
EXEC utility.table$remove @table_schema = 'demo', @table_name = 'Parent'
EXEC utility.table$remove @table_schema = 'demo', @table_name = 'Grand%'
EXEC utility.table$remove @table_schema = 'demo', @table_name = 'Great%'
go

CREATE TABLE Demo.GreatGreatGreatGreatGreatGrandParent
(
	GreatGreatGreatGreatGreatGrandParentId  int   CONSTRAINT PKGreatGreatGreatGreatGreatGrandParent PRIMARY KEY,
	FirstLevelCode  CHAR(20) NOT NULL CONSTRAINT AKGreatGreatGreatGreatGreatGrandParent UNIQUE
)
CREATE TABLE Demo.GreatGreatGreatGreatGrandParent
(
	GreatGreatGreatGreatGrandParentId int CONSTRAINT PKGreatGreatGreatGreatGreatParentId PRIMARY KEY,
	GreatGreatGreatGreatGreatGrandParentId INT,
	SecondLevelCode  CHAR(20) NOT NULL
)
CREATE TABLE Demo.GreatGreatGreatGrandParent
(
	GreatGreatGreatGrandParentId int  CONSTRAINT PKGreatGreatGreatGreatParentId PRIMARY KEY,
	GreatGreatGreatGreatGrandParentId INT,
	ThirdLevelCode  CHAR(20) NOT NULL
)
CREATE TABLE Demo.GreatGreatGrandParent
(
	GreatGreatGrandParentId int  CONSTRAINT PKGreatGreatGreatParentId PRIMARY KEY,
	GreatGreatGreatGrandParentId INT,
	FourthLevelCode  CHAR(20) NOT NULL
)
CREATE TABLE Demo.GreatGrandParent
(
	GreatGrandParentId int  CONSTRAINT PKGreatGreatParentId PRIMARY KEY,
	GreatGreatGrandParentId INT,
	FifthLevelCode  CHAR(20) NOT NULL
)
CREATE TABLE Demo.GrandParent
(
	GrandParentId int  CONSTRAINT PKGreatParentId PRIMARY KEY,
	GreatGrandParentId INT,
	SixthLevelCode  CHAR(20) NOT NULL
)
CREATE TABLE Demo.Parent
(
	ParentId int CONSTRAINT PKParentId PRIMARY KEY,
	GrandParentId INT,
	SeventhLevelCode  CHAR(20) NOT NULL
)
CREATE TABLE Demo.Child
(
	ChildId int  CONSTRAINT PKChildId PRIMARY KEY,
	ParentId INT,
	EighthLevelCode  CHAR(20) NOT NULL
)