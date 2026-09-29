extends Control

@onready var balance_label: Label = $MarginContainer/VBoxContainer/TopBar/LabelBalance
@onready var energy_label: Label = $MarginContainer/VBoxContainer/TopBar/LabelEnergy
@onready var task_list: VBoxContainer = $MarginContainer/VBoxContainer/ListView/ScrollContainer/TaskList
@onready var back_button: Button = $MarginContainer/VBoxContainer/ButtonBack

var chapters: Array = []
var task_order: Array = []

func _ready() -> void:
	load_tasks()
	load_task_order()
	build_list()
	update_topbar()
	back_button.pressed.connect(_on_back_pressed)

func load_tasks() -> void:
	var f := FileAccess.open("res://data/tasks.json", FileAccess.READ)
	chapters = JSON.parse_string(f.get_as_text())
	f.close()

func load_task_order() -> void:
	var f := FileAccess.open("res://data/task_order.json", FileAccess.READ)
	task_order = JSON.parse_string(f.get_as_text())
	f.close()

func is_task_locked(task_id: String) -> bool:
	var idx: int = task_order.find(task_id)
	if idx <= 0:
		return false    # первое задание или не найдено — не блокируем
	
	var prev_id: String = task_order[idx - 1]
	
	# проверяем, что предыдущее задание пройдено
	for entry in ProfileManager.data.tasks.completed:
		if str(entry.get("task_id", "")) == prev_id:
			return false    # предыдущее пройдено → текущее открыто
	
	return true    # предыдущее не пройдено → блокируем

func build_list() -> void:
	for child in task_list.get_children():
		child.queue_free()
	
	var completed_ids: Array = []
	for entry in ProfileManager.data.tasks.completed:
		completed_ids.append(entry.task_id)
	
	var energy := int(ProfileManager.data.pet.state.energy)
	
	for chapter in chapters:
		# заголовок главы
		var chapter_label := Label.new()
		chapter_label.text = chapter.title
		chapter_label.add_theme_font_size_override("font_size", 18)
		chapter_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1))
		task_list.add_child(chapter_label)
		
		# задания главы
		for t in chapter.tasks:
			var cost := int(t.get("energy", 0))
			var reward := int(t.get("reward", 0))
			var is_done: bool = t.id in completed_ids
			var locked: bool = is_task_locked(t.id)
			
			var btn := Button.new()
			if locked:
					btn.text = "🔒 %s" % t.title
			elif is_done:
				btn.text = "   ✓ %s \n -⚡%d" % [t.title, cost]
			else:
				btn.text = "   %s \n -⚡%d   +💰%d" % [t.title, cost, reward]
				btn.custom_minimum_size = Vector2(0, 56)
				
			if locked:
				btn.pressed.connect(_on_locked_pressed.bind(t))
			elif energy < cost:
				btn.disabled = true
			else:
				btn.pressed.connect(_on_task_selected.bind(t))
			
			task_list.add_child(btn)

func _on_locked_pressed(task: Dictionary) -> void:
	_show_message("Сначала пройди предыдущее задание.")

func _on_task_selected(task: Dictionary) -> void:
	var cost := int(task.get("energy", 0))
	var reward := int(task.get("reward", 0))
	var energy := int(ProfileManager.data.pet.state.energy)
	if energy < cost:
		_show_message("Питомец устал. Ему нужно отдохнуть.")
		return
	
	var is_done := false
	for entry in ProfileManager.data.tasks.completed:
		if entry.task_id == task.id:
			is_done = true
			break
	
	var text := "Задание — %s\nДля выполнения — %d энергии" % [task.title, cost]
	if is_done:
		text += "\nПовторное прохождение: без награды"
	else:
		text += "\nНаграда — %d монет" % reward
	
	var dialog := ConfirmationDialog.new()
	dialog.title = "Начать задание?"
	dialog.dialog_text = text
	dialog.ok_button_text = "Начать"
	dialog.cancel_button_text = "Отмена"
	
	dialog.min_size = Vector2(320, 200)
	
	var label := dialog.get_label()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	dialog.confirmed.connect(_on_task_confirmed.bind(task))
	add_child(dialog)
	dialog.popup_centered()

func _on_task_confirmed(task: Dictionary) -> void:
	TaskHolder.current_task = task
	TaskHolder.entry_point = "tasks"
	ScreenManager.go_to("res://scenes/screens/TaskScene.tscn")

func update_topbar() -> void:
	balance_label.text = "Баланс: %d" % int(ProfileManager.data.economy.balance)
	energy_label.text = "Энергия: %d" % int(ProfileManager.data.pet.state.energy)

func _show_message(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()

func _on_back_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/Home.tscn")
