IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[support_scManifestSequence_Finalizer_ByManifest]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[support_scManifestSequence_Finalizer_ByManifest]
GO

SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[support_scManifestSequence_Finalizer_ByManifest]
	@manifestDate datetime
	, @mfstCode nvarchar(20)
AS

	declare @msg varchar(200)

	set nocount on


	select 
		mt.ManifestTemplateId, mt.MTCode, mst.Frequency
			, @manifestDate, dbo.scGetDayFrequency(@manifestDate)
	from
		scManifestTemplates mt
	join 
		scManifestSequenceTemplates mst on mst.ManifestTemplateId = mt.ManifestTemplateId
	where
		dbo.scGetDayFrequency(@manifestDate) & mst.Frequency > 0
	and mt.MTCode = @mfstCode
	and mt.MTDeleted = 0
	-- Based on the templates, make a list of all the manifests that must exist
	-- for @manifestDate.  Some may already exist.

	create table #neededMfsts (ManifestTemplateId int)
	insert #neededMfsts
	select 
		mt.ManifestTemplateId
	from
		scManifestTemplates mt
	join 
		scManifestSequenceTemplates mst on mst.ManifestTemplateId = mt.ManifestTemplateId
	where
		dbo.scGetDayFrequency(@manifestDate) & mst.Frequency > 0
	and mt.MTCode = @mfstCode
	and mt.MTDeleted = 0

	-- Make a list of existing manifests for @manifestDate.
	create table #existingMfsts (ManifestTemplateId int)
	insert #existingMfsts
	select
		 m.ManifestTemplateId
	from 
		scManifests m
	left join
		scManifestSequences ms on ms.ManifestId = m.ManifestId
	where
		m.ManifestDate = @manifestDate
	and m.MfstCode = @mfstCode

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
		,@manifestDate
		,mt.ManifestTemplateId
	from
		scManifestTemplates mt
	join 
		#neededMfsts n on n.ManifestTemplateId = mt.ManifestTemplateId
	left join 
		#existingMfsts e on e.ManifestTemplateId = mt.ManifestTemplateId
	where e.ManifestTemplateId is null

	set @msg = 'Manifest sequence finalizer inserted ' + cast(@@rowcount as varchar) + ' manifest records'
	print @msg
	exec syncSystemLog_Insert 2, 0, 1, @msg

	-- Using the templates, make a list of the needed manifest sequences for manifests for @manifestDate.
	create table #neededSeqs (
		 ManifestId int
		,ManifestSequenceTemplateId int
		,AccountPubId int
		,Sequence int
	)

	insert #neededSeqs
	select
		 m.ManifestId
		,msi.ManifestSequenceTemplateId
		,msi.AccountPubId
		,msi.Sequence
	from
		scManifests m
	join
		scManifestTemplates mt on mt.ManifestTemplateId = m.ManifestTemplateId
	join
		scManifestSequenceTemplates mst on mst.ManifestTemplateId = mt.ManifestTemplateId
	join
		scManifestSequenceItems msi on msi.ManifestSequenceTemplateId = mst.ManifestSequenceTemplateId and
		dbo.scGetDayFrequency(@manifestDate) & mst.Frequency > 0
	where
		m.ManifestDate = @manifestDate
		and m.MfstCode = @mfstCode

	-- Make a list of all the existing manifest sequence records for manifests for @manifestDate.
	create table #existingSeqs (
		 ManifestId int
		,ManifestSequenceTemplateId int
		,AccountPubId int
	)

	insert #existingSeqs
	select 
		 ms.ManifestId
		,ms.ManifestSequenceTemplateId
		,ms.AccountPubId
	from
		scManifestSequences ms
	join
		scManifests m on m.ManifestId = ms.ManifestId
	where
		m.ManifestDate = @manifestDate
		and m.MfstCode = @mfstCode

	-- Insert any needed manifest sequences that do not already exist.
	insert scManifestSequences (
		 ManifestId
		,ManifestSequenceTemplateId
		,AccountPubId
		,Sequence
	)
	select n.ManifestId, n.ManifestSequenceTemplateId, n.AccountPubId, n.Sequence
	from 
		#neededSeqs n
	left join 
		#existingSeqs e on 
			e.ManifestId = n.ManifestId and
			e.ManifestSequenceTemplateId = n.ManifestSequenceTemplateId and
			e.AccountPubId = n.AccountPubId
	where
		e.ManifestId is null

	set @msg = 'Manifest sequence finalizer inserted ' + cast(@@rowcount as varchar) + ' manifest sequence records'
	print @msg
	exec syncSystemLog_Insert 2, 0, 1, @msg

SET QUOTED_IDENTIFIER OFF 
