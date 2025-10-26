extends Node2D

const SPEED = 60

var direction = 1

@onready var animated_sprite = $AnimatedSprite2D
@export var npc_name: String = "Villager"
@export_multiline var personality: String = "You are a friendly villager in a medieval town."

var player_in_range = false
var player_reference = null

@onready var prompt_label = $PromptLabel
@onready var interaction_area = $InteractionArea

func _ready():
	# Connect the Area2D signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	prompt_label.visible = false

func _on_body_entered(body):
	print("Body entered")
	print(body.name)
	if body.name == "Player":
		player_in_range = true
		player_reference = body
		prompt_label.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		player_reference = null
		prompt_label.visible = false

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("Interact"):
		start_interaction()

func start_interaction():
	print("Interaction started with " + npc_name)
	# We'll connect this to dialogue system later
	var dialogue_ui = get_tree().root.find_child("DialogueUI", true, false)
	if dialogue_ui:
		dialogue_ui.open_dialogue(self)
