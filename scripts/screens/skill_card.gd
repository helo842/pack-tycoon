# SkillCard - la ficha de compra de una mejora del arbol del rebirth.
#
# POR QUE EXISTE. Antes, pulsar un nodo lo compraba en el acto: el arbol entero
# se gastaba a base de clics y la unica explicacion de lo que acababas de pagar
# era una linea de aviso en la barra, que se borra al siguiente clic. Esta es la
# misma ficha que la tienda usa para sus items (ver item_card.gd): se pulsa el
# nodo, se ve que es, lo que da y lo que cuesta, y solo si se pulsa COMPRAR se
# paga. Es tambien el sitio donde cabe lo que un nodo NO puede decir en 176 px
# (el porque de sus numeros).
#
# LOS NUMEROS SON LOS DE Game Y SkillTree, no de aqui: el AHORA sale de
# Game.skill_bonus(stat) -lo mismo que aplica el juego a la partida- y el
# AL COMPRARLO del mismo numero mas el `value` del nodo. Escribir un "+20 %" a
# mano aqui seria la forma mas facil de que la ficha mienta el dia que alguien
# toque el equilibrio.
#
# LA FICHA NO COMPRA: pide la compra (buy_requested). Quien la abrio -el panel
# del arbol- hace la compra con su misma logica de siempre: cobrar, sonar y
# avisar. Asi comprar desde la ficha y comprar desde el nodo son lo mismo, que es
# la misma regla que sigue la ficha de la tienda.
class_name SkillCard
extends Control

signal closed()
## El jugador ha pulsado COMPRAR. Lleva el id del nodo, que es lo que necesita
## quien sepa comprar (ver rebirth_panel.gd, _on_buy_skill).
signal buy_requested(id: String)

## Las mismas medidas que la ficha de la tienda y que el arbol, que usan el mismo
## panel: ui_panel_shop.png es de 1600x960 y se dibuja tal cual, con el interior
## de x 224..1696 e y 140..940. Las constantes son las de ItemCard a proposito:
## las dos fichas se abren en el mismo sitio y una encima de la otra se leen
## igual, que es lo que se espera de dos pantallas del mismo juego.
const TITLE_Y := 196.0
## La segunda linea: el estado del nodo (sin comprar, comprado o que le falta).
const STATE_Y := 254.0
const ART_CENTER := Vector2(500, 520)
const ART_BOX := Vector2(400, 400)
## La columna de texto, a la derecha del dibujo. COL_MID es su CENTRO (label_at
## coloca por el centro) y COL_X su borde izquierdo, que se usa solo para la raya.
const COL_X := 760.0
const COL_W := 860.0
const COL_MID := 1190.0
const DESC_Y := 340.0
const DETAIL_Y := 390.0
const DETAIL_STEP := 36.0
## El hueco de la explicacion larga: de 390 a 534, con la raya en 540 y los
## numeros en 560. La quinta linea ya los pisa. Ver SkillTree.NODES, que es donde
## estan escritas para caber en cuatro.
const DETAIL_LINES_MAX := 4
const SEPARATOR_Y := 540.0
const LINE_STEP := 40.0
const NOW_Y := 580.0
const NEXT_Y := 620.0
## La chapa del precio y el boton, en la misma fila que en la tienda.
const TAG := Vector2(200, 64)
const TAG_Y := 690.0
const BUY_CENTER := Vector2(1190, 830)
const BUY_W := 384.0

## Lo que dice la ficha cuando el nodo ya es tuyo, en el sitio del boton.
const OWNED_TEXT := "COMPRADO"
## Y el nombre de lo que se paga: la moneda del rebirth, que es el cerdito. Va en
## el tooltip del precio porque en la chapa solo cabe el numero.
const COIN_NAME := "monedas de rebirth"

var _id := ""
## Todo lo que depende del nodo, para poder borrarlo y volver a montarlo entero
## en cada refresco (como en ItemCard): el estado cambia al comprar y los numeros
## del AHORA y del AL COMPRARLO con el.
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

	# Los numeros del AHORA cambian al comprar cualquier nodo (y el estado de este
	# tambien), asi que el refresco va con la senal que emite Game al comprar.
	Game.skills_changed.connect(refresh)
	refresh()


## Que mejora enseña la ficha. Se puede llamar antes de meterla en el arbol (como
## hace el panel) o despues; en el primer caso el refresco lo hace _ready().
func show_skill(id: String) -> void:
	_id = id
	if is_node_ready():
		refresh()


func skill_id() -> String:
	return _id


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

func refresh() -> void:
	if not is_node_ready():
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

	var node := SkillTree.node_by_id(_id)
	if node.is_empty():
		# Un id que ya no existe (un guardado viejo, un nodo borrado) no puede
		# pintar una ficha a medias: se cierra y se acabó. Sin esto, la ficha se
		# abriria con el titulo vacio y un precio que no es de nadie.
		_close()
		return

	var stat := str(node["stat"])
	var owned := Game.skill_owned(_id)
	var cost := Game.skill_cost(_id)

	# El titulo es el EFECTO y no un nombre: las mejoras del arbol no se llaman de
	# ninguna otra forma, y "+20 % DE DANO" dice mas que "MEJORA DE DANO".
	_add(UIKit.label_at(SkillTree.effect_text(_id), Vector2(960, TITLE_Y),
			Vector2(1200, 70), 48, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	_add(UIKit.label_at(_state_text(cost), Vector2(960, STATE_Y), Vector2(1200, 44), 21,
			Palette.GOLD_XL if cost < 0 or Game.can_buy_skill(_id) else Palette.RUST_L,
			HORIZONTAL_ALIGNMENT_CENTER))

	_add(UIKit.fit_art(str(node["art"]), ART_CENTER, ART_BOX))

	# Lo que hace, en corto y en largo. El corto es el mismo texto que lleva el
	# nodo en el arbol (asi el que viene del clic reconoce lo que ha pulsado) y el
	# largo explica de donde sale el numero y con que se junta.
	_add(UIKit.label_at(SkillTree.desc_of(_id), Vector2(COL_MID, DESC_Y),
			Vector2(COL_W, 44), 28, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var lineas := UIKit.wrap(SkillTree.detail_of(_id), COL_W, 21)
	for i in lineas.size():
		_add(UIKit.label_at(lineas[i], Vector2(COL_MID, DETAIL_Y + float(i) * DETAIL_STEP),
				Vector2(COL_W, DETAIL_STEP), 21, Palette.CREAM_D,
				HORIZONTAL_ALIGNMENT_LEFT))

	# Los dos numeros, y son los que de verdad van a valer: el AHORA es lo que el
	# arbol lleva sumado al stat en este momento y el AL COMPRARLO es eso mas lo
	# que suma este nodo. Es el par que hace falta para decidir, y por eso van
	# juntos y con el mismo texto: comparar dos lineas iguales se lee de un golpe.
	var ahora := Game.skill_bonus(stat)
	_add(UIKit.label_at("AHORA, CON EL ARBOL: " + SkillTree.total_text(stat, ahora),
			Vector2(COL_MID, NOW_Y), Vector2(COL_W, LINE_STEP), 21, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_CENTER))
	if cost < 0:
		# Ya es tuyo: no hay nada que pagar. Se DICE donde iria el boton, que es
		# lo que sustituye (igual que hace la ficha de la tienda).
		_add(UIKit.label_at(OWNED_TEXT, BUY_CENTER, Vector2(COL_W, 60), 42,
				Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER))
		return
	_add(UIKit.label_at("AL COMPRARLO: "
			+ SkillTree.total_text(stat, ahora + float(node["value"])),
			Vector2(COL_MID, NEXT_Y), Vector2(COL_W, LINE_STEP), 21, Palette.GOLD_XL,
			HORIZONTAL_ALIGNMENT_CENTER))

	# El precio: la chapa con el cerdito y su numero, el mismo par que en el arbol
	# y en la barra de la partida. El numero en ROJO cuando no llega, que es lo
	# unico de la ficha que se puede leer sin pensar.
	var chapa := UIKit.image("ui_tag_price", Vector2(COL_MID, TAG_Y), TAG)
	chapa.name = "Tag"
	chapa.tooltip_text = "Cuesta %d %s" % [cost, COIN_NAME]
	_add(chapa)
	var num := PixelNumber.new()
	num.name = "Cost"
	# El color va antes del texto: PixelNumber solo lo aplica al construir los
	# glifos (ver pixel_number.gd, _rebuild).
	num.color = Palette.CREAM if Game.can_buy_skill(_id) else Palette.RUST_L
	num.scale_factor = 0.34
	num.max_width = TAG.x - 24.0
	num.set_number(cost)
	_add(num)
	num.position = Vector2(COL_MID, TAG_Y) - num.size * 0.5

	# El boton va SIEMPRE que quede algo que comprar, tambien con el nodo cerrado
	# o sin monedas: un boton muerto y callado no explica nada, y lo que falta ya
	# lo dice la linea de arriba. Quien compra de verdad es el panel, que es el
	# que comprueba (ver rebirth_panel.gd, _on_buy_skill).
	var b := UIKit.small_button("COMPRAR", "currency_piggy", BUY_CENTER, BUY_W, 30)
	b.pressed.connect(_on_buy)
	_add(b)


## Lo que dice la segunda linea de la ficha: si ya es tuyo, de que nodo cuelga o
## cuantas monedas faltan. Es la unica frase que la ficha cambia de color, y lo
## que explica es siempre lo mismo: por que (no) se puede comprar ya.
func _state_text(cost: int) -> String:
	if cost < 0:
		return OWNED_TEXT
	if not Game.skill_unlocked(_id):
		# Colgado de otro nodo: se dice CUAL y lo que da, que es lo que hay que
		# comprar antes. El nombre del efecto es el idioma del arbol.
		return "ANTES: " + SkillTree.effect_text(SkillTree.req_of(_id))
	if not Game.can_buy_skill(_id):
		return "TE FALTAN %d MONEDAS" % Game.skill_missing_coins(_id)
	return "COMPRA UNICA"


func _add(n: Node) -> void:
	_body.add_child(n)


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

## Comprar lo pide a quien la abrio (el panel del arbol): la ficha no cobra ni
## avisa, para que comprar aqui y comprar desde el nodo sean exactamente lo mismo.
func _on_buy() -> void:
	buy_requested.emit(_id)


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# Se para el evento para que ESC cierre SOLO la ficha y no el arbol que hay
	# detras: esta capa va despues en el arbol de nodos, asi que le llega antes.
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
