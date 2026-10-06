# ShopPanel - la tienda: los ocho items que mejoran la apertura.
#
# DOS CLASES DE FILA. Los seis items de estadisticas suben hasta ocho niveles,
# asi que su fila lleva los puntos de nivel y un precio que crece con cada uno.
# El PC y los Pinchos son de COMPRA UNICA: no hay nada que subir, asi que su
# fila no lleva puntos, dice COMPRA UNICA donde irian, y quita la chapa del
# precio y pone COMPRADO en cuanto se tienen. Quien es cual lo dice
# LootDB.item_max_level(), no una lista aqui dentro.
#
# LOS SOBRES YA NO ESTAN AQUI. Se compran en la columna de la izquierda de la
# pantalla de partida (ver game.gd, _build_pack_zone()), a un clic de la mesa y
# sin abrir nada. En el panel se queda lo que si es una decision de vez en
# cuando: en que se gasta el dinero que sobra.
class_name ShopPanel
extends Control

signal closed()

## Todas las medidas caben en el recuadro interior del panel, que es
## x 224..1696 y 140..940: ui_panel_shop.png es de 1600x960 y se dibuja tal
## cual centrado, con el marco dorado de 48 px a cada lado. Las ranuras y las
## chapitas van a multiplos de 16, que es el tamano de un pixel de arte: asi no
## se descuadra el pixelado al estirar.
##
## La lista de los ocho items va centrada en el panel. Al quitarse la fila de
## sobres y el titulo, el hueco de arriba se ha repartido a los dos lados de la
## lista en vez de dejarlo en blanco.
const ITEMS_TITLE_Y := 300.0
const ITEM_COL0_X := 280.0
const ITEM_COL1_X := 980.0
const ITEM_COL_W := 660.0
const ITEM_ROW0_Y := 380.0
const ITEM_ROW_STEP := 128.0
const ITEM_ICON := 64.0
const ITEM_TAG := Vector2(120, 46)
const ITEM_TEXT_X := 92.0

var _money: PixelNumber
var _item_cells: Array = []


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
	# El rotulo, centrado en el panel: ya no comparte la linea con el rotulo del
	# dano, que se ha quitado.
	add_child(UIKit.label_at("ITEMS - MEJORAN LA APERTURA",
			Vector2(960, ITEMS_TITLE_Y), Vector2(1200, 60), 42, Palette.GOLD,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	var per_col := 4
	for i in LootDB.item_count():
		var col := i / per_col
		var row := i % per_col
		var x := ITEM_COL0_X if col == 0 else ITEM_COL1_X
		var y := ITEM_ROW0_Y + float(row) * ITEM_ROW_STEP
		_item_cells.append(_item_cell(LootDB.item_at(i), i, Vector2(x, y)))


## Una fila de la lista de items: icono, nombre, descripcion, puntos de nivel (si
## el item sube de nivel) y precio. La descripcion va a la vista a proposito (no
## en un tooltip): es lo unico que dice que hace el item, y el usuario quiere
## leerlo sin pasar el raton.
func _item_cell(item: Dictionary, index: int, top_left: Vector2) -> Dictionary:
	var x := top_left.x
	var y := top_left.y
	var right := x + ITEM_COL_W

	# Fondo tenue de la fila, para separarla de la de al lado sin recargar. Las de
	# los items ya comprados van con un tinte dorado muy suave: se ve de un vistazo
	# cuanto catalogo queda sin leer el precio de cada fila.
	var back := ColorRect.new()
	back.color = Color(1.0, 1.0, 1.0, 0.045)
	back.position = Vector2(x, y - 50.0)
	back.size = Vector2(ITEM_COL_W, 100.0)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var art := UIKit.image(str(item["art"]), Vector2(x + 46.0, y), Vector2(ITEM_ICON, ITEM_ICON))
	add_child(art)

	# Los puntos de nivel SOLO en los items que suben de nivel. En el PC y en los
	# Pinchos no hay nada que marcar: son de una sola compra, y ocho cuadros
	# vacios debajo del nombre solo dirian que no los has subido, que es
	# justamente lo que no se puede hacer.
	#
	# Y en su sitio, donde irian los puntos, va el rotulo que LO DICE: "COMPRA
	# UNICA". Sin el, la fila del PC solo se distinguia de las demas por lo que NO
	# tenia (ni puntos ni segundo precio), y eso no se lee: hay que leerlo. Con el
	# rotulo, comprar el PC o los Pinchos una vez y no volver a verlos en la tienda
	# deja de ser una sorpresa.
	var pips: Array = []
	var max_level := LootDB.item_max_level(index)
	var una_vez: Label = null
	if max_level > 1:
		pips = _pips(Vector2(x + ITEM_TEXT_X + _pips_width(max_level, 10.0, 4.0) * 0.5,
				y + 22.0), max_level, 10.0, 4.0)
	else:
		# La caja va ancha a proposito (el rotulo mide 168 px: 12 caracteres x 14) y
		# la etiqueta se alinea por la izquierda de ESA caja, asi que queda en la
		# misma x que el nombre y la descripcion de arriba.
		var caja := Vector2(184, 24)
		una_vez = UIKit.label_at("COMPRA UNICA",
				Vector2(x + ITEM_TEXT_X + caja.x * 0.5, y + 22.0), caja, 14,
				Palette.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		add_child(una_vez)

	# Nombre y descripcion alineados a la izquierda, en la misma columna.
	var name_label := UIKit.label(str(item["name"]), 21, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size = Vector2(ITEM_COL_W - ITEM_TEXT_X - 150.0, 30)
	name_label.position = Vector2(x + ITEM_TEXT_X, y - 38.0)
	add_child(name_label)

	var desc := str(item.get("desc", ""))
	var desc_label := UIKit.label(desc, 14, Palette.CREAM_D,
			HORIZONTAL_ALIGNMENT_LEFT)
	desc_label.size = Vector2(ITEM_COL_W - ITEM_TEXT_X - 150.0, 22)
	desc_label.position = Vector2(x + ITEM_TEXT_X, y - 8.0)
	add_child(desc_label)

	var tag := Vector2(right - 68.0, y)
	var tag_node := UIKit.image("ui_tag_price", tag, ITEM_TAG)
	add_child(tag_node)
	var cost := PixelNumber.new()
	cost.scale_factor = 0.26
	cost.max_width = ITEM_TAG.x - 16.0
	add_child(cost)
	cost.set_number(int(item["base_cost"]))
	cost.position = tag - cost.size * 0.5

	# El rotulo de "esta fila ya no se puede pagar" va en el MISMO sitio que la
	# chapa del precio, que es lo que sustituye, asi que los dos se turnan sin
	# moverse de sitio: COMPRADO en las piezas de compra unica y AL TOPE en un item
	# de niveles que ha llegado a los ocho.
	#
	# Y es una Label y no un PixelNumber a proposito: la fuente del PixelNumber
	# solo tiene glifos de DIGITOS, asi que un texto con letras NO se dibuja. El
	# "MAX" que hacia este trabajo antes salia en blanco, y esa era la razon de
	# que las filas al tope parecieran tener un hueco roto.
	var owned_label := UIKit.label_at("", tag, ITEM_TAG, 17, Palette.GOLD_XL,
			HORIZONTAL_ALIGNMENT_CENTER)
	owned_label.visible = false
	add_child(owned_label)

	# Sin tooltip: el hover con recuadro flotante no le gusta al usuario, y la
	# descripcion ya esta escrita en la fila.
	var b := UIKit.hit_area(self, Rect2(Vector2(x, y - 52.0),
			Vector2(ITEM_COL_W, 100.0)), "")
	b.pressed.connect(_on_item.bind(index))
	return {"art": art, "back": back, "owned": owned_label, "cost": cost,
			"tag": tag, "tag_node": tag_node, "pips": pips, "once": una_vez,
			"button": b}


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
		# cost < 0 es "aqui ya no hay nada que pagar": o es de compra unica y ya
		# es tuyo (COMPRADO), o esta al tope de sus ocho niveles (AL TOPE). Ni
		# precio ni chapa: la chapa se ESCONDE en vez de dejarse vacia, que una
		# chapa de precio en blanco se lee como un fallo de dibujo.
		var cerrado := cost < 0
		rotulo.text = "COMPRADO" if max_level <= 1 else "AL TOPE"
		rotulo.visible = cerrado
		(cell["tag_node"] as TextureRect).visible = not cerrado
		num.visible = not cerrado
		(cell["back"] as ColorRect).color = Color(Palette.GOLD_XL, 0.055) if cerrado \
				else Color(1.0, 1.0, 1.0, 0.045)
		# Los puntos de nivel de los items que suben: los comprados en dorado y el
		# resto en el gris de fondo.
		for j in (cell["pips"] as Array).size():
			((cell["pips"] as Array)[j] as ColorRect).color = \
					Palette.GOLD_XL if j < level else Palette.NIGHT_LL
		if cerrado:
			(cell["art"] as TextureRect).modulate = Color(0.85, 0.85, 0.88)
			continue
		num.set_number(cost)
		var affordable := Game.can_afford(cost)
		num.color = Palette.CREAM if affordable else Palette.RUST_L
		(cell["art"] as TextureRect).modulate = _lit(affordable)
		# El texto acaba de cambiar de ancho, asi que se vuelve a centrar.
		num.position = tag - num.size * 0.5


static func _lit(affordable: bool) -> Color:
	return Color.WHITE if affordable else Color(0.55, 0.55, 0.62, 1.0)


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

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
		_close()
		get_viewport().set_input_as_handled()
