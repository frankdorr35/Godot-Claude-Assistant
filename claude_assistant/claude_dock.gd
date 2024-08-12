@tool
extends VBoxContainer

signal send_request(prompt)
signal create_file(content)
signal edit_file(file_path, content)
signal show_settings
signal previous_query
signal next_query

@onready var input_text = $VSplitContainer/InputTextEdit
@onready var output_text = $VSplitContainer/OutputCodeEdit
@onready var send_button = $ButtonContainer/SendButton
@onready var create_file_button = $ButtonContainer/CreateFileButton
@onready var edit_file_button = $ButtonContainer/EditFileButton
@onready var settings_button = $ButtonContainer/SettingsButton
@onready var prev_button = $ButtonContainer/PrevButton
@onready var next_button = $ButtonContainer/NextButton

var highlighter: CodeHighlighter

func _ready():
	if send_button:
		send_button.connect("pressed", Callable(self, "_on_send_button_pressed"))
	if create_file_button:
		create_file_button.connect("pressed", Callable(self, "_on_create_file_button_pressed"))
	if edit_file_button:
		edit_file_button.connect("pressed", Callable(self, "_on_edit_file_button_pressed"))
	if settings_button:
		settings_button.connect("pressed", Callable(self, "_on_settings_button_pressed"))
	if prev_button:
		prev_button.connect("pressed", Callable(self, "_on_prev_button_pressed"))
	if next_button:
		next_button.connect("pressed", Callable(self, "_on_next_button_pressed"))
	
	highlighter = CodeHighlighter.new()
	highlighter.number_color = Color.DARK_ORANGE
	highlighter.symbol_color = Color.DARK_GOLDENROD
	highlighter.function_color = Color.DARK_BLUE
	highlighter.member_variable_color = Color.DARK_GREEN
	
	if output_text:
		output_text.syntax_highlighter = highlighter

func _on_send_button_pressed():
	if input_text:
		emit_signal("send_request", input_text.text)

func _on_create_file_button_pressed():
	if output_text:
		emit_signal("create_file", output_text.text)

func _on_edit_file_button_pressed():
	if output_text:
		emit_signal("edit_file", "res://example.gd", output_text.text)

func _on_settings_button_pressed():
	emit_signal("show_settings")

func _on_prev_button_pressed():
	emit_signal("previous_query")

func _on_next_button_pressed():
	emit_signal("next_query")

func display_response(response):
	if output_text:
		output_text.text = response
		
		if "func " in response or "var " in response:
			set_gdscript_keywords()
		elif "def " in response or "import " in response:
			set_python_keywords()

func set_input_text(text):
	if input_text:
		input_text.text = text

func set_gdscript_keywords():
	highlighter.clear_keywords()
	highlighter.add_keyword_color("func", Color.PURPLE)
	highlighter.add_keyword_color("var", Color.PURPLE)
	highlighter.add_keyword_color("for", Color.PURPLE)
	highlighter.add_keyword_color("if", Color.PURPLE)
	highlighter.add_keyword_color("else", Color.PURPLE)
	highlighter.add_keyword_color("elif", Color.PURPLE)
	highlighter.add_keyword_color("while", Color.PURPLE)
	highlighter.add_keyword_color("match", Color.PURPLE)
	highlighter.add_keyword_color("return", Color.PURPLE)

func set_python_keywords():
	highlighter.clear_keywords()
	highlighter.add_keyword_color("def", Color.PURPLE)
	highlighter.add_keyword_color("class", Color.PURPLE)
	highlighter.add_keyword_color("for", Color.PURPLE)
	highlighter.add_keyword_color("if", Color.PURPLE)
	highlighter.add_keyword_color("else", Color.PURPLE)
	highlighter.add_keyword_color("elif", Color.PURPLE)
	highlighter.add_keyword_color("while", Color.PURPLE)
	highlighter.add_keyword_color("import", Color.PURPLE)
	highlighter.add_keyword_color("from", Color.PURPLE)
