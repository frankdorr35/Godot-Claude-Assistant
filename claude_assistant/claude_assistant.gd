@tool
extends EditorPlugin

var dock
var http_request
var api_key = "" # You'll need to set this to your actual API key
var file_dialog: FileDialog

func _enter_tree():
	# Initialize the dock
	dock = preload("res://addons/claude_assistant/claude_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	
	# Connect signals
	dock.connect("send_request", Callable(self, "_on_send_request"))
	dock.connect("create_file", Callable(self, "_on_create_file"))
	dock.connect("edit_file", Callable(self, "_on_edit_file"))
	
	# Initialize HTTP request
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_request_completed"))
	
	# Initialize FileDialog
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	add_child(file_dialog)
	file_dialog.connect("file_selected", Callable(self, "_on_file_selected"))

func _exit_tree():
	# Clean-up of the plugin goes here
	remove_control_from_docks(dock)
	dock.free()
	file_dialog.queue_free()

func _on_send_request(prompt):
	var project_structure = get_project_structure()
	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01"
	]
	var body = JSON.stringify({
		"model": "claude-3-sonnet-20240229",
		"system": "You are an AI assistant helping with Godot game development. Here's the current project structure:\n" + project_structure,
		"messages": [
			{"role": "user", "content": prompt}
		],
		"max_tokens": 1000
	})
	print("API Key (first 5 chars): " + api_key.substr(0, 5))  # Print first 5 chars of API key for verification
	print("Request Body: " + body)  # Print the request body
	http_request.request("https://api.anthropic.com/v1/messages", headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(result, response_code, headers, body):
	print("Response Code: ", response_code)
	print("Headers: ", headers)
	print("Body: ", body.get_string_from_utf8())
	
	if result != HTTPRequest.RESULT_SUCCESS:
		dock.display_response("Error: HTTP Request failed. Error code: " + str(result))
		return
	
	if response_code != 200:
		dock.display_response("Error: Received HTTP " + str(response_code) + " response.")
		return
	
	var json_string = body.get_string_from_utf8()
	var json = JSON.parse_string(json_string)
	if json == null:
		dock.display_response("Error: Unable to parse API response. Raw response:\n" + json_string)
	elif json.has("error"):
		dock.display_response("API Error: " + json.error.message)
	elif json.has("content") and json.content.size() > 0:
		dock.display_response(json.content[0].text)
	else:
		dock.display_response("Error: Unexpected API response structure.")

func get_project_structure():
	var structure = ""
	var dir = DirAccess.open("res://")
	if dir:
		structure = _get_dir_contents(dir, "res://", 0)
	return structure

func _get_dir_contents(dir: DirAccess, path: String, indent: int) -> String:
	var structure = ""
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path + "/" + file_name
			var file_info = ""
			for i in range(indent):
				structure += "  "
			if dir.current_is_dir():
				structure += "[D] " + file_name + "\n"
				var subdir = DirAccess.open(full_path)
				if subdir:
					structure += _get_dir_contents(subdir, full_path, indent + 1)
			else:
				var file = FileAccess.open(full_path, FileAccess.READ)
				if file:
					var file_size = file.get_length()
					var file_content = file.get_as_text()
					file.close()
					
					file_info = " (Size: " + str(file_size) + " bytes)"
					
					if file_name.ends_with(".gd"):
						var script = load(full_path)
						if script:
							file_info += " - GDScript"
							var method_list = script.get_script_method_list()
							file_info += " (" + str(method_list.size()) + " methods)"
					elif file_name.ends_with(".tscn"):
						file_info += " - Scene"
						var scene = load(full_path)
						if scene:
							var node_count = _count_nodes(scene)
							file_info += " (" + str(node_count) + " nodes)"
				
				structure += "[F] " + file_name + file_info + "\n"
		file_name = dir.get_next()
	dir.list_dir_end()
	return structure

func _count_nodes(scene: PackedScene) -> int:
	var instance = scene.instantiate()
	var count = _recursive_count_nodes(instance)
	instance.free()
	return count

func _recursive_count_nodes(node: Node) -> int:
	var count = 1  # Count the current node
	for child in node.get_children():
		count += _recursive_count_nodes(child)
	return count

func _on_create_file(content):
	file_dialog.popup_centered(Vector2(800, 600))
	file_dialog.connect("file_selected", Callable(self, "_on_file_selected").bind(content))

func _on_edit_file(file_path, content):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("File edited successfully: " + file_path)
	else:
		printerr("Failed to open file for editing: " + file_path)

func _on_file_selected(path, content=null):
	if content != null:
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
			print("File created successfully: " + path)
		else:
			printerr("Failed to create file: " + path)
	file_dialog.disconnect("file_selected", Callable(self, "_on_file_selected"))
