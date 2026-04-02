class_name ProcGenService
extends RefCounted

var catalog: ProcGenTileCatalog
var _generators: Dictionary = {}

func _init(p_catalog: ProcGenTileCatalog = null) -> void:
	catalog = p_catalog
	register_generator(&"random", ProcGenRandomGenerator.new())
	register_generator(&"rule_based", ProcGenRuleBasedGenerator.new())
	register_generator(&"noise", ProcGenNoiseGenerator.new())

func register_generator(generator_id: StringName, generator: ProcGenLevelGenerator) -> void:
	_generators[generator_id] = generator

func generate_layout(request: ProcGenRequest) -> ProcGenLayout:
	assert(catalog != null, "ProcGenService requires a tile catalog.")
	var generator: ProcGenLevelGenerator = _generators.get(request.algorithm)
	assert(generator != null, "Unknown generator algorithm: %s" % String(request.algorithm))
	var layout: ProcGenLayout = generator.generate(request, catalog)
	apply_agent_overrides(layout, request.agent_overrides)
	return layout

func generate_layout_from_dict(request_data: Dictionary) -> ProcGenLayout:
	return generate_layout(ProcGenRequest.from_dict(request_data))

func compose_chunk_sequence(request: ProcGenRequest, chunks: Array[ProcGenChunk]) -> ProcGenLayout:
	assert(catalog != null, "ProcGenService requires a tile catalog.")
	var layout: ProcGenLayout = ProcGenLayout.new(request.width, request.height, request.logical_layers)
	var air: int = catalog.require_index(&"air")
	for layer_name in request.logical_layers:
		layout.fill(layer_name, air)

	var cursor_x: int = 0
	for chunk in chunks:
		if chunk == null:
			continue
		var origin: Vector2i = Vector2i(cursor_x, max(0, request.height - chunk.height))
		chunk.stamp_into(layout, origin, catalog)
		cursor_x += chunk.width
		if cursor_x >= request.width:
			break

	layout.metadata = {
		"seed": request.seed,
		"algorithm": "chunk_sequence"
	}
	return layout

func apply_agent_overrides(layout: ProcGenLayout, overrides: Array[Dictionary]) -> void:
	if catalog == null:
		return
	for override in overrides:
		var layer_name: StringName = StringName(override.get("layer", "ground"))
		var tile_id: StringName = StringName(override.get("tile_id", "air"))
		var tile_index: int = catalog.get_index(tile_id)
		if tile_index < 0:
			continue
		layout.set_cell(layer_name, int(override.get("x", -1)), int(override.get("y", -1)), tile_index)

func serialize_layout(layout: ProcGenLayout) -> Dictionary:
	assert(catalog != null, "ProcGenService requires a tile catalog.")
	return layout.to_dictionary(catalog)

func debug_ascii(layout: ProcGenLayout, layer_name: StringName = &"ground") -> String:
	assert(catalog != null, "ProcGenService requires a tile catalog.")
	return "\n".join(layout.to_rows(catalog, layer_name))

func get_request_schema() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"seed": {"type": "integer"},
			"width": {"type": "integer"},
			"height": {"type": "integer"},
			"algorithm": {
				"type": "string",
				"enum": ["random", "rule_based", "noise"]
			},
			"logical_layers": {
				"type": "array",
				"items": {"type": "string"}
			},
			"params": {"type": "object"},
			"agent_overrides": {
				"type": "array",
				"items": {
					"type": "object",
					"properties": {
						"layer": {"type": "string"},
						"x": {"type": "integer"},
						"y": {"type": "integer"},
						"tile_id": {"type": "string"}
					},
					"required": ["layer", "x", "y", "tile_id"]
				}
			}
		},
		"required": ["seed", "width", "height", "algorithm"]
	}
