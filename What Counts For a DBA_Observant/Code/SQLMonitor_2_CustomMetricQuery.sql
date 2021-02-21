use OurMonitor;
go

--non-system based custom metric
select count(*)
from   demo.ourTable with (READUNCOMMITTED)