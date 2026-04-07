extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

var _is_collected: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_start_glow()
	_start_float()
	_start_pulse()
	_spawn_sparkle()

func _start_glow() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate", Color(3.5, 3.0, 0.2, 1.0), 0.4)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "modulate", Color(1.8, 1.4, 0.1, 1.0), 0.4)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)

func _start_float() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "position:y", -5.0, 0.7)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 5.0, 0.7)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)

func _start_pulse() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.35)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.95, 0.95), 0.35)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)

func _spawn_sparkle() -> void:
	if _is_collected:
		return

	# Create a simple glowing dot instead of using sprite texture
	var sparkle := ColorRect.new()
	sparkle.size = Vector2(4, 4)
	sparkle.color = Color(3.0, 2.5, 0.3, 1.0)

	var angle := randf() * TAU
	var distance := randf_range(10.0, 20.0)
	sparkle.position = Vector2(cos(angle), sin(angle)) * distance

	add_child(sparkle)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sparkle, "color", Color(3.0, 2.5, 0.3, 0.0), 0.5)
	tween.tween_property(sparkle, "position", sparkle.position + Vector2(cos(angle), sin(angle)) * 12.0, 0.5)
	await tween.finished
	sparkle.queue_free()

	await get_tree().create_timer(randf_range(0.1, 0.3)).timeout
	_spawn_sparkle()

func _on_body_entered(body: Node) -> void:
	if _is_collected:
		return
	if not body.has_method("heal"):
		return
	_is_collected = true
	_play_collect_effect()

func _play_collect_effect() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(3.0, 3.0), 0.3)
	tween.tween_property(sprite, "modulate", Color(4.0, 3.5, 0.5, 0.0), 0.3)
	await tween.finished
	LevelManager.advance_to_next_level()
	queue_free()
