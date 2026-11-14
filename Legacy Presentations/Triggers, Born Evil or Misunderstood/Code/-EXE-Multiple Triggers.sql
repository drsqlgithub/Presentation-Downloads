--start with multi-row example of names.... Settings make a difference...

use TriggerDemos;
go
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('account.Contact')) 
		DROP TABLE account.Contact;
IF EXISTS (SELECT * FROM sys.schemas WHERE schema_id = schema_id('account')) 
		DROP SCHEMA account;
GO
create schema account
go
create table account.Contact
(
	accountId	int not null identity primary key,
	FirstName	nvarchar(30) not null,
	LastName    nvarchar(30) not null
)
GO
create trigger account.Contact$InsertUpdateTrigger
ON account.Contact
AFTER UPDATE AS
BEGIN
	select 'starting ' + object_name(@@procid)
	IF EXISTS (Select *
				FROM  account.Contact
				WHERE len(FirstName) = 0 or len(LastName) = 0)
	 BEGIN
		ROLLBACK TRANSACTION;
		THROW 50000, 'THe firstName and lastName values must be non-empty ('''') strings',1;
	 END

END
GO
create trigger account.Contact$InsertUpdateTrigger2
ON account.Contact
AFTER  UPDATE AS
BEGIN
    select 'starting ' + object_name(@@procid)
	UPDATE account.Contact
	SET    LastName = ''
	WHERE  accountId in (select AccountId
						 from Inserted); 
END
GO

exec sp_settriggerorder 'account.Contact$InsertUpdateTrigger2','LAST','INSERT'
exec sp_settriggerorder 'account.Contact$InsertUpdateTrigger2','LAST','UPDATE'
--SELECT trigger_events.type_desc, triggers.*
--FROM sys.trigger_events
--         JOIN sys.triggers
--                  ON sys.triggers.object_id = sys.trigger_events.object_id

insert into account.Contact(FirstName, LastName)
values ('Dino','Flintstone');
go

update account.contact
set LastName = 'Blah'


--insert into account.Contact(FirstName, LastName)
--values ('Fred','Flintstone');
--go
--insert into account.Contact(FirstName, LastName)
--values ('Dino','');
--go

--create trigger account.Contact$InsertUpdateTrigger2
--ON account.Contact
--AFTER INSERT, UPDATE AS
--BEGIN
--    select 'starting ' + object_name(@@procid)
--	UPDATE account.Contact
--	SET    LastName = ''
--	WHERE  accountId in (select AccountId
--						 from Inserted); 
--END
--GO
--insert into account.Contact(FirstName, LastName)
--values ('Dino','');
--go

--drop trigger account.Contact$InsertUpdateTrigger
--GO

--insert into account.Contact(FirstName, LastName)
--values ('Dino','');
--go

--select *
--from   account.Contact

--create trigger account.Contact$InsertUpdateTrigger
--ON account.Contact
--AFTER INSERT, UPDATE AS
--BEGIN
--	select 'starting ' + object_name(@@procid)
--	IF EXISTS (Select *
--				FROM  account.Contact
--				WHERE len(FirstName) = 0 or len(LastName) = 0)
--	 BEGIN
--		ROLLBACK TRANSACTION;
--		THROW 50000, 'THe firstName and lastName values must be non-empty ('''') strings',1;
--	 END
--END
--GO

--insert into account.Contact(FirstName, LastName)
--values ('Barney','Rubble');
--go

--insert into account.Contact(FirstName, LastName)
--values ('Barney','');
--go
