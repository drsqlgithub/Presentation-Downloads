SET NOCOUNT ON 
GO
USE SequenceDemos
GO
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('demo.noEvil'))
		DROP TABLE demo.noEvil;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.NoEvil_AccountNumber_SEQUENCE'))
		DROP SEQUENCE Demo.NoEvil_AccountNumber_SEQUENCE;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.NoEvil_SEQUENCE'))
		DROP SEQUENCE Demo.NoEvil_SEQUENCE;
IF EXISTS (SELECT * FROM sys.procedures where object_id = OBJECT_ID('demo.noEvil$getNextAccountNumber'))
		DROP procedure demo.noEvil$getNextAccountNumber;
GO
--sequence will be base of formatted account number, which will be 12 
--characters long: 'A' + 0 padded sequence number + a simple check digit
CREATE SEQUENCE Demo.NoEvil_AccountNumber_SEQUENCE AS int
		START WITH 1 INCREMENT BY 1 CACHE 50000;
GO
--basic surrogate key for our table
CREATE SEQUENCE Demo.NoEvil_SEQUENCE AS int
		START WITH 1 INCREMENT BY 1 CACHE 50000;
go

--use a procedure when just formatting output.  ... 
CREATE  PROCEDURE demo.noEvil$getNextAccountNumber
	@accountNumber char(12) OUTPUT
AS
	--doing it in a loop is the simplest method when complex requirements.
	WHILE (1=1)
	 BEGIN
		--Get the base account number, which is just the next value from the stack
		SET @accountNumber = 'A' + right(replicate ('0',10) + 
					CAST(NEXT VALUE FOR Demo.NoEvil_AccountNumber_SEQUENCE as nvarchar(10)), 10)

		--add a check digit to the account number (take some digits add together, take the first number)
	    SELECT @accountNumber = CAST(@accountNumber AS varchar(11)) + 
			RIGHT(CAST(
			   CAST(SUBSTRING(@accountNumber, 2,1) AS TINYINT) +
			   CAST(SUBSTRING(@accountNumber, 3,1) AS TINYINT) +
			   POWER(CAST(SUBSTRING(@accountNumber, 5,1) AS TINYINT),2) +
			   CAST(SUBSTRING(@accountNumber, 8,1) AS TINYINT) * 3 + 
			   CAST(SUBSTRING(@accountNumber, 9,1) AS TINYINT) * 2 + 
			   CAST(SUBSTRING(@accountNumber, 10,1) AS TINYINT) + 
			   CAST(SUBSTRING(@accountNumber, 11,1) AS TINYINT) * 3  AS VARCHAR(10)),1)

		--if the number doesn't have this character string in it (including check digit)
		if @accountNumber not like '%666%'
				AND @accountNumber NOT LIKE '%22%' --not a fan of #22 or #25 either :)
				AND @accountNumber NOT LIKE '%25%'
		    BREAK -- we are done
     END
go


CREATE TABLE demo.noEvil
(
	noEvilId int primary key DEFAULT (NEXT VALUE FOR Demo.NoEvil_SEQUENCE),
	accountNumber char(12) UNIQUE,
	rowCreateTime datetime2(7) DEFAULT (SYSDATETIME()),
	processId int DEFAULT (@@spid)
)
go

--used for multiple connection test
EXECUTE Utility.WaitForSync$Reset; 
go

