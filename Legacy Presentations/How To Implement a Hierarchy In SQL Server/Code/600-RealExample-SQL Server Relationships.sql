USE AdventureWorks2012
go
WITH tableHierarchy
AS
(
        SELECT  p.object_id AS object_id,
                cast(null AS int) AS parent_id, 
                object_Name(p.object_id) AS tableName,
                cast(NULL AS sysName) AS parentObjectName,
                cast(Name AS varchar(max)) AS parentToChild,
                cast(Name AS varchar(max)) AS childToParent,
                1 AS TreeLevel,
                CAST(null AS sysName) AS keyName
        FROM   sys.tables AS p
        WHERE  NOT EXISTS ( SELECT *
                            FROM   sys.foreign_keys AS fk
                            WHERE fk.parent_object_id = p.object_id) 

        UNION ALL 

        SELECT  fk.parent_object_id,fk.referenced_object_id, 
                object_Name(fk.parent_object_id),                
                object_Name(FK.referenced_object_id) AS tableName,
                parentToChild  + ' \ ' + cast(object_Name(fk.parent_object_id) as varchar(128)),
                cast(object_Name(fk.parent_object_id) as varchar(128)) + ' \ ' + childToParent,
                TreeLevel + 1 as TreeLevel,
                fk.Name
        FROM    sys.foreign_keys AS fk
                    INNER JOIN tableHierarchy
                         on fk.referenced_object_id = tableHierarchy.object_id
)
		--NOTE: Distinct removes duplicates when there are > 1 relationships between two tables
SELECT  DISTINCT tableName AS childTableName, --parentObjectName, keyName AS keyConstraint, 
		childToParent
		--, parentToChild 
FROM   tableHierarchy
WHERE  tableName NOT IN ('sysdiagrams')
ORDER BY childTableName
--ORDER BY coalesce(parentObjectName, tableName)
--ORDER BY parentToChild
--ORDER BY childToParent
--ORDER BY tableName 

--For example, say you need to load data into tables.  The following variant gives you tables that are to be loaded first, then second then third: 
go
