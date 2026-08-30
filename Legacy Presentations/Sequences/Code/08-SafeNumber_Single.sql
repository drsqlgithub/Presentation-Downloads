use SequenceDemos
GO

--@accountNumber NOT LIKE '%666%', '%22%' or '%25%'

--checkdigit isn't simple sum!
declare @accountNumber char(12)
exec demo.noEvil$getNextAccountNumber @accountNumber = @accountNumber OUTPUT
SELECT @accountNumber
GO
ALTER SEQUENCE Demo.NoEvil_AccountNumber_SEQUENCE RESTART
GO

/*
CREATE TABLE demo.noEvil
(
	noEvilId int primary key DEFAULT (NEXT VALUE FOR Demo.NoEvil_SEQUENCE),
	accountNumber char(12) UNIQUE,
	rowCreateTime datetime2(7) DEFAULT (SYSDATETIME()),
	processId int DEFAULT (@@spid)
)
*/
go
set nocount on
--execute the next two batches together to see numbers generated
declare @accountNumber char(12)
exec demo.noEvil$getNextAccountNumber @accountNumber = @accountNumber output

INSERT INTO demo.noEvil (accountNumber)
SELECT  @accountNumber AS accountNumber
GO 100 


select max(noEvilId) as EvilIdMax, COUNT(*) AS numRows, max(accountNumber) as AccountNumberMax,
	   DATEDIFF(minute,MIN(rowCreateTime), MAX(rowCreateTime)) AS RunMinutes,
	   DATEDIFF(second,MIN(rowCreateTime), MAX(rowCreateTime)) AS RunSeconds,
	   DATEDIFF(millisecond,MIN(rowCreateTime), MAX(rowCreateTime)) AS RunMilliseconds
from  demo.noEvil    
GO
--@accountNumber NOT LIKE '%666%', '%22%' or '%25%'
select * 
from   demo.noEvil
order by 2

--execute the next four batches together to see numbers generated, this time adding 10000
TRUNCATE TABLE demo.noEvil 
ALTER SEQUENCE Demo.NoEvil_AccountNumber_SEQUENCE RESTART WITH 66599
												 --6659999  took .2 seconds
												 --665999999 took 20 seconds on this laptop , with one process
ALTER SEQUENCE Demo.NoEvil_SEQUENCE RESTART
GO
set nocount on
declare @accountNumber char(12)
exec demo.noEvil$getNextAccountNumber @accountNumber = @accountNumber output

INSERT INTO demo.noEvil (accountNumber)
SELECT  @accountNumber AS accountNumber
GO 10000



GO
select datediff (millisecond,gap.rowcreateTime,noEvil.rowCreateTime) as createTimeGap
	  , gap.accountNumber, noEvil.accountNumber
from   demo.noEvil
		 join demo.noEvil as gap
			on gap.noEvilId = noEvil.noEvilId - 1
order by createTimeGap desc
GO

/*
numRows     accountNumber seconds                                 minutes
----------- ------------- --------------------------------------- ---------------------------------------
8460688     A00097241656  2351.244000                             39.187400000

(1 row(s) affected)

createTimeGap accountNumber accountNumber
------------- ------------- -------------
1591          A00024999995  A00026000004
1560          A00021999995  A00023000004
187           A00042499997  A00042600006
172           A00052499996  A00052600005
172           A00012499992  A00012600001
171           A00042199997  A00042300006
171           A00002199991  A00002300000
171           A00002499991  A00002600000
171           A00012199992  A00012300001
171           A00092199992  A00092300001
*/


select max(noEvilId) as EvilIdMax, COUNT(*) AS numRows, 
	   min(accountNumber) as AccountNumberMin,
	   max(accountNumber) as AccountNumberMax,
	   DATEDIFF(minute,MIN(rowCreateTime), MAX(rowCreateTime)) AS RunMinutes,
	   DATEDIFF(second,MIN(rowCreateTime), MAX(rowCreateTime)) AS RunSeconds,
	   DATEDIFF(millisecond,MIN(rowCreateTime), MAX(rowCreateTime)) AS RunMilliseconds
from  demo.noEvil    
GO

--check the skipped values...
SELECT I, 'A' + right(replicate ('0',10) + CAST(I as nvarchar(10)), 10) 
			 + RIGHT(CAST(
				CAST(SUBSTRING('A' + right(replicate ('0',10) + CAST(I as nvarchar(10)), 10) , 2,1) AS TINYINT) +
			   CAST(SUBSTRING('A' + right(replicate ('0',10) + CAST(I as nvarchar(10)), 10) , 3,1) AS TINYINT) +
			  POWER(CAST(SUBSTRING('A' + right(replicate ('0',10) + CAST(I as nvarchar(10)), 10) , 5,1) AS TINYINT),2) +
			   CAST(SUBSTRING('A' + right(replicate ('0',10) + CAST(I as nvarchar(10)), 10) , 8,1) AS TINYINT) * 3 + 
			   CAST(SUBSTRING('A' + right(replicate ('0',10) + CAST(I as nvarchar(10)), 10) , 9,1) AS TINYINT) * 2 + 
			   CAST(SUBSTRING('A' + right(replicate ('0',10) + CAST(I as nvarchar(10)), 10) , 10,1) AS TINYINT) + 
			   CAST(SUBSTRING('A' + right(replicate ('0',10) + CAST(I as nvarchar(10)), 10) , 11,1) AS TINYINT) * 3  AS VARCHAR(10)),1) as badNumber
FROM   (

		--get gaps in sequence, using the values from accountNumber generation. Positions 2-10 are the sequence bits
		SELECT I
		FROM   Tools.Number
		WHERE  I BETWEEN  (SELECT MIN(CAST(SUBSTRING (AccountNumber,2,10) as Int))
						  FROM   demo.noEvil  )
						   and (SELECT MAX(CAST(SUBSTRING (AccountNumber,2,10) as Int))
						  FROM   demo.noEvil  )
		EXCEPT
		SELECT CAST(SUBSTRING (AccountNumber,2,10) as Int)
		FROM   demo.noEvil  ) as AccountNumbers



