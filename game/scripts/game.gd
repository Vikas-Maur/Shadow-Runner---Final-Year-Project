extends Node2D

const DEFAULT_CAMERA_BOTTOM_LIMIT := 120
const AUTO_SAVE_INTERVAL_SECONDS := 0.75
const DEATH_RESTART_DELAY_SECONDS := 0.6

@onready var level_root: Node2D = $LevelRoot
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var tutorial_hint: PanelContainer = $TutorialLayer/TutorialHint
@onready var tutorial_label: Label = $TutorialLayer/TutorialHint/MarginContainer/TutorialLabel

var _loaded_level: Node = null
var _autosave_timer: float = 0.0
var _tutorial_message_serial: int = 0
var _death_restart_in_progress: bool = false

func _ready() -> void:
	set_process_input(LevelManager.are_development_tools_enabled())
	tutorial_hint.visible = false
	_connect_player_death()
	_load_current_level()

func _input(event: InputEvent) -> void:
	if not LevelManager.are_development_tools_enabled():
		return

	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_E:
		if _teleport_player_to_dev_target():
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer < AUTO_SAVE_INTERVAL_SECONDS:
		return

	_autosave_timer = 0.0
	_save_player_progress()

func _exit_tree() -> void:
	_save_player_progress()

func _connect_player_death() -> void:
	if player != null and player.has_signal("died") and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

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

	var loaded_level_index := _get_loaded_level_index()
	var resume_state: Dictionary = LevelManager.consume_resume_player_position(loaded_level_index)
	if bool(resume_state.get("available", false)):
		player.global_position = resume_state.get("position", Vector2.ZERO)
		player.velocity = Vector2.ZERO
		if player.has_method("restore_saved_health"):
			player.call("restore_saved_health", int(resume_state.get("health", -1)))
		_save_player_progress()
		return

	var spawn_node := _loaded_level.find_child("PlayerSpawn", true, false)
	if spawn_node is Node2D:
		player.global_position = spawn_node.global_position
		player.velocity = Vector2.ZERO
		_save_player_progress()

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

func show_tutorial_message(message: String, duration_seconds: float = 4.0) -> void:
	if message.is_empty():
		return

	_tutorial_message_serial += 1
	var message_serial := _tutorial_message_serial
	tutorial_label.text = message
	tutorial_hint.visible = true

	var timer := get_tree().create_timer(max(duration_seconds, 0.1))
	timer.timeout.connect(func():
		if message_serial == _tutorial_message_serial:
			tutorial_hint.visible = false
	)

func _save_player_progress() -> void:
	if _loaded_level == null or not is_instance_valid(_loaded_level):
		return
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("is_dead") and player.is_dead():
		return

	LevelManager.save_player_progress(_get_loaded_level_index(), player.global_position, int(player.get("current_health")))

func _on_player_died() -> void:
	if _death_restart_in_progress:
		return

	_death_restart_in_progress = true
	Engine.time_scale = 0.5

	var restart_delay := DEATH_RESTART_DELAY_SECONDS
	if player != null and player.has_method("get_death_restart_delay_seconds"):
		restart_delay = max(float(player.call("get_death_restart_delay_seconds")), 0.1)

	var timer := get_tree().create_timer(restart_delay)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
		if get_tree() != null:
			get_tree().reload_current_scene()
	)

func _get_loaded_level_index() -> int:
	if _loaded_level == null or not is_instance_valid(_loaded_level):
		return LevelManager.get_current_level_index()

	var level_scene_path := _loaded_level.scene_file_path
	var resolved_level_index := LevelManager.find_level_index_by_scene_path(level_scene_path)
	if resolved_level_index >= 0:
		return resolved_level_index

	return LevelManager.get_current_level_index()
