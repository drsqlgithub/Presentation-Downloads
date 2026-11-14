--http://blogs.msdn.com/sqlcat/archive/2005/09/05/461199.aspx
---- Total waits are wait_time_ms


--high signal waits are an indicator of CPU pressure since last restart
Select signal_wait_time_ms=sum(signal_wait_time_ms)
          ,cast(100.0 * sum(signal_wait_time_ms) / sum (wait_time_ms) as numeric(20,2)) as [%signal (cpu) waits]
          ,sum(wait_time_ms - signal_wait_time_ms) as [resource_wait_time_ms]
          ,cast(100.0 * sum(wait_time_ms - signal_wait_time_ms) / sum (wait_time_ms) as numeric(20,2)) as [%resource waits]
From sys.dm_os_wait_stats
GO

-- Get Average Task Counts (run multiple times) for the user process schedulers
SELECT  AVG(current_tasks_count) AS avg_task_count,
		AVG(runnable_tasks_count) AS avg_runnable_task_count,
		AVG(pending_disk_io_count) AS avg_pending_disk_io_count
FROM sys.dm_os_schedulers WITH (NOLOCK)
WHERE scheduler_id < 255 OPTION (RECOMPILE);
GO

--individual schedulers
select *
from sys.dm_os_schedulers
WHERE scheduler_id < 255 OPTION (RECOMPILE);
go

--glenn berry's website
--http://sqlserverperformance.wordpress.com/2010/04/20/a-dmv-a-day-%e2%80%93-day-21/

-- Get CPU Utilization History for last 256 minutes (in one minute intervals)
-- This version works with SQL Server 2008 and above
DECLARE @ts_now bigint = (SELECT cpu_ticks/(cpu_ticks/ms_ticks)
						  FROM sys.dm_os_sys_info WITH (NOLOCK)); 

SELECT TOP(256) SQLProcessUtilization AS [SQL Server Process CPU Utilization], 
                SystemIdle AS [System Idle Process], 
                100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization], 
                DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event Time] 
FROM ( 
	  SELECT record.value('(./Record/@id)[1]', 'int') AS record_id, 
			record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') 
			AS [SystemIdle], 
			record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 
			'int') 
			AS [SQLProcessUtilization], [timestamp] 
	  FROM ( 
			SELECT [timestamp], CONVERT(xml, record) AS [record] 
			FROM sys.dm_os_ring_buffers WITH (NOLOCK)
			WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
			AND record LIKE N'%<SystemHealth>%') AS x 
	  ) AS y 
ORDER BY record_id DESC OPTION (RECOMPILE);
