extends Control

@onready var pet_image: TextureRect = $MarginContainer/VBoxContainer/PetImage
@onready var timer_label: Label = $MarginContainer/VBoxContainer/LabelTimer
@onready var title_label: Label = $MarginContainer/VBoxContainer/LabelTitle
@onready var progress: ProgressBar = $MarginContainer/VBoxContainer/Progress
@onready var skip_button: Button = $MarginContainer/VBoxContainer/ButtonSkip

const SLEEP_NORMAL := 10   # должно быть 3600
const SLEEP_DEMO := 3

const DOT_SEQUENCE: Array[int] = [1, 2, 3, 4, 3, 2]   # точки по кругу
const DOT_INTERVAL := 0.5                   # секунда на смену

var sleep_duration := SLEEP_NORMAL
var dot_timer := 0.0
var dot_index := 0

func _ready() -> void:
	PetVisual.apply(pet_image, "kitten")
	var is_demo: bool = bool(ProfileManager.data.meta.get("demo_mode", false))
	if is_demo:
		sleep_duration = SLEEP_DEMO
		skip_button.visible = true
		skip_button.pressed.connect(_finish_sleep)
	else:
		sleep_duration = SLEEP_NORMAL
		skip_button.visible = false
	
	if ProfileManager.data.meta.demo_mode:
		sleep_duration = SLEEP_DEMO
		skip_button.visible = true
		skip_button.pressed.connect(_finish_sleep)
	else:
		skip_button.visible = false
	
	var d := ProfileManager.data
	if not d.pet.is_sleeping:
		d.pet.is_sleeping = true
		d.pet.sleep_started_at = str(Time.get_unix_time_from_system())
		ProfileManager.save_profile()
	else:
		# сон уже идёт — проверим, не закончился ли
		var started: float = float(d.pet.sleep_started_at)
		var elapsed := Time.get_unix_time_from_system() - started
		if elapsed >= sleep_duration:
			_finish_sleep()
			return
	
	_update_dots()

func _process(delta: float) -> void:
	_tick_timer()
	_tick_dots(delta)
	
	

func _tick_timer() -> void:
	var d := ProfileManager.data
	var started: float = float(d.pet.sleep_started_at)
	var elapsed := Time.get_unix_time_from_system() - started
	var left := maxf(sleep_duration - elapsed, 0.0)
	
	progress.value = clamp(elapsed / sleep_duration, 0.0, 1.0)
	timer_label.text = _format_time(left)
	
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 500.0)
	progress.modulate = Color(1, 1, 1, pulse)
	
	if elapsed >= sleep_duration:
		_finish_sleep()

func _tick_dots(delta: float) -> void:
	dot_timer += delta
	if dot_timer >= DOT_INTERVAL:
		dot_timer = 0.0
		dot_index = (dot_index + 1) % DOT_SEQUENCE.size()
		_update_dots()

func _update_dots() -> void:
	var count := int(DOT_SEQUENCE[dot_index])
	title_label.text = "Питомец спит" + ".".repeat(count)

func _format_time(seconds: float) -> String:
	var s := int(seconds)
	@warning_ignore("integer_division")
	var m := s / 60
	var sec := s % 60
	return "%02d:%02d" % [m, sec]

func _finish_sleep() -> void:
	var d := ProfileManager.data
	
	# считаем итог, но пока не применяем
	var result := _calculate_day_result()
	d.budget.pending_result = result
	d.budget.pending_day = int(d.budget.current_period)
	
	# сбрасываем сон
	d.pet.is_sleeping = false
	d.pet.sleep_started_at = ""
	d.pet.state.energy = 100
	d.tasks.completed_today = 0
	ProfileManager.save_profile()
	
	ScreenManager.go_to("res://scenes/screens/DayResult.tscn")

func _calculate_day_result() -> Dictionary:
	var d := ProfileManager.data
	var planned: Dictionary = d.budget.planned
	var actual: Dictionary = d.budget.actual
	
	var match_mandatory: bool = int(actual.mandatory) == int(planned.mandatory)
	var match_optional: bool = int(actual.optional) == int(planned.optional)
	
	# опыт только если оба совпали
	var exp_reward: int = 10 if (match_mandatory and match_optional) else 0
	
	# заработал сам за день
	var earned_today: int = int(d.economy.get("day_earnings", 0))
	
	# доход дня (периода)
	var period_income: int = int(d.economy.get("period_income", 100))
	
	return {
		"match_mandatory": match_mandatory,
		"match_optional": match_optional,
		"exp_reward": exp_reward,
		"earned_today": earned_today,
		"period_income": period_income,
		"hunger": -40
	}
