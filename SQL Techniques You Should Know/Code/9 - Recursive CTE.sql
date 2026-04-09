--Note: The first example is not an endorcement of using this method for generating a simple sequence of numbers
--      It is however, a simple way to look at this, and the base method if you need a sequence that requires a 
--      loop.  For more info, check these blogs:

-- https://drsql.link/2026/01/28/performance-test-of-generating-a-set-of-sequential-numbers/
-- https://drsql.link/2026/02/04/generating-a-set-of-sequential-numbers-part-2/

--One of the simplest examples is generating a series of numbers. For example:


WITH NewSequence AS (
SELECT 1 AS value
UNION ALL
SELECT value + 1
FROM  NewSequence
WHERE value < 100
)
SELECT Value
FROM   NewSequence;

--obvs use for anything it can do (and any of the methods in those articles
--if at all possible (except the while loop if you can avoid it!)
SELECT *
FROM  GENERATE_SERIES(1,100);

/*
But as I always suggest people do... take this to a bit of a crazy place to see what is possible

As an example, a sequence where the value isnt an integer and increases by 2.446 each iteration:
*/


--Types have to match perfectly, this won't even work.
WITH NewSequence AS (
SELECT 2.446 AS value
UNION ALL
SELECT value + 2.446
FROM  NewSequence
WHERE value < 100
)
SELECT *
FROM   NewSequence;

---why aren't they the same? Stay tuned for the next section, but 
-- 2.446 IS numeric(4,3)
-- 2.446 + 2.446 is numeric(5,3)
-- and if it DID work, the actual type will likely be larger to allow
-- for larger loop values



--Perfect match, wild output
WITH NewSequence AS (
SELECT CAST(2.446 AS DECIMAL(20,3)) AS value
UNION ALL
SELECT CAST(value + 2.446 AS DECIMAL(20,3)) AS value --test wisely if the data to be output is important to be precise
FROM  NewSequence
WHERE value < 100
)
SELECT *
FROM   NewSequence;




--Goto folder named 9 - Breadth Processing - For a hierarchy example