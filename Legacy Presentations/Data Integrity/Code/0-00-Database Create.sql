USE master
go
--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'HowToImplementDataIntegrity')
 exec ('
alter database  HowToImplementDataIntegrity
	set single_user with rollback immediate;

drop database HowToImplementDataIntegrity;')
GO


CREATE DATABASE HowToImplementDataIntegrity
 ON  PRIMARY 
( NAME = N'HowToImplementDataIntegrity_Data', FILENAME = N'C:\SQL\Data\HowToImplementDataIntegrity_Data.mdf' , SIZE = 200MB , MAXSIZE = 200MB)
 LOG ON 
( NAME = N'HowToImplementDataIntegrity_Log', FILENAME = N'C:\SQL\Log\HowToImplementDataIntegrity_log.ldf' , SIZE = 100MB , MAXSIZE = 100MB)
GO

USE HowToImplementDataIntegrity
go
CREATE SCHEMA Utility
go
CREATE SCHEMA Demo
go

create  procedure utility.relationships$remove
(
	 @table_schema  sysname = '%', 
	 @parent_table_name sysname = '%', --it is the parent when it is being referred to
	 @child_table_name sysname = '%', --it is the child table when it is the table referring 
		  --to another
	 @constraint_name sysname = '%'  --can be used to drop only a single constraint
) as 
-- ----------------------------------------------------------------
-- Drop all of the foreign key contraints on and or to a table
--
-- 2006 Louis Davidson - louis.davidson@compass.net - Compass Technology
-- ----------------------------------------------------------------
 begin
	 set nocount on
	 declare @statements cursor 
	 set @statements = cursor static for 
	 select  'alter table ' + quotename(ctu.table_schema) + '.' + quotename(ctu.table_name) +
			 ' drop constraint ' + quotename(cc.constraint_name)
	 from  information_schema.referential_constraints as cc
			  join information_schema.constraint_table_usage as ctu
			   on cc.constraint_catalog = ctu.constraint_catalog
				  and cc.constraint_schema = ctu.constraint_schema
				  and cc.constraint_name = ctu.constraint_name
	 where   ctu.table_schema like @table_schema  
	   and ctu.table_name like @child_table_name
	   and cc.constraint_name like @constraint_name
	   and   exists (  select *
					   from information_schema.constraint_table_usage ctu2
					   where cc.unique_constraint_catalog = ctu2.constraint_catalog
						  and  cc.unique_constraint_schema = ctu2.constraint_schema
						  and  cc.unique_constraint_name = ctu2.constraint_name
                          and ctu2.table_schema like @table_schema
						  and ctu2.table_name like @parent_table_name)
		  
	 open @statements
	 declare @statement nvarchar(1000)
	 While  (1=1)
	  begin
                fetch from @statements into @statement
                if @@fetch_status <> 0
                 break

                begin try
                    exec (@statement)
                end try
                begin catch
                    select 'Error occurred: ' + cast(error_number() as varchar(10))+ ':' + error_message() + char(13) + char(10) + 
                                            'Statement executed: ' +  @statement
                end catch

	     end
 end
go



create procedure utility.table$remove
(
    @table_name sysname, 
    @table_schema sysname = '%'
) as
-- ----------------------------------------------------------------
-- Drops tables from the database.
--
-- ----------------------------------------------------------------

 begin

	set nocount on
	declare @statements cursor 
	set @statements = cursor for 
	    select 'drop table ' + object_schema_name(object_id)+ '.'+ name
	    from  sys.objects
            where type_desc in ('USER_TABLE')
	      and name like @table_name
	      and object_schema_name(object_id) like @table_schema
	
	open @statements

	declare @statement varchar(1000)

	While 1=1
	 begin
	       fetch from @statements into @statement
               if @@fetch_status <> 0
                    break

               begin try
                exec (@statement)
               end try
	       begin catch
		    select 'Error occurred: ' + cast(error_number() as varchar(10))+ ':' + error_message() + char(13) + char(10) + 
                                        'Statement executed: ' +  @statement
	       end catch

	 end

 end
GO

