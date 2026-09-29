extends Control

var selected_body := "round"
var selected_color := "blue"

@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/PetNameInput
@onready var ready_button: Button = $MarginContainer/VBoxContainer/Button
@onready var pet_image: TextureRect = $MarginContainer/VBoxContainer/PetImage

const SPRITES := {
	"round": {
		"blue":  "res://sprites/kitten/1_kitten/1_kitten_default.png",
		"green": "res://sprites/kitten/1_kitten/1_kitten_grey.png",
		"orange": "res://sprites/kitten/1_kitten/1_kitten_pink.png"
	},
	"angular": {
		"blue":  "res://sprites/kitten/2_kitten/2_kitten_defualt.png",
		"green": "res://sprites/kitten/2_kitten/2_kitten_grey.png",
		"orange": "res://sprites/kitten/2_kitten/2_kitten_pink.png"
	},
	"slim": {
		"blue": "res://sprites/kitten/3_kitten/3_kitten_default.png",
		"green": "res://sprites/kitten/3_kitten/3_kitten_grey.png",
		"orange": "res://sprites/kitten/3_kitten/3_kitten_pink.png"
	}
}


func _ready() -> void:
	ready_button.disabled = false
	_update_preview()     

func _on_body_pressed(body_id: String) -> void:
	selected_body = body_id
	ready_button.disabled = false
	_update_preview()

func _update_preview() -> void:
	if not SPRITES.has(selected_body):
		return
	if not SPRITES[selected_body].has(selected_color):
		return
	
	var path: String = SPRITES[selected_body][selected_color]
	if ResourceLoader.exists(path):
		pet_image.texture = load(path)

func _on_color_pressed(color_id: String) -> void:
	selected_color = color_id
	_update_preview()

func _on_ready_pressed() -> void:
	if selected_body == "":
		return
		
	var pet_name := name_input.text.strip_edges()
	if pet_name == "":
		pet_name = "Финник"  # имя по умолчанию, если пусто
	
	ProfileManager.data.pet.name = pet_name
	ProfileManager.data.pet.appearance.body = selected_body
	ProfileManager.data.pet.appearance.color = selected_color
	ProfileManager.save_profile()
	
	ScreenManager.go_to("res://scenes/screens/Home.tscn")
