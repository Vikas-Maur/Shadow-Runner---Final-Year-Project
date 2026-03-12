extends Node2D

const SPEED = 60
const VILEMURK_TUTORIAL_FLAG := "vilemurk_stomp_hint"
const VILEMURK_TUTORIAL_TEXT := "Tip: Jump, then press S or Down Arrow to stomp enemies."

var direction = 1

@onready var ray_cast_right = $RayCastRight
@onready var ray_cast_left = $RayCastLeft
@onready var animated_sprite = $AnimatedSprite2D
@onready var npc = $NPC
@onready var killzone = $Killzone

var _player: Node2D = null
var _tutorial_checked: bool = false

func _ready():
	if LevelManager.is_enemy_defeated(self):
		queue_free()
		return

	_player = get_tree().root.find_child("Player", true, false)
	if npc != null and npc.has_signal("died") and not npc.died.is_connected(_on_npc_died):
		npc.died.connect(_on_npc_died)
	if LevelManager.has_one_time_flag(VILEMURK_TUTORIAL_FLAG):
		_tutorial_checked = true

func _process(delta):
	if npc != null and npc.has_method("is_dead") and npc.is_dead():
		return

	if ray_cast_right.is_colliding():
		direction = -1
		animated_sprite.flip_h = true
	if ray_cast_left.is_colliding():
		direction = 1
		animated_sprite.flip_h = false
	
	position.x += direction * SPEED * delta
	_maybe_show_vilemurk_tutorial()

func _on_npc_died():
	LevelManager.register_enemy_defeat(self)
	set_process(false)
	if killzone != null:
		killzone.monitoring = false
		killzone.monitorable = false
	queue_free()

func take_damage(amount: int) -> void:
	apply_damage(amount)

func apply_damage(damage_input: Variant, source: Node = null) -> void:
	if npc == null or not npc.has_method("apply_damage"):
		return

	npc.apply_damage(damage_input, source)

func is_dead() -> bool:
	if npc == null or not npc.has_method("is_dead"):
		return false

	return npc.is_dead()

func _maybe_show_vilemurk_tutorial() -> void:
	if _tutorial_checked or npc == null or npc.npc_name != "Vilemurk":
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().root.find_child("Player", true, false)
		if _player == null:
			return

	if not npc.has_method("should_show_health_bar") or not npc.should_show_health_bar(_player):
		return

	_tutorial_checked = true
	if not LevelManager.mark_one_time_flag_seen(VILEMURK_TUTORIAL_FLAG):
		return

	var game_root := get_tree().current_scene
	if game_root != null and game_root.has_method("show_tutorial_message"):
		game_root.show_tutorial_message(VILEMURK_TUTORIAL_TEXT)
