# Game - el estado del juego. Es un autoload (ver project.godot), asi que vive
# durante toda la sesion y no depende de que pantalla este puesta.
#
# Guarda en user://packtycoon.json. Se guarda al salir y cada 30 segundos si ha
# cambiado algo, no en cada venta: escribir el fichero en cada operacion ralentiza
# el juego en cuanto se tienen 200 objetos.
extends Node

signal money_changed(value: int)
signal inventory_changed()
signal items_changed()
## Un paquete ha pedido abrirse (el jugador le ha hecho clic). Lo escucha game.gd,
## que es quien sabe cuantos paquetes se pueden llevar a la vez (los Guantes).
signal open_requested(element: Object)
signal settings_changed()
## Aviso corto para la parte de arriba de la pantalla.
signal notice(text: String, color: Color)

const SAVE_PATH := "user://packtycoon.json"
const AUTOSAVE_EVERY := 30.0
const START_MONEY := 500
const INVENTORY_SLOTS := 10

var money: int = START_MONEY
var rebirth_coins: int = 0

# Inventario y estadisticas. "items_found" y "packs_opened" son para logros,
# que todavia no estan.
var inventory: Array = []
## Nivel comprado de cada item de la tienda (ITEMS SHOP del PDF). El indice del
## array es el de LootDB.ITEMS. Los seis de estadisticas suben hasta ocho; el PC
## y los Pinchos son de compra unica (nivel 1 y ya). Ver LootDB.item_max_level().
var items: Array = [0, 0, 0, 0, 0, 0, 0, 0]

var auto_open: bool = false
var auto_buy: bool = false
## Que sobres puede comprar la compra automatica: los ids que el jugador ha
## marcado en su mini menu (ver AutoBuyPanel). Con todos marcados -que es como
## empieza- se comporta como siempre: el mas barato de los doce que pueda pagar.
## Con ninguno marcado no compra nada, que es una forma legitima de apagarla
## sin apagar el boton.
var auto_buy_packs: Array = []
## Vende solo, al instante. No es una automatizacion mas del arbol de
## herramientas: es una forma de jugar (abrir cajas sin pararse en nada), asi
## que vive en los ajustes y no en la barra de la partida.
var auto_sell: bool = false
var music_volume: float = 0.7
var sfx_volume: float = 0.45
var fullscreen: bool = false

var lifetime_earned: int = 0
var packs_opened: int = 0
var items_found: int = 0
var best_grade: int = 0

var _dirty := false
var _autosave_left := AUTOSAVE_EVERY


func _ready() -> void:
	# Los items empiezan todos a 0; se rellenan desde el guardado.
	while items.size() < LootDB.item_count():
		items.append(0)
	# La lista de la compra automatica se rellena ANTES de leer el guardado: un
	# guardado que no la traiga (los de antes de este menu) se queda con todos
	# los sobres, que es el comportamiento de siempre.
	auto_buy_packs = _all_pack_ids()
	# El cierre lo lleva este nodo y no el motor, para poder meter medio frame
	# de margen antes de salir (ver _on_close). Sin esto, el motor cierra de
	# golpe en cuanto llega el aviso de la ventana.
	get_tree().auto_accept_quit = false
	load_game()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_EVERY
		if _dirty:
			save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_close()


## Cerrar el juego: guardar, callar y salir.
##
## Los tres pasos van en este orden y con medio frame entre el ultimo y el
## quit() a proposito. Al parar una voz, la que suelta el WAV es el hilo de
## audio, que mezcla por su cuenta: si se sale en el mismo frame, el motor avisa
## de "resources still in use at exit" y de instancias perdidas. Y como la
## musica es un bucle infinito, eso pasaba SIEMPRE al cerrar, no a veces.
func _on_close() -> void:
	save_game()
	Sound.stop_all()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


# --------------------------------------------------------------------------- #
# Dinero
# --------------------------------------------------------------------------- #

func can_afford(amount: int) -> bool:
	return money >= amount


func add_money(amount: int) -> void:
	if amount == 0:
		return
	money = maxi(0, money + amount)
	if amount > 0:
		lifetime_earned += amount
	_dirty = true
	money_changed.emit(money)


func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	_dirty = true
	money_changed.emit(money)
	return true


# --------------------------------------------------------------------------- #
# Precio de los sobres
# --------------------------------------------------------------------------- #
#
# El precio vive en loot_db (SOBRES vale 0, y por eso es gratis en cualquier
# momento de la partida). Pasa por aqui para que la columna de sobres y la
# compra automatica contesten lo mismo y para que un dia se pueda poner un
# descuento o una oferta en un solo sitio.

## Lo que cuesta un sobre.
func pack_price(pack_id: String) -> int:
	return int(LootDB.pack_by_id(pack_id)["price"])


## ¿El sobre es gratuito? Los gratuitos se anuncian con GRATIS en la columna en
## vez de con su precio.
func pack_free(pack_id: String) -> bool:
	return pack_price(pack_id) <= 0


## Todos los ids de sobre, que es el estado de partida de la lista de la compra
## automatica.
func _all_pack_ids() -> Array:
	var ids: Array = []
	for i in LootDB.pack_count():
		ids.append(str(LootDB.pack_at(i)["id"]))
	return ids


## ¿Tiene el jugador esta pieza comprada?
func has_item(item_id: String) -> bool:
	return LootDB.item_level(items, item_id) > 0


## ¿Se puede encender la apertura automatica? Su pieza son los Pinchos.
func auto_open_unlocked() -> bool:
	return LootDB.auto_open_unlocked(items)


## ¿Se puede encender la compra automatica? Su pieza es el PC.
func auto_buy_unlocked() -> bool:
	return LootDB.auto_buy_unlocked(items)


## ¿Esta este sobre en la lista de la compra automatica?
func auto_buy_wants(pack_id: String) -> bool:
	return auto_buy_packs.has(pack_id)


## Marca o desmarca un sobre en la lista de la compra automatica.
func set_auto_buy_wanted(pack_id: String, on: bool) -> void:
	if on == auto_buy_wants(pack_id):
		return
	if on:
		auto_buy_packs.append(pack_id)
	else:
		auto_buy_packs.erase(pack_id)
	_dirty = true
	settings_changed.emit()


# --------------------------------------------------------------------------- #
# Inventario
# --------------------------------------------------------------------------- #

func inventory_free() -> bool:
	return inventory.size() < INVENTORY_SLOTS


## Mete un objeto del revelado. Si no cabe, se vende al instante y se avisa:
## en esta version el inventario son 10 huecos y no hay forma de ampliarlos.
func store(item: Dictionary) -> bool:
	if not inventory_free():
		add_money(int(item["value"]))
		notice.emit("INVENTARIO LLENO: VENDIDO", Palette.GOLD)
		return false
	inventory.append(item.duplicate(true))
	_dirty = true
	inventory_changed.emit()
	return true


## Apunta que ha salido un objeto, sin decidir todavia que se hace con el.
##
## Va aparte de store() a proposito: desde que un objeto puede venderse en la
## mesa o desde la tarjeta, guardarlo o venderlo ya no es lo mismo que
## encontrarlo. Si se contara dentro de store(), un objeto vendido no contaria
## como encontrado y las estadisticas mentirian.
func register_found(item: Dictionary) -> void:
	items_found += 1
	best_grade = maxi(best_grade, int(item.get("grade", 0)))
	_dirty = true


## Vende por indice. Devuelve cuanto se ha sacado (0 si no habia nada).
func sell_at(index: int) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var item: Dictionary = inventory[index]
	inventory.remove_at(index)
	var value := int(item["value"])
	add_money(value)
	_dirty = true
	inventory_changed.emit()
	return value


func sell_all() -> int:
	var total := 0
	for item in inventory:
		total += int(item["value"])
	inventory.clear()
	if total > 0:
		add_money(total)
	_dirty = true
	inventory_changed.emit()
	return total


func inventory_value() -> int:
	var total := 0
	for item in inventory:
		total += int(item["value"])
	return total


# --------------------------------------------------------------------------- #
# Items de la tienda
# --------------------------------------------------------------------------- #

func item_level(index: int) -> int:
	if index < 0 or index >= items.size():
		return 0
	return int(items[index])


func item_cost(index: int) -> int:
	return LootDB.item_cost(index, item_level(index))


## Niveles que puede llegar a tener un item: 8 en los seis de estadisticas y 1
## en el PC y los Pinchos. Lo mira la tienda para saber si una fila lleva puntos
## de nivel o un COMPRADO.
func item_max_level(index: int) -> int:
	return LootDB.item_max_level(index)


## Sube un nivel de un item (o lo compra, si es de compra unica). Devuelve false
## si no hay nada que comprar: ya lo tiene al tope, o no le llega el dinero.
func buy_item(index: int) -> bool:
	var cost := item_cost(index)
	if cost < 0 or not spend(cost):
		return false
	items[index] = item_level(index) + 1
	_dirty = true
	items_changed.emit()
	return true


# --------------------------------------------------------------------------- #
# Apertura de paquetes: vida, dano y estadisticas de los items
# --------------------------------------------------------------------------- #

## Dano de cada golpe al cargar el boton.
func damage_per_hit() -> float:
	return LootDB.damage_per_hit(items)


## Segundos que tarda un ciclo de carga.
func charge_time() -> float:
	return LootDB.charge_time(items)


func crit_chance() -> float:
	return LootDB.crit_chance(items)


func crit_mult() -> float:
	return LootDB.crit_mult(items)


func luck() -> float:
	return LootDB.luck(items)


func open_count() -> int:
	return LootDB.open_count(items)


func table_slots() -> int:
	return LootDB.table_slots(items)


func auto_buy_interval() -> float:
	return LootDB.auto_buy_interval(items)


func spike_dps() -> float:
	return LootDB.spike_dps(items)


## Armario: expone automaticamente los mejores objetos del inventario (hasta
## locker_slots) y cada uno aporta un extra de valor segun su rareza. Se cogen
## los mejores solos para no meter un panel nuevo: el efecto es el mismo (hasta
## tres objetos dando stats por su calidad).
func locker_bonus() -> float:
	var slots := LootDB.locker_slots(items)
	if slots <= 0:
		return 0.0
	var bonuses: Array = []
	for item in inventory:
		bonuses.append(LootDB.locker_item_bonus(str(item.get("rarity", "common"))))
	bonuses.sort()
	bonuses.reverse()
	var total := 0.0
	for i in mini(slots, bonuses.size()):
		total += float(bonuses[i])
	return total


## Multiplicador de valor de los objetos nuevos (Armario).
func value_multiplier() -> float:
	return 1.0 + locker_bonus()


## Un paquete pide abrirse. game.gd decide cuantos mas arranca a la vez.
func request_open(element: Object) -> void:
	open_requested.emit(element)


# --------------------------------------------------------------------------- #
# Ajustes
# --------------------------------------------------------------------------- #

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_dirty = true
	settings_changed.emit()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_dirty = true
	settings_changed.emit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_dirty = true
	settings_changed.emit()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if on
		else DisplayServer.WINDOW_MODE_WINDOWED)


## Enciende o apaga la apertura automatica (los Pinchos). Devuelve false si no
## se ha podido encender, que solo pasa por una cosa: no tener los Pinchos. Quien
## llama es quien avisa al jugador de que le falta (ver game.gd, _locked_notice()).
##
## La regla vive aqui y no en el boton para que valga tambien viniendo de un
## guardado, de los tests o de donde sea: un boton puede saltarse una comprobacion
## que se haga solo al pulsarlo, esto no.
func set_auto_open(on: bool) -> bool:
	if on and not auto_open_unlocked():
		return false
	auto_open = on
	_dirty = true
	settings_changed.emit()
	return true


## Igual que set_auto_open(), pero con SU pieza: comprar solo necesita el PC, y
## no los Pinchos. Antes pedia las dos y eso se quito: tener el PC y que el boton
## siguiera apagado por los Pinchos hacia que la compra pareciera no servir.
func set_auto_buy(on: bool) -> bool:
	if on and not auto_buy_unlocked():
		return false
	auto_buy = on
	_dirty = true
	settings_changed.emit()
	return true


func set_auto_sell(on: bool) -> void:
	auto_sell = on
	_dirty = true
	settings_changed.emit()


# --------------------------------------------------------------------------- #
# Guardado
# --------------------------------------------------------------------------- #

## Vuelve al estado inicial y borra el guardado. Lo usan las pruebas de humo y
## las capturas; de momento no hay boton de "empezar de cero" en el juego.
func hard_reset() -> void:
	money = START_MONEY
	rebirth_coins = 0
	inventory = []
	items = []
	while items.size() < LootDB.item_count():
		items.append(0)
	auto_open = false
	auto_buy = false
	auto_buy_packs = _all_pack_ids()
	auto_sell = false
	music_volume = 0.7
	sfx_volume = 0.45
	fullscreen = false
	lifetime_earned = 0
	packs_opened = 0
	items_found = 0
	best_grade = 0
	_dirty = true
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	money_changed.emit(money)
	inventory_changed.emit()
	items_changed.emit()
	settings_changed.emit()


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"money": money,
		"rebirth_coins": rebirth_coins,
		"inventory": inventory,
		"items": items,
		"auto_open": auto_open,
		"auto_buy": auto_buy,
		"auto_buy_packs": auto_buy_packs,
		"auto_sell": auto_sell,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"lifetime_earned": lifetime_earned,
		"packs_opened": packs_opened,
		"items_found": items_found,
		"best_grade": best_grade,
	}


func save_game() -> void:
	_dirty = false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo guardar en %s: %s" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Guardado ilegible; se empieza de cero.")
		return
	_apply(parsed)


func _apply(d: Dictionary) -> void:
	money = int(d.get("money", START_MONEY))
	rebirth_coins = int(d.get("rebirth_coins", 0))
	inventory = d.get("inventory", [])
	if typeof(inventory) != TYPE_ARRAY:
		inventory = []
	# Acepta el guardado viejo, que llamaba "tools" a lo mismo.
	items = d.get("items", d.get("tools", []))
	if typeof(items) != TYPE_ARRAY:
		items = []
	while items.size() < LootDB.item_count():
		items.append(0)
	# Y se recortan al tope de cada uno: un guardado puede traer un nivel de mas
	# si los maximos cambian (el PC y los Pinchos son de compra unica y su tope es
	# 1, asi que un 8 guardado de antes se queda en 1).
	for i in items.size():
		items[i] = clampi(int(items[i]), 0, LootDB.item_max_level(i))
	auto_open = bool(d.get("auto_open", false))
	auto_buy = bool(d.get("auto_buy", false))
	# La lista de sobres de la compra automatica, limpia contra los sobres que
	# hay de verdad: un guardado viejo puede traer ids de sobres que ya no
	# existen, y no se nota hasta que la compra automatica se queda quieta.
	var guardados = d.get("auto_buy_packs", null)
	if typeof(guardados) == TYPE_ARRAY:
		auto_buy_packs = []
		for i in LootDB.pack_count():
			var pack_id := str(LootDB.pack_at(i)["id"])
			if (guardados as Array).has(pack_id):
				auto_buy_packs.append(pack_id)
	else:
		auto_buy_packs = _all_pack_ids()
	auto_sell = bool(d.get("auto_sell", false))
	music_volume = float(d.get("music_volume", 0.7))
	sfx_volume = float(d.get("sfx_volume", 0.45))
	fullscreen = bool(d.get("fullscreen", false))
	lifetime_earned = int(d.get("lifetime_earned", 0))
	packs_opened = int(d.get("packs_opened", 0))
	items_found = int(d.get("items_found", 0))
	best_grade = int(d.get("best_grade", 0))
	# Y cada automatizacion se cae si no esta SU pieza: un guardado que venga con
	# ellas encendidas y sin Pinchos o sin PC (de una version anterior, o de haber
	# tocado el fichero) no puede dejar la mesa abriendose o comprando sola.
	if not auto_open_unlocked():
		auto_open = false
	if not auto_buy_unlocked():
		auto_buy = false
	_dirty = false
