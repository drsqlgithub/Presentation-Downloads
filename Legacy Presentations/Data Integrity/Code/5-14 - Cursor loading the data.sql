USE HowToImplementDataIntegrity
go
SET NOCOUNT ON 
DELETE demo.Child
DELETE demo.Parent
DELETE demo.GrandParent
DELETE demo.GreatGrandParent
DELETE demo.GreatGreatGrandParent
DELETE demo.GreatGreatGreatGrandParent
DELETE demo.GreatGreatGreatGreatGrandParent
DELETE demo.GreatGreatGreatGreatGreatGrandParent

SELECT COUNT(*) AS foreign_key_constraint_count
FROM   sys.foreign_keys
WHERE  name LIKE 'Great%'
   OR  name LIKE 'Parent%'
   OR  name LIKE 'CHild%'
go

DECLARE @startTime DATETIME = GETDATE()

DECLARE @cursor CURSOR, @keyId INT, @parentKeyId INT, @code CHAR(20)
SET @cursor = CURSOR for SELECT *
						 FROM   PerformanceDemo.hold.GreatGreatGreatGreatGreatGrandParent
OPEN @cursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @keyId, @code
	IF @@fetch_status <> 0
	   BREAK
	   
	INSERT INTO Demo.GreatGreatGreatGreatGreatGrandParent
	SELECT @keyId,@code
 END
 
SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGreatGreatGreatGreatGrandParent

SET @cursor = CURSOR for SELECT *
						 FROM   PerformanceDemo.hold.GreatGreatGreatGreatGrandParent
OPEN @cursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @keyId, @parentKeyId, @code
	IF @@fetch_status <> 0
	   BREAK
	   
	INSERT INTO Demo.GreatGreatGreatGreatGrandParent
	SELECT @keyId,@parentKeyId,@code
 END
 
 SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGreatGreatGreatGrandParent

 SET @cursor = CURSOR for SELECT *
						 FROM   PerformanceDemo.hold.GreatGreatGreatGrandParent
OPEN @cursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @keyId, @parentKeyId, @code
	IF @@fetch_status <> 0
	   BREAK
	   
	INSERT INTO Demo.GreatGreatGreatGrandParent
	SELECT @keyId,@parentKeyId,@code
 END
 SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGreatGreatGrandParent

 SET @cursor = CURSOR for SELECT *
						 FROM   PerformanceDemo.hold.GreatGreatGrandParent
OPEN @cursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @keyId, @parentKeyId, @code
	IF @@fetch_status <> 0
	   BREAK
	   
	INSERT INTO Demo.GreatGreatGrandParent
	SELECT @keyId,@parentKeyId,@code
 END
 SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGreatGrandParent


 SET @cursor = CURSOR for SELECT *
						 FROM   PerformanceDemo.hold.GreatGrandParent
OPEN @cursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @keyId, @parentKeyId, @code
	IF @@fetch_status <> 0
	   BREAK
	   
	INSERT INTO Demo.GreatGrandParent
	SELECT @keyId,@parentKeyId,@code
 END
 SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGrandParent

 

 SET @cursor = CURSOR for SELECT *
						 FROM   PerformanceDemo.hold.GrandParent
OPEN @cursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @keyId, @parentKeyId, @code
	IF @@fetch_status <> 0
	   BREAK
	   
	INSERT INTO Demo.GrandParent
	SELECT @keyId,@parentKeyId,@code
 END
 SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GrandParent

 
 SET @cursor = CURSOR for SELECT *
						 FROM   PerformanceDemo.hold.Parent
OPEN @cursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @keyId, @parentKeyId, @code
	IF @@fetch_status <> 0
	   BREAK
	   
	INSERT INTO Demo.Parent
	SELECT @keyId,@parentKeyId,@code
 END
 SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_Parent


 
 SET @cursor = CURSOR for SELECT *
						 FROM   PerformanceDemo.hold.Child
OPEN @cursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @keyId, @parentKeyId, @code
	IF @@fetch_status <> 0
	   BREAK
	   
	INSERT INTO Demo.Child
	SELECT @keyId,@parentKeyId,@code
 END
 SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_Child_Done
