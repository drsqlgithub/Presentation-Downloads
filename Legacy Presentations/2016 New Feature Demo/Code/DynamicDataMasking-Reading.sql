CREATE DATABASE TestDynamicDataMasking;
GO
USE TestDynamicDataMasking;
GO
CREATE SCHEMA Demo; 
GO 
CREATE TABLE Demo.Person --warning, I am using very small column datatypes in this example to make formatting of the output easier 
( 
    PersonId    int NOT NULL CONSTRAINT PKPerson PRIMARY KEY, 
    FirstName    nvarchar(10) NULL, 
    LastName    nvarchar(10) NULL, 
    PersonNumber varchar(10) NOT NULL, 
    StatusCode    varchar(10) CONSTRAINT DFLTPersonStatus DEFAULT ('New') 
                            CONSTRAINT CHKPersonStatus CHECK (StatusCode in ('Active','Inactive','New')), 
    EmailAddress nvarchar(40) NULL, 
    InceptionTime date NOT NULL, --Time we first saw this person. Usually the row create time, but not always 
    --a number that I didn't feel could insult anyone of any origin, ability, etc that I could put in this table 
    YachtCount   tinyint NOT NULL CONSTRAINT DFLTPersonYachtCount DEFAULT (0) 
                            CONSTRAINT CHKPersonYachtCount CHECK (YachtCount >= 0), 
);

INSERT INTO Demo.Person (PersonId,FirstName,LastName,PersonNumber, StatusCode, EmailAddress, InceptionTime,YachtCount) 
VALUES(1,'Fred','Flintstone','0000000014','Active','fred@flintstone@slatequarry.net','1/1/1959',0), 
      (2,'Barney','Rubble','0000000032','Active','barneyrubble@aol.com','8/1/1960',1), 
      (3,'Wilma','Flintstone','0000000102','Active',NULL, '1/1/1959', 1);

GO

SELECT *
FROM   Demo.Person;
GO

--Datatypes each have a default mask (which is not the same as the DEFAULT, or even CHECK constraint, allows)

ALTER TABLE Demo.Person ALTER COLUMN PersonNumber 
    ADD MASKED WITH (Function = 'default()'); 
ALTER TABLE Demo.Person ALTER COLUMN StatusCode 
    ADD MASKED WITH (Function = 'default()'); 
ALTER TABLE Demo.Person ALTER COLUMN EmailAddress 
    ADD MASKED WITH (Function = 'default()'); 
ALTER TABLE Demo.Person ALTER COLUMN InceptionTime 
    ADD MASKED WITH (Function = 'default()'); 
ALTER TABLE Demo.Person ALTER COLUMN YachtCount 
    ADD MASKED WITH (Function = 'default()'); 
GO

--DBO and anyone with UNMASK rights sees data as is
SELECT *
FROM   Demo.Person;
GO

CREATE USER NormalUser WITHOUT LOGIN;
GO
GRANT SELECT,INSERT, UPDATE, DELETE ON Demo.Person TO NormalUser;
GO


--Show the data:
EXECUTE AS User='NormalUser'; 
GO 
SELECT * 
FROM   Demo.Person; 
GO 
REVERT;


--show the email mask
ALTER TABLE Demo.Person ALTER COLUMN EmailAddress DROP MASKED;
ALTER TABLE Demo.Person ALTER COLUMN EmailAddress 
    ADD MASKED WITH (Function = 'email()');

SELECT * 
FROM   Demo.Person; 
GO
EXECUTE AS User='NormalUser'; 
GO 
SELECT * 
FROM   Demo.Person; 
GO 
REVERT;

--note, don't have to drop existing masking
ALTER TABLE Demo.Person ALTER COLUMN YachtCount 
    ADD MASKED WITH (Function = 'random(1,100)'); --make the value between 1 and 100. You could make it always the same value pretty easily by using the same value for start and end

SELECT * 
FROM   Demo.Person; 
GO
EXECUTE AS User='NormalUser'; 
GO 
SELECT * 
FROM   Demo.Person; 
GO 
REVERT;
GO


--partial, more or less a substring in the start and end
ALTER TABLE Demo.Person ALTER COLUMN PersonNumber  --first 1 and last 2 characters (and a fixed number of dashes)
    ADD MASKED WITH (Function = 'partial(1,"-------",2)'); --note the double quotes on the text
GO

SELECT * 
FROM   Demo.Person; 
GO
EXECUTE AS User='NormalUser'; 
GO 
SELECT * 
FROM   Demo.Person; 
GO 
REVERT;
GO



--Some uses of data can be... confusing
EXECUTE AS User='NormalUser'; 
GO 
SELECT * 
FROM   Demo.Person; 

--stop here...

--now which of these will return data:
SELECT * 
FROM   Demo.Person
WHERE  PersonNumber = '0-------14'

SELECT *
FROM   Demo.Person
WHERE  PersonNumber = '0000000014'

--stop here


--if you haven't tried this before, no way you guess what this will output!
SELECT * 
FROM   Demo.Person; 

SELECT SUM(YachtCount) as YachtCount, MAX(PersonNumber) as MaxPersonNumber,  
       MIN(PersonNumber) as PersonNumber, COUNT(*) as MatchingRows 
FROM   Demo.Person;

SELECT SUM(YachtCount) as YachtCount, MAX(PersonNumber) as MaxPersonNumber,  
       MIN(PersonNumber) as PersonNumber, COUNT(*) as MatchingRows 
FROM   Demo.Person
GROUP BY YachtCount;

GO 
REVERT; 
GO




--lastly, this is what occurs when you try to modify data:

EXECUTE AS User='NormalUser'; 
go
--delete Wilma 
DELETE FROM demo.person WHERE PersonNumber = '0000000102';
--add Betty 
INSERT INTO Demo.Person (PersonId,FirstName,LastName,PersonNumber, StatusCode, EmailAddress, InceptionTime,YachtCount) 
VALUES(4,'Betty','Rubble','0000000153','Active','betty.rubble@aol.com','8/1/1960',0);
--update Fred's person number using only a masked column 
UPDATE Demo.Person 
SET    PersonNumber = '1111111114' 
WHERE  PersonNumber = '0000000014';
SELECT * 
FROM   Demo.Person; 
GO
REVERT; 
GO
SELECT * 
FROM   Demo.Person; 

--no effect, other than the data is masked... So you could pretty easily determin what data is in the table if you gave it a try.

CREATE PROCEDURE dbo.Person$select
AS
    SELECT *
    FROM   demo.Person;
GO
GRANT EXECUTE ON dbo.Person$select TO NormalUser;
GO

EXECUTE AS User='NormalUser'; 
GO
EXECUTE dbo.Person$select
GO
REVERT;