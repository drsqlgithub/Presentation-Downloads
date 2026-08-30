Use SequenceDemos;
GO
set nocount on 

--reset objects for demo
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.InvoiceLineItem'))
		DROP TABLE Demo.InvoiceLineItem;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.Invoice'))
		DROP TABLE Demo.Invoice;

IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.Invoice_SEQUENCE'))
		DROP SEQUENCE Demo.Invoice_SEQUENCE;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.InvoiceLineItem_SEQUENCE'))
		DROP SEQUENCE Demo.InvoiceLineItem_SEQUENCE;
GO

--Using an Identity
CREATE TABLE Demo.Invoice
(
	InvoiceId	INT	NOT NULL IDENTITY(1,1) PRIMARY KEY,
	InvoiceNumber char(10) NOT NULL UNIQUE
);
--Using an Identity
CREATE TABLE Demo.InvoiceLineItem
(
	InvoiceLineItemId INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
	InvoiceId	INT	NOT NULL,
	InvoiceLineItemNumber INT NOT NULL,
	Quantity INT NOT NULL,
	Price    Numeric(10,2) NOT NULL,
	UNIQUE (InvoiceId, InvoiceLineItemNumber),
	FOREIGN KEY (InvoiceId) REFERENCES Demo.Invoice (InvoiceId)
);
GO

--the always safe method... get the new value based on alternate key
INSERT INTO Demo.Invoice(InvoiceNumber)
VALUES ('0000000001')

DECLARE @newValue int = (SELECT InvoiceId
						from   Demo.Invoice
						where  InvoiceNumber = '0000000001')
SELECT @newvalue as NewInvoiceNumber

INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 1,10,100.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 2,20,200.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 3,30,300.00)
GO

SELECT *
FROM   Demo.Invoice
ORDER BY InvoiceNumber
SELECT *
FROM   Demo.InvoiceLineItem
ORDER BY InvoiceId, InvoiceLineItemNumber
GO



--the classic method
INSERT INTO Demo.Invoice(InvoiceNumber)
VALUES ('0000000002')

DECLARE @newvalue int = scope_identity() 
SELECT @newvalue as NewInvoiceNumber

INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 1,10,100.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 2,20,200.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 3,30,300.00)
GO

SELECT *
FROM   Demo.Invoice
ORDER BY InvoiceNumber
SELECT *
FROM   Demo.InvoiceLineItem
ORDER BY InvoiceId, InvoiceLineItemNumber
GO

--the Output Method
declare @newvalueHolder table (newvalue int)

INSERT INTO Demo.Invoice(InvoiceNumber)
OUTPUT inserted.InvoiceId into @newvalueHolder
VALUES ('0000000003')

declare @newvalue int
set @newvalue = (select newvalue from @newvalueHolder)

INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 1,10,100.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 2,20,200.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 3,30,300.00)
GO

SELECT *
FROM   Demo.Invoice
ORDER BY InvoiceNumber
SELECT *
FROM   Demo.InvoiceLineItem
ORDER BY InvoiceId, InvoiceLineItemNumber
GO


----------------------------------------------------------
-- now sequences

Use SequenceDemos;
GO
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.InvoiceLineItem'))
		DROP TABLE Demo.InvoiceLineItem;
IF EXISTS (SELECT * FROM sys.tables where object_id = OBJECT_ID('Demo.Invoice'))
		DROP TABLE Demo.Invoice;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.Invoice_SEQUENCE'))
		DROP SEQUENCE Demo.Invoice_SEQUENCE;
IF EXISTS (SELECT * FROM sys.sequences where object_id = OBJECT_ID('Demo.InvoiceLineItem_SEQUENCE'))
		DROP SEQUENCE Demo.InvoiceLineItem_SEQUENCE;
GO

--simple/typical case
CREATE SEQUENCE Demo.Invoice_SEQUENCE
AS INT
START WITH 1
GO
CREATE SEQUENCE Demo.InvoiceLineItem_SEQUENCE
AS INT
START WITH 1
GO

--Using a sequence
CREATE TABLE Demo.Invoice
(
	InvoiceId	INT	NOT NULL PRIMARY KEY DEFAULT (NEXT VALUE FOR Demo.Invoice_SEQUENCE),
	InvoiceNumber char(10) NOT NULL UNIQUE
)
--Using a sequence
CREATE TABLE Demo.InvoiceLineItem
(
	InvoiceLineItemId INT NOT NULL PRIMARY KEY  DEFAULT (NEXT VALUE FOR Demo.InvoiceLineItem_SEQUENCE),
	InvoiceId	INT	NOT NULL,
	InvoiceLineItemNumber INT NOT NULL,
	Quantity INT NOT NULL,
	Price    Numeric(10,2) NOT NULL,
	UNIQUE (InvoiceId, InvoiceLineItemNumber)
	--oops, no foreign key, why? Hold on!
)
GO

--safe method
INSERT INTO Demo.Invoice(InvoiceNumber)
VALUES ('0000000001')

DECLARE @newValue int = (SELECT InvoiceId
						from   Demo.Invoice
						where  InvoiceNumber = '0000000001')
SELECT @newValue as NewInvoiceId

INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 1,10,100.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 2,20,200.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 3,30,300.00)
GO

SELECT *
FROM   Demo.Invoice
SELECT *
FROM   Demo.InvoiceLineItem
GO



DECLARE @newValue int = (NEXT VALUE FOR Demo.Invoice_SEQUENCE)
SELECT @newValue as NewInvoiceId

INSERT INTO Demo.Invoice(InvoiceId, InvoiceNumber)
VALUES (@newValue, '0000000002')

INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 1,10,100.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 2,20,200.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 3,30,300.00)
GO

SELECT *
FROM   Demo.Invoice
SELECT *
FROM   Demo.InvoiceLineItem
GO


--trying the same value again
DECLARE @newValue int = (NEXT VALUE FOR Demo.Invoice_SEQUENCE)
SELECT @newValue as NewInvoiceId

--same method as previously
INSERT INTO Demo.Invoice(InvoiceId, InvoiceNumber)
VALUES (@newValue, '0000000002')

INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 1,10,100.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 2,20,200.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 3,30,300.00)
GO

SELECT *
FROM   Demo.Invoice;
SELECT *
FROM   Demo.InvoiceLineItem;
GO

--do the delete invalid data dance
delete from  Demo.InvoiceLineItem
where  not exists ( select * 
					from Demo.Invoice 
					where InvoiceLineItem.InvoiceId = Invoice.InvoiceId);
GO


SELECT *
FROM   Demo.Invoice
SELECT *
FROM   Demo.InvoiceLineItem
GO

--protection!
ALTER TABLE Demo.InvoiceLineItem
	ADD FOREIGN KEY (InvoiceId) REFERENCES Demo.Invoice (InvoiceId)
GO

--trying the same value again
DECLARE @newValue int = (NEXT VALUE FOR Demo.Invoice_SEQUENCE)
SELECT @newValue as NewInvoiceId

--same method as previously
INSERT INTO Demo.Invoice(InvoiceId, InvoiceNumber)
VALUES (@newValue, '0000000002')

INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 1,10,100.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 2,20,200.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 3,30,300.00)
GO

SELECT *
FROM   Demo.Invoice;
SELECT *
FROM   Demo.InvoiceLineItem;
GO

--the Output Method
declare @newvalueHolder table (newvalue int)

INSERT INTO Demo.Invoice(InvoiceNumber)
OUTPUT inserted.InvoiceId into @newvalueHolder
VALUES ('0000000003')

declare @newvalue int
set @newvalue = (select newvalue from @newvalueHolder)

INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 1,10,100.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 2,20,200.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 3,30,300.00)
GO

SELECT *
FROM   Demo.Invoice
ORDER BY InvoiceNumber
SELECT *
FROM   Demo.InvoiceLineItem
ORDER BY InvoiceId, InvoiceLineItemNumber
GO

--prefetch method
DECLARE @newValue int = (NEXT VALUE FOR Demo.Invoice_SEQUENCE)
SELECT @newValue as NewInvoiceId

--same method as previously
INSERT INTO Demo.Invoice(InvoiceId, InvoiceNumber)
VALUES (@newValue, '0000000004')

INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 1,10,100.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 2,20,200.00)
INSERT INTO Demo.InvoiceLineItem(InvoiceId, InvoiceLineItemNumber,Quantity,Price)
VALUES (@newvalue, 3,30,300.00)
GO

SELECT *
FROM   Demo.Invoice
SELECT *
FROM   Demo.InvoiceLineItem
GO
