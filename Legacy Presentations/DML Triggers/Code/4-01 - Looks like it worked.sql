Use HowToWriteADmlTrigger;
go
------------------------------------------------------------------
--Making it seem like something happens but it really hasn't

IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.Version')) 
		DROP TABLE Demo.Version;
go

CREATE TABLE Demo.Version
(
    DatabaseVersion varchar(10) PRIMARY KEY
);
go
CREATE TRIGGER Demo.Version$InsteadOfInsertUpdateDeleteTrigger
ON Demo.Version
INSTEAD OF INSERT, UPDATE, DELETE AS
BEGIN
   SET NOCOUNT ON;
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   --We just put the kibosh on the action and don't tell anyone... Adding the error would be better
   THROW 50000, 'The System.Version table may not be modified in production', 16;
END;
go
set nocount off
go
--seems to work, right?
INSERT  into Demo.Version (DatabaseVersion)
VALUES ('1.0.12');
GO

--this justifies the elimination of triggers alone, right?
select *
from   Demo.Version
GO

--but get rid of the error message...

ALTER TRIGGER Demo.Version$InsteadOfInsertUpdateDeleteTrigger
ON Demo.Version
INSTEAD OF INSERT, UPDATE, DELETE AS
BEGIN
   SET NOCOUNT ON;
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   --We just put the kibosh on the action and don't tell anyone... Adding the error would be better
   --THROW 50000, 'The System.Version table may not be modified in production', 16;
END;
go
set nocount off
go
--seems to work, right?
INSERT  into Demo.Version (DatabaseVersion)
VALUES ('1.0.12');
GO

--this justifies the elimination of triggers alone, right?
select *
from   Demo.Version
GO



-- stop here...