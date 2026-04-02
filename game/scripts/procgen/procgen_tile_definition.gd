class_name ProcGenTileDefinition
extends Resource

@export var id: StringName = &"air"
@export var label: String = ""
@export var collision_enabled: bool = false
@export_range(0.0, 2.0, 0.01) var friction: float = 1.0
@export_range(0.0, 1.0, 0.01) var visibility: float = 1.0
@export_range(0.0, 1.0, 0.01) var danger: float = 0.0
@export var blocks_light: bool = false
@export var tags: PackedStringArray = PackedStringArray()

func is_walkable() -> bool:
	return not collision_enabled and danger < 1.0

func to_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"label": label,
		"collision_enabled": collision_enabled,
		"friction": friction,
		"visibility": visibility,
		"danger": danger,
		"blocks_light": blocks_light,
		"tags": tags
	}
