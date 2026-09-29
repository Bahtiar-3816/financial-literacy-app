extends Node

const SPRITES := {
	"kitten": {
		"round": {
			"blue": "res://sprites/kitten/1_kitten/1_kitten_default.png",
			"green": "res://sprites/kitten/1_kitten/1_kitten_grey.png",
			"orange": "res://sprites/kitten/1_kitten/1_kitten_pink.png"
		},
		"angular": {
			"blue": "res://sprites/kitten/2_kitten/2_kitten_defualt.png",
			"green": "res://sprites/kitten/2_kitten/2_kitten_grey.png",
			"orange": "res://sprites/kitten/2_kitten/2_kitten_pink.png",
		},
		"slim": {
			"blue": "res://sprites/kitten/3_kitten/3_kitten_default.png",
			"green": "res://sprites/kitten/3_kitten/3_kitten_grey.png",
			"orange": "res://sprites/kitten/3_kitten/3_kitten_pink.png"
		}
	},
	
	"cat": {
		"round": {
			"blue": "res://sprites/cat/cat_1/1_cat_defualt.png",
			"green": "res://sprites/cat/cat_1/1_cat_grey.png",
			"orange": "res://sprites/cat/cat_1/1_cat_pink.png"
		},
		"angular": {
			"blue": "res://sprites/cat/cat_1/1_cat_defualt.png",
			"green": "res://sprites/cat/cat_1/1_cat_grey.png",
			"orange": "res://sprites/cat/cat_1/1_cat_pink.png"
		},
		"slim": {
			"blue": "res://sprites/cat/cat_2/2_cat_default.png",
			"green": "res://sprites/cat/cat_2/2_cat_grey.png",
			"orange": "res://sprites/cat/cat_2/2_cat_pink.png"
		}
	}

}

	#"round": {
		#"blue":  "res://sprites/kitten/1_kitten/1_kitten_default.png",
		#"green": "res://sprites/kitten/1_kitten/1_kitten_grey.png",
		#"orange": "res://sprites/kitten/1_kitten/1_kitten_pink.png"
	#},
	#"angular": {
		#"blue":  "res://sprites/kitten/2_kitten/2_kitten_defualt.png",
		#"green": "res://sprites/kitten/2_kitten/2_kitten_grey.png",
		#"orange": "res://sprites/kitten/2_kitten/2_kitten_pink.png"
	#},
	#"slim": {
		#"blue": "res://sprites/kitten/3_kitten/3_kitten_default.png",
		#"green": "res://sprites/kitten/3_kitten/3_kitten_grey.png",
		#"orange": "res://sprites/kitten/3_kitten/3_kitten_pink.png"
	#}
#}


# заглушка, пока нет картинок
const FALLBACK := "res://sprites/icon.svg"

func get_texture(age: String = "kitten") -> Texture2D:
	var d := ProfileManager.data
	var body: String = str(d.pet.appearance.get("body", "round"))
	var color: String = str(d.pet.appearance.get("color", "blue"))
	
	if SPRITES.has(age) and SPRITES[age].has(body) and SPRITES[age][body].has(color):
		var path: String = SPRITES[age][body][color]
		if ResourceLoader.exists(path):
			return load(path)
	
	return load(FALLBACK)

func apply(texture_rect: TextureRect, age: String = "kitten") -> void:
	texture_rect.texture = get_texture(age)
	texture_rect.modulate = Color.WHITE

func get_color(color_id: String) -> Color:
	match color_id:
		"blue":   return Color(0.4, 0.7, 1.0)
		"green":  return Color(0.5, 0.9, 0.5)
		"orange": return Color(1.0, 0.7, 0.4)
		_:        return Color.WHITE
