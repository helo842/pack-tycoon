# PetPanel - la TIENDA DE MASCOTAS: un gachapon con cuatro maquinas.
#
# Sale en la barra de arriba, al lado de la TIENDA, en cuanto se compra HYPER en
# la ascension (Game.pet_shop_shown). Cada maquina es una pagina (flechas encima
# de la maquina) con sus seis mascotas: 1, 10 o 100 monedas de rebirth, o 1
# punto de ascension la tirada (ver PetDB.MACHINES). Cada tirada sube un nivel a
# la mascota que sale; las que estan al maximo ya no salen. Cada mascota sube una
# cosa (dinero, rebirth, dano, critico...) y no se pierden nunca, ni al ascender.
#
# Mismo estilo que la TIENDA: carton, la cinta roja del titulo, la etiqueta de
# papel con el saldo y fichas de papel sujetas con celo. A la izquierda la
# maquina y el boton de tirar; a la derecha las seis fichas. Lo que sale se
# ensena en grande, en el centro de la pantalla (ver _play_capsule).
class_name PetPanel
extends Control

signal closed()

const HEAD_Y := ShopPanel.HEAD_Y
const TITLE_TAG := ShopPanel.TITLE_TAG
const TITLE_TAG_CENTER := ShopPanel.TITLE_TAG_CENTER
const BOX := ShopPanel.BOX
const BOX_COL0_X := 840.0
const BOX_COL_STEP := ShopPanel.BOX_COL_STEP
const BOX_ROW0_Y := 248.0
const BOX_ROW_STEP := 352.0
const PER_ROW := 3
const ICON_BOX := Vector2(128, 128)
const ICON_DY := 80.0
const NAME_DY := 166.0
const LEVEL_DY := 202.0
const BONUS_DY := 236.0

## El saldo: la etiqueta de papel con el cerdito (o la estrella), a la derecha.
const COINS_PLATE := Rect2(1250, 98, 340, 68)

## La pagina (nombre de la maquina entre dos flechas), la maquina y el boton.
const PAGE_Y := 262.0
const PAGE_ARROW_DX := 230.0
const MACHINE_CENTER := Vector2(500, 490)
const MACHINE_BOX := Vector2(320, 320)
const ROLL_CENTER := Vector2(500, 740)
const ROLL_W := 320.0
const STATUS_Y := 830.0
## El revelado: en el centro de la pantalla, encima de todo.
const SCREEN_CENTER := Vector2(960, 470)

const SHADOW := ShopPanel.SHADOW
const TAPE := ShopPanel.TAPE
const TAPE_SIZE := ShopPanel.TAPE_SIZE
const EDGE := ShopPanel.EDGE
const PIP_ON := ShopPanel.PIP_ON
const PIP_OFF := ShopPanel.PIP_OFF
## La silueta de la mascota que aun no se tiene.
const LOCKED := Color(0.18, 0.12, 0.10, 0.55)
const LOCKED_TEXT := Color(0.55, 0.48, 0.42)

var _coins: PixelNumber
var _page_name: Label
var _status: Label
## Lo que cambia con la pagina (maquina, boton, fichas, icono del saldo): se
## rehace entero al pasar de pagina.
var _page_box: Control
var _machine: Control
var _roll: Button
var _cells: Dictionary = {}
var _page := 0
## El revelado a pantalla completa. Mientras esta, no se tira otra vez.
var _reveal: Control = null
var _reveal_ready := false
var _busy := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.veil(0.55))
	add_child(UIKit.panel("ui_panel_carton"))
	var close := UIKit.close_button(UIKit.PANEL_CLOSE)
	close.pressed.connect(_close)
	add_child(close)

	_build_head()
	_page_box = Control.new()
	_page_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_box)
	add_child(UIKit.image("ui_arrow_left", Vector2(MACHINE_CENTER.x - PAGE_ARROW_DX, PAGE_Y),
			Vector2(72, 72)))
	add_child(UIKit.image("ui_arrow_right", Vector2(MACHINE_CENTER.x + PAGE_ARROW_DX, PAGE_Y),
			Vector2(72, 72)))
	UIKit.hit_area(self, Rect2(Vector2(MACHINE_CENTER.x - PAGE_ARROW_DX - 40.0, PAGE_Y - 40.0),
			Vector2(80, 80)), "Maquina anterior").pressed.connect(_step_page.bind(-1))
	UIKit.hit_area(self, Rect2(Vector2(MACHINE_CENTER.x + PAGE_ARROW_DX - 40.0, PAGE_Y - 40.0),
			Vector2(80, 80)), "Maquina siguiente").pressed.connect(_step_page.bind(1))
	_page_name = UIKit.title_label_at("", Vector2(MACHINE_CENTER.x, PAGE_Y), Vector2(380, 50),
			40, Palette.OUTLINE)
	add_child(_page_name)
	_status = UIKit.title_label_at("", Vector2(MACHINE_CENTER.x, STATUS_Y), Vector2(560, 30),
			21, Palette.OUTLINE)
	add_child(_status)

	_build_page()
	Game.skills_changed.connect(refresh)


func _machine_data() -> Dictionary:
	return PetDB.MACHINES[_page]


func _currency_icon() -> String:
	return "tree_asc_star" if _machine_data()["currency"] == "ascension" else "currency_piggy"


func _step_page(step: int) -> void:
	if _busy:
		return
	Sound.click()
	_page = (_page + step + PetDB.MACHINES.size()) % PetDB.MACHINES.size()
	_status.text = ""
	_build_page()


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

func _build_head() -> void:
	add_child(UIKit.image("ui_tag_price", TITLE_TAG_CENTER, TITLE_TAG))
	# Label y no PixelNumber: la fuente de los precios no tiene la M, la C ni la O.
	add_child(UIKit.title_label_at("MASCOTAS", TITLE_TAG_CENTER, TITLE_TAG - Vector2(120, 40),
			44, Palette.GOLD_XL))

	_rect(COINS_PLATE.position + Vector2(6, 6), COINS_PLATE.size, SHADOW)
	_rect(COINS_PLATE.position, COINS_PLATE.size, ShopPanel.EDGE_OPEN)
	_rect(COINS_PLATE.position + Vector2(EDGE, EDGE), COINS_PLATE.size - Vector2(EDGE, EDGE) * 2.0,
			ShopPanel.BACK_OPEN)
	_rect(Vector2(COINS_PLATE.get_center().x - 30.0, COINS_PLATE.position.y - 10.0),
			Vector2(60, 20), TAPE)
	_coins = PixelNumber.new()
	_coins.scale_factor = 0.40
	_coins.max_width = COINS_PLATE.size.x - 110.0
	add_child(_coins)


## Rehace lo de la pagina actual: icono del saldo, maquina, boton y fichas.
func _build_page() -> void:
	for c in _page_box.get_children():
		c.queue_free()
	_cells = {}
	var m := _machine_data()
	_page_box.add_child(UIKit.fit_art(_currency_icon(),
			Vector2(COINS_PLATE.position.x + 50.0, HEAD_Y), Vector2(52, 52)))
	_machine = UIKit.fit_art("tree_pet_machine" + str(m["suffix"]), MACHINE_CENTER, MACHINE_BOX)
	_page_box.add_child(_machine)
	_roll = UIKit.small_button("TIRAR %d" % int(m["cost"]), _currency_icon(), ROLL_CENTER,
			ROLL_W, 32)
	_roll.tooltip_text = "Tirar de la maquina %s: %s" % [str(m["name"]).to_lower(), _cost_text()]
	_roll.pressed.connect(_on_roll)
	_page_box.add_child(_roll)
	_page_name.text = "%s  %d/%d" % [m["name"], _page + 1, PetDB.MACHINES.size()]
	_page_name.add_theme_font_size_override("font_size",
			UIKit.fit_size(_page_name.text, PAGE_ARROW_DX * 2.0 - 90.0, 40))

	var pets := PetDB.pets_of(str(m["id"]))
	var nombres: Array = []
	for p in pets:
		nombres.append(str(p["name"]))
	var name_size := UIKit.row_size(nombres, BOX.x - 24.0, 28)
	var al_maximo: Array = []
	for p in pets:
		al_maximo.append(PetDB.bonus_text(p, PetDB.MAX_LEVEL, true))
	var bonus_size := UIKit.row_size(al_maximo, BOX.x - 24.0, 21)
	for i in pets.size():
		var top_left := Vector2(BOX_COL0_X + float(i % PER_ROW) * BOX_COL_STEP,
				BOX_ROW0_Y + float(i / PER_ROW) * BOX_ROW_STEP)
		_build_cell(pets[i], top_left, name_size, bonus_size)
	refresh()


## "1 MONEDA", "10 MONEDAS", "1 PUNTO DE ASCENSION".
func _cost_text() -> String:
	var m := _machine_data()
	var n := int(m["cost"])
	if m["currency"] == "ascension":
		return "%d PUNTO%s DE ASCENSION" % [n, "" if n == 1 else "S"]
	return "%d MONEDA%s" % [n, "" if n == 1 else "S"]


## Una ficha: papel con filete, celo, la mascota, su nombre, los puntos de nivel
## y lo que da.
func _build_cell(p: Dictionary, top_left: Vector2, name_size: int, bonus_size: int) -> void:
	var x := top_left.x
	var box := _page_box
	_rect(top_left + ShopPanel.SHADOW_OFF, BOX, SHADOW, box)
	var frame := _rect(top_left, BOX, ShopPanel.EDGE_OPEN, box)
	_rect(top_left + Vector2(EDGE, EDGE), BOX - Vector2(EDGE, EDGE) * 2.0, ShopPanel.BACK_OPEN, box)
	_rect(Vector2(x + (BOX.x - TAPE_SIZE.x) * 0.5, top_left.y - TAPE_SIZE.y * 0.5), TAPE_SIZE, TAPE,
			box)
	var art := UIKit.fit_art(str(p["art"]), Vector2(x + BOX.x * 0.5, top_left.y + ICON_DY),
			ICON_BOX)
	box.add_child(art)
	box.add_child(UIKit.title_label_at(str(p["name"]), Vector2(x + BOX.x * 0.5, top_left.y + NAME_DY),
			Vector2(BOX.x - 24.0, 36), name_size, Palette.RARITY[str(p["rarity"])].darkened(0.3)))
	var pips: Array = []
	var side := 14.0
	var gap := 6.0
	var x0 := x + (BOX.x - (side + gap) * PetDB.MAX_LEVEL + gap) * 0.5
	for i in PetDB.MAX_LEVEL:
		pips.append(_rect(Vector2(x0 + float(i) * (side + gap), top_left.y + LEVEL_DY - side * 0.5),
				Vector2(side, side), PIP_OFF, box))
	# Un solo tamano para las fichas de la pagina, el del texto mas largo que
	# puede salir (ver _build_page): encogido ficha a ficha se leia como un fallo.
	var bonus := UIKit.title_label_at("", Vector2(x + BOX.x * 0.5, top_left.y + BONUS_DY),
			Vector2(BOX.x - 24.0, 24), bonus_size, Palette.GOLD_D)
	box.add_child(bonus)
	_cells[str(p["id"])] = {"art": art, "pips": pips, "bonus": bonus, "frame": frame}


func _rect(at: Vector2, size: Vector2, color: Color, parent: Node = self) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.position = at
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


# --------------------------------------------------------------------------- #
# Refresco
# --------------------------------------------------------------------------- #

func refresh() -> void:
	if not is_node_ready():
		return
	var m := _machine_data()
	_coins.set_number(Game.pet_currency(str(m["id"])))
	_coins.position = (Vector2(COINS_PLATE.position.x + 88.0, HEAD_Y - _coins.size.y * 0.5)).round()

	for p in PetDB.pets_of(str(m["id"])):
		var id := str(p["id"])
		var nivel := Game.pet_level(id)
		var c: Dictionary = _cells[id]
		(c["art"] as CanvasItem).modulate = Color.WHITE if nivel > 0 else LOCKED
		for i in PetDB.MAX_LEVEL:
			(c["pips"][i] as ColorRect).color = PIP_ON if i < nivel else PIP_OFF
		# Sin la mascota se ve lo que daria el nivel 1, en gris.
		var bonus := c["bonus"] as Label
		bonus.text = PetDB.bonus_text(p, nivel, true)
		bonus.add_theme_color_override("font_color", Palette.GOLD_D if nivel > 0 else LOCKED_TEXT)
		(c["frame"] as ColorRect).color = ShopPanel.EDGE_DONE if nivel >= PetDB.MAX_LEVEL \
				else ShopPanel.EDGE_OPEN

	var puede := Game.can_roll_pet(str(m["id"]))
	_roll.modulate = Color.WHITE if puede else Color(0.55, 0.55, 0.62, 1.0)
	if Game.pets_maxed(str(m["id"])):
		_status.text = "TODAS AL MAXIMO"
	elif not puede:
		_status.text = ("TE FALTA " if int(m["cost"]) == 1 else "TE FALTAN ") + _cost_text()
	elif _status.text.is_empty() or _status.text.begins_with("TE FALTA"):
		_status.text = _cost_text() + " POR CAPSULA"
	_status.add_theme_font_size_override("font_size", UIKit.fit_size(_status.text, 520.0, 21))


# --------------------------------------------------------------------------- #
# La tirada
# --------------------------------------------------------------------------- #

func _on_roll() -> void:
	if _busy:
		return
	var machine_id := str(_machine_data()["id"])
	if not Game.can_roll_pet(machine_id):
		Sound.play("sfx_error")
		UIKit.shake(_roll)
		return
	var id := Game.roll_pet(machine_id)
	_busy = true
	Sound.click()
	UIKit.shake(_machine)
	_play_capsule(PetDB.pet_by_id(id))


## EL REVELADO, en el centro de la pantalla y encima de todo, como la carta de la
## intro: se oscurece todo, la capsula cae, tiembla cada vez mas y revienta en un
## destello blanco; detras queda el brillo de su rareza girando y saltan chispas
## de ese color. Un clic lo cierra. La tirada YA esta hecha (Game.roll_pet); esto
## es solo lo que se ve.
func _play_capsule(p: Dictionary) -> void:
	_reveal = Control.new()
	_reveal.size = Vector2(1920, 1080)
	_reveal.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal.gui_input.connect(_on_reveal_input)
	_reveal_ready = false
	add_child(_reveal)
	var dim := _rect(Vector2(-200, -200), Vector2(2320, 1480), Color(0.02, 0.015, 0.04, 0.0), _reveal)
	dim.create_tween().tween_property(dim, "color:a", 0.9, 0.25)

	var holder := Control.new()
	holder.position = Vector2(SCREEN_CENTER.x, -150)
	holder.add_child(UIKit.fit_art("tree_pet_capsule", Vector2.ZERO, Vector2(160, 160)))
	_reveal.add_child(holder)
	var tw := holder.create_tween()
	tw.tween_property(holder, "position", SCREEN_CENTER, 0.5).set_trans(Tween.TRANS_BOUNCE) \
			.set_ease(Tween.EASE_OUT)
	# Tres tandas de temblor, cada una mas fuerte y mas grande: se va a abrir.
	for tanda in 3:
		var fuerza := 0.15 + 0.12 * tanda
		tw.tween_property(holder, "scale", Vector2.ONE * (1.0 + 0.15 * (tanda + 1)), 0.08)
		for ang in [fuerza, -fuerza, fuerza * 0.6, 0.0]:
			tw.tween_property(holder, "rotation", ang, 0.05)
		tw.tween_callback(Sound.play.bind("sfx_tool"))
		tw.tween_interval(0.12)
	tw.tween_callback(_open_capsule.bind(holder, p))


func _open_capsule(holder: Control, p: Dictionary) -> void:
	holder.queue_free()
	var rareza := str(p["rarity"])
	var color: Color = Palette.RARITY[rareza]
	Sound.play("sfx_rare" if rareza != "common" else "sfx_open")

	# El brillo de la rareza: dos capas que giran al reves y laten.
	for i in 2:
		var lado := 900.0 if i == 0 else 600.0
		var glow := UIKit.image("rarity_glow_" + rareza, SCREEN_CENTER, Vector2(lado, lado))
		glow.pivot_offset = glow.size * 0.5
		# Sumando luz y no tapando: sobre el velo oscuro asi brilla de verdad.
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		glow.modulate.a = 0.0
		_reveal.add_child(glow)
		glow.create_tween().tween_property(glow, "modulate:a", 1.0, 0.3)
		glow.create_tween().set_loops().tween_property(glow, "rotation", TAU * (1 if i == 0 else -1),
				7.0 if i == 0 else 5.0).as_relative()
		var pulso := glow.create_tween().set_loops()
		pulso.tween_property(glow, "scale", Vector2.ONE * 1.08, 0.6).set_trans(Tween.TRANS_SINE)
		pulso.tween_property(glow, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

	_burst(color, 70 if rareza == "legendary" else 40)
	var art := UIKit.fit_art(str(p["art"]), SCREEN_CENTER, Vector2(320, 320))
	art.pivot_offset = art.size * 0.5
	art.scale = Vector2(0.1, 0.1)
	_reveal.add_child(art)
	var at := art.create_tween()
	at.tween_property(art, "scale", Vector2.ONE * 1.15, 0.35).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	at.tween_property(art, "scale", Vector2.ONE, 0.15)
	var bote := art.create_tween().set_loops()
	bote.tween_property(art, "position:y", art.position.y - 14.0, 0.7).set_trans(Tween.TRANS_SINE)
	bote.tween_property(art, "position:y", art.position.y, 0.7).set_trans(Tween.TRANS_SINE)

	var flash := _rect(Vector2(-200, -200), Vector2(2320, 1480), Color.WHITE, _reveal)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.45)

	var nivel := Game.pet_level(str(p["id"]))
	var arriba := "NUEVA MASCOTA!" if nivel == 1 else "NIVEL %d" % nivel
	_pop_text(arriba, SCREEN_CENTER + Vector2(0, -250), 36, Palette.CREAM, 0.15)
	_pop_text(str(p["name"]), SCREEN_CENTER + Vector2(0, 230), 64, color, 0.3)
	_pop_text(Palette.RARITY_NAME[rareza] + " - " + PetDB.bonus_text(p, nivel),
			SCREEN_CENTER + Vector2(0, 300), 30, Palette.GOLD_XL, 0.45)
	_pop_text("CLIC PARA SEGUIR", SCREEN_CENTER + Vector2(0, 380), 22, Palette.CREAM_D, 0.9)
	_status.text = ("%s %s" % ["NUEVA:" if nivel == 1 else "NIVEL %d:" % nivel, str(p["name"])])
	refresh()
	get_tree().create_timer(0.4).timeout.connect(func() -> void: _reveal_ready = true)


## Un texto del revelado: aparece creciendo con rebote, con un poco de retraso.
func _pop_text(text: String, center: Vector2, font_size: int, color: Color, delay: float) -> void:
	var l := UIKit.label_at(text, center, Vector2(1400, font_size + 20), font_size, color,
			HORIZONTAL_ALIGNMENT_CENTER, 6, true)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ZERO
	_reveal.add_child(l)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.3).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Chispas del color de la rareza, en todas direcciones y cayendo.
func _burst(color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = SCREEN_CENTER
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 1.4
	p.spread = 180.0
	p.initial_velocity_min = 400.0
	p.initial_velocity_max = 900.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 8.0
	p.scale_amount_max = 16.0
	p.color = color.lightened(0.2)
	_reveal.add_child(p)
	p.emitting = true


func _on_reveal_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_reveal()


func _close_reveal() -> void:
	if _reveal == null or not _reveal_ready:
		return
	Sound.click()
	var r := _reveal
	_reveal = null
	_busy = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := r.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.2)
	tw.tween_callback(r.queue_free)


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _reveal != null and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		_close_reveal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
