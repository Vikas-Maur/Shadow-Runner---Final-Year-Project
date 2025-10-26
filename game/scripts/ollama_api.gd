extends Node

const OLLAMA_URL = "http://127.0.0.1:11434/api/generate"

var active_requests = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func send_message(prompt: String, system_prompt: String, callback: Callable):
	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)
	active_requests.append(http_request)
	
	# Enable threading - this often fixes hanging issues
	http_request.use_threads = true
	http_request.timeout = 30
	
	http_request.request_completed.connect(func(result, response_code, headers, body):
		print("=== SIGNAL FIRED ===")
		_on_request_completed(result, response_code, headers, body, callback, http_request)
	)
	
	var json_data = {
		"model": "phi3",
		"prompt": prompt,
		"system": system_prompt,
		"stream": false
	}
	
	var json_string = JSON.stringify(json_data)
	var headers_array = ["Content-Type: application/json"]
	
	print("=== Initiating request ===")
	
	await get_tree().process_frame
	
	var error = http_request.request(OLLAMA_URL, headers_array, HTTPClient.METHOD_POST, json_string)
	print("Request error code: ", error)
	
	if error != OK:
		print("ERROR: Failed to initiate request: ", error)
		callback.call("Failed to initiate request")
		http_request.queue_free()
		active_requests.erase(http_request)

func _on_request_completed(result, response_code, headers, body, callback, http_request):
	print("=== Request completed ===")
	print("Result: ", result)
	print("Response code: ", response_code)
	print("Body size: ", body.size())
	
	active_requests.erase(http_request)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Error: Request failed with result code: ", result)
		callback.call("Sorry, I couldn't process that.")
		http_request.queue_free()
		return
	
	var body_string = body.get_string_from_utf8()
	print("Response preview: ", body_string.substr(0, 200))
	
	var json = JSON.new()
	var parse_result = json.parse(body_string)
	
	if parse_result == OK:
		var response = json.data
		if response.has("response"):
			callback.call(response["response"])
		else:
			callback.call("Sorry, I couldn't understand that.")
	else:
		print("JSON parse error")
		callback.call("Sorry, there was an error.")
	
	http_request.queue_free()
