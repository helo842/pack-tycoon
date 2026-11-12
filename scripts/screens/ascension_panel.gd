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
# Los nodos son hexagonos (tree_asc_hex) con su dibujo dentro. Hoy solo hay uno,
# HYPER, grande y en el centro; lo que da y lo que cuesta esta en AscensionTree.
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

## El nodo HYPER: un hexagono grande en el centro de lo que queda debajo de la
## barra, con la persona morada dentro, y su nombre, lo que da y el precio debajo.
const HEX_CENTER := Vector2(960, 560)
const HEX_SIDE := 360.0
const HEX_ART := Vector2(190, 190)
const NAME_Y := 790.0
const DESC_Y := 840.0
const COST_Y := 885.0

const STAND_HINT := "ASCENDER LO BORRA TODO Y DA 1 PUNTO PARA SIEMPRE"

var _points: PixelNumber
var _points_label: Label
var _status: Label
var _hint_label: Label
var _go: Button
var _hex: Control
var _hex_btn: Button
var _cost: Label
var _pulse: Tween = null
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

	_build_node()
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


func _build_node() -> void:
	var n := AscensionTree.node_by_id("hyper")
	_hex = Control.new()
	_hex.size = Vector2(HEX_SIDE, HEX_SIDE)
	_hex.position = HEX_CENTER - _hex.size * 0.5
	_hex.pivot_offset = _hex.size * 0.5
	_hex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hex)
	var mitad := _hex.size * 0.5
	_hex.add_child(UIKit.image("rarity_glow_epic", mitad, _hex.size * 1.5))
	_hex.add_child(UIKit.image("tree_asc_hex", mitad, _hex.size))
	_hex.add_child(UIKit.fit_art(str(n["art"]), mitad + Vector2(0, 6), HEX_ART))

	# El clic: un boton plano encima del hexagono (aqui no hay arrastre que
	# respetar, como en el arbol del rebirth).
	_hex_btn = Button.new()
	_hex_btn.flat = true
	_hex_btn.focus_mode = Control.FOCUS_NONE
	_hex_btn.position = _hex.position
	_hex_btn.size = _hex.size
	_hex_btn.tooltip_text = str(n["name"]) + ": " + str(n["desc"])
	_hex_btn.pressed.connect(_on_buy.bind("hyper"))
	add_child(_hex_btn)

	add_child(UIKit.label_at(str(n["name"]), Vector2(960, NAME_Y), Vector2(400, 50), 42,
		LILA, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UIKit.label_at(str(n["desc"]), Vector2(960, DESC_Y), Vector2(400, 30), 28,
		Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	_cost = UIKit.label_at("", Vector2(960, COST_Y), Vector2(400, 30), 21,
		Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_cost)


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
	add_child(UIKit.fit_art("tree_asc_hyper", Vector2(icono_x, ROW_BANK),
		Vector2(RebirthPanel.BANK_ART, RebirthPanel.BANK_ART)))
	_points = PixelNumber.new()
	_points.color = LILA
	_points.scale_factor = RebirthPanel.BANK_SCALE
	_points.max_width = RebirthPanel.BANK_MAX_W
	add_child(_points)
	_points_label = UIKit.label("PUNTOS DE ASCENSION", 21, Palette.CREAM_D,
		HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_points_label)
	_status = UIKit.label("", 21, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_status)
	_hint_label = UIKit.label("", 21, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_hint_label)

	_go = UIKit.small_button("ASCENDER", "tree_asc_hyper", GO_CENTER, GO_W, 32)
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
	_points_label.text = "PUNTO DE ASCENSION" if Game.ascension_points == 1 \
		else "PUNTOS DE ASCENSION"
	_points_label.size = Vector2(UIKit.text_width(_points_label.text, 21), UIKit.text_height(21))
	_points_label.position = Vector2(_points.position.x + _points.size.x
		+ RebirthPanel.BANK_LABEL_GAP, ROW_BANK - _points_label.size.y * 0.5)

	var puede := Game.can_ascend()
	_go.modulate = BUTTON_TINT if puede else Color(0.5, 0.42, 0.62)
	_go.tooltip_text = ("Lo borra TODO: la partida, las monedas y el arbol del rebirth,"
		+ " los rebirths y el album. Te llevas 1 punto de ascension y lo comprado aqui.")
	if puede:
		_status.text = "YA PUEDES ASCENDER"
		_status.add_theme_color_override("font_color", Palette.GOLD_XL)
	else:
		_status.text = "ANTES: COMPRA TODO EL ARBOL DEL REBIRTH"
		_status.add_theme_color_override("font_color", Palette.RUST_L)
	_place_line(_status, ROW_STATUS)
	_hint_label.text = _hint_text
	_place_line(_hint_label, ROW_HINT)

	# El nodo: comprado, comprable (late) o sin puntos (apagado).
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_hex.scale = Vector2.ONE
	if Game.asc_owned("hyper"):
		_hex.modulate = Color.WHITE
		_cost.text = "COMPRADO"
		_cost.add_theme_color_override("font_color", LILA)
	else:
		var coste := int(AscensionTree.node_by_id("hyper")["cost"])
		_cost.text = "%d PUNTO%s" % [coste, "" if coste == 1 else "S"]
		var listo := Game.can_buy_asc("hyper")
		_cost.add_theme_color_override("font_color",
			Palette.GOLD_XL if listo else Palette.RUST_L)
		_hex.modulate = Color(1.15, 1.15, 1.15) if listo else Color(0.6, 0.55, 0.7)
		if listo:
			_pulse = _hex.create_tween().set_loops()
			_pulse.tween_property(_hex, "scale", Vector2.ONE * 1.05, 0.6)
			_pulse.tween_property(_hex, "scale", Vector2.ONE, 0.6)


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

func _on_buy(id: String) -> void:
	_confirm = false
	var n := AscensionTree.node_by_id(id)
	if Game.asc_owned(id):
		Sound.play("sfx_error")
		_hint("YA TIENES " + str(n["name"]), Palette.CREAM_D)
		return
	if not Game.can_buy_asc(id):
		Sound.play("sfx_error")
		_hint("TE FALTAN PUNTOS: ASCIENDE PARA GANARLOS", Palette.RUST_L)
		return
	Game.buy_asc(id)
	Sound.play("sfx_rare")
	_burst()
	MainRoot.get_root().banner(str(n["name"]), str(n["desc"]))
	_hint("COMPRADO: " + str(n["name"]) + " " + str(n["desc"]), Palette.GOLD_XL)


## Dos pulsaciones: la primera avisa de lo que se pierde, la segunda asciende.
func _on_ascend() -> void:
	if not Game.can_ascend():
		_confirm = false
		Sound.play("sfx_error")
		_hint("TE FALTA COMPRAR TODO EL ARBOL DEL REBIRTH", Palette.RUST_L)
		return
	if not _confirm:
		_confirm = true
		Sound.play("sfx_error")
		_hint("SE BORRA TODO. PULSA OTRA VEZ PARA ASCENDER", Palette.RUST_L)
		return
	_confirm = false
	var puntos := Game.do_ascension()
	Sound.play("sfx_tool")
	Sound.play("sfx_rare")
	_burst()
	MainRoot.get_root().banner("ASCENSION", "+%d PUNTO DE ASCENSION" % puntos)
	_hint("HAS ASCENDIDO: GASTA EL PUNTO EN EL HEXAGONO", Palette.GOLD_XL)


## Un estallido de particulas moradas desde el hexagono.
func _burst() -> void:
	var p := CPUParticles2D.new()
	p.position = HEX_CENTER
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
