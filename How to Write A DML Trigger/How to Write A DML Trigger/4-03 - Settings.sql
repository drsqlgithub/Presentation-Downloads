USE HowToWriteADmlTrigger
go
set nocount on
go
--reset server settings to defaults...
exec sp_configure 'nested triggers',1
exec sp_configure 'disallow results from triggers',0 --allow results
go
reconfigure
go

--There are server configurations
select name, value_in_use, description
from   sys.configurations
where  name like '%trig%'
go

--database settings
USE HowToWriteADmlTrigger;
go

select is_recursive_triggers_on
from   sys.databases
where  database_id = db_id()
GO

--reset the table we will use for this demo
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.TriggerTracer')) 
		DROP TABLE Demo.TriggerTracer;
go
--columns to let you see when the different rows in the demos...
create table Demo.TriggerTracer
(
	triggerTracerId			int not null identity primary key,
	rowCreateTime			datetime2(3) not null default (sysdatetime()),
	rowModifyTime			datetime2(3) not null default (sysdatetime()),
	nestLevel				int not null default (0),
	triggerNestLevel		int not null default (0),
	batchName				varchar(25) not null,
	whereTriggerCalled		varchar(100) not null
)
go
--simple trigger for testing...
create trigger Demo.TriggerTracer$insertTrigger
on Demo.TriggerTracer
after insert
as
	select	'starting ' + object_name(@@procid) as ProcessLocation, 
			@@nestlevel as nestlevel, trigger_nestlevel() as triggerNestlevel
go

--put a row in the table, see the output
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),'Simple-1st','outside')
GO

--the ideal setting for production server... No result sets from triggers...
exec sp_configure 'disallow results from triggers',1
go
reconfigure
go

--now try again to put a row in the table, using extremely similar code
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel,triggerNestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,0,'Simple-2nd','outside')
GO

--use only for debugging... It is however particularly useful for  
--simple path testing... (You can probably use the debugger too, but that is much slower :)
exec sp_configure 'disallow results from triggers',0
go
reconfigure
go



--reset the table for the next setting demo
truncate table Demo.TriggerTracer
go

-----------------------------------
-- database setting recursive triggers
select is_recursive_triggers_on --currently set to the default to not cause trigger recursion
from   sys.databases
where  database_id = db_id()
GO

--now to show the different in nestlevel, @@proc_id, etc
alter trigger Demo.TriggerTracer$insertTrigger
on Demo.TriggerTracer
after insert
as
	select	'starting ' + object_name(@@procid) as ProcessLocation, 
			@@nestlevel as nestlevel, trigger_nestlevel() as triggerNestlevel;

	insert into Demo.TriggerTracer(batchName,rowCreateTime, rowModifyTime,nestLevel, triggerNestLevel, whereTriggerCalled)
	select batchName, sysdatetime(), sysdatetime(),@@nestlevel,trigger_nestlevel(), object_name(@@procid) 
	from   inserted

GO

--put a row in the table
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'NoRecurse-1st','outside');
GO

--no recursion, we only get one additional row...
select *
from   Demo.TriggerTracer;
GO

--show change in nestlevel by repeating in a procedure
create procedure Demo.TriggerTracer$Insert
(	@batchName	varchar(15), @whereTriggerCalled varchar(100) )
as
--put a row in the table
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),@@nestlevel,@batchName,@whereTriggerCalled);
GO


EXEC Demo.TriggerTracer$Insert @batchName = 'NoRecurse-2nd', @whereTriggerCalled = 'procedure';
GO
select *
from   Demo.TriggerTracer;
GO


--now set to allow recursion
alter database HowToWriteADmlTrigger
	set recursive_triggers on;
go

select is_recursive_triggers_on
from   sys.databases
where  database_id = db_id();
GO

--put a row in the table
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'Recursion-3rd','outside')
GO

select *
from   Demo.TriggerTracer
go

--show the inserted table before max limit reached
alter trigger Demo.TriggerTracer$insertTrigger
on Demo.TriggerTracer
after insert
as
	select	'starting ' + object_name(@@procid) as ProcessLocation, 
			@@nestlevel as nestlevel, trigger_nestlevel() as triggerNestlevel;
	
	if @@nestlevel = 32 --show the inserted table before max limit reached
		select *
		from   Demo.TriggerTracer 
		where  batchName in (select batchName
							 from  inserted);

	insert into Demo.TriggerTracer(batchName,rowCreateTime, rowModifyTime,nestLevel, triggerNestLevel, whereTriggerCalled)
	select batchName, sysdatetime(), sysdatetime(),@@nestlevel,trigger_nestlevel(), object_name(@@procid) 
	from   inserted

GO

--put a row in the table
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'Recursion-4th','outside')
GO

--still  no new rows inserted..
select *
from   Demo.TriggerTracer
GO

--restore the default
alter database HowToWriteADmlTrigger
	set recursive_triggers off
GO

--put a row in the table
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'NoRecurse-5th','outside')
GO

select *
from   Demo.TriggerTracer
GO

--reset table for nesting
TRUNCATE TABLE Demo.TriggerTracer
GO
------------------------------
-- Instead of triggers and recursion

--turn recursion on
alter database HowToWriteADmlTrigger
	set recursive_triggers on
GO

--show the inserted table before max limit reached
create trigger Demo.TriggerTracer$insteadOfInsertTrigger
ON Demo.TriggerTracer
INSTEAD OF  insert
as
	select	'starting INSTEAD OF' + object_name(@@procid) as ProcessLocation, 
			@@nestlevel as nestlevel, trigger_nestlevel() as triggerNestlevel;
	
	if @@nestlevel = 32 --show the inserted table before max limit reached
		select *
		from   Demo.TriggerTracer 
		where  batchName in (select batchName
							 from  inserted);

	insert into Demo.TriggerTracer(batchName,rowCreateTime, rowModifyTime,nestLevel, triggerNestLevel, whereTriggerCalled)
	select 'INSTEAD' + batchName, sysdatetime(), sysdatetime(),@@nestlevel,trigger_nestlevel(), object_name(@@procid) 
	from   inserted

GO


--put a row in the table
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'Recursion-5th','outside')
GO


--restore the default
alter database HowToWriteADmlTrigger
	set recursive_triggers off
GO

--put a row in the table
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'Recursion-6th','outside')
GO

TRUNCATE TABLE Demo.TriggerTracer
go
DROP TRIGGER Demo.TriggerTracer$insteadOfInsertTrigger
GO
---------------------------------------------------------------------------------------------------------
-- server setting nested triggers (can triggers cause other triggers to fire)

--make the insert trigger do an update
alter trigger Demo.TriggerTracer$insertTrigger
on Demo.TriggerTracer
after insert
as
	select	'starting ' + object_name(@@procid) as ProcessLocation, 
			@@nestlevel as nestlevel, trigger_nestlevel() as triggerNestlevel;

	--if recursion is on, update will never be hit
	insert into Demo.TriggerTracer(batchName,rowCreateTime, rowModifyTime,nestLevel, triggerNestLevel, whereTriggerCalled)
	select batchName, sysdatetime(), sysdatetime(),@@nestlevel,trigger_nestlevel(), object_name(@@procid) 
	from   inserted

	--dump the data if we are at the max nest level before we fail
	if @@nestlevel = 32
		select *
		from   Demo.TriggerTracer 
		where  batchName in (select batchName
							 from  inserted);

	--new to allow for nesting
	update Demo.TriggerTracer
	set    rowModifyTime = sysdatetime()
	where  triggerTracerId in (select triggerTracerId
							   from   inserted)

GO

--and add an update trigger that does an insert (this certainly could happen!)
create trigger Demo.TriggerTracer$updateTrigger
on Demo.TriggerTracer
after update
as
	select	'starting ' + object_name(@@procid) as ProcessLocation, 
			@@nestlevel as nestlevel, trigger_nestlevel() as triggerNestlevel;

	--dump the data if we are at the max nest level before we fail
	if @@nestlevel = 32
		select *
		from   Demo.TriggerTracer 
		where  batchName in (select batchName
							 from  inserted);

	insert into Demo.TriggerTracer(batchName,rowCreateTime, rowModifyTime,nestLevel, triggerNestLevel, whereTriggerCalled)
	select batchName, sysdatetime(), sysdatetime(),@@nestlevel,trigger_nestlevel(), object_name(@@procid) 
	from   inserted
GO


--------------------------------------------------------------------------
--  Server configuration: Nested Triggers

select *
from   sys.configurations
where  name = 'nested triggers'
go

/*
--should be 1, reset if needed
exec sp_configure 'nested triggers',1
go
reconfigure
go
*/


--note, looks like recursion, but it is really the insert trigger causing the update trigger
--and the update again causing the insert trigger... 
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'Nesting-1st','outside')


--not the ideal setting, but it could force the use of far safer (yet more difficult to code) triggers
--and will stop our problem...though probably causing more concerns
exec sp_configure 'nested triggers',0
go
reconfigure
go

--now what happens?
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'Nesting-2nd','outside')
GO

--only the insert trigger fired...
select * 
from   Demo.TriggerTracer
go

--set it back to the "normal" setting
exec sp_configure 'nested triggers',1
go
reconfigure
go




----------------------------------------------------------------------------
--Multiple triggers and the settings...

drop trigger Demo.TriggerTracer$updateTrigger
go


--yes you can have multiple triggers for the same operation, and they can nest to call the other one
--make sure that the nested trigger setting is what you expect...
alter trigger Demo.TriggerTracer$insertTrigger
on Demo.TriggerTracer
after insert
as
	select	'starting ' + object_name(@@procid) as ProcessLocation, 
			@@nestlevel as nestlevel, trigger_nestlevel() as triggerNestlevel;

	--dump the data if we are at the max nest level before we fail
	if @@nestlevel = 32
		select *
		from   Demo.TriggerTracer 
		where  batchName in (select batchName
							 from  inserted);
	--now we have the insert trigger calling insert
	insert into Demo.TriggerTracer(batchName,rowCreateTime, rowModifyTime,nestLevel, triggerNestLevel, whereTriggerCalled)
	select batchName, sysdatetime(), sysdatetime(),@@nestlevel,trigger_nestlevel(), object_name(@@procid) 
	from   inserted

GO

--identical except for name
create trigger Demo.TriggerTracer$insertTrigger2
on Demo.TriggerTracer
after insert
as
	select	'starting ' + object_name(@@procid) as ProcessLocation, 
			@@nestlevel as nestlevel, trigger_nestlevel() as triggerNestlevel;

	--dump the data if we are at the max nest level before we fail
	if @@nestlevel = 32
		select *
		from   Demo.TriggerTracer 
		where  batchName in (select batchName
							 from  inserted);

	insert into Demo.TriggerTracer(batchName,rowCreateTime, rowModifyTime,nestLevel, triggerNestLevel, whereTriggerCalled)
	select batchName, sysdatetime(), sysdatetime(),@@nestlevel,trigger_nestlevel(), object_name(@@procid) 
	from   inserted

GO

--insert will cause other insert trigger to fire infinitely (if SQL Server would allow it)
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'Nesting-3rd','outside')
GO
select *
from   Demo.TriggerTracer

--set it back to the "abnormal" setting
exec sp_configure 'nested triggers',0
go
reconfigure
go

--now the insert causes both insert triggers, but no more
insert into Demo.TriggerTracer(rowCreateTime, rowModifyTime,nestLevel, batchName,whereTriggerCalled)
values (sysdatetime(), sysdatetime(),0,'Nesting-4th','outside')
GO
--now the insert causes both insert triggers, but no more
select *
from   Demo.TriggerTracer
GO
--set it back to the "normal" setting so future examples are not confused
exec sp_configure 'nested triggers',1
go
reconfigure
go