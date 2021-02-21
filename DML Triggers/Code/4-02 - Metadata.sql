--server settings
select *
from   sys.configurations
where  name like '%trig%'
go

--database settings
select name, is_recursive_triggers_on
from   sys.databases;


use HowToWriteADmlTrigger;
go


--Table and View list with trigger count
SELECT schemas.name as schema_name, objects.name as object_name, lower(objects.type_desc) as object_type,
		SUM(case when trigger_events.type_desc = 'INSERT' then 1 else 0 end) as trigger_insert_count,
		SUM(case when trigger_events.type_desc = 'UPDATE' then 1 else 0 end) as trigger_update_count,
		SUM(case when trigger_events.type_desc = 'DELETE' then 1 else 0 end) as trigger_delete_count,
		MAX(CAST(triggers.is_disabled AS INT)) AS is_disabled
FROM sys.objects
		join sys.schemas
			on objects.schema_id = schemas.schema_id
		left outer join sys.triggers
			 JOIN sys.trigger_events
					  ON sys.triggers.object_id = sys.trigger_events.object_id
			on objects.object_id = triggers.parent_id
WHERE objects.type_desc in ('user_table','view')
group by schemas.name, objects.name, lower(objects.type_desc);

--Trigger list


SELECT schemas.name as schema_name, triggers.name as trigger_name, objects.name as object_name, 
		lower(objects.type_desc) as object_type,
		triggers.is_disabled,triggers.is_instead_of_trigger,
		max(case when trigger_events.type_desc = 'INSERT' then 1 else 0 end) as insert_event,
		max(case when trigger_events.type_desc = 'INSERT' then is_first else 0 end) as insert_first,
		max(case when trigger_events.type_desc = 'UPDATE' then 1 else 0 end) as update_event,
		max(case when trigger_events.type_desc = 'UPDATE' then is_first else 0 end) as update_first,
		max(case when trigger_events.type_desc = 'DELETE' then 1 else 0 end) as delete_event,
		max(case when trigger_events.type_desc = 'DELETE' then is_first else 0 end) as delete_first,
		max(object_definition(triggers.object_id)) as TriggerDefinition
FROM sys.triggers
		join sys.objects
			on objects.object_id = triggers.parent_id
		join sys.schemas
			on objects.schema_id = schemas.schema_id
         JOIN sys.trigger_events
                  ON sys.triggers.object_id = sys.trigger_events.object_id
--WHERE parent_id = object_id('Demo.TriggerOrder')
group by schemas.name, triggers.is_disabled,triggers.name, objects.name, lower(objects.type_desc),triggers.is_instead_of_trigger;
go

--Disable a trigger
DISABLE TRIGGER Characters.Person$InsteadOfInsertTrigger ON Characters.Person
go

--Disable a trigger
ENABLE TRIGGER Characters.Person$InsteadOfInsertTrigger ON Characters.Person
go
--------------------------------------------------------------------------------
-- Table list, with triggers

SELECT schemas.name as schema_name, objects.name as object_name, lower(objects.type_desc) as object_type,
		count(*) over (partition by schemas.name, objects.name)
			 - case when triggers.name is null then 1 else 0 end as TotalTableTriggerCount,
		Coalesce(triggers.name,'--no triggers--') as TriggerName, 
		COALESCE(triggers.is_instead_of_Trigger,-1) AS is_instead_of_trigger,

		max(case when trigger_events.type_desc = 'INSERT' then 1 else 0 end) as insert_event,
		max(case when trigger_events.type_desc = 'UPDATE' then 1 else 0 end) as update_event,
		max(case when trigger_events.type_desc = 'DELETE' then 1 else 0 end) as delete_event
FROM sys.objects
		join sys.schemas
			on objects.schema_id = schemas.schema_id
		left outer join sys.triggers
         JOIN sys.trigger_events
                  ON sys.triggers.object_id = sys.trigger_events.object_id
			on objects.object_id = triggers.parent_id
WHERE objects.type_desc in ('user_table','view')
group by schemas.name, objects.name, lower(objects.type_desc), triggers.NAME,triggers.is_instead_of_Trigger;
GO

--Table list with triggers that reference using DMV...
SELECT   schemas.name, objects.name,  coalesce(referenced_server_name,'<>') + '.'
            + coalesce(referenced_database_name,'<>') + '.'
            + coalesce(referenced_schema_name,'<>') + '.'
            + coalesce(referenced_entity_name,'<>') as referenced_object_name,
        referenced_minor_name
FROM sys.objects
		join sys.schemas
			on objects.schema_id = schemas.schema_id
		cross apply sys.dm_sql_referenced_entities (schemas.name + '.' + objects.name,'OBJECT')
WHERE objects.type_desc ='SQL_TRIGGER'
order by  schemas.name, objects.name