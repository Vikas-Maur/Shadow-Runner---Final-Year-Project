extends CharacterBody2D

const FinalBossFireballScene = preload("res://scenes/effects/final_boss_fireball.tscn")
const FinalBossConstructScene = preload("res://scenes/effects/final_boss_construct.tscn")
const StompShockwaveScene = preload("res://scenes/effects/stomp_shockwave.tscn")
const BASE_COLLISION_SIZE := Vector2(54.0, 118.0)
const BASE_COLLISION_OFFSET := Vector2(0.0, 25.0)
const BASE_SPRITE_OFFSET := Vector2(0.0, 21.0)
const BASE_COMBAT_PIVOT_OFFSET := Vector2(0.0, -24.0)
const BASE_PROJECTILE_SPAWN_OFFSET := Vector2(52.0, 0.0)
const CONSTRUCT_PATTERN_STAIRCASE := &"staircase"
const CONSTRUCT_PATTERN_WALL := &"wall"
const CONSTRUCT_PATTERN_RAMPART := &"rampart"
const STOMP_NONE := 0
const STOMP_RISING := 1
const STOMP_DIVING := 2

@export var move_speed: float = 96.0
@export var ground_acceleration: float = 620.0
@export var ground_friction: float = 760.0
@export var jump_velocity: float = -315.0
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 540.0
@export var engage_range: float = 420.0
@export var disengage_range: float = 540.0
@export var engage_vertical_tolerance: float = 180.0
@export var chase_stop_distance: float = 84.0
@export var jump_cooldown_seconds: float = 0.9
@export var jump_trigger_height: float = 34.0
@export var obstacle_probe_distance: float = 18.0
@export var shoot_damage: int = 28
@export var shoot_speed: float = 230.0
@export var shoot_lifetime_seconds: float = 1.2
@export var shoot_cooldown_seconds: float = 1.1
@export var shoot_range: float = 320.0
@export var shoot_vertical_tolerance: float = 90.0
@export var shoot_spawn_offset: Vector2 = Vector2(52, -24)
@export var stomp_trigger_radius: float = 72.0
@export var stomp_vertical_tolerance: float = 82.0
@export var stomp_cooldown_seconds: float = 2.2
@export var stomp_jump_velocity: float = -255.0
@export var stomp_fall_speed: float = 460.0
@export var stomp_damage: int = 38
@export var stomp_shockwave_radius: float = 46.0
@export var stomp_shockwave_lifetime_seconds: float = 0.24
@export var enable_default_shoot_ai: bool = true
@export_group("Constructs")
@export var construct_spawn_action: StringName = &"boss_construct"
@export var construct_debug_pattern: StringName = CONSTRUCT_PATTERN_STAIRCASE
@export var max_active_constructs: int = 2
@export var construct_block_size: Vector2 = Vector2(24.0, 24.0)
@export var construct_lifetime_seconds: float = 4.2
@export var construct_step_delay_seconds: float = 0.1
@export var construct_block_pop_duration_seconds: float = 0.12
@export var construct_spawn_forward_offset: float = 34.0
@export_group("")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var npc: Node = $NPC
@onready var combat_pivot: Node2D = $CombatPivot
@onready var projectile_spawn: Node2D = $CombatPivot/ProjectileSpawn
@onready var ai_hooks: Node = $AIHooks

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _player: Node2D = null
var _shoot_cooldown_timer: float = 0.0
var _jump_cooldown_timer: float = 0.0
var _stomp_cooldown_timer: float = 0.0
var _facing_direction: int = 1
var _move_intent: float = 0.0
var _wants_jump: bool = false
var _combat_engaged: bool = false
var _engaged_by_damage: bool = false
var _presentation_scale: Vector2 = Vector2.ONE
var _stomp_state: int = STOMP_NONE
var _ai_state: Dictionary = {}
var _active_constructs: Array[Node] = []

func _ready() -> void:
	if LevelManager.is_enemy_defeated(self):
		queue_free()
		return

	_capture_instance_scale()
	_player = _find_player()
	if npc != null and npc.has_signal("died") and not npc.died.is_connected(_on_npc_died):
		npc.died.connect(_on_npc_died)

	animated_sprite.play("default")
	_update_player_facing()

func _capture_instance_scale() -> void:
	_presentation_scale = Vector2(absf(scale.x), absf(scale.y))
	if is_zero_approx(_presentation_scale.x):
		_presentation_scale.x = 1.0
	if is_zero_approx(_presentation_scale.y):
		_presentation_scale.y = 1.0

	# Keep the physics body unscaled so gravity and floor detection remain stable.
	scale = Vector2.ONE
	_apply_presentation_scale()

func _apply_presentation_scale() -> void:
	animated_sprite.scale = _presentation_scale
	animated_sprite.position = Vector2(
		BASE_SPRITE_OFFSET.x * _presentation_scale.x,
		BASE_SPRITE_OFFSET.y * _presentation_scale.y
	)
	collision_shape.position = Vector2(
		BASE_COLLISION_OFFSET.x * _presentation_scale.x,
		BASE_COLLISION_OFFSET.y * _presentation_scale.y
	)

	var shape := collision_shape.shape as RectangleShape2D
	if shape != null:
		shape.size = Vector2(
			BASE_COLLISION_SIZE.x * _presentation_scale.x,
			BASE_COLLISION_SIZE.y * _presentation_scale.y
		)

	combat_pivot.position = Vector2(
		BASE_COMBAT_PIVOT_OFFSET.x * _presentation_scale.x,
		(BASE_COMBAT_PIVOT_OFFSET.y + BASE_SPRITE_OFFSET.y) * _presentation_scale.y
	)
	projectile_spawn.position = Vector2(
		BASE_PROJECTILE_SPAWN_OFFSET.x * _presentation_scale.x,
		BASE_PROJECTILE_SPAWN_OFFSET.y * _presentation_scale.y
	)

func _physics_process(delta: float) -> void:
	if npc != null and npc.has_method("is_dead") and npc.is_dead():
		return

	var was_on_floor := is_on_floor()
	_player = _find_player() if _player == null or not is_instance_valid(_player) else _player
	_shoot_cooldown_timer = max(_shoot_cooldown_timer - delta, 0.0)
	_jump_cooldown_timer = max(_jump_cooldown_timer - delta, 0.0)
	_stomp_cooldown_timer = max(_stomp_cooldown_timer - delta, 0.0)
	_prune_constructs()

	_sync_engagement_state()
	_update_player_facing()
	_handle_construct_input()
	_update_ai(delta)
	_apply_movement(delta)
	move_and_slide()
	_update_stomp_after_move(was_on_floor)

func _update_ai(delta: float) -> void:
	_update_phase_state(delta)
	_run_future_ai_hooks(delta)
	_update_construct_ai(delta)
	_update_stomp_ai()

	_update_movement_ai()

	if enable_default_shoot_ai:
		_try_shoot_at_player()

func _update_phase_state(_delta: float) -> void:
	# Reserved for future phase changes, movement patterns, and scripted transitions.
	pass

func _run_future_ai_hooks(_delta: float) -> void:
	# Reserved for future AI extensions layered on top of the default ranged pressure.
	if ai_hooks == null:
		return

func _update_construct_ai(_delta: float) -> void:
	# Reserved for future construct logic, pattern selection, and phase-specific defenses.
	pass

func _sync_engagement_state() -> void:
	if _player == null or not is_instance_valid(_player):
		_combat_engaged = false
		return

	var horizontal_distance := absf(_player.global_position.x - global_position.x)
	var vertical_distance := absf(_player.global_position.y - global_position.y)
	var player_in_engage_range := horizontal_distance <= engage_range and vertical_distance <= engage_vertical_tolerance
	var should_engage := _engaged_by_damage or player_in_engage_range

	if npc != null and npc.get("player_in_range"):
		should_engage = true

	if should_engage:
		_combat_engaged = true
		if npc != null and npc.has_method("start_boss_fight"):
			npc.start_boss_fight()
	elif _combat_engaged and horizontal_distance > disengage_range and not (npc != null and npc.get("is_interacting_with_player")):
		_combat_engaged = false
		_engaged_by_damage = false
		if npc != null and npc.has_method("end_boss_fight"):
			npc.end_boss_fight()

	_ai_state["combat_engaged"] = _combat_engaged

func _update_movement_ai() -> void:
	_move_intent = 0.0
	_wants_jump = false

	if not _can_run_combat_ai():
		return
	if _is_stomping():
		return

	var horizontal_delta := _player.global_position.x - global_position.x
	if horizontal_delta > chase_stop_distance:
		_move_intent = 1.0
	elif horizontal_delta < -chase_stop_distance:
		_move_intent = -1.0

	if _should_jump_toward_player():
		_wants_jump = true

	_ai_state["move_intent"] = _move_intent
	_ai_state["wants_jump"] = _wants_jump

func _apply_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y = min(velocity.y + (gravity * gravity_scale * delta), max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if _stomp_state == STOMP_DIVING:
		velocity.y = min(max(velocity.y, stomp_fall_speed), max_fall_speed)
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		return

	if _stomp_state == STOMP_RISING:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		return

	if absf(_move_intent) > 0.0:
		velocity.x = move_toward(velocity.x, _move_intent * move_speed, ground_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	if _wants_jump and is_on_floor() and _jump_cooldown_timer <= 0.0:
		velocity.y = jump_velocity
		_jump_cooldown_timer = jump_cooldown_seconds

func _should_jump_toward_player() -> bool:
	if not _can_run_combat_ai():
		return false
	if not is_on_floor() or _jump_cooldown_timer > 0.0:
		return false

	var player_is_above := _player.global_position.y < global_position.y - jump_trigger_height
	if player_is_above:
		return true

	if absf(_move_intent) <= 0.0:
		return false

	return test_move(global_transform, Vector2(_move_intent * obstacle_probe_distance, 0.0))

func _can_run_combat_ai() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if npc == null:
		return false
	if not _combat_engaged:
		return false
	if npc.get("is_interacting_with_player"):
		return false
	if _player.has_method("is_dead") and _player.is_dead():
		return false

	return true

func _update_stomp_ai() -> void:
	if not _can_run_combat_ai():
		return
	if _stomp_state != STOMP_NONE:
		return
	if not is_on_floor() or _stomp_cooldown_timer > 0.0:
		return
	if not _is_player_in_stomp_window():
		return

	_start_stomp()

func _start_stomp() -> void:
	_stomp_state = STOMP_RISING
	velocity.x = 0.0
	velocity.y = stomp_jump_velocity
	_stomp_cooldown_timer = stomp_cooldown_seconds
	_ai_state["stomp_state"] = _stomp_state

func _update_stomp_after_move(was_on_floor: bool) -> void:
	if _stomp_state == STOMP_RISING and velocity.y >= 0.0:
		_stomp_state = STOMP_DIVING
		_ai_state["stomp_state"] = _stomp_state

	var landed_from_stomp := _stomp_state == STOMP_DIVING and not was_on_floor and is_on_floor()
	if landed_from_stomp:
		_spawn_stomp_shockwave()
		_stomp_state = STOMP_NONE
		_ai_state["stomp_state"] = _stomp_state

func _is_player_in_stomp_window() -> bool:
	if _player == null:
		return false

	var to_player := _player.global_position - global_position
	return absf(to_player.x) <= stomp_trigger_radius and absf(to_player.y) <= stomp_vertical_tolerance

func _is_stomping() -> bool:
	return _stomp_state != STOMP_NONE

func _spawn_stomp_shockwave() -> void:
	var shockwave = StompShockwaveScene.instantiate()
	var scene_root = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	scene_root.add_child(shockwave)
	shockwave.global_position = _get_ground_impact_position()
	if shockwave.has_method("configure"):
		shockwave.configure(
			self,
			_build_attack_damage(stomp_damage, &"stomp"),
			stomp_shockwave_radius,
			stomp_shockwave_lifetime_seconds
		)

func _get_ground_impact_position() -> Vector2:
	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		return global_position

	return collision_shape.global_position + Vector2(0.0, shape.size.y * 0.5 - max(_presentation_scale.y * 3.0, 1.0))

func _try_shoot_at_player() -> void:
	if _shoot_cooldown_timer > 0.0:
		return
	if not _can_run_combat_ai():
		return
	if _is_stomping():
		return
	if not _is_player_in_shoot_window():
		return

	var projectile = FinalBossFireballScene.instantiate()
	var scene_root = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	scene_root.add_child(projectile)
	projectile.global_position = global_position + Vector2(shoot_spawn_offset.x * _facing_direction, shoot_spawn_offset.y)
	if projectile_spawn != null:
		projectile.global_position = projectile_spawn.global_position
	if projectile.has_method("configure"):
		projectile.configure(
			self,
			Vector2(_facing_direction, 0.0),
			_build_attack_damage(shoot_damage, &"projectile"),
			shoot_speed,
			shoot_lifetime_seconds
		)

	_shoot_cooldown_timer = shoot_cooldown_seconds

func _is_player_in_shoot_window() -> bool:
	if _player == null:
		return false

	var to_player := _player.global_position - global_position
	return absf(to_player.x) <= shoot_range and absf(to_player.y) <= shoot_vertical_tolerance

func _update_player_facing() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	if _player.global_position.x > global_position.x:
		_facing_direction = 1
	elif _player.global_position.x < global_position.x:
		_facing_direction = -1

	# The boss spritesheet faces right by default.
	animated_sprite.flip_h = _facing_direction < 0
	combat_pivot.scale = Vector2(_presentation_scale.x * _facing_direction, _presentation_scale.y)
	_ai_state["facing_direction"] = _facing_direction

func _handle_construct_input() -> void:
	if construct_spawn_action == &"":
		return
	if Input.is_action_just_pressed(construct_spawn_action):
		request_construct(construct_debug_pattern)

func request_construct(pattern_name: StringName = CONSTRUCT_PATTERN_STAIRCASE) -> bool:
	_prune_constructs()
	if max_active_constructs > 0 and _active_constructs.size() >= max_active_constructs:
		return false

	var pattern := _get_construct_pattern(pattern_name)
	if pattern.is_empty():
		return false

	var construct := FinalBossConstructScene.instantiate()
	if construct.has_method("configure"):
		construct.configure(
			pattern,
			construct_block_size,
			construct_lifetime_seconds,
			construct_step_delay_seconds,
			construct_block_pop_duration_seconds,
			_facing_direction
		)

	var scene_root = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	scene_root.add_child(construct)
	construct.global_position = _get_construct_origin()

	if construct.has_signal("expired"):
		construct.connect("expired", Callable(self, "_on_construct_expired"))

	_active_constructs.append(construct)
	_ai_state["active_constructs"] = _active_constructs.size()
	return true

func get_available_construct_patterns() -> Array[StringName]:
	return [
		CONSTRUCT_PATTERN_STAIRCASE,
		CONSTRUCT_PATTERN_WALL,
		CONSTRUCT_PATTERN_RAMPART
	]

func _get_construct_pattern(pattern_name: StringName) -> Array[Vector2i]:
	match pattern_name:
		CONSTRUCT_PATTERN_STAIRCASE:
			return [
				Vector2i(0, 0),
				Vector2i(1, -1),
				Vector2i(2, -2),
				Vector2i(3, -3)
			]
		CONSTRUCT_PATTERN_WALL:
			return [
				Vector2i(0, 0),
				Vector2i(0, -1),
				Vector2i(0, -2),
				Vector2i(0, -3)
			]
		CONSTRUCT_PATTERN_RAMPART:
			return [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(0, -1),
				Vector2i(1, -1),
				Vector2i(2, -2)
			]
		_:
			return []

func _get_construct_origin() -> Vector2:
	var anchor := _get_ground_impact_position()
	return anchor + Vector2(_facing_direction * construct_spawn_forward_offset, 0.0)

func _on_construct_expired(construct: Node) -> void:
	_active_constructs.erase(construct)
	_prune_constructs()

func _prune_constructs() -> void:
	var live_constructs: Array[Node] = []
	for construct in _active_constructs:
		if construct != null and is_instance_valid(construct) and not construct.is_queued_for_deletion():
			live_constructs.append(construct)
	_active_constructs = live_constructs
	_ai_state["active_constructs"] = _active_constructs.size()

func _clear_constructs() -> void:
	for construct in _active_constructs:
		if construct != null and is_instance_valid(construct) and not construct.is_queued_for_deletion():
			construct.queue_free()
	_active_constructs.clear()
	_ai_state["active_constructs"] = 0

func _find_player() -> Node2D:
	return get_tree().root.find_child("Player", true, false) as Node2D

func _on_npc_died() -> void:
	LevelManager.register_enemy_defeat(self)
	set_physics_process(false)
	velocity = Vector2.ZERO
	_clear_constructs()
	queue_free()

func take_damage(amount: int) -> void:
	apply_damage(amount)

func apply_damage(damage_input: Variant, source: Node = null) -> void:
	if npc == null or not npc.has_method("apply_damage"):
		return

	if source != null and source.name == "Player":
		_engaged_by_damage = true
		_combat_engaged = true
		if npc.has_method("start_boss_fight"):
			npc.start_boss_fight()

	npc.apply_damage(damage_input, source)

func is_dead() -> bool:
	if npc == null or not npc.has_method("is_dead"):
		return false

	return npc.is_dead()

func is_final_boss() -> bool:
	return true

func _build_attack_damage(flat_damage: int, attack_type: StringName) -> Dictionary:
	return {
		"flat_damage": flat_damage,
		"attack_type": String(attack_type)
	}
