class_name ProcGenDefaults
extends RefCounted

static func build_catalog() -> ProcGenTileCatalog:
	var catalog := ProcGenTileCatalog.new()
	var definitions: Array[ProcGenTileDefinition] = []
	definitions.append(_tile(&"air", "Air", false, 1.0, 1.0, 0.0, false, []))
	definitions.append(_tile(&"floor", "Floor", true, 1.0, 0.8, 0.0, true, ["ground", "walkable_surface"]))
	definitions.append(_tile(&"wall", "Wall", true, 1.2, 0.95, 0.0, true, ["ground", "blocker"]))
	definitions.append(_tile(&"one_way", "One Way Platform", true, 1.0, 0.7, 0.0, false, ["ground", "platform"]))
	definitions.append(_tile(&"spike", "Spike", true, 0.9, 1.0, 1.0, false, ["hazard"]))
	definitions.append(_tile(&"shadow_zone", "Shadow Zone", false, 1.0, 0.2, 0.0, false, ["stealth", "cover"]))
	definitions.append(_tile(&"light_zone", "Light Zone", false, 1.0, 1.0, 0.0, false, ["stealth", "lit"]))
	catalog.definitions = definitions
	catalog.rebuild_index()
	return catalog

static func build_theme() -> ProcGenVisualTheme:
	var theme := ProcGenVisualTheme.new()
	var visuals: Array[ProcGenTileVisual] = []
	visuals.append(_visual(&"ground", &"floor", 0, 0, Vector2i(0, 0)))
	visuals.append(_visual(&"ground", &"floor", 0, 0, Vector2i(1, 0), 1, 0.4))
	visuals.append(_visual(&"ground", &"wall", 0, 0, Vector2i(2, 0)))
	visuals.append(_visual(&"ground", &"one_way", 0, 0, Vector2i(3, 0)))
	visuals.append(_visual(&"ground", &"spike", 0, 0, Vector2i(4, 0)))
	visuals.append(_visual(&"stealth", &"shadow_zone", 1, 0, Vector2i(5, 0)))
	visuals.append(_visual(&"stealth", &"light_zone", 1, 0, Vector2i(6, 0)))
	theme.visuals = visuals
	theme.rebuild_index()
	return theme

static func build_demo_chunks() -> Array[ProcGenChunk]:
	var start_chunk := ProcGenChunk.new()
	start_chunk.chunk_id = &"start_ledge"
	start_chunk.width = 8
	start_chunk.height = 4
	start_chunk.rows = PackedStringArray([
		"........",
		"........",
		"..####..",
		"########"
	])

	var gap_chunk := ProcGenChunk.new()
	gap_chunk.chunk_id = &"gap_with_shadows"
	gap_chunk.width = 8
	gap_chunk.height = 4
	gap_chunk.rows = PackedStringArray([
		"..ssss..",
		"........",
		"##....##",
		"########"
	])

	var spike_chunk := ProcGenChunk.new()
	spike_chunk.chunk_id = &"spike_lane"
	spike_chunk.width = 8
	spike_chunk.height = 4
	spike_chunk.rows = PackedStringArray([
		"........",
		"........",
		".^^^^^..",
		"########"
	])

	var chunks: Array[ProcGenChunk] = []
	chunks.append(start_chunk)
	chunks.append(gap_chunk)
	chunks.append(spike_chunk)
	return chunks

static func _tile(
	tile_id: StringName,
	label: String,
	collision_enabled: bool,
	friction: float,
	visibility: float,
	danger: float,
	blocks_light: bool,
	tags: Array
) -> ProcGenTileDefinition:
	var tile := ProcGenTileDefinition.new()
	tile.id = tile_id
	tile.label = label
	tile.collision_enabled = collision_enabled
	tile.friction = friction
	tile.visibility = visibility
	tile.danger = danger
	tile.blocks_light = blocks_light
	tile.tags = PackedStringArray(tags)
	return tile

static func _visual(
	logical_layer: StringName,
	tile_id: StringName,
	tile_map_layer: int,
	source_id: int,
	atlas_coords: Vector2i,
	alternative_tile: int = 0,
	weight: float = 1.0
) -> ProcGenTileVisual:
	var visual := ProcGenTileVisual.new()
	visual.logical_layer = logical_layer
	visual.tile_id = tile_id
	visual.tile_map_layer = tile_map_layer
	visual.source_id = source_id
	visual.atlas_coords = atlas_coords
	visual.alternative_tile = alternative_tile
	visual.weight = weight
	return visual
