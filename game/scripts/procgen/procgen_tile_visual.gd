class_name ProcGenTileVisual
extends Resource

@export var tile_id: StringName = &"air"
@export var logical_layer: StringName = &"ground"
@export var tile_map_layer: int = 0
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0
@export_range(0.0, 10.0, 0.01) var weight: float = 1.0

func to_dictionary() -> Dictionary:
	return {
		"tile_id": String(tile_id),
		"logical_layer": String(logical_layer),
		"tile_map_layer": tile_map_layer,
		"source_id": source_id,
		"atlas_coords": atlas_coords,
		"alternative_tile": alternative_tile,
		"weight": weight
	}
