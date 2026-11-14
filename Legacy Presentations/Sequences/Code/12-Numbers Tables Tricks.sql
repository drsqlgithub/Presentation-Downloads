use SequenceDemos
go

--numbers table tricks if you run short of time :)

select *
from   Tools.Number;
GO
;WITH DIGITS (I) as(--set up a set of numbers from 0-9
        SELECT I
        FROM   (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) as digits (I))
--builds a table from 0 to 99999
,Integers (I) as (
        SELECT D1.I + (10*D2.I) + (100*D3.I) + (1000*D4.I) + (10000*D5.I)
               + (100000*D6.I)
        FROM digits AS D1 CROSS JOIN digits AS D2 CROSS JOIN digits AS D3
                CROSS JOIN digits AS D4 CROSS JOIN digits AS D5
                CROSS JOIN digits AS D6)
SELECT * FROM Integers
GO

--show disection of how this query works
;WITH digits (I) AS (--set up a set of numbers from 0-9
        SELECT i
        FROM   (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS digits (I))
SELECT D1.I AS D1I, 10*D2.I AS D2I, D1.I + (10*D2.I) AS [Sum]
FROM digits AS D1 CROSS JOIN digits AS D2
ORDER BY [Sum];


--parsing a string
DECLARE @string varchar(20) = 'Hello nurse!'

SELECT Number.I as Position,
       SUBSTRING(split.value,Number.I,1) as [Character],
       UNICODE(SUBSTRING(split.value,Number.I,1)) as [Unicode]
FROM   Tools.Number
         CROSS JOIN (select @string as value) as split
WHERE  Number.I > 0 --No zeroth  position
  AND  Number.I <= LEN(@string)
ORDER BY Position;
GO


--parse all the names in the adventureworks database
SELECT LastName, Number.I as position,
              SUBSTRING(Person.LastName,Number.I,1) as [char],
              UNICODE(SUBSTRING(Person.LastName, Number.I,1)) as [Unicode]
FROM   Adventureworks2012.Person.Person
         JOIN Tools.Number
               ON Number.I <= LEN(Person.LastName )
                   AND  UNICODE(SUBSTRING(Person.LastName, Number.I,1)) is not null
ORDER  BY LastName ;

GO

--search for non-standard characters
SELECT LastName, Number.I as Position,
              SUBSTRING(Person.LastName,Number.I,1) as [Char],
              UNICODE(SUBSTRING(Person.LastName, Number.I,1)) as [Unicode]
FROM   Adventureworks2012.Person.Person
         JOIN Tools.Number
               ON Number.I <= LEN(Person.LastName )
                  AND  UNICODE(SUBSTRING(Person.LastName, Number.I,1)) is not null
--Note I used both a-z and A-Z in LIKE in case of case sensitive AW database
WHERE  SUBSTRING(Person.LastName, Number.I,1) not like '[a-zA-Z ~''~-]' ESCAPE '~'
ORDER BY LastName, Position ;
GO


--normalizing a set with delimited lists
CREATE TABLE Demo.poorDesign
(
    poorDesignId    int,
    badValue        varchar(20)
);
INSERT INTO Demo.poorDesign
VALUES (1,'1,3,56,7,3,6'),
       (2,'22,3'),
       (3,'1');
GO


SELECT poorDesign.poorDesignId as betterDesignId,
       SUBSTRING(',' + poorDesign.badValue + ',',I + 1,
               CHARINDEX(',',',' + poorDesign.badValue + ',', I + 1) - I - 1)
                                       AS betterScalarValue
FROM   Demo.poorDesign
         JOIN Tools.Number
            on I >= 1
              AND I < LEN(',' + poorDesign.badValue + ',') - 1
              AND SUBSTRING(',' + + poorDesign.badValue  + ',', I, 1) = ',';
GO



DROP TABLE Demo.poorDesign;
GO

--stupid math tricks:

ALTER TABLE Tools.Number
  ADD Ipower3 as cast( power(cast(I as bigint),3) as bigint) PERSISTED  ;
  --Note that I had to cast I as bigint first to let the power function
  --return a bigint

GO
select *
from   Tools.Number



DECLARE @level int = 2; --sum of two cubes
;WITH cubes as
(SELECT Ipower3
FROM   Tools.Number
WHERE  I >= 1 and I < 500) --<<<Vary I for performance, and for cheating reasons,
                           --<<<max needed value

SELECT c1.Ipower3 + c2.Ipower3 as [sum of 2 cubes in @level Ways],
	   min(c1.Ipower3), max(c2.Ipower3), max(c1.Ipower3), min(c2.Ipower3)
FROM   cubes as c1
         cross join cubes as c2
WHERE c1.Ipower3 <= c2.Ipower3 --this gets rid of the "duplicate" value pairs

GROUP by (c1.Ipower3 + c2.Ipower3)
HAVING count(*) = @level
ORDER BY [sum of 2 cubes in @level Ways];
GO


DECLARE @level int = 3; --sum of two cubes
;WITH cubes as
(SELECT Ipower3
FROM   Tools.Number
WHERE  I >= 1 and I < 1000) --<<<Vary for performance, and for cheating reasons,
                           --<<<max needed value

SELECT c1.Ipower3 + c2.Ipower3 as [sum of 2 cubes in @level Ways]
FROM   cubes as c1
         cross join cubes as c2
WHERE c1.Ipower3 < c2.Ipower3
GROUP by (c1.Ipower3 + c2.Ipower3)
HAVING count(*) = @level
ORDER BY [sum of 2 cubes in @level Ways];
GO