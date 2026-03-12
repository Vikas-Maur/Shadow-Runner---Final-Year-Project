extends Area2D

@export var radius: float = 28.0
@export var lifetime_seconds: float = 0.18
@export var ring_width: float = 2.0
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.85)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _damage_input: Variant = {"flat_damage": 0, "attack_type": "shockwave"}
var _source: Node = null
var _elapsed: float = 0.0
var _hit_targets: Dictionary = {}
var _visual_scale: float = 0.35

func _ready() -> void:
	_update_collision_shape()
	queue_redraw()
	_apply_damage_deferred()

func _process(delta: float) -> void:
	_elapsed += delta
	var duration = max(lifetime_seconds, 0.01)
	var progress = clamp(_elapsed / duration, 0.0, 1.0)
	_visual_scale = lerpf(0.35, 1.0, progress)
	modulate.a = lerpf(1.0, 0.0, progress)
	queue_redraw()

	if progress >= 1.0:
		queue_free()

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius * _visual_scale, 0.0, TAU, 48, ring_color, ring_width, true)

func configure(source: Node, damage_input: Variant, new_radius: float, new_lifetime_seconds: float) -> void:
	_source = source
	_damage_input = damage_input
	radius = new_radius
	lifetime_seconds = new_lifetime_seconds
	_update_collision_shape()
	queue_redraw()

func _apply_damage_deferred() -> void:
	await get_tree().physics_frame
	apply_damage()

func apply_damage() -> void:
	_apply_group_damage()

	for area in get_overlapping_areas():
		_try_damage_target(_resolve_damage_receiver(area))

	for body in get_overlapping_bodies():
		_try_damage_target(_resolve_damage_receiver(body))

func _apply_group_damage() -> void:
	for npc in get_tree().get_nodes_in_group("health_npcs"):
		if npc == null or not is_instance_valid(npc):
			continue
		if not npc.is_enemy:
			continue
		if npc.global_position.distance_to(global_position) > radius:
			continue

		_try_damage_target(npc)

func _try_damage_target(target: Node) -> void:
	if target == null or target == _source or not target.has_method("apply_damage"):
		return

	var target_id = target.get_instance_id()
	if _hit_targets.has(target_id):
		return

	if target.has_method("is_dead") and target.is_dead():
		return

	_hit_targets[target_id] = true
	target.apply_damage(_damage_input, _source)

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
