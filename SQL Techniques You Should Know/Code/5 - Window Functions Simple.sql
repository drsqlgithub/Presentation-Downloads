USE Tempdb;
GO
/*
Window Functions:
*/
--reminder of the data
SELECT SetId,
       GroupingId,
       Value
FROM   [Set];


--show that the window includes all 9 rows when using ()
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(Value) OVER () AS MaxWindowValue,
    MAX(Value) OVER () AS MaxWindowValue,
    COUNT(Value) OVER () AS CountWindowValues
FROM   [Set];
GO


--show the sizes of the window when partitioning by GroupingId
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(Value) OVER (Partition BY GroupingId) as MaxWindowValue,
    MAX(Value) OVER (Partition BY GroupingId) as MaxWindowValue,
    COUNT(Value) OVER (Partition BY GroupingId) as MaxWindowValue
FROM   [Set];
GO

--now value
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(SetId) OVER (Partition BY Value) as MinWindowValue,
    MAX(SetId) OVER (Partition BY Value) as MaxWindowValue,
    COUNT(SetId) OVER (Partition BY Value) as CountWindowValue
FROM   [Set];
GO

--Not just columns
SELECT SetId, GroupingId, Value, CASE WHEN value < 50 THEN 1 ELSE 0 END AS partition,
    '' AS 'Window ->',
    MIN(SetId) OVER (Partition BY CASE WHEN value < 50 THEN 1 ELSE 0 end) as MaxWindowValue,
    MAX(SetId) OVER (Partition BY CASE WHEN value < 50 THEN 1 ELSE 0 end) as MaxWindowValue,
    COUNT(SetId) OVER (Partition BY CASE WHEN value < 50 THEN 1 ELSE 0 end) as MaxWindowValue
FROM   [Set];
GO

--note: keys don't matter to the windows (they do for your logic, and performance, but not for the act of partitioning)


--Can even be a literal (which of course, would just be the same as ()
SELECT SetId, GroupingId, Value, 1 AS partition,
    '' AS 'Window ->',
    MIN(SetId) OVER (Partition BY 1) as MaxWindowValue,
    MAX(SetId) OVER (Partition BY 1) as MaxWindowValue,
    COUNT(SetId) OVER (Partition BY 1) as MaxWindowValue
FROM   [Set];
GO

--or variable
DECLARE @partition INT = 2;
--Can even be a literal (which of course, would just be the same as ()
SELECT SetId, GroupingId, Value, @partition AS partition,
    '' AS 'Window ->',
    MIN(SetId) OVER (Partition BY @partition) as MaxWindowValue,
    MAX(SetId) OVER (Partition BY @partition) as MaxWindowValue,
    COUNT(SetId) OVER (Partition BY @partition) as MaxWindowValue
FROM   [Set];
GO

/*
The last two I DID expect to fail
*/



--As of SQL Server 2022, you can use the WINDOW clause to just type the partition
--once. VERY helpful for documentation.
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(SetId) OVER LONGEXPRESSION as MaxWindowValue,
    MAX(SetId) OVER LONGEXPRESSION as MaxWindowValue,
    COUNT(SetId) OVER LONGEXPRESSION as MaxWindowValue
FROM   [Set]
WINDOW LONGEXPRESSION AS (Partition BY CASE WHEN value < 50 THEN 1 ELSE 0 END)
GO


--multiple windows per statement
SELECT SetId,
    '' AS 'Window G->',
    MIN(Value) OVER (PARTITION BY GroupingId) AS Grouping_MinWindowValue,
    MAX(Value) OVER (PARTITION BY GroupingId) AS Grouping_MaxWindowValue,
    Count(Value) OVER (PARTITION BY GroupingId) AS Grouping_CountWindowValue,

    '' AS 'Window V->',
    MIN(Value) OVER (PARTITION BY Value) AS Value_MinWindowValue,	
    MAX(Value) OVER (PARTITION BY Value) AS Value_MaxWindowValue,
    Count(Value) OVER (PARTITION BY Value) AS Value_CountWindowValue
FROM   [Set];	


--remember to be careful with the window and WHERE clauses

--don't do this:
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(Value) OVER ()  AS Filtered_MinWindowValue,
    MAX(Value) OVER ()  AS Filtered_MaxWindowValue
FROM   [Set]
WHERE  Value between 20 and 30;

--when you mean this:

WITH ALLRows AS (
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(Value) OVER ()  AS Filtered_MinWindowValue,
    MAX(Value) OVER ()  AS Filtered_MaxWindowValue
FROM   [Set]
)
SELECT *
FROM   ALLRows
WHERE  Value between 20 and 30;

--VERY VERY DIFFERENT

--NOTE: You cannot filter on a WINDOW function in SQL Server without a CTE.


/*
When Sorting Matters
*/

--ROW_NUMBER requires an ordered partition
SELECT SetId,GroupingId, Value,
    '' AS 'Window ->',
    ROW_NUMBER() OVER GroupingIdDesc AS RowNum_PartGroupingDesc,
    ROW_NUMBER() OVER GroupingIdAsc  AS RowNum_PartGroupingAsc,
    ROW_NUMBER() OVER WholeTableDesc  AS RowNum_WholeTableDesc,
    ROW_NUMBER() OVER WholeTableAsc  AS RowNum__WholeTableAsc
FROM   [Set]
WINDOW GroupingIdDesc AS (PARTITION BY GroupingId ORDER BY Value DESC),
       GroupingIdAsc AS (PARTITION BY GroupingId ORDER BY Value ASC),

       WholeTableAsc AS (ORDER BY Value ASC),
       WholeTableDesc AS (ORDER BY Value DESC);

--it can be nonsense, like random using NEWID()
--ROW_NUMBER requires an ordered partition
SELECT SetId,GroupingId, Value,
    '' AS 'Window ->',
    ROW_NUMBER() OVER GroupingIdDesc AS RowNum_PartGroupingDesc,
    ROW_NUMBER() OVER GroupingIdAsc  AS RowNum_PartGroupingAsc,
    ROW_NUMBER() OVER WholeTableDesc  AS RowNum_WholeTableDesc,
    ROW_NUMBER() OVER WholeTableAsc  AS RowNum__WholeTableAsc --in output this may seem static, but PK value changes
FROM   [Set]
WINDOW GroupingIdDesc AS (PARTITION BY GroupingId ORDER BY NEWID() DESC),
       GroupingIdAsc AS (PARTITION BY GroupingId ORDER BY NEWID() ASC),

       WholeTableAsc AS (ORDER BY NEWID() ASC),
       WholeTableDesc AS (ORDER BY NEWID() DESC);


/*
Reaching back and forth
*/


--you can do a lot of things with aggregates, like aggregating values you are ordering by
--this is where we get some rolling aggregates. And in this cass backwards and forwards.
SELECT SetId,
       GroupingId,
       Value,

        'ValueOrderAsc',
        MIN(Value) OVER ValueOrderAsc   AS MinValueAsc,
        MAX(Value) OVER ValueOrderAsc   AS MaxValueAsc,
        SUM(Value) OVER ValueOrderAsc   AS SumValueAsc,
        COUNT(Value) OVER ValueOrderAsc AS CountValueAsc,

        'ValueOrderDesc',
        --
        MIN(Value) OVER ValueOrderDesc AS MinValueDesc,
        MAX(Value) OVER ValueOrderDesc AS MaxValueDesc,
        SUM(Value) OVER ValueOrderDesc AS SumValueDesc,
        COUNT(Value) OVER ValueOrderDesc AS CountValueDesc
FROM   [Set]
WINDOW ValueOrderAsc AS (ORDER BY VALUE ASC),
       ValueOrderDesc AS (ORDER BY VALUE DESC)
ORDER BY SetId;


--specifically fetching a value 
SELECT SetId,
       GroupingId,
       Value,
    'ValueOrderAsc',
    MIN(Value) OVER ValueOrderAsc AS MinValueAsc,
    MAX(Value) OVER ValueOrderAsc AS MaxValueAsc,
    SUM(Value) OVER ValueOrderAsc AS SumValueAsc,
    COUNT(Value) OVER ValueOrderAsc AS CountValueAsc,

    --NOTE: Lag and Lead get the row value, but they 
    --behave based on sort order, not ROW order.

    --now we can reach back and forth a value
    LAG(SetId) OVER ValueOrderAsc AS LagSetIdValueAsc,
    LEAD(SetId) OVER ValueOrderAsc AS LeadSetIdValueAsc,
    LAG(Value) OVER ValueOrderAsc AS LagValueValueAsc,
    LEAD(Value) OVER ValueOrderAsc AS LeadValueValueAsc,

    'ValueOrderDesc',

    MIN(Value) OVER ValueOrderDesc AS MinValueDesc,
    MAX(Value) OVER ValueOrderDesc AS MaxValueDesc,
    SUM(Value) OVER ValueOrderDesc AS SumValueDesc,
    COUNT(Value) OVER ValueOrderDesc AS CountValueDesc,

    --now we can reach back and forth a value
    LAG(SetId) OVER ValueOrderDesc AS LagSetIdValueDesc,
    LEAD(SetId) OVER ValueOrderDesc AS LeadSetIdValueDesc,
    LAG(Value) OVER ValueOrderDesc AS LagValueValueDesc,
    LEAD(Value) OVER ValueOrderDesc AS LeadValueValueDesc

FROM   [Set]
WINDOW ValueOrderAsc AS (ORDER BY VALUE ASC),
       ValueOrderDesc AS (ORDER BY VALUE DESC)
ORDER BY SetId;


--can do it multiple days
SELECT SetId,
       GroupingId,
       Value,
    'ValueOrderAsc',
    --now we can reach back and forth a value
    LAG(SetId) OVER ValueOrderAsc AS LagSetIdValueAsc,
    LEAD(SetId) OVER ValueOrderAsc AS LeadSetIdValueAsc,

    LAG(SetId,2) OVER ValueOrderAsc AS Lag2SetIdValueAsc,
    LEAD(SetId,2) OVER ValueOrderAsc AS Lead2SetIdValueAsc,

    'ValueOrderDesc',

    --now we can reach back and forth a value
    LAG(SetId) OVER ValueOrderDesc AS LagSetIdValueDesc,
    LEAD(SetId) OVER ValueOrderDesc AS LeadSetIdValueDesc,

    LAG(SetId,2) OVER ValueOrderDesc AS Lag2SetIdValueDesc,
    LEAD(SetId,2) OVER ValueOrderDesc AS Lead2SetIdValueDesc


FROM   [Set]
WINDOW ValueOrderAsc AS (ORDER BY VALUE ASC),
       ValueOrderDesc AS (ORDER BY VALUE DESC)


--can do it multiple days
SELECT SetId,
       GroupingId,
       Value,
    'ValueOrderAsc',
    --now we can reach back and forth a value

    LEAD(SetId,2) OVER ValueOrderAsc AS LeadSetIdValueAsc_2, 
    LEAD(SetId,1) OVER ValueOrderAsc AS LeadSetIdValueAsc_1, 
    LAG(SetId,0) OVER ValueOrderAsc AS LagSetIdValueAsc_0, --gets current value
    LAG(SetId,1) OVER ValueOrderAsc AS LagSetIdValueAsc_1,
    LAG(SetId,2) OVER ValueOrderAsc AS LagSetIdValueAsc_2,

    'ValueOrderDesc',
    --now we can reach back and forth a value

    LEAD(SetId,2) OVER ValueOrderDesc AS LeadSetIdValueDesc_2, 
    LEAD(SetId,1) OVER ValueOrderDesc AS LeadSetIdValueDesc_1, 
    LAG(SetId,0) OVER ValueOrderDesc AS LagSetIdValueDesc_0, --gets current value
    LAG(SetId,1) OVER ValueOrderDesc AS LagSetIdValueDesc_1,
    LAG(SetId,2) OVER ValueOrderDesc AS LagSetIdValueDesc_2


FROM   [Set]
WINDOW ValueOrderAsc AS (ORDER BY VALUE ASC),
       ValueOrderDesc AS (ORDER BY VALUE DESC)


--getting the first and last values in a window
SELECT SetId, 
       GroupingId,
       Value,
       '' AS 'ValueOrderAsc ->',
       FIRST_VALUE(SetId) OVER ValueOrderAsc AS FirstSetIdValueAsc,
       LAST_VALUE(SetId) OVER ValueOrderAsc AS LastSetIdValueAsc,

       '' AS 'ValueOrderDesc ->',
       FIRST_VALUE(SetId) OVER ValueOrderDesc AS FirstSetIdValueDesc,
       LAST_VALUE(SetId) OVER ValueOrderDesc AS LastSetIdValueDesc
FROM   [Set]
WINDOW ValueOrderAsc AS (ORDER BY VALUE ASC),
       ValueOrderDesc AS (ORDER BY VALUE DESC);

/*
Controlling a moving frame

/*
BETWEEN <window frame bound> AND <window frame bound>

Frame bounds:
<number> PRECEDING (or FOLLOWING)
UNBOUNDED PRECEDING
CURRENT ROW

 If you don't specify ROWS or RANGE but you specify ORDER BY, RANGE UNBOUNDED PRECEDING AND CURRENT ROW
*/

*/
--Getting values form current and 3 rolling frames (ordered by value, fetching 3 full frames in 
--the second window)
SELECT SetId, 
       GroupingId,
       Value,
       '' AS 'ValueOrderAsc',
       FIRST_VALUE(SetId) OVER ValueOrderAsc AS FirstSetIdValueOrderAsc,
       LAST_VALUE(SetId) OVER ValueOrderAsc AS LastSetIdValueOrderAsc,
       SUM(Value) OVER ValueOrderAsc AS SumValueValueOrderAsc,

       '' as 'ValueOrderAsc3',
       FIRST_VALUE(SetId) OVER ValueOrderAsc3 AS FirstSetIdValueOrderAsc3Windows,
       LAST_VALUE(SetId) OVER ValueOrderAsc3 AS LastSetIdValueOrderAsc3Windows,
       SUM(Value) over ValueOrderAsc3 AS SumValueValueOrderAsc3Windows,

FROM   [Set]
WINDOW ValueOrderAsc as (ORDER BY VALUE ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), --these first two windows
       ValueOrderDesc as (ORDER BY VALUE DESC),                                                --are equivalent
       ValueOrderAsc3 as (ORDER BY VALUE ASC ROWS BETWEEN 0 PRECEDING AND 2 FOLLOWING)  ,
       ValueOrderDesc3 as (ORDER BY VALUE DESC ROWS BETWEEN 0 PRECEDING AND 2 FOLLOWING)
ORDER BY SetId asc;


--frames unbounded reaching forward, reaching back
SELECT SetId, 
       GroupingId,
       Value,
       '' AS 'ValueOrderAsc',
       FIRST_VALUE(SetId) over ValueOrderUBP AS FirstSetIdValueOrderUBP,
       LAST_VALUE(SetId) over ValueOrderUBP  AS LastSetIdValueOrderUBP,
       SUM(Value) over ValueOrderUBP AS SumValueValueOrderUBP,
       
       '' AS 'ValueOrderUBF',
       FIRST_VALUE(SetId) over ValueOrderUBF AS FirstSetIdValueOrderUBF,
       LAST_VALUE(SetId) over ValueOrderUBF  AS LastSetIdValueOrderUBF,
       SUM(Value) over ValueOrderUBF AS SumValueValueOrderUBF

FROM   [Set]
WINDOW ValueOrderUBP as (ORDER BY VALUE ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), --note preceding
       ValueOrderUBF as (ORDER BY VALUE ASC ROWS BETWEEN 0 PRECEDING AND UNBOUNDED FOLLOWING)  --now following.
ORDER BY SetId asc;


--showing how range gets sets of data with the same exact value
SELECT SetId, 
       GroupingId,
       Value,
       '' AS 'ValueOrderUBP',
       FIRST_VALUE(SetId) over ValueOrderUBP AS FirstValueUBP,
       LAST_VALUE(SetId) over ValueOrderUBP AS LastValueUBP,

       '' AS 'ValueOrderCR',
       FIRST_VALUE(SetId) over ValueOrderCR AS FirstValueCR,
       LAST_VALUE(SetId) over ValueOrderCR AS LastValueCR

FROM   [Set]
       --UBP is the same as RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       --and not including a RANGE with an ORDER BY.
WINDOW ValueOrderUBP as (ORDER BY GroupingId ASC RANGE UNBOUNDED PRECEDING), 
       ValueOrderCR as (ORDER BY GroupingId ASC RANGE CURRENT ROW);
       --Range groups the same values together, So you can see in the CR Rows.

--here you can see that the equivalent values in the OrderBy are followed to the "last value"
