class_name ProcGenTileCatalog
extends Resource

@export var definitions: Array[ProcGenTileDefinition] = []

var _indices_by_id: Dictionary = {}

func rebuild_index() -> void:
	_indices_by_id.clear()
	for index in range(definitions.size()):
		var definition: ProcGenTileDefinition = definitions[index]
		if definition == null:
			continue
		_indices_by_id[definition.id] = index

func has_tile(tile_id: StringName) -> bool:
	if _indices_by_id.is_empty():
		rebuild_index()
	return _indices_by_id.has(tile_id)

func get_index(tile_id: StringName) -> int:
	if _indices_by_id.is_empty():
		rebuild_index()
	return int(_indices_by_id.get(tile_id, -1))

func get_definition(tile_id: StringName) -> ProcGenTileDefinition:
	return get_definition_by_index(get_index(tile_id))

func get_definition_by_index(index: int) -> ProcGenTileDefinition:
	if index < 0 or index >= definitions.size():
		return null
	return definitions[index]

func require_index(tile_id: StringName) -> int:
	var tile_index: int = get_index(tile_id)
	assert(tile_index >= 0, "Unknown tile id: %s" % String(tile_id))
	return tile_index

func to_dictionary() -> Dictionary:
	var tiles: Array[Dictionary] = []
	for definition in definitions:
		if definition == null:
			continue
		tiles.append(definition.to_dictionary())
	return {
		"tiles": tiles
	}
