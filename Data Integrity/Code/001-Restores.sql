USE [master]
RESTORE DATABASE [PerformanceDemo] FROM  DISK = N'C:\SQL\Backup\DemoDatabase.bck' WITH  FILE = 1, 
 MOVE N'QuestDemo' TO N'C:\SQL\Data\QuestDemo.mdf',  
 MOVE N'QuestDemo_log' TO N'C:\SQL\Log\QuestDemo_log.ldf',  NOUNLOAD,  REPLACE,  STATS = 5

GO


