USE TempDB;
GO
/*
Set from the slides. Using these simple rows to show things that we can also 
visualize in the set. There are examples using AdventureWorks2025 which you can
find here: https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure
*/

CREATE TABLE [Set] --Reserved Word, but I felt it fit the demo best. (and shows one more technique.
                   --what happens when you accidentally name something a Reserved keyword.
(
    SetId INT PRIMARY KEY,
    GroupingId INT,
    Value INT --Note the color, this is a keyword, but it is not reserved, so it can be used.
);

INSERT INTO [dbo].[Set]
(
    SetId,
    GroupingId,
    Value
)
VALUES
(1, 1, 10),
(2, 1, 20),
(3, 2, 30),
(4, 2, 40),
(5, 2, 50),
(6, 2, 60),
(7, 3, 70),
(8, 3, 80),
(9, 4, 90);
GO	
/*
show the data
*/
SELECT SetId,
       GroupingId,
       Value
FROM   [Set]


/*
Group by queries
*/
--simple/typical case 
SELECT GroupingId,
       MAX(SetId) AS MaxSetId,
       MAX(Value) AS MaxValue
FROM   [Set]
GROUP  BY GroupingId;

--full table with no group or where
SELECT MAX(Value) AS MaxValue
FROM   [Set];

--full table with group or where
SELECT MIN(Value) AS MinValue,
       MAX(Value) AS MaxValue
FROM   [Set]
WHERE  GroupingId IN (1,2);


--forcing the set to be less likely ordered. Order is NOT guaranteed
--in any case if the last statement does not include an ORDER BY;

WITH BaseRows AS --my default CTE name, when it is just a natural part of the query
                 --Always use better names if it is not clear
(
    SELECT TOP 100 *
    FROM   [Set]
    ORDER BY NEWID() --this just gets the top rows by NEWID() (but we have < 100 rows, so all)
)
SELECT GroupingId, 
       STRING_AGG(Value,',')
FROM   BaseRows
GROUP  BY GroupingId;


--now with a sorted aggregate, 
WITH BaseRows AS 
(
    SELECT TOP 100 *
    FROM   [Set]
    ORDER BY NEWID()
)

SELECT GroupingId, 
       STRING_AGG(Value,','), 
       STRING_AGG(Value,',') WITHIN GROUP (ORDER BY Value) AS ValueCommaList
FROM   BaseRows
GROUP  BY GroupingId;


/*
Rollups - totals, subtotals, and more.
*/

--rollup on group, nulls mean a total
SELECT GroupingId,
       MAX(SetId) AS MaxSetId,
       MAX(Value) AS MaxValue
FROM   [Set]
GROUP  BY ROLLUP(GroupingId);


--grouping function to add context to NULL values
SELECT GroupingId,
       MAX(SetId) AS MaxSetId,
       MAX(Value) AS MaxValue,
       CASE WHEN GROUPING(GroupingId) = 1 THEN '--All Rows--' ELSE '' END AS Header
FROM   [Set]
GROUP  BY ROLLUP(GroupingId);


--multipl level gorup by, showing how GROUPING feels backwards at first
SELECT GroupingId,
       SetId,
       SUM(Value) AS SumValue,
       CASE WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 0 THEN 'Grouping Total' 
            --this can be confusing. Look at the output
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 1 THEN 'Set Total' 
            WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 1 THEN '--Grand Total--' 
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 0 THEN 'Detail Row' 
            END AS Header
FROM   [Set]
GROUP  BY ROLLUP(GroupingId, SetId);

/*/
GroupingId  SetId       SumValue    Header
----------- ----------- ----------- ---------------
1           1           10          Detail Row
1           2           20          Detail Row

This GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 0 THEN 'Grouping Total' 
Says that the NULL in SetId is caused because it is being grouped by
the value in Grouping Id.

1           NULL        30          Grouping Total
2           3           30          Detail Row
2           4           40          Detail Row
2           5           50          Detail Row
2           6           60          Detail Row
2           NULL        180         Grouping Total
3           7           70          Detail Row
3           8           80          Detail Row
3           NULL        150         Grouping Total
4           9           90          Detail Row
4           NULL        90          Grouping Total
NULL        NULL        450         --Grand Total--
*/

--CUBE is far less typical, but it can be good for analyzing data
SELECT GroupingId,
       SetId,
       SUM(Value) AS SumValue,
       CASE WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 0 THEN 'Grouping Total' 
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 1 THEN 'Set Total' 
            WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 1 THEN '--Grand Total--' 
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 0 THEN 'Detail Row' 
            END AS Header
FROM   [Set]
GROUP  BY ROLLUP(SetId, GroupingId);

/*
Grouping sets are kind of bring your own adventure example:
*/

--basically the same as a rollup, specifying each level manually.
SELECT GroupingId,
       SetId,
       SUM(Value) AS SumValue,
       CASE WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 0 THEN 'Grouping Total' 
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 1 THEN 'Set Total' 
            WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 1 THEN '--Grand Total--' 
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 0 THEN 'Detail Row' 
            END AS Header
FROM   [Set]
GROUP  BY GROUPING SETS ((GroupingId),(GroupingId,SetId),())


--no grand total from the () now
SELECT GroupingId,
       SetId,
       SUM(Value) AS SumValue,
       CASE WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 0 THEN 'Grouping Total' 
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 1 THEN 'Set Total' 
            WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 1 THEN '--Grand Total--' 
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 0 THEN 'Detail Row' 
            END AS Header
FROM   [Set]
GROUP  BY GROUPING SETS ((GroupingId),(GroupingId,SetId))

--duplicating levels in the GROUPING SETS
SELECT GroupingId,
       SetId,
       SUM(Value) AS SumValue,
       CASE WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 0 THEN 'Grouping Total' 
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 1 THEN 'Set Total' 
            WHEN GROUPING(SetId) = 1 AND GROUPING(GroupingId) = 1 THEN '--Grand Total--' 
            WHEN GROUPING(SetId) = 0 AND GROUPING(GroupingId) = 0 THEN 'Detail Row' 
            END AS Header
FROM   [Set]
GROUP  BY GROUPING SETS ((GroupingId),(GroupingId,SetId),(),
                         (GroupingId),(GroupingId,SetId),()); --yeah, you CAN repeat them!


/*
Something a bit larger/more interesting (but harder to follow when trying to figure things out!
*/

USE AdventureWorksDW2025;
GO

--get all sales, the totall number of orders (fact tables often at item grain for sales, 
--largely fro products
SELECT SUM(SalesAmount) AS SalesTotal, COUNT(DISTINCT SalesOrderNumber) AS SalesCount,
       COUNT(*) AS SalesItemCount
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey;

--Now add layers of grouping
SELECT ProductLine, CalendarYear, SUM(SalesAmount) AS SalesTotal, COUNT(DISTINCT SalesOrderNumber) AS SalesCount,
       COUNT(*) AS SalesItemCount
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY ProductLine, CalendarYear


--now with rollup for the two dimensions
SELECT ProductLine, CalendarYear, 
       CASE WHEN GROUPING(ProductLine) = 1 AND GROUPING(CalendarYear) = 0 THEN 'CalendarYear Total' 
            WHEN GROUPING(ProductLine) = 0 AND GROUPING(CalendarYear) = 1 THEN 'ProductLine Total' 
            WHEN GROUPING(ProductLine) = 1 AND GROUPING(CalendarYear) = 1 THEN '--Grand Total--' 
            WHEN GROUPING(ProductLine) = 0 AND GROUPING(CalendarYear) = 0 THEN 'Detail Row' 
            END AS Header,

SUM(SalesAmount) AS SalesTotal, COUNT(DISTINCT SalesOrderNumber) AS SalesCount,
       COUNT(*) AS SalesItemCount
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY ROLLUP(ProductLine, CalendarYear)



--note, you can't use the following GROUPING SETS:
SELECT ProductLine, CalendarYear, 
       CASE WHEN GROUPING(ProductLine) = 1 AND GROUPING(CalendarYear) = 0 THEN 'CalendarYear Total' 
            WHEN GROUPING(ProductLine) = 0 AND GROUPING(CalendarYear) = 1 THEN 'ProductLine Total' 
            WHEN GROUPING(ProductLine) = 1 AND GROUPING(CalendarYear) = 1 THEN '--Grand Total--' 
            WHEN GROUPING(ProductLine) = 0 AND GROUPING(CalendarYear) = 0 THEN 'Detail Row' 
            END AS Header,

SUM(SalesAmount) AS SalesTotal, COUNT(DISTINCT SalesOrderNumber) AS SalesCount,
       COUNT(*) AS SalesItemCount
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY GROUPING SETS((ProductLine),())

--Every column that isn't in an aggregate must show up in the GROUP BY So you can do any of these:
SELECT ProductLine, CalendarYear, 
       CASE WHEN GROUPING(ProductLine) = 1 AND GROUPING(CalendarYear) = 0 THEN 'CalendarYear Total' 
            WHEN GROUPING(ProductLine) = 0 AND GROUPING(CalendarYear) = 1 THEN 'ProductLine Total' 
            WHEN GROUPING(ProductLine) = 1 AND GROUPING(CalendarYear) = 1 THEN '--Grand Total--' 
            WHEN GROUPING(ProductLine) = 0 AND GROUPING(CalendarYear) = 0 THEN 'Detail Row' 
            END AS Header,

SUM(SalesAmount) AS SalesTotal, COUNT(DISTINCT SalesOrderNumber) AS SalesCount,
       COUNT(*) AS SalesItemCount
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
--GROUP BY GROUPING SETS((ProductLine),(CalendarYear))
--GROUP BY GROUPING SETS((CalendarYear),(ProductLine))
--GROUP BY GROUPING SETS((CalendarYear,ProductLine))
GROUP BY GROUPING SETS((CalendarYear,ProductLine),())

--As long as those two columns appear