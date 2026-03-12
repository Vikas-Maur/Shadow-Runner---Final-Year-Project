extends Node

const GAME_SCENE := "res://scenes/game.tscn"
const SAVE_PATH := "user://game_state.cfg"
const DEFAULT_LEVEL_INDEX := 0
const DEBUG_SHORTCUT_LEVEL_KEYS := {
	KEY_1: 0,
	KEY_2: 1,
	KEY_3: 2,
	KEY_KP_1: 0,
	KEY_KP_2: 1,
	KEY_KP_3: 2
}

const LEVELS := [
	{
		"id": "level_1",
		"scene_path": "res://scenes/levels/level_1.tscn",
		"transition_scene_path": ""
	},
	{
		"id": "level_2",
		"scene_path": "res://scenes/levels/level_2.tscn",
		"transition_scene_path": ""
	},
	{
		"id": "level_3",
		"scene_path": "res://scenes/levels/level_3.tscn",
		"transition_scene_path": ""
	}
]

signal current_level_changed(level_index: int)
signal score_changed(current_score: int)

var current_level_index: int = 0
var pending_level_index: int = -1
var times_opened: int = 0
var current_score: int = 0
var has_saved_progress: bool = false
var saved_level_index: int = DEFAULT_LEVEL_INDEX
var saved_player_position: Vector2 = Vector2.ZERO
var saved_player_health: int = -1
var _resume_from_saved_state: bool = false
var _one_time_flags: Dictionary = {}
var _defeated_enemy_keys: Dictionary = {}
var _collected_item_keys: Dictionary = {}

func _ready() -> void:
	_load_game_state()
	times_opened += 1
	_save_game_state()
	current_level_index = clamp(current_level_index, 0, LEVELS.size() - 1)
	set_process_input(are_development_tools_enabled())

func _input(event: InputEvent) -> void:
	if not are_development_tools_enabled():
		return

	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		var target_level_index: int = int(DEBUG_SHORTCUT_LEVEL_KEYS.get(event.keycode, -1))
		if target_level_index >= 0:
			load_level(target_level_index)
			get_viewport().set_input_as_handled()

func start_new_game() -> void:
	current_level_index = DEFAULT_LEVEL_INDEX
	pending_level_index = -1
	_resume_from_saved_state = false
	_clear_progress_state()
	current_level_changed.emit(current_level_index)

func are_development_tools_enabled() -> bool:
	return OS.is_debug_build()

func can_continue() -> bool:
	return has_saved_progress and not get_level_scene_path(saved_level_index).is_empty()

func prepare_continue() -> bool:
	if not can_continue():
		return false

	current_level_index = saved_level_index
	pending_level_index = -1
	_resume_from_saved_state = true
	current_level_changed.emit(current_level_index)
	return true

func save_player_progress(level_index: int, player_position: Vector2, player_health: int) -> void:
	if get_level_scene_path(level_index).is_empty():
		return

	var normalized_level_index: int = clamp(level_index, 0, LEVELS.size() - 1)
	var normalized_player_health: int = max(player_health, 0)
	if (
		has_saved_progress
		and saved_level_index == normalized_level_index
		and saved_player_position.is_equal_approx(player_position)
		and saved_player_health == normalized_player_health
	):
		return

	has_saved_progress = true
	saved_level_index = normalized_level_index
	saved_player_position = player_position
	saved_player_health = normalized_player_health
	_save_game_state()

func consume_resume_player_position(level_index: int) -> Dictionary:
	var should_resume: bool = _resume_from_saved_state and has_saved_progress and saved_level_index == level_index
	_resume_from_saved_state = false
	if not should_resume:
		return {
			"available": false,
			"position": Vector2.ZERO,
			"health": -1
		}

	return {
		"available": true,
		"position": saved_player_position,
		"health": saved_player_health
	}

func get_current_level_index() -> int:
	return current_level_index

func find_level_index_by_scene_path(scene_path: String) -> int:
	for level_index in LEVELS.size():
		if String(LEVELS[level_index].get("scene_path", "")) == scene_path:
			return level_index

	return -1

func get_times_opened() -> int:
	return times_opened

func get_score() -> int:
	return current_score

func add_score(amount: int = 1) -> void:
	if amount <= 0:
		return

	current_score += amount
	score_changed.emit(current_score)
	_save_game_state()

func build_progress_key(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""

	var level_root: Node = _find_level_root_for_node(node)
	if level_root == null:
		return ""

	var level_scene_path: String = level_root.scene_file_path
	var level_index: int = find_level_index_by_scene_path(level_scene_path)
	var level_id: String = get_level_id(level_index) if level_index >= 0 else level_root.name
	var relative_path: String = String(level_root.get_path_to(node))
	return "%s::%s" % [level_id, relative_path]

func is_enemy_defeated(node: Node) -> bool:
	return _has_progress_key(_defeated_enemy_keys, build_progress_key(node))

func register_enemy_defeat(node: Node) -> bool:
	return _register_progress_key(_defeated_enemy_keys, build_progress_key(node))

func is_item_collected(node: Node) -> bool:
	return _has_progress_key(_collected_item_keys, build_progress_key(node))

func register_collected_item(node: Node) -> bool:
	return _register_progress_key(_collected_item_keys, build_progress_key(node))

func has_one_time_flag(flag_name: String) -> bool:
	return bool(_one_time_flags.get(flag_name, false))

func mark_one_time_flag_seen(flag_name: String) -> bool:
	if flag_name.is_empty() or has_one_time_flag(flag_name):
		return false

	_one_time_flags[flag_name] = true
	_save_game_state()
	return true

func reset_game_state() -> void:
	current_level_index = DEFAULT_LEVEL_INDEX
	pending_level_index = -1
	_resume_from_saved_state = false
	_clear_progress_state()
	current_level_changed.emit(current_level_index)

func has_next_level(level_index: int = current_level_index) -> bool:
	return level_index >= 0 and level_index < LEVELS.size() - 1

func get_current_level_scene_path() -> String:
	return get_level_scene_path(current_level_index)

func get_level_scene_path(level_index: int) -> String:
	if level_index < 0 or level_index >= LEVELS.size():
		return ""
	return String(LEVELS[level_index].get("scene_path", ""))

func get_current_level_id() -> String:
	return get_level_id(current_level_index)

func get_level_id(level_index: int) -> String:
	if level_index < 0 or level_index >= LEVELS.size():
		return ""
	return String(LEVELS[level_index].get("id", ""))

func advance_to_next_level() -> bool:
	if not has_next_level():
		return false

	var next_level_index := current_level_index + 1
	var transition_scene_path := String(LEVELS[current_level_index].get("transition_scene_path", ""))
	if not transition_scene_path.is_empty():
		pending_level_index = next_level_index
		get_tree().change_scene_to_file(transition_scene_path)
		return true

	return load_level(next_level_index)

func load_level(level_index: int) -> bool:
	var scene_path := get_level_scene_path(level_index)
	if scene_path.is_empty():
		return false

	current_level_index = level_index
	pending_level_index = -1
	_resume_from_saved_state = false
	current_level_changed.emit(current_level_index)
	get_tree().change_scene_to_file(GAME_SCENE)
	return true

func complete_pending_transition() -> bool:
	if pending_level_index < 0:
		return false

	var next_level_index := pending_level_index
	pending_level_index = -1
	return load_level(next_level_index)

func _clear_progress_state() -> void:
	current_score = 0
	has_saved_progress = false
	saved_level_index = DEFAULT_LEVEL_INDEX
	saved_player_position = Vector2.ZERO
	saved_player_health = -1
	_one_time_flags.clear()
	_defeated_enemy_keys.clear()
	_collected_item_keys.clear()
	score_changed.emit(current_score)
	_save_game_state()

func _load_game_state() -> void:
	var config := ConfigFile.new()
	var load_result: int = config.load(SAVE_PATH)
	if load_result != OK:
		current_level_index = DEFAULT_LEVEL_INDEX
		return

	times_opened = int(config.get_value("meta", "times_opened", 0))
	current_score = int(config.get_value("progress", "score", 0))
	has_saved_progress = bool(config.get_value("progress", "has_saved_progress", false))
	saved_level_index = clamp(int(config.get_value("progress", "level_index", DEFAULT_LEVEL_INDEX)), 0, LEVELS.size() - 1)
	saved_player_position = Vector2(
		float(config.get_value("progress", "player_x", 0.0)),
		float(config.get_value("progress", "player_y", 0.0))
	)
	saved_player_health = int(config.get_value("progress", "player_health", -1))

	var saved_flags: Variant = config.get_value("progress", "one_time_flags", {})
	if saved_flags is Dictionary:
		_one_time_flags = saved_flags.duplicate(true)

	var saved_enemy_keys: Variant = config.get_value("progress", "defeated_enemy_keys", {})
	if saved_enemy_keys is Dictionary:
		_defeated_enemy_keys = saved_enemy_keys.duplicate(true)

	var saved_item_keys: Variant = config.get_value("progress", "collected_item_keys", {})
	if saved_item_keys is Dictionary:
		_collected_item_keys = saved_item_keys.duplicate(true)

	current_level_index = saved_level_index if has_saved_progress else DEFAULT_LEVEL_INDEX

func _save_game_state() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "times_opened", times_opened)
	config.set_value("progress", "score", current_score)
	config.set_value("progress", "has_saved_progress", has_saved_progress)
	config.set_value("progress", "level_index", saved_level_index)
	config.set_value("progress", "player_x", saved_player_position.x)
	config.set_value("progress", "player_y", saved_player_position.y)
	config.set_value("progress", "player_health", saved_player_health)
	config.set_value("progress", "one_time_flags", _one_time_flags)
	config.set_value("progress", "defeated_enemy_keys", _defeated_enemy_keys)
	config.set_value("progress", "collected_item_keys", _collected_item_keys)
	config.save(SAVE_PATH)

func _find_level_root_for_node(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if find_level_index_by_scene_path(current.scene_file_path) >= 0:
			return current
		current = current.get_parent()

	return null

func _has_progress_key(progress_store: Dictionary, progress_key: String) -> bool:
	if progress_key.is_empty():
		return false

	return bool(progress_store.get(progress_key, false))

func _register_progress_key(progress_store: Dictionary, progress_key: String) -> bool:
	if progress_key.is_empty() or _has_progress_key(progress_store, progress_key):
		return false

	progress_store[progress_key] = true
	_save_game_state()
	return true
