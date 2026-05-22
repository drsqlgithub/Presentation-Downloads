/*
--Bit types are weird. They call themselves an integer datatype:

"An integer data type that can take a value of 1, 0, or NULL." 
   (https://learn.microsoft.com/en-us/sql/t-sql/data-types/bit-transact-sql?view=sql-server-ver17)

But they don't act like an integer in many ways:
*/
SELECT CAST(1 AS BIT) + CAST(0 AS BIT);
/*
Also this:
*/
select cast('true' as bit), cast('false' as bit), cast(100000000 as bit), cast(-100000000 as bit)
/*


Since NULL means unknown, if you want to say "really, there is no FK relationship" you either need a "there is no row row" or:

AddressId  int NULL FK to Address.AddressId
NoAddressFlag bit NOT NULL

- If both are NULL, then you would interpret this as "We don't know the address, and we don't know if they even have an address."
- If NoAddressFlag = 1, that would mean, they don't have an address, and you can ignore the NULL value in AddressId. 
- if NoAddressFlag = 0, and AddressId is NULL, we know they have an address, but it is unknown. 
- And NoAddressFlag = 0, and AddressId non null, then we have their address.

Just annoying.

When I want to make 100% sure that someone understands that NULL/UNKNOWN and FALSE are different things, I use this example:
*/
DECLARE @NullValue INT = NULL; 

SELECT @NullValue, 
       CASE WHEN @NullValue = 1 THEN 1 ELSE 0 END,
       CASE WHEN NOT(@NullValue = 1) THEN 1 ELSE 0 END,
       CASE WHEN NOT(NOT(@NullValue = 1)) THEN 1 ELSE 0 END,
       CASE WHEN NOT(NOT(NOT(@NullValue = 1))) THEN 1 ELSE 0 END,
       CASE WHEN NOT(NOT(NOT(NOT(@NullValue = 1)))) THEN 1 ELSE 0 END;
/*
NULL conceptually represents EVERY possible value that could be stored in that column. So any value that is in the table might match, so the comparison results in UNKNOWN, which says "we are not sure, so it isn't false, but it certainly isn't true.

For every Boolean comparison operarator, there is a truth table that tells us what happens in each comparison. For example, consider the truth table for NOT.

| A     | NOT A |
|-------|-------|
| TRUE  | FALSE |
| FALSE | TRUE  |
| NULL  | NULL  |

The key here is that NOT NULL = NULL.  NULL is not FALSE, and NULL is not TRUE. NULL is UNKNOWN. So no matter how many times you NOT this comparison, it will remain UNKNOWN. I don't know if I have a value, and the opposite is still not knowing.

Where it gets wild is things like IN:
*/
Use AdventureWorks2025
GO

SELECT *
FROM   Sales.Customer
WHERE  PersonId IN  (
                    16362,
                    17360,
                    3645,
                    16488,
                    8440,
                    16300,
                    NULL
                    )
;
/*
This is the is the mathematical equivalent of:
16362 in table
OR
17360 in table
OR
...
you don't get the NULL values. But since because NULL or TRUE is true, you get the non-null values. 

What about  NOT IN
*/
SELECT *
FROM   Sales.Customer
WHERE  PersonId NOT IN 
                    (
                    16362,
                    17360,
                    3645,
                    16488,
                    8440,
                    16300,
                    NULL
                    );

--you don't get any results, even though you KNOW that 16362 is definitely in that table. The query now becomes:

And now it becomes:
NOT (PersonId = 16362)
AND
NOT (PersonId = 17360)
AND
...
AND 
NOT (PersonId = NULL)
/*
And since TRUE AND TRUE AND NULL is not TRUE, but instead UNKNOWN, no rows are returned.

Filters work on having a TRUE result. Constraints fail only on a FALSE result.

So a WHERE, HAVING, IF, CASE, ON, etc will all look for a TRUE result to determine whether to include or exclude a row or value. As we showed previously.

CHECK and FOREIGN KEY constrant fail only on FALSE. NULL is acceptable. 

Logically, it would seem that they look for rows that match their criteria. But what they are looking for are rows that explicitly don't match their criteria. And when you mix in columns that allow NULL values, the behavior can be counter-intuitive.

For example, consider these two tables, and a check constraint on CustomerName and an foreign key constraint on StatusCode (to Status table):
*/
USE Tempdb;
GO
DROP TABLE IF EXISTS Customer, Status
CREATE TABLE Status(
    StatusCode CHAR(1) NOT NULL PRIMARY KEY);

CREATE TABLE Customer
(
    CustomerId INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName VARCHAR(255) NULL
          CHECK (LEN(CustomerName) > 3),
    StatusCode CHAR(1) NULL 
          REFERENCES Status (StatusCode)
);
INSERT INTO Status(StatusCode) VALUES ('A'), ('B'), ('C');
/*
If you try to insert a row with a NULL StatusCode and/or CustomerName, you might expect them to fail, but they succeed:
*/
INSERT Customer(CustomerName, StatusCode)
VALUES (NULL,NULL);
INSERT INTO Customer(CustomerName, StatusCode)
VALUES (NULL,'C');
INSERT INTO Customer(CustomerName, StatusCode)
VALUES ('Robin',NULL);
/*

Even though CustomerName is not > 3 in length, nor is StatusCode in the referenced table. This is because in both cases, the expression evaluates to NULL, and a constraint is satisfied if the expression is not FALSE. Since NULL is neither TRUE nor FALSE, the constraint passes. Then the NULL constraint on the column takes over. In a single column constraint, this makes some sense. But when there is more than one column, it starts to get confusing. 

Now it gets weird.
*/

DELETE FROM Customer;

ALTER TABLE Customer 
ADD CONSTRAINT CK_Customer_NameAndStatus 
CHECK (CustomerName = 'Barney' AND StatusCode = 'B');
/*
This statement works:
*/
INSERT INTO Customer(CustomerName, StatusCode)
VALUES ('Barney', 'B');
/*
And these all fail:
*/
INSERT INTO Customer(CustomerName, StatusCode)
VALUES ('Barney', 'C');
INSERT INTO Customer(CustomerName, StatusCode)
VALUES ('Leonard', 'B');
INSERT INTO Customer(CustomerName, StatusCode)
VALUES ('Leonard', 'C');
/*
But: these works: what about these?
*/
INSERT Customer(CustomerName, StatusCode)
VALUES (NULL,NULL);
/*
What about this?
*/
INSERT INTO Customer(CustomerName, StatusCode)
VALUES (NULL,'C');
/*
Fails? But why? In a sec...

And this?
*/
INSERT INTO Customer(CustomerName, StatusCode)
VALUES ('Barney', NULL);

This succeeds. 
/*
Why? Back to the truth tables. When we have:

'Barney' = 'Barney' AND NULL = 'B'

The first part evaluates to true, the second part evaluates to NULL, and TRUE AND NULL = NULL, which satisfies the constraint because it is not explicitly FALSE. But when we had

NULL = 'Barney' AND 'C' = 'B'

The first part evaluates to NULL, the second part evaluates to FALSE, and NULL AND FALSE = FALSE, which violates the constraint.

> This is why I always understand why people have issues with NULLs. It can get nuts.


Now say you have the following table with a complex key:*/
CREATE TABLE Domain
(
    DomainKey1 int NOT NULL,
    DomainKey2 int NOT NULL,
    CONSTRAINT PK_Domain PRIMARY KEY (DomainKey1, DomainKey2)
);
insert into domain values (1, 1), (2, 2);
GO
CREATE TABLE DomainReference
(
    DomainKey1 int NULL,
    DomainKey2 int NULL,
    CONSTRAINT FK_DomainReference_Domain FOREIGN KEY (DomainKey1, DomainKey2) REFERENCES Domain(DomainKey1, DomainKey2)
);
GO

/*
It should be clear that this will succeed:
*/

INSERT INTO DomainReference(DomainKey1, DomainKey2)
VALUES (1, 1);

/*
And this:
*/


INSERT INTO DomainReference(DomainKey1, DomainKey2)
VALUES (NULL, NULL);

/*
But, what about partial references?
*/


INSERT INTO DomainReference(DomainKey1, DomainKey2)
VALUES (1, NULL);

INSERT INTO DomainReference(DomainKey1, DomainKey2)
VALUES (NULL, 1);

/*
Both worked. But what about this:
*/


INSERT INTO DomainReference(DomainKey1, DomainKey2)
VALUES (99, NULL);

INSERT INTO DomainReference(DomainKey1, DomainKey2)
VALUES (NULL, 99);

/*
These too worked. Why? Because the composite foreign key constraint allows for partial matches when one of the key columns is NULL. This feels like it disagrees with the previous example, but in this case, the reference is considered as a whole, and any NULL values in the foreign key means that the row do not participate in the referential integrity check. 

But yet:
*/
INSERT INTO DomainReference(DomainKey1, DomainKey2)
VALUES (99, 99);

/*
Msg 547, Level 16, State 0, Line 254
The INSERT statement conflicted with the FOREIGN KEY constraint "FK_DomainReference_Domain". The conflict occurred in database "tempdb", table "dbo.Domain".
The statement has been terminated.
*/

If you want to control this, you will need to use a CHECK constraint that says:

DELETE FROM dbo.DomainReference;

ALTER TABLE dbo.DomainReference
ADD CHECK ((DomainKey1 IS NULL AND DomainKey2 IS NULL) OR (DomainKey1 IS NOT NULL AND DomainKey2 IS NOT NULL));

*/
