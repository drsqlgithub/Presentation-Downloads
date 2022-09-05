USE HowToWriteADmlTrigger
go
set nocount on
GO
--reset the objects for this section
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = object_id('Demo.TriggerOrder')) 
		DROP TABLE Demo.TriggerOrder;
go

CREATE TABLE Demo.TriggerOrder
(
	triggerOrderId INT PRIMARY KEY
)
GO
CREATE TRIGGER Demo.TriggerOrder$afterInsertUpdateA
ON Demo.TriggerOrder
AFTER INSERT, UPDATE AS 
BEGIN
	--error handling/template omitted for clarity
	SELECT object_name(@@procid),
		   CASE WHEN (SELECT COUNT(*) FROM DELETED) > 0 THEN 'Update' ELSE 'Insert' END 
END;
go 
CREATE TRIGGER Demo.TriggerOrder$afterInsertUpdateB
ON Demo.TriggerOrder
AFTER INSERT, UPDATE AS 
BEGIN
	--error handling/template omitted for clarity
	SELECT object_name(@@procid),
		   CASE WHEN (SELECT COUNT(*) FROM DELETED) > 0 THEN 'Update' ELSE 'Insert' END 
END;
GO
CREATE TRIGGER Demo.TriggerOrder$afterInsertUpdateC
ON Demo.TriggerOrder
AFTER INSERT, UPDATE AS 
BEGIN
	--error handling/template omitted for clarity
	SELECT object_name(@@procid),
		   CASE WHEN (SELECT COUNT(*) FROM DELETED) > 0 THEN 'Update' ELSE 'Insert' END 
END;
GO
CREATE TRIGGER Demo.TriggerOrder$afterInsertUpdateD
ON Demo.TriggerOrder
AFTER INSERT, UPDATE AS 
BEGIN
	--error handling/template omitted for clarity
	SELECT object_name(@@procid),
		   CASE WHEN (SELECT COUNT(*) FROM DELETED) > 0 THEN 'Update' ELSE 'Insert' END 
END;
GO
INSERT INTO Demo.TriggerOrder
VALUES (1)
GO
EXEC sp_settriggerorder 'Demo.TriggerOrder$afterInsertUpdateD','first','insert';
EXEC sp_settriggerorder 'Demo.TriggerOrder$afterInsertUpdateA','last','insert';
go
INSERT INTO Demo.TriggerOrder
VALUES (2)
GO
UPDATE Demo.TriggerOrder
SET  triggerOrderId = 2
WHERE triggerOrderId = 2;
GO
EXEC sp_settriggerorder 'Demo.TriggerOrder$afterInsertUpdateB','first','update';
EXEC sp_settriggerorder 'Demo.TriggerOrder$afterInsertUpdateC','last','update';
GO
UPDATE Demo.TriggerOrder
SET  triggerOrderId = 2
WHERE triggerOrderId = 2;
GO

--losing the ordering attribute, accidentally...
alter TRIGGER Demo.TriggerOrder$afterInsertUpdateB
ON Demo.TriggerOrder
AFTER INSERT, UPDATE AS 
BEGIN
	--error handling/template omitted for clarity
	SELECT object_name(@@procid),
		   CASE WHEN (SELECT COUNT(*) FROM DELETED) > 0 THEN 'Update' ELSE 'Insert' END 
END;
GO


--reverting the order on purpose
EXEC sp_settriggerorder 'Demo.TriggerOrder$afterInsertUpdateC','none','update';
GO
UPDATE Demo.TriggerOrder
SET  triggerOrderId = 2
WHERE triggerOrderId = 2;
GO

SELECT schemas.name as schema_name, triggers.name as trigger_name, objects.name as object_name, 
		lower(objects.type_desc) as object_type,
		triggers.is_disabled,
		max(case when trigger_events.type_desc = 'INSERT' then 1 else 0 end) as insert_event,
		max(case when trigger_events.type_desc = 'INSERT' then is_first else 0 end) as insert_first,
		max(case when trigger_events.type_desc = 'INSERT' then is_last else 0 end) as insert_last,
		max(case when trigger_events.type_desc = 'UPDATE' then 1 else 0 end) as update_event,
		max(case when trigger_events.type_desc = 'UPDATE' then is_first else 0 end) as update_first,
		max(case when trigger_events.type_desc = 'UPDATE' then is_last else 0 end) as update_last,
		max(case when trigger_events.type_desc = 'DELETE' then 1 else 0 end) as delete_event,
		max(case when trigger_events.type_desc = 'DELETE' then is_first else 0 end) as delete_first,
		max(case when trigger_events.type_desc = 'DELETE' then is_last else 0 end) as delete_last,
		max(object_definition(triggers.object_id)) as TriggerDefinition
FROM sys.triggers
		join sys.objects
			on objects.object_id = triggers.parent_id
		join sys.schemas
			on objects.schema_id = schemas.schema_id
         JOIN sys.trigger_events
                  ON sys.triggers.object_id = sys.trigger_events.object_id
WHERE parent_id = object_id('Demo.TriggerOrder')
group by schemas.name, triggers.is_disabled,triggers.name, objects.name, lower(objects.type_desc);
go