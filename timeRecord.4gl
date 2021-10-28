IMPORT util
IMPORT os

CONSTANT C_FJS_MISC = "FJS Misc"
CONSTANT C_FJS_SUPP = "FJS Supp"
CONSTANT C_FJS_CLOUD = "FJS Cloud"
CONSTANT C_FJS_PM = "FJS PM"
CONSTANT C_FJS_DEV = "FJS Dev"
CONSTANT C_PS_PM = "PS PM"
CONSTANT C_PS_DEV = "PS Dev"
CONSTANT C_PREV_TASK = "Previous Task"
CONSTANT C_PREV_TASK_IMG = "fa-mail-reply"
CONSTANT C_EMAIL = "fa-envelope-o"
CONSTANT C_PHONE = "fa-phone"
CONSTANT C_TEAMS = "fa-windows"
CONSTANT C_TICKET = "fa-tag"

TYPE t_arr DYNAMIC ARRAY OF RECORD
	l_dt   DATETIME YEAR TO MINUTE,
	l_code STRING,
	l_jira STRING,
	l_what STRING
END RECORD
TYPE t_arr2 DYNAMIC ARRAY OF RECORD
	l_date DATE,
	l_time DATETIME HOUR TO MINUTE,
	l_dur  INTERVAL HOUR TO MINUTE,
	l_for  STRING,
	l_type STRING,
	l_jira STRING,
	l_what STRING
END RECORD
DEFINE m_codes   DYNAMIC ARRAY OF STRING
DEFINE m_quick   DYNAMIC ARRAY OF RECORD
		code STRING,
		desc STRING,
		img STRING
	END RECORD
DEFINE m_dataDir STRING
MAIN
	DEFINE l_str  STRING
	DEFINE l_jira STRING
	DEFINE l_cd   STRING
	DEFINE l_tmp  STRING
	DEFINE x, y, l_row SMALLINT
	DEFINE l_arr  t_arr
	DEFINE l_arr2 t_arr2
	DEFINE l_quick DYNAMIC ARRAY OF RECORD
		txt STRING,
		img STRING
	END RECORD

	LET m_dataDir = fgl_getenv("DATADIR")

	CALL getCodes()
	CALL getQuickEvents()
	FOR x = 1 TO m_quick.getLength()
		LET l_quick[x].txt = SFMT("%1 / %2", m_quick[x].code, m_quick[x].desc)
		LET l_quick[x].img = m_quick[x].img
	END FOR
	LET l_quick[x+1].txt = C_PREV_TASK
	LET l_quick[x+1].img = C_PREV_TASK_IMG

	CALL loadArr(l_arr, TODAY)
	IF l_arr.getLength() = 0 THEN
		LET l_arr[1].l_what = "Emails"
		LET l_tmp = TODAY||" 09:00"
		LET l_arr[1].l_dt = util.Datetime.parse(l_tmp,"%d/%m/%Y %H:%M")
		LET l_arr[1].l_code = C_FJS_MISC
	END IF
	CALL setup_arr2(l_arr, l_arr2)

	LET l_cd = C_FJS_MISC

	OPEN FORM f FROM "timeRecord"
	DISPLAY FORM f
	DISPLAY TODAY TO l_dte
	DIALOG ATTRIBUTES(UNBUFFERED)
		DISPLAY ARRAY l_quick TO tab.*
			ON ACTION quickEvent
				LET l_row           = arr_curr()
				LET x               = l_arr.getLength() + 1
				IF l_quick[l_row].txt = C_PREV_TASK THEN -- find previous ticket worked on
					FOR l_row = l_arr.getLength() TO 2 STEP -1
						IF l_arr[l_row].l_jira IS NOT NULL THEN
							EXIT FOR
						END IF
					END FOR
					IF l_arr[l_row].l_jira IS NOT NULL THEN
						LET l_arr[x].l_dt   = CURRENT
						LET l_arr[x].l_code = l_arr[l_row].l_code
						LET l_arr[x].l_what = l_arr[l_row].l_what
						LET l_arr[x].l_jira = l_arr[l_row].l_jira
					ELSE
						ERROR "No previous task!"
					END IF
				ELSE
					LET l_arr[x].l_dt   = CURRENT
					LET l_arr[x].l_code = m_quick[l_row].code
					LET l_arr[x].l_what = m_quick[l_row].desc
				END IF
				CALL setup_arr2(l_arr, l_arr2)
		END DISPLAY
		INPUT BY NAME l_str, l_jira, l_cd ATTRIBUTES(WITHOUT DEFAULTS)
			AFTER FIELD l_str
				IF l_str IS NOT NULL AND l_cd IS NULL THEN
					NEXT FIELD l_cd
				END IF
			AFTER FIELD l_jira
				IF l_jira.subString(1,5) = "SUPUK" THEN
					LET l_cd = C_FJS_SUPP
				END IF
			ON ACTION accept
				IF l_str IS NOT NULL AND l_cd IS NOT NULL THEN
					LET x               = l_arr.getLength() + 1
					LET l_arr[x].l_dt   = CURRENT
					LET l_arr[x].l_code = l_cd
					LET l_arr[x].l_what = l_str
					LET l_arr[x].l_jira = l_jira
					CALL setup_arr2(l_arr, l_arr2)
				END IF
				LET l_str  = ""
				LET l_jira = ""
				LET l_cd   = C_FJS_MISC
		END INPUT
		DISPLAY ARRAY l_arr2 TO arr.*
			BEFORE ROW
				IF l_str IS NULL THEN
					LET x      = arr_curr()
					LET l_str  = l_arr[x].l_what
					LET l_jira = l_arr[x].l_jira
					LET l_cd   = l_arr[x].l_code
				END IF
			ON ACTION update
				LET x        = arr_curr()
				LET y        = scr_line()
				LET int_flag = FALSE
				INPUT l_arr2[x].l_time, l_arr2[x].l_jira, l_arr2[x].l_what FROM arr[y].l_time, arr[y].l_jirano, arr[y].l_what
						ATTRIBUTES(WITHOUT DEFAULTS)
				IF NOT int_flag THEN
					LET l_arr[x].l_what = l_arr2[x].l_what
					LET l_arr[x].l_jira = l_arr2[x].l_jira
					LET l_tmp           = l_arr2[y].l_date || " " || l_arr2[y].l_time
					LET l_arr[x].l_dt = util.Datetime.parse(l_tmp, "%d/%m/%Y %H:%M")
					CALL setup_arr2(l_arr, l_arr2)
				END IF
		END DISPLAY
		ON ACTION clear
			LET l_str  = ""
			LET l_jira = ""
			LET l_cd   = C_FJS_MISC
			NEXT FIELD l_str
		ON ACTION close
			LET int_flag = FALSE
			EXIT DIALOG
		ON ACTION abort
			LET int_flag = TRUE
			EXIT DIALOG
		ON ACTION viewDate
			CALL viewDate()
			DISPLAY TODAY TO l_dte
	END DIALOG

	IF NOT int_flag THEN
		CALL saveArr(l_arr, TODAY)
	END IF
END MAIN
--------------------------------------------------------------------------------
FUNCTION getQuickEvents()
	DEFINE l_file STRING
	DEFINE l_json TEXT
	DEFINE x SMALLINT
	LET l_file = os.Path.join(m_dataDir, "quickEvents.json")
	IF os.Path.exists(l_file) THEN
		LOCATE l_json IN FILE l_file
		CALL util.JSONArray.parse(s: l_json).toFGL(m_quick)
	ELSE
		LET x = 1
		LET m_quick[x].code = C_FJS_MISC
		LET m_quick[x].img = C_EMAIL
		LET m_quick[x].desc = "Email" LET x = x + 1
		LET m_quick[x].code = C_FJS_MISC
		LET m_quick[x].img = C_PHONE
		LET m_quick[x].desc = "Phone" LET x = x + 1
		LET m_quick[x].code = C_FJS_MISC
		LET m_quick[x].img = C_TEAMS
		LET m_quick[x].desc = "Teams" LET x = x + 1
		LET m_quick[x].code = C_FJS_SUPP
		LET m_quick[x].img = C_TICKET
		LET m_quick[x].desc = "Work on " LET x = x + 1
		LET m_quick[x].code = C_FJS_SUPP
		LET m_quick[x].img = C_PHONE
		LET m_quick[x].desc = "Phone" LET x = x + 1
		LET m_quick[x].code = C_FJS_DEV
		LET m_quick[x].img = C_TICKET
		LET m_quick[x].desc = "Work on" LET x = x + 1

		LET m_quick[x].code = C_FJS_CLOUD
		LET m_quick[x].img = C_EMAIL
		LET m_quick[x].desc = "Email" LET x = x + 1
		LET m_quick[x].code = C_FJS_CLOUD
		LET m_quick[x].img = C_PHONE
		LET m_quick[x].desc = "Phone" LET x = x + 1

		LET m_quick[x].code = C_PS_PM
		LET m_quick[x].img = C_TICKET
		LET m_quick[x].desc = "Work on" LET x = x + 1
		LET m_quick[x].code = C_PS_DEV
		LET m_quick[x].img = C_TICKET
		LET m_quick[x].desc = "Work on" LET x = x + 1
		LOCATE l_json IN FILE l_file
		LET l_json = util.JSON.stringify(m_quick)
		DISPLAY "quickEvents.json is missing, created"
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getCodes()
	DEFINE l_file STRING
	DEFINE l_json TEXT
	LET l_file = os.Path.join(m_dataDir, "codes.json")
	IF os.Path.exists(l_file) THEN
		LOCATE l_json IN FILE l_file
		CALL util.JSONArray.parse(s: l_json).toFGL(m_codes)
	ELSE
		LET m_codes[1] = C_FJS_MISC
		LET m_codes[2] = C_FJS_SUPP
		LET m_codes[3] = C_FJS_CLOUD
		LET m_codes[4] = C_FJS_PM
		LET m_codes[5] = C_FJS_DEV
		LET m_codes[6] = C_PS_PM
		LET m_codes[7] = C_PS_DEV
		LOCATE l_json IN FILE l_file
		LET l_json = util.JSON.stringify(m_codes)
		DISPLAY "codes.json is missing, created"
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION codes(l_cb ui.comboBox)
	DEFINE x SMALLINT
	FOR x = 1 TO m_codes.getLength()
		CALL l_cb.addItem(m_codes[x], m_codes[x])
	END FOR
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION loadArr(l_arr t_arr, l_dte DATE) RETURNS()
	DEFINE l_file STRING
	DEFINE l_json TEXT
	CALL l_arr.clear()
	LET l_file = os.Path.join(m_dataDir, "data" || util.Datetime.format(l_dte, "%y%m%d") || ".json")
	IF NOT os.Path.exists(l_file) THEN
		RETURN
	END IF
	IF NOT os.Path.copy(l_file, l_file || ".bak") THEN
		CALL fgl_winMessage("Error", SFMT("Failed to make a backup of %1 !", l_file), "exclamation")
		EXIT PROGRAM
	END IF
	LOCATE l_json IN FILE l_file
	IF os.Path.exists(l_file) THEN
		CALL util.JSON.parse(l_json, l_arr)
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION saveArr(l_arr t_arr, l_dte DATE) RETURNS()
	DEFINE l_file STRING
	DEFINE l_json TEXT
	LET l_file = os.Path.join(m_dataDir, "data" || util.Datetime.format(l_dte, "%y%m%d") || ".json")
	LOCATE l_json IN FILE l_file
	LET l_json = util.JSON.stringify(l_arr)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION setup_arr2(l_arr t_arr, l_arr2 t_arr2) RETURNS()
	DEFINE x, y SMALLINT
	CALL l_arr2.clear()
	FOR x = 1 TO l_arr.getLength()
		LET l_arr2[x].l_date = l_arr[x].l_dt
		LET l_arr2[x].l_time = l_arr[x].l_dt
		IF x < l_arr.getLength() THEN
			LET l_arr2[x].l_dur = l_arr[x + 1].l_dt - l_arr[x].l_dt
		END IF
		LET y                = l_arr[x].l_code.getIndexOf(" ", 1)
		LET l_arr2[x].l_for  = l_arr[x].l_code.subString(1, y - 1)
		LET l_arr2[x].l_type = l_arr[x].l_code.subString(y + 1, l_arr[x].l_code.getLength())
		LET l_arr2[x].l_jira = l_arr[x].l_jira
		LET l_arr2[x].l_what = l_arr[x].l_what
	END FOR
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION viewDate() RETURNS()
	DEFINE l_dte  DATE
	DEFINE l_arr  t_arr
	DEFINE l_arr2 t_arr2

	DIALOG ATTRIBUTES(UNBUFFERED)
		INPUT BY NAME l_dte
			ON CHANGE l_dte
				IF l_dte IS NOT NULL THEN
					CALL loadArr(l_arr, l_dte)
					IF l_arr.getLength() = 0 THEN
						ERROR "No data for date!"
						NEXT FIELD l_dte
					END IF
					CALL setup_arr2(l_arr, l_arr2)
				END IF
		END INPUT
		DISPLAY ARRAY l_arr2 TO arr.*
		END DISPLAY
		ON ACTION cancel
			EXIT DIALOG
	END DIALOG
END FUNCTION
