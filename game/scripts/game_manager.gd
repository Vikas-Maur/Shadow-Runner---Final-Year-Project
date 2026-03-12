extends Node

var score: int = 0

@onready var score_label: Label = get_node_or_null("ScoreLabel") as Label

func _ready() -> void:
	if not LevelManager.score_changed.is_connected(_on_score_changed):
		LevelManager.score_changed.connect(_on_score_changed)
	_on_score_changed(LevelManager.get_score())

func add_point(amount: int = 1) -> void:
	LevelManager.add_score(amount)

func _on_score_changed(new_score: int) -> void:
	score = new_score
	if score_label != null:
		score_label.text = "You collected %d coins." % score
