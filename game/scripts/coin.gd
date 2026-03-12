extends Area2D

@onready var game_manager = %GameManager
@onready var animation_player = $AnimationPlayer

var _is_collected: bool = false

func _ready() -> void:
	if LevelManager.is_item_collected(self):
		queue_free()

func _on_body_entered(body):
	if _is_collected or body.name != "Player":
		return
	if not LevelManager.register_collected_item(self):
		return

	_is_collected = true
	game_manager.add_point()
	animation_player.play("pickup")
