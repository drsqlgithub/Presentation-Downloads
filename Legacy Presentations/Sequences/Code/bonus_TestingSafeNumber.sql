

set nocount on
declare @i int = 0
while (1=1)
 begin
	set @i = @i + 1
	if @i > 200000000
		break

	declare @accountNumber char(12)
	exec demo.noEvil$getNextAccountNumber @accountNumber = @accountNumber output

	INSERT INTO demo.noEvil (accountNumber)
	SELECT  @accountNumber AS accountNumber
 end

 /* test query

select count(*) as numRows, max(accountNumber) as accountNumber,
	 datediff (millisecond,min(rowcreateTime),max(rowCreateTime)) * 1.0 / 1000 as seconds,
	 datediff (millisecond,min(rowcreateTime),max(rowCreateTime)) * 1.0 / 1000 / 60 as minutes
from   demo.noEvil(nolock)

select top 10 datediff (millisecond,gap.rowcreateTime,noEvil.rowCreateTime) as createTimeGap
	  , gap.accountNumber, noEvil.accountNumber
from   demo.noEvil(nolock)
		 join demo.noEvil (nolock) as gap
			on gap.noEvilId = noEvil.noEvilId - 1
order by createTimeGap desc
GO
*/