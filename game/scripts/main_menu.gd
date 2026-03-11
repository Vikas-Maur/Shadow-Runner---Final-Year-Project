extends Control

@onready var btn_new_game : TextureButton = $BtnNewGame
@onready var btn_continue : TextureButton = $BtnContinue
@onready var btn_exit     : TextureButton = $BtnExit
@onready var dev_level_panel: Control = $DevLevelPanel
@onready var dev_level_1_button: Button = $DevLevelPanel/MarginContainer/VBoxContainer/DevLevel1Button
@onready var dev_level_2_button: Button = $DevLevelPanel/MarginContainer/VBoxContainer/DevLevel2Button
@onready var dev_level_3_button: Button = $DevLevelPanel/MarginContainer/VBoxContainer/DevLevel3Button

const INTRO_SCENE := "res://scenes/IntroSequence.tscn"
const GAME_SCENE  := "res://scenes/game.tscn"

func _ready() -> void:
	btn_continue.disabled = false
	btn_new_game.pressed.connect(_on_new_game)
	btn_continue.pressed.connect(_on_continue)
	btn_exit.pressed.connect(_on_exit)

	dev_level_panel.visible = LevelManager.are_development_tools_enabled()
	if dev_level_panel.visible:
		dev_level_1_button.pressed.connect(_on_dev_level_pressed.bind(0))
		dev_level_2_button.pressed.connect(_on_dev_level_pressed.bind(1))
		dev_level_3_button.pressed.connect(_on_dev_level_pressed.bind(2))

func _on_new_game() -> void:
	LevelManager.start_new_game()
	get_tree().change_scene_to_file(INTRO_SCENE)

func _on_continue() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_exit() -> void:
	get_tree().quit()

func _on_dev_level_pressed(level_index: int) -> void:
	LevelManager.load_level(level_index)
