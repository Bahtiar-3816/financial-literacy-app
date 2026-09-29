extends Control

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/LabelTitle
@onready var text_label: Label = $Panel/MarginContainer/VBoxContainer/LabelText
@onready var buy_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ButtonBuy
@onready var cancel_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ButtonCancel

signal purchased(goal_id: String)
signal canceled

var goal_id: String = ""

func _ready() -> void:
	visible = false
	buy_button.pressed.connect(_on_buy)
	cancel_button.pressed.connect(_on_cancel)

func open(goal: Dictionary) -> void:
	goal_id = str(goal.id)
	title_label.text = "Ты накопил достаточно!"
	text_label.text = "Купить «%s» за %d монет?" % [goal.title, int(goal.price)]
	visible = true
	
	# анимация появления
	$Panel.modulate.a = 0
	$Panel.scale = Vector2(0.9, 0.9)
	$Panel.pivot_offset = $Panel.size / 2
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property($Panel, "modulate:a", 1.0, 0.25)
	tween.tween_property($Panel, "scale", Vector2(1.0, 1.0), 0.25)

func _on_buy() -> void:
	purchased.emit(goal_id)
	visible = false

func _on_cancel() -> void:
	canceled.emit()
	visible = false
