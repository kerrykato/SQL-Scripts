-- Script generated on 10/6/2004 8:02 PM
-- By: TAKO\katokm
-- Server: (LOCAL)

BEGIN TRANSACTION            
  DECLARE @JobID BINARY(16)  
  DECLARE @ReturnCode INT    
  SELECT @ReturnCode = 0     
IF (SELECT COUNT(*) FROM msdb.dbo.syscategories WHERE name = N'SyncronexJob') < 1 
  EXECUTE msdb.dbo.sp_add_category @name = N'SyncronexJob'

  -- Delete the job with the same name (if it exists)
  SELECT @JobID = job_id     
  FROM   msdb.dbo.sysjobs    
  WHERE (name = N'DEMO_MakeDatesCurrent')       
  IF (@JobID IS NOT NULL)    
  BEGIN  
  -- Check if the job is a multi-server job  
  IF (EXISTS (SELECT  * 
              FROM    msdb.dbo.sysjobservers 
              WHERE   (job_id = @JobID) AND (server_id <> 0))) 
  BEGIN 
    -- There is, so abort the script 
    RAISERROR (N'Unable to import job ''DEMO_MakeDatesCurrent'' since there is already a multi-server job with this name.', 16, 1) 
    GOTO QuitWithRollback  
  END 
  ELSE 
    -- Delete the [local] job 
    EXECUTE msdb.dbo.sp_delete_job @job_name = N'DEMO_MakeDatesCurrent' 
    SELECT @JobID = NULL
  END 

BEGIN 

  -- Add the job
  EXECUTE @ReturnCode = msdb.dbo.sp_add_job @job_id = @JobID OUTPUT , @job_name = N'DEMO_MakeDatesCurrent', @owner_login_name = N'dmconfig', @description = N'No description available.', @category_name = N'SyncronexJob', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job steps
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 1, @step_name = N'Dispatch Edition', @command = N'/*
This script will add the number of months difference between the messagedate and the current date
i.e.  if the current date is july 8 and the messagedate is june 30, it will add one month to make the 
message date equal to the current month.  

This script will then adjust the month by -1 for any messagedates that are greater than the current date
*/
update demessage
set messagedatetime = dateadd(
	month, 
	datediff(month, messagedatetime, current_timestamp),
	messagedatetime
	)
where datediff(month, messagedatetime, current_timestamp) <> 0 

update demessage
set messagedatetime = dateadd(month, -1, messagedatetime)
where messagedatetime > dateadd(d, 1, convert(varchar, current_timestamp, 1))

--Sets date to today for non-complete messages
update demessage
set messagedatetime = dateadd(day, datediff(day, dateadd(month,datediff(month, messagedatetime, current_timestamp),messagedatetime), current_timestamp), dateadd(month,datediff(month, messagedatetime, current_timestamp),messagedatetime))
where messagestatusid not in (5,6)

--Keeps datepart(day) equal to messagedatetime day
update demessage
set messagestatusdatetime = dateadd
			(
			day,
			datediff(day, messagestatusdatetime, messagedatetime),
			messagestatusdatetime
			)
where datediff(day, messagestatusdatetime, messagedatetime) <> 0

update demessagestatushistory
set sdm_messagehistorydatetime = dateadd
			(
			day,
			datediff(day, sdm_messagehistorydatetime, messagedatetime),
			sdm_messagehistorydatetime
			)
from demessagestatushistory msh
inner join demessage m
on m.messageid = msh.sdm_messageid
where datediff(day, sdm_messagehistorydatetime, messagedatetime) <> 0', @database_name = N'SDMData', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 2
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1 

  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job schedules
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @JobID, @name = N'Start when SQL Server Agent Starts', @enabled = 1, @freq_type = 64
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @JobID, @name = N'Nightly', @enabled = 1, @freq_type = 4, @active_start_date = 20020502, @active_start_time = 10000, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_end_date = 99991231, @active_end_time = 235959
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


