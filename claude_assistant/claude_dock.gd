@tool
extends VBoxContainer

signal send_request(prompt)
signal create_file(content)
signal edit_file(file_path, content)

@onready var input_text = $VSplitContainer/TextEdit
@onready var send_button = $SendButton
@onready var output_text = $VSplitContainer/CodeEdit
@onready var create_file_button = $CreateFileButton
@onready var edit_file_button = $EditFileButton

var highlighter: CodeHighlighter

func _ready():
	send_button.connect("pressed", Callable(self, "_on_send_button_pressed"))
	create_file_button.connect("pressed", Callable(self, "_on_create_file_button_pressed"))
	edit_file_button.connect("pressed", Callable(self, "_on_edit_file_button_pressed"))
	
	# Setup syntax highlighter
	highlighter = CodeHighlighter.new()
	highlighter.number_color = Color.DARK_ORANGE
	highlighter.symbol_color = Color.DARK_RED
	highlighter.function_color = Color.DARK_BLUE
	highlighter.member_variable_color = Color.DARK_GREEN
	
	output_text.syntax_highlighter = highlighter

func _on_send_button_pressed():
	var prompt = input_text.text
	emit_signal("send_request", prompt)

func _on_create_file_button_pressed():
	emit_signal("create_file", output_text.text)

func _on_edit_file_button_pressed():
	# You might want to add a file selection dialog here
	# For now, we'll just use a hardcoded path as an example
	emit_signal("edit_file", "res://example.gd", output_text.text)

func display_response(response):
	output_text.text = response
	
	# Attempt to detect the language and set appropriate keywords
	if "func " in response or "var " in response:
		set_gdscript_keywords()
	elif "def " in response or "import " in response:
		set_python_keywords()
	# Add more language detection as needed

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
