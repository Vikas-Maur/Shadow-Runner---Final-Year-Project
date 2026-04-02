class_name ProcGenVisualTheme
extends Resource

@export var visuals: Array[ProcGenTileVisual] = []

var _visuals_by_key: Dictionary = {}

func rebuild_index() -> void:
	_visuals_by_key.clear()
	for visual in visuals:
		if visual == null:
			continue
		var key := _get_key(visual.logical_layer, visual.tile_id)
		if not _visuals_by_key.has(key):
			_visuals_by_key[key] = []
		(_visuals_by_key[key] as Array).append(visual)

func get_visuals(logical_layer: StringName, tile_id: StringName) -> Array[ProcGenTileVisual]:
	if _visuals_by_key.is_empty():
		rebuild_index()
	var key := _get_key(logical_layer, tile_id)
	return _visuals_by_key.get(key, [])

func pick_visual(logical_layer: StringName, tile_id: StringName, cell: Vector2i, seed: int) -> ProcGenTileVisual:
	var candidates := get_visuals(logical_layer, tile_id)
	if candidates.is_empty():
		return null
	if candidates.size() == 1:
		return candidates[0]

	var total_weight := 0.0
	for candidate in candidates:
		total_weight += max(candidate.weight, 0.001)

	var roll := _stable_roll(logical_layer, tile_id, cell, seed) * total_weight
	var cursor := 0.0
	for candidate in candidates:
		cursor += max(candidate.weight, 0.001)
		if roll <= cursor:
			return candidate

	return candidates.back()

func _get_key(logical_layer: StringName, tile_id: StringName) -> String:
	return "%s::%s" % [String(logical_layer), String(tile_id)]

func _stable_roll(logical_layer: StringName, tile_id: StringName, cell: Vector2i, seed: int) -> float:
	var hash_value := seed
	hash_value = hash_value * 31 + String(logical_layer).hash()
	hash_value = hash_value * 31 + String(tile_id).hash()
	hash_value = hash_value * 31 + cell.x * 73856093
	hash_value = hash_value * 31 + cell.y * 19349663
	hash_value = abs(hash_value)
	return float(hash_value % 10000) / 10000.0
