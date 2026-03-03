DECLARE @dbName sysname;
SET @dbName = 'ADSync'

SELECT '#TransSummary', * FROM dbo.tbl_Trans_Summary
WHERE DatabaseName = @dbName
--WHERE DatabaseName NOT IN ('Login_audit','_DbaAdmin')
ORDER BY DateHour DESC;

SELECT '#LegitActions', * FROM dbo.LegitActions
WHERE DatabaseName = @dbName
ORDER BY DateHour DESC;

SELECT '#PastYear', hostName, LoginName, MAX(DateHour) [LastAccess]
FROM dbo.LegitActions
WHERE DatabaseName = @dbName
	AND Datehour >= DATEADD(YEAR,-1, GETDATE())
GROUP BY HostName, loginname
ORDER BY MAX(DateHour) DESC;
