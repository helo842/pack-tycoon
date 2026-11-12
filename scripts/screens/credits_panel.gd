# CreditsPanel - los creditos de lo que no es nuestro.
#
# Se abre desde Ajustes (boton CREDITOS, abajo a la derecha). Hoy solo hay una
# cosa de fuera: la musica de fondo, el recopilatorio de una hora de Stream
# Cafe. Es de uso libre con una condicion: el credito tiene que decir el artista
# y el enlace del video ("stream cafe - <enlace>"), porque es mas de una pista.
#
# POR QUE EL ENLACE VA CON OTRA FUENTE
# ------------------------------------
# La fuente del juego (font_pack.fnt) solo tiene mayusculas, y el id de un video
# de YouTube distingue mayusculas de minusculas: escrito en mayusculas el enlace
# no lleva a ninguna parte. Por eso el enlace va con la fuente por defecto de
# Godot, que tiene minusculas, y ademas se puede pulsar para abrirlo.
class_name CreditsPanel
extends Control

signal closed()

const MUSIC_ARTIST := "STREAM CAFE"
const MUSIC_TITLE := "1 HOUR OF COMFY AND RELAXING SONGS"
const MUSIC_URL := "https://www.youtube.com/watch?v=TQvXEza4fPc"

## Mismas medidas que el resto de paneles de ui_panel_shop: interior de x 224 a
## 1696 y de y 140 a 940.
const TITLE_Y := 240.0
const SECTION_Y := 400.0
const ARTIST_Y := 500.0
const TRACK_Y := 580.0
const LINK_Y := 670.0
const HINT_Y := 850.0


func _ready() -> void:
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))
	add_child(UIKit.label_at("CREDITOS", Vector2(960, TITLE_Y), Vector2(1400, 70),
			48, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var close := UIKit.close_button(UIKit.PANEL_CLOSE)
	close.pressed.connect(_close)
	add_child(close)

	add_child(UIKit.label_at("MUSICA", Vector2(960, SECTION_Y), Vector2(1200, 50),
			35, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	add_child(UIKit.label_at(MUSIC_ARTIST, Vector2(960, ARTIST_Y), Vector2(1200, 70),
			56, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	add_child(UIKit.label_at(MUSIC_TITLE, Vector2(960, TRACK_Y), Vector2(1300, 50),
			28, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	add_child(_link_button())
	add_child(UIKit.label_at("MUSICA DE USO LIBRE CON CREDITO", Vector2(960, HINT_Y),
			Vector2(1360, 40), 24, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true))


## El enlace: texto plano con la fuente por defecto (ver arriba) y pulsable.
func _link_button() -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.text = MUSIC_URL
	b.tooltip_text = "Abrir el video en el navegador"
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", ThemeDB.fallback_font)
	b.add_theme_font_size_override("font_size", 34)
	for state in ["font_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, Palette.GOLD_XL)
	b.add_theme_color_override("font_hover_color", Palette.CREAM)
	b.size = Vector2(1200, 60)
	b.position = Vector2(960, LINK_Y) - b.size * 0.5
	b.pressed.connect(_open_link)
	return b


func _open_link() -> void:
	Sound.click()
	OS.shell_open(MUSIC_URL)


## Quien lo abrio (Ajustes) lo saca del velo con pop_veil, que es quien lo libera
## despues de la animacion de salida.
func _close() -> void:
	Sound.click()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
