/*
This file was used to generate a data set that we will use in file 002 to performance test 
the algorithms. I will use a pre-generated set for the demos today...
*/


USE HowToOptimizeAHierarchyInSQLServer
go
IF EXISTS (SELECT * FROM sys.tables WHERE OBJECT_ID = OBJECT_ID('DemoCreator.Hierarchy'))
	DROP TABLE DemoCreator.Hierarchy
go
IF EXISTS (SELECT * FROM sys.schemas WHERE SCHEMA_ID = schema_ID('DemoCreator'))
	DROP SCHEMA DemoCreator
go

CREATE SCHEMA DemoCreator
go
CREATE TABLE DemoCreator.Hierarchy
(
	ParentName	varchar(20),
	ChildName   varchar(20),
	Level	int,
	RootNodeFlag bit DEFAULT (0)
)


CREATE INDEX LEVEL ON DemoCreator.Hierarchy(level)
go


declare 
		@loopCounter int = 1,
		@level int = 1,
		@levelCounter int = 1
set nocount on 

declare @levelCriteria table (level int, numNodes int)
insert into @levelCriteria
--largeDemoData Size
values (1,1),(2,100),(3,1000),(4,2000),(5,299)
--wide
--values (1,1),(2,300),(3,5000),(4,10000),(5,40000)
--deep
--values (1,1),(2,100),(3,1000),(4,2000),(5,3000),(6,4000),(7,5000),(8,6000),
--       (9,6000),(10,4000),(11,3000),(12,2000),(13,3000),(14,2000),(15,1000)
--monster
--values (1,1),(2,1000),(3,3000),(4,7000),(5,9000),(6,14000),(7,15000),(8,16000),
--       (9,16000),(10,24000),(11,23000),(12,12000),(13,13000),(14,32000),(15,41000),
--	   (16,6000),(17,14000),(18,13000),(19,12000),(20,6000),(21,4000),(22,8000),
--	   (23,5000),(24,3000),(25,1000)

----super monster
--values (1,1),(2,2000),(3,3000),(4,4000),(5,5000),(6,6000),(7,7000),(8,8000),
--       (9,9000),(10,10000),(11,11000),(12,12000),(13,13000),(14,14000),(15,15000),
--	   (16,16000),(17,17000),(18,18000),(19,19000),(20,20000),(21,21000),(22,22000),
--	   (23,23000),(24,24000),(25,25000),(26,26000),(27,27000),(28,28000),(29,29000),
--	   (30,30000),(31,31000),(32,32000),(33,33000),(34,34000),(35,35000),(36,36000),
--	   (37,37000),(38,38000),(39,39000),(40,40000),(41,41000),(42,42000),(43,43000),
--	   (44,44000),(45,45000),(46,46000),(47,47000),(48,48000),(49,49000),(50,50000)

while 1=1
 begin
	insert into DemoCreator.Hierarchy (ChildName, ParentName, LEVEL)
	select 'node' + cast(@loopCounter as varchar(10)),
		   (select top 1  ChildName from DemoCreator.Hierarchy where level = @level -1 order by newid()),
		   @level

	select @loopCounter = @loopCounter + 1
	select @levelCounter = @levelCounter + 1
	if @levelCounter > (select numNodes from @levelCriteria where level = @level)
		begin
			select @level as level, @levelCounter - 1 as rowsCreatedInLevel
			select @level = @level + 1
			select @levelCounter = 1
		end
	if @level > (select max(level) from @levelCriteria)
		break

 end
 select @loopCounter -1 as rowsCreated

 UPDATE  DemoCreator.Hierarchy
 SET RootNodeFlag = 1
 WHERE NOT EXISTS (SELECT *
				   FROM   DemoCreator.Hierarchy AS testMe
				   WHERE  testMe.parentName = Hierarchy.childName)

go
SELECT count(*) FROM DemoCreator.Hierarchy


--select *
--into DemoCreatorHold.Hierarchy1274001
--FROM DemoCreator.Hierarchy
