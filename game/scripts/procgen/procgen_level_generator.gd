class_name ProcGenLevelGenerator
extends RefCounted

func generate(request: ProcGenRequest, catalog: ProcGenTileCatalog) -> ProcGenLayout:
	push_error("%s does not implement generate()." % get_script().resource_path)
	return ProcGenLayout.new(request.width, request.height, request.logical_layers)

func _build_rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng

func _new_layout(request: ProcGenRequest) -> ProcGenLayout:
	var layout := ProcGenLayout.new(request.width, request.height, request.logical_layers)
	layout.metadata = {
		"seed": request.seed,
		"algorithm": String(request.algorithm)
	}
	return layout

func _tile(catalog: ProcGenTileCatalog, tile_id: StringName) -> int:
	return catalog.require_index(tile_id)
