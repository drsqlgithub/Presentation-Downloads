--We had this example where we wanted the last preceeding by day. This required you to 
--HAVE rows for each iteration.

USE AdventureWorksDW2025
GO

/*
Running Totals
*/
--rolling sum by row
SELECT ProductAlternateKey, FullDateAlternateKey, SalesAmount,
       SUM(SalesAmount) OVER DateOrderAsc
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
WHERE ProductAlternateKey = 'BK-M18S-48'
WINDOW DateOrderAsc AS (ORDER BY FullDateAlternateKey ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
ORDER BY FullDateAlternateKey ASC

--rolling sum by previous 5 sales
SELECT ProductAlternateKey, FullDateAlternateKey, SalesAmount,
       SUM(SalesAmount) OVER DateOrderAsc
FROM   dbo.FactInternetSales
         JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
         JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
WHERE ProductAlternateKey = 'BK-M18S-48'
WINDOW DateOrderAsc AS (ORDER BY FullDateAlternateKey ASC ROWS BETWEEN 5 PRECEDING AND CURRENT ROW)
ORDER BY FullDateAlternateKey ASC


--But what if you want sales over the past 5 days, not sales

--Rolling Averages, including every day:
SELECT ProductAlternateKey, 
       FullDateAlternateKey,
       SUM(SalesAmount),
       SUM(SUM(SalesAmount)) OVER (PARTITION BY ProductAlternateKey
                              ORDER BY FullDateAlternateKey asc ROWS BETWEEN 5 PRECEDING AND CURRENT ROW)
FROM   dbo.DimDate --now we need every day, for each product
                   --so the cross product of Product and Day
         CROSS JOIN (SELECT * FROM dbo.DimProduct WHERE DimProduct.ProductAlternateKey = 'BK-M18S-48') AS DimProduct
         --  CROSS JOIN (SELECT * FROM dbo.DimProduct ) AS DimProduct
            LEFT JOIN dbo.FactInternetSales
                ON DimProduct.ProductKey = FactInternetSales.ProductKey
                   AND dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
WHERE  DimDate.FullDateAlternateKey > '2010-12-18'
GROUP BY ProductAlternateKey,
         FullDateAlternateKey
ORDER BY ProductAlternateKey,FullDateAlternateKey ASC;


WITH BaseRows AS (
SELECT ProductAlternateKey, 
       FullDateAlternateKey,
       SUM(SalesAmount) AS CurrentSum,
       SUM(SUM(SalesAmount)) OVER (PARTITION BY ProductAlternateKey
                              ORDER BY FullDateAlternateKey asc ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS RollingSum
FROM   dbo.DimDate --now we need every day, for each product
                   --so the cross product of Product and Day
         CROSS JOIN (SELECT * FROM dbo.DimProduct WHERE DimProduct.ProductAlternateKey = 'BK-M18S-48') AS DimProduct
         --  CROSS JOIN (SELECT * FROM dbo.DimProduct ) AS DimProduct
            LEFT JOIN dbo.FactInternetSales
                ON DimProduct.ProductKey = FactInternetSales.ProductKey
                   AND dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
WHERE  DimDate.FullDateAlternateKey > '2010-12-18'
GROUP BY ProductAlternateKey,
         FullDateAlternateKey
)
SELECT *
FROM   BaseRows
WHERE  RollingSum IS NOT NULL 
ORDER BY ProductAlternateKey,FullDateAlternateKey ASC;








/*

Bonus: My Method

*/

--create a table that creates time slices:


DECLARE @StartingValue DATE = 
     (SELECT MIN([FullDateAlternateKey]) FROM dbo.DimDate);

--display the starting time
SELECT @StartingValue AS StartingValue;
WITH TimeFrame AS (
SELECT --generate time frames to look back to. For me, it is month or years
      -- or even weeks, hours; to look back to
      Value  AS GroupValue, --This is what you are going to call the group
      --here I will call it the number of months prior
      --to the starting data
      
      --5 days earlier than the EndDate
      DATEADD(day,-6,DATEADD(day,-value,@StartingValue)) AS StartDate,
                  --includes current day, and 4 days earlier

      --series starting with today, incremented by a day (end date is the date we
      --care about.
      DATEADD(day,-value ,@StartingValue) AS EndDate
FROM   GENERATE_SERIES(0,5000) --back to the 70's
)
SELECT *
FROM TimeFrame



-------
-- Then join it to the actual data:

DECLARE @StartingValue DATE = '2013-12-18'
     --(SELECT ([FullDateAlternateKey]) FROM dbo.DimDate);

--display the starting time
SELECT @StartingValue AS StartingValue;
WITH TimeFrame AS (
SELECT --generate time frames to look back to. For me, it is month or years
      -- or even weeks, hours; to look back to
      Value  AS GroupValue, --This is what you are going to call the group
      --here I will call it the number of months prior
      --to the starting data
      
      --5 days earlier than the EndDate
      DATEADD(day,-6,DATEADD(day,-value,@StartingValue)) AS StartDate,
                  --includes current day, and 4 days earlier

      --series starting with today, incremented by a day (end date is the date we
      --care about.
      DATEADD(day,-value ,@StartingValue) AS EndDate
FROM   GENERATE_SERIES(0,5000) --back to the 70's
)
SELECT GroupValue,
      DimProduct.ProductAlternateKey,
      MAX(TimeFrame.EndDate) AS PeriodDate,
      SUM(FactInternetSales.SalesAmount) AS RollingSum,
      MAX(TimeFrame.StartDate) AS PeriodStartDate
FROM   dbo.FactInternetSales
            JOIN dbo.DimProduct
                ON DimProduct.ProductKey = FactInternetSales.ProductKey
         JOIN dbo.DimDate AS OrderDimDate
            ON OrderDimDate.DateKey = FactInternetSales.OrderDateKey
         JOIN TimeFrame
         --note that we don't include the startdate, but we do the end
         --since that is the day we are iterating on.
            ON OrderDimDate.FullDateAlternateKey > TimeFrame.StartDate
               AND OrderDimDate.FullDateAlternateKey <= TimeFrame.EndDate
WHERE DimProduct.ProductAlternateKey = 'BK-M18S-48'
GROUP BY DimProduct.ProductAlternateKey, TimeFrame.GroupValue
ORDER BY PeriodStartDate ASC;




