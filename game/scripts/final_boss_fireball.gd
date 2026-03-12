extends Node2D

@export var speed: float = 230.0
@export var lifetime_seconds: float = 1.2
@export var radius: float = 5.0
@export var collision_radius: float = 12.0
@export var outer_color: Color = Color(0.58, 0.02, 0.02, 0.7)
@export var flame_color: Color = Color(0.91, 0.16, 0.06, 0.92)
@export var core_color: Color = Color(1.0, 0.62, 0.18, 0.98)
@export var trail_color: Color = Color(0.38, 0.0, 0.0, 0.9)

var _direction: Vector2 = Vector2.RIGHT
var _damage_input: Variant = {"flat_damage": 0, "attack_type": "projectile"}
var _source: Node = null
var _elapsed: float = 0.0
var _spent: bool = false

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _spent:
		return

	_elapsed += delta
	if _elapsed >= lifetime_seconds:
		queue_free()
		return

	var next_position := global_position + (_direction * speed * delta)
	var hit_target := _intersect_motion(global_position, next_position)
	if hit_target != null:
		global_position = next_position
		_handle_hit(hit_target)
		return

	global_position = next_position

func _draw() -> void:
	draw_line(Vector2(-12, 0), Vector2(4, 0), trail_color, 3.0, true)
	draw_circle(Vector2.ZERO, radius * 1.2, outer_color)
	draw_circle(Vector2(-1.5, 0), radius * 0.78, flame_color)
	draw_circle(Vector2(1.5, 0), radius * 0.38, core_color)

func configure(source: Node, direction: Vector2, damage_input: Variant, projectile_speed: float, projectile_lifetime_seconds: float) -> void:
	_source = source
	_damage_input = damage_input
	speed = projectile_speed
	lifetime_seconds = projectile_lifetime_seconds

	_direction = direction.normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT

	rotation = _direction.angle()

func _intersect_motion(start: Vector2, finish: Vector2) -> Node:
	var shape := CircleShape2D.new()
	shape.radius = collision_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, start)
	query.motion = finish - start
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 3
	if _source is CollisionObject2D:
		query.exclude = [(_source as CollisionObject2D).get_rid()]

	var results := get_world_2d().direct_space_state.intersect_shape(query, 8)
	var closest_collider: Node = null
	var closest_distance: float = INF
	for result in results:
		var collider = result.get("collider")
		if _should_ignore_collider(collider):
			continue

		if not (collider is Node):
			continue

		var collider_node := collider as Node
		var hit_distance := _get_hit_distance_along_motion(start, finish, collider_node)
		if hit_distance < closest_distance:
			closest_distance = hit_distance
			closest_collider = collider_node

	return closest_collider

func _should_ignore_collider(node: Variant) -> bool:
	if node == null or not (node is Node):
		return false

	var damage_target := _resolve_damage_receiver(node)
	return damage_target == _source

func _handle_hit(collider: Variant) -> void:
	if _spent:
		return

	var damage_target := _resolve_damage_receiver(collider)
	if damage_target != null and damage_target != _source and damage_target.has_method("apply_damage"):
		damage_target.apply_damage(_damage_input, _source)

	_spend()

func _spend() -> void:
	if _spent:
		return

	_spent = true
	queue_free()

func _resolve_damage_receiver(node: Variant) -> Node:
	if node == null or not (node is Node):
		return null

	var resolved_node := node as Node
	var candidates: Array[Node] = [resolved_node]

	if resolved_node.get_parent() != null:
		candidates.append(resolved_node.get_parent())
		for sibling in resolved_node.get_parent().get_children():
			candidates.append(sibling)

	for candidate in candidates:
		if candidate != null and candidate.has_method("apply_damage"):
			return candidate

	return null

func _get_hit_distance_along_motion(start: Vector2, finish: Vector2, collider: Node) -> float:
	var travel := finish - start
	var travel_length := travel.length()
	if travel_length <= 0.001:
		return 0.0

	var collider_position := _get_node_global_position(collider)
	var projected_distance := (collider_position - start).dot(travel / travel_length)
	return clampf(projected_distance, 0.0, travel_length)

func _get_node_global_position(node: Node) -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_position

	if node.get_parent() is Node2D:
		return (node.get_parent() as Node2D).global_position

	return global_position
