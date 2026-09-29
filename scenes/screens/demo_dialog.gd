extends Control

@onready var on_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonOn
@onready var off_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonOff
@onready var reset_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonReset
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonClose

signal demo_on
signal demo_off
signal reset_profile

func _ready() -> void:
	visible = false
	on_button.pressed.connect(_on_on)
	off_button.pressed.connect(_on_off)
	reset_button.pressed.connect(_on_reset)
	close_button.pressed.connect(_close)

func open() -> void:
	visible = true
	$Panel.modulate.a = 0
	$Panel.scale = Vector2(0.9, 0.9)
	$Panel.pivot_offset = $Panel.size / 2
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property($Panel, "modulate:a", 1.0, 0.2)
	tween.tween_property($Panel, "scale", Vector2(1.0, 1.0), 0.2)

func _close() -> void:
	visible = false

func _on_on() -> void:
	demo_on.emit()
	_close()

func _on_off() -> void:
	demo_off.emit()
	_close()

func _on_reset() -> void:
	# подтверждение сброса
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Сбросить весь профиль?\nЭто удалит все данные."
	dialog.confirmed.connect(func():
		reset_profile.emit()
		_close()
	)
	add_child(dialog)
	dialog.popup_centered()
