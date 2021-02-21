USE TestTemporal
GO
SELECT *
FROM   Demo.Company;
GO
SELECT *
FROM   Demo.Company FOR SYSTEM_TIME ALL
ORDER BY SysStartTime DESC;