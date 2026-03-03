/*
Run this script on:

        SC-SRV-SQL150.Login_audit    -  This database will be modified

to synchronize it with a database with the schema represented by:

        SC-SRV-SQL106.Login_audit

You are recommended to back up your database before running this script

Script created by SQL Compare version 15.4.23.28990 from Red Gate Software Ltd at 2/24/2026 2:35:32 PM

*/
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL Serializable
GO
BEGIN TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating sequences'
GO
CREATE SEQUENCE [dbo].[TraceCollectBatchID]
AS bigint
START WITH 1
INCREMENT BY 1
MINVALUE -9223372036854775808
MAXVALUE 9223372036854775807
NO CYCLE
CACHE 
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[tbl_Parameters]'
GO
CREATE TABLE [dbo].[tbl_Parameters]
(
[paramName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[paramValue] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[testfield1] [bit] NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_tbl_Parameters] on [dbo].[tbl_Parameters]'
GO
ALTER TABLE [dbo].[tbl_Parameters] ADD CONSTRAINT [PK_tbl_Parameters] PRIMARY KEY CLUSTERED ([paramName])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[HostName]'
GO
CREATE FUNCTION [dbo].[HostName]
(
)
RETURNS NVARCHAR(100)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @str NVARCHAR(100)
	
	-- Add the T-SQL statements to compute the return value here
	SELECT @Str = paramvalue FROM dbo.tbl_Parameters WHERE paramName = 'SQLInstanceName'
	
	-- Return the result of the function
	RETURN @Str

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[CreateTransactionTrace]'
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
		exec sp_trace_setevent @TraceID, 114, 8 , @on			--HostName
--
		exec sp_trace_setevent @TraceID, 114, 1 , @on			--TextData
--
		exec sp_trace_setevent @TraceID, 114, 10, @on			--ApplicationName
		exec sp_trace_setevent @TraceID, 114, 3 , @on			--DatabaseID
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[tbl_Trans_audit]'
GO
CREATE TABLE [dbo].[tbl_Trans_audit]
(
[ID] [bigint] NOT NULL IDENTITY(1, 1),
[HostName] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ApplicationName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LoginName] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StartTime] [datetime] NOT NULL,
[DatabaseName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DatabaseID] [int] NOT NULL,
[TextData] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TraceCollectBatchID] [bigint] NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_tbl_Trans_audit] on [dbo].[tbl_Trans_audit]'
GO
ALTER TABLE [dbo].[tbl_Trans_audit] ADD CONSTRAINT [PK_tbl_Trans_audit] PRIMARY KEY CLUSTERED ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [NCI_Trans_Audit_TraceCollectBatchID_DatabaseID] on [dbo].[tbl_Trans_audit]'
GO
CREATE NONCLUSTERED INDEX [NCI_Trans_Audit_TraceCollectBatchID_DatabaseID] ON [dbo].[tbl_Trans_audit] ([TraceCollectBatchID], [DatabaseID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[ImportAndCycleTransactionTrace]'
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
	from dbo.tbl_Parameters
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
--	truncate table dbo.tbl_Trans_audit;

	--Get the NEXT sequence ID for capturing batches
	DECLARE @BatchID BIGINT;
	SET @BatchID = NEXT VALUE FOR TraceCollectBatchID;

	Insert into dbo.tbl_Trans_Audit
		(TraceCollectBatchID, HostName, ApplicationName, LoginName, StartTime, Databasename, DatabaseID, TextData)
		Select @BatchID, HostName, Left(ApplicationName,100), Left(LoginName,255), StartTime, Left(Databasename,50), DatabaseID, CAST(TextData AS NVARCHAR(1000))
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
				from dbo.[tbl_Parameters] 
				where [paramName] = 'MaxFileSizeMB'

			Select @MaxFileCount = Cast(IsNull(paramValue,20) as int)  
				from dbo.[tbl_Parameters] 
				where [paramName] = 'MaxFileCount'

			Exec dbo.CreateTransactionTrace @TransactionPath,@MAxFileSizeMB,@MaxFileCount, @NewTraceID output
			exec sp_trace_setstatus @NewTraceID, 1
		end
	
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[tbl_Trans_Summary]'
GO
CREATE TABLE [dbo].[tbl_Trans_Summary]
(
[DateHour] [datetime] NOT NULL,
[DatabaseName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[HostName] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LoginName] [varchar] (40) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ApplicationName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Hits] [int] NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_tbl_Trans_Summary] on [dbo].[tbl_Trans_Summary]'
GO
ALTER TABLE [dbo].[tbl_Trans_Summary] ADD CONSTRAINT [PK_tbl_Trans_Summary] PRIMARY KEY CLUSTERED ([DateHour], [DatabaseName], [HostName], [LoginName], [ApplicationName])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [NCI_tbl_Trans_Summary_DateHour] on [dbo].[tbl_Trans_Summary]'
GO
CREATE NONCLUSTERED INDEX [NCI_tbl_Trans_Summary_DateHour] ON [dbo].[tbl_Trans_Summary] ([DateHour])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[ResetCollectionTables]'
GO
CREATE PROC [dbo].[ResetCollectionTables]
AS

BEGIN


	TRUNCATE TABLE dbo.tbl_Trans_audit;

	TRUNCATE TABLE dbo.tbl_Trans_Summary;

	ALTER SEQUENCE dbo.TraceCollectBatchID RESTART WITH 1;


END

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[SummarizeTransAudit]'
GO
/****** Object:  StoredProcedure [dbo].[SummarizeTransAudit]    Script Date: 9/7/2016 11:03:00 AM ******/
CREATE proc [dbo].[SummarizeTransAudit]
as

--Aggrgate information from tbl_Trans_Audit into tbl_Trans_Summary

--Get the lastest batchID
	DECLARE @LatestBatchID BIGINT;

	SELECT @LatestBatchID = CAST(current_value AS BIGINT)
	FROM sys.sequences
	WHERE name = 'TraceCollectBatchID';

--Aggregate the LATEST batch into Temp table #t
	SELECT 
		DateAdd(HOUR,DatePart(HOUR,ta.StartTime), Cast(Convert(varchar(20),ta.StartTime,1) as datetime))	[DateHour]
		,ta.DatabaseName
		,ta.HostName
		,ta.LoginName
		,IsNull(ta.ApplicationName,'')	[ApplicationName]
		,Count(ta.DatabaseID) [Hits]
	INTO #T
	FROM [Login_Audit].[dbo].[tbl_Trans_audit] ta
	WHERE ta.TraceCollectBatchID = @LatestBatchID
	GROUP BY DateAdd(HOUR,DatePart(HOUR,ta.StartTime), Cast(Convert(varchar(20),ta.StartTime,1) as datetime))
		,ta.Databasename
		, ta.HostName
		, ta.LoginName
		, ta.ApplicationName
	ORDER BY 2;
		

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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[DatabasesWithNoConnections]'
GO



CREATE VIEW [dbo].[DatabasesWithNoConnections]
AS
    SELECT  S.name + CASE
                         WHEN S.state = 6 THEN
                             ' (offline)'
                         ELSE
                             ''
                     END [Name]
          , S.state
    FROM    sys.databases               S
        LEFT JOIN dbo.tbl_Trans_Summary T
                  ON T.DatabaseName = S.name
    WHERE
        S.name NOT IN ( 'master', 'model', 'msdb', 'tempdb' )
        AND T.DatabaseName IS NULL;

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[LegitActions]'
GO




/****** Script for SelectTopNRows command from SSMS  ******/
CREATE VIEW [dbo].[LegitActions]
AS

/* Returns data from tbl_Trans_Summary, but omits
    data that was specificallty generated from the Monitoring
    Server identitifed in tbl_Parameters where paramName = 'MonitoringServer'.

*/

SELECT ts.[DateHour]
      ,ts.[DatabaseName]
      ,ts.[HostName]
      ,ts.[LoginName]
      ,ts.[ApplicationName]
      ,ts.[Hits]
  FROM [Login_audit].[dbo].[tbl_Trans_Summary] ts

     CROSS APPLY (SELECT paramValue FROM dbo.tbl_Parameters WHERE paramName = 'MonitoringServer') mn

  WHERE ts.DatabaseName NOT IN ('_DBAAdmin', 'Login_audit')
	AND ts.hostname <> mn.paramvalue                --eliminates Monitoring server
	AND ts.hostname <> [Login_audit].dbo.HostName() --eliminates THIS server
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Transaction_Summary]'
GO

/****** Script for SelectTopNRows command from SSMS  ******/
CREATE VIEW [dbo].[Transaction_Summary]
AS


    SELECT  DATEADD(   HOUR
                     , DATEPART(HOUR, ta.StartTime)
                     , CAST(CONVERT(VARCHAR(20), ta.StartTime, 1) AS DATETIME)
                   )               [Hour]
          , ta.DatabaseName
          , ta.HostName
          , ta.LoginName
          , ta.ApplicationName
          , COUNT(ta.DatabaseID) [Calls]
    FROM    Login_audit.dbo.tbl_Trans_audit ta
        CROSS APPLY(
                       SELECT   paramValue
                       FROM dbo.tbl_Parameters
                       WHERE paramName = 'MonitoringServer'
                   )                              mn

    WHERE ta.HostName <> mn.paramValue
        AND ta.HostName <> [login_audit].dbo.HostName()
    GROUP BY
        DATEADD(
                   HOUR
                 , DATEPART(HOUR, ta.StartTime)
                 , CAST(CONVERT(VARCHAR(20), ta.StartTime, 1) AS DATETIME)
               )
      , ta.DatabaseName
      , ta.HostName
      , ta.LoginName
      , ta.ApplicationName;
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[DatabaseTransTrends]'
GO
CREATE proc [dbo].[DatabaseTransTrends] @StartDate datetime, @EndDate datetime, @DatabaseName varchar(100)
as
--Select @StartDate = '9/1/2016', @EndDate = '9/10/2016', @DatabaseName = 'Australia_commerce'

SELECT  db.name                             [DatabaseName]
      , CONVERT(VARCHAR(30), S.DateHour, 1) [FixedDate]
      , SUM(S.Hits)                         [Hits]
FROM    sys.databases                           db

    LEFT JOIN Login_audit.dbo.tbl_Trans_Summary S
              ON db.name = S.DatabaseName

WHERE
    db.name = @DatabaseName -- db.database_id > 4

    AND ( S.DateHour BETWEEN @StartDate AND @EndDate
            OR  ISNULL(S.DateHour, @EndDate) = @EndDate
        )
GROUP BY
    db.name
  , CONVERT(VARCHAR(30), S.DateHour, 1);

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
COMMIT TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
-- This statement writes to the SQL Server Log so SQL Monitor can show this deployment.
IF HAS_PERMS_BY_NAME(N'sys.xp_logevent', N'OBJECT', N'EXECUTE') = 1
BEGIN
    DECLARE @databaseName AS nvarchar(2048), @eventMessage AS nvarchar(2048)
    SET @databaseName = REPLACE(REPLACE(DB_NAME(), N'\', N'\\'), N'"', N'\"')
    SET @eventMessage = N'Redgate SQL Compare: { "deployment": { "description": "Redgate SQL Compare deployed to ' + @databaseName + N'", "database": "' + @databaseName + N'" }}'
    EXECUTE sys.xp_logevent 55000, @eventMessage
END
GO
DECLARE @Success AS BIT
SET @Success = 1
SET NOEXEC OFF
IF (@Success = 1) PRINT 'The database update succeeded'
ELSE BEGIN
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	PRINT 'The database update failed'
END
GO
