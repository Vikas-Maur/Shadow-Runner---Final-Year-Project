extends Area2D

const DamagePayload = preload("res://scripts/damage_payload.gd")

@onready var timer = $Timer
@export var damage_payload: DamagePayload
@export var flat_damage: int = 25
@export_range(0.0, 2.0, 0.01) var max_health_damage_percent: float = 0.0
@export_range(0.0, 2.0, 0.01) var current_health_damage_percent: float = 0.0
@export var minimum_damage: int = 0
@export var hit_cooldown_seconds: float = 0.6

var _damage_cooldowns: Dictionary = {}

func _on_body_entered(body):
	if not body.has_method("apply_damage") and not body.has_method("take_damage"):
		return

	var body_id = body.get_instance_id()
	if _damage_cooldowns.has(body_id):
		return

	_damage_cooldowns[body_id] = true
	var payload: Variant = damage_payload
	if payload == null:
		payload = {
		"flat_damage": flat_damage,
		"max_health_percent": max_health_damage_percent,
		"current_health_percent": current_health_damage_percent,
		"minimum_damage": minimum_damage
		}
	if body.has_method("apply_damage"):
		body.apply_damage(payload, self)
	else:
		body.take_damage(flat_damage)

	if body.has_method("is_dead") and body.is_dead():
		Engine.time_scale = 0.5
		timer.start()
		return

	var cooldown_timer = get_tree().create_timer(hit_cooldown_seconds)
	cooldown_timer.timeout.connect(func():
		_damage_cooldowns.erase(body_id)
	)


func _on_timer_timeout():
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
