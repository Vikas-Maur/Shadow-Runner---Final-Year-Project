extends Node2D

const SPEED = 60
var direction = 1
var health = 150

@onready var ray_cast_right = $RayCastRight
@onready var ray_cast_left = $RayCastLeft
@onready var animated_sprite = $AnimatedSprite2D
@onready var killzone = $Killzone

# ---- SOUND PLAYERS (2D so volume fades with distance) ----
@onready var walk_sound_player: AudioStreamPlayer2D = $WalkSoundPlayer
@onready var death_sound_player: AudioStreamPlayer2D = $DeathSoundPlayer

# ---- SOUND ARRAYS ----
@export var walk_sounds: Array[AudioStream] = []
@export var death_sounds: Array[AudioStream] = []

# ---- WALK SOUND TIMER ----
@export var walk_sound_interval: float = 0.4
var _walk_timer: float = 0.0

# --- Attack cooldown ---
const ATTACK_COOLDOWN = 1.2
var can_attack = true

func _ready():
	if LevelManager.is_enemy_defeated(self):
		queue_free()
		return
	if killzone:
		killzone.body_entered.connect(_on_killzone_body_entered)

func _process(delta):
	if ray_cast_right.is_colliding():
		direction = -1
		animated_sprite.flip_h = true

	if ray_cast_left.is_colliding():
		direction = 1
		animated_sprite.flip_h = false

	position.x += direction * SPEED * delta

	# 🔊 Walk sound timer
	_walk_timer -= delta
	if _walk_timer <= 0.0:
		_play_sound(walk_sound_player, walk_sounds)
		_walk_timer = walk_sound_interval

# Called when player walks into slime
func _on_killzone_body_entered(body: Node) -> void:
	if not can_attack:
		return
	if body.has_method("take_damage"):
		body.take_damage(10)
		can_attack = false
		await get_tree().create_timer(ATTACK_COOLDOWN).timeout
		can_attack = true

# -------------------------
# DAMAGE SYSTEM
# -------------------------
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		die()

func apply_damage(damage_input: Variant, _source: Node = null):
	var damage_amount := 0
	if damage_input is Dictionary:
		damage_amount = int(damage_input.get("flat_damage", 0))
	elif damage_input is int:
		damage_amount = damage_input
	take_damage(damage_amount)

func die():
	LevelManager.register_enemy_defeat(self)

	if killzone != null:
		killzone.monitoring = false
		killzone.monitorable = false

	# 🔊 Detach sound player so it survives queue_free
	if death_sound_player != null and not death_sounds.is_empty():
		var sound = death_sound_player
		remove_child(sound)
		get_parent().add_child(sound)
		sound.global_position = global_position
		_play_sound(sound, death_sounds)
		# Auto cleanup after sound finishes
		sound.finished.connect(sound.queue_free)

	queue_free()

# -------------------------
# 🔊 SOUND HELPER
# -------------------------
func _play_sound(player: AudioStreamPlayer2D, sounds: Array[AudioStream]) -> void:
	if sounds.is_empty() or player == null:
		return
	player.stream = sounds[randi() % sounds.size()]
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play(0.0)
