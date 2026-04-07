extends Node

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready():
	add_child(player)

func play_sound(sound: AudioStream):
	if sound == null:
		return
	player.stream = sound
	player.play()
