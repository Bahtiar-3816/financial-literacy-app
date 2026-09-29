extends Control

@onready var background: TextureRect = $Background
@onready var pet_sprite: TextureRect = $PetSprite
@onready var choices_area: VBoxContainer = $ChoicesArea
@onready var name_label: Label = $DialogPanel/VBoxContainer/NameLabel
@onready var text_label: Label = $DialogPanel/VBoxContainer/TextLabel
@onready var tap_hint: Label = $TapHint   # "Нажми, чтобы продолжить"

var task: Dictionary = {}
var steps: Array = []
var current_index := 0
var waiting_for_tap := false
var current_step := 0
var typewriter_speed := 0.03     # секунд на символ
var typewriter_progress := 0.0
var is_typing := false
var full_text := ""


const SPEAKER_SPRITES := {
	"kitten": "res://assets/pets/round_kitten.png",
	"cat":    "res://assets/pets/round_cat.png",
	"cashier": "res://assets/pets/round_cat.png"   # пока кот, потом свой спрайт
}

const SPEAKER_NAMES := {
	"kitten": "Котёнок",
	"cat":    "Кот",
	"cashier": "Кот-кассир"
}

func _ready() -> void:
	task = TaskHolder.current_task
	
	# если это возврат из магазина с результатом — показываем концовку
	if not TaskHolder.quest_result.is_empty():
		_show_quest_result(TaskHolder.quest_result)
		return
		
	if task.is_empty():
		ScreenManager.go_to("res://scenes/screens/Tasks.tscn")
		return
	
	steps = task.steps
	if task.has("background") and ResourceLoader.exists(task.background):
		background.texture = load(task.background)
	
	_show_step(0)

func _show_step(index: int) -> void:
	if index < 0 or index >= steps.size():
		_finish_task()
		return
	
	current_step = index
	var step: Dictionary = steps[index]
	
	full_text = step.get("text", "")
	text_label.text = ""
	typewriter_progress = 0.0
	is_typing = true
	waiting_for_tap = false    # пока не допечатается, тап не работает
	tap_hint.visible = false
	
	# фон
	if step.has("background") and ResourceLoader.exists(step.background):
		background.texture = load(step.background)
	
	# спрайт и имя
	var speaker: String = step.get("speaker", "cat")
	if speaker == "kitten":
		name_label.text = str(ProfileManager.data.pet.name)
	else:
		name_label.text = SPEAKER_NAMES.get(speaker, "")
	
	_animate_name()
	
# очистка кнопок от прошлого шага
	for child in choices_area.get_children():
		child.queue_free()
# состояние ожидания определится после печати текста в _on_typing_finished
	waiting_for_tap = false
	tap_hint.visible = false

func _start_shop_quest() -> void:
	var d := ProfileManager.data
	
	TaskHolder.quest_active = true
	TaskHolder.quest_items = ["food_basic", "food_basic"]
	TaskHolder.quest_budget = 60
	TaskHolder.quest_allow_far_shop = false
	TaskHolder.quest_result = ""
	
	d.purchases.current_period = []
	
	# сохраняем в ПРОФИЛЬ
	d.economy["saved_balance"] = int(d.economy.get("balance", 0))
	d.economy["quest_wallet"] = 60
	d.economy["quest_target"] = ""
	d.economy["quest_from"] = ""
	d.economy["quest_bought_optional"] = false
	
	d.economy.balance = 60
	ProfileManager.save_profile()
	
	ScreenManager.go_to("res://scenes/screens/Shop.tscn")

func _process(delta: float) -> void:
	if not is_typing:
		return
	
	typewriter_progress += delta / typewriter_speed
	var visible_chars := int(typewriter_progress)
	
	if visible_chars >= full_text.length():
		text_label.text = full_text
		is_typing = false
		_on_typing_finished()
	else:
		text_label.text = full_text.substr(0, visible_chars)

func _on_typing_finished() -> void:
	# когда текст допечатался — включаем ожидание тапа или показываем выборы
	var step: Dictionary = steps[current_step]
	var type: String = step.get("type", "line")
	if type == "choice" and step.has("choices"):
		waiting_for_tap = false
		tap_hint.visible = false
		_show_choices(step)
	else:
		waiting_for_tap = true
		tap_hint.visible = true

func _show_choices(step: Dictionary) -> void:
	for choice in step.choices:
		var btn := Button.new()
		btn.text = choice.text
		btn.custom_minimum_size = Vector2(280, 56)
		btn.modulate = Color(1, 1, 1, 0.9)
		btn.pressed.connect(_on_choice.bind(choice))
		choices_area.add_child(btn)
		


func _animate_name() -> void:
	name_label.modulate = Color(1, 1, 1, 0)
	name_label.scale = Vector2(0.9, 0.9)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(name_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(name_label, "scale", Vector2(1.0, 1.0), 0.2)

func _on_choice(choice: Dictionary) -> void:
	if bool(choice.get("abort", false)):
		# отказ — просто выход, без зачёта задания
		_return_from_abort()
		return
		
	var next := int(choice.get("next", -1))
	if next == -1:
		_finish_task()
	else:
		_show_step(next)

func _return_from_abort() -> void:
	var d := ProfileManager.data
	if int(d.economy.get("quest_wallet", -1)) >= 0:
		d.economy.balance = int(d.economy.get("saved_balance", d.economy.balance))
		d.economy["saved_balance"] = 0
		d.economy["quest_wallet"] = -1
		d.economy["quest_target"] = ""
		d.economy["quest_from"] = ""
		d.economy["quest_bought_optional"] = false
		ProfileManager.save_profile()
	
	TaskHolder.quest_active = false
	TaskHolder.quest_shop_target = ""
	TaskHolder.quest_result = ""
	
	match TaskHolder.entry_point:
		"shopselect":
			ScreenManager.go_to("res://scenes/screens/ShopSelect.tscn")
		_:
			ScreenManager.go_to("res://scenes/screens/Tasks.tscn")
	
	TaskHolder.entry_point = "tasks"

func _input(event: InputEvent) -> void:
	if is_typing and event is InputEventMouseButton and event.pressed:
		# мгновенно допечатать
		text_label.text = full_text
		is_typing = false
		_on_typing_finished()
		get_viewport().set_input_as_handled()
		return
	
	if not waiting_for_tap:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	var step: Dictionary = steps[current_step]
	if step.has("action"):
		_run_action(step.action)
		return
	if step.has("next"):
		_show_step(int(step.next))
	else:
		_show_step(current_step + 1)

func _finish_task() -> void:
	var d := ProfileManager.data
	var cost := int(task.get("energy", 0))
	var reward := int(task.get("reward", 0))
	var exp_reward := int(task.get("exp", 0))
	
	# восстановление баланса — ОДИН РАЗ
	if int(d.economy.get("quest_wallet", -1)) >= 0:
		d.economy.balance = int(d.economy.get("saved_balance", d.economy.balance))
		d.economy["saved_balance"] = 0
		d.economy["quest_wallet"] = -1
		d.economy["quest_target"] = ""
		d.economy["quest_from"] = ""
		d.economy["quest_bought_optional"] = false
		TaskHolder.quest_active = false
		TaskHolder.quest_shop_target = ""
	
	# списание энергии — ОДИН РАЗ
	d.pet.state.energy = clampi(int(d.pet.state.energy) - cost, 0, 100)
	
	# награда
	var already_done := false
	for entry in d.tasks.completed:
		if str(entry.get("task_id", "")) == str(task.get("id", "")):
			already_done = true
			break
	
	if not already_done:
		d.economy.balance += reward
		d.economy.income_log.append({
			"source": "task_%s" % task.get("id", ""),
			"amount": reward,
			"at": Time.get_datetime_string_from_system()
		})
		d.tasks.completed.append({
			"task_id": str(task.get("id", "")),
			"result": "done",
			"at": Time.get_datetime_string_from_system()
		})
		if task.has("topic"):
			d.tasks.topic_progress[task.topic] = int(d.tasks.topic_progress.get(task.topic, 0)) + 1
		if exp_reward > 0:
			Economy.add_stage_exp(exp_reward)
	
	# разблокировки
	if str(task.get("id", "")) == "task_1_1":
		Economy.unlock_after_intro()
	if str(task.get("id", "")) == "task_1_2":
		ProfileManager.data.progress.shop_quest_done = true
		ProfileManager.data.progress.sleep_unlocked = true
		ProfileManager.data.progress.budget_unlocked = true
	if str(task.get("id", "")) == "task_1_3":
		ProfileManager.data.progress.price_quest_done = true
		ProfileManager.data.progress.far_shop_unlocked = true
	if str(task.get("id", "")) == "task_2_1":
		ProfileManager.data.progress.savings_quest_done = true
		ProfileManager.data.progress.savings_unlocked = true
	if str(task.get("id", "")) == "task_2_2":
		ProfileManager.data.progress.bank_quest_done = true
		ProfileManager.data.progress.bank_unlocked = true
	
	d.tasks.completed_today = int(d.tasks.completed_today) + 1
	ProfileManager.save_profile()
	
	ScreenManager.go_to("res://scenes/screens/Tasks.tscn")

func _show_quest_result(result: String) -> void:
	match result:
		"mix":
			steps = [
				{ "type": "line", "speaker": "cat", "text": "О, ты пришёл. Вижу, купил всё необходимое и даже для себя что-то взял. Молодец, сын." },
				{ "type": "line", "speaker": "cat", "text": "Но помни: если тратить всё, что у тебя есть, ты не сможешь накопить на свою цель. Не забывай немного откладывать." }
			]
		"only_mandatory":
			steps = [
				{ "type": "line", "speaker": "cat", "text": "О, ты пришёл. Вижу, купил всё необходимое и даже ни копейки на себя не потратил. Молодец, сын." },
				{ "type": "line", "speaker": "cat", "text": "Но помни: если всё время так копить, тебе это быстро наскучит. Не забывай немного и на себя тратить." }
			]
		"fail_mandatory":
			steps = [
				{ "type": "line", "speaker": "cat", "text": "О, ты пришёл. Ну что, где там продукты? Что не купил?" },
				{ "type": "line", "speaker": "kitten", "text": "Да..." },
				{ "type": "line", "speaker": "cat", "text": "Да как так? А что мы будем сегодня есть тогда?" },
				{ "type": "line", "speaker": "kitten", "text": "Извини, пап, я даже об этом не подумал." },
				{ "type": "line", "speaker": "cat", "text": "Эх. Если все деньги потратить на необязательное, ты и на мечту не накопишь, и голодным останешься. Сначала — необходимое, потом — желаемое." },
				{ "type": "line", "speaker": "kitten", "text": "Хорошо, понял тебя, пап." },
				{ "type": "line", "speaker": "cat", "text": "Давай попробуем ещё раз.", "action": "restart_shop_quest" }
			]
		"price_saved":
			steps = [
				{ "type": "line", "speaker": "cat", "text": "О, ты пришёл. Вижу, купил еду." },
				{ "type": "line", "speaker": "kitten", "text": "Да, пап, я сравнил цены и сэкономил." },
				{ "type": "line", "speaker": "cat", "text": "Ха-ха, молодец! Сравнивать цены и купить то же дешевле — отличная идея." }
			]
		"price_saved_optional":
			steps = [
				{ "type": "line", "speaker": "cat", "text": "О, ты пришёл. Вижу, купил еду и даже для себя что-то взял." },
				{ "type": "line", "speaker": "kitten", "text": "Да, пап, я ходил туда-сюда и смог кое-что себе купить." },
				{ "type": "line", "speaker": "cat", "text": "Ого, какой экономный! Сравнивать цены — отличная идея. Но и про накопления не забывай." }
			]
		"price_not_saved":
			steps = [
				{ "type": "line", "speaker": "cat", "text": "О, ты пришёл. Вижу, еду купил. Смог сэкономить?" },
				{ "type": "line", "speaker": "kitten", "text": "Нет, пап. Купил в ближайшем магазине." },
				{ "type": "line", "speaker": "cat", "text": "Ну ладно. Но ты мог бы и сэкономить. Иногда полезно сравнить цены." },
				{ "type": "line", "speaker": "kitten", "text": "Хорошо, понял тебя, пап." }
			]
		"safety_ok":
			steps = [
				{ "type": "line", "speaker": "kitten", "text": "Думаю... поставлю столько монет. Так же делают разумные котята?" },
				{ "type": "line", "speaker": "cat", "text": "Молодец! Даже немного монет — это уже защита. Главное — делать это каждый раз, когда получаешь деньги." },
				{ "type": "line", "speaker": "kitten", "text": "Понял! Теперь у меня две копилки: цель и подушка." },
				{ "type": "line", "speaker": "cat", "text": "Именно. И когда что-то случится, ты не растеряешься. Ты уже готов." }
			]
		"safety_zero":
			steps = [
				{ "type": "line", "speaker": "cat", "text": "Ты всё на аквариум?" },
				{ "type": "line", "speaker": "kitten", "text": "Да, думаю, что не понадобится." },
				{ "type": "line", "speaker": "cat", "text": "Понимаю. Но жизнь непредсказуема. Если заболеешь, придётся взять из аквариума. Цель станет дальше." },
				{ "type": "line", "speaker": "kitten", "text": "Нет, думаю, я не заболею." },
				{ "type": "line", "speaker": "cat", "text": "Хорошо. Но если заболеешь, вспомни мои слова и извлеки урок." },
				{ "type": "line", "speaker": "kitten", "text": "Хорошо, пап!" }
			]
		"bank_ok":
			steps = [
				{ "type": "line", "speaker": "kitten", "text": "Я распределил деньги, пап. Часть в банке, а другая в копилке." },
				{ "type": "line", "speaker": "cat", "text": "Молодец, сын. Теперь если что-то случится, у тебя деньги будут и в копилке, и в банке." },
				{ "type": "line", "speaker": "kitten", "text": "Да, а в банке мне ещё добавят монет за то, что я у них держу свои монетки." },
				{ "type": "line", "speaker": "cat", "text": "Тоже верно, тем более это ещё и надёжно." },
				{ "type": "line", "speaker": "kitten", "text": "Теперь моя подушка в безопасности!" }
			]
		"bank_zero":
			steps = [
				{ "type": "line", "speaker": "kitten", "text": "Пап, я решил положить все свои монеты в копилку." },
				{ "type": "line", "speaker": "cat", "text": "А что будет, если копилка упадёт?" },
				{ "type": "line", "speaker": "kitten", "text": "Наверное, монеты рассыплются..." },
				{ "type": "line", "speaker": "cat", "text": "И что тогда?" },
				{ "type": "line", "speaker": "kitten", "text": "Монеты могут пропасть. И если я заболею — нечем будет лечиться." },
				{ "type": "line", "speaker": "cat", "text": "Верно. Может, тогда попробуем положить часть в банк?" },
				{ "type": "line", "speaker": "kitten", "text": "Эм-м, хорошо!" }
			]
		"budget_ok":
			steps = [
				{ "type": "line", "speaker": "cat", "text": "Всё закончил?" },
				{ "type": "line", "speaker": "kitten", "text": "Да, готово, посмотри." },
				{ "type": "line", "speaker": "cat", "text": "Хм. Всё верно, сынок. Молодец. Теперь ты стал на шаг ближе к самостоятельности." },
				{ "type": "line", "speaker": "kitten", "text": "Спасибо, пап!" }
			]
		"budget_fail":
			steps = [
				{ "type": "line", "speaker": "kitten", "text": "Готово, пап, посмотри." },
				{ "type": "line", "speaker": "cat", "text": "Хм, суммы обязательных расходов тебе не хватит на неделю." },
				{ "type": "line", "speaker": "kitten", "text": "Почему?" },
				{ "type": "line", "speaker": "cat", "text": "Молоко стоит 1 монету. Если сложить 1 монету 7 раз — 7 монет. А у тебя меньше. Что будет, если не поешь?" },
				{ "type": "line", "speaker": "kitten", "text": "Я буду голодным. И грустным." },
				{ "type": "line", "speaker": "cat", "text": "Верно. Что нужно исправить?" },
				{ "type": "line", "speaker": "kitten", "text": "Сначала положить на обязательное. Потом — на накопления. И только потом — на игрушки.", "action": "restart_budget_quest" }
			]
	
	TaskHolder.quest_result = ""    # сбрасываем после показа
	TaskHolder.quest_shop_target = "" 
	_show_step(0)

func _run_action(action: String) -> void:
	match action:
		"start_shop_quest":
			_start_shop_quest()
		"restart_shop_quest":
			_restart_shop_quest()
		"start_price_quest":
			_start_price_quest()
		"start_safety_quest":
			_start_safety_quest()
		"start_bank_quest":
			_start_bank_quest()
		"start_budget_quest":
			_start_budget_quest()
		"restart_budget_quest":
			_restart_budget_quest()

func _start_budget_quest() -> void:
	var d := ProfileManager.data
	
	TaskHolder.quest_active = true
	TaskHolder.quest_type = "budget"
	
	d.economy["saved_balance"] = int(d.economy.get("balance", 0))
	d.economy["quest_wallet"] = 100
	d.economy.balance = 100
	
	d.budget.planned = { "mandatory": 0, "optional": 0, "savings": 0 }
	ProfileManager.save_profile()
	
	TaskHolder.entry_point = "tasks"
	ScreenManager.go_to("res://scenes/screens/Budget.tscn")

func _restart_budget_quest() -> void:
	var d := ProfileManager.data
	d.economy.balance = 100
	d.budget.planned = { "mandatory": 0, "optional": 0, "savings": 0 }
	ProfileManager.save_profile()
	
	TaskHolder.quest_active = true
	TaskHolder.quest_type = "budget"
	ScreenManager.go_to("res://scenes/screens/Budget.tscn")


func _start_bank_quest() -> void:
	var d := ProfileManager.data
	
	TaskHolder.quest_active = true
	TaskHolder.quest_type = "bank"
	TaskHolder.quest_bank_start = int(d.economy.get("bank", 0))
	
	ProfileManager.save_profile()
	TaskHolder.entry_point = "tasks"
	ScreenManager.go_to("res://scenes/screens/Goal.tscn")

func _start_safety_quest() -> void:
	var d := ProfileManager.data
	
	TaskHolder.quest_active = true
	TaskHolder.quest_type = "safety"           # тип задания
	TaskHolder.quest_safety_start = int(d.economy.get("safety", 0))  # сколько было до
	
	ProfileManager.save_profile()
	
	TaskHolder.entry_point = "tasks"
	ScreenManager.go_to("res://scenes/screens/Goal.tscn")

func _restart_shop_quest() -> void:
	var d := ProfileManager.data
	d.purchases.current_period = []
	var wallet: int = int(d.economy.get("quest_wallet", 60))
	if wallet <= 0:
		wallet = 60
	d.economy.balance = wallet
	d.economy["quest_from"] = ""
	d.economy["quest_bought_optional"] = false
	ProfileManager.save_profile()
	
	TaskHolder.quest_active = true
	ScreenManager.go_to("res://scenes/screens/Shop.tscn")

func _start_price_quest() -> void:
	var d := ProfileManager.data
	
	TaskHolder.quest_active = true
	TaskHolder.quest_shop_target = "food_basic"
	TaskHolder.quest_shop_budget = 40
	TaskHolder.quest_shop_from = ""
	TaskHolder.quest_shop_bought_optional = false
	TaskHolder.quest_allow_far_shop = true
	TaskHolder.quest_items = ["food_basic", "food_basic"]
	
	d.purchases.current_period = []
	
	d.economy["saved_balance"] = int(d.economy.get("balance", 0))
	d.economy["quest_wallet"] = 40
	d.economy["quest_target"] = "food_basic"
	d.economy["quest_from"] = ""
	d.economy["quest_bought_optional"] = false
	
	d.economy.balance = 40
	ProfileManager.save_profile()
	
	ScreenManager.go_to("res://scenes/screens/ShopSelect.tscn")
