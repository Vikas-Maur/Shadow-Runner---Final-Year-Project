extends Control

const AISettings = preload("res://scripts/ai_settings.gd")
const INTRO_SCENE := "res://scenes/IntroSequence.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const OLLAMA_HOST := "127.0.0.1"
const OLLAMA_PORT := 11434
const OLLAMA_TAGS_ENDPOINT := "/api/tags"
const OLLAMA_TIMEOUT_MS := 1500
const OLLAMA_STATUS_CHECKING := 0
const OLLAMA_STATUS_OFFLINE := 1
const OLLAMA_STATUS_NO_MODELS := 2
const OLLAMA_STATUS_ONLINE := 3

@onready var btn_new_game: TextureButton = $BtnNewGame
@onready var btn_continue: TextureButton = $BtnContinue
@onready var btn_exit: TextureButton = $BtnExit

@onready var ai_status_label: Label = $AISettingsPanel/MarginContainer/VBoxContainer/AIStatusLabel
@onready var model_option_button: OptionButton = $AISettingsPanel/MarginContainer/VBoxContainer/ModelOptionButton
@onready var refresh_ai_button: Button = $AISettingsPanel/MarginContainer/VBoxContainer/RefreshAIButton

@onready var dev_level_panel: Control = $DevLevelPanel
@onready var dev_level_1_button: Button = $DevLevelPanel/MarginContainer/VBoxContainer/DevLevel1Button
@onready var dev_level_2_button: Button = $DevLevelPanel/MarginContainer/VBoxContainer/DevLevel2Button
@onready var dev_level_3_button: Button = $DevLevelPanel/MarginContainer/VBoxContainer/DevLevel3Button
@onready var dev_reset_state_button: Button = $DevLevelPanel/MarginContainer/VBoxContainer/DevResetStateButton

@onready var high_score_label: Label = $HighScoreLabel

var _available_ollama_models: Array[String] = []
var _ollama_status: int = OLLAMA_STATUS_CHECKING
var _is_updating_model_selector: bool = false
var _ollama_status_request_serial: int = 0

func _ready() -> void:
	btn_continue.disabled = not LevelManager.can_continue()
	btn_new_game.pressed.connect(_on_new_game)
	btn_continue.pressed.connect(_on_continue)
	btn_exit.pressed.connect(_on_exit)

	dev_level_panel.visible = LevelManager.are_development_tools_enabled()
	if dev_level_panel.visible:
		dev_level_1_button.pressed.connect(_on_dev_level_pressed.bind(0))
		dev_level_2_button.pressed.connect(_on_dev_level_pressed.bind(1))
		dev_level_3_button.pressed.connect(_on_dev_level_pressed.bind(2))
		dev_reset_state_button.pressed.connect(_on_dev_reset_state_pressed)

	LeaderBoard.load_score()
	if LeaderBoard.top_score > 0:
		high_score_label.text = "High Score - %s" % LeaderBoard.top_score
	else:
		high_score_label.text = "No High Score Yet"

	model_option_button.item_selected.connect(_on_model_selected)
	refresh_ai_button.pressed.connect(_refresh_ollama_status)

	_populate_model_selector()
	_refresh_ai_status_label()
	_refresh_ollama_status()

func _on_new_game() -> void:
	GameData.current_score = 0
	LevelManager.start_new_game()
	get_tree().change_scene_to_file(INTRO_SCENE)

func _on_continue() -> void:
	if not LevelManager.prepare_continue():
		btn_continue.disabled = true
		return

	get_tree().change_scene_to_file(GAME_SCENE)

func _on_exit() -> void:
	get_tree().quit()

func _on_dev_level_pressed(level_index: int) -> void:
	LevelManager.load_level(level_index)

func _on_dev_reset_state_pressed() -> void:
	LevelManager.reset_game_state()
	btn_continue.disabled = not LevelManager.can_continue()

func _populate_model_selector() -> void:
	_is_updating_model_selector = true
	model_option_button.clear()

	var selected_model: String = AISettings.get_selected_model()
	var model_choices: Array[String] = AISettings.get_model_choices(_available_ollama_models)
	var selected_index: int = 0

	for index in range(model_choices.size()):
		var model_name: String = model_choices[index]
		model_option_button.add_item(model_name)
		if model_name == selected_model:
			selected_index = index

	if model_option_button.get_item_count() > 0:
		model_option_button.select(selected_index)

	_is_updating_model_selector = false

func _refresh_ollama_status() -> void:
	_ollama_status_request_serial += 1
	var request_serial: int = _ollama_status_request_serial
	_ollama_status = OLLAMA_STATUS_CHECKING
	_refresh_ai_status_label()
	refresh_ai_button.disabled = true

	var response: Dictionary = await _fetch_ollama_models()
	if request_serial != _ollama_status_request_serial or not is_inside_tree():
		return

	refresh_ai_button.disabled = false
	if not bool(response.get("ok", false)):
		_ollama_status = OLLAMA_STATUS_OFFLINE
		_available_ollama_models.clear()
		_populate_model_selector()
		_refresh_ai_status_label()
		return

	_available_ollama_models.clear()
	var response_models: Array = response.get("models", [])
	for model_name in response_models:
		_available_ollama_models.append(String(model_name))
	_ollama_status = OLLAMA_STATUS_ONLINE if not _available_ollama_models.is_empty() else OLLAMA_STATUS_NO_MODELS
	_populate_model_selector()
	_refresh_ai_status_label()

func _fetch_ollama_models() -> Dictionary:
	var client: HTTPClient = HTTPClient.new()
	var connection_result: Dictionary = await _connect_http_client(client, OLLAMA_TIMEOUT_MS)
	if not bool(connection_result.get("ok", false)):
		return connection_result

	var request_error: int = client.request(HTTPClient.METHOD_GET, OLLAMA_TAGS_ENDPOINT, PackedStringArray(), "")
	if request_error != OK:
		return {
			"ok": false,
			"error": "request_failed"
		}

	var response_result: Dictionary = await _read_http_response(client, OLLAMA_TIMEOUT_MS)
	if not bool(response_result.get("ok", false)):
		return response_result

	var body_text: String = String(response_result.get("body", ""))
	var parsed_body: JSON = JSON.new()
	if parsed_body.parse(body_text) != OK or not (parsed_body.data is Dictionary):
		return {
			"ok": false,
			"error": "invalid_response"
		}

	return {
		"ok": true,
		"models": _extract_model_names(parsed_body.data)
	}

func _connect_http_client(client: HTTPClient, timeout_ms: int) -> Dictionary:
	var connect_error: int = client.connect_to_host(OLLAMA_HOST, OLLAMA_PORT)
	if connect_error != OK:
		return {
			"ok": false,
			"error": "connect_failed"
		}

	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		if Time.get_ticks_msec() > deadline:
			return {
				"ok": false,
				"error": "connect_timeout"
			}

		client.poll()
		await get_tree().process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {
			"ok": false,
			"error": "not_connected"
		}

	return {
		"ok": true
	}

func _read_http_response(client: HTTPClient, timeout_ms: int) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		if Time.get_ticks_msec() > deadline:
			return {
				"ok": false,
				"error": "request_timeout"
			}

		client.poll()
		await get_tree().process_frame

	if client.get_response_code() != 200:
		return {
			"ok": false,
			"error": "http_%s" % client.get_response_code()
		}

	var body: String = ""
	deadline = Time.get_ticks_msec() + timeout_ms
	while client.get_status() == HTTPClient.STATUS_BODY:
		if Time.get_ticks_msec() > deadline:
			return {
				"ok": false,
				"error": "body_timeout"
			}

		client.poll()
		var chunk: PackedByteArray = client.read_response_body_chunk()
		if chunk.is_empty():
			await get_tree().process_frame
			continue

		body += chunk.get_string_from_utf8()

	return {
		"ok": true,
		"body": body
	}

func _extract_model_names(response_data: Dictionary) -> Array[String]:
	var model_names: Array[String] = []
	var models: Array = response_data.get("models", [])
	if not (models is Array):
		return model_names

	for model_entry in models:
		if not (model_entry is Dictionary):
			continue

		var model_data: Dictionary = model_entry as Dictionary
		var model_name: String = String(model_data.get("name", model_data.get("model", ""))).strip_edges()
		if model_name.is_empty():
			continue

		if model_name in model_names:
			continue

		model_names.append(model_name)

	return model_names

func _on_model_selected(index: int) -> void:
	if _is_updating_model_selector:
		return

	AISettings.set_selected_model(model_option_button.get_item_text(index))
	_refresh_ai_status_label()

func _refresh_ai_status_label() -> void:
	var selected_model: String = AISettings.get_selected_model()
	match _ollama_status:
		OLLAMA_STATUS_CHECKING:
			_set_ai_status("Checking Ollama status... Selected model: %s" % selected_model, Color(1.0, 0.95, 0.7, 1.0))
		OLLAMA_STATUS_OFFLINE:
			_set_ai_status("Ollama is not installed or not running. Some AI features might not work. Selected model: %s" % selected_model, Color(1.0, 0.72, 0.72, 1.0))
		OLLAMA_STATUS_NO_MODELS:
			_set_ai_status("Ollama is running, but no models are installed. Some AI features might not work. Selected model: %s" % selected_model, Color(1.0, 0.8, 0.55, 1.0))
		OLLAMA_STATUS_ONLINE:
			if selected_model in _available_ollama_models:
				_set_ai_status("Ollama is online. Selected model: %s" % selected_model, Color(0.75, 1.0, 0.75, 1.0))
			else:
				_set_ai_status("Ollama is online, but %s is not installed locally. The game will fall back to an installed model." % selected_model, Color(1.0, 0.88, 0.62, 1.0))

func _set_ai_status(text: String, font_color: Color) -> void:
	ai_status_label.text = text
	ai_status_label.add_theme_color_override("font_color", font_color)
