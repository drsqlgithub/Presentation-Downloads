/*
Topics (Enough to fill more than 1 hour):
`
--Row Level Security
--==================

-- Using 2016 Feature
	-- Mechanics
	-- Scaling
--Using Legacy Tools
--Dynamic Data Masking

Code can be found at  http://drsql.org/presentations

If you want to contact me, DRSQL:
	DRSQL.org  (Today's code and more located here via Dropbox links)
	drsql@hotmail.com or louis@drsql.org
	Twitter:drsql

*/


IF EXISTS (SELECT * FROM sys.databases WHERE name = 'TestRowLevelSecurity')
	ALTER DATABASE TestRowLevelSecurity SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE master
GO
DROP DATABASE IF EXISTS TestRowLevelSecurity
GO
CREATE DATABASE TestRowLevelSecurity
GO
USE TestRowLevelSecurity
GO

SELECT 'Well can you?' AS [Can you read this?], @@version;
GO