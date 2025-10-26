extends CanvasLayer

@onready var chat_panel = $ChatPanel
@onready var npc_name_label = $ChatPanel/VBoxContainer/NPCNameLabel
@onready var chat_history = $ChatPanel/VBoxContainer/ChatHistory
@onready var message_input = $ChatPanel/VBoxContainer/HBoxContainer/MessageInput
@onready var send_button = $ChatPanel/VBoxContainer/HBoxContainer/SendButton

var current_npc = null
var is_active = false

func _ready():
	# Start hidden
	visible = false
	send_button.pressed.connect(_on_send_pressed)
	message_input.text_submitted.connect(_on_text_submitted)
	
	# CRITICAL: Enable BBCode in RichTextLabel
	chat_history.bbcode_enabled = true

func open_dialogue(npc):
	current_npc = npc
	npc_name_label.text = npc.npc_name
	chat_history.text = ""
	message_input.text = ""
	visible = true
	is_active = true
	message_input.grab_focus()
	
	# Pause the game (optional)
	get_tree().paused = true

func close_dialogue():
	visible = false
	is_active = false
	current_npc = null
	get_tree().paused = false

func _on_send_pressed():
	send_message()

func _on_text_submitted(text):
	send_message()

func send_message():
	var message = message_input.text.strip_edges()
	if message == "":
		return
	
	# Add player message to chat
	chat_history.text += "[color=cyan]You:[/color] " + message + "\n\n"
	message_input.text = ""
	
	# Send to Ollama
	request_ai_response(message)

func request_ai_response(user_message):
	chat_history.text += "[color=yellow]" + current_npc.npc_name + ":[/color] ...\n\n"
	
	# Find OllamaAPI
	var ollama_api = get_tree().root.find_child("OllamaAPI", true, false)
	if ollama_api:
		var system_prompt = current_npc.personality + " Your name is " + current_npc.npc_name + "."
		ollama_api.send_message(user_message, system_prompt, _on_ai_response)
	else:
		print("ERROR: OllamaAPI not found!")
		add_npc_response("[color=red]Error: AI system not available[/color]")

func _on_ai_response(response_text):
	add_npc_response("[color=yellow]" + current_npc.npc_name + ":[/color] " + response_text)

func add_npc_response(response_text):
	# Remove the "..." message
	var text = chat_history.text
	var thinking_pos = text.rfind("...")
	if thinking_pos != -1:
		# Find the start of the line containing "..."
		var line_start = text.rfind("\n", thinking_pos - 1)
		if line_start == -1:
			line_start = 0
		else:
			line_start += 1  # Skip the newline
		
		# Remove from line start to end
		chat_history.text = text.substr(0, line_start)
	
	chat_history.text += response_text + "\n\n"

func _input(event):
	if is_active and event.is_action_pressed("ui_cancel"):
		close_dialogue()
