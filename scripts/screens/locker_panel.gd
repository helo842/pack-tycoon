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
# LOS HUECOS LOS PONE EL NIVEL DEL ARMARIO, no este panel: empieza con uno y
# llega a ocho (LootDB.locker_slots()). Los ocho marcos se dibujan SIEMPRE, y los
# que no tienes salen apagados: asi se ve que subir el armario sirve para algo
# (un hueco mas), que es lo que no se veia cuando el armario exponia solo.
class_name LockerPanel
extends Control

signal closed()

## Las mismas medidas que la tienda y el mini menu, que usan el mismo panel:
## ui_panel_shop.png es de 1600x960 y se dibuja tal cual, con el interior de
## x 224..1696 e y 140..940.
const TITLE_Y := 250.0
## Las dos columnas. El centro de cada una: izquierda el inventario, derecha el
## armario. 700 px de ancho cada una con 72 de aire en medio.
const LEFT_MID := 574.0
const RIGHT_MID := 1346.0
const HEADER_Y := 316.0
## La rejilla del inventario: seis columnas de 96 (616 px con los huecos), que es
## lo que cabe a lo ancho de la columna, y las filas que quepan de alto en la
## ventana del scroll. Con 50 huecos salen nueve filas y hay scroll.
const INV_SIDE := 96.0
const INV_COLS := 6
const INV_STEP := 104.0
## La ventana del scroll del inventario. Empieza debajo del rotulo (que acaba en
## 336) y le deja sitio al boton de vender, que baja hasta 920.
const INV_VIEW := Rect2(240, 360, 668, 400)
## La rejilla del armario: cuatro columnas de 128 (536 px), que es lo que piden
## ocho huecos en dos filas.
const LOCK_SIDE := 128.0
const LOCK_COLS := 4
const LOCK_STEP := 136.0
const LOCK_TOP := 424.0
## Las cuatro lineas de los bonus, debajo de las vitrinas.
const STAT_Y := 668.0
const STAT_STEP := 40.0
## La nota va a 824 y no mas abajo: el pie de la columna es del boton de vender
## (su chapa sube hasta 840) y con la nota a 856 el marco le comia el texto.
const HINT_Y := 824.0
const HINT_COLOR := Color(0.72, 0.72, 0.78, 1.0)

var _inv_label: Label = null
var _locker_label: Label = null
## Una casilla del inventario por hueco: el marco y su zona de clic.
var _inv_cells: Array = []
## Una casilla del armario por hueco (los ocho, tenga el armario el nivel que
## tenga): el marco, su fondo y su zona de clic.
var _locker_cells: Array = []
## Las cuatro lineas de bonus, en el orden de LootDB.kind_ids().
var _stat_labels: Array = []


func _ready() -> void:
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))

	add_child(UIKit.label_at("ARMARIO", Vector2(960, TITLE_Y), Vector2(1400, 70),
		48, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	var close := UIKit.close_button(Vector2(1650, TITLE_Y), 96.0)
	close.pressed.connect(_close)
	add_child(close)

	_build_inventory()
	_build_locker()
	_build_stats()

	Game.inventory_changed.connect(refresh)
	Game.locker_changed.connect(refresh)
	Game.items_changed.connect(refresh)
	refresh()


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

## La columna de la IZQUIERDA: el inventario. Con 50 huecos no caben de una vez,
## asi que la rejilla vive en una ventana con scroll, como la lista de sobres de
## la pantalla de partida.
func _build_inventory() -> void:
	_inv_label = UIKit.label_at("", Vector2(LEFT_MID, HEADER_Y), Vector2(660, 44),
		28, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
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
	list.custom_minimum_size = Vector2(0.0, float(filas) * INV_STEP)
	scroll.add_child(list)

	# Un margen a cada lado para centrar la rejilla dentro de la ventana: con seis
	# columnas de 96 y huecos de 8 son 616 px en una ventana de 668.
	var margen := (INV_VIEW.size.x - (float(INV_COLS - 1) * INV_STEP + INV_SIDE)) * 0.5
	for i in Game.INVENTORY_SLOTS:
		var col := i % INV_COLS
		var fila := i / INV_COLS
		var centre := Vector2(margen + INV_SIDE * 0.5 + float(col) * INV_STEP,
				INV_SIDE * 0.5 + float(fila) * INV_STEP)
		var holder := UIKit.slot(centre, INV_SIDE)
		list.add_child(holder)
		var b := UIKit.hit_area(list, Rect2(centre - Vector2(INV_SIDE, INV_SIDE) * 0.5,
				Vector2(INV_SIDE, INV_SIDE)), "")
		b.pressed.connect(_expose.bind(i))
		_inv_cells.append({"holder": holder, "button": b})

	# VENDER TODO vive aqui porque el inventario ya no esta en la pantalla de
	# partida: si el boton se hubiera quedado alli, no habria forma de vaciar el
	# inventario.
	# La chapa va MAS ABAJO y mas estrecha que las de los otros paneles (224 en vez
	# de 384) porque pega con la ventana del scroll: la chapa mide 0,45 de su ancho
	# de alto, y con 384 el rotulo se metia debajo del marco de la ultima fila de
	# huecos (medido: el texto a y 855..869 y los marcos hasta 872).
	# VENDER TODO va en el PIE DE LA COLUMNA DEL ARMARIO y no debajo del inventario,
	# que es donde estaba el boton cuando el inventario vivia en la partida. Abajo a
	# la izquierda no cabe: la rejilla del inventario son nueve filas y su ultima
	# fila acaba en y 976, asi que cualquier chapa ahi se mete debajo de un marco
	# que el scroll ya no enseña (medido: la chapa se comia 7 px del marco). El
	# tooltip dice a quien vende, que es lo unico que el sitio no deja claro.
	var sell := UIKit.small_button("VENDER TODO", "", Vector2(RIGHT_MID, 890), 224, 21,
			"ui_button_sell", "ui_button_sell")
	sell.tooltip_text = "Vende de golpe todo lo que hay en el inventario (lo expuesto no)"
	sell.pressed.connect(_sell_all)
	add_child(sell)


## La columna de la DERECHA: las vitrinas. Se dibujan los ocho huecos del tope
## del armario y los que no estan comprados salen apagados, para que se vea lo
## que da subirlo.
func _build_locker() -> void:
	_locker_label = UIKit.label_at("", Vector2(RIGHT_MID, HEADER_Y), Vector2(660, 44),
		28, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_locker_label)

	for i in LootDB.LOCKER_SLOTS_MAX:
		var col := i % LOCK_COLS
		var fila := i / LOCK_COLS
		var centre := Vector2(RIGHT_MID + (float(col) - (float(LOCK_COLS) - 1.0) * 0.5)
				* LOCK_STEP, LOCK_TOP + float(fila) * LOCK_STEP)
		var holder := UIKit.slot(centre, LOCK_SIDE)
		add_child(holder)
		var b := UIKit.hit_area(self, Rect2(centre - Vector2(LOCK_SIDE, LOCK_SIDE) * 0.5,
				Vector2(LOCK_SIDE, LOCK_SIDE)), "")
		b.pressed.connect(_take.bind(i))
		_locker_cells.append({"holder": holder, "button": b})


## Las cuatro lineas de bonus, una por tipo de botin, en el orden de
## LootDB.kind_ids(): el total que da el armario a cada stat.
func _build_stats() -> void:
	for i in LootDB.kind_ids().size():
		var l := UIKit.label_at("", Vector2(RIGHT_MID, STAT_Y + float(i) * STAT_STEP),
				Vector2(660, 36), 24, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
		add_child(l)
		_stat_labels.append(l)
	add_child(UIKit.label_at("CADA OBJETO DA DE UN 2 % A UN 15 % SEGUN SU NOTA PSA",
			Vector2(RIGHT_MID, HINT_Y), Vector2(660, 32), 16, HINT_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))


## La barra de scroll, con los colores del juego. La misma que la columna de
## sobres (ver game.gd, _style_pack_scrollbar()): la de Godot es gris con las
## esquinas redondeadas y en una pantalla de pixel art se lee como un pegote.
func _style_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(10.0, 0.0)
	for par in [["scroll", Color(0.02, 0.015, 0.04, 0.45)],
			["grabber", Color(Palette.GOLD_D, 0.7)],
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
	_inv_label.text = "INVENTARIO %d/%d" % [Game.inventory.size(), Game.INVENTORY_SLOTS]
	_locker_label.text = "ARMARIO %d/%d" % [Game.locker_size(), Game.locker_slots()]
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
			# GUANTES" de la vez anterior es peor que no decir nada.
			b.tooltip_text = ""
			b.disabled = true
			continue
		b.disabled = false
		var item: Dictionary = Game.inventory[i]
		holder.add_child(UIKit.fit_art(str(item.get("art", "loot_vinyl")),
				Vector2(INV_SIDE * 0.5, INV_SIDE * 0.5 - 6.0),
				Vector2(INV_SIDE * 0.6, INV_SIDE * 0.6)))
		_add_value(holder, int(item.get("value", 0)), INV_SIDE)
		# El tooltip dice QUE pasa al pulsarlo, con lo que va a aportar: es lo
		# unico que explica el intercambio (el objeto deja de poder venderse).
		b.tooltip_text = "Exponer %s (%s)" % [str(item.get("name", "")),
				_kind_bonus_text(LootDB.kind_of(item), LootDB.bonus_for(item))]


func _paint_locker() -> void:
	var slots := Game.locker_slots()
	for i in _locker_cells.size():
		var holder: Control = _locker_cells[i]["holder"]
		var b: Button = _locker_cells[i]["button"]
		_clear(holder)
		b.tooltip_text = ""
		if i >= slots:
			# Hueco que todavia no es tuyo: se queda el marco apagado, sin zona de
			# clic (no hay nada que decidir en un sitio que no existe).
			var back := holder.get_node_or_null("Back") as TextureRect
			if back != null:
				back.modulate = Color(0.35, 0.35, 0.4, 1.0)
			b.disabled = true
			continue
		var back_on := holder.get_node_or_null("Back") as TextureRect
		if back_on != null:
			back_on.modulate = Color.WHITE
		var hay := i < Game.locker.size()
		b.disabled = not hay
		if not hay:
			continue
		var item: Dictionary = Game.locker[i]
		holder.add_child(UIKit.fit_art(str(item.get("art", "loot_vinyl")),
				Vector2(LOCK_SIDE * 0.5, LOCK_SIDE * 0.5 - 8.0),
				Vector2(LOCK_SIDE * 0.62, LOCK_SIDE * 0.62)))
		_add_value(holder, int(item.get("value", 0)), LOCK_SIDE)
		b.tooltip_text = "Guardar %s en el inventario (%s)" % [str(item.get("name", "")),
				_kind_bonus_text(LootDB.kind_of(item), LootDB.bonus_for(item))]


func _paint_stats() -> void:
	var totals := Game.kind_totals()
	var ids := LootDB.kind_ids()
	for i in mini(ids.size(), _stat_labels.size()):
		var row := LootDB.kind_row(str(ids[i]))
		var pct := roundi(float(totals.get(str(ids[i]), 0.0)) * 100.0)
		var l: Label = _stat_labels[i]
		l.text = "%s +%d %% %s" % [str(row["name"]), pct, str(row["stat"])]
		l.add_theme_color_override("font_color",
				Palette.GOLD_XL if pct > 0 else Palette.CREAM_D)


## La linea de una casilla: el objeto y, debajo, lo que vale.
func _add_value(holder: Control, value: int, side: float) -> void:
	var num := PixelNumber.new()
	num.scale_factor = 0.13
	num.max_width = side - 10.0
	holder.add_child(num)
	num.set_number(value)
	num.position = Vector2(side * 0.5, side - 22.0) - num.size * 0.5


## Vacia una ranura SIN cargarse su fondo: el "Back" es el marco que pone
## UIKit.slot() y es lo unico que tiene que sobrevivir a un refresco.
static func _clear(holder: Control) -> void:
	for c in holder.get_children():
		if c.name != "Back":
			holder.remove_child(c)
			c.queue_free()


## "+13 % DANO": lo que aporta un objeto (o un tipo) al stat que toca.
static func _kind_bonus_text(kind_id: String, bonus: float) -> String:
	return "+%d %% %s" % [roundi(bonus * 100.0), str(LootDB.kind_row(kind_id)["stat"])]


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
		Game.notice.emit("HACEN FALTA: ARMARIO", Palette.RUST_L)
		return
	if not Game.locker_put(index):
		Sound.play("sfx_error")
		Game.notice.emit("ARMARIO LLENO: SUBE EL ARMARIO", Palette.RUST_L)
		return


## Pulsar un objeto expuesto lo devuelve al inventario: exponer no puede ser una
## decision sin vuelta atras (el objeto no vale para otra cosa mientras esta ahi).
func _take(index: int) -> void:
	if index >= Game.locker.size():
		return
	Sound.click()
	if not Game.locker_take(index):
		Sound.play("sfx_error")
		Game.notice.emit("INVENTARIO LLENO", Palette.RUST_L)


func _sell_all() -> void:
	var total := Game.inventory_value()
	if total <= 0:
		Sound.play("sfx_error")
		Game.notice.emit("NO HAY NADA QUE VENDER", Palette.CREAM_D)
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
