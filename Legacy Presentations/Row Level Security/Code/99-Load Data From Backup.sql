:setvar destinationdb TestRowLevelSecurity_alt
:setvar backuplocation "C:\Users\Public\Documents\"

USE [master]
RESTORE DATABASE [RLSSourceData] FROM  DISK = N'$(backuplocation)RLSSourceData.bak' WITH  FILE = 1,  MOVE N'RLSSourceData' TO N'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\RLSSourceData.mdf',  MOVE N'RLSSourceData_log' TO N'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\RLSSourceData_log.ldf',  NOUNLOAD,  REPLACE,  STATS = 5
GO


USE $(destinationdb)
GO
DELETE FROM Demo.Employee;
DELETE FROM Demo.Widget;
DELETE FROM Demo.WidgetType;
GO
INSERT INTO Demo.Employee(EmployeeId,
                     EmployeeNumber,
                     ManagerId)
SELECT EmployeeId, EmployeeNumber, ManagerId
FROM   RLSSourceData.Demo.Employee
GO
INSERT INTO Demo.WidgetType(WidgetType,
                       ManagedByEmployeeId)
SELECT WidgetType, ManagedByEmployeeId
FROM    RLSSourceData.Demo.WidgetType
GO
INSERT INTO Demo.Widget(WidgetId,
                   WidgetName,
                   WidgetType)
SELECT WidgetId,WidgetName,WidgetType
FROM   RLSSourceData.Demo.Widget
GO
DELETE FROM Demo.Widget WHERE WidgetType IS NULL;