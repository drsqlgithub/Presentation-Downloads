USE HowToImplementDataIntegrity
GO
--to implement some domains, you will need to know the collation of the database
SELECT collation_name
FROM   sys.databases
WHERE  database_id = DB_ID()

--case insensitive accent sensitive is used for this database
go
IF EXISTS (SELECT * FROM sys.tables WHERE OBJECT_ID = OBJECT_ID('Demo.CheckConstraint'))
	DROP TABLE Demo.CheckConstraint
go
IF EXISTS (SELECT * FROM sys.tables WHERE OBJECT_ID = OBJECT_ID('Demo.ValuesInABCDomainTable'))
	DROP TABLE Demo.ValuesInABCDomainTable
go

CREATE TABLE Demo.CheckConstraint
(
	CheckConstraintId	int IDENTITY CONSTRAINT PKCheckConstraint PRIMARY KEY,
	WholeBetween0And100 tinyint NULL,
	Exactly10ASCII CHAR(10) NOT NULL,
	AtLeast10Unicode NVARCHAR(100) NOT NULL,
	Percentage10Places decimal (11,10) NOT NULL,
	FormatAANNN CHAR(5) NULL,
	Between3and5ASCII varchar(5) NOT NULL,
	Exactly10AllUPPERCASE CHAR(10) NULL,
	FormatBasedOnType varchar(6) NOT NULL,
	FormatBasedOnTime varchar(10) NOT NULL,
	CheckConstraintTypeId INT NOT NULL, --used in combo with next attribute
	ValuesInABCCheck CHAR(1) NOT NULL,
	ValuesInABCDomainTable CHAR(1) NOT NULL,
	CreateTime DATETIME NULL CONSTRAINT DFTLCHeckContraint_CreateTime  DEFAULT (SYSDATETIME()),
	CreatedDaysAgo AS (DATEDIFF(DAY,CreateTime,GETDATE())) --PERSISTED, if the value cannot change
)
go

--the first step is the datatype, making sure that the best type is chosen
--and is the smallest type that will work...

--Simple:
--WHole Number between 0 and 100, nullable

--WholeBetween0And100 tinyint NULL,

ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$WholeBetween0And100
	CHECK (WholeBetween0And100 BETWEEN 0 AND 100);

--Exactly 10 ASCII characters, no more no less, not including trailing spaces, not nullable

--	Exactly10ASCII CHAR(10) NOT NULL,

ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$Exactly10ASCII
	CHECK (LEN(Exactly10ASCII) = 10); --The only caveat here is that it won't include trailing spaces. 
									  -- all blanks: '          ' would fail because select len ('          ') = 0
									  --to allow all spaces, use datalength SELECT datalength('          ') = 10


--At least 10 UNICODE charaters, not including trailing spaces, more allowed up to 100, no nulls allowed

--AtLeast10Unicode NVARCHAR(100) NOT NULL,

ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$AtLeast10Unicode
	CHECK (LEN(AtLeast10Unicode) >= 10);

--Percentage values from 0 to 100%, 10 decimal places, between 0 and 1 no nulls.

--Percentage10Places decimal (11,10), --I store percentages in decimal form because that is how they are easiest used for math
									  --displayers can change to 0 to 100 by multiplying by 100
ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$Percentage10Places
	CHECK (Percentage10Places BETWEEN 0 AND 1);

--your actual need may vary, as this column allows 0 to 100%, and not 110%. Constrain to your acceptable min and max that 
--your requiremments will allow


--Exactly 5 characters, format AANNN, case insensitive, NULLs

--FormatAANNN char(5) NULL

ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$FormatAANNN
	CHECK (FormatAANNN LIKE '[a-z][a-z][0-9][0-9][0-9]');

--Less simple

--between 3 and 5 ASCII characters, all alpha numeric no nulls

--    Between3and5ASCII varchar(5) NOT NULL,

ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$Between3and5ASCII
	CHECK (LEN(Between3and5ASCII) >= 3 AND
			Between3and5ASCII LIKE replicate('[a-z0-9 ]',len(Between3and5ASCII)))
		
--exactly 10 alpha characters, all uppercase nulls

--Exactly10AllUPPERCASE CHAR(10) NOT,

ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$Exactly10AllUPPERCASE
	CHECK (Exactly10AllUPPERCASE COLLATE Latin1_General_Bin LIKE '[A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z]');
							     --used a binary colation here to make sure that the format was honored as uppercase



--set format based on type AANNN when type = 1, AA1NNN when type = 2 no nulls

--FormatBasedOnType varchar(6) NOT,

ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$FormatBasedOnType
	CHECK (
			(CheckConstraintTypeId = 1 AND FormatBasedOnType LIKE '[a-z]1[0-9][0-9][0-9]')
	         OR
			(CheckConstraintTypeId = 2 AND FormatBasedOnType LIKE '[a-z]1[0-9][0-9][0-9][0-9]')
		   )

--up to 10 characters, but set format AANNN starting on 
--				CreateTime = '20120101' no nulls

--FormatBasedOnTime varchar(10) 

ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$FormatBasedOnTime
	CHECK (
			(CreateTime >= '20120101' AND FormatBasedOnTime LIKE '[a-z]1[0-9][0-9][0-9]')
	         OR
			(CreateTime < '20120101')
		   )
--this sort of thing I would suggest only when you old data that you can't remove, but can't check. You can add an 
--constraint that just checks future data, but it will not ignore the data when you edit older data.
GO


-- Value must be A, B, or C, No NULLs, case not important

--	ValuesInABCCheck CHAR(1) NOT NULL,
	
ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$ValuesInABCCheck
	CHECK ( ValuesInABCCheck IN ('A','B','C'));



--Value must be A, B, or C No NUlls

--	ValuesInABCDomainTable CHAR(1) NOT NULL,

CREATE TABLE Demo.ValuesInABCDomainTable 
(
	ValuesInABCDomainTable CHAR(1) CONSTRAINT PKABC PRIMARY KEY,
	DESCRIPTION VARCHAR(100)
)

INSERT INTO Demo.ValuesInABCDomainTable
VALUES ('A','First Letter'),('B','Not the first, but the second'),('C','Third Letter')
GO

--technically FK is a later discussion, but this is a trivial use..
ALTER TABLE Demo.CheckConstraint
	ADD CONSTRAINT FKCheckConstraint$hasDomainIn$ValuesInABCDomainTable 
		FOREIGN KEY (ValuesInABCDomainTable) REFERENCES Demo.ValuesInABCDomainTable(ValuesInABCDomainTable)
GO




--data works
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
		)
GO

--all nullable columns null, still works
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( NULL , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          NULL , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          NULL , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO



--fails on noted item
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 101 , -- WholeBetween0And100 - tinyint <<== Fail here
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO


INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '012345678' , -- Exactly10ASCII - char(10) <<== Fail here
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO


INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          1.5 , -- Percentage10Places - decimal <<== Fail here
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA12A' , -- FormatAANNN - char(5) <<== Fail here
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5) 
          '12' , -- Between3and5ASCII - varchar(5) <<== Fail here
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO

INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'hellothere' , -- Exactly10AllUPPERCASE - char(10) <<== Fail here
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO

INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a12345' , -- FormatBasedOnType - varchar(6) --will work for type = 2 <<== Fail here
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO

INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a123' , -- FormatBasedOnTime - varchar(10) --will work for time < 2012 <<== Won't fail here this time
          
          '2010-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO

--CreateTime is null, the format can be ANYTHING
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'ANYTHING' , -- FormatBasedOnTime - varchar(10) --will work for time < 2012 or NULL CreateTime
          
          NULL,  -- CreateTime - datetime <<== Format test fail here-- row will be created...
          'A', --ValueInABCCheck -- Char(1),
		  'A'--ValueInABCDomainTable --CHar(1)
        )
GO





--data works
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'F', --ValueInABCCheck -- Char(1), <==Fail Here
		  'A'--ValueInABCDomainTable --CHar(1)
		)
GO

--data works
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'F'--ValueInABCDomainTable --CHar(1) <== Fail here
		)
GO


SELECT *
FROM   Demo.CheckConstraint
go

--trusted constraints
SELECT check_constraints.name, is_not_trusted, is_disabled, COALESCE(columns.NAME,'--multi-column--'), definition
FROM   sys.check_constraints
		 LEFT JOIN sys.columns
			ON columns.OBJECT_ID = check_constraints.parent_object_id
               AND columns.column_id = check_constraints.parent_column_id       
WHERE  parent_object_id = object_id('Demo.CheckConstraint')
GO

ALTER TABLE Demo.CheckConstraint
	ADD NotNullFromNowOn VARCHAR(10) NULL
go    

--fails!
ALTER TABLE demo.CheckConstraint
	ADD CONSTRAINT CHKCheckConstraint$NotNullFromNowOn
	CHECK (NotNullFromNowOn IS NOT NULL);
GO

-- success, by using WITH NOCHECK, telling it to ignore the existing data. Often done to make constraint adds faster
ALTER TABLE demo.CheckConstraint
	WITH NOCHECK ADD CONSTRAINT CHKCheckConstraint$NotNullFromNowOn 
	CHECK (NotNullFromNowOn IS NOT NULL)  ;
GO

--The best constraints as trusted and enabled
SELECT check_constraints.name, is_not_trusted, is_disabled, COALESCE(columns.NAME,'--multi-column--'), definition
FROM   sys.check_constraints
		 LEFT JOIN sys.columns
			ON columns.OBJECT_ID = check_constraints.parent_object_id
               AND columns.column_id = check_constraints.parent_column_id       
WHERE  parent_object_id = object_id('Demo.CheckConstraint')
GO


--data works, with new not null value
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable,
		  NotNullFromNowOn
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A',--ValueInABCDomainTable --CHar(1)
		  'New Data'
		)
GO

--NULL falue fails
INSERT Demo.CheckConstraint
        ( WholeBetween0And100 ,
          Exactly10ASCII ,
          AtLeast10Unicode ,
          Percentage10Places ,
          FormatAANNN ,
          Between3and5ASCII ,
          Exactly10AllUPPERCASE ,
          CheckConstraintTypeId ,
          FormatBasedOnType ,
          FormatBasedOnTime ,
          CreateTime,
		  ValuesInABCCheck,
		  ValuesInABCDomainTable,
		  NotNullFromNowOn
        )
VALUES  ( 0 , -- WholeBetween0And100 - tinyint
          '0123456789' , -- Exactly10ASCII - char(10)
          '0123456789' , -- AtLeast10Unicode - varchar(100)
          0.5 , -- Percentage10Places - decimal
          'AA123' , -- FormatAANNN - char(5)
          '123' , -- Between3and5ASCII - varchar(5)
          'HELLOTHERE' , -- Exactly10AllUPPERCASE - char(10)
		   1 , -- CheckConstraintTypeId - int
          'a1234' , -- FormatBasedOnType - varchar(6)
          'a1234' , -- FormatBasedOnTime - varchar(10)
          
          '2013-08-19 03:57:05',  -- CreateTime - datetime
          'A', --ValueInABCCheck -- Char(1),
		  'A',--ValueInABCDomainTable --CHar(1)
		  NULL
		)
GO
--but there is null data in there, which can really annoy users :)
SELECT NotNullFromNowOn
FROM   demo.CheckConstraint
go

--setting to existing value, FAIL
UPDATE demo.CheckConstraint
SET    NotNullFromNowOn = NULL
WHERE  NotNullFromNowOn IS NULL
GO

--The goal is to get the constraint trusted, but this is not the syntax! This turns off the constraint completely

--disable the constraint
ALTER TABLE Demo.CheckConstraint
	NOCHECK CONSTRAINT CHKCheckConstraint$NotNullFromNowOn
GO

SELECT check_constraints.name, is_not_trusted, is_disabled, COALESCE(columns.NAME,'--multi-column--'), definition
FROM   sys.check_constraints
		 LEFT JOIN sys.columns
			ON columns.OBJECT_ID = check_constraints.parent_object_id
               AND columns.column_id = check_constraints.parent_column_id       
WHERE  parent_object_id = object_id('Demo.CheckConstraint')
GO
--this enables it, but is it trusted?
ALTER TABLE Demo.CheckConstraint
	CHECK CONSTRAINT CHKCheckConstraint$NotNullFromNowOn
GO
--no, since it still has non-conformant data 
SELECT check_constraints.name, is_not_trusted, is_disabled, COALESCE(columns.NAME,'--multi-column--'), definition
FROM   sys.check_constraints
		 LEFT JOIN sys.columns
			ON columns.OBJECT_ID = check_constraints.parent_object_id
               AND columns.column_id = check_constraints.parent_column_id       
WHERE  parent_object_id = object_id('Demo.CheckConstraint')
GO

--Of course not, and if it was going to it would have failed since the data still is bad.. fix the data 
UPDATE demo.CheckConstraint
SET    NotNullFromNowOn = 'Old'
WHERE  NotNullFromNowOn IS NULL 
GO

--To make it trusted, use:

ALTER TABLE Demo.CheckConstraint
	WITH CHECK CHECK CONSTRAINT  CHKCheckConstraint$NotNullFromNowOn
GO
SELECT check_constraints.name, is_not_trusted, is_disabled, COALESCE(columns.NAME,'--multi-column--'), definition
FROM   sys.check_constraints
		 LEFT JOIN sys.columns
			ON columns.OBJECT_ID = check_constraints.parent_object_id
               AND columns.column_id = check_constraints.parent_column_id       
WHERE  parent_object_id = object_id('Demo.CheckConstraint')
GO
GO