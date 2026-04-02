class_name ProcGenChunk
extends Resource

@export var chunk_id: StringName = &"chunk"
@export var logical_layer: StringName = &"ground"
@export var width: int = 8
@export var height: int = 6
@export var legend: Dictionary = {
	".": &"air",
	"#": &"floor",
	"^": &"spike",
	"s": &"shadow_zone"
}
@export var rows: PackedStringArray = PackedStringArray()
@export var markers: Dictionary = {
	"entry": Vector2i(0, 0),
	"exit": Vector2i(7, 0)
}
@export var tags: PackedStringArray = PackedStringArray()

func stamp_into(layout: ProcGenLayout, origin: Vector2i, catalog: ProcGenTileCatalog) -> void:
	for y in range(min(rows.size(), height)):
		var row: String = rows[y]
		for x in range(min(row.length(), width)):
			var symbol: String = row.substr(x, 1)
			if not legend.has(symbol):
				continue
			var tile_id: StringName = StringName(legend[symbol])
			var tile_index: int = catalog.get_index(tile_id)
			if tile_index < 0:
				continue
			layout.set_cell(logical_layer, origin.x + x, origin.y + y, tile_index)
