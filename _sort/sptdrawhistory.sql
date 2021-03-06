USE [nsdb_sample]
GO
/****** Object:  StoredProcedure [dbo].[scForecastEditDetailSalesHistory_Select]    Script Date: 05/06/2011 12:49:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
/*
	scForecastEditDetailSalesHistory_Select

	Used by the DrawHistory class to display the sales history for a forecasted draw.

	exec scForecastEditDetailSalesHistory_Select 2, 1, '10-06-2008', 31

--	$History: /Gazette/Database/Scripts/Sprocs/dbo.scForecastEditDetailSalesHistory_Select.prc $
-- 
-- ****************** Version 3 ****************** 
-- User: jpeaslee   Date: 2008-10-16   Time: 09:32:01-07:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 6303 Missing draw dates not obvious on forecast review draw history 
-- page 
-- 
-- ****************** Version 2 ****************** 
-- User: jpeaslee   Date: 2008-10-14   Time: 14:37:23-07:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 6323 
-- 
-- ****************** Version 1 ****************** 
-- User: jpeaslee   Date: 2008-09-15   Time: 06:57:50-07:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- 
*/
ALTER proc [dbo].[scForecastEditDetailSalesHistory_Select]
	@AccountId		int
,	@PublicationId	int
,	@DrawDate		datetime
,	@ForecastRuleId int
as
begin
set nocount on

declare @DrawDateMin datetime
declare @DrawDateMax datetime

exec NormalizeStartStopDates @DrawDate, @DrawDate, @DrawDateMin output, @DrawDateMax output

--parameter sniffing
declare @local_AccountId int
declare @local_PublicationId int

set @local_AccountId = @AccountId
set @local_PublicationId = @PublicationId


-- We assume caller has verified that the change type is forecast.
declare @tmpdate datetime
declare @weekcount int
declare @nweeks int

-- Make a table of based-on dates.  Dates are descending, week numbers are ascending, e.g.:
--   nweek  drawdate
--     1    07-29-2008
--     2    07-22-2008
--     3    07-15-2008
--     4    07-08-2008
-- This conforms to the way we use scForecastWeightingTables.wtWeek.

create table #basedondates (nweek int, drawdate datetime)

set @tmpdate = dateadd(wk, -1, @DrawDateMin)
set @weekcount = 0
select @nweeks = FRBasedOnWeeks from scForecastRules where ForecastRuleId = @ForecastRuleId

while @weekcount < @nweeks
begin
	set @weekcount = @weekcount + 1
	insert #basedondates values (@weekcount, @tmpdate)
	set @tmpdate = dateadd(wk, -1, @tmpdate)
end

create table #draws (
	  DrawId int
	, AccountId int
	, PublicationId int
	, DrawDate datetime
	, DrawWeekday int 
	, DrawAmount int
	, AdjAmount int
	, AdjAdminAmount int
	, RetAmount int
) 

insert into #draws
select d.DrawID, d.AccountID, d.PublicationID, d.DrawDate, d.DrawWeekday, d.DrawAmount, d.AdjAmount, d.AdjAdminAmount, d.RetAmount 
from scDraws d
where d.DrawDate between @DrawDateMin and @DrawDateMax
and d.AccountID = @local_AccountId
and d.PublicationID = @local_PublicationId
and d.DrawWeekday = datepart(dw, @DrawDate)

select
	 convert(varchar, b.DrawDate, 101) as DrawDate
	,w.wtWeight                        as Weight
	,d.DrawAmount                      as DrawAmount
	,d.AdjAmount                       as AdjAmount
	,d.AdjAdminAmount                  as AdjAdminAmount
	,d.RetAmount                       as [Returns]
	,isnull(d.DrawAmount, 0) 
	  + isnull(d.AdjAmount, 0)
	  + isnull(d.AdjAdminAmount, 0)
	  - isnull(d.RetAmount, 0)         as NetSales
	,edt.ExceptionDateTypeName         as ExceptionDateTypeName
	,ed.Headline                       as Headline
	,ed.Note                           as Note
	,isnull(edt.ExceptionDateTypeColor, 'black') as TextColor
from #basedondates b
left join #draws d on b.drawdate = d.drawdate 
				   and d.accountid = @local_AccountId
				   and d.publicationid = @local_PublicationId
left join dbo.scForecastWeightingTables w on w.ForecastRuleId = @ForecastRuleId
										 and w.wtWeek = b.nweek
left join scForecastExceptionDates ed on ed.ExceptionDate = b.DrawDate
left join scForecastExceptionDateTypes edt on ed.ExceptionDateTypeId = edt.ExceptionDateTypeId
order by b.DrawDate desc

drop table #basedondates

set nocount off
end

