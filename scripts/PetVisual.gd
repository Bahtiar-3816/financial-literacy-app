extends Node

const SPRITES := {
	"round":   { "kitten": "res://sprites/sprites_child/котенок_1.png",    "cat": "res://sprites/sprites_adult/кот_1.png" },
	"angular": { "kitten": "res://sprites/sprites_child/котенок_2.png",    "cat": "res://sprites/sprites_adult/кот_2.png" },
	"slim":    { "kitten": "res://sprites/sprites_child/котенок_3.png",    "cat": "res://sprites/sprites_adult/кот_3.png" }
}

# заглушка, пока нет картинок
const FALLBACK := "res://sprites/icon.svg"

func get_texture(body: String, age: String = "kitten") -> Texture2D:
	var path := FALLBACK
	if SPRITES.has(body) and SPRITES[body].has(age):
		path = SPRITES[body][age]
	if not ResourceLoader.exists(path):
		path = FALLBACK
	return load(path)

func get_color(color_id: String) -> Color:
	match color_id:
		"blue":   return Color(0.4, 0.7, 1.0)
		"green":  return Color(0.5, 0.9, 0.5)
		"orange": return Color(1.0, 0.7, 0.4)
		_:        return Color.WHITE

func apply(texture_rect: TextureRect, age: String = "kitten") -> void:
	var d := ProfileManager.data
	texture_rect.texture = get_texture(d.pet.appearance.body, age)
	texture_rect.modulate = get_color(d.pet.appearance.color)
