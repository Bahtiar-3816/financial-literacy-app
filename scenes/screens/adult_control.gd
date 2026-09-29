extends Control

@onready var periods_label: Label = $MarginContainer/VBoxContainer/LabelPeriods
@onready var tasks_label: Label   = $MarginContainer/VBoxContainer/LabelTasks
@onready var topics_label: Label  = $MarginContainer/VBoxContainer/LabelTopics
@onready var stage_label: Label   = $MarginContainer/VBoxContainer/LabelStage
@onready var reset_button: Button = $MarginContainer/VBoxContainer/ButtonReset
@onready var back_button: Button  = $MarginContainer/VBoxContainer/ButtonBack

@onready var demo_button: Button = $MarginContainer/VBoxContainer/ButtonDemo
@onready var demo_dialog: Control = $DemoDialog

var hold_time := 0.0
const HOLD_DURATION := 2.0

func _ready() -> void:
	refresh()
	reset_button.button_down.connect(_on_reset_down)
	reset_button.button_up.connect(_on_reset_up)
	back_button.pressed.connect(_on_back_pressed)
	set_process(false)
	demo_button.pressed.connect(_on_demo_button)
	demo_dialog.demo_on.connect(_on_demo_on)
	demo_dialog.demo_off.connect(_on_demo_off)
	demo_dialog.reset_profile.connect(_on_reset)

func _on_demo_button() -> void:
	demo_dialog.open()

func _on_demo_on() -> void:
	var d := ProfileManager.data
	d.meta["demo_mode"] = true
	d.meta["is_test_profile"] = true
	ProfileManager.save_profile()
	_show_message("Демо-режим включён.\nСон — 3 сек, отдых — 5 сек.")

func _on_demo_off() -> void:
	var d := ProfileManager.data
	d.meta["demo_mode"] = false
	ProfileManager.save_profile()
	_show_message("Демо-режим выключен.")

func _on_reset() -> void:
	ProfileManager.reset_profile()
	ScreenManager.go_to("res://scenes/screens/Welcome.tscn")

func refresh() -> void:
	var d := ProfileManager.data
	
	var periods_done: int = int(d.budget.current_period) - 1
	periods_label.text = "Периодов пройдено: %d" % max(periods_done, 0)
	
	var tasks_done: int = d.tasks.completed.size()
	tasks_label.text = "Заданий пройдено: %d" % tasks_done
	
	var topic_progress: Dictionary = d.tasks.topic_progress
	var topics_text := "Пройденные темы: "
	var labels := { "budget": "бюджет", "money": "деньги", "savings": "сбережения", "payments": "платежи" }
	var parts: Array = []
	for key in labels.keys():
		var count := int(topic_progress.get(key, 0))
		parts.append("%s — %d" % [labels[key], count])
	topics_label.text = topics_text + ", ".join(parts)
	
	stage_label.text = "Питомец: стадия %d" % int(d.pet.stage)

func _on_reset_down() -> void:
	hold_time = 0.0
	set_process(true)
	reset_button.text = "Удерживайте..."

func _on_reset_up() -> void:
	set_process(false)
	if hold_time < HOLD_DURATION:
		reset_button.text = "Удерживайте для сброса"

func _process(delta: float) -> void:
	hold_time += delta
	if hold_time >= HOLD_DURATION:
		set_process(false)
		_confirm_reset()

func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Удалить все данные и начать заново?"
	dialog.confirmed.connect(_do_reset)
	add_child(dialog)
	dialog.popup_centered()

func _do_reset() -> void:
	ProfileManager.reset_profile()
	ScreenManager.go_to("res://scenes/screens/Welcome.tscn")

func _on_back_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/Home.tscn")

func _on_demo_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Сбросить профиль\nи начать демонстрационный сценарий?"
	dialog.confirmed.connect(_do_demo)
	add_child(dialog)
	dialog.popup_centered()

func _do_demo() -> void:
	ProfileManager.start_demo_profile()
	ScreenManager.go_to("res://scenes/screens/Welcome.tscn")

func _show_message(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = msg
	dialog.ok_button_text = "Ок"
	add_child(dialog)
	dialog.popup_centered()
