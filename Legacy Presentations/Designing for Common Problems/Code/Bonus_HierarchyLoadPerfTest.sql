use Patterns_Hierarchy
GO

declare 
		--@tableName sysname = 'corporate.company',
		--@tableName sysname = 'corporate.companyHierarchyId',
		--@tableName sysname = 'corporate.companyPathMethod',
		@tableName sysname = 'corporate.companyNestedSets',

		@loopCounter int = 1,
		@level int = 1,
		@levelCounter int = 1
set nocount on 

declare @levelCriteria table (level int, numNodes int)
insert into @levelCriteria
values (1,1),(2,100),(3,1000),(4,2000),(5,299)

create table #demoTree
(
	name  varchar(20),
	parentName varchar(20),
	level int
)


while 1=1
 begin
	insert into #demoTree
	select cast(@loopCounter as varchar(10)),
		   (select top 1 name from #demoTree where level = @level -1 order by newid()),
		   @level

	select @loopCounter = @loopCounter + 1
	select @levelCounter = @levelCounter + 1
	if @levelCounter > (select numNodes from @levelCriteria where level = @level)
		begin
			select @level as level, @levelCounter - 1 as rowsCreatedInLevel
			select @level = @level + 1
			select @levelCounter = 1
		end
	if @level > (select max(level) from @levelCriteria)
		break

 end
 select @loopCounter -1 as rowsCreated

execute ('truncate table ' + @tableName)

declare @loadCursor cursor, @query nvarchar(4000)
set @loadCursor = cursor for 
		select 'EXEC ' + @tablename + '$insert @name = ''' + name + ''', @parentCompanyName = ' + COALESCE('''' + parentName+ '''', 'NULL') 
		from #demoTree
open @loadCursor 
while 1=1
 begin
	fetch next from @loadCursor into @query
	if @@fetch_status <> 0
		break
	select @query
	EXEC(@query)
 end


drop table #demoTree
