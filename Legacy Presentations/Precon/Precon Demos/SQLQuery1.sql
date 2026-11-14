drop VIEW sales.customerClassification
drop table sales.customer
drop schema sales

go

CREATE SCHEMA sales
go
CREATE TABLE sales.customer
(
	customerNumber	char(5) constraint PKsalesCustomer PRIMARY KEY,
	firstName       varchar(30),
	lastName        varchar(30)
)
go
INSERT INTO sales.customer(customerNumber,firstName,lastName)
VALUES ('00001','Beeg','Speender'),('00002','Lotso','Spendingbear'),
       ('00003','Po','Urr'),('00004','Owen','Lott')
GO
SELECT *
FROM   sales.customer
GO
--make customer '00001' "special".  This value is used in workflow code in order
--to automatically give this customer special treatment.

SELECT customerNumber, firstName, lastName,
	   CASE WHEN customerNumber IN ('00001') THEN 'Special'  
	        ELSE 'Normal' END as customerType
FROM   sales.customer
GO
/*
customerNumber firstName   LastName         CustomerType
-------------- ----------- ---------------- ------------
00001          Beeg        Speender         Special
00002          Lotso       Spendingbear     Normal
00003          Po          Urr              Normal
00004          Owen        Lott             Normal
*/
--So done right? Well, what if you need to use this in a report? Do you recode?
--Next, you think, well, how about making it a view... (note, we don't name it
--view...

CREATE VIEW sales.customerClassification
AS
SELECT customerNumber, 
	   CASE WHEN customerNumber IN ('00001') THEN 'Special'  
	        ELSE 'Normal' END as customerType
FROM   sales.customer
GO

--Then you just join to the view
SELECT customer.customerNumber, customer.firstName, customer.LastName, customerClassification.customerType
FROM   sales.customer
		  join sales.customerClassification
			 ON customer.customerNumber = customerClassification.customerNumber

Go

--You then test the heck out of your code and implement in production.

--it is at this point, you get the request to add a new person to the special group. Clearly 
--mr lotso spendingbear is loaded too, so we want to treat him special also.

ALTER VIEW sales.customerClassification
AS
SELECT customerNumber, 
	   CASE WHEN customerNumber IN ('00001','00002') THEN 'Special'  
	        ELSE 'Normal' END as customerType
FROM   sales.customer
GO

--Then you just join to the view
SELECT customer.customerNumber, customer.firstName, customer.LastName, customerClassification.customerType
FROM   sales.customer
		  join sales.customerClassification
			 ON customer.customerNumber = customerClassification.customerNumber

Go

--But this is clearly no the "best" way to implement settings such as this, but all too often you see code
--like this because the developer takes the "easy" way out. The problem with this solution is that you have
--to modify code for every change in status for a customer. So just adding a new special customer would (or
--at least should) require testing and a production rollout of code... In other words, programmer intervention.

--And as your needs grow, dealing with configurations like this gets more and more complicated.
--For example, you may want to have additional types of customers, and subclasses of customers
--and each group might need to be treated specially.  So instead, implement something like:


CREATE TABLE sales.customerType
 (
	customerTypeCode	varchar(30) CONSTRAINT PKsales_customerType PRIMARY KEY,
	description         varchar(200)
)
GO
INSERT INTO sales.customerType(customerTypeCode,description)
VALUES ('Normal','Basic customers with no special handling'),
       ('Special','Customers that require special handling')
GO

ALTER TABLE sales.customer 
	ADD customerTypeCode varchar(30) NOT NULL 
	                  CONSTRAINT DFLTsales_customer_customerTypecode DEFAULT ('Normal')
GO
ALTER TABLE sales.customer
    ADD CONSTRAINT FKsales_customer$isCategorizedBy$sales_customerType FOREIGN KEY
	             (customerTypecode) REFERENCES sales.customerType (customerTypeCode)
GO
UPDATE sales.customer
SET    customerTypeCode = 'Special'
WHERE  customerNumber in ('00001','00002')
GO

SELECT *
FROM   sales.customer

--so okay, now you say, we just basically have the same set of data as before. The true value of this
--design is that say we want to implement a setting where we want to send a welcome message to customers.
--instead of coding some code based on CustomerType, we add a column to the customerType table

ALTER TABLE sales.customerType
	ADD welcomeLetterType varchar(30) NOT NULL 
	                  CONSTRAINT DFLTsales_customerType_welcomeLetterType DEFAULT ('None')
GO
UPDATE sales.customerType
SET    welcomeLetterType = 'Simple'
WHERE  customerTypeCode = 'Normal'
GO
UPDATE sales.customerType
SET    welcomeLetterType = 'Expanded'
WHERE  customerTypeCode = 'Special'
GO

SELECT customer.customerNumber, customerType.customerTypeCode, customerType.welcomeLetterType
FROM   sales.customer
		 JOIN sales.customerType
			ON customer.customerTypeCode = customerType.customerTypeCode

GO

customerNumber customerTypeCode               welcomeLetterType
-------------- ------------------------------ ------------------------------
00001          Special                        Expanded
00002          Special                        Expanded
00003          Normal                         Simple
00004          Normal                         Simple


--And so on. In the end, the goal is that you can program to these values, and adding a new
--customerTypeCode that needs an expanded or simple welecome letter is now no code.  And if you
--distill all of the typical treatments for customers down to simple setting values, the only time
--you have to change and test the code you have written is when you add a new type of treatment.

