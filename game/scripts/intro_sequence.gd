extends Control

@onready var panel      : TextureRect     = $Panel
@onready var arrow      : TextureRect     = $Arrow
@onready var story_text : Label           = $TextBox/StoryText
@onready var anim       : AnimationPlayer = $AnimationPlayer

const GAME_SCENE := "res://scenes/game.tscn"

const PANELS : Array[Texture2D] = [
	preload("res://assets/images/story_panel_1.png"),
	preload("res://assets/images/story_panel_2.png"),
	preload("res://assets/images/story_panel_3.png"),
]

# Each panel has an array of lines shown one by one
const STORY_LINES : Array = [
	[
		"Long ago, the kingdom of Lumeria was protected by an ancient magical force known as the Three Lumens — crystals that balanced light, shadow, and life.",
		"One night, the Lumens vanished.",
	],
	[
		"Without them, darkness slowly began spreading through the world.",
		"Strange creatures appeared, villages became abandoned, and an unknown force started controlling the shadows themselves.",
	],
	[
		"You play as Aren, a quiet knight trained in the ancient art of Shadow Running — the ability to move unseen through darkness.",
		"Your mission begins when an old villager named Elder Bran reveals the truth:",
		"\"Someone has awakened the Shadow Engine… and it feeds on fear.\" \nTo stop it, you must locate the missing Lumens.",
		"But the deeper you go, the more the shadows start watching you back.",
	]
]

var current_panel : int = 0
var current_line  : int = 0
var can_advance   : bool = false

func _ready() -> void:
	show_panel(0)

func show_panel(index: int) -> void:
	can_advance = false
	arrow.visible = false
	current_line = 0
	panel.texture = PANELS[index]
	story_text.text = ""
	anim.play("fade_in")
	await anim.animation_finished
	show_current_line()

func show_current_line() -> void:
	story_text.text = STORY_LINES[current_panel][current_line]
	can_advance = true
	arrow.visible = true

func _input(event: InputEvent) -> void:
	if not can_advance:
		return
	var clicked = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked = true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			clicked = true
	if clicked:
		advance()

func advance() -> void:
	current_line += 1
	# Still lines left in this panel
	if current_line < STORY_LINES[current_panel].size():
		show_current_line()
		return
	# All lines done — move to next panel
	can_advance = false
	arrow.visible = false
	anim.play("fade_out")
	await anim.animation_finished
	current_panel += 1
	if current_panel >= PANELS.size():
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		show_panel(current_panel)
