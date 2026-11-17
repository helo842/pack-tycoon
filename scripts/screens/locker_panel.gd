# LockerPanel - el armario: el inventario a la IZQUIERDA y las vitrinas a la
# DERECHA, en la misma pantalla.
#
# EL INVENTARIO Y EL ARMARIO VAN JUNTOS Y NO EN DOS PANTALLAS. Mover un objeto de
# una a otra es UNA accion (pulsarlo), y con dos pantallas habria que salir de
# una, entrar en la otra y acordarse de cual era el objeto. Aqui esta todo a la
# vista: a la izquierda lo que tienes, a la derecha lo que expones.
#
# LO QUE HACE EXPONER. Un objeto expuesto sale del inventario -ya no se puede
# vender- y a cambio da el bonus de SU TIPO segun su nota PSA (ver LootDB,
# LOOT_KINDS): las CARTAS dan dano, las ZAPATILLAS velocidad de carga, los
# VINILOS dinero y la ELECTRONICA puntos de rebirth. Los cuatro totales se leen
# aqui abajo, que es el unico sitio donde se ve lo que se gana por exponer algo.
#
# DOS GESTOS EN LA REJILLA DEL INVENTARIO, porque son dos decisiones distintas:
# clic IZQUIERDO expone el objeto (lo que hace el panel) y clic DERECHO lo VENDE,
# ese y solo ese. Con el izquierdo a secas, vender era todo o nada (VENDER TODO al
# pie), y el inventario es justo donde se guarda lo que todavia no se ha decidido:
# se vende el barato y se expone el bueno. El gesto no se ve en la casilla, asi
# que lo dicen la leyenda de la columna y el tooltip de cada hueco.
#
# EL ESTILO ES EL DE LA TIENDA DE MASCOTAS (desde 2026-11-17): carton claro, la
# cinta roja del titulo y fichas de papel con celo. Antes iba en el panel oscuro
# con marcos negros y los objetos se veian pequenos y apagados. VENDER TODO va en
# la cabecera, donde la tienda de mascotas lleva el saldo.
#
# LOS HUECOS LOS PONE EL NIVEL DEL ARMARIO, no este panel: empieza con uno y
# llega a ocho (LootDB.locker_slots()). Los ocho marcos se dibujan SIEMPRE, y los
# que no tienes salen apagados: asi se ve que subir el armario sirve para algo
# (un hueco mas), que es lo que no se veia cuando el armario exponia solo.
class_name LockerPanel
extends Control

signal closed()

## La cabecera, como la de la tienda y la de mascotas (ver ShopPanel).
const HEAD_Y := ShopPanel.HEAD_Y
const TITLE_TAG := ShopPanel.TITLE_TAG
const TITLE_TAG_CENTER := ShopPanel.TITLE_TAG_CENTER
const SELL_CENTER := Vector2(1420, HEAD_Y)
## Las dos columnas. El centro de cada una: izquierda el inventario, derecha el
## armario.
const LEFT_MID := 574.0
const RIGHT_MID := 1346.0
const HEADER_Y := 250.0
## La leyenda de los dos gestos (clic izquierdo expone, derecho vende), entre el
## rotulo y la rejilla.
const LEGEND_Y := 288.0
## La rejilla del inventario: seis fichas de papel de 96 por fila, en una ventana
## con scroll (50 huecos no caben de una vez).
const INV_SIDE := 96.0
const INV_COLS := 6
const INV_STEP := 104.0
const INV_VIEW := Rect2(240, 316, 668, 624)
## Las vitrinas: ocho fichas de papel con celo, cuatro por fila. Cada una lleva el
## objeto, lo que da y lo que vale (el nombre lo dice el raton encima: los
## nombres largos no cabian a un tamano que se leyera).
const LOCK_CARD := Vector2(148, 176)
const LOCK_COLS := 4
const LOCK_STEP := Vector2(160, 190)
const LOCK_TOP := 292.0
## La nota de papel con lo que da el armario, debajo de las vitrinas.
const NOTE := Rect2(RIGHT_MID - 320.0, 690.0, 640.0, 254.0)
const STAT_Y := 760.0
const STAT_STEP := 32.0
const HINT_Y := 922.0
const HINT_COLOR := Palette.GOLD_D
## Texto oscuro sobre el carton, como en la tienda de mascotas.
const INK := Palette.OUTLINE
const MUTED := Color(0.18, 0.12, 0.10, 0.55)

var _inv_label: Label = null
var _locker_label: Label = null
## Una casilla del inventario por hueco: la ficha y su zona de clic.
var _inv_cells: Array = []
## Una ficha del armario por hueco (los ocho, tenga el armario el nivel que
## tenga): la ficha y su zona de clic.
var _locker_cells: Array = []
## Las lineas de bonus, en el orden de LootDB.kind_ids().
var _stat_labels: Array = []


func _ready() -> void:
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_carton"))
	add_child(UIKit.image("ui_tag_price", TITLE_TAG_CENTER, TITLE_TAG))
	add_child(UIKit.title_label_at("Armario", TITLE_TAG_CENTER, TITLE_TAG - Vector2(120, 40),
			44, Palette.GOLD_XL))

	var close := UIKit.close_button(UIKit.PANEL_CLOSE)
	close.pressed.connect(_close)
	add_child(close)

	# VENDER TODO, en la cabecera: vende el inventario entero (lo expuesto no).
	var sell := UIKit.small_button("Vender todo", "", SELL_CENTER, 288, 28,
			"ui_button_sell", "ui_button_sell")
	sell.tooltip_text = "Vende de golpe todo lo que hay en el inventario (lo expuesto no)"
	sell.pressed.connect(_sell_all)
	add_child(sell)

	_build_inventory()
	_build_locker()
	_build_stats()

	Game.inventory_changed.connect(refresh)
	Game.locker_changed.connect(refresh)
	Game.items_changed.connect(refresh)
	refresh()
	# Al abrir, lo que hay en las fichas entra una detras de otra.
	var arts: Array = []
	for cell in _locker_cells + _inv_cells:
		for c in (cell["holder"] as Control).get_children():
			if c is TextureRect:
				arts.append(c)
	UIKit.pop_in(arts, 0.03)


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

## Una ficha de papel: sombra, filete, fondo crema y (si `celo`) la tira de celo
## arriba. Va TODO dentro de un nodo "Back", que es lo unico que sobrevive a
## _clear() y lo que se apaga en los huecos que aun no son tuyos.
func _paper_holder(top_left: Vector2, box: Vector2, celo: bool) -> Control:
	var holder := Control.new()
	holder.size = box
	holder.position = top_left
	holder.pivot_offset = box * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Control.new()
	back.name = "Back"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)
	_rect(ShopPanel.SHADOW_OFF * 0.5, box, ShopPanel.SHADOW, back)
	_rect(Vector2.ZERO, box, ShopPanel.EDGE_OPEN, back)
	_rect(Vector2(ShopPanel.EDGE, ShopPanel.EDGE), box - Vector2(ShopPanel.EDGE, ShopPanel.EDGE) * 2.0,
			ShopPanel.BACK_OPEN, back)
	if celo:
		var t := ShopPanel.TAPE_SIZE * 0.7
		_rect(Vector2((box.x - t.x) * 0.5, -t.y * 0.5), t, ShopPanel.TAPE, back)
	return holder


func _rect(at: Vector2, size: Vector2, color: Color, parent: Node) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.position = at
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


## La columna de la IZQUIERDA: el inventario, en fichas de papel con scroll.
func _build_inventory() -> void:
	_inv_label = UIKit.label_at("", Vector2(LEFT_MID, HEADER_Y), Vector2(660, 44),
		35, INK, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_inv_label)

	var scroll := ScrollContainer.new()
	scroll.name = "InvScroll"
	scroll.position = INV_VIEW.position
	scroll.size = INV_VIEW.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	_style_scrollbar(scroll)

	var list := Control.new()
	list.name = "InvList"
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var filas := int(ceil(float(Game.INVENTORY_SLOTS) / float(INV_COLS)))
	# 8 px de mas abajo para la sombra de la ultima fila.
	list.custom_minimum_size = Vector2(0.0, float(filas) * INV_STEP + 8.0)
	scroll.add_child(list)

	# Un margen a cada lado para centrar la rejilla dentro de la ventana.
	var margen := (INV_VIEW.size.x - (float(INV_COLS - 1) * INV_STEP + INV_SIDE)) * 0.5
	for i in Game.INVENTORY_SLOTS:
		var col := i % INV_COLS
		var fila := i / INV_COLS
		var top_left := Vector2(margen + float(col) * INV_STEP, 4.0 + float(fila) * INV_STEP)
		var holder := _paper_holder(top_left, Vector2(INV_SIDE, INV_SIDE), false)
		list.add_child(holder)
		var b := UIKit.hit_area(list, Rect2(top_left, Vector2(INV_SIDE, INV_SIDE)), "")
		b.pressed.connect(_expose.bind(i))
		# El clic DERECHO vende ESE objeto y solo ese. Godot no emite `pressed` con
		# el boton derecho (el Button solo escucha el izquierdo), asi que el evento
		# se mira a mano.
		b.gui_input.connect(_on_inv_input.bind(i))
		UIKit.juice(b, [holder], 1.08)
		_inv_cells.append({"holder": holder, "button": b})

	# LOS DOS GESTOS, ESCRITOS. El clic derecho no tiene nada que lo anuncie
	# dentro de la casilla: esta linea y el tooltip de cada hueco lo explican.
	add_child(UIKit.label_at("Clic: exponer · Clic derecho: vender",
		Vector2(LEFT_MID, LEGEND_Y), Vector2(660, 24), 21, INK,
		HORIZONTAL_ALIGNMENT_CENTER, 0, true))


## La columna de la DERECHA: las vitrinas. Se dibujan las ocho del tope del
## armario y las que no estan compradas salen apagadas, para que se vea lo que da
## subirlo.
func _build_locker() -> void:
	_locker_label = UIKit.label_at("", Vector2(RIGHT_MID, HEADER_Y), Vector2(660, 44),
		35, INK, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_locker_label)

	for i in LootDB.LOCKER_SLOTS_MAX:
		var col := i % LOCK_COLS
		var fila := i / LOCK_COLS
		var top_left := Vector2(RIGHT_MID + (float(col) - (float(LOCK_COLS) - 1.0) * 0.5)
				* LOCK_STEP.x - LOCK_CARD.x * 0.5, LOCK_TOP + float(fila) * LOCK_STEP.y)
		var holder := _paper_holder(top_left, LOCK_CARD, true)
		add_child(holder)
		var b := UIKit.hit_area(self, Rect2(top_left, LOCK_CARD), "")
		b.pressed.connect(_take.bind(i))
		UIKit.juice(b, [holder], 1.06)
		_locker_cells.append({"holder": holder, "button": b})


## La nota de papel con lo que da el armario: una linea por tipo de botin (el
## total que da cada uno a su stat) y debajo la pista de como sube.
func _build_stats() -> void:
	add_child(_paper_holder(NOTE.position, NOTE.size, true))
	add_child(UIKit.label_at("Lo que te da", Vector2(RIGHT_MID, NOTE.position.y + 34),
			Vector2(600, 40), 28, INK, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	for i in LootDB.kind_ids().size():
		var l := UIKit.label_at("", Vector2(RIGHT_MID, STAT_Y + float(i) * STAT_STEP),
				Vector2(600, 30), 21, INK, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
		add_child(l)
		_stat_labels.append(l)
	# Los porcentajes salen de LootDB (ver LootDB.bonus_for), y la pista dice las
	# dos cosas que se le escapan al jugador: el valor cuenta y repetir tipo resta.
	add_child(UIKit.label_at("Mejor nota, rareza y sobre: más bonus. Repetir tipo: menos",
			Vector2(RIGHT_MID, HINT_Y), Vector2(600, 22), 14, HINT_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))


## La barra de scroll, con los colores del juego (la de Godot es gris y redonda).
func _style_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(10.0, 0.0)
	for par in [["scroll", Color(0.35, 0.23, 0.16, 0.35)],
			["grabber", Color(Palette.GOLD_D, 0.8)],
			["grabber_highlight", Color(Palette.GOLD, 0.9)],
			["grabber_pressed", Palette.GOLD_XL]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = par[1]
		bar.add_theme_stylebox_override(str(par[0]), sb)


# --------------------------------------------------------------------------- #
# Refresco
# --------------------------------------------------------------------------- #

## Repinta las dos rejillas, los dos rotulos y las cuatro lineas de bonus. Es una
## sola funcion y no cuatro porque todo esto cambia a la vez: mover un objeto de
## una columna a la otra cambia las dos rejillas y al menos una linea.
func refresh() -> void:
	if not is_node_ready():
		return
	_inv_label.text = "Inventario %d/%d" % [Game.inventory.size(), Game.INVENTORY_SLOTS]
	_locker_label.text = "Armario %d/%d" % [Game.locker_size(), Game.locker_slots()]
	_paint_inventory()
	_paint_locker()
	_paint_stats()


func _paint_inventory() -> void:
	for i in _inv_cells.size():
		var holder: Control = _inv_cells[i]["holder"]
		var b: Button = _inv_cells[i]["button"]
		_clear(holder)
		var hay := i < Game.inventory.size()
		if not hay:
			# El tooltip se limpia: una casilla vacia que siga diciendo "Exponer
			# TREBOL" de la vez anterior es peor que no decir nada.
			b.tooltip_text = ""
			b.disabled = true
			continue
		b.disabled = false
		var item: Dictionary = Game.inventory[i]
		# 8 px por encima del centro y no 6: los dibujos que llenan su lienzo hasta
		# abajo (un vinilo es un disco entero) bajaban 1,5 px por encima del precio
		# de la casilla. Es la misma cuenta que la vitrina de la partida.
		var dibujo := UIKit.fit_art(str(item.get("art", "loot_vinyl")),
				Vector2(INV_SIDE * 0.5, INV_SIDE * 0.5 - 10.0),
				Vector2(INV_SIDE * 0.68, INV_SIDE * 0.62))
		# Un objeto HOLO (GOLDEN RAIN) brilla tambien aqui.
		if Gameplay.is_holo(item):
			UIKit.holo(dibujo)
		holder.add_child(dibujo)
		_add_value(holder, int(item.get("value", 0)), Vector2(INV_SIDE, INV_SIDE), 0.18)
		# El tooltip dice QUE pasa al pulsarlo, con lo que va a aportar: es lo
		# unico que explica el intercambio (el objeto deja de poder venderse). Y
		# dice tambien el otro gesto, con SU precio: el clic derecho no se ve.
		b.tooltip_text = "Exponer %s (%s) - clic derecho: vender por %s" % [
				str(item.get("name", "")),
				_kind_bonus_text(LootDB.kind_of(item), LootDB.bonus_for(item)),
				PixelNumber.format(int(item.get("value", 0)))]


func _paint_locker() -> void:
	var slots := Game.locker_slots()
	for i in _locker_cells.size():
		var holder: Control = _locker_cells[i]["holder"]
		var b: Button = _locker_cells[i]["button"]
		_clear(holder)
		b.tooltip_text = ""
		var back := holder.get_node_or_null("Back") as CanvasItem
		if i >= slots:
			# Hueco que todavia no es tuyo: la ficha apagada, sin zona de clic, y
			# dice que se abre subiendo el armario.
			back.modulate = Color(0.55, 0.5, 0.48, 0.7)
			holder.add_child(UIKit.label_at("Cerrado", LOCK_CARD * 0.5,
					Vector2(LOCK_CARD.x - 16, 26), 21, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
			b.tooltip_text = "Sube el armario en la tienda para abrir este hueco"
			b.disabled = true
			continue
		back.modulate = Color.WHITE
		var hay := i < Game.locker.size()
		b.disabled = not hay
		if not hay:
			holder.add_child(UIKit.label_at("Vacío", LOCK_CARD * 0.5,
					Vector2(LOCK_CARD.x - 16, 26), 21, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
			continue
		var item: Dictionary = Game.locker[i]
		var dibujo := UIKit.fit_art(str(item.get("art", "loot_vinyl")),
				Vector2(LOCK_CARD.x * 0.5, 66.0), Vector2(104, 92))
		# Un objeto HOLO (GOLDEN RAIN) brilla tambien aqui.
		if Gameplay.is_holo(item):
			UIKit.holo(dibujo)
		holder.add_child(dibujo)
		# Lo expuesto flota en su vitrina.
		UIKit.bob(dibujo, 3.0, 2.8, float(i) * 0.21)
		var que := _kind_bonus_text(LootDB.kind_of(item), LootDB.bonus_for(item))
		holder.add_child(UIKit.label_at(que, Vector2(LOCK_CARD.x * 0.5, 128.0),
				Vector2(LOCK_CARD.x - 12, 24), UIKit.fit_size(que, LOCK_CARD.x - 16, 21),
				Palette.GOLD_D, HORIZONTAL_ALIGNMENT_CENTER))
		_add_value(holder, int(item.get("value", 0)), LOCK_CARD, 0.2)
		b.tooltip_text = "%s (%s). Clic: devolverlo al inventario" % [
				str(item.get("name", "")), que]


func _paint_stats() -> void:
	var totals := Game.kind_totals()
	var ids := LootDB.kind_ids()
	for i in mini(ids.size(), _stat_labels.size()):
		var row := LootDB.kind_row(str(ids[i]))
		var pct := roundi(float(totals.get(str(ids[i]), 0.0)) * 100.0)
		var l: Label = _stat_labels[i]
		l.text = "%s: +%d %% de %s" % [str(row["name"]), pct, str(row["stat"]).to_lower()]
		l.add_theme_color_override("font_color", Palette.GOLD_D if pct > 0 else MUTED)


## Lo que vale un objeto, con los digitos dorados, al pie de su ficha.
func _add_value(holder: Control, value: int, box: Vector2, escala: float) -> void:
	var num := PixelNumber.new()
	num.scale_factor = escala
	num.max_width = box.x - 12.0
	holder.add_child(num)
	num.set_number(value)
	num.position = (Vector2(box.x * 0.5, box.y - 18.0) - num.size * 0.5).round()


## Vacia una ficha SIN cargarse su papel: el "Back" (ver _paper_holder) es lo
## unico que tiene que sobrevivir a un refresco.
static func _clear(holder: Control) -> void:
	for c in holder.get_children():
		if c.name != "Back":
			holder.remove_child(c)
			c.queue_free()


## "+13 % daño": lo que aporta un objeto (o un tipo) al stat que toca.
static func _kind_bonus_text(kind_id: String, bonus: float) -> String:
	return "+%d %% %s" % [roundi(bonus * 100.0),
			str(LootDB.kind_row(kind_id)["stat"]).to_lower()]


# --------------------------------------------------------------------------- #
# Acciones
# --------------------------------------------------------------------------- #

## Pulsar un objeto del inventario lo EXPONE: sale del inventario y entra en el
## armario. Lo unico que puede impedirlo es que no haya hueco, y se distinguen
## los dos motivos: sin armario comprado no hay vitrina, y con el armario lleno
## lo que falta es subirlo de nivel.
func _expose(index: int) -> void:
	Sound.click()
	if Game.locker_slots() <= 0:
		Sound.play("sfx_error")
		Game.notice.emit("Hacen falta: armario", Palette.RUST_L)
		return
	if not Game.locker_put(index):
		Sound.play("sfx_error")
		Game.notice.emit("Armario lleno: sube el armario", Palette.RUST_L)
		return


## Pulsar un objeto expuesto lo devuelve al inventario: exponer no puede ser una
## decision sin vuelta atras (el objeto no vale para otra cosa mientras esta ahi).
func _take(index: int) -> void:
	if index >= Game.locker.size():
		return
	Sound.click()
	if not Game.locker_take(index):
		Sound.play("sfx_error")
		Game.notice.emit("Inventario lleno", Palette.RUST_L)


## Vender UN objeto del inventario: el clic derecho sobre su hueco.
##
## Hace falta porque VENDER TODO es todo o nada, y el inventario es donde se
## guarda lo que todavia no se ha decidido. El objeto que se vende es el de ESE
## hueco y ninguno mas, y paga Game.sell_at(index): el MISMO valor que el hueco
## esta enseñando, asi que la casilla no puede decir una cifra y pagar otra.
##
## Lo expuesto en el armario NO se vende desde aqui: eso se devuelve al inventario
## y luego se vende, que es el trato de exponer (mientras esta en la vitrina no
## vale para vender).
func _sell_one(index: int) -> void:
	if index < 0 or index >= Game.inventory.size():
		return
	var value := Game.sell_at(index)
	if value <= 0:
		Sound.play("sfx_error")
		return
	Sound.play("sfx_sell")
	Game.notice.emit("Vendido: +" + PixelNumber.format(value), Palette.GOLD_XL)


## El evento del clic derecho sobre un hueco del inventario. Godot solo emite
## `pressed` con el boton izquierdo, asi que el derecho hay que mirarlo aqui. El
## evento se consume para que no siga subiendo y lo reciba otra cosa.
func _on_inv_input(event: InputEvent, index: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	_sell_one(index)
	accept_event()


func _sell_all() -> void:
	var total := Game.inventory_value()
	if total <= 0:
		Sound.play("sfx_error")
		Game.notice.emit("No hay nada que vender", Palette.CREAM_D)
		return
	Game.sell_all()
	Sound.play("sfx_sell_all")
	Game.notice.emit("+" + PixelNumber.format(total), Palette.GOLD_XL)


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
