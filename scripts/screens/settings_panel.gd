# SettingsPanel - los ajustes.
#
# Dos deslizadores, dos casillas (pantalla completa y venta automatica), la fila
# del AUTO GUARDAR (en gris hasta comprarlo en el arbol del rebirth) y cuando
# sale la FICHA del objeto.
#
# El selector de IDIOMA ya no esta: solo habia espanol y no hacia nada, y su
# sitio es el que necesitaban las dos filas nuevas dentro del interior del
# panel (hasta y 892).
class_name SettingsPanel
extends Control

signal closed()

var _music: PixelSlider
var _sfx: PixelSlider
var _screen_box: TextureRect
var _sell_box: TextureRect
## La fila del AUTO GUARDAR: su casilla y el boton ELEGIR, que solo existen con
## la mejora comprada (sin ella la fila es gris y no tiene nada que pulsar).
var _store_box: TextureRect = null
var _store_pick: Button = null
var _card_label: Label = null
var _filter: AutoStorePanel = null

const ROW_SLIDER_1 := 330.0
const ROW_SLIDER_2 := 430.0
const ROW_SCREEN := 530.0
const ROW_SELL := 626.0
const ROW_STORE := 722.0
const ROW_CARD := 818.0
const AUTOSTORE_SCENE := preload("res://scenes/AutoStorePanel.tscn")
const CARD_NAMES := {"always": "SIEMPRE", "good": "LO BUENO", "never": "NUNCA"}

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

	var close := UIKit.close_button(UIKit.PANEL_CLOSE)
	close.pressed.connect(_close)
	add_child(close)

	_build_sliders()
	_build_checks()
	_build_autostore()
	_build_card_mode()


func _build_sliders() -> void:
	var y := ROW_SLIDER_1
	add_child(UIKit.art("ui_icon_music", Vector2(300, y), 0.5))
	add_child(UIKit.label_at("MUSICA", Vector2(660, y), Vector2(440, 60), 40,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	_music = _slider(Vector2(SLIDER_X, y), Game.music_volume, "music")
	_last_sfx = Game.sfx_volume

	y = ROW_SLIDER_2
	add_child(UIKit.art("ui_icon_sound", Vector2(300, y), 0.5))
	add_child(UIKit.label_at("SONIDOS", Vector2(660, y), Vector2(440, 60), 40,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	_sfx = _slider(Vector2(SLIDER_X, y), Game.sfx_volume, "sfx")


## Las dos barras van centradas en x=SLIDER_X: a 900 la pista empezaba justo
## donde acaba SONIDOS y el contorno se pegaba a la ultima letra.
const SLIDER_X := 1000.0


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
	_screen_box = _check_row("ui_icon_settings", "PANTALLA COMPLETA", ROW_SCREEN,
			Game.fullscreen, _toggle_fullscreen)
	_sell_box = _check_row("currency_coin", "VENTA AUTOMATICA", ROW_SELL,
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
	# 96 y no 128: las filas van a 96 de distancia y a 128 los iconos se pisaban.
	add_child(UIKit.image(icon, Vector2(300, y), Vector2(96, 96)))
	# El rotulo tiene 17 caracteres, asi que a tamano 42 son 714 px y se saldria
	# de la caja de 560. Con shrink=True el tamano baja hasta que quepa.
	add_child(UIKit.label_at(text, Vector2(660, y), Vector2(560, 60), 40,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	var box := UIKit.image(_check_tex(on), Vector2(1050, y), Vector2(96, 96))
	add_child(box)
	var hit := UIKit.hit_area(self, Rect2(Vector2(1002, y - 48.0), Vector2(96, 96)))
	hit.pressed.connect(action)
	UIKit.juice(hit, [box], 1.1)
	return box


## LA FILA DEL AUTO GUARDAR. Sin la mejora del arbol sale entera en gris y donde
## iria la casilla dice donde se compra; con ella, en color, con su casilla y el
## boton ELEGIR que abre el filtro (AutoStorePanel).
func _build_autostore() -> void:
	var y := ROW_STORE
	var on := Game.autostore_unlocked()
	var tint := Color.WHITE if on else Color(0.45, 0.45, 0.52, 1.0)
	add_child(UIKit.image("ui_icon_inventory", Vector2(300, y), Vector2(96, 96), tint))
	var l := UIKit.label_at("AUTO GUARDAR", Vector2(660, y), Vector2(560, 60), 40,
			Palette.CREAM if on else Palette.PRICE_OFF, HORIZONTAL_ALIGNMENT_LEFT, 0, true)
	add_child(l)
	if not on:
		add_child(UIKit.label_at("ARBOL DEL REBIRTH: %d MONEDAS"
				% SkillTree.COST_QOL_AUTOSTORE, Vector2(1290, y), Vector2(620, 40), 21,
				Palette.PRICE_OFF, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
		return
	_store_box = UIKit.image(_check_tex(Game.autostore_on), Vector2(1050, y), Vector2(96, 96))
	add_child(_store_box)
	var hit := UIKit.hit_area(self, Rect2(Vector2(1002, y - 48.0), Vector2(96, 96)))
	hit.pressed.connect(_toggle_autostore)
	UIKit.juice(hit, [_store_box], 1.1)
	_store_pick = UIKit.small_button("ELEGIR", "", Vector2(1330, y), 240, 28)
	_store_pick.tooltip_text = "Elegir que se guarda"
	_store_pick.pressed.connect(_open_filter)
	add_child(_store_pick)


## LA FICHA DEL OBJETO: cuando sale (siempre, solo lo bueno o nunca). Flechas a
## los lados como tenia el idioma; las dos cambian de valor en circulo.
func _build_card_mode() -> void:
	var y := ROW_CARD
	add_child(UIKit.image("ui_icon_achievement", Vector2(300, y), Vector2(96, 96)))
	add_child(UIKit.label_at("FICHA DEL OBJETO", Vector2(660, y), Vector2(560, 60), 40,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	add_child(UIKit.image("ui_arrow_left", Vector2(1010, y), Vector2(72, 72)))
	_card_label = UIKit.label_at("", Vector2(1200, y), Vector2(280, 50), 35,
			Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_card_label)
	add_child(UIKit.image("ui_arrow_right", Vector2(1390, y), Vector2(72, 72)))
	UIKit.hit_area(self, Rect2(Vector2(970, y - 40.0), Vector2(80, 80)),
			"Ficha: antes").pressed.connect(_step_card_mode.bind(-1))
	UIKit.hit_area(self, Rect2(Vector2(1350, y - 40.0), Vector2(80, 80)),
			"Ficha: despues").pressed.connect(_step_card_mode.bind(1))
	_paint_card_mode()


func _paint_card_mode() -> void:
	_card_label.text = str(CARD_NAMES.get(Game.card_mode, "LO BUENO"))


func _step_card_mode(step: int) -> void:
	Sound.click()
	var modes: Array = Game.CARD_MODES
	var i := modes.find(Game.card_mode)
	Game.set_card_mode(str(modes[(i + step + modes.size()) % modes.size()]))
	_paint_card_mode()
	Game.notice.emit("FICHA: " + _card_label.text, Palette.CREAM_D)


func _toggle_autostore() -> void:
	Sound.click()
	Game.set_autostore(not Game.autostore_on)
	_store_box.texture = Sprites.tex(_check_tex(Game.autostore_on))
	Game.notice.emit("AUTO GUARDAR: " + ("SI" if Game.autostore_on else "NO"),
			Palette.CREAM_D)


## El filtro va en su propio panel, encima de los ajustes: son 18 botones y no
## caben en una fila.
func _open_filter() -> void:
	if _filter != null:
		return
	Sound.click()
	_filter = AUTOSTORE_SCENE.instantiate() as AutoStorePanel
	_filter.closed.connect(_on_filter_closed)
	MainRoot.get_root().push_veil(_filter)


func _on_filter_closed() -> void:
	if _filter != null:
		MainRoot.get_root().pop_veil(_filter)
		_filter = null


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
