# RebirthPanel - la hucha: reiniciar la partida a cambio de monedas de rebirth.
#
# QUE ES EL REBIRTH. La partida se reinicia entera (dinero, items, inventario y
# armario) y a cambio te llevas MONEDAS, que no se pierden nunca mas: cada moneda
# sube un 5 % el valor de todo lo que vendas, para siempre. Es la unica cosa del
# juego que pasa de una partida a la siguiente, y por eso vive en su propia
# pantalla y detras de un boton: no se puede pulsar por accidente.
#
# LOS NUMEROS SON DE GAME, NO DE AQUI. Lo que te llevarias sale de
# Game.pending_rebirth_coins() -el MISMO calculo que hace do_rebirth(), asi que el
# panel no puede prometer una cosa y dar otra- y el +5 % de
# LootDB.REBIRTH_VALUE_PER_COIN. Escribir aqui un cinco a mano seria la forma mas
# facil de que el dia que se cambie el equilibrio la pantalla mienta.
#
# LA ELECTRONICA DEL ARMARIO ENTRA AQUI. Game.rebirth_multiplier() multiplica las
# monedas que te llevas, y el panel lo dice con el numero de verdad (X1.15 ahora
# mismo): exponer electronica es la unica forma de subir el premio del rebirth, y
# eso solo se ve si se enseña cuanto esta dando.
#
# SOLO SE ABRE CUANDO SE PUEDE. El boton del menu esta apagado hasta llegar al
# requisito (ver menu.gd), pero el panel se dibuja igual y dice lo que FALTA, que
# es lo unico util de una pantalla que no se puede usar todavia.
class_name RebirthPanel
extends Control

signal closed()

## Las mismas medidas que la tienda y el mini menu, que usan el mismo panel:
## ui_panel_shop.png es de 1600x960 y se dibuja tal cual, con el interior de
## x 224..1696 e y 140..940.
const TITLE_Y := 250.0
## El dibujo de la hucha, grande y a la izquierda del bloque de los numeros: es
## lo que hace que la pantalla se lea como "la hucha" de un vistazo.
const PIGGY_CENTER := Vector2(520, 416)
const PIGGY_SCALE := 0.30
## El bloque de la derecha: la moneda, el numero y las dos lineas que lo explican.
## El numero va ANCLADO POR SU IZQUIERDA (COINS_X) por el mismo motivo que el
## contador de dinero de la barra de arriba: centrado, cada cifra de mas lo empuja
## hacia los dos lados y acaba pisando el dibujo de la moneda.
const COIN_CENTER := Vector2(1024, 408)
const COIN_SCALE := 0.14
const COINS_X := 1072.0
const COINS_Y := 408.0
const COINS_SCALE := 0.45
const COINS_MAX_W := 560.0
const HEADLINE_CENTER := Vector2(1152, 320)
## Con cuantas monedas te quedas y lo que falta para poder reiniciar. Las dos van
## en esta columna y no al pie: son datos del MISMO premio que el numero de
## arriba, y el pie es de los botones (un rotulo por debajo de la chapa de
## REBIRTH es un rotulo que se lee pegado a un borde).
const OWNED_CENTER := Vector2(1152, 548)
const MISSING_CENTER := Vector2(1152, 604)
## El texto del trato, una linea por frase, partido con UIKit.wrap. Va centrado y
## a lo ancho del panel, por debajo de la hucha, y cada frase CABE EN UNA LINEA a
## 21 px (66 caracteres): el panel tiene el alto justo para esto, los numeros y
## los dos botones, y una frase de mas empujaria el parrafo encima de las chapas.
const DEAL_CENTER_X := 960.0
const DEAL_Y := 668.0
const DEAL_W := 1400.0
const DEAL_STEP := 32.0
const DEAL_SIZE := 21
## Los dos botones, al pie. La chapa mide 0,45 del ancho de alto, asi que con 320
## son 144 px: con 352 serian 158 y se saldrian del panel por abajo (el interior
## acaba en y 940).
const GO_CENTER := Vector2(760, 856)
const GO_W := 320.0
const CANCEL_CENTER := Vector2(1420, 856)
const CANCEL_W := 320.0

## El numero de monedas que te llevarias. Es un PixelNumber y no una etiqueta
## porque es un numero del juego, y en este juego los numeros son glifos de arte.
var _coins: PixelNumber = null
## Lo que falta para llegar al requisito, o lo que se gana al reiniciar.
var _missing: Label = null
## El boton de reiniciar. Se queda pulsable aunque no se pueda (es lo unico que
## permite explicar que falta, como en la barra de las automatizaciones) y se
## apaga de color cuando no llega.
var _go: Button = null
## Con cuantas monedas te quedas y cuanto sube el valor con ellas.
var _owned: Label = null
## La linea que dice cuanto esta multiplicando la Electronica del armario.
var _electronics: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))

	add_child(UIKit.label_at("REBIRTH", Vector2(960, TITLE_Y), Vector2(1400, 70),
		48, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	var close := UIKit.close_button(Vector2(1650, TITLE_Y), 96.0)
	close.pressed.connect(_close)
	add_child(close)

	_build_prize()
	_build_deal()
	_build_buttons()

	# Los tres numeros de la pantalla (lo que te llevas, lo que tienes y cuanto
	# multiplica la electronica) cambian con el armario, asi que se repintan con
	# el. Con Game.settings_changed y no con do_rebirth(): el rebirth emite todo lo
	# habido y por haber, y este panel se cierra justo despues.
	Game.locker_changed.connect(refresh)
	Game.items_changed.connect(refresh)
	refresh()


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

## El bloque del premio: la hucha, la moneda, el numero de monedas que te
## llevarias y, debajo, las que ya tienes.
func _build_prize() -> void:
	add_child(UIKit.square("currency_piggy", PIGGY_CENTER, PIGGY_SCALE))
	add_child(UIKit.square("currency_coin", COIN_CENTER, COIN_SCALE))
	add_child(UIKit.label_at("TE LLEVARAS", HEADLINE_CENTER, Vector2(560, 44), 32,
		Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	_coins = PixelNumber.new()
	# El color va ANTES del texto: PixelNumber solo lo aplica al construir los
	# glifos (ver pixel_number.gd, _rebuild).
	_coins.color = Palette.GOLD_XL
	_coins.scale_factor = COINS_SCALE
	_coins.max_width = COINS_MAX_W
	add_child(_coins)

	# MONEDAS DE REBIRTH va DEBAJO del numero, no a su lado: al lado, con nueve
	# cifras el numero empujaria el rotulo fuera del panel.
	add_child(UIKit.label_at("MONEDAS DE REBIRTH", Vector2(1152, 480), Vector2(560, 32),
		24, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	_owned = UIKit.label_at("", OWNED_CENTER, Vector2(1000, 36), 21, Palette.CREAM_D,
		HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_owned)


## Lo que pasa al pulsar el boton, en tres frases y sin adornos: lo que se
## pierde, lo que se gana y de donde sale el multiplicador. Cada frase se parte
## con UIKit.wrap() porque a 21 px en la caja del panel caben 66 caracteres y la
## primera mide 84: escribirla de una tirada la recortaria por los dos lados.
func _build_deal() -> void:
	var y := DEAL_Y
	for p in [
		"REINICIA LA PARTIDA: SE PIERDE TODO LO DE ESTA PARTIDA.",
		"LAS MONEDAS SE QUEDAN Y SUBEN UN +%d %% POR MONEDA LO QUE VENDES"
			% roundi(LootDB.REBIRTH_VALUE_PER_COIN * 100.0),
	]:
		for linea in UIKit.wrap(str(p), DEAL_W, DEAL_SIZE):
			add_child(UIKit.label_at(str(linea), Vector2(DEAL_CENTER_X, y),
				Vector2(DEAL_W, DEAL_STEP), DEAL_SIZE, Palette.CREAM_D,
				HORIZONTAL_ALIGNMENT_CENTER, 0, true))
			y += DEAL_STEP
	# La tercera frase lleva el multiplicador QUE ESTA DANDO AHORA el armario, y va
	# aparte porque es la unica que cambia sola (ver refresh()).
	_electronics = UIKit.label_at("", Vector2(DEAL_CENTER_X, y), Vector2(DEAL_W, DEAL_STEP),
		DEAL_SIZE, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_electronics)

	_missing = UIKit.label_at("", MISSING_CENTER, Vector2(1400, 40), 26, Palette.CREAM_D,
		HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_missing)


func _build_buttons() -> void:
	_go = UIKit.small_button("REBIRTH", "", GO_CENTER, GO_W, 34)
	_go.pressed.connect(_on_rebirth)
	add_child(_go)

	var cancel := UIKit.small_button("CANCELAR", "", CANCEL_CENTER, CANCEL_W, 34,
		"ui_button_sell", "ui_button_sell")
	cancel.pressed.connect(_close)
	add_child(cancel)


# --------------------------------------------------------------------------- #
# Refresco
# --------------------------------------------------------------------------- #

## Todo lo que depende de la partida: el premio, lo que ya tienes, lo que falta y
## cuanto suma la electronica. Se puede llamar cuando sea; sin nodo todavia no
## hace nada.
func refresh() -> void:
	if not is_node_ready():
		return
	var premio := Game.pending_rebirth_coins()
	_coins.set_number(premio)
	# Centrado a mano en vertical: la posicion vertical no depende de las cifras,
	# asi que se calcula una vez por refresco y no se pega el numero a la moneda.
	_coins.position = Vector2(COINS_X, COINS_Y - _coins.size.y * 0.5)

	var subida := roundi((Game.rebirth_value_mult() - 1.0) * 100.0)
	# La linea es CORTA a proposito: label_at() ensancha la caja cuando el texto no
	# cabe y la centra, asi que una frase larga crece hacia los dos lados por igual
	# y acaba metiendo su ultima letra en el marco del panel (medido en la captura
	# 24_rebirth: con "TODO LO QUE VENDAS", x 656..1718 en un interior que acaba en
	# 1696, o sea el % cortado por el borde). 37 caracteres son 770 px y sobran
	# 130 px por lado.
	_owned.text = "YA TIENES %d MONEDAS: TODO VALE +%d %%" % [
		Game.rebirth_coins, subida]
	_electronics.text = "Y LA ELECTRONICA DEL ARMARIO LAS MULTIPLICA: X%s" % \
		LootDB.short_number(Game.rebirth_multiplier())

	var puede := Game.can_rebirth()
	_go.modulate = Color.WHITE if puede else Color(0.55, 0.55, 0.62, 1.0)
	_missing.text = "" if puede else "TE FALTAN %s DE LO GANADO EN ESTA PARTIDA" % \
		PixelNumber.format(Game.rebirth_missing())
	_missing.add_theme_color_override("font_color",
		Palette.CREAM_D if puede else Palette.RUST_L)


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

## Reiniciar de verdad. El que reinicia es Game.do_rebirth(), que ademas avisa a
## todo el juego y guarda: aqui solo queda contar lo que ha pasado y cerrar.
##
## El boton NO se deshabilita cuando no llega, y no es un descuido: un boton
## muerto y callado no explica nada, y lo unico util de este panel cuando todavia
## no se puede es decir QUE falta. Ver la barra de las automatizaciones
## (game.gd, _locked_notice()), que hace lo mismo.
func _on_rebirth() -> void:
	if not Game.can_rebirth():
		Sound.play("sfx_error")
		Game.notice.emit("AUN NO: TE FALTAN "
			+ PixelNumber.format(Game.rebirth_missing()), Palette.RUST_L)
		return
	var coins := Game.do_rebirth()
	Sound.play("sfx_tool")
	Game.notice.emit("REBIRTH: +" + PixelNumber.format(coins) + " MONEDAS",
		Palette.GOLD_XL)
	_close()


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
