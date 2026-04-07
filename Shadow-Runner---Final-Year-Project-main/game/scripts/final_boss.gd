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

@export_group("Movement")
@export var move_speed: float = 96.0
@export var ground_acceleration: float = 620.0
@export var ground_friction: float = 760.0
@export var jump_velocity: float = -315.0
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 540.0
@export var engage_range: float = 420.0
@export var disengage_range: float = 540.0
@export var engage_vertical_tolerance: float = 180.0
@export var jump_cooldown_seconds: float = 0.9
@export var play_boundary_start_x: float = -100000.0
@export var play_boundary_end_x: float = 100000.0

@export_group("Fire")
@export var shoot_damage: int = 28
@export var shoot_speed: float = 230.0
@export var shoot_lifetime_seconds: float = 1.2
@export var shoot_cooldown_seconds: float = 1.1
@export var shoot_spawn_offset: Vector2 = Vector2(52, -24)
@export var max_fireballs_per_interval: int = 2
@export var fireball_interval_seconds: float = 3.0

@export_group("Stomp")
@export var stomp_cooldown_seconds: float = 2.2
@export var stomp_jump_velocity: float = -255.0
@export var stomp_fall_speed: float = 460.0
@export var stomp_damage: int = 38
@export var stomp_shockwave_radius: float = 46.0
@export var stomp_shockwave_lifetime_seconds: float = 0.24

@export_group("Constructs")
@export var construct_spawn_action: StringName = &"boss_construct"
@export var construct_debug_pattern: StringName = CONSTRUCT_PATTERN_STAIRCASE
@export var max_active_constructs: int = 2
@export var max_construct_blocks_per_cast: int = 8
@export var construct_forward_span_blocks: int = 6
@export var construct_back_span_blocks: int = 2
@export var construct_height_blocks: int = 6
@export var construct_block_size: Vector2 = Vector2(24.0, 24.0)
@export var construct_lifetime_seconds: float = 4.2
@export var construct_step_delay_seconds: float = 0.1
@export var construct_block_pop_duration_seconds: float = 0.12
@export var construct_spawn_forward_offset: float = 34.0

@export_group("LLM AI")
@export var enable_llm_ai: bool = true
@export var ollama_model: String = "gemma2:9b"
@export var ai_decision_interval_seconds: float = 0.35
@export var ai_request_timeout_ms: int = 900
@export var ai_max_response_tokens: int = 160
@export var ai_temperature: float = 0.65
@export var ai_top_p: float = 0.9
@export var ai_max_decision_horizon_seconds: float = 0.45
@export var ai_force_face_player: bool = true
@export var ai_min_pressure_distance: float = 20.0
@export var ai_preferred_min_distance: float = 110.0
@export var ai_emergency_action_delay_seconds: float = 0.18
@export var ai_debug_logging: bool = false
@export_group("")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var npc: Node = $NPC
@onready var combat_pivot: Node2D = $CombatPivot
@onready var projectile_spawn: Node2D = $CombatPivot/ProjectileSpawn
@onready var ai_hooks: Node = $AIHooks

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _player: Node2D = null
var _ollama_api: Node = null
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
var _ai_request_in_flight: bool = false
var _ai_request_serial: int = 0
var _ai_request_cooldown_timer: float = 0.0
var _ai_request_elapsed_seconds: float = 0.0
var _current_move_horizon: float = 0.0
var _pending_jump_request: bool = false
var _pending_fire_request: bool = false
var _pending_stomp_request: bool = false
var _pending_construct_request: bool = false
var _pending_construct_cells: Array[Vector2i] = []
var _last_ai_decision: Dictionary = {}
var _last_action_result: Dictionary = {
	"status": "idle"
}
var _last_player_attack_snapshot: Dictionary = {
	"type": "none"
}
var _last_player_hit_on_boss: Dictionary = {
	"type": "none"
}
var _recent_fireball_timestamps: Array[float] = []

func _ready() -> void:
	if LevelManager.is_enemy_defeated(self):
		queue_free()
		return

	_capture_instance_scale()
	_refresh_player_reference()
	_ollama_api = _find_ollama_api()
	if npc != null and npc.has_signal("died") and not npc.died.is_connected(_on_npc_died):
		npc.died.connect(_on_npc_died)

	animated_sprite.play("default")
	_apply_visual_facing()
	_capture_runtime_state()

func _physics_process(delta: float) -> void:
	if npc != null and npc.has_method("is_dead") and npc.is_dead():
		return

	var was_on_floor := is_on_floor()
	_refresh_player_reference()
	if _ollama_api == null or not is_instance_valid(_ollama_api):
		_ollama_api = _find_ollama_api()

	_shoot_cooldown_timer = max(_shoot_cooldown_timer - delta, 0.0)
	_jump_cooldown_timer = max(_jump_cooldown_timer - delta, 0.0)
	_stomp_cooldown_timer = max(_stomp_cooldown_timer - delta, 0.0)
	_ai_request_cooldown_timer = max(_ai_request_cooldown_timer - delta, 0.0)
	_current_move_horizon = max(_current_move_horizon - delta, 0.0)
	if _ai_request_in_flight:
		_ai_request_elapsed_seconds += delta
	else:
		_ai_request_elapsed_seconds = 0.0
	_prune_recent_fireballs()
	_prune_constructs()

	_sync_engagement_state()
	_handle_construct_input()
	_update_ai(delta)
	_execute_pending_ai_actions()
	_apply_movement(delta)
	move_and_slide()
	_enforce_horizontal_play_bounds()
	_update_stomp_after_move(was_on_floor)
	_capture_runtime_state()

func _update_ai(delta: float) -> void:
	_update_phase_state(delta)
	_run_future_ai_hooks(delta)
	_update_llm_controller(delta)

func _update_phase_state(_delta: float) -> void:
	pass

func _run_future_ai_hooks(_delta: float) -> void:
	if ai_hooks == null:
		return

func _update_llm_controller(_delta: float) -> void:
	_update_combat_facing()

	if _current_move_horizon <= 0.0:
		_move_intent = 0.0

	if not enable_llm_ai:
		_clear_llm_intent()
		return

	if not _can_run_combat_ai():
		_clear_llm_intent()
		return

	if _ai_request_in_flight:
		if _ai_request_elapsed_seconds >= ai_emergency_action_delay_seconds:
			_apply_fallback_pressure("awaiting_llm")
		return

	if _ai_request_cooldown_timer > 0.0:
		return

	_request_llm_decision()

func _request_llm_decision() -> void:
	if _ollama_api == null or not is_instance_valid(_ollama_api) or not _ollama_api.has_method("send_structured_message"):
		_ai_request_cooldown_timer = ai_decision_interval_seconds
		_last_action_result = {
			"time_seconds": _round_number(_get_now_seconds()),
			"status": "llm_unavailable"
		}
		_apply_fallback_pressure("llm_unavailable")
		return

	var snapshot := _build_ai_prompt_snapshot()
	_ai_request_serial += 1
	_ai_request_in_flight = true
	_ai_request_elapsed_seconds = 0.0
	_ai_state["awaiting_llm"] = true
	_ai_state["latest_snapshot"] = snapshot

	if ai_debug_logging:
		print("FinalBoss AI request: ", JSON.stringify(snapshot))

	_ollama_api.call(
		"send_structured_message",
		JSON.stringify(snapshot),
		_build_ai_system_prompt(),
		_build_ai_response_schema(),
		Callable(self, "_on_llm_decision_response").bind(_ai_request_serial),
		{
			"model": ollama_model,
			"timeout_ms": ai_request_timeout_ms,
			"num_predict": ai_max_response_tokens,
			"temperature": ai_temperature,
			"top_p": ai_top_p
		}
	)

func _on_llm_decision_response(result: Dictionary, request_serial: int) -> void:
	if request_serial != _ai_request_serial:
		return

	_ai_request_in_flight = false
	_ai_request_elapsed_seconds = 0.0
	_ai_request_cooldown_timer = ai_decision_interval_seconds
	_ai_state["awaiting_llm"] = false

	if not is_inside_tree() or not _can_run_combat_ai():
		return

	if not bool(result.get("ok", false)):
		_last_action_result = {
			"time_seconds": _round_number(_get_now_seconds()),
			"status": "llm_error",
			"error": String(result.get("error", "unknown_error"))
		}
		_apply_fallback_pressure("llm_error")
		return

	var decision := _sanitize_ai_decision(result.get("json", {}))
	if decision.is_empty():
		_last_action_result = {
			"time_seconds": _round_number(_get_now_seconds()),
			"status": "invalid_decision"
		}
		_apply_fallback_pressure("invalid_decision")
		return

	_last_ai_decision = decision
	_current_move_horizon = float(decision.get("horizon_seconds", ai_max_decision_horizon_seconds))
	_move_intent = _move_text_to_intent(String(decision.get("move", "hold")))
	_apply_face_choice(String(decision.get("face", _get_face_to_player_text())))
	_pending_jump_request = bool(decision.get("jump_now", false))
	_pending_fire_request = bool(decision.get("fire_now", false))
	_pending_stomp_request = bool(decision.get("stomp_now", false))

	var construct_section: Dictionary = decision.get("construct", {})
	_pending_construct_request = bool(construct_section.get("spawn", false))
	_pending_construct_cells = _normalize_construct_cells(construct_section.get("cells", []))
	if _pending_construct_request and _pending_construct_cells.is_empty():
		_pending_construct_request = false

	_ai_state["last_decision"] = decision

	if ai_debug_logging:
		print("FinalBoss AI decision: ", JSON.stringify(decision))

func _sanitize_ai_decision(raw_decision: Variant) -> Dictionary:
	if not (raw_decision is Dictionary):
		return {}

	var decision: Dictionary = raw_decision
	var move_text := String(decision.get("move", "hold")).to_lower()
	if not ["left", "right", "hold"].has(move_text):
		move_text = "hold"

	var face_text := String(decision.get("face", _get_face_to_player_text())).to_lower()
	if not ["left", "right", "keep"].has(face_text):
		face_text = _get_face_to_player_text()

	var horizon_seconds := clampf(
		float(decision.get("horizon_seconds", ai_max_decision_horizon_seconds)),
		0.1,
		max(ai_max_decision_horizon_seconds, 0.1)
	)

	var construct_section: Dictionary = {}
	if decision.get("construct", {}) is Dictionary:
		construct_section = decision.get("construct", {})

	var sanitized_decision := {
		"move": move_text,
		"face": face_text,
		"jump_now": bool(decision.get("jump_now", false)),
		"fire_now": bool(decision.get("fire_now", false)),
		"stomp_now": bool(decision.get("stomp_now", false)),
		"horizon_seconds": _round_number(horizon_seconds),
		"construct": {
			"spawn": bool(construct_section.get("spawn", false)),
			"cells": _normalize_construct_cells(construct_section.get("cells", []))
		}
	}

	return _coerce_active_combat_decision(sanitized_decision)

func _execute_pending_ai_actions() -> void:
	_wants_jump = false
	var action_results: Array[Dictionary] = []

	if _pending_fire_request:
		action_results.append(_build_action_result("fire", _perform_fire_attack(), {
			"cooldown_remaining": _round_number(_shoot_cooldown_timer)
		}))
		_pending_fire_request = false

	if _pending_construct_request:
		action_results.append(_build_action_result("construct", request_construct(&"", _pending_construct_cells), {
			"slots_remaining": _get_remaining_construct_slots(),
			"cells": _vector2i_array_to_dicts(_pending_construct_cells)
		}))
		_pending_construct_request = false
		_pending_construct_cells.clear()

	if _pending_stomp_request:
		action_results.append(_build_action_result("stomp", _perform_stomp_attack(), {
			"cooldown_remaining": _round_number(_stomp_cooldown_timer),
			"grounded": is_on_floor()
		}))
		_pending_stomp_request = false

	if _pending_jump_request:
		var jump_success := _queue_ai_jump()
		action_results.append(_build_action_result("jump", jump_success, {
			"cooldown_remaining": _round_number(_jump_cooldown_timer),
			"grounded": is_on_floor()
		}))
		_pending_jump_request = false

	if not action_results.is_empty():
		_last_action_result = {
			"time_seconds": _round_number(_get_now_seconds()),
			"actions": action_results
		}

func _build_action_result(action_name: String, executed: bool, details: Dictionary = {}) -> Dictionary:
	return {
		"action": action_name,
		"status": "executed" if executed else "rejected",
		"details": details
	}

func _queue_ai_jump() -> bool:
	if not _can_run_combat_ai():
		return false
	if _is_stomping():
		return false
	if not is_on_floor():
		return false
	if _jump_cooldown_timer > 0.0:
		return false

	_wants_jump = true
	return true

func _perform_fire_attack() -> bool:
	if not _can_run_combat_ai():
		return false
	if _shoot_cooldown_timer > 0.0:
		return false
	if _is_fireball_quota_exhausted():
		return false
	if _is_stomping():
		return false

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
	_recent_fireball_timestamps.append(_get_now_seconds())
	return true

func _perform_stomp_attack() -> bool:
	if not _can_run_combat_ai():
		return false
	if _stomp_state != STOMP_NONE:
		return false
	if not is_on_floor():
		return false
	if _stomp_cooldown_timer > 0.0:
		return false

	_start_stomp()
	return true

func _coerce_active_combat_decision(sanitized_decision: Dictionary) -> Dictionary:
	var decision := sanitized_decision.duplicate(true)
	if ai_force_face_player:
		decision["face"] = _get_face_to_player_text()

	var to_player := _get_vector_to_player()
	var horizontal_distance := absf(to_player.x)
	var player_side := _get_player_side(to_player.x)
	var move_toward_player := "right" if player_side == "right" else "left"
	var move_away_from_player := "left" if player_side == "right" else "right"
	var too_close := horizontal_distance < ai_preferred_min_distance

	var construct_section: Dictionary = decision.get("construct", {})
	var construct_spawn := bool(construct_section.get("spawn", false))
	var has_active_choice := (
		String(decision.get("move", "hold")) != "hold"
		or bool(decision.get("jump_now", false))
		or bool(decision.get("fire_now", false))
		or bool(decision.get("stomp_now", false))
		or construct_spawn
	)
	if has_active_choice:
		if bool(decision.get("fire_now", false)) and _is_fireball_quota_exhausted():
			decision["fire_now"] = false
			if _can_construct_now():
				decision["construct"] = _build_construct_fallback_payload()
		if too_close and not bool(decision.get("stomp_now", false)):
			decision["move"] = move_away_from_player
		decision["move"] = _coerce_move_within_bounds(String(decision.get("move", "hold")))
		return decision

	if _can_fire_now():
		decision["fire_now"] = true
		decision["move"] = move_away_from_player if too_close else ("hold" if horizontal_distance <= ai_min_pressure_distance else move_toward_player)
	elif _is_fireball_quota_exhausted() and _can_construct_now():
		decision["construct"] = _build_construct_fallback_payload()
		decision["move"] = move_away_from_player if too_close else "hold"
	elif _can_stomp_now() and horizontal_distance <= 96.0 and horizontal_distance >= ai_preferred_min_distance * 0.45:
		decision["stomp_now"] = true
		decision["move"] = move_toward_player
	elif _can_jump_now() and _player != null and is_instance_valid(_player) and _player.global_position.y < global_position.y - 10.0:
		decision["jump_now"] = true
		decision["move"] = move_away_from_player if too_close else move_toward_player
	else:
		decision["move"] = move_away_from_player if too_close else move_toward_player

	decision["move"] = _coerce_move_within_bounds(String(decision.get("move", "hold")))

	return decision

func _apply_fallback_pressure(reason: String) -> void:
	if not _can_run_combat_ai():
		return

	var fallback_decision := _coerce_active_combat_decision({
		"move": "hold",
		"face": _get_face_to_player_text(),
		"jump_now": false,
		"fire_now": false,
		"stomp_now": false,
		"horizon_seconds": _round_number(ai_max_decision_horizon_seconds),
		"construct": {
			"spawn": false,
			"cells": []
		}
	})

	_last_ai_decision = fallback_decision.duplicate(true)
	_ai_state["last_decision"] = fallback_decision
	_current_move_horizon = max(_current_move_horizon, float(fallback_decision.get("horizon_seconds", ai_max_decision_horizon_seconds)))
	_move_intent = _move_text_to_intent(String(fallback_decision.get("move", "hold")))
	_apply_face_choice(String(fallback_decision.get("face", _get_face_to_player_text())))
	_pending_jump_request = _pending_jump_request or bool(fallback_decision.get("jump_now", false))
	_pending_fire_request = _pending_fire_request or bool(fallback_decision.get("fire_now", false))
	_pending_stomp_request = _pending_stomp_request or bool(fallback_decision.get("stomp_now", false))

	var fallback_construct: Dictionary = fallback_decision.get("construct", {})
	if bool(fallback_construct.get("spawn", false)):
		_pending_construct_request = true
		_pending_construct_cells = _normalize_construct_cells(fallback_construct.get("cells", []))

	_last_action_result = {
		"time_seconds": _round_number(_get_now_seconds()),
		"status": "fallback_pressure",
		"reason": reason,
		"decision": fallback_decision
	}

func _update_combat_facing() -> void:
	if not ai_force_face_player:
		return
	if not _can_run_combat_ai():
		return

	var face_to_player := _get_face_to_player_text()
	if face_to_player == "left" or face_to_player == "right":
		_apply_face_choice(face_to_player)

func _coerce_move_within_bounds(move_text: String) -> String:
	if not _has_horizontal_play_bounds():
		return move_text
	if global_position.x <= play_boundary_start_x and move_text == "left":
		return "hold"
	if global_position.x >= play_boundary_end_x and move_text == "right":
		return "hold"

	return move_text

func _enforce_horizontal_play_bounds() -> void:
	if not _has_horizontal_play_bounds():
		return

	var clamped_x := clampf(global_position.x, play_boundary_start_x, play_boundary_end_x)
	if not is_equal_approx(clamped_x, global_position.x):
		global_position.x = clamped_x
		velocity.x = 0.0
		_move_intent = 0.0

func _has_horizontal_play_bounds() -> bool:
	return play_boundary_start_x <= play_boundary_end_x

func _prune_recent_fireballs() -> void:
	if max_fireballs_per_interval <= 0:
		_recent_fireball_timestamps.clear()
		return

	var cutoff: float = _get_now_seconds() - maxf(fireball_interval_seconds, 0.01)
	var live_timestamps: Array[float] = []
	for fired_at in _recent_fireball_timestamps:
		if fired_at >= cutoff:
			live_timestamps.append(fired_at)

	_recent_fireball_timestamps = live_timestamps

func _is_fireball_quota_exhausted() -> bool:
	if max_fireballs_per_interval <= 0:
		return true

	_prune_recent_fireballs()
	return _recent_fireball_timestamps.size() >= max_fireballs_per_interval

func _get_remaining_fireballs_in_interval() -> int:
	if max_fireballs_per_interval <= 0:
		return 0

	_prune_recent_fireballs()
	return maxi(max_fireballs_per_interval - _recent_fireball_timestamps.size(), 0)

func _build_construct_fallback_payload() -> Dictionary:
	return {
		"spawn": true,
		"cells": _vector2i_array_to_dicts(_get_construct_pattern(CONSTRUCT_PATTERN_WALL))
	}

func _get_face_to_player_text() -> String:
	if _player == null or not is_instance_valid(_player):
		return "right" if _facing_direction >= 0 else "left"

	if _player.global_position.x > global_position.x:
		return "right"
	if _player.global_position.x < global_position.x:
		return "left"

	return "right" if _facing_direction >= 0 else "left"

func _get_vector_to_player() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO

	return _player.global_position - global_position

func _can_jump_now() -> bool:
	return _can_run_combat_ai() and is_on_floor() and _jump_cooldown_timer <= 0.0 and not _is_stomping()

func _can_fire_now() -> bool:
	return _can_run_combat_ai() and _shoot_cooldown_timer <= 0.0 and not _is_stomping() and not _is_fireball_quota_exhausted()

func _can_stomp_now() -> bool:
	return _can_run_combat_ai() and is_on_floor() and _stomp_cooldown_timer <= 0.0 and _stomp_state == STOMP_NONE

func _can_construct_now() -> bool:
	return _can_run_combat_ai() and _get_remaining_construct_slots() != 0

func _sync_engagement_state() -> void:
	if _player == null or not is_instance_valid(_player):
		_combat_engaged = false
		_clear_llm_intent()
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
		_clear_llm_intent()
		if npc != null and npc.has_method("end_boss_fight"):
			npc.end_boss_fight()

	_ai_state["combat_engaged"] = _combat_engaged

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

	if _has_horizontal_play_bounds():
		if global_position.x <= play_boundary_start_x and velocity.x < 0.0:
			velocity.x = 0.0
		elif global_position.x >= play_boundary_end_x and velocity.x > 0.0:
			velocity.x = 0.0

	if _wants_jump and is_on_floor() and _jump_cooldown_timer <= 0.0:
		velocity.y = jump_velocity
		_jump_cooldown_timer = jump_cooldown_seconds

func _can_run_combat_ai() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if npc == null:
		return false
	if not _combat_engaged:
		return false
	if npc.get("is_interacting_with_player"):
		return false
	if _player.has_method("is_dead") and bool(_player.call("is_dead")):
		return false

	return true

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

func _handle_construct_input() -> void:
	if construct_spawn_action == &"":
		return
	if Input.is_action_just_pressed(construct_spawn_action):
		request_construct(construct_debug_pattern)

func request_construct(pattern_name: StringName = CONSTRUCT_PATTERN_STAIRCASE, custom_cells: Array = []) -> bool:
	_prune_constructs()
	if max_active_constructs > 0 and _active_constructs.size() >= max_active_constructs:
		return false

	var pattern := _normalize_construct_cells(custom_cells)
	if pattern.is_empty():
		pattern = _normalize_construct_cells(_get_construct_pattern(pattern_name))
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

func _normalize_construct_cells(raw_cells: Variant) -> Array[Vector2i]:
	var normalized: Array[Vector2i] = []
	if not (raw_cells is Array):
		return normalized

	var seen: Dictionary = {}
	for raw_cell in raw_cells:
		var cell := Vector2i.ZERO
		if raw_cell is Dictionary:
			cell = Vector2i(
				clampi(int((raw_cell as Dictionary).get("x", 0)), -construct_back_span_blocks, construct_forward_span_blocks),
				clampi(int((raw_cell as Dictionary).get("y", 0)), -construct_height_blocks, 1)
			)
		elif raw_cell is Vector2i:
			cell = Vector2i(
				clampi((raw_cell as Vector2i).x, -construct_back_span_blocks, construct_forward_span_blocks),
				clampi((raw_cell as Vector2i).y, -construct_height_blocks, 1)
			)
		else:
			continue

		var key := "%s:%s" % [cell.x, cell.y]
		if seen.has(key):
			continue

		seen[key] = true
		normalized.append(cell)
		if normalized.size() >= max_construct_blocks_per_cast:
			break

	return normalized

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

func _capture_instance_scale() -> void:
	_presentation_scale = Vector2(absf(scale.x), absf(scale.y))
	if is_zero_approx(_presentation_scale.x):
		_presentation_scale.x = 1.0
	if is_zero_approx(_presentation_scale.y):
		_presentation_scale.y = 1.0

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

func _apply_face_choice(face_choice: String) -> void:
	match face_choice:
		"left":
			_facing_direction = -1
		"right":
			_facing_direction = 1
		_:
			pass

	_apply_visual_facing()

func _apply_visual_facing() -> void:
	animated_sprite.flip_h = _facing_direction < 0
	combat_pivot.scale = Vector2(_presentation_scale.x * _facing_direction, _presentation_scale.y)
	_ai_state["facing_direction"] = _facing_direction

func _refresh_player_reference() -> void:
	var next_player := _player
	if next_player == null or not is_instance_valid(next_player):
		next_player = _find_player()

	if next_player == _player:
		return

	_disconnect_player_signals()
	_player = next_player
	_connect_player_signals()

func _connect_player_signals() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_signal("attack_performed"):
		var attack_callable := Callable(self, "_on_player_attack_performed")
		if not _player.is_connected("attack_performed", attack_callable):
			_player.connect("attack_performed", attack_callable)
	if _player.has_method("get_last_attack_snapshot"):
		var snapshot = _player.call("get_last_attack_snapshot")
		if snapshot is Dictionary:
			_last_player_attack_snapshot = (snapshot as Dictionary).duplicate(true)

func _disconnect_player_signals() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_signal("attack_performed"):
		var attack_callable := Callable(self, "_on_player_attack_performed")
		if _player.is_connected("attack_performed", attack_callable):
			_player.disconnect("attack_performed", attack_callable)

func _on_player_attack_performed(_attack_type: StringName, details: Dictionary) -> void:
	_last_player_attack_snapshot = details.duplicate(true)

func _find_player() -> Node2D:
	return get_tree().root.find_child("Player", true, false) as Node2D

func _find_ollama_api() -> Node:
	return get_tree().root.find_child("OllamaAPI", true, false)

func _on_npc_died() -> void:
	LevelManager.register_enemy_defeat(self)
	set_physics_process(false)
	velocity = Vector2.ZERO
	_clear_constructs()
	_spawn_key()
	queue_free()

func _spawn_key() -> void:
	var key_scene = load("res://scenes/key.tscn")
	if key_scene == null:
		return
	var key = key_scene.instantiate()
	var scene_root = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	scene_root.add_child(key)
	key.global_position = global_position

func take_damage(amount: int) -> void:
	apply_damage(amount)

func apply_damage(damage_input: Variant, source: Node = null) -> void:
	if npc == null or not npc.has_method("apply_damage"):
		return

	if source != null and source.name == "Player":
		_engaged_by_damage = true
		_combat_engaged = true
		_record_player_hit(damage_input)
		if npc.has_method("start_boss_fight"):
			npc.start_boss_fight()

	npc.apply_damage(damage_input, source)

func _record_player_hit(damage_input: Variant) -> void:
	_last_player_hit_on_boss = {
		"type": String(_extract_attack_type(damage_input)),
		"time_seconds": _round_number(_get_now_seconds()),
		"estimated_damage": _estimate_damage_amount(damage_input)
	}

	if _last_player_attack_snapshot.is_empty():
		_last_player_attack_snapshot = _last_player_hit_on_boss.duplicate(true)
	else:
		_last_player_attack_snapshot["landed_on_boss"] = true
		_last_player_attack_snapshot["hit_time_seconds"] = _round_number(_get_now_seconds())

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

func _extract_attack_type(damage_input: Variant) -> StringName:
	if damage_input is Dictionary:
		return StringName(String((damage_input as Dictionary).get("attack_type", "default")))

	return &"default"

func _estimate_damage_amount(damage_input: Variant) -> int:
	if damage_input is int:
		return int(damage_input)
	if damage_input is float:
		return int(round(float(damage_input)))
	if damage_input is Dictionary:
		return int((damage_input as Dictionary).get("flat_damage", (damage_input as Dictionary).get("flat", 0)))

	return 0

func _clear_llm_intent() -> void:
	_move_intent = 0.0
	_current_move_horizon = 0.0
	_pending_jump_request = false
	_pending_fire_request = false
	_pending_stomp_request = false
	_pending_construct_request = false
	_pending_construct_cells.clear()
	_wants_jump = false

func _capture_runtime_state() -> void:
	_ai_state["position"] = _vector_to_dict(global_position)
	_ai_state["velocity"] = _vector_to_dict(velocity)
	_ai_state["move_intent"] = _move_intent
	_ai_state["stomp_state"] = _stomp_state
	_ai_state["active_constructs"] = _active_constructs.size()

func _build_ai_prompt_snapshot() -> Dictionary:
	var player_snapshot := _build_player_snapshot()
	var to_player := Vector2.ZERO
	if _player != null and is_instance_valid(_player):
		to_player = _player.global_position - global_position

	return {
		"timestamp_seconds": _round_number(_get_now_seconds()),
		"boss": _build_boss_snapshot(),
		"player": player_snapshot,
		"spatial": {
			"delta_to_player": _vector_to_dict(to_player),
			"horizontal_distance": _round_number(absf(to_player.x)),
			"vertical_distance": _round_number(absf(to_player.y)),
			"distance_to_player": _round_number(to_player.length()),
			"player_side": _get_player_side(to_player.x),
			"play_bounds_x": {
				"start": _round_number(play_boundary_start_x),
				"end": _round_number(play_boundary_end_x),
				"boss_within_bounds": not _has_horizontal_play_bounds() or (global_position.x >= play_boundary_start_x and global_position.x <= play_boundary_end_x)
			}
		},
		"ability_availability": {
			"can_move": true,
			"can_jump_now": _can_jump_now(),
			"can_fire_now": _can_fire_now(),
			"can_stomp_now": _can_stomp_now(),
			"can_construct_now": _can_construct_now(),
			"fireball_quota": {
				"remaining_in_interval": _get_remaining_fireballs_in_interval(),
				"max_per_interval": max_fireballs_per_interval,
				"interval_seconds": _round_number(fireball_interval_seconds),
				"quota_exhausted": _is_fireball_quota_exhausted()
			}
		},
		"recent_signals": {
			"player_last_attack": _last_player_attack_snapshot,
			"player_last_hit_on_boss": _last_player_hit_on_boss,
			"boss_last_action_result": _last_action_result,
			"boss_last_llm_decision": _last_ai_decision
		},
		"combat_directives": {
			"default_sprite_facing": "right",
			"must_face_player": true,
			"must_stay_in_combat_mode": true,
			"do_not_idle": true,
			"goal": "maintain simultaneous attack pressure and defensive structure usage",
			"preferred_min_distance_to_player": _round_number(ai_preferred_min_distance),
			"spacing_rule": "avoid getting too close unless a stomp or emergency punish is clearly worth it",
			"play_area_rule": "never move beyond play_bounds_x.start or play_bounds_x.end"
		}
	}

func _build_boss_snapshot() -> Dictionary:
	var boss_health := int(npc.get("current_health")) if npc != null else 0
	var boss_max_health := int(npc.get("max_health")) if npc != null else 0
	return {
		"position": _vector_to_dict(global_position),
		"velocity": _vector_to_dict(velocity),
		"health": boss_health,
		"max_health": boss_max_health,
		"health_ratio": _safe_ratio(boss_health, boss_max_health),
		"grounded": is_on_floor(),
		"facing_direction": _facing_direction,
		"combat_engaged": _combat_engaged,
		"stomp_state": _stomp_state_to_text(),
		"constructs": {
			"active_count": _active_constructs.size(),
			"max_active": max_active_constructs,
			"slots_remaining": _get_remaining_construct_slots(),
			"block_budget_per_cast": max_construct_blocks_per_cast,
			"allowed_relative_x_min": -construct_back_span_blocks,
			"allowed_relative_x_max": construct_forward_span_blocks,
			"allowed_relative_y_min": -construct_height_blocks,
			"allowed_relative_y_max": 1
		},
		"cooldowns": {
			"jump_seconds": _round_number(_jump_cooldown_timer),
			"fire_seconds": _round_number(_shoot_cooldown_timer),
			"stomp_seconds": _round_number(_stomp_cooldown_timer)
		},
		"fireball_usage": {
			"remaining_in_interval": _get_remaining_fireballs_in_interval(),
			"max_per_interval": max_fireballs_per_interval,
			"interval_seconds": _round_number(fireball_interval_seconds)
		}
	}

func _build_player_snapshot() -> Dictionary:
	if _player == null or not is_instance_valid(_player):
		return {
			"visible": false
		}

	if _player.has_method("get_combat_state_snapshot"):
		var snapshot = _player.call("get_combat_state_snapshot")
		if snapshot is Dictionary:
			var resolved_snapshot: Dictionary = (snapshot as Dictionary).duplicate(true)
			resolved_snapshot["visible"] = true
			return resolved_snapshot

	return {
		"visible": true,
		"position": _vector_to_dict(_player.global_position),
		"velocity": _vector_to_dict(_extract_node_velocity(_player)),
		"grounded": bool(_player.call("is_on_floor")) if _player.has_method("is_on_floor") else false,
		"last_attack": _last_player_attack_snapshot
	}

func _build_ai_system_prompt() -> String:
	return """You are the final boss combat brain for a fast 2D action platformer.
Output only compact JSON that matches the response schema. No prose. No markdown. No explanations.
Make split-second decisions. Treat this as fight-or-flight where milliseconds matter.
The local game code will only validate and execute legal abilities. It must not choose strategy for you.
The boss sprite faces right by default.
Always face the player. Stay in combat mode. Maintain both attack pressure and defensive behavior.
Do not stand still to think. Do not output passive plans. If you are able to act, choose an action or reposition immediately.
Maintain at least about %s horizontal units from the knight when practical. Do not drift into point-blank range without a clear reason.
Stay inside the horizontal play area between x=%s and x=%s. Never move beyond those X bounds.
You may fire at most %s fireballs every %s seconds. When the fireball quota is low or exhausted, shift into construct-heavy play and use walls/ramparts/other constructs instead of trying to spam projectiles.
Fight creatively using movement, facing, jumping, stomps, fireballs, and constructs.
Use resources carefully. Respect cooldowns, construct slots remaining, and your block budget per cast.
Construct coordinates are relative to the boss's current facing:
- positive x = forward
- negative x = behind
- y = 0 is the ground anchor
- negative y builds upward
You may combine actions in one decision if they are worth the risk.
Construct budget per cast: %d blocks.
Allowed construct x range: %d to %d.
Allowed construct y range: %d to %d.
""" % [
		_round_number(ai_preferred_min_distance),
		_round_number(play_boundary_start_x),
		_round_number(play_boundary_end_x),
		max_fireballs_per_interval,
		_round_number(fireball_interval_seconds),
		max_construct_blocks_per_cast,
		-construct_back_span_blocks,
		construct_forward_span_blocks,
		-construct_height_blocks,
		1
	]

func _build_ai_response_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["move", "face", "jump_now", "fire_now", "stomp_now", "construct", "horizon_seconds"],
		"properties": {
			"move": {
				"type": "string",
				"enum": ["left", "right", "hold"]
			},
			"face": {
				"type": "string",
				"enum": ["left", "right", "keep"]
			},
			"jump_now": {
				"type": "boolean"
			},
			"fire_now": {
				"type": "boolean"
			},
			"stomp_now": {
				"type": "boolean"
			},
			"horizon_seconds": {
				"type": "number",
				"minimum": 0.1,
				"maximum": max(ai_max_decision_horizon_seconds, 0.1)
			},
			"construct": {
				"type": "object",
				"additionalProperties": false,
				"required": ["spawn", "cells"],
				"properties": {
					"spawn": {
						"type": "boolean"
					},
					"cells": {
						"type": "array",
						"maxItems": max_construct_blocks_per_cast,
						"items": {
							"type": "object",
							"additionalProperties": false,
							"required": ["x", "y"],
							"properties": {
								"x": {
									"type": "integer",
									"minimum": -construct_back_span_blocks,
									"maximum": construct_forward_span_blocks
								},
								"y": {
									"type": "integer",
									"minimum": -construct_height_blocks,
									"maximum": 1
								}
							}
						}
					}
				}
			}
		}
	}

func _get_remaining_construct_slots() -> int:
	if max_active_constructs <= 0:
		return -1

	return max(max_active_constructs - _active_constructs.size(), 0)

func _get_player_side(delta_x: float) -> String:
	if delta_x > 0.0:
		return "right"
	if delta_x < 0.0:
		return "left"

	return "overlap"

func _move_text_to_intent(move_text: String) -> float:
	match move_text:
		"left":
			return -1.0
		"right":
			return 1.0
		_:
			return 0.0

func _stomp_state_to_text() -> String:
	match _stomp_state:
		STOMP_RISING:
			return "rising"
		STOMP_DIVING:
			return "diving"
		_:
			return "idle"

func _vector_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": _round_number(value.x),
		"y": _round_number(value.y)
	}

func _vector2i_array_to_dicts(cells: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in cells:
		result.append({
			"x": cell.x,
			"y": cell.y
		})
	return result

func _round_number(value: float) -> float:
	return snappedf(value, 0.01)

func _safe_ratio(value: int, maximum_value: int) -> float:
	if maximum_value <= 0:
		return 0.0

	return _round_number(float(value) / float(maximum_value))

func _extract_node_velocity(node: Node) -> Vector2:
	var raw_velocity = node.get("velocity")
	if raw_velocity is Vector2:
		return raw_velocity

	return Vector2.ZERO

func _get_now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
