use master
Go

--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'Patterns_Generalization')
 exec ('
alter database  Patterns_Generalization
	set single_user with rollback immediate;

drop database Patterns_Generalization;')

CREATE DATABASE Patterns_Generalization; --uses basic defaults from model databases
GO
USE Patterns_Generalization;
GO

CREATE SCHEMA Inventory;
GO

--generic object, used to store the basics for typical searches\
CREATE TABLE Inventory.Item
(
	ItemId	int NOT NULL IDENTITY CONSTRAINT PKInventoryItem PRIMARY KEY,
	Name    varchar(30) NOT NULL CONSTRAINT AKInventoryItemName UNIQUE,
	Type    varchar(15) NOT NULL,
	Color	varchar(15) NOT NULL,
	Description varchar(100) NOT NULL,
	ApproximateValue  numeric(12,2) NULL,
	ReceiptImage   varbinary(max) NULL, --in full system, probably want 1 receipt to multiple items
	PhotographicImage varbinary(max) NULL
);

GO

--too much put into description..
INSERT INTO Inventory.Item
VALUES ('Den Couch','Furniture','Blue','Blue plaid couch, seats 4',450.00,0x001,0x001),
       ('Den Ottoman','Furniture','Blue','Blue plaid ottoman that goes with couch',  
         150.00,0x001,0x001),
       ('40 Inch Sorny TV','Electronics','Black',
        '40 Inch Sorny TV, Model R2D12, Serial Number XD49292', 800,0x001,0x001),
        ('29 Inch JQC TV','Electronics','Black','29 Inch JQC CRTVX29 TV',800,0x001,0x001),
	    ('Mom''s Pearl Necklace','Jewelery','White',
         'Appraised for $1300 in June of 2003. 30 inch necklace, was Mom''s', 1300,0x001,0x001);

GO
SELECT Name, Type, Description, ApproximateValue
FROM   Inventory.Item;

GO

--in order to make the data easier to work with (though a bit more complex to deal with)

--specific table for jewelery info
CREATE TABLE Inventory.JeweleryItem
(
	ItemId	int	CONSTRAINT PKInventoryJewleryItem PRIMARY KEY
	            CONSTRAINT FKInventoryJewleryItem$Extends$InventoryItem
				           REFERENCES Inventory.Item(ItemId),
	QualityLevel   varchar(10) NOT NULL,
	AppraiserName  varchar(100) NULL,
	AppraisalValue numeric(12,2) NULL,
	AppraisalYear  char(4) NULL

);

GO
--specific table for electronics
CREATE TABLE Inventory.ElectronicItem
(
	ItemId	int	CONSTRAINT PKInventoryElectronicItem PRIMARY KEY
	            CONSTRAINT FKInventoryElectronicItem$Extends$InventoryItem
				           REFERENCES Inventory.Item(ItemId),
	BrandName  varchar(20) NOT NULL,
	ModelNumber varchar(20) NOT NULL,
	SerialNumber varchar(20) NULL
);

GO

--make the description less specific
UPDATE Inventory.Item
SET    Description = '40 Inch TV' 
WHERE  Name = '40 Inch Sorny TV';
GO
--add more specific details for this item
INSERT INTO Inventory.ElectronicItem (ItemId, BrandName, ModelNumber, SerialNumber)
SELECT ItemId, 'Sorny','R2D12','XD49393'
FROM   Inventory.Item
WHERE  Name = '40 Inch Sorny TV';
GO

--and for the JQC tv
UPDATE Inventory.Item
SET    Description = '29 Inch TV' 
WHERE  Name = '29 Inch JQC TV';
GO
INSERT INTO Inventory.ElectronicItem(ItemId, BrandName, ModelNumber, SerialNumber)
SELECT ItemId, 'JQC','CRTVX29',NULL
FROM   Inventory.Item
WHERE  Name = '29 Inch JQC TV';
GO

--and for the Jewelry
UPDATE Inventory.Item
SET    Description = '30 Inch Pearl Neclace' 
WHERE  Name = 'Mom''s Pearl Necklace';
GO

INSERT INTO Inventory.JeweleryItem (ItemId, QualityLevel, AppraiserName, AppraisalValue,AppraisalYear )
SELECT ItemId, 'Fine','Joey Appraiser',1300,'2003'
FROM   Inventory.Item
WHERE  Name = 'Mom''s Pearl Necklace';
Go


--now we have a simple generic list
SELECT Name, Type, Description, ApproximateValue
FROM   Inventory.Item;
GO

--a specific list of electronics
SELECT Item.Name, ElectronicItem.BrandName, ElectronicItem.ModelNumber, ElectronicItem.SerialNumber,
		Item.ApproximateValue
FROM   Inventory.Item
         LEFT OUTER JOIN Inventory.ElectronicItem
				ON Item.ItemId = ElectronicItem.ItemId
WHERE  Item.Type = 'Electronics'
GO

--a specific list of electronics
SELECT Item.Name, JeweleryItem.QualityLevel, JeweleryItem.AppraiserName,
				  JeweleryItem.AppraisalValue,JeweleryItem.AppraisalYear,
		Item.ApproximateValue
FROM   Inventory.Item
         LEFT OUTER JOIN Inventory.JeweleryItem
				ON Item.ItemId = JeweleryItem.ItemId
WHERE  Item.Type = 'Jewelery'
GO

--generic list for generic needs
SELECT Name, Description, 
       CASE Type
			  WHEN 'Electronics'
				THEN 'Brand:' + COALESCE(BrandName,'_______') +
					 ' Model:' + COALESCE(ModelNumber,'________')  + 
					 ' SerialNumber:' + COALESCE(SerialNumber,'_______')
			  WHEN 'Jewelery'
					THEN 'QualityLevel:' + QualityLevel +
				 ' Appraiser:' + COALESCE(AppraiserName,'_______') +
				 ' AppraisalValue:' +COALESCE(Cast(AppraisalValue as varchar(20)),'_______')   
						 +' AppraisalYear:' + COALESCE(AppraisalYear,'____') 
  				ELSE '--No Description for ItemType---' END as ExtendedDescription
FROM   Inventory.Item --outer joins because every item will only have one of these if any
           LEFT OUTER JOIN Inventory.ElectronicItem
		ON Item.ItemId = ElectronicItem.ItemId
	   LEFT OUTER JOIN Inventory.JeweleryItem
		ON Item.ItemId = JeweleryItem.ItemId;

GO
