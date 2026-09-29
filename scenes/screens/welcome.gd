extends Control
@onready var demo_hint: Label = $MarginContainer/VBoxContainer/LabelDemo

func _ready() -> void:
	if ProfileManager.data.meta.demo_mode:
		demo_hint.text = "Демо-режим: пройдите сценарий подряд"
		demo_hint.visible = true
	else:
		demo_hint.visible = false

func _on_button_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/CreatePet.tscn")
