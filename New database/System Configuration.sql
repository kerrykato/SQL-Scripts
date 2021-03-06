begin tran

/*
	This procedure is intended to assist in setting the typical configuration 
	settings that need to be set for each installation
*/

--|  Declarations
declare @database 		nvarchar(25)
declare @ver 			nvarchar(10)
declare @doUpdate 		bit
declare @updateSignatureFilePath bit
declare @commitTran 		bit
declare @nestedCompanyFolders	bit

declare @multiCompany 			nvarchar(5)
declare @webserver 			nvarchar(25)
declare @installPath_Web		nvarchar(100)
declare @installPath_SQL		nvarchar(100)
declare @dataExchangePath		nvarchar(100)

---------------------------------------------------------------------------------------------
--	MODIFY THE FOLLOWING VARIABLES AS NECESSARY
---------------------------------------------------------------------------------------------
set @doUpdate = 1		--|  (0|1) 0 = Display current values, 1 = Display updated values
set @updateSignatureFilePath = 0
set @commitTran = 0		--|  (0|1) 0 = Rollback, 1 = Commit
set @nestedCompanyFolders = 1	--|  (0|1) 

set @database = 'nsdb_sample'  	--|  database name of the company you are configuring
set @multiCompany = 'False'	--|  (true|false) enables/disables multi-company	
set @webserver = 'seagull'	--|  dns, servername, ip address of the web application server
set @installPath_Web = 'C:\Program Files\Syncronex\SingleCopy'	
set @installPath_SQL = 'C:\Program Files\Syncronex\SingleCopy'
set @dataExchangePath = 'C:\Program Files\Syncronex\DataExchange\From_Sync'
---------------------------------------------------------------------------------------------

declare @signaturePath 			nvarchar(100)
declare @deliveryReceiptsPath	 	nvarchar(100)
declare @pathToForecastEngine_exe 	nvarchar(100)
declare @pathToSyncExport_exe		nvarchar(100)
declare @sysPropertyName nvarchar(50)
declare @sysPropertyValue nvarchar(128)
declare @charindex int
declare @configFile nvarchar(255)

--|  Initialize Variables
if right( @installPath_Web, 1 ) = '\'
	set @installPath_Web = left( @installPath_Web, len(@installPath_Web) - 1 )

if right( @installPath_SQL, 1 ) = '\'
	set @installPath_SQL = left( @installPath_SQL, len(@installPath_SQL) - 1 )

if right( @dataExchangePath, 1 ) = '\'
	set @dataExchangePath = left( @dataExchangePath, len(@dataExchangePath) - 1 )


create table #syncSystemProperties (
	SysPropertyName nvarchar(255)
	, SysPropertyDisplayName nvarchar(255)
	, SysPropertyValue_Old nvarchar(255)
	, SysPropertyValue_New nvarchar(255)
)

	insert into #syncSystemProperties ( SysPropertyName, SysPropertyDisplayName, SysPropertyValue_Old )
	select SysPropertyName, SysPropertyName, SysPropertyValue as SysPropertyValue_Old
	from syncSystemProperties
	where SysPropertyName in ( 'PDAServer', 'PDAServerPath' )
	union all
	select SysPropertyName, SysPropertyName, SysPropertyValue
	from syncSystemProperties
	where SysPropertyName in ( 'SignatureFilePath' )
	union all
	select SysPropertyName, SysPropertyName, SysPropertyValue
	from syncSystemProperties
	where SysPropertyName in ( 'DeliveryReceiptsExportFile' )
	union all
	select SysPropertyName, SysPropertyName, SysPropertyValue
	from NSSESSION..syncsystemproperties
	where SysPropertyName = 'ForecastEnginePath'
	union all
	select SysPropertyName, SysPropertyName, SysPropertyValue
	from syncSystemProperties
	where SysPropertyName in ( 'DataExportEnginePath' )
	union all
	select 'ExportConfigFilePath', 'ExportConfigFilePath (Returns/Adjustments)', SysPropertyValue
	from syncSystemProperties
	where SysPropertyName in ( 'ExportConfigFilePath' )
	union all
	select 'DataExportConfigFile', 'DataExportConfigFile (Forecast)', SysPropertyValue
	from syncSystemProperties
	where SysPropertyName in ( 'DataExportConfigFile' )
	union all
	select 'InvoiceExportConfigFilePath', 'InvoiceExportConfigFilePath (Invoice)', SysPropertyValue
	from syncSystemProperties
	where SysPropertyName in ( 'InvoiceExportConfigFilePath' )


--|  Get the database version
select @ver = replace(verInfoVersion, 'Core_', '')
from nsversioninfo v1
join (
	select max(verInfoId) as verInfoId
	from nsversionInfo
	where verInfoDescription in (
		'Core Installation'
		, 'Core Upgrade'
		)
	) as v2
on v1.verInfoId = v2.verInfoId

select @ver as [SingleCopy Version]

set nocount on

/* Company Info */
  --|  Multi-Company Enabled?
--/*
	if @doUpdate = 1
	begin
		set @sysPropertyName = 'EnableMultiCompany'

		update NSSESSION..syncSystemProperties
		set SysPropertyValue = @multiCompany 
		where SysPropertyName = @sysPropertyName 
	end
--*/
	select 'Multi-Company' as [SysPropertyName]
		, case sysPropertyValue when 'true' then 'Enabled' when 'false' then 'Disabled' end as [SysPropertyValue]
	from NSSESSION..syncSystemProperties
	where SysPropertyName = 'EnableMultiCompany'



  --|  nsSessionCompanies
	if @doUpdate = 1 
	begin
		if not exists ( select 1 from NSSESSION..nsSessionCompanies where CoDbCatalog = @database )
		begin
			insert into NSSESSION..nsSessionCompanies (CoName, CoDbCatalog, CoActive)
			select @database, @database, 1
			print 'Inserted ' + cast(@@rowcount as varchar) + ' row(s) into NSSESSION..nsSessionCompanies'
		end
	end

	select CoName, CoDbCatalog, CoActive
	from NSSESSION..nsSessionCompanies
	where CoDbCatalog = @database
	
	if ( @doUpdate = 1 and @multiCompany = 'true' )
	begin
		update nsCompanies
		set CoCustom2 = @database
		where CoCustom2 <> @database
		if @@rowcount > 0
			print 'updated CoCustom2 = ' + @database + ' in table nsCompanies'
	end

/* PDA CONFIG */

	--|Server

	if @doUpdate = 1
	begin
		set @sysPropertyName = 'PDAServer'
		set @sysPropertyValue = @webServer

		update syncSystemProperties
		set SysPropertyValue = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
		and SysPropertyValue <> @sysPropertyValue
		
		if @@rowcount > 0
		begin 
			print 'Set system property ''' + @sysPropertyName + ''' = ''' + @sysPropertyValue + ''''
		end

		update #syncSystemProperties
		set SysPropertyValue_New = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
	end

	--|Virtual Directory

	if @doUpdate = 1
	begin
		set @sysPropertyName = 'PDAServerPath'
		set @sysPropertyValue = '/' + @database

		update syncSystemProperties
		set SysPropertyValue = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
		and SysPropertyValue <> @sysPropertyValue	
		
		if @@rowcount > 0
		begin 
			print 'Set system property ''' + @sysPropertyName + ''' = ''' + @sysPropertyValue + ''''
		end

		update #syncSystemProperties
		set SysPropertyValue_New = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
	end

	--|Signature Path

	if @doUpdate = 1
	begin
		set @sysPropertyName = 'SignatureFilePath'
		set @signaturePath = case @nestedCompanyFolders 
			when 1 then @dataExchangePath + '\' + @database + '\Signatures'
			else @dataExchangePath + '\Signatures'
			end

		update syncSystemProperties
		set SysPropertyValue = @signaturePath 
		where SysPropertyName = @sysPropertyName
		and SysPropertyValue <> @signaturePath 
		
		if @@rowcount > 0 
		begin
			print 'Set system property ''' + @sysPropertyName + ''' = ''' + @signaturePath + ''''
		end

		update #syncSystemProperties
		set SysPropertyValue_New = @signaturePath
		where SysPropertyName = @sysPropertyName
	end

	--|Delivery Receipts Path

	if @doUpdate = 1
	begin
		set @sysPropertyName = 'DeliveryReceiptsExportFile'
		set @deliveryReceiptsPath = case @nestedCompanyFolders 
			when 1 then @dataExchangePath + '\' + @database + '\DeliveryReceipts'
			else @dataExchangePath + '\DeliveryReceipts'
			end
		
		update syncSystemProperties
		set SysPropertyValue = @deliveryReceiptsPath
		where SysPropertyName = @sysPropertyName
		and SysPropertyValue <> @deliveryReceiptsPath

		if @@rowcount > 0 
		begin
			print 'Set system property ''' + @sysPropertyName + ''' = ''' + @deliveryReceiptsPath + ''''
		end

		update #syncSystemProperties
		set SysPropertyValue_New = @deliveryReceiptsPath
		where SysPropertyName = @sysPropertyName
	end

/* ForecastEngine */

	--|Path to ForecastEngine.exe

	if @doUpdate = 1
	begin
		set @sysPropertyName = 'ForecastEnginePath'
		set @pathToForecastEngine_exe = @installPath_SQL + '\bin'

		update NSSESSION..syncSystemProperties
		set SysPropertyValue = @pathToForecastEngine_exe 
		where SysPropertyName = @sysPropertyName

		if @@rowcount > 0 
		begin
			print 'Set system property ''' + @sysPropertyName + ''' = ''' + @pathToForecastEngine_exe  + ''''
		end

		update #syncSystemProperties
		set SysPropertyValue_New = @pathToForecastEngine_exe
		where SysPropertyName = @sysPropertyName
	end

/* Exports */

	--|Path to syncExport.exe
	if @doUpdate = 1
	begin
		set @sysPropertyName = 'DataExportEnginePath'
		set @pathToSyncExport_exe = @installPath_Web + '\bin\SyncExport.exe'

		update syncSystemProperties
		set SysPropertyValue = @pathToSyncExport_exe
		where SysPropertyName = @sysPropertyName

		if @@rowcount > 0 
		begin
			print 'Set system property ''' + @sysPropertyName + ''' = ''' + @pathToSyncExport_exe + ''''	
		end

		update #syncSystemProperties
		set SysPropertyValue_New = @pathToSyncExport_exe
		where SysPropertyName = @sysPropertyName
	end

	--|  Returns/Adjustments Config
	if @doUpdate = 1
	begin  
		set @sysPropertyName = 'ExportConfigFilePath'

		select @sysPropertyValue = SysPropertyValue
		from syncSystemProperties
		where SysPropertyName = @sysPropertyName 

		--| Parse old file name
		if right( @sysPropertyValue, 4 ) = '.xml'
		begin
			select @charindex = charindex('\', @sysPropertyValue, 0)
			while @charindex > 0
			begin
				if  charindex('\', @sysPropertyValue, @charindex + 1) > 0 
					set @charindex = charindex('\', @sysPropertyValue, @charindex + 1)
				else 
					break
			end
			set @configFile = right( @sysPropertyValue, len( @sysPropertyValue ) - @charindex )
		end

		select @sysPropertyValue = 
			case @ver 
				when '3.0.00' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'ExportConfig.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'ExportConfig.xml' )
					end
				when '3.1.2.0002' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'ExportConfig.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'ExportConfig.xml' )
					end
				when '3.1.2.0004' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'ExportConfig.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'ExportConfig.xml' )
					end
				when '3.1.3.0000' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database
					else @installPath_Web + '\DataIO'
					end
				when '3.1.4.0001' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database
					else @installPath_Web + '\DataIO'
					end					
				else SysPropertyValue 
				end
		from syncSystemProperties
		where SysPropertyName = @sysPropertyName 

		update syncSystemProperties
		set SysPropertyValue = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
		
		if @@rowcount > 0 
		begin
			print 'Set system property ''' + @sysPropertyName + ''' = ''' + @sysPropertyValue + ''''	
		end

		update #syncSystemProperties
		set SysPropertyValue_New = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
	end

	--|  Forecast Config
	if @doUpdate = 1
	begin
		set @sysPropertyName = 'DataExportConfigFile'

		select @sysPropertyValue = SysPropertyValue
		from syncSystemProperties
		where SysPropertyName = @sysPropertyName 

		--| Parse old file name
		if right( @sysPropertyValue, 4 ) = '.xml'
		begin
			select @charindex = charindex('\', @sysPropertyValue, 0)
			while @charindex > 0
			begin
				if  charindex('\', @sysPropertyValue, @charindex + 1) > 0 
					set @charindex = charindex('\', @sysPropertyValue, @charindex + 1)
				else 
					break
			end
			set @configFile = right( @sysPropertyValue, len( @sysPropertyValue ) - @charindex )
		end

		select @sysPropertyValue =
			case @ver
				when '3.0.00' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'DailyForecastExport.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'DailyForecastExport.xml' )
					end 
				when '3.1.2.0002' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'DailyForecastExport.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'DailyForecastExport.xml' )
					end
				when '3.1.2.0004' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'DailyForecastExport.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'DailyForecastExport.xml' )
					end
				when '3.1.3.0000' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database
					else @installPath_Web + '\DataIO'
					end
				when '3.1.4.0001' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database
					else @installPath_Web + '\DataIO'
					end					
				else SysPropertyValue 
				end
 		from syncSystemProperties
		where SysPropertyName = @sysPropertyName 

		update syncSystemProperties
		set SysPropertyValue = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
		
		if @@rowcount > 0
		begin 
			print 'Set system property ''' + @sysPropertyName + ''' = ''' + @sysPropertyValue + ''''
		end

		update #syncSystemProperties
		set SysPropertyValue_New = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
	end

	--|  Invoices Config
	if @doUpdate = 1
	begin
		set @sysPropertyName = 'InvoiceExportConfigFilePath'

		select @sysPropertyValue = SysPropertyValue
		from syncSystemProperties
		where SysPropertyName = @sysPropertyName 

		--| Parse old file name
		if right( @sysPropertyValue, 4 ) = '.xml'
		begin
			select @charindex = charindex('\', @sysPropertyValue, 0)
			while @charindex > 0
			begin
				if  charindex('\', @sysPropertyValue, @charindex + 1) > 0 
					set @charindex = charindex('\', @sysPropertyValue, @charindex + 1)
				else 
					break
			end
			set @configFile = right( @sysPropertyValue, len( @sysPropertyValue ) - @charindex )
		end

		select @sysPropertyValue = 
			case @ver
				when '3.0.00' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					end 
				when '3.1.2.0002' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					end
				when '3.1.2.0004' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					end
				when '3.1.3.0000' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					end
				when '3.1.4.0001' then case @nestedCompanyFolders 
					when 1 then @installPath_Web + '\DataIO\' + @database + '\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					else @installPath_Web + '\DataIO\' + isnull( @configFile, 'InvoiceExportConfig.xml' )
					end
				else SysPropertyValue 
				end
		from syncSystemProperties
		where SysPropertyName = @sysPropertyName 

		update syncSystemProperties
		set SysPropertyValue = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
		and SysPropertyValue <> @sysPropertyValue
		
		if @@rowcount > 0
		begin 
			print 'Set system property ''' + @sysPropertyName + ''' = ''' + @sysPropertyValue + ''''
		end

		update #syncSystemProperties
		set SysPropertyValue_New = @sysPropertyValue
		where SysPropertyName = @sysPropertyName
	end

--|  Review System Configuration Settings
if @doUpdate = 1
begin
	select SysPropertyName
		, SysPropertyDisplayName
		, SysPropertyValue_Old
		, case 
			when SysPropertyValue_Old = SysPropertyValue_New then '(Same as Old.  No update.)'
			else SysPropertyValue_New
			end as [SysPropertyValue_New]
				
	from #syncSystemProperties
end
else
begin
	select SysPropertyName, SysPropertyValue_Old as [SysPropertyValue]
	from #syncSystemProperties
end

if @commitTran = 1
begin
	drop table #syncSystemProperties
	print 'transaction committed'
	commit tran	
end
else
begin
	drop table #syncSystemProperties
	print 'transaction rolled back'
	rollback tran
end

