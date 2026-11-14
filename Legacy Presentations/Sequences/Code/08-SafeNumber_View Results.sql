Use SequenceDemos
GO
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