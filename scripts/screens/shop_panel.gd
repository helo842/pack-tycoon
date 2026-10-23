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

## Todas las medidas caben en el recuadro interior del panel, que es
## x 224..1696 y 140..940: ui_panel_shop.png es de 1600x960 y se dibuja tal
## cual centrado, con el marco dorado de 48 px a cada lado.
##
## EL TITULO NO PUEDE SUBIR MAS, y no es gusto: arriba a la izquierda esta el
## contador de dinero con su moneda (y 143..245), asi que un titulo mas alto le
## caeria encima. A 264 su linea empieza en 231 y la del dinero acaba en 214.
const ITEMS_TITLE_Y := 264.0
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
const BOX_ROW0_Y := 320.0
const BOX_ROW_STEP := 324.0
const PER_ROW := 5
const ICON_BOX := Vector2(112, 112)
const ICON_DY := 68.0
const NAME_DY := 150.0
const LEVEL_DY := 188.0
const TAG := Vector2(160, 56)
const TAG_DY := 230.0
## El fondo de la caja y su filete. La comprada se marca con el filete en dorado
## claro, que es lo que se ve de un vistazo al mirar la rejilla entera.
const BACK_OPEN := Color(0.02, 0.015, 0.04, 0.62)
const BACK_DONE := Color(0.10, 0.07, 0.02, 0.62)
const EDGE_OPEN := Color(Palette.GOLD_D, 0.85)
const EDGE_DONE := Color(Palette.GOLD_XL, 0.9)
const EDGE := 4.0

var _money: PixelNumber
var _item_cells: Array = []
## La ficha abierta, si hay una. Solo puede haber una: es una capa por encima de
## la tienda y la tienda ya es una capa.
var _card: ItemCard = null


func _ready() -> void:
	add_child(UIKit.veil(0.55))
	add_child(UIKit.panel("ui_panel_shop"))

	var close := UIKit.close_button(Vector2(1700, 150), 96.0)
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

## El dinero que llevas, arriba a la izquierda, con la moneda delante.
##
## El TITULO no vuelve ("TIENDA" ya lo dice el boton que abre el panel, y ocupaba
## la franja entera), pero la moneda si: es la que dice que el numero de al lado
## es dinero y no cualquier otra cuenta.
##
## La moneda a 0.20 son 102 px: a 0.22 se salia por arriba del marco y abajo
## pisaba la lista de items.
func _build_money() -> void:
	add_child(UIKit.square("currency_coin", Vector2(300, 194), 0.20))
	_money = PixelNumber.new()
	_money.scale_factor = 0.55
	_money.max_width = 460.0
	add_child(_money)
	_money.set_number(Game.money)
	_money.position = Vector2(430, 194 - _money.size.y * 0.5)


func _on_money_changed(_v: int) -> void:
	refresh()


# --------------------------------------------------------------------------- #
# Items
# --------------------------------------------------------------------------- #

func _build_items() -> void:
	add_child(UIKit.label_at("ITEMS - MEJORAN LA APERTURA",
			Vector2(960, ITEMS_TITLE_Y), Vector2(1200, 60), 42, Palette.GOLD,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))

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

	# La caja: un fondo oscuro con filete dorado, como la bandeja de los sobres
	# (ver game.gd, _build_pack_zone()). NO es un ui_slot estirado a 264x264: el
	# marco del slot es cuadrado y estirarlo descuadra su bevel, que es lo unico
	# que le da volumen.
	var back := ColorRect.new()
	back.color = BACK_OPEN
	back.position = top_left
	back.size = BOX
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var frame := _frame(top_left, EDGE_OPEN)

	# El dibujo del item, colocado por su DIBUJO dentro de la caja (ver
	# UIKit.fit_art): los diez items no llenan igual su lienzo y escalados por el
	# lienzo se verian de tres tamaños distintos.
	var art := UIKit.fit_art(str(item["art"]), Vector2(x + BOX.x * 0.5, y + ICON_DY),
			ICON_BOX)
	add_child(art)

	var name_label := UIKit.label_at(str(item["name"]),
			Vector2(x + BOX.x * 0.5, y + NAME_DY), Vector2(BOX.x - 24.0, 36),
			name_size, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
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
		una_vez = UIKit.label_at("COMPRA UNICA",
				Vector2(x + BOX.x * 0.5, y + LEVEL_DY), Vector2(BOX.x - 40.0, 24), 14,
				Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
		add_child(una_vez)

	var tag := Vector2(x + BOX.x * 0.5, y + TAG_DY)
	var tag_node := UIKit.image("ui_tag_price", tag, TAG)
	add_child(tag_node)
	var cost := PixelNumber.new()
	cost.scale_factor = 0.34
	cost.max_width = TAG.x - 24.0
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
	var owned_label := UIKit.label_at("", tag, TAG, 21, Palette.GOLD_XL,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true)
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
		r.color = Palette.NIGHT_LL
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
					Palette.GOLD_XL if j < level else Palette.NIGHT_LL
		if cerrado:
			(cell["art"] as TextureRect).modulate = Color(0.85, 0.85, 0.88)
			continue
		# El color va ANTES del texto, siempre: PixelNumber solo lo aplica al
		# construir los glifos (ver pixel_number.gd, _rebuild), asi que al reves el
		# numero se queda del color que tuviera la vez anterior.
		num.color = Palette.CREAM if Game.can_afford(cost) else Palette.RUST_L
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
