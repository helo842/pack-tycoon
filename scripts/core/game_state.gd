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
## Un paquete ha pedido abrirse (el jugador le ha hecho clic). Lo escucha game.gd,
## que es quien sabe cuantos paquetes se pueden llevar a la vez (el cupo de la mesa).
signal open_requested(element: Object)
signal settings_changed()
## El arbol de mejoras ha cambiado: se ha comprado un nodo con monedas de
## rebirth. Lo escucha el panel del arbol, que es el unico que lo enseña.
signal skills_changed()
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
## Las monedas de rebirth SIN GASTAR. Se ganan reiniciando la partida (una por
## cada 1,5 M del contador, ver LootDB.REBIRTH_COIN_AT) y se gastan en el arbol
## de mejoras, que es lo unico que se compra con ellas.
var rebirth_coins: int = 0
## El arbol de mejoras: el id de cada nodo comprado y su nivel (ver SkillTree).
##
## GUARDAR ESTO Y NADA MAS es lo que hace que el arbol sea pequeno: lo que da
## cada nodo y lo que cuesta lo dice SkillTree, y los multiplicadores de abajo
## los sacan de aqui. Un diccionario y no una lista de ids porque el nivel de un
## nodo es parte del nodo (hoy todos son de una compra, ver SkillTree.LEVELS).
var skills: Dictionary = {}

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
## array es el de LootDB.ITEMS. Los siete con niveles suben hasta ocho; el PC y
## los Pinchos son de compra unica (nivel 1 y ya). Ver LootDB.item_max_level().
var items: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

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

## Todo lo que ha ENTRADO en esta partida (no lo que hay en el contador: el
## dinero se va comprando sobres). Se sigue llevando la cuenta porque es un dato
## de la partida que se guarda, pero el REBIRTH ya no lo mira: su requisito se
## mide en el dinero que tienes (ver can_rebirth).
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

## Lo que cuesta un sobre, con el descuento del DOLAR ya aplicado.
##
## El sobre gratuito sigue a 0: un descuento sobre cero es cero, y ademas la
## columna lo anuncia con GRATIS (ver pack_free).
func pack_price(pack_id: String) -> int:
	var base := int(LootDB.pack_by_id(pack_id)["price"])
	if base <= 0:
		return base
	var off := LootDB.pack_discount(items)
	return maxi(1, roundi(float(base) * (1.0 - off)))


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

## Huecos del armario: los de la pieza de la tienda (uno por nivel) mas los que
## compre el arbol del rebirth (+2 por la mejora de ARMARIO), y el total con el
## TOPE de LootDB.LOCKER_SLOTS_MAX.
##
## El tope no es un detalle: el panel del armario dibuja los ocho marcos del tope
## y son los que hay, asi que un hueco de mas seria un objeto expuesto que no se
## puede ver ni recuperar. Con el tope, la mejora del arbol adelanta el armario
## (te lleva al octavo con menos niveles comprados), que es exactamente lo que
## promete un +2 de huecos.
func locker_slots() -> int:
	return clampi(LootDB.locker_slots(items) + int(skill_bonus(SkillTree.SLOTS_STAT)),
		0, LootDB.LOCKER_SLOTS_MAX)


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


## Cuanto sube el DANO del golpe: lo que dan las Cartas expuestas EN EL ARMARIO y
## lo que hay comprado en el arbol del rebirth. Son dos cosas distintas y cada
## una con su origen, pero el golpe solo tiene un multiplicador, asi que se
## juntan aqui y no en cada sitio que pega (el boton, los pinchos y la mesa).
func damage_multiplier() -> float:
	return (1.0 + kind_bonus("cards")) * (1.0 + skill_bonus("damage"))


## Cuanto se acelera la CARGA del boton (Zapatillas expuestas y la mejora de
## VELOCIDAD del arbol). El tiempo por ciclo se divide por esto: 1.0 es "igual
## que sin nada".
func charge_multiplier() -> float:
	return (1.0 + kind_bonus("sneakers")) * (1.0 + skill_bonus("speed"))


## Cuanto sube el DINERO que se saca de cada objeto encontrado: lo que dan los
## Vinilos expuestos y la mejora de DINERO del arbol del rebirth. Es el
## multiplicador que se le pasa a LootDB.roll_pack(), asi que lo que se ve en la
## tarjeta de revelado ya lo lleva.
##
## LAS MONEDAS DE REBIRTH YA NO ENTRAN AQUI. Cada moneda sumaba un 5 % al valor
## de todo lo que vendias sin hacer nada, y eso dejaba el rebirth sin decision:
## se acumulaba solo. Ahora el dinero es un NODO del arbol que hay que comprar
## (+30 %) y las monedas se gastan ahi.
func value_multiplier() -> float:
	return (1.0 + kind_bonus("vinyls")) * (1.0 + skill_bonus("money"))


## Cuanto se multiplican las monedas de rebirth que da reiniciar (Electronica
## expuesta). No toca el dinero: toca el PREMIO del rebirth, que es lo que le da
## sentido a exponer electronica.
func rebirth_multiplier() -> float:
	return 1.0 + kind_bonus("electronics")


# --------------------------------------------------------------------------- #
# Rebirth (la hucha)
# --------------------------------------------------------------------------- #

## ¿Le llega para reiniciar? El requisito se mide en el DINERO QUE TIENE AHORA
## (money, lo que hay en el contador), que es lo mismo que se lleva el cerdo al
## romperse: el rebirth pide juntar esa cifra y no gastarla, y por eso guardar el
## dinero sube las monedas del premio Y adelanta el reinicio.
func can_rebirth() -> bool:
	return money >= LootDB.REBIRTH_REQUIRE


## Las monedas que daria reiniciar AHORA, con la Electronica del armario dentro.
## Es el mismo calculo que hace do_rebirth(), y lo enseña el panel: si los dos
## numeros no salieran de aqui, el panel podria prometer una cosa y dar otra.
##
## SE CUENTA EL DINERO DEL CONTADOR (`money`), igual que el requisito: el cerdo
## se lleva lo que hay dentro cuando se rompe. Por eso el numero del panel BAJA
## al comprar sobres y mejoras, que es justo la informacion que necesita el
## jugador para decidir si le queda una moneda mas o si reinicia ya.
func pending_rebirth_coins() -> int:
	return LootDB.rebirth_coins_for(money, rebirth_multiplier())


## Lo que falta para poder reiniciar (0 si ya se puede). Es dinero del contador,
## como el requisito: se puede decir con la misma cifra que enseña la barra de
## arriba sin traducir nada.
func rebirth_missing() -> int:
	return maxi(0, LootDB.REBIRTH_REQUIRE - money)


## Reiniciar la partida: se pierde TODO lo de la partida (dinero, items, armario
## e inventario) y se gana la hucha, que es lo unico que pasa de una partida a la
## siguiente. Devuelve las monedas ganadas.
##
## EL ARBOL DE MEJORAS NO SE TOCA, y es lo que hace que reiniciar signifique
## algo: las monedas se ganan reiniciando y se gastan en el arbol (ver
## buy_skill), asi que el arbol es tan permanente como las monedas. Reiniciar
## para perderlo seria pagar por nada.
##
## Las estadisticas de logros (paquetes abiertos, objetos encontrados, mejor
## nota) NO se pierden: son de la cuenta, no de la partida.
func do_rebirth() -> int:
	if not can_rebirth():
		return 0
	var coins := pending_rebirth_coins()
	rebirth_coins += coins
	money = START_MONEY
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
# El arbol de mejoras (las monedas de rebirth)
# --------------------------------------------------------------------------- #
#
# Las monedas que da el rebirth se GASTAN aqui. El id de cada nodo, lo que
# cuesta y lo que da viven en SkillTree; aqui solo esta lo que el jugador tiene
# comprado y los multiplicadores que salen de eso.
#
# POR QUE LAS COMPRAS SON DEFINITIVAS. El arbol es lo que hace que el rebirth
# valga la pena: si reiniciar se llevara por delante las mejoras compradas, cada
# moneda gastada seria una moneda tirada en el siguiente rebirth y el juego se
# quedaria sin nada que construir. No se pueden deshacer ni devolver, que es lo
# mismo que pasa con las piezas de la tienda dentro de una partida.

## El nivel comprado de un nodo (0 si no se ha comprado).
func skill_level(id: String) -> int:
	return int(skills.get(id, 0))


func skill_owned(id: String) -> bool:
	return skill_level(id) > 0


## ¿Se puede comprar ya, aunque no haya monedas? Es el requisito del arbol:
## todos los caminos salen del nodo del centro (ver SkillTree.NODES). Un nodo que
## no existe sale BLOQUEADO, para que un id de un guardado viejo no abra nada.
func skill_unlocked(id: String) -> bool:
	if not SkillTree.has_node(id):
		return false
	var req := SkillTree.req_of(id)
	return req == "" or skill_owned(req)


## Lo que cuesta el siguiente nivel de un nodo, o -1 si no hay nada que comprar:
## o ese nodo no existe, o ya esta al tope.
func skill_cost(id: String) -> int:
	if not SkillTree.has_node(id) or skill_level(id) >= SkillTree.levels_of(id):
		return -1
	return int(SkillTree.node_by_id(id)["cost"])


## ¿Le llega para comprarlo? Es lo que mira el panel para pintar el nodo de una
## forma o de otra.
func can_buy_skill(id: String) -> bool:
	var cost := skill_cost(id)
	return cost >= 0 and skill_unlocked(id) and rebirth_coins >= cost


## Cuantas monedas faltan para ese nodo (0 si le llega ahora mismo). Lo dice el
## panel cuando no se puede comprar, que es lo unico util que se puede decir.
func skill_missing_coins(id: String) -> int:
	var cost := skill_cost(id)
	if cost < 0:
		return 0
	return maxi(0, cost - rebirth_coins)


## Comprar un nodo. Devuelve false si no se puede: al tope, con el requisito sin
## cumplir o sin monedas. La comprobacion vive aqui y no en el boton para que
## valga igual viniendo del panel, de un test o de donde sea.
func buy_skill(id: String) -> bool:
	var cost := skill_cost(id)
	if cost < 0 or not skill_unlocked(id) or rebirth_coins < cost:
		return false
	rebirth_coins -= cost
	skills[id] = skill_level(id) + 1
	_dirty = true
	skills_changed.emit()
	# Y con el arbol cambian los multiplicadores de la partida en curso (el dano
	# y la velocidad se notan en el acto, y los huecos del armario ya estan
	# disponibles): se avisa por donde se avisa siempre de estas cosas, que es
	# como se entera la pantalla de juego sin saber que existe un arbol.
	items_changed.emit()
	locker_changed.emit()
	settings_changed.emit()
	save_game()
	return true


## Lo que suma un stat entre todos los nodos comprados. Los de porcentaje suman
## fracciones (0.5 = +50 %) y el armario suma huecos: cada uno se lo pide a
## SkillTree, que es quien sabe que es cada nodo.
func skill_bonus(stat: String) -> float:
	var total := 0.0
	for id in skills:
		var n := SkillTree.node_by_id(str(id))
		if n.is_empty() or str(n["stat"]) != stat:
			continue
		total += float(n["value"]) * float(skill_level(str(id)))
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

## Dano de cada golpe al cargar el boton. Las Cartas expuestas en el armario
## suben este numero por encima de lo que dan los items de la tienda.
func damage_per_hit() -> float:
	return LootDB.damage_per_hit(items) * damage_multiplier()


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


## Dano por segundo de los Pinchos, con la mejora de PINCHOS del arbol encima.
## Se multiplica AQUI y no dentro de LootDB.spike_dps() porque ese calculo es el
## de los Pinchos de la tienda, y el arbol no es una pieza de la tienda.
func spike_dps() -> float:
	return LootDB.spike_dps(items, float(money)) * (1.0 + skill_bonus("spikes"))


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
	skills = {}
	inventory = []
	locker = []
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
		"skills": skills,
		"inventory": inventory,
		"locker": locker,
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
	# El arbol de mejoras, limpio contra los nodos que existen de verdad: un
	# guardado de antes del arbol no trae la clave (y sale vacio, que es lo
	# correcto: nadie habia comprado nada) y uno tocado a mano no puede meter un
	# nodo inventado ni un nivel de mas.
	skills = SkillTree.clean_levels(d.get("skills", {}))
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
