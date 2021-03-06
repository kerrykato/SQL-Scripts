IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[scAdjustmentsExport_SelectDaily]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[scAdjustmentsExport_SelectDaily]
GO

SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
	
CREATE PROCEDURE [dbo].[scAdjustmentsExport_SelectDaily]
	 @startdate				DATETIME
	,@stopdate				DATETIME
	,@excludeInactive		INT = 1
	,@excludeNonImported	INT = 1
As
/*=========================================================
	scAdjustmentsExport_SelectDaily

	Generates result set of draws with Adjustment information between
	@startdate and @stopdate.  Intended to allow for flexible
	data extract for those cases where the weekly output from
	scAdjustmentsExport_SelectWeek is not appropriate.
	For example, if the output file should contain only one day's
	worth of data or needs to contain more than 7 days.

	As with the weekly version, the data set returned contains
	*all* pertinent information from Account, AccountPub, Rollup
	and Publication.

	@excludeInactive	1 (Default) means we don't pull items that are not Active
						This is at the Account AND AccountPub level

	@excludeNonImported	1 (Default) means we don't pull any items that were not previously
						imported. This is the old default behavior but it's configurable
						in this version.
	
	$History: /SingleCopy/Branches/SC_3.6.0/Core/Database/Scripts/Sprocs/dbo.scAdjustmentsExport_SelectDaily.PRC $
-- 
-- ****************** Version 4 ****************** 
-- User: jpeaslee   Date: 2012-11-01   Time: 09:19:20-07:00 
-- Updated in: /SingleCopy/Branches/SC_3.6.0/Core/Database/Scripts/Sprocs 
-- Merge Branches: Origin=$/SingleCopy/Trunk/Database/Scripts/Sprocs 
--  
-- Version: 1317 
-- Case 20329 Adjustment Export has no provision for exporting the total of 
-- AdjFullAmount & AdjAdminFullAmount 
-- 
-- ****************** Version 3 ****************** 
-- User: jpeaslee   Date: 2012-11-01   Time: 09:15:47-07:00 
-- Updated in: /SingleCopy/Trunk/Database/Scripts/Sprocs 
-- Case 20329 Adjustment Export has no provision for exporting the total of 
-- AdjFullAmount & AdjAdminFullAmount 
-- 
-- ****************** Version 2 ****************** 
-- User: mmisantone   Date: 2009-07-09   Time: 10:26:38-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 8526 
-- 
-- ****************** Version 1 ****************** 
-- User: mmisantone   Date: 2009-07-06   Time: 15:23:24-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
==========================================================*/
BEGIN
	SET	NOCOUNT	ON

	-- Normalize the start date and end date (remove time portion
	-- from @startdate and add "11:59:59" to @stopdate
	SELECT	@startdate = CAST( FLOOR( CAST( @startdate AS FLOAT ) ) AS DATETIME )
	SELECT	@stopdate  = DATEADD( s, 86399, CAST( FLOOR( CAST( @stopdate AS FLOAT ) ) AS DATETIME ) )

	-- make sure @stop > @start
	-- 
	IF ( DATEDIFF( mi, @startdate, @stopdate ) < 0 )
	BEGIN
		RAISERROR('Invalid Start/Stop dates passed to scDrawForecast_Export_SelectDaily. Expected start < stop',16,1)
		RETURN 1
	END

	-- This table holds raw data, before formatting. The temp table is required
	-- so that we can add both 'normal account' related draw as well as 
	-- rollup draw.
	CREATE TABLE #currdraw (
		 DrawID			INT
		,DrawDate		DATETIME		
		,AccountID		INT				-- reference into scAccounts for normal accounts
		,RollupID		INT				-- reference into scRollups for rollup accounts
		,PublicationId	INT				-- reference into nsPublications table
		,DrawAmount		INT				-- Draw
		,AdjAmount		INT				-- Adjustment Amount
		,AdjAdminAmount INT				-- Admin Adjustment Amount
		,AdjExportLastAmt	INT			-- Last exported Adjustment
		,IsRollup		TINYINT			-- Indicates if it's a rollup account or not (1=true, 0=false)
	)

	-- Get data for "normal" accounts i.e., no rollups and no child accounts.
	INSERT #currdraw (
		 DrawID
		,DrawDate
		,AccountID
		,RollupID
		,PublicationID
		,DrawAmount
		,AdjAmount
		,AdjAdminAmount
		,AdjExportLastAmt
		,IsRollup
	)
	SELECT
		 d.DrawID
		,d.DrawDate
		,d.AccountID
		,NULL
		,d.PublicationID
		,d.DrawAmount
		,d.AdjAmount
		,d.AdjAdminAmount
		,d.AdjExportLastAmt
		,0
	FROM	scDraws	d
	JOIN	scAccounts a ON (a.accountid = d.accountid)
	JOIN	nsPublications p ON (p.PublicationId = d.PublicationId)
	JOIN	scAccountsPubs ap ON (ap.AccountId = a.AccountId and ap.PublicationId = p.PublicationId)

	WHERE	d.drawdate BETWEEN @startdate AND @stopdate
 	AND		( @excludeNonImported != 1 OR  a.AcctImported = 1 )
	AND		( @excludeInactive != 1
			  OR ( ap.Active = 1 AND A.AcctActive = 1 ) )
	AND D.RollupAcctID IS NULL		-- NON-child accounts

	-- Get summed child account data for rollup accounts.
	insert #currdraw (
		 DrawID
		,DrawDate
		,AccountID
		,RollupID
		,PublicationID
		,DrawAmount
		,AdjAmount
		,AdjAdminAmount
		,AdjExportLastAmt
		,IsRollup
	)
	SELECT
		 0
		,d.DrawDate
		,NULL
		,r.RollupID
		,d.PublicationID
		,SUM( D.DrawAmount )
		,SUM( d.AdjAmount )
		,SUM( d.AdjAdminAmount )
		,SUM( d.AdjExportLastAmt )
		,1
	FROM	scDraws	d
	JOIN	scAccounts a ON (a.accountid = d.accountid)
	JOIN	nsPublications p ON (p.PublicationId = d.PublicationId)
	JOIN	scAccountsPubs ap ON (ap.AccountId = a.AccountId and ap.PublicationId = p.PublicationId)
	JOIN	scRollups r on (r.RollupId = d.RollupAcctID)

	WHERE	d.drawdate BETWEEN @startdate AND @stopdate
 	AND		( @excludeNonImported != 1 OR  r.RollupImported = 1 )
	AND		( @excludeInactive != 1
			  OR ( ap.Active = 1 AND A.AcctActive = 1 AND R.RollupActive = 1 ) )

	GROUP BY d.DrawDate, r.RollupID, d.PublicationID

	SELECT	CD.DrawID											AS [DrawID]
	,		AT.ATName											AS [ATName]
	,		AT.ATDescription									AS [ATDescription]
	,		COALESCE( R.RollupID, A.AccountID )					AS [AccountID]
	,		COALESCE( R.RollupCode, A.AcctCode )				AS [Code]
	,		COALESCE( R.RollupName,A.AcctName )					AS [Name]
	,		COALESCE( R.RollupDescription, A.AcctDescription )	AS [Description]
	,		COALESCE( R.RollupAddress, A.AcctAddress )			AS [Address]
	,		COALESCE( R.rollupCity, A.AcctCity )				AS [City]
	,		COALESCE( R.RollupStateProvince, A.AcctStateProvince ) AS [StateProvince]
	,		COALESCE( R.RollupPostalCode, A.AcctPostalCode )	AS [PostalCode]
	,		COALESCE( R.RollupCountry, A.AcctCountry )			AS [Country]
	,		COALESCE( R.RollupContact, A.AcctContact )			AS [Contact]
	,		COALESCE( R.RollupPhone, A.AcctPhone )				AS [Phone]
	,		COALESCE( R.RollupHours, A.AcctHours )				AS [Hours]
	,		COALESCE( R.RollupSpecialInstructions, A.AcctSpecialInstructions )	AS [SpecialInstructions]
	,		COALESCE( R.RollupCustom1, A.AcctCustom1 )			AS [Custom1]
	,		COALESCE( R.RollupCustom2, A.AcctCustom2 )			AS [Custom2]
	,		COALESCE( R.RollupCustom3, A.AcctCustom3 )			AS [Custom3]
	,		COALESCE( R.RollupNotes, A.AcctNotes )				AS [Notes]
	,		CD.IsRollup											AS [IsRollup]
	,		AP.APCustom1										AS [APCustom1]
	,		AP.APCustom2										AS [APCustom2]
	,		AP.APCustom3										AS [APCustom3]
	,		P.PublicationID										AS [PublicationID]
	,		P.PubName											AS [PubName]
	,		P.PubShortName										AS [PubShortName]
	,		P.PubDescription									AS [PubDescription]
	,		P.PubCustom1										AS [PubCustom1]
	,		P.PubCustom2										AS [PubCustom2]
	,		P.PubCustom3										AS [PubCustom3]
	,		CD.DrawDate											AS [DrawDate]
	,		CD.DrawAmount										AS [DrawAmount]
	,		CD.DrawDate											AS [ABCDrawDate]
	,		CD.AdjAmount										AS [AdjFullAmount]
	,		CD.AdjAdminAmount									As [AdjAdminFullAmount]
			-- If both CD.AdjAmount and CD.AdjAdminAmount are NULL, no adjustments have been entered
	,		CASE WHEN CD.AdjAmount IS NULL AND CD.AdjAdminAmount IS NULL THEN
				NULL
			ELSE
				(ISNULL(CD.AdjAmount,0) + ISNULL(CD.AdjAdminAmount,0) - ISNULL(CD.AdjExportLastAmt,0))
			END													 AS [AdjAmount]
	,		ISNULL(CD.AdjAmount,0) + ISNULL(CD.AdjAdminAmount,0) AS [AdjCombinedFullAmount]
	FROM	#currdraw CD
	JOIN	nsPublications P ON CD.PublicationID = P.PublicationID
	LEFT JOIN	scAccounts A ON CD.AccountID = A.AccountID
	LEFT JOIN	scRollups R ON CD.ROllupID = R.RollupID
	LEFT JOIN	scAccountsPubs AP ON CD.AccountID = AP.AccountID AND CD.PublicationID = AP.PublicationID
	LEFT JOIN	dd_scAccountTypes AT ON A.AccountTypeID = AT.AccountTypeID

	ORDER BY CD.DrawDate

	DROP TABLE #currdraw

	SET	NOCOUNT	OFF
END 


grant execute on [dbo].[scAdjustmentsExport_SelectDaily] to [nsUser]
GO                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          