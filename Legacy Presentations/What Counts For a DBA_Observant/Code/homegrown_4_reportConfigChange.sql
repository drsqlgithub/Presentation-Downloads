
use OurMonitor;
go

select captureTime, serverConfiguration.name, serverConfiguration.value
from   myMonitor.serverConfiguration
		join myMonitor.serverConfigurationBatch
			on serverConfiguration.serverConfigurationBatchSequence = 
				serverConfigurationBatch.serverConfigurationBatchSequence 
where  name = 'show advanced options';
go

select afterBatch.CaptureTime, after.name, after.value, after.valueInEffect,
	   before.name, before.value, before.valueInEffect, beforeBatch.CaptureTime as BeforeCaptureTime
from   myMonitor.serverConfiguration as after
		 join myMonitor.serverConfiguration as before
			on after.configurationId = before.configurationId
			   and before.serverConfigurationBatchSequence - 1 = --get the previous sequence batch
										after.serverConfigurationBatchSequence 
		 join myMonitor.serverConfigurationBatch as afterBatch
			on afterBatch.serverConfigurationBatchSequence = 
				after.serverConfigurationBatchSequence 
		 join myMonitor.serverConfigurationBatch as beforeBatch
			on beforeBatch.serverConfigurationBatchSequence = 
				before.serverConfigurationBatchSequence 
where (after.value <> before.value --show only rows where a change has occurred
	   or  after.valueInEffect <> before.valueInEffect)
  and afterBatch.CaptureTime > dateadd(week,-1,sysdatetime()); --changes for the last week


