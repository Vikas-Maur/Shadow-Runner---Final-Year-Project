extends Node2D

@onready var level_root: Node2D = $LevelRoot
@onready var player: CharacterBody2D = $Player

var _loaded_level: Node = null

func _ready() -> void:
	_load_current_level()

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

func _move_player_to_spawn() -> void:
	if _loaded_level == null:
		return

	var spawn_node := _loaded_level.find_child("PlayerSpawn", true, false)
	if spawn_node is Node2D:
		player.global_position = spawn_node.global_position
		player.velocity = Vector2.ZERO
