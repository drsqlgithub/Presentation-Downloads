use master
Go

--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'Patterns_FileStorage')
 exec ('
alter database  Patterns_FileStorage
	set single_user with rollback immediate;

drop database Patterns_FileStorage;')

CREATE DATABASE Patterns_FileStorage; --uses basic defaults from model databases
GO
USE Patterns_FileStorage;
GO

--configure server to allow filestream
--The basics are to enable go to SQL Server Configuration Manager 
--if not enabled will need to be resarted

--Then enable the feature in configurations

--0: Disable filestream for the instance; 1: enable filestream for T-SQL; 
--2: Enable T-SQL and Win32 streaming access.
EXEC sp_configure filestream_access_level, 2 
RECONFIGURE
GO

--add a filegroup
ALTER DATABASE Patterns_FileStorage ADD
	FILEGROUP FilestreamData CONTAINS FILESTREAM;

GO
ALTER DATABASE Patterns_FileStorage ADD FILE (
       NAME = FilestreamDataFile1,
       FILENAME = 'd:\sql\filestream') --directory cannot yet exist, but subdir must
TO FILEGROUP FilestreamData;
GO

--first we will simply use the 2005 feature 
CREATE  TABLE TestSimpleFileStream
(
        TestSimpleFilestreamId INT NOT NULL 
                      CONSTRAINT PKTestSimpleFileStream PRIMARY KEY,
        FileStreamColumn VARBINARY(MAX) FILESTREAM NULL,
        RowGuid uniqueidentifier NOT NULL ROWGUIDCOL DEFAULT (NewId()) UNIQUE --A table that has FILESTREAM columns must have a nonnull 
																			  --unique column with the ROWGUIDCOL property. 
)       FILESTREAM_ON FilestreamData; --optional, goes to default otherwise
GO

select *
from  TestSimpleFileStream
GO


INSERT INTO TestSimpleFileStream(TestSimpleFilestreamId,FileStreamColumn)
SELECT 1, CAST(N'This is a slightly exciting example' as varbinary(max));
GO

--in sql, looks just like regular varbinary max. To use specially you need to use 
--api calls.  I won't demonstrate as it is too complex and far too boring :)
SELECT TestSimpleFilestreamId,FileStreamColumn,CAST(FileStreamColumn as nvarchar(40))
FROM   TestSimpleFilestream;
Go

--to use via api, you will basically start a transaction, and using the api calls, 
--get access to manipulate the file:
BEGIN TRANSACTION
SELECT FileStreamColumn.PathName() , GET_FILESTREAM_TRANSACTION_CONTEXT()
from   dbo.TestSimpleFilestream
ROLLBACK TRANSACTION


-----------------------------------
-- File table
-----------------------------------


--set up non-transacted access and the name of the database dir for the UNC name
ALTER database Patterns_FileStorage
	SET FILESTREAM (NON_TRANSACTED_ACCESS = FULL, 
                         DIRECTORY_NAME = N'PatternsDemos');

GO
--create the file table, definte where we put it and what collation to use
CREATE TABLE dbo.FileTableTest AS FILETABLE
  WITH (
        FILETABLE_DIRECTORY = 'FileTableTest',
	     FILETABLE_COLLATE_FILENAME = database_default
	);

GO
--fixed schema
select * 
from   dbo.FileTableTest 

GO
--column metadata
SELECT  *
FROM    ( 

   SELECT    REPLACE(LOWER(objects.type_desc), '_', ' ') AS table_type, schemas.name AS schema_name, objects.name AS table_name,
                    columns.name AS column_name, CASE WHEN columns.is_identity = 1 THEN 'IDENTITY NOT NULL'
                                                      WHEN columns.is_nullable = 1 THEN 'NULL'
                                                      ELSE 'NOT NULL'
                                                 END AS nullability,
                   --types that have a ascii character or binary length
                    CASE WHEN columns.is_computed = 1 THEN 'Computed'
                         WHEN types.name IN ( 'varchar', 'char', 'varbinary' ) THEN types.name + CASE WHEN columns.max_length = -1 THEN '(max)'
                                                                                                      ELSE '(' + CAST(columns.max_length AS VARCHAR(4)) + ')'
                                                                                                 END
                
                         --types that have an unicode character type that requires length to be halved
                         WHEN types.name IN ( 'nvarchar', 'nchar' ) THEN types.name + CASE WHEN columns.max_length = -1 THEN '(max)'
                                                                                           ELSE '(' + CAST(columns.max_length / 2 AS VARCHAR(4)) + ')'
                                                                                      END

                          --types with a datetime precision
                         WHEN types.name IN ( 'time', 'datetime2', 'datetimeoffset' ) THEN types.name + '(' + CAST(columns.scale AS VARCHAR(4)) + ')'

                         --types with a precision/scale
                         WHEN types.name IN ( 'numeric', 'decimal' )
                         THEN types.name + '(' + CAST(columns.precision AS VARCHAR(4)) + ',' + CAST(columns.scale AS VARCHAR(4)) + ')'

                        --timestamp should be reported as rowversion
                         WHEN types.name = 'timestamp' THEN 'rowversion'
                         --and the rest. Note, float is declared with a bit length, but is
                         --represented as either float or real in types 
                         ELSE types.name
                    END AS declared_datatype,

                   --types that have a ascii character or binary length
                    CASE WHEN types.is_assembly_type = 1 THEN 'CLR TYPE'
						 WHEN baseType.name IN ( 'varchar', 'char', 'varbinary' ) THEN baseType.name + CASE WHEN columns.max_length = -1 THEN '(max)'
                                                   ELSE '(' + CAST(columns.max_length AS VARCHAR(4)) + ')'
                                              END
                
                         --types that have an unicode character type that requires length to be halved
                         WHEN baseType.name IN ( 'nvarchar', 'nchar' ) THEN baseType.name + CASE WHEN columns.max_length = -1 THEN '(max)'
                                                                                                 ELSE '(' + CAST(columns.max_length / 2 AS VARCHAR(4)) + ')'
                                                                                            END

                         --types with a datetime precision
                         WHEN baseType.name IN ( 'time', 'datetime2', 'datetimeoffset' ) THEN baseType.name + '(' + CAST(columns.scale AS VARCHAR(4)) + ')'

                         --types with a precision/scale
                         WHEN baseType.name IN ( 'numeric', 'decimal' )
                         THEN baseType.name + '(' + CAST(columns.precision AS VARCHAR(4)) + ',' + CAST(columns.scale AS VARCHAR(4)) + ')'

                         --timestamp should be reported as rowversion
                         WHEN baseType.name = 'timestamp' THEN 'rowversion'
                         --and the rest. Note, float is declared with a bit length, but is
                         --represented as either float or real in types 
                         ELSE baseType.name
                    END AS base_datatype, CASE WHEN EXISTS ( SELECT *
                                                             FROM   sys.key_constraints
                                                                    JOIN sys.indexes
                                                                        ON key_constraints.parent_object_id = indexes.object_id
                                                                           AND key_constraints.unique_index_id = indexes.index_id
                                                                    JOIN sys.index_columns
                                                                        ON index_columns.object_id = indexes.object_id
                                                                           AND index_columns.index_id = indexes.index_id
                                                             WHERE  key_constraints.type = 'PK'
                                                                    AND columns.column_id = index_columns.column_id
                                                                    AND columns.OBJECT_ID = index_columns.OBJECT_ID ) THEN 1
                                               ELSE 0
                                          END AS primary_key_column, columns.column_id, default_constraints.definition AS default_value,
                    check_constraints.definition AS column_check_constraint,
                    CASE WHEN EXISTS ( SELECT   *
                                       FROM     sys.check_constraints AS cc
                                       WHERE    cc.parent_object_id = columns.OBJECT_ID
                                                AND cc.definition LIKE '%~[' + columns.name + '~]%' ESCAPE '~'
                                                AND cc.parent_column_id = 0 ) THEN 1
                         ELSE 0
                    END AS table_check_constraint_reference,
					columnProperties.Description
          FROM      sys.columns
                    JOIN sys.types
                        ON columns.user_type_id = types.user_type_id

                    left outer JOIN sys.types AS baseType
                        ON columns.system_type_id = baseType.system_type_id
                           AND baseType.user_type_id = baseType.system_type_id
                    JOIN sys.objects
                            JOIN sys.schemas
                                   ON schemas.schema_id = objects.schema_id
                        ON objects.object_id = columns.OBJECT_ID
                    LEFT OUTER JOIN sys.default_constraints
                        ON default_constraints.parent_object_id = columns.object_id
                              AND default_constraints.parent_column_id = columns.column_id
                    LEFT OUTER JOIN sys.check_constraints
                        ON check_constraints.parent_object_id = columns.object_id
                             AND check_constraints.parent_column_id = columns.column_id 
					LEFT OUTER JOIN (select major_id as object_id, minor_id as column_id, value as Description
									from   sys.extended_properties
									where  class_desc = 'OBJECT_OR_COLUMN'
									  and  minor_id > 0
									  and name = 'Description')	 as columnProperties
						on columns.object_id = columnProperties.object_id
						   and columns.column_id = columnProperties.column_id
							) AS rows
WHERE   table_type = 'user table'
              AND schema_name LIKE 'dbo'
              AND table_name LIKE 'FileTableTest'
              AND column_name LIKE '%'
              AND nullability LIKE '%'
              AND base_datatype LIKE '%'
              AND declared_datatype LIKE '%'
ORDER BY table_type, schema_name, table_name, column_id
GO


--create a directory
INSERT INTO FiletableTest(name, is_directory) 
VALUES ( 'Project 1', 1);

GO
SELECT stream_id, file_stream, name, is_directory --,*
FROM   FileTableTest
WHERE  name = 'Project 1';
GO
--get the path for UNC access
SELECT FileTableRootPath() + file_stream.GetFileNamespacePath()
FROM FiletableTest
WHERE name = N'Project 1';
GO

INSERT INTO FiletableTest(name, is_directory, file_stream, path_locator) 
VALUES ( 'Test.Txt', 0, cast(N'This is some text' as varbinary(max)),

		--get path to locate the file
		(SELECT path_locator.GetReparentedValue( path_locator.GetAncestor(1),
			   (SELECT path_locator FROM FiletableTest 
				WHERE name = 'Project 1' 
				  AND parent_path_locator is NULL
				  AND is_directory = 1))
		FROM  FiletableTest
		WHERE name = 'Project 1')--WHERE clause will need to be more well thought out
);
GO


--File table can be used in exactly the same manner as the other file_stream columms. This allows transaction modification using
--windows calls, and then you can allow viewing via Windows.
BEGIN TRANSACTION
SELECT file_stream.PathName(), GET_FILESTREAM_TRANSACTION_CONTEXT()
from   dbo.FileTableTest
WHERE  name = 'Test.Txt'
ROLLBACK TRANSACTION

--But it can also be used in a natural manner via non-transaction access:
--Note: notepad cannot be used on a local share due to how it accesses text 
--files.
SELECT FileTableRootPath() + file_stream.GetFileNamespacePath()
FROM  dbo.FiletableTest
where name = 'Test.Txt'

--Or just open up all of the table for the database in Windows Explorer:
SELECT FileTableRootPath() 
GO
--now i can see the data 
SELECT cast(file_stream as nvarchar(1000))
from   dbo.FileTableTest
WHERE  name = 'Test.Txt'