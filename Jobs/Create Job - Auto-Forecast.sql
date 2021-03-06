USE [msdb]
GO
/*
	Use the following command (or select from the Query menu option) to replace parameter values
	for dbcatalog and owner
	
		CTRL+SHIFT+M = Specify Values for Paramters

*/
DECLARE @jobName nvarchar(50)
DECLARE @jobCategoryName nvarchar(50)
DECLARE @dbCatalog nvarchar(25)
DECLARE @jobOwner nvarchar(25)

set @dbCatalog = N'<db_catalog, sysname, NSDB>'
set @jobName = '<job_name, sysname, Syncronex: Auto-Forecast>'
set @jobCategoryName = N'<job_category, sysname, SyncronexJob>'
set @jobOwner = N'<job_owner, sysname, nsAdmin>'

set @jobName = @jobName + UPPER( N' (<db_catalog, sysname, NSDB>)' )

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = @jobName)

--|  Delete the job if it already exists
IF  @jobId is not null
BEGIN
	print 'Job ''' + @jobName + ''' already exists.  Deleting job.'
	EXEC msdb.dbo.sp_delete_job @job_id=@jobId
END

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

--|  Add Job Category, if necessary
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=@jobCategoryName AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=@jobCategoryName
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END


--DECLARE @jobId BINARY(16)
--|  Add the job
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=@jobName, 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Run forecast engine for date range', 
		@category_name=@jobCategoryName, 
		@owner_login_name=@jobOwner, @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
	GOTO QuitWithRollback
ELSE
	print 'Added job: ''' + @jobName + ''''

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Auto-Forecast', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
declare @beginDate varchar(10)
declare @endDate varchar(10)
declare @beginDate_DaysOut int
declare @endDate_DaysOut int
declare @msg varchar(256)
declare @date datetime

set @beginDate_DaysOut = <forecastStart_DaysOut, sysname, 1>
set @endDate_DaysOut = <forecastEnd_DaysOut, sysname, 1>

set @begindate = convert(varchar, dateadd(d, @beginDate_DaysOut, getdate()), 1)
set @enddate = convert(varchar, dateadd(d, @endDate_DaysOut, getdate()), 1)
set @date = getdate()


if not exists ( 
	select 1 as [ForecastEngineRunning]
	from merc_ControlPanel 
	where AppLayer = ''ForecastEngine''
	and AttributeName = ''EngineLock''
	and AttributeValue = ''True'' 
)
begin
	set @msg = ''Auto-Forecast beginning for date range '''''' + @beginDate + '''''' to '''''' + @endDate + ''''''.''

	update merc_ControlPanel
	set AttributeValue = case AttributeName
		when ''BeginDate'' then @beginDate
		when ''EndDate'' then @endDate
		when ''LoggingLevel'' then ''0''
		when ''LogFile'' then NULL
		when ''DiagnosticOutput'' then ''False''
		when ''EngineRequest'' then ''true''
		when ''UserName'' then ''Scheduled Job''
		when ''UserId'' then ''-1''
		when ''OverwriteUserEdits'' then ''False''
		else AttributeValue
		end
	where AppLayer = ''ForecastEngine''
end
else
begin
	set @msg = ''Forecasting is locked.  Auto-Forecast for '''''' + @beginDate + '''''' to '''''' + @endDate + '''''' will not be executed.''
end

exec syncSystemLog_Insert @moduleId=2,@SeverityId=0,@CompanyId=1,@Message=@msg

exec nsMessages_INSERTNOTALREADY 
	@nsSubject=''Auto-Forecast''
	, @nsMessageText=@msg
	, @nsFromId = 8
	, @nsToId = 0
	, @nsGroupId = 2
	, @nsTime = @date
	, @nsPriorityId = 2 	--|  Normal
	, @nsStatusId = 3  	--|
	, @nsTypeId = 1		--|  Memo 
	, @nsStateId = 1
	, @nsCompareTime = @date
	, @nsAccountId = 0
', 
		@database_name=@dbCatalog, 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Auto-Forecast Job Schedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20091207, 
		@active_end_date=99991231, 
		@active_start_time=180000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
	IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
