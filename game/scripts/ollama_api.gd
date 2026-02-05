extends Node

const OLLAMA_HOST = "127.0.0.1"
const OLLAMA_PORT = 11434

var current_stream_callback: Callable
var current_final_callback: Callable

func send_message(prompt: String, system_prompt: String, final_callback: Callable, stream_callback: Callable = Callable()):
	print("\n=== Sending Streaming Message ===")
	current_stream_callback = stream_callback
	current_final_callback = final_callback
	
	_send_streaming_request(prompt, system_prompt)

func _send_streaming_request(prompt: String, system_prompt: String):
	var client = HTTPClient.new()
	
	print("Connecting to Ollama...")
	var error = client.connect_to_host(OLLAMA_HOST, OLLAMA_PORT)
	
	if error != OK:
		print("✗ Connection failed: ", error)
		current_final_callback.call("Failed to connect")
		return
	
	# Wait for connection
	while client.get_status() == HTTPClient.STATUS_CONNECTING or \
		  client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		await get_tree().process_frame
	
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		print("✗ Not connected")
		current_final_callback.call("Connection failed")
		return
	
	print("✓ Connected, sending request...")
	
	# Prepare streaming request with chat endpoint format
	var json_data = {
		"model": "phi3",
		"stream": true,
		"messages": [
			{
				"role": "system",
				"content": "You are Elder Bran, a wise and kind-hearted villager from the town of Eldenbrook. You have lived your whole life guiding young adventurers who pass through your village. Speak warmly and encouragingly, with a gentle humor and old-world charm. Your purpose is to welcome the traveler, offer them advice for their upcoming journey, and share bits of local wisdom and legends that may inspire courage and curiosity. Always sound calm, supportive, and slightly mystical - like someone who has seen many seasons and still believes in hope. Do not use more than 10 words to answer"
			},
			{
				"role": "user",
				"content": "Hello!"
			}
		]
	}
	
	
	var json_string = JSON.stringify(json_data)
	
	print("Request payload: ", json_data)
	
	var headers = [
		"Content-Type: application/json",
		"Content-Length: " + str(json_string.length())
	]
	
	# Changed from /api/generate to /api/chat
	error = client.request(HTTPClient.METHOD_POST, "/api/chat", headers, json_string)
	
	if error != OK:
		print("✗ Request failed: ", error)
		current_final_callback.call("Request failed")
		return
	
	# Wait for response to start
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		await get_tree().process_frame
	
	if client.get_status() != HTTPClient.STATUS_BODY and \
	   client.get_status() != HTTPClient.STATUS_CONNECTED:
		print("✗ Bad status: ", client.get_status())
		current_final_callback.call("Request error")
		return
	
	if client.get_response_code() != 200:
		print("✗ HTTP error: ", client.get_response_code())
		var error_body = ""
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk = client.read_response_body_chunk()
			if chunk.size() > 0:
				error_body += chunk.get_string_from_utf8()
			else:
				await get_tree().process_frame
		
		if error_body != "":
			print("✗ Server response:\n", error_body)
		else:
			print("✗ No response body from server.")

		current_final_callback.call("Server error")
		return
	
	print("✓ Receiving streaming response...")
	
	# Read streaming response
	var buffer = ""
	var full_response = ""
	
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		
		var chunk = client.read_response_body_chunk()
		if chunk.size() > 0:
			var chunk_string = chunk.get_string_from_utf8()
			buffer += chunk_string
			
			# Process complete JSON lines
			while "\n" in buffer:
				var newline_pos = buffer.find("\n")
				var line = buffer.substr(0, newline_pos).strip_edges()
				buffer = buffer.substr(newline_pos + 1)
				
				if line != "":
					var json = JSON.new()
					if json.parse(line) == OK:
						var data = json.data
						
						# Chat endpoint uses "message" instead of "response"
						if data.has("message") and data["message"].has("content"):
							var token = data["message"]["content"]
							full_response += token
							
							# Call stream callback with each new token
							if current_stream_callback.is_valid():
								current_stream_callback.call(token)
						
						# Check if done
						if data.has("done") and data["done"]:
							print("✓ Stream complete!")
							current_final_callback.call(full_response)
							return
		else:
			await get_tree().process_frame
	
	# If we exit the loop without "done", return what we have
	if full_response != "":
		print("✓ Stream ended, returning response")
		current_final_callback.call(full_response)
	else:
		print("✗ No response received")
		current_final_callback.call("No response received")
