extends Node2D

const SPEED = 60

var direction = 1

@onready var ray_cast_right = $RayCastRight
@onready var ray_cast_left = $RayCastLeft
@onready var animated_sprite = $AnimatedSprite2D
@onready var npc = $NPC
@onready var killzone = $Killzone

func _ready():
	if npc != null and npc.has_signal("died") and not npc.died.is_connected(_on_npc_died):
		npc.died.connect(_on_npc_died)

func _process(delta):
	if npc != null and npc.has_method("is_dead") and npc.is_dead():
		return

	if ray_cast_right.is_colliding():
		direction = -1
		animated_sprite.flip_h = true
	if ray_cast_left.is_colliding():
		direction = 1
		animated_sprite.flip_h = false
	
	position.x += direction * SPEED * delta

func _on_npc_died():
	set_process(false)
	if killzone != null:
		killzone.monitoring = false
		killzone.monitorable = false
	queue_free()
