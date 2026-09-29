extends Control


@onready var label_mandatory: Label = $MarginContainer/VBoxContainer/LabelMandatory
@onready var label_optional: Label  = $MarginContainer/VBoxContainer/LabelOptional
@onready var label_total: Label     = $MarginContainer/VBoxContainer/LabelTotal
@onready var label_mood: Label      = $MarginContainer/VBoxContainer/LabelMood
@onready var button_ok: Button      = $MarginContainer/VBoxContainer/ButtonOk
@onready var label_exp: Label = $MarginContainer/VBoxContainer/LabelExp
@onready var label_earned: Label = $MarginContainer/VBoxContainer/LabelEarned
@onready var label_income: Label = $MarginContainer/VBoxContainer/LabelIncome


func _ready() -> void:
	var result: Dictionary = ProfileManager.data.budget.pending_result
	if result.is_empty():
		# нечего показывать — на Home
		ScreenManager.go_to("res://scenes/screens/Home.tscn")
		return
	_show_result(result)
	button_ok.pressed.connect(_on_ok_pressed)

func _show_result(result: Dictionary) -> void:
	label_mandatory.text = "Обязательные расходы %s" % [
		"совпали с реальными" if result.match_mandatory else "не совпали с реальными"
	]
	label_optional.text = "Необязательные расходы %s" % [
		"совпали с реальными" if result.match_optional else "не совпали с реальными"
	]
	
	var exp_reward: int = int(result.get("exp_reward", 0))
	var earned: int = int(result.get("earned_today", 0))
	var income: int = int(result.get("period_income", 0))
	
	label_exp.text = "Опыт за день: +%d" % exp_reward
	label_earned.text = "Питомец заработал: +%d монет" % earned
	label_income.text = "Доход дня: +%d монет" % income
	
	if exp_reward > 0:
		label_mood.text = "Молодец!"
	else:
		label_mood.text = "В следующий раз спланируй точнее."

func _format_reward(matched: bool) -> String:
	return "+5 монет" if matched else "−5 монет"

func _on_ok_pressed() -> void:
	var d := ProfileManager.data
	var result: Dictionary = d.budget.pending_result
	if result.is_empty():
		ScreenManager.go_to("res://scenes/screens/Home.tscn")
		return
	
	# опыт
	var exp_reward: int = int(result.get("exp_reward", 0))
	if exp_reward > 0:
		Economy.add_stage_exp(exp_reward)
	
	# голод
	d.pet.state.satiety = clampi(int(d.pet.state.satiety) + int(result.get("hunger", -40)), 0, 100)
	
	# завершаем период — там начислится period_income и настроение −10
	Economy.apply_period_result()
	
	# сбрасываем day_earnings
	d.economy["day_earnings"] = 0
	
	# очищаем pending
	d.budget.pending_result = {}
	d.budget.pending_day = 0
	ProfileManager.save_profile()
	
	ScreenManager.go_to("res://scenes/screens/Home.tscn")




#
