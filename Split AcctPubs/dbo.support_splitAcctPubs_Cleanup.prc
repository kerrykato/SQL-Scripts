if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[support_splitAcctPubs_Cleanup]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[support_splitAcctPubs_Cleanup]
GO

create  procedure [dbo].[support_splitAcctPubs_Cleanup]
	@minmax nvarchar(3) = 'min'  --[min|max]
as
/*=========================================================
    dbo.support_splitAcctPubs_Cleanup.PRC
    
	Note:  If this is run just prior to running the Manifest Sequence Finalizer it should 
			not be necessary to clean up splits in the Manifest tables

	$History:  $

==========================================================*/
begin
	set nocount on

	declare @msg nvarchar(1024)

	select @msg = 'support_splitAcctPubs_Cleanup:  Procedure started...'
	print @msg
	exec syncSystemLog_Insert @moduleId=2, @SeverityId=0, @CompanyId=1, @Message=@msg
	
	select splits.ManifestTemplateId, splits.ManifestSequenceTemplateId, splits.AccountId
		, msi.ManifestSequenceItemId 
		, ap.AccountPubId
		, ap.PublicationId
		, Sequence
	into #splitDetails
	from (  
		--|  splits
		select ManifestTemplateId, ManifestSequenceTemplateId, AccountId 
		from (
			--|  prelim
			select mt.ManifestTemplateId, mst.ManifestSequenceTemplateId, ap.AccountId, msi.Sequence  
			from scManifestTemplates mt
			join scManifestSequenceTemplates mst
				on mt.ManifestTemplateId = mst.ManifestTemplateId
			join scManifestSequenceItems msi
				on mst.ManifestSequenceTemplateId = msi.ManifestSequenceTemplateId
			join scAccountsPubs ap
				on msi.AccountPubId = ap.AccountPubId
			group by mt.ManifestTemplateId, mst.ManifestSequenceTemplateId, ap.AccountId, msi.Sequence
		 ) as [prelim]  
		group by ManifestTemplateId, ManifestSequenceTemplateId, AccountId 
		having count(*) > 1 
		) as [splits]
	join scAccountsPubs ap
		on splits.AccountId = ap.AccountId
	join scManifestSequenceItems msi
		on ap.AccountPubId = msi.AccountPubId
		and splits.ManifestSequenceTemplateId = msi.ManifestSequenceTemplateId
	order by 1, 2, 3



	select splitDetails.ManifestTemplateId, splitDetails.ManifestSequenceTemplateId, splitDetails.AccountId
		, splitDetails.ManifestSequenceItemId
		, splitDetails.Sequence
		, case @minmax	
			when 'min' then MinMax.MinSequence
			when 'max' then MinMax.MaxSequence
			else MinMax.MinSequence 
			end as [NewSequence]
	into #preview
	from #splitDetails splitDetails
	join scAccounts a
		on splitDetails.AccountId = a.AccountId
	join nsPublications p
		on splitDetails.PublicationId = p.PublicationId
	join scManifestTemplates mt
		on splitDetails.ManifestTemplateId = mt.ManifestTemplateId
	join (
			--| Get the Min/Max sequences from #splitDetails to be used in case scManifestLoad does not have a Sequence of record
			select ManifestTemplateId, AccountId, min(Sequence) as [MinSequence], max(Sequence) as [MaxSequence]
			from #splitDetails
			group by ManifestTemplateId, AccountId
		) as MinMax
		on splitDetails.ManifestTemplateId = MinMax.ManifestTemplateId
		and splitDetails.AccountId = MinMax.AccountId

	insert into syncSystemLog ( 
		  LogMessage
		, SLTimeStamp
		, ModuleId
		, SeverityId
		, CompanyId
		, [Source]
		--, GroupId 
		)
	select 
		 'Account ''' + a.AcctCode + ''' on Manifest/Sequence ''' + mt.MTCode + '/' + mst.Code
		  + ''' was split between drop sequences.  Publications were consolidated on drop sequence '
		  + case @minmax	
			when 'min' then cast(MinMax.MinSequence as varchar)
			when 'max' then cast(MinMax.MaxSequence as varchar)
			else cast(MinMax.MinSequence as varchar) 
			end  --cast(MaxSequence as varchar)
		  + ' (' + @minmax + ').  (ManifestTemplates).'
			as [LogMessage]
		, getdate() as [SLTimeStamp]
		, 2 as [ModuleId]	--|2=SingleCopy
		, 1 as [SeverityId] --|1=Warning
		, 1 as [CompanyId]
		, N'' as [Source]   --|nvarchar(100)
		--, newid() as [GroupId]
	from #splitDetails splitDetails
	join scAccounts a
		on splitDetails.AccountId = a.AccountId
	join nsPublications p
		on splitDetails.PublicationId = p.PublicationId
	join (
			--| Get the Min/Max sequences from #splitDetails to be used in case scManifestLoad does not have a Sequence of record
			select ManifestTemplateId, AccountId, min(Sequence) as [MinSequence], max(Sequence) as [MaxSequence]
			from #splitDetails
			group by ManifestTemplateId, AccountId
		) as MinMax
		on splitDetails.ManifestTemplateId = MinMax.ManifestTemplateId
		and splitDetails.AccountId = MinMax.AccountId
	join scManifestTemplates mt
		on splitDetails.ManifestTemplateId = mt.ManifestTemplateId
	join scManifestSequenceTemplates mst
		on splitDetails.ManifestSequenceTemplateId = mst.ManifestSequenceTemplateId
	where splitDetails.Sequence <> MaxSequence	
	order by MTCode--a.AcctCode, p.PubShortName

	update scManifestSequenceItems
	set Sequence = new.NewSequence
	from scManifestSequenceItems msi
	join #preview new
		on msi.ManifestSequenceItemId = new.ManifestSequenceItemId
	where msi.Sequence <> new.NewSequence

	set @msg = cast(@@rowcount as varchar) + ' sequence item records updated'
	print @msg
	exec syncSystemLog_Insert @moduleId=2, @SeverityId=0, @CompanyId=1, @Message=@msg
		
	--| Cleanup
	drop table #splitDetails
	drop table #preview


	select @msg = 'support_splitAcctPubs_Cleanup:  Procedure completed.'
	print @msg
	exec syncSystemLog_Insert @moduleId=2, @SeverityId=0, @CompanyId=1, @Message=@msg

end
GO

grant execute on [dbo].[support_splitAcctPubs_Cleanup] to [nsuser]
GO
