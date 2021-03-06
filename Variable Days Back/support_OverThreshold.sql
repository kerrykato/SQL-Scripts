SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO

create procedure [dbo].[support_scThreshholdDate] (
	@currentDate datetime,		-- normally this is today's date
	@periodLength int,			-- days in billing period
	@periodStartDate datetime,	-- start date of initial period, in case period is more than one week
	@cutoffDay int				-- day in period where return threshhold changes (one-based)
)
AS
/*=========================================================
	Calculate the return threshhold date based on configuration values
	and the current date.  This is also known as "variable days back".

	The calculation is based on a billing period and a weekday
	on which to cut off returns for th period.

	If today is on or after the cutoff day, the earliest day to allow 
	returns (the threshhold date) is the first day of the current period.

	If today is before the cutoff day, the threshhold is the first day
	of the preceding period.

	NOTE!! Billing periods are assumed to be whole weeks, not fractions of
	a week.
	
	Date		Author	Reference	Description
    --------	------	---------	-----------
	03/22/07	johnp	Case 245	Created, based on procedure scReturnThreshhold, which is now obsolete.
==========================================================*/
BEGIN
	declare @msg varchar(200)	
	declare @sDate varchar(10)
	declare @daysFromStart int			-- days from start of initial period to target date
	declare @thisPeriodNum int			-- period number of target date's period
	declare @thisPeriodStart datetime	-- starting date of period containing target date
	declare @dayInPeriod int			-- current date offset in its period
	declare @returnThreshhold datetime

	-- Remove time portion of @currentDate
	set @sDate = convert(varchar(10), @currentDate, 101)
	set @currentDate = convert( datetime, @sDate )

	set @daysFromStart = datediff(day, @periodStartDate, @currentDate)
	print '@daysFromStart=' + cast(@daysFromStart as varchar)
	
	set @thisPeriodNum = floor(@daysFromStart / @periodLength)
	print '@thisPeriodNum=' + cast(@thisPeriodNum as varchar)
	
	set @thisPeriodStart = dateadd(day, (@thisPeriodNum * @periodLength), @periodStartDate)
	print '@thisPeriodStart=' + convert(varchar, @thisPeriodStart, 1)
	
	set @dayInPeriod = datediff(day, @thisPeriodStart, @currentDate) + 1 -- one-based
	print '@dayInPeriod=' + cast(@dayInPeriod as varchar)
	
	-- Note that @cutoffDay is a number of days from the start of the period, not a day-of-the-week.
	if @dayInPeriod >= @cutoffDay
		set @returnThreshhold = @thisPeriodStart
	else
		set @returnThreshhold = dateadd(day, (@periodLength * -1), @thisPeriodStart)

	print '@returnThreshhold=' + convert(varchar, @returnThreshhold, 1)

END

--select dateadd(d, -63, '1/26/2012')
exec [dbo].[support_scThreshholdDate] '1/26/2012', 63, '1/26/2012', 64