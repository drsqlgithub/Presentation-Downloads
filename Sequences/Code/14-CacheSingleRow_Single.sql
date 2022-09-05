Use SequenceDemos
GO
set nocount on
GO
--Single connection


INSERT INTO Demo.InstrumentReading(Value)
VALUES (RAND());
GO 10000

INSERT INTO Demo.InstrumentReadingIdentity(Value)
VALUES (RAND());
GO 10000
