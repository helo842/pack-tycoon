# ShopPanel - la tienda.
#
# Son dos cosas en el mismo panel porque comparten sitio y contexto: los cinco
# tipos de paquete (lo que se compra para jugar) y las cuatro herramientas (lo
# que se compra para abrir mas rapido). Las herramientas no hacen dano, acortan
# la espera, asi que la fila lleva el multiplicador de velocidad actual al lado.
class_name ShopPanel
extends Control

signal closed()
signal pack_chosen(pack_id: String)

## Todas las medidas caben en el recuadro interior del panel, que es
## x 224..1696 y 140..940: ui_panel_shop.png es de 1600x960 y se dibuja tal
## cual centrado, con el marco dorado de 48 px a cada lado. Las ranuras y las
## chapitas van a multiplos de 16, que es el tamano de un pixel de arte: asi no
## se descuadra el pixelado al estirar.
const PACK_SLOT := 192.0
const PACK_GAP := 80.0
const PACK_ROW_Y := 354.0
const PACK_NAME_DY := 126.0
const PACK_TAG_DY := 194.0
const TAG_SIZE := Vector2(200, 76)
const TOOLS_TITLE_Y := 624.0
const TOOL_SLOT := 136.0
const TOOL_GAP := 96.0
const TOOL_ART := 128.0
const TOOL_ROW_Y := 720.0
const TOOL_NAME_DY := 102.0
const TOOL_PIPS_DY := 136.0
const TOOL_TAG_DY := 178.0
const TOOL_TAG_SIZE := Vector2(144, 52)
# La caja del nombre se sale de la celda hasta media separacion: el hueco entre
# celdas es espacio gratis, y los nombres largos lo necesitan.
const NAME_WIDTH := PACK_SLOT + PACK_GAP * 0.5
const TOOL_NAME_WIDTH := TOOL_SLOT + TOOL_GAP * 0.5

var _name_size := 28
var _tool_name_size := 21

var _money: PixelNumber
var _speed: Label
var _pack_cells: Array = []
var _tool_cells: Array = []


func _ready() -> void:
	add_child(UIKit.veil(0.55))
	add_child(UIKit.panel("ui_panel_shop"))
	# El titulo va centrado en la franja de arriba, dentro del marco: antes
	# estaba a 135 y su mitad superior se montaba sobre el borde dorado.
	add_child(UIKit.label_at("TIENDA", Vector2(960, 192), Vector2(1600, 110), 64,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0))

	var close := UIKit.close_button(Vector2(1700, 150), 96.0)
	close.pressed.connect(_close)
	add_child(close)

	_build_money()
	_build_packs()
	_build_tools()

	Game.money_changed.connect(_on_money_changed)
	Game.tools_changed.connect(refresh)
	refresh()


# --------------------------------------------------------------------------- #
# Dinero
# --------------------------------------------------------------------------- #

func _build_money() -> void:
	# El dinero va en la misma franja que el titulo, a la izquierda. La moneda
	# a 0.20 son 102 px: a 0.22 se salia por arriba del marco y abajo pisaba la
	# primera ranura de sobres.
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
# Paquetes
# --------------------------------------------------------------------------- #

func _build_packs() -> void:
	var n := LootDB.pack_count()
	var total := float(n) * PACK_SLOT + float(n - 1) * PACK_GAP
	var x := 960.0 - total * 0.5 + PACK_SLOT * 0.5
	# Un solo tamano para los cinco nombres. Encogiendo cada uno por su cuenta
	# "ELECTRONICA" salia a 14 px y el resto a 28, y una fila con tres tamanos
	# distintos se lee como un fallo. El mas largo de la fila manda.
	var nombres: Array = []
	for i in n:
		nombres.append(LootDB.pack_at(i)["name"])
	_name_size = UIKit.row_size(nombres, NAME_WIDTH, 30)
	for i in n:
		_pack_cells.append(_pack_cell(LootDB.pack_at(i), Vector2(x, PACK_ROW_Y)))
		x += PACK_SLOT + PACK_GAP


func _pack_cell(pack: Dictionary, centre: Vector2) -> Dictionary:
	add_child(UIKit.slot(centre, PACK_SLOT))
	var art := UIKit.square(str(pack["art"]), centre, PACK_SLOT / 512.0)
	add_child(art)
	# La caja del nombre llega a media separacion: los nombres largos (11
	# caracteres) necesitan mas ancho que la celda, y lo que sobra entre celdas
	# es justo lo que hay.
	add_child(UIKit.label_at(str(pack["name"]), centre + Vector2(0, PACK_NAME_DY),
			Vector2(NAME_WIDTH, 44), _name_size, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	# El precio va en chapita: aqui es lo que cuesta, en la mesa lo que vale.
	var tag := centre + Vector2(0, PACK_TAG_DY)
	var tag_node := UIKit.image("ui_tag_price", tag, TAG_SIZE)
	add_child(tag_node)
	var price := PixelNumber.new()
	price.scale_factor = 0.36
	price.max_width = TAG_SIZE.x - 24.0
	add_child(price)
	price.set_number(int(pack["price"]))
	price.position = tag - price.size * 0.5

	var b := UIKit.hit_area(self, Rect2(Vector2(centre.x - PACK_SLOT * 0.5, 250),
			Vector2(PACK_SLOT, 350)), "Comprar %s por %s"
			% [pack["name"], PixelNumber.format(int(pack["price"]))])
	b.pressed.connect(_on_pack.bind(str(pack["id"])))
	return {"art": art, "price": price, "tag_node": tag_node, "button": b}


# --------------------------------------------------------------------------- #
# Herramientas
# --------------------------------------------------------------------------- #
func _build_tools() -> void:
	# El rotulo se queda a la izquierda del ancho interior (la caja va de 260 a
	# 1660) y el multiplicador a la derecha, para que no se pisen. Antes el
	# multiplicador vivia en x 1460..1780 y se salia del marco por la derecha.
	add_child(UIKit.label_at("HERRAMIENTAS - ACORTAN LA ESPERA",
			Vector2(860, TOOLS_TITLE_Y), Vector2(1200, 50), 32, Palette.GOLD,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	# "X" y no "x": la fuente del juego solo tiene mayusculas, y una minuscula
	# sale como un cajon vacio.
	# add_child NO sobra: sin el, la etiqueta se quedaba sin padre y el
	# multiplicador no se veia nunca en la tienda.
	_speed = UIKit.label_at("", Vector2(1580, TOOLS_TITLE_Y), Vector2(200, 50), 30,
		Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0)
	add_child(_speed)

	var n := LootDB.tool_count()
	var total := float(n) * TOOL_SLOT + float(n - 1) * TOOL_GAP
	var x := 960.0 - total * 0.5 + TOOL_SLOT * 0.5
	# Igual que en los sobres: un tamano para los cuatro nombres de la fila.
	var nombres: Array = []
	for i in n:
		nombres.append(LootDB.tool_at(i)["name"])
	_tool_name_size = UIKit.row_size(nombres, TOOL_NAME_WIDTH, 26)
	for i in n:
		_tool_cells.append(_tool_cell(LootDB.tool_at(i), i, Vector2(x, TOOL_ROW_Y)))
		x += TOOL_SLOT + TOOL_GAP


func _tool_cell(tool: Dictionary, index: int, centre: Vector2) -> Dictionary:
	add_child(UIKit.slot(centre, TOOL_SLOT))
	var art := UIKit.square(str(tool["art"]), centre, TOOL_ART / 512.0)
	add_child(art)
	add_child(UIKit.label_at(str(tool["name"]), centre + Vector2(0, TOOL_NAME_DY),
			Vector2(TOOL_NAME_WIDTH, 34), _tool_name_size, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var pips := _pips(centre + Vector2(0, TOOL_PIPS_DY), LootDB.TOOL_MAX_LEVEL)

	var tag := centre + Vector2(0, TOOL_TAG_DY)
	var tag_node := UIKit.image("ui_tag_price", tag, TOOL_TAG_SIZE)
	add_child(tag_node)
	var cost := PixelNumber.new()
	cost.scale_factor = 0.30
	cost.max_width = TOOL_TAG_SIZE.x - 20.0
	add_child(cost)
	cost.set_number(int(tool["base_cost"]))
	cost.position = tag - cost.size * 0.5

	var b := UIKit.hit_area(self, Rect2(Vector2(centre.x - TOOL_SLOT * 0.5, 644),
			Vector2(TOOL_SLOT, 292)), str(tool["name"]))
	b.pressed.connect(_on_tool.bind(index))
	# "tag" se guarda aparte porque el precio cambia de texto en cada refresco y
	# hay que recolocarlo: el ancho depende de cuantos digitos tenga.
	return {"art": art, "cost": cost, "tag": tag, "tag_node": tag_node,
			"pips": pips, "button": b}


## Los puntos de nivel de una herramienta. Son rectangulos planos, no un sprite:
## son informacion, no arte.
func _pips(centre: Vector2, total: int) -> Array:
	var nodes: Array = []
	var side := 18.0
	var gap := 8.0
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
	if is_instance_valid(_speed):
		_speed.text = "X%s" % trim(Game.speed_multiplier())
	_refresh_packs()
	_refresh_tools()


func _refresh_packs() -> void:
	for i in _pack_cells.size():
		var cell: Dictionary = _pack_cells[i]
		if not is_instance_valid(cell["art"]):
			continue
		var price := int(LootDB.pack_at(i)["price"])
		var affordable := Game.can_afford(price)
		(cell["art"] as TextureRect).modulate = _lit(affordable)
		(cell["price"] as PixelNumber).color = Palette.CREAM if affordable \
				else Palette.RUST_L


func _refresh_tools() -> void:
	for i in _tool_cells.size():
		var cell: Dictionary = _tool_cells[i]
		if not is_instance_valid(cell["art"]):
			continue
		var level := Game.tool_level(i)
		var cost := LootDB.tool_cost(i, level)
		var num: PixelNumber = cell["cost"]
		var tag: Vector2 = cell["tag"]
		for j in (cell["pips"] as Array).size():
			((cell["pips"] as Array)[j] as ColorRect).color = \
					Palette.GOLD_XL if j < level else Palette.NIGHT_LL
		if cost < 0:
			num.set_text("MAX")
			num.color = Palette.GOLD_XL
			(cell["art"] as TextureRect).modulate = Color.WHITE
		else:
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

func _on_pack(pack_id: String) -> void:
	var price := int(LootDB.pack_by_id(pack_id)["price"])
	if not Game.can_afford(price):
		Sound.play("sfx_error")
		Game.notice.emit("NO TE LLEGA", Palette.RUST_L)
		return
	Game.spend(price)
	Sound.play("sfx_buy")
	pack_chosen.emit(pack_id)
	refresh()


func _on_tool(index: int) -> void:
	var cost := Game.tool_cost(index)
	if cost < 0:
		Sound.play("sfx_error")
		Game.notice.emit("YA ESTA AL MAXIMO", Palette.GOLD)
		return
	if not Game.can_afford(cost):
		Sound.play("sfx_error")
		Game.notice.emit("NO TE LLEGA", Palette.RUST_L)
		return
	Game.buy_tool(index)
	Sound.play("sfx_tool")
	Game.notice.emit("+1 NIVEL", Palette.GOLD_XL)
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
