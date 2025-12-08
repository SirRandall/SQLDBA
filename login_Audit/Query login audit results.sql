/* 2025-12-08 Randy Sheldon

    Query the Login_Audit table which captures connection statistics and aggregates them over time.
    The result shows WHO is connecting, from WHERE, and how OFTEN.


*/

--ignoreHost. These Hostnames will be ignored.
    DROP TABLE IF EXISTS #IgnoreHost
    CREATE TABLE #IgnoreHost (HostName sysname PRIMARY KEY);
    INSERT INTO #IgnoreHost
    (HostName)
    VALUES
     ('SC-SRV-SQL119'),('SC-SRV-SQL106'), ('NHAMON112'), ('001-RWIGGKWAGRP'),('001L-MDPD7OMKMP');

--ignoreApps. These applications will be ignored.
    DROP TABLE IF EXISTS #IgnoreAPP;
    CREATE TABLE #IgnoreApp (AppName sysname PRIMARY KEY);
    INSERT INTO #IgnoreApp
    (AppName)
    VALUES ('Redgate%'),('Red Gate%'),('Microsoft SQL Server Management Studio'),('Microsoft SQL Server Management Studio - Query');

--ignoreLogin. These logins will be ignored.
    DROP TABLE IF EXISTS #IgnoreLogin;
    CREATE TABLE #IgnoreLogin (LoginName sysname PRIMARY KEY);
    INSERT INTO #IgnoreLogin
    (LoginName)
    VALUES
    ('%rsheldon%');

--ignoreDatabase. These Databases will be ignored.
    DROP TABLE IF EXISTS #IgnoreDatabase;
    CREATE TABLE #IgnoreDatabase (databaseName sysname PRIMARY KEY);
    INSERT INTO #IgnoreDatabase
    (databaseName)
    VALUES
    ('master'),('tempdb'),('model'),('msdb'),('_DbaAdmin'),('Login_audit');


--BEGIN!
--Set @DatabaseNAme to a specific name, partial name, or blank for all.
DECLARE @DatabaseName sysname = ''

DROP TABLE IF EXISTS #History;
SELECT la.[DateHour]
      ,la.[DatabaseName]
      ,la.[HostName]
      ,la.[LoginName]
      ,la.[ApplicationName]
      ,la.[Hits]
  INTO #History
  FROM [Login_audit].[dbo].[LegitActions] LA
    LEFT JOIN #IgnoreDatabase idb
        ON la.DatabaseName = idb.databaseName
    LEFT JOIN #IgnoreLogin il
        ON la.LoginName like il.LoginName
    LEFT JOIN #IgnoreApp ia
        ON LA.ApplicationName LIKE ia.AppName
    LEFT JOIN #IgnoreHost ih
        ON LA.HostName = ih.HostName
  WHERE (la.DatabaseName LIKE @DatabaseName OR @DatabaseName = '')
    AND ia.AppName IS NULL
    AND ih.HostName IS NULL
    AND idb.databaseName IS NULL
    AND il.LoginName IS null
    AND la.DateHour > DATEADD(YEAR,-1,GETDATE())

--Results:
    SELECT H.DatabaseName, H.HostName, h.LoginName, h.ApplicationName
        , MAX(H.DateHour) [LastAccess], MAX(hits)
    FROM #History H
    GROUP BY h.DatabaseName, h.HostName, h.LoginName, h.ApplicationName
    ORDER BY h.DatabaseName, h.HostName, h.LoginName--, h.DateHour DESC
  
