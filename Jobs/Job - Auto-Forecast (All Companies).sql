-- Script generated on 6/29/2009 8:28 PM
-- By: PELICAN\katokm
-- Server: (LOCAL)

BEGIN TRANSACTION            
  DECLARE @JobID BINARY(16)  
  DECLARE @ReturnCode INT    
  SELECT @ReturnCode = 0     
IF (SELECT COUNT(*) FROM msdb.dbo.syscategories WHERE name = N'[Syncronex Job]') < 1 
  EXECUTE msdb.dbo.sp_add_category @name = N'[Syncronex Job]'

  -- Delete the job with the same name (if it exists)
  SELECT @JobID = job_id     
  FROM   msdb.dbo.sysjobs    
  WHERE (name = N'Syncronex:  Auto-Forecast (tomorrow)')       
  IF (@JobID IS NOT NULL)    
  BEGIN  
  -- Check if the job is a multi-server job  
  IF (EXISTS (SELECT  * 
              FROM    msdb.dbo.sysjobservers 
              WHERE   (job_id = @JobID) AND (server_id <> 0))) 
  BEGIN 
    -- There is, so abort the script 
    RAISERROR (N'Unable to import job ''Syncronex:  Auto-Forecast (tomorrow)'' since there is already a multi-server job with this name.', 16, 1) 
    GOTO QuitWithRollback  
  END 
  ELSE 
    -- Delete the [local] job 
    EXECUTE msdb.dbo.sp_delete_job @job_name = N'Syncronex:  Auto-Forecast (tomorrow)' 
    SELECT @JobID = NULL
  END 

BEGIN 

  -- Add the job
  EXECUTE @ReturnCode = msdb.dbo.sp_add_job @job_id = @JobID OUTPUT , @job_name = N'Syncronex:  Auto-Forecast (tomorrow)', @owner_login_name = N'nsAdmin', @description = N'No description available.', @category_name = N'[Syncronex Job]', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 0, @delete_level= 0
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job steps
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 1, @step_name = N'scForecastEngine_Run', @command = N'set nocount on

declare @company_name varchar(50)
declare @company_catalog varchar(50)
declare @sql varchar(4096)

declare company_cursor cursor
for
	select CoName, CoDbCatalog
	from NSSESSION..nsSessionCompanies

open company_cursor
fetch next from company_cursor into @company_name, @company_catalog 
while @@fetch_status = 0
begin
	print @company_name

	set @sql = ''use '' + @company_catalog + '' exec scForecastEngine_Run @DaysFromNow=1, @LoggingLevel=-1, @LogFile=Null, @Diagnostic=False''
	exec(@sql)

	fetch next from company_cursor into @company_name, @company_catalog 	
end

close company_cursor
deallocate company_cursor
', @database_name = N'NSSESSION', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 0, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 2
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1 

  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job schedules
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @JobID, @name = N'Daily', @enabled = 1, @freq_type = 4, @active_start_date = 20090622, @active_start_time = 50000, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_end_date = 99991231, @active_end_time = 235959
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the Target Servers
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @JobID, @server_name = N'(local)' 
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

END
COMMIT TRANSACTION          
GOTO   EndSave              
QuitWithRollback:
  IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION 
EndSave: 


