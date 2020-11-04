DECLARE @XESessionName SYSNAME = 'CRUD';
DECLARE @Tsql NVARCHAR(MAX) = '';

;WITH AllSessionEventFields AS
(
	--Unique Global Fields (Actions) across all events for the session.
	SELECT DISTINCT sa.name EventField, 'action' AS XmlNodeName, 
		CASE WHEN x.SqlDataType IS NULL THEN 'text' ELSE 'value' END AS XmlSubNodeName,
		'Global Fields (Action)' AS FieldType, o.type_name XE_type, 
		COALESCE(x.SqlDataType, 'NVARCHAR(MAX)') AS SqlDataType
	FROM sys.server_event_sessions s
	JOIN sys.server_event_session_events se
		ON se.event_session_id = s.event_session_id
	JOIN sys.server_event_session_actions sa
		ON sa.event_session_id = s.event_session_id
		AND sa.event_id = se.event_id
	JOIN sys.dm_xe_objects o
		ON o.name = sa.name
		AND o.object_type = 'action'
	LEFT JOIN master.dbo.XE_TSQL_TypeXref x
		ON x.XE_type = o.type_name
	WHERE s.name = @XESessionName

	UNION

	 --Unique Event Fields across all events for the session.
	SELECT DISTINCT c.name EventField, 'data' AS XmlNodeName, 
		CASE WHEN x.SqlDataType IS NULL THEN 'text' ELSE 'value' END AS XmlSubNodeName,
		'Event Fields' AS FieldType, c.type_name XE_type, 
		COALESCE(x.SqlDataType, 'NVARCHAR(MAX)') AS SqlDataType
	FROM sys.server_event_sessions s
	JOIN sys.server_event_session_events se
		ON se.event_session_id = s.event_session_id
	JOIN sys.dm_xe_object_columns c
		ON c.object_name = se.name
		AND c.column_type = 'data' 
	LEFT JOIN master.dbo.XE_TSQL_TypeXref x
		ON x.XE_type = c.type_name
	WHERE s.name = @XESessionName
)
SELECT @Tsql = @Tsql + CHAR(9) + 
	CASE
		WHEN f.SqlDataType = 'XML' THEN
			'event_data.query (''(/event/' + f.XmlNodeName + '[@name=''''' + f.EventField + ''''']/' +
			f.XmlSubNodeName + 

			--The XML chunk is wrapped in a [f.XmlSubNodeName] root node. Clicking on the XML 
			--in SSMS pops open a new tab showing the XML data. That's normal behavior.
			--For event field "showplan_xml", we want SSMS to pop open a new tab showing the Execution Plan. 
			--To do that, we need to exclude the "value" root node. We'll use an XML wildcard here.
			CASE WHEN f.EventField = 'showplan_xml' THEN '/*' ELSE '' END +

			')[1]'') AS [' + f.EventField + '],' + CHAR(13) + CHAR(10)
		ELSE
			'event_data.value (''(/event/' + f.XmlNodeName + '[@name=''''' + f.EventField + ''''']/' +
			f.XmlSubNodeName + ')[1]'', ''' + f.SqlDataType + ''') AS [' + f.EventField + '],' + CHAR(13) + CHAR(10)
	END
FROM AllSessionEventFields f
ORDER BY f.EventField

SELECT @Tsql = LEFT(@Tsql, LEN(@Tsql) - 3);
SELECT @Tsql = ';WITH XEvents AS
(
	SELECT object_name, CAST(event_data AS XML) AS event_data
	FROM sys.fn_xe_file_target_read_file ( ''' + @XESessionName + '*.xel'', NULL, NULL, NULL )  
)
SELECT object_name, event_data,' + CHAR(13) + CHAR(10) + '
	--XEvent timestamp is UTC. Adjust for local server time.
	DATEADD(HOUR, DATEDIFF(HOUR, GETUTCDATE(), GETDATE()), event_data.value (''(/event/@timestamp)[1]'', ''DATETIME'')) AS [timestamp],' + CHAR(13) + CHAR(10) + @Tsql + '
FROM XEvents;';

--PRINT @Tsql;
SELECT [processing-instruction(x)] = @Tsql FOR XML PATH(''),TYPE
--EXEC(@Tsql);
