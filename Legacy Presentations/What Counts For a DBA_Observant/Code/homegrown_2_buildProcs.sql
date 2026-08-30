--already pre-created

use OurMonitor
go
create procedure myMonitor.fileStatsBatch$Capture
as 

 begin
	set xact_abort on --if there is an error, stop the batch and rollback
    begin transaction

	insert into myMonitor.fileStatBatch (fileStatBatchSequence)
	select COALESCE(MAX(fileStatBatchSequence) + 1,1)
	from   myMonitor.fileStatBatch

	--didn't use identity because I don't want gaps to make reporting 
	--a bit easier. Could renumber if needed to
	declare @fileStatBatchSequence int
	set     @fileStatBatchSequence = (select MAX(fileStatBatchSequence)
									  from   myMonitor.fileStatBatch)
    
	--just grab the values and put in table.
    insert into myMonitor.fileStat
           (fileStatBatchSequence,databaseName,fileName
           ,readCount,readBytes,readIoStallMs
           ,writeCount,writeBytes,writeIoStallMs
           ,totalIoStallMs,fileSizeBytes)
	select @fileStatBatchSequence, db_name(mf.database_id) as databaseName, mf.physical_name, 
				num_of_reads, num_of_bytes_read, io_stall_read_ms, num_of_writes ,
				num_of_bytes_written, io_stall_write_ms, io_stall,size_on_disk_bytes
	from sys.dm_io_virtual_file_stats(null,null) as divfs
				join sys.master_files as mf
					on mf.database_id = divfs.database_id
						 and mf.file_id = divfs.file_id

	commit transaction
 end
go

create procedure myMonitor.serverConfigurationBatch$Capture
as 

 begin
 	set xact_abort on --if there is an error, stop the batch and rollback
    begin transaction

	insert into myMonitor.serverConfigurationBatch (serverConfigurationBatchSequence)
	select COALESCE(MAX(serverConfigurationBatchSequence) + 1,1)
	from   myMonitor.serverConfigurationBatch

	--didn't use identity because I don't want gaps to make reporting 
	--a bit easier. Could renumber if needed to
	declare @serverConfigurationBatchSequence int
	set     @serverConfigurationBatchSequence = (select MAX(serverConfigurationBatchSequence)
									  from   myMonitor.serverConfigurationBatch)

	--just grab the values and put in table.	
	insert into myMonitor.serverConfiguration (serverConfigurationBatchSequence,configurationId,name, value, valueInEffect)
	select @serverConfigurationBatchSequence, configuration_id, name, cast(value as bigint), cast(value_in_use as bigint)
	from   sys.configurations

	commit transaction
 end
go

