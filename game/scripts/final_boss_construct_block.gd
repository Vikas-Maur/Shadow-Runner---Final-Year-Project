extends StaticBody2D

@export var block_size: Vector2 = Vector2(24.0, 24.0)
@export var fill_color: Color = Color(0.26, 0.03, 0.03, 0.96)
@export var core_color: Color = Color(0.52, 0.08, 0.08, 0.96)
@export var edge_color: Color = Color(1.0, 0.39, 0.14, 0.9)
@export var pop_duration_seconds: float = 0.12

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _pop_elapsed: float = 0.0

func _ready() -> void:
	add_to_group("final_boss_construct_block")
	_update_collision_shape()
	set_process(true)
	scale = Vector2(1.0, 0.05)
	queue_redraw()

func _process(delta: float) -> void:
	if _pop_elapsed >= pop_duration_seconds:
		if not is_equal_approx(scale.y, 1.0):
			scale = Vector2.ONE
		return

	_pop_elapsed += delta
	var progress: float = minf(_pop_elapsed / maxf(pop_duration_seconds, 0.001), 1.0)
	var pop_scale_y: float = lerpf(0.05, 1.0, _ease_out_back(progress))
	scale = Vector2(1.0, pop_scale_y)

func _draw() -> void:
	var rect := Rect2(Vector2(-block_size.x * 0.5, -block_size.y), block_size)
	var inner_rect := rect.grow(-2.0)
	var ember_rect := Rect2(
		Vector2(rect.position.x + 3.0, rect.position.y + 3.0),
		Vector2(maxf(rect.size.x - 6.0, 2.0), 5.0)
	)

	draw_rect(rect, fill_color)
	draw_rect(inner_rect, core_color)
	draw_rect(ember_rect, edge_color)
	draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), edge_color, 2.0, true)
	draw_line(Vector2(rect.position.x, rect.end.y - 1.0), Vector2(rect.end.x, rect.end.y - 1.0), Color(0.12, 0.01, 0.01, 0.85), 2.0, true)

func configure(new_block_size: Vector2, pop_duration: float) -> void:
	block_size = new_block_size
	pop_duration_seconds = pop_duration
	_update_collision_shape()
	queue_redraw()

func _update_collision_shape() -> void:
	if collision_shape == null:
		return

	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape

	shape.size = block_size
	collision_shape.position = Vector2(0.0, -block_size.y * 0.5)

func _ease_out_back(value: float) -> float:
	var overshoot := 1.70158
	var shifted := value - 1.0
	return 1.0 + ((overshoot + 1.0) * shifted * shifted * shifted) + (overshoot * shifted * shifted)

func is_final_boss_construct_block() -> bool:
	return true
