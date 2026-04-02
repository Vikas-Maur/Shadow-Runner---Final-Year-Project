class_name ProcGenDebugOverlay
extends Node2D

@export var tile_size: Vector2 = Vector2(16.0, 16.0)
@export var show_collision: bool = true
@export var show_danger: bool = true
@export var show_visibility: bool = true

var _layout: ProcGenLayout
var _catalog: ProcGenTileCatalog

func configure(layout: ProcGenLayout, catalog: ProcGenTileCatalog) -> void:
	_layout = layout
	_catalog = catalog
	queue_redraw()

func _draw() -> void:
	if _layout == null or _catalog == null:
		return

	for layer_name in _layout.layer_names:
		for y in range(_layout.height):
			for x in range(_layout.width):
				var definition := _catalog.get_definition_by_index(_layout.get_cell(layer_name, x, y))
				if definition == null or definition.id == &"air":
					continue

				var cell_rect := Rect2(Vector2(x, y) * tile_size, tile_size)
				if show_collision and definition.collision_enabled:
					draw_rect(cell_rect, Color(0.1, 0.6, 1.0, 0.18), true)
				if show_danger and definition.danger > 0.0:
					draw_rect(cell_rect, Color(1.0, 0.15, 0.15, 0.26), true)
				if show_visibility and definition.visibility < 0.5:
					draw_rect(cell_rect, Color(0.1, 0.1, 0.1, 0.22), true)
