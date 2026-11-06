# ShopPanel - la tienda: los diez items que mejoran la apertura.
#
# LOS ITEMS SON CAJAS. Diez cajas en rejilla (cinco arriba y cinco abajo), cada
# una con su dibujo, su nombre, sus puntos de nivel y su precio. Antes eran dos
# columnas de filas con el icono a la izquierda y el texto al lado, y una lista de
# texto no dice "esto se puede coger": una caja si. Ademas, en rejilla caben los
# ocho en una pantalla sin scroll y se ven todos a la vez, que es lo que hace
# falta para decidir en que se gasta el dinero.
#
# Y LA CAJA NO COMPRA: abre la FICHA del item (ver ItemCard), que es donde estan
# la descripcion larga y -lo que de verdad decide- los numeros del efecto de
# ahora y del nivel siguiente. El precio de la caja esta para saber si llegas; el
# boton de comprar esta en la ficha, con esos numeros delante.
#
# DOS CLASES DE ITEM, y se nota en la caja. Los siete con niveles suben hasta
# ocho niveles, asi que la caja lleva los puntos de nivel y un precio que crece
# con cada uno. El PC y los Pinchos son de COMPRA UNICA: no hay nada que subir, y
# donde irian los puntos dicen COMPRA UNICA. Quien es cual lo dice
# LootDB.item_max_level(), no una lista aqui dentro.
#
# LOS SOBRES YA NO ESTAN AQUI. Se compran en la columna de la izquierda de la
# pantalla de partida (ver game.gd, _build_pack_zone()), a un clic de la mesa y
# sin abrir nada. En el panel se queda lo que si es una decision de vez en
# cuando: en que se gasta el dinero que sobra.
class_name ShopPanel
extends Control

signal closed()

const ITEM_CARD_SCENE := preload("res://scenes/ItemCard.tscn")

## El panel es la caja de carton claro (ui_panel_carton, 1600x960 centrado:
## x 160..1760 y 60..1020). Su cinta de embalar cruza la cabecera de y 92 a
## 172, y en ella van el titulo TIENDA y el dinero, a la altura HEAD_Y.
const HEAD_Y := 132.0
## La cinta roja del titulo (el mismo sprite que el precio de las fichas). Su
## dibujo solo pinta una banda en medio del alto, por eso es mas alta que la cifra.
const TITLE_TAG := Vector2(480, 120)
const TITLE_TAG_CENTER := Vector2(440, HEAD_Y)
## La placa del dinero: su borde derecho fijo antes de la solapa de cerrar.
const MONEY_RIGHT := 1590.0
const MONEY_H := 68.0
const MONEY_PAD := 24.0
const MONEY_COIN := 52.0
const MONEY_MAX_W := 520.0
const MONEY_TAPE := Vector2(60, 20)
## Una caja: 264 de ancho por 264 de alto, y la rejilla de cinco columnas y dos
## filas (diez items: cinco arriba y cinco abajo). Los pasos (288 y 324) dejan
## 24 px de aire entre cajas de la misma fila y 60 entre las dos filas. El ancho
## bajo de 320 a 264 al entrar el noveno item: cinco cajas de 320 no caben en el
## recuadro interior, que va de x 224 a x 1696.
##
## El alto lo manda lo que lleva dentro, de arriba abajo: el dibujo (112), el
## nombre (33), los puntos de nivel o COMPRA UNICA (22) y la chapa del precio
## (56). Todo va a multiplos de 4 y las medidas de la rejilla a multiplos de 8,
## para no descuadrar el pixelado al estirar.
const BOX := Vector2(264, 264)
const BOX_COL0_X := 252.0
const BOX_COL_STEP := 288.0
const BOX_ROW0_Y := 248.0
const BOX_ROW_STEP := 376.0
const PER_ROW := 5
const ICON_BOX := Vector2(112, 112)
const ICON_DY := 68.0
const NAME_DY := 150.0
const LEVEL_DY := 188.0
## La cinta del precio cruza la ficha entera y asoma 8 px por cada lado, como
## en la maqueta C (la de terciopelo) que eligio el usuario para el precio.
const TAG := Vector2(BOX.x + 16.0, 64)
const TAG_DY := 230.0
## La caja es una ficha de papel crema sobre el carton del panel, con el texto
## en oscuro. La comprada (o al tope) se oscurece y lleva el filete en dorado,
## que es lo que se ve de un vistazo al mirar la rejilla entera.
const BACK_OPEN := Palette.CREAM_L
const BACK_DONE := Palette.CREAM_D
const EDGE_OPEN := Palette.CREAM_D
const EDGE_DONE := Palette.GOLD_D
## Los puntos de nivel: los comprados en rojo, como la cinta del precio.
const PIP_ON := Palette.RUST_L
const PIP_OFF := Palette.CREAM_D
const EDGE := 4.0
## La sombra de la ficha sobre el carton y el trozo de celo que la sujeta.
const SHADOW := Color(0.35, 0.23, 0.16, 0.63)
const SHADOW_OFF := Vector2(8, 8)
const TAPE := Color(0.93, 0.89, 0.77, 0.8)
const TAPE_SIZE := Vector2(80, 24)

var _money: PixelNumber
var _money_plate: ColorRect
var _money_back: ColorRect
var _money_shadow: ColorRect
var _money_tape: ColorRect
var _money_coin: TextureRect
var _item_cells: Array = []
## La ficha abierta, si hay una. Solo puede haber una: es una capa por encima de
## la tienda y la tienda ya es una capa.
var _card: ItemCard = null


func _ready() -> void:
	add_child(UIKit.veil(0.55))
	add_child(UIKit.panel("ui_panel_carton"))

	var close := UIKit.close_button(UIKit.PANEL_CLOSE)
	close.pressed.connect(_close)
	add_child(close)

	_build_money()
	_build_items()

	Game.money_changed.connect(_on_money_changed)
	Game.items_changed.connect(refresh)
	refresh()


# --------------------------------------------------------------------------- #
# Dinero
# --------------------------------------------------------------------------- #

## La cabecera, sobre la cinta de embalar: a la izquierda TIENDA, con las
## letras doradas de los precios, en una cinta roja como la de las fichas; a la
## derecha, el dinero en una etiqueta de papel crema pegada con celo, como las
## fichas de los items. Cada
## cosa va sobre algo suyo: sueltos encima de la cinta parecian flotar.
func _build_money() -> void:
	add_child(UIKit.image("ui_tag_price", TITLE_TAG_CENTER, TITLE_TAG))
	var titulo := PixelNumber.new()
	titulo.scale_factor = 0.56
	titulo.name = "Titulo"
	add_child(titulo)
	titulo.set_text("TIENDA")
	titulo.position = (TITLE_TAG_CENTER - titulo.size * 0.5).round()

	_money = PixelNumber.new()
	_money.scale_factor = 0.40
	_money.max_width = MONEY_MAX_W
	_money.set_number(Game.money)
	_money_shadow = _rect(Vector2.ZERO, Vector2.ZERO, SHADOW)
	_money_plate = _rect(Vector2.ZERO, Vector2.ZERO, EDGE_OPEN)
	_money_back = _rect(Vector2.ZERO, Vector2.ZERO, BACK_OPEN)
	_money_tape = _rect(Vector2.ZERO, MONEY_TAPE, TAPE)
	_money_coin = UIKit.square("currency_coin", Vector2.ZERO, 0.12)
	add_child(_money_coin)
	add_child(_money)
	_place_money()


## La placa del dinero crece hacia la IZQUIERDA con la cifra: su borde derecho
## se queda fijo antes de la solapa de cerrar.
func _place_money() -> void:
	var coin := MONEY_COIN
	var w := MONEY_PAD * 2.0 + coin + 12.0 + _money.size.x
	var plate := Rect2(Vector2(MONEY_RIGHT - w, HEAD_Y - MONEY_H * 0.5), Vector2(w, MONEY_H))
	_money_shadow.position = plate.position + Vector2(6, 6)
	_money_shadow.size = plate.size
	_money_tape.position = Vector2(plate.get_center().x - MONEY_TAPE.x * 0.5,
			plate.position.y - MONEY_TAPE.y * 0.5)
	_money_plate.position = plate.position
	_money_plate.size = plate.size
	_money_back.position = plate.position + Vector2(EDGE, EDGE)
	_money_back.size = plate.size - Vector2(EDGE, EDGE) * 2.0
	_money_coin.position = Vector2(plate.position.x + MONEY_PAD + coin * 0.5, HEAD_Y) \
			- _money_coin.size * 0.5
	_money.position = Vector2(plate.position.x + MONEY_PAD + coin + 12.0,
			HEAD_Y - _money.size.y * 0.5).round()


func _on_money_changed(_v: int) -> void:
	refresh()


# --------------------------------------------------------------------------- #
# Items
# --------------------------------------------------------------------------- #

func _build_items() -> void:
	# Un solo tamaño de nombre para las diez cajas, como en la lista de sobres:
	# encoger cada uno por su cuenta deja "PC" a 28 y "OJO VERDE" a 21 en la misma
	# rejilla, y eso se lee como un fallo.
	var nombres: Array = []
	for i in LootDB.item_count():
		nombres.append(str(LootDB.item_at(i)["name"]))
	var name_size := UIKit.row_size(nombres, BOX.x - 24.0, 28)

	for i in LootDB.item_count():
		var col := i % PER_ROW
		var row := i / PER_ROW
		var top_left := Vector2(BOX_COL0_X + float(col) * BOX_COL_STEP,
				BOX_ROW0_Y + float(row) * BOX_ROW_STEP)
		_item_cells.append(_item_box(LootDB.item_at(i), i, top_left, name_size))


## Una caja de la rejilla: fondo con filete, dibujo, nombre, puntos de nivel (o
## COMPRA UNICA) y la chapa del precio con lo que cuesta el siguiente nivel.
##
## Devuelve las piezas que hay que repintar cuando cambia el nivel o el dinero
## (ver _refresh_items): si no, el que mire la rejilla despues de comprar veria el
## precio viejo.
func _item_box(item: Dictionary, index: int, top_left: Vector2, name_size: int) -> Dictionary:
	var x := top_left.x
	var y := top_left.y

	# La caja: una ficha de papel con filete, su sombra y un trozo de celo
	# arriba. NO es un ui_slot estirado a 264x264: el marco del slot es cuadrado
	# y estirarlo descuadra su bevel, que es lo unico que le da volumen.
	_rect(top_left + SHADOW_OFF, BOX, SHADOW)
	var back := ColorRect.new()
	back.color = BACK_OPEN
	back.position = top_left
	back.size = BOX
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var frame := _frame(top_left, EDGE_OPEN)
	_rect(Vector2(x + (BOX.x - TAPE_SIZE.x) * 0.5, y - TAPE_SIZE.y * 0.5), TAPE_SIZE, TAPE)

	# El dibujo del item, colocado por su DIBUJO dentro de la caja (ver
	# UIKit.fit_art): los diez items no llenan igual su lienzo y escalados por el
	# lienzo se verian de tres tamaños distintos.
	var art := UIKit.fit_art(str(item["art"]), Vector2(x + BOX.x * 0.5, y + ICON_DY),
			ICON_BOX)
	add_child(art)

	# Texto oscuro SIN contorno (la fuente del titulo): sobre el papel claro, el
	# contorno de la fuente normal lo emborronaba.
	var name_label := UIKit.title_label_at(str(item["name"]),
			Vector2(x + BOX.x * 0.5, y + NAME_DY), Vector2(BOX.x - 24.0, 36),
			UIKit.fit_size(str(item["name"]), BOX.x - 24.0, name_size), Palette.OUTLINE)
	add_child(name_label)

	# Los puntos de nivel SOLO en los items que suben de nivel. En el PC y en los
	# Pinchos no hay nada que marcar: son de una sola compra, y ocho cuadros
	# vacios debajo del nombre solo dirian que no los has subido, que es
	# justamente lo que no se puede hacer.
	#
	# Y en su sitio, donde irian los puntos, va el rotulo que LO DICE: "COMPRA
	# UNICA". Sin el, la caja del PC solo se distinguiria de las demas por lo que
	# NO tiene (ni puntos ni segundo precio), y eso no se lee: hay que leerlo.
	var pips: Array = []
	var max_level := LootDB.item_max_level(index)
	var una_vez: Label = null
	if max_level > 1:
		pips = _pips(Vector2(x + BOX.x * 0.5, y + LEVEL_DY), max_level, 10.0, 4.0)
	else:
		una_vez = UIKit.title_label_at("COMPRA UNICA",
				Vector2(x + BOX.x * 0.5, y + LEVEL_DY), Vector2(BOX.x - 40.0, 24),
				UIKit.fit_size("COMPRA UNICA", BOX.x - 40.0, 14), Palette.GOLD_D)
		add_child(una_vez)

	var tag := Vector2(x + BOX.x * 0.5, y + TAG_DY)
	var tag_node := UIKit.image("ui_tag_price", tag, TAG)
	add_child(tag_node)
	var cost := PixelNumber.new()
	cost.scale_factor = 0.38
	cost.max_width = TAG.x - 28.0
	add_child(cost)
	cost.set_number(int(item["base_cost"]))
	cost.position = tag - cost.size * 0.5

	# El rotulo de "esta caja ya no se puede pagar" va en el MISMO sitio que la
	# chapa del precio, que es lo que sustituye, asi que los dos se turnan sin
	# moverse: COMPRADO en las piezas de compra unica y AL TOPE en un item de
	# niveles que ha llegado a los ocho.
	#
	# Y es una Label y no un PixelNumber a proposito: la fuente del PixelNumber
	# solo tiene glifos de DIGITOS, asi que un texto con letras NO se dibuja. El
	# "MAX" que hacia este trabajo antes salia en blanco, y esa era la razon de
	# que las cajas al tope parecieran tener un hueco roto.
	# En dorado oscuro, como COMPRA UNICA: el dorado claro no se leia sobre el papel.
	var owned_label := UIKit.title_label_at("", tag, TAG, 21, Palette.GOLD_D)
	owned_label.visible = false
	add_child(owned_label)

	# Sin tooltip: el hover con recuadro flotante no le gusta al usuario. La caja
	# entera es la zona de clic (la caja es lo que se mira, no donde hay que
	# apuntar) y lo que hace el clic lo dice su propio tooltip, que es lo que
	# buscan las pruebas de raton.
	var b := UIKit.hit_area(self, Rect2(top_left, BOX),
			"Ver ficha de " + str(item["name"]))
	b.pressed.connect(_open_card.bind(index))
	return {"art": art, "back": back, "frame": frame, "owned": owned_label,
			"cost": cost, "tag": tag, "tag_node": tag_node, "pips": pips,
			"once": una_vez, "button": b}


func _rect(at: Vector2, size: Vector2, color: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.position = at
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


## El filete de una caja: cuatro rectangulos planos. No es un sprite porque la
## caja mide lo que mide y un sprite habria que estirarlo, y en este juego el arte
## se estira a escalas enteras o no se estira.
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


static func _pips_width(total: int, side: float, gap: float) -> float:
	return float(total) * (side + gap) - gap


## Los puntos de nivel de un item. Son rectangulos planos, no un sprite: son
## informacion, no arte.
func _pips(centre: Vector2, total: int, side: float = 18.0, gap: float = 8.0) -> Array:
	var nodes: Array = []
	var x0 := centre.x - float(total) * (side + gap) * 0.5 + gap * 0.5
	for i in total:
		var r := ColorRect.new()
		r.size = Vector2(side, side)
		r.position = Vector2(x0 + float(i) * (side + gap), centre.y - side * 0.5)
		r.color = PIP_OFF
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		nodes.append(r)
	return nodes


# --------------------------------------------------------------------------- #
# Refresco
# --------------------------------------------------------------------------- #

func refresh() -> void:
	if is_instance_valid(_money):
		_money.set_number(Game.money)
		_place_money()
	_refresh_items()


func _refresh_items() -> void:
	for i in _item_cells.size():
		var cell: Dictionary = _item_cells[i]
		if not is_instance_valid(cell["art"]):
			continue
		var level := Game.item_level(i)
		var max_level := Game.item_max_level(i)
		var cost := Game.item_cost(i)
		var num: PixelNumber = cell["cost"]
		var tag: Vector2 = cell["tag"]
		var rotulo: Label = cell["owned"]
		var frame: Array = cell["frame"]
		# cost < 0 es "aqui ya no hay nada que pagar": o es de compra unica y ya
		# es tuyo (COMPRADO), o esta al tope de sus ocho niveles (AL TOPE). Ni
		# precio ni chapa: la chapa se ESCONDE en vez de dejarse vacia, que una
		# chapa de precio en blanco se lee como un fallo de dibujo.
		var cerrado := cost < 0
		rotulo.text = "COMPRADO" if max_level <= 1 else "AL TOPE"
		rotulo.visible = cerrado
		(cell["tag_node"] as TextureRect).visible = not cerrado
		num.visible = not cerrado
		(cell["back"] as ColorRect).color = BACK_DONE if cerrado else BACK_OPEN
		for p in frame:
			(p as ColorRect).color = EDGE_DONE if cerrado else EDGE_OPEN
		# Los puntos de nivel de los items que suben: los comprados en dorado y el
		# resto en el gris de fondo.
		for j in (cell["pips"] as Array).size():
			((cell["pips"] as Array)[j] as ColorRect).color = \
					PIP_ON if j < level else PIP_OFF
		if cerrado:
			(cell["art"] as TextureRect).modulate = Color(0.85, 0.85, 0.88)
			continue
		# El color va ANTES del texto, siempre: PixelNumber solo lo aplica al
		# construir los glifos (ver pixel_number.gd, _rebuild), asi que al reves el
		# numero se queda del color que tuviera la vez anterior.
		# Sin dinero, el numero se apaga (ver Palette.PRICE_OFF).
		num.color = Palette.CREAM if Game.can_afford(cost) else Palette.PRICE_OFF
		num.set_number(cost)
		(cell["art"] as TextureRect).modulate = _lit(Game.can_afford(cost))
		# El texto acaba de cambiar de ancho, asi que se vuelve a centrar.
		num.position = tag - num.size * 0.5


static func _lit(affordable: bool) -> Color:
	return Color.WHITE if affordable else Color(0.55, 0.55, 0.62, 1.0)


# --------------------------------------------------------------------------- #
# La ficha de un item
# --------------------------------------------------------------------------- #

## Abrir la ficha del item de esta caja. La ficha se cuelga de la capa de encima
## (la de las tarjetas), no de la tienda: el panel de la tienda mide la pantalla
## entera y un hijo suyo no se puede poner por encima de su propio marco.
func _open_card(index: int) -> void:
	if _card != null:
		return
	var raiz := MainRoot.get_root()
	if raiz == null:
		return
	Sound.click()
	_card = ITEM_CARD_SCENE.instantiate() as ItemCard
	_card.closed.connect(_close_card)
	# La ficha no compra: pide la compra, y aqui se hace con la misma logica que
	# el clic en una caja de la lista (ver _on_item). Asi comprar desde los dos
	# sitios es exactamente lo mismo: cobra, suena y avisa igual.
	_card.buy_requested.connect(_on_item)
	_card.show_item(index)
	raiz.push_overlay(_card)


## Cerrar la ficha. `_card` se suelta ANTES de emitir nada: el refresco de la
## tienda repinta los precios, y con la ficha a medias de quitar podria volver a
## pedirla.
func _close_card() -> void:
	if _card == null:
		return
	var raiz := MainRoot.get_root()
	if raiz != null:
		raiz.pop_overlay(_card)
	_card = null
	refresh()


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

## Comprar el siguiente nivel de un item. Es tambien lo que hace el boton
## COMPRAR de la ficha: quien compra es la tienda siempre, no la ficha.
func _on_item(index: int) -> void:
	var cost := Game.item_cost(index)
	if cost < 0:
		Sound.play("sfx_error")
		Game.notice.emit("YA LO TIENES" if Game.item_max_level(index) <= 1
				else "YA ESTA AL TOPE", Palette.GOLD)
		return
	if not Game.can_afford(cost):
		Sound.play("sfx_error")
		Game.notice.emit("NO TE LLEGA", Palette.RUST_L)
		return
	Game.buy_item(index)
	Sound.play("sfx_tool")
	Game.notice.emit("COMPRADO" if Game.item_max_level(index) <= 1
			else "+1 NIVEL", Palette.GOLD_XL)
	refresh()


func _close() -> void:
	Sound.click()
	# La ficha que estuviera abierta se va con la tienda: si no, se quedaria sola
	# encima de la mesa, sin tienda detras y sin forma de volver a abrirla.
	if _card != null:
		_close_card()
	closed.emit()
	queue_free()


## "2.10" -> "2.1"
static func trim(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Con la ficha abierta, ESC es de la ficha: ella lo dice y para el evento
		# (ver ItemCard._unhandled_input), asi que aqui no se cierra la tienda.
		if _card != null:
			return
		_close()
		get_viewport().set_input_as_handled()
