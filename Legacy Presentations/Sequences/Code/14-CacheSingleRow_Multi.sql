Use SequenceDemos
GO
--Run on multiple connections, in two sections
SET NOCOUNT ON
EXECUTE Utility.WaitForSync$StartWait 10;
GO
INSERT INTO Demo.InstrumentReading(Value)
VALUES (RAND());
WAITFOR DELAY '00:00:00.001'
GO 10000

--reset between tests one time: EXECUTE Utility.WaitForSync$Reset

EXECUTE Utility.WaitForSync$StartWait 10;
GO

INSERT INTO Demo.InstrumentReadingIdentity(Value)
VALUES (RAND());
WAITFOR DELAY '00:00:00.001'
GO 10000
