extends Node
## Persistent player settings (audio volumes, control layout, language, vibration).
## Stored in user://settings.json. Every change is clamped, saved and broadcast.

signal changed(key: String)
signal language_changed(code: String)

const PATH := "user://settings.json"

const DEFAULTS := {
	"master_volume": 0.9,
	"music_volume": 0.7,
	"sfx_volume": 0.85,
	"button_scale": 1.0,
	"button_opacity": 0.75,
	"vibration": true,
	"language": "ru",
	"difficulty": "normal",
}

var master_volume: float = 0.9
var music_volume: float = 0.7
var sfx_volume: float = 0.85
var button_scale: float = 1.0
var button_opacity: float = 0.75
var vibration: bool = true
var language: String = "ru"
var difficulty: String = "normal"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func load_settings() -> void:
	var values: Dictionary = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(PATH):
		var text := FileAccess.get_file_as_string(PATH)
		var json := JSON.new()
		var parsed: Variant = json.data if json.parse(text) == OK else null
		if parsed is Dictionary:
			for key: String in DEFAULTS.keys():
				if parsed.has(key):
					values[key] = parsed[key]
		else:
			push_warning("Settings: damaged settings file, using defaults")
	_apply(values)
	language_changed.emit(language)
	changed.emit("all")


func save_settings() -> bool:
	var data := {
		"schema": 1,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"button_scale": button_scale,
		"button_opacity": button_opacity,
		"vibration": vibration,
		"language": language,
		"difficulty": difficulty,
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Settings: cannot write %s" % PATH)
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	var values := _snapshot()
	values[key] = value
	_apply(values)
	save_settings()
	changed.emit(key)


func get_value(key: String) -> Variant:
	match key:
		"master_volume": return master_volume
		"music_volume": return music_volume
		"sfx_volume": return sfx_volume
		"button_scale": return button_scale
		"button_opacity": return button_opacity
		"vibration": return vibration
		"language": return language
		"difficulty": return difficulty
		_: return null


func set_language(code: String) -> void:
	if code != "ru" and code != "en":
		return
	language = code
	save_settings()
	language_changed.emit(language)
	changed.emit("language")


func _snapshot() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"button_scale": button_scale,
		"button_opacity": button_opacity,
		"vibration": vibration,
		"language": language,
		"difficulty": difficulty,
	}


func _apply(values: Dictionary) -> void:
	master_volume = clampf(float(values.get("master_volume", DEFAULTS["master_volume"])), 0.0, 1.0)
	music_volume = clampf(float(values.get("music_volume", DEFAULTS["music_volume"])), 0.0, 1.0)
	sfx_volume = clampf(float(values.get("sfx_volume", DEFAULTS["sfx_volume"])), 0.0, 1.0)
	button_scale = clampf(float(values.get("button_scale", DEFAULTS["button_scale"])), 0.6, 1.6)
	button_opacity = clampf(float(values.get("button_opacity", DEFAULTS["button_opacity"])), 0.15, 1.0)
	vibration = bool(values.get("vibration", DEFAULTS["vibration"]))
	var lang: String = str(values.get("language", DEFAULTS["language"]))
	language = lang if (lang == "ru" or lang == "en") else "ru"
	var diff: String = str(values.get("difficulty", DEFAULTS["difficulty"]))
	difficulty = diff if diff in ["easy", "normal", "nightmare"] else "normal"


func vibrate(ms: int = 30, amplitude: float = 0.6) -> void:
	if not vibration:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)
