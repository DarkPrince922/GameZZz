extends GutTest
## Spec section 4: every mandatory sound id must exist in the registry and point
## at a real, importable, non-silent file. Missing entry = failing test.

const AUDIO_DIR := "res://assets/audio"


func test_all_required_events_are_in_registry() -> void:
	var missing := DataDB.missing_sound_ids()
	assert_eq(missing, [], "these ids are missing from data/sounds.json: %s" % str(missing))


func test_registry_files_exist_and_import() -> void:
	var problems: Array = []
	for event_id: String in DataDB.sound_event_ids():
		var entry := DataDB.sound_event(event_id)
		for path: Variant in entry.get("files", []):
			if not FileAccess.file_exists(str(path)):
				problems.append("%s: file missing %s" % [event_id, path])
			elif not ResourceLoader.exists(str(path)):
				problems.append("%s: not importable %s" % [event_id, path])
	assert_eq(problems, [], "broken audio files: %s" % str(problems))


func test_music_files_exist_and_loop() -> void:
	var problems: Array = []
	for track_id: String in DataDB.music_ids():
		var entry := DataDB.music_track(track_id)
		var path := str(entry.get("file", ""))
		if path == "" or not FileAccess.file_exists(path):
			problems.append("%s: missing file" % track_id)
		elif not ResourceLoader.exists(path):
			problems.append("%s: not importable" % track_id)
		if entry.get("loop") != true:
			problems.append("%s: loop must be true" % track_id)
	assert_eq(problems, [], "music problems: %s" % str(problems))


func test_audio_streams_load() -> void:
	var failures: Array = []
	for event_id: String in DataDB.sound_event_ids():
		for path: Variant in DataDB.sound_event(event_id).get("files", []):
			var stream: AudioStream = load(str(path)) as AudioStream
			if stream == null:
				failures.append(str(path))
			elif stream.get_length() <= 0.0:
				failures.append("%s has zero length" % path)
	assert_eq(failures, [], "streams failed to load: %s" % str(failures))


func test_frequent_sounds_have_variants() -> void:
	var required := int(DataDB.required_events.get("min_variants_for_frequent", 2))
	for event_id: String in DataDB.required_events.get("frequent_events", []):
		var files: Array = DataDB.sound_event(event_id).get("files", [])
		assert_gte(files.size(), required,
			"%s needs >= %d variants to avoid annoying repeats" % [event_id, required])


func test_pitch_variance_is_reasonable() -> void:
	var limit := float(DataDB.required_events.get("max_pitch_variance", 0.2))
	for event_id: String in DataDB.sound_event_ids():
		var variance := float(DataDB.sound_event(event_id).get("pitch_variance", 0.0))
		assert_lte(variance, limit, "%s pitch variance is too wide" % event_id)


func test_audio_size_budget() -> void:
	var total := _dir_size(AUDIO_DIR)
	var budget := DataDB.audio_budget_bytes()
	assert_lte(total, budget, "assets/audio is %.2f MiB, budget %.2f MiB" % [
		float(total) / 1048576.0, float(budget) / 1048576.0])


func test_no_orphan_audio_files() -> void:
	var known: Dictionary = {}
	for event_id: String in DataDB.sound_event_ids():
		for path: Variant in DataDB.sound_event(event_id).get("files", []):
			known[str(path)] = true
	for track_id: String in DataDB.music_ids():
		known[str(DataDB.music_track(track_id).get("file", ""))] = true
	var orphans: Array = []
	for subdir: String in ["/sfx", "/music"]:
		var dir := DirAccess.open(AUDIO_DIR + subdir)
		if dir == null:
			continue
		for file_name: String in dir.get_files():
			if file_name.ends_with(".import"):
				continue
			var full := AUDIO_DIR + subdir + "/" + file_name
			if not known.has(full):
				orphans.append(full)
	assert_eq(orphans, [], "files not referenced by the registry: %s" % str(orphans))


func _dir_size(path: String) -> int:
	var total := 0
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				total += _dir_size(path + "/" + entry)
		elif not entry.ends_with(".import"):
			total += FileAccess.get_file_as_bytes(path + "/" + entry).size()
		entry = dir.get_next()
	dir.list_dir_end()
	return total
