USE tempdb
GO
DROP TABLE IF EXISTS A, A1;
GO
CREATE TABLE A
(
  Aid INT CONSTRAINT PKA PRIMARY KEY,
  Value VARCHAR(10)
);
CREATE TABLE A1 --named to indicate it is a different verson
(               --of the same table you are testing
  Aid INT CONSTRAINT PKA1 PRIMARY KEY,
  Value VARCHAR(10)
);
INSERT INTO A (Aid, Value)
       --same                   --different 3 and 5 not in both, 3 spelled different
VALUES(1,'One'), (2,'Two'),     (3,'Three'),(4,'For');
INSERT INTO A1 (Aid, Value)
VALUES(1,'One'), (2,'Two'),     (4,'Four'),(5,'Five');

SELECT '' AS 'A',*
FROM   A;
SELECT '' AS 'A1',*
FROM   A1;


/*
Showing 2 sets are (or are not), exactly alike
*/
--note, while * is not good in most code (especially that
--you will use in production), here I am using it so it
--clearly represents ALL columns. A column list is used
--to denote just using a subset of columns.

SELECT COUNT(*) as A_Count from A;
SELECT COUNT(*) as A1_Count from A1;

SELECT COUNT(*) as INTERSECT_Count
FROM
(
SELECT Aid, Value
FROM   A
INTERSECT
SELECT Aid, Value
FROM   A1
) as CompareSets

/*
If these don't return the same number of rows, our simple alikeness test fails. (Be aware of your table structure because "physical" columns like RowLastModifiedTime or RowLastModifiedByUserId type columns may need to be removed if you are checking some kinds of data.

Now you can see the differences here:
*/
SELECT '' AS A_NotIn_A1, *
FROM   A
EXCEPT
SELECT '', *
FROM A1;

--And 

SELECT '' AS A1_NotIn_A, *
FROM   A1
EXCEPT
SELECT '', *
FROM A;

--matching rows:

SELECT '' AS In_A1_And_A, *
FROM   A1
INTERSECT
SELECT '', *
FROM A;

/*
Using Subqueries, now you get more control. Like when you just want to find rows that don't exist in another table:
*/

SELECT '' AS A_KeyNotIn_A1, *
FROM   A
WHERE  NOT EXISTS (SELECT *
                   FROM   A1
                   WHERE  A.Aid = A1.Aid);

--and if you want to see the difference in a single column
--exists, but A.Value is different from A1.Value
SELECT '' AS A_ValueDifferentIn_A1, *
FROM A
WHERE EXISTS (SELECT *
              FROM A1
              WHERE A.Aid = A1.Aid
              --NULL safe comparison. Here NULL = NULL
              --good for ETL, should not usually be used for every
              --type of query
              AND A.Value IS DISTINCT FROM A1.Value);

--Not my favorite way to do it, but you will see this sort of query on occasion:
SELECT '' AS A_KeyNotIn_A1, *
FROM   A
        LEFT OUTER JOIN A1
          ON A.Aid = A1.Aid
WHERE  A1.Aid IS NULL;

--Basically this says what was said in the NOT EXISTS query, but it doesn't read the same way (and is marginally slower as written because it needs to return data from A1, even though it is saying to only return data if it is NULL (and Aid is a NOT NULL key)

/*
For testing though, this is the way I tend to do it:

Use a FULL OUTER JOIN, which lets me see all the data in both tables and where they do/don't match
*/
SELECT  '' AS Diff_A_and_A1,
        --key from join
        COALESCE(A1.Aid,A.Aid) AS Aid,
       --row existence
        CASE WHEN A.Aid IS NULL THEN 'A1'
             WHEN A1.Aid IS NULL THEN 'A'
             ELSE 'Both' END AS RowExistsIn,
        --column comparison
        CASE WHEN A1.Value is distinct from A.Value
             THEN 'Different'
             ELSE 'Same'
        END Value_Comparison,
        --values for you to look at
        A.Value AS A_Value,
        A1.Value AS A1_Value
FROM   A
        FULL OUTER JOIN A1
            ON A.Aid = A1.Aid;

/*
Of course, it is never quite this simple (and I rarely would spend time naming columns unless I needed this to be a repeatable process, but we will look at another example later in another section where I want to show you that the data in two solutions match one another.

In testing, it is nice to have a known correct answer to compare against. So say A is the set you are getting from your code, then you might have an A1 set around to check with. It is also a great way to see if you get the same data from a rewritten version of a query, as I will show later.
*/
