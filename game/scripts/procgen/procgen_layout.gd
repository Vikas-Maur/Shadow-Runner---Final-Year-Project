class_name ProcGenLayout
extends RefCounted

var width: int = 0
var height: int = 0
var layer_names: Array[StringName] = []
var metadata: Dictionary = {}

var _layer_data: Dictionary = {}

func _init(p_width: int = 0, p_height: int = 0, p_layers: Array[StringName] = [&"ground", &"stealth"]) -> void:
	resize(p_width, p_height, p_layers)

func resize(p_width: int, p_height: int, p_layers: Array[StringName]) -> void:
	width = max(p_width, 0)
	height = max(p_height, 0)
	layer_names = p_layers.duplicate()
	_layer_data.clear()
	for layer_name in layer_names:
		_layer_data[layer_name] = _make_filled_array(width * height, -1)

func clear(fill_value: int = -1) -> void:
	for layer_name in layer_names:
		_layer_data[layer_name] = _make_filled_array(width * height, fill_value)

func fill(layer_name: StringName, value: int) -> void:
	if not _layer_data.has(layer_name):
		return
	_layer_data[layer_name] = _make_filled_array(width * height, value)

func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func get_index(x: int, y: int) -> int:
	return y * width + x

func get_cell(layer_name: StringName, x: int, y: int) -> int:
	if not is_in_bounds(x, y) or not _layer_data.has(layer_name):
		return -1
	return (_layer_data[layer_name] as Array[int])[get_index(x, y)]

func set_cell(layer_name: StringName, x: int, y: int, value: int) -> void:
	if not is_in_bounds(x, y) or not _layer_data.has(layer_name):
		return
	var data: Array[int] = _layer_data[layer_name]
	data[get_index(x, y)] = value

func fill_rect(layer_name: StringName, rect: Rect2i, value: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			set_cell(layer_name, x, y, value)

func stamp(other: ProcGenLayout, origin: Vector2i) -> void:
	for layer_name in other.layer_names:
		if not _layer_data.has(layer_name):
			_layer_data[layer_name] = _make_filled_array(width * height, -1)
			layer_names.append(layer_name)
		for y in range(other.height):
			for x in range(other.width):
				var value := other.get_cell(layer_name, x, y)
				if value < 0:
					continue
				set_cell(layer_name, origin.x + x, origin.y + y, value)

func clone() -> ProcGenLayout:
	var copy := ProcGenLayout.new(width, height, layer_names)
	copy.metadata = metadata.duplicate(true)
	for layer_name in layer_names:
		copy._layer_data[layer_name] = (_layer_data[layer_name] as Array[int]).duplicate()
	return copy

func get_used_rect(layer_name: StringName) -> Rect2i:
	if not _layer_data.has(layer_name):
		return Rect2i()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in range(height):
		for x in range(width):
			if get_cell(layer_name, x, y) < 0:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func to_rows(catalog: ProcGenTileCatalog, layer_name: StringName) -> PackedStringArray:
	var rows := PackedStringArray()
	if not _layer_data.has(layer_name):
		return rows
	for y in range(height):
		var row := ""
		for x in range(width):
			var definition := catalog.get_definition_by_index(get_cell(layer_name, x, y))
			if definition == null or definition.id == &"air":
				row += "."
				continue
			row += String(definition.id).left(1).to_upper()
		rows.append(row)
	return rows

func to_dictionary(catalog: ProcGenTileCatalog) -> Dictionary:
	var serialized_layers := {}
	for layer_name in layer_names:
		var rows: Array[PackedStringArray] = []
		for y in range(height):
			var row := PackedStringArray()
			for x in range(width):
				var definition := catalog.get_definition_by_index(get_cell(layer_name, x, y))
				row.append(String(definition.id) if definition != null else "")
			rows.append(row)
		serialized_layers[String(layer_name)] = rows
	return {
		"width": width,
		"height": height,
		"layers": serialized_layers,
		"metadata": metadata.duplicate(true)
	}

func _make_filled_array(size: int, value: int) -> Array[int]:
	var result: Array[int] = []
	result.resize(size)
	for index in range(size):
		result[index] = value
	return result
