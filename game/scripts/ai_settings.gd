extends RefCounted

const SAVE_PATH := "user://ai_settings.cfg"
const SECTION := "ollama"
const KEY_MODEL := "selected_model"
const DEFAULT_MODEL := "gemma4:latest"
const COMMON_MODELS := [
	"gemma4:latest",
	"gemma3",
	"llama3.2",
	"qwen2.5",
	"mistral"
]

static func get_selected_model(fallback: String = DEFAULT_MODEL) -> String:
	var config: ConfigFile = ConfigFile.new()
	var load_result: int = config.load(SAVE_PATH)
	if load_result != OK:
		return fallback

	var model_name: String = String(config.get_value(SECTION, KEY_MODEL, fallback)).strip_edges()
	if model_name.is_empty():
		return fallback

	return model_name

static func set_selected_model(model_name: String) -> void:
	var trimmed_model: String = model_name.strip_edges()
	if trimmed_model.is_empty():
		trimmed_model = DEFAULT_MODEL

	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, KEY_MODEL, trimmed_model)
	config.save(SAVE_PATH)

static func get_model_choices(installed_models: Array = []) -> Array[String]:
	var ordered_models: Array[String] = []
	var seen: Dictionary = {}

	for model_name in COMMON_MODELS:
		_append_unique_model(ordered_models, seen, String(model_name))

	for model_name in installed_models:
		_append_unique_model(ordered_models, seen, String(model_name))

	_append_unique_model(ordered_models, seen, get_selected_model())
	return ordered_models

static func _append_unique_model(target: Array[String], seen: Dictionary, model_name: String) -> void:
	var trimmed_model: String = model_name.strip_edges()
	if trimmed_model.is_empty():
		return

	var normalized_key: String = trimmed_model.to_lower()
	if seen.has(normalized_key):
		return

	seen[normalized_key] = true
	target.append(trimmed_model)
