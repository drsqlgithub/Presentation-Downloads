EXECUTE Utility.WaitForSync$StartWait 10; --wait for 15 seconds after first execution
SET NOCOUNT ON
Use SequenceDemos;
go
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
BEGIN TRANSACTION

declare @accountNumber char(12)
exec demo.noEvil$getNextAccountNumber @accountNumber = @accountNumber output

INSERT INTO demo.noEvil (accountNumber)
SELECT  @accountNumber AS accountNumber
COMMIT TRANSACTION

GO 3333 