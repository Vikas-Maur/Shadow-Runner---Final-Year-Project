class_name ProcGenDemo
extends Node2D

@export var tile_map: TileMap
@export var debug_overlay: ProcGenDebugOverlay
@export var seed: int = 1337
@export_enum("random", "rule_based", "noise") var algorithm: String = "rule_based"
@export var map_width: int = 96
@export var map_height: int = 32

var _service: ProcGenService

func _ready() -> void:
	var catalog: ProcGenTileCatalog = ProcGenDefaults.build_catalog()
	var theme: ProcGenVisualTheme = ProcGenDefaults.build_theme()
	_service = ProcGenService.new(catalog)

	var request: ProcGenRequest = ProcGenRequest.from_dict({
		"seed": seed,
		"width": map_width,
		"height": map_height,
		"algorithm": algorithm,
		"logical_layers": ["ground", "stealth"],
		"params": {
			"floor_thickness": 2,
			"max_gap": 4,
			"max_rise": 3
		}
	})

	var layout: ProcGenLayout = _service.generate_layout(request)
	ProcGenTileMapRenderer.new().render(layout, catalog, theme, tile_map, request.seed, Vector2i.ZERO, true)

	if debug_overlay != null:
		debug_overlay.configure(layout, catalog)

	print(_service.debug_ascii(layout, &"ground"))
