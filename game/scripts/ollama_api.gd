extends Node

const OLLAMA_HOST := "127.0.0.1"
const OLLAMA_PORT := 11434
const CHAT_ENDPOINT := "/api/chat"
const DEFAULT_MODEL := "gemma2:9b"
const DEFAULT_TIMEOUT_MS := 30000
const DEFAULT_STREAM_TOKENS := 500
const DEFAULT_STRUCTURED_TOKENS := 160

var _request_serial: int = 0
var _open_stream_logs: Dictionary = {}

func send_message(
	prompt: String,
	system_prompt: String,
	final_callback: Callable,
	stream_callback: Callable = Callable(),
	request_options: Dictionary = {}
) -> void:
	_send_streaming_request(prompt, system_prompt, final_callback, stream_callback, request_options)

func send_structured_message(
	prompt: String,
	system_prompt: String,
	json_schema: Dictionary,
	final_callback: Callable,
	request_options: Dictionary = {}
) -> void:
	_send_structured_request(prompt, system_prompt, json_schema, final_callback, request_options)

func _send_streaming_request(
	prompt: String,
	system_prompt: String,
	final_callback: Callable,
	stream_callback: Callable,
	request_options: Dictionary
) -> void:
	var request_id := _next_request_id()
	var client := HTTPClient.new()
	var timeout_ms := int(request_options.get("timeout_ms", DEFAULT_TIMEOUT_MS))
	var connection_result := await _connect_client(client, timeout_ms)
	if not bool(connection_result.get("ok", false)):
		_log_request_failure(request_id, "Connection failed")
		_call_if_valid(final_callback, "Connection failed")
		return

	var payload := _build_payload(prompt, system_prompt, request_options, true, {})
	_log_outgoing_messages(request_id, payload, "stream")
	var request_error := client.request(
		HTTPClient.METHOD_POST,
		CHAT_ENDPOINT,
		_build_headers(payload),
		JSON.stringify(payload)
	)
	if request_error != OK:
		_log_request_failure(request_id, "Request failed")
		_call_if_valid(final_callback, "Request failed")
		return

	var response_result := await _read_streaming_response(client, stream_callback, timeout_ms, request_id)
	_finish_stream_log(request_id)
	if not bool(response_result.get("ok", false)):
		_log_request_failure(request_id, String(response_result.get("error", "Request error")))
		_call_if_valid(final_callback, String(response_result.get("error", "Request error")))
		return

	_call_if_valid(final_callback, String(response_result.get("text", "")))

func _send_structured_request(
	prompt: String,
	system_prompt: String,
	json_schema: Dictionary,
	final_callback: Callable,
	request_options: Dictionary
) -> void:
	var request_id := _next_request_id()
	var client := HTTPClient.new()
	var timeout_ms := int(request_options.get("timeout_ms", DEFAULT_TIMEOUT_MS))
	var connection_result := await _connect_client(client, timeout_ms)
	if not bool(connection_result.get("ok", false)):
		_log_request_failure(request_id, "connection_failed")
		_call_if_valid(final_callback, {
			"ok": false,
			"error": "connection_failed",
			"text": "",
			"json": {}
		})
		return

	var payload := _build_payload(prompt, system_prompt, request_options, false, json_schema)
	_log_outgoing_messages(request_id, payload, "structured")
	var request_error := client.request(
		HTTPClient.METHOD_POST,
		CHAT_ENDPOINT,
		_build_headers(payload),
		JSON.stringify(payload)
	)
	if request_error != OK:
		_log_request_failure(request_id, "request_failed")
		_call_if_valid(final_callback, {
			"ok": false,
			"error": "request_failed",
			"text": "",
			"json": {}
		})
		return

	var response_result := await _read_full_response(client, timeout_ms)
	if not bool(response_result.get("ok", false)):
		_log_request_failure(request_id, String(response_result.get("error", "request_error")))
		_call_if_valid(final_callback, {
			"ok": false,
			"error": String(response_result.get("error", "request_error")),
			"text": String(response_result.get("body", "")),
			"json": {}
		})
		return

	var body_text := String(response_result.get("body", ""))
	var parsed_body := JSON.new()
	if parsed_body.parse(body_text) != OK or not (parsed_body.data is Dictionary):
		_log_request_failure(request_id, "invalid_response_json")
		_call_if_valid(final_callback, {
			"ok": false,
			"error": "invalid_response_json",
			"text": body_text,
			"json": {}
		})
		return

	var response_data: Dictionary = parsed_body.data
	if response_data.has("error"):
		_log_request_failure(request_id, String(response_data.get("error", "server_error")))
		_call_if_valid(final_callback, {
			"ok": false,
			"error": String(response_data.get("error", "server_error")),
			"text": body_text,
			"json": {}
		})
		return

	var content := ""
	if response_data.has("message") and response_data["message"] is Dictionary:
		content = String((response_data["message"] as Dictionary).get("content", ""))

	var json_payload := _extract_json_payload(content)
	if json_payload.is_empty():
		_log_assistant_message(request_id, content, "structured-invalid")
		_log_request_failure(request_id, "invalid_structured_payload")
		_call_if_valid(final_callback, {
			"ok": false,
			"error": "invalid_structured_payload",
			"text": content,
			"json": {}
		})
		return

	_log_assistant_message(request_id, content, "structured")
	_call_if_valid(final_callback, {
		"ok": true,
		"error": "",
		"text": content,
		"json": json_payload
	})

func _build_payload(
	prompt: String,
	system_prompt: String,
	request_options: Dictionary,
	stream_response: bool,
	response_format: Dictionary
) -> Dictionary:
	var is_structured_request := not response_format.is_empty()
	var model_name := String(request_options.get("model", DEFAULT_MODEL))
	var max_tokens := int(request_options.get(
		"num_predict",
		DEFAULT_STRUCTURED_TOKENS if is_structured_request else DEFAULT_STREAM_TOKENS
	))

	var payload := {
		"model": model_name,
		"stream": stream_response,
		"messages": [
			{
				"role": "system",
				"content": system_prompt
			},
			{
				"role": "user",
				"content": prompt
			}
		],
		"options": {
			"num_predict": max_tokens,
			"temperature": float(request_options.get("temperature", 0.7)),
			"top_p": float(request_options.get("top_p", 0.9))
		}
	}

	if request_options.has("keep_alive"):
		payload["keep_alive"] = request_options["keep_alive"]

	if is_structured_request:
		payload["format"] = response_format

	return payload

func _build_headers(payload: Dictionary) -> PackedStringArray:
	var json_bytes := JSON.stringify(payload).to_utf8_buffer()
	return PackedStringArray([
		"Content-Type: application/json",
		"Content-Length: " + str(json_bytes.size())
	])

func _connect_client(client: HTTPClient, timeout_ms: int) -> Dictionary:
	var error := client.connect_to_host(OLLAMA_HOST, OLLAMA_PORT)
	if error != OK:
		return {
			"ok": false,
			"error": "connect_failed"
		}

	var deadline := Time.get_ticks_msec() + timeout_ms
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		if Time.get_ticks_msec() > deadline:
			return {
				"ok": false,
				"error": "connect_timeout"
		}

		client.poll()
		if not await _await_next_frame():
			return {
				"ok": false,
				"error": "request_cancelled"
			}

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {
			"ok": false,
			"error": "not_connected"
		}

	return {
		"ok": true
	}

func _read_streaming_response(client: HTTPClient, stream_callback: Callable, timeout_ms: int, request_id: int) -> Dictionary:
	var start_result := await _await_response_start(client, timeout_ms)
	if not bool(start_result.get("ok", false)):
		return start_result

	var buffer := ""
	var full_response := ""
	var deadline := Time.get_ticks_msec() + timeout_ms

	while client.get_status() == HTTPClient.STATUS_BODY:
		if Time.get_ticks_msec() > deadline:
			return {
				"ok": false,
				"error": "body_timeout"
			}

		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			if not await _await_next_frame():
				return {
					"ok": false,
					"error": "request_cancelled"
				}
			continue

		buffer += chunk.get_string_from_utf8()
		while "\n" in buffer:
			var newline_index := buffer.find("\n")
			var line := buffer.substr(0, newline_index).strip_edges()
			buffer = buffer.substr(newline_index + 1)

			if line.is_empty():
				continue

			var json := JSON.new()
			if json.parse(line) != OK or not (json.data is Dictionary):
				continue

			var packet: Dictionary = json.data
			if packet.has("message") and packet["message"] is Dictionary:
				var token := String((packet["message"] as Dictionary).get("content", ""))
				if not token.is_empty():
					full_response += token
					_log_stream_token(request_id, token)
					_call_if_valid(stream_callback, token)

			if bool(packet.get("done", false)):
				return {
					"ok": true,
					"text": full_response
				}

	if not full_response.is_empty():
		return {
			"ok": true,
			"text": full_response
		}

	return {
		"ok": false,
		"error": "empty_response"
	}

func _read_full_response(client: HTTPClient, timeout_ms: int) -> Dictionary:
	var start_result := await _await_response_start(client, timeout_ms)
	if not bool(start_result.get("ok", false)):
		return start_result
	return await _drain_response_body(client, timeout_ms)

func _await_response_start(client: HTTPClient, timeout_ms: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		if Time.get_ticks_msec() > deadline:
			return {
				"ok": false,
				"error": "request_timeout"
		}

		client.poll()
		if not await _await_next_frame():
			return {
				"ok": false,
				"error": "request_cancelled"
			}

	var status := client.get_status()
	if status != HTTPClient.STATUS_BODY and status != HTTPClient.STATUS_CONNECTED:
		return {
			"ok": false,
			"error": "bad_status"
		}

	if client.get_response_code() != 200:
		var error_response := await _drain_response_body(client, timeout_ms)
		return {
			"ok": false,
			"error": "http_%s" % client.get_response_code(),
			"body": String(error_response.get("body", ""))
		}

	return {
		"ok": true
	}

func _drain_response_body(client: HTTPClient, timeout_ms: int) -> Dictionary:
	var body := ""
	var deadline := Time.get_ticks_msec() + timeout_ms
	while client.get_status() == HTTPClient.STATUS_BODY:
		if Time.get_ticks_msec() > deadline:
			return {
				"ok": false,
				"error": "body_timeout",
				"body": body
			}

		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			if not await _await_next_frame():
				return {
					"ok": false,
					"error": "request_cancelled",
					"body": body
				}
			continue

		body += chunk.get_string_from_utf8()

	return {
		"ok": true,
		"body": body
	}

func _await_next_frame() -> bool:
	if not is_inside_tree():
		return false

	var tree: SceneTree = get_tree()
	if tree == null:
		return false

	await tree.process_frame
	return is_inside_tree() and get_tree() != null

func _extract_json_payload(content: String) -> Dictionary:
	var stripped := content.strip_edges()
	if stripped.is_empty():
		return {}

	var direct_parse := JSON.new()
	if direct_parse.parse(stripped) == OK and direct_parse.data is Dictionary:
		return direct_parse.data

	var first_brace := stripped.find("{")
	var last_brace := stripped.rfind("}")
	if first_brace == -1 or last_brace == -1 or last_brace < first_brace:
		return {}

	var candidate := stripped.substr(first_brace, last_brace - first_brace + 1)
	var extracted_parse := JSON.new()
	if extracted_parse.parse(candidate) == OK and extracted_parse.data is Dictionary:
		return extracted_parse.data

	return {}

func _call_if_valid(callback: Callable, payload: Variant) -> void:
	if callback.is_valid():
		callback.call(payload)

func _next_request_id() -> int:
	_request_serial += 1
	return _request_serial

func _log_outgoing_messages(request_id: int, payload: Dictionary, request_kind: String) -> void:
	print("[Ollama][#", request_id, "][", request_kind, "] model=", String(payload.get("model", DEFAULT_MODEL)))
	var messages = payload.get("messages", [])
	if not (messages is Array):
		return

	for index in range((messages as Array).size()):
		var message = (messages as Array)[index]
		if not (message is Dictionary):
			continue

		var role := String((message as Dictionary).get("role", "unknown"))
		var content := String((message as Dictionary).get("content", "")).strip_edges()
		print("[Ollama][#", request_id, "][out][", role, "][", index, "] ", content)

func _log_assistant_message(request_id: int, content: String, response_kind: String) -> void:
	print("[Ollama][#", request_id, "][in][assistant][", response_kind, "] ", content.strip_edges())

func _log_stream_token(request_id: int, token: String) -> void:
	if token.is_empty():
		return

	if not bool(_open_stream_logs.get(request_id, false)):
		_open_stream_logs[request_id] = true
		printraw("[Ollama][#%s][in][assistant][stream] " % request_id)

	printraw(token)

func _log_request_failure(request_id: int, error_text: String) -> void:
	print("[Ollama][#", request_id, "][error] ", error_text)

func _finish_stream_log(request_id: int) -> void:
	if not bool(_open_stream_logs.get(request_id, false)):
		return

	_open_stream_logs.erase(request_id)
	print("")
