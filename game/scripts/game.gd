extends Node2D

const DEFAULT_CAMERA_BOTTOM_LIMIT := 120

@onready var level_root: Node2D = $LevelRoot
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D

var _loaded_level: Node = null

func _ready() -> void:
	set_process_input(LevelManager.are_development_tools_enabled())
	_load_current_level()

func _input(event: InputEvent) -> void:
	if not LevelManager.are_development_tools_enabled():
		return

	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_E:
		if _teleport_player_to_dev_target():
			get_viewport().set_input_as_handled()

func _load_current_level() -> void:
	var level_scene_path := LevelManager.get_current_level_scene_path()
	if level_scene_path.is_empty():
		push_error("No level scene is configured for %s." % LevelManager.get_current_level_id())
		return

	var level_scene := load(level_scene_path) as PackedScene
	if level_scene == null:
		push_error("Failed to load level scene: %s" % level_scene_path)
		return

	if _loaded_level != null:
		_loaded_level.queue_free()
		_loaded_level = null

	_loaded_level = level_scene.instantiate()
	level_root.add_child(_loaded_level)
	_move_player_to_spawn()
	_apply_level_camera_settings()

func _move_player_to_spawn() -> void:
	if _loaded_level == null:
		return

	var spawn_node := _loaded_level.find_child("PlayerSpawn", true, false)
	if spawn_node is Node2D:
		player.global_position = spawn_node.global_position
		player.velocity = Vector2.ZERO

func _apply_level_camera_settings() -> void:
	var camera_bottom_limit := DEFAULT_CAMERA_BOTTOM_LIMIT
	var game_level := _loaded_level as GameLevel
	if game_level != null:
		camera_bottom_limit = game_level.camera_bottom_limit

	camera.limit_bottom = camera_bottom_limit

func _teleport_player_to_dev_target() -> bool:
	var game_level := _loaded_level as GameLevel
	if game_level == null:
		return false

	player.global_position = game_level.get_dev_teleport_global_position()
	player.velocity = Vector2.ZERO
	return true
