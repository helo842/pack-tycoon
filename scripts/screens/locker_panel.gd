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
## La leyenda de los dos gestos (clic izquierdo expone, derecho vende), ENTRE los
## rotulos de las columnas y la rejilla.
##
## No cabe debajo de la ventana del scroll, que es su sitio natural: las 50
## casillas siguen ahi debajo, recortadas por la ventana pero en el arbol, asi que
## cualquier rotulo por debajo de y 760 aterriza encima de los marcos de la fila
## siguiente (medido: la leyenda a 788 pisaba la fila que empieza en 776, y el
## check lo caza). Aqui arriba esta el unico hueco libre de la columna.
const LEGEND_Y := 348.0
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
## Las notas de ayuda, en crema apagado: el gris azulado de antes sobre el marron
## del panel se quedaba sin contraste.
const HINT_COLOR := Palette.CREAM_D

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
		48, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true))

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
		# El clic DERECHO vende ESE objeto y solo ese. Godot no emite `pressed` con
		# el boton derecho (el Button solo escucha el izquierdo), asi que el evento
		# se mira a mano.
		b.gui_input.connect(_on_inv_input.bind(i))
		_inv_cells.append({"holder": holder, "button": b})

	# LOS DOS GESTOS, ESCRITOS. El clic derecho no tiene nada que lo anuncie
	# dentro de la casilla, y un gesto que no se ve es un gesto que no existe:
	# esta linea y el tooltip de cada hueco son lo unico que lo explican.
	add_child(UIKit.label_at("CLIC: EXPONER - CLIC DERECHO: VENDER UNO",
		Vector2(LEFT_MID, LEGEND_Y), Vector2(660, 20), 16, HINT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, 0, true))

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
	# Los porcentajes salen de LootDB y no escritos a mano: este rotulo decia
	# "DEL 2 % AL 15 %" cuando el tope ya era el 25 %. Y es CORTO a proposito: con
	# 53 letras en 660 px encogia hasta 7 px de alto, que no se leia ni de cerca.
	add_child(UIKit.label_at("CADA OBJETO DA DEL %d %% AL %d %% SEGUN SU NOTA" % [
				roundi(LootDB.KIND_BONUS_MIN * 100.0), roundi(LootDB.KIND_BONUS_MAX * 100.0)],
			Vector2(RIGHT_MID, HINT_Y), Vector2(660, 32), 14, HINT_COLOR,
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
			# TREBOL" de la vez anterior es peor que no decir nada.
			b.tooltip_text = ""
			b.disabled = true
			continue
		b.disabled = false
		var item: Dictionary = Game.inventory[i]
		# 8 px por encima del centro y no 6: los dibujos que llenan su lienzo hasta
		# abajo (un vinilo es un disco entero) bajaban 1,5 px por encima del precio
		# de la casilla. Es la misma cuenta que la vitrina de la partida.
		holder.add_child(UIKit.fit_art(str(item.get("art", "loot_vinyl")),
				Vector2(INV_SIDE * 0.5, INV_SIDE * 0.5 - 8.0),
				Vector2(INV_SIDE * 0.6, INV_SIDE * 0.6)))
		_add_value(holder, int(item.get("value", 0)), INV_SIDE)
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
##
## Las cifras iban a 0,13 (9 px de alto en una casilla de 96) y no se leian: es lo
## que dice si un objeto vale la pena exponerlo o venderlo. Ahora van a 0,18 en
## las casillas del inventario y a 0,22 en las del armario, y un poco mas abajo
## para no tocar el dibujo, que acaba a 8 px por encima del centro mas su alto.
func _add_value(holder: Control, value: int, side: float) -> void:
	var num := PixelNumber.new()
	num.scale_factor = 0.18 if side < LOCK_SIDE else 0.22
	num.max_width = side - 10.0
	holder.add_child(num)
	num.set_number(value)
	num.position = Vector2(side * 0.5, side - (18.0 if side < LOCK_SIDE else 22.0)) \
			- num.size * 0.5


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
	Game.notice.emit("VENDIDO: +" + PixelNumber.format(value), Palette.GOLD_XL)


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
