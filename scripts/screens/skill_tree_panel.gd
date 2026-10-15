# SkillTreePanel - el arbol de habilidades: cuatro ramas de dos mejoras.
#
# QUE ES. El arbol del Idea.pdf, que hasta ahora no existia: cuatro ramas
# -Calidad de vida, Ganancias, Dano y Herencia- y en cada una dos opciones que se
# compran con MONEDAS DE REBIRTH. Los datos (que ramas hay, que hace cada opcion,
# cuanto cuesta cada nivel) estan en LootDB.SKILL_BRANCHES: aqui solo se dibuja
# lo que diga esa tabla, asi que anadir una quinta rama no obliga a tocar este
# fichero. La lista SI se recorre de LootDB (ver _build_branches), que es lo que
# hace que el panel y el equilibrio no puedan desincronizarse.
#
# SE PAGA CON MONEDAS Y NO CON DINERO, y de ahi que el panel viva detras de la
# hucha: las monedas son lo unico que pasa de una partida a la siguiente y el
# arbol es lo unico del juego que no se pierde de ninguna manera (ni el rebirth
# ni el reinicio lo tocan). Por eso el contador de arriba a la izquierda es la
# MONEDA, con su dibujo: aqui no se gasta el dinero de la partida, y poner un
# contador de dinero en esta pantalla seria mentir.
#
# LA CASILLA ENSEÑA LO QUE SE COMPRA, y al tope lo que ya se tiene. El precio de
# debajo es el del nivel SIGUIENTE, asi que el par que se lee es "pagas esto y te
# llevas esto" -que es como se lee un arbol de habilidades-, y los puntos de
# nivel dicen en que punto estas. En la opcion de un solo nivel no hay puntos que
# marcar: ahi va el rotulo COMPRA UNICA, el mismo que usa la tienda para el PC y
# los Pinchos, que son tambien las compras de una sola vez.
#
# LOS NUMEROS NO SE ESCRIBEN AQUI. El efecto de cada casilla sale de
# LootDB.skill_effect(), que es la formula de verdad de esa opcion al nivel que
# se le pida; el precio sale de Game.skill_cost(). Escribir un "+8 %" a mano en
# una etiqueta seria la forma mas facil de que la pantalla mintiera el dia que se
# toque el equilibrio.
class_name SkillTreePanel
extends Control

signal closed()

## Las mismas medidas que la tienda y la hucha, que usan el mismo marco:
## ui_panel_shop.png es de 1600x960 y se dibuja tal cual, con el interior de
## x 224..1696 e y 140..940. Todo lo de aqui vive dentro de esa caja y el smoke
## test lo comprueba (los textos, las chapas y los dibujos).
const TITLE_Y := 210.0
## La linea que dice CON QUE SE PAGA. Corta a proposito: el que llega aqui viene
## de la hucha y ya sabe lo que son las monedas, pero el que se pierda tiene que
## poder leerlo en la propia pantalla y no en el tooltip de otro boton.
const SUBTITLE_Y := 262.0
## Cada rama es una COLUMNA: su emblema y su nombre arriba y, debajo, sus dos
## opciones. En columna se lee como lo que es (cuatro ramas del mismo arbol) y
## deja las dos casillas de una rama juntas, que es lo que hay que comparar.
##
## Cuatro columnas de 320 separadas 48 (paso 368): de x 248 a 1672 en un interior
## que acaba en 1696, o sea 24 px de aire a cada lado. El nombre de rama mas largo
## ("CALIDAD DE VIDA", 15 caracteres) mide 315 px a 21, que es el ancho exacto de
## la columna: por eso las ramas se llaman asi y no con un nombre mas largo.
const BRANCH_ICON_Y := 306.0
const BRANCH_NAME_Y := 350.0
const BOX := Vector2(320, 264)
const BOX_COL0_X := 248.0
const BOX_COL_STEP := 368.0
const BOX_ROW0_Y := 372.0
## 264 de casilla mas 24 de aire: la segunda fila acaba en y 924, dentro del
## interior (940) y con sitio para la raya de abajo.
const BOX_ROW_STEP := 288.0
const ICON_BOX := Vector2(96, 96)
const ICON_DY := 56.0
const NAME_DY := 128.0
## La linea del efecto, a 14 px (dos pasos de la fuente): es la mas corta de la
## casilla y tiene que caber con el texto mas largo del catalogo
## ("+7500 AL EMPEZAR" son 15 caracteres, 210 px de los 296 que deja la casilla).
const EFFECT_DY := 160.0
const LEVEL_DY := 190.0
const COST_DY := 226.0

## Los colores de la casilla, los mismos que la tienda: fondo oscuro con filete
## dorado, y la comprada en dorado claro. Es el mismo idioma visual para el mismo
## gesto ("aqui se compra algo"), y por eso el jugador no tiene que aprender nada
## nuevo para entender el arbol.
const BACK_OPEN := Color(0.02, 0.015, 0.04, 0.62)
const BACK_DONE := Color(0.10, 0.07, 0.02, 0.62)
const EDGE_OPEN := Color(Palette.GOLD_D, 0.85)
const EDGE_DONE := Color(Palette.GOLD_XL, 0.9)
const EDGE := 4.0

## El contador de monedas, en el mismo sitio que el dinero de la tienda: arriba a
## la izquierda y por su IZQUIERDA (si creciera, se estira hacia la derecha en vez
## de empujar el dibujo de la moneda).
var _coins: PixelNumber = null
## Una entrada por opcion del arbol (ocho), con todo lo que hay que repintar
## cuando cambian las monedas o los niveles. En el mismo orden que
## LootDB.skill_options(), que es lo que permite ir de la casilla al dato por
## indice.
var _cells: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))

	var close := UIKit.close_button(Vector2(1700, 150), 96.0)
	close.pressed.connect(_close)
	add_child(close)

	_build_head()
	_build_branches()

	# Con skills_changed y no refrescando a mano al comprar: asi el panel se
	# repinta tambien cuando las monedas cambian por otro camino (el rebirth de
	# detras, sin ir mas lejos, que cierra este panel pero puede reabrirlo).
	Game.skills_changed.connect(refresh)
	refresh()


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

## El encabezado: el contador de monedas, el titulo y con que se paga.
func _build_head() -> void:
	add_child(UIKit.image("currency_coin", Vector2(300, 180), Vector2(87, 87)))
	_coins = PixelNumber.new()
	# El color va ANTES del texto: PixelNumber solo lo aplica al construir los
	# glifos (ver pixel_number.gd, _rebuild).
	_coins.color = Palette.GOLD_XL
	_coins.scale_factor = 0.55
	_coins.max_width = 460.0
	add_child(_coins)
	_coins.position = Vector2(400, 180 - _coins.size.y * 0.5)

	add_child(UIKit.label_at("ARBOL DE HABILIDADES", Vector2(960, TITLE_Y),
		Vector2(1400, 70), 48, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	add_child(UIKit.label_at("SE PAGAN CON MONEDAS DE REBIRTH", Vector2(960, SUBTITLE_Y),
		Vector2(900, 32), 21, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true))


## Las cuatro ramas, cada una su columna: emblema, nombre y sus dos casillas.
##
## El tamaño del nombre de rama sale de row_size() con el mas largo de los cuatro,
## para que los cuatro se lean al mismo tamaño: encoger cada uno por su cuenta
## dejaria "DANO" a 28 y "CALIDAD DE VIDA" a 14 en la misma fila, que se lee como
## un fallo y no como un diseno.
func _build_branches() -> void:
	var ramas: Array = LootDB.skill_branches()
	var nombres: Array = []
	for branch in ramas:
		nombres.append(str(branch["name"]))
	var name_size := UIKit.row_size(nombres, BOX.x, 21)

	for b in ramas.size():
		var branch: Dictionary = ramas[b]
		var mid_x := BOX_COL0_X + float(b) * BOX_COL_STEP + BOX.x * 0.5
		# El emblema es uno de los cuatro iconos de habilidad que ya venian en el
		# kit (diamante, rayo, dolar y ciclo): el arte de las cuatro ramas ya
		# existia y lo que faltaba era el arbol que las usara.
		add_child(UIKit.art(str(branch["art"]), Vector2(mid_x, BRANCH_ICON_Y), 0.22))
		add_child(UIKit.label_at(str(branch["name"]), Vector2(mid_x, BRANCH_NAME_Y),
			Vector2(BOX.x, 30), name_size, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))
		for o in (branch["options"] as Array).size():
			var option: Dictionary = (branch["options"] as Array)[o]
			var top_left := Vector2(BOX_COL0_X + float(b) * BOX_COL_STEP,
				BOX_ROW0_Y + float(o) * BOX_ROW_STEP)
			_cells.append(_option_box(option, top_left, name_size))


## Una casilla del arbol: fondo con filete, dibujo, nombre, el efecto que se
## compra, los puntos de nivel (o COMPRA UNICA) y lo que cuesta.
##
## Devuelve las piezas que hay que repintar (ver refresh()): el nivel, el efecto,
## el precio y el color de la casilla dependen de la partida y cambian con cada
## compra.
func _option_box(option: Dictionary, top_left: Vector2, name_size: int) -> Dictionary:
	var x := top_left.x
	var y := top_left.y
	var mid_x := x + BOX.x * 0.5

	var back := ColorRect.new()
	back.color = BACK_OPEN
	back.position = top_left
	back.size = BOX
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var frame := _frame(top_left, EDGE_OPEN)

	var art := UIKit.fit_art(str(option["art"]), Vector2(mid_x, y + ICON_DY), ICON_BOX)
	add_child(art)

	add_child(UIKit.label_at(str(option["name"]), Vector2(mid_x, y + NAME_DY),
		Vector2(BOX.x - 24.0, 36), name_size, Palette.CREAM,
		HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	# El efecto del nivel que se compra, en el mismo sitio donde la tienda pone
	# los puntos de nivel a secas. Se repinta en refresh(): su texto y su color
	# dependen de las monedas que lleves.
	var effect := UIKit.label_at("", Vector2(mid_x, y + EFFECT_DY),
		Vector2(BOX.x - 24.0, 24), 14, Palette.GOLD_XL,
		HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(effect)

	var pips: Array = []
	var una_vez: Label = null
	if int(option["max"]) > 1:
		pips = _pips(Vector2(mid_x, y + LEVEL_DY), int(option["max"]))
	else:
		una_vez = UIKit.label_at("COMPRA UNICA", Vector2(mid_x, y + LEVEL_DY),
			Vector2(BOX.x - 40.0, 22), 14, Palette.GOLD,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true)
		add_child(una_vez)

	# El precio: la moneda del juego con su numero al lado, los dos centrados
	# como un grupo (la moneda pegada al borde izquierdo y el numero al centro se
	# leian como dos cosas sueltas). El sitio de la moneda es el de la chapa del
	# precio de la tienda, y el rotulo AL TOPE lo sustituye cuando ya no hay nada
	# que comprar.
	var coin := UIKit.image("currency_coin", Vector2(mid_x, y + COST_DY), Vector2(28, 28))
	coin.name = "Coin"
	add_child(coin)
	var cost := PixelNumber.new()
	cost.name = "Cost"
	cost.scale_factor = 0.26
	add_child(cost)
	var owned := UIKit.label_at("", Vector2(mid_x, y + COST_DY), BOX - Vector2(24, 16),
		21, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	owned.name = "Owned"
	owned.visible = false
	add_child(owned)

	var b := UIKit.hit_area(self, Rect2(top_left, BOX), "")
	b.pressed.connect(_buy.bind(str(option["id"])))
	return {"option": str(option["id"]), "art": art, "back": back, "frame": frame,
			"effect": effect, "pips": pips, "once": una_vez, "coin": coin,
			"cost": cost, "owned": owned, "button": b, "mid": mid_x, "y": y}


## El filete de una casilla: cuatro rectangulos planos, como el de la tienda. No
## es un sprite porque la casilla mide lo que mide y en este juego el arte se
## estira a escalas enteras o no se estira.
func _frame(at: Vector2, color: Color) -> Array:
	var partes: Array = []
	for r in [Rect2(at, Vector2(BOX.x, EDGE)),
			Rect2(at + Vector2(0.0, BOX.y - EDGE), Vector2(BOX.x, EDGE)),
			Rect2(at, Vector2(EDGE, BOX.y)),
			Rect2(at + Vector2(BOX.x - EDGE, 0.0), Vector2(EDGE, BOX.y))]:
		var c := ColorRect.new()
		c.color = color
		c.position = r.position
		c.size = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		partes.append(c)
	return partes


## Los puntos de nivel: un cuadro por nivel, en dorado los comprados. Son
## rectangulos planos, no un sprite, porque son informacion y no arte.
func _pips(centre: Vector2, total: int, side: float = 14.0, gap: float = 6.0) -> Array:
	var nodes: Array = []
	var x0 := centre.x - float(total) * (side + gap) * 0.5 + gap * 0.5
	for i in total:
		var r := ColorRect.new()
		r.size = Vector2(side, side)
		r.position = Vector2(x0 + float(i) * (side + gap), centre.y - side * 0.5)
		r.color = Palette.NIGHT_LL
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		nodes.append(r)
	return nodes


# --------------------------------------------------------------------------- #
# Refresco
# --------------------------------------------------------------------------- #

## Todo lo que depende de la partida: las monedas y, casilla a casilla, el nivel,
## el efecto, el precio y el color. Se puede llamar cuando sea.
func refresh() -> void:
	if not is_node_ready():
		return
	_coins.set_number(Game.rebirth_coins)
	_coins.position = Vector2(400, 180 - _coins.size.y * 0.5)

	# Los dos arrays salen del mismo sitio (una casilla por opcion), pero se
	# recorre el mas corto: si un dia el panel enseñara menos casillas que
	# opciones, esto tiene que seguir refrescando las que hay y no salirse.
	var opciones: Array = LootDB.skill_options()
	for i in mini(_cells.size(), opciones.size()):
		_refresh_cell(_cells[i], opciones[i])


func _refresh_cell(cell: Dictionary, option: Dictionary) -> void:
	if not is_instance_valid(cell["art"]):
		return
	var option_id := str(cell["option"])
	var level := Game.skill_level(option_id)
	var tope := Game.skill_max_level(option_id)
	var cost := Game.skill_cost(option_id)
	var cerrado := cost < 0
	var alcanzable := not cerrado and Game.rebirth_coins >= cost

	# EL EFECTO. Al tope se enseña el que ya esta dando (no hay nivel siguiente
	# que prometer); si no, el que se lleva al comprar este nivel, que es lo que
	# empareja con el precio de debajo.
	var linea := Game.skill_effect(option_id, level if cerrado else level + 1)
	var effect: Label = cell["effect"]
	effect.text = linea
	effect.add_theme_color_override("font_color",
		Palette.CREAM_D if cerrado else (Palette.GOLD_XL if alcanzable else Palette.RUST_L))

	for j in (cell["pips"] as Array).size():
		((cell["pips"] as Array)[j] as ColorRect).color = \
			Palette.GOLD_XL if j < level else Palette.NIGHT_LL

	# EL PRECIO. Al tope no hay nada que pagar: se esconde la moneda con su
	# numero y en su sitio va el rotulo, que es lo que sustituye al precio. El
	# rotulo dice COMPRA UNICA cuando no es que hayas llegado al tope sino que esa
	# opcion no tiene niveles (las de un solo nivel), y AL TOPE en las escaleras.
	(cell["coin"] as TextureRect).visible = not cerrado
	(cell["cost"] as PixelNumber).visible = not cerrado
	var owned: Label = cell["owned"]
	owned.visible = cerrado
	owned.text = "COMPRA UNICA" if tope <= 1 else "AL TOPE"
	if not cerrado:
		var num: PixelNumber = cell["cost"]
		var texto := PixelNumber.format(cost)
		num.color = Palette.CREAM if alcanzable else Palette.RUST_L
		num.set_number(cost)
		# La moneda y el numero, centrados como un grupo: se mide el numero ya
		# escrito (cambia de ancho con las cifras) y se reparte el hueco.
		var total := 28.0 + 6.0 + num.size.x
		var x0: float = float(cell["mid"]) - total * 0.5
		(cell["coin"] as TextureRect).position = Vector2(x0, 0.0) \
			+ Vector2(0.0, float(cell["y"]) + COST_DY - 14.0)
		num.position = Vector2(x0 + 34.0, float(cell["y"]) + COST_DY - num.size.y * 0.5)
		(cell["art"] as TextureRect).modulate = Color.WHITE if alcanzable \
			else Color(0.55, 0.55, 0.62, 1.0)
	else:
		(cell["art"] as TextureRect).modulate = Color(0.85, 0.85, 0.88)

	(cell["back"] as ColorRect).color = BACK_DONE if cerrado else BACK_OPEN
	for p in (cell["frame"] as Array):
		(p as ColorRect).color = EDGE_DONE if cerrado else EDGE_OPEN

	# El tooltip dice lo que hace la opcion, que es lo unico que la casilla no
	# puede enseñar (el efecto es un numero sin explicacion): el nombre, la frase
	# larga de LootDB y en que punto esta. Es tambien como la prueba de raton
	# encuentra la casilla, igual que en la tienda.
	var button: Button = cell["button"]
	button.tooltip_text = "%s: %s NIVEL %d/%d" % [str(option["name"]),
		str(option["desc"]), level, tope]


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

## Comprar el siguiente nivel de una opcion. La casilla COMPRA directamente: en
## un arbol de habilidades no hay ficha que abrir (la opcion se explica sola en
## su casilla y en su tooltip) y el precio mas caro del arbol son ocho monedas,
## asi que el paso de mas solo haria lento lo que se hace de un vistazo.
##
## Quien no puede comprar NO se queda callado: el boton se pulsa igual y el aviso
## dice cuanto falta, como en la barra de las automatizaciones (ver game.gd,
## _locked_notice()) y en el panel de la hucha.
func _buy(option_id: String) -> void:
	var option := LootDB.skill_option(option_id)
	if option.is_empty():
		return
	var cost := Game.skill_cost(option_id)
	if cost < 0:
		Sound.play("sfx_error")
		Game.notice.emit("YA ESTA AL TOPE", Palette.GOLD)
		return
	if Game.rebirth_coins < cost:
		Sound.play("sfx_error")
		Game.notice.emit("TE FALTAN %d MONEDAS" % (cost - Game.rebirth_coins),
			Palette.RUST_L)
		return
	if not Game.buy_skill(option_id):
		Sound.play("sfx_error")
		return
	Sound.play("sfx_tool")
	Game.notice.emit("%s: NIVEL %d/%d" % [str(option["name"]),
		Game.skill_level(option_id), Game.skill_max_level(option_id)], Palette.GOLD_XL)


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# Se para el evento para que ESC cierre SOLO el arbol y no la hucha que hay
	# detras: este panel va en la capa de encima, asi que le llega antes.
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
