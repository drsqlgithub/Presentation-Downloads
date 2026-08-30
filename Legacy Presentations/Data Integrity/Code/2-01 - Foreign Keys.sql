USE HowToImplementDataIntegrity
GO
IF EXISTS ( SELECT  *
            FROM    sys.tables
            WHERE   OBJECT_ID = OBJECT_ID('Demo.InvoiceLineItem') ) 
    DROP TABLE Demo.InvoiceLineItem
go
IF EXISTS ( SELECT  *
            FROM    sys.tables
            WHERE   OBJECT_ID = OBJECT_ID('Demo.Invoice') ) 
    DROP TABLE Demo.Invoice
go
IF EXISTS ( SELECT  *
            FROM    sys.tables
            WHERE   OBJECT_ID = OBJECT_ID('Demo.Product') ) 
    DROP TABLE Demo.Product
go
IF EXISTS ( SELECT  *
            FROM    sys.tables
            WHERE   OBJECT_ID = OBJECT_ID('Demo.Customer') ) 
    DROP TABLE Demo.Customer
go

--the table structures from the slide, still with minimal columns
CREATE TABLE Demo.Customer
    (                        --if declaring column as PK, will default to NOT NULL. Not so when doing it as an alter
      CustomerNumber CHAR(5) NOT NULL CONSTRAINT PKCustomer PRIMARY KEY,
	  NAME VARCHAR(10) NOT NULL CONSTRAINT CHKCustomer$name CHECK ( LEN(NAME) > 0 )
    )

CREATE TABLE Demo.Product
    (
      ProductCode CHAR(5) NOT NULL CONSTRAINT PKProduct PRIMARY KEY ,
      Name VARCHAR(20) NOT NULL CONSTRAINT CHKProduct$name CHECK ( LEN(NAME) > 0 )
    )

CREATE TABLE Demo.Invoice
    (
      InvoiceNumber CHAR(5) NOT NULL CONSTRAINT PKInvoice PRIMARY KEY ,
      CustomerNumber CHAR(5) NOT NULL
        CONSTRAINT FKInvoice$isBilledWith$DemoInvoice REFERENCES Demo.Customer ( CustomerNumber ) ON DELETE NO ACTION
																								  ON UPDATE CASCADE
    )

CREATE TABLE Demo.InvoiceLineItem
    (
      InvoiceNumber CHAR(5) NOT NULL
        CONSTRAINT FKInvoice$contains$DemoInvoiceLineItem REFERENCES Demo.Invoice ( InvoiceNumber ) ON DELETE CASCADE
																									ON UPDATE CASCADE ,
      InvoiceLineItemNumber INT NOT NULL,
      ProductCode CHAR(5) NOT NULL
        CONSTRAINT FKProduct$isPaidForVia$DemoInvoiceLineItem REFERENCES Demo.Product ( ProductCode ) ON DELETE NO ACTION
																									  ON UPDATE CASCADE ,
      CONSTRAINT PKInvoiceLineItem PRIMARY KEY
        ( InvoiceNumber, InvoiceLineItemNumber )
    )
GO
--create some data with no dependencies
INSERT Demo.Customer
        ( CustomerNumber, Name )
VALUES  ( 'CUST1','Customer 1'),('CUST2','Customer 2')
GO
INSERT Demo.Product
        ( ProductCode, Name )
VALUES  ('PROD1', 'Bunny Slippers'),('PROD2', 'Taz Slippers'),('PROD3', 'Not Slippers')
GO 

--create invoices for the customers we created
INSERT Demo.Invoice
        ( InvoiceNumber, CustomerNumber )
VALUES  ( 'INV01', 'CUST1'),( 'INV02', 'CUST1'),( 'INV03', 'CUST2')
GO

--then line items using the invoice and products
INSERT Demo.InvoiceLineItem
        ( InvoiceNumber , InvoiceLineItemNumber , ProductCode   )
VALUES  ( 'INV01' , 1, 'PROD1'), ( 'INV01' , 2, 'PROD2'),
        ( 'INV02' , 1, 'PROD3'),
		( 'INV03' , 1, 'PROD1'), ( 'INV03', 2, 'PROD3')
GO



--See the data 
SELECT Invoice.CustomerNumber, Customer.Name, Invoice.InvoiceNumber, 
		InvoiceLineItem.InvoiceLineItemNumber, InvoiceLineItem.ProductCode,
		Product.Name
FROM   Demo.Invoice
		 JOIN Demo.InvoiceLineItem
			ON	Demo.Invoice.InvoiceNumber = Demo.InvoiceLineItem.InvoiceNumber
		 JOIN Demo.Product
			ON Demo.InvoiceLineItem.ProductCode = Demo.Product.ProductCode
		 JOIN Demo.Customer
			ON Invoice.CustomerNumber = Customer.CustomerNumber
GO

--guaranteed to match
SELECT COUNT(*)
FROM   Demo.InvoiceLineItem

SELECT COUNT(*)
FROM   Demo.InvoiceLineItem
		 JOIN Demo.Invoice	
			ON Demo.InvoiceLineItem.InvoiceNumber = Demo.Invoice.InvoiceNumber
GO 


--Update of PK with cascade, will make Invoice rows change as well. Note the rowcount
UPDATE Demo.Customer
SET		CustomerNumber = 'First'
WHERE  CustomerNumber = 'CUST1'
GO
--See the data 
SELECT Invoice.CustomerNumber, Customer.Name, Invoice.InvoiceNumber, 
		InvoiceLineItem.InvoiceLineItemNumber, InvoiceLineItem.ProductCode,
		Product.Name
FROM   Demo.Invoice
		 JOIN Demo.InvoiceLineItem
			ON	Demo.Invoice.InvoiceNumber = Demo.InvoiceLineItem.InvoiceNumber
		 JOIN Demo.Product
			ON Demo.InvoiceLineItem.ProductCode = Demo.Product.ProductCode
		 JOIN Demo.Customer
			ON Invoice.CustomerNumber = Customer.CustomerNumber
GO

--delete of invoice removes child rows due to FK
DELETE Demo.Invoice
WHERE InvoiceNumber = 'INV03'
go
SELECT Invoice.CustomerNumber, Invoice.InvoiceNumber, 
		InvoiceLineItem.InvoiceLineItemNumber, InvoiceLineItem.ProductCode,
		Product.Name
FROM   Demo.Invoice
		 JOIN Demo.InvoiceLineItem
			ON	Demo.Invoice.InvoiceNumber = Demo.InvoiceLineItem.InvoiceNumber
		 JOIN Demo.Product
			ON Demo.InvoiceLineItem.ProductCode = Demo.Product.ProductCode
GO

SELECT *
FROM   Demo.Invoice
SELECT *
FROM   Demo.InvoiceLineItem
GO