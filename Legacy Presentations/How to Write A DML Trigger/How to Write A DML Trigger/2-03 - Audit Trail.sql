use HowToWriteADmlTrigger;
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
CREATE TRIGGER hr.employee$updateAuditTrailTrigger
ON hr.employee
AFTER UPDATE AS 
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
          SET @action = 'UPDATE'

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
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;


		THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH
END;

GO
--captures any change to the row and writes the previous version to the log
--silently
CREATE TRIGGER hr.employee$DeleteAuditTrailTrigger
ON hr.employee
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
          --since we are only doing update and delete, we just
          --need to see if there are any rows
          --inserted to determine what action is being done.

          DECLARE @action char(6); --note only one action can happen at a time, even using MERGE
          SET @action = 'DELETE'

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
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;


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