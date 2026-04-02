class_name ProcGenNoiseGenerator
extends ProcGenLevelGenerator

func generate(request: ProcGenRequest, catalog: ProcGenTileCatalog) -> ProcGenLayout:
	var layout := _new_layout(request)
	var air := _tile(catalog, &"air")
	var floor_tile := _tile(catalog, &"floor")
	var wall_tile := _tile(catalog, &"wall")
	var shadow_tile := _tile(catalog, &"shadow_zone")
	var noise := FastNoiseLite.new()
	noise.seed = request.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = float(request.params.get("frequency", 0.045))

	layout.fill(&"ground", air)
	layout.fill(&"stealth", air)

	var floor_base := int(request.params.get("floor_base", request.height / 2))
	var floor_amplitude := int(request.params.get("floor_amplitude", 5))
	var ceiling_base := int(request.params.get("ceiling_base", 3))

	for x in range(request.width):
		var floor_height := floor_base + int(noise.get_noise_1d(float(x)) * floor_amplitude)
		var ceiling_height := ceiling_base + int(abs(noise.get_noise_1d(float(x) + 1000.0)) * 2.0)
		floor_height = clamp(floor_height, request.height / 3, request.height - 4)
		ceiling_height = clamp(ceiling_height, 1, floor_height - 4)

		for y in range(floor_height, request.height):
			layout.set_cell(&"ground", x, y, wall_tile if y > floor_height else floor_tile)

		if x % 7 != 0:
			for y in range(ceiling_height, min(ceiling_height + 3, floor_height - 1)):
				layout.set_cell(&"stealth", x, y, shadow_tile)

	layout.metadata["spawn"] = Vector2i(2, max(2, floor_base - 3))
	layout.metadata["goal"] = Vector2i(request.width - 3, max(2, floor_base - 5))
	return layout
