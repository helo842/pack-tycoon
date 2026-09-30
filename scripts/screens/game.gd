# Game - la pantalla de juego.
#
# Aqui esta el bucle entero:
#   1. se compra un paquete en la tienda y cae en la mesa
#   2. se le hace clic y se espera (las herramientas acortan la espera)
#   3. sale la tarjeta de revelado
#   4. el objeto cae en la mesa y se vende
#
# La mesa tiene tope de 8 elementos, que es el "limite maximo de elementos
# simultaneos" del Idea.pdf. Cuando esta llena no se puede comprar mas.
extends Control

const SHOP_SCENE := preload("res://scenes/ShopPanel.tscn")
const REVEAL_SCENE := preload("res://scenes/RevealCard.tscn")
const SETTINGS_SCENE := preload("res://scenes/SettingsPanel.tscn")

const MAX_ELEMENTS := 8
const INV_X0 := 660.0
const INV_STEP := 132.0
const INV_Y := 1000.0
const INV_SIDE := 128.0

## La mesa: donde caen los objetos. Es el rectangulo ENTERO de la superficie
## (el mismo que ocupa el sprite bg_table), y de ahi para dentro se recorta
## todo: el sitio donde nace un objeto, hasta donde se puede arrastrar y por
## donde se pasea. 1824 y 752 son multiplos de 8, que es lo que mide un pixel de
## arte de la mesa, para que el sprite no se deforme al dibujarlo.
const TABLE_RECT := Rect2(48, 140, 1824, 752)

## Cuantos puntos al azar se prueban para colocar un objeto nuevo. Ver _free_spot().
const SPOT_TRIES := 40

const AUTO_BUY_EVERY := 0.65
const AUTO_OPEN_EVERY := 0.35

var _table: Control
var _fx: Control
var _money: PixelNumber
var _table_label: Label
var _speed_label: Label
var _inv_label: Label
var _inv_slots: Array = []
var _elements: Array = []
var _shop: ShopPanel = null
var _settings: SettingsPanel = null
var _reveal: RevealCard = null
var _auto_open_btn: Button = null
var _auto_buy_btn: Button = null
var _sell_btn: Button = null
var _rng := RandomNumberGenerator.new()

var _buy_timer := 0.0
var _open_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	add_child(UIKit.image("bg_menu_backroom", Vector2(960, 540), Vector2(1920, 1080)))

	# El orden de add_child es el orden de capas: primero lo que va detras.
	_build_table_area()

	_table = Control.new()
	_table.name = "Table"
	_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_table)

	_fx = Control.new()
	_fx.name = "Fx"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	_build_top_bar()
	_build_inventory()

	Game.money_changed.connect(_on_money_changed)
	Game.inventory_changed.connect(_refresh_inventory)
	Game.tools_changed.connect(_refresh_top)
	Game.settings_changed.connect(_refresh_top)
	_refresh_inventory()
	_refresh_top()
	_on_money_changed(Game.money)


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

func _build_table_area() -> void:
	# La mesa. Antes esto era una franja oscura con ocho ranuras fijas en
	# rejilla, y los objetos caian siempre en las mismas casillas. Ahora es una
	# superficie (sprite generado con tools/make_background.py --table) y los
	# objetos caen donde quieren y se pueden mover.
	add_child(UIKit.image("bg_table", TABLE_RECT.get_center(), TABLE_RECT.size))

	var line := ColorRect.new()
	line.color = Color(Palette.GOLD_D, 0.55)
	line.position = Vector2(40, 900)
	line.size = Vector2(1840, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)


func _build_top_bar() -> void:
	# Franja oscura detras: sin ella el dinero y los botones se leen encima de
	# las baldas del fondo y no se distinguen bien.
	var bar := ColorRect.new()
	bar.color = Color(0.02, 0.015, 0.04, 0.66)
	bar.size = Vector2(1920, 112)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var line := ColorRect.new()
	line.color = Color(Palette.GOLD_D, 0.7)
	line.position = Vector2(0, 112)
	line.size = Vector2(1920, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	add_child(UIKit.square("currency_coin", Vector2(74, 58), 0.17))
	_money = PixelNumber.new()
	_money.scale_factor = 0.48
	_money.max_width = 470.0
	add_child(_money)
	_money.set_number(Game.money)
	# El contador se ancla por su IZQUIERDA, no por su centro: si no, cuando el
	# numero crece se sale por la pantalla en vez de empujar lo de al lado.
	_money.position = Vector2(128, 58 - _money.size.y * 0.5)	# Las cajas van anchas a proposito: label_at agranda la caja si el texto no
	# cabe y la centra, asi que una caja corta ("MESA 3/8" son 224 px en una de
	# 190) deslocaba el texto a la izquierda y lo pegaba al contador.
	_table_label = UIKit.label_at("", Vector2(690, 58), Vector2(250, 50), 28,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0)
	add_child(_table_label)
	_speed_label = UIKit.label_at("", Vector2(910, 58), Vector2(150, 50), 28,
		Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0)
	add_child(_speed_label)

	_auto_open_btn = UIKit.icon_button("ui_icon_auto_open", Vector2(1050, 58), 80.0,
			"Apertura automatica: abre sola los paquetes de la mesa")
	_auto_open_btn.pressed.connect(_toggle_auto_open)
	add_child(_auto_open_btn)

	_auto_buy_btn = UIKit.icon_button("ui_icon_auto_buy", Vector2(1145, 58), 80.0,
			"Compra automatica: compra el paquete mas barato que puedas pagar")
	_auto_buy_btn.pressed.connect(_toggle_auto_buy)
	add_child(_auto_buy_btn)

	_sell_btn = UIKit.small_button("VENDER", "", Vector2(1350, 58), 240, 21,
			"ui_button_sell", "ui_button_sell")
	_sell_btn.pressed.connect(_sell_all_table)
	add_child(_sell_btn)

	var shop := UIKit.small_button("TIENDA", "ui_icon_shop", Vector2(1630, 58), 288, 32)
	shop.pressed.connect(_open_shop)
	add_child(shop)

	var settings := UIKit.icon_button("ui_icon_settings", Vector2(1856, 58), 80.0,
			"Ajustes")
	settings.pressed.connect(_open_settings)
	add_child(settings)


func _build_inventory() -> void:
	var sell_all := UIKit.small_button("VENDER TODO", "", Vector2(210, INV_Y), 384, 28,
		"ui_button_sell", "ui_button_sell")
	sell_all.pressed.connect(_sell_inventory)
	add_child(sell_all)

	# El rotulo va sobre su fila de huecos, no encima de la chapa de VENDER TODO.
	# Con el centro en (470, 928) la caja empezaba en x 270 y la chapa llega a
	# x 402: el texto se leia a la mitad, cortado por el marco de la chapa.
	# Y a y 918, no a 912: la linea de las baldas pasa por y 900..903 y a 912 la
	# cruzaba por arriba de las letras. Entre la linea (903) y los huecos (936)
	# quedan 33 px, y el rotulo mide 24.
	_inv_label = UIKit.label_at("", Vector2(800, 918), Vector2(400, 44), 26,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0)
	add_child(_inv_label)

	for i in Game.INVENTORY_SLOTS:
		var holder := UIKit.slot(Vector2(INV_X0 + float(i) * INV_STEP, INV_Y), INV_SIDE)
		add_child(holder)
		_inv_slots.append(holder)


# --------------------------------------------------------------------------- #
# La mesa
# --------------------------------------------------------------------------- #

## Un sitio libre para un objeto nuevo, dentro de la mesa.
##
## Se prueban SPOT_TRIES puntos al azar y se elige el que menos pisa a los que
## ya hay. Con eso salen repartidos solos y solo se solapan cuando de verdad no
## cabe otro, que es cuando el jugador los separa arrastrando: para eso se
## pueden mover. Sorteando a pelo, con ocho objetos de 300x340 en una mesa de
## 1824x752 la mitad caerian uno encima de otro desde el primer minuto.
func _free_spot() -> Vector2:
	var x0 := TABLE_RECT.position.x
	var y0 := TABLE_RECT.position.y
	var x1 := x0 + TABLE_RECT.size.x - TableElement.BOX.x
	var y1 := y0 + TABLE_RECT.size.y - TableElement.BOX.y
	var best := Vector2(x0, y0)
	var best_score := -1.0
	for i in SPOT_TRIES:
		var p := Vector2(_rng.randf_range(x0, x1), _rng.randf_range(y0, y1))
		var mine := Rect2(p, TableElement.BOX)
		var score := 0.0
		for el in _elements:
			if is_instance_valid(el):
				score += _overlap(mine, Rect2(el.position, TableElement.BOX))
		if best_score < 0.0 or score < best_score:
			best_score = score
			best = p
		if score <= 0.0:
			break
	return best


static func _overlap(a: Rect2, b: Rect2) -> float:
	var i := a.intersection(b)
	return maxf(0.0, i.size.x) * maxf(0.0, i.size.y)


## Un punto al azar de la mesa, para los avisos flotantes.
func _table_point() -> Vector2:
	return TABLE_RECT.position + Vector2(
			_rng.randf_range(80.0, TABLE_RECT.size.x - 80.0),
			_rng.randf_range(80.0, TABLE_RECT.size.y - 80.0))


func table_count() -> int:
	return _elements.size()


func table_free() -> bool:
	return _elements.size() < MAX_ELEMENTS


func _add_element(el: TableElement) -> void:
	# El sitio se busca ANTES de meterlo en la lista: _free_spot() mira donde
	# estan los demas, y el que se esta colocando todavia no esta.
	var rest := _free_spot()
	_elements.append(el)
	el.bounds = TABLE_RECT
	el.opened.connect(_on_element_opened.bind(el))
	el.sold.connect(_on_element_sold.bind(el))
	_table.add_child(el)
	# La caida la lleva el elemento: asi se puede cortar si el jugador lo agarra
	# antes de que aterrice. Ver TableElement.play_drop().
	el.play_drop(rest)
	_refresh_top()


func _drop_element(el: TableElement) -> void:
	_elements.erase(el)
	_refresh_top()


func _spawn_pack(pack_id: String) -> TableElement:
	var el := TableElement.new()
	el.setup_pack(LootDB.pack_by_id(pack_id))
	_add_element(el)
	return el


## Crea el botin en la mesa y DEVUELVE el elemento: quien lo pide lo necesita
## para poder venderlo o quitarlo despues (la tarjeta de revelado, sin ir mas
## lejos, decide sobre el objeto que ya esta puesto).
func _spawn_loot(item: Dictionary) -> TableElement:
	var el := TableElement.new()
	el.setup_loot(item)
	_add_element(el)
	return el


# --------------------------------------------------------------------------- #
# Bucle: compra, apertura, revelado, venta
# --------------------------------------------------------------------------- #

func _open_shop() -> void:
	if _shop != null:
		return
	Sound.click()
	_shop = SHOP_SCENE.instantiate() as ShopPanel
	_shop.pack_chosen.connect(_on_pack_chosen)
	_shop.closed.connect(_close_shop)
	_main().push_veil(_shop)


func _close_shop() -> void:
	Sound.click()
	if _shop != null:
		_main().pop_veil(_shop)
		_shop = null


func _on_pack_chosen(pack_id: String) -> void:
	if table_free():
		# El sonido de compra lo pone la tienda, que es quien ha cobrado.
		_spawn_pack(pack_id)
		return
	# La tienda ya ha cobrado: si la mesa estaba llena se devuelve el dinero.
	var price := int(LootDB.pack_by_id(pack_id)["price"])
	Game.add_money(price)
	Sound.play("sfx_error")
	Game.notice.emit("MESA LLENA: TE DEVUELVEN " + PixelNumber.format(price),
			Palette.RUST_L)


func _on_element_opened(pack_id: String, el: TableElement) -> void:
	_drop_element(el)
	Game.packs_opened += 1
	var item := LootDB.roll_pack(_rng, pack_id)
	# Encontrado es una cosa y guardado es otra: se apunta aqui, cuando sale,
	# porque a partir de este punto puede venderse sin pasar por el inventario.
	Game.register_found(item)
	if Game.auto_sell:
		_sell_quietly(item)
		return
	_reveal_item(item)


## Venta automatica: el objeto se vende nada mas salir, sin tarjeta y sin mesa.
func _sell_quietly(item: Dictionary) -> void:
	var value := int(item.get("value", 0))
	Game.add_money(value)
	Sound.play("sfx_sell")
	_float_text("+" + PixelNumber.format(value), _table_point(), Palette.GOLD_XL)


func _reveal_item(item: Dictionary) -> void:
	# Primero el sonido de que se ha abierto, y ENCIMA el del premio si toca:
	# en ese orden se entiende "algo ha salido" y luego "y es bueno".
	Sound.play("sfx_open")
	var rarity_id := str(item.get("rarity", "common"))
	if rarity_id == "epic" or rarity_id == "legendary":
		Sound.play("sfx_rare")

	# El objeto cae en la mesa ANTES de la tarjeta, asi que cuando se cierra ya
	# esta puesto, en su sitio, y se puede mover y vender como cualquier otro.
	# Y NO se guarda solo en el inventario: eso lo decide el boton GUARDAR o
	# VENDER. Antes se hacia las dos cosas y el objeto acababa duplicado, en la
	# mesa y en el inventario a la vez.
	var el: TableElement = null
	if table_free():
		el = _spawn_loot(item)

	var card := REVEAL_SCENE.instantiate() as RevealCard
	card.show_item(item)
	card.resolved.connect(_on_reveal_resolved.bind(item, el))
	_reveal = card
	_main().push_overlay(card)


## Que hacer con el objeto cuando se cierra la tarjeta.
func _on_reveal_resolved(action: String, item: Dictionary, el: TableElement) -> void:
	if _reveal != null:
		_main().pop_overlay(_reveal)
		_reveal = null
	if action == RevealCard.ACTION_STORE:
		_store_revealed(item, el)
	elif action == RevealCard.ACTION_SELL:
		_sell_revealed(item, el)
	elif el == null:
		# Cerrada sin elegir y sin sitio en la mesa: se guarda, que es lo unico
		# que no pierde el objeto. Con sitio, se queda en la mesa y ya esta.
		_store_revealed(item, null)


## Al inventario. El objeto DEJA la mesa: no puede estar en los dos sitios.
func _store_revealed(item: Dictionary, el: TableElement) -> void:
	var stored := Game.store(item)
	_remove_from_table(el)
	# store() ya vende y avisa solo cuando el inventario esta lleno; el sonido lo
	# pone aqui para que se oiga igual que las demas ventas.
	Sound.play("sfx_click" if stored else "sfx_sell")


func _sell_revealed(item: Dictionary, el: TableElement) -> void:
	var value := int(item.get("value", 0))
	var at := TABLE_RECT.get_center()
	if el != null and is_instance_valid(el):
		at = el.global_position + el.size * 0.5
		# sell_instant() coge el valor del elemento y lo borra, pero no ingresa
		# nada: el dinero lo lleva siempre _sell_revealed.
		value = el.sell_instant()
		_drop_element(el)
	Game.add_money(value)
	Sound.play("sfx_sell")
	_float_text("+" + PixelNumber.format(value), at, Palette.GOLD_XL)
	_refresh_top()


func _remove_from_table(el: TableElement) -> void:
	if el == null or not is_instance_valid(el):
		return
	_drop_element(el)
	el.queue_free()
	_refresh_top()


func _on_element_sold(value: int, at: Vector2, el: TableElement) -> void:
	_drop_element(el)
	Game.add_money(value)
	Sound.play("sfx_sell")
	_float_text("+" + PixelNumber.format(value), at, Palette.GOLD_XL)


func _sell_all_table() -> void:
	var total := 0
	for el in _elements:
		if is_instance_valid(el):
			total += el.sell_instant()
	_elements.clear()
	if total > 0:
		Game.add_money(total)
		Sound.play("sfx_sell_all")
		_float_text("+" + PixelNumber.format(total), Vector2(960, 500), Palette.GOLD_XL)
	_refresh_top()


func _sell_inventory() -> void:
	var total := Game.inventory_value()
	if total <= 0:
		Sound.play("sfx_error")
		Game.notice.emit("NO HAY NADA QUE VENDER", Palette.CREAM_D)
		return
	Game.sell_all()
	Sound.play("sfx_sell_all")
	_float_text("+" + PixelNumber.format(total), Vector2(960, 960), Palette.GOLD_XL)


# --------------------------------------------------------------------------- #
# Automatizaciones
# --------------------------------------------------------------------------- #

func _process(delta: float) -> void:
	if _reveal != null:
		return
	if Game.auto_buy:
		_buy_timer -= delta
		if _buy_timer <= 0.0:
			_buy_timer = AUTO_BUY_EVERY
			_auto_buy_step()
	if Game.auto_open:
		_open_timer -= delta
		if _open_timer <= 0.0:
			_open_timer = AUTO_OPEN_EVERY
			_auto_open_step()


func _auto_buy_step() -> void:
	if not table_free() or _shop != null:
		return
	var best := ""
	var best_price := 1 << 60
	for i in LootDB.pack_count():
		var p: Dictionary = LootDB.pack_at(i)
		var price := int(p["price"])
		if price <= Game.money and price < best_price:
			best_price = price
			best = str(p["id"])
	if best == "":
		return
	Game.spend(best_price)
	_spawn_pack(best)


func _auto_open_step() -> void:
	for el in _elements:
		if is_instance_valid(el) and el.is_waiting_pack():
			el.start_opening()
			return


func _toggle_auto_open() -> void:
	Sound.play("sfx_toggle")
	Game.set_auto_open(not Game.auto_open)
	_refresh_top()
	Game.notice.emit("AUTO APERTURA: " + ("SI" if Game.auto_open else "NO"),
			Palette.CREAM_D)


func _toggle_auto_buy() -> void:
	Sound.play("sfx_toggle")
	Game.set_auto_buy(not Game.auto_buy)
	_refresh_top()
	Game.notice.emit("AUTO COMPRA: " + ("SI" if Game.auto_buy else "NO"),
			Palette.CREAM_D)


# --------------------------------------------------------------------------- #
# Refresco de la interfaz
# --------------------------------------------------------------------------- #

func _on_money_changed(value: int) -> void:
	if is_instance_valid(_money):
		_money.set_number(value)


func _refresh_top() -> void:
	if is_instance_valid(_table_label):
		_table_label.text = "MESA %d/%d" % [table_count(), MAX_ELEMENTS]
	if is_instance_valid(_speed_label):
		# "X" y no "x": la fuente del juego solo tiene mayusculas, y una minuscula
		# sale como un cajon vacio al lado del numero.
		_speed_label.text = "X" + _trim(Game.speed_multiplier())
	if is_instance_valid(_auto_open_btn):
		UIKit.set_icon_button_lit(_auto_open_btn, Game.auto_open)
	if is_instance_valid(_auto_buy_btn):
		UIKit.set_icon_button_lit(_auto_buy_btn, Game.auto_buy)
	if is_instance_valid(_sell_btn):
		_sell_btn.disabled = _count_table_loot() == 0


func _refresh_inventory() -> void:
	if is_instance_valid(_inv_label):
		_inv_label.text = "INVENTARIO %d/%d" % [Game.inventory.size(), Game.INVENTORY_SLOTS]
	for i in _inv_slots.size():
		var holder: Control = _inv_slots[i]
		for c in holder.get_children():
			if c.name != "Back":
				c.queue_free()
		if i >= Game.inventory.size():
			continue
		var item: Dictionary = Game.inventory[i]
		holder.add_child(UIKit.square(str(item.get("art", "loot_vinyl")),
				Vector2(INV_SIDE * 0.5, INV_SIDE * 0.5 - 8.0), 0.16))
		var num := PixelNumber.new()
		num.scale_factor = 0.15
		num.max_width = INV_SIDE - 12.0
		holder.add_child(num)
		num.set_number(int(item.get("value", 0)))
		num.position = Vector2(INV_SIDE * 0.5, INV_SIDE - 26.0) - num.size * 0.5
		var value := int(item.get("value", 0))
		UIKit.hit_area(holder, Rect2(Vector2.ZERO, Vector2(INV_SIDE, INV_SIDE)),
				"Vender por " + PixelNumber.format(value)).pressed.connect(
				_sell_inventory_slot.bind(i))


func _sell_inventory_slot(index: int) -> void:
	var got := Game.sell_at(index)
	if got > 0:
		Sound.play("sfx_sell")
		_float_text("+" + PixelNumber.format(got), Vector2(960, 960), Palette.GOLD_XL)


func _count_table_loot() -> int:
	var n := 0
	for el in _elements:
		if is_instance_valid(el) and el.is_loot():
			n += 1
	return n


# --------------------------------------------------------------------------- #
# Detalles de pantalla
# --------------------------------------------------------------------------- #

func _float_text(text: String, at: Vector2, color: Color) -> void:
	var num := PixelNumber.new()
	num.scale_factor = 0.5
	num.set_text(text)
	num.color = color
	_fx.add_child(num)
	num.position = at - num.size * 0.5
	var rise := num.position.y - 90.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(num, "position:y", rise, 0.9).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(num, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(num.queue_free)


func _open_settings() -> void:
	if _settings != null:
		return
	Sound.click()
	_settings = SETTINGS_SCENE.instantiate() as SettingsPanel
	_settings.closed.connect(_on_settings_closed)
	_main().push_veil(_settings)


func _on_settings_closed() -> void:
	_settings = null


func _main() -> MainRoot:
	return MainRoot.get_root()


## "2.10" -> "2.1"
static func _trim(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _reveal != null:
		return
	if _settings != null:
		_main().pop_veil(_settings)
		_settings = null
	elif _shop != null:
		_close_shop()
	else:
		Game.save_game()
		_main().show_menu()
	get_viewport().set_input_as_handled()
