# Game - el estado del juego. Es un autoload (ver project.godot), asi que vive
# durante toda la sesion y no depende de que pantalla este puesta.
#
# Guarda en user://packtycoon.json. Se guarda al salir y cada 30 segundos si ha
# cambiado algo, no en cada venta: escribir el fichero en cada operacion ralentiza
# el juego en cuanto se tienen 200 objetos.
extends Node

signal money_changed(value: int)
signal inventory_changed()
signal tools_changed()
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
var tools: Array = [0, 0, 0, 0]

var auto_open: bool = false
var auto_buy: bool = false
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
	# Las herramientas empiezan todas a 0; se rellenan desde el guardado.
	while tools.size() < LootDB.tool_count():
		tools.append(0)
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
# Herramientas
# --------------------------------------------------------------------------- #

func tool_level(index: int) -> int:
	if index < 0 or index >= tools.size():
		return 0
	return int(tools[index])


func tool_cost(index: int) -> int:
	return LootDB.tool_cost(index, tool_level(index))


func buy_tool(index: int) -> bool:
	var cost := tool_cost(index)
	if cost < 0 or not spend(cost):
		return false
	tools[index] = tool_level(index) + 1
	_dirty = true
	tools_changed.emit()
	return true


func speed_multiplier() -> float:
	return LootDB.speed_multiplier(tools)


func open_time(pack_id: String) -> float:
	return LootDB.open_time(pack_id, tools)


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


func set_auto_open(on: bool) -> void:
	auto_open = on
	_dirty = true
	settings_changed.emit()


func set_auto_buy(on: bool) -> void:
	auto_buy = on
	_dirty = true
	settings_changed.emit()


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
	tools = []
	while tools.size() < LootDB.tool_count():
		tools.append(0)
	auto_open = false
	auto_buy = false
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
	tools_changed.emit()
	settings_changed.emit()


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"money": money,
		"rebirth_coins": rebirth_coins,
		"inventory": inventory,
		"tools": tools,
		"auto_open": auto_open,
		"auto_buy": auto_buy,
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
	tools = d.get("tools", [0, 0, 0, 0])
	if typeof(tools) != TYPE_ARRAY:
		tools = [0, 0, 0, 0]
	while tools.size() < LootDB.tool_count():
		tools.append(0)
	auto_open = bool(d.get("auto_open", false))
	auto_buy = bool(d.get("auto_buy", false))
	auto_sell = bool(d.get("auto_sell", false))
	music_volume = float(d.get("music_volume", 0.7))
	sfx_volume = float(d.get("sfx_volume", 0.45))
	fullscreen = bool(d.get("fullscreen", false))
	lifetime_earned = int(d.get("lifetime_earned", 0))
	packs_opened = int(d.get("packs_opened", 0))
	items_found = int(d.get("items_found", 0))
	best_grade = int(d.get("best_grade", 0))
	_dirty = false
