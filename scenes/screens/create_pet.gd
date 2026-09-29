extends Control

var selected_body := ""
var selected_color := ""

@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/PetNameInput
@onready var ready_button: Button = $MarginContainer/VBoxContainer/Button
@onready var pet_image: TextureRect = $MarginContainer/VBoxContainer/PetImage

const SPRITES := {
	"round": "res://sprites/sprites_child/котенок_1.png",
	"angular": "res://sprites/sprites_child/котенок_2.png",
	"slim": "res://sprites/sprites_child/котенок_3.png"
}


func _ready() -> void:
	ready_button.disabled = true

func _on_body_pressed(body_id: String) -> void:
	selected_body = body_id
	ready_button.disabled = false
	_update_preview()

func _update_preview() -> void:
	if selected_body == "":
		pet_image.texture = null
		return
	var path: String = SPRITES[selected_body]
	if ResourceLoader.exists(path):
		pet_image.texture = PetVisual.get_texture(selected_body, "kitten")
		pet_image.modulate = PetVisual.get_color(selected_color)

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
