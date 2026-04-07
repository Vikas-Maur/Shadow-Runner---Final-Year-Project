extends Area2D

const HEAL_AMOUNT := 10

@onready var sprite: Sprite2D = $Sprite2D
@onready var collect_sound: AudioStreamPlayer = $CollectSound  # 🔊

@export var collect_sounds: Array[AudioStream] = []

var _is_collected: bool = false

func _ready() -> void:
	if LevelManager.is_item_collected(self):
		queue_free()
		return
	
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true
	
	_start_float_animation()
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _start_float_animation() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "position:y", -3.0, 0.6)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 3.0, 0.6)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node) -> void:
	if _is_collected:
		return
	if not body.has_method("heal"):
		return
	if not LevelManager.register_collected_item(self):
		return
	_is_collected = true
	body.heal(HEAL_AMOUNT)
	_play_collect_sound()  # 🔊
	_play_collect_effect()

# 🔊 Play sound then free
func _play_collect_sound() -> void:
	if collect_sounds.is_empty() or collect_sound == null:
		return
	collect_sound.stream = collect_sounds[randi() % collect_sounds.size()]
	collect_sound.pitch_scale = randf_range(0.95, 1.05)
	collect_sound.play(0.0)

func _play_collect_effect() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await tween.finished
	# ✅ Wait for sound to finish before freeing so it doesn't cut off
	if collect_sound != null and collect_sound.playing:
		await collect_sound.finished
	queue_free()
