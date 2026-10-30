# RebirthPanel - el arbol de mejoras del rebirth: aqui se gastan las monedas.
#
# QUE ES. La mejora del CENTRO da +30 % de dinero y cuesta una moneda (es la
# puerta del arbol) y de ella salen CUATRO CAMINOS DIAGONALES, uno por lado, de
# tres monedas cada uno: mas dano, mas velocidad, mas huecos de armario y mas
# dano de pinchos. Todo lo que hay que comprar -lo que cuesta, lo que da y donde
# se dibuja- esta en SkillTree; aqui solo esta el dibujo y los clics.
#
# ANTES ESTO ERA LA HUCHA. El panel enseñaba lo que te llevarias al reiniciar y
# un boton para reiniciar, y no habia nada que decidir: cada moneda subia un 5 %
# el valor de lo que vendias sola, para siempre. Ahora la moneda se GASTA, y el
# rebirth pasa a ser un boton de la barra de arriba.
#
# LA BARRA VA ENCIMA DEL ARBOL, no al lado, porque el arbol se arrastra: el saldo
# de monedas, lo que te dara reiniciar y el requisito no pueden irse de la
# pantalla cuando el jugador se mueve. Va superpuesta a la vista y se pinta
# despues (o sea por encima), y el arbol se cuela por debajo de ella al
# desplazarse.
#
# EL ARRASTRE ES DE VERDAD. Pulsar y mover mueve el arbol; pulsar y soltar en el
# mismo sitio abre la FICHA de ese nodo (SkillCard), que es donde se ve lo que da
# y lo que cuesta y donde esta el boton de comprar. Son los dos gestos del MISMO
# boton, asi que quien decide es el movimiento acumulado (DRAG_SLOP): es la unica
# forma de que arrastrar empezando encima de un nodo funcione, que es como se
# empieza casi siempre. POR ESO LOS NODOS NO SON BOTONES: un Button de verdad se
# comeria la pulsacion y no habria arrastre desde encima de un nodo. Los nodos
# son dibujos (nada de la vista recoge el raton) y quien sabe cual has pulsado es
# _node_at(), que mira las cajas que ha colocado este mismo panel.
#
# LA FICHA NO COMPRA, pide la compra: quien cobra, suena y avisa es este panel
# (ver _on_buy_skill), que es el mismo camino de siempre. Abrir la ficha de un
# nodo NO cuesta nada y se puede hacer con cualquiera, tambien con los que ya son
# tuyos o con los que todavia estan cerrados: es justo donde se explica por que
# no se pueden comprar.
#
# LOS NUMEROS SON DE GAME Y DE SKILLTREE, NO DE AQUI. Lo que te llevarias sale de
# Game.pending_rebirth_coins() -el MISMO calculo que hace do_rebirth(), asi que la
# pantalla no puede prometer una cosa y dar otra- y los efectos y los precios de
# SkillTree. Escribir un 30 % a mano aqui seria la forma mas facil de que el dia
# que se cambie el equilibrio la pantalla mienta.
#
# LA CHAPA QUE LO ABRE ESTA EN LA BARRA DE LA PARTIDA, al lado de la tienda (ver
# game.gd, _open_rebirth), y vive apagada hasta llegar al requisito. El panel se
# abre igualmente cuando no se puede: el arbol se compra con monedas (que se
# ganan reiniciando) y lo que FALTA es lo unico util de una pantalla que todavia
# no se puede usar del todo.
class_name RebirthPanel
extends Control

signal closed()

const SKILL_CARD_SCENE := preload("res://scenes/SkillCard.tscn")

## La vista del arbol: el recuadro interior del panel (ui_panel_shop es de
## 1600x960, con el interior de x 224..1696 e y 140..940), recortado, con el mundo
## moviendose dentro. Es tambien la zona de arrastre: toda la pantalla util.
const VIEW_POS := Vector2(224, 140)
const VIEW_SIZE := Vector2(1472, 800)

## La barra de arriba, superpuesta al arbol. Su alto lo manda la chapa del
## REBIRTH, que mide 0,45 del ancho: con 288 son 130 px, que con 16 de aire por
## arriba y por abajo son los 150 de la barra.
const BAR_H := 150.0
## Casi opaca, y no es un capricho: el arbol se cuela POR DEBAJO de la barra, y con
## un 0.88 los rotulos de la fila que acaba de subir se leian a traves del fondo
## como un fantasma detras del saldo (se vio en la captura de la rama de calidad
## de vida, que es la primera que queda medio tapada). Con 0.97 la franja sigue
## leyendose como una capa por encima y no como un cristal.
const BAR_BACK := Color(0.02, 0.015, 0.04, 0.97)
const BAR_EDGE := Color(Palette.GOLD_D, 0.85)
const EDGE := 4.0
## Donde se apoya el arbol al abrir: pegado a la barra por arriba, que es el
## hueco que le queda libre.
const TREE_TOP := BAR_H + 8.0

## Las tres filas de la barra: el saldo (y lo que te dara reiniciar), el estado
## del rebirth y el aviso de la ultima mejora tocada.
const ROW_BANK := 178.0
const ROW_STATUS := 226.0
const ROW_HINT := 268.0
## El saldo: el cerdito y, a su derecha, las monedas sin gastar. La x del numero
## no es la del cerdito: el dibujo se coloca por su CENTRO, asi que los tres
## datos van encadenados (piggy > numero > rotulo) con su aire entre medias.
const BANK_X := 296.0
const BANK_ART := 72.0
const BANK_GAP := 12.0
const BANK_NUM_X := BANK_X + BANK_ART * 0.5 + BANK_GAP
const BANK_SCALE := 0.42
const BANK_MAX_W := 130.0
const BANK_LABEL_GAP := 16.0
## Y lo que te dara reiniciar, pegado al boton que lo hace: el rotulo y el numero
## anclado por su izquierda, que es lo que impide que se mueva al cambiar de
## cifras.
const PRIZE_CENTER := Vector2(1010, ROW_BANK)
const PRIZE_X := 1140.0
## Al mismo tamano que el numero de monedas de la izquierda: a 0,30 la cifra del
## premio salia de la mitad de alto que la de la hucha, y es la que se mira para
## decidir si se reinicia.
const PRIZE_SCALE := 0.42
const PRIZE_MAX_W := 72.0
## El bloque de texto de la izquierda: el estado y el aviso. De x 240 a 1210, que
## es donde empieza la chapa del REBIRTH (1216) menos 6 de aire. Son 970 px y no
## menos porque la fila del estado son DOS textos pegados -lo que falta y de que
## es- y el par mas largo que sale ("TE FALTAN 80.000 DE LO QUE TENGAS AHORA",
## 38 caracteres) mide 798 + 16 de aire a 21 px: el hueco se deja ancho para que
## el dia que suba el requisito la frase no se encoja sola ni se mezclen dos
## tamanos de letra en la misma barra, que es lo que pasaba antes.
const TEXT_X := 240.0
const TEXT_W := 970.0
const TEXT_SIZE := 21
## Aire entre el dato y la nota que lo explica ("TE FALTAN 80.000" y "DE LO QUE
## TENGAS AHORA"), en la misma fila de la barra.
const PAIR_GAP := 16.0
## Lo que se dice cuando no se ha tocado nada todavia: que el arbol se paga con
## monedas y que lo comprado no se pierde. Es la duda que tiene el jugador la
## primera vez que abre esto.
const STAND_HINT := "SE PAGA CON MONEDAS Y SE QUEDA PARA SIEMPRE"

const GO_CENTER := Vector2(1360, 215)
const GO_W := 288.0
const CLOSE_CENTER := Vector2(1648, 190)
const CLOSE_SIDE := 96.0

## Un nodo: la chapa (ui_slot, 256 nativo) y lo que lleva dentro. 176 de lado y
## no mas porque el arbol entero (los cinco) tiene que caber de una vez en la
## vista, y la separacion entre nodos la manda SkillTree.SEP.
const NODE := 176.0
const NODE_ART := Vector2(112, 112)
const NODE_ART_CENTER := Vector2(88, 70)
## El coste, dentro de la chapa y abajo: cerdito y numero. Es lo que dice si se
## puede comprar ya.
const NODE_COST_Y := 146.0
const NODE_COIN := Vector2(36, 36)
const NODE_COIN_X := 50.0
const NODE_COST_X := 76.0
## A 0,32 y no a 0,24: el precio es lo que dice si un nodo se puede comprar, y a
## 0,24 la cifra media lo mismo que el cerdito pequeno de al lado y no se leia.
const NODE_COST_SCALE := 0.32
const NODE_COST_MAX_W := 64.0
## Y el rotulo del efecto, DEBAJO de la chapa (fuera de ella: dentro no cabe a un
## tamano legible).
const NODE_TEXT_DY := 26.0
const NODE_TEXT_BOX := Vector2(320, 30)
## Hasta donde puede crecer la caja del rotulo antes de encoger la letra. Con 320
## "+20 % DE VELOCIDAD" o "+2 HUECOS DE ARMARIO" no cabian a 21 y bajaban a 14,
## la mitad de alto que los rotulos de al lado. Con 440 caben todos a 21, y los
## nodos de una misma fila estan a 672 px (SkillTree.SEP): no se tocan. Los
## cortos se quedan en 320 para no pisar a su vecino en la rama de abajo.
const NODE_TEXT_MAX_W := 440.0
## Donde cae la MEJORA DEL CENTRO al abrir el arbol: con EL PRIMER ANILLO justo
## debajo de la barra. Antes se apoyaba en la barra la caja del dibujo entero, y
## daba lo mismo porque la caja ERA el primer anillo; ahora que el dano, la
## velocidad y los Pinchos se estiran tres anillos hacia fuera, apoyar la caja
## entera abriria el arbol por su fondo (con el centro casi fuera por abajo).
##
## Apoyando el primer anillo en TREE_TOP se ve lo que hay que ver al abrirlo: el
## centro, sus cuatro caminos y el principio de la rama de abajo. El SEGUNDO
## anillo queda entero detras de la barra, y su ROTULO tambien (cuelga 67 px por
## debajo del nodo, asi que asomaba una linea de letras cortadas). De eso se
## encarga _update_covers(): no se ensancha la separacion porque el primer anillo
## entero, rotulo incluido, no cabe entre la barra y el borde del panel.
const CENTER_Y := TREE_TOP + SkillTree.SEP.y + NODE * 0.5

## Las lineas que unen los nodos, por estado del camino.
const LINK_W := 12.0
const LINK_DIM := Color(0.36, 0.32, 0.45)
const LINK_OPEN := Color(Palette.GOLD_D)
const LINK_DONE := Color(Palette.GOLD_XL)

## Cuanto se puede mover el arbol: al menos esto de su dibujo tiene que quedar
## dentro de la vista. Sin tope se puede lanzar fuera y quedarse mirando un
## panel vacio.
const KEEP := 160.0
## Cuanto hay que MOVER el raton para que un clic cuente como arrastre. 12 px es
## lo que tiembla una mano al pulsar.
const DRAG_SLOP := 12.0

## El color de un nodo segun lo que se puede hacer con el. El "ready" va mas
## claro que los demas a proposito: el nodo que se puede comprar ahora mismo es
## lo unico que hay que encontrar de un vistazo.
const STATE_TINT := {
	"owned": Color(1.0, 1.0, 1.0),
	"ready": Color(1.22, 1.22, 1.22),
	"poor": Color(0.72, 0.72, 0.80),
	"locked": Color(0.42, 0.40, 0.50),
}
## El color del ROTULO segun el estado. Ya no se oscurece con la chapa (ver
## _build_node), asi que el bloqueado lleva su propio tono apagado: mas oscuro que
## el resto para que se vea que aun no toca, pero legible sobre el marron.
const STATE_TEXT := {
	"owned": Palette.GOLD_XL,
	"ready": Palette.CREAM,
	"poor": Palette.CREAM_D,
	"locked": Color8(170, 150, 120),
}

## El lienzo de las lineas. Es una clase aparte -y no un _draw() del panel-
## porque las lineas van DENTRO de la vista recortada y tienen que moverse con el
## arrastre: pintadas en el panel se saldrian por el marco en cuanto se arrastrara.
class TreeLines extends Control:
	var panel: RebirthPanel = null

	func _draw() -> void:
		if panel == null:
			return
		for n in SkillTree.NODES:
			var req := str(n["req"])
			if req == "":
				continue
			var base := SkillTree.node_by_id(req)
			if base.is_empty():
				continue
			panel._draw_link(self, base["pos"], n["pos"], str(n["id"]))

## La vista recortada, el mundo que se mueve dentro y los nodos dibujados, por id.
var _view: Control
var _world: Control
## El lienzo de las lineas. Va aparte del mundo porque el redibujado se pide AL
## LIENZO: mover el arbol es mover _world (y eso ya se ve sin repintar), pero
## cambiar el color de una linea hay que pedirlo a quien la pinta. Pedirlo a
## _world no hacia nada (no tiene _draw), asi que las lineas se quedaban con el
## color que tenian al abrir el panel: comprabas el camino y seguia apagado.
var _lines: Control = null
var _nodes: Dictionary = {}
## Lo que se pulsa de la barra: el saldo, el premio, el estado, el aviso, el
## boton del rebirth y el numero de monedas que te llevarias.
var _bank: PixelNumber
var _bank_label: Label
var _coins: PixelNumber
var _missing: Label
var _missing_note: Label
var _hint_label: Label
var _go: Button
## Donde esta el arbol ahora mismo, en coordenadas de la vista.
var _offset := Vector2.ZERO
## El arrastre en curso: donde empezo (en coords de la vista), de donde salio el
## arbol y cuanto se ha movido de verdad. Null es "no hay arrastre".
var _drag_start = null
var _drag_from := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _dragged := 0.0
## La ficha del nodo que se acaba de pulsar, o null si no hay ninguna abierta. Va
## en la capa de encima (la de las tarjetas), no dentro del panel: el panel mide
## la pantalla entera y un hijo suyo no se puede poner por encima de su marco (ver
## shop_panel.gd, _open_card, que es exactamente el mismo caso).
var _card: SkillCard = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))

	# La vista ANTES que la barra: el orden de los hijos es el orden de dibujo, y
	# el arbol tiene que colarse por DEBAJO de la barra.
	_build_view()
	_build_bar()
	_set_offset(_centered_offset())

	# El arbol cambia al comprar, y los numeros de la barra cambian con el
	# armario (la electronica multiplica el premio del rebirth), con las piezas y
	# con el dinero (de donde sale el premio). Con Game.money_changed y no con
	# do_rebirth(): el rebirth emite todo lo habido y por haber, y este panel se
	# cierra justo despues.
	Game.skills_changed.connect(refresh)
	Game.items_changed.connect(refresh)
	Game.locker_changed.connect(refresh)
	Game.money_changed.connect(func(_m: int) -> void: refresh())
	refresh()


# --------------------------------------------------------------------------- #
# Montaje: la vista del arbol
# --------------------------------------------------------------------------- #

func _build_view() -> void:
	_view = Control.new()
	_view.name = "View"
	_view.position = VIEW_POS
	_view.size = VIEW_SIZE
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	add_child(_view)

	_world = Control.new()
	_world.name = "World"
	_world.size = VIEW_SIZE
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_world)
	var lines := TreeLines.new()
	lines.name = "Lines"
	lines.panel = self
	lines.size = VIEW_SIZE
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(lines)
	_lines = lines

	for i in SkillTree.node_count():
		var node: Dictionary = SkillTree.node_at(i)
		_nodes[str(node["id"])] = _build_node(node)


## Un nodo: la chapa, el dibujo de su stat y, abajo, lo que cuesta o la palabra
## COMPRADO. Todo dentro de un Control que se coloca por su CENTRO (el del nodo
## en coordenadas del arbol) y que se pinta de una vez segun su estado: apagarlo
## es bajarle el modulate, no repintar siete cosas.
func _build_node(node: Dictionary) -> Dictionary:
	var id := str(node["id"])
	var center: Vector2 = node["pos"]

	var view := Control.new()
	view.name = id
	view.size = Vector2(NODE, NODE)
	view.position = center - view.size * 0.5
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(view)

	# LA CHAPA VA EN SU PROPIA CAPA, y es lo que se oscurece segun el estado (ver
	# _paint_node). Antes se oscurecia el nodo entero, rotulo incluido, y un nodo
	# bloqueado dejaba su texto a un 42 % de brillo: gris oscuro sobre marron, que
	# no se leia. El rotulo cuelga de `view` y tiene su color propio.
	var body := Control.new()
	body.name = "Body"
	body.size = view.size
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(body)
	body.add_child(UIKit.image("ui_slot", Vector2(NODE, NODE) * 0.5, Vector2(NODE, NODE)))
	body.add_child(UIKit.fit_art(str(node["art"]), NODE_ART_CENTER, NODE_ART))

	# El coste es el cerdito y su numero, el mismo par que la barra de la partida:
	# en este juego las monedas se leen siempre igual. El numero lo coloca
	# _paint_node(), que es quien sabe cuantas cifras tiene (el control mide, el
	# dibujo de la chapa no).
	var coin := UIKit.image("currency_piggy", Vector2(NODE_COIN_X, NODE_COST_Y), NODE_COIN)
	body.add_child(coin)
	var cost := PixelNumber.new()
	# El color va ANTES del texto: PixelNumber solo lo aplica al construir los
	# glifos (ver pixel_number.gd, _rebuild), asi que cambiarlo despues no pinta
	# nada hasta el siguiente set_number.
	cost.color = Palette.GOLD_XL
	cost.scale_factor = NODE_COST_SCALE
	cost.max_width = NODE_COST_MAX_W
	body.add_child(cost)

	# El centro va en x NODE/2 (el del nodo) y en y NODE_COST_Y (la fila del
	# coste): "COMPRADO" va donde iria el precio, no en medio de la chapa.
	# En crema y no en oro: va sobre el labio naranja de la chapa, y en oro sobre
	# naranja no se distinguia.
	var done := UIKit.label_at("COMPRADO", Vector2(NODE * 0.5, NODE_COST_Y),
		Vector2(NODE, 30), 14, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	body.add_child(done)

	# El efecto, debajo de la chapa y a lo ancho de una caja mas grande que el
	# nodo: "2 HUECOS DE ARMARIO" no cabe en 176 px y encogerlo hasta ahi lo
	# dejaria ilegible. Los rotulos de dos nodos de la misma fila no se tocan
	# porque la separacion (SkillTree.SEP) es mayor que esta caja.
	var texto := SkillTree.effect_text(id)
	var caja := Vector2(clampf(UIKit.text_width(texto, TEXT_SIZE), NODE_TEXT_BOX.x,
		NODE_TEXT_MAX_W), NODE_TEXT_BOX.y)
	var effect := UIKit.label_at(texto,
		Vector2(NODE * 0.5, NODE + NODE_TEXT_DY), caja, TEXT_SIZE, Palette.CREAM,
		HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	view.add_child(effect)

	return {
		"id": id, "center": center, "view": view, "body": body, "cost": cost,
		"done": done,
		"coin": coin, "effect": effect,
	}


## Una linea entre dos nodos, con el color de lo que se puede hacer con ese
## camino (ver link_color).
func _draw_link(canvas: CanvasItem, from: Vector2, to: Vector2, id: String) -> void:
	canvas.draw_line(from, to, link_color(id), LINK_W, false)


## El color de la linea de un camino: dorado el comprado, ambar el que ya se
## puede comprar (o sea el que cuelga de un nodo que si tienes) y morado apagado
## el cerrado. Es publico porque hay un tercero que lo mira: el test comprueba la
## regla del color aqui, en la funcion que decide, y no en el pixel.
func link_color(id: String) -> Color:
	if Game.skill_owned(id):
		return LINK_DONE
	if Game.skill_unlocked(id):
		return LINK_OPEN
	return LINK_DIM


# --------------------------------------------------------------------------- #
# Montaje: la barra
# --------------------------------------------------------------------------- #

func _build_bar() -> void:
	var back := ColorRect.new()
	back.color = BAR_BACK
	back.position = VIEW_POS
	back.size = Vector2(VIEW_SIZE.x, BAR_H)
	# IGNORE a proposito: arrastrar el arbol tambien funciona empezando por la
	# barra, que es lo que se espera de una franja que tapa el arbol. Los botones
	# que hay encima si recogen su clic (son otra capa).
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var edge := ColorRect.new()
	edge.color = BAR_EDGE
	edge.position = VIEW_POS + Vector2(0, BAR_H)
	edge.size = Vector2(VIEW_SIZE.x, EDGE)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)

	add_child(UIKit.image("currency_piggy", Vector2(BANK_X, ROW_BANK),
		Vector2(BANK_ART, BANK_ART)))
	_bank = PixelNumber.new()
	_bank.color = Palette.GOLD_XL
	_bank.scale_factor = BANK_SCALE
	_bank.max_width = BANK_MAX_W
	add_child(_bank)
	_bank_label = UIKit.label("MONEDAS DE REBIRTH", 21, Palette.CREAM_D,
		HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_bank_label)

	add_child(UIKit.label_at("TE DARA", PRIZE_CENTER, Vector2(220, 30), 21,
		Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER))
	_coins = PixelNumber.new()
	_coins.color = Palette.GOLD_XL
	_coins.scale_factor = PRIZE_SCALE
	_coins.max_width = PRIZE_MAX_W
	add_child(_coins)

	# La fila del estado son DOS etiquetas y no una: el dato (lo que falta) y la
	# nota que lo explica van de distinto color, y el dato es lo unico de la barra
	# que cambia de ancho. Son UIKit.label() y no label_at() porque su ancho tiene
	# que ser el del TEXTO: la nota se pega detras del numero, y con una caja fija
	# quedaria un hueco del tamano de la caja (label_at() agranda el control hasta
	# el ancho pedido). Quien las coloca es _place_status(), que las pone a las dos
	# al mismo tamano de letra.
	_missing = UIKit.label("", 21, Palette.RUST_L, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_missing)
	# Y detras, DE QUE es lo que falta: el requisito va del dinero del contador -lo
	# mismo que se lleva el premio y lo que el jugador tiene delante en la barra de
	# la partida-, asi que se dice "de lo que tengas ahora" y no "de lo ganado".
	_missing_note = UIKit.label("DE LO QUE TENGAS AHORA", 21, Palette.CREAM_D,
		HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_missing_note)
	_hint_label = UIKit.label(STAND_HINT, 21, Palette.CREAM_D,
		HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_hint_label)

	_go = UIKit.small_button("REBIRTH", "currency_piggy", GO_CENTER, GO_W, 32)
	_go.pressed.connect(_on_rebirth)
	add_child(_go)

	var close := UIKit.close_button(CLOSE_CENTER, CLOSE_SIDE)
	close.pressed.connect(_close)
	add_child(close)


# --------------------------------------------------------------------------- #
# El arrastre y los clics del arbol
# --------------------------------------------------------------------------- #

## Pulsar y arrastrar mueve el arbol; pulsar y soltar en el mismo sitio abre la
## ficha del nodo que haya debajo.
##
## No se llama a accept_event(): este control es el de arriba en toda la vista
## (los nodos y los rotulos son IGNORE) y el clic no tiene a donde ir.
func _on_view_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_drag_start = mb.position
			_drag_from = _offset
			_last_pos = mb.position
			_dragged = 0.0
		elif _drag_start != null:
			_drag_start = null
			if _dragged <= DRAG_SLOP:
				_tap(_node_at(mb.position - _offset))
		return
	var mm := event as InputEventMouseMotion
	if mm == null or _drag_start == null:
		return
	_dragged += (mm.position - _last_pos).length()
	_last_pos = mm.position
	_set_offset(_drag_from + (mm.position - _drag_start))


## El id del nodo que hay en este punto del ARBOL (no de la vista), o "" si no
## hay ninguno. Las cajas no se solapan: SkillTree.SEP es mayor que NODE.
func _node_at(tree_pos: Vector2) -> String:
	var half := NODE * 0.5
	for id in _nodes:
		var center: Vector2 = _nodes[id]["center"]
		if absf(tree_pos.x - center.x) <= half and absf(tree_pos.y - center.y) <= half:
			return str(id)
	return ""


## Pulsar un nodo (pulsar y soltar sin moverse) ABRE SU FICHA, no lo compra: la
## compra se decide dentro, con lo que da el nodo y lo que cuesta delante. Se
## abre con cualquier nodo, tambien con el que ya es tuyo o con el que esta
## cerrado, que es donde se explica por que no se puede comprar.
func _tap(id: String) -> void:
	if id == "":
		return
	_open_card(id)


## Abrir la ficha de un nodo. Si ya hay una abierta no se abre otra: el arbol
## entero esta tapado por ella, asi que no hay forma de pulsar un segundo nodo
## sin cerrarla antes, y dos fichas apiladas solo se pueden deber a un test.
func _open_card(id: String) -> void:
	if _card != null:
		return
	var raiz := MainRoot.get_root()
	if raiz == null:
		return
	Sound.click()
	_card = SKILL_CARD_SCENE.instantiate() as SkillCard
	_card.closed.connect(_close_card)
	# La ficha no compra: pide la compra, y aqui se hace con la misma logica de
	# siempre (cobrar, sonar, avisar y refrescar el arbol).
	_card.buy_requested.connect(_on_buy_skill)
	_card.show_skill(id)
	raiz.push_overlay(_card)


## Cerrar la ficha. `_card` se suelta ANTES de refrescar: el refresco repinta los
## nodos y la barra, y con la ficha a medias de quitar podria volver a pedirla.
func _close_card() -> void:
	if _card == null:
		return
	var raiz := MainRoot.get_root()
	if raiz != null:
		raiz.pop_overlay(_card)
	_card = null
	refresh()


## Comprar el nodo que pide la ficha. Todo lo que puede salir mal se dice en el
## aviso de la barra: un nodo que no hace nada no explica nada, que es la misma
## regla que la chapa del rebirth y los botones de las automatizaciones. La ficha
## ya lo adelanta en su segunda linea, y aqui se repite para el que pulse COMPRAR
## de todas formas: el boton no se apaga nunca (un boton muerto y callado no
## explica nada).
func _on_buy_skill(id: String) -> void:
	if Game.skill_owned(id):
		Sound.play("sfx_error")
		_hint("YA TIENES " + SkillTree.effect_text(id), Palette.CREAM_D)
		return
	if not Game.skill_unlocked(id):
		Sound.play("sfx_error")
		_hint("ANTES: " + SkillTree.effect_text(SkillTree.req_of(id)), Palette.RUST_L)
		return
	if not Game.can_buy_skill(id):
		Sound.play("sfx_error")
		_hint("TE FALTAN %d MONEDAS" % Game.skill_missing_coins(id), Palette.RUST_L)
		return
	Game.buy_skill(id)
	Sound.play("sfx_tool")
	_hint("COMPRADO: " + SkillTree.effect_text(id), Palette.GOLD_XL)


# --------------------------------------------------------------------------- #
# La vista: donde esta el arbol y cuanto se puede mover
# --------------------------------------------------------------------------- #

## Coloca el arbol en la vista. El tope es KEEP: por mucho que se arrastre, tiene
## que quedar ese trozo de dibujo dentro.
func _set_offset(value: Vector2) -> void:
	_offset = _clamp_offset(value)
	_world.position = _offset
	_update_covers()


## El rotulo de un nodo que esta ENTERO detras de la barra no se pinta.
##
## El rotulo del efecto cuelga 67 px por debajo de su chapa, asi que un nodo que
## la barra tapa del todo dejaba asomar UNA LINEA DE LETRAS CORTADAS justo debajo
## de ella (se vio en la captura del arbol con los anillos nuevos). Se apaga el
## rotulo; la chapa no hace falta tocarla, porque el recorte de la vista ya la
## corta y la barra va encima. Se repasa al mover el arbol, que es cuando un nodo
## entra o sale de debajo: al arrastrarlo hacia abajo, su rotulo vuelve.
func _update_covers() -> void:
	var fondo := VIEW_POS.y + BAR_H + EDGE
	for id in _nodes:
		var view: Control = _nodes[id]["view"]
		var arriba := VIEW_POS.y + _offset.y + view.position.y
		(_nodes[id]["effect"] as Label).visible = arriba + NODE > fondo


## El tope del arrastre, por eje y a partir del dibujo del arbol (SkillTree.bounds):
## por mucho que se arrastre, tiene que quedar dentro de la vista el trozo que
## dice KEEP, y por eso el limite sale de la caja del dibujo y no de la ventana
## (la vista es mas ancha que el arbol, o sea que a lo ancho el tope sobra: es el
## precio de que el mismo calculo valga el dia que el arbol crezca).
##
## _axis() cubre el caso de que los dos limites se crucen (que el dibujo no quepa
## ni dejando KEEP): entonces no hay nada permitido y lo unico sensato es
## centrarlo. Hoy no pasa, y con cinco nodos tampoco hace falta que pase.
func _clamp_offset(value: Vector2) -> Vector2:
	var b := SkillTree.bounds()
	var lo := Vector2(KEEP - b.end.x, KEEP - b.end.y)
	var hi := VIEW_SIZE - Vector2(KEEP, KEEP) - b.position
	return Vector2(_axis(value.x, lo.x, hi.x), _axis(value.y, lo.y, hi.y))


func _axis(value: float, lo: float, hi: float) -> float:
	if lo > hi:
		return (lo + hi) * 0.5
	return clampf(value, lo, hi)


## Donde se coloca el arbol al abrir: centrado a lo ancho en el dibujo ENTERO
## (para que los cuatro caminos queden a la misma distancia de un borde y del
## otro) y con la mejora del centro en CENTER_Y, que deja el primer anillo
## apoyado debajo de la barra. Lo que asoma del dibujo por los lados y por abajo
## se alcanza arrastrando, que es lo que hace un arbol mas grande que la ventana.
func _centered_offset() -> Vector2:
	var b := SkillTree.bounds()
	return _clamp_offset(Vector2(VIEW_SIZE.x * 0.5 - b.get_center().x, CENTER_Y))


# --------------------------------------------------------------------------- #
# Refresco
# --------------------------------------------------------------------------- #

## Todo lo que depende de la partida: el color de cada nodo, el saldo, el premio,
## el requisito y el aviso. NO toca el aviso de la ultima compra (lo pone _tap) ni
## vuelve a colocar el arbol: lo que el jugador ha movido se queda donde lo dejo.
func refresh() -> void:
	if not is_node_ready():
		return
	for id in _nodes:
		_paint_node(str(id))
	if _lines != null:
		_lines.queue_redraw()

	_bank.set_number(Game.rebirth_coins)
	_bank.position = Vector2(BANK_NUM_X, ROW_BANK - _bank.size.y * 0.5)
	_bank_label.size = _line_size(_bank_label.text)
	_bank_label.position = Vector2(_bank.position.x + _bank.size.x + BANK_LABEL_GAP,
		ROW_BANK - _bank_label.size.y * 0.5)

	var premio := Game.pending_rebirth_coins()
	_coins.set_number(premio)
	_coins.position = Vector2(PRIZE_X, ROW_BANK - _coins.size.y * 0.5)
	# La electronica del armario es la unica forma de subir el premio del rebirth,
	# asi que cuanto esta dando va en el tooltip del boton: es informacion que hay
	# que poder consultar y que no merece una linea de la barra. Y con ella va el
	# requisito, porque el tooltip es el sitio de consultar las reglas de la chapa.
	_go.tooltip_text = ("Reinicia la partida: se pierde TODO lo de esta partida."
		+ " Hacen falta %s en el contador (el dinero que TIENES, no lo ganado en"
		+ " la partida). Te llevas %d monedas (1 por cada 1,5 M que tengas) y la"
		+ " Electronica del armario las multiplica: x%s. Lo que vendes ya no sube"
		+ " con las monedas: se gastan en el arbol.") % [
		PixelNumber.format(LootDB.REBIRTH_REQUIRE), premio,
		LootDB.short_number(Game.rebirth_multiplier())]

	var puede := Game.can_rebirth()
	_go.modulate = Color.WHITE if puede else Color(0.55, 0.55, 0.62, 1.0)
	if puede:
		_missing.text = "YA PUEDES REINICIAR"
		_missing.add_theme_color_override("font_color", Palette.GOLD_XL)
		_missing_note.visible = false
	else:
		_missing.text = "TE FALTAN " + PixelNumber.format(Game.rebirth_missing())
		_missing.add_theme_color_override("font_color", Palette.RUST_L)
		_missing_note.visible = true
	_place_status()
	_place_line(_hint_label, ROW_HINT)


## Pinta un nodo entero segun lo que se puede hacer con el.
func _paint_node(id: String) -> void:
	var node: Dictionary = _nodes[id]
	var state := _state_of(id)
	var cost: PixelNumber = node["cost"]
	var done: Label = node["done"]
	var coin: TextureRect = node["coin"]
	var effect: Label = node["effect"]

	(node["body"] as Control).modulate = STATE_TINT[state]
	effect.add_theme_color_override("font_color", STATE_TEXT[state])
	var owned := state == "owned"
	# Comprado se enseña COMPRADO y no su precio: un numero que ya no sirve para
	# nada solo confunde sobre si hay algo mas que comprar ahi, y el cerdito se va
	# con el, que el coste es el PAR (cerdito y numero) y no el numero.
	if owned:
		# El numero se VACIA y no solo se esconde: sus glifos son hijos suyos y
		# seguirian ahi, en las mismas coordenadas, con el control invisible (que
		# es justo lo que mira el check de solapes del test).
		cost.set_text("")
	else:
		# El color va por recolor(): las cifras del precio no cambian al ganar o
		# perder monedas, y set_number() no repintaria nada (ver pixel_number.gd).
		cost.recolor(Palette.RUST_L if state == "poor" else Palette.GOLD_XL)
		cost.set_number(Game.skill_cost(id))
		cost.position = Vector2(NODE_COST_X, NODE_COST_Y - cost.size.y * 0.5)
	cost.visible = not owned
	coin.visible = not owned
	done.visible = owned


## Que se puede hacer con un nodo: ya es tuyo, se puede comprar ahora, no te
## llegan las monedas o le falta el nodo de antes.
func _state_of(id: String) -> String:
	if Game.skill_owned(id):
		return "owned"
	if not Game.skill_unlocked(id):
		return "locked"
	return "ready" if Game.can_buy_skill(id) else "poor"


## Coloca una linea de texto de la barra pegada a su izquierda. El alto y el
## ancho son los del TEXTO (no una caja fija): asi se puede encadenar una linea
## detras de otra midiendo de verdad, y un numero que gana cifras no deja ni un
## hueco de mas ni se come lo que tiene al lado.
func _place_line(label: Label, row: float) -> void:
	# La letra se encoge si la linea no cabe en su hueco: al lado derecho de la
	# barra hay botones (la chapa del REBIRTH empieza en 1216) y un aviso largo se
	# les meteria debajo.
	var size := UIKit.fit_size(label.text, TEXT_W, TEXT_SIZE)
	label.add_theme_font_size_override("font_size", size)
	label.size = Vector2(UIKit.text_width(label.text, size), UIKit.text_height(size))
	label.position = Vector2(TEXT_X, row - label.size.y * 0.5)


## La fila del estado: lo que falta para reiniciar (o que ya se puede) y, pegado
## detras, de que es lo que falta. Los DOS van al mismo tamano de letra, y por eso
## no se colocan con _place_line() cada uno por su cuenta: una fila con dos
## tamanos distintos se lee como un fallo y no como un diseno (ver UIKit.row_size,
## que es la misma regla para la columna de sobres).
##
## El tamano se elige con los caracteres que van a salir de verdad (la nota no
## cuenta cuando esta escondida, que es cuando ya se puede reiniciar) y con el
## aire de en medio, que se cuenta en caracteres porque la fuente es de ancho
## fijo: los 38 caracteres del par mas largo mas los 16 px de aire son 814 de los
## 970 que hay hasta la chapa del REBIRTH, asi que entra a 21 px sin encogerse.
## Lo que venga mas largo, se encoge entero.
func _place_status() -> void:
	var chars := _missing.text.length()
	if _missing_note.visible:
		chars += _missing_note.text.length()
	var size := UIKit.FONT_STEP
	for k in range(1, UIKit.font_step(TEXT_SIZE) / UIKit.FONT_STEP + 1):
		var s := k * UIKit.FONT_STEP
		if float(s) * float(chars) + PAIR_GAP <= TEXT_W:
			size = s
	_missing.add_theme_font_size_override("font_size", size)
	_missing.size = _line_size(_missing.text, size)
	_missing.position = Vector2(TEXT_X, ROW_STATUS - _missing.size.y * 0.5)
	_missing_note.add_theme_font_size_override("font_size", size)
	_missing_note.size = _line_size(_missing_note.text, size)
	# La nota se pega DETRAS del dato, medido con el texto de verdad: el requisito
	# cambia de cifras y una x fija dejaria un hueco.
	_missing_note.position = Vector2(_missing.position.x + _missing.size.x + PAIR_GAP,
		ROW_STATUS - _missing_note.size.y * 0.5)


## Lo que ocupa un texto de la barra a un tamano dado, medido con las tablas de la
## fuente (el mismo calculo que usa UIKit al colocar los rotulos). NO se le
## pregunta a la etiqueta: Godot actualiza su tamano minimo en diferido, y en el
## mismo refresco en que se escribe el aviso ese tamano todavia es el de antes.
func _line_size(text: String, size: int = TEXT_SIZE) -> Vector2:
	return Vector2(UIKit.text_width(text, size), UIKit.text_height(size))


## El aviso de la ultima mejora tocada, en la tercera linea de la barra.
func _hint(text: String, color: Color) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override("font_color", color)
	_place_line(_hint_label, ROW_HINT)


# --------------------------------------------------------------------------- #
# Lo que se puede consultar de fuera (los tests)
# --------------------------------------------------------------------------- #

## Donde ha quedado un nodo EN LA PANTALLA, con el arrastre que haya. Es lo que
## usan las pruebas para pulsar donde se ve el nodo: calcular esa posicion a mano
## en el test es justo como se deja de probar el arrastre sin enterarse.
func node_point(id: String) -> Vector2:
	var node: Dictionary = _nodes.get(id, {})
	if node.is_empty():
		return Vector2.ZERO
	var center: Vector2 = node["center"]
	return VIEW_POS + _offset + center


## La caja de un nodo en la pantalla (para comprobar que cabe en la vista).
func node_rect(id: String) -> Rect2:
	var node: Dictionary = _nodes.get(id, {})
	if node.is_empty():
		return Rect2()
	var center: Vector2 = node["center"]
	return Rect2(VIEW_POS + _offset + center - Vector2(NODE, NODE) * 0.5,
		Vector2(NODE, NODE))


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

## Reiniciar de verdad. El que reinicia es Game.do_rebirth(), que ademas avisa a
## todo el juego y guarda: aqui solo queda contar lo que ha pasado y cerrar.
##
## El boton NO se deshabilita cuando no llega, y no es un descuido: un boton
## muerto y callado no explica nada, y lo unico util de esta pantalla cuando
## todavia no se puede reiniciar es decir QUE falta. Ver la barra de las
## automatizaciones (game.gd, _locked_notice()), que hace lo mismo.
func _on_rebirth() -> void:
	if not Game.can_rebirth():
		Sound.play("sfx_error")
		Game.notice.emit("AUN NO: TE FALTAN "
			+ PixelNumber.format(Game.rebirth_missing()), Palette.RUST_L)
		_hint("TE FALTAN " + PixelNumber.format(Game.rebirth_missing())
			+ " DE LO QUE TIENES AHORA", Palette.RUST_L)
		return
	var coins := Game.do_rebirth()
	Sound.play("sfx_tool")
	Game.notice.emit("REBIRTH: +" + PixelNumber.format(coins) + " MONEDAS",
		Palette.GOLD_XL)
	_close()


func _close() -> void:
	Sound.click()
	# La ficha que estuviera abierta se va con el arbol: si no, se quedaria sola
	# encima de la pantalla, sin arbol detras y sin forma de volver a abrirla.
	if _card != null:
		_close_card()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Con la ficha abierta, ESC es de la ficha: ella lo dice y para el evento
		# (ver SkillCard._unhandled_input), asi que aqui no se cierra el arbol.
		if _card != null:
			return
		_close()
		get_viewport().set_input_as_handled()
