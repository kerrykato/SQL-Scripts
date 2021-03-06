USE [Syncronex]
GO
/****** Object:  StoredProcedure [dbo].[scGateway_Get_Returns01File]    Script Date: 02/06/2015 14:19:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter Procedure [dbo].[scGateway_Get_Returns01File_TEST]
(
	@DeliveryDate 	datetime 	= NULL
)

AS
/*=========================================================
    scGateway_Get_Returns01File
        This is a Gateway process to get the Runlist file
		for the Windows based handheld units.

		This procedure is written in the normal Gateway stored
		procedure format so normal Syncronex logging of information 
		is not used since the Gatway process has its own way of 
		doing it.
    
		$History: /SingleCopy/Trunk/Database/Scripts/Sprocs/dbo.scGateway_Get_Returns01File.PRC $
-- 
-- ****************** Version 6 ****************** 
-- User: cbeagle   Date: 2010-07-27   Time: 14:25:30-04:00 
-- Updated in: /SingleCopy/Trunk/Database/Scripts/Sprocs 
-- Cases 14241/14251 - Modify Gateway to Allow Returns More Than 4 Weeks 
-- Back/Modify Gateway Process Producing Return01 File To Use 'Returns 
-- Allowed' Flag 
-- 
-- ****************** Version 5 ****************** 
-- User: cbeagle   Date: 2010-07-26   Time: 10:30:14-04:00 
-- Updated in: /SingleCopy/Trunk/Database/Scripts/Sprocs 
-- Case 14160 - Increase Manifest, Device, and Account Code Sizes for Windows 
-- Mobile 
-- 
-- ****************** Version 4 ****************** 
-- User: cbeagle   Date: 2009-07-21   Time: 13:51:36-04:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 9982 - Modify Windows Mobile System to Handle 5 Character PubID 
-- 
-- ****************** Version 3 ****************** 
-- User: cbeagle   Date: 2009-01-19   Time: 13:08:18-05:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 6565 - Implement changes to Gateway for Windows PDA Transfers for new 
-- Manifest Management 
-- 
-- ****************** Version 2 ****************** 
-- User: cbeagle   Date: 2009-01-08   Time: 15:48:39-05:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 2207 - Fix problem in existence test 
-- 
-- ****************** Version 1 ****************** 
-- User: cbeagle   Date: 2008-12-29   Time: 10:32:09-05:00 
-- Updated in: /Gazette/Database/Scripts/Sprocs 
-- Case 2207 - Develop Handheld Interface between Single Copy server and 
-- Single Copy (Windows) 


    Date:  10/24/2008
    Author: CBeagle

    Change History
    
 
    -------------------------------------------------------
    Date       Author      Reference           Description
    -------------------------------------------------------
    10/24/08   CBeagle	   Case 2207           Created
    01/08/09   CBeagle     Case 6565           Modify for new
                                               manifest system.

==========================================================*/

SET NOCOUNT ON


DECLARE @UpdateDate 	DATETIME
DECLARE @DrawDate 	DATETIME
DECLARE @DAPropertyName VARCHAR(50)
DECLARE @DAValue		VARCHAR(128)
DECLARE @DFcategoryName	VARCHAR(20)

SET @DrawDate = @DeliveryDate
-- test
-- SET @DrawDate = '2008-10-05'
SET @DAPropertyName = 'UseCommServer'
SET @DAValue		= 'true'
SET @DFCategoryName = 'data'



DECLARE @dteDelDate smalldatetime
DECLARE @dteBOW smalldatetime
DECLARE @DOW int

SET @dteDelDate = CONVERT(smalldatetime,@DrawDate)
SET @DOW = datepart(dw,@dteDelDate)

IF @DOW = 1
BEGIN
	SET @dteBOW = @dteDelDate - 6
END
ELSE
BEGIN
	SET @dteBOW = @dteDelDate - (@DOW -2)
END

DECLARE @DateExtent 	varchar(8)

SET @DateExtent = CONVERT (varchar,(CONVERT (smalldatetime,@DrawDate) - 28),112)


----------------------------------------------------------------------
-- get route/device list

/*
SELECT DISTINCT RTRIM(M.MfstCode) + '_' + RTRIM(DE.DeviceCode)
FROM scManifests M
Join nsDevices DE on DE.DeviceID = M.DeviceID
	AND DE.CompanyID = M.CompanyID
	AND DE.DistributionCenterID = M.DistributionCenterID
Join dd_nsDeviceAdminValues DAV on DAV.DeviceTypeID = DE.DeviceTypeID
Join dd_nsDeviceAdminProperties DAP on DAP.DeviceAdminPropertyID = DAV.DeviceAdminPropertyID
WHERE DAP.DeviceAdminPropertyName = @DAPropertyName
	AND DAV.DeviceAdminValue = @DAValue
-- get only manifests for correct date
	AND CONVERT(varchar(8),M.ManifestDate,112) = CONVERT(varchar(8),@DrawDate,112)

ORDER BY RTRIM(M.MfstCode) + '_' + RTRIM(DE.DeviceCode)
*/


----------------------------------------------------------------------
-- create return file


-- due to resulting duplicate records when using required output format 
-- need store original selection in temp table to eliminate duplicates and 
-- then produce final output file

-- the table below is different in its use in the other 'scGateway_Get-'
-- programs in that it capture record details and not the final record format.
-- this was done to increase the program's efficiency 


CREATE TABLE #tempOutputTable(
	[Route_Unit] [varchar](100) NULL
	,[AcctCode] [varchar](100) NULL
	,[PubShortName] [varchar](100) NULL
	,[DrawDate] [datetime] NULL
	,[DrawRate] [decimal](8, 5) NULL
	,[DrawAmount] [int] NULL
	,[RetAmount] [int] NULL
	,[DeliveryDate] [datetime] NULL
	,[DrawID] [int]  NULL
	,[AccountID] [int]  NULL
	,[AllowReturns] [int]  NULL

	) ON [PRIMARY]



INSERT INTO #tempOutputTable(
	[Route_Unit] 
	,[AcctCode]
	,[PubShortName] 
	,[DrawDate] 
	,[DrawRate] 
	,[DrawAmount] 
	,[RetAmount] 
	,[DeliveryDate] 
	,[DrawID] 
	,[AccountID] 
	,[AllowReturns] 

	) 

	SELECT DISTINCT RTRIM(LTRIM(M.MfstCode)) + '_' + RTRIM(DE.DeviceCode)
		,AC.AcctCode
		,PB.PubShortName
		,DR.DrawDate
		,DR.DrawRate
		,DR.DrawAmount + ISNULL(DR.AdjAmount,0) + ISNULL(DR.AdjAdminAmount,0)
		,ISNULL(DR.RetAmount,0)
		,DR.DeliveryDate
		,DR.DrawID
		,DR.AccountID
		,(SELECT AllowReturns FROM scDefaultDraws WHERE CompanyId = 1 AND DistributionCenterId = 1 AND AccountId = DR.AccountId AND PublicationId = DR.PublicationId AND DrawWeekday = DR.DrawWeekday) 


FROM scManifests M
Join nsDevices DE on DE.DeviceID = M.DeviceID
	AND DE.CompanyID = M.CompanyID
	AND DE.DistributionCenterID = M.DistributionCenterID
Join dd_nsDeviceAdminValues DAV on DAV.DeviceTypeID = DE.DeviceTypeID
Join dd_nsDeviceAdminProperties DAP on DAP.DeviceAdminPropertyID = DAV.DeviceAdminPropertyID

Join scManifestSequences MS on MS.ManifestID = M.ManifestID
Join scAccountsPubs AP on AP.AccountPubID = MS.AccountPubID
Join scAccounts AC on AC.AccountID = AP.AccountID
	AND AC.CompanyID = AP.CompanyID
	AND AC.DistributionCenterID = AP.DistributionCenterID

-- select any scDraws records for accounts when selecting return 
-- records since returns for any publication can be picked up
-- (i.e., do not limit to scDraws records tied only to scAccountsPubs records)
Join scDraws DR on DR.AccountID = AC.AccountID
	AND DR.CompanyID = AC.CompanyID
	AND DR.DistributionCenterID = AC.DistributionCenterID
	AND CONVERT(varchar(8),DR.DeliveryDate,112) < CONVERT(varchar(8),@DrawDate,112)

Join nsPublications PB on PB.PublicationID = DR.PublicationID
	AND PB.CompanyID = DR.CompanyID
	AND PB.DistributionCenterID = DR.DistributionCenterID
WHERE DAP.DeviceAdminPropertyName = @DAPropertyName
	AND DAV.DeviceAdminValue = @DAValue
-- get only manifests for correct date
	AND CONVERT(varchar(8),M.ManifestDate,112) = CONVERT(varchar(8),@DrawDate,112)

-- select only records for which returns can be entered
	AND dbo.scOverThreshhold(@DrawDate,DR.DeliveryDate, AC.AccountTypeID, PB.PublicationID ) = 0

	AND (DR.DrawAmount + ISNULL(DR.AdjAmount,0) + ISNULL(DR.AdjAdminAmount,0)) > 0

-- for testing replace above with following
--	AND DR.DrawDate >= @DateExtent  



-- now create resulting output file

SELECT [Route_Unit] as [Route_Unit]
		, CONVERT(char(20),AcctCode)		 as VendorNumber
		, CONVERT(char(3),' ') as VendorModifier
		, CONVERT(char(5), PubShortName)			as PubID
		, CONVERT(char(2),'')		as Edition
		, CONVERT(char(8),DrawDate,112)			as Issue
		, CONVERT(char(1),'D') as PubType
		, CONVERT(char(5),-1) 	as ExpDraw
		, RTRIM(REPLICATE('0',5 - LEN((CAST(FLOOR(DrawRate * 1000) AS CHAR(8))))) 
		 +  (CAST(FLOOR(DrawRate * 1000) AS CHAR(5)))) as  Cost
		, CONVERT(char(5),DrawAmount)	as QtyDelivered
		, CONVERT(char(5),' ')			as QtyReturned
		, CONVERT(char(5),RetAmount)	as QtyPrevReturn

		, CONVERT(char(1),' ')			as ItemStatus
		, CONVERT(char(20),ISNULL(
				(Select I.InvoiceID
				From scInvoices I
				Where I.AccountID = OT.AccountID
					and CONVERT(char(8),OT.DeliveryDate,112) >= CONVERT(char(8),I.BeginDate,112)
					and CONVERT(char(8),OT.DeliveryDate,112) <= CONVERT(char(8),I.EndDate,112)
				)			
				,''))as InvoiceNumber 


		, CONVERT(char(1),
			CASE	
				WHEN AllowReturns = 1	THEN 'Y'
				ELSE 'N'
			END)		as ReturnsAllowed

		, CONVERT(char(1),DATEPART(dw,DeliveryDate))			as DayOfWeek

		, CONVERT(char(1),
			CASE	
				WHEN cast(DeliveryDate AS smalldatetime) >= @dteBOW         THEN '0'
				WHEN cast(DeliveryDate AS smalldatetime) >= (@dteBOW - 7)   THEN '1'
				WHEN cast(DeliveryDate AS smalldatetime) >= (@dteBOW - 14)  THEN '2'
				WHEN cast(DeliveryDate AS smalldatetime) >= (@dteBOW - 21)  THEN '3'
				WHEN cast(DeliveryDate AS smalldatetime) >= (@dteBOW - 28)  THEN '4'
				ELSE '5'
			END)			as [Week]


		, CONVERT(char(8),DrawID) as DrawID --for when upload LogDraw and LogReturns
		, CONVERT(char(12),' ')	as Spare

FROM #tempOutputTable OT
ORDER BY 	[Route_Unit] 
	,[AcctCode]
	,[PubShortName] 
	,[DrawDate]

DROP TABLE #tempOutputTable


SET NOCOUNT OFF

