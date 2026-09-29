extends Control

@onready var balance_label: Label = $MarginContainer/VBoxContainer/LabelBalance
@onready var savings_label: Label = $MarginContainer/VBoxContainer/TopBar/LabelSavings
@onready var mood_label: Label    = $MarginContainer/VBoxContainer/TopBar/LabelMood
@onready var pet_name_label: Label = $MarginContainer/VBoxContainer/PetPanel/VBoxContainer/LabelPetName
@onready var finish_button: Button = $MarginContainer/VBoxContainer/ButtonSleep
@onready var adult_button: Button = $MarginContainer/VBoxContainer/ButtonAdult
@onready var pet_image: TextureRect = $MarginContainer/VBoxContainer/PetPanel/VBoxContainer/PetImage
@onready var energy_label: Label = $MarginContainer/VBoxContainer/TopBar2/LabelEnergy
@onready var rest_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ButtonRest
@onready var satiety_label: Label = $MarginContainer/VBoxContainer/TopBar3/LabelSatiety

@onready var bar_mood: ProgressBar = $MarginContainer/VBoxContainer/TopBar/BarMood
@onready var bar_energy: ProgressBar = $MarginContainer/VBoxContainer/TopBar2/BarEnergy
@onready var bar_satiety: ProgressBar = $MarginContainer/VBoxContainer/TopBar3/BarSatiety

@onready var budget_button: Button = $MarginContainer/VBoxContainer/Actions/ButtonBudget
@onready var shop_button: Button   = $MarginContainer/VBoxContainer/Actions/ButtonShop
@onready var goal_button: Button   = $MarginContainer/VBoxContainer/Actions/ButtonSavings
@onready var sleep_button: Button  = $MarginContainer/VBoxContainer/ButtonSleep

@onready var bar_exp: ProgressBar = $MarginContainer/VBoxContainer/PetPanel/VBoxContainer/BarExp
@onready var label_exp: Label = $MarginContainer/VBoxContainer/PetPanel/VBoxContainer/LabelExp

var rest_duration: float = 3600.0 # 3600.0 - столько должно быть 

const STAGE_THRESHOLDS := {
	1: 100,
	2: 200,
	3: 300,
	4: 300   # на 4 стадии — просто визуально, расти некуда
}

func _apply_pet_visual() -> void:
	PetVisual.apply(pet_image, "kitten")
	
	if bool(ProfileManager.data.meta.get("demo_mode", false)):
		rest_duration = 5.0
	
	var stage: int = int(ProfileManager.data.pet.stage)
	var scale_factor := 0.85 + stage * 0.1   # 0.95, 1.05, 1.15, 1.25
	pet_image.scale = Vector2(scale_factor, scale_factor)
	pet_image.pivot_offset = pet_image.size / 2

func _color_from_id(color_id: String) -> Color:
	match color_id:
		"blue":   return Color(0.4, 0.7, 1.0)
		"green":  return Color(0.5, 0.9, 0.5)
		"orange": return Color(1.0, 0.7, 0.4)
		_:        return Color.WHITE

func _ready() -> void:
	_apply_pet_visual()
	refresh()
	rest_button.pressed.connect(_on_rest_pressed)
	finish_button.pressed.connect(_on_finish_pressed)
	adult_button.pressed.connect(_on_adult_pressed)
	set_process(true)
	# finish_button.disabled = not ProfileManager.data.budget.confirmed # делает кнопку недоступной до момента изменения плана бюджета

func _process(_delta: float) -> void:
	_tick_rest()

func _tick_rest() -> void:
	var d := ProfileManager.data
	if not d.pet.is_resting:
		return
	
	var started: float = float(d.pet.rest_started_at)
	var now := Time.get_unix_time_from_system()
	var elapsed := now - started
	
	if elapsed >= rest_duration:
		_finish_rest()
		return
	
	# показываем прогресс
	var progress := elapsed / rest_duration
	energy_label.text = "Энергия: %d%% (отдыхает)" % int(progress * 100)

func _on_rest_pressed() -> void:
	var d := ProfileManager.data
	if d.pet.is_resting:
		# прерываем — энергия остаётся частичной
		var started: float = float(d.pet.rest_started_at)
		var elapsed := Time.get_unix_time_from_system() - started
		var gained := int( (elapsed / rest_duration) * 100 )
		d.pet.state.energy = clampi(int(d.pet.state.energy) + gained, 0, 100)
		d.pet.is_resting = false
		d.pet.rest_started_at = ""
	else:
		# начинаем отдых
		d.pet.is_resting = true
		d.pet.rest_started_at = str(Time.get_unix_time_from_system())
	
	ProfileManager.save_profile()
	refresh()

func _finish_rest() -> void:
	var d := ProfileManager.data
	d.pet.state.energy = 100
	d.pet.is_resting = false
	d.pet.rest_started_at = ""
	ProfileManager.save_profile()
	refresh()

func refresh() -> void:
	var d := ProfileManager.data
	
	if d.pet.is_resting:
		rest_button.text = "Прервать отдых"
	else:
		energy_label.text = "Энергия: %d" % int(d.pet.state.energy)
		rest_button.text = "Отдохнуть"
		
	satiety_label.text = "Сытость: %d" % int(d.pet.state.satiety)
	balance_label.text = "Баланс: %d" % int(d.economy.balance)
	savings_label.text = "Копилка: %d" % int(d.economy.savings)
	mood_label.text = "Настроение: %d" % int(d.pet.state.mood)
	pet_name_label.text = str(d.pet.name) if d.pet.name != "" else "Финиик"
	bar_mood.value = int(d.pet.state.mood)
	bar_energy.value = int(d.pet.state.energy)
	bar_satiety.value = int(d.pet.state.satiety)
	
	budget_button.disabled = not bool(d.progress.budget_unlocked)
	shop_button.disabled   = not bool(d.progress.shop_unlocked)
	goal_button.disabled   = not bool(d.progress.goal_unlocked)
	sleep_button.disabled  = not bool(d.progress.sleep_unlocked)
	goal_button.disabled = not bool(ProfileManager.data.progress.get("savings_unlocked", false))
	
	# шкала опыта
	var stage: int = int(d.pet.stage)
	var progress: int = int(d.pet.stage_progress)
	var need: int = STAGE_THRESHOLDS.get(stage, 300)
	
	bar_exp.max_value = need
	bar_exp.value = progress
	
	if stage >= 4:
		label_exp.text = "Максимальный уровень"
	else:
		label_exp.text = "Уровень %d — %d/%d" % [stage, progress, need]

func _on_finish_pressed() -> void:
	var d := ProfileManager.data

	# проверка: составлен ли план бюджета
	if not bool(d.budget.get("confirmed", false)):
		_show_message("Сначала составь план бюджета, котёнок.")
		return
	
	
	#if int(d.tasks.completed_today) < 0:
		#_show_message("Питомец хочет поиграть.\nСначала выполни хотя бы одно задание.")
		#return
	
	# начинаем сон
	d.pet.is_sleeping = true
	d.pet.sleep_started_at = str(Time.get_unix_time_from_system())
	ProfileManager.save_profile()
	ScreenManager.go_to("res://scenes/screens/Sleep.tscn")

func _show_message(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = msg
	dialog.title = "Итог за день"
	dialog.ok_button_text = "Ок"
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()



func _on_budget_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/Budget.tscn")

func _on_shop_pressed() -> void:
	var d := ProfileManager.data
	var intro_done: bool = bool(d.progress.intro_done)
	var quest_done: bool = bool(d.progress.shop_quest_done)
	
	if intro_done and not quest_done:
		# запускаем задание через TaskScene
		for chapter in _load_chapters():
			for t in chapter.tasks:
				if t.id == "task_1_2":
					TaskHolder.current_task = t
					ScreenManager.go_to("res://scenes/screens/TaskScene.tscn")
					return
	
	ScreenManager.go_to("res://scenes/screens/ShopSelect.tscn")

func _load_chapters() -> Array:
	var f := FileAccess.open("res://data/tasks.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data

func _on_goal_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/Goal.tscn")

func _on_task_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/Tasks.tscn")

func _on_adult_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/AdultControl.tscn")
