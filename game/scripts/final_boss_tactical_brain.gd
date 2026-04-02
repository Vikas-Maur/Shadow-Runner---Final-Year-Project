class_name FinalBossTacticalBrain
extends RefCounted

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(seed: int = 0) -> void:
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed

func decide(snapshot: Dictionary, llm_suggestion: Dictionary = {}) -> Dictionary:
	var spatial: Dictionary = _get_dictionary(snapshot.get("spatial", {}))
	var ability: Dictionary = _get_dictionary(snapshot.get("ability_availability", {}))
	var environment: Dictionary = _get_dictionary(snapshot.get("environment", {}))
	var rhythm: Dictionary = _get_dictionary(snapshot.get("combat_rhythm", {}))
	var player: Dictionary = _get_dictionary(snapshot.get("player", {}))

	var horizontal_distance: float = float(spatial.get("horizontal_distance", 0.0))
	var vertical_distance: float = float(spatial.get("vertical_distance", 0.0))
	var player_side: String = String(spatial.get("player_side", "right"))
	var move_toward_player: String = "right" if player_side == "right" else "left"
	var move_away_from_player: String = "left" if player_side == "right" else "right"
	var preferred_min_distance: float = float(_get_dictionary(snapshot.get("combat_directives", {})).get("preferred_min_distance_to_player", 110.0))
	var current_tile: Dictionary = _get_dictionary(environment.get("current_tile", {}))
	var current_risk: Dictionary = _get_dictionary(environment.get("current_tile_risk", {}))
	var safe_positions: Array[Dictionary] = _get_dictionary_array(environment.get("safe_positions", []))
	var nearby_hazards: Array[Dictionary] = _get_dictionary_array(environment.get("nearby_hazards", []))
	var fireball_quota: Dictionary = _get_dictionary(ability.get("fireball_quota", {}))
	var can_fire_now: bool = bool(ability.get("can_fire_now", false))
	var can_stomp_now: bool = bool(ability.get("can_stomp_now", false))
	var can_jump_now: bool = bool(ability.get("can_jump_now", false))
	var can_construct_now: bool = bool(ability.get("can_construct_now", false))
	var hesitation_chance: float = clampf(float(rhythm.get("hesitation_chance", 0.22)), 0.0, 1.0)
	var imperfect_noise: float = maxf(float(rhythm.get("imperfect_decision_noise", 0.12)), 0.0)

	var options: Array[Dictionary] = []
	options.append(_score_fire(snapshot, horizontal_distance, vertical_distance, preferred_min_distance, move_toward_player, move_away_from_player, current_risk, can_fire_now))
	options.append(_score_stomp(horizontal_distance, vertical_distance, current_risk, can_stomp_now))
	options.append(_score_construct(snapshot, horizontal_distance, preferred_min_distance, move_toward_player, move_away_from_player, environment, can_construct_now, fireball_quota))
	options.append(_score_jump(snapshot, player, environment, can_jump_now))
	options.append(_score_reposition("reposition", move_toward_player, horizontal_distance > preferred_min_distance * 1.8, safe_positions, snapshot))
	options.append(_score_reposition("retreat", move_away_from_player, horizontal_distance < preferred_min_distance, safe_positions, snapshot))
	options.append(_score_wait(horizontal_distance, current_risk, hesitation_chance, nearby_hazards))

	_apply_llm_bias(options, llm_suggestion)
	_apply_imperfect_noise(options, imperfect_noise)
	options.sort_custom(Callable(self, "_sort_option_score"))

	var chosen: Dictionary = _choose_weighted_option(options, hesitation_chance)
	var decision: Dictionary = _build_decision_from_option(chosen, move_toward_player, move_away_from_player, safe_positions)
	decision["reason_trace"] = _build_reason_trace(chosen, current_tile, current_risk, nearby_hazards)
	return decision

func _score_fire(
	_snapshot: Dictionary,
	horizontal_distance: float,
	vertical_distance: float,
	preferred_min_distance: float,
	move_toward_player: String,
	move_away_from_player: String,
	current_risk: Dictionary,
	can_fire_now: bool
) -> Dictionary:
	var score: float = -1.0
	var reasons: Array[String] = []
	var move_text: String = "hold"
	if can_fire_now:
		score = 0.35
		if horizontal_distance >= 110.0 and horizontal_distance <= 320.0:
			score += 0.55
			reasons.append("mid_range_window")
		if vertical_distance <= 92.0:
			score += 0.18
		if horizontal_distance < 80.0:
			score -= 0.35
			reasons.append("too_close")
		if float(current_risk.get("score", 0.0)) > 0.9:
			score -= 0.25
			reasons.append("unsafe_footing")
		if horizontal_distance > preferred_min_distance * 1.5:
			move_text = move_toward_player
		elif horizontal_distance < preferred_min_distance * 0.8:
			move_text = move_away_from_player

	var option: Dictionary = _new_option("fire", score, move_text, reasons)
	option["fire_now"] = can_fire_now and score > 0.0
	option["action_seconds"] = 0.34
	option["recovery_seconds"] = 0.28
	return option

func _score_stomp(horizontal_distance: float, vertical_distance: float, current_risk: Dictionary, can_stomp_now: bool) -> Dictionary:
	var score: float = -1.0
	var reasons: Array[String] = []
	if can_stomp_now:
		score = 0.22
		if horizontal_distance >= 42.0 and horizontal_distance <= 130.0:
			score += 0.7
			reasons.append("stomp_range")
		if vertical_distance <= 64.0:
			score += 0.16
		if float(current_risk.get("score", 0.0)) > 1.0:
			score -= 0.3
			reasons.append("bad_launch_tile")

	var option: Dictionary = _new_option("stomp", score, "hold", reasons)
	option["stomp_now"] = can_stomp_now and score > 0.0
	option["action_seconds"] = 0.5
	option["recovery_seconds"] = 0.38
	return option

func _score_construct(
	_snapshot: Dictionary,
	horizontal_distance: float,
	preferred_min_distance: float,
	move_toward_player: String,
	move_away_from_player: String,
	environment: Dictionary,
	can_construct_now: bool,
	fireball_quota: Dictionary
) -> Dictionary:
	var score: float = -1.0
	var reasons: Array[String] = []
	var cells: Array[Dictionary] = []
	var move_text: String = "hold"
	if can_construct_now:
		score = 0.25
		var quota_exhausted: bool = bool(fireball_quota.get("quota_exhausted", false))
		var remaining_fireballs: int = int(fireball_quota.get("remaining_in_interval", 0))
		var nearby_hazards: Array[Dictionary] = _get_dictionary_array(environment.get("nearby_hazards", []))
		var player_tile: Dictionary = _get_dictionary(environment.get("player_tile", {}))
		var player_on_high_visibility_tile: bool = float(player_tile.get("visibility", 1.0)) >= 0.85
		if quota_exhausted or remaining_fireballs <= 0:
			score += 0.6
			reasons.append("projectile_quota_low")
			cells = _choose_construct_cells("pressure_reset")
		elif horizontal_distance < 96.0:
			score += 0.44
			reasons.append("close_range_cover")
			cells = _choose_construct_cells("close_cover")
		elif not nearby_hazards.is_empty():
			score += 0.3
			reasons.append("hazard_shaping")
			cells = _choose_construct_cells("hazard_lane")
		elif player_on_high_visibility_tile:
			score += 0.2
			reasons.append("screen_control")
			cells = _choose_construct_cells("screen_control")
		else:
			score += 0.18
			cells = _choose_construct_cells("advance")
		if horizontal_distance > preferred_min_distance * 1.35:
			move_text = move_toward_player
		elif horizontal_distance < preferred_min_distance * 0.9:
			move_text = move_away_from_player

	var option: Dictionary = _new_option("construct", score, move_text, reasons)
	option["construct"] = {
		"spawn": can_construct_now and score > 0.0,
		"cells": cells
	}
	option["action_seconds"] = 0.44
	option["recovery_seconds"] = 0.34
	return option

func _score_jump(snapshot: Dictionary, player: Dictionary, environment: Dictionary, can_jump_now: bool) -> Dictionary:
	var score: float = -1.0
	var reasons: Array[String] = []
	if can_jump_now:
		score = 0.16
		var player_position: Dictionary = _get_dictionary(player.get("position", {}))
		var current_position: Dictionary = _get_dictionary(_get_dictionary(snapshot.get("boss", {})).get("position", {}))
		if float(player_position.get("y", 0.0)) < float(current_position.get("y", 0.0)) - 14.0:
			score += 0.42
			reasons.append("player_above")
		if bool(environment.get("hazard_ahead", false)):
			score += 0.35
			reasons.append("hazard_ahead")

	var option: Dictionary = _new_option("jump", score, "hold", reasons)
	option["jump_now"] = can_jump_now and score > 0.0
	option["action_seconds"] = 0.3
	option["recovery_seconds"] = 0.24
	return option

func _score_reposition(
	action_name: String,
	move_direction: String,
	should_boost: bool,
	safe_positions: Array[Dictionary],
	_snapshot: Dictionary
) -> Dictionary:
	var score: float = 0.08
	var reasons: Array[String] = []
	if should_boost:
		score += 0.72
		reasons.append("spacing_adjust")
	if not safe_positions.is_empty():
		score += 0.26
		reasons.append("safe_landing")

	var option: Dictionary = _new_option(action_name, score, move_direction, reasons)
	option["action_seconds"] = 0.28
	option["recovery_seconds"] = 0.18
	return option

func _score_wait(
	horizontal_distance: float,
	current_risk: Dictionary,
	hesitation_chance: float,
	nearby_hazards: Array[Dictionary]
) -> Dictionary:
	var score: float = 0.04
	var reasons: Array[String] = []
	if rng.randf() < hesitation_chance:
		score += 0.28
		reasons.append("hesitation")
	if horizontal_distance > 280.0:
		score += 0.12
	if float(current_risk.get("score", 0.0)) > 1.1:
		score -= 0.25
	if not nearby_hazards.is_empty():
		score -= 0.08

	var option: Dictionary = _new_option("wait", score, "hold", reasons)
	option["action_seconds"] = 0.18
	option["recovery_seconds"] = 0.22
	return option

func _apply_llm_bias(options: Array[Dictionary], llm_suggestion: Dictionary) -> void:
	if llm_suggestion.is_empty():
		return

	var primary_action: String = String(llm_suggestion.get("primary_action", ""))
	for option in options:
		if String(option.get("name", "")) != primary_action:
			continue
		option["score"] = float(option.get("score", 0.0)) + 0.14
		var reasons: Array[String] = _get_string_array(option.get("reasons", []))
		reasons.append("llm_bias")
		option["reasons"] = reasons

func _apply_imperfect_noise(options: Array[Dictionary], imperfect_noise: float) -> void:
	for option in options:
		var noise: float = rng.randf_range(-imperfect_noise, imperfect_noise)
		option["score"] = float(option.get("score", 0.0)) + noise

func _choose_weighted_option(options: Array[Dictionary], hesitation_chance: float) -> Dictionary:
	if options.is_empty():
		return _new_option("wait", 1.0, "hold", ["fallback"])

	if options.size() == 1:
		return options[0]

	var first: Dictionary = options[0]
	var second: Dictionary = options[1]
	if rng.randf() < hesitation_chance * 0.5 and float(second.get("score", -INF)) > 0.12:
		return second
	return first

func _build_decision_from_option(
	option: Dictionary,
	move_toward_player: String,
	move_away_from_player: String,
	safe_positions: Array[Dictionary]
) -> Dictionary:
	var action_name: String = String(option.get("name", "wait"))
	var move_text: String = String(option.get("move", "hold"))
	var jump_now: bool = bool(option.get("jump_now", false))
	var fire_now: bool = bool(option.get("fire_now", false))
	var stomp_now: bool = bool(option.get("stomp_now", false))
	var construct: Dictionary = _get_dictionary(option.get("construct", {
		"spawn": false,
		"cells": []
	}))
	var observation_seconds: float = _phase_seconds(0.14, 0.08)
	var thinking_seconds: float = _phase_seconds(0.11, 0.08)
	var action_seconds: float = maxf(float(option.get("action_seconds", 0.3)), 0.12)
	var recovery_seconds: float = maxf(float(option.get("recovery_seconds", 0.24)), 0.12)

	if action_name == "retreat" and move_text == "hold":
		move_text = move_away_from_player
	if action_name == "reposition" and move_text == "hold":
		move_text = move_toward_player

	if action_name == "wait":
		move_text = "hold"
		fire_now = false
		stomp_now = false
		jump_now = false
		construct = {
			"spawn": false,
			"cells": []
		}
	elif action_name == "retreat" and safe_positions.is_empty():
		move_text = move_away_from_player

	return {
		"primary_action": action_name,
		"move": move_text,
		"face": "keep",
		"jump_now": jump_now,
		"fire_now": fire_now,
		"stomp_now": stomp_now,
		"construct": construct,
		"horizon_seconds": _round_number(action_seconds),
		"observation_seconds": _round_number(observation_seconds),
		"thinking_seconds": _round_number(thinking_seconds),
		"action_seconds": _round_number(action_seconds),
		"recovery_seconds": _round_number(recovery_seconds)
	}

func _build_reason_trace(
	option: Dictionary,
	current_tile: Dictionary,
	current_risk: Dictionary,
	nearby_hazards: Array[Dictionary]
) -> Array[String]:
	var trace: Array[String] = []
	trace.append("observe: standing on %s with risk %.2f" % [
		String(current_tile.get("tile_id", "air")),
		float(current_risk.get("score", 0.0))
	])
	if not nearby_hazards.is_empty():
		trace.append("observe: hazards nearby")

	var reasons: Array[String] = _get_string_array(option.get("reasons", []))
	if reasons.is_empty():
		trace.append("think: kept pacing variation over immediate pressure")
	else:
		trace.append("think: %s" % ", ".join(reasons))

	trace.append("act: %s" % String(option.get("name", "wait")))
	return trace

func _new_option(name: String, score: float, move_text: String, reasons: Array[String]) -> Dictionary:
	return {
		"name": name,
		"score": score,
		"move": move_text,
		"reasons": reasons,
		"jump_now": false,
		"fire_now": false,
		"stomp_now": false,
		"construct": {
			"spawn": false,
			"cells": []
		}
	}

func _build_wall_cells() -> Array[Dictionary]:
	return [
		{"x": 0, "y": 0},
		{"x": 0, "y": -1},
		{"x": 0, "y": -2},
		{"x": 0, "y": -3}
	]

func _build_rampart_cells() -> Array[Dictionary]:
	return [
		{"x": 0, "y": 0},
		{"x": 1, "y": 0},
		{"x": 0, "y": -1},
		{"x": 1, "y": -1},
		{"x": 2, "y": -2}
	]

func _build_stair_cells() -> Array[Dictionary]:
	return [
		{"x": 0, "y": 0},
		{"x": 1, "y": -1},
		{"x": 2, "y": -2},
		{"x": 3, "y": -3}
	]

func _build_pillar_gate_cells() -> Array[Dictionary]:
	return [
		{"x": 0, "y": 0},
		{"x": 0, "y": -1},
		{"x": 2, "y": 0},
		{"x": 2, "y": -1},
		{"x": 1, "y": -2}
	]

func _build_overhang_cells() -> Array[Dictionary]:
	return [
		{"x": 0, "y": 0},
		{"x": 1, "y": 0},
		{"x": 2, "y": -1},
		{"x": 3, "y": -1},
		{"x": 1, "y": -2}
	]

func _build_zigzag_cells() -> Array[Dictionary]:
	return [
		{"x": 0, "y": 0},
		{"x": 1, "y": -1},
		{"x": 2, "y": 0},
		{"x": 3, "y": -1},
		{"x": 4, "y": 0}
	]

func _build_wedge_cells() -> Array[Dictionary]:
	return [
		{"x": 0, "y": 0},
		{"x": 1, "y": 0},
		{"x": 2, "y": -1},
		{"x": 3, "y": -2},
		{"x": 4, "y": -2}
	]

func _build_canopy_cells() -> Array[Dictionary]:
	return [
		{"x": 0, "y": 0},
		{"x": 1, "y": -1},
		{"x": 2, "y": -2},
		{"x": 3, "y": -2},
		{"x": 4, "y": -1}
	]

func _choose_construct_cells(mode: String) -> Array[Dictionary]:
	var pool: Array = []
	match mode:
		"pressure_reset":
			pool.append(_build_wall_cells())
			pool.append(_build_pillar_gate_cells())
			pool.append(_build_canopy_cells())
		"close_cover":
			pool.append(_build_rampart_cells())
			pool.append(_build_overhang_cells())
			pool.append(_build_pillar_gate_cells())
		"hazard_lane":
			pool.append(_build_zigzag_cells())
			pool.append(_build_wedge_cells())
			pool.append(_build_overhang_cells())
		"screen_control":
			pool.append(_build_canopy_cells())
			pool.append(_build_wedge_cells())
			pool.append(_build_stair_cells())
		_:
			pool.append(_build_stair_cells())
			pool.append(_build_zigzag_cells())
			pool.append(_build_wedge_cells())

	if pool.is_empty():
		return _build_wall_cells()

	var pattern_index: int = rng.randi_range(0, pool.size() - 1)
	var selected: Array[Dictionary] = pool[pattern_index]
	return _mutate_construct_cells(selected)

func _mutate_construct_cells(cells: Array[Dictionary]) -> Array[Dictionary]:
	var mutated: Array[Dictionary] = []
	var x_shift: int = rng.randi_range(0, 1)
	var y_shift: int = rng.randi_range(0, 1)
	for raw_cell in cells:
		var x_value: int = int(raw_cell.get("x", 0))
		var y_value: int = int(raw_cell.get("y", 0))
		if rng.randf() < 0.22:
			y_value -= y_shift
		if rng.randf() < 0.35:
			x_value += x_shift
		mutated.append({
			"x": x_value,
			"y": y_value
		})
	return mutated

func _phase_seconds(base_seconds: float, jitter_seconds: float) -> float:
	return _round_number(maxf(0.08, base_seconds + rng.randf_range(-jitter_seconds, jitter_seconds)))

func _sort_option_score(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("score", 0.0)) > float(b.get("score", 0.0))

func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}

func _get_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value:
		if item is Dictionary:
			result.append(item)
	return result

func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result

func _round_number(value: float) -> float:
	return snappedf(value, 0.01)
