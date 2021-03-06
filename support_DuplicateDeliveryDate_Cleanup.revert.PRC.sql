--revert
USE [NSDB_CHI]
GO
/****** Object:  StoredProcedure [dbo].[support_DuplicateDeliveryDate_Cleanup]    Script Date: 10/16/2013 16:13:36 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO

ALTER PROCEDURE [dbo].[support_DuplicateDeliveryDate_Cleanup]
	  @param1 nvarchar(20) = null
	, @param2 int = null
	, @param3 datetime = null
AS
/*
	[dbo].[support_DuplicateDeliveryDate_Cleanup]
	
	$History:  $
*/
BEGIN
	set nocount on
	
	--|  Declarations
	declare @msg nvarchar(1024)
	
	set @msg = 'support_DuplicateDeliveryDate_Cleanup procedure starting...'
    print @msg
    exec nsSystemLog_Insert @ModuleId=2, @SeverityId=0, @Message=@msg

	delete scDrawHistory
	from scDrawHistory dh
	join (
		select d.DrawID
		from scDraws d
		join (
			select d.AccountID, d.PublicationID, d.DeliveryDate
			from scDraws d
			where d.DrawDate > CONVERT(varchar, getdate(), 1)
			group by d.AccountID, d.PublicationID, d.DeliveryDate
			having COUNT(*) > 1
			) prelim
			on d.AccountID = prelim.AccountID
			and d.PublicationID = prelim.PublicationID
			and d.DeliveryDate = prelim.DeliveryDate
		where d.DrawDate = d.DeliveryDate
		and d.DrawAmount = 0
	) d
		on d.DrawID = dh.drawid
		
	set @msg = 'support_DuplicateDeliveryDate_Cleanup removed ' + CAST(@@rowcount as varchar) + ' records from scDrawHistory.'
    print @msg
    exec nsSystemLog_Insert @ModuleId=2, @SeverityId=0, @Message=@msg


	delete scDraws
	from scDraws d
	join (
		select d.AccountID, d.PublicationID, d.DeliveryDate
		from scDraws d
		where d.DrawDate > CONVERT(varchar, getdate(), 1)
		group by d.AccountID, d.PublicationID, d.DeliveryDate
		having COUNT(*) > 1
		) prelim
		on d.AccountID = prelim.AccountID
		and d.PublicationID = prelim.PublicationID
		and d.DeliveryDate = prelim.DeliveryDate
	where d.DrawDate = d.DeliveryDate
	and d.DrawAmount = 0		

	set @msg = 'support_DuplicateDeliveryDate_Cleanup removed ' + CAST(@@rowcount as varchar) + ' records from scDraws.'
    print @msg
    exec nsSystemLog_Insert @ModuleId=2, @SeverityId=0, @Message=@msg

	
	set @msg = 'support_DuplicateDeliveryDate_Cleanup completed successfully'
    print @msg
    exec nsSystemLog_Insert @ModuleId=2, @SeverityId=0, @Message=@msg


END
