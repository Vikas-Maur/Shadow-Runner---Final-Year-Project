extends Area2D

signal activated

@export var prompt_text: String = "Press I or click to enter"
@export var no_destination_text: String = "No next level yet"

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false
	_update_prompt_text()

func _process(_delta: float) -> void:
	if _player_in_range and Input.is_action_just_pressed("Interact"):
		_activate_portal()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_activate_portal()

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return

	_player_in_range = true
	_update_prompt_text()
	prompt_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.name != "Player":
		return

	_player_in_range = false
	prompt_label.visible = false

func _activate_portal() -> void:
	if not LevelManager.has_next_level():
		_update_prompt_text()
		return

	activated.emit()
	LevelManager.advance_to_next_level()

func _update_prompt_text() -> void:
	prompt_label.text = prompt_text if LevelManager.has_next_level() else no_destination_text
