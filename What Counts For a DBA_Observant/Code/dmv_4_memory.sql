-- Good basic information about memory amounts and state
SELECT total_physical_memory_kb, available_physical_memory_kb, 
       total_page_file_kb, available_page_file_kb, 
       system_memory_state_desc
FROM sys.dm_os_sys_memory WITH (NOLOCK) OPTION (RECOMPILE);
GO

--Performance counter, amount of time data stays in cache on average
SELECT cntr_value AS 'Page Life Expectancy'
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager'
AND counter_name = 'Page life expectancy' 


--Buffer Cache Hit Ratio, ratio of hits to the buffer cache versus the disk
select sum(cast(case when counter_name = 'Buffer cache hit ratio' then cntr_value else 0 end as numeric))/
sum(case when counter_name = 'Buffer cache hit ratio base' then cntr_value else 0 end)
		as cacheHitRatio	
from   sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager'
 and  counter_name like 'Buffer cache hit ratio%'

---------------------------------------------------------------
--won't run these for time, but it gives examples of other performance counters you can access
/*
--http://technet.microsoft.com/en-us/library/ms189628.aspx
--Indicates the number of requests per second that had to wait for a free page.

declare @cntr_value int,
		@timeOfSample datetime

select @cntr_value = cntr_value,
		@timeOfSample = getdate()
from   sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager'
 and counter_name = 'Free list stalls/sec'

waitfor delay '00:00:02'
select --cntr_value - @cntr_value, datediff(millisecond,@timeOfSample,getdate()),
		((cntr_value - @cntr_value) * 1.0) / datediff(millisecond,@timeOfSample,getdate()) * 1000.0 as [SQLServer:Buffer Manager:Free list stalls/sec]
from   sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager'
 and counter_name = 'Free list stalls/sec'
go
----------------------------------------------------------------

--Indicates the number of requests per second to find a page in the buffer pool.
declare @cntr_value bigint,
		@timeOfSample datetime

select @cntr_value = cntr_value,
		@timeOfSample = getdate()
from   sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager'
 and counter_name = 'Page lookups/sec'

waitfor delay '00:00:02'

select -- cntr_value - @cntr_value, datediff(millisecond,@timeOfSample,getdate()),
		((cntr_value - @cntr_value) * 1.0) / datediff(millisecond,@timeOfSample,getdate()) * 1000.0 as [SQLServer:Buffer Manager:Page lookups/sec]
from   sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager'
 and counter_name = 'Page lookups/sec'

----------------------------------------------------------------
go
                                                                                                    
-- Memory Grants Outstanding value for default instance
SELECT cntr_value AS [Memory Grants Outstanding]                                                                                                      
FROM sys.dm_os_performance_counters WITH (NOLOCK)
WHERE [object_name] = N'SQLServer:Memory Manager' -- Modify this if you have named instances
AND counter_name = N'Memory Grants Outstanding' OPTION (RECOMPILE);

-- Memory Grants Outstanding above zero for a sustained period is a very strong indicator of memory pressure

-- Memory Grants Pending value for default instance
SELECT cntr_value AS [Memory Grants Pending]                                                                                                      
FROM sys.dm_os_performance_counters WITH (NOLOCK)
WHERE [object_name] = N'SQLServer:Memory Manager' -- Modify this if you have named instances
AND counter_name = N'Memory Grants Pending' OPTION (RECOMPILE);
*/

/*

-- SQL Server Process Address space info 
SELECT	physical_memory_in_use_kb,     -- 
		page_fault_count,              -- 
		memory_utilization_percentage, -- BOL: Specifies the percentage of committed memory that is in the working set. Not nullable.
		process_physical_memory_low,   -- bit, 1 bad, 0 good
        process_virtual_memory_low,     --

	    large_page_allocations_kb,     -- http://blogs.msdn.com/b/psssql/archive/2009/06/05/sql-server-and-large-pages-explained.aspx
		locked_page_allocations_kb    -- see above for some explanation
		--there are more, but couldn't find good links :)
FROM sys.dm_os_process_memory WITH (NOLOCK) OPTION (RECOMPILE);
GO
*/