extends Node
## Central audio: all gameplay sounds and music go through this autoload.
## - bus layout Master / Music / SFX / UI (created at runtime, no .tres needed)
## - pooled AudioStreamPlayer (hard cap from data/sounds.json, default 16)
## - random variant + random pitch for frequent sounds
## - AudioStreamPlayer2D for enemies, traps and bosses
## - music crossfade, looping ambience, pause mutes SFX but keeps menus alive

signal music_changed(track_id: String)

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const CROSSFADE_TIME := 0.7
const SPATIAL_POOL := 8

var last_missing_id: String = ""
var _pool: Array[AudioStreamPlayer] = []
var _spatial_pool: Array[AudioStreamPlayer2D] = []
var _spatial_parent: Node = null
var _streams: Dictionary = {}
var _next_player: int = 0
var _rng := RandomNumberGenerator.new()
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active := "a"
var _current_music: String = ""
var _ambience: AudioStreamPlayer
var _current_ambience: String = ""
var _paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	_build_pool()
	_build_music_players()
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = BUS_SFX
	add_child(_ambience)
	if get_node_or_null("/root/Settings") != null:
		apply_settings()
		Settings.changed.connect(_on_settings_changed)


# ------------------------------------------------------------------- buses
func _ensure_buses() -> void:
	for bus_name: String in [BUS_MUSIC, BUS_SFX, BUS_UI]:
		var index := AudioServer.get_bus_index(bus_name)
		if index == -1:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, BUS_MASTER)
		AudioServer.set_bus_mute(index, false)


func bus_index(bus_name: String) -> int:
	return AudioServer.get_bus_index(bus_name)


func has_buses() -> bool:
	return bus_index(BUS_MUSIC) != -1 and bus_index(BUS_SFX) != -1 and bus_index(BUS_UI) != -1


func apply_settings() -> void:
	if get_node_or_null("/root/Settings") == null:
		return
	_set_bus_volume(BUS_MASTER, Settings.master_volume)
	_set_bus_volume(BUS_MUSIC, Settings.music_volume)
	_set_bus_volume(BUS_SFX, Settings.sfx_volume)
	_set_bus_volume(BUS_UI, Settings.sfx_volume)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var value := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0005)))
	AudioServer.set_bus_mute(index, value <= 0.001)


func bus_volume(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func _on_settings_changed(key: String) -> void:
	if key == "master_volume" or key == "music_volume" or key == "sfx_volume" or key == "all":
		apply_settings()


# -------------------------------------------------------------------- pool
func _build_pool() -> void:
	var limit := _sound_limit()
	for i in limit:
		var player := AudioStreamPlayer.new()
		player.name = "SFX%d" % i
		player.bus = BUS_SFX
		add_child(player)
		_pool.append(player)


func _sound_limit() -> int:
	var limit := 16
	if get_node_or_null("/root/DataDB") != null:
		limit = DataDB.max_concurrent_sounds()
	return clampi(limit, 1, 32)


func pool_size() -> int:
	return _pool.size()


func active_sound_count() -> int:
	var count := 0
	for player: AudioStreamPlayer in _pool:
		if player.playing:
			count += 1
	return count


# -------------------------------------------------------------------- play
func play(event_id: String, pitch_shift: float = 1.0) -> void:
	var entry := _event(event_id)
	if entry.is_empty():
		return
	var stream := _pick_stream(entry, event_id)
	if stream == null:
		return
	var player := _next_free_player()
	if player == null:
		return
	player.stream = stream
	if entry.has("bus"):
		player.bus = str(entry["bus"])
	else:
		player.bus = BUS_SFX
	player.volume_db = float(entry.get("volume_db", -10.0))
	var variance := float(entry.get("pitch_variance", 0.0))
	var pitch := 1.0
	if variance > 0.0:
		pitch += _rng.randf_range(-variance, variance)
	player.pitch_scale = clampf(pitch * pitch_shift, 0.25, 3.0)
	player.play()


func play_at(event_id: String, position: Vector2, parent: Node = null) -> void:
	var entry := _event(event_id)
	if entry.is_empty():
		return
	var stream := _pick_stream(entry, event_id)
	if stream == null:
		return
	var player := _next_free_spatial(parent)
	if player == null:
		return
	player.stream = stream
	player.global_position = position
	player.volume_db = float(entry.get("volume_db", -10.0))
	var variance := float(entry.get("pitch_variance", 0.0))
	var pitch := 1.0
	if variance > 0.0:
		pitch += _rng.randf_range(-variance, variance)
	player.pitch_scale = clampf(pitch, 0.25, 3.0)
	player.play()


func play_spatial_or_global(event_id: String, position: Vector2, parent: Node = null) -> void:
	var entry := _event(event_id)
	if entry.is_empty():
		return
	if bool(entry.get("spatial", false)):
		play_at(event_id, position, parent)
	else:
		play(event_id)


func _event(event_id: String) -> Dictionary:
	if get_node_or_null("/root/DataDB") == null:
		return {}
	var entry := DataDB.sound_event(event_id)
	if entry.is_empty():
		last_missing_id = event_id
		print("WARNING: ", "AudioManager: unknown sound id '%s'" % event_id)
	return entry


func _pick_stream(entry: Dictionary, event_id: String) -> AudioStream:
	var files: Array = entry.get("files", [])
	if files.is_empty():
		if entry.has("file"):
			files = [entry["file"]]
		else:
			last_missing_id = event_id
			print("WARNING: ", "AudioManager: sound '%s' has no files" % event_id)
			return null
	var path := str(files[_rng.randi_range(0, files.size() - 1)])
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		last_missing_id = event_id
		print("WARNING: ", "AudioManager: missing audio file %s" % path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		print("WARNING: ", "AudioManager: cannot load %s" % path)
		return null
	_set_loop(stream, bool(entry.get("loop", false)))
	_streams[path] = stream
	return stream


func _next_free_player() -> AudioStreamPlayer:
	for i in _pool.size():
		var index := (_next_player + i) % _pool.size()
		if not _pool[index].playing:
			_next_player = (index + 1) % _pool.size()
			return _pool[index]
	# every player is busy: steal the oldest slot (never exceed the cap)
	var stolen := _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	return stolen


func _next_free_spatial(parent: Node) -> AudioStreamPlayer2D:
	var host := parent if parent != null else get_tree().current_scene
	if host == null:
		return null
	if _spatial_parent != host:
		_spatial_parent = host
		for player: AudioStreamPlayer2D in _spatial_pool:
			if is_instance_valid(player):
				player.queue_free()
		_spatial_pool.clear()
	for player: AudioStreamPlayer2D in _spatial_pool:
		if is_instance_valid(player) and not player.playing:
			return player
	if _spatial_pool.size() >= SPATIAL_POOL:
		return _spatial_pool[0]
	var spatial := AudioStreamPlayer2D.new()
	spatial.bus = BUS_SFX
	spatial.max_distance = 1400.0
	spatial.attenuation = 1.2
	host.add_child(spatial)
	_spatial_pool.append(spatial)
	return spatial


# ------------------------------------------------------------------- music
func _build_music_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = BUS_MUSIC
	_music_a.name = "MusicA"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = BUS_MUSIC
	_music_b.name = "MusicB"
	add_child(_music_b)


func current_music() -> String:
	return _current_music


func play_music(track_id: String, fade: float = CROSSFADE_TIME) -> void:
	if track_id == _current_music and (_music_a.playing or _music_b.playing):
		return
	var entry := _music_entry(track_id)
	if entry.is_empty():
		return
	var stream := _pick_stream(entry, track_id)
	if stream == null:
		return
	_set_loop(stream, bool(entry.get("loop", true)))
	var incoming := _music_b if _music_active == "a" else _music_a
	var outgoing := _music_a if _music_active == "a" else _music_b
	incoming.stream = stream
	incoming.volume_db = -40.0 if fade > 0.0 else _music_db(entry)
	incoming.play()
	if fade > 0.0:
		var tween := create_tween()
		tween.tween_property(incoming, "volume_db", _music_db(entry), fade)
		if outgoing.playing:
			var fade_out := create_tween()
			fade_out.tween_property(outgoing, "volume_db", -40.0, fade)
			fade_out.tween_callback(outgoing.stop)
	_music_active = "b" if _music_active == "a" else "a"
	_current_music = track_id
	music_changed.emit(track_id)


func stop_music(fade: float = CROSSFADE_TIME) -> void:
	for player: AudioStreamPlayer in [_music_a, _music_b]:
		if player == null or not player.playing:
			continue
		if fade > 0.0:
			var tween := create_tween()
			tween.tween_property(player, "volume_db", -40.0, fade)
			tween.tween_callback(player.stop)
		else:
			player.stop()
	_current_music = ""


func play_ambience(event_id: String) -> void:
	if event_id == _current_ambience:
		return
	var entry: Dictionary = _event(event_id)
	if entry.is_empty():
		entry = _music_entry(event_id)
	if entry.is_empty():
		return
	var stream := _pick_stream(entry, event_id)
	if stream == null:
		return
	_set_loop(stream, true)
	_ambience.stream = stream
	_ambience.volume_db = float(entry.get("volume_db", -20.0))
	_ambience.play()
	_current_ambience = event_id


func stop_ambience() -> void:
	_ambience.stop()
	_current_ambience = ""


func current_ambience() -> String:
	return _current_ambience


func _music_entry(track_id: String) -> Dictionary:
	if get_node_or_null("/root/DataDB") == null:
		return {}
	var entry := DataDB.music_track(track_id)
	if entry.is_empty():
		last_missing_id = track_id
		print("WARNING: ", "AudioManager: unknown music id '%s'" % track_id)
	return entry


func _music_db(entry: Dictionary) -> float:
	return float(entry.get("volume_db", -9.0))


# ------------------------------------------------------------------- pause
func set_paused(paused: bool) -> void:
	_paused = paused
	var sfx_index := AudioServer.get_bus_index(BUS_SFX)
	if sfx_index != -1:
		AudioServer.set_bus_mute(sfx_index, paused)
	# menu sounds stay on the UI bus, music keeps playing but ducked
	if get_node_or_null("/root/Settings") != null:
		_set_bus_volume(BUS_MUSIC, Settings.music_volume * (0.5 if paused else 1.0))


func is_paused() -> bool:
	return _paused


func _set_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if loop:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() / (2 * (2 if wav.stereo else 1))
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED


func _exit_tree() -> void:
	for player: AudioStreamPlayer in _pool:
		if is_instance_valid(player):
			player.stop()
