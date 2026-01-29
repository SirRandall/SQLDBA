--Find Toxic Execution plans
/* 20260129, Randy Sheldon

    Overview:       Searches DMV query statistics looking for either specific SQL text  --- OR --- a specific query_hash.
                        --The query_hash can be found in SQL Monitor, after searching on 'Top Queries'

                    The results will also try to filter out queries executed by the program_name(s) included in CTE table 'xPrograms'


    Instructions:
                    1. Connect to the proper database (the same query in two different databases will have different hash values)
                    2. Set a value for EITHER @search_string   --- OR --- @Query_hash
                    3. Set the unused parameter to NULL
                    4. Choose @ShowToxicOnly = 1, if you only want to see the worst of the worst
                    5. Choose @ExclusdeDiagnosticQueries, if you want to try to ignore queries that are also querying the query_stats
*/
GO

USE myNHA_Main
GO

--Search for...
        DECLARE @search_string NVARCHAR(MAX) = NULL --N'Caseload' --N'select group_id, name, automated_backup_preference';
        DECLARE @query_hash binary(8) = 0x1e2715155742dcf5 --0xB70C87CDF06B4C06;

--Options
        DECLARE @ShowToxicOnly              BIT = 0;    --only show "toxic" results.
        DECLARE @ExcludeDiagnosticQueries   BIT = 1;    --set to 1 to exclude plans related to querying the [dm_exec_query_stats] table


WITH 
xPrograms AS 
(
    SELECT v.program_name
    FROM  (VALUES   
        ('Red Gate SQL Monitor')
        ,('Solarwinds')
        ) v(program_name)
),

stats AS
(
    SELECT  qs.plan_handle
          , qs.query_hash
          , qs.execution_count
          , qs.total_elapsed_time / 1000000.0                        AS total_elapsed_sec
          , qs.max_elapsed_time / 1000000.0                          AS max_elapsed_sec
          , qs.min_elapsed_time / 1000000.0                          AS min_elapsed_sec
          , (qs.total_elapsed_time / qs.execution_count) / 1000000.0 AS avg_elapsed_sec
          , qs.total_worker_time / 1000000.0                         AS total_cpu_sec
          , (qs.total_worker_time / qs.execution_count) / 1000000.0  AS avg_cpu_sec
          , qs.total_logical_reads / qs.execution_count              AS avg_logical_reads
          , qs.last_execution_time
          , st.text                                                  AS qry_text
          , s.program_name

    FROM    sys.dm_exec_query_stats                     qs

       LEFT JOIN sys.dm_exec_requests r
            ON qs.plan_handle = r.plan_handle
                AND r.session_id = @@SPID   -- 👈 exclude your session

           LEFT JOIN sys.dm_exec_sessions s
            ON r.session_id = s.session_id

        CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st  --query syntax

    WHERE   ((   qs.query_hash = @query_hash  AND @query_hash <> ''  )
            OR  
            (    st.text LIKE '%' + @search_string + '%' and   @search_string <> ''   )
            )

        AND r.session_id IS NULL

        AND ((@ExcludeDiagnosticQueries = 1 AND st.text NOT LIKE '%dm_exec_query_stats%')  
            OR 
             (@ExcludeDiagnosticQueries = 0)      --do NOT return plans that are generated simply by querying the stats
            )
)

--output 
    SELECT  plan_handle
          , stats.query_hash
          , execution_count
          , max_elapsed_sec
          , avg_elapsed_sec
          , avg_cpu_sec
          , avg_logical_reads
          , stats.last_execution_time
            /* Toxicity flags */
          , CASE
                WHEN max_elapsed_sec >= avg_elapsed_sec * 10 THEN
                    '🚨 Outlier execution (max >> 10x avg)'
                WHEN max_elapsed_sec >= 30 THEN
                    '🐢 Very slow execution (>30s)'
                WHEN execution_count <= 3
                     AND avg_elapsed_sec >= 5 THEN
                    '☠ Low exec count + expensive'
                WHEN avg_elapsed_sec >= avg_cpu_sec * 5 THEN
                    '⏳ Waiting / memory / IO bound'
                ELSE
                    'OK'
            END                                                                   AS toxicity_reason
          , CASE WHEN (max_elapsed_sec >= avg_elapsed_sec * 5) THEN 'Max_Elapsed >= (Avg_Elapsed * 5)' 
                 WHEN (max_elapsed_sec >= 10) THEN 'Max_Elaped >=10'
                 WHEN (execution_count <= 3
                            AND avg_elapsed_sec >= 3) THEN 'exec_count <=3 and Avg_Elapsed >=3'
                ELSE ''
            END  AS [concern]
          

            /* Numeric severity score */
          , CAST((max_elapsed_sec / NULLIF(avg_elapsed_sec, 0))
                 + (avg_elapsed_sec / NULLIF(avg_cpu_sec, 0)) AS DECIMAL(10, 2))  AS toxicity_score
          , 'DBCC FREEPROCCACHE (' + CONVERT(VARCHAR(100), plan_handle, 1) + ');' AS FreeProcStatement
          , qry_text
          
    FROM    stats

        LEFT JOIN xPrograms xp
            ON stats.program_name =  xp.program_name

    WHERE
        xp.program_name IS NULL
        AND
        

        (
            @ShowToxicOnly = 1
            AND (
                    max_elapsed_sec >= avg_elapsed_sec * 5
                    OR  max_elapsed_sec >= 10
                    OR  (
                            execution_count <= 3
                            AND avg_elapsed_sec >= 3
                        )
                )
        )
        OR  (@ShowToxicOnly = 0)
    ORDER BY toxicity_score DESC;

--DBCC FREEPROCCACHE (0x06000A00F3185217B0D8CEE6FB02000001000000000000000000000000000000000000000000000000000000);
