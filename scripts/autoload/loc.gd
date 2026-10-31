extends Node
## Localisation: RU/EN dictionaries from data/i18n/*.json.
## Missing keys fall back to English, then to the key itself, so the UI never breaks.

signal language_changed(code: String)

const LANG_DIR := "res://data/i18n/"
const LANGUAGES := ["ru", "en"]
const FALLBACK := "en"

var _tables: Dictionary = {}
var _current: String = FALLBACK


func _ready() -> void:
	_load_all()
	var code := "ru"
	if Engine.has_singleton("Settings") or get_node_or_null("/root/Settings") != null:
		code = str(Settings.language)
	set_language(code)


func _load_all() -> void:
	for code: String in LANGUAGES:
		var path := "%s%s.json" % [LANG_DIR, code]
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			_tables[code] = parsed if parsed is Dictionary else {}
		else:
			push_error("Loc: missing translation table %s" % path)
			_tables[code] = {}


func set_language(code: String) -> void:
	if not _tables.has(code):
		code = FALLBACK
	if _current == code and not _tables.is_empty():
		return
	_current = code
	language_changed.emit(_current)


func current_language() -> String:
	return _current


func text(key: String) -> String:
	var table: Dictionary = _tables.get(_current, {})
	if table.has(key):
		return str(table[key])
	var fallback: Dictionary = _tables.get(FALLBACK, {})
	if fallback.has(key):
		return str(fallback[key])
	return key


func textf(key: String, args: Array) -> String:
	var template := text(key)
	if args.is_empty():
		return template
	return template % args


func has_key(key: String) -> bool:
	return (_tables.get(_current, {}) as Dictionary).has(key)


func keys(code: String = "") -> Array:
	var target := code if code != "" else _current
	return (_tables.get(target, {}) as Dictionary).keys()
