extends Node

const INCOME_DAILY := 20             # ежедневный доход
const INCOME_TASK  := 30             # награда за задание
const SAVINGS_STEP := 10             # шаг пополнения копилки

const STAGE_THRESHOLDS := {
	1: 100,
	2: 200,
	3: 300
}

func add_stage_exp(amount: int) -> void:
	var d := ProfileManager.data
	var stage: int = int(d.pet.stage)
	var progress: int = int(d.pet.stage_progress) + amount
	
	# если уже максимальная — просто копим, не растём
	if stage >= 4:
		d.pet.stage_progress = progress
		ProfileManager.save_profile()
		return
	
	# растем по циклу, пока хватает опыта
	while stage < 4:
		var need: int = STAGE_THRESHOLDS.get(stage, 99999)
		if progress < need:
			break
		progress -= need
		stage += 1
	
	d.pet.stage = stage
	d.pet.stage_progress = progress
	ProfileManager.save_profile()

# --- Доход ---
func add_income(source: String, amount: int) -> void:
	var d := ProfileManager.data
	d.economy.balance += amount
	d.economy["day_earnings"] = int(d.economy.get("day_earnings", 0)) + amount
	d.economy.income_log.append({
		"source": source,
		"amount": amount,
		"at": Time.get_datetime_string_from_system()
	})
	ProfileManager.save_profile()

func claim_daily() -> bool:
	var today := Time.get_date_string_from_system()
	if ProfileManager.data.economy.last_daily_claim == today:
		return false
	ProfileManager.data.economy.last_daily_claim = today
	add_income("daily_login", INCOME_DAILY)
	return true

# --- Покупка ---
func can_afford(price: int) -> bool:
	return ProfileManager.data.economy.balance >= price

func buy_item(item_id: String, price: int, type: String) -> bool:
	if not can_afford(price):
		return false
	ProfileManager.data.economy.balance -= price
	ProfileManager.data.purchases.current_period.append({
		"item_id": item_id,
		"type": type,
		"price": price,
		"at": Time.get_datetime_string_from_system()
	})
	
	# учёт в факте бюджета
	if type == "mandatory":
		ProfileManager.data.budget.actual.mandatory += price
	else:
		ProfileManager.data.budget.actual.optional += price
	ProfileManager.save_profile()
	return true

# --- Накопления ---
func add_to_savings(amount: int) -> bool:
	if not can_afford(amount):
		return false
	ProfileManager.data.economy.balance -= amount
	ProfileManager.data.economy.savings += amount
	ProfileManager.data.budget.actual.savings += amount
	ProfileManager.save_profile()
	check_goal_reached()
	return true

func withdraw_from_savings(amount: int, confirmed: bool = false) -> bool:  # снятие с бережений
	if not confirmed:
		return false
	if ProfileManager.data.economy.savings < amount:
		return false
	ProfileManager.data.economy.savings -= amount
	ProfileManager.data.economy.balance += amount
	ProfileManager.save_profile()
	return true

# --- Итоги периода ---
func apply_period_result() -> Dictionary:
	var d := ProfileManager.data
	var planned: Dictionary = d.budget.planned
	var actual: Dictionary = d.budget.actual
	#   plan_matched
	var plan_matched: bool = (
		actual.mandatory <= planned.mandatory and
		actual.optional  <= planned.optional  and
		actual.savings   >= planned.savings
	)
	
	# настроение падает каждый день
	d.pet.state.mood = clampi(int(d.pet.state.mood) - 10, 0, 100)
	
	var mood_delta := 0
	var satiety_delta := 0
	
	# план соблюдён?
	mood_delta += 5 if plan_matched else -5
	
	d.pet.state.mood    = clampi(d.pet.state.mood + mood_delta, 0, 100)
	d.pet.state.satiety = clampi(d.pet.state.satiety + satiety_delta, 0, 100)
	
	# рост питомца
	if plan_matched and actual.savings > 0:
		d.pet.stage_progress += 1
	if d.pet.stage_progress >= 3 and d.pet.stage < 3:
		d.pet.stage += 1
		d.pet.stage_progress = 0
	
	# запись в историю
	var summary := "Всё по плану!" if plan_matched else "План не совпал с фактом."
	d.history.append({
		"period": d.budget.current_period,
		"plan_matched": plan_matched,
		"savings_added": actual.savings,
		"pet_stage_after": d.pet.stage,
		"summary": summary
	})
	
	# сохраняем покупки дня в историю
	d.purchases.history.append({
		"day": d.budget.current_period,
		"items": d.purchases.current_period.duplicate()
	})
	
	# затем сбрасываем
	d.purchases.current_period = []
	# новый период
	d.budget.current_period += 1
	d.budget.planned = { "mandatory": 0, "optional": 0, "savings": 0 }
	d.budget.actual  = { "mandatory": 0, "optional": 0, "savings": 0 }
	d.budget.confirmed = false
	d.purchases.current_period = []
	
	d.economy.balance += int(d.economy.period_income)  # начисление денег за каждый период
	ProfileManager.save_profile()
	return { "plan_matched": plan_matched, "summary": summary }

func unlock_after_intro() -> void:
	var d := ProfileManager.data
	d.progress.intro_done = true
	d.progress.shop_unlocked = true
	ProfileManager.save_profile()

func evaluate_shop_quest() -> String:
	var purchased: Array = ProfileManager.data.purchases.current_period
	var count_optional := 0
	var count_food := 0
	
	for entry in purchased:
		if entry.item_id == "food_basic":
			count_food += 1
		if entry.type == "optional":
			count_optional += 1
	
	if count_food < 2:
		return "fail_mandatory"
	if count_optional >= 1:
		return "mix"
	return "only_mandatory"

func evaluate_price_quest() -> String:
	var d := ProfileManager.data
	var from: String = str(d.economy.get("quest_from", ""))
	var bought_optional: bool = bool(d.economy.get("quest_bought_optional", false))
	
	if from == "far":
		if bought_optional:
			return "price_saved_optional"
		return "price_saved"
	return "price_not_saved"

func get_bank_limit() -> int:
	var stage: int = int(ProfileManager.data.pet.stage)
	match stage:
		1: return 100
		2: return 200
		_: return 300

func add_to_bank(amount: int) -> bool:
	var d := ProfileManager.data
	if not can_afford(amount):
		return false
	
	var bank: int = int(d.economy.get("bank", 0))
	var limit := get_bank_limit()
	if bank + amount > limit:
		return false
	
	d.economy.balance -= amount
	d.economy["bank"] = bank + amount
	ProfileManager.save_profile()
	return true

func withdraw_from_bank(amount: int, confirmed: bool = false) -> bool:
	if not confirmed:
		return false
	var d := ProfileManager.data
	var bank: int = int(d.economy.get("bank", 0))
	if bank < amount:
		return false
	d.economy.balance += amount
	d.economy["bank"] = bank - amount
	ProfileManager.save_profile()
	return true

func apply_bank_interest() -> void:
	var d := ProfileManager.data
	var bank: int = int(d.economy.get("bank", 0))
	if bank <= 0:
		return
	
	var interest: int = int(round(bank * 0.10))
	d.economy.balance += interest
	d.economy.income_log.append({
		"source": "bank_interest",
		"amount": interest,
		"at": Time.get_datetime_string_from_system()
	})
	ProfileManager.save_profile()

func check_goal_reached() -> void:
	var d := ProfileManager.data
	var active_id: String = str(d.goal.get("active_id", ""))
	if active_id == "":
		return
	
	if str(d.goal.get("reached_id", "")) == active_id:
		return    # уже помечено
	
	var f := FileAccess.open("res://data/goals.json", FileAccess.READ)
	var goals: Array = JSON.parse_string(f.get_as_text())
	f.close()
	
	var goal: Dictionary = {}
	for g in goals:
		if g.id == active_id:
			goal = g
			break
	if goal.is_empty():
		return
	
	if int(d.economy.savings) < int(goal.price):
		return
	
	d.goal["reached_id"] = active_id
	ProfileManager.save_profile()
