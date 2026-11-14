--start before you explain
set nocount on;
go
use OurMonitor;
go
--flush the tables for the demo.. can't truncate due to FKs
delete from myMonitor.fileStatBatch;
delete from myMonitor.serverConfigurationBatch;
while 1=1
 begin
	--force a configuration change to show up in the log
	declare @value int = case when (select value_in_use
						from   sys.configurations
						where  name = 'show advanced options') = 1 then 0 else 1 end

	exec sp_configure 'show advanced options', @value
	reconfigure

	--run the capture procedures.  Usually would be in a job executed periodically
	exec myMonitor.fileStatsBatch$Capture; --typically hourly or so
	exec myMonitor.serverConfigurationBatch$Capture; --typically daily
	waitfor delay '00:00:10';
 end
 go