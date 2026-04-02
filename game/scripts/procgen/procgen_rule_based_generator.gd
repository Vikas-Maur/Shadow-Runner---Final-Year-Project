class_name ProcGenRuleBasedGenerator
extends ProcGenLevelGenerator

func generate(request: ProcGenRequest, catalog: ProcGenTileCatalog) -> ProcGenLayout:
	var rng := _build_rng(request.seed)
	var layout := _new_layout(request)
	var air := _tile(catalog, &"air")
	var floor_tile := _tile(catalog, &"floor")
	var wall_tile := _tile(catalog, &"wall")
	var spike_tile := _tile(catalog, &"spike")
	var shadow_tile := _tile(catalog, &"shadow_zone")

	layout.fill(&"ground", air)
	layout.fill(&"stealth", air)

	var floor_thickness := int(request.params.get("floor_thickness", 2))
	var corridor_bottom := request.height - floor_thickness - 2
	for y in range(request.height - floor_thickness, request.height):
		for x in range(request.width):
			layout.set_cell(&"ground", x, y, wall_tile)

	var platform_y := corridor_bottom
	var x_cursor := 1
	var max_gap := int(request.params.get("max_gap", 4))
	var max_rise := int(request.params.get("max_rise", 3))
	var min_platform := int(request.params.get("min_platform", 4))
	var max_platform := int(request.params.get("max_platform", 8))
	var shadow_depth := int(request.params.get("shadow_depth", 2))

	while x_cursor < request.width - 8:
		var platform_length := rng.randi_range(min_platform, max_platform)
		for x in range(x_cursor, min(x_cursor + platform_length, request.width - 1)):
			layout.set_cell(&"ground", x, platform_y, floor_tile)
			for shadow_offset in range(1, shadow_depth + 1):
				var shadow_y := platform_y + shadow_offset
				if shadow_y < request.height - floor_thickness:
					layout.set_cell(&"stealth", x, shadow_y, shadow_tile)

		var hazard_roll := rng.randf()
		if hazard_roll < 0.25 and x_cursor + platform_length + 2 < request.width - 2:
			layout.set_cell(&"ground", x_cursor + platform_length - 1, platform_y - 1, spike_tile)

		var gap := rng.randi_range(2, max_gap)
		var rise := rng.randi_range(-max_rise, max_rise)
		platform_y = clamp(platform_y - rise, 4, corridor_bottom)
		x_cursor += platform_length + gap

	for x in range(0, request.width, 9):
		var pillar_height := rng.randi_range(2, 5)
		for y in range(request.height - floor_thickness - pillar_height, request.height - floor_thickness):
			layout.set_cell(&"ground", x, y, wall_tile)

	layout.metadata["spawn"] = Vector2i(2, corridor_bottom - 1)
	layout.metadata["goal"] = Vector2i(min(request.width - 3, x_cursor), max(2, platform_y - 1))
	layout.metadata["guaranteed_path"] = true
	return layout
