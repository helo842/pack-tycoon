# Menu - la pantalla de inicio.
#
# Fondo de trastienda, el titulo y dos chapas. Es la maqueta shot_start.png
# montada con los mismos sprites y las mismas medidas.
#
# Y LA HUCHA, arriba a la derecha: el rebirth es lo unico del juego que pasa de
# una partida a la siguiente, asi que su sitio es el menu y no la partida -en la
# partida se reinicia, en el menu se mira cuanto llevas-. El boton abre su panel
# (ver RebirthPanel) y esta apagado hasta que la partida da para reiniciarla.
extends Control

const SETTINGS_SCENE := preload("res://scenes/SettingsPanel.tscn")
const REBIRTH_SCENE := preload("res://scenes/RebirthPanel.tscn")

## La hucha y su contador, en la esquina de arriba a la derecha.
##
## Van AHI y no en el pie porque el pie ya tiene la moneda y el rotulo de la
## version, y porque la esquina de arriba es el unico sitio del menu que ni el
## titulo (cajas de 1200 px centradas, o sea hasta x 1560) ni las chapas de
## JUGAR y AJUSTES (x 704..1216) tocan.
const PIGGY_CENTER := Vector2(1608, 152)
const PIGGY_SCALE := 0.16
const COINS_X := 1668.0
## El contador se ancla por su IZQUIERDA (no por su centro) y con tope de ancho:
## asi crece hacia la derecha y nunca se sale de la pantalla, que es lo mismo que
## hace el dinero en la barra de la partida.
const COINS_MAX_W := 240.0
const REBIRTH_CENTER := Vector2(1744, 292)
const REBIRTH_W := 320.0
## La linea que dice lo que falta, debajo de la chapa. Con caja corta y shrink,
## porque el texto mas largo ("TE FALTAN 999.999") mide 272 px a tamano 16.
const NOTE_CENTER := Vector2(1744, 400)
const NOTE_BOX := Vector2(320, 28)

var _settings: SettingsPanel = null
var _rebirth: RebirthPanel = null
## El boton del rebirth, para poder apagarlo cuando la partida no da para
## reiniciarla (y para que las pruebas lo encuentren sin buscarlo por el texto).
var _rebirth_btn: Button = null
## Las monedas que llevas acumuladas.
var _coins: PixelNumber = null
var _note: Label = null


func _ready() -> void:
	# El fondo ya viene a 1920x1080, que es justo el tamano de la pantalla base.
	add_child(UIKit.image("bg_menu_backroom", Vector2(960, 540), Vector2(1920, 1080)))

	_build_title()
	_build_buttons()
	_build_rebirth()
	_build_footer()

	# El contador y el apagado del boton dependen de la partida, y la partida
	# cambia sola (un rebirth emite settings_changed y money_changed). El menu se
	# destruye al entrar a jugar, asi que estas conexiones se van con el.
	Game.money_changed.connect(_on_money_changed)
	Game.settings_changed.connect(_refresh_rebirth)
	_refresh_rebirth()


func _build_title() -> void:
	# El titulo va con label_at y no con label + size a mano: asi la caja se
	# agranda si el texto no cabe y nunca se recorta por los lados, que es lo que
	# le pasaba al subtitulo con la caja de 900.
	#
	# Y NO lleva destello detras. El fx_shine que habia sobre el fondo de la
	# trastienda se leia como un halo azulado, no como luz, y el usuario lo quito
	# a proposito: sin el, el titulo se apoya en el fondo oscuro y se lee mejor.
	# La fuente del titulo no lleva contorno: el borde negro se veia como una
	# sombra gorda sobre el fondo y el usuario lo quito.
	add_child(UIKit.title_label_at("PACK", Vector2(960, 210), Vector2(1200, 150), 112,
			Palette.CREAM))
	add_child(UIKit.title_label_at("TYCOON", Vector2(960, 345), Vector2(1200, 170), 140,
			Palette.GOLD_XL))
	# A 480 el rotulo queda a 32 px de la chapa de JUGAR (que sube hasta y 512).
	add_child(UIKit.label_at("ABRE PAQUETES. A CIEGAS.", Vector2(960, 480),
			Vector2(1200, 60), 35, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0))


func _build_buttons() -> void:
	# 512x256 en vez de 448x224: el hueco real para el texto (el cuerpo oscuro
	# de la chapa menos el icono) es lo que dicta el tamano de la letra, y con
	# la chapa mas estrecha "AJUSTES" se encogia a 28 px mientras "JUGAR" se
	# quedaba en 49 y las dos lineas no parecian del mismo juego.
	var play := UIKit.plate_button("JUGAR", "ui_icon_play", Vector2(960, 640),
			Vector2(512, 256), 49)
	play.pressed.connect(_on_play)
	add_child(play)

	var settings := UIKit.plate_button("AJUSTES", "ui_icon_settings", Vector2(960, 900),
			Vector2(512, 256), 42)
	settings.pressed.connect(_on_settings)
	add_child(settings)


## La hucha: lo que llevas de rebirth y el boton que reinicia la partida.
func _build_rebirth() -> void:
	add_child(UIKit.square("currency_piggy", PIGGY_CENTER, PIGGY_SCALE))
	_coins = PixelNumber.new()
	# El color va ANTES del texto: PixelNumber solo lo aplica al construir los
	# glifos (ver pixel_number.gd, _rebuild).
	_coins.color = Palette.GOLD_XL
	_coins.scale_factor = 0.4
	_coins.max_width = COINS_MAX_W
	add_child(_coins)

	_rebirth_btn = UIKit.small_button("REBIRTH", "", REBIRTH_CENTER, REBIRTH_W, 30)
	_rebirth_btn.pressed.connect(_on_rebirth)
	add_child(_rebirth_btn)

	_note = UIKit.label_at("", NOTE_CENTER, NOTE_BOX, 16, Palette.CREAM_D,
		HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_note)


## El boton abre el panel; el que reinicia de verdad es el panel, con su
## explicacion delante (perder la partida no se decide de un clic suelto).
func _on_rebirth() -> void:
	if _rebirth != null:
		return
	Sound.click()
	_rebirth = REBIRTH_SCENE.instantiate() as RebirthPanel
	_rebirth.closed.connect(_on_rebirth_closed)
	var main := MainRoot.get_root()
	if main != null:
		main.push_veil(_rebirth)


func _on_rebirth_closed() -> void:
	_rebirth = null
	_refresh_rebirth()


## El contador de monedas y, si no llega, cuanto falta. La chapa se apaga de
## color cuando todavia no se puede reiniciar y lo dice en su tooltip, que es lo
## que se lee al pasar por encima; el clic sigue llegando igual, para poder
## explicar QUE falta (misma regla que la barra de las automatizaciones).
func _refresh_rebirth() -> void:
	if not is_node_ready():
		return
	_coins.set_number(Game.rebirth_coins)
	_coins.position = Vector2(COINS_X, PIGGY_CENTER.y - _coins.size.y * 0.5)
	var puede := Game.can_rebirth()
	_rebirth_btn.modulate = Color.WHITE if puede else Color(0.55, 0.55, 0.62, 1.0)
	_rebirth_btn.tooltip_text = "REBIRTH: reinicia la partida a cambio de monedas" \
			if puede else "REBIRTH: te faltan " + PixelNumber.format(Game.rebirth_missing())
	_note.text = "" if puede else "TE FALTAN " + PixelNumber.format(Game.rebirth_missing())
	_note.add_theme_color_override("font_color",
		Palette.CREAM_D if puede else Palette.RUST_L)


## El dinero cambia mucho y el rebirth depende de lo ganado, asi que el contador
## se repinta con el (el argumento de la senal no se usa: lo que interesa es que
## algo ha cambiado).
func _on_money_changed(_value: int) -> void:
	_refresh_rebirth()


func _build_footer() -> void:
	# La moneda va al rincon, no en linea con el texto: el sprite son 72 px y la
	# chapa de AJUSTES baja hasta y 1028, asi que entre la chapa y el borde solo
	# quedan 52 px, y en cualquier x debajo de la chapa la moneda le cae encima.
	# A la izquierda del pie no hay nada.
	var money := UIKit.square("currency_coin", Vector2(200, 1000), 0.14)
	add_child(money)
	# El texto a y 1045, no a 1030: la chapa de AJUSTES llega a 1028 y a 1030 el
	# rotulo le pasaba por debajo al marco de la chapa.
	# label_at y no label + size a mano: el texto son 36 caracteres (756 px a
	# tamano 21) y la caja de 900 se queda corta si se pide mas.
	add_child(UIKit.label_at("PRIMERA VERSION - SIN LOGROS TODAVIA",
			Vector2(960, 1045), Vector2(900, 50), 30, Palette.CREAM_D,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))


# --------------------------------------------------------------------------- #

func _on_play() -> void:
	Sound.click()
	var main := MainRoot.get_root()
	if main != null:
		main.show_game()


func _on_settings() -> void:
	if _settings != null:
		return
	Sound.click()
	_settings = SETTINGS_SCENE.instantiate() as SettingsPanel
	var main := MainRoot.get_root()
	if main != null:
		main.push_veil(_settings)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# ESC cierra la capa de arriba y solo esa: los dos paneles son velos del
	# menu y pueden estar abiertos de uno en uno.
	if _rebirth != null:
		_rebirth._close()
		get_viewport().set_input_as_handled()
		return
	if _settings != null:
		var main := MainRoot.get_root()
		if main != null:
			main.pop_veil(_settings)
		_settings = null
		get_viewport().set_input_as_handled()
