if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[de_Message_Insert]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[de_Message_Insert]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


CREATE PROCEDURE [dbo].[de_Message_Insert]
	(
	@Address varchar(255) = '123 Main St.'
	,@District varchar(25) = null
	,@MessageType varchar(25) = 'DEMO'
	,@MessageText varchar(1024) = 'MessageText'
	,@SpecialInstructions varchar(1024) = 'SpecialInstructions'
	,@MessageReason varchar(25) = 'MessageReason'
	,@Publication varchar(50) = 'Publication'
	,@SubscriberAccountNumber varchar(50) = '01234567'
	,@SubscriberName varchar(50) = 'John Smith'
	,@SubscriberPhone varchar(50) = '555-NEWS'
	,@ExtensionAttribute1 varchar(255) = 'ExtensionAttribute1'
	,@ExtensionAttribute2 varchar(255) = 'ExtensionAttribute2'
	,@ExtensionAttribute3 varchar(255) = 'ExtensionAttribute3'
	,@ExtensionAttribute4 varchar(255) = 'ExtensionAttribute4'
	,@ExtensionAttribute5 varchar(255) = 'ExtensionAttribute5'
	)
AS
/* =============================================
Procedure:  de_Message_Insert

Created By:	katokm
Date Created:	6/18/2003	


History
-----------------------------------------------
Date	Name		Change Description
-----------------------------------------------
==============================================*/
begin
set nocount on

declare @rowcount int
	,@error int
	,@errormessage varchar(1024)
	,@procedure varchar(100)

	select @procedure = 'Stored Procedure: de_Message_Insert'

	insert into deMessage
	(
	--|Input Fields
	AddressConcat
	,District
	,MessageType
	,MessageText
	,SpecialInstructions
	,MessageReason
	,Publication
	,SubscriberAccountNumber
	,SubscriberName
	,SubscriberPhone
	,ExtensionAttribute1
	,ExtensionAttribute2
	,ExtensionAttribute3
	,ExtensionAttribute4
	,ExtensionAttribute5
	--|System generated
	,MessageDateTime
	,MessageStatusDateTime
	--|Constants
	,MessageStatusID
	,City
	,State
	,Zip
	,Company
	,DistributionCenter
	,Zone
	,Route
	)
	select 
	--|Input Fields
	 @Address
	, @District
	, @MessageType
	, @MessageText
	, @SpecialInstructions
	, @MessageReason
	, @Publication
	, @SubscriberAccountNumber
	, @SubscriberName
	, @SubscriberPhone
	, @ExtensionAttribute1
	, @ExtensionAttribute2
	, @ExtensionAttribute3
	, @ExtensionAttribute4
	, @ExtensionAttribute5
	--|System generated
	,getdate()
	,getdate()
	--|Constants
	,7  --|7=Pending
	,null
	,null
	,null
	,null
	,null
	,null
	,null

	select @error = @@error, @rowcount = @@rowcount
	if @error <> 0
	begin
		select @errormessage = 'Error inserting message into deMessage.  ' + @procedure + '.  Error: ' + cast(@error as varchar(25))
		select cast(@error as varchar(25)) as [ResultCode], @errormessage as [Result]
		return(@error)
	end
	else
	begin
		select 'SUCCESS' as [ResultCode], 'SUCCESS' as [Result]
		return(0)
	end
end


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

