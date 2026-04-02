class_name ProcGenComposedPathGenerator
extends ProcGenLevelGenerator

const STYLE_PROFILES: Array[StringName] = [&"terraces", &"catwalks", &"zigzag", &"caverns"]

func generate(request: ProcGenRequest, catalog: ProcGenTileCatalog) -> ProcGenLayout:
	var rng: RandomNumberGenerator = _build_rng(request.seed)
	var layout: ProcGenLayout = _new_layout(request)
	var air: int = _tile(catalog, &"air")
	var floor_tile: int = _tile(catalog, &"floor")
	var wall_tile: int = _tile(catalog, &"wall")
	var one_way_tile: int = _tile(catalog, &"one_way")
	var spike_tile: int = _tile(catalog, &"spike")
	var shadow_tile: int = _tile(catalog, &"shadow_zone")
	var floor_thickness: int = int(request.params.get("floor_thickness", 3))
	var corridor_bottom: int = request.height - floor_thickness - 2
	var max_gap: int = int(request.params.get("max_gap", 3))
	var max_step: int = int(request.params.get("max_step", 1))
	var shadow_depth: int = int(request.params.get("shadow_depth", 2))
	var hazard_chance: float = clampf(float(request.params.get("hazard_chance", 0.1)), 0.0, 1.0)
	var branch_density: float = clampf(float(request.params.get("branch_density", 0.35)), 0.0, 1.0)
	var overhang_density: float = clampf(float(request.params.get("overhang_density", 0.3)), 0.0, 1.0)
	var arch_density: float = clampf(float(request.params.get("arch_density", 0.25)), 0.0, 1.0)
	var style_profile: StringName = _resolve_style_profile(request, rng)
	var motif_plan: Array[StringName] = _extract_motif_plan(request.params)
	var surface: Array[int] = _make_surface(request.width, -1)

	layout.fill(&"ground", air)
	layout.fill(&"stealth", air)

	for y in range(request.height - floor_thickness, request.height):
		for x in range(request.width):
			layout.set_cell(&"ground", x, y, wall_tile)

	var entry_y: int = clampi(int(request.params.get("entry_y", corridor_bottom)), 5, corridor_bottom)
	for x in range(min(4, request.width)):
		surface[x] = entry_y

	_build_surface(surface, rng, corridor_bottom, max_gap, max_step, style_profile, motif_plan)
	_stamp_surface(layout, surface, floor_tile, wall_tile, floor_thickness)
	_add_arches(layout, surface, rng, air, arch_density, floor_thickness)
	_add_branch_ledges(layout, surface, rng, floor_tile, one_way_tile, shadow_tile, branch_density, shadow_depth)
	_add_overhangs(layout, surface, rng, one_way_tile, shadow_tile, overhang_density, shadow_depth)
	_add_hazards(layout, surface, rng, spike_tile, hazard_chance)

	var goal_cell: Vector2i = _find_goal_cell(surface)
	layout.metadata["spawn"] = Vector2i(2, max(2, entry_y - 1))
	layout.metadata["goal"] = goal_cell
	layout.metadata["guaranteed_path"] = true
	layout.metadata["style_profile"] = String(style_profile)
	layout.metadata["motif_plan"] = _stringify_motifs(motif_plan)
	return layout

func _resolve_style_profile(request: ProcGenRequest, rng: RandomNumberGenerator) -> StringName:
	var style_value: Variant = request.params.get("style_profile", &"")
	if style_value is StringName and String(style_value) != "":
		return style_value
	if style_value is String and String(style_value) != "":
		return StringName(style_value)
	return STYLE_PROFILES[rng.randi_range(0, STYLE_PROFILES.size() - 1)]

func _extract_motif_plan(params: Dictionary) -> Array[StringName]:
	var motif_plan: Array[StringName] = []
	var motif_value: Variant = params.get("motif_plan", [])
	if motif_value is Array:
		for item in motif_value:
			motif_plan.append(StringName(item))
	return motif_plan

func _build_surface(
	surface: Array[int],
	rng: RandomNumberGenerator,
	corridor_bottom: int,
	max_gap: int,
	max_step: int,
	style_profile: StringName,
	motif_plan: Array[StringName]
) -> void:
	var x_cursor: int = 4
	var current_y: int = surface[3]
	var motif_index: int = 0

	while x_cursor < surface.size() - 4:
		var motif: StringName = motif_plan[motif_index] if motif_index < motif_plan.size() else _choose_motif(rng, style_profile)
		motif_index += 1
		var segment_length: int = _choose_segment_length(rng, style_profile)
		var segment_heights: Array[int] = _build_segment_heights(motif, segment_length, current_y, corridor_bottom, max_step, rng)

		for local_x in range(segment_heights.size()):
			var world_x: int = x_cursor + local_x
			if world_x >= surface.size():
				break
			surface[world_x] = segment_heights[local_x]
			current_y = segment_heights[local_x]

		x_cursor += segment_heights.size()
		if x_cursor >= surface.size() - 4:
			break

		var gap: int = _choose_gap(rng, style_profile, max_gap)
		var landing_shift: int = rng.randi_range(-1, 1)
		if gap >= 3:
			landing_shift = clampi(landing_shift, 0, 1)
		current_y = clampi(current_y + landing_shift, 5, corridor_bottom)
		x_cursor += gap

	for x in range(surface.size() - 4, surface.size()):
		if x >= 0:
			surface[x] = current_y

func _choose_motif(rng: RandomNumberGenerator, style_profile: StringName) -> StringName:
	var bag: Array[StringName] = [&"flat", &"flat", &"rise", &"drop", &"wave", &"basin", &"mesa", &"stair"]
	match style_profile:
		&"terraces":
			bag.append_array([&"mesa", &"mesa", &"rise", &"flat", &"flat"])
		&"catwalks":
			bag.append_array([&"stair", &"rise", &"drop", &"flat", &"flat"])
		&"zigzag":
			bag.append_array([&"wave", &"wave", &"stair", &"rise", &"drop"])
		&"caverns":
			bag.append_array([&"basin", &"basin", &"mesa", &"wave", &"flat"])
	return bag[rng.randi_range(0, bag.size() - 1)]

func _choose_segment_length(rng: RandomNumberGenerator, style_profile: StringName) -> int:
	match style_profile:
		&"terraces":
			return rng.randi_range(8, 14)
		&"catwalks":
			return rng.randi_range(5, 10)
		&"zigzag":
			return rng.randi_range(6, 11)
		&"caverns":
			return rng.randi_range(7, 13)
	return rng.randi_range(6, 12)

func _choose_gap(rng: RandomNumberGenerator, style_profile: StringName, max_gap: int) -> int:
	var safe_max_gap: int = max(1, max_gap)
	match style_profile:
		&"terraces":
			return rng.randi_range(1, min(2, safe_max_gap))
		&"catwalks":
			return rng.randi_range(1, safe_max_gap)
		&"zigzag":
			return rng.randi_range(1, min(3, safe_max_gap))
		&"caverns":
			return rng.randi_range(1, min(2, safe_max_gap))
	return rng.randi_range(1, safe_max_gap)

func _build_segment_heights(
	motif: StringName,
	length: int,
	start_y: int,
	corridor_bottom: int,
	max_step: int,
	rng: RandomNumberGenerator
) -> Array[int]:
	var heights: Array[int] = []
	var current_y: int = start_y
	var target_shift: int = rng.randi_range(1, 3)
	var center: int = length / 2

	for index in range(length):
		match motif:
			&"rise":
				if index > 0 and index % 2 == 0:
					current_y -= min(1, max_step)
			&"drop":
				if index > 0 and index % 2 == 0:
					current_y += min(1, max_step)
			&"wave":
				if index < center and index % 2 == 1:
					current_y -= min(1, max_step)
				elif index >= center and index % 2 == 1:
					current_y += min(1, max_step)
			&"basin":
				if index < center and index % 2 == 1:
					current_y += min(1, max_step)
				elif index >= center and index % 2 == 1:
					current_y -= min(1, max_step)
			&"mesa":
				if index == 1:
					current_y -= min(target_shift, max_step)
				elif index == length - 2:
					current_y += min(target_shift, max_step)
			&"stair":
				if index > 0:
					current_y += -1 if index % 2 == 0 else 1
			_:
				pass

		current_y = clampi(current_y, 5, corridor_bottom)
		heights.append(current_y)

	return heights

func _stamp_surface(layout: ProcGenLayout, surface: Array[int], floor_tile: int, wall_tile: int, floor_thickness: int) -> void:
	for x in range(surface.size()):
		var y: int = surface[x]
		if y < 0:
			continue
		layout.set_cell(&"ground", x, y, floor_tile)
		for fill_y in range(y + 1, max(y + 2, layout.height - floor_thickness)):
			layout.set_cell(&"ground", x, fill_y, wall_tile)

func _add_arches(layout: ProcGenLayout, surface: Array[int], rng: RandomNumberGenerator, air: int, density: float, floor_thickness: int) -> void:
	var arch_attempts: int = int(round(float(layout.width) / 18.0))
	for _attempt in range(arch_attempts):
		if rng.randf() > density:
			continue
		var start_x: int = rng.randi_range(4, max(4, layout.width - 10))
		var span: int = rng.randi_range(4, 7)
		if start_x + span >= layout.width - 2:
			continue
		var base_y: int = surface[start_x]
		if base_y < 6:
			continue
		var is_flat_enough: bool = true
		for x in range(start_x, start_x + span):
			if abs(surface[x] - base_y) > 1:
				is_flat_enough = false
				break
		if not is_flat_enough:
			continue

		var clearance: int = rng.randi_range(2, 4)
		for x in range(start_x + 1, start_x + span - 1):
			for y in range(base_y + 1, min(base_y + 1 + clearance, layout.height - floor_thickness)):
				layout.set_cell(&"ground", x, y, air)

func _add_branch_ledges(
	layout: ProcGenLayout,
	surface: Array[int],
	rng: RandomNumberGenerator,
	floor_tile: int,
	one_way_tile: int,
	shadow_tile: int,
	density: float,
	shadow_depth: int
) -> void:
	var branch_attempts: int = int(round(float(layout.width) / 14.0))
	for _attempt in range(branch_attempts):
		if rng.randf() > density:
			continue
		var start_x: int = rng.randi_range(5, max(5, layout.width - 12))
		var span: int = rng.randi_range(4, 8)
		if start_x + span >= layout.width - 2:
			continue
		var anchor_y: int = surface[start_x]
		if anchor_y < 7:
			continue
		var ledge_y: int = max(3, anchor_y - rng.randi_range(3, 5))
		for x in range(start_x, start_x + span):
			layout.set_cell(&"ground", x, ledge_y, one_way_tile if x % 2 == 0 else floor_tile)
			for shade_offset in range(1, shadow_depth + 1):
				var shade_y: int = ledge_y + shade_offset
				if shade_y < anchor_y:
					layout.set_cell(&"stealth", x, shade_y, shadow_tile)

func _add_overhangs(
	layout: ProcGenLayout,
	surface: Array[int],
	rng: RandomNumberGenerator,
	one_way_tile: int,
	shadow_tile: int,
	density: float,
	shadow_depth: int
) -> void:
	var overhang_attempts: int = int(round(float(layout.width) / 16.0))
	for _attempt in range(overhang_attempts):
		if rng.randf() > density:
			continue
		var start_x: int = rng.randi_range(4, max(4, layout.width - 10))
		var span: int = rng.randi_range(3, 7)
		var anchor_y: int = surface[start_x]
		if anchor_y < 6 or start_x + span >= layout.width:
			continue
		var cover_y: int = max(2, anchor_y - rng.randi_range(4, 6))
		for x in range(start_x, start_x + span):
			if surface[x] < 0:
				break
			layout.set_cell(&"ground", x, cover_y, one_way_tile)
			for shade_offset in range(1, shadow_depth + 1):
				var shade_y: int = cover_y + shade_offset
				if shade_y < surface[x]:
					layout.set_cell(&"stealth", x, shade_y, shadow_tile)

func _add_hazards(layout: ProcGenLayout, surface: Array[int], rng: RandomNumberGenerator, spike_tile: int, hazard_chance: float) -> void:
	if hazard_chance <= 0.0:
		return
	for x in range(4, layout.width - 4):
		if surface[x] < 0:
			continue
		if surface[x - 1] < 0 or surface[x + 1] < 0:
			continue
		if rng.randf() > hazard_chance:
			continue
		layout.set_cell(&"ground", x, surface[x] - 1, spike_tile)

func _find_goal_cell(surface: Array[int]) -> Vector2i:
	for x in range(surface.size() - 2, 2, -1):
		if surface[x] >= 0:
			return Vector2i(x, max(2, surface[x] - 1))
	return Vector2i(max(2, surface.size() - 3), 4)

func _stringify_motifs(motif_plan: Array[StringName]) -> Array[String]:
	var values: Array[String] = []
	for motif in motif_plan:
		values.append(String(motif))
	return values

func _make_surface(size: int, fill_value: int) -> Array[int]:
	var result: Array[int] = []
	result.resize(size)
	for index in range(size):
		result[index] = fill_value
	return result
