
--this is the expression, ignoring outer apostrophes
DECLARE @expression nvarchar(max) = N'2.446' 
--DECLARE @expression nvarchar(max) = N'2.446 + 2.446' 

--But 2.446 + 2.446 = 4.892, right?
--DECLARE @Expression NVARCHAR(MAX) = '4.892'

--add the expression to a simple SELECT statement
DECLARE @SQL nvarchar(max) = 'SELECT ' + @expression + ' AS CheckMe'

--then add it to a query:
SELECT
    system_type_name,
    CASE is_nullable WHEN 1 
         THEN 'NULL' ELSE 'NOT NULL' END AS nullability
FROM   sys.dm_exec_describe_first_result_set (@SQL,NULL,0) AS dedfrs






GO
CREATE OR ALTER FUNCTION dbo.ExamineExpression
(
    @Expression nvarchar(MAX)
) 
RETURNS @Output TABLE
(
    Datatype sysname,
    Nullability VARCHAR(10),
    Expression NVARCHAR(MAX)
)
AS
 BEGIN
    --add the expression to a simple SELECT statement
    DECLARE @SQL NVARCHAR(MAX) = 'SELECT ' + @expression 
                                             + ' AS CheckMe'
    --then add it to a query:
    INSERT INTO @output(Datatype, Nullability, Expression)
           --multiple rows can be returned for an error, but these parts will remain the same
    SELECT DISTINCT COALESCE(system_type_name,'Invalid expression'),
        CASE WHEN system_type_name IS NULL THEN 'Error'
             WHEN is_nullable = 1 THEN 'NULL' 
             WHEN is_nullable = 0 THEN 'NOT NULL' 
             ELSE 'UNKNOWN' END AS nullability,
        @Expression
    FROM   sys.dm_exec_describe_first_result_set (@SQL,NULL,0) 
                                                         AS dedfrs;
 RETURN;
END
GO

WITH CheckExpression AS
(
    SELECT *
    FROM   (VALUES('1'),
                  ('''name'''),
                  ('N''name'''),
                  ('NULL'),
                  ('''0xABCDEF'''),
                  ('0xABCDEF'),
                  ('6 * 4'),
                  ('6 * 5 + 1.0'),
                  ('6 * 5 + 1.00'),
                  
                  ('CAST(1 as decimal(2,4))'),
                  ('REPLICATE(''A'',4001)'),
                  ('REPLICATE(N''A'',4001)'),
                  ('REPLICATE(N''A'',200000)'),
                  ('REPLICATE(cast(''A'' as nvarchar(max)),200000)')
                  ) AS Rows(Value)
)
SELECT *
FROM   CheckExpression
        CROSS APPLY dbo.ExamineExpression(Value);

