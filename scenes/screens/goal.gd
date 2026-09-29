extends Control

@onready var savings_label: Label = $MarginContainer/VBoxContainer/LabelSavings
@onready var goal_title: Label    = $MarginContainer/VBoxContainer/LabelGoalTitle
@onready var goal_price: Label    = $MarginContainer/VBoxContainer/LabelGoalPrice
@onready var remaining_label: Label = $MarginContainer/VBoxContainer/LabelRemaining
@onready var goal_list: HBoxContainer = $MarginContainer/VBoxContainer/GoalList
@onready var back_button: Button = $MarginContainer/VBoxContainer/GridContainer/ButtonBack
@onready var withdraw_button: Button = $MarginContainer/VBoxContainer/GridContainer/ButtonWithdraw
@onready var savings_window: Control = $SavingsWindow
@onready var finish_button: Button = $MarginContainer/VBoxContainer/ButtonFinish
@onready var purchase_dialog: Control = $PurchaseDialog

var goals: Array = []
var dialog_open := false

func _ready() -> void:
	load_goals()
	build_goal_buttons()
	refresh()
	purchase_dialog.purchased.connect(_on_goal_purchased)
	purchase_dialog.canceled.connect(_on_goal_canceled)
	
	if TaskHolder.quest_active and (TaskHolder.quest_type == "safety" or TaskHolder.quest_type == "bank"):
		back_button.visible = false
		finish_button.visible = true
		finish_button.pressed.connect(_on_finish_quest)
	else:
		back_button.visible = true
		finish_button.visible = false
	
	back_button.pressed.connect(_on_back_pressed)
	withdraw_button.pressed.connect(_on_withdraw_pressed)
	
	$MarginContainer/VBoxContainer/GridContainer/Savings.pressed.connect(_on_savings_pressed)

func _on_finish_quest() -> void:
	var d := ProfileManager.data
	
	if TaskHolder.quest_type == "safety":
		var safety_now: int = int(d.economy.get("safety", 0))
		var added: int = safety_now - TaskHolder.quest_safety_start
		if added > 0:
			TaskHolder.quest_result = "safety_ok"
		else:
			TaskHolder.quest_result = "safety_zero"
	
	elif TaskHolder.quest_type == "bank":
		var bank_now: int = int(d.economy.get("bank", 0))
		var added: int = bank_now - TaskHolder.quest_bank_start
		if added > 0:
			TaskHolder.quest_result = "bank_ok"
		else:
			TaskHolder.quest_result = "bank_zero"
	
	TaskHolder.quest_active = false
	TaskHolder.quest_type = ""
	ScreenManager.go_to("res://scenes/screens/TaskScene.tscn")



func _on_savings_pressed() -> void:
	savings_window.open()

func load_goals() -> void:
	var f := FileAccess.open("res://data/goals.json", FileAccess.READ)
	goals = JSON.parse_string(f.get_as_text())
	f.close()

func build_goal_buttons() -> void:
	# очищаем старые кнопки (на случай повторного вызова)
	for child in goal_list.get_children():
		child.queue_free()
	
	var purchased_ids: Array = []
	for entry in ProfileManager.data.get("purchased_goals", []):
		purchased_ids.append(str(entry.get("goal_id", "")))
	
	for g in goals:
		if g.id in purchased_ids:
			continue    # пропускаем купленные
		
		var btn := Button.new()
		btn.text = g.title
		btn.pressed.connect(_on_goal_selected.bind(g.id))
		goal_list.add_child(btn)

func _on_goal_canceled() -> void:
	dialog_open = false
	# цель остаётся, монеты остаются
	# reached_id сбрасываем — окно не всплывёт, пока не пополнит снова
	ProfileManager.data.goal["reached_id"] = ""
	ProfileManager.save_profile()
	refresh()


func _on_goal_selected(goal_id: String) -> void:
	ProfileManager.data.goal.active_id = goal_id
	ProfileManager.data.goal["reached_id"] = ""    # сброс при смене цели
	ProfileManager.save_profile()
	refresh()


func refresh() -> void:
	var d := ProfileManager.data
	savings_label.text = "Накоплено: %d" % int(d.economy.savings)
	
	var active_id: String = str(d.goal.get("active_id", ""))
	if active_id == "":
		goal_title.text = "Цель: не выбрана"
		goal_price.text = ""
		remaining_label.text = ""
	else:
		for g in goals:
			if g.id == active_id:
				goal_title.text = "Цель: %s" % g.title
				goal_price.text = "Стоимость: %d" % int(g.price)
				var left := int(g.price) - int(d.economy.savings)
				remaining_label.text = "Осталось: %d" % max(left, 0)
				break
	
	# проверка достижения
	var reached_id: String = str(d.goal.get("reached_id", ""))
	if reached_id != "" and reached_id == active_id and not dialog_open:
		for g in goals:
			if g.id == reached_id:
				purchase_dialog.open(g)
				dialog_open = true
				return
	
	print("reached_id = ", reached_id, " active_id = ", active_id, " dialog_open = ", dialog_open)
	if reached_id != "" and reached_id == active_id and not dialog_open:
		for g in goals:
			if g.id == reached_id:
				print("Открываю PurchaseDialog для ", g.title)
				purchase_dialog.open(g)
				dialog_open = true
				return

func _on_goal_purchased(goal_id: String) -> void:
	dialog_open = false
	var d := ProfileManager.data
	
	var price := 0
	for g in goals:
		if g.id == goal_id:
			price = int(g.price)
			break
	
	# списываем
	d.economy.savings -= price
	
	# запись в купленные
	if not d.has("purchased_goals"):
		d["purchased_goals"] = []
	d["purchased_goals"].append({
		"goal_id": goal_id,
		"at": Time.get_datetime_string_from_system()
	})
	
	# опыт
	var count: int = int(d.goal.get("completed_count", 0))
	var exp_reward := 50
	if count == 1: exp_reward = 100
	elif count >= 2: exp_reward = 150
	Economy.add_stage_exp(exp_reward)
	
	# сброс цели — ребёнок сам выберет новую
	d.goal["completed_count"] = count + 1
	d.goal["active_id"] = ""
	d.goal["reached_id"] = ""
	ProfileManager.save_profile()
	
	refresh()

func _on_withdraw_pressed() -> void:
	var d := ProfileManager.data
	if d.economy.savings <= 0:
		return
	
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Снять все накопления\nи вернуть на баланс?"
	dialog.confirmed.connect(_do_withdraw_all)
	add_child(dialog)
	dialog.popup_centered()

func _do_withdraw_all() -> void:
	var d := ProfileManager.data
	var amount := int(d.economy.savings)
	if Economy.withdraw_from_savings(amount, true):
		# цель не достигнута — сбрасываем reached_id
		d.goal["reached_id"] = ""
		ProfileManager.save_profile()
		refresh()

func _on_back_pressed() -> void:
	ScreenManager.go_to("res://scenes/screens/Home.tscn")

func _on_step_pressed(amount: int) -> void:
	if Economy.add_to_savings(amount):
		refresh()
