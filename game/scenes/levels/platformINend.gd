extends Node2D

@export var move_distance: float = 100.0
@export var speed: float = 2.0   # lower = slower, smoother
@export var phase_offset := 0.0
var start_position: Vector2
var time := 0.0

func _ready():
	start_position = global_position

func _physics_process(delta):
	time += delta
	var offset = sin(time * speed + phase_offset) * move_distance
	global_position.y = start_position.y + offset
