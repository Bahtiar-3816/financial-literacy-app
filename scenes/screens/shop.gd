extends Control

@onready var title_label: Label = $MarginContainer/VBoxContainer/TopBar/Label
@onready var balance_label: Label = $MarginContainer/VBoxContainer/TopBar/LabelBalance
@onready var items_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ItemsList
@onready var back_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ButtonBack
@onready var history_dialog: Control = $PurchaseHistory
@onready var history_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ButtonHistory
@onready var next_button: Button = $MarginContainer/VBoxContainer/ButtonNext
@onready var dialog: Control = $Dialog

var catalog: Array = []

func _ready() -> void:
	load_catalog()
	
	if TaskHolder.quest_active:
		title_label.text = "Купи: " + _quest_list_text()
		back_button.visible = false
		history_button.visible = false
		next_button.visible = false       # покажем после проверки
	else:
		back_button.visible = true
		history_button.visible = true
		next_button.visible = false       # в обычном режиме не нужна
	
	refresh_balance()
	build_list()
	back_button.pressed.connect(_on_back_pressed)
	history_button.pressed.connect(_on_history_pressed)
	
	next_button.visible = false
	next_button.pressed.connect(_on_next_pressed)
	
	if TaskHolder.quest_active:
		_check_quest_progress()

func _on_optional_blocked() -> void:
	dialog.open("shop_blocked")


func _quest_list_text() -> String:
	var counts := {}
	for id in TaskHolder.quest_items:
		counts[id] = counts.get(id, 0) + 1
	var parts: Array = []
	for id in counts.keys():
		parts.append("%s ×%d" % [_get_title(id), counts[id]])
	return ", ".join(parts)

func _get_title(item_id: String) -> String:
	for it in catalog:
		if it.id == item_id:
			return it.title
	return item_id

func _on_history_pressed() -> void:
	history_dialog.open()

func load_catalog() -> void:
	var f := FileAccess.open("res://data/items.json", FileAccess.READ)
	catalog = JSON.parse_string(f.get_as_text())
	f.close()

func refresh_balance() -> void:
	balance_label.text = "Баланс: %d" % int(ProfileManager.data.economy.balance)

func build_list() -> void:
	for child in items_list.get_children():
		child.queue_free()
	for item in catalog:
		var row := _make_item_row(item)
		items_list.add_child(row)

func _get_price(item: Dictionary) -> int:
	var base := int(item.price)
	if TaskHolder.shop_mode == "far":
		base = int(round(base * 0.8))   # −20%
	return base

func _make_item_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 100)
	row.add_theme_constant_override("separation", 8)
	
	
	var is_price_quest: bool = TaskHolder.quest_active and TaskHolder.quest_shop_target != ""
	var meat_count := 0
	for entry in ProfileManager.data.purchases.current_period:
		if entry.item_id == TaskHolder.quest_shop_target:
			meat_count += 1
	
	var meat_bought: bool = meat_count >= 2
	var block_all: bool = is_price_quest and item.id != TaskHolder.quest_shop_target and not meat_bought
	
	# --- Картинка слева ---
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(100, 100)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var icon_path: String = item.get("icon", "res://icon.svg")
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	row.add_child(icon)
	
	# --- Правый блок: название, описание, кнопка ---
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	
	var title := Label.new()
	title.text = item.title
	title.add_theme_font_size_override("font_size", 14)
	info.add_child(title)
	
	var desc := Label.new()
	desc.text = _effect_text(item)
	desc.add_theme_font_size_override("font_size", 10)
	desc.modulate = Color(0.8, 0.8, 0.8, 1.0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(desc)
	
	var price := _get_price(item)
	var btn := Button.new()
	
	if block_all:
		btn.text = "%d 💰" % price
		btn.disabled = false
		btn.pressed.connect(_on_optional_blocked)
	else:
		btn.text = "%d 💰" % price
		btn.disabled = not Economy.can_afford(price)
		btn.pressed.connect(_on_buy_pressed.bind(item))
	
	btn.custom_minimum_size = Vector2(0, 30)
	info.add_child(btn)
	
	row.add_child(info)
	
	return row

func _effect_text(item: Dictionary) -> String:
	var type_label := "обязательный" if item.type == "mandatory" else "желательный"
	var effect: String = item.get("effect", "")
	var effect_ru := _translate_effect(effect)
	return "%s %s" % [type_label, effect_ru]

func _translate_effect(effect: String) -> String:
	# "satiety+15" → "Сытость +15"
	var map := { "satiety": "Сытость", "mood": "Настроение", "energy": "Энергия" }
	for key in map.keys():
		if effect.begins_with(key):
			var rest := effect.substr(key.length())
			return "%s %s" % [map[key], rest]
	return effect

func _on_buy_pressed(item: Dictionary) -> void:
	# защита: в задании «Сравнение цен» покупаем только еду, пока она не куплена
	if TaskHolder.quest_active and TaskHolder.quest_shop_target != "":
		var meat_count := 0
		for entry in ProfileManager.data.purchases.current_period:
			if entry.item_id == TaskHolder.quest_shop_target:
				meat_count += 1
		
		if item.id != TaskHolder.quest_shop_target and meat_count < 2:
			dialog.open("shop_blocked")
			return
	
	var price := _get_price(item)
	if not Economy.buy_item(item.id, price, item.type):
		var missing := price - int(ProfileManager.data.economy.balance)
		_show_message("Не хватает %d монет" % missing)
		return
	
	# запоминаем магазин для задания
	if TaskHolder.quest_active and item.id == TaskHolder.quest_shop_target:
		TaskHolder.quest_shop_from = TaskHolder.shop_mode
		# и в профиль — чтобы сохранилось при выходе
		ProfileManager.data.economy["quest_from"] = TaskHolder.shop_mode
	
	if item.type == "optional":
		TaskHolder.quest_shop_bought_optional = true
		ProfileManager.data.economy["quest_bought_optional"] = true
	
	# применяем эффект
	if not TaskHolder.quest_active and item.has("effect"):
		_apply_effect(item.effect)
	
	refresh_balance()
	build_list()  # перестроить, чтобы обновить disabled у кнопок
	
	if TaskHolder.quest_active:
		_check_quest_progress()


func _show_message(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Товар добавлен!"
	dialog.dialog_text = msg
	dialog.min_size = Vector2(200, 75) 
	dialog.ok_button_text = "Продолжить..."
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	
	dialog.popup_centered()

func _apply_effect(effect: String) -> void:
	# формат: "satiety+15", "mood+5", "energy+20"
	var d := ProfileManager.data
	
	var sign := 1
	var op_index := effect.find("+")
	if op_index == -1:
		op_index = effect.find("-")
		sign = -1
	if op_index == -1:
		return    # нет знака — нечего применять
	
	var stat := effect.substr(0, op_index)
	var amount := int(effect.substr(op_index + 1)) * sign
	
	match stat:
		"satiety":
			d.pet.state.satiety = clampi(int(d.pet.state.satiety) + amount, 0, 100)
		"mood":
			d.pet.state.mood = clampi(int(d.pet.state.mood) + amount, 0, 100)
		"energy":
			d.pet.state.energy = clampi(int(d.pet.state.energy) + amount, 0, 100)

func _check_quest_progress() -> void:
	if not TaskHolder.quest_active:
		return
	
	# задание «Сравнение цен»?
	if TaskHolder.quest_shop_target != "":
		var bought := {}
		for entry in ProfileManager.data.purchases.current_period:
			bought[entry.item_id] = bought.get(entry.item_id, 0) + 1
		
		var needed := {}
		for id in TaskHolder.quest_items:
			needed[id] = needed.get(id, 0) + 1
		
		var all_bought := true
		for id in needed.keys():
			if int(bought.get(id, 0)) < int(needed[id]):
				all_bought = false
				break
		
		next_button.visible = all_bought
		next_button.text = "Далее"
		return
	
	var bought := {}
	for entry in ProfileManager.data.purchases.current_period:
		bought[entry.item_id] = bought.get(entry.item_id, 0) + 1
	
	var needed := {}
	for id in TaskHolder.quest_items:
		needed[id] = needed.get(id, 0) + 1
	
	var all_mandatory := true
	for id in needed.keys():
		if int(bought.get(id, 0)) < int(needed[id]):
			all_mandatory = false
			break
	
	if all_mandatory:
		next_button.visible = true
		next_button.text = "Далее"
		return
	
	# если обязательное не куплено, но есть хотя бы одна покупка — даём «Завершить»
	var anything_bought: bool = ProfileManager.data.purchases.current_period.size() > 0
	if anything_bought:
		next_button.visible = true
		next_button.text = "Завершить"
	else:
		next_button.visible = false

func _on_back_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/Home.tscn")

func _on_next_pressed() -> void:
	if TaskHolder.quest_shop_target != "":
		TaskHolder.quest_result = Economy.evaluate_price_quest()
	else:
		TaskHolder.quest_result = Economy.evaluate_shop_quest()
	TaskHolder.quest_active = false
	ScreenManager.go_to("res://scenes/screens/TaskScene.tscn")
