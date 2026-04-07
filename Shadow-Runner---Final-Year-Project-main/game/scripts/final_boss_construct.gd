extends Node2D

signal expired(construct: Node2D)

const FinalBossConstructBlockScene = preload("res://scenes/effects/final_boss_construct_block.tscn")

@export var block_size: Vector2 = Vector2(24.0, 24.0)
@export var lifetime_seconds: float = 4.2
@export var spawn_step_delay_seconds: float = 0.1
@export var block_pop_duration_seconds: float = 0.12

var _pattern_cells: Array[Vector2i] = []
var _spawn_index: int = 0
var _spawn_timer: float = 0.0
var _elapsed: float = 0.0
var _expired: bool = false

func _ready() -> void:
	if _pattern_cells.is_empty():
		queue_free()
		return

	add_to_group("final_boss_construct")
	set_process(true)
	_spawn_next_block()

func _process(delta: float) -> void:
	if _expired:
		return

	_elapsed += delta
	if _elapsed >= lifetime_seconds:
		_expire()
		return

	if _spawn_index >= _pattern_cells.size():
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_next_block()

func configure(pattern_cells: Array[Vector2i], new_block_size: Vector2, lifetime: float, step_delay: float, pop_duration: float, facing_direction: int) -> void:
	block_size = new_block_size
	lifetime_seconds = lifetime
	spawn_step_delay_seconds = step_delay
	block_pop_duration_seconds = pop_duration
	_pattern_cells.clear()
	for cell in pattern_cells:
		_pattern_cells.append(Vector2i(cell.x * facing_direction, cell.y))

func _spawn_next_block() -> void:
	if _spawn_index >= _pattern_cells.size():
		return

	var block = FinalBossConstructBlockScene.instantiate()
	if block.has_method("configure"):
		block.configure(block_size, block_pop_duration_seconds)

	add_child(block)

	var cell := _pattern_cells[_spawn_index]
	block.position = Vector2(cell.x * block_size.x, cell.y * block_size.y)

	_spawn_index += 1
	_spawn_timer = spawn_step_delay_seconds

func _expire() -> void:
	if _expired:
		return

	_expired = true
	expired.emit(self)
	queue_free()
