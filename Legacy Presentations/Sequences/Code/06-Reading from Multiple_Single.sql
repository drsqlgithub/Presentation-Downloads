Use SequenceDemos
GO

SELECT NEXT VALUE FOR Demo.First_SEQUENCE as First,
		NEXT VALUE FOR Demo.Second_SEQUENCE as Second,
		NEXT VALUE FOR Demo.Second_SEQUENCE as SecondAgain--,
		
		--,rand(), rand(), sysdatetime()
FROM    Tools.Number
WHERE   I between 1 and 4000

