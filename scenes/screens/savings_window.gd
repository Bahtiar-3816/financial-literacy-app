extends Control

@onready var panel: PanelContainer = $Panel
@onready var bank_sum: Label = $Panel/MarginContainer/VBoxContainer/BankSection/VBoxContainer/BankSum
@onready var bank_interest: Label = $Panel/MarginContainer/VBoxContainer/BankSection/VBoxContainer/BankInterest
@onready var bank_limit: Label = $Panel/MarginContainer/VBoxContainer/BankSection/VBoxContainer/BankLimit
@onready var piggy_sum: Label = $Panel/MarginContainer/VBoxContainer/PiggySection/VBoxContainer/PiggySum
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonClose

var panel_closed_y: float = 0.0

func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	_connect_buttons()
	refresh()
	
	await get_tree().process_frame
	panel_closed_y = panel.position.y
	
	var bank_panel: PanelContainer = $Panel/MarginContainer/VBoxContainer/BankSection
	var bank_unlocked: bool = bool(ProfileManager.data.progress.get("bank_unlocked", false))
	var in_safety_quest: bool = TaskHolder.quest_active and TaskHolder.quest_type == "safety"
	var in_bank_quest: bool = TaskHolder.quest_active and TaskHolder.quest_type == "bank"
	
	var show_bank := false
	if in_safety_quest:
		show_bank = false
	elif in_bank_quest:
		show_bank = true
	elif bank_unlocked:
		show_bank = true
	
	bank_panel.visible = show_bank

func _connect_buttons() -> void:
	# банк — плюсы
	$Panel/MarginContainer/VBoxContainer/BankSection/VBoxContainer/HBoxContainer/Button10.pressed.connect(func(): _add_bank(10))
	$Panel/MarginContainer/VBoxContainer/BankSection/VBoxContainer/HBoxContainer/Button20.pressed.connect(func(): _add_bank(20))
	$Panel/MarginContainer/VBoxContainer/BankSection/VBoxContainer/HBoxContainer/Button30.pressed.connect(func(): _add_bank(30))
	$Panel/MarginContainer/VBoxContainer/BankSection/VBoxContainer/HBoxContainer/ButtonWithdraw.pressed.connect(_withdraw_bank)
# копилка — плюсы
	$Panel/MarginContainer/VBoxContainer/PiggySection/VBoxContainer/HBoxContainer/Button10.pressed.connect(func(): _add_piggy(10))
	$Panel/MarginContainer/VBoxContainer/PiggySection/VBoxContainer/HBoxContainer/Button20.pressed.connect(func(): _add_piggy(20))
	$Panel/MarginContainer/VBoxContainer/PiggySection/VBoxContainer/HBoxContainer/Button30.pressed.connect(func(): _add_piggy(30))
	$Panel/MarginContainer/VBoxContainer/PiggySection/VBoxContainer/HBoxContainer/ButtonWithdraw.pressed.connect(_withdraw_piggy)

func refresh() -> void:
	var d := ProfileManager.data
	var bank: int = int(d.economy.get("bank", 0))
	var safety: int = int(d.economy.get("safety", 0))
	var limit := Economy.get_bank_limit()
	
	bank_sum.text = "Накопления: %d" % bank
	bank_interest.text = "10%% завтра принесёт: %d" % int(round(bank * 0.10))
	bank_limit.text = "Лимит: %d/%d" % [bank, limit]
	piggy_sum.text = "Подушка безопасности: %d" % safety

func open() -> void:
	refresh()
	visible = true
	
	# сдвигаем вниз от исходной позиции
	panel.position.y = panel_closed_y + 500
	panel.modulate = Color(1, 1, 1, 0)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "position:y", panel_closed_y, 0.3)

func close() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.tween_property(panel, "position:y", panel_closed_y + 500, 0.25)
	tween.chain().tween_callback(func(): visible = false)

func _add_bank(amount: int) -> void:
	if not Economy.add_to_bank(amount):
		_show_message("Недостаточно монет\nили превышен лимит банка.")
		return
	refresh()

func _withdraw_bank() -> void:
	var bank: int = int(ProfileManager.data.economy.get("bank", 0))
	if bank <= 0:
		return
	if Economy.withdraw_from_bank(bank, true):
		refresh()

func _add_piggy(amount: int) -> void:
	var d := ProfileManager.data
	if not Economy.can_afford(amount):
		_show_message("Недостаточно монет.")
		return
	d.economy.balance -= amount
	d.economy["safety"] = int(d.economy.get("safety", 0)) + amount
	ProfileManager.save_profile()
	refresh()

func _withdraw_piggy() -> void:
	var d := ProfileManager.data
	var safety: int = int(d.economy.get("safety", 0))
	if safety <= 0:
		return
	d.economy.balance += safety
	d.economy["safety"] = 0
	ProfileManager.save_profile()
	refresh()

func _show_message(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
