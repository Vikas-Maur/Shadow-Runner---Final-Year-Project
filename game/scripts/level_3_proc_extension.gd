extends Node2D

const PORTAL_SCENE := preload("res://scenes/portal.tscn")
const MID_LAYER := 1
const BRIDGE_TILES := 4
const EXTENSION_MARGIN_TILES := 3
const PROC_TILE_SOURCE_ID := 0
const PROC_FLOOR_ATLAS := Vector2i(0, 0)
const PROC_WALL_ATLAS := Vector2i(2, 0)
const PROC_ONE_WAY_ATLAS := Vector2i(3, 0)

@onready var tile_map: TileMap = $TileMap
@onready var final_boss: Node2D = $FinalBoss

var _catalog: ProcGenTileCatalog
var _service: ProcGenService
var _runtime_seed: int = 0

func _ready() -> void:
	if tile_map == null:
		return

	_catalog = ProcGenDefaults.build_catalog()
	_service = ProcGenService.new(_catalog)
	_runtime_seed = _build_runtime_seed()

	var floor_anchor: Vector2i = _find_extension_anchor_cell()
	if floor_anchor == Vector2i(-1, -1):
		push_warning("Level 3 procedural extension could not find a floor anchor.")
		return

	var request: ProcGenRequest = _build_randomized_request()

	var layout: ProcGenLayout = _service.generate_layout(request)
	var entry_floor_y: int = _find_entry_floor_y(layout)
	var extension_origin: Vector2i = Vector2i(
		floor_anchor.x + BRIDGE_TILES + EXTENSION_MARGIN_TILES,
		floor_anchor.y - entry_floor_y
	)
	var theme: ProcGenVisualTheme = _build_fixed_proc_theme()
	if not _theme_has_ground_collision(theme):
		push_warning("Level 3 procedural extension tiles are missing collision shapes in the TileSet.")
		return

	_draw_bridge(floor_anchor, extension_origin.x, theme)
	ProcGenTileMapRenderer.new().render(layout, _catalog, theme, tile_map, _runtime_seed, extension_origin, false)
	_register_procgen_region(layout, extension_origin, theme)
	_spawn_portal(layout, extension_origin)

func _build_runtime_seed() -> int:
	return int(Time.get_ticks_usec() % 2147483647)

func _build_randomized_request() -> ProcGenRequest:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _runtime_seed

	var style_profile: StringName = _choose_style_profile(rng)
	var motif_plan: Array[String] = _build_motif_plan(rng, style_profile)
	var width: int = rng.randi_range(56, 84)
	var height: int = rng.randi_range(21, 27)
	var floor_thickness: int = 3
	var corridor_bottom: int = height - floor_thickness - 2
	var max_gap: int = rng.randi_range(2, 4)
	var max_step: int = 1
	var shadow_depth: int = rng.randi_range(1, 3)
	var branch_density: float = rng.randf_range(0.35, 0.72)
	var overhang_density: float = rng.randf_range(0.25, 0.65)
	var arch_density: float = rng.randf_range(0.15, 0.5)
	var overrides: Array[Dictionary] = []

	for x in range(4):
		overrides.append({
			"layer": "ground",
			"x": x,
			"y": corridor_bottom,
			"tile_id": "floor"
		})

	return ProcGenRequest.from_dict({
		"seed": _runtime_seed,
		"width": width,
		"height": height,
		"algorithm": "composed_path",
		"logical_layers": ["ground", "stealth"],
		"params": {
			"floor_thickness": floor_thickness,
			"max_gap": max_gap,
			"max_step": max_step,
			"shadow_depth": shadow_depth,
			"hazard_chance": 0.0,
			"branch_density": branch_density,
			"overhang_density": overhang_density,
			"arch_density": arch_density,
			"style_profile": String(style_profile),
			"motif_plan": motif_plan,
			"entry_y": corridor_bottom
		},
		"agent_overrides": overrides
	})

func _choose_style_profile(rng: RandomNumberGenerator) -> StringName:
	var styles: Array[StringName] = [&"terraces", &"catwalks", &"zigzag", &"caverns"]
	return styles[rng.randi_range(0, styles.size() - 1)]

func _build_motif_plan(rng: RandomNumberGenerator, style_profile: StringName) -> Array[String]:
	var motif_count: int = rng.randi_range(6, 10)
	var motifs: Array[String] = []
	var bag: Array[StringName] = [&"flat", &"rise", &"drop", &"wave", &"basin", &"mesa", &"stair"]

	match style_profile:
		&"terraces":
			bag.append_array([&"mesa", &"mesa", &"flat", &"rise"])
		&"catwalks":
			bag.append_array([&"flat", &"flat", &"stair", &"drop"])
		&"zigzag":
			bag.append_array([&"wave", &"wave", &"stair", &"rise", &"drop"])
		&"caverns":
			bag.append_array([&"basin", &"basin", &"mesa", &"wave"])

	for _index in range(motif_count):
		motifs.append(String(bag[rng.randi_range(0, bag.size() - 1)]))

	return motifs

func _find_extension_anchor_cell() -> Vector2i:
	var used_rect: Rect2i = tile_map.get_used_rect()
	var boss_cell: Vector2i = tile_map.local_to_map(final_boss.position) if final_boss != null else used_rect.get_center()
	var search_min_x: int = max(used_rect.position.x, boss_cell.x - 6)
	var search_max_x: int = used_rect.end.x - 1
	var search_min_y: int = max(used_rect.position.y, boss_cell.y - 2)
	var search_max_y: int = used_rect.end.y - 1

	for x in range(search_max_x, search_min_x - 1, -1):
		for y in range(search_min_y, search_max_y + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not _is_mid_layer_occupied(cell):
				continue
			if _is_mid_layer_occupied(cell + Vector2i(0, -1)):
				continue
			return cell

	for x in range(search_max_x, used_rect.position.x - 1, -1):
		for y in range(used_rect.position.y, used_rect.end.y):
			var fallback_cell: Vector2i = Vector2i(x, y)
			if _is_mid_layer_occupied(fallback_cell):
				return fallback_cell

	return Vector2i(-1, -1)

func _build_fixed_proc_theme() -> ProcGenVisualTheme:
	var theme: ProcGenVisualTheme = ProcGenVisualTheme.new()
	var visuals: Array[ProcGenTileVisual] = []
	visuals.append(_make_visual(&"ground", &"floor", PROC_FLOOR_ATLAS))
	visuals.append(_make_visual(&"ground", &"one_way", PROC_ONE_WAY_ATLAS))
	visuals.append(_make_visual(&"ground", &"wall", PROC_WALL_ATLAS))
	visuals.append(_make_visual(&"ground", &"spike", Vector2i(4, 0)))
	theme.visuals = visuals
	theme.rebuild_index()
	return theme

func _draw_bridge(floor_anchor: Vector2i, extension_start_x: int, theme: ProcGenVisualTheme) -> void:
	var bridge_visual: ProcGenTileVisual = theme.pick_visual(&"ground", &"floor", floor_anchor, _runtime_seed)
	if bridge_visual == null:
		return

	for x in range(floor_anchor.x + 1, extension_start_x):
		tile_map.set_cell(
			bridge_visual.tile_map_layer,
			Vector2i(x, floor_anchor.y),
			bridge_visual.source_id,
			bridge_visual.atlas_coords,
			bridge_visual.alternative_tile
		)

func _spawn_portal(layout: ProcGenLayout, extension_origin: Vector2i) -> void:
	var goal_variant: Variant = layout.metadata.get("goal", Vector2i(layout.width - 3, 10))
	var goal_cell: Vector2i = Vector2i(layout.width - 3, 10)
	if goal_variant is Vector2i:
		goal_cell = goal_variant
	var portal: Node2D = PORTAL_SCENE.instantiate() as Node2D
	add_child(portal)
	portal.position = tile_map.map_to_local(extension_origin + goal_cell) + Vector2(0.0, -8.0)

func _find_entry_floor_y(layout: ProcGenLayout) -> int:
	for x in range(min(6, layout.width)):
		for y in range(layout.height):
			var tile_index: int = layout.get_cell(&"ground", x, y)
			var definition: ProcGenTileDefinition = _catalog.get_definition_by_index(tile_index)
			if definition == null:
				continue
			if definition.id == &"floor" or definition.id == &"wall" or definition.id == &"one_way":
				return y
	return layout.height - 1

func _make_visual(logical_layer: StringName, tile_id: StringName, atlas_coords: Vector2i) -> ProcGenTileVisual:
	var visual: ProcGenTileVisual = ProcGenTileVisual.new()
	visual.logical_layer = logical_layer
	visual.tile_id = tile_id
	visual.tile_map_layer = MID_LAYER
	visual.source_id = PROC_TILE_SOURCE_ID
	visual.atlas_coords = atlas_coords
	visual.alternative_tile = 0
	visual.weight = 1.0
	return visual

func _theme_has_ground_collision(theme: ProcGenVisualTheme) -> bool:
	var required_tiles: Array[StringName] = [&"floor", &"wall", &"one_way"]
	for tile_id in required_tiles:
		var visual: ProcGenTileVisual = theme.pick_visual(&"ground", tile_id, Vector2i.ZERO, _runtime_seed)
		if visual == null:
			return false
		if not _visual_has_collision(visual):
			return false
	return true

func _visual_has_collision(visual: ProcGenTileVisual) -> bool:
	if tile_map == null or tile_map.tile_set == null:
		return false
	var source: TileSetSource = tile_map.tile_set.get_source(visual.source_id)
	var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
	if atlas_source == null:
		return false
	if not atlas_source.has_tile(visual.atlas_coords):
		return false
	var tile_data: TileData = atlas_source.get_tile_data(visual.atlas_coords, visual.alternative_tile)
	if tile_data == null:
		return false
	return tile_data.get_collision_polygons_count(0) > 0

func _register_procgen_region(layout: ProcGenLayout, origin: Vector2i, theme: ProcGenVisualTheme) -> void:
	if tile_map == null:
		return

	var runtime_regions: Array[Dictionary] = []
	if tile_map.has_meta("procgen_runtime_regions"):
		var meta_value: Variant = tile_map.get_meta("procgen_runtime_regions")
		if meta_value is Array:
			for item in meta_value:
				if item is Dictionary:
					runtime_regions.append(item)

	runtime_regions.append({
		"layout": layout,
		"origin": origin,
		"theme": theme
	})
	tile_map.set_meta("procgen_runtime_regions", runtime_regions)

func _is_mid_layer_occupied(cell: Vector2i) -> bool:
	if cell.y < 0:
		return false
	return tile_map.get_cell_source_id(MID_LAYER, cell) != -1
