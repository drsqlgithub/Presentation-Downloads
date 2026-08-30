use HowToWriteADmlTrigger;
go
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Measurements.WeatherReading'))
		DROP TABLE Measurements.WeatherReading;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Measurements.WeatherReading_exception'))
		DROP TABLE Measurements.WeatherReading_exception;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Measurements.WeatherReading_SEQUENCE'))
		DROP SEQUENCE Measurements.WeatherReading_SEQUENCE;
IF EXISTS (SELECT * FROM sys.schemas where schema_id = schema_id('Measurements'))
		DROP SCHEMA Measurements;
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE Name = 'Measurements')
	EXEC ('CREATE SCHEMA Measurements;')
GO

--using a sequence for pk to allow for multiple tables using the same surrogate key sequence
CREATE SEQUENCE Measurements.WeatherReading_SEQUENCE
AS INT
START WITH 0
INCREMENT BY 1
MINVALUE 0
NO CYCLE;
GO

CREATE TABLE Measurements.WeatherReading  
(
    WeatherReadingId int NOT NULL CONSTRAINT DFLTWeatherReading_WeatherReadingId 
									DEFAULT (NEXT VALUE FOR Measurements.WeatherReading_SEQUENCE)
          CONSTRAINT PKWeatherReading PRIMARY KEY,
    ReadingTime   datetime2(3) NOT NULL
          CONSTRAINT AKMeasurements_WeatherReading_Date UNIQUE,
    Temperature     float NOT NULL
          CONSTRAINT chkMeasurements_WeatherReading_Temperature
                      CHECK(Temperature between -80 and 150) --anything outside of this should not be entered
                      --raised from last edition for global warming
);
GO

--these values fail because of the one row with a 600 degree temperature!
INSERT  into Measurements.WeatherReading (ReadingTime, Temperature)
VALUES ('20080101 0:00',82.00), ('20080101 0:01',89.22),
       ('20080101 0:02',600.32),('20080101 0:03',88.22),
       ('20080101 0:04',99.01);
GO

select *
from   Measurements.WeatherReading 

--instead, we will create a table to divert the bad values..
--this could be done using the outside tools, like SSIS, but if the tool is 
--something you can't change...this technique is better than getting up at 6 am every 
--night when a sensor acts up...
CREATE TABLE Measurements.WeatherReading_exception -- change to sequence tonight:)
(
    WeatherReadingId  int NOT NULL CONSTRAINT DFLTWeatherReading_Exception_WeatherReadingId 
									DEFAULT (NEXT VALUE FOR Measurements.WeatherReading_SEQUENCE)

          CONSTRAINT PKMeasurements_WeatherReading_exception PRIMARY KEY,
    ReadingTime       datetime2(3) NOT NULL,
    Temperature       float NOT NULL 
);

GO
CREATE TRIGGER Measurements.WeatherReading$InsteadOfInsertTrigger
ON Measurements.WeatherReading
INSTEAD OF INSERT AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON;
   SET ROWCOUNT 0; --in case the client has modified the rowcount
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --           @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
          --[validation section]
          --[modification section]

          --<perform action>

           --GOOD data (Note, repeat pk here or default will fire > 1 time. Remove PK
		   --           if using identity values)
          INSERT Measurements.WeatherReading (WeatherReadingId, ReadingTime, Temperature)
          SELECT WeatherReadingId, ReadingTime, Temperature
          FROM   inserted
          WHERE  (Temperature between -80 and 150);

           --BAD data
          INSERT Measurements.WeatherReading_exception
                                     (WeatherReadingId, ReadingTime, Temperature)
          SELECT WeatherReadingId, ReadingTime, Temperature
          FROM   inserted
          WHERE  NOT(Temperature between -80 and 150);


   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION;

		--[Error logging section]
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
	            @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END
GO


--now you can enter the data as it was before, and no constraints are violated, and the bad
--data is available for debugging
INSERT  INTO Measurements.WeatherReading (ReadingTime, Temperature)
VALUES ('20080101 0:00',82.00), ('20080101 0:01',89.22),
       ('20080101 0:02',600.32),('20080101 0:03',88.22),
       ('20080101 0:04',99.01);
GO

--view the data
SELECT *
FROM Measurements.WeatherReading;
GO

SELECT *
FROM   Measurements.WeatherReading_exception;
GO
