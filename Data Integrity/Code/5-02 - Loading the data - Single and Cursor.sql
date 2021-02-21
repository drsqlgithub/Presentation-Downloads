USE HowToImplementDataIntegrity
go
SET NOCOUNT on
DELETE demo.Child
DELETE demo.Parent
DELETE demo.GrandParent
DELETE demo.GreatGrandParent
DELETE demo.GreatGreatGrandParent
DELETE demo.GreatGreatGreatGrandParent
DELETE demo.GreatGreatGreatGreatGrandParent
DELETE demo.GreatGreatGreatGreatGreatGrandParent
go

SELECT COUNT(*) AS foreign_key_constraint_count
FROM   sys.foreign_keys
WHERE  (name LIKE 'Great%'
   OR  name LIKE 'Parent%'
   OR  name LIKE 'CHild%')
  AND is_not_trusted = 0
  AND is_disabled = 0
go

SELECT 'Single Statements'
go
DECLARE @startTime DATETIME = GETDATE()

INSERT INTO demo.GreatGreatGreatGreatGreatGrandParent
SELECT *
FROM   HowToImplementDataIntegrity_SourceData.demo.GreatGreatGreatGreatGreatGrandParent

SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGreatGreatGreatGreatGrandParent

INSERT INTO demo.GreatGreatGreatGreatGrandParent
SELECT *
FROM   HowToImplementDataIntegrity_SourceData.demo.GreatGreatGreatGreatGrandParent

SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGreatGreatGreatGrandParent

INSERT INTO demo.GreatGreatGreatGrandParent
SELECT *
FROM   HowToImplementDataIntegrity_SourceData.demo.GreatGreatGreatGrandParent

SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGreatGreatGrandParent

INSERT INTO demo.GreatGreatGrandParent
SELECT *
FROM   HowToImplementDataIntegrity_SourceData.demo.GreatGreatGrandParent

SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGreatGrandParent
INSERT INTO demo.GreatGrandParent
SELECT *
FROM   HowToImplementDataIntegrity_SourceData.demo.GreatGrandParent

SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GreatGrandParent

INSERT INTO demo.GrandParent
SELECT *
FROM   HowToImplementDataIntegrity_SourceData.demo.GrandParent			

SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_GrandParent

INSERT INTO demo.Parent
SELECT *
FROM   HowToImplementDataIntegrity_SourceData.demo.Parent				

SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_Parent

INSERT INTO demo.Child
SELECT *
FROM   HowToImplementDataIntegrity_SourceData.demo.Child

SELECT DATEDIFF(millisecond,@startTime,GETDATE())/1000.0 AS InsertTimeSeconds_Child_DONE

GO
SELECT 'Rows Created',
		(SELECT COUNT(*) FROM demo.GreatGreatGreatGreatGreatGrandParent) AS GreatGreatGreatGreatGreatGrandParent,
		(SELECT COUNT(*) FROM demo.GreatGreatGreatGreatGrandParent) AS GreatGreatGreatGreatGrandParent,
		(SELECT COUNT(*) FROM demo.GreatGreatGreatGrandParent) AS GreatGreatGreatGrandParent,
		(SELECT COUNT(*) FROM demo.GreatGreatGrandParent) AS GreatGreatGrandParent,
		(SELECT COUNT(*) FROM demo.GreatGrandParent) AS GreatGrandParent,
		(SELECT COUNT(*) FROM demo.GrandParent) AS GrandParent,
		(SELECT COUNT(*) FROM demo.Parent) AS Parent,
		(SELECT COUNT(*) FROM demo.Child) AS Child
GO

SELECT 'End Single Statements'
GO
SELECT 'Start Cursors'
GO
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
						 FROM   HowToImplementDataIntegrity_SourceData.demo.GreatGreatGreatGreatGreatGrandParent
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
						 FROM    HowToImplementDataIntegrity_SourceData.demo.GreatGreatGreatGreatGrandParent
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
						 FROM   HowToImplementDataIntegrity_SourceData.demo.GreatGreatGreatGrandParent
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
						 FROM   HowToImplementDataIntegrity_SourceData.demo.GreatGreatGrandParent
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
						 FROM   HowToImplementDataIntegrity_SourceData.demo.GreatGrandParent
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
						 FROM   HowToImplementDataIntegrity_SourceData.demo.GrandParent
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
						 FROM   HowToImplementDataIntegrity_SourceData.demo.Parent
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
						 FROM   HowToImplementDataIntegrity_SourceData.demo.Child
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
GO
SELECT 'Rows Created',
		(SELECT COUNT(*) FROM demo.GreatGreatGreatGreatGreatGrandParent) AS GreatGreatGreatGreatGreatGrandParent,
		(SELECT COUNT(*) FROM demo.GreatGreatGreatGreatGrandParent) AS GreatGreatGreatGreatGrandParent,
		(SELECT COUNT(*) FROM demo.GreatGreatGreatGrandParent) AS GreatGreatGreatGrandParent,
		(SELECT COUNT(*) FROM demo.GreatGreatGrandParent) AS GreatGreatGrandParent,
		(SELECT COUNT(*) FROM demo.GreatGrandParent) AS GreatGrandParent,
		(SELECT COUNT(*) FROM demo.GrandParent) AS GrandParent,
		(SELECT COUNT(*) FROM demo.Parent) AS Parent,
		(SELECT COUNT(*) FROM demo.Child) AS Child
GO
SELECT 'END Single Row'