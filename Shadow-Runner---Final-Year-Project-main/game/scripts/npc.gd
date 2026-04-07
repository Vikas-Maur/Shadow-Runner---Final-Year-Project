extends Node2D

const SPEED = 60
const DamagePayload = preload("res://scripts/damage_payload.gd")

var direction = 1

@onready var animated_sprite = $AnimatedSprite2D
@export var npc_name: String = ""
@export_multiline var personality: String = ""
@export var max_health: int = 100
@export var is_enemy: bool = false
@export var is_boss: bool = false
@export var enemy_type: StringName = &"neutral"
@export var health_bar_visibility_range: float = 48.0
@export var default_damage_multiplier: float = 1.0
@export var sword_damage_multiplier: float = 1.0
@export var stomp_damage_multiplier: float = 1.0
@export var shockwave_damage_multiplier: float = 1.0
@export var projectile_damage_multiplier: float = 1.0

var player_in_range = false
var player_reference = null
var current_health: int = 0
var is_interacting_with_player: bool = false
var boss_fight_active: bool = false

@onready var prompt_label = $PromptLabel
@onready var interaction_area = $InteractionArea

signal health_changed(current_health: int, max_health: int)
signal died
signal interaction_state_changed(active: bool)
signal boss_fight_state_changed(active: bool)
signal player_range_changed(in_range: bool)

func _ready():
	add_to_group("health_npcs")
	current_health = max_health
	health_changed.emit(current_health, max_health)

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	prompt_label.visible = false

func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true
		player_reference = body
		player_range_changed.emit(true)

		# ✅ FIX: Show prompt ONLY for non-enemy NPCs
		if not is_enemy:
			prompt_label.visible = true
		else:
			prompt_label.visible = false

		# ✅ Boss fight trigger (no interaction)
		if is_enemy and is_boss:
			start_boss_fight()

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		player_reference = null
		prompt_label.visible = false
		player_range_changed.emit(false)

		if is_enemy and is_boss and not is_interacting_with_player:
			end_boss_fight()

func _process(_delta):
	# ✅ FIX: Only NPCs can be interacted with
	if player_in_range and Input.is_action_just_pressed("Interact") and not is_enemy:
		start_interaction()

func start_interaction():
	if not is_interacting_with_player:
		is_interacting_with_player = true
		interaction_state_changed.emit(true)

	var dialogue_ui = get_tree().root.find_child("DialogueUI", true, false)
	if dialogue_ui:
		dialogue_ui.open_dialogue(self)

func end_interaction():
	if not is_interacting_with_player:
		return

	is_interacting_with_player = false
	interaction_state_changed.emit(false)

	if is_enemy and is_boss and not player_in_range:
		end_boss_fight()

func start_boss_fight():
	if boss_fight_active:
		return
	boss_fight_active = true
	boss_fight_state_changed.emit(true)

func end_boss_fight():
	if not boss_fight_active:
		return
	boss_fight_active = false
	boss_fight_state_changed.emit(false)

func take_damage(amount: int):
	apply_damage(amount)

func apply_damage(damage_input: Variant, _source: Node = null):
	if is_dead():
		return

	# Prevent boss from damaging itself
	if is_boss and _source != null and _source.is_in_group("health_npcs"):
		return
	if is_boss and _source != null and _source.has_method("is_final_boss"):
		return

	var resolved_damage = _resolve_damage_amount(_scale_damage_input_for_attack_type(damage_input))
	if resolved_damage <= 0:
		return

	current_health = max(current_health - resolved_damage, 0)
	health_changed.emit(current_health, max_health)

	if current_health == 0:
		died.emit()
		if is_enemy and is_boss:
			end_boss_fight()

func heal(amount: int):
	if amount <= 0 or is_dead():
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return current_health <= 0

func should_show_health_bar(player: Node2D) -> bool:
	if not is_enemy or player == null or is_dead():
		return false

	return global_position.distance_to(player.global_position) <= health_bar_visibility_range

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

func _scale_damage_input_for_attack_type(damage_input: Variant) -> Variant:
	if not is_enemy:
		return damage_input

	var attack_type = _extract_attack_type(damage_input)
	var multiplier = _get_damage_multiplier_for_attack(attack_type)

	if is_equal_approx(multiplier, 1.0):
		return damage_input

	if damage_input is int:
		return max(int(round(float(damage_input) * multiplier)), 0)

	if damage_input is float:
		return max(float(damage_input) * multiplier, 0.0)

	if damage_input is Dictionary:
		var scaled_damage: Dictionary = damage_input.duplicate(true)

		if scaled_damage.has("flat_damage"):
			scaled_damage["flat_damage"] = max(int(round(float(scaled_damage["flat_damage"]) * multiplier)), 0)
		elif scaled_damage.has("flat"):
			scaled_damage["flat"] = max(int(round(float(scaled_damage["flat"]) * multiplier)), 0)

		if scaled_damage.has("minimum_damage"):
			scaled_damage["minimum_damage"] = max(int(round(float(scaled_damage["minimum_damage"]) * multiplier)), 0)
		if scaled_damage.has("max_health_percent"):
			scaled_damage["max_health_percent"] = max(float(scaled_damage["max_health_percent"]) * multiplier, 0.0)
		if scaled_damage.has("current_health_percent"):
			scaled_damage["current_health_percent"] = max(float(scaled_damage["current_health_percent"]) * multiplier, 0.0)

		return scaled_damage

	return damage_input

func _extract_attack_type(damage_input: Variant) -> StringName:
	if damage_input is Dictionary:
		return StringName(String(damage_input.get("attack_type", "")))
	return &"default"

func _get_damage_multiplier_for_attack(attack_type: StringName) -> float:
	match attack_type:
		&"sword":
			return sword_damage_multiplier
		&"stomp":
			return stomp_damage_multiplier
		&"shockwave":
			return shockwave_damage_multiplier
		&"projectile":
			return projectile_damage_multiplier
		_:
			return default_damage_multiplier
