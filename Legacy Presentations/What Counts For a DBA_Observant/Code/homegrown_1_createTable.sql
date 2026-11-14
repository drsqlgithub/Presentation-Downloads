

use OurMonitor
go


create schema myMonitor;
go

--drop table myMonitor.fileStat, myMonitor.fileStatBatch
--go
--header table to contain the a batch number and time of capture
create table myMonitor.fileStatBatch
(
	fileStatBatchSequence int constraint PKfileStatBatch primary key,
	captureTime			  datetime2(3) constraint DFLTFileStatBatch_captureTime default (SYSDATETIME())
);

create table myMonitor.fileStat --will hold one row per file
(
	fileStatBatchSequence	int  constraint FKFileStat$references$myMonitor_FileStatBatch
									references myMonitor.fileStatBatch(fileStatBatchSequence) 
														on update cascade on delete cascade,
	databaseName	sysname,
	fileName        varchar(300),
	readCount		bigint,
	readBytes		bigint,
	readIoStallMs	bigint,
	writeCount	bigint,
	writeBytes	bigint,
	writeIoStallMs	bigint,
	totalIoStallMs  bigint,
	fileSizeBytes	bigint,
	constraint PKfileStat primary key (fileStatBatchSequence, fileName)
);

--drop table myMonitor.serverConfiguration, myMonitor.serverConfigurationBatch
--go

create table myMonitor.serverConfigurationBatch
(
	serverConfigurationBatchSequence int constraint PKServerConfigurationBatch primary key,
	captureTime			  datetime2(3) constraint DFLTServerConfigurationBatch_captureTime default (SYSDATETIME())
)
create table myMonitor.serverConfiguration --will hold one row per sys.configurations value
(
	serverConfigurationBatchSequence int constraint FKserverConfiguration$references$myMonitor_serverConfiguration
										 references myMonitor.serverConfigurationBatch(serverConfigurationBatchSequence) 
														on update cascade on delete cascade,
	configurationId int,
	name			sysname,
	value			bigint,
	valueInEffect   bigint,
	constraint PKserverConfiguration primary key (serverConfigurationBatchSequence,configurationId)
)
