--using multiple sequence values, and as default
USE SequenceDemos
GO
SET NOCOUNT ON 
GO
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.HashedRow'))
		DROP TABLE Demo.HashedRow;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.Bucket'))
		DROP TABLE Demo.Bucket;

GO
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.HashedRow_HashGen_SEQUENCE'))
		DROP SEQUENCE Demo.HashedRow_HashGen_SEQUENCE;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.HashedRow_SEQUENCE'))
		DROP SEQUENCE Demo.HashedRow_SEQUENCE;
GO

CREATE TABLE Demo.Bucket
(
	BucketId	tinyint PRIMARY KEY CHECK (BucketId BETWEEN 0 AND 7),
	Name  varchar(10)
)
GO
INSERT INTO demo.Bucket (BucketId, Name)
VALUES (0,'Zero'),(1,'One'),(2,'Two'),(3,'Three'),
       (4,'Four'),(5,'Five'),(6,'Six'),(7,'Seven')

GO


--rotating values from 0 - 7
CREATE SEQUENCE Demo.HashedRow_HashGen_SEQUENCE
AS tinyint 
START WITH 0 
INCREMENT BY 1 
MAXVALUE 7
CYCLE;
GO

SELECT NEXT VALUE FOR Demo.HashedRow_HashGen_SEQUENCE
FROM   Tools.Number
WHERE  I between 0 and 100
GO

ALTER SEQUENCE Demo.HashedRow_HashGen_SEQUENCE RESTART
GO

CREATE SEQUENCE Demo.HashedRow_SEQUENCE
AS int 
START WITH 1 
INCREMENT BY 1 
GO

CREATE TABLE demo.HashedRow
(
	HashedRowId	int PRIMARY KEY DEFAULT (NEXT VALUE FOR Demo.HashedRow_SEQUENCE),
	BucketId tinyint DEFAULT (NEXT VALUE FOR Demo.HashedRow_HashGen_SEQUENCE) 
									REFERENCES demo.Bucket(BucketId),
	SecondBucketId tinyint DEFAULT (NEXT VALUE FOR Demo.HashedRow_HashGen_SEQUENCE) 
									REFERENCES demo.Bucket(BucketId),
	OtherColumn varchar(20)
)
GO

INSERT INTO  demo.HashedRow (OtherColumn)
SELECT CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65)+ CHAR(RAND() * 26 + 65)+
	   CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65) + CHAR(RAND() * 26 + 65)
FROM   Tools.Number
WHERE  I between 1 and 100
GO

SELECT HashedRow.*, Bucket.Name as BucketName, SecondBucket.Name as SecondBucketName
FROM   demo.HashedRow
		 JOIN demo.Bucket
			ON HashedRow.BucketId = Bucket.BucketId
		 JOIN demo.Bucket as SecondBucket
			ON HashedRow.SecondBucketId = SecondBucket.BucketId
ORDER BY HashedRowId;
GO

SELECT case when grouping(Bucket.Name) = 1 then '--Total--' Else Bucket.Name END AS BucketName, COUNT(*)
FROM   demo.HashedRow
		 JOIN demo.Bucket
			ON HashedRow.BucketId = Bucket.BucketId
GROUP BY Bucket.Name WITH ROLLUP
ORDER BY max(Bucket.BucketId)



GO

GO
