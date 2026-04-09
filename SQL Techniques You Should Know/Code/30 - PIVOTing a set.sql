USE AdventureWorksDW2025;

--So you have this set:

SELECT ProductAlternateKey,
       CalendarYear,
       SUM(SalesAmount) AS TotalSales
FROM dbo.FactInternetSales
    JOIN dbo.DimDate
        ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
    JOIN dbo.DimProduct
        ON DimProduct.ProductKey = FactInternetSales.ProductKey
GROUP BY ProductAlternateKey,
         CalendarYear;

-----------------------------------------------------------------

--Pivot to products and years

SELECT ProductAlternateKey,
       COALESCE([2011], 0) AS [2011],
       COALESCE([2012], 0) AS [2012],
       COALESCE([2013], 0) AS [2013],
       COALESCE([2014], 0) AS [2014]
FROM
(
    SELECT ProductAlternateKey,
           CalendarYear,
           SUM(SalesAmount) AS TotalSales
    FROM dbo.FactInternetSales
        JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
        JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
    GROUP BY ProductAlternateKey,
             CalendarYear
) AS SourceData
PIVOT
(
    MAX(TotalSales)
    FOR CalendarYear IN ([2011], [2012], [2013], [2014])
) AS PivotTable
ORDER BY ProductAlternateKey;

--Alternative method uses group by and case expressions for the pivoted data:

SELECT ProductAlternateKey,
       SUM(CASE WHEN CalendarYear = 2011 THEN
                SalesAmount
                ELSE 0 END
          ) AS [2011],
       SUM(CASE WHEN CalendarYear = 2012 THEN
                SalesAmount
                ELSE 0 END
          ) AS [2012],
       SUM(CASE WHEN CalendarYear = 2013 THEN
                SalesAmount
                ELSE 0 END
          ) AS [2013],
       SUM(CASE WHEN CalendarYear = 2014 THEN
                SalesAmount
                ELSE 0 END
          ) AS [2014]
    FROM dbo.FactInternetSales
        JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
        JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
    GROUP BY ProductAlternateKey --only the rows axis needs to be group by'd here.

/*
As usual, be wary of AI code. It put together this output:
*/

SELECT ProductAlternateKey,
       MAX(CASE WHEN CalendarYear = 2011 THEN
                TotalSales
                ELSE 0 END
          ) AS [2011],
       MAX(CASE WHEN CalendarYear = 2012 THEN
                TotalSales
                ELSE 0 END
          ) AS [2012],
       MAX(CASE WHEN CalendarYear = 2013 THEN
                TotalSales
                ELSE 0 END
          ) AS [2013],
       MAX(CASE WHEN CalendarYear = 2014 THEN
                TotalSales
                ELSE 0 END
          ) AS [2014]
FROM
(
    SELECT ProductAlternateKey,
           CalendarYear,
           SUM(SalesAmount) AS TotalSales
    FROM dbo.FactInternetSales
        JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
        JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
    GROUP BY ProductAlternateKey,
             CalendarYear
) AS SourceData
GROUP BY ProductAlternateKey
ORDER BY ProductAlternateKey;






/*
And yes, when you change algorithms, check your work!
*/
SELECT ProductAlternateKey,
       COALESCE([2011], 0) AS [2011],
       COALESCE([2012], 0) AS [2012],
       COALESCE([2013], 0) AS [2013],
       COALESCE([2014], 0) AS [2014]
INTO #PivotExpressions
FROM
(
    SELECT ProductAlternateKey,
           CalendarYear,
           SUM(SalesAmount) AS TotalSales
    FROM dbo.FactInternetSales
        JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
        JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
    GROUP BY ProductAlternateKey,
             CalendarYear
) AS SourceData
PIVOT
(
    MAX(TotalSales)
    FOR CalendarYear IN ([2011], [2012], [2013], [2014])
) AS PivotTable
ORDER BY ProductAlternateKey;


SELECT ProductAlternateKey,
       SUM(CASE WHEN CalendarYear = 2011 THEN
                SalesAmount
                ELSE 0 END
          ) AS [2011],
       SUM(CASE WHEN CalendarYear = 2012 THEN
                SalesAmount
                ELSE 0 END
          ) AS [2012],
       SUM(CASE WHEN CalendarYear = 2013 THEN
                SalesAmount
                ELSE 0 END
          ) AS [2013],
       SUM(CASE WHEN CalendarYear = 2014 THEN
                SalesAmount
                ELSE 0 END
          ) AS [2014]
    INTO #CaseExpressions
    FROM dbo.FactInternetSales
        JOIN dbo.DimDate
            ON dbo.FactInternetSales.OrderDateKey = dbo.DimDate.DateKey
        JOIN dbo.DimProduct
            ON DimProduct.ProductKey = FactInternetSales.ProductKey
    GROUP BY ProductAlternateKey --only the rows axis needs to be group by'd here.

--Same answer:
SELECT COUNT(*) as PivotExpressions_Count from #PivotExpressions;
SELECT COUNT(*) as CaseExpessions_Count from #CaseExpressions;

SELECT COUNT(*) as INTERSECT_Count
FROM
(
SELECT *
FROM   #PivotExpressions
INTERSECT
SELECT *
FROM   #CaseExpressions
) as CompareSets