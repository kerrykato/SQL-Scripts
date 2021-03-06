begin tran

set nocount on

declare @mfstcode nvarchar(25)
declare @startdate datetime
declare @enddate datetime
declare @msg nvarchar(200)

--set @mfstcode = '524-528 ret'
set @enddate = '8/30/2012'
set @startdate = '8/27/2012'


declare manifest_cursor cursor
for 
	select distinct ManifestCode
	from support_ReturnsManifest_Import

open manifest_cursor
fetch next from manifest_cursor into @mfstcode
while @@FETCH_STATUS = 0
begin

	create table #manifestsToInsert (ManifestTemplateId int, ManifestDate datetime )
	
	;with cteDateRange(Date)
		AS
		(
			SELECT
				@StartDate [Date]
			UNION ALL
			SELECT
				DATEADD(day, 1, Date) Date
			FROM
				cteDateRange
			WHERE
				Date < @EndDate
		)
	insert into #manifestsToInsert( ManifestTemplateId, ManifestDate )
	select mt.ManifestTemplateId, [Date]--, m.ManifestID
	from scManifestTemplates mt
	join scManifestSequenceTemplates mst
		on mt.ManifestTemplateId = mst.ManifestTemplateId
	join cteDateRange dt
		on 1 = 1
	left join scManifests m
		on mt.ManifestTemplateId = m.ManifestTemplateId
		and dt.Date = m.ManifestDate
	where (
			( @mfstcode is not null and  mt.MTCode = @mfstcode)
			or 
			( @mfstcode is null and mt.ManifestTemplateId > 0 and mt.MTDeleted = 0 )
		)
	and dbo.scGetDayFrequency([Date]) & mst.Frequency > 0
	and m.ManifestID is null

	-- Insert the manifests if they do not exist
	insert scManifests (
		 CompanyID
		,DistributionCenterId
		,MfstCode
		,MfstName
		,MfstDescription
		,MfstNotes
		,MfstImported
		,MfstCustom1
		,MfstCustom2
		,MfstCustom3
		,MfstActive
		,DeviceId
		,ManifestTypeId
		,ManifestOwner
		,ManifestDate
		,ManifestTemplateId
	)
	select
		 1
		,1
		,mt.MTCode
		,mt.MTName
		,mt.MTDescription
		,mt.MTNotes
		,mt.MTImported
		,mt.MTCustom1
		,mt.MTCustom2
		,mt.MTCustom3
		,1
		,mt.DeviceId
		,mt.ManifestTypeId
		,mt.MTOwner
		,tmp.ManifestDate
		,mt.ManifestTemplateId
	from #manifestsToInsert tmp
	join scManifestTemplates mt
		on tmp.ManifestTemplateId = mt.ManifestTemplateId
	set @msg = 'Inserted ' + cast(@@rowcount as varchar) + ' historical manifest records for manifest ''' + @mfstcode + ''''
	print @msg
	--exec syncSystemLog_Insert 2, 0, 1, @msg

	select
		 mt.MTCode
		,mt.MTName
		, u.UserName as [MTOwner]
		, d.DeviceCode
		, convert(varchar, tmp.ManifestDate, 1) as [ManifestDate]
	from #manifestsToInsert tmp
	join scManifestTemplates mt
		on tmp.ManifestTemplateId = mt.ManifestTemplateId
	left join Users u
		on mt.MTOwner = u.UserID
	left join nsDevices d
		on mt.DeviceId = d.DeviceId
		

	;with cteDateRange(Date)
		AS
		(
			SELECT
				@StartDate [Date]
			UNION ALL
			SELECT
				DATEADD(day, 1, Date) Date
			FROM
				cteDateRange
			WHERE
				Date < @EndDate
	),
	cteAlreadyOnManifest
	as (
		select m.ManifestID, ms.ManifestSequenceTemplateId, ms.AccountPubId, ms.Sequence
		from scManifests m
		join cteDateRange dt
			on m.ManifestDate = dt.Date
		join scManifestSequences ms
			on m.ManifestID = ms.ManifestId	
		where m.MfstCode = @mfstcode
		)
	select m.ManifestID, mst.ManifestSequenceTemplateId, msi.AccountPubId, msi.Sequence
	into #manifestSequencesToInsert
	from scManifests m
	join cteDateRange dt
		on m.ManifestDate = dt.Date
	join scManifestTemplates mt
		on m.ManifestTemplateId = mt.ManifestTemplateId
	join scManifestSequenceTemplates mst
		on mt.ManifestTemplateId = mst.ManifestTemplateId
		and dbo.scGetDayFrequency(m.ManifestDate) & mst.Frequency > 0
	join scManifestSequenceItems msi
		on mst.ManifestSequenceTemplateId = msi.ManifestSequenceTemplateId
	left join cteAlreadyOnManifest cte
		on msi.ManifestSequenceTemplateId = cte.ManifestSequenceTemplateId
		and msi.AccountPubId = cte.AccountPubId
	where (
			( @mfstcode is not null and  mt.MTCode = @mfstcode)
			or 
			( @mfstcode is null and mt.ManifestTemplateId > 0  and mt.MTDeleted = 0 )
		)
	and cte.AccountPubId is null


	insert scManifestSequences ( ManifestId, ManifestSequenceTemplateId, AccountPubId, Sequence )
	select *
	from #manifestSequencesToInsert
	set @msg = 'Inserted ' + cast(@@rowcount as varchar) + ' manifest sequence records for manifest ''' + @mfstcode + ''''
	print @msg

	select m.MfstCode, convert(varchar, m.ManifestDate, 1) as [ManifestDate], COUNT(*) as [# of AcctPubs Added]
	from #manifestSequencesToInsert tmp
	join scManifests m
		on tmp.ManifestID = m.ManifestID
	group by m.MfstCode, m.ManifestDate
	order by m.MfstCode, m.ManifestDate

	select m.MfstCode, convert(varchar, m.ManifestDate, 1) as [ManifestDate], a.AcctCode, p.PubShortName, tmp.Sequence
	from #manifestSequencesToInsert tmp
	join scManifests m
		on tmp.ManifestID = m.ManifestID
	join scAccountsPubs ap
		on tmp.AccountPubId = ap.AccountPubID
	join scAccounts a
		on a.AccountID = ap.AccountId
	join nsPublications p
		on ap.PublicationId = p.PublicationID
	order by m.MfstCode, m.ManifestDate, tmp.Sequence

	drop table #manifestsToInsert
	drop table #manifestSequencesToInsert

fetch next from manifest_cursor into @mfstcode
end

close manifest_cursor
deallocate manifest_cursor

	/*
	;with cteDateRange(Date)
		AS
		(
			SELECT
				@StartDate [Date]
			UNION ALL
			SELECT
				DATEADD(day, 1, Date) Date
			FROM
				cteDateRange
			WHERE
				Date < @EndDate
		)
	   , cteDefaultDraws
	   as ( 
		 select distinct ap.AccountId, ap.PublicationId, dt.Date, dd.DrawWeekday, dd.DrawAmount
		 from scManifestTemplates mt
		 join scManifestSequenceTemplates mst
			on mt.ManifestTemplateId = mst.ManifestTemplateId
		join scManifestSequenceItems msi
			on mst.ManifestSequenceTemplateId = msi.ManifestSequenceTemplateId
		join cteDateRange dt
			on 1 = 1	
		join scAccountsPubs ap
			on msi.AccountPubId = ap.AccountPubID
		join scDefaultDraws dd
			on dd.AccountId = ap.AccountID
			and dd.PublicationId = ap.PublicationId		
			and dd.DrawWeekday = DATEPART(dw, dt.Date)
		)
		insert into scDraws ( CompanyID, DistributionCenterID, AccountID, PublicationID, DrawWeekday, DrawDate, DrawAmount, DrawRate, DeliveryDate )
		select 1, 1, dd.AccountID, dd.PublicationID, dd.DrawWeekday, dd.Date, dd.DrawAmount, 0.0, dd.Date
		from cteDefaultDraws dd
		left join scDraws d
			on dd.AccountId = d.AccountID
			and dd.PublicationId = d.PublicationID
			and dd.DrawWeekday = d.DrawWeekday
			and dd.Date = d.DrawDate
		where d.DrawID is null
		--group by dd.AccountID, dd.PublicationID, dd.DrawWeekday, dd.Date
		--having COUNT(*) > 1
		set @msg = 'Inserted ' + cast(@@rowcount as varchar) + ' draw records records'
		print @msg
	*/
	
commit tran