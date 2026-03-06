extends Control

@onready var btn_new_game : TextureButton = $BtnNewGame
@onready var btn_continue : TextureButton = $BtnContinue
@onready var btn_exit     : TextureButton = $BtnExit

const INTRO_SCENE := "res://scenes/IntroSequence.tscn"
const GAME_SCENE  := "res://scenes/game.tscn"

func _ready() -> void:
	btn_continue.disabled = not FileAccess.file_exists("user://save.dat")
	btn_new_game.pressed.connect(_on_new_game)
	btn_continue.pressed.connect(_on_continue)
	btn_exit.pressed.connect(_on_exit)

func _on_new_game() -> void:
	get_tree().change_scene_to_file(INTRO_SCENE)

func _on_continue() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_exit() -> void:
	get_tree().quit()
