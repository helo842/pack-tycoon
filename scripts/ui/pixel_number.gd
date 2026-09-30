# PixelNumber - numeros con los sprites num_*.png
#
# Los digitos son imagenes, no una fuente de Godot: cada glifo es una celda de
# 8x12 pixeles de arte escalada x8 (64x96 px de textura). Cada celda lleva su
# contorno, asi que la celda entera es el avance y la "tinta" de dentro (arte
# x 1..5, y 2..8, mas el contorno) es lo que se ve de verdad:
#
#     textura 64x96
#     +--------------------+
#     |  x..x              |  <- arte y=1 con el contorno de arriba
#     | .xxxx.  arte x 1..5 |     arte y=2..8
#     | ...       ...      |
#     +--------------------+
#     ^ 8 px de aire arriba, 16 px abajo
#
# El control mide lo que ocupa la TINTA (72 px de alto a escala 1) y coloca las
# celdas desplazadas hacia arriba para que quede centrado. Asi el que lo llama
# puede centrarlo con la normal sin tener que compensarlo a mano.
class_name PixelNumber
extends Control

const GLYPHS := {
	"0": "num_0", "1": "num_1", "2": "num_2", "3": "num_3", "4": "num_4",
	"5": "num_5", "6": "num_6", "7": "num_7", "8": "num_8", "9": "num_9",
	",": "num_comma", ".": "num_period", "-": "num_minus",
	"+": "num_plus", "%": "num_percent",
}

const CELL := Vector2(64.0, 96.0)     # tamaño de cada num_*.png
const INK_TOP := 8.0                 # px de textura hasta el primer pixel de tinta
const INK_HEIGHT := 72.0             # alto de la tinta dentro de la celda
const MIN_SCALE := 0.10

@export var scale_factor: float = 0.5
@export var color: Color = Color.WHITE
@export var shadow: bool = true
## Si es mayor que 0, el numero se encoge lo justo para caber en ese ancho.
@export var max_width: float = 0.0

var _text: String = ""
var _scale_used: float = 0.5


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


func set_text(value: String) -> void:
	if value == _text:
		return
	_text = value
	_rebuild()


func set_number(value: int) -> void:
	set_text(PixelNumber.format(value))


func get_text() -> String:
	return _text


## "1234567" -> "1.234.567". El separador es PUNTO, no coma: el juego esta en
## espanol y "874,000" se leia como un numero mal escrito. La fuente tiene los
## dos signos (num_comma y num_period) asi que el cambio es solo de aqui.
static func format(value: int) -> String:
	var neg := value < 0
	var s := str(absi(value))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return ("-" + out) if neg else out


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var s := scale_factor
	if max_width > 0.0:
		var needed := float(_text.length()) * CELL.x * s
		if needed > max_width:
			s = maxf(MIN_SCALE, max_width / (float(_text.length()) * CELL.x))
	_scale_used = s

	for i in _text.length():
		var ch := _text[i]
		if not GLYPHS.has(ch):
			continue
		if shadow:
			_add_glyph(GLYPHS[ch], i, s, Palette.OUTLINE, s * 6.0, s * 6.0)
		_add_glyph(GLYPHS[ch], i, s, color, 0.0, 0.0)

	custom_minimum_size = Vector2(float(_text.length()) * CELL.x * s, INK_HEIGHT * s)
	size = custom_minimum_size


func _add_glyph(sprite_name: String, index: int, s: float, tint: Color,
		off_x: float, off_y: float) -> void:
	var tr := TextureRect.new()
	tr.texture = Sprites.tex(sprite_name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = tint
	tr.size = CELL * s
	tr.position = Vector2(float(index) * CELL.x * s - off_x, -INK_TOP * s + off_y)
	add_child(tr)


## El ancho real que ocupa, por si hay que reserves sitio antes de crearlo.
static func measure(text: String, s: float) -> Vector2:
	return Vector2(float(text.length()) * CELL.x * s, INK_HEIGHT * s)
