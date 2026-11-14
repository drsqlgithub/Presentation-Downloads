/*
--was created in our 0 script for homegrown monitoring
Use OurMonitor
go
create schema demo;
go
create table demo.ourTable
(
	ourTableId int identity primary key
);
go
*/
use OurMonitor;
go
set nocount on;
truncate table demo.ourtable;
go
while 1=1 --adding 1 row per second
 begin
	insert demo.ourTable default values;
	waitfor delay '00:00:01';
 end
 GO

