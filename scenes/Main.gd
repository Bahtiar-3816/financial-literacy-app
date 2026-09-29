extends Control

@onready var holder: Control = $ScreenHolder
@onready var fade: ColorRect = $FadeOverlay

func _ready() -> void:
	fade.modulate.a = 0.0
	ScreenManager.register_holder(holder)
	ScreenManager.register_fade(fade)
	_go_to_start_screen()

func _go_to_start_screen() -> void:
	var d := ProfileManager.data
	
	# питомец ещё не создан?
	if str(d.pet.name) == "":
		ScreenManager.go_to("res://scenes/screens/Welcome.tscn")
		return
	
	# есть незавершённое задание (в магазине)?
	var quest_wallet: int = int(d.economy.get("quest_wallet", -1))
	if quest_wallet >= 0:
		# восстановить TaskHolder и открыть магазин
		TaskHolder.quest_active = true
		TaskHolder.quest_shop_target = str(d.economy.get("quest_target", ""))
		TaskHolder.quest_shop_budget = quest_wallet
		TaskHolder.quest_shop_from = str(d.economy.get("quest_from", ""))
		TaskHolder.quest_shop_bought_optional = bool(d.economy.get("quest_bought_optional", false))
		ScreenManager.go_to("res://scenes/screens/Shop.tscn")
		return
	
	# есть непросмотренный итог дня?
	if not d.budget.pending_result.is_empty():
		ScreenManager.go_to("res://scenes/screens/DayResult.tscn")
		return
	
	# питомец спит?
	if bool(d.pet.is_sleeping):
		ScreenManager.go_to("res://scenes/screens/Sleep.tscn")
		return
	
	ScreenManager.go_to("res://scenes/screens/Home.tscn")








#
