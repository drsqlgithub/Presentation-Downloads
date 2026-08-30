use OurMonitor
go

--note... For real implementation, the next two calls would need to make sure 
--the server had not been reset, or the stats cleared

--get the last batch
declare @lastFileStatBatchSequence int = (select MAX(fileStatBatchSequence) 
									       from      myMonitor.fileStatBatch);

--get a previous batch to compare to
--declare @firstFileStatBatchSequence int = @lastFileStatBatchSequence - 1;
declare @firstFileStatBatchSequence int = 1;

declare @allowTimesBeforeServerRestart bit = 0 --times before server restart could lead to 
											   --odd results due to resetting of the counters

if ( select captureTime
	 from   myMonitor.fileStatBatch 
	 where  fileStatBatchSequence = @firstFileStatBatchSequence) < 
	 (SELECT sqlserver_start_time FROM sys.dm_os_sys_info)
	  AND @allowTimesBeforeServerRestart = 0

   THROW 50000, 'The starting batch capture time is before the server was restarted, stats may not work',16

--
 select captureTime, 'StartingBatch' as sequencing
 from   myMonitor.fileStatBatch 
 where  fileStatBatchSequence = @firstFileStatBatchSequence
 union all
 select captureTime, 'EndingBatch'
 from   myMonitor.fileStatBatch 
 where  fileStatBatchSequence = @lastFileStatBatchSequence;

 --grouped by drive letter 
 select	UPPER(left(fileStat.fileName,1)) as drive
        , max(dateDiff(second,previousBatch.captureTime,fileStatBatch.captureTime)) as seconds
        , max(dateDiff(minute,previousBatch.captureTime,fileStatBatch.captureTime)) as minutes
        , sum(fileStat.totalIoStallMs - previous.totalIoStallMs) as totalIoStallMs
        , sum(fileStat.writeIoStallMs - previous.writeIoStallMs) as writeIoStallMs
        , sum(fileStat.readIoStallMs - previous.readIoStallMs) as readIoStallMs

        , sum(fileStat.readCount - previous.readCount) as readCount
        , sum(fileStat.readBytes - previous.readBytes) as readBytes
        , sum((fileStat.readBytes - previous.readBytes) / 1024.0 /1024.0) as readMB

        , sum(fileStat.writeCount - previous.writeCount) as writeCount
        , sum(fileStat.writeBytes - previous.writeBytes) as writeBytes
        , sum((fileStat.writeBytes - previous.writeBytes) / 1024.0 /1024.0) as writeMB

        , sum((fileStat.fileSizeBytes - previous.fileSizeBytes) / 1024.0 /1024.0) as fileSizeChangeMB
from	myMonitor.fileStat
		   join myMonitor.fileStatBatch
			   on fileStat.fileStatBatchSequence = fileStatBatch.fileStatBatchSequence
		   join myMonitor.fileStat as previous
			   on previous.fileName = fileStat.fileName
			      and fileStat.fileStatBatchSequence = @lastfileStatBatchSequence
	   	   join myMonitor.fileStatBatch as previousBatch
				on 	previous.fileStatBatchSequence = previousBatch.fileStatBatchSequence
				    and   previousBatch.fileStatBatchSequence = @firstFileStatBatchSequence
group by UPPER(left(fileStat.fileName,1))
order by drive;
				 
--at the row row level, database/filename
 select	fileStat.databaseName, UPPER(left(fileStat.fileName,1)) as drive,
        fileStat.fileName
        , dateDiff(second,previousBatch.captureTime,fileStatBatch.captureTime) as seconds
        , dateDiff(minute,previousBatch.captureTime,fileStatBatch.captureTime) as minutes
        ,fileStat.totalIoStallMs - previous.totalIoStallMs as totalIoStallMs
        ,fileStat.writeIoStallMs - previous.writeIoStallMs as writeIoStallMs
        ,fileStat.readIoStallMs - previous.readIoStallMs as readIoStallMs

        ,fileStat.readCount - previous.readCount as readCount
        ,fileStat.readBytes - previous.readBytes as readBytes
        ,(fileStat.readBytes - previous.readBytes) / 1024.0 /1024.0 as readMB

        ,fileStat.writeCount - previous.writeCount as writeCount
        ,fileStat.writeBytes - previous.writeBytes as writeBytes
        ,(fileStat.writeBytes - previous.writeBytes) / 1024.0 /1024.0 as writeMB

        ,(fileStat.fileSizeBytes - previous.fileSizeBytes) / 1024.0 /1024.0 as fileSizeChangeMB

from	myMonitor.fileStat
		   join myMonitor.fileStatBatch
			   on fileStat.fileStatBatchSequence = fileStatBatch.fileStatBatchSequence
		   join myMonitor.fileStat as previous
			   on previous.fileName = fileStat.fileName
			      and fileStat.fileStatBatchSequence = @lastfileStatBatchSequence
	   	   join myMonitor.fileStatBatch as previousBatch
				on 	previous.fileStatBatchSequence = previousBatch.fileStatBatchSequence
				    and   previousBatch.fileStatBatchSequence = @firstFileStatBatchSequence
order by fileName;
				 