class_name ProcGenTileMapRenderer
extends RefCounted

func render(
	layout: ProcGenLayout,
	catalog: ProcGenTileCatalog,
	theme: ProcGenVisualTheme,
	tile_map: TileMap,
	seed: int = 0,
	cell_origin: Vector2i = Vector2i.ZERO,
	clear_layers: bool = true
) -> void:
	if tile_map == null:
		return

	var used_layers := _collect_tile_map_layers(theme)
	if clear_layers:
		for tile_map_layer in used_layers:
			if tile_map_layer >= 0 and tile_map_layer < tile_map.get_layers_count():
				tile_map.clear_layer(tile_map_layer)

	for logical_layer in layout.layer_names:
		for y in range(layout.height):
			for x in range(layout.width):
				var tile_index := layout.get_cell(logical_layer, x, y)
				if tile_index < 0:
					continue

				var definition := catalog.get_definition_by_index(tile_index)
				if definition == null or definition.id == &"air":
					continue

				var tile_id := definition.id
				if tile_id == &"air":
					continue

				var visual := theme.pick_visual(logical_layer, tile_id, Vector2i(x, y), seed)
				if visual == null:
					continue

				if visual.tile_map_layer >= tile_map.get_layers_count():
					continue

				var target_cell := cell_origin + Vector2i(x, y)
				tile_map.set_cell(
					visual.tile_map_layer,
					target_cell,
					visual.source_id,
					visual.atlas_coords,
					visual.alternative_tile
				)

func _collect_tile_map_layers(theme: ProcGenVisualTheme) -> Array[int]:
	var layer_ids: Array[int] = []
	for visual in theme.visuals:
		if visual == null or layer_ids.has(visual.tile_map_layer):
			continue
		layer_ids.append(visual.tile_map_layer)
	return layer_ids
