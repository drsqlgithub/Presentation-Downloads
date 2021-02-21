
USE HowToOptimizeAHierarchyInSQLServer;
GO

	DROP PROCEDURE IF EXISTS GappedNestedSets.Company$Reparent
	DROP PROCEDURE IF EXISTS GappedNestedSets.Company$Insert
	DROP PROCEDURE IF EXISTS GappedNestedSets.Company$delete
	DROP PROCEDURE IF EXISTS GappedNestedSets.Sale$InsertTestData
	DROP TABLE IF EXISTS GappedNestedSets.Sale
	DROP TABLE IF EXISTS GappedNestedSets.Company
	DROP SEQUENCE IF EXISTS GappedNestedSets.CompanyDataGenerator_SEQUENCE
	DROP SEQUENCE IF EXISTS GappedNestedSets.Company_SEQUENCE
	DROP SCHEMA IF EXISTS GappedNestedSets
go

CREATE SCHEMA GappedNestedSets
go

CREATE TABLE GappedNestedSets.Company
(
    CompanyId   int identity CONSTRAINT PKCompany primary key,
    Name        varchar(20) CONSTRAINT AKCompany_Name UNIQUE,
	HierarchyLeft int,
	HierarchyRight int
	,CONSTRAINT AKCompany_HierarchyLeft__HierarchyRight
					 unique (HierarchyLeft,HierarchyRight)
);  
GO
--create unique index HierarchyRight__HierarchyLeft on GappedNestedSets.Company (HierarchyRight, HierarchyLeft)
--go

CREATE SEQUENCE GappedNestedSets.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1
GO
CREATE TABLE GappedNestedSets.Sale
(
	SalesId	int NOT NULL IDENTITY (1,1) CONSTRAINT PKSale PRIMARY KEY,
	TransactionNumber varchar(10) NOT NULL CONSTRAINT AKSale UNIQUE,
	Amount numeric(12,2) NOT NULL,
	CompanyId int NOT NULL REFERENCES GappedNestedSets.Company (CompanyId)
)
go
CREATE INDEX XCompanyId ON GappedNestedSets.Sale(CompanyId, Amount)
go

CREATE PROCEDURE GappedNestedSets.Company$Insert(@Name varchar(20), @ParentCompanyName  varchar(20), @gapSize INT = 20) 
as 
BEGIN
	if @gapSize < 2
		throw 50000,'GapSize must be 2 or greater',1

	--note, enhancement ideas I have seen include leaving gaps to make inserts cheaper, but 
	--this would be far more complex, and certainly make the demo unwieldy. The inserts are 
	--slow compared to all other methods, but not impossibly so...
	SET NOCOUNT ON;
	BEGIN TRANSACTION

	if @ParentCompanyName is NULL
	 begin
		if exists (select * from GappedNestedSets.Company)
			THROW 50000,'More than one root node is not supported in this code',1;
		else
			insert into GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
			values (@Name, 1,1+@gapSize)
	 end 
	 ELSE
	 BEGIN


		if not exists (select * from GappedNestedSets.Company)
			THROW 50000,'You must start with a root node',1;

		--find the place in the Hierarchy where you will add a node
		DECLARE @ParentRight INT,
				@parentLeft INT,
				@childRight INT 
		select @ParentRight = HierarchyRight,
			   @parentLeft = HierarchyLeft 
		from   GappedNestedSets.Company 
		where Name = @ParentCompanyName

		select @childRight = MAX(HierarchyRight)
		FROM   GappedNestedSets.Company
		WHERE  HierarchyLeft > @parentLeft and HierarchyLeft < @ParentRight

		--select @ParentRight pr, @parentLeft pl, @childRight

		
		IF (@ChildRight IS NULL AND @ParentRight - @parentLeft >= 3) 
		  BEGIN	
				--SELECT 'quick'
				INSERT GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
				SELECT @Name, @parentLeft + 1, @parentLeft + 2 
		  END
		ELSE IF (@ChildRight IS NOT NULL AND @ParentRight - @ChildRight >= 3)
		  BEGIN	
				--SELECT 'quick'
				INSERT GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
				SELECT @Name, @childRight + 2, @childRight + 3 
		  END
		ELSE 
		BEGIN
		    --SELECT 'not quick'
			--make room for the new nodes.  
			UPDATE GappedNestedSets.Company 
			SET	   HierarchyRight = @gapSize + Company.HierarchyRight + 2, --for the parent node and all things right, add 2 to the hierachy right

				   --for all nodes right of the parent (not incl the parent), add 2
				   HierarchyLeft = Company.HierarchyLeft + CASE WHEN Company.HierarchyLeft > @ParentRight THEN  @gapSize + 2  ELSE 0 end
			WHERE  HierarchyRight >= @ParentRight

			--insert the node
			INSERT GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
			SELECT @Name, @ParentRight, @ParentRight + 1
		END
	END

	commit transaction
END
GO

CREATE PROCEDURE GappedNestedSets.Sale$InsertTestData
@Name varchar(20), 
@RowCount    int = 5
AS 
	SET NOCOUNT ON 
	WHILE @RowCount > 0
	  BEGIN
		INSERT INTO GappedNestedSets.Sale (TransactionNumber, Amount, CompanyId)
		SELECT	CAST (NEXT VALUE FOR GappedNestedSets.CompanyDataGenerator_SEQUENCE AS varchar(10)),
				CAST (NEXT VALUE FOR GappedNestedSets.CompanyDataGenerator_SEQUENCE AS numeric(12,2)), 
				(SELECT CompanyId FROM GappedNestedSets.Company WHERE Name = @Name)
		SET @rowCount = @rowCOunt - 1
	  END
GO

DELETE FROM GappedNestedSets.Company

EXEC GappedNestedSets.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;
EXEC GappedNestedSets.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';
EXEC GappedNestedSets.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';
EXEC GappedNestedSets.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';

----To make it clearer for doing the math, I only put sale data on root nodes. This is also a very 
----reasonable expectation to have in the real world for many situations. It does not really affect the
----outcome if sale data was appended to the non-root nodes.
EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Nashville Branch';
EXEC GappedNestedSets.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';
EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Knoxville Branch';
EXEC GappedNestedSets.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';
EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Memphis Branch';
EXEC GappedNestedSets.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';
EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Portland Branch';
EXEC GappedNestedSets.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';
EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Camden Branch';
GO

SELECT *
FROM   GappedNestedSets.Company
ORDER BY HierarchyLeft
