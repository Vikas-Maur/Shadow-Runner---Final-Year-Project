class_name GameLevel
extends Node2D

@export var camera_bottom_limit: int = 120
@export var dev_teleport_position: Vector2 = Vector2.ZERO

func get_dev_teleport_global_position() -> Vector2:
	if dev_teleport_position != Vector2.ZERO:
		return to_global(dev_teleport_position)

	var portal := find_child("Portal", true, false)
	if portal is Node2D:
		return portal.global_position

	var spawn_node := find_child("PlayerSpawn", true, false)
	if spawn_node is Node2D:
		return spawn_node.global_position

	return global_position
