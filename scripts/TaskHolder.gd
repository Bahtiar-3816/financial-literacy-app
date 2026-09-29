extends Node

var current_task: Dictionary = {}

var shop_mode := "near"

# Режим задания «поход в магазин»
var quest_active := false          # идёт ли задание «поход в магазин»
var quest_items: Array = []        # список обязательных товаров (id)
var quest_budget: int = 60          # сколько монет выдано
var quest_allow_far_shop := false  # доступен ли дальний магазин
var quest_result := ""
var quest_wallet := 0            # монеты, выданные на задание
var saved_balance := 0           # баланс ребёнка до задания
var quest_purchases: Array = []

var quest_shop_target := ""       # id товара, который обязательно купить (food_basic)
var quest_shop_budget := 40        # сколько выдано монет
var quest_shop_from := ""         # "" | "near" | "far" — где куплено
var quest_shop_bought_optional := false  # купил ли необязательное
var entry_point := "tasks"   # "tasks" | "shopselect" | "home"
var quest_type := ""             # "" | "shop" | "price" | "safety"
var quest_safety_start := 0      # safety до задания
var quest_bank_start := 0
