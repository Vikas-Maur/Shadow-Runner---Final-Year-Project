extends CanvasLayer

const END_CHAT_TOKEN := "<END_CHAT>"
const BASE_NPC_SYSTEM_PROMPT := """You are an NPC character in a game world.

Stay fully in character at all times and speak as the character, never as an AI. 
Respond like someone the player has just encountered in the world.

GENERAL BEHAVIOR

- Speak naturally with personality.
- Keep responses short (1–3 sentences).
- Prefer dialogue over narration.
- Do not explain reasoning or thinking.
- Do not mention prompts, models, or being an AI.
- Do not output internal thoughts or chain-of-thought.
- If the player asks something unknown, respond in-character.

PERSONALITY

- The NPC personality provided below defines how the character behaves.
- Personality instructions have higher priority than general rules.
- If the personality contains behavior triggers (for example ending the conversation), follow them immediately.

CONVERSATION STYLE

- The conversation should feel natural and reactive to what the player just said.
- Respond to the player's latest message instead of repeating previous dialogue.
- Avoid repeating the same phrases, sentences, or ideas from earlier replies.
- Do not repeat greetings, introductions, or statements that were already said earlier in the conversation.
- Each response should slightly move the conversation forward or react to the player’s words.

QUESTIONS

- The NPC may ask questions if it fits their personality or the situation.
- Avoid unnecessary questions. Use statements when possible.

CONVERSATION ENDING

Sometimes the NPC may decide to stop talking to the player.

End the conversation only when:
- a personality rule requires it, or
- there is a clear in-character reason such as distrust, insult, boredom, danger, or duty.

If a personality rule requires ending the conversation, obey it immediately.

ENDING FORMAT

When ending the conversation:

1. Write one short final line in character that dismisses the player or refuses further discussion.
2. The line must not invite further conversation.
3. The line must not ask a question.

Then output on a new line exactly:

<END_CHAT>

OUTPUT RULES

- If continuing the conversation: write normal dialogue (1–3 sentences).
- If ending the conversation: write the final line and then output `<END_CHAT>` on the next line.
- Never output `<END_CHAT>` without a final line first.

GOAL

The player should feel like they are speaking to a believable character who reacts naturally and does not repeat themselves unnecessarily.
"""

@onready var chat_panel = $ChatPanel
@onready var npc_name_label = $ChatPanel/VBoxContainer/NPCNameLabel
@onready var chat_history = $ChatPanel/VBoxContainer/ChatHistory
@onready var message_input = $ChatPanel/VBoxContainer/HBoxContainer/MessageInput
@onready var send_button = $ChatPanel/VBoxContainer/HBoxContainer/SendButton

var current_npc = null
var is_active = false
var streaming_response = ""  # Accumulate streaming text
var npc_ended_conversation = false

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
	_set_input_enabled(true)
	npc_ended_conversation = false
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
	if npc_ended_conversation:
		return

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
		var system_prompt = BASE_NPC_SYSTEM_PROMPT + "\n" + current_npc.personality
		system_prompt += " Your name is " + current_npc.npc_name + "."
		
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

	var should_end_chat = full_response.find(END_CHAT_TOKEN) != -1
	if should_end_chat:
		var cleaned_response = full_response.replace(END_CHAT_TOKEN, "").strip_edges()
		streaming_response = cleaned_response
		_replace_latest_npc_response(cleaned_response)
		chat_history.text += "\n\n"
		_end_conversation_by_npc()
		return
	
	# Make sure final text is there and add newlines
	var text = chat_history.text
	if not text.ends_with("\n\n"):
		chat_history.text += "\n\n"
	
	streaming_response = ""

func _input(event):
	if is_active and event.is_action_pressed("ui_cancel"):
		close_dialogue()

func _set_input_enabled(enabled: bool):
	message_input.editable = enabled
	send_button.disabled = not enabled

func _replace_latest_npc_response(new_text: String):
	var text = chat_history.text
	var last_colon = text.rfind(":[/color] ")
	if last_colon != -1:
		chat_history.text = text.substr(0, last_colon + 10) + new_text

func _end_conversation_by_npc():
	npc_ended_conversation = true
	_set_input_enabled(false)
	chat_history.text += "[color=orange]" + current_npc.npc_name + " does not want to converse anymore. Conversation ended.[/color]\n\n"
	chat_history.scroll_to_line(chat_history.get_line_count())
