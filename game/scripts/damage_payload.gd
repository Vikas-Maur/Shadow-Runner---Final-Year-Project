extends Resource
class_name DamagePayload

@export var flat_damage: int = 0
@export_range(0.0, 2.0, 0.01) var max_health_percent: float = 0.0
@export_range(0.0, 2.0, 0.01) var current_health_percent: float = 0.0
@export var minimum_damage: int = 0

func calculate_damage(max_health: int, current_health: int) -> int:
	var total_damage := flat_damage
	total_damage += int(round(float(max_health) * max_health_percent))
	total_damage += int(round(float(current_health) * current_health_percent))
	return max(total_damage, minimum_damage)
