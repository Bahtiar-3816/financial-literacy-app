extends Control

@onready var pet_image: TextureRect = $MarginContainer/VBoxContainer/PetImage
@onready var dialog_label: Label = $MarginContainer/VBoxContainer/DialogLabel
@onready var button_near: Button = $MarginContainer/VBoxContainer/ShopsRow/ShopNear/ButtonNear
@onready var button_far: Button = $MarginContainer/VBoxContainer/ShopsRow/ShopFar/ButtonFar
@onready var back_button: Button = $MarginContainer/VBoxContainer/ButtonBack
@onready var dialog: Control = $Dialog

const FAR_SHOP_ENERGY_COST := 20
const FAR_SHOP_DISCOUNT := 0.2    # −20%

func _ready() -> void:
	PetVisual.apply(pet_image, "cat")
	pet_image.gui_input.connect(_on_pet_clicked)
	button_near.pressed.connect(_on_near_pressed)
	button_far.pressed.connect(_on_far_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# если задание «сравнение цен» активно — оба магазина доступны
	if TaskHolder.quest_active and TaskHolder.quest_shop_target != "":
		_show_dialog("Сравни цены и выбери, где купить еду.")
		return
	
	_show_dialog("Куда хочешь пойти ? Если у тебя имеются вопросы, то кликни по мне.")

func _show_dialog(text: String) -> void:
	dialog_label.text = text

func _on_pet_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dialog.open("shop_cat")

func _on_near_pressed() -> void:	
	TaskHolder.shop_mode = "near"
	ScreenManager.go_to("res://scenes/screens/Shop.tscn")

func _on_far_pressed() -> void:
		# если это задание «сравнение цен» — не списываем энергию
	if TaskHolder.quest_active and TaskHolder.quest_shop_target != "":
		TaskHolder.shop_mode = "far"
		ScreenManager.go_to("res://scenes/screens/Shop.tscn")
		return
		
	# если дальний ещё не разблокирован и это не задание «сравнение цен»
	var far_unlocked: bool = bool(ProfileManager.data.progress.get("far_shop_unlocked", false))
	if not far_unlocked:
		@warning_ignore("shadowed_variable")
		var dialog := ConfirmationDialog.new()
		dialog.title = "Перейти к заданию?"
		dialog.dialog_text = "Перейти к заданию «Сравнение цен»?"
		dialog.ok_button_text = "Да"
		dialog.cancel_button_text = "Нет"
		dialog.confirmed.connect(_start_price_quest_from_shop)
		add_child(dialog)
		dialog.popup_centered()
		return
	
	var d := ProfileManager.data
	if int(d.pet.state.energy) < FAR_SHOP_ENERGY_COST:
		_show_dialog("Питомец слишком устал. Отдохни.")
		return
	
	d.pet.state.energy = clampi(int(d.pet.state.energy) - FAR_SHOP_ENERGY_COST, 0, 100)
	ProfileManager.save_profile()
	TaskHolder.shop_mode = "far"
	ScreenManager.go_to("res://scenes/screens/Shop.tscn")

func _start_price_quest_from_shop() -> void:
	var f := FileAccess.open("res://data/tasks.json", FileAccess.READ)
	var chapters = JSON.parse_string(f.get_as_text())
	f.close()
	
	for chapter in chapters:
		for t in chapter.tasks:
			if t.id == "task_1_3":
				TaskHolder.current_task = t
				TaskHolder.entry_point = "shopselect"
				ScreenManager.go_to("res://scenes/screens/TaskScene.tscn")
				return
	
	

func _load_chapters() -> Array:
	var f := FileAccess.open("res://data/tasks.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data

func _on_back_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/Home.tscn")











#
