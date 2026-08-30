SELECT 'IN SQLCMD Mode, this will keep you from running the entire script'
GO
EXIT
GO
------------------------------------------------------------------

USE TestRowLevelSecurity_alt
GO


CREATE TABLE Demo.Employee
(
	EmployeeId int NOT NULL CONSTRAINT PKEmployee PRIMARY KEY,
	EmployeeNumber char(8) NOT NULL,
    ManagerId int NULL --implements a simple tree structure... 
               CONSTRAINT FKEmployee_Ref_DemoEmployee
                   REFERENCES Demo.Employee (EmployeeId)
 );
GO
 CREATE  TABLE Demo.WidgetType
 (
	WidgetType VARCHAR(100) NOT NULL CONSTRAINT PKWidgetType PRIMARY KEY,
	ManagedByEmployeeId INT CONSTRAINT FKWidget_Ref_DemoEmployees
                   REFERENCES Demo.Employee (EmployeeId)
				   	ON DELETE CASCADE
);
GO
CREATE TABLE Demo.Widget
(
	WidgetId INT NOT NULL CONSTRAINT PKWidget PRIMARY KEY,
	WidgetName VARCHAR(100),
	WidgetType VARCHAR(100) CONSTRAINT FKWidget_Ref_DemoWidgetType
                   REFERENCES Demo.WidgetType (WidgetType)
				   				   	ON DELETE CASCADE
 );
 GO


--Use data generator to create a bunch of data
--(Or Restore Backup From Download as RLSSourceData and 
-- USE file: 99-Load Data From Backup (Backup in download as well)

--if using backup, skip to --==** These next steps are done in backed
--up data
/*
--force 1 to be the root
UPDATE Demo.Employee
SET ManagerId = NULL
WHERE EmployeeId = 1;

--pare off rows that are not part of the hierarchy where 1 = ROOT
WITH EmployeeHierarchy AS
(
    SELECT EmployeeID,  CAST(CONCAT('\',EmployeeId,'\') AS varchar(1500)) AS Hierarchy
    FROM Demo.Employee
    WHERE ManagerId IS NULL
    UNION ALL
    SELECT Employee.EmployeeID, CAST(CONCAT(Hierarchy,Employee.EmployeeId,'\') 
                                                        AS varchar(1500)) AS Hierarchy
    FROM Demo.Employee
      INNER JOIN EmployeeHierarchy
        ON Employee.ManagerId = EmployeeHierarchy.EmployeeId
  )
DELETE --remove data that doesn't show up in the manager = 1 hierarchy
FROM  Demo.Employee
WHERE  EmployeeId NOT IN (SELECT EmployeeId
							FROM   EmployeeHierarchy);
GO

--force some rows to be all owned by the same manager
DECLARE @minEmployeeId int = (SELECT MIN(managedByEmployeeId)
							  FROM  Demo.WidgetType
							  WHERE ManagedByEmployeeId BETWEEN 300 AND 350);

UPDATE Demo.WidgetType
SET   ManagedByEmployeeId = @minEmployeeId
WHERE managedByEmployeeId BETWEEN 300 AND 350

delete from Demo.Widget where WidgetType is null
GO
*/
--==**

--Show the data
WITH EmployeeHierarchy AS
(
    SELECT EmployeeID,  CAST(CONCAT('\',EmployeeId,'\') AS varchar(1500)) AS Hierarchy
    FROM Demo.Employee
    WHERE ManagerId IS NULL
    UNION ALL
    SELECT Employee.EmployeeID, CAST(CONCAT(Hierarchy,Employee.EmployeeId,'\') 
                                                        AS varchar(1500)) AS Hierarchy
    FROM Demo.Employee
      INNER JOIN EmployeeHierarchy
        ON Employee.ManagerId = EmployeeHierarchy.EmployeeId
  )
SELECT *
FROM  EmployeeHierarchy;

SELECT *
FROM   Demo.WidgetType;

SELECT *
FROM   Demo.Widget;
GO

--needed for breadth first algorithm..
create index ManagerId on Demo.Employee(ManagerId);


--using session context for security to keep things simple

CREATE OR ALTER FUNCTION rowLevelSecurity.employeeHierarchy$SecurityPredicate
(
	@canYouSeeEmployeeId int
)
RETURNS TABLE  
WITH SCHEMABINDING
AS 

RETURN
(	
	WITH EmployeeHierarchy AS
	(                      --if this is the employeeId that you are checking, make it 1
		SELECT EmployeeID, CASE WHEN CAST(SESSION_CONTEXT(N'UserName') AS INT) = @canYouSeeEmployeeId 
								     --OR USER_NAME() = 'dbo' 
									 THEN 1 ELSE 0 end AS retval
									 --,CAST(CONCAT('\',EmployeeId,'\') AS VARCHAR(1500)) AS Hierarchy
		FROM Demo.Employee
		WHERE EmployeeId = CAST(SESSION_CONTEXT(N'UserName') AS INT)
		UNION ALL                   --does this match the employee we are looking for?
		SELECT Employee.EmployeeID, CASE WHEN @canYouSeeEmployeeId = Employee.EmployeeID THEN 1 ELSE Retval END
									--CAST(CONCAT(Hierarchy,Employee.EmployeeId,'\') AS VARCHAR(1500)) AS Hierarchy
		FROM Demo.Employee
		  INNER JOIN EmployeeHierarchy
			ON Employee.ManagerId = EmployeeHierarchy.EmployeeId
		WHERE retval = 0 --stop looping when retval = 1 which means the value was found
	  )
	SELECT TOP(1) 1 AS retval
	FROM  EmployeeHierarchy
	WHERE retval = 1);

GO

EXEC sys.sp_set_session_context @key = N'UserName', @value = 491
SELECT *
FROM   rowLevelSecurity.employeeHierarchy$SecurityPredicate (6295); --if this doesn't return data, structure has changed, pick a value

SELECT *
FROM   rowLevelSecurity.employeeHierarchy$SecurityPredicate (1200);
GO

EXEC sys.sp_set_session_context @key = N'UserName', @value = 1
SELECT *
FROM   rowLevelSecurity.employeeHierarchy$SecurityPredicate (6295); --if this doesn't return data, structure has changed, pick a value

SELECT *
FROM   rowLevelSecurity.employeeHierarchy$SecurityPredicate (1200);
GO

DROP SECURITY POLICY IF EXISTS rowLevelSecurity.Demo_WidgetType_SecurityPolicy ;
GO
--simple, data viewing filter 
CREATE SECURITY POLICY rowLevelSecurity.Demo_WidgetType_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.employeeHierarchy$SecurityPredicate(ManagedByEmployeeId) ON Demo.WidgetType
    WITH (STATE = ON); --go ahead and make it apply
GO

EXEC sys.sp_set_session_context @key = N'UserName', @value = NULL;
--without context set, will be 0
SELECT COUNT(*) FROM Demo.WidgetType;

--picking a value in the table
EXEC sys.sp_set_session_context @key = N'UserName', @value = 491
SELECT COUNT(*)
FROM   Demo.WidgetType
GO

--picking a value in the table
EXEC sys.sp_set_session_context @key = N'UserName', @value = 156
SELECT COUNT(*)
FROM   Demo.WidgetType
GO

--picking a value in the table, that we set up to have > 1 row
EXEC sys.sp_set_session_context @key = N'UserName', @value = 300
SELECT COUNT(*)
FROM   Demo.WidgetType
GO

--now, lets go with the root node
EXEC sys.sp_set_session_context @key = N'UserName', @value = 1

SELECT *
FROM   Demo.WidgetType
ORDER BY ManagedByEmployeeId
GO

----------------------------------------------------
--For a hierarchy, you can easily tune the structures using one of the other
--paradigms... I will use a kimball hierarchy helper which is VERY tunable, and one
--of the best performers when dealing with non volatile hierarchyes (which most employee
--reporting hierarchies are
----------------------------------------------------
--

--This is basically the normal hierarcy query that will return 1-Many rows per 
--employee, 1 for self, and rows for any related rows.

CREATE function Demo.Employee$returnHierarchyHelper
(@EmployeeId int)
RETURNS @Output TABLE (ManagerId int, ChildEmployeeId int, Distance int, ParentRootNodeFlag bit, ChildLeafNodeFlag bit)
as
BEGIN
	;WITH EmployeeHierarchy(EmployeeId, ManagerId, treelevel, hierarchy)
	AS
	(
		 --gets the top level in hierarchy we want. The hierarchy column
		 --will show the row's place in the hierarchy from this query only
		 --not in the overall reality of the row's place in the table
		 SELECT EmployeeID, ManagerId,
				1 as treelevel, CAST(EmployeeId as varchar(max)) as hierarchy
		 FROM   Demo.Employee
		 WHERE  EmployeeId=@EmployeeId

		 UNION ALL

		 --joins back to the CTE to recursively retrieve the rows 
		 --note that treelevel is incremented on each iteration
		 SELECT Employee.EmployeeID, Employee.ManagerId,
				treelevel + 1 as treelevel,
				hierarchy + '\' +cast(Employee.EmployeeId as varchar(20)) as hierarchy
		 FROM   Demo.Employee
				  INNER JOIN EmployeeHierarchy
					--use to get children
					on Employee.ManagerId= EmployeeHierarchy.EmployeeID

	)
	--added to original tree example with distance, root and leaf node indicators
	insert into @Output (ManagerId, ChildEmployeeId, Distance, ParentRootNodeFlag, ChildLeafNodeFlag)
	select  @EmployeeId as ManagerId, EmployeeHierarchy.EmployeeId as ChildEmployeeId, treeLevel - 1 as Distance,
										   case when EmployeeId = @EmployeeId AND ManagerId IS NULL then 1 else 0 end as ParentRootNodeFlag,
										   case when NOT exists(select *	
																from   Demo.Employee
																where  Employee.ManagerId = EmployeeHierarchy.EmployeeId
															   ) then 1 else 0 end as ChildRootNodeFlag
	from   EmployeeHierarchy

RETURN;

END;
GO

SELECT *
FROM   Demo.Employee$returnHierarchyHelper(1);

SELECT *
FROM   Demo.Employee$returnHierarchyHelper(1815);

CREATE TABLE Demo.Employee_HierarchyHelper
(
	EmployeeId INT,
	CanSeeEmployeeId INT,
	CONSTRAINT PK_Employee_HierarchyHelper PRIMARY KEY (CanSeeEmployeeId,EmployeeId)
);
GO
--procedure to load hierarchy helper
CREATE OR ALTER PROCEDURE Demo.Employee$ReloadHierarchyHelper
AS
BEGIN

	TRUNCATE TABLE Demo.Employee_HierarchyHelper
	INSERT INTO Demo.Employee_HierarchyHelper
	(
		EmployeeId,
		CanSeeEmployeeId
	)
	SELECT HH.ManagerId AS EmployeeId, HH.ChildEmployeeId AS CanSeeEmployeeId
	FROM   Demo.Employee
			CROSS APPLY Demo.Employee$returnHierarchyHelper(EmployeeId) AS HH
END
GO
EXEC Demo.Employee$ReloadHierarchyHelper;
GO

SELECT *
FROM   Demo.Employee_HierarchyHelper;

DROP SECURITY POLICY rowLevelSecurity.Demo_WidgetType_SecurityPolicy ;
GO

CREATE OR ALTER FUNCTION rowLevelSecurity.employeeHierarchy$SecurityPredicate
(
	@canYouSeeEmployeeId int
)
RETURNS TABLE  
WITH SCHEMABINDING
AS 

RETURN
(	
	SELECT 1 AS retval
	WHERE EXISTS (SELECT 1
					FROM Demo.Employee_HierarchyHelper
					WHERE  EmployeeId = CAST(SESSION_CONTEXT(N'UserName') AS INT)
					  AND  CanSeeEmployeeId = @canYouSeeEmployeeId)
);

GO



--simple, data viewing filter 
CREATE SECURITY POLICY rowLevelSecurity.Demo_WidgetType_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.employeeHierarchy$SecurityPredicate(ManagedByEmployeeId) ON Demo.WidgetType
    WITH (STATE = ON); --go ahead and make it apply
GO

EXEC sys.sp_set_session_context @key = N'UserName', @value = 1;

SELECT *
FROM   demo.WidgetType

SET STATISTICS IO ON; 
SELECT *
FROM   demo.WidgetType;
SET STATISTICS IO OFF;


--looking at the widgetType's joined to the Widgets 200K +
SELECT *
FROM    demo.Widget
		 JOIN demo.WidgetType
			ON WidgetType.WidgetType = Widget.WidgetType

GO
--TURN ON QUERY PLAN
SELECT *
FROM    demo.Widget
		 JOIN demo.WidgetType
			ON WidgetType.WidgetType = Widget.WidgetType
GO


--TURN OFF QUERY PLAN


EXEC sys.sp_set_session_context @key = N'UserName', @value = 1202

SELECT *
FROM   demo.WidgetType

SELECT *
FROM    demo.Widget
		 JOIN demo.WidgetType
			ON WidgetType.WidgetType = Widget.WidgetType
GO

--However, this:

SELECT *
FROM    demo.Widget;

--returns ALL DATA.


--predicate function for widget data
CREATE OR ALTER FUNCTION rowLevelSecurity.employeeHierarchy$SecurityPredicate_ForWidget
(
	@canYouSeeWidgetType varchar(100)
)
RETURNS TABLE  
WITH SCHEMABINDING
AS 

RETURN
(	
	SELECT TOP 1 1 AS retval
	FROM Demo.Employee_HierarchyHelper
	WHERE  EmployeeId = CAST(SESSION_CONTEXT(N'UserName') AS INT)
		AND  CanSeeEmployeeId = (SELECT ManagedByEmployeeId
								 FROM   Demo.WidgetType
								 WHERE  WidgetType = @canYouSeeWidgetType)
);

GO

/* could just add this:
CREATE SECURITY POLICY rowLevelSecurity.Demo_Widget_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.employeeHierarchy$SecurityPredicate_ForWidget(WidgetType) ON Demo.Widget
    WITH (STATE = ON); --go ahead and make it apply
*/
DROP SECURITY POLICY IF EXISTS rowLevelSecurity.Demo_WidgetType_SecurityPolicy 
GO
CREATE SECURITY POLICY rowLevelSecurity.Demo_WidgetType_SecurityPolicy 
    ADD FILTER PREDICATE rowLevelSecurity.employeeHierarchy$SecurityPredicate(ManagedByEmployeeId) ON Demo.WidgetType
    ,ADD FILTER PREDICATE rowLevelSecurity.employeeHierarchy$SecurityPredicate_ForWidget(WidgetType) ON Demo.Widget

    WITH (STATE = ON); --go ahead and make it apply
GO


EXEC sys.sp_set_session_context @key = N'UserName', @value = 1202

SELECT *
FROM   Demo.WidgetType

SELECT *
FROM   Demo.Widget


EXEC sys.sp_set_session_context @key = N'UserName', @value = 1

SELECT *
FROM   Demo.WidgetType
ORDER BY ManagedByEmployeeId

SELECT *
FROM   Demo.Widget

--owns multiple rows
EXEC sys.sp_set_session_context @key = N'UserName', @value = 300

SELECT *
FROM   Demo.WidgetType;

SELECT *
FROM   Demo.Widget;

SET STATISTICS IO ON;
SELECT *
FROM   Demo.Widget;
SET STATISTICS IO OFF;

EXEC sys.sp_set_session_context @key = N'UserName', @value = 1;
SET STATISTICS IO ON;
SELECT *
FROM   Demo.Widget
SET STATISTICS IO OFF;

--now no clustered index
ALTER TABLE Demo.Employee_HierarchyHelper
	DROP CONSTRAINT PK_Employee_HierarchyHelper;
GO

EXEC sys.sp_set_session_context @key = N'UserName', @value = 1;
SET STATISTICS IO ON;
SELECT *
FROM   Demo.Widget


SELECT *
FROM   Demo.Widget
WHERE  Widget.WidgetType IN ('00022','67325')
SET STATISTICS IO OFF;