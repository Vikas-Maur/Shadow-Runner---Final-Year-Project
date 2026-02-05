extends CanvasLayer

@onready var chat_panel = $ChatPanel
@onready var npc_name_label = $ChatPanel/VBoxContainer/NPCNameLabel
@onready var chat_history = $ChatPanel/VBoxContainer/ChatHistory
@onready var message_input = $ChatPanel/VBoxContainer/HBoxContainer/MessageInput
@onready var send_button = $ChatPanel/VBoxContainer/HBoxContainer/SendButton

var current_npc = null
var is_active = false
var streaming_response = ""  # Accumulate streaming text

func _ready():
	visible = false
	send_button.pressed.connect(_on_send_pressed)
	message_input.text_submitted.connect(_on_text_submitted)
	
	# Enable BBCode
	chat_history.bbcode_enabled = true

func open_dialogue(npc):
	current_npc = npc
	npc_name_label.text = npc.npc_name
	chat_history.text = ""
	message_input.text = ""
	visible = true
	is_active = true
	message_input.grab_focus()
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
	
	# Send to Ollama with streaming
	request_ai_response(message)

func request_ai_response(user_message):
	# Add NPC name with placeholder
	chat_history.text += "[color=yellow]" + current_npc.npc_name + ":[/color] "
	streaming_response = ""
	
	var ollama_api = get_tree().root.find_child("OllamaAPI", true, false)
	if ollama_api:
		var system_prompt = current_npc.personality + " Your name is " + current_npc.npc_name + "."
		
		# Pass both streaming callback and final callback
		ollama_api.send_message(
			user_message, 
			system_prompt, 
			_on_ai_response_complete,  # Called when done
			_on_ai_response_stream      # Called for each token
		)
	else:
		print("ERROR: OllamaAPI not found!")
		chat_history.text += "[color=red]Error: AI system not available[/color]\n\n"

func _on_ai_response_stream(token: String):
	# Called for each new piece of text (real-time streaming!)
	streaming_response += token
	
	# Update the last line with accumulated response
	var text = chat_history.text
	var last_colon = text.rfind(":[/color] ")
	if last_colon != -1:
		# Replace everything after the last colon with new response
		chat_history.text = text.substr(0, last_colon + 10) + streaming_response
	
	# Auto-scroll to bottom
	chat_history.scroll_to_line(chat_history.get_line_count())

func _on_ai_response_complete(full_response: String):
	# Called when streaming is done
	print("Stream complete, final response length: ", full_response.length())
	
	# Make sure final text is there and add newlines
	var text = chat_history.text
	if not text.ends_with("\n\n"):
		chat_history.text += "\n\n"
	
	streaming_response = ""

func _input(event):
	if is_active and event.is_action_pressed("ui_cancel"):
		close_dialogue()
