USE tempdb
GO
DROP TABLE IF EXISTS A, A_Reference;
GO
CREATE TABLE A
(
  Aid INT CONSTRAINT PKA PRIMARY KEY,
  Value VARCHAR(10)
);
CREATE TABLE A_Reference --named to indicate it is a different verson
(               --of the same table you are testing
  Aid INT CONSTRAINT PKA_Reference PRIMARY KEY,
  Value VARCHAR(10)
);
INSERT INTO A (Aid, Value)
       --same                   --different 3 and 5 not in both, 3 spelled different
VALUES(1,'One'), (2,'Two'),     (3,'Three'),(4,'For');
INSERT INTO A_Reference (Aid, Value)
VALUES(1,'One'), (2,'Two'),     (4,'Four'),(5,'Five');

SELECT '' AS 'A',*
FROM   A;
SELECT '' AS 'A_Reference',*
FROM   A_Reference;


/*
Showing 2 sets are (or are not), exactly alike
*/
--note, while * is not good in most code (especially that
--you will use in production), here I am using it so it
--clearly represents ALL columns. A column list is used
--to denote just using a subset of columns.

SELECT COUNT(*) as A_Count from A;
SELECT COUNT(*) as A_Reference_Count from A_Reference;

SELECT COUNT(*) as INTERSECT_Count
FROM
(
SELECT Aid, Value
FROM   A
INTERSECT
SELECT Aid, Value
FROM   A_Reference
) as CompareSets

/*
If these don't return the same number of rows, our simple alikeness test fails. (Be aware of your table structure because "physical" columns like RowLastModifiedTime or RowLastModifiedByUserId type columns may need to be removed if you are checking some kinds of data.

Now you can see the differences here:
*/
SELECT '' AS A_NotIn_A_Reference, *
FROM   A
EXCEPT   --rows not in A_Reference
SELECT '', *
FROM A_Reference;

--And 

SELECT '' AS A_Reference_NotIn_A, *
FROM   A_Reference
EXCEPT
SELECT '', *
FROM A;

--matching rows:

SELECT '' AS In_A_Reference_And_A, *
FROM   A_Reference
INTERSECT
SELECT '', *
FROM A;

/*
Using Subqueries, now you get more control. Like when you just want to find rows that don't exist in another table:
*/

SELECT '' AS A_KeyNotIn_A_Reference, *
FROM   A
WHERE  NOT EXISTS (SELECT *
                   FROM   A_Reference
                   WHERE  A.Aid = A_Reference.Aid);

--and if you want to see the difference in a single column
--exists, but A.Value is different from A_Reference.Value
SELECT '' AS A_ValueDifferentIn_A_Reference, *
FROM A
WHERE EXISTS (SELECT *
              FROM A_Reference
              WHERE A.Aid = A_Reference.Aid
              --NULL safe comparison. Here NULL = NULL
              --good for ETL, should not usually be used for every
              --type of query
              AND A.Value IS DISTINCT FROM A_Reference.Value); --use to treat NULL = NULL for ETL type purposes

--Not my favorite way to do it, but you will see this sort of query on occasion:
SELECT '' AS A_KeyNotIn_A_Reference, *
FROM   A
        LEFT OUTER JOIN A_Reference
          ON A.Aid = A_Reference.Aid
WHERE  A_Reference.Aid IS NULL;

--Basically this says what was said in the NOT EXISTS query, but it doesn't read the same way (and is marginally slower as written because it needs to return data from A_Reference, even though it is saying to only return data if it is NULL (and Aid is a NOT NULL key)

/*
For testing though, this is the way I tend to do it:

Use a FULL OUTER JOIN, which lets me see all the data in both tables and where they do/don't match
*/
SELECT  '' AS Diff_A_and_A_Reference,
        --key from join
        COALESCE(A_Reference.Aid,A.Aid) AS Aid,
       --row existence
        CASE WHEN A.Aid IS NULL THEN 'A_Reference'
             WHEN A_Reference.Aid IS NULL THEN 'A'
             ELSE 'Both' END AS RowExistsIn,
        --column comparison
        CASE WHEN A_Reference.Value is distinct from A.Value
             THEN 'Different'
             ELSE 'Same'
        END Value_Comparison,
        --values for you to look at
        A.Value AS A_Value,
        A_Reference.Value AS A_Reference_Value
FROM   A
        FULL OUTER JOIN A_Reference
            ON A.Aid = A_Reference.Aid;

/*
Of course, it is never quite this simple (and I rarely would spend time naming columns unless I needed this to be a repeatable process, but we will look at another example later in another section where I want to show you that the data in two solutions match one another.

In testing, it is nice to have a known correct answer to compare against. So say A is the set you are getting from your code, then you might have an A_Reference set around to check with. It is also a great way to see if you get the same data from a rewritten version of a query, as I will show later.
*/
