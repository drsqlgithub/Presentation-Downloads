USE MattersOfConcurrency;
GO

DROP TABLE IF EXISTS Demo_Mem.SingleTable;
DROP TABLE IF EXISTS Demo_Mem.Interaction;
DROP TABLE IF EXISTS Demo_Mem.Person;
DROP FUNCTION IF EXISTS MemOptTools.String$Replicate

DROP SCHEMA IF EXISTS Demo_Mem;
DROP SCHEMA IF EXISTS MemOptTools;
GO

CREATE SCHEMA Demo_Mem;
GO

CREATE SCHEMA MemOptTools; --to hold my replicate replacement
GO

CREATE OR ALTER FUNCTION MemOptTools.String$Replicate
(
    @inputString    nvarchar(1000),
    @replicateCount smallint
)
RETURNS nvarchar(1000)
WITH NATIVE_COMPILATION, SCHEMABINDING
AS
BEGIN ATOMIC WITH(TRANSACTION ISOLATION LEVEL = SNAPSHOT, 
                  LANGUAGE = N'English')
    DECLARE @i int = 0, @output nvarchar(1000) = '';

    WHILE @i < @replicateCount
    BEGIN
        SET @output = @output + @inputString;
        SET @i = @i + 1;
    END;

    RETURN @output;
END;
GO

CREATE TABLE Demo_Mem.SingleTable
(
    singleTableId int IDENTITY(1, 1) CONSTRAINT PKsingleTable PRIMARY KEY NONCLUSTERED HASH WITH(BUCKET_COUNT = 100),
    value         varchar(100),
    padding       char(4000) default (MemOptTools.String$Replicate('A',4000)) --REPLICATE NOT SUPPORTED, but this replicate substitute is
)
WITH (MEMORY_OPTIMIZED = ON);
GO
INSERT INTO Demo_Mem.SingleTable(Value)
VALUES('Fred'),
(   'Barney'),
(   'Wilma'),
(   'Betty'),
(   'Mr_Slate'),
(   'Slagstone'),
(   'Gazoo'),
(   'Hoppy'),
(   'Schmoo'),
(   'Slaghoople'),
(   'Pebbles'),
(   'BamBam'),
(   'Rockhead'),
(   'Arnold'),
(   'ArnoldMom'),
(   'Tex'),
(   'Dino');
GO

CREATE TABLE Demo_Mem.Person
(
    PersonId int          IDENTITY(1, 1) CONSTRAINT PKPerson PRIMARY KEY NONCLUSTERED HASH WITH(BUCKET_COUNT = 100),
    Name     varchar(100) CONSTRAINT AKPerson UNIQUE NONCLUSTERED,
)
WITH (MEMORY_OPTIMIZED = ON);
GO

INSERT INTO Demo_Mem.Person(Name)
SELECT value
FROM   Demo_Mem.SingleTable;
GO

CREATE TABLE Demo_Mem.Interaction
(
    InteractionId   int          IDENTITY(1, 1) CONSTRAINT PKInteraction PRIMARY KEY NONCLUSTERED HASH WITH(BUCKET_COUNT = 100),
    Subject         nvarchar(20),
    Message         nvarchar(100),
    InteractionTime datetime2(0),
    PersonId        int          CONSTRAINT FKInteraction$References$Demo_Person REFERENCES Demo_Mem.Person(PersonId),
    CONSTRAINT AKInteraction UNIQUE NONCLUSTERED
    (
        PersonId,
        Subject,
        Message)
)
WITH (MEMORY_OPTIMIZED = ON);
GO

--add an insert first that loads other rows
INSERT INTO Demo_Mem.Interaction(Subject, Message, InteractionTime, PersonId)
VALUES('Hello1', 'Hello There', SYSDATETIME(), 10);

INSERT INTO Demo_Mem.Interaction(Subject, Message, InteractionTime, PersonId)
VALUES('Hello2', 'Hello There', SYSDATETIME(), 9);

INSERT INTO Demo_Mem.Interaction(Subject, Message, InteractionTime, PersonId)
VALUES('Hello3', 'Hello There', SYSDATETIME(), 8);
GO

