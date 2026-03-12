extends Area2D

@export var speed: float = 320.0
@export var lifetime_seconds: float = 0.7
@export var radius: float = 4.0
@export var projectile_color: Color = Color(1.0, 0.92, 0.45, 0.95)
@export var trail_color: Color = Color(1.0, 0.55, 0.18, 0.85)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _direction: Vector2 = Vector2.RIGHT
var _damage_input: Variant = {"flat_damage": 0, "attack_type": "projectile"}
var _source: Node = null
var _elapsed: float = 0.0
var _spent: bool = false

func _ready() -> void:
	_update_collision_shape()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _spent:
		return

	_elapsed += delta
	if _elapsed >= lifetime_seconds:
		queue_free()
		return

	global_position += _direction * speed * delta

func _draw() -> void:
	draw_line(Vector2(-8, 0), Vector2(5, 0), trail_color, 2.0, true)
	draw_circle(Vector2.ZERO, radius, projectile_color)

func configure(source: Node, direction: Vector2, damage_input: Variant, projectile_speed: float, projectile_lifetime_seconds: float) -> void:
	_source = source
	_damage_input = damage_input
	speed = projectile_speed
	lifetime_seconds = projectile_lifetime_seconds

	_direction = direction.normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT

	rotation = _direction.angle()

func _on_area_entered(area: Area2D) -> void:
	_handle_collision(area)

func _on_body_entered(body: Node2D) -> void:
	_handle_collision(body)

func _handle_collision(node: Node) -> void:
	if _spent or node == null or not is_instance_valid(node):
		return

	if _belongs_to_source(node):
		return

	var damage_target = _resolve_damage_receiver(node)
	if damage_target != null:
		if damage_target == _source or _belongs_to_source(damage_target):
			return
		if damage_target.has_method("is_dead") and damage_target.is_dead():
			_spend()
			return

		damage_target.apply_damage(_damage_input, _source)
		_spend()
		return

	_spend()

func _spend() -> void:
	if _spent:
		return

	_spent = true
	queue_free()

func _belongs_to_source(node: Node) -> bool:
	if _source == null:
		return false

	var current: Node = node
	while current != null:
		if current == _source:
			return true
		current = current.get_parent()

	return false

func _resolve_damage_receiver(node: Node) -> Node:
	var candidates: Array[Node] = [node]

	if node.get_parent() != null:
		candidates.append(node.get_parent())
		for sibling in node.get_parent().get_children():
			candidates.append(sibling)

	var owner = node.get_owner()
	if owner != null:
		candidates.append(owner)
		for owner_child in owner.get_children():
			candidates.append(owner_child)

	for candidate in candidates:
		if candidate != null and candidate.has_method("apply_damage"):
			return candidate

	return null

func _update_collision_shape() -> void:
	if collision_shape == null:
		return

	var shape := collision_shape.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		collision_shape.shape = shape
	shape.radius = radius
