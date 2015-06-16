SET NOCOUNT ON
DECLARE @DBVER VARCHAR(10),
	@ENTITYNAME VARCHAR(500),
	@ATTRIBUTENAME VARCHAR(500),
	@DISPLAYVALUE VARCHAR(500),
	@EDRENTITYID INT,
	@EDRENTITYNAME VARCHAR(500)

PRINT 'HAWAII DEPARTMENT OF EDUCATION'
PRINT 'REPORT DATE: ' + CONVERT(VARCHAR,GETDATE())
PRINT ''

SELECT @DBVER = ATTRIBUTEVALUE
FROM SDMCONFIG..MERC_CONTROLPANEL
WHERE ATTRIBUTENAME = 'DBVER'

PRINT 'SQL SERVER: ' + @@SERVERNAME
PRINT 'DATABASE VERSION: ' + @DBVER
PRINT ''

PRINT 'EDR ENTITIES'
PRINT '------------'

DECLARE ENTITY_CURSOR CURSOR
FOR
	SELECT ME.ENTITYNAME, MA.ATTRIBUTENAME, LI.DISPLAYVALUE
	FROM SDMCONFIG..MERC_ENTITY ME
	INNER JOIN SDMCONFIG..MERC_KEY MK
		ON ME.ENTITYID = MK.ENTITYID
	INNER JOIN SDMCONFIG..MERC_KEYATTRIBUTE MKA
		ON MK.KEYID = MKA.KEYID
	INNER JOIN SDMCONFIG..MERC_ATTRIBUTE MA
		ON MKA.ATTRIBUTEID = MA.ATTRIBUTEID
	INNER JOIN SDMCONFIG..LISTITEM LI
		ON CAST(MK.KEYTYPE AS VARCHAR) = LI.KEYVALUE
	WHERE MK.KEYTYPE IN (20565,20566)
	AND ME.ENTITYTYPE = 20531
	ORDER BY ME.ENTITYNAME ASC
	
OPEN ENTITY_CURSOR
FETCH NEXT FROM ENTITY_CURSOR INTO @ENTITYNAME, @ATTRIBUTENAME, @DISPLAYVALUE
WHILE @@FETCH_STATUS = 0
BEGIN
	PRINT @ENTITYNAME + ' (' + @DISPLAYVALUE + ': ' + @ATTRIBUTENAME + ')'

FETCH NEXT FROM ENTITY_CURSOR INTO @ENTITYNAME, @ATTRIBUTENAME, @DISPLAYVALUE
END

CLOSE ENTITY_CURSOR
DEALLOCATE ENTITY_CURSOR

PRINT ''
PRINT 'CLIENT ENTITIES'
PRINT '---------------'

DECLARE ENTITY_CURSOR CURSOR
FOR
	SELECT ME.ENTITYNAME, MA.ATTRIBUTENAME, LI.DISPLAYVALUE, ME.EDRENTITYID
	FROM SDMCONFIG..MERC_ENTITY ME
	INNER JOIN SDMCONFIG..MERC_KEY MK
		ON ME.ENTITYID = MK.ENTITYID
	INNER JOIN SDMCONFIG..MERC_KEYATTRIBUTE MKA
		ON MK.KEYID = MKA.KEYID
	INNER JOIN SDMCONFIG..MERC_ATTRIBUTE MA
		ON MKA.ATTRIBUTEID = MA.ATTRIBUTEID
	INNER JOIN SDMCONFIG..LISTITEM LI
		ON CAST(MK.KEYTYPE AS VARCHAR) = LI.KEYVALUE
	WHERE MK.KEYTYPE IN (20565,20566)
	AND ME.ENTITYTYPE = 20530
	ORDER BY ME.ENTITYNAME ASC
	
OPEN ENTITY_CURSOR
FETCH NEXT FROM ENTITY_CURSOR INTO @ENTITYNAME, @ATTRIBUTENAME, @DISPLAYVALUE, @EDRENTITYID
WHILE @@FETCH_STATUS = 0
BEGIN
	IF PATINDEX('%<CONTAINER>%',@ENTITYNAME) > 0
	BEGIN
		SELECT @ENTITYNAME = RIGHT(LEFT(@ENTITYNAME,PATINDEX('%</CONTAINER>%',@ENTITYNAME)-1),PATINDEX('%</CONTAINER>%',@ENTITYNAME)-(PATINDEX('%<CONTAINER>%',@ENTITYNAME)+LEN('<CONTAINER>')))
	END

	SELECT	@EDRENTITYNAME = ENTITYNAME
	FROM	SDMCONFIG..MERC_ENTITY
	WHERE	ENTITYID = @EDRENTITYID

	PRINT @ENTITYNAME + ' (' + @DISPLAYVALUE + ': ' + @ATTRIBUTENAME  + ')'

FETCH NEXT FROM ENTITY_CURSOR INTO @ENTITYNAME, @ATTRIBUTENAME, @DISPLAYVALUE, @EDRENTITYID
END

CLOSE ENTITY_CURSOR
DEALLOCATE ENTITY_CURSOR

	PRINT ''
	PRINT 'ENTITY MAPPING'
	PRINT '--------------'

DECLARE ENTITYMAPPING_CURSOR CURSOR
FOR
	SELECT ME.ENTITYNAME, ME2.ENTITYNAME
	FROM SDMCONFIG..MERC_ENTITY ME
	INNER JOIN SDMCONFIG..MERC_ENTITY ME2
	ON ME.EDRENTITYID = ME2.ENTITYID
	WHERE ME.ENTITYTYPE = 20530
	
OPEN ENTITYMAPPING_CURSOR
FETCH NEXT FROM ENTITYMAPPING_CURSOR INTO @ENTITYNAME, @EDRENTITYNAME
WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @ENTITYNAME = RIGHT(LEFT(@ENTITYNAME,PATINDEX('%</CONTAINER>%',@ENTITYNAME)-1),PATINDEX('%</CONTAINER>%',@ENTITYNAME)-(PATINDEX('%<CONTAINER>%',@ENTITYNAME)+LEN('<CONTAINER>')))
	PRINT @ENTITYNAME + ' ---Maps-to---> ' + @EDRENTITYNAME

FETCH NEXT FROM ENTITYMAPPING_CURSOR INTO @ENTITYNAME, @EDRENTITYNAME
END

CLOSE ENTITYMAPPING_CURSOR
DEALLOCATE ENTITYMAPPING_CURSOR
