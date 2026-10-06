# SettingsPanel - los ajustes.
#
# Reproduce la maqueta shot_settings.png: dos deslizadores, un interruptor de
# pantalla completa y el selector de idioma (de momento solo espanol, porque es
# lo unico que hay escrito; el selector esta porque cambiarlo es solo un aviso).
class_name SettingsPanel
extends Control

signal closed()

var _music: PixelSlider
var _sfx: PixelSlider
var _screen_box: TextureRect
var _sell_box: TextureRect

## Ultimo valor del deslizador de SONIDOS al que ya se le ha dado el clic de
## referencia. Ver _on_volume().
var _last_sfx := 0.0


func _ready() -> void:
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_settings"))
	# y=240 y no 135: el interior del panel empieza en y=188, y a 135 el titulo
	# estaba medio sobre el marco. Las filas de abajo se separan para caber
	# entre 188 y 892 sin tocarse.
	add_child(UIKit.label_at("AJUSTES", Vector2(960, 240), Vector2(1600, 90),
			63, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	var close := UIKit.close_button(Vector2(1630, 240), 96.0)
	close.pressed.connect(_close)
	add_child(close)

	_build_sliders()
	_build_checks()
	_build_language()
	_build_note()


func _build_sliders() -> void:
	var y := 350.0
	add_child(UIKit.art("ui_icon_music", Vector2(300, y), 0.5))
	add_child(UIKit.label_at("MUSICA", Vector2(660, y), Vector2(440, 60), 40,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	_music = _slider(Vector2(900, y), Game.music_volume, "music")
	_last_sfx = Game.sfx_volume

	y = 470.0
	add_child(UIKit.art("ui_icon_sound", Vector2(300, y), 0.5))
	add_child(UIKit.label_at("SONIDOS", Vector2(660, y), Vector2(440, 60), 40,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	_sfx = _slider(Vector2(900, y), Game.sfx_volume, "sfx")


func _slider(center: Vector2, value: float, which: String) -> PixelSlider:
	var s := PixelSlider.new()
	s.position = center - Vector2(280, 40)
	s.size = Vector2(560, 80)
	s.value = value
	s.value_changed.connect(_on_volume.bind(which))
	add_child(s)
	return s


## Las dos filas de casilla. Son la misma pieza repetida, que es justo el motivo
## por el que esta pantalla se monta en codigo: cuando entro la segunda (venta
## automatica) no hubo que duplicar nada, solo pedir otra fila.
##
## y=590 y y=690 y no las dos juntas: la casilla mide 96 y la zona de clic 96,
## asi que dos filas a menos de 96 de distancia se pisarian los clics.
func _build_checks() -> void:
	_screen_box = _check_row("ui_icon_settings", "PANTALLA COMPLETA", 590.0,
			Game.fullscreen, _toggle_fullscreen)
	_sell_box = _check_row("currency_coin", "VENTA AUTOMATICA", 690.0,
			Game.auto_sell, _toggle_auto_sell)


## Una fila de casilla: icono, rotulo, casilla y su zona de clic. Devuelve la
## casilla, que es lo unico que hay que repintar al cambiarla.
##
## La casilla va a x=1050 y no a 930: el rotulo se centra en la caja de 560, que
## llega hasta x 940, asi que a 930 la casilla se metia 58 px por debajo del
## texto ("VENTA AUTOMATICA" mide 560 a tamano 35). A 1050 el texto acaba en 940
## y la casilla empieza en 1002.
func _check_row(icon: String, text: String, y: float, on: bool,
		action: Callable) -> TextureRect:
	# El icono va por TAMANO (128x128) y no por escala. Con art(..., 0.5) cada
	# icono se escalaba sobre SU propio lienzo, y no todos miden lo mismo: los
	# ui_icon_* son de 256 (salian a 128) y currency_coin es de 512, asi que
	# salia a 256 y tapaba media pantalla. Con el tamano fijo da igual de que
	# medida sea el sprite.
	add_child(UIKit.image(icon, Vector2(300, y), Vector2(128, 128)))
	# El rotulo tiene 17 caracteres, asi que a tamano 42 son 714 px y se saldria
	# de la caja de 560. Con shrink=True el tamano baja hasta que quepa.
	add_child(UIKit.label_at(text, Vector2(660, y), Vector2(560, 60), 40,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	var box := UIKit.image(_check_tex(on), Vector2(1050, y), Vector2(96, 96))
	add_child(box)
	UIKit.hit_area(self, Rect2(Vector2(1002, y - 48.0), Vector2(96, 96))).pressed.connect(
			action)
	return box


func _build_language() -> void:
	# y=790 en vez de 850: la fila de idioma era justo la que chocaba con la nota
	# de abajo, y las dos caben dentro del interior del panel (hasta y=892).
	var y := 790.0
	add_child(UIKit.label_at("IDIOMA", Vector2(660, y), Vector2(440, 60), 35,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	add_child(UIKit.image("ui_arrow_left", Vector2(880, y), Vector2(80, 80),
			Color(0.5, 0.5, 0.58)))
	add_child(UIKit.label_at("ESPANOL", Vector2(1110, y), Vector2(360, 60), 35,
			Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	add_child(UIKit.image("ui_arrow_right", Vector2(1340, y), Vector2(80, 80),
			Color(0.5, 0.5, 0.58)))


func _build_note() -> void:
	# Esta nota era cierta cuando el texto usaba la fuente de Godot. Ahora ya no
	# lo usa, asi que dice otra cosa: que el idioma esta por hacer, que es lo
	# unico que el selector todavia no puede hacer.
	#
	# y=850 era 944, y 944 esta SOBRE el marco del panel: el interior de un
	# panel de 1600x960 con margen de 9-slice de 8 px de arte (128 px) llega
	# hasta y=892. Con la fuente suave el texto se salia de la caja sin que se
	# notase mucho; con la fuente nueva se veia el recorte en la captura.
	add_child(UIKit.label_at(
			"EL IDIOMA SE PUEDE CAMBIAR CUANDO HAYA MAS DE UNO",
			Vector2(960, 856), Vector2(1360, 44), 21, Palette.CREAM_D,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))


func _check_tex(on: bool) -> String:
	return "ui_checkbox_on" if on else "ui_checkbox_off"


func _on_volume(v: float, which: String) -> void:
	if which == "music":
		Game.set_music_volume(v)
	else:
		Game.set_sfx_volume(v)
		# Un clic de referencia: es la unica forma de oir como va a sonar sin
		# salir de los ajustes. Se salta los cambios minusculos para que
		# arrastrar el pomo de una tirada no sea una metralleta.
		if absf(v - _last_sfx) >= 0.05:
			_last_sfx = v
			Sound.click()


func _toggle_fullscreen() -> void:
	Sound.click()
	Game.set_fullscreen(not Game.fullscreen)
	_screen_box.texture = Sprites.tex(_check_tex(Game.fullscreen))


## Venta automatica: todo lo que salga de una caja se vende al instante, sin
## tarjeta de revelado y sin pasar por la mesa.
func _toggle_auto_sell() -> void:
	Sound.click()
	Game.set_auto_sell(not Game.auto_sell)
	_sell_box.texture = Sprites.tex(_check_tex(Game.auto_sell))
	Game.notice.emit("VENTA AUTOMATICA: " + ("SI" if Game.auto_sell else "NO"),
			Palette.CREAM_D)


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
