@tool
extends EditorPlugin

var dock
var http_request
var file_dialog: FileDialog
var settings_dialog: AcceptDialog
var api_key_input: LineEdit
var loading_indicator: ProgressBar
var history: Array = []
var history_index: int = -1

const MAX_TOKENS = 4000
const SETTINGS_PATH = "user://claude_assistant_settings.cfg"

func _enter_tree():
	dock = preload("res://addons/claude_assistant/claude_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	
	dock.connect("send_request", Callable(self, "_on_send_request"))
	dock.connect("create_file", Callable(self, "_on_create_file"))
	dock.connect("edit_file", Callable(self, "_on_edit_file"))
	dock.connect("show_settings", Callable(self, "_on_show_settings"))
	dock.connect("previous_query", Callable(self, "_on_previous_query"))
	dock.connect("next_query", Callable(self, "_on_next_query"))
	
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_request_completed"))
	
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	add_child(file_dialog)
	file_dialog.connect("file_selected", Callable(self, "_on_file_selected"))
	
	_setup_settings_dialog()
	_setup_loading_indicator()
	_load_settings()

func _exit_tree():
	if dock:
		remove_control_from_docks(dock)
		dock.free()
	if file_dialog:
		file_dialog.queue_free()
	if settings_dialog:
		settings_dialog.queue_free()
	if http_request:
		http_request.queue_free()

func _setup_settings_dialog():
	settings_dialog = AcceptDialog.new()
	settings_dialog.title = "Claude Assistant Settings"
	var vbox = VBoxContainer.new()
	settings_dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "API Key:"
	vbox.add_child(label)
	
	api_key_input = LineEdit.new()
	api_key_input.secret = true
	vbox.add_child(api_key_input)
	
	settings_dialog.connect("confirmed", Callable(self, "_on_settings_confirmed"))
	add_child(settings_dialog)

func _setup_loading_indicator():
	loading_indicator = ProgressBar.new()
	loading_indicator.modulate = Color(1, 1, 1, 0.8)
	loading_indicator.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	loading_indicator.hide()
	dock.add_child(loading_indicator)

func _load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err == OK:
		var saved_key = config.get_value("settings", "api_key", "")
		api_key_input.text = saved_key

func _save_settings():
	var config = ConfigFile.new()
	config.set_value("settings", "api_key", api_key_input.text)
	config.save(SETTINGS_PATH)

func _on_show_settings():
	settings_dialog.popup_centered(Vector2(300, 100))

func _on_settings_confirmed():
	_save_settings()

func _on_send_request(prompt):
	if api_key_input.text.is_empty():
		dock.display_response("Error: API key not set. Please set it in the settings.")
		return
	
	var project_structure = get_project_structure()
	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + api_key_input.text,
		"anthropic-version: 2023-06-01"
	]
	var body = JSON.stringify({
		"model": "claude-3-sonnet-20240229",
		"system": "You are an AI assistant helping with Godot game development. Here's the current project structure:\n" + project_structure,
		"messages": [
			{"role": "user", "content": prompt}
		],
		"max_tokens": MAX_TOKENS
	})
	http_request.request("https://api.anthropic.com/v1/messages", headers, HTTPClient.METHOD_POST, body)
	
	loading_indicator.show()
	loading_indicator.value = 0
	var tween = create_tween()
	tween.tween_property(loading_indicator, "value", 100, 5.0)
	
	history.append({"prompt": prompt, "response": ""})
	history_index = history.size() - 1

func _on_request_completed(result, response_code, headers, body):
	loading_indicator.hide()
	
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
		var response = json.content[0].text
		dock.display_response(response)
		history[history_index]["response"] = response
	else:
		dock.display_response("Error: Unexpected API response structure.")

func _on_previous_query():
	if history_index > 0:
		history_index -= 1
		_display_history_item()

func _on_next_query():
	if history_index < history.size() - 1:
		history_index += 1
		_display_history_item()

func _display_history_item():
	var item = history[history_index]
	dock.set_input_text(item["prompt"])
	dock.display_response(item["response"])

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
