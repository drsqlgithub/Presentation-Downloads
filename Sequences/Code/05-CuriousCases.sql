--the datatype of the sequence must be scale = 0, but the output needn't be.
USE SequenceDemos
GO

--Decimal number

IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.NonIntegerColumn'))
		DROP TABLE Demo.NonIntegerColumn;
GO
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.NonIntegerColumn_SEQUENCE'))
		DROP SEQUENCE Demo.NonIntegerColumn_SEQUENCE;
GO
CREATE SEQUENCE Demo.NonIntegerColumn_SEQUENCE
AS int 
START WITH 1
GO
CREATE TABLE Demo.NonIntegerColumn
(
	NumericColumn numeric(10,1) PRIMARY KEY 
	   DEFAULT (NEXT VALUE FOR Demo.NonIntegerColumn_SEQUENCE / 10.0),
	Value int
)
	GO
insert into Demo.NonIntegerColumn(value)
select i
from   Tools.Number
where  i > 100 and i < 300
GO
select *
from Demo.NonIntegerColumn

-------------------------------------------------------------------------
--hex string

IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.NonIntegerColumn'))
		DROP TABLE Demo.NonIntegerColumn;
GO
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.NonIntegerColumn_SEQUENCE'))
		DROP SEQUENCE Demo.NonIntegerColumn_SEQUENCE;
GO
CREATE SEQUENCE Demo.NonIntegerColumn_SEQUENCE
AS int 
START WITH 1
GO
CREATE TABLE Demo.NonIntegerColumn
(
	HexKey varchar(8) PRIMARY KEY 
	   DEFAULT (SUBSTRING(CONVERT(varchar(10), cast(NEXT VALUE FOR Demo.NonIntegerColumn_SEQUENCE as varbinary(10)), 1),3,10)),
	Value int
)
GO
insert into Demo.NonIntegerColumn(value)
select i
from   Tools.Number
where  i > 1 and i < 300
GO
select *
from Demo.NonIntegerColumn

--someday I am going to make a base(52) key with numbers, letters (both lowercase and caps, 26 + 26 + 10)

----------------------------------------

select (i /2) * (1-(2 * (i % 2))) as TheGoal
from   Tools.Number
where i < 100 and i >= 2
order by ABS((i /2) * (1-(2 * (i % 2)))), TheGoal desc
--and i % 2 = 0

--math demo
select i, (i /2) as halfStepProgression, --aka the beauty of integer math
		  (1-(2 * (i % 2))) as PosOddNegEven, -- (2 * (1 or 0)) 1-2 or 1-0 = 1 or -1
		  (i /2) * (1-(2 * (i % 2))) as TheGoal
from   Tools.Number
where i < 100 and i >= 2
order by i


IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.JumpySurrogate'))
		DROP TABLE Demo.JumpySurrogate;
GO
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.JumpySurrogate_SEQUENCE'))
		DROP SEQUENCE Demo.JumpySurrogate_SEQUENCE;
GO
CREATE SEQUENCE Demo.JumpySurrogate_SEQUENCE
AS int 
START WITH 2
GO

create table Demo.JumpySurrogate
(
	JumpySurrogateId int PRIMARY KEY 
		DEFAULT((NEXT VALUE FOR Demo.JumpySurrogate_SEQUENCE /2) * 
				(1-(2 * (NEXT VALUE FOR Demo.JumpySurrogate_SEQUENCE % 2)))),
	Value int
)
GO
insert into Demo.JumpySurrogate(value)
select i
from   Tools.Number
where i < 1000
GO
select *
from   Demo.JumpySurrogate
order by value


