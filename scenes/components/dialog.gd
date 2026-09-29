extends Control

@onready var question_label: Label = $Panel/MarginContainer/VBoxContainer/LabelQuestion
@onready var options_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/OptionsList
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonClose

var current_dialog: Dictionary = {}

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	close_button.visible = false
	visible = false

func open(dialog_id: String) -> void:
	var f := FileAccess.open("res://data/dialogs.json", FileAccess.READ)
	var all: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	
	if not all.has(dialog_id):
		return
	
	current_dialog = all[dialog_id]
	visible = true
	_show_question()

func _show_question() -> void:
	question_label.text = current_dialog.greeting
	for child in options_list.get_children():
		child.queue_free()
	
	close_button.visible = false
	
	for option in current_dialog.options:
		var btn := Button.new()
		btn.text = option.text
		btn.custom_minimum_size = Vector2(0, 48)
		btn.pressed.connect(_on_option_pressed.bind(option))
		options_list.add_child(btn)

func _on_option_pressed(option: Dictionary) -> void:
	# если это "Мне всё понятно" или ответ пустой — закрываем
	if option.answer == "":
		_on_close_pressed()
		return
	
	# показываем ответ
	question_label.text = option.answer
	for child in options_list.get_children():
		child.queue_free()
	
	close_button.visible = true

func _on_close_pressed() -> void:
	visible = false
