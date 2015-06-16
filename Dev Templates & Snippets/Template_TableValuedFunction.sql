IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[<Procedure_Name, sysname, stored_procedure_name>]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[<Procedure_Name, sysname, stored_procedure_name>]
GO

SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE FUNCTION [dbo].[<Procedure_Name, sysname, stored_procedure_name>] (
	  @param1 nvarchar(20) = null
	, @param2 int = null
	, @param3 datetime = null
)	
RETURNS @table TABLE
(
	column_1 int
	,column_2 datetime
)

AS
/************************************************************************

	$History: $

*************************************************************************/
BEGIN


	insert into @table
	select 'value1', 'value2'

	RETURN
END
GO	