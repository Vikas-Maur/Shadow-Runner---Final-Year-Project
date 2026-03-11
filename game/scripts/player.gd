extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const DamagePayload = preload("res://scripts/damage_payload.gd")

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite = $AnimatedSprite2D
@export var max_health: int = 100

signal health_changed(current_health: int, max_health: int)
signal died

var current_health: int = 0

func _ready():
	current_health = max_health
	health_changed.emit(current_health, max_health)

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction: -1, 0, 1
	var direction = Input.get_axis("move_left", "move_right")
	
	# Flip the Sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
	
	# Play animations
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")
	
	# Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func take_damage(amount: int):
	apply_damage(amount)

func apply_damage(damage_input: Variant, _source: Node = null):
	if is_dead():
		return

	var resolved_damage = _resolve_damage_amount(damage_input)
	if resolved_damage <= 0:
		return

	current_health = max(current_health - resolved_damage, 0)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()

func heal(amount: int):
	if amount <= 0 or is_dead():
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return current_health <= 0

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
