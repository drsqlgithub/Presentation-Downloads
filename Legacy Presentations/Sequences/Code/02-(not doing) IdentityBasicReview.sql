Use SequenceDemos;
GO
set nocount on 

IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.IdentityPropertyDemo'))
		DROP TABLE Demo.IdentityPropertyDemo;
GO
create table Demo.IdentityPropertyDemo
(
	IdentityPropertyDemoId int NOT NULL IDENTITY(1,1),
	OtherColumns varchar(50) CHECK (len(OtherColumns) > 1)
)
GO

select IDENT_SEED('Demo.IdentityPropertyDemo') as IdentitySeed
select IDENT_INCR('Demo.IdentityPropertyDemo') as IdentityIncrement
GO
                                   
---------------------------------

--try to insert a value
insert into Demo.IdentityPropertyDemo (identityPropertyDemoId, otherColumns)
values (1,'nope')
go
insert into Demo.IdentityPropertyDemo (OtherColumns)
values ('Yes'),('But what will the values be that are generated?')
GO

select 'Interesting',*
from   Demo.IdentityPropertyDemo
GO


--------------------------------------
TRUNCATE TABLE Demo.IdentityPropertyDemo
GO
--demonstrate the scope_identity, @@identity, IDENT_CURRENT differences

IF EXISTS (SELECT * FROM sys.procedures where object_id = OBJECT_ID('Demo.IdentityPropertyDemo$insert'))
		DROP PROCEDURE Demo.IdentityPropertyDemo$insert;
GO
create procedure Demo.IdentityPropertyDemo$insert
(
	@OtherColumns varchar(50)
)
as
	BEGIN
		insert into Demo.IdentityPropertyDemo (OtherColumns)
		values (@otherColumns)
	END
GO

insert into Demo.IdentityPropertyDemo (OtherColumns)
values ('ad-hoc')
GO
execute demo.IdentityPropertyDemo$insert 'stored procedure'
GO
--next execute this on a different connection
/*
insert into Demo.IdentityPropertyDemo (OtherColumns)
values ('different connection')
*/
GO

--show the 3 values as they appear in the table
select '@@identity', * --last identity on the connection
from   demo.IdentityPropertyDemo
where IdentityPropertyDemoId = @@identity
union all
select 'scope_identity()',* --last identity in scope
from   demo.IdentityPropertyDemo
where IdentityPropertyDemoId = scope_identity()
union all
select 'IDENT_CURRENT(', * --last identity for object
from   demo.IdentityPropertyDemo
where IdentityPropertyDemoId = IDENT_CURRENT('demo.IdentityPropertyDemo')
go

--------------------------------

TRUNCATE TABLE Demo.IdentityPropertyDemo
GO
insert into Demo.IdentityPropertyDemo (OtherColumns)
values ('violate'),('')
GO
insert into Demo.IdentityPropertyDemo (OtherColumns)
values ('Now what values?')

select 'Also Interesting',*
from   Demo.IdentityPropertyDemo
GO
---------------------------------


SET IDENTITY_INSERT Demo.IdentityPropertyDemo ON
insert into Demo.IdentityPropertyDemo (identityPropertyDemoId, otherColumns)
values (1,'yep')
insert into Demo.IdentityPropertyDemo (identityPropertyDemoId, otherColumns)
values (1,'um, whu?')
SET IDENTITY_INSERT Demo.IdentityPropertyDemo OFF

select 'But why?',*
from   Demo.IdentityPropertyDemo
GO

sp_help 'Demo.IdentityPropertyDemo'
go
delete from  Demo.IdentityPropertyDemo
GO

--the current identity value for the table
select IDENT_CURRENT('Demo.IdentityPropertyDemo')
-------------------------------------


TRUNCATE TABLE Demo.IdentityPropertyDemo
GO
ALTER TABLE Demo.IdentityPropertyDemo
	ADD PRIMARY KEY (identityPropertyDemoId)


SET IDENTITY_INSERT Demo.IdentityPropertyDemo ON
insert into Demo.IdentityPropertyDemo (identityPropertyDemoId, otherColumns)
values (2,'yes 2'),(3,'yes 3')
SET IDENTITY_INSERT Demo.IdentityPropertyDemo OFF
GO

DBCC CHECKIDENT ('Demo.IdentityPropertyDemo',RESEED,0)
GO
insert into Demo.IdentityPropertyDemo (otherColumns)
values ('Will this work?')

select *
from Demo.IdentityPropertyDemo 
GO
