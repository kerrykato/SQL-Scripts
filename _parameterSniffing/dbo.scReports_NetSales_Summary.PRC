SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[scReports_NetSales_Summary]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[scReports_NetSales_Summary]
GO


CREATE PROCEDURE dbo.scReports_NetSales_Summary
(
	 @start			datetime				-- beginning range for the report
	,@stop			datetime				-- ending range for the report
	,@mfstowner 	nvarchar(256)			-- opitonal route owner filter
    ,@mfstid		int						-- optional manifest filter
	,@acctname		nvarchar(50)			-- optional acct name filter
	,@acctcode 		nvarchar(20)			-- optional acct code filter
    ,@categories	nvarchar(400) = NULL	-- optional category filter
	,@acctTypeList	nvarchar(400) = NULL	-- optional list of acct types to run
	,@pub			int              		-- optional publication filter
	,@zip			nvarchar(15)			-- optional zip code filter
	,@city			nvarchar(50)			-- optional city filter
	,@state			nvarchar(5)				-- optional state filter
	,@cust1			nvarchar(50)			-- optional custom filter
	,@cust2			nvarchar(50)			-- optional custom filter
	,@cust3			nvarchar(50)			-- optional custom filter
	,@freq			tinyint					-- flag for running only the Sunday numbers
    ,@Deactive		tinyint					-- flag (tristate) indicating how to deal with Deactive Accounts
    ,@RollupDetail	tinyint					-- flag to include rollup detail (Rollup accounts)
	,@UserID		int						-- user who is running the report

)
As
-- $History: /SingleCopy/Branches/SC_3.1.4/Customers/SPT/Database/Scripts/Sprocs/dbo.scReports_NetSales_Summary.PRC $
-- 
-- ****************** Version 30 ****************** 
-- User: jpeaslee   Date: 2010-07-15   Time: 11:43:36-07:00 
-- Updated in: /SingleCopy/Branches/SC_3.1.4/Customers/SPT/Database/Scripts/Sprocs 
-- Case 14146 Net Sales Summary times out 
-- Case 13099 Net Sales Summary inaccurate when accounts moved to a different 
-- manifest or rollup 
-- 
-- ****************** Version 27 ****************** 
-- User: mmisantone   Date: 2009-03-20   Time: 09:44:40-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 8400 
-- 
-- ****************** Version 26 ****************** 
-- User: robcom   Date: 2009-01-22   Time: 14:58:45-08:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 7618 
-- 
-- ****************** Version 25 ****************** 
-- User: robcom   Date: 2008-12-11   Time: 16:00:57-08:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 6567 -- Modified to work with new Manifest/Acct Mangement 
-- Plus MAJOR overhaul to existing code.  Removed redundancies, cleaned up 
-- and added some performance improvements 
-- 
-- ****************** Version 24 ****************** 
-- User: rreffner   Date: 2008-10-07   Time: 13:23:19-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 6242 
-- 
-- ****************** Version 23 ****************** 
-- User: rreffner   Date: 2008-10-07   Time: 12:57:58-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 6241 
-- 
-- ****************** Version 22 ****************** 
-- User: rreffner   Date: 2008-09-26   Time: 13:04:24-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 5187 
-- 
-- ****************** Version 21 ****************** 
-- User: jboardman   Date: 2008-06-20   Time: 15:24:28-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 4066 
-- 
-- ****************** Version 20 ****************** 
-- User: jboardman   Date: 2008-06-05   Time: 12:11:02-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 4203 
-- 
-- ****************** Version 19 ****************** 
-- User: jboardman   Date: 2008-06-05   Time: 09:02:13-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 4203 
-- 
-- ****************** Version 18 ****************** 
-- User: jboardman   Date: 2008-06-04   Time: 13:22:55-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 4203 
-- 
-- ****************** Version 17 ****************** 
-- User: jboardman   Date: 2008-05-28   Time: 14:27:16-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 4213 
-- 
-- ****************** Version 16 ****************** 
-- User: jboardman   Date: 2008-05-27   Time: 14:17:52-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 4023 
-- 
-- ****************** Version 15 ****************** 
-- User: rreffner   Date: 2008-04-22   Time: 13:23:33-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 3746 
-- 
-- ****************** Version 14 ****************** 
-- User: jpeaslee   Date: 2008-02-21   Time: 10:24:03-08:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 2961 Accounts are excluded from Net Sales report if not in any 
-- categories 
-- 
-- ****************** Version 13 ****************** 
-- User: jpeaslee   Date: 2007-05-11   Time: 13:12:53-07:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 314, rollup accounts omitted if not in selected category/type 

/*=========================================================
    scReports_NetSales_Summary
        Creates report data for net sales report


    02/26/2004
    
    robcom

    03/22/2004  robcom      CHG000220       Adding support to show/hide 
                                            Deactive Accounts on this report
                                            0 = Show Deactive (Default)
                                            1 = Hide Deactive
                                            2 = Only show deactive

    09/20/2005  johnp	    rollups         Adding support to show/hide child account detail
                            bug             Fixed "no data" when printing for single manifest and all
                                            accounts on that manifest are of type UNKNOWN (accountypeid = 0)
    09/28/2005  johnp   	bug             Adding Kerry's fix for draws with no returns or adjustments
    10/07/2005	kerry		bug				Resolving issue with null values for returns and adjustments 
											introduced by previous fix.
	02/22/2006	johnp		BUG00013		Incorrect percentage calculation
	02/23/2006	johnp		REQ00016		Incorrect account filtering when some fields are null
	03/26/2006	johnp		REQ00039		Support multiple categories and account types
	06/07/2006	johnp		Billing 		Include only delivery routes
	07/12/2006	johnp		REQ00304 		Multi select categories and account types
	09/06/2006	johnp		REQ00058		Add route owner filter
	11/28/2006  robcom      tampa issue     performance improvements
	05/01/2007	johnp		Case 292 		Explicit drop of global temp tables
	04/18/08    Reffner     Case 3746
	05/21/2008  jboardman   Case 4203       Rollup Overhaul
==========================================================*/
begin
    set nocount on

DECLARE @mask_start datetime
DECLARE @mask_stop datetime
DECLARE @mask_mfstowner nvarchar(256)
DECLARE @mask_mfstid int
DECLARE @mask_acctname nvarchar(50)
DECLARE @mask_acctcode nvarchar(20)
DECLARE @mask_categories nvarchar(400)
DECLARE @mask_acctTypeList nvarchar(400)
DECLARE @mask_pub int
DECLARE @mask_zip nvarchar(15)
DECLARE @mask_city nvarchar(50)
DECLARE @mask_state nvarchar(5)
DECLARE @mask_cust1 nvarchar(50)
DECLARE @mask_cust2 nvarchar(50)
DECLARE @mask_cust3 nvarchar(50)
DECLARE @mask_freq tinyint
DECLARE @mask_Deactive tinyint
DECLARE @mask_RollupDetail tinyint
DECLARE @mask_UserId int

set @mask_start = @start
set @mask_stop = @stop
set @mask_mfstowner = @mfstowner
set @mask_mfstid = @mfstid
set @mask_acctname = @acctname
set @mask_acctcode = @acctcode
set @mask_categories = @categories
set @mask_acctTypeList = @acctTypeList
set @mask_pub = @pub
set @mask_zip = @zip
set @mask_city = @city
set @mask_state = @state
set @mask_cust1 = @cust1
set @mask_cust2 = @cust2
set @mask_cust3 = @cust3
set @mask_freq = @freq
set @mask_Deactive = @Deactive
set @mask_RollupDetail = @RollupDetail
set @mask_UserId = @UserId

    -- make sure our dates reflect midnight of start to 11:59pm of end
    declare @chardate   varchar(10)
    set @chardate = convert(varchar(10),@mask_start,101)
    set @mask_start    = cast( @chardate as datetime )

    set @chardate = convert(varchar(10),@mask_stop,101)
    set @mask_stop     = cast( @chardate + ' 23:59:59' as datetime )

	DECLARE @deliveryManifestTypeId INT
	--
	--	We're using '0' (zero) now to indicate 'any' (rather than -1 or null)
	--	We don't want to change the interface to the sproc though so we have
	--	to convert some of the args to this new way of handling 'any'
	IF ( @mask_mfstid is null OR @mask_mfstid = -1 )
	BEGIN	
		SET @mask_mfstid = 0
		--	Concerned with 'any' manifest but we want to be sure and only pull
		--	delivery manifests (so that we don't double-count values for accounts that appear on 
		--	different types of manifests (delivery, return, etc.)
		SELECT	@deliveryManifestTypeId = ManifestTypeId 
		FROM	dd_scManifestTypes 
		WHERE	ManifestTypeName = 'D' -- Delivery
	END
	ELSE	-- caller asks for a specific manifest so we don't need to filter out by type
	BEGIN
		SET	@deliveryManifestTypeId = 0	-- use zero to indicate that we don't care about type
	END

	--	Manifest Owner in the old (pre 3.1) world was a string. The
	--  3.1 and later revisions use an INT id value instead.  Again, since we
	--	don't want to mess with the interface, we make the necessary changes here
	--	If we get a space in the @mask_mfstowner parameter, then this means that
	--	the user did not have access to the list of owners, and should only
	--	be able to see manifests that they owned.
	DECLARE @ManifestOwnerArg INT
	SELECT	@ManifestOwnerArg = 
		CASE	
			WHEN @mask_mfstowner IS NULL THEN 0
			WHEN @mask_mfstowner = '' THEN @mask_UserId
			ELSE (SELECT UserId FROM dbo.Users WHERE UserName = @mask_mfstowner)
		END
	/*
	Fill #tempDraws with data that is summed across the date span
	but is NOT summed by manifest, account, and publication.  We will
	do that later as required by the report output.  

	This step supports correlation between an account and the manifest it was 
	assigned to on each day of the report's time span.  If an account moved to a 
	different manifest during the time span, it will show up on both manifests. 
	Each occurrence will show the totals only for the dates that the account was 
	on that manifest.

	All filters EXCEPT MANIFEST are applied here.

	Because we are joining on the account category tables, we must use SELECT DISTINCT
	to avoid getting duplicate account/pubs when an account is in more than one category.
	This requires adding DrawDate so we don't exclude any draw records for the date span.
	*/
	CREATE TABLE #tempDraws(
		ManifestTemplateId	INT	NOT NULL
	,	AccountId			INT NOT NULL
	,	PublicationId		INT NOT NULL
	,	DrawAmount			INT	NOT NULL
	,	RetAmount			INT NOT NULL
	,	AdjAmount			INT NOT NULL
	,	AdjAdminAmount		INT NOT NULL
	,	RollupAcctId		INT
	,	DrawDate			DATETIME
	)
	INSERT #tempDraws(
		ManifestTemplateId
	,	AccountId
	,	PublicationId
	,	DrawAmount
	,	RetAmount
	,	AdjAmount
	,	AdjAdminAmount
	,	RollupAcctId
	,	DrawDate
	)
	SELECT DISTINCT
		M.ManifestTemplateId
	,	D.AccountId
	,	D.PublicationId
	,	D.DrawAmount
	,	ISNULL(d.RetAmount, 0)
	,	ISNULL(d.AdjAmount, 0)
	,	ISNULL(d.AdjAdminAmount, 0)
	,	D.RollupAcctId
	,	D.DrawDate
	FROM
		scDraws D
	JOIN
		scAccountsPubs AP ON D.AccountId = AP.AccountId AND D.PublicationId = AP.PublicationId
	JOIN
		scManifestSequences ms on ms.AccountPubId = ap.AccountPubId
	JOIN
		scManifests m on m.ManifestId = ms.ManifestId and m.ManifestDate = d.DrawDate
	JOIN
		dbo.scAccounts A ON D.AccountID = A.AccountID
	JOIN
		dbo.scAccountsCategories AC ON A.AccountID = AC.AccountID
	JOIN
		dbo.dd_scAccountCategories C ON AC.CategoryID = C.CategoryID
	WHERE
		D.DrawDate BETWEEN @mask_start AND @mask_stop
	AND	( @Pub IS NULL OR (@Pub IS NOT NULL AND D.PublicationId = @Pub) )
	AND (
			( @mask_freq = 127 )								-- every day (Mon thru Sun)
				OR
			( @mask_freq = 126 and d.drawweekday <> 1 )		-- daily (no sunday)
				OR
			( @mask_freq = 1   and d.drawweekday = 1 )		-- sunday only
		)
	AND (
			( @mask_acctcode IS NULL )
				OR
			( A.AcctCode LIKE @mask_acctcode + N'%' )
		)
	AND (
			( @mask_acctname IS NULL )
				OR
			( A.AcctName LIKE @mask_acctname + N'%' )
		)
	AND (
			( @mask_zip IS NULL )
				OR
			( A.AcctPostalCode LIKE @mask_zip + N'%' )
		)
	AND (
			( @mask_city IS NULL )
				OR
			( A.acctcity LIKE @mask_city + N'%' )
		)
	AND (
			( @mask_cust1 IS NULL )
				OR
			( A.acctcustom1 LIKE @mask_cust1 + N'%' )
		)
	AND (
			( @mask_cust2 IS NULL )
				OR
			( A.acctcustom2 LIKE @mask_cust2 + N'%' )
		)
	AND (
			( @mask_cust3 IS NULL )
				OR
			( A.acctcustom3 LIKE @mask_cust3 + N'%' )
		)
	AND (
			( @ManifestOwnerArg = 0 )
				OR
			( @ManifestOwnerArg > 0 AND M.ManifestOwner = @ManifestOwnerArg )
		)
	AND	(
			( @accttypelist IS NULL )
				OR
			( @accttypelist IS NOT NULL AND A.accounttypeid IN ( SELECT ID FROM dbo.scATTableFromList( @mask_acctTypeList ) ) )
		)
	AND (
			( @Categories is null )
				OR
			( @Categories is not null AND C.CategoryId in (select ID from dbo.scCATTableFromList( @mask_categories ) ) )
		)
	AND
		(
			( @mask_Deactive = 0 )											-- show em all (default) "Include Inactive"
				OR
			( @mask_Deactive = 1 AND a.AcctActive = 1 AND ap.Active = 1 )	-- hide any inactive accounts
				OR
			( @mask_Deactive = 2 AND a.AcctActive = 0 AND ap.Active = 0 )	-- show ONLY the inactive accounts
		)
	AND
		(
			( @deliveryManifestTypeId = 0 )				-- see above. Don't apply the filter if we haven't set the type
				OR
			( M.ManifestTypeId = @deliveryManifestTypeId )
		)

	CREATE INDEX idx_tempDraws_accountpubid on #tempdraws( AccountId, PublicationId )

	CREATE TABLE #results (
		ManifestTemplateId	INT
	,	AccountId			INT
	,	RollupId			INT
	,	AcctCode			VARCHAR(20)
	,	AcctName 			VARCHAR(50)
	,	AcctCity 			VARCHAR(50)
	,	AcctPostalCode 		VARCHAR(15)
	,	AcctCustom1 		VARCHAR(50)
	,	AcctCustom2 		VARCHAR(50)
	,	AcctCustom3 		VARCHAR(50)
	,	AcctStateProvince 	VARCHAR(5)
	,	AcctActive			TINYINT
	,	PublicationId		INT NOT NULL
	,	DrawAmount			INT	NOT NULL
	,	Adj					INT	NOT NULL
	,	Ret					INT NOT NULL
	,	Net					INT NOT NULL
	)
		
	IF ( @mask_RollupDetail = 0 )
	BEGIN
		-- Show Rollup Detail was selected on criteria page, so we load "normal" 
		-- and child account data into #results, excluding rollups.
		INSERT #results (
			ManifestTemplateId
		,	AccountId
		,	RollupId
		,	AcctCode
		,	AcctName
		,	AcctCity
		,	AcctPostalCode
		,	AcctCustom1
		,	AcctCustom2
		,	AcctCustom3
		,	AcctStateProvince
		,	AcctActive
		,	PublicationId
		,	DrawAmount
		,	Adj
		,	Ret
		,	Net
		)
		select 
			d.ManifestTemplateId
		,	d.AccountId
		,	null as RollupId
		,	max(a.AcctCode)
		,	max(a.AcctName)
		,	max(a.AcctCity)
		,	max(a.AcctPostalCode)
		,	max(a.AcctCustom1)
		,	max(a.AcctCustom2)
		,	max(a.AcctCustom3)
		,	max(a.AcctStateProvince)
		,	CASE 
				WHEN max(a.AcctActive) + max(ap.Active) > 0 THEN 1
				ELSE 0
			END as AcctActive
		,	d.PublicationId
		,	sum(d.DrawAmount)                   as DrawAmount
		,	sum(d.AdjAmount + d.AdjAdminAmount) as Adj
		,	sum(d.RetAmount)                    as Ret
		,	sum(d.DrawAmount + d.AdjAmount + d.AdjAdminAmount - d.RetAmount) as Net
		from #tempDraws d
		join scAccounts a on a.AccountId = d.AccountId
		join scAccountsPubs ap on ap.AccountId = d.AccountId and ap.PublicationId = d.PublicationId
		where ( (@mask_mfstid = 0 ) or (d.ManifestTemplateID = @mfstId) )
		group by
			d.ManifestTemplateId
		,	d.AccountId
		,	d.PublicationId
	END
	ELSE
	BEGIN
		-- Group By Rollup was selected on criteria page, 
		-- so first we load "normal" account data into #results...
		INSERT #results (
			ManifestTemplateId
		,	AccountId
		,	RollupId
		,	AcctCode
		,	AcctName
		,	AcctCity
		,	AcctPostalCode
		,	AcctCustom1
		,	AcctCustom2
		,	AcctCustom3
		,	AcctStateProvince
		,	AcctActive
		,	PublicationId
		,	DrawAmount
		,	Adj
		,	Ret
		,	Net
		)
		select 
			d.ManifestTemplateId
		,	d.AccountId
		,	null as RollupId
		,	max(AcctCode)
		,	max(AcctName)
		,	max(AcctCity)
		,	max(AcctPostalCode)
		,	max(AcctCustom1)
		,	max(AcctCustom2)
		,	max(AcctCustom3)
		,	max(AcctStateProvince)
		,	CASE 
				WHEN max(a.AcctActive) + max(ap.Active) > 0 THEN 1
				ELSE 0
			END as AcctActive
		,	d.PublicationId
		,	sum(d.DrawAmount) as DrawAmount
		,	sum(d.AdjAmount + d.AdjAdminAmount) as Adj
		,	sum(d.RetAmount) as Ret
		,	sum(d.DrawAmount + d.AdjAmount + d.AdjAdminAmount - d.RetAmount) as Net
		from #tempDraws d
		join scAccounts a on a.AccountId = d.AccountId
		join scAccountsPubs ap on ap.AccountId = d.AccountId and ap.PublicationId = d.PublicationId
		where d.RollupAcctId is null
		and   ( (@mask_mfstid = 0 ) or (d.ManifestTemplateID = @mfstId) )
		group by
			 d.ManifestTemplateId
			,d.AccountId
			,d.PublicationId

		-- ... then we load rollup account data.
		/*
		Note grouping by manifest, rollup, and pub.  This is how we handle a rollup 
		with child accounts on different manifests.  The rollup is associated with 
		each manifest used by any of its children, so the report shows it on multiple 
		manifests.  For each manifest, the rolled up totals are only for the children 
		on that manifest.
		*/
		INSERT #results (
			ManifestTemplateId
		,	AccountId
		,	RollupId
		,	AcctCode
		,	AcctName
		,	AcctCity
		,	AcctPostalCode
		,	AcctCustom1
		,	AcctCustom2
		,	AcctCustom3
		,	AcctStateProvince
		,	AcctActive
		,	PublicationId
		,	DrawAmount
		,	Adj
		,	Ret
		,	Net
		)
		select 
			d.ManifestTemplateId					as ManifestTemplateId
		,	d.RollupAcctId							as AccountId
		,	d.RollupAcctId							as RollupId
		,	max(r.RollupCode)						as AcctCode
		,	max(r.RollupName)						as AcctName
		,	max(r.RollupCity)						as AcctCity
		,	max(r.RollupPostalCode)					as AcctPostalCode
		,	max(r.RollupCustom1)					as AcctCustom1
		,	max(r.RollupCustom2)					as AcctCustom2
		,	max(r.RollupCustom3)					as AcctCustom3
		,	max(r.RollupStateProvince)				as AcctStateProvince
		,	1										as AcctActive
		,	d.PublicationId							as PublicationId
		,	sum(d.DrawAmount)						as DrawAmount
		,	sum(d.AdjAmount + d.AdjAdminAmount)		as Adj
		,	sum(d.RetAmount)						as Ret
		,	sum(d.DrawAmount + d.AdjAmount + d.AdjAdminAmount - d.RetAmount) as Net
		from #tempDraws d
		join scRollups r on r.RollupId = d.RollupAcctId
		where d.RollupAcctId is not null
		and   ( (@mask_mfstid = 0 ) or (d.ManifestTemplateID = @mfstId) )
		group by
			 d.ManifestTemplateId
			,d.RollupAcctId
			,d.PublicationId
	END

/*
ReportNetSales.asp uses integer indexes into the result set columns,
and expects columns in EXACTLY this order:

const COL_MFSTID = 0        MfstID
const COL_ACCTID = 1        AccountID
const COL_ROUTE  = 2        MFSTCode
const COL_ACCT   = 3        AcctCode
const COL_ACCTNM = 4        AcctName
const COL_CITY   = 5        AcctCity
const COL_ZIP    = 6        AcctPostalCode
const COL_CUST1  = 7        AcctCustom1
const COL_CUST2  = 8        AcctCustom2
const COL_CUST3  = 9        AcctCustom3
const COL_PUB    = 10       PublicationId
const COL_NET    = 11       Net
const COL_DRAW   = 12       DrawAmount
const COL_ADJ    = 13       Adj
const COL_RETURN = 14       Ret
const COL_STATE  = 15       AcctStateProvince
const COL_ACTIVE = 16       AcctActive
const COL_PARENT = 17       RollupId
const COL_MFSTNAME = 18     MfstName
*/

	SELECT	
		r.ManifestTemplateId
	,	r.AccountId
	,	mt.MTCode as MFSTCode   -- ReportNetSales.asp expects this column name
	,	r.AcctCode
	,	r.AcctName
	,	r.AcctCity
	,	r.AcctPostalCode
	,	r.AcctCustom1
	,	r.AcctCustom2
	,	r.AcctCustom3
	,	r.PublicationId
	,	r.Net
	,	r.DrawAmount
	,	r.Adj
	,	r.Ret
	,	r.AcctStateProvince
	,	r.AcctActive
	,	r.RollupId
	,	mt.MTName
	FROM
		#results r
	LEFT JOIN
		scManifestTemplates mt on mt.ManifestTemplateId = r.ManifestTemplateId
	ORDER BY MTCode, AcctCode, PublicationID

	drop table #results
	drop table #tempDraws

	set nocount off
end

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT EXECUTE ON [dbo].[scReports_NetSales_Summary] TO [nsUser]
GO
