extends Control

@onready var available_label: Label  = $MarginContainer/VBoxContainer/HBoxContainer/LabelAvailable

@onready var lbl_mandatory: Label = $MarginContainer/VBoxContainer/RowMandatory/LabelMandatoryValue
@onready var lbl_optional: Label = $MarginContainer/VBoxContainer/RowOptional/LabelOptionalValue
@onready var lbl_savings: Label = $MarginContainer/VBoxContainer/RowSavings/LabelSavingsValue

@onready var remainder_label: Label  = $MarginContainer/VBoxContainer/HBoxContainer/LabelRemainder
@onready var confirm_button: Button  = $MarginContainer/VBoxContainer/ButtonConfirm
@onready var back_button: Button     = $MarginContainer/VBoxContainer/ButtonBack
@onready var pet_image: TextureRect = $MarginContainer/VBoxContainer/PetImage
@onready var dialog_label: Label    = $MarginContainer/VBoxContainer/DialogLabel
@onready var dialog: Control = $Dialog
@onready var finish_button: Button = $MarginContainer/VBoxContainer/ButtonFinish

var total_available := 0
var val_mandatory := 0
var val_optional := 0
var val_savings := 0
const STEP := 10

var hold_category := ""        # какая категория удерживается
var hold_direction := 0        # +1 для плюса, -1 для минуса
var hold_delay := 0.0          # время до старта автоповтора
var hold_repeat := 0.0         # время между повторами
const HOLD_DELAY := 0.4        # пауза перед автоповтором
const HOLD_REPEAT := 0.1       # частота повторов




func _ready() -> void:
	PetVisual.apply(pet_image, "cat")
	pet_image.gui_input.connect(_on_pet_clicked)
	_show_dialog("Привет! Давай вместе спланируем бюджет! Если у тебя есть какие-либо вопросы, то кликни по мне")
	
	total_available = int(ProfileManager.data.economy.balance)
	available_label.text = "Доступно: %d" % total_available
	
	# если план уже есть - подстановка
	var planned: Dictionary = ProfileManager.data.budget.planned
	val_mandatory = int(planned.mandatory)
	val_optional = int(planned.optional)
	val_savings = int(planned.savings)
	_update_labels()
	
	# кнопки обязательных 
	$MarginContainer/VBoxContainer/RowMandatory/ButtonMinus.button_down.connect(_on_hold_start.bind("mandatory", -1))
	$MarginContainer/VBoxContainer/RowMandatory/ButtonMinus.button_up.connect(_on_hold_end)
	$MarginContainer/VBoxContainer/RowMandatory/ButtonPlus.button_down.connect(_on_hold_start.bind("mandatory", 1))
	$MarginContainer/VBoxContainer/RowMandatory/ButtonPlus.button_up.connect(_on_hold_end)
	# кнопки необязательных
	$MarginContainer/VBoxContainer/RowOptional/ButtonMinus.button_down.connect(_on_hold_start.bind("optional", -1))
	$MarginContainer/VBoxContainer/RowOptional/ButtonMinus.button_up.connect(_on_hold_end)
	$MarginContainer/VBoxContainer/RowOptional/ButtonPlus.button_down.connect(_on_hold_start.bind("optional", 1))
	$MarginContainer/VBoxContainer/RowOptional/ButtonPlus.button_up.connect(_on_hold_end)
	# кнопки накоплений
	$MarginContainer/VBoxContainer/RowSavings/ButtonMinus.button_down.connect(_on_hold_start.bind("savings", -1))
	$MarginContainer/VBoxContainer/RowSavings/ButtonMinus.button_up.connect(_on_hold_end)
	$MarginContainer/VBoxContainer/RowSavings/ButtonPlus.button_down.connect(_on_hold_start.bind("savings", 1))
	$MarginContainer/VBoxContainer/RowSavings/ButtonPlus.button_up.connect(_on_hold_end)
	
	var in_quest: bool = TaskHolder.quest_active and TaskHolder.quest_type == "budget"
	if in_quest:
		back_button.visible = false
		confirm_button.visible = false
		finish_button.visible = true
		finish_button.pressed.connect(_on_finish_budget_quest)
	else:
		finish_button.visible = false
	
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	set_process(false)
	_update_remainder()

func _on_finish_budget_quest() -> void:
	var sum_important: int = val_mandatory + val_savings
	var optional: int = val_optional
	
	if sum_important > optional:
		TaskHolder.quest_result = "budget_ok"
	else:
		TaskHolder.quest_result = "budget_fail"
	
	TaskHolder.quest_active = false
	TaskHolder.quest_type = ""
	ScreenManager.go_to("res://scenes/screens/TaskScene.tscn")

func _on_pet_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dialog.open("budget_cat")

func _show_dialog(text: String) -> void:
	dialog_label.text = text

func _on_hold_start(category: String, direction: int) -> void:
	hold_category = category
	hold_direction = direction
	hold_delay = HOLD_DELAY
	hold_repeat = 0.0
	set_process(true)
	
	# мгновенный отклик — одно нажатие сразу
	_apply_step(category, direction)

func _on_hold_end() -> void:
	hold_category = ""
	set_process(false)

func _process(delta: float) -> void:
	if hold_category == "":
		return
	
	if hold_delay > 0.0:
		hold_delay -= delta
		return
	
	hold_repeat -= delta
	if hold_repeat <= 0.0:
		hold_repeat = HOLD_REPEAT
		_apply_step(hold_category, hold_direction)

func _apply_step(category: String, direction: int) -> void:
	if category == "mandatory":
		val_mandatory = maxi(0, val_mandatory + direction * STEP)
	elif category == "optional":
		val_optional = maxi(0, val_optional + direction * STEP)
	elif category == "savings":
		val_savings = maxi(0, val_savings + direction * STEP)
	_on_value_changed()

func _on_value_changed() -> void:
	_update_labels()
	_update_remainder()
	_react_to_plan()

func _update_labels() -> void:
	lbl_mandatory.text = str(val_mandatory)
	lbl_optional.text = str(val_optional)
	lbl_savings.text = str(val_savings)

func _update_remainder() -> void: # остаток
	var sum := val_mandatory + val_optional + val_savings
	var remainder := total_available - sum
	remainder_label.text = "Остаток: %d" % remainder
	confirm_button.disabled = remainder < 0

func _react_to_plan() -> void:
	var sum := val_mandatory + val_optional + val_savings
	var remainder := total_available - sum
	
	if remainder < 0:
		_show_dialog("Ой, ты распределил больше, чем у тебя есть, убери лишнее")
	elif remainder == 0:
		_show_dialog("Отлично! Вся сумма распределена, ты молодец!")
	else:
		_show_dialog("У тебя ещё осталось %d монет, стоит их распределить" % remainder)

func _on_confirm_pressed() -> void:
	var d := ProfileManager.data
	d.budget.planned.mandatory = val_mandatory
	d.budget.planned.optional  = val_optional
	d.budget.planned.savings   = val_savings
	
	d.budget.confirmed = true
	ProfileManager.save_profile()
	ScreenManager.go_to("res://scenes/screens/Home.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_hold_end()

func _on_back_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/Home.tscn")
