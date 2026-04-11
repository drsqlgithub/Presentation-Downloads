USE Tempdb;
GO
/*
Window Functions:
*/
--Present--

--reminder of the data
SELECT SetId,
       GroupingId,
       Value
FROM   [Set];


--Present--
--show that the window includes all 9 rows when using ()
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(Value) OVER () AS MaxWindowValue,
    MAX(Value) OVER () AS MaxWindowValue,
    COUNT(Value) OVER () AS CountWindowValues,
    SUM(Value) OVER () AS TotalWindowValues
FROM   [Set];
GO

--Present--
--show the sizes of the window when partitioning by GroupingId
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(Value) OVER (Partition BY GroupingId) as MaxWindowValue,
    MAX(Value) OVER (Partition BY GroupingId) as MaxWindowValue,
    COUNT(Value) OVER (Partition BY GroupingId) as MaxWindowValue
FROM   [Set];
GO

--Present--
--now value
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(SetId) OVER (Partition BY Value) as MinWindowSetId
    MAX(SetId) OVER (Partition BY Value) as MaxWindowSetId,
    COUNT(SetId) OVER (Partition BY Value) as CountWindowSetId
FROM   [Set];
GO

--Present--
--Not just columns
SELECT SetId, GroupingId, Value, CASE WHEN value < 50 THEN 1 ELSE 0 END AS partition,
    '' AS 'Window ->',
    MIN(SetId) OVER (Partition BY CASE WHEN value < 50 THEN 1 ELSE 0 end) as MaxWindowSetId,
    MAX(SetId) OVER (Partition BY CASE WHEN value < 50 THEN 1 ELSE 0 end) as MaxWindowSetId,
    COUNT(SetId) OVER (Partition BY CASE WHEN value < 50 THEN 1 ELSE 0 end) as MaxWindowSetId
FROM   [Set];
GO

--note: keys don't matter to the windows (they do for your logic, and performance, but not for the act of partitioning)

--Present--
--Can even be a literal (which of course, would just be the same as ()
SELECT SetId, GroupingId, Value, 1 AS partition,
    '' AS 'Window ->',
    MIN(SetId) OVER (Partition BY 1) as MaxWindowSetId,
    MAX(SetId) OVER (Partition BY 1) as MaxWindowSetId,
    COUNT(SetId) OVER (Partition BY 1) as MaxWindowSetId
FROM   [Set];
GO

--or variable
DECLARE @partition INT = 2;
--Can even be a literal (which of course, would just be the same as ()
SELECT SetId, GroupingId, Value, @partition AS partition,
    '' AS 'Window ->',
    MIN(SetId) OVER (Partition BY @partition) as MaxWindowSetId,
    MAX(SetId) OVER (Partition BY @partition) as MaxWindowSetId,
    COUNT(SetId) OVER (Partition BY @partition) as MaxWindowSetId
FROM   [Set];
GO

/*
The last two I DID expect to fail with no column data in there
*/



--Present--
--As of SQL Server 2022, you can use the WINDOW clause to just type the partition
--once. VERY helpful for documentation.
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(SetId) OVER LONGEXPRESSION as MaxWindowSetId,
    MAX(SetId) OVER LONGEXPRESSION as MaxWindowSetId,
    COUNT(SetId) OVER LONGEXPRESSION as MaxWindowSetId
FROM   [Set]
WINDOW LONGEXPRESSION AS (Partition BY CASE WHEN value < 50 THEN 1 ELSE 0 END)
GO

--Present--
--multiple windows per statement
SELECT SetId,
    GroupingId,
    Value,
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

--Present--
--don't do this:
SELECT SetId, GroupingId, Value,
    '' AS 'Window ->',
    MIN(Value) OVER ()  AS Filtered_MinWindowValue,
    MAX(Value) OVER ()  AS Filtered_MaxWindowValue
FROM   [Set]
WHERE  Value between 20 and 30;


--Present--
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

--Present--

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

--Present--
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


--Present--

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
    LAG(SetId) OVER ValueOrderAsc AS LagSetIdAsc,
    LEAD(SetId) OVER ValueOrderAsc AS LeadSetIdAsc,
    LAG(Value) OVER ValueOrderAsc AS LagValueAsc,
    LEAD(Value) OVER ValueOrderAsc AS LeadValueAsc,

    'ValueOrderDesc',

    MIN(Value) OVER ValueOrderDesc AS MinValueDesc,
    MAX(Value) OVER ValueOrderDesc AS MaxValueDesc,
    SUM(Value) OVER ValueOrderDesc AS SumValueDesc,
    COUNT(Value) OVER ValueOrderDesc AS CountValueDesc,

    SetId,
    --now we can reach back and forth a value
    LAG(SetId) OVER ValueOrderDesc AS LagSetIdDesc,
    LEAD(SetId) OVER ValueOrderDesc AS LeadSetIdDesc,
    LAG(Value) OVER ValueOrderDesc AS LagValueDesc,
    LEAD(Value) OVER ValueOrderDesc AS LeadValueDesc

FROM   [Set]
WINDOW ValueOrderAsc AS (ORDER BY VALUE ASC),
       ValueOrderDesc AS (ORDER BY VALUE DESC)
ORDER BY [Set].SetId;


--can do it multiple days
SELECT SetId,
       GroupingId,
       Value,
    'ValueOrderAsc',
    --now we can reach back and forth a value
    LAG(SetId) OVER ValueOrderAsc AS LagSetIdAsc,
    LEAD(SetId) OVER ValueOrderAsc AS LeadSetIdAsc,

    LAG(SetId,2) OVER ValueOrderAsc AS Lag2SetIdAsc,
    LEAD(SetId,2) OVER ValueOrderAsc AS Lead2SetIdAsc,

    'ValueOrderDesc',

    --now we can reach back and forth a value
    LAG(SetId) OVER ValueOrderDesc AS LagSetIdDesc,
    LEAD(SetId) OVER ValueOrderDesc AS LeadSetIdDesc,

    LAG(SetId,2) OVER ValueOrderDesc AS Lag2SetIdDesc,
    LEAD(SetId,2) OVER ValueOrderDesc AS Lead2SetIdDesc


FROM   [Set]
WINDOW ValueOrderAsc AS (ORDER BY VALUE ASC),
       ValueOrderDesc AS (ORDER BY VALUE DESC)
ORDER BY [Set].SetId;


--can lag or lead in differen directions based on sort
--can even get current row values
SELECT SetId,
       GroupingId,
       Value,
    'ValueOrderAsc',
    --now we can reach back and forth a value

    LEAD(SetId,2) OVER ValueOrderAsc AS LeadSetIdAsc_2, 
    LEAD(SetId,1) OVER ValueOrderAsc AS LeadSetIdAsc_1, 
    LAG(SetId,0) OVER ValueOrderAsc AS LagSetIdAsc_0, --gets current value
    LAG(SetId,1) OVER ValueOrderAsc AS LagSetIdAsc_1,
    LAG(SetId,2) OVER ValueOrderAsc AS LagSetIdAsc_2,

    'ValueOrderDesc',
    --now we can reach back and forth a value

    LEAD(SetId,2) OVER ValueOrderDesc AS LeadSetIdDesc_2, 
    LEAD(SetId,1) OVER ValueOrderDesc AS LeadSetIdDesc_1, 
    LAG(SetId,0) OVER ValueOrderDesc AS LagSetIdDesc_0, --gets current value
    LAG(SetId,1) OVER ValueOrderDesc AS LagSetIdDesc_1,
    LAG(SetId,2) OVER ValueOrderDesc AS LagSetIdDesc_2


FROM   [Set]
WINDOW ValueOrderAsc AS (ORDER BY VALUE ASC),
       ValueOrderDesc AS (ORDER BY VALUE DESC)
ORDER BY SetId;


--Present--
--getting the first and last values in a window
SELECT SetId, 
       GroupingId,
       Value,
       '' AS 'ValueOrderAsc ->',
       FIRST_VALUE(SetId) OVER ValueOrderAsc AS FirstSetIdAsc,
       LAST_VALUE(SetId) OVER ValueOrderAsc AS LastSetIdAsc,

       '' AS 'ValueOrderDesc ->',
       FIRST_VALUE(SetId) OVER ValueOrderDesc AS FirstSetIdeDesc,
       LAST_VALUE(SetId) OVER ValueOrderDesc AS LastSetIdDesc
FROM   [Set]
WINDOW ValueOrderAsc AS (ORDER BY VALUE ASC),
       ValueOrderDesc AS (ORDER BY VALUE DESC)
ORDER BY SetId;

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
--Present--

--Getting values form current and 3 rolling frames (ordered by value, fetching 3 full frames in 
--the second window)


SELECT SetId, 
       GroupingId,
       Value,
       '' AS 'ValueOrderAsc',
       FIRST_VALUE(SetId) OVER ValueOrderAsc AS FirstSetIdVOrderAsc,
       LAST_VALUE(SetId) OVER ValueOrderAsc AS LastSetIdOrderAsc,
       SUM(Value) OVER ValueOrderAsc AS SumValueOrderAsc,

       '' as 'ValueOrderAsc3',
       FIRST_VALUE(SetId) OVER ValueOrderAsc3Follow AS FirstSetIdOrderAsc3Follow,
       LAST_VALUE(SetId) OVER ValueOrderAsc3Follow AS LastSetIdOrderAsc3Follow,
       SUM(Value) over ValueOrderAsc3Follow AS SumValueOrderAsc3Follow,
       Value

FROM   [Set]
WINDOW ValueOrderAsc as (ORDER BY VALUE ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), --these first two windows
       ValueOrderDesc as (ORDER BY VALUE DESC),                                                --are equivalent (though in different orders)
       ValueOrderAsc3Follow as (ORDER BY VALUE ASC ROWS BETWEEN 0 PRECEDING AND 2 FOLLOWING)  ,
       ValueOrderDesc3Follow as (ORDER BY VALUE DESC ROWS BETWEEN 0 PRECEDING AND 2 FOLLOWING)
ORDER BY SetId asc;


--frames unbounded reaching forward, reaching back
SELECT SetId, 
       GroupingId,
       Value,
       '' AS 'ValueOrderAsc',
       FIRST_VALUE(SetId) over ValueOrderUBP AS FirstSetIdOrderUBP,
       LAST_VALUE(SetId) over ValueOrderUBP  AS LastSetIdOrderUBP,
       SUM(Value) over ValueOrderUBP AS SumValueOrderUBP,
       
       '' AS 'ValueOrderUBF',
       FIRST_VALUE(SetId) over ValueOrderUBF AS FirstSetIdOrderUBF,
       LAST_VALUE(SetId) over ValueOrderUBF  AS LastSetIdVOrderUBF,
       SUM(Value) over ValueOrderUBF AS SumValueOrderUBF

FROM   [Set]
WINDOW ValueOrderUBP as (ORDER BY VALUE ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), --note preceding
       ValueOrderUBF as (ORDER BY VALUE ASC ROWS BETWEEN 0 PRECEDING AND UNBOUNDED FOLLOWING)  --now following.
ORDER BY SetId asc;


--showing how range gets sets of data with the same exact value
SELECT SetId, 
       GroupingId,
       Value,
       '' AS 'ValueOrderUBP',
       FIRST_VALUE(SetId) over ValueOrderUBP AS FirstSetIdUBP,
       LAST_VALUE(SetId) over ValueOrderUBP AS LastSetIdUBP,
       SUM(Value) OVER ValueOrderUBP AS SumValueUBP,

       '' AS 'ValueOrderCR',
       FIRST_VALUE(SetId) over ValueOrderCR AS FirstSetIdCR,
       LAST_VALUE(SetId) over ValueOrderCR AS LastSetIdCR,
       SUM(Value) OVER ValueOrderCR AS SumValueCR

FROM   [Set]
       --UBP is the same as RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       --and not including a RANGE with an ORDER BY.
WINDOW ValueOrderUBP as (ORDER BY GroupingId ASC RANGE UNBOUNDED PRECEDING), 
       ValueOrderCR as (ORDER BY GroupingId ASC RANGE CURRENT ROW); --this is just 1 range at a time... the Current Row becomes a range
       --Range groups the same values together, So you can see in the CR Rows.

--here you can see that the equivalent values in the OrderBy are followed to the "last value"
