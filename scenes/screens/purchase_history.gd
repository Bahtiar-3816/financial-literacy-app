extends Control

@onready var history_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/HistoryList
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonClose

func  _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_build_history()
	visible = false

func open() -> void:
	visible = true
	_build_history()
	
func _build_history() -> void:
	for child in history_list.get_children():
		child.queue_free()
	
	var d := ProfileManager.data
	var history: Array = d.purchases.history
	var today: Array = d.purchases.current_period
	var today_num: int = int(d.budget.current_period)
	
	# сегодняшний день (текущий период)
	if today.size() > 0:
		_add_day_entry({ "day": today_num, "items": today, "is_today": true })
	
	# прошедшие дни — в обратном порядке, чтобы свежие были сверху
	var reversed_history: Array = history.duplicate()
	reversed_history.reverse()
	for entry in reversed_history:
		_add_day_entry(entry)
	
	if today.is_empty() and history.is_empty():
		var empty := Label.new()
		empty.text = "Пока ничего не куплено."
		empty.modulate = Color(0.7, 0.7, 0.7)
		history_list.add_child(empty)

func _add_day_entry(entry: Dictionary) -> void:
	var day: int = int(entry.get("day", 0))
	var items: Array = entry.get("items", [])
	var is_today: bool = bool(entry.get("is_today", false))
	
	# заголовок дня
	var day_label := Label.new()
	day_label.text = "День %d%s" % [day, " сегодня" if is_today else ""]
	day_label.add_theme_font_size_override("font_size", 16)
	day_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	history_list.add_child(day_label)
	
	# список товаров
	if items.is_empty():
		var none := Label.new()
		none.text = "   ничего не куплено"
		none.modulate = Color(0.6, 0.6, 0.6)
		history_list.add_child(none)
	else:
		for item in items:
			var line := Label.new()
			line.text = "   • %s — %d 💰" % [_get_title(item.item_id), int(item.price)]
			line.autowrap_mode = TextServer.AUTOWRAP_OFF
			line.custom_minimum_size = Vector2(280, 0)
			history_list.add_child(line)
	
	# разделитель
	var sep := HSeparator.new()
	history_list.add_child(sep)

func _get_title(item_id: String) -> String:
	var f := FileAccess.open("res://data/items.json", FileAccess.READ)
	var catalog: Array = JSON.parse_string(f.get_as_text())
	f.close()
	for it in catalog:
		if it.id == item_id:
			return it.title
	return item_id

func _on_close_pressed() -> void:
	visible = false

#
