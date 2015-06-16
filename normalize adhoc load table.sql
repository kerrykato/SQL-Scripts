declare @dayofweek nvarchar(9)
declare @date datetime
set @dayofweek = 'Sunday'
	
select @date = case @dayofweek
		when 'Monday' then dateadd( week, datediff(week,0,getdate()), 7	)
		when 'Tuesday' then dateadd( week, datediff(week,0,getdate()), 8	)
		when 'Wednesday' then dateadd( week, datediff(week,0,getdate()), 9	)
		when 'Thursday' then dateadd( week, datediff(week,0,getdate()), 10	)
		when 'Friday' then dateadd( week, datediff(week,0,getdate()), 11	)
		when 'Satday' then dateadd( week, datediff(week,0,getdate()), 12	)
		when 'Sunday' then dateadd( week, datediff(week,0,getdate()), 13	)
		end

;with cte
as (
	select 1 as [DrawWeekday]
		, convert(varchar, @date, 1) as [DrawDate]
		, [AcctCode] as [AcctCode]
		, [PubCode] as [PubCode]
		, [SUN] as DrawAmount
	from support_AcctDraw_Init_Load ld
	union all 
	select [DrawWeekday] + 1
		, convert(varchar, dateadd(d, 1, [DrawDate]), 1) as [DrawDate]
		, ld.[AcctCode] as [AcctCode]
		, ld.[PubCode] as [PubCode]
		, case [DrawWeekday] + 1
			when 2 then [MON]
			when 3 then [TUE]
			when 4 then [WED]
			when 5 then [THU]
			when 6 then [FRI]
			when 7 then [SAT]
			end as [DrawAmount]

	from cte
	join support_AcctDraw_Init_Load ld
		on cte.AcctCode = ld.AcctCode
		and cte.PubCode = ld.PubCode
	where
		[DrawWeekday] + 1 <= 7
	)
select *
from cte
order by AcctCode