extends Area2D

@export var score_amount: int = 1

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _is_collected: bool = false

func _ready() -> void:
	if LevelManager.is_item_collected(self):
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _is_collected or body.name != "Player":
		return
	if not LevelManager.register_collected_item(self):
		return

	_is_collected = true

	# ✅ EXISTING SYSTEM
	LevelManager.add_score(score_amount)

	# ✅ ADD THIS (IMPORTANT) 
	GameData.current_score += score_amount

	print("Current Score:", GameData.current_score) # debug

	animation_player.play("pickup")
