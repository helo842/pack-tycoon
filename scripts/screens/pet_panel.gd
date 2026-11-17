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
const ROLL_W := 220.0
## Los dos botones (TIRAR 1 y TIRAR x5), uno a cada lado del centro de la maquina.
const ROLL_DX := 120.0
## Cuantas tiradas hace el boton grande.
const MULTI := 5
const STATUS_Y := 830.0
## El boton que abre el menu EQUIPAR: arriba, en la cabecera, al lado del saldo
## (abajo, bajo la maquina, no se veia).
## 192 de ancho (la chapa mide 0,45 de su ancho de alto: 86, poco mas que la
## etiqueta del saldo); con 240 se comia media cabecera y con 160 la letra no
## llegaba a 21.
const EQUIP_CENTER := Vector2(1144, HEAD_Y)
const EQUIP_W := 192.0
## La linea de ayuda del menu EQUIPAR, abajo en la columna de los huecos.
const EQUIP_HINT_Y := 915.0

## EL MENU EQUIPAR. A la izquierda los huecos (PetDB.SLOTS) y lo que dan en total;
## a la derecha todas las mascotas que se tienen, seis por fila.
const SLOT_BOX := Vector2(160, 230)
const SLOT_STEP := 180.0
const SLOT_Y := 330.0
const TOTALS_Y := 640.0
const OWN_BOX := Vector2(136, 176)
const OWN_X0 := 830.0
const OWN_Y0 := 236.0
const OWN_STEP := Vector2(146, 182)
const OWN_PER_ROW := 6
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
var _roll5: Button
var _cells: Dictionary = {}
var _page := 0
## El revelado a pantalla completa. Mientras esta, no se tira otra vez.
var _reveal: Control = null
var _reveal_ready := false
var _busy := false
## El menu EQUIPAR, encima de la tienda mientras esta abierto (null si no).
var _equip: Control = null
var _equip_status: Label = null


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
			Vector2(80, 80)), "Máquina anterior").pressed.connect(_step_page.bind(-1))
	UIKit.hit_area(self, Rect2(Vector2(MACHINE_CENTER.x + PAGE_ARROW_DX - 40.0, PAGE_Y - 40.0),
			Vector2(80, 80)), "Máquina siguiente").pressed.connect(_step_page.bind(1))
	_page_name = UIKit.title_label_at("", Vector2(MACHINE_CENTER.x, PAGE_Y), Vector2(380, 50),
			40, Palette.OUTLINE)
	add_child(_page_name)
	_status = UIKit.title_label_at("", Vector2(MACHINE_CENTER.x, STATUS_Y), Vector2(560, 30),
			21, Palette.OUTLINE)
	add_child(_status)

	var equipar := UIKit.small_button("Equipar", "", EQUIP_CENTER, EQUIP_W, 21)
	equipar.tooltip_text = "Elegir qué mascotas llevas: solo las equipadas dan su bonus"
	equipar.pressed.connect(_open_equip)
	add_child(equipar)

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
	add_child(UIKit.title_label_at("Mascotas", TITLE_TAG_CENTER, TITLE_TAG - Vector2(120, 40),
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
	# La maquina se mece despacio, como si esperara la moneda.
	UIKit.bob(_machine, 5.0, 3.2)
	_roll = UIKit.small_button("Tirar %d" % int(m["cost"]), _currency_icon(),
			ROLL_CENTER - Vector2(ROLL_DX, 0), ROLL_W, 30)
	_roll.tooltip_text = "Tirar de la máquina %s: %s" % [str(m["name"]).to_lower(), _cost_text().to_lower()]
	_roll.pressed.connect(_on_roll)
	_page_box.add_child(_roll)
	_roll5 = UIKit.small_button("Tirar x%d" % MULTI, _currency_icon(),
			ROLL_CENTER + Vector2(ROLL_DX, 0), ROLL_W, 30)
	_roll5.tooltip_text = "Tirar %d veces seguidas: %s" % [MULTI, _cost_text(MULTI)]
	_roll5.pressed.connect(_on_roll.bind(MULTI))
	_page_box.add_child(_roll5)
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
	# Las fichas de la pagina entran una detras de otra y luego flotan.
	var arts: Array = []
	for id in _cells:
		arts.append(_cells[id]["art"])
	UIKit.pop_in(arts, 0.05)
	for i in arts.size():
		UIKit.bob(arts[i], 3.0, 2.6, float(i) * 0.19)


## "1 MONEDA", "10 MONEDAS", "1 PUNTO DE ASCENSION".
func _cost_text(tiradas := 1) -> String:
	var m := _machine_data()
	var n := int(m["cost"]) * tiradas
	if m["currency"] == "ascension":
		return "%d punto%s de ascensión" % [n, "" if n == 1 else "s"]
	return "%d moneda%s" % [n, "" if n == 1 else "s"]


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
	_roll5.modulate = Color.WHITE if _can_roll_multi() else Color(0.55, 0.55, 0.62, 1.0)
	if Game.pets_maxed(str(m["id"])):
		_status.text = "Todas al máximo"
	elif not puede:
		_status.text = ("Te falta " if int(m["cost"]) == 1 else "Te faltan ") + _cost_text()
	elif _status.text.is_empty() or _status.text.begins_with("Te falta"):
		_status.text = _cost_text() + " por cápsula"
	_status.add_theme_font_size_override("font_size", UIKit.fit_size(_status.text, 520.0, 21))


# --------------------------------------------------------------------------- #
# La tirada
# --------------------------------------------------------------------------- #

## La x5 pide tener para las cinco; si la maquina se llena a medias, para ahi
## (no se cobra lo que no sale).
func _can_roll_multi() -> bool:
	var m := _machine_data()
	return Game.can_roll_pet(str(m["id"])) \
			and Game.pet_currency(str(m["id"])) >= int(m["cost"]) * MULTI


func _on_roll(tiradas := 1) -> void:
	if _busy:
		return
	var machine_id := str(_machine_data()["id"])
	var boton := _roll if tiradas == 1 else _roll5
	if not (Game.can_roll_pet(machine_id) if tiradas == 1 else _can_roll_multi()):
		Sound.play("sfx_error")
		UIKit.shake(boton)
		return
	var salidas: Array = []
	for i in tiradas:
		var id := Game.roll_pet(machine_id)
		if id == "":
			break
		salidas.append(PetDB.pet_by_id(id))
	_busy = true
	Sound.click()
	UIKit.shake(_machine)
	if salidas.size() == 1:
		_play_capsule(salidas[0])
	else:
		_play_capsules(salidas)


## El velo oscuro del revelado, encima de todo; un clic (cuando este listo) lo cierra.
func _open_reveal() -> void:
	_reveal = Control.new()
	_reveal.size = Vector2(1920, 1080)
	_reveal.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal.gui_input.connect(_on_reveal_input)
	_reveal_ready = false
	add_child(_reveal)
	var dim := _rect(Vector2(-200, -200), Vector2(2320, 1480), Color(0.02, 0.015, 0.04, 0.0), _reveal)
	dim.create_tween().tween_property(dim, "color:a", 0.9, 0.25)


## EL REVELADO, en el centro de la pantalla y encima de todo, como la carta de la
## intro: se oscurece todo, la capsula cae, tiembla cada vez mas y revienta en un
## destello blanco; detras queda el brillo de su rareza girando y saltan chispas
## de ese color. Un clic lo cierra. La tirada YA esta hecha (Game.roll_pet); esto
## es solo lo que se ve.
func _play_capsule(p: Dictionary) -> void:
	_open_reveal()
	var holder := Control.new()
	holder.position = Vector2(SCREEN_CENTER.x, -150)
	var brillo := _capsule_glow(holder, str(p["rarity"]), 360.0)
	holder.add_child(UIKit.fit_art("tree_pet_capsule", Vector2.ZERO, Vector2(160, 160)))
	_reveal.add_child(holder)
	var tw := holder.create_tween()
	tw.tween_property(holder, "position", SCREEN_CENTER, 0.5).set_trans(Tween.TRANS_BOUNCE) \
			.set_ease(Tween.EASE_OUT)
	# Tres tandas de temblor, cada una mas fuerte y mas grande: se va a abrir.
	for tanda in 3:
		var fuerza := 0.15 + 0.12 * tanda
		tw.tween_property(holder, "scale", Vector2.ONE * (1.0 + 0.15 * (tanda + 1)), 0.08)
		tw.parallel().tween_property(brillo, "modulate:a", (tanda + 2) / 4.0, 0.08)
		for ang in [fuerza, -fuerza, fuerza * 0.6, 0.0]:
			tw.tween_property(holder, "rotation", ang, 0.05)
		tw.tween_callback(Sound.play.bind("sfx_tool"))
		tw.tween_interval(0.12)
	tw.tween_callback(_open_capsule.bind(holder, p))


## La x5: caen todas las capsulas en fila, tiemblan juntas y revientan a la vez.
## Al final queda EL RESUMEN: cada mascota que ha salido (las repetidas juntas,
## con cuantas veces y el nivel con el que se queda), cada una con su brillo.
func _play_capsules(ps: Array) -> void:
	_open_reveal()
	var resumen := _summary(ps)
	var holders: Array = []
	for i in ps.size():
		var holder := Control.new()
		holder.position = Vector2(_slot_x(i, ps.size()), -150)
		var brillo := _capsule_glow(holder, str(ps[i]["rarity"]), 290.0)
		holder.add_child(UIKit.fit_art("tree_pet_capsule", Vector2.ZERO, Vector2(130, 130)))
		_reveal.add_child(holder)
		holders.append(holder)
		var tw := holder.create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(holder, "position:y", SCREEN_CENTER.y, 0.5) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		for tanda in 3:
			var fuerza := 0.15 + 0.12 * tanda
			tw.tween_property(holder, "scale", Vector2.ONE * (1.0 + 0.15 * (tanda + 1)), 0.08)
			tw.parallel().tween_property(brillo, "modulate:a", (tanda + 2) / 4.0, 0.08)
			for ang in [fuerza, -fuerza, fuerza * 0.6, 0.0]:
				tw.tween_property(holder, "rotation", ang, 0.05)
			if i == 0:
				tw.tween_callback(Sound.play.bind("sfx_tool"))
			tw.tween_interval(0.12)
		# La ultima en caer es la que abre todas.
		if i == ps.size() - 1:
			tw.tween_callback(_open_capsules.bind(holders, resumen))


## Las mascotas de la tirada sin repetir, en el orden en que salieron:
## [{"pet", "veces", "nivel"}]. El nivel es el que tiene ya (la tirada esta hecha).
func _summary(ps: Array) -> Array:
	var por_id := {}
	var out: Array = []
	for p in ps:
		var id := str(p["id"])
		if not por_id.has(id):
			por_id[id] = {"pet": p, "veces": 0, "nivel": Game.pet_level(id)}
			out.append(por_id[id])
		por_id[id]["veces"] += 1
	return out


func _slot_x(i: int, n: int) -> float:
	return SCREEN_CENTER.x + (float(i) - float(n - 1) * 0.5) * 340.0


func _open_capsules(holders: Array, resumen: Array) -> void:
	for h in holders:
		(h as Node).queue_free()
	var rara := false
	for r in resumen:
		rara = rara or str(r["pet"]["rarity"]) != "common"
	Sound.play("sfx_rare" if rara else "sfx_open")
	_pop_text("Tirada x%d" % MULTI, SCREEN_CENTER + Vector2(0, -300), 44, Palette.CREAM, 0.1)
	for i in resumen.size():
		var r: Dictionary = resumen[i]
		var p: Dictionary = r["pet"]
		var rareza := str(p["rarity"])
		var color: Color = Palette.RARITY[rareza]
		var c := Vector2(_slot_x(i, resumen.size()), SCREEN_CENTER.y - 30.0)
		var glow := UIKit.image("rarity_glow_" + rareza, c, Vector2(380, 380))
		glow.pivot_offset = glow.size * 0.5
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		_reveal.add_child(glow)
		glow.create_tween().set_loops().tween_property(glow, "rotation", TAU, 6.0).as_relative()
		_burst(color, 25, c)
		var art := UIKit.fit_art(str(p["art"]), c, Vector2(200, 200))
		art.pivot_offset = art.size * 0.5
		art.scale = Vector2(0.1, 0.1)
		_reveal.add_child(art)
		art.create_tween().tween_property(art, "scale", Vector2.ONE, 0.35).set_delay(0.08 * i) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var nivel := int(r["nivel"])
		var veces := int(r["veces"])
		# La fuente no tiene la x minuscula: X.
		var arriba := "¡Nueva!" if nivel == veces else "Nivel %d" % nivel
		if veces > 1:
			arriba = "x%d · nivel %d" % [veces, nivel] + (" · ¡nueva!" if nivel == veces else "")
		var d := 0.15 + 0.08 * i
		_pop_text(arriba, c + Vector2(0, -150), 26, Palette.CREAM, d, 320.0)
		_pop_text(str(p["name"]), c + Vector2(0, 140), 36, color, d + 0.1, 320.0)
		_pop_text(PetDB.bonus_text(p, nivel, true), c + Vector2(0, 185), 22, Palette.GOLD_XL,
				d + 0.2, 320.0)
	_pop_text("Clic para seguir", SCREEN_CENTER + Vector2(0, 380), 22, Palette.CREAM_D, 0.9)
	var flash := _rect(Vector2(-200, -200), Vector2(2320, 1480), Color.WHITE, _reveal)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.45)
	_status.text = "Tirada x%d: %d mascota%s" % [MULTI, resumen.size(),
			"" if resumen.size() == 1 else "s"]
	refresh()
	get_tree().create_timer(0.4).timeout.connect(func() -> void: _reveal_ready = true)


## El brillito que se escapa de la capsula antes de abrirse, del color de lo que
## lleva dentro, y unos destellos de ese color girando alrededor. Devuelve el
## conjunto apagado (alfa 0): quien lo llama lo sube con cada tanda de temblor.
func _capsule_glow(holder: Control, rareza: String, lado: float) -> Control:
	var fx := Control.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.modulate.a = 0.0
	holder.add_child(fx)
	var glow := UIKit.image("rarity_glow_" + rareza, Vector2.ZERO, Vector2(lado, lado))
	glow.pivot_offset = glow.size * 0.5
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	fx.add_child(glow)
	glow.create_tween().set_loops().tween_property(glow, "rotation", TAU, 4.0).as_relative()

	# Seis destellos en dos anillos (uno mas cerca), girando y parpadeando a destiempo.
	var orbita := Control.new()
	orbita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(orbita)
	var color: Color = Palette.RARITY[rareza].lightened(0.45)
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var r := lado * (0.40 if i % 2 == 0 else 0.30)
		var star := _sparkle(color, 1.0 if i % 2 == 0 else 0.7)
		star.position = Vector2(cos(ang), sin(ang)) * r
		orbita.add_child(star)
		var tw := star.create_tween().set_loops()
		tw.tween_interval(0.12 * i)
		tw.tween_property(star, "scale", star.scale * 0.35, 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(star, "scale", star.scale, 0.3).set_trans(Tween.TRANS_SINE)
	orbita.create_tween().set_loops().tween_property(orbita, "rotation", TAU, 1.6).as_relative()
	return fx


## Un destello de pixel art: una cruz fina con el centro casi blanco, centrada en
## el origen (asi escala y gira sobre si mismo).
func _sparkle(color: Color, escala: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.scale = Vector2.ONE * escala
	_rect(Vector2(-18, -3), Vector2(36, 6), color, c)
	_rect(Vector2(-3, -18), Vector2(6, 36), color, c)
	_rect(Vector2(-6, -6), Vector2(12, 12), color.lightened(0.6), c)
	return c


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
	var arriba := "¡Nueva mascota!" if nivel == 1 else "Nivel %d" % nivel
	_pop_text(arriba, SCREEN_CENTER + Vector2(0, -250), 36, Palette.CREAM, 0.15)
	_pop_text(str(p["name"]), SCREEN_CENTER + Vector2(0, 230), 64, color, 0.3)
	_pop_text(Palette.RARITY_NAME[rareza] + " - " + PetDB.bonus_text(p, nivel),
			SCREEN_CENTER + Vector2(0, 300), 30, Palette.GOLD_XL, 0.45)
	_pop_text("Clic para seguir", SCREEN_CENTER + Vector2(0, 380), 22, Palette.CREAM_D, 0.9)
	_status.text = ("%s %s" % ["Nueva:" if nivel == 1 else "Nivel %d:" % nivel, str(p["name"])])
	refresh()
	get_tree().create_timer(0.4).timeout.connect(func() -> void: _reveal_ready = true)


## Un texto del revelado: aparece creciendo con rebote, con un poco de retraso.
func _pop_text(text: String, center: Vector2, font_size: int, color: Color, delay: float,
		width := 1400.0) -> void:
	font_size = UIKit.fit_size(text, width, font_size)
	var l := UIKit.label_at(text, center, Vector2(width, font_size + 20), font_size, color,
			HORIZONTAL_ALIGNMENT_CENTER, 6, true)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ZERO
	_reveal.add_child(l)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.3).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Chispas del color de la rareza, en todas direcciones y cayendo.
func _burst(color: Color, amount: int, at := SCREEN_CENTER) -> void:
	var p := CPUParticles2D.new()
	p.position = at
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


# --------------------------------------------------------------------------- #
# El menu EQUIPAR
# --------------------------------------------------------------------------- #

func _open_equip() -> void:
	if _busy:
		return
	Sound.click()
	_equip = Control.new()
	_equip.size = Vector2(1920, 1080)
	_equip.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_equip)
	_build_equip()


func _close_equip() -> void:
	if _equip == null:
		return
	Sound.click()
	_equip.queue_free()
	_equip = null
	refresh()


## Rehace el menu entero: se llama al abrirlo y en cada cambio (son 24 fichas).
func _build_equip(aviso := "") -> void:
	for c in _equip.get_children():
		c.queue_free()
	_equip.add_child(UIKit.panel("ui_panel_carton"))
	var volver := UIKit.close_button(UIKit.PANEL_CLOSE)
	volver.tooltip_text = "Volver a las máquinas"
	volver.pressed.connect(_close_equip)
	_equip.add_child(volver)
	_equip.add_child(UIKit.image("ui_tag_price", TITLE_TAG_CENTER, TITLE_TAG))
	_equip.add_child(UIKit.title_label_at("Equipar", TITLE_TAG_CENTER, TITLE_TAG - Vector2(120, 40),
			44, Palette.GOLD_XL))

	# Los huecos: la equipada con su nivel encima, o vacio.
	_equip.add_child(UIKit.title_label_at("Equipadas %d/%d" % [Game.pets_equipped.size(),
			PetDB.SLOTS], Vector2(MACHINE_CENTER.x, PAGE_Y), Vector2(500, 50), 40, Palette.OUTLINE))
	for i in PetDB.SLOTS:
		var top_left := Vector2(MACHINE_CENTER.x + (float(i) - float(PetDB.SLOTS - 1) * 0.5)
				* SLOT_STEP - SLOT_BOX.x * 0.5, SLOT_Y)
		if i < Game.pets_equipped.size():
			var p := PetDB.pet_by_id(str(Game.pets_equipped[i]))
			_pet_card(p, top_left, SLOT_BOX, true, true)
		else:
			_paper(top_left, SLOT_BOX, ShopPanel.EDGE_OPEN, _equip)
			_equip.add_child(UIKit.title_label_at("Vacío", top_left + SLOT_BOX * 0.5,
					Vector2(SLOT_BOX.x - 16.0, 30), 24, LOCKED_TEXT))

	# Lo que dan entre todas, stat a stat (Game.pet_bonus ya solo cuenta las
	# equipadas), en una nota de papel: el dorado sobre el carton no se leia.
	_paper(Vector2(MACHINE_CENTER.x - 270.0, TOTALS_Y - 34.0), Vector2(540, 210),
			ShopPanel.EDGE_OPEN, _equip)
	_equip.add_child(UIKit.title_label_at("Lo que te dan", Vector2(MACHINE_CENTER.x, TOTALS_Y),
			Vector2(500, 40), 30, Palette.OUTLINE))
	var y := TOTALS_Y + 52.0
	for stat in PetDB.STAT_NAMES:
		var b := Game.pet_bonus(str(stat))
		if b <= 0.0:
			continue
		var t := "+%d%% de %s" % [roundi(b * 100.0), str(PetDB.STAT_NAMES[stat][1]).to_lower()]
		_equip.add_child(UIKit.title_label_at(t, Vector2(MACHINE_CENTER.x, y), Vector2(520, 34),
				UIKit.fit_size(t, 520.0, 28), Palette.GOLD_D))
		y += 40.0
	if Game.pets_equipped.is_empty():
		_equip.add_child(UIKit.title_label_at("Nada", Vector2(MACHINE_CENTER.x, y),
				Vector2(520, 34), 28, LOCKED_TEXT))

	var t := aviso if aviso != "" else "Clic para poner o quitar"
	_equip_status = UIKit.title_label_at(t, Vector2(MACHINE_CENTER.x, EQUIP_HINT_Y),
			Vector2(560, 30), UIKit.fit_size(t, 560.0, 21),
			Palette.OUTLINE)
	_equip.add_child(_equip_status)

	# Todas las que se tienen, en el orden de las maquinas, con su nivel encima.
	var n := 0
	for p in PetDB.PETS:
		if Game.pet_level(str(p["id"])) <= 0:
			continue
		var top_left := OWN_X0 * Vector2.RIGHT + OWN_Y0 * Vector2.DOWN \
				+ Vector2(float(n % OWN_PER_ROW) * OWN_STEP.x, float(n / OWN_PER_ROW) * OWN_STEP.y)
		_pet_card(p, top_left, OWN_BOX, Game.pet_equipped(str(p["id"])))
		n += 1
	if n == 0:
		_equip.add_child(UIKit.title_label_at("Aún no tienes mascotas",
				Vector2(OWN_X0 + OWN_STEP.x * 3.0 - 12.0, 540), Vector2(800, 40), 32, LOCKED_TEXT))


## Una ficha de mascota del menu EQUIPAR: el nivel ENCIMA ("NV 3"), el dibujo, el
## nombre (solo en los huecos: en la ficha pequena no cabia a un tamano que se
## leyera; ahi lo dice el raton encima) y lo que da a ese nivel ("+75%" y debajo
## "DINERO"). Marco dorado si esta equipada. Un clic la pone o la quita. Los
## tamanos de letra salen del texto mas largo de esa linea: iguales en todas.
func _pet_card(p: Dictionary, top_left: Vector2, box: Vector2, equipada: bool,
		con_nombre := false) -> void:
	var id := str(p["id"])
	var nivel := Game.pet_level(id)
	_paper(top_left, box, ShopPanel.EDGE_DONE if equipada else ShopPanel.EDGE_OPEN, _equip)
	var cx := top_left.x + box.x * 0.5
	var ancho := box.x - 16.0
	var nombres: Array = []
	var stats: Array = []
	for q in PetDB.PETS:
		nombres.append(str(q["name"]))
	for st in PetDB.STAT_NAMES.values():
		stats.append(str(st[1]))
	var nv := "Nv %d" % nivel if nivel < PetDB.MAX_LEVEL else "Nv max"
	var partes := PetDB.bonus_text(p, nivel, true).split(" ", true, 1)
	var lineas := [
		[nv, 0.10, UIKit.row_size(["Nv max"], ancho, int(box.y * 0.12)), Palette.OUTLINE],
		[partes[0], 0.76, UIKit.row_size(["+800%"], ancho, int(box.y * 0.14)), Palette.GOLD_D],
		[partes[1], 0.90, UIKit.row_size(stats, ancho, int(box.y * 0.10)), Palette.GOLD_D],
	]
	if con_nombre:
		lineas[1][1] = 0.78
		lineas.append([str(p["name"]), 0.64, UIKit.row_size(nombres, ancho, int(box.y * 0.10)),
				Palette.RARITY[str(p["rarity"])].darkened(0.3)])
	for l in lineas:
		_equip.add_child(UIKit.title_label_at(str(l[0]), Vector2(cx, top_left.y + box.y * l[1]),
				Vector2(ancho, l[2] + 4), l[2], l[3]))
	var lado := box.y * (0.36 if con_nombre else 0.40)
	var art := UIKit.fit_art(str(p["art"]), Vector2(cx, top_left.y + box.y * (0.37
			if con_nombre else 0.43)), Vector2(lado, lado))
	_equip.add_child(art)
	UIKit.bob(art, 2.0, 2.4, fmod(top_left.x * 0.0037 + top_left.y * 0.0021, 1.0))
	var hit := UIKit.hit_area(_equip, Rect2(top_left, box), "%s (nivel %d): %s. %s" % [
			str(p["name"]), nivel, PetDB.bonus_text(p, nivel),
			"Clic para quitarla" if equipada else "Clic para equiparla"])
	hit.pressed.connect(_on_equip_pressed.bind(id))


## El papel de una ficha: sombra, filete del color que se pida, fondo crema y celo.
func _paper(top_left: Vector2, box: Vector2, edge: Color, parent: Node) -> void:
	_rect(top_left + ShopPanel.SHADOW_OFF, box, SHADOW, parent)
	_rect(top_left, box, edge, parent)
	_rect(top_left + Vector2(EDGE, EDGE), box - Vector2(EDGE, EDGE) * 2.0, ShopPanel.BACK_OPEN,
			parent)
	_rect(Vector2(top_left.x + (box.x - TAPE_SIZE.x * 0.6) * 0.5, top_left.y - TAPE_SIZE.y * 0.4),
			TAPE_SIZE * 0.6, TAPE, parent)


func _on_equip_pressed(id: String) -> void:
	if Game.toggle_pet_equip(id):
		Sound.click()
		_build_equip()
	else:
		Sound.play("sfx_error")
		_build_equip("Huecos llenos: quita una")
		UIKit.shake(_equip_status)


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _reveal != null and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		_close_reveal()
		get_viewport().set_input_as_handled()
	elif _equip != null and event.is_action_pressed("ui_cancel"):
		_close_equip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
