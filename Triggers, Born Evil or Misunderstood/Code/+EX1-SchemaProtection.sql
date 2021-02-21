USE TriggerDefense
GO
--this is a standard object I put in my dev databases to make sure I don't accidentally put stuff in
--the dbo schema by accident (unlike the prosecution examples which didn't exactly follow the best practices
--at all times!)
CREATE TRIGGER tr_database$noDboSchemaObjects
ON DATABASE
AFTER CREATE_TABLE, ALTER_TABLE,
	  CREATE_PROCEDURE, ALTER_PROCEDURE,
	  CREATE_FUNCTION, ALTER_FUNCTION,
	  CREATE_SEQUENCE, ALTER_SEQUENCE,
	  CREATE_VIEW, ALTER_VIEW,
	  CREATE_SYNONYM, CREATE_TYPE
AS
 BEGIN
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
 
	--make sure that there are no objects in the dbo schema...
	--if you wanted to allow exceptions, could implement a Utility object that
	--had name and type to allow objects if you are unable to prevent some case
	IF EXISTS ( SELECT *
				FROM   sys.objects
				WHERE  SCHEMA_ID = SCHEMA_ID('dbo')
				  AND  type_desc  IN ('AGGREGATE_FUNCTION','CLR_SCALAR_FUNCTION',
									  'CLR_STORED_PROCEDURE','CLR_TABLE_VALUED_FUNCTION',
									  'CLR_TRIGGER','EXTENDED_STORED_PROCEDURE',
									  'SEQUENCE_OBJECT','SQL_INLINE_TABLE_VALUED_FUNCTION',
									  'SQL_SCALAR_FUNCTION','SQL_STORED_PROCEDURE',
									  'SQL_TABLE_VALUED_FUNCTION','SQL_TRIGGER',
									  'SYNONYM','TABLE_TYPE',
									  'USER_TABLE','VIEW'))
	   BEGIN
	     SELECT 'You tried to execute as statement that was disallowed:'
		      ,EVENTDATA().value
                    ('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]','nvarchar(max)');

		 THROW 50000,'Don''t do that. Get your hands off the dbo schema',16;
	   END
    END TRY
   BEGIN CATCH 
             IF @@trancount > 0 
                ROLLBACK TRANSACTION; --note, THROW can be used as a savepoint name, so the semicolon is essential!

              THROW;

     END CATCH
END
GO
-- test it
create table test
(
	testId int primary key
)
go

create schema fred
go
create table fred.test
(
	testId int
)
go

select *
from fred.test











