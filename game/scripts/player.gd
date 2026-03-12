extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const DamagePayload = preload("res://scripts/damage_payload.gd")
const StompShockwaveScene = preload("res://scenes/effects/stomp_shockwave.tscn")
const KnightProjectileScene = preload("res://scenes/effects/knight_projectile.tscn")

@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_pivot: Node2D = $AttackPivot
@onready var sword_sprite: Sprite2D = $AttackPivot/SwordSprite
@onready var attack_area: Area2D = $AttackPivot/AttackArea
@export var max_health: int = 100
@export var coyote_time_seconds: float = 0.12
@export var jump_buffer_seconds: float = 0.12
@export_range(0.1, 1.0, 0.05) var jump_release_multiplier: float = 0.45
@export var dash_speed: float = 260.0
@export var dash_duration_seconds: float = 0.16
@export var dash_cooldown_seconds: float = 0.45
@export var stomp_fall_speed: float = 420.0
@export var stomp_bounce_velocity: float = -220.0
@export var stomp_damage: int = 60
@export var stomp_shockwave_damage: int = 25
@export var stomp_shockwave_radius: float = 28.0
@export var stomp_shockwave_lifetime_seconds: float = 0.18
@export var stomp_height_grace: float = 10.0
@export var sword_damage: int = 35
@export var sword_attack_duration_seconds: float = 0.18
@export var sword_attack_cooldown_seconds: float = 0.22
@export var shoot_damage: int = 24
@export var shoot_speed: float = 320.0
@export var shoot_lifetime_seconds: float = 0.7
@export var shoot_cooldown_seconds: float = 0.3
@export var shoot_spawn_offset: Vector2 = Vector2(14, -12)
@export var boss_death_animation_duration_seconds: float = 0.8
@export var boss_death_hold_seconds: float = 2.0

signal health_changed(current_health: int, max_health: int)
signal died
signal attack_performed(attack_type: StringName, details: Dictionary)

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_health: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var stomp_active: bool = false
var facing_direction: int = 1
var sword_attack_timer: float = 0.0
var sword_attack_cooldown_timer: float = 0.0
var shoot_cooldown_timer: float = 0.0
var sword_hit_targets: Dictionary = {}
var _death_animation_locked: bool = false
var _death_restart_delay_seconds: float = 0.6
var _last_damage_source: Node = null
var _death_animation_elapsed: float = 0.0
var last_attack_snapshot: Dictionary = {
	"type": "none"
}

func _ready():
	current_health = max_health
	health_changed.emit(current_health, max_health)
	_reset_death_state()
	_update_attack_visuals()

func _physics_process(delta):
	if is_dead():
		_process_death_state(delta)
		return

	var direction = Input.get_axis("move_left", "move_right")
	var was_on_floor = is_on_floor()

	_update_timers(delta, was_on_floor)
	_collect_input(direction, was_on_floor)

	if _is_dashing():
		velocity.x = float(facing_direction) * dash_speed
		velocity.y = 0.0
	else:
		if not was_on_floor:
			velocity.y += gravity * delta

		if _can_consume_jump(was_on_floor):
			_do_jump()

		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= jump_release_multiplier

		if stomp_active:
			velocity.y = max(velocity.y, stomp_fall_speed)
			velocity.x = move_toward(velocity.x, 0.0, SPEED)
		elif direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	if direction > 0:
		facing_direction = 1
	elif direction < 0:
		facing_direction = -1

	animated_sprite.flip_h = facing_direction < 0
	_update_attack_visuals()

	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")

	move_and_slide()

	var landed_after_stomp = stomp_active and not was_on_floor and is_on_floor()
	if landed_after_stomp:
		_spawn_stomp_shockwave(global_position)

	if is_on_floor():
		stomp_active = false

	_process_sword_hits()

func _process_death_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, SPEED)
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = max(velocity.y, 0.0)

	if _death_animation_locked:
		_death_animation_elapsed += delta
		if _death_animation_elapsed < boss_death_animation_duration_seconds:
			animated_sprite.play("die")
		else:
			animated_sprite.stop()
			animated_sprite.animation = &"die"
			animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count(&"die") - 1

	attack_pivot.rotation = 0.0
	sword_sprite.visible = false
	attack_area.monitoring = false
	move_and_slide()

func _update_timers(delta: float, was_on_floor: bool) -> void:
	if was_on_floor:
		coyote_timer = coyote_time_seconds
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	dash_timer = max(dash_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	sword_attack_timer = max(sword_attack_timer - delta, 0.0)
	sword_attack_cooldown_timer = max(sword_attack_cooldown_timer - delta, 0.0)
	shoot_cooldown_timer = max(shoot_cooldown_timer - delta, 0.0)

func _collect_input(direction: float, was_on_floor: bool) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_seconds

	if Input.is_action_just_pressed("dash"):
		_start_dash(direction)

	if Input.is_action_just_pressed("attack"):
		_start_sword_attack()

	if Input.is_action_just_pressed("shoot"):
		_start_shoot(direction)

	if Input.is_action_just_pressed("move_down") and not was_on_floor and not _is_dashing() and not _is_sword_attacking():
		stomp_active = true
		jump_buffer_timer = 0.0
		_record_attack(&"stomp", {
			"phase": "dive_start"
		})

func _can_consume_jump(was_on_floor: bool) -> bool:
	if jump_buffer_timer <= 0.0 or _is_dashing():
		return false

	return was_on_floor or coyote_timer > 0.0

func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	stomp_active = false

func _start_dash(direction: float) -> void:
	if dash_cooldown_timer > 0.0 or _is_dashing() or _is_sword_attacking():
		return

	if direction > 0.0:
		facing_direction = 1
	elif direction < 0.0:
		facing_direction = -1

	dash_timer = dash_duration_seconds
	dash_cooldown_timer = dash_cooldown_seconds
	stomp_active = false
	velocity.y = 0.0

func _is_dashing() -> bool:
	return dash_timer > 0.0

func _start_shoot(direction: float) -> void:
	if shoot_cooldown_timer > 0.0 or _is_dashing() or _is_sword_attacking() or stomp_active:
		return

	if direction > 0.0:
		facing_direction = 1
	elif direction < 0.0:
		facing_direction = -1

	var projectile = KnightProjectileScene.instantiate()
	var scene_root = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	scene_root.add_child(projectile)
	projectile.global_position = global_position + Vector2(shoot_spawn_offset.x * facing_direction, shoot_spawn_offset.y)
	if projectile.has_method("configure"):
		projectile.configure(
			self,
			Vector2(facing_direction, 0.0),
			_build_attack_damage(shoot_damage, &"projectile"),
			shoot_speed,
			shoot_lifetime_seconds
		)

	shoot_cooldown_timer = shoot_cooldown_seconds
	_record_attack(&"projectile", {
		"cooldown_seconds": shoot_cooldown_seconds
	})

func _start_sword_attack() -> void:
	if sword_attack_cooldown_timer > 0.0 or _is_sword_attacking() or _is_dashing():
		return

	sword_attack_timer = sword_attack_duration_seconds
	sword_attack_cooldown_timer = sword_attack_cooldown_seconds
	stomp_active = false
	sword_hit_targets.clear()
	_update_attack_visuals()
	_process_sword_hits()
	_record_attack(&"sword", {
		"duration_seconds": sword_attack_duration_seconds
	})

func _is_sword_attacking() -> bool:
	return sword_attack_timer > 0.0

func can_stomp_target(target: Node) -> bool:
	if not stomp_active or velocity.y <= 0.0:
		return false

	return global_position.y <= target.global_position.y + stomp_height_grace

func handle_stomp_attack(target: Node) -> void:
	if target == null or not target.has_method("apply_damage"):
		return

	stomp_active = false
	target.apply_damage(_build_attack_damage(stomp_damage, &"stomp"), self)
	_spawn_stomp_shockwave(target.global_position)
	velocity.y = stomp_bounce_velocity
	_record_attack(&"stomp", {
		"phase": "impact"
	})

func is_stomping() -> bool:
	return stomp_active

func _update_attack_visuals() -> void:
	var sword_active = _is_sword_attacking()
	attack_pivot.position = Vector2(0, -12)
	attack_pivot.scale.x = facing_direction
	sword_sprite.visible = sword_active
	attack_area.monitoring = sword_active

	if not sword_active:
		attack_pivot.rotation = 0.0
		return

	var swing_progress = 1.0 - (sword_attack_timer / sword_attack_duration_seconds)
	var swing_degrees = lerpf(-70.0, 55.0, clamp(swing_progress, 0.0, 1.0))
	attack_pivot.rotation_degrees = swing_degrees

func _process_sword_hits() -> void:
	if not _is_sword_attacking():
		return

	for area in attack_area.get_overlapping_areas():
		var damage_target = _resolve_damage_receiver(area)
		if damage_target == null:
			continue

		var target_id = damage_target.get_instance_id()
		if sword_hit_targets.has(target_id):
			continue

		sword_hit_targets[target_id] = true
		damage_target.apply_damage(_build_attack_damage(sword_damage, &"sword"), self)

func _resolve_damage_receiver(node: Node) -> Node:
	var candidates: Array[Node] = [node]

	if node.get_parent() != null:
		candidates.append(node.get_parent())
		for sibling in node.get_parent().get_children():
			candidates.append(sibling)

	var owner = node.get_owner()
	if owner != null:
		candidates.append(owner)
		for owner_child in owner.get_children():
			candidates.append(owner_child)

	for candidate in candidates:
		if candidate != null and candidate.has_method("apply_damage"):
			return candidate

	return null

func _build_attack_damage(flat_damage: int, attack_type: StringName) -> Dictionary:
	return {
		"flat_damage": flat_damage,
		"attack_type": String(attack_type)
	}

func _spawn_stomp_shockwave(origin: Vector2) -> void:
	if stomp_shockwave_damage <= 0:
		return

	var shockwave = StompShockwaveScene.instantiate()
	var scene_root = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	scene_root.add_child(shockwave)
	shockwave.global_position = origin
	if shockwave.has_method("configure"):
		shockwave.configure(
			self,
			_build_attack_damage(stomp_shockwave_damage, &"shockwave"),
			stomp_shockwave_radius,
			stomp_shockwave_lifetime_seconds
		)

func take_damage(amount: int):
	apply_damage(amount)

func apply_damage(damage_input: Variant, _source: Node = null):
	if is_dead():
		return

	var resolved_damage = _resolve_damage_amount(damage_input)
	if resolved_damage <= 0:
		return

	_last_damage_source = _source
	current_health = max(current_health - resolved_damage, 0)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		_prepare_death_state(_source)
		died.emit()

func heal(amount: int):
	if amount <= 0 or is_dead():
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func restore_saved_health(saved_health: int) -> void:
	if saved_health < 0:
		return

	current_health = int(clamp(saved_health, 0, max_health))
	if current_health > 0:
		_reset_death_state()
	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return current_health <= 0

func get_death_restart_delay_seconds() -> float:
	return _death_restart_delay_seconds

func was_killed_by_final_boss() -> bool:
	return _is_final_boss_source(_last_damage_source)

func _prepare_death_state(source: Node) -> void:
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	sword_attack_timer = 0.0
	sword_attack_cooldown_timer = 0.0
	shoot_cooldown_timer = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	stomp_active = false
	sword_hit_targets.clear()
	_update_attack_visuals()

	if _is_final_boss_source(source):
		_death_animation_locked = true
		_death_animation_elapsed = 0.0
		_death_restart_delay_seconds = boss_death_animation_duration_seconds + boss_death_hold_seconds
		animated_sprite.play("die")
	else:
		_death_animation_locked = false
		_death_restart_delay_seconds = 0.6

func _reset_death_state() -> void:
	_death_animation_locked = false
	_death_restart_delay_seconds = 0.6
	_last_damage_source = null
	_death_animation_elapsed = 0.0

func _is_final_boss_source(source: Node) -> bool:
	if source == null:
		return false
	if source.has_method("is_final_boss") and source.is_final_boss():
		return true

	return false

func _resolve_damage_amount(damage_input: Variant) -> int:
	if damage_input is int:
		return int(damage_input)

	if damage_input is float:
		return int(round(float(damage_input)))

	if damage_input is DamagePayload:
		return damage_input.calculate_damage(max_health, current_health)

	if damage_input is Dictionary:
		var flat_damage = int(damage_input.get("flat_damage", damage_input.get("flat", 0)))
		var max_health_percent = clamp(float(damage_input.get("max_health_percent", 0.0)), 0.0, 2.0)
		var current_health_percent = clamp(float(damage_input.get("current_health_percent", 0.0)), 0.0, 2.0)
		var minimum_damage = int(damage_input.get("minimum_damage", 0))

		var resolved = flat_damage
		resolved += int(round(float(max_health) * max_health_percent))
		resolved += int(round(float(current_health) * current_health_percent))
		return max(resolved, minimum_damage)

	return 0

func get_last_attack_snapshot() -> Dictionary:
	return last_attack_snapshot.duplicate(true)

func get_combat_state_snapshot() -> Dictionary:
	return {
		"position": _vector_to_dict(global_position),
		"velocity": _vector_to_dict(velocity),
		"health": current_health,
		"max_health": max_health,
		"health_ratio": _safe_ratio(current_health, max_health),
		"grounded": is_on_floor(),
		"facing_direction": facing_direction,
		"stomp_active": stomp_active,
		"dash_active": _is_dashing(),
		"sword_attacking": _is_sword_attacking(),
		"shoot_cooldown_remaining": _round_number(shoot_cooldown_timer),
		"dash_cooldown_remaining": _round_number(dash_cooldown_timer),
		"last_attack": get_last_attack_snapshot()
	}

func _record_attack(attack_type: StringName, details: Dictionary = {}) -> void:
	var snapshot := {
		"type": String(attack_type),
		"time_seconds": _round_number(float(Time.get_ticks_msec()) / 1000.0),
		"position": _vector_to_dict(global_position),
		"facing_direction": facing_direction,
		"grounded": is_on_floor(),
		"stomp_active": stomp_active,
		"dash_active": _is_dashing(),
		"sword_attacking": _is_sword_attacking()
	}

	for key in details.keys():
		snapshot[key] = details[key]

	last_attack_snapshot = snapshot
	attack_performed.emit(attack_type, snapshot)

func _vector_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": _round_number(value.x),
		"y": _round_number(value.y)
	}

func _round_number(value: float) -> float:
	return snappedf(value, 0.01)

func _safe_ratio(value: int, maximum_value: int) -> float:
	if maximum_value <= 0:
		return 0.0

	return _round_number(float(value) / float(maximum_value))
