# Game - el estado del juego. Es un autoload (ver project.godot), asi que vive
# durante toda la sesion y no depende de que pantalla este puesta.
#
# Guarda en user://packtycoon.json. Se guarda al salir y cada 30 segundos si ha
# cambiado algo, no en cada venta: escribir el fichero en cada operacion ralentiza
# el juego en cuanto se tienen 200 objetos.
extends Node

signal money_changed(value: int)
signal inventory_changed()
## El armario ha cambiado: algo ha entrado o ha salido de una vitrina, o se ha
## comprado/subido el propio armario (un nivel mas son huecos nuevos).
signal locker_changed()
signal items_changed()
## El arbol de habilidades ha cambiado: se ha comprado un nivel (o se ha empezado
## de cero). Lo escuchan el panel del arbol y el de la hucha, que son los dos que
## enseñan numeros que dependen de las monedas y de los niveles.
signal skills_changed()
## Un paquete ha pedido abrirse (el jugador le ha hecho clic). Lo escucha game.gd,
## que es quien sabe cuantos paquetes se pueden llevar a la vez (los Guantes).
signal open_requested(element: Object)
signal settings_changed()
## Aviso corto para la parte de arriba de la pantalla.
signal notice(text: String, color: Color)

const SAVE_PATH := "user://packtycoon.json"
const AUTOSAVE_EVERY := 30.0
const START_MONEY := 500
## Huecos del inventario. 50 y no 10 porque el inventario ya no es una tira de
## diez ranuras debajo de la mesa: es la columna de la IZQUIERDA del armario (ver
## LockerPanel), y ahi cabe una rejilla larga con scroll. Ampliarlo de verdad
## (con mejoras) es otra cosa y sigue pendiente.
const INVENTORY_SLOTS := 50

var money: int = START_MONEY
var rebirth_coins: int = 0

# Inventario y estadisticas. "items_found" y "packs_opened" son para logros,
# que todavia no estan.
var inventory: Array = []
## El armario: los objetos EXPUESTOS, uno por hueco (ver LootDB.locker_slots()).
##
## Un objeto expuesto sale del inventario y deja de poder venderse: esta en la
## vitrina. Por eso el armario es un array de objetos y no una lista de indices
## del inventario, que se rompe sola en cuanto se vende algo de en medio. Y por
## eso tambien el armario no guarda nada "automaticamente": lo pone el jugador
## desde su panel (ver LockerPanel), que es lo que le da sentido a los huecos.
var locker: Array = []
## Nivel comprado de cada item de la tienda (ITEMS SHOP del PDF). El indice del
## array es el de LootDB.ITEMS. Los seis de estadisticas suben hasta ocho; el PC
## y los Pinchos son de compra unica (nivel 1 y ya). Ver LootDB.item_max_level().
var items: Array = [0, 0, 0, 0, 0, 0, 0, 0]

## El ARBOL DE HABILIDADES: nivel comprado de cada opcion, por su id (ver
## LootDB.SKILL_BRANCHES). Es un diccionario y no un array por el mismo motivo
## que el armario guarda objetos y no indices: las opciones son un catalogo que
## se puede ampliar, y con un array de posiciones anadir una rama en medio
## moveria todo lo comprado por el jugador.
##
## Lo que NO se gasta aqui: el dinero. El arbol se paga con monedas de rebirth
## (rebirth_coins), que son lo unico que pasa de una partida a la siguiente. Y a
## diferencia de la partida, esto NO se pierde nunca: ni el rebirth ni el
## reinicio lo tocan (ver do_rebirth() y hard_reset()).
var skills: Dictionary = {}

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

## Lo que cuesta un sobre, ya con el descuento del arbol de habilidades dentro.
##
## El descuento vive AQUI y no en los sitios que cobran a proposito: la columna
## de sobres, la compra automatica y el aviso de la mesa preguntan todos por el
## precio, y con la cuenta repartida el dia que se toque el descuento habria tres
## precios distintos en la misma partida sin que nada avisara.
func pack_price(pack_id: String) -> int:
	var base := int(LootDB.pack_by_id(pack_id)["price"])
	# El precio 0 del sobre gratuito tiene que seguir siendo 0 (y multiplicarlo
	# por 0.85 daria 0 igual, pero redondear un 0 es una trampa esperando a que
	# alguien cambie la formula): el gratuito es la red de seguridad del juego.
	if base <= 0:
		return 0
	return maxi(1, int(round(float(base) * LootDB.skill_price_mult(skill_level("barato")))))


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


# --------------------------------------------------------------------------- #
# El arbol de habilidades
# --------------------------------------------------------------------------- #
#
# El estado son ocho contadores (uno por opcion) y el dinero que se gasta son
# las monedas de rebirth. Todo lo que suma el arbol sale de LootDB (que es quien
# tiene las formulas y lo que dice el panel), asi que aqui solo se pregunta por
# el nivel y se aplican los multiplicadores donde toca.

## Nivel comprado de una opcion del arbol. 0 si no existe esa opcion, para que
## un id viejo de un guardado no pueda mejorar nada.
func skill_level(option_id: String) -> int:
	if not LootDB.has_skill(option_id):
		return 0
	return clampi(int(skills.get(option_id, 0)), 0, LootDB.skill_max(option_id))


## Niveles que puede tener una opcion (1 en las de compra unica).
func skill_max_level(option_id: String) -> int:
	return LootDB.skill_max(option_id)


## ¿La opcion esta al tope? Es lo que apaga su casilla en el panel.
func skill_maxed(option_id: String) -> bool:
	var tope := skill_max_level(option_id)
	return tope > 0 and skill_level(option_id) >= tope


## Lo que cuesta el SIGUIENTE nivel de una opcion, en monedas de rebirth. -1
## cuando no hay nada que comprar (ya esta al tope), como item_cost().
func skill_cost(option_id: String) -> int:
	return LootDB.skill_cost(option_id, skill_level(option_id))


## El efecto de una opcion al nivel que se le pida, ya escrito para leerlo.
## El panel enseña el del nivel SIGUIENTE (lo que se compra) y, al tope, el de
## ahora: quien llama decide cual de los dos pide.
func skill_effect(option_id: String, level: int) -> String:
	return LootDB.skill_effect(option_id, level)


## Suma de niveles comprados del arbol entero. Es la medida de "cuanto llevo
## mejorado" y lo que enseña la chapa que abre el panel.
func skill_total() -> int:
	var total := 0
	for option in LootDB.skill_options():
		total += skill_level(str(option["id"]))
	return total


## Comprar el siguiente nivel de una opcion con monedas de rebirth. Devuelve
## false si no hay nada que comprar (al tope) o si no llegan las monedas.
##
## El pago va por las monedas y NO por el dinero de la partida: es la unica
## moneda que el rebirth no borra, y por eso el arbol es progresion de cuenta.
func buy_skill(option_id: String) -> bool:
	var cost := skill_cost(option_id)
	if cost < 0 or rebirth_coins < cost:
		return false
	rebirth_coins -= cost
	skills[option_id] = skill_level(option_id) + 1
	_dirty = true
	skills_changed.emit()
	return true


# --- los efectos, ya aplicados --------------------------------------------- #

## Segundos que tarda un objeto en caer a la mesa ("Caida rapida").
func drop_time() -> float:
	return LootDB.skill_drop_time(skill_level("caida"))


## ¿Los objetos nuevos se colocan solos en rejilla? ("Mesa ordenada").
func tidy_table() -> bool:
	return skill_level("orden") > 0


## Probabilidad de que un golpe suelte dinero extra ("Dinero al rasgar").
func rip_chance() -> float:
	return LootDB.skill_rip_chance(skill_level("rasgar"))


## Cuanto dinero suelta ese golpe, segun lo que costo el sobre.
func rip_cash_for(pack_id: String) -> int:
	return LootDB.skill_rip_cash(pack_price(pack_id))


## Probabilidad de que un golpe haga el doble de dano ("Golpe doble").
func double_chance() -> float:
	return LootDB.skill_double_chance(skill_level("doble"))


## El dinero con el que empieza una partida nueva, con la herencia del arbol
## dentro. Lo usa do_rebirth(): empezar de cero con la mejora comprada es
## exactamente lo que promete "Dinero heredado".
func start_money() -> int:
	return START_MONEY + LootDB.skill_heir_money(skill_level("hereda"))


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
## en esta version el inventario son INVENTORY_SLOTS huecos y no hay forma de
## ampliarlos (el armario tiene sus propios huecos y no son del inventario).
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
# El armario
# --------------------------------------------------------------------------- #
#
# El armario es la vitrina: los objetos que el jugador saca del inventario para
# exponerlos. Un objeto expuesto ya no esta en el inventario (no se puede vender)
# y a cambio da el bonus de SU tipo segun su nota PSA (ver LootDB.LOOT_KINDS).
#
# Poner y quitar objetos es MANUAL a proposito. La version anterior exponia sola
# "los mejores" y eso convertia el armario en un adorno: como no habia nada que
# decidir, subirlo de nivel solo servia para exponer mas objetos que ya estaban
# expuestos. Con huecos y manos, cada nivel del armario es un hueco mas que hay
# que LLENAR, y elegir que se expone (dano, velocidad, dinero o rebirth) es la
# decision.

## Huecos del armario. Cero sin la pieza comprada.
func locker_slots() -> int:
	return LootDB.locker_slots(items)


func locker_size() -> int:
	return locker.size()


func locker_free() -> bool:
	return locker.size() < locker_slots()


## Exponer el objeto `index` del inventario. Devuelve false si no hay hueco (ni
## armario comprado, o ya lleno), que es lo unico que puede fallar: el indice lo
## pone la interfaz, que es quien esta mirando la lista.
func locker_put(index: int) -> bool:
	if index < 0 or index >= inventory.size() or not locker_free():
		return false
	locker.append(inventory[index])
	inventory.remove_at(index)
	_dirty = true
	inventory_changed.emit()
	locker_changed.emit()
	return true


## Sacar de la vitrina el objeto `index` del armario: vuelve al inventario. Si el
## inventario esta lleno no se toca nada (no se puede tener el objeto en el aire).
func locker_take(index: int) -> bool:
	if index < 0 or index >= locker.size() or not inventory_free():
		return false
	inventory.append(locker[index])
	locker.remove_at(index)
	_dirty = true
	inventory_changed.emit()
	locker_changed.emit()
	return true


## Lo que aporta el armario a UN tipo de botin: la suma de sus objetos expuestos
## (ver LootDB.bonus_for, que es lo que da un objeto segun su nota).
func kind_bonus(kind_id: String) -> float:
	var total := 0.0
	for item in locker:
		if LootDB.kind_of(item) == kind_id:
			total += LootDB.bonus_for(item)
	return total


## Las cuatro sumas a la vez, para leerlas de una vez en el panel.
func kind_totals() -> Dictionary:
	var totals := {}
	for kind_id in LootDB.kind_ids():
		totals[kind_id] = 0.0
	for item in locker:
		totals[LootDB.kind_of(item)] = float(totals[LootDB.kind_of(item)]) \
				+ LootDB.bonus_for(item)
	return totals


## Cuanto sube el DANO del golpe (Cartas expuestas).
func damage_multiplier() -> float:
	return 1.0 + kind_bonus("cards")


## Cuanto se acelera la CARGA del boton (Zapatillas expuestas). El tiempo por
## ciclo se divide por esto: 1.0 es "igual que sin armario".
func charge_multiplier() -> float:
	return 1.0 + kind_bonus("sneakers")


## Cuanto sube el DINERO que se saca de cada objeto encontrado: lo que dan los
## Vinilos expuestos mas la paga permanente del rebirth. Es el multiplicador que
## se le pasa a LootDB.roll_pack(), asi que lo que se ve en la tarjeta de
## revelado ya lo lleva.
func value_multiplier() -> float:
	return (1.0 + kind_bonus("vinyls")) * rebirth_value_mult() \
			* LootDB.skill_sale_mult(skill_level("ventas"))


## Cuanto se multiplican las monedas de rebirth que da reiniciar (Electronica
## expuesta). No toca el dinero: toca el PREMIO del rebirth, que es lo que le da
## sentido a exponer electronica.
func rebirth_multiplier() -> float:
	return 1.0 + kind_bonus("electronics")


## La paga permanente del rebirth, al valor de lo que se vende.
func rebirth_value_mult() -> float:
	return LootDB.rebirth_value_mult(rebirth_coins)


# --------------------------------------------------------------------------- #
# Rebirth (la hucha)
# --------------------------------------------------------------------------- #

## ¿Le llega para reiniciar? El requisito se mide en lo GANADO en esta partida
## (lifetime_earned), no en el dinero que tenga ahora: es una meta de la partida
## entera, y guardar el dinero para el final no cambia nada.
func can_rebirth() -> bool:
	return lifetime_earned >= LootDB.REBIRTH_REQUIRE


## Las monedas que daria reiniciar AHORA, con la Electronica del armario dentro.
## Es el mismo calculo que hace do_rebirth(), y lo enseña el panel: si los dos
## numeros no salieran de aqui, el panel podria prometer una cosa y dar otra.
func pending_rebirth_coins() -> int:
	return LootDB.rebirth_coins_for(lifetime_earned, rebirth_multiplier())


## Lo que falta para poder reiniciar (0 si ya se puede).
func rebirth_missing() -> int:
	return maxi(0, LootDB.REBIRTH_REQUIRE - lifetime_earned)


## Reiniciar la partida: se pierde TODO lo de la partida (dinero, items, armario
## e inventario) y se gana la hucha, que es lo unico que pasa de una partida a la
## siguiente. Devuelve las monedas ganadas.
##
## Las estadisticas de logros (paquetes abiertos, objetos encontrados, mejor
## nota) NO se pierden: son de la cuenta, no de la partida.
func do_rebirth() -> int:
	if not can_rebirth():
		return 0
	var coins := pending_rebirth_coins()
	rebirth_coins += coins
	# El dinero inicial es el de siempre MAS la herencia del arbol: es la mejora
	# que se nota justo aqui, en la primera compra de la partida nueva.
	money = start_money()
	# Y EL ARBOL NO SE TOCA. Ni los niveles ni las monedas que quedan sin gastar:
	# las dos cosas son de la cuenta y no de la partida, que es toda la razon de
	# que el arbol se pague con monedas de rebirth.
	items = []
	while items.size() < LootDB.item_count():
		items.append(0)
	inventory = []
	locker = []
	lifetime_earned = 0
	# Las automatizaciones se caen con las piezas, que se han ido: si no, la
	# partida nueva empezaria con la mesa abriendose sola y sin Pinchos.
	auto_open = false
	auto_buy = false
	auto_buy_packs = _all_pack_ids()
	_dirty = true
	money_changed.emit(money)
	inventory_changed.emit()
	locker_changed.emit()
	items_changed.emit()
	settings_changed.emit()
	save_game()
	return coins


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

## Dano de cada golpe al cargar el boton. Las Cartas expuestas en el armario
## suben este numero por encima de lo que dan los items de la tienda.
func damage_per_hit() -> float:
	return LootDB.damage_per_hit(items) * damage_multiplier() \
			* LootDB.skill_damage_mult(skill_level("golpe"))


## Segundos que tarda un ciclo de carga. Las Zapatillas expuestas lo acortan.
func charge_time() -> float:
	return LootDB.charge_time(items) / charge_multiplier()


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
	locker = []
	items = []
	while items.size() < LootDB.item_count():
		items.append(0)
	auto_open = false
	auto_buy = false
	auto_buy_packs = _all_pack_ids()
	auto_sell = false
	skills = {}
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
	skills_changed.emit()
	settings_changed.emit()


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"money": money,
		"rebirth_coins": rebirth_coins,
		"inventory": inventory,
		"locker": locker,
		"items": items,
		"skills": skills,
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
	# El armario: los objetos expuestos. Un guardado de antes de que existiera no
	# trae la clave y el armario sale vacio, que es lo correcto (los objetos
	# siguen donde estaban, en el inventario).
	locker = d.get("locker", [])
	if typeof(locker) != TYPE_ARRAY:
		locker = []
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
	# El arbol de habilidades: un guardado de antes de que existiera no trae la
	# clave y el arbol sale vacio, que es lo correcto. Los niveles se limpian
	# contra el catalogo de VERDAD (ni ids que ya no existen, ni niveles por
	# encima del tope de su opcion): un guardado tocado a mano no puede dejar una
	# mejora al nivel 40 ni una opcion fantasma en el panel.
	skills = {}
	var skills_guardadas = d.get("skills", null)
	if typeof(skills_guardadas) == TYPE_DICTIONARY:
		for option in LootDB.skill_options():
			var option_id := str(option["id"])
			if not (skills_guardadas as Dictionary).has(option_id):
				continue
			var lvl := clampi(int((skills_guardadas as Dictionary)[option_id]), 0,
					LootDB.skill_max(option_id))
			if lvl > 0:
				skills[option_id] = lvl
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
	# Y el armario se recorta a sus huecos: con el armario al nivel 2 caben 2
	# objetos expuestos. Un guardado que traiga mas (de una partida en la que el
	# armario estaba mas alto, o tocado a mano) devuelve el resto al inventario en
	# vez de tirarlo, que es lo unico que no pierde nada.
	while locker.size() > locker_slots():
		inventory.append(locker.pop_back())
	_dirty = false
