--By Magic, The idea is that these triggers do things that you need to get done without 
--it appearing to do anything...

-------------------------------------------------------------------------
-- Audit trail - side effects

use TriggerDefense;
go

IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('hr.employee_auditTrail'))
		DROP TABLE hr.employee_auditTrail;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('hr.employee'))
		DROP TABLE hr.employee;
IF EXISTS (SELECT * FROM sys.schemas where schema_id = schema_id('hr'))
		DROP SCHEMA hr;
GO

CREATE SCHEMA hr;
GO
CREATE TABLE hr.employee
(
    employee_id char(6) NOT NULL CONSTRAINT PKhr_employee PRIMARY KEY,
    first_name  varchar(20) NOT NULL,
    last_name   varchar(20) NOT NULL,
    salary      decimal(12,2) NOT NULL
);
--simple audit trail, copying the columns in the table and the action, who changed it, and when it changed
CREATE TABLE hr.employee_auditTrail
(
    employee_auditTrailId  int identity CONSTRAINT PKemployee_auditTrail PRIMARY KEY,
	employee_id          char(6) NOT NULL,
    date_changed         datetime2(0) NOT NULL --default so we don't have to
                                               --code for it
          CONSTRAINT DfltHr_employee_date_changed DEFAULT (SYSDATETIME()),
    first_name           varchar(20) NOT NULL,
    last_name            varchar(20) NOT NULL,
    salary               decimal(12,2) NOT NULL,
    --the following are the added columns to the original
    --structure of hr.employee
    action               char(6) NOT NULL
          CONSTRAINT chkHr_employee_action --we don't log inserts, only changes
                                          CHECK(action in ('delete','update')),
    changed_by_user_name sysname NOT NULL
                CONSTRAINT DfltHr_employee_changed_by_user_name
                                          DEFAULT (original_login())
);
GO



--captures any change to the row and writes the previous version to the log
--silently
CREATE TRIGGER hr.employee$updateAndDeleteAuditTrailTrigger
ON hr.employee
AFTER UPDATE, DELETE AS --one trigger for simplicity of demo
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
   --        @rowsAffected int = (select count(*) from inserted)
              @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
          --[validation section]
          --[modification section]
          --since we are only doing update and delete, we just
          --need to see if there are any rows
          --inserted to determine what action is being done.

          DECLARE @action char(6); --note only one action can happen at a time, even using MERGE
          SET @action = CASE WHEN (SELECT count(*) FROM inserted) > 0
                             THEN 'update' ELSE 'delete' END;

          --since the deleted table contains all changes, we just insert all
          --of the rows in the deleted table and we are done.
          INSERT employee_auditTrail (employee_id, first_name, last_name,
                                     salary, action)
          SELECT employee_id, first_name, last_name, salary, @action
          FROM   deleted;

   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION;
		--[Error logging section]

		THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH
END;

GO

INSERT hr.employee (employee_id, first_name, last_name, salary)
VALUES (1, 'Phillip','Taibul',10000);
GO
INSERT hr.employee (employee_id, first_name, last_name, salary)
VALUES (2, 'Ugottabee','Kidding',20000);
GO
INSERT hr.employee (employee_id, first_name, last_name, salary)
VALUES (3, 'Gonagedda','Sack',20000);
GO
--now look at the data
SELECT *
FROM   hr.employee;
go
SELECT *
FROM   hr.employee_auditTrail
order by employee_Id, date_changed;
GO

--modify the data
UPDATE hr.employee
SET salary = salary * 1.10 --ten percent raise for everyone;

--then update a few rows
UPDATE hr.employee
SET salary = salary * 1.05 --five more for our good employee!
WHERE employee_id = 2;

--and delete one row
DELETE hr.employee
WHERE employee_id = 3; -- and Mr Sack gets it 
go

--now look at the data
SELECT *
FROM   hr.employee;

SELECT *
FROM   hr.employee_auditTrail
order by employee_Id, date_changed;
GO


---------------------------------------------------------------------------
-- High speed data diversion
--
-- Like readings coming in from a machine, or heads down data entry

IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Measurements.WeatherReading'))
		DROP TABLE Measurements.WeatherReading;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Measurements.WeatherReading_exception'))
		DROP TABLE Measurements.WeatherReading_exception;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Measurements.WeatherReading_SEQUENCE'))
		DROP SEQUENCE Measurements.WeatherReading_SEQUENCE;
IF EXISTS (SELECT * FROM sys.schemas where schema_id = schema_id('Measurements'))
		DROP SCHEMA Measurements;
GO

CREATE SCHEMA Measurements;
GO
--using a sequence for pk to allow for multiple tables using the same sequence
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

--note, this technique could be used for heads down data entry, where data is cleaned inline and data that doesn't
--meet the basic requirements is sent to a cleaning queue rather than put directly into the primary tables



--Additional examples not done for time:
--using an instead of trigger to format data
--using an instead of trigger to make a view updatable.



----------------------------------------------------------------------------
-- Row Modification/Creation Time/Data Formatting


IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Example.InsteadOfTriggerExample'))
		DROP TABLE Example.InsteadOfTriggerExample;
IF EXISTS (SELECT * FROM sys.schemas where schema_id = schema_id('Example'))
		DROP SCHEMA Example;
GO

create schema Example;
go

CREATE TABLE Example.InsteadOfTriggerExample
(
        InsteadOfTriggerExampleId  int NOT NULL 
                        CONSTRAINT PKInsteadOfTriggerExample PRIMARY KEY,
        FormatUpper  varchar(30) NOT NULL,
        RowCreatedTime datetime2(3) NOT NULL,
        RowLastModifyTime datetime2(3) NOT NULL
);

GO

CREATE TRIGGER Example.InsteadOfTriggerExample$InsteadOfInsertTrigger
ON Example.InsteadOfTriggerExample
INSTEAD OF INSERT AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
          @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --     @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action> --this is all I change other than the name and table in the
                              --trigger declaration/heading
          INSERT INTO Example.InsteadOfTriggerExample                
                      (InsteadOfTriggerExampleId,FormatUpper,
                       RowCreatedTime,RowLastModifyTime)
          --uppercase the FormatUpper column, set the %time columns to system time
           SELECT InsteadOfTriggerExampleId, UPPER(FormatUpper),
                  sysdatetime(),sysdatetime()                                                                 
           FROM   Inserted;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


INSERT INTO Example.InsteadOfTriggerExample (InsteadOfTriggerExampleId,FormatUpper)
VALUES (1,'not upper at all');
GO

SELECT *
FROM   Example.InsteadOfTriggerExample;
GO

INSERT INTO Example.InsteadOfTriggerExample (InsteadOfTriggerExampleId,FormatUpper)
VALUES (2,'UPPER TO START'),(3,'UpPeRmOsT tOo!');
GO


SELECT *
FROM   Example.InsteadOfTriggerExample;
GO

--causes an error
INSERT INTO Example.InsteadOfTriggerExample (InsteadOfTriggerExampleId,FormatUpper)
VALUES (4,NULL) ;
GO


--cover the update case...
CREATE TRIGGER Example.InsteadOfTriggerExample$InsteadOfUpdateTrigger
ON Example.InsteadOfTriggerExample
INSTEAD OF UPDATE AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
         @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --    @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action> 
          --note, this trigger assumes non-editable keys. Consider adding a surrogate key
          --(even non-pk) if you need to be able to modify key values
          UPDATE InsteadOfTriggerExample 
          SET    FormatUpper = UPPER(Inserted.FormatUpper),
                 --RowCreatedTime, Leave this value out to make sure if it was updated
				                   --that the value will not change...
                 RowLastModifyTime = SYSDATETIME()
          FROM   Inserted
                   JOIN Example.InsteadOfTriggerExample 
                       ON Inserted.InsteadOfTriggerExampleId = 
                                 InsteadOfTriggerExample.InsteadOfTriggerExampleId;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]

      THROW;--will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

--test, updating the dates to rediculous values (that we have all seen mistakenly
--made no doubt!
UPDATE  Example.InsteadOfTriggerExample
SET     RowCreatedTime = '1900-01-01',
        RowLastModifyTime = '1900-01-01',
        FormatUpper = 'final test'
WHERE   InsteadOfTriggerExampleId in (1,2);
GO

--Yet it doesn't stick...Solving at least one data issue...
SELECT *
FROM   Example.InsteadOfTriggerExample;
GO


-------------------------------------------------------------------------
-- Instead of Trigger Making a View act Like a Table with Multiple Tables
create schema Example;
go


IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Example.TableName'))
		DROP TABLE Example.TableName;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Example.TableNameA'))
		DROP TABLE Example.TableNameA;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Example.TableNameB'))
		DROP TABLE Example.TableNameB;

--say you have a simple enough table...
create table Example.TableName
(
	TableNameId int PRIMARY KEY,
	ValueA	varchar(10) NULL,
	ValueB  varchar(10) NULL
)
go

--with some simple enough data
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (1, NULL, '10');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (2, '20', '20');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (3, '30', NULL);
GO       

select *
from   Example.TableName
GO

--Now say you need to partition the table for some reason...
CREATE TABLE Example.TableNameA
(
    TableNameId int PRIMARY KEY,
    ValueA  varchar(10) NULL
)
CREATE TABLE Example.TableNameB
(
    TableNameId int PRIMARY KEY,
    ValueB  varchar(10) NULL
)
GO

--split the data...Only put rows that are non-null...
insert into Example.TableNameA
select TableNameId, valueA
from   Example.TableName
where  valueA is not null

insert into Example.TableNameB
select TableNameId, ValueB
from   Example.TableName
where ValueB is not null;
GO
--get rid of the real table
drop table Example.TableName
go

CREATE VIEW Example.TableName
AS 
    SELECT  coalesce(tableNameA.tableNameId, tableNameB.tableNameId) AS TableNameId,
            TableNameA.ValueA, TableNameB.ValueB
    FROM    Example.TableNameA
                FULL OUTER JOIN Example.TableNameB
                    ON tableNameA.tableNameId = tableNameB.tableNameId
GO 

select *
from Example.Tablename
go

--now we want to use the view like a table, but this won't work 
--as is because the view isn't on just one table.
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (4, NULL, '10');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (5, '20', '20');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (6, '30', NULL);
GO              

--so we will create an instead of trigger that does the insert for us
CREATE TRIGGER Example.TableName$InsteadOfInsertTrigger
ON Example.TableName
INSTEAD OF INSERT AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --@rowsAffected = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;


   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors
          --[modification section] In this section, the goal is no errors but do any data mods here
          --<perform action>  In this section (generally the only one used in an instead of trigger), youi
		                    --will usually cause the operation replaced by the trigger to occur
		INSERT INTO Example.TableNameA(TableNameId,ValueA)
		SELECT TableNameId, ValueA
		FROM inserted
		WHERE ValueA IS NOT null; 

		INSERT INTO Example.TableNameB(TableNameId,ValueB)
		SELECT TableNameId, ValueB
		FROM inserted
		WHERE ValueB IS NOT null
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

      --[Error logging section]
      --DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
      --         @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
      --         @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
      --EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;

go

--now we want to use the view like a table, and the instead of 
--trigger allows that
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (4, NULL, '10');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (5, '20', '20');
INSERT INTO Example.TableName(TableNameId, ValueA, ValueB)
VALUES (6, '30', NULL);
GO      

SELECT *
FROM   Example.TableName
GO 

--Now we try to do an update on the view:
UPDATE Example.TableName --seems to work but no rows modified (the row for A doesn't exist!)
SET    ValueA = 'U10'
WHERE  TableNameId = 1 

SELECT *
FROM   Example.TableName
WHERE  TableNameId = 1
GO 
UPDATE Example.TableName --updates both tables
SET    ValueA = 'U20',
       ValueB = 'U21'
WHERE  tableNameId = 2 
GO
UPDATE Example.TableName
SET    ValueB = 'U30'
WHERE  tableNameId = 3
GO 

SELECT *
FROM Example.TableName
GO 

--so to make this view updatable in a reasonable manner, we need to 
--use an insead of trigger
CREATE TRIGGER Example.TableName$InsteadOfUpdateTrigger
ON Example.TableName
INSTEAD OF UPDATE AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --@rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;


   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors
          --[modification section] In this section, the goal is no errors but do any data mods here
          --<perform action>  In this section (generally the only one used in an instead of trigger), youi
		                    --will usually cause the operation replaced by the trigger to occur
		    UPDATE TableNameA
			SET    ValueA = inserted.ValueA
			FROM   Example.TableNameA
					  JOIN inserted
						  ON TableNameA.TableNameId = inserted.TableNameId
			IF @@rowcount = 0
			  BEGIN
					INSERT INTO Example.TableNameA(TableNameId,ValueA)
					SELECT TableNameId, ValueA
					FROM inserted
					WHERE ValueA IS NOT NULL
			  END 

			UPDATE TableNameB
			SET    ValueB = inserted.ValueB
			FROM   Example.TableNameB
					  JOIN inserted
						  ON tableNameB.tableNameId = inserted.tableNameId 

			IF @@rowcount = 0
			  BEGIN
					INSERT INTO Example.TableNameB(TableNameId,ValueB)
					SELECT TableNameId, ValueB
					FROM inserted
					WHERE ValueB IS NOT NULL
			  END
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

      --[Error logging section]
      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO 

UPDATE Example.TableName
SET    ValueA = 'U10'
WHERE  tableNameId = 4 

UPDATE Example.TableName
SET    ValueA = 'U20',
       ValueB = 'U21'
WHERE  tableNameId = 5 

UPDATE Example.TableName
SET    ValueB = 'U30'
WHERE  tableNameId = 6
GO 

SELECT *
FROM Example.TableName
go

--optimistic aren't I?
delete Example.TableName
go


CREATE TRIGGER Example.TableName$InsteadOfDeleteTrigger
ON Example.TableName
INSTEAD OF DELETE AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
    ---@rowsAffected int = (SELECT COUNT(*) FROM inserted);
			@rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;


   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors
          --[modification section] In this section, the goal is no errors but do any data mods here
          --<perform action>  In this section (generally the only one used in an instead of trigger), youi
		                    --will usually cause the operation replaced by the trigger to occur
		    DELETE tableNameA
			FROM   Example.tableNameA
					  JOIN deleted
						  ON tableNameA.tableNameId = deleted.tableNameId

			DELETE tableNameB
			FROM   Example.tableNameB
					  JOIN deleted
						  ON tableNameB.tableNameId = deleted.tableNameId 
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

      --[Error logging section]
      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO 


select *
from   Example.TableName;
GO
--delete 1 row
delete Example.TableName
WHERE TableNameId = 6
go

SELECT *
FROM Example.tableName
go

--delete > 1 row
delete Example.TableName
WHERE tableNameId > 3
go

SELECT *
FROM Example.TableName
go

--Obviously this is unlikely
truncate table Example.Tablename
go

--but you could do:
truncate table Example.TablenameA
go
truncate table Example.TablenameB
go


--empty!
SELECT *
FROM Example.tableName
go



---------------------------------------------------------------------------
-- Delete unused parent rows - CASCADE PARENT DELETE

IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Entertainment.GameInstance'))
		DROP TABLE Entertainment.GameInstance;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Entertainment.Game'))
		DROP TABLE Entertainment.Game;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Entertainment.GamePlatform'))
		DROP TABLE Entertainment.GamePlatform;
IF EXISTS (SELECT * FROM sys.schemas where schema_id = schema_id('Entertainment'))
		DROP SCHEMA Entertainment;
GO

CREATE SCHEMA Entertainment;
go
CREATE TABLE Entertainment.GamePlatform
(
    GamePlatformId int NOT NULL CONSTRAINT PKEntertainmentGamePlatform PRIMARY KEY,
    Name  varchar(50) NOT NULL CONSTRAINT AKEntertainmentGamePlatform_Name UNIQUE
);
CREATE TABLE Entertainment.Game
(
    GameId  int NOT NULL CONSTRAINT PKEntertainmentGame PRIMARY KEY,
    Name    varchar(50) NOT NULL CONSTRAINT AKEntertainmentGame_Name UNIQUE
    --more details that are common to all platforms
);

--associative entity with cascade relationships back to Game and GamePlatform
CREATE TABLE Entertainment.GameInstance
(
    GamePlatformId int NOT NULL ,
    GameId int NOT NULL ,
    PurchaseDate date NOT NULL,
    CONSTRAINT PKEntertainmentGameInstance PRIMARY KEY (GamePlatformId, GameId),
    CONSTRAINT
    EntertainmentGame$is_owned_on_platform_by$EntertainmentGameInstance
      FOREIGN KEY (GameId) REFERENCES Entertainment.Game(GameId)
                                               ON DELETE CASCADE,
      CONSTRAINT
        EntertainmentGamePlatform$is_linked_to$EntertainmentGameInstance
      FOREIGN KEY (GamePlatformId)
           REFERENCES Entertainment.GamePlatform(GamePlatformId)
                ON DELETE CASCADE
);
GO

INSERT  into Entertainment.Game (GameId, Name)
VALUES (1,'Lego Pirates of the Carribean'),
       (2,'Legend Of Zelda: Ocarina of Time');

INSERT  into Entertainment.GamePlatform(GamePlatformId, Name)
VALUES (1,'Nintendo Wii'),   --Yes, as a matter of fact I am still a
       (2,'Nintendo 3DS');     --Nintendo Fanboy, why do you ask?

--the full outer joins ensure that all rows are returned from all sets, leaving
--nulls where data is missing...Show data before associations made
SELECT  GamePlatform.Name as Platform, Game.Name as Game, GameInstance. PurchaseDate
FROM    Entertainment.Game as Game
            FULL OUTER JOIN Entertainment.GameInstance as GameInstance
                    ON Game.GameId = GameInstance.GameId
            FULL OUTER JOIN Entertainment.GamePlatform
                    ON GamePlatform.GamePlatformId = GameInstance.GamePlatformId;
GO

--indicate the purchase
INSERT  into Entertainment.GameInstance(GamePlatformId, GameId, PurchaseDate)
VALUES (1,1,'20110804'),
       (1,2,'20110810'),
       (2,2,'20110604');

--the full outer joins ensure that all rows are returned from all sets, leaving
--nulls where data is missing
SELECT  GamePlatform.Name as Platform, Game.Name as Game, GameInstance. PurchaseDate
FROM    Entertainment.Game as Game
            FULL OUTER JOIN Entertainment.GameInstance as GameInstance
                    ON Game.GameId = GameInstance.GameId
            FULL OUTER JOIN Entertainment.GamePlatform
                    ON GamePlatform.GamePlatformId = GameInstance.GamePlatformId;
GO

CREATE TRIGGER Entertainment.GameInstance$afterDeleteTrigger
ON Entertainment.GameInstance
AFTER DELETE AS
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
   --        @rowsAffected int = (select count(*) from inserted)
             @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
        --[validation section] 

        --[modification section]
                         --delete all Games
        DELETE Game      --where the GameInstance was deleted ie. Inverse Cascade Delete
        WHERE  GameId in (SELECT deleted.GameId
                          FROM   deleted     --and there are no GameInstances
                           WHERE  not exists (SELECT  *        --left
                                              FROM    GameInstance
                                              WHERE   GameInstance.GameId =
                                                               deleted.GameId));
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION;
		--[Error logging section]

		THROW; --will halt the batch or be caught by the caller's catch block

   END CATCH
END
GO
DELETE Entertainment.GamePlatform
WHERE GamePlatformId = 1;
GO
SELECT GamePlatform.Name AS Platform, Game.Name AS Game, GameInstance. PurchaseDate
FROM Entertainment.Game AS Game
FULL OUTER JOIN Entertainment.GameInstance as GameInstance
ON Game.GameId = GameInstance.GameId
FULL OUTER JOIN Entertainment.GamePlatform
ON GamePlatform.GamePlatformId = GameInstance.GamePlatformId;
GO

