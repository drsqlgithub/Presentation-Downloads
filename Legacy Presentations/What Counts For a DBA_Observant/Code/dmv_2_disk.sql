select db_name(mf.database_id) as databaseName, mf.type_desc, mf.physical_name, 
            num_of_reads, num_of_bytes_read, io_stall_read_ms, num_of_writes ,
            num_of_bytes_written, io_stall_write_ms, io_stall,size_on_disk_bytes
from sys.dm_io_virtual_file_stats(null,null) as divfs -- all databases
            join sys.master_files as mf --all files
                on mf.database_id = divfs.database_id
                        and mf.file_id = divfs.file_id
order by databaseName, mf.physical_Name, mf.type_desc desc;



-- io stats over some time


--This view returns I/O statistics for data and log files [MDF and LDF file]. This view 
--is one of the commonly used views and will help you to identify I/O file level. This 
--will return information’s like:-
declare @resetbaseLine bit = 1;

set nocount on;
if @resetBaseLine = 1 or object_id('tempdb..#baseline') is null
    begin
        if object_id('tempdb..#baseline') is not null
            drop table #baseline;

        --initialize the baseline table
        select db_name(mf.database_id) as databaseName, mf.physical_name, 
                    num_of_reads, num_of_bytes_read, io_stall_read_ms, num_of_writes ,
                    num_of_bytes_written, io_stall_write_ms, io_stall,size_on_disk_bytes,
                    getdate() as baselineDate
        into #baseline
        from sys.dm_io_virtual_file_stats(null,null) as divfs
                    join sys.master_files as mf
                        on mf.database_id = divfs.database_id
                             and mf.file_id = divfs.file_id;
        waitfor delay '0:00:10';
    end;

 
declare @temptable table (databaseName sysname, drive char(1), physical_name  varchar(255),
		seconds  int, minutes  int, io_stall_ms bigint, io_stall_read_ms bigint, io_stall_write_ms bigint,
		num_of_reads  bigint, num_of_bytes_read bigint, num_of_mbbytes_read numeric(12,4),
		num_of_writes  bigint, num_of_bytes_written bigint, num_of_mbbytes_written numeric(12,4),
		size_change_on_disk_in_mb numeric(12,4));

--using a temp table to allow me to aggregate in in different ways
insert into @temptable 
--output the values, subtracting the baseline from the "currentLine" values :)
select	currentLine.databaseName, 
		UPPER(left(currentLine.physical_name,1)) as drive, --for almost all situations, the first 
														   --letter will be the drive letter
        currentLine.physical_name
        , dateDiff(second,#baseline.baselineDate,currentLine.baselineDate) as seconds
        , dateDiff(minute,#baseline.baselineDate,currentLine.baselineDate) as minutes
        ,currentLine.io_stall - #baseline.io_stall as io_stall_ms
        ,currentLine.io_stall_read_ms - #baseline.io_stall_read_ms as io_stall_read_ms
        ,currentLine.io_stall_write_ms - #baseline.io_stall_write_ms as io_stall_write_ms

        ,currentLine.num_of_reads - #baseline.num_of_reads as num_of_reads
        ,currentLine.num_of_bytes_read - #baseline.num_of_bytes_read as num_of_bytes_read
        ,(currentLine.num_of_bytes_read - #baseline.num_of_bytes_read) / 1024.0 /1024.0 as num_of_mbbytes_read


        ,currentLine.num_of_writes - #baseline.num_of_writes as num_of_writes
        ,currentLine.num_of_bytes_written - #baseline.num_of_bytes_written as num_of_bytes_written
        ,(currentLine.num_of_bytes_written - #baseline.num_of_bytes_written) / 1024.0 /1024.0 as num_of_mbbytes_written

        ,(currentLine.size_on_disk_bytes - #baseline.size_on_disk_bytes) / 1024.0 /1024.0 as size_change_on_disk_in_mb

from ( --the "currentLine" is the current version to compare to the baseline
            select  db_name(mf.database_id) as databaseName, mf.physical_name, 
                    num_of_reads, num_of_bytes_read, io_stall_read_ms, num_of_writes, 
                    num_of_bytes_written, io_stall_write_ms, io_stall,size_on_disk_bytes,
                    getdate() as baselineDate
            from sys.dm_io_virtual_file_stats(null,null) as divfs
                        join sys.master_files as mf
                                on mf.database_id = divfs.database_id
                                    and mf.file_id = divfs.file_id) as currentLine
                        join #baseline
                                on #baseLine.databaseName = currentLine.databaseName
                                    and #baseLine.physical_name = currentLine.physical_name
--          order by currentLine.io_stall - #baseline.io_stall desc
order by (currentLine.num_of_bytes_written - #baseline.num_of_bytes_written) + 
        (currentLine.num_of_bytes_read - #baseline.num_of_bytes_read) desc

select drive, max(seconds) as seconds, max(minutes) as minutes
		, sum(io_stall_ms) as io_stall_ms, sum(io_stall_read_ms) as io_stall_read_ms
		, sum(io_stall_write_ms) as io_stall_write_ms, sum(num_of_reads) as num_of_reads
		, sum(num_of_bytes_read) as num_of_bytes_read, sum(num_of_mbbytes_read) as num_of_mbbytes_read
		,sum(num_of_writes) as num_of_writes, sum(num_of_bytes_written) as num_of_bytes_written
		,sum(num_of_mbbytes_written) as num_of_mbbytes_written
		,sum(size_change_on_disk_in_mb) as size_change_on_disk_in_mb
from @tempTable
--where drive = 'E'
group by drive
order by io_stall_ms desc

select *
from   @tempTable
--where drive = 'E'
order by io_stall_ms desc


