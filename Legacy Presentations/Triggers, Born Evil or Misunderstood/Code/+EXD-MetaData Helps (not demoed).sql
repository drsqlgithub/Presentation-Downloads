--server settings
select *
from   sys.configurations
where  name like '%trig%'
go

--database settings
select name, is_recursive_triggers_on
from   sys.databases;


use TriggerDefense;
go
--add enabled?

--Table and View list with trigger count
SELECT schemas.name as schema_name, objects.name as object_name, lower(objects.type_desc) as object_type,
		SUM(case when trigger_events.type_desc = 'INSERT' then 1 else 0 end) as trigger_insert_count,
		SUM(case when trigger_events.type_desc = 'UPDATE' then 1 else 0 end) as trigger_update_count,
		SUM(case when trigger_events.type_desc = 'DELETE' then 1 else 0 end) as trigger_delete_count
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
--definitely add enabled here
SELECT schemas.name as schema_name,  triggers.name as trigger_name, objects.name as object_name, 
		lower(objects.type_desc) as object_type,
		max(case when trigger_events.type_desc = 'INSERT' then 1 else 0 end) as insert_event,
		max(case when trigger_events.type_desc = 'UPDATE' then 1 else 0 end) as update_event,
		max(case when trigger_events.type_desc = 'DELETE' then 1 else 0 end) as delete_event,
		max(object_definition(triggers.object_id)) as TriggerDefinition
FROM sys.triggers
		join sys.objects
			on objects.object_id = triggers.parent_id
		join sys.schemas
			on objects.schema_id = schemas.schema_id
         JOIN sys.trigger_events
                  ON sys.triggers.object_id = sys.trigger_events.object_id
group by schemas.name, triggers.name, objects.name, lower(objects.type_desc);
go
--------------------------------------------------------------------------------
-- Table list, with triggers

SELECT schemas.name as schema_name, objects.name as object_name, lower(objects.type_desc) as object_type,
		Coalesce(triggers.name,'--no triggers--') as TriggerName, 
		count(*) over (partition by schemas.name, objects.name)
			 - case when triggers.name is null then 1 else 0 end as TableTriggerCount,
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
group by schemas.name, objects.name, lower(objects.type_desc), triggers.name;
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