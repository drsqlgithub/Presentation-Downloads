	use OurMonitor
	go
	set nocount on
	insert into demo.ourtable default values;
	go 10000 --run this batch 10000 times to produce > 100 rows per second for monitor alert...