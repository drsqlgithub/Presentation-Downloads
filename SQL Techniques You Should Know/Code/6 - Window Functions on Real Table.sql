USE AdventureWorksDW2025
GO

/*
Stupid, useful, and other techniques with window functions
*/
--Present--

--Okay hotshot, what will these queries do?

SELECT COUNT(*), COUNT(*) OVER () --the window here just included the row being returned
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey;

SELECT COUNT(*) OVER () --the window here is all rows, repeated over all rows
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey;
            



/*
The output demonstrates what you get with a window function for () with and without other rows.
*/



 /*
 Using Window Functions of Aggregates... gets a bit messy, but very powerful too.
 */
 --Present--
--sales by product and year
SELECT ProductAlternateKey, CalendarYear, SUM(SalesAmount)
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY ProductAlternateKey, DimDate.CalendarYear
ORDER BY calendarYear, ProductAlternateKey, SUM(SalesAmount) DESC;

--so what if we want to compare sales of this product for the year to the total for all sales?

/*
Thing is, this seems like it should work...
*/

--sales by prodct, calendar year, compared to sales for all time
SELECT ProductAlternateKey, CalendarYear, SUM(SalesAmount), SUM(SalesAmount) OVER (),
       SUM(SalesAmount) OVER (PARTITION BY ProductAlternateKey)
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY ProductAlternateKey, DimDate.CalendarYear;

/*
But it doesn't:

Msg 8120, Level 16, State 1, Line 45
Column 'dbo.FactInternetSales.SalesAmount' is invalid in the select list because it is not contained in either an aggregate function or the GROUP BY clause.

This is because the window functions can now only access the columns: ProductAlternateKey, CalendarYear, and then the non-grouped by columns as a set you can aggregate. You can access all of aggregated data using an windowed aggregate of the non-windowed aggregate.

Now I chnage it to aggregate at the window level and then aggregate at the partition level
*/
--Present--
--sales by prodct, calendar year, compared to sales for all time, and by only product
SELECT ProductAlternateKey,
       CalendarYear,
       SUM(SalesAmount) AS ProductYearlySales,
       
       --Summing all the sales amount for all the data
       SUM(SUM(SalesAmount)) OVER (PARTITION BY ProductAlternateKey) AS TotalSalesAllTimeForProduct,

       --Summing all the sales amount for all the data
       SUM(SUM(SalesAmount)) OVER () AS TotalSalesAllTime

FROM dbo.FactInternetSales
    JOIN dbo.DimDate
        ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
    JOIN dbo.DimProduct
        ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY ProductAlternateKey,
         DimDate.CalendarYear
ORDER BY ProductAlternateKey,
         DimDate.CalendarYear;
/*
But the window for the output becomes:

ProductAlternateKey       CalendarYear Aggregates -> ProductYearlySales   
------------------------- ------------               ---------------------
BC-M005                   2012                       109.89               
BC-M005                   2013                       19420.56           

Now you can use a window function like this:

       SUM(SUM(SalesAmount)) OVER (PARTITION BY ProductAlternateKey) AS TotalSalesAllTimeForProduct,

To convert make the table that has all of the products, like if we gat all of the BC-M005 rows

ProductAlternateKey       CalendarYear 
------------------------- ------------ ---------------------
BC-M005                   2012         109.89
BC-M005                   2013         19420.56
BC-M005                   2014         699.30


And we get a value that is repeated:

TotalSalesAllTimeForProduct
---------------------------
20229.75                   

And the other window is all SUM(SalesAmounts):

SUM(SUM(SalesAmount)) OVER () AS TotalSalesAllTime

Which gets us all sales (which is why sometimes you may need more rows to start with, and then filter them out, like in a CTE.)
*/

/*
Clear? If you are like me, you are a bit confused...and if this is the first time you have seen this, you are a LOT confused. I had to as AI for the syntax here multiple times (and sometimes to ask "what does this do?".

BIG KEY: You probably will use some tool to generate this code at times. You NEED to be able to visualize what is happening and work through whether or not your results are correct.

The key is you can access any agregates or key values in a window. Which is why we used the FIRST_VALUE and LAST_VALUE aggregate functions. I might be tempted to write this as:
*/

--Present--
WITH ProductYearSales AS (

--sales by product, calendar year, compared to sales for all time, and by only product
SELECT ProductAlternateKey,
       CalendarYear,
       SUM(SalesAmount) AS ProductYearlySales
FROM dbo.FactInternetSales
    JOIN dbo.DimDate
        ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
    JOIN dbo.DimProduct
        ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY ProductAlternateKey,
         DimDate.CalendarYear
)
SELECT *,
       --Summing all the sales amount for all the data
       SUM(ProductYearlySales) OVER (PARTITION BY ProductAlternateKey) AS TotalSalesAllTimeForProduct,

       --Summing all the sales amount for all the data
       SUM(ProductYearlySales) OVER () AS TotalSalesAllTime
FROM  ProductYearSales

ORDER BY ProductAlternateKey,
         CalendarYear;

/*
Aha, but are these actually the same values? Well we need to check don't we.

So how do we KNOW they are the same? Let's use our testing tools:
*/

DROP TABLE IF EXISTS #TestOriginalVersion; --<< Most of the time you should KNOW that one is correct
DROP TABLE IF EXISTS #TestNewVersion;

--Old version in a table:

--sales by prodct, calendar year, compared to sales for all time, and by only product
SELECT ProductAlternateKey,
       CalendarYear,
       SUM(SalesAmount) AS ProductYearlySales,
       
       --Summing all the sales amount for all the data
       SUM(SUM(SalesAmount)) OVER (PARTITION BY ProductAlternateKey) AS TotalSalesAllTimeForProduct

       --Summing all the sales amount for all the data
       --SUM(SUM(SalesAmount)) OVER () AS TotalSalesAllTime
INTO #TestOriginalVersion
FROM dbo.FactInternetSales
    JOIN dbo.DimDate
        ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
    JOIN dbo.DimProduct
        ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY ProductAlternateKey,
         DimDate.CalendarYear
ORDER BY ProductAlternateKey,
         DimDate.CalendarYear;

--newversion in a table
WITH ProductYearSales AS (

--sales by prodct, calendar year, compared to sales for all time, and by only product
SELECT ProductAlternateKey,
       CalendarYear,
       SUM(SalesAmount) AS ProductYearlySales
FROM dbo.FactInternetSales
    JOIN dbo.DimDate
        ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
    JOIN dbo.DimProduct
        ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY ProductAlternateKey,
         DimDate.CalendarYear
)
SELECT ProductYearSales.ProductAlternateKey,
       ProductYearSales.CalendarYear,
       ProductYearSales.ProductYearlySales,
       --Summing all the sales amount for all the data
       SUM(ProductYearlySales) OVER (PARTITION BY ProductAlternateKey) AS TotalSalesAllTimeForProduct

       --Summing all the sales amount for all the data
       --SUM(ProductYearlySales) OVER () AS TotalSalesAllTime
INTO #TestNewVersion
FROM  ProductYearSales
--Force a difference
WHERE ProductYearSales.CalendarYear <> '2011'

ORDER BY ProductAlternateKey,
         CalendarYear;

--now apply the simple test

SELECT COUNT(*)
FROM   #TestOriginalVersion

SELECT COUNT(*)
FROM   #TestNewVersion

SELECT COUNT(*)
FROM   (SELECT * FROM #TestOriginalVersion
        INTERSECT
        SELECT * FROM #TestNewVersion) AS Inter

--Uh oh.


--Let's look at the data:

SELECT *
FROM   #TestNewVersion
        FULL OUTER JOIN #TestOriginalVersion
            ON #TestOriginalVersion.ProductAlternateKey = #TestNewVersion.ProductAlternateKey
               AND #TestOriginalVersion.CalendarYear = #TestNewVersion.CalendarYear

--Ah, I did something wrong (deliberately!) that removed the 2011 rows.

/*
Comment out the 2011 line and rerun

So check the performance if you do write in a more step-like mode, but in queries like this where you aren't getting great index usage, it may not make a difference.

*/



/*
There are lots of cool aggregate functions 
*/

--Present--
--ranking data:

--Rank order(s) per day (leaves gaps)

SELECT ProductAlternateKey, FullDateAlternateKey, SalesAmount,
       RANK() OVER (PARTITION BY FullDateAlternateKey ORDER BY SalesAmount DESC) --filter works in CTE only in SQL Server
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
ORDER BY FullDateAlternateKey ASC;

--DENSE_RANK doesn't leave gaps
SELECT ProductAlternateKey, FullDateAlternateKey, SalesAmount,
       DENSE_RANK() OVER (PARTITION BY FullDateAlternateKey ORDER BY SalesAmount DESC) --filter works in CTE only in SQL Server
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
ORDER BY FullDateAlternateKey ASC;


--finding gaps in series
--Present--
--in this case, date_dim is an integer that looks like the date, like 20260411 today. 
--this makes it an easy thing to find gaps.
WITH DateOrder AS (
    --this makes a gapless sequence number
    SELECT ROW_NUMBER() OVER (ORDER BY DateKey) AS OrderingValue, DateKey
FROM dbo.DimDate
)
SELECT * 
FROM   DateOrder
        JOIN DateOrder AS SecondCopy
            ON DateOrder.OrderingValue = SecondCopy.OrderingValue + 1
--then we look for the gaps
WHERE DateOrder.DateKey <> SecondCopy.DateKey + 1;


--Present--
--Get the previous non-null sales day for a product

--Adding IGNORE NULLS on some of the expressions makes it skip null values when 
--looking back if values exists
WITH BaseRows AS (
SELECT ProductAlternateKey, 
       FullDateAlternateKey,
       SUM(SalesAmount) AS DaySalesAmount,
       LAG(FullDateAlternateKey,1) IGNORE NULLS OVER (PARTITION BY ProductAlternateKey 
                              ORDER BY FullDateAlternateKey) AS PreviousSalesDate,
       LAG(SUM(SalesAmount),1) IGNORE NULLS OVER (PARTITION BY ProductAlternateKey 
                              ORDER BY FullDateAlternateKey) AS PreviousSalesAmount
FROM   dbo.DimDate
         LEFT JOIN dbo.FactInternetSales
             JOIN dbo.DimProduct
                ON DimProduct.ProductKey = FactInternetSales.ProductKey
                   AND DimProduct.ProductAlternateKey = 'BK-R89R-48'
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
GROUP BY ProductAlternateKey,
         FullDateAlternateKey
)
SELECT *
FROM   BaseRows
WHERE  DaySalesAmount IS NOT null
ORDER BY FullDateAlternateKey ASC;


--The median

WITH BaseRows AS (
SELECT FullDateAlternateKey, SUM(SalesAmount) AS DaySalesAmount,
        
        --date simply to break the tie
        ROW_NUMBER() OVER (ORDER BY SUM(SalesAmount), FullDateAlternateKey ) AS RowNbr,
        ROW_NUMBER() OVER (ORDER BY SUM(SalesAmount) DESC, FullDateAlternateKey DESC) AS RowNbrDesc,
        PERCENTILE_CONT(.5) WITHIN GROUP (ORDER BY SUM(SalesAmount)) OVER () AS Percentile
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY FullDateAlternateKey 
)
SELECT TOP 10 *-- use top 1 and ORDER BY to get an exact row, or Percentile to get the calculated median
FROM BaseRows
ORDER BY ABS(RowNbr - BaseRows.RowNbrDesc) asc;

