-------------------------------------------------------------------------
-- Range Uniqueness - Requires multiple rows of data for the validation
use HowToWriteADmlTrigger;
go


IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('office.appointment'))
		DROP TABLE office.appointment;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('office.doctor'))
		DROP TABLE office.doctor;
IF EXISTS (SELECT * FROM sys.schemas where schema_id = schema_id('office'))
		DROP SCHEMA office;
GO
CREATE SCHEMA office;
GO
CREATE TABLE office.doctor
(
		doctorId	int NOT NULL CONSTRAINT PKOfficeDoctor PRIMARY KEY,
		doctorNumber char(5) NOT NULL CONSTRAINT AKOfficeDoctor_doctorNumber UNIQUE
);

CREATE TABLE office.appointment
(
	appointmentId	int NOT NULL CONSTRAINT PKOfficeAppointment PRIMARY KEY,
        --real situation would include room, patient, etc, 
	doctorId	int NOT NULL CONSTRAINT FKappointment$isMadeFor$office_doctor
								 REFERENCES office.doctor (doctorId),
	startTime	datetime2(0) NOT NULL, --precision to the second
	endTime		datetime2(0) NOT NULL,
	CONSTRAINT AKOfficeAppointment_DoctorStartTime UNIQUE (doctorId,startTime),
	CONSTRAINT AKOfficeAppointment_DoctorEndTime UNIQUE (doctorId,endTime),
	CONSTRAINT AKOfficeAppointment_StartBeforeEnd CHECK (startTime <= endTime)
);
GO
INSERT INTO office.doctor (doctorId, doctorNumber)
VALUES (1,'00001'),(2,'00002');
INSERT INTO office.appointment(appointmentId, doctorId, startTime, endTime)
VALUES (1,1,'20120712 14:00','20120712 14:59:59'),
	   (2,1,'20120712 15:00','20120712 16:59:59'),

	   (3,2,'20120712 8:00','20120712 11:59:59'),
	   (4,2,'20120712 13:00','20120712 17:59:59'), 
	   (5,2,'20120712 14:00','20120712 14:59:59'); --offensive item for demo, conflicts                
                                                       --with 4

GO

SELECT CASE WHEN Appointment.startTime between Acheck.startTime and Acheck.endTime   then ' 2' ELSE '' END +
	   CASE WHEN Appointment.endTime between Acheck.startTime and Acheck.endTime then ' 3' ELSE '' END + 
	   CASE WHEN appointment.startTime < Acheck.startTime 
                           and appointment.endTime > Acheck.endTime  THEN ' 4' ELSE '' END,
	   appointment.appointmentId,appointment.startTime, appointment.endTime,
       Acheck.appointmentId as conflictingAppointmentId,aCheck.startTime, aCheck.endTime
FROM   office.appointment
          JOIN office.appointment as ACheck
		ON appointment.doctorId = ACheck.doctorId
	/*1*/	   and appointment.appointmentId <> ACheck.appointmentId

	/*2*/	  and (Appointment.startTime between Acheck.startTime and Acheck.endTime  
	
	/*3*/	        or Appointment.endTime between Acheck.startTime and Acheck.endTime
	
	/*4*/	        or (appointment.startTime < Acheck.startTime 
                           and appointment.endTime > Acheck.endTime));


/* In this query, I have highlighted four points: 
/*1*/ In the join, we have to make sure that we don’t compare the current row to itself,
      because an appointment will always overlap itself. 

/*2*/ Here, we check to see if the startTime is between the start and end, inclusive of
      the actual values. 
/*3*/ Same as 2 for the endTime. 
/*4*/ Finally, we check to see if any appointment is engulfing another. 
*/

GO
--make the data right by getting rid of the offensive row
DELETE FROM office.appointment where AppointmentId = 5;
GO
CREATE TRIGGER office.appointment$insertTrigger
ON office.appointment
AFTER INSERT AS 
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
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --           @rowsAffected int = (SELECT COUNT(*) FROM deleted);
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   BEGIN TRY
         --[validation section]
		IF UPDATE(startTime) or UPDATE(endTime) or UPDATE(doctorId)
		   BEGIN
		   --almost all AFTER trigger validations can be written as a query that should
		   --not return any rows, and if it does, raise an error
		   IF EXISTS ( SELECT *
					   FROM   office.appointment
								join office.appointment as ACheck
									on appointment.doctorId = ACheck.doctorId
										and appointment.appointmentId <> ACheck.appointmentId
										and (Appointment.startTime between Acheck.startTime 
																		and Acheck.endTime
											or Appointment.endTime between Acheck.startTime 
																		and Acheck.endTime
											or (appointment.startTime < Acheck.startTime 
													and appointment.endTime > Acheck.endTime))
					  --and for data that is not included in the modified rows, usually a 
					  --correlated subquery to get the groups of affected rows
					  --in this case, the rows for the doctor that is affected
					  --and you could possibly limit the data to a given time period as well, but
					  --we won't for simplicity
					  WHERE  EXISTS (SELECT *									             
									 FROM   inserted --only use inserted because deleted row couldn't cause a conflict
									 WHERE  inserted.doctorId = Acheck.doctorId))
				   BEGIN
				      IF @rowsAffected = 1
						 SELECT @msg = CONCAT('Appointment for doctor ', doctorNumber,
						                      ' overlapped existing appointment.')
									 FROM   inserted
						   JOIN office.doctor
  				  			   on inserted.doctorId = doctor.doctorId;

  					  ELSE --multiple row, just indicate an error occurred. Could get more fancy
						 --but would have to do error finding query again, which could be slow
						 SELECT @msg = CONCAT('One of the inserted rows caused an overlapping ',             
										     'appointment time for a doctor.');
					THROW 50000,@msg,1;

		   END
         END
          --[modification section]
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
CREATE TRIGGER office.appointment$updateTrigger
ON office.appointment
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
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --           @rowsAffected int = (SELECT COUNT(*) FROM deleted);
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   BEGIN TRY
         --[validation section]
		IF UPDATE(startTime) or UPDATE(endTime) or UPDATE(doctorId)
		   BEGIN
		   --almost all AFTER trigger validations can be written as a query that should
		   --not return any rows, and if it does, raise an error
		   IF EXISTS ( SELECT *
					   FROM   office.appointment
								join office.appointment as ACheck
									on appointment.doctorId = ACheck.doctorId
										and appointment.appointmentId <> ACheck.appointmentId
										and (Appointment.startTime between Acheck.startTime 
																		and Acheck.endTime
											or Appointment.endTime between Acheck.startTime 
																		and Acheck.endTime
											or (appointment.startTime < Acheck.startTime 
													and appointment.endTime > Acheck.endTime))
					  --and for data that is not included in the modified rows, usually a 
					  --correlated subquery to get the groups of affected rows
					  --in this case, the rows for the doctor that is affected
					  --and you could possibly limit the data to a given time period as well, but
					  --we won't for simplicity
					  WHERE  EXISTS (SELECT *									             
									 FROM   inserted --only use inserted because deleted row couldn't cause a conflict
									 WHERE  inserted.doctorId = Acheck.doctorId))
				   BEGIN
				      IF @rowsAffected = 1
						 SELECT @msg = CONCAT('Appointment for doctor ', doctorNumber,
						                      ' overlapped existing appointment.')
									 FROM   inserted
						   JOIN office.doctor
  				  			   on inserted.doctorId = doctor.doctorId;

  					  ELSE --multiple row, just indicate an error occurred. Could get more fancy
						 --but would have to do error finding query again, which could be slow
						 SELECT @msg = CONCAT('One of the changed rows caused an overlapping ',             
										     'appointment time for a doctor.');
					THROW 50000,@msg,1;

		   END
         END
          --[modification section]
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
--reminder of data
SELECT *
FROM   office.appointment
ORDER BY doctorId, startTime;

GO

--exactly duplicated time (must be an averlap)
INSERT INTO office.appointment
VALUES (5,1,'20120712 14:00','20110712 14:59:59');
GO


--overlapping range
SELECT *
FROM   office.appointment
ORDER BY doctorId, startTime;

INSERT INTO office.appointment
VALUES (5,1,'20120712 11:30','20120712 14:30:59');
GO

--try multiple rows simultaneously
--first row fails
SELECT *
FROM   office.appointment
ORDER BY doctorId, startTime;
INSERT into office.appointment
VALUES (5,1,'20120712 11:30','20120712 15:29:59'),
       (6,2,'20120713 10:00','20120713 10:59:59')

GO

SELECT *
FROM   office.appointment
ORDER BY doctorId, startTime;


--no error
INSERT INTO office.appointment
VALUES (5,1,'20120712 10:00','20120712 11:59:59'),
       (6,2,'20120713 10:00','20120713 10:59:59');

GO
SELECT *
FROM   office.appointment
ORDER BY doctorId, startTime;
GO

--always test the update
UPDATE office.appointment
SET    startTime = '20120712 15:30',
       endTime = '20120712 15:59:59'
WHERE  appointmentId = 1; 

GO
--This row will work, since it no longer overlapps
UPDATE office.appointment
SET    startTime = '2012-07-12 14:00:00',
       endTime = '2012-07-12 14:29:59' --instead of 14:59
WHERE  appointmentId = 1; 
GO


SELECT *
FROM   office.appointment
ORDER BY doctorId, startTime;
GO




