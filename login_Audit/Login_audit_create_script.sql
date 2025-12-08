USE [master]
GO


--Configure OLE automation on the server
	sp_configure 'show advanced options', 1;
	GO
	RECONFIGURE;
	GO
	sp_configure 'Ole Automation Procedures', 1;
	GO
	RECONFIGURE;
	GO
--Confirm it
	EXEC sp_configure 'Ole Automation Procedures';
	GO

Create database [Login_audit]
go

Alter database [Login_audit] MODIFY FILE
(NAME=N'Login_Audit',Size=128MB, MAXSIZE=UNLIMITED,FILEGROWTH=8MB)
go

Alter database [Login_audit] MODIFY FILE
(NAME=N'Login_Audit_log',Size=128MB, MAXSIZE=UNLIMITED,FILEGROWTH=8MB)
go

ALTER DATABASE [Login_audit] SET COMPATIBILITY_LEVEL = 100
GO

IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [Login_audit].[dbo].[sp_fulltext_database] @action = 'disable'
end
GO

ALTER DATABASE [Login_audit] SET ANSI_NULL_DEFAULT OFF 
GO

ALTER DATABASE [Login_audit] SET ANSI_NULLS OFF 
GO

ALTER DATABASE [Login_audit] SET ANSI_PADDING OFF 
GO

ALTER DATABASE [Login_audit] SET ANSI_WARNINGS OFF 
GO

ALTER DATABASE [Login_audit] SET ARITHABORT OFF 
GO

ALTER DATABASE [Login_audit] SET AUTO_CLOSE OFF 
GO

ALTER DATABASE [Login_audit] SET AUTO_SHRINK OFF 
GO

ALTER DATABASE [Login_audit] SET AUTO_UPDATE_STATISTICS ON 
GO

ALTER DATABASE [Login_audit] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO

ALTER DATABASE [Login_audit] SET CURSOR_DEFAULT  GLOBAL 
GO

ALTER DATABASE [Login_audit] SET CONCAT_NULL_YIELDS_NULL OFF 
GO

ALTER DATABASE [Login_audit] SET NUMERIC_ROUNDABORT OFF 
GO

ALTER DATABASE [Login_audit] SET QUOTED_IDENTIFIER OFF 
GO

ALTER DATABASE [Login_audit] SET RECURSIVE_TRIGGERS OFF 
GO

ALTER DATABASE [Login_audit] SET  DISABLE_BROKER 
GO

ALTER DATABASE [Login_audit] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO

ALTER DATABASE [Login_audit] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO

ALTER DATABASE [Login_audit] SET TRUSTWORTHY OFF 
GO

ALTER DATABASE [Login_audit] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO

ALTER DATABASE [Login_audit] SET PARAMETERIZATION SIMPLE 
GO

ALTER DATABASE [Login_audit] SET READ_COMMITTED_SNAPSHOT OFF 
GO

ALTER DATABASE [Login_audit] SET HONOR_BROKER_PRIORITY OFF 
GO

ALTER DATABASE [Login_audit] SET RECOVERY SIMPLE 
GO

ALTER DATABASE [Login_audit] SET  MULTI_USER 
GO

ALTER DATABASE [Login_audit] SET PAGE_VERIFY CHECKSUM  
GO

ALTER DATABASE [Login_audit] SET DB_CHAINING OFF 
GO

ALTER DATABASE [Login_audit] SET  READ_WRITE 
GO



--*********************** STOP ***********************
--****** EXECUTE PREVIOUS SCRIPTS THEN CONTINUE ******








/* For security reasons the login is created disabled and with a random password. */
/****** Object:  Login [login_audit_guest]    Script Date: 1/15/2019 9:41:08 AM ******/
use [master]
go

CREATE LOGIN [login_audit_guest] WITH PASSWORD=N'2922Twice', DEFAULT_DATABASE=[Login_audit]
	, DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO

USE [Login_audit]
GO
/****** Object:  User [login_audit_guest]    Script Date: 1/15/2019 9:41:10 AM ******/
CREATE USER [login_audit_guest] FOR LOGIN [login_audit_guest] WITH DEFAULT_SCHEMA=[dbo]
GO

--*********************** STOP ***********************
--****** EXECUTE PREVIOUS SCRIPTS THEN CONTINUE ******










/****** Object:  Table [dbo].[tbl_Parameters]    Script Date: 1/15/2019 9:41:10 AM ******/
USE [Login_audit]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Parameters](
	[paramName] [nvarchar](50) NOT NULL,
	[paramValue] [nvarchar](200) NOT NULL,
 CONSTRAINT [PK_tbl_Parameters] PRIMARY KEY CLUSTERED 
(
	[paramName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Trans_audit]    Script Date: 1/15/2019 9:41:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Trans_audit](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[HostName] [varchar](30) NOT NULL,
	[ApplicationName] [varchar](100) NULL,
	[LoginName] [varchar](255) NULL,
	[StartTime] [datetime] NOT NULL,
	[DatabaseName] [varchar](50) NOT NULL,
	[DatabaseID] [int] NOT NULL,
 CONSTRAINT [PK_tbl_Trans_audit] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Trans_Summary]    Script Date: 1/15/2019 9:41:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Trans_Summary](
	[DateHour] [datetime] NOT NULL,
	[DatabaseName] [varchar](100) NOT NULL,
	[HostName] [varchar](30) NOT NULL,
	[LoginName] [varchar](40) NOT NULL,
	[ApplicationName] [varchar](100) NOT NULL,
	[Hits] [int] NOT NULL,
 CONSTRAINT [PK_tbl_Trans_Summary] PRIMARY KEY CLUSTERED 
(
	[DateHour] ASC,
	[DatabaseName] ASC,
	[HostName] ASC,
	[LoginName] ASC,
	[ApplicationName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[DatabasesWithNoConnections]    Script Date: 1/15/2019 9:41:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE view [dbo].[DatabasesWithNoConnections]
as
Select S.name + Case when S.State = 6 then ' (offline)' else '' end [Name]
	, S.State
from sys.databases S
	left join tbl_Trans_Summary T
		on T.DatabaseName = S.Name
where S.name not in ('master','model','msdb')
	and T.DatabaseName is Null

GO
/****** Object:  View [dbo].[Transaction_Summary]    Script Date: 1/15/2019 9:41:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/
Create View [dbo].[Transaction_Summary]
as
	SELECT 
      DateAdd(HOUR,DatePart(HOUR,StartTime), Cast(Convert(varchar(20),StartTime,1) as datetime))	[Hour]
      ,[DatabaseName]
      ,[HostName]
      ,[LoginName]
	  ,[ApplicationName]
		      
      ,Count([DatabaseID]) [Calls]
  FROM [Login_Audit].[dbo].[tbl_Trans_audit]
  Group by DateAdd(HOUR,DatePart(HOUR,StartTime), Cast(Convert(varchar(20),StartTime,1) as datetime))
	,Databasename, HostName, LoginName, ApplicationName
--order by 6, DatabaseName, HostNAme, LoginNAme, ApplicationNAme
GO




/****** Object:  StoredProcedure [dbo].[CreateTransactionTrace]    Script Date: 1/15/2019 9:41:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  StoredProcedure [dbo].[CreateTransactionTrace]    Script Date: 9/7/2016 11:02:51 AM ******/
CREATE proc [dbo].[CreateTransactionTrace] @RootAuditPath nvarchar(256)
	, @MaxFileSizeMB bigint = 20
	, @MaxFileNumber int = 1
	, @NewTraceID int output
as

	declare @rc int
	declare @TraceID int

--Create Trace
	exec @rc = sp_trace_create @TraceID output
		, 2
		, @RootAuditPath
		, @maxfilesizeMB
		, NULL 
		, @MaxFileNumber

if (@rc != 0) goto error

-- Set the events
	declare @on bit
	set @on = 1
		--Audit Schema Object Access
		--http://www.databasejournal.com/features/mssql/article.php/3887996/Determining-Object-Access-Using-SQL-Server-Profiler.htm
		exec sp_trace_setevent @TraceID, 114, 8, @on			--HostName
	--	exec sp_trace_setevent @TraceID, 114, 1, @on			--TextData
		exec sp_trace_setevent @TraceID, 114, 10, @on			--ApplicationName
		exec sp_trace_setevent @TraceID, 114, 3, @on			--DatabaseID
		exec sp_trace_setevent @TraceID, 114, 11, @on			--LoginName
		exec sp_trace_setevent @TraceID, 114, 35, @on			--DatabaseName
		exec sp_trace_setevent @TraceID, 114, 12, @on			--SPID
		exec sp_trace_setevent @TraceID, 114, 14, @on			--StartTime

-- Set the Filters
	declare @intfilter int
		set @intfilter = 5

	exec sp_trace_setfilter @TraceID, 3, 0, 4, @intfilter		--DBID>=5. Don't monitor system databases
	exec sp_trace_setfilter @TraceID, 10, 0, 7, N'SQL Server Profiler - 9d6318ce-e48f-4885-9939-8079624f63cd'

goto finish

error: 
	select ErrorCode=@rc

finish: 
	Set @NewTraceID = @TraceID

GO
/****** Object:  StoredProcedure [dbo].[DatabaseTransTrends]    Script Date: 1/15/2019 9:41:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE proc [dbo].[DatabaseTransTrends] @StartDate datetime, @EndDate datetime, @DatabaseName varchar(100)
as
--Select @StartDate = '9/1/2016', @EndDate = '9/10/2016', @DatabaseName = 'Australia_commerce'

Select db.name							[DatabaseName]
	, Convert(varchar(30),s.Datehour,1) [FixedDate]
	, Sum(S.hits)		[Hits]
	from sys.databases db
	left join Login_audit.dbo.tbl_Trans_Summary S
		on db.name = s.DatabaseName
where db.name = @DatabaseName -- db.database_id > 4
	and (S.DateHour between @StartDate and @EndDate
		or IsNull(S.DateHour,@EndDate) = @EndDate)
group by db.name, Convert(varchar(30),s.Datehour,1)

GO
/****** Object:  StoredProcedure [dbo].[ImportAndCycleTransactionTrace]    Script Date: 1/15/2019 9:41:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  StoredProcedure [dbo].[ImportAndCycleTransactionTrace]    Script Date: 9/7/2016 11:03:09 AM ******/
CREATE Proc [dbo].[ImportAndCycleTransactionTrace] @RestartTrace int = 1
as

/* 3/18/2015 Randy Sheldon
	1. Stops currently running trace. If one isn't running, it creates one
	   if @RestartTrace = 1
	2. Imports data from stopped trace file
	3. Deletes selected trace
	4. Deletes trace TRC files created
	5. Starts a new identical trace 
*/
	Declare @TransactionPath nvarchar(200)
	Declare @TraceID int

--Get the paths for transaction audit
	Select @TransactionPath = paramValue
	from tbl_Parameters
	where paramName = 'Transaction_Audit_path'
		print '@TransactionPath = ' + @TransactionPath

--Find active TraceID for Transaction audit
	If Exists(Select Path from sys.traces where path Like @TransactionPath + '%') 
		begin
			Select @TraceID = ID 
			from sys.traces
			where Path like @TransactionPath + '%'

			print '@TraceID = ' + Cast(@traceID as varchar(2))

		end
	else
		goto Exit_
	
	
--Stop trace
	exec sp_trace_SetStatus @TraceID, 0


--Import information from the trace
	truncate table tbl_Trans_audit

	Insert into tbl_Trans_Audit
		(HostName, ApplicationName, LoginName, StartTime, Databasename, DatabaseID)
		Select HostName, Left(ApplicationName,100), Left(LoginName,255), StartTime, Left(Databasename,50), DatabaseID
		from fn_trace_gettable(@TransactionPath + '.trc', 20)
		where HostName is Not Null
			and StartTime is Not Null
			and DatabaseName is not null
		order by StartTime
		
		Select  Cast(@@rowcount as varchar(20)) + ' rows imported.'
		

--delete the previous trace
--	If @TraceID > 0 
	exec sp_trace_setStatus @TraceID, 2

--Clear out existing tracefiles in this directory, using Ole Automation
	Declare @Result int
	Declare @FSO_Token int
	Declare @DeletePath nvarchar(256)
		Set @DeletePath = @TransactionPath + '*.trc'

	Exec @Result = sp_OACreate 'Scripting.FileSystemObject', @FSO_Token OUTPUT
	Exec @Result = sp_OAMethod @FSO_Token, 'DeleteFile', NULL, @DeletePath
	Exec @Result = sp_OADestroy @FSO_Token

Exit_:
--Create a new Trace
		
	If @RestartTrace = 1
		begin
			Declare @NewTraceID int, @MaxFileSizeMB int, @MaxFileCount int
			Select @MAxFileSizeMB = Cast(IsNull(paramValue,20) as int) 
				from [tbl_Parameters] 
				where [paramName] = 'MaxFileSizeMB'

			Select @MaxFileCount = Cast(IsNull(paramValue,20) as int)  
				from [tbl_Parameters] 
				where [paramName] = 'MaxFileCount'

			Exec dbo.CreateTransactionTrace @TransactionPath,@MAxFileSizeMB,@MaxFileCount, @NewTraceID output
			exec sp_trace_setstatus @NewTraceID, 1
		end
	
GO
/****** Object:  StoredProcedure [dbo].[SummarizeTransAudit]    Script Date: 1/15/2019 9:41:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  StoredProcedure [dbo].[SummarizeTransAudit]    Script Date: 9/7/2016 11:03:00 AM ******/
CREATE proc [dbo].[SummarizeTransAudit]
as

--Aggrgate information from tbl_Trans_Audit
--into tbl_Trans_Summary

--Aggregate into Temp table #t
		SELECT 
		  DateAdd(HOUR,DatePart(HOUR,StartTime), Cast(Convert(varchar(20),StartTime,1) as datetime))	[DateHour]
		  ,[DatabaseName]
		  ,[HostName]
		  ,[LoginName]
		  ,IsNull([ApplicationName],'')	[ApplicationName]
		  ,Count([DatabaseID]) [Hits]
	  into #T
	  FROM [Login_Audit].[dbo].[tbl_Trans_audit]
	  Group by DateAdd(HOUR,DatePart(HOUR,StartTime), Cast(Convert(varchar(20),StartTime,1) as datetime))
		,Databasename, HostName, LoginName, ApplicationName
	order by 2
		

		--Update temp table with any records that might already exist
		Update #T
			Set Hits = T.Hits + S.Hits
			from #T T
				join tbl_Trans_Summary S
				on		T.DateHour			= S.DateHour
					and T.DatabaseNAme		= S.DatabaseName
					and T.HostName			= S.HostName
					and T.LoginName			= S.LoginName
					and T.ApplicationName	= S.ApplicationName

		--Delete matching records from tbl_Trans_Summary
			Delete from tbl_Trans_Summary
			from tbl_Trans_Summary S
				join #T T
					on		T.DateHour			= S.DateHour
						and T.DatabaseNAme		= S.DatabaseName
						and T.HostName			= S.HostName
						and T.LoginName			= S.LoginName
						and T.ApplicationName	= S.ApplicationName

		--Insert the rest
			Insert into tbl_Trans_Summary(DateHour, DatabaseName, HostName, LoginName, ApplicationNAme, Hits)
			Select distinct DateHour, Left(DatabaseName,100), Left(HostName,30), right(LoginName,40), Left(ApplicationName,100), Hits
			from #T

--No errors. Truncate source table
--	truncate table tbl_Trans_audit

Exit_:
	drop table #t


GO


--COMPLETED to HERE!

--SQL JOB
USE [msdb]
GO

/****** Object:  Job [Login_Audit_CycleTranTrace]    Script Date: 1/15/2019 10:06:15 AM ******/
BEGIN TRANSACTION

DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 1/15/2019 10:06:15 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
	BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Login_Audit_CycleTranTrace', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'nha\rsheldon', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Cycle Transaction tracer]    Script Date: 1/15/2019 10:06:15 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Cycle Transaction tracer', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec [dbo].[ImportAndCycleTransactionTrace]  1', 
		@database_name=N'Login_Audit', 
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Summarize Transaction Audit data]    Script Date: 1/15/2019 10:06:15 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Summarize Transaction Audit data', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec dbo.SummarizeTransAudit', 
		@database_name=N'Login_Audit', 
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Hourly', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20150318, 
		@active_end_date=99991231, 
		@active_start_time=170000, 
		@active_end_time=165959, 
		@schedule_uid=N'3fcaff1c-f054-488e-98ea-13131a43e0b0'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

--*********************** STOP ***********************
--****** EXECUTE PREVIOUS SCRIPTS THEN CONTINUE ******











--Populate Parameters
--Review parameter values, change as needed before executing
use Login_audit
go

Insert into [Login_audit].[dbo].[tbl_Parameters] (paramName, paramValue)
	values ('Login_Audit_path','D:\Login_audit\login_audit')
go
Insert into [Login_audit].[dbo].[tbl_Parameters] (paramName, paramValue)
	values ('MaxFileCount','50')
go
Insert into [Login_audit].[dbo].[tbl_Parameters] (paramName, paramValue)
	values ('MaxFileSizeMB','50')
go
Insert into [Login_audit].[dbo].[tbl_Parameters] (paramName, paramValue)
	values ('SQLInstanceName', @@SERVERNAME)
go
Insert into [Login_audit].[dbo].[tbl_Parameters] (paramName, paramValue)
	values ('Transaction_Audit_path', 'D:\Login_audit\' + @@servername + '_Trace')
go

--*********************** STOP ***********************
--****** EXECUTE PREVIOUS SCRIPTS THEN CONTINUE ******





--*****  CREATE THESE DIRECTORIES ON ALL NODES *****
exec master.sys.xp_create_subdir 'D:\login_audit\login_audit'






--Creates the first trace
use msdb
go
exec sp_start_job @job_name='Login_Audit_CycleTranTrace'



--**Utility**
/*
--Reset tables
use Login_audit
go

truncate table tbl_Trans_Summary
go

truncate table tbl_Trans_audit
go


--Backup database you created
use Master

EXECUTE dbo.DatabaseBackup
  @BackupType = 'FULL'		-- FULL|DIFF|LOG
 ,@Directory = '\\sqlbackups\SQL'	--specify multiple paths to stripe backup files evenly
 ,@Databases = 'login_audit' 	
 ,@Verify = 'N'
 ,@CleanupTime = 504		--hours
 ,@Compress = 'Y'
 ,@CopyOnly = 'N'
 ,@ChangeBackupType = 'Y'	
 ,@NumberOfFiles =1
 ,@CheckSum = 'N'
 ,@LogToTable = 'Y'
 ,@Execute = 'Y'

*/