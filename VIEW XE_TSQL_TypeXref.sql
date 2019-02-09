USE master;
GO

IF OBJECT_ID('XE_TSQL_TypeXref') IS NULL
	EXEC('CREATE VIEW XE_TSQL_TypeXref AS SELECT 1 AS Alias');
GO

/*
	This view attempts to map each Extended Events data type
	to a TSQL data type.
*/
ALTER VIEW dbo.XE_TSQL_TypeXref
AS
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
		WHEN 'uint64' THEN 'BIGINT'	--possible overflow?
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

		--These mappings? No clue. Default to NVARCHAR(MAX).
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
