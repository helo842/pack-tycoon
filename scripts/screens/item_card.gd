# ItemCard - la ficha de un item de la tienda.
#
# La tienda enseña diez CAJAS con lo justo (el dibujo, el nombre, los puntos de
# nivel y el precio). Esta es la pantalla que se abre al pulsar una: que es el
# objeto y -lo que de verdad hace falta para decidir- LOS NUMEROS. Un "MAS BOTIN
# RARO" no dice si el siguiente nivel vale sus monedas; un "+2 % DE BOTIN RARO"
# al lado de un "+4 %" si.
#
# LOS NUMEROS SE SACAN DE LOOTDB, no se escriben aqui. Cada efecto se lee con
# LootDB.item_effect(), que aplica la formula de verdad de ese item al nivel que
# se le pida, asi que la ficha no puede mentir: si mañana cambia el +15 % de dano
# por nivel, la ficha lo dice sola sin que nadie se acuerde de tocarla.
#
# LA FICHA NO COMPRA: pide la compra. Emite buy_requested y quien la abrio (la
# tienda) hace la compra con su misma logica de siempre -cobrar, sonar y avisar-,
# que es la unica forma de que comprar desde la ficha y comprar desde la lista se
# comporten igual. Cuando el item sube de nivel, Game.items_changed la repinta, y
# por eso los numeros cambian solos al comprar.
class_name ItemCard
extends Control

signal closed()
## El jugador ha pulsado COMPRAR. Lleva el indice del item, que es lo que
## necesita quien sepa comprar (ver shop_panel.gd, _on_item()).
signal buy_requested(index: int)

## Las mismas medidas que la tienda, que usa el mismo panel: ui_panel_shop.png es
## de 1600x960 y se dibuja tal cual, con el interior de x 224..1696 e y 140..940.
## El titulo y la raya no dependen del item; lo que si depende se monta en _body y
## se vuelve a montar entero en cada refresco (ver refresh()).
const TITLE_Y := 196.0
const LEVEL_Y := 254.0
## El dibujo, a la izquierda, y la columna de texto, a la derecha. El dibujo se
## coloca por su DIBUJO dentro de ART_BOX (ver UIKit.fit_art): los diez items no
## llenan igual su lienzo y escalados por el lienzo se verian de tres tamaños.
const ART_CENTER := Vector2(500, 520)
const ART_BOX := Vector2(400, 400)
## La columna de texto. COL_MID es su CENTRO y COL_X su borde izquierdo, y no son
## intercambiables: label_at() y label() colocan por el CENTRO (ver ui_kit.gd,
## place()), asi que pasarle COL_X a una etiqueta la dibuja media columna a la
## izquierda y las lineas de la descripcion acaban encima del dibujo del objeto.
## COL_X se usa solo donde hace falta un BORDE: la raya que separa los dos bloques
## de la ficha (una ColorRect, que se coloca por su esquina).
const COL_X := 760.0
const COL_W := 860.0
const COL_MID := 1190.0
const DESC_Y := 340.0
## Las lineas de la descripcion larga. 860 px a tamaño 21 son 40 caracteres por
## linea, y el hueco da para CUATRO lineas: de 390 a 534, con la raya en 540 y
## los numeros en 560. La quinta ya los pisa, asi que las descripciones de
## LootDB estan escritas para caber en cuatro y el smoke test lo comprueba en
## los diez items (no solo en el que abre): alargar un texto sin mirar esto se
## ve como texto encima de los numeros, no como un error.
const DETAIL_Y := 390.0
const DETAIL_STEP := 36.0
const DETAIL_LINES_MAX := 4
## La raya que separa lo que ES el objeto de lo que HACE.
const SEPARATOR_Y := 540.0
const LINE_STEP := 40.0
const NOW_Y := 580.0
const NEXT_Y := 620.0
## La chapa del precio de la ficha: la ficha tiene sitio de sobra, y a 200x64 con
## las cifras a 0,34 el precio era lo mas pequeno de la pantalla siendo lo que
## se mira antes de pulsar COMPRAR.
const TAG := Vector2(256, 80)
const TAG_Y := 690.0
const BUY_CENTER := Vector2(1190, 830)
const BUY_W := 384.0

var _index: int = 0
## Todo lo que depende del item, para poder borrarlo y volver a montarlo. Se
## BORRA ademas de soltarse: un hijo que solo hace queue_free() sigue en el arbol
## hasta el final del frame, y en ese rato se dibujaria dos veces el mismo texto
## y las pruebas encontrarian el nodo viejo.
var _body: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))

	var close := UIKit.close_button(Vector2(1650, TITLE_Y), 96.0)
	close.pressed.connect(_close)
	add_child(close)

	var line := ColorRect.new()
	line.color = Color(Palette.GOLD_D, 0.7)
	line.position = Vector2(COL_X, SEPARATOR_Y)
	line.size = Vector2(COL_W, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	Game.items_changed.connect(refresh)
	refresh()


## Que item enseña la ficha. Se puede llamar antes de meterla en el arbol (como
## hace la tienda) o despues; en el primer caso el refresco lo hace _ready().
func show_item(index: int) -> void:
	_index = clampi(index, 0, LootDB.item_count() - 1)
	if is_node_ready():
		refresh()


func item_index() -> int:
	return _index


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

func refresh() -> void:
	if not is_node_ready():
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

	var item := LootDB.item_at(_index)
	var level := Game.item_level(_index)
	var tope := Game.item_max_level(_index)
	var cost := Game.item_cost(_index)

	# El nombre, de titulo, y debajo en que punto esta: el nivel que ya tiene de
	# los que puede llegar a tener, o si es de una sola compra.
	_add(UIKit.label_at(str(item["name"]), Vector2(960, TITLE_Y), Vector2(1200, 70),
			48, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var estado := "NIVEL %d DE %d" % [level, tope] if tope > 1 \
			else ("COMPRADO" if level > 0 else "COMPRA UNICA")
	_add(UIKit.label_at(estado, Vector2(960, LEVEL_Y), Vector2(1200, 44), 21,
			Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER))

	_add(UIKit.fit_art(str(item["art"]), ART_CENTER, ART_BOX))

	# Lo que hace, en corto y en largo. El corto es la misma linea que se lee en la
	# tienda (asi el que viene de la caja reconoce el texto) y el largo explica
	# como funciona de verdad.
	_add(UIKit.label_at(str(item["desc"]), Vector2(COL_MID, DESC_Y), Vector2(COL_W, 44),
			28, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var lineas := UIKit.wrap(str(item.get("detail", "")), COL_W, 21)
	for i in lineas.size():
		_add(UIKit.label_at(lineas[i],
				Vector2(COL_MID, DETAIL_Y + float(i) * DETAIL_STEP),
				Vector2(COL_W, DETAIL_STEP), 21, Palette.CREAM_D,
				HORIZONTAL_ALIGNMENT_LEFT))

	# Los numeros: el efecto de AHORA y el que tendra al subir. Es lo unico que
	# cambia al comprar, y por eso van juntos y con el mismo texto: comparar dos
	# lineas iguales es lo mas rapido que se puede leer.
	_add(UIKit.label_at("AHORA: " + LootDB.item_effect(_index, level),
			Vector2(COL_MID, NOW_Y), Vector2(COL_W, LINE_STEP), 21, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_CENTER))
	if cost < 0:
		# No hay nada que comprar: o es de una sola compra y ya es tuyo, o esta al
		# tope. Se DICE donde iria el boton, que es lo que sustituye.
		_add(UIKit.label_at("COMPRADO" if tope <= 1 else "AL TOPE",
				BUY_CENTER, Vector2(COL_W, 60), 42, Palette.GOLD_XL,
				HORIZONTAL_ALIGNMENT_CENTER))
		return
	# En el PC y en los Pinchos no hay "nivel siguiente" (solo tienen uno), asi
	# que el segundo numero se anuncia como lo que es: lo que pasa al comprarlo.
	var que := "AL COMPRARLO: " if tope <= 1 else "NIVEL %d: " % (level + 1)
	_add(UIKit.label_at(que + LootDB.item_effect(_index, level + 1),
			Vector2(COL_MID, NEXT_Y), Vector2(COL_W, LINE_STEP), 21, Palette.GOLD_XL,
			HORIZONTAL_ALIGNMENT_CENTER))

	# Los dos se llaman por su nombre: la chapa y el numero de dentro son lo unico
	# del panel que se puede medir de fuera (el numero tiene que caber en la
	# chapa), y buscarlos por el arbol sin nombre es adivinar cual de los dos es.
	var chapa := UIKit.image("ui_tag_price", Vector2(COL_MID, TAG_Y), TAG)
	chapa.name = "Tag"
	_add(chapa)
	var num := PixelNumber.new()
	num.name = "Cost"
	# El color va antes del texto: PixelNumber solo lo aplica al construir los
	# glifos (ver pixel_number.gd, _rebuild).
	num.color = Palette.CREAM if Game.can_afford(cost) else Palette.RUST_L
	num.scale_factor = 0.46
	num.max_width = TAG.x - 40.0
	num.set_number(cost)
	_add(num)
	num.position = Vector2(COL_MID, TAG_Y) - num.size * 0.5

	var b := UIKit.small_button("COMPRAR", "", BUY_CENTER, BUY_W, 30)
	b.pressed.connect(_on_buy)
	_add(b)


func _add(n: Node) -> void:
	_body.add_child(n)


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

## Comprar lo pide a quien la abrio (la tienda): la ficha no cobra ni avisa, para
## que comprar aqui y comprar en la lista sean exactamente lo mismo.
func _on_buy() -> void:
	buy_requested.emit(_index)


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# Se para el evento para que ESC cierre SOLO la ficha y no la tienda que hay
	# detras: esta capa va despues en el arbol, asi que le llega antes.
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
