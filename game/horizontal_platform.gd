extends CharacterBody2D

@export var move_distance: float = 100.0
@export var speed: float = 50.0

var start_position: Vector2
var direction := 1

func _ready():
	start_position = global_position

func _physics_process(delta):
	var movement = direction * speed
	
	velocity = Vector2(movement, 0)
	move_and_slide()

	var traveled = global_position.x - start_position.x

	if abs(traveled) >= move_distance:
		direction *= -1
