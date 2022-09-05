use master
Go

--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'UserSpecifiedSchemaDemo')
 exec ('
alter database  UserSpecifiedSchemaDemo
	set single_user with rollback immediate;

drop database UserSpecifiedSchemaDemo;')

CREATE DATABASE UserSpecifiedSchemaDemo; --uses basic defaults from model databases
GO
USE UserSpecifiedSchemaDemo;
GO


CREATE SCHEMA Hardware;
GO
CREATE TABLE Hardware.Equipment
(
    EquipmentId int NOT NULL
          CONSTRAINT PKHardwareEquipment PRIMARY KEY,
    EquipmentTag varchar(10) NOT NULL
          CONSTRAINT AKHardwareEquipment UNIQUE,
    EquipmentType varchar(10),
	
);
GO
INSERT INTO Hardware.Equipment
VALUES (1,'CLAWHAMMER','Hammer'),
       (2,'HANDSAW','Saw'),
       (3,'POWERDRILL','PowerTool');
GO

/*
CREATE TABLE Hardware.Equipment_AltDesign
(
    EquipmentId int NOT NULL
          CONSTRAINT PKHardwareEquipment PRIMARY KEY,
    EquipmentTag varchar(10) NOT NULL
          CONSTRAINT AKHardwareEquipment UNIQUE,
    EquipmentType varchar(10),
	UserDefined1  sql_variant,
	UserDefined2  sql_variant,
	UserDefined3  sql_variant,
	UserDefined4  sql_variant,
	UserDefined5  sql_variant,
	UserDefined6  sql_variant
);
*/

CREATE TABLE Hardware.EquipmentPropertyType
(
    EquipmentPropertyTypeId int NOT NULL
        CONSTRAINT PKHardwareEquipmentPropertyType PRIMARY KEY,
    Name varchar(15)
        CONSTRAINT AKHardwareEquipmentPropertyType UNIQUE,
    TreatAsDatatype sysname NOT NULL
);

INSERT INTO Hardware.EquipmentPropertyType
VALUES(1,'Width','numeric(10,2)'),
      (2,'Length','numeric(10,2)'),
      (3,'HammerHeadStyle','varchar(30)');
GO

CREATE TABLE Hardware.EquipmentProperty
(
    EquipmentId int NOT NULL
      CONSTRAINT FKHardwareEquipment$hasExtendedPropertiesIn$HardwareEquipmentProperty
           REFERENCES Hardware.Equipment(EquipmentId),
    EquipmentPropertyTypeId int
      CONSTRAINT FKHardwareEquipmentPropertyTypeId$definesTypesFor$HardwareEquipmentProperty
           REFERENCES Hardware.EquipmentPropertyType(EquipmentPropertyTypeId),
    Value sql_variant,
    CONSTRAINT PKHardwareEquipmentProperty PRIMARY KEY
                     (EquipmentId, EquipmentPropertyTypeId)
);
GO

CREATE PROCEDURE Hardware.EquipmentProperty$Insert
(
    @EquipmentId int,
    @EquipmentPropertyName varchar(15),
    @Value sql_variant
)
AS
    SET NOCOUNT ON;
    DECLARE @entryTrancount int = @@trancount;

    BEGIN TRY
        DECLARE @EquipmentPropertyTypeId int,
                @TreatASDatatype sysname;

        SELECT @TreatASDatatype = TreatAsDatatype,
               @EquipmentPropertyTypeId = EquipmentPropertyTypeId
        FROM   Hardware.EquipmentPropertyType
        WHERE  EquipmentPropertyType.Name = @EquipmentPropertyName;

      BEGIN TRANSACTION;
        --insert the value
        INSERT INTO Hardware.EquipmentProperty(EquipmentId, EquipmentPropertyTypeId,
                    Value)
        VALUES (@EquipmentId, @EquipmentPropertyTypeId, @Value);


        --Then get that value from the table and cast it in a dynamic SQL
        -- call.  This will raise a trappable error if the type is incompatible
        DECLARE @validationQuery  varchar(max) =
              ' DECLARE @value sql_variant
                SELECT  @value = cast(value as ' + @TreatASDatatype + ')
                FROM    Hardware.EquipmentProperty
                WHERE   EquipmentId = ' + cast (@EquipmentId as varchar(10)) + '
                  and   EquipmentPropertyTypeId = ' +
                       cast(@EquipmentPropertyTypeId as varchar(10)) + ' ';

        EXECUTE (@validationQuery);
      COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
         IF @@TRANCOUNT > 0
             ROLLBACK TRANSACTION;

         DECLARE @ERRORmessage nvarchar(4000)
         SET @ERRORmessage = 'Error occurred in procedure ''' +
                  object_name(@@procid) + ''', Original Message: '''
                 + ERROR_MESSAGE() + '''';
      THROW 50000,@ERRORMessage,16;
      RETURN -100;

     END CATCH

GO

---Error
EXEC Hardware.EquipmentProperty$Insert 1,'Width','Claw'; --width is numeric(10,2)
GO

EXEC Hardware.EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'Width', @Value = 2;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'Length',@Value = 8.4;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'HammerHeadStyle',@Value = 'Claw'
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =2 ,
        @EquipmentPropertyName = 'Width',@Value = 1;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =2 ,
        @EquipmentPropertyName = 'Length',@Value = 7;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =3 ,
        @EquipmentPropertyName = 'Width',@Value = 6;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =3 ,
        @EquipmentPropertyName = 'Length',@Value = 12.1;

GO
--row based output in natural format
SELECT Equipment.EquipmentTag,Equipment.EquipmentType,
       EquipmentPropertyType.name, EquipmentProperty.Value
FROM   Hardware.EquipmentProperty
         JOIN Hardware.Equipment
            on Equipment.EquipmentId = EquipmentProperty.EquipmentId
         JOIN Hardware.EquipmentPropertyType
            on EquipmentPropertyType.EquipmentPropertyTypeId =
                                   EquipmentProperty.EquipmentPropertyTypeId;

GO
--requires hard coded values for types
SET ANSI_WARNINGS OFF; --eliminates the NULL warning on aggregates.
SELECT  Equipment.EquipmentTag,Equipment.EquipmentType,
   MAX(CASE WHEN EquipmentPropertyType.name = 'HammerHeadStyle' THEN Value END)
                                                            AS 'HammerHeadStyle',
   MAX(CASE WHEN EquipmentPropertyType.name = 'Length'THEN Value END) AS Length,
   MAX(CASE WHEN EquipmentPropertyType.name = 'Width' THEN Value END) AS Width
FROM   Hardware.EquipmentProperty
         JOIN Hardware.Equipment
            on Equipment.EquipmentId = EquipmentProperty.EquipmentId
         JOIN Hardware.EquipmentPropertyType
            on EquipmentPropertyType.EquipmentPropertyTypeId =
                                     EquipmentProperty.EquipmentPropertyTypeId
GROUP BY Equipment.EquipmentTag,Equipment.EquipmentType;
SET ANSI_WARNINGS OFF; --eliminates the NULL warning on aggregates.


GO

--dynamic pivot for any types set up
SET ANSI_WARNINGS OFF;
DECLARE @query varchar(8000);
SELECT  @query = 'select Equipment.EquipmentTag,Equipment.EquipmentType ' + (
                SELECT DISTINCT
                    ',MAX(CASE WHEN EquipmentPropertyType.name = ''' +
                       EquipmentPropertyType.name + ''' THEN cast(Value as ' +
                       EquipmentPropertyType.TreatAsDatatype + ') END) AS [' +
                       EquipmentPropertyType.name + ']' AS [text()]
                FROM
                    Hardware.EquipmentPropertyType
                FOR XML PATH('') ) + '
                FROM  Hardware.EquipmentProperty
                             JOIN Hardware.Equipment
                                on Equipment.EquipmentId =
                                     EquipmentProperty.EquipmentId
                             JOIN Hardware.EquipmentPropertyType
                                on EquipmentPropertyType.EquipmentPropertyTypeId
                                   = EquipmentProperty.EquipmentPropertyTypeId
          GROUP BY Equipment.EquipmentTag,Equipment.EquipmentType  '
EXEC (@query);
GO
--add another type
INSERT INTO Hardware.EquipmentPropertyType
VALUES(4,'DemoReady?','numeric(10,2)')


--Adding a column

--use sparse columns...
ALTER TABLE Hardware.Equipment
    ADD Length numeric(10,2) SPARSE NULL;

GO

--allow users to add columns using a given procedure
CREATE PROCEDURE Hardware.Equipment$addProperty
(
    @propertyName   sysname, --the column to add
    @datatype       sysname, --the datatype as it appears in a column creation
    @sparselyPopulatedFlag bit = 1 --Add column as sparse or not
)
WITH EXECUTE AS SELF
AS
  --note: I did not include full error handling for clarity
  DECLARE @query nvarchar(max);

 --check for column existance
 IF NOT EXISTS (SELECT *
               FROM   sys.columns
               WHERE  name = @propertyName
                 AND  OBJECT_NAME(object_id) = 'Equipment'
                 AND  OBJECT_SCHEMA_NAME(object_id) = 'Hardware')
  BEGIN
    --build the ALTER statement, then execute it
     SET @query = 'ALTER TABLE Hardware.Equipment ADD ' + quotename(@propertyName) + ' '
                + @datatype
                + case when @sparselyPopulatedFlag = 1 then ' SPARSE ' end
                + ' NULL ';
     EXEC (@query);
  END
 ELSE
     THROW 50000, 'The property you are adding already exists',16;


GO
--EXEC Hardware.Equipment$addProperty 'Length','numeric(10,2)',1; -- added manually
EXEC Hardware.Equipment$addProperty 'Width','numeric(10,2)',1;
EXEC Hardware.Equipment$addProperty 'HammerHeadStyle','varchar(30)',1;

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle,Length,Width
FROM   Hardware.Equipment;

GO
UPDATE Hardware.Equipment
SET    Length = 7.00,
       Width =  1.00
WHERE  EquipmentTag = 'HANDSAW';

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle,Length,Width
FROM   Hardware.Equipment;
GO
ALTER TABLE Hardware.Equipment
 ADD CONSTRAINT CHKHardwareEquipment$HammerHeadStyle CHECK
        ((HammerHeadStyle is NULL AND EquipmentType <> 'Hammer')
        OR EquipmentType = 'Hammer');
GO
UPDATE Hardware.Equipment
SET    Length = 12.10,
       Width =  6.00,
       HammerHeadStyle = 'Wrong!'
WHERE  EquipmentTag = 'HANDSAW';

GO

UPDATE Hardware.Equipment
SET    Length = 12.10,
       Width =  6.00
WHERE  EquipmentTag = 'POWERDRILL';

UPDATE Hardware.Equipment
SET    Length = 8.40,
       Width =  2.00,
       HammerHeadStyle = 'Claw'
WHERE  EquipmentTag = 'CLAWHAMMER';

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle ,Length,Width
FROM   Hardware.Equipment;

select *
from   Hardware.Equipment;


GO

SELECT name, is_sparse
FROM   sys.columns
WHERE  OBJECT_NAME(object_id) = 'Equipment'

GO
--drop the constraints and columns so we can use an XML column_set
ALTER TABLE Hardware.Equipment
    DROP CONSTRAINT CHKHardwareEquipment$HammerHeadStyle;
ALTER TABLE Hardware.Equipment
    DROP COLUMN HammerHeadStyle, Length, Width;
GO

ALTER TABLE Hardware.Equipment
  ADD SparseColumns xml column_set FOR ALL_SPARSE_COLUMNS;

GO
EXEC Hardware.equipment$addProperty 'Length','numeric(10,2)',1;
EXEC Hardware.equipment$addProperty 'Width','numeric(10,2)',1;
EXEC Hardware.equipment$addProperty 'HammerHeadStyle','varchar(30)',1;
GO


ALTER TABLE Hardware.Equipment
 ADD CONSTRAINT CHKHardwareEquipment$HammerHeadStyle CHECK
        ((HammerHeadStyle is NULL AND EquipmentType <> 'Hammer')
        OR EquipmentType = 'Hammer');

GO

UPDATE Hardware.Equipment
SET    Length = 7,
       Width =  1
WHERE  EquipmentTag = 'HANDSAW';

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle ,Length,Width
FROM   Hardware.Equipment;

select *
from   Hardware.Equipment;



UPDATE Hardware.Equipment
SET    SparseColumns = '<Length>12.10</Length><Width>6.00</Width>'
WHERE  EquipmentTag = 'POWERDRILL';

UPDATE Hardware.Equipment
SET    SparseColumns = '<Length>8.40</Length><Width>2.00</Width>
                        <HammerHeadStyle>Claw</HammerHeadStyle>'
WHERE  EquipmentTag = 'CLAWHAMMER';

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle, Length, Width
FROM   Hardware.Equipment;
GO
SELECT *
FROM   Hardware.Equipment;
GO

--use columnset by name
SELECT EquipmentTag, SparseColumns
FROM   Hardware.Equipment;
GO