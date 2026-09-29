extends Node

const SAVE_PATH := "user://profile.json"
var data: Dictionary = {}

func _ready() -> void:
	load_or_create()

func load_or_create():
	if FileAccess.file_exists(SAVE_PATH):
		load_profile()
	else:
		data = _default_profile()
		save_profile()

func _default_profile() -> Dictionary:
	return {
		"meta": {
			"profile_id": str(Time.get_unix_time_from_system()),
			"created_at": Time.get_datetime_string_from_system(),
			"is_test_profile": false,
			"demo_mode": false,
			"schema_version": 1
		},
		"progress": {
			"intro_done": false,        # первое задание пройдено
			"shop_unlocked": false,      # Покупки открыты
			"shop_quest_done": false,
			"savings_unlocked": false,
			"savings_quest_done": false,
			"bank_unlocked": false,
			"bank_quest_done": false,
			"budget_unlocked": false,   # Бюджет открыт
			"goal_unlocked": false,     # Копилка открыта
			"sleep_unlocked": false,     # Сон открыт
			"far_shop_unlocked": false
		},
		"pet": {
			"name": "",
			"appearance": {"body": "round", "color": "blue", "accessory": "none" },
			"state": {"mood": 50, "satiety": 100, "energy": 80},
			"rest_started_at": "",
			"is_resting": false,
			"is_sleeping": false,
			"sleep_started_at": "",
			"stage": 1,
			"stage_progress": 0,
			"stage_max": 4,
			"saved_balance": 0,     
			"quest_wallet": -1,     
			"quest_target": "",      
			"quest_from": "",        
			"quest_bought_optional": false  
		},
		"economy": {
			"balance": 100,
			"savings": 0,
			"bank": 0, 
			"period_income": 100,
			"day_earnings": 0,
			"last_daily_claim": "",
			"income_log": []
		},
		"budget": {
			"current_period": 1,
			"pending_result": {},
			"pending_day": 0,
			"planned": {"mandatory": 0, "optional": 0, "savings": 0},
			"confirmed": false,
			"actual": {"mandatory": 0, "optional": 0, "savings": 0}
		},
		"purchases": {"current_period": [], "history": []},
		"goal": {
			"active_id": "",
			"available": [],
			"completed_count": 0,
			"reached_id": ""
			},
			"purchased_goals": [],
		"tasks": {"completed": [], "completed_today": 0 ,"topic_progress": {"budget": 0, "savings": 0, "payments": 0}},
		"history": []
	}

func save_profile() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func load_profile() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	f.close()

func reset_profile(demo: bool = false) -> void:
	data = _default_profile()
	data.meta["demo_mode"] = demo
	data.meta["is_test_profile"] = demo
	save_profile()

func start_demo_profile() -> void:
	data = _default_profile()
	data.meta.is_test_profile = true
	data.meta.demo_mode = true
	data.economy.balance = 100  # стартовый бюджет
	save_profile()
