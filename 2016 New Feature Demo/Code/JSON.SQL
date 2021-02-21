--WITHOUT_ARRAY_WRAPPER

-- So more reading on the subject is here
-- https://docs.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server 

USE WideWorldImporters -- Latest demo db from Microsoft https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0 
GO

--NOTE: WHERE  Invoices.InvoiceID IN (9443,34025) chose because they have > 1 sub item

SELECT Invoices.InvoiceID, Invoices.InvoiceDate, Invoices.DeliveryMethodID, Invoices.DeliveryInstructions
	   ,InvoiceLines.StockItemID AS [InvoiceLine.StockItemId], InvoiceLines.Quantity AS [InvoiceLine.Quantity]
FROM   Sales.Invoices
         JOIN Sales.InvoiceLines
            ON InvoiceLines.InvoiceID = Invoices.InvoiceID
WHERE  Invoices.InvoiceID IN (9443,34025)
ORDER BY InvoiceId

--very basic AUTO
SELECT Invoices.InvoiceID, Invoices.InvoiceDate, Invoices.DeliveryMethodID, Invoices.DeliveryInstructions
FROM   Sales.Invoices
WHERE  Invoices.InvoiceID IN (9443,34025)
FOR    JSON AUTO;

--no square brackets
SELECT Invoices.InvoiceID, Invoices.InvoiceDate, Invoices.DeliveryMethodID, Invoices.DeliveryInstructions
FROM   Sales.Invoices
WHERE  Invoices.InvoiceID IN (9443,34025)
FOR    JSON AUTO, WITHOUT_ARRAY_WRAPPER;

--adding root 
SELECT Invoices.InvoiceID, Invoices.InvoiceDate, Invoices.DeliveryMethodID, Invoices.DeliveryInstructions
FROM   Sales.Invoices
WHERE  Invoices.InvoiceID IN (9443,34025)
FOR    JSON PATH, ROOT ('Invoices');

--making delivery a node with method and instructons
SELECT TOP 2 Invoices.InvoiceID, Invoices.InvoiceDate, 
			Invoices.DeliveryMethodID AS [Delivery.Method], 
			Invoices.DeliveryInstructions AS [Delivery.Instructions]
FROM   Sales.Invoices
WHERE  Invoices.InvoiceID IN (9443,34025)
FOR    JSON PATH, ROOT ('Invoices');

--Show joins, nested multiple items
SELECT Invoices.InvoiceID, Invoices.InvoiceDate, InvoiceLines.StockItemID AS [InvoiceLine.StockItemId], InvoiceLines.Quantity AS [InvoiceLine.Quantity]
FROM   Sales.Invoices
         JOIN Sales.InvoiceLines
            ON InvoiceLines.InvoiceID = Invoices.InvoiceID
WHERE  Invoices.InvoiceID IN (9443,34025)
ORDER BY InvoiceId
FOR    JSON AUTO

----Show joins, nested items, without sorting 
SELECT Invoices.InvoiceID, Invoices.InvoiceDate, InvoiceLines.StockItemID, InvoiceLines.Quantity
FROM   Sales.Invoices
         JOIN Sales.InvoiceLines
            ON InvoiceLines.InvoiceID = Invoices.InvoiceID
WHERE  Invoices.InvoiceID IN (9443,34025)
ORDER BY NEWID()
FOR    JSON AUTO


--Show joins, nested multiple items, using basically the same structure...
SELECT Invoices.InvoiceID, Invoices.InvoiceDate, 
		InvoiceLines.StockItemID AS [InvoiceLines.StockItemId], InvoiceLines.Quantity AS [InvoiceLines.Quantity]
FROM   Sales.Invoices
         JOIN Sales.InvoiceLines
            ON InvoiceLines.InvoiceID = Invoices.InvoiceID
WHERE  Invoices.InvoiceID IN (9443,34025)
ORDER BY InvoiceId
FOR    JSON PATH, ROOT ('Invoices');


--You have to be very deliberate about your query structure (this can be REALLY complex stuff to write!)
SELECT Invoices.InvoiceID, Invoices.InvoiceDate, 
        (SELECT InvoiceLines.StockItemID, InvoiceLines.Quantity 
         FROM  Sales.InvoiceLines
         WHERE InvoiceLines.InvoiceID = Invoices.InvoiceID
         FOR JSON PATH) AS InvoiceLines
FROM   Sales.Invoices
WHERE  Invoices.InvoiceID IN (9443,34025)
ORDER BY InvoiceId
FOR    JSON PATH, ROOT ('Invoices');


-- https://docs.microsoft.com/en-us/sql/relational-databases/json/convert-json-data-to-rows-and-columns-with-openjson-sql-SERVER

--Reading JSON
DECLARE @json NVARCHAR(MAX)

SET @json=N'{
	"Invoices": [{
		"InvoiceID": 9443,
		"InvoiceDate": "2013-07-01",
		"Delivery": {
			"Method": 3,
			"Instructions": "Shop 29, 934 Borgen Street"
		}
	},
	{
		"InvoiceID": 34025,
		"InvoiceDate": "2014-10-04",
		"Delivery": {
			"Method": 3,
			"Instructions": "Unit 248, 226 Auzina Lane"
		}
	}]
}}';

SELECT *
FROM OPENJSON(@json,'$.Invoices') --Subject (can be layered)
WITH ( InvoiceID INT '$.InvoiceID', --The item in the hierarch
       InvoiceDate DATE '$.InvoiceDate',
       DeliveryMethod INT '$.Delivery.Method',
       DeliveryInstructions VARCHAR(30) '$.Delivery.Instructions')


--NOT Covered: 
        --More complex JSON document importing;
        --JSON_VALUE --pick a value out of a JSON value
        --JSON_QUERY query a JSON doc
        --JSON_MODIFY to update the value of a property in a JSON string


