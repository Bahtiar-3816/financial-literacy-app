extends Node

var screen_holder: Control
var fade_overlay: ColorRect

const FADE_DURATION := 0.25


func register_holder(holder: Control) -> void:
	screen_holder = holder

func register_fade(overlay: ColorRect) -> void:
	fade_overlay = overlay


func go_to(scene_path: String) -> void:
	if fade_overlay == null:
		# если оверлея нет — просто смена
		_change_scene(scene_path)
		return
	
	# показываем чёрный слой
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_callback(func(): _change_scene(scene_path))
	tween.tween_property(fade_overlay, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func(): fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func _change_scene(scene_path: String) -> void:
	if screen_holder == null:
		push_error("ScreenHolder не зарегистрирован")
		return
	for child in screen_holder.get_children():
		child.queue_free()
	var scene = load(scene_path)
	var instance = scene.instantiate()
	screen_holder.add_child(instance)
