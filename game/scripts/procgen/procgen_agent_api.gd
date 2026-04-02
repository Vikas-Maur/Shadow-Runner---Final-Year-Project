class_name ProcGenAgentAPI
extends RefCounted

var tile_map: TileMap
var catalog: ProcGenTileCatalog

var _runtime_regions: Array[Dictionary] = []
var _visual_lookup: Dictionary = {}

func _init(p_tile_map: TileMap = null, p_catalog: ProcGenTileCatalog = null) -> void:
	configure(p_tile_map, p_catalog)

func configure(p_tile_map: TileMap, p_catalog: ProcGenTileCatalog) -> void:
	tile_map = p_tile_map
	catalog = p_catalog

func clear_runtime_regions() -> void:
	_runtime_regions.clear()

func clear_visual_mappings() -> void:
	_visual_lookup.clear()

func register_theme(theme: ProcGenVisualTheme) -> void:
	if theme == null:
		return

	for visual in theme.visuals:
		if visual == null:
			continue
		_visual_lookup[_make_visual_key(
			visual.tile_map_layer,
			visual.source_id,
			visual.atlas_coords,
			visual.alternative_tile
		)] = {
			"logical_layer": visual.logical_layer,
			"tile_id": visual.tile_id
		}

func register_layout_region(layout: ProcGenLayout, origin: Vector2i, theme: ProcGenVisualTheme = null) -> void:
	if layout == null:
		return
	if theme != null:
		register_theme(theme)

	_runtime_regions.append({
		"layout": layout,
		"origin": origin
	})

func consume_tile_map_metadata() -> void:
	if tile_map == null or not tile_map.has_meta("procgen_runtime_regions"):
		return

	var raw_regions: Variant = tile_map.get_meta("procgen_runtime_regions")
	if not (raw_regions is Array):
		return

	clear_runtime_regions()
	for raw_region in raw_regions:
		if not (raw_region is Dictionary):
			continue
		var region: Dictionary = raw_region
		var layout_value: Variant = region.get("layout")
		var origin_value: Variant = region.get("origin", Vector2i.ZERO)
		var theme_value: Variant = region.get("theme")
		var layout: ProcGenLayout = layout_value as ProcGenLayout
		var theme: ProcGenVisualTheme = theme_value as ProcGenVisualTheme
		var origin: Vector2i = _coerce_vector2i(origin_value)
		if layout == null:
			continue
		register_layout_region(layout, origin, theme)

func get_tile_info_at_world(world_position: Vector2, logical_layer: StringName = &"ground") -> Dictionary:
	return get_tile_info(_world_to_cell(world_position), logical_layer)

func get_tile_info(cell: Vector2i, logical_layer: StringName = &"ground") -> Dictionary:
	var runtime_tile: Dictionary = _get_runtime_tile_info(cell, logical_layer)
	if not runtime_tile.is_empty():
		return runtime_tile

	var tile_map_tile: Dictionary = _get_tilemap_tile_info(cell, logical_layer)
	if not tile_map_tile.is_empty():
		return tile_map_tile

	return _build_empty_tile_info(cell, logical_layer)

func get_nearby_tiles(world_position: Vector2, radius_cells: int = 3, logical_layer: StringName = &"ground") -> Array[Dictionary]:
	var center_cell: Vector2i = _world_to_cell(world_position)
	var tiles: Array[Dictionary] = []
	var clamped_radius: int = maxi(radius_cells, 0)
	for y in range(center_cell.y - clamped_radius, center_cell.y + clamped_radius + 1):
		for x in range(center_cell.x - clamped_radius, center_cell.x + clamped_radius + 1):
			tiles.append(get_tile_info(Vector2i(x, y), logical_layer))
	return tiles

func evaluate_risk(tile: Dictionary) -> Dictionary:
	var score: float = 0.0
	var reasons: Array[String] = []
	var danger: float = float(tile.get("danger", 0.0))
	var visibility: float = float(tile.get("visibility", 1.0))
	var collision_enabled: bool = bool(tile.get("collision_enabled", false))
	var tags: Array[String] = _variant_to_string_array(tile.get("tags", []))

	score += danger * 1.8
	if collision_enabled:
		score += 0.7
		reasons.append("blocked")
	if danger > 0.0:
		reasons.append("danger")
	if visibility >= 0.85:
		score += 0.2
		reasons.append("exposed")
	if tags.has("hazard"):
		score += 0.5
	if tags.has("cover") or tags.has("stealth"):
		score -= 0.2
		reasons.append("cover")

	return {
		"score": _round_number(maxf(score, 0.0)),
		"reasons": reasons
	}

func simulate_move(action: Dictionary) -> Dictionary:
	var actor_position: Vector2 = _coerce_vector2(action.get("actor_position", Vector2.ZERO))
	var move_direction: String = String(action.get("move", "hold")).to_lower()
	var distance_cells: int = clampi(int(action.get("distance_cells", 2)), 0, 8)
	var jump: bool = bool(action.get("jump", false))

	var direction_sign: int = 0
	if move_direction == "left":
		direction_sign = -1
	elif move_direction == "right":
		direction_sign = 1

	var start_cell: Vector2i = _world_to_cell(actor_position)
	var target_cell: Vector2i = start_cell + Vector2i(direction_sign * distance_cells, -1 if jump else 0)
	var target_tile: Dictionary = get_tile_info(target_cell)
	var support_tile: Dictionary = get_tile_info(target_cell + Vector2i(0, 1))
	var target_risk: Dictionary = evaluate_risk(target_tile)
	var support_risk: Dictionary = evaluate_risk(support_tile)
	var landing_safe: bool = (
		not bool(target_tile.get("collision_enabled", false))
		and bool(support_tile.get("collision_enabled", false))
		and float(target_risk.get("score", 0.0)) < 1.4
		and float(support_risk.get("score", 0.0)) < 1.9
	)

	return {
		"start_cell": _vector2i_to_dict(start_cell),
		"target_cell": _vector2i_to_dict(target_cell),
		"target_tile": target_tile,
		"support_tile": support_tile,
		"target_risk": target_risk,
		"support_risk": support_risk,
		"landing_safe": landing_safe,
		"estimated_world_position": _vector_to_dict(_cell_to_world(target_cell))
	}

func get_safe_positions(origin_world_position: Vector2, search_radius_cells: int = 6, max_positions: int = 5) -> Array[Dictionary]:
	var origin_cell: Vector2i = _world_to_cell(origin_world_position)
	var candidates: Array[Dictionary] = []
	var clamped_radius: int = maxi(search_radius_cells, 0)

	for y in range(origin_cell.y - clamped_radius, origin_cell.y + clamped_radius + 1):
		for x in range(origin_cell.x - clamped_radius, origin_cell.x + clamped_radius + 1):
			var cell: Vector2i = Vector2i(x, y)
			var tile: Dictionary = get_tile_info(cell)
			var support_tile: Dictionary = get_tile_info(cell + Vector2i(0, 1))
			if bool(tile.get("collision_enabled", false)):
				continue
			if not bool(support_tile.get("collision_enabled", false)):
				continue

			var tile_risk: Dictionary = evaluate_risk(tile)
			var support_risk: Dictionary = evaluate_risk(support_tile)
			var score: float = float(tile_risk.get("score", 0.0)) + (float(support_risk.get("score", 0.0)) * 0.6)
			score += float(origin_cell.distance_to(cell)) * 0.08
			score += float(tile.get("visibility", 1.0)) * 0.1
			if float(tile.get("danger", 0.0)) > 0.0 or float(support_tile.get("danger", 0.0)) > 0.0:
				continue

			candidates.append({
				"cell": _vector2i_to_dict(cell),
				"world_position": _vector_to_dict(_cell_to_world(cell)),
				"tile": tile,
				"support_tile": support_tile,
				"score": _round_number(score)
			})

	candidates.sort_custom(Callable(self, "_sort_candidate_positions"))
	if candidates.size() <= max_positions:
		return candidates
	var trimmed: Array[Dictionary] = []
	for index in range(max_positions):
		trimmed.append(candidates[index])
	return trimmed

func get_tool_descriptors() -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	descriptors.append({
		"name": "get_nearby_tiles",
		"description": "Return nearby logical tiles and their properties around a world position.",
		"parameters": {
			"world_position": {"type": "Vector2"},
			"radius_cells": {"type": "int", "default": 3},
			"logical_layer": {"type": "StringName", "default": "ground"}
		}
	})
	descriptors.append({
		"name": "get_player_position",
		"description": "Resolve the player's current world position.",
		"parameters": {}
	})
	descriptors.append({
		"name": "evaluate_risk",
		"description": "Score the danger/exposure of a tile payload returned by tile queries.",
		"parameters": {
			"tile": {"type": "Dictionary"}
		}
	})
	descriptors.append({
		"name": "simulate_move",
		"description": "Estimate the landing cell, tile risk, and safety of a possible move.",
		"parameters": {
			"actor_position": {"type": "Vector2"},
			"move": {"type": "String", "enum": ["left", "right", "hold"]},
			"distance_cells": {"type": "int"},
			"jump": {"type": "bool"}
		}
	})
	descriptors.append({
		"name": "get_safe_positions",
		"description": "Find low-risk standable cells near a world position.",
		"parameters": {
			"origin_world_position": {"type": "Vector2"},
			"search_radius_cells": {"type": "int", "default": 6},
			"max_positions": {"type": "int", "default": 5}
		}
	})
	return descriptors

func get_player_position(player: Node2D) -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {
			"visible": false
		}

	return {
		"visible": true,
		"position": _vector_to_dict(player.global_position)
	}

func _get_runtime_tile_info(cell: Vector2i, logical_layer: StringName) -> Dictionary:
	for index in range(_runtime_regions.size() - 1, -1, -1):
		var region: Dictionary = _runtime_regions[index]
		var layout_value: Variant = region.get("layout")
		var origin_value: Variant = region.get("origin", Vector2i.ZERO)
		var layout: ProcGenLayout = layout_value as ProcGenLayout
		var origin: Vector2i = _coerce_vector2i(origin_value)
		if layout == null:
			continue

		var local_cell: Vector2i = cell - origin
		if not layout.is_in_bounds(local_cell.x, local_cell.y):
			continue

		var layers: Dictionary = {}
		var primary_layer: StringName = logical_layer
		var primary_definition: ProcGenTileDefinition = null
		var danger: float = 0.0
		var visibility: float = 1.0
		var collision_enabled: bool = false
		var blocks_light: bool = false
		var tags: Array[String] = []

		for layer_name in layout.layer_names:
			var tile_index: int = layout.get_cell(layer_name, local_cell.x, local_cell.y)
			var definition: ProcGenTileDefinition = catalog.get_definition_by_index(tile_index) if catalog != null else null
			if definition == null or definition.id == &"air":
				continue
			layers[String(layer_name)] = definition.to_dictionary()
			if layer_name == logical_layer or primary_definition == null:
				primary_layer = layer_name
				primary_definition = definition
			danger = maxf(danger, definition.danger)
			visibility = minf(visibility, definition.visibility)
			collision_enabled = collision_enabled or definition.collision_enabled
			blocks_light = blocks_light or definition.blocks_light
			for tag in definition.tags:
				var tag_text: String = String(tag)
				if not tags.has(tag_text):
					tags.append(tag_text)

		if primary_definition == null:
			return _build_empty_tile_info(cell, logical_layer)

		return {
			"cell": _vector2i_to_dict(cell),
			"world_position": _vector_to_dict(_cell_to_world(cell)),
			"tile_id": String(primary_definition.id),
			"label": primary_definition.label,
			"logical_layer": String(primary_layer),
			"collision_enabled": collision_enabled,
			"friction": primary_definition.friction,
			"visibility": _round_number(visibility),
			"danger": _round_number(danger),
			"blocks_light": blocks_light,
			"tags": tags,
			"source": "runtime_layout",
			"layers": layers
		}

	return {}

func _get_tilemap_tile_info(cell: Vector2i, logical_layer: StringName) -> Dictionary:
	if tile_map == null:
		return {}

	for layer_index in range(tile_map.get_layers_count()):
		var source_id: int = tile_map.get_cell_source_id(layer_index, cell)
		if source_id == -1:
			continue

		var atlas_coords: Vector2i = tile_map.get_cell_atlas_coords(layer_index, cell)
		var alternative_tile: int = tile_map.get_cell_alternative_tile(layer_index, cell)
		var visual_key: String = _make_visual_key(layer_index, source_id, atlas_coords, alternative_tile)
		if _visual_lookup.has(visual_key):
			var mapped_value: Variant = _visual_lookup[visual_key]
			if mapped_value is Dictionary:
				var mapped: Dictionary = mapped_value
				var tile_id: StringName = StringName(mapped.get("tile_id", "air"))
				var mapped_layer: StringName = StringName(mapped.get("logical_layer", logical_layer))
				var definition: ProcGenTileDefinition = catalog.get_definition(tile_id) if catalog != null else null
				if definition != null:
					return _build_definition_tile_info(cell, mapped_layer, definition, "tilemap_visual")

		var inferred_tile: Dictionary = _infer_tilemap_tile(cell, logical_layer, layer_index, source_id, atlas_coords, alternative_tile)
		if not inferred_tile.is_empty():
			return inferred_tile

	return {}

func _infer_tilemap_tile(
	cell: Vector2i,
	logical_layer: StringName,
	layer_index: int,
	source_id: int,
	atlas_coords: Vector2i,
	alternative_tile: int
) -> Dictionary:
	if tile_map == null or tile_map.tile_set == null:
		return {}

	var source: TileSetSource = tile_map.tile_set.get_source(source_id)
	var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
	if atlas_source == null or not atlas_source.has_tile(atlas_coords):
		return {}

	var tile_data: TileData = atlas_source.get_tile_data(atlas_coords, alternative_tile)
	if tile_data == null:
		return {}

	var has_collision: bool = tile_data.get_collision_polygons_count(0) > 0
	var definition: ProcGenTileDefinition = null
	if catalog != null:
		if has_collision and catalog.has_tile(&"wall"):
			definition = catalog.get_definition(&"wall")
		elif not has_collision and catalog.has_tile(&"light_zone"):
			definition = catalog.get_definition(&"light_zone")

	if definition == null:
		return {
			"cell": _vector2i_to_dict(cell),
			"world_position": _vector_to_dict(_cell_to_world(cell)),
			"tile_id": "unknown",
			"label": "Unknown Tile",
			"logical_layer": String(logical_layer),
			"collision_enabled": has_collision,
			"friction": 1.0,
			"visibility": 1.0,
			"danger": 0.0,
			"blocks_light": has_collision,
			"tags": ["inferred"],
			"source": "tilemap_inferred",
			"tile_map_layer": layer_index
		}

	return _build_definition_tile_info(cell, logical_layer, definition, "tilemap_inferred")

func _build_definition_tile_info(
	cell: Vector2i,
	logical_layer: StringName,
	definition: ProcGenTileDefinition,
	source_name: String
) -> Dictionary:
	var tags: Array[String] = []
	for tag in definition.tags:
		tags.append(String(tag))

	return {
		"cell": _vector2i_to_dict(cell),
		"world_position": _vector_to_dict(_cell_to_world(cell)),
		"tile_id": String(definition.id),
		"label": definition.label,
		"logical_layer": String(logical_layer),
		"collision_enabled": definition.collision_enabled,
		"friction": definition.friction,
		"visibility": _round_number(definition.visibility),
		"danger": _round_number(definition.danger),
		"blocks_light": definition.blocks_light,
		"tags": tags,
		"source": source_name
	}

func _build_empty_tile_info(cell: Vector2i, logical_layer: StringName) -> Dictionary:
	var definition: ProcGenTileDefinition = catalog.get_definition(&"air") if catalog != null and catalog.has_tile(&"air") else null
	if definition != null:
		return _build_definition_tile_info(cell, logical_layer, definition, "empty")

	return {
		"cell": _vector2i_to_dict(cell),
		"world_position": _vector_to_dict(_cell_to_world(cell)),
		"tile_id": "air",
		"label": "Air",
		"logical_layer": String(logical_layer),
		"collision_enabled": false,
		"friction": 1.0,
		"visibility": 1.0,
		"danger": 0.0,
		"blocks_light": false,
		"tags": [],
		"source": "empty"
	}

func _world_to_cell(world_position: Vector2) -> Vector2i:
	if tile_map == null:
		return Vector2i.ZERO
	var local_position: Vector2 = tile_map.to_local(world_position)
	return tile_map.local_to_map(local_position)

func _cell_to_world(cell: Vector2i) -> Vector2:
	if tile_map == null:
		return Vector2.ZERO
	return tile_map.to_global(tile_map.map_to_local(cell))

func _make_visual_key(tile_map_layer: int, source_id: int, atlas_coords: Vector2i, alternative_tile: int) -> String:
	return "%s|%s|%s|%s|%s" % [
		tile_map_layer,
		source_id,
		atlas_coords.x,
		atlas_coords.y,
		alternative_tile
	]

func _sort_candidate_positions(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("score", 0.0)) < float(b.get("score", 0.0))

func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			result.append(String(item))
	elif value is Array:
		for item in value:
			result.append(String(item))
	return result

func _coerce_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var raw_value: Dictionary = value
		return Vector2(float(raw_value.get("x", 0.0)), float(raw_value.get("y", 0.0)))
	return Vector2.ZERO

func _coerce_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		var vector_value: Vector2 = value
		return Vector2i(int(round(vector_value.x)), int(round(vector_value.y)))
	if value is Dictionary:
		var raw_value: Dictionary = value
		return Vector2i(int(raw_value.get("x", 0)), int(raw_value.get("y", 0)))
	return Vector2i.ZERO

func _vector_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": _round_number(value.x),
		"y": _round_number(value.y)
	}

func _vector2i_to_dict(value: Vector2i) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}

func _round_number(value: float) -> float:
	return snappedf(value, 0.01)
