# AutoBuyPanel - el mini menu de la compra automatica.
#
# La compra automatica no es un interruptor de SI o NO: tambien es QUE se
# compra. Con los doce sobres marcados va subiendo de escalon sola segun se
# enriquece el jugador, y marcando solo los de arriba se apunta a lo caro. Eso
# no cabe en un boton de la barra, asi que el boton abre este panel.
#
# Solo se puede llegar aqui con SU pieza comprada (el PC, ver
# LootDB.AUTO_ITEM_BUY): el boton que abre esto ni siquiera responde antes (ver
# game.gd, _open_auto_buy()). Por eso el panel no repite la explicacion del
# candado: cuando se abre, ya esta abierto.
class_name AutoBuyPanel
extends Control

signal closed()

## Las mismas medidas que la tienda, que usa el mismo panel: ui_panel_shop.png es
## de 1600x960 y se dibuja tal cual, con el interior de x 224..1696 e y 140..940.
## Todo va a multiplos de 8 para no descuadrar el pixelado.
const TITLE_Y := 250.0
const TOGGLE_Y := 340.0
## La lista: dos columnas de seis, que son los once sobres de pago (el gratuito
## de la columna no entra: la compra automatica lo salta a proposito, ver
## game.gd, _auto_buy_step()).
const COL0_X := 280.0
const COL1_X := 980.0
const COL_W := 660.0
const ROW0_Y := 452.0
const ROW_STEP := 82.0
const ROW_H := 68.0
const PER_COL := 6
const PACK_ART := 72.0
## La caja del nombre del sobre y donde empieza. Es lo que queda entre el dibujo
## y la chapita del precio.
const PACK_NAME_W := 280.0
const PACK_NAME_X := 176.0
## El tamano del nombre, UNO para las once filas (lo calcula _build_packs).
##
## Con uno por fila y shrink, "SOBRES ORO" saldria a 21 y "ELECTRONICA LUJO"
## (16 caracteres en 280 px: 336) a 14, y una lista con dos tamanos se lee como
## un fallo. El que manda es el mas largo, asi que aqui los once bajan a 14: la
## caja de esta lista no da para mas, y el nombre ya lleva el escalon dentro
## (ORO / LUJO), que es a lo que no se puede renunciar.
var _name_size := 21
## La chapita del precio, mas ancha que la de la tienda: aqui el sobre mas caro
## cuesta diez millones, y "10.000.000" son once glifos. Con 140 px el numero
## tenia que encogerse tanto que dejaba de leerse.
## 192x56 y no 168x44: con la chapa baja las cifras iban a 0,22 (16 px de alto) y
## "10.000.000" se salia de la cinta. Ahora la cinta llega hasta el borde de la
## fila y el numero va a 0,28.
const PACK_TAG := Vector2(192, 56)

var _box: TextureRect
var _cells: Array = []


func _ready() -> void:
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))

	add_child(UIKit.label_at("COMPRA AUTOMATICA", Vector2(960, TITLE_Y),
			Vector2(1400, 70), 48, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	var close := UIKit.close_button(Vector2(1650, TITLE_Y), 96.0)
	close.pressed.connect(_close)
	add_child(close)

	_build_toggle()
	_build_packs()
	refresh()


# --------------------------------------------------------------------------- #
# El interruptor
# --------------------------------------------------------------------------- #

## La fila de encendido. Es la misma casilla que la de los ajustes, por el mismo
## motivo: es un interruptor, y en este juego un interruptor ya se dibuja asi.
func _build_toggle() -> void:
	add_child(UIKit.image("ui_icon_auto_buy", Vector2(540, TOGGLE_Y), Vector2(112, 112)))
	add_child(UIKit.label_at("ENCENDIDA", Vector2(880, TOGGLE_Y - 18.0),
			Vector2(560, 50), 35, Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	# La regla, escrita donde se decide: sin esto el jugador no sabe por que a
	# veces compra el de 1.000 y a veces el de 400.000. Y a tamano 16 en una caja
	# de 560 (29 caracteres son 464 px): con la caja justa, shrink lo encogia
	# hasta que dejaba de leerse.
	add_child(UIKit.label_at("EL MAS BARATO DE LOS MARCADOS",
			Vector2(880, TOGGLE_Y + 28.0), Vector2(560, 34), 16, Palette.CREAM_D,
			HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	_box = UIKit.image(_check_tex(Game.auto_buy), Vector2(1260, TOGGLE_Y),
			Vector2(96, 96))
	add_child(_box)
	UIKit.hit_area(self, Rect2(Vector2(1212, TOGGLE_Y - 48.0), Vector2(96, 96))
			).pressed.connect(_toggle)


# --------------------------------------------------------------------------- #
# La lista de sobres
# --------------------------------------------------------------------------- #

func _build_packs() -> void:
	# Un solo tamano para los once nombres: ver _name_size.
	var nombres: Array = []
	for n in LootDB.pack_count():
		var p: Dictionary = LootDB.pack_at(n)
		if Game.pack_price(str(p["id"])) > 0:
			nombres.append(str(p["name"]))
	_name_size = UIKit.row_size(nombres, PACK_NAME_W, 21)

	var i := 0
	for n in LootDB.pack_count():
		var pack: Dictionary = LootDB.pack_at(n)
		var price := Game.pack_price(str(pack["id"]))
		# El sobre gratuito no entra en la lista. No es un olvido: la compra
		# automatica lo salta SIEMPRE (si lo comprara se quedaria en el para
		# siempre y no gastaria un duro en los de pago), asi que ponerlo aqui
		# seria una casilla que no hace nada.
		if price <= 0:
			continue
		var col := i / PER_COL
		var row := i % PER_COL
		i += 1
		var x := COL0_X if col == 0 else COL1_X
		var y := ROW0_Y + float(row) * ROW_STEP
		_cells.append(_pack_row(pack, price, Vector2(x, y)))


## Una fila: casilla, dibujo del sobre, nombre y precio. Toda la fila es la zona
## de clic (la casilla es lo que se mira, no donde hay que apuntar).
func _pack_row(pack: Dictionary, price: int, top_left: Vector2) -> Dictionary:
	var x := top_left.x
	var y := top_left.y

	var back := ColorRect.new()
	back.color = Color(1.0, 1.0, 1.0, 0.045)
	back.position = Vector2(x, y - ROW_H * 0.5)
	back.size = Vector2(COL_W, ROW_H)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var box := UIKit.image(_check_tex(Game.auto_buy_wants(str(pack["id"]))),
			Vector2(x + 40.0, y), Vector2(64, 64))
	add_child(box)

	# fit_art y no square: el sobre se coloca por su DIBUJO, que es lo que hace
	# que las cartas (estrechas) y las zapatillas (anchas) se vean del mismo
	# tamano en la lista.
	var art := UIKit.fit_art(str(pack["art"]), Vector2(x + 130.0, y),
			Vector2(PACK_ART, PACK_ART))
	add_child(art)

	var label := UIKit.label_at(str(pack["name"]),
			Vector2(x + PACK_NAME_X + PACK_NAME_W * 0.5, y),
			Vector2(PACK_NAME_W, 34), _name_size, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_LEFT, 0, true)
	add_child(label)

	var tag := Vector2(x + COL_W - PACK_TAG.x * 0.5, y)
	var tag_node := UIKit.image("ui_tag_price", tag, PACK_TAG)
	add_child(tag_node)
	var num := PixelNumber.new()
	num.scale_factor = 0.28
	num.max_width = PACK_TAG.x - 40.0
	add_child(num)
	num.set_number(price)
	num.position = tag - num.size * 0.5

	var hit := UIKit.hit_area(self, Rect2(Vector2(x, y - ROW_H * 0.5),
			Vector2(COL_W, ROW_H)), "")
	hit.pressed.connect(_toggle_pack.bind(str(pack["id"])))
	return {"back": back, "box": box, "art": art, "label": label,
			"num": num, "tag": tag, "tag_node": tag_node, "button": hit}


# --------------------------------------------------------------------------- #
# Refresco
# --------------------------------------------------------------------------- #

func refresh() -> void:
	_box.texture = Sprites.tex(_check_tex(Game.auto_buy))
	# Un sobre desmarcado se APAGA entero (dibujo, nombre y precio): marcado o no
	# es la unica informacion de la fila, y el color lo dice de un vistazo sin
	# tener que ir mirando casilla por casilla.
	var i := 0
	for n in LootDB.pack_count():
		var pack: Dictionary = LootDB.pack_at(n)
		if Game.pack_price(str(pack["id"])) <= 0:
			continue
		if i >= _cells.size():
			break
		var cell: Dictionary = _cells[i]
		i += 1
		if not is_instance_valid(cell["box"]):
			continue
		var on := Game.auto_buy_wants(str(pack["id"]))
		(cell["box"] as TextureRect).texture = Sprites.tex(_check_tex(on))
		for key in ["art", "label"]:
			(cell[key] as CanvasItem).modulate = Color.WHITE if on \
					else Color(0.5, 0.5, 0.58, 1.0)
		var num: PixelNumber = cell["num"]
		num.color = Palette.CREAM if on else Palette.RUST_L
		num.position = (cell["tag"] as Vector2) - num.size * 0.5


static func _check_tex(on: bool) -> String:
	return "ui_checkbox_on" if on else "ui_checkbox_off"


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

func _toggle() -> void:
	Sound.click()
	if not Game.set_auto_buy(not Game.auto_buy):
		Game.notice.emit("PRIMERO LOS PINCHOS Y EL PC", Palette.RUST_L)
		return
	Game.notice.emit("AUTO COMPRA: " + ("SI" if Game.auto_buy else "NO"),
			Palette.CREAM_D)
	refresh()


func _toggle_pack(pack_id: String) -> void:
	Sound.click()
	Game.set_auto_buy_wanted(pack_id, not Game.auto_buy_wants(pack_id))
	refresh()


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
