# AscensionPanel - el arbol MORADO de la ascension (el super-rebirth).
#
# Se abre con el boton ASCENSION del panel del rebirth, que solo sale con el
# arbol del rebirth entero comprado (Game.ascension_shown). Es la misma pantalla
# que la del rebirth -barra de arriba con el saldo, el estado y un aviso, y el
# arbol debajo- pero en morado y con particulas moradas subiendo.
#
# ASCENDER LO BORRA TODO (ver Game.do_ascension) y da un PUNTO DE ASCENSION.
# Por eso pide dos pulsaciones: la primera avisa y la segunda asciende. Despues
# el panel se queda abierto, que es justo donde se gasta el punto.
#
# EL ARBOL ES UNA TELARANA: HYPER grande en el centro y seis hilos que salen de
# el, con tres anillos de hexagonos (tree_asc_hex con su dibujo dentro) unidos
# por los hilos de la red. Pulsar un hexagono lo ELIGE y su ficha sale abajo a
# la derecha (nombre, lo que da, el precio y el boton); pulsar el elegido otra
# vez lo compra. Los interruptores (los automaticos) se encienden y se apagan
# desde la misma ficha. Lo que da y lo que cuesta cada uno esta en AscensionTree.
class_name AscensionPanel
extends Control

signal closed()

## Mismas medidas que el panel del rebirth: el interior de ui_panel_shop.
const VIEW_POS := RebirthPanel.VIEW_POS
const VIEW_SIZE := RebirthPanel.VIEW_SIZE
const BAR_H := RebirthPanel.BAR_H
const ROW_BANK := RebirthPanel.ROW_BANK
const ROW_STATUS := RebirthPanel.ROW_STATUS
const ROW_HINT := RebirthPanel.ROW_HINT
const TEXT_X := RebirthPanel.TEXT_X
const TEXT_W := RebirthPanel.TEXT_W
const TEXT_SIZE := RebirthPanel.TEXT_SIZE
const GO_CENTER := RebirthPanel.GO_CENTER
const GO_W := RebirthPanel.GO_W

## Los morados de la pantalla. El panel de carton se tine entero: la ascension
## tiene que leerse como OTRO sitio y no como el arbol de siempre. El azul pasa
## de 1 a proposito: el carton casi no tiene azul y multiplicando por 1 o menos
## salia granate, no morado.
const PANEL_TINT := Color(0.75, 0.5, 2.2)
const VEIL := Color(0.10, 0.0, 0.18, 0.78)
const INSIDE := Color(0.13, 0.03, 0.22, 0.96)
const BAR_BACK := Color(0.06, 0.01, 0.10, 0.97)
const BAR_EDGE := Color(0.62, 0.30, 0.95, 0.9)
const BUTTON_TINT := Color(0.85, 0.55, 1.25)
const LILA := Color8(214, 160, 255)
const PURPLE := Color8(150, 80, 230)

## LA TELARANA es mas grande que la vista y se NAVEGA: se arrastra con el raton
## y se acerca o aleja con la rueda o las lupas, como el arbol del rebirth. Vive
## en un "mundo" con HYPER en el origen; WEB_VIEW es el trozo de pantalla donde
## se ve (entre la barra y la ficha). Los hilos van de 60 en 60 grados,
## empezando a la derecha (AscensionTree.SPOKES), y se estiran un poco a lo
## ancho porque la vista es mas ancha que alta.
const WEB_VIEW := Rect2(224, 294, 1472, 546)
const RING_R := [0.0, 230.0, 410.0, 590.0, 770.0]
const STRETCH_X := 1.4
## Donde va el nombre de cada hilo: fuera del ultimo anillo.
const SPOKE_LABEL_R := 960.0
## El hexagono de HYPER y el de los demas; el dibujo ocupa ART_PART de el.
const HYPER_SIDE := 180.0
const HEX_SIDE := 112.0
const ART_PART := 0.52
const THREAD := Color(0.42, 0.24, 0.62, 0.75)
const THREAD_LIT := Color8(214, 160, 255)
## El zoom (el ultimo es el tamano de verdad) y con cual se abre.
const ZOOM_STEPS: Array[float] = [0.3, 0.45, 0.65, 1.0]
const ZOOM_START := 2
const ZOOM_SIDE := 72.0
const ZOOM_IN_CENTER := Vector2(1640, 690)
const ZOOM_OUT_CENTER := Vector2(1640, 776)
## Lo que tiene que quedar de telarana dentro de la vista por mucho que se
## arrastre, y lo que se puede mover el raton antes de que un clic sea arrastre.
const KEEP := 200.0
const DRAG_SLOP := 12.0

## LA FICHA del hexagono elegido: una franja a lo ancho debajo de la red, con el
## nombre y el precio arriba, lo que da abajo y el boton a la derecha. En una
## esquina no cabia: la red ocupa casi todo y el texto salia en cuatro lineas.
const CARD := Rect2(240, 846, 1440, 88)
const CARD_ROW1 := 870.0
const CARD_ROW2 := 910.0
const CARD_TEXT_X := 264.0
## Hasta donde llega el texto: luego va el boton.
const CARD_TEXT_END := 1440.0

const STAND_HINT := "Ascender lo borra todo menos lo morado y las mascotas"

var _points: PixelNumber
var _points_label: Label
var _status: Label
var _hint_label: Label
var _go: Button
## Cada hexagono: {"view", "ring" (el marco del elegido), "pulse"} por su id.
var _nodes: Dictionary = {}
var _web: Control
## La vista recortada, el mundo que se mueve dentro y donde esta.
var _clip: Control
var _world: Control
var _offset := Vector2.ZERO
var _zoom_i := ZOOM_START
var _zoom_in: Button
var _zoom_out: Button
## El arrastre: donde se pulso (null si no hay), desde donde y cuanto se ha movido.
var _drag_start = null
var _drag_from := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _dragged := 0.0
var _selected := "hyper"
var _card_name: Label
var _card_desc: Label
var _card_cost: Label
var _card_btn: Button = null
## Lo que pone el boton de la ficha ("Comprar", "Encender" o "Apagar").
var _card_btn_text := ""
## La primera pulsacion de ASCENDER solo avisa; la segunda asciende.
var _confirm := false
var _hint_text := STAND_HINT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# El velo va PRIMERO: MainRoot._pop_in lo trata como el primer hijo.
	var veil := UIKit.veil()
	veil.color = VEIL
	add_child(veil)
	add_child(UIKit.panel("ui_panel_shop"))
	get_child(1).modulate = PANEL_TINT

	var inside := ColorRect.new()
	inside.color = INSIDE
	inside.position = VIEW_POS
	inside.size = VIEW_SIZE
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inside)
	add_child(_rising_particles())

	_build_web()
	_build_bar()

	Game.skills_changed.connect(refresh)
	Game.money_changed.connect(func(_m: int) -> void: refresh())
	refresh()


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

## Las particulas moradas que suben por todo el menu, recortadas a la vista. Con
## preprocess para que al abrir ya este lleno y no se vea arrancar la primera ola.
func _rising_particles() -> Control:
	var clip := Control.new()
	clip.position = VIEW_POS
	clip.size = VIEW_SIZE
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := CPUParticles2D.new()
	p.position = Vector2(VIEW_SIZE.x * 0.5, VIEW_SIZE.y + 10.0)
	p.texture = _pixel()
	p.amount = 90
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(VIEW_SIZE.x * 0.5, 4.0)
	p.direction = Vector2(0, -1)
	p.spread = 10.0
	p.gravity = Vector2(0, -25)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 170.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	var tonos := Gradient.new()
	tonos.offsets = PackedFloat32Array([0.0, 1.0])
	tonos.colors = PackedColorArray([PURPLE, LILA])
	p.color_initial_ramp = tonos
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9),
		Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	clip.add_child(p)
	return clip


## Un pixel blanco (el color lo pone la rampa): las particulas son cuadrados,
## como el resto del pixel art.
static var _px: Texture2D = null
static func _pixel() -> Texture2D:
	if _px == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_px = ImageTexture.create_from_image(img)
	return _px


## Donde va cada nodo en el MUNDO de la telarana (HYPER en el origen).
static func node_pos(id: String) -> Vector2:
	var n := AscensionTree.node_by_id(id)
	# LOS DE FUERA DE LA TELARAÑA (la SUBASTA): en el hueco entre los hilos de
	# Dinero y Rebirth, a la altura de sus nombres, sin hilo que los una.
	if AscensionTree.is_extra(id):
		var a := deg_to_rad(30.0)
		return Vector2(cos(a) * SPOKE_LABEL_R * STRETCH_X, sin(a) * SPOKE_LABEL_R)
	if n.is_empty() or int(n["ring"]) == 0:
		return Vector2.ZERO
	return spoke_point(int(n["spoke"]), float(RING_R[int(n["ring"])]))


static func spoke_point(spoke: int, r: float) -> Vector2:
	var a := deg_to_rad(60.0 * spoke)
	return Vector2(cos(a) * r * STRETCH_X, sin(a) * r)


## La caja del dibujo entero (con los nombres de los hilos), en el mundo.
static func web_bounds() -> Rect2:
	var w := SPOKE_LABEL_R * STRETCH_X + 160.0
	var h := SPOKE_LABEL_R * 0.866 + 60.0
	return Rect2(-w, -h, w * 2.0, h * 2.0)


func zoom() -> float:
	return ZOOM_STEPS[_zoom_i]


## Un punto del mundo, en la pantalla (para los estallidos).
func world_to_screen(p: Vector2) -> Vector2:
	return WEB_VIEW.position + _offset + p * zoom()


func _build_web() -> void:
	_clip = Control.new()
	_clip.position = WEB_VIEW.position
	_clip.size = WEB_VIEW.size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	_clip.gui_input.connect(_on_view_input)
	add_child(_clip)
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_world)
	_web = Control.new()
	_web.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_web.draw.connect(_draw_web)
	_world.add_child(_web)
	for spoke in AscensionTree.SPOKES.size():
		_world.add_child(UIKit.label_at(str(AscensionTree.SPOKES[spoke]),
				spoke_point(spoke, SPOKE_LABEL_R), Vector2(300, 50), 40, LILA,
				HORIZONTAL_ALIGNMENT_CENTER, 1))
	for n in AscensionTree.NODES + AscensionTree.EXTRA:
		_build_node(n)
	_world.propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	_build_card()
	_build_zoom()
	# Se abre con HYPER en el centro de la vista.
	_set_offset(WEB_VIEW.size * 0.5)


## Los hilos: los seis que salen del centro y los anillos que los unen.
## Encendidos (lila) los que unen dos nodos comprados.
func _draw_web() -> void:
	for spoke in AscensionTree.SPOKES.size():
		var antes := "hyper"
		for ring in range(1, RING_R.size()):
			var id := str(AscensionTree.node_at(spoke, ring).get("id", ""))
			_thread(node_pos(antes), node_pos(id), Game.asc_owned(antes) and Game.asc_owned(id))
			antes = id
	for ring in range(1, RING_R.size()):
		for spoke in AscensionTree.SPOKES.size():
			var a := str(AscensionTree.node_at(spoke, ring).get("id", ""))
			var b := str(AscensionTree.node_at((spoke + 1) % AscensionTree.SPOKES.size(),
					ring).get("id", ""))
			_thread(node_pos(a), node_pos(b), Game.asc_owned(a) and Game.asc_owned(b))


func _thread(from: Vector2, to: Vector2, lit: bool) -> void:
	_web.draw_line(from, to, THREAD_LIT if lit else THREAD, 5.0 if lit else 4.0)


## Un hexagono con su dibujo y su nombre debajo. No es un boton: los clics los
## reparte _on_view_input, para que pulsar y arrastrar encima de un nodo mueva la
## telarana en vez de comprar.
func _build_node(n: Dictionary) -> void:
	var id := str(n["id"])
	var lado := HYPER_SIDE if id == "hyper" else HEX_SIDE
	var view := Control.new()
	view.size = Vector2(lado, lado)
	view.position = node_pos(id) - view.size * 0.5
	view.pivot_offset = view.size * 0.5
	_world.add_child(view)
	var mitad := view.size * 0.5
	var marco := UIKit.image("tree_asc_hex", mitad, view.size * 1.22, LILA)
	marco.visible = false
	view.add_child(marco)
	if id == "hyper":
		view.add_child(UIKit.image("rarity_glow_epic", mitad, view.size * 1.5))
	elif AscensionTree.is_extra(id):
		view.add_child(UIKit.image("rarity_glow_legendary", mitad, view.size * 1.5))
	view.add_child(UIKit.image("tree_asc_hex", mitad, view.size))
	view.add_child(UIKit.fit_art(str(n["art"]), mitad + Vector2(0, lado * 0.02),
			view.size * ART_PART))
	view.add_child(UIKit.label_at(str(n["name"]), Vector2(mitad.x, lado + 16.0),
			Vector2(lado + 60.0, 32), 24, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	_nodes[id] = {"view": view, "ring": marco, "pulse": null}


## El nodo que hay en este punto del MUNDO, o "".
func _node_at(world: Vector2) -> String:
	for id in _nodes:
		var lado := HYPER_SIDE if str(id) == "hyper" else HEX_SIDE
		if world.distance_to(node_pos(str(id))) <= lado * 0.5:
			return str(id)
	return ""


## Pulsar y arrastrar mueve la telarana; pulsar y soltar en el sitio pulsa el
## hexagono de debajo. La rueda acerca y aleja con el punto del raton quieto.
func _on_view_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP
			or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		set_zoom_step(_zoom_i + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1),
				mb.position)
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_drag_start = mb.position
			_drag_from = _offset
			_last_pos = mb.position
			_dragged = 0.0
		elif _drag_start != null:
			_drag_start = null
			if _dragged <= DRAG_SLOP:
				var id := _node_at((mb.position - _offset) / zoom())
				if id != "":
					_on_node_pressed(id)
		return
	var mm := event as InputEventMouseMotion
	if mm == null or _drag_start == null:
		return
	_dragged += (mm.position - _last_pos).length()
	_last_pos = mm.position
	_set_offset(_drag_from + (mm.position - _drag_start))


## Coloca el mundo en la vista, sin dejar que se escape entero (KEEP).
func _set_offset(value: Vector2) -> void:
	var caja := web_bounds()
	var b := Rect2(caja.position * zoom(), caja.size * zoom())
	var lo := Vector2(KEEP - b.end.x, KEEP - b.end.y)
	var hi := WEB_VIEW.size - Vector2(KEEP, KEEP) - b.position
	_offset = Vector2(clampf(value.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)),
			clampf(value.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)))
	_world.position = _offset
	_world.scale = Vector2(zoom(), zoom())


## Cambia el zoom dejando QUIETO el punto `anchor` de la vista (el del raton, o
## el centro con las lupas).
func set_zoom_step(index: int, anchor = null) -> void:
	var nuevo := clampi(index, 0, ZOOM_STEPS.size() - 1)
	if nuevo == _zoom_i:
		return
	var punto: Vector2 = anchor if anchor != null else WEB_VIEW.size * 0.5
	var en_mundo := (punto - _offset) / zoom()
	_zoom_i = nuevo
	_set_offset(punto - en_mundo * zoom())
	_paint_zoom()


func _build_zoom() -> void:
	_zoom_in = UIKit.icon_button("ui_icon_zoom_in", ZOOM_IN_CENTER, ZOOM_SIDE,
			"Acercar la telaraña (o la rueda del ratón)")
	_zoom_in.pressed.connect(func() -> void: _zoom_button(1))
	add_child(_zoom_in)
	_zoom_out = UIKit.icon_button("ui_icon_zoom_out", ZOOM_OUT_CENTER, ZOOM_SIDE,
			"Alejar la telaraña para verla entera")
	_zoom_out.pressed.connect(func() -> void: _zoom_button(-1))
	add_child(_zoom_out)
	_paint_zoom()


func _zoom_button(step: int) -> void:
	Sound.click()
	set_zoom_step(_zoom_i + step)


func _paint_zoom() -> void:
	UIKit.dim_icon_button(_zoom_in, _zoom_i >= ZOOM_STEPS.size() - 1)
	UIKit.dim_icon_button(_zoom_out, _zoom_i <= 0)


## La ficha del elegido: nombre, lo que da, el precio (o si esta encendido) y el
## boton que lo compra o lo enciende y apaga.
func _build_card() -> void:
	var edge := ColorRect.new()
	edge.color = BAR_EDGE
	edge.position = CARD.position
	edge.size = CARD.size
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)
	var back := ColorRect.new()
	back.color = BAR_BACK
	back.position = CARD.position + Vector2(4, 4)
	back.size = CARD.size - Vector2(8, 8)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_card_name = UIKit.label("", 28, LILA, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_card_name)
	_card_desc = UIKit.label("", 21, Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_card_desc)
	_card_cost = UIKit.label("", 21, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_card_cost)


## El boton de la ficha se rehace cuando cambia lo que pone: el texto va en una
## etiqueta de dentro (UIKit.small_button), y Button.text lo ensanchaba.
func _set_card_button(text: String) -> void:
	if text == _card_btn_text and _card_btn != null:
		return
	if _card_btn != null:
		_card_btn.queue_free()
	_card_btn_text = text
	_card_btn = UIKit.small_button(text, "tree_asc_star",
			Vector2(CARD.end.x - 120.0, CARD.get_center().y), 192, 26)
	_card_btn.pressed.connect(func() -> void: _on_buy(_selected))
	add_child(_card_btn)


func _build_bar() -> void:
	var back := ColorRect.new()
	back.color = BAR_BACK
	back.position = VIEW_POS
	back.size = Vector2(VIEW_SIZE.x, BAR_H)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var edge := ColorRect.new()
	edge.color = BAR_EDGE
	edge.position = VIEW_POS + Vector2(0, BAR_H)
	edge.size = Vector2(VIEW_SIZE.x, RebirthPanel.EDGE)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)

	var icono_x := RebirthPanel.BANK_X
	add_child(UIKit.fit_art("tree_asc_star", Vector2(icono_x, ROW_BANK),
		Vector2(RebirthPanel.BANK_ART, RebirthPanel.BANK_ART)))
	_points = PixelNumber.new()
	_points.color = LILA
	_points.scale_factor = RebirthPanel.BANK_SCALE
	_points.max_width = RebirthPanel.BANK_MAX_W
	add_child(_points)
	_points_label = UIKit.label("Puntos de ascensión", 21, Palette.CREAM_D,
		HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_points_label)
	_status = UIKit.label("", 21, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_status)
	_hint_label = UIKit.label("", 21, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_hint_label)

	_go = UIKit.small_button("Ascender", "tree_asc_star", GO_CENTER, GO_W, 32)
	_go.pressed.connect(_on_ascend)
	add_child(_go)

	var close := UIKit.close_button(UIKit.PANEL_CLOSE, UIKit.PANEL_CLOSE_SIDE)
	close.pressed.connect(_close)
	add_child(close)


# --------------------------------------------------------------------------- #
# Refresco
# --------------------------------------------------------------------------- #

func refresh() -> void:
	if not is_node_ready():
		return
	_points.set_number(Game.ascension_points)
	_points.position = Vector2(RebirthPanel.BANK_NUM_X, ROW_BANK - _points.size.y * 0.5)
	_points_label.text = "Punto de ascensión" if Game.ascension_points == 1 \
		else "Puntos de ascensión"
	_points_label.size = Vector2(UIKit.text_width(_points_label.text, 21), UIKit.text_height(21))
	_points_label.position = Vector2(_points.position.x + _points.size.x
		+ RebirthPanel.BANK_LABEL_GAP, ROW_BANK - _points_label.size.y * 0.5)

	var puede := Game.can_ascend()
	_go.modulate = BUTTON_TINT if puede else Color(0.5, 0.42, 0.62)
	_go.tooltip_text = ("Lo borra TODO: la partida, las monedas y el árbol del rebirth,"
		+ " los rebirths y el álbum. Te llevas 1 punto de ascensión y lo comprado aquí.")
	if puede:
		_status.text = "Ya puedes ascender"
		_status.add_theme_color_override("font_color", Palette.GOLD_XL)
	else:
		_status.text = "Antes: compra todo el árbol del rebirth"
		_status.add_theme_color_override("font_color", Palette.RUST_L)
	_place_line(_status, ROW_STATUS)
	_hint_label.text = _hint_text
	_place_line(_hint_label, ROW_HINT)

	for id in _nodes:
		_paint_node(str(id))
	_paint_card()
	_web.queue_redraw()


## Comprado (claro), interruptor apagado (gris), comprable (late), abierto sin
## puntos (medio) o cerrado porque falta el de dentro (muy apagado).
func _paint_node(id: String) -> void:
	var node: Dictionary = _nodes[id]
	var view: Control = node["view"]
	if node["pulse"] != null and (node["pulse"] as Tween).is_valid():
		(node["pulse"] as Tween).kill()
	node["pulse"] = null
	view.scale = Vector2.ONE
	(node["ring"] as CanvasItem).visible = id == _selected
	if Game.asc_owned(id):
		view.modulate = Color(0.55, 0.55, 0.62) if Game.asc_off.has(id) else Color.WHITE
	elif Game.can_buy_asc(id):
		view.modulate = Color(1.15, 1.15, 1.15)
		var tw := view.create_tween().set_loops()
		tw.tween_property(view, "scale", Vector2.ONE * 1.06, 0.6)
		tw.tween_property(view, "scale", Vector2.ONE, 0.6)
		node["pulse"] = tw
	elif Game.asc_unlocked(id):
		view.modulate = Color(0.6, 0.55, 0.7)
	else:
		view.modulate = Color(0.3, 0.26, 0.36)


func _paint_card() -> void:
	var n := AscensionTree.node_by_id(_selected)
	_card_name.text = str(n["name"])
	_card_desc.text = str(n["desc"])
	_place_at(_card_name, CARD_TEXT_X, CARD_ROW1, 28)
	var desc_size := UIKit.fit_size(_card_desc.text, CARD_TEXT_END - CARD_TEXT_X, 21)
	_card_desc.add_theme_font_size_override("font_size", desc_size)
	_place_at(_card_desc, CARD_TEXT_X, CARD_ROW2, desc_size)
	var toggle := bool(n.get("toggle", false))
	var color := Palette.GOLD_XL
	var boton := "Comprar"
	if Game.asc_owned(_selected):
		if toggle:
			var on := not Game.asc_off.has(_selected)
			_card_cost.text = "Encendido" if on else "Apagado"
			color = LILA if on else Palette.CREAM_D
			boton = "Apagar" if on else "Encender"
		else:
			_card_cost.text = "Comprado"
			color = LILA
	else:
		var coste := AscensionTree.cost_of(_selected)
		_card_cost.text = "%d punto%s" % [coste, "" if coste == 1 else "s"]
		if not Game.asc_unlocked(_selected):
			_card_cost.text += " · antes: " + str(AscensionTree.node_by_id(
					AscensionTree.req_of(_selected))["name"])
		color = Palette.GOLD_XL if Game.can_buy_asc(_selected) else Palette.RUST_L
	_card_cost.add_theme_color_override("font_color", color)
	_place_at(_card_cost, CARD_TEXT_X + _card_name.size.x + 24.0, CARD_ROW1, 21)
	_set_card_button(boton)
	_card_btn.visible = not (Game.asc_owned(_selected) and not toggle)
	_card_btn.modulate = BUTTON_TINT if (Game.can_buy_asc(_selected) or Game.asc_owned(_selected)) \
			else Color(0.5, 0.42, 0.62)


## Una etiqueta de la ficha, a su tamano y centrada en la fila `row`.
func _place_at(label: Label, x: float, row: float, font_size: int) -> void:
	label.size = Vector2(UIKit.text_width(label.text, font_size), UIKit.text_height(font_size))
	label.position = Vector2(x, row - label.size.y * 0.5)


## Una linea de la barra pegada a la izquierda, encogida si no cabe.
func _place_line(label: Label, row: float) -> void:
	var size := UIKit.fit_size(label.text, TEXT_W, TEXT_SIZE)
	label.add_theme_font_size_override("font_size", size)
	label.size = Vector2(UIKit.text_width(label.text, size), UIKit.text_height(size))
	label.position = Vector2(TEXT_X, row - label.size.y * 0.5)


func _hint(text: String, color: Color) -> void:
	_hint_text = text
	_hint_label.add_theme_color_override("font_color", color)
	refresh()


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

## Pulsar un hexagono lo elige; pulsar el que ya esta elegido lo compra.
func _on_node_pressed(id: String) -> void:
	if id == _selected:
		_on_buy(id)
		return
	Sound.click()
	_selected = id
	refresh()


func _on_buy(id: String) -> void:
	_confirm = false
	_selected = id
	var n := AscensionTree.node_by_id(id)
	if Game.asc_owned(id):
		if bool(n.get("toggle", false)):
			var on := Game.toggle_asc(id)
			Sound.play("sfx_toggle")
			_hint(str(n["name"]) + (": encendido" if on else ": apagado"), Palette.CREAM_D)
			return
		Sound.play("sfx_error")
		_hint("Ya tienes " + str(n["name"]), Palette.CREAM_D)
		return
	if not Game.asc_unlocked(id):
		Sound.play("sfx_error")
		_hint("Antes: " + str(AscensionTree.node_by_id(AscensionTree.req_of(id))["name"]),
				Palette.RUST_L)
		return
	if not Game.can_buy_asc(id):
		Sound.play("sfx_error")
		_hint("Te faltan puntos: asciende para ganarlos", Palette.RUST_L)
		return
	Game.buy_asc(id)
	Sound.play("sfx_rare")
	_burst(world_to_screen(node_pos(id)))
	MainRoot.get_root().banner(str(n["name"]), str(n["desc"]))
	_hint("Comprado: " + str(n["name"]) + " " + str(n["desc"]), Palette.GOLD_XL)


## Dos pulsaciones: la primera avisa de lo que se pierde, la segunda asciende.
func _on_ascend() -> void:
	if not Game.can_ascend():
		_confirm = false
		Sound.play("sfx_error")
		_hint("Te falta comprar todo el árbol del rebirth", Palette.RUST_L)
		return
	if not _confirm:
		_confirm = true
		Sound.play("sfx_error")
		_hint("Se borra todo y el árbol del rebirth sube un %d %%. Pulsa otra vez"
				% roundi((SkillTree.ASC_COST_GROWTH - 1.0) * 100.0), Palette.RUST_L)
		return
	_confirm = false
	var puntos := Game.do_ascension()
	Sound.play("sfx_tool")
	Sound.play("sfx_rare")
	_burst()
	MainRoot.get_root().banner("Ascensión", "+%d punto%s de ascensión"
			% [puntos, "" if puntos == 1 else "s"])
	_hint("Has ascendido: gasta los puntos en la telaraña", Palette.GOLD_XL)


## Un estallido de particulas moradas desde un hexagono.
func _burst(at: Vector2 = Vector2.ZERO) -> void:
	if at == Vector2.ZERO:
		at = world_to_screen(Vector2.ZERO)
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = _pixel()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 80
	p.lifetime = 1.4
	p.spread = 180.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 200.0
	p.initial_velocity_max = 520.0
	p.damping_min = 120.0
	p.damping_max = 220.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 14.0
	p.color = LILA
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
