extends Node

const GAME_SCENE := "res://scenes/game.tscn"
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

var current_level_index: int = 0
var pending_level_index: int = -1

func _ready() -> void:
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
	current_level_index = 0
	pending_level_index = -1
	current_level_changed.emit(current_level_index)

func are_development_tools_enabled() -> bool:
	return OS.is_debug_build()

func has_next_level(level_index: int = current_level_index) -> bool:
	return level_index >= 0 and level_index < LEVELS.size() - 1

func get_current_level_scene_path() -> String:
	return get_level_scene_path(current_level_index)

func get_level_scene_path(level_index: int) -> String:
	if level_index < 0 or level_index >= LEVELS.size():
		return ""
	return String(LEVELS[level_index].get("scene_path", ""))

func get_current_level_id() -> String:
	if current_level_index < 0 or current_level_index >= LEVELS.size():
		return ""
	return String(LEVELS[current_level_index].get("id", ""))

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
	current_level_changed.emit(current_level_index)
	get_tree().change_scene_to_file(GAME_SCENE)
	return true

func complete_pending_transition() -> bool:
	if pending_level_index < 0:
		return false

	var next_level_index := pending_level_index
	pending_level_index = -1
	return load_level(next_level_index)
