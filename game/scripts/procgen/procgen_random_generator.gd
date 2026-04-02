class_name ProcGenRandomGenerator
extends ProcGenLevelGenerator

func generate(request: ProcGenRequest, catalog: ProcGenTileCatalog) -> ProcGenLayout:
	var rng := _build_rng(request.seed)
	var layout := _new_layout(request)
	var air := _tile(catalog, &"air")
	var floor_tile := _tile(catalog, &"floor")
	var spike_tile := _tile(catalog, &"spike")
	var shadow_tile := _tile(catalog, &"shadow_zone")

	layout.fill(&"ground", air)
	layout.fill(&"stealth", air)

	var floor_thickness := int(request.params.get("floor_thickness", 3))
	for y in range(request.height - floor_thickness, request.height):
		for x in range(request.width):
			layout.set_cell(&"ground", x, y, floor_tile)

	var platform_count := int(request.params.get("platform_count", max(8, request.width / 7)))
	for _platform_index in range(platform_count):
		var platform_length := rng.randi_range(3, 8)
		var x_start := rng.randi_range(1, max(1, request.width - platform_length - 2))
		var y := rng.randi_range(4, max(4, request.height - floor_thickness - 4))
		for x in range(x_start, x_start + platform_length):
			layout.set_cell(&"ground", x, y, floor_tile)
			if rng.randf() < 0.55 and y + 1 < request.height - floor_thickness:
				layout.set_cell(&"stealth", x, y + 1, shadow_tile)

	if spike_tile >= 0:
		var spike_groups := int(request.params.get("spike_groups", max(2, request.width / 18)))
		for _spike_index in range(spike_groups):
			var x_start := rng.randi_range(2, max(2, request.width - 4))
			var length := rng.randi_range(1, 3)
			var y := request.height - floor_thickness - 1
			for x in range(x_start, min(x_start + length, request.width - 2)):
				layout.set_cell(&"ground", x, y, spike_tile)

	layout.metadata["spawn"] = Vector2i(2, request.height - floor_thickness - 2)
	layout.metadata["goal"] = Vector2i(request.width - 3, 4)
	return layout
