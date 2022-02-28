/*
	XML shredder for sys.fn_xe_file_target_read_file
	Generates individual queries for each session event.
*/
DECLARE @XESessionName SYSNAME = 'system_health';
DECLARE @Tsql NVARCHAR(MAX) = '';

;WITH XE_TSQL_TypeXref
AS
(
	--Attempt to map each Extended Events data type to a TSQL data type.
	SELECT  
		o.name XE_type, o.description XE_type_description, 
		o.capabilities, o.capabilities_desc, o.type_size XE_type_size,
		CASE type_name
			--These mappings should be safe.
			--They correspond almost directly to each other.
			WHEN 'ansi_string' THEN 'VARCHAR(MAX)'
			WHEN 'binary_data' THEN 'VARBINARY(MAX)'
			WHEN 'boolean' THEN 'BIT'
			WHEN 'char' THEN 'VARCHAR(MAX)'
			WHEN 'guid' THEN 'UNIQUEIDENTIFIER'
			WHEN 'int16' THEN 'SMALLINT'
			WHEN 'int32' THEN 'INT'
			WHEN 'int64' THEN 'BIGINT'
			WHEN 'int8' THEN 'SMALLINT'
			WHEN 'uint16' THEN 'INT'
			WHEN 'uint32' THEN 'BIGINT'
			WHEN 'uint64' THEN 'BIGINT' --possible overflow?
			WHEN 'uint8' THEN 'SMALLINT'
			WHEN 'unicode_string' THEN 'NVARCHAR(MAX)'
			WHEN 'xml' THEN 'XML'

			--These mappings are based off of descriptions and type_size.
			WHEN 'cpu_cycle' THEN 'BIGINT'
			WHEN 'filetime' THEN 'BIGINT'
			WHEN 'wchar' THEN 'NVARCHAR(2)'

			--How many places of precision?
			WHEN 'float32' THEN 'NUMERIC(30, 4)'
			WHEN 'float64' THEN 'NUMERIC(30, 4)'

			--These mappings? Not sure. Default to NVARCHAR(MAX).
			WHEN 'activity_id' THEN 'NVARCHAR(MAX)'
			WHEN 'activity_id_xfer' THEN 'NVARCHAR(MAX)'
			WHEN 'ansi_string_ptr' THEN 'NVARCHAR(MAX)'
			WHEN 'callstack' THEN 'NVARCHAR(MAX)'
			WHEN 'guid_ptr' THEN 'NVARCHAR(MAX)'
			WHEN 'null' THEN 'NVARCHAR(MAX)'
			WHEN 'ptr' THEN 'NVARCHAR(MAX)'
			WHEN 'unicode_string_ptr' THEN 'NVARCHAR(MAX)'
		END AS SqlDataType
	FROM sys.dm_xe_objects o
	WHERE o.object_type = 'type'
),
AllSessionEventFields AS
(
	--Global Fields (Actions) across all events for the session.
	SELECT se.name EventName, sa.name EventField, 'action' AS XmlNodeName, 
		CASE WHEN x.SqlDataType IS NULL THEN 'text' ELSE 'value' END AS XmlSubNodeName,
		'Global Field' AS FieldType, o.type_name XE_type, 
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
	LEFT JOIN XE_TSQL_TypeXref x
		ON x.XE_type = o.type_name
	WHERE s.name = @XESessionName
	
	UNION

	 --Event Fields across all events for the session.
	SELECT se.name EventName, c.name EventField, 'data' AS XmlNodeName, 
		CASE WHEN x.SqlDataType IS NULL THEN 'text' ELSE 'value' END AS XmlSubNodeName,
		'Event Field' AS FieldType, c.type_name XE_type, 
		COALESCE(x.SqlDataType, 'NVARCHAR(MAX)') AS SqlDataType
	FROM sys.server_event_sessions s
	JOIN sys.server_event_session_events se
		ON se.event_session_id = s.event_session_id
	JOIN sys.dm_xe_object_columns c
		ON c.object_name = se.name
		AND c.column_type = 'data' 
	LEFT JOIN XE_TSQL_TypeXref x
		ON x.XE_type = c.type_name
	WHERE s.name = @XESessionName
)
SELECT @Tsql = @Tsql + CHAR(9) + 
	CASE 
		WHEN LAG(f.EventName) OVER(PARTITION BY f.EventName ORDER BY f.EventField) IS NULL THEN 
			CHAR(13) + CHAR(10) + 
			';WITH XEvents AS
(
	SELECT object_name, CAST(event_data AS XML) AS event_data
	FROM sys.fn_xe_file_target_read_file ( ''' + @XESessionName + '*.xel'', NULL, NULL, NULL ) 
	WHERE object_name = ''' + f.EventName + '''
)
SELECT object_name, event_data,
	--XEvent timestamp is UTC. Adjust for local server time.
	DATEADD(HOUR, DATEDIFF(HOUR, GETUTCDATE(), GETDATE()), event_data.value (''(/event/@timestamp)[1]'', ''DATETIME'')) AS [timestamp],' + CHAR(13) + CHAR(10) + 
			CHAR(9) + '--' + f.EventName + 
			CHAR(13) + CHAR(10) + CHAR(9)
		ELSE ''
	END +
	CASE
		WHEN f.SqlDataType = 'XML' THEN
			'event_data.query (''(/event/' + f.XmlNodeName + '[@name=''''' + f.EventField + ''''']/' +
			f.XmlSubNodeName + 

			--The XML chunk is wrapped in a [f.XmlSubNodeName] root node. Clicking on the XML 
			--in SSMS pops open a new tab showing the XML data. That's normal behavior.
			--For event field "showplan_xml", we want SSMS to pop open a new tab showing the Execution Plan. 
			--To do that, we need to exclude the "value" root node. We'll use an XML wildcard here.
			CASE WHEN f.EventField = 'showplan_xml' THEN '/*' ELSE '' END +

			')[1]'') AS [' + f.EventField + ']' + CHAR(13) + CHAR(10)
		ELSE
			'event_data.value (''(/event/' + f.XmlNodeName + '[@name=''''' + f.EventField + ''''']/' +
			f.XmlSubNodeName + ')[1]'', ''' + f.SqlDataType + ''') AS [' + f.EventField + ' (' + f.FieldType + ')]'
	END + 
	CASE 
		WHEN LEAD(f.EventName) OVER(PARTITION BY f.EventName ORDER BY f.EventField) IS NULL THEN 
			CHAR(13) + CHAR(10) + 'FROM XEvents;' + CHAR(13) + CHAR(10) + 'GO' 
		ELSE ',' 
	END + CHAR(13) + CHAR(10)
FROM AllSessionEventFields f
ORDER BY f.EventName, f.EventField

SELECT [Mega-Query] = @Tsql FOR XML PATH(''),TYPE
