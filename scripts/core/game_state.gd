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
## Algo gordo que merece el cartel grande de arriba (MainRoot.banner): una
## coleccion completa del album.
signal celebrate(title: String, subtitle: String)
## La mesa se ha vaciado por decreto: un rebirth (lo que habia en ella era de la
## partida que se va) o un reinicio de los tests. Lo escucha la pantalla de juego,
## que es la que tiene los elementos dibujados y tiene que quitarlos.
signal table_reset()
## Ha empezado o acabado un evento (comprador VIP u hora feliz): lo escucha la
## banda de avisos de la mesa.
signal events_changed()
## El album ha apuntado un objeto nuevo o una nota mejor.
signal album_changed()
## Los encargos han avanzado, se ha cumplido uno o han cambiado.
signal missions_changed()
## Una habilidad se ha usado o ha vuelto a estar lista.
signal abilities_changed()
## La racha de golpes perfectos ha subido o se ha roto (ver Gameplay.STREAK_STEP).
signal streak_changed(streak: int)

const SAVE_PATH := "user://packtycoon.json"
const AUTOSAVE_EVERY := 30.0
const START_MONEY := 500
## Huecos del inventario. 50 y no 10 porque el inventario ya no es una tira de
## diez ranuras debajo de la mesa: es la columna de la IZQUIERDA del armario (ver
## LockerPanel), y ahi cabe una rejilla larga con scroll. Ampliarlo de verdad
## (con mejoras) es otra cosa y sigue pendiente.
const INVENTORY_SLOTS := 50

var money: int = START_MONEY
## Las monedas de rebirth SIN GASTAR. Se ganan reiniciando la partida (con la
## raiz cubica del contador, ver LootDB.rebirth_coins_for) y se gastan en el arbol
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

## El dano que ha sobrado de un golpe y que espera al siguiente sobre, para la
## mejora EL SOBRANTE NO SE TIRA (ver SkillTree.QOL_CARRY). Es de la PARTIDA y no
## del elemento: el golpe que rompe una caja se da contra ella, que desaparece, y
## lo que sobra tiene que llegar al siguiente que el jugador golpee.
##
## Vive fuera del guardado a proposito: es medio golpe en vuelo, no progreso. Al
## cargar una partida guardada vale cero, que es lo mismo que empieza valiendo.
var carry_damage: float = 0.0

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
## EL AUTO GUARDAR (nodo del arbol SkillTree.QOL_AUTOSTORE): con el encendido,
## lo que sale de un sobre se guarda solo si su tipo, su nota PSA y su rareza
## estan marcados en las tres listas, y si no se vende solo. Las listas se eligen
## valor por valor en Ajustes (AutoStorePanel). Son de la cuenta, como el arbol:
## el rebirth no las toca.
var autostore_on: bool = false
var autostore_kinds: Array = []
var autostore_grades: Array = []
var autostore_rarities: Array = []
## Cuando sale la FICHA del objeto: "always" con cada objeto, "good" solo con
## lo que merece pararse (ver card_worth) y "never" nunca (cae en la mesa).
const CARD_MODES: Array = ["always", "good", "never"]
var card_mode: String = "good"
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

## LO QUE HAY ENCIMA DE LA MESA: los sobres comprados (con la vida que les queda)
## y el botin sin vender. Cada entrada es {"pack": id, "hp": vida} o
## {"loot": objeto}.
##
## ANTES NO SE GUARDABA, y era un agujero: salir al menu (ESC) o cerrar el juego
## tiraba los sobres que ya se habian pagado y el botin que no se habia vendido.
## La mesa la dibuja la pantalla de juego, asi que es ella la que sabe lo que hay:
## mientras esta abierta deja aqui `table_provider`, y cada guardado le pide la
## foto de la mesa. Al cerrarse deja la ultima foto en `table`, y la siguiente
## pantalla de juego la vuelve a poner en la mesa (ver game.gd, _restore_table).
var table: Array = []
var table_provider: Callable = Callable()

# --- el gameplay nuevo (ver Gameplay) -------------------------------------- #

## EL ALBUM: el dibujo de cada objeto visto (sin la nota) y la mejor nota que ha
## salido de el. Es de la CUENTA, como las estadisticas: no se pierde al
## reiniciar, y por eso sus colecciones dan un bonus para siempre.
var album: Dictionary = {}
## Los encargos en curso: cada uno {type, goal, progress, kind, reward}.
var missions: Array = []
## El sobre mas caro comprado en esta partida: de el salen el premio de los
## encargos y el sobre dorado (que es el siguiente a este).
var top_pack_price: int = 0
var top_pack_index: int = 0
## Golpes perfectos dados en toda la cuenta (estadistica).
var perfect_hits: int = 0

## Lo que NO se guarda: los eventos en curso y las recargas. Son de este rato de
## juego, como el dano que sobra de un golpe.
var buyer: Dictionary = {}          # {kind, grade, left}
var happy: Dictionary = {}          # {kind, left}
var cooldowns: Dictionary = {}      # id de habilidad -> segundos que le faltan
var charged_next: bool = false
var frenzy_left: float = 0.0
## Golpes perfectos seguidos (ver Gameplay.STREAK_STEP). Es de este rato de juego.
var streak: int = 0
var _rng_play := RandomNumberGenerator.new()

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
	_autostore_defaults()
	_rng_play.randomize()
	# El cierre lo lleva este nodo y no el motor, para poder meter medio frame
	# de margen antes de salir (ver _on_close). Sin esto, el motor cierra de
	# golpe en cuanto llega el aviso de la ventana.
	get_tree().auto_accept_quit = false
	load_game()
	if missions.is_empty():
		_fill_missions()
	# La pantalla completa se GUARDABA pero no se aplicaba al arrancar: la casilla
	# de los ajustes salia marcada y la ventana se abria igual en ventana. Sin
	# ventana (los tests van en headless) no hay modo que poner.
	if fullscreen and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_tick_play(delta)
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
		payout(item)
		notice.emit("INVENTARIO LLENO: VENDIDO", Palette.GOLD)
		return false
	inventory.append(item.duplicate(true))
	_dirty = true
	inventory_changed.emit()
	# El encargo de GUARDAR cuenta aqui, al entrar de verdad en el inventario.
	mission_event("store", int(item.get("grade", 0)), LootDB.kind_of(item))
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
	_album_add(item)
	mission_event("grade", int(item.get("grade", 0)))


## Vende por indice. Devuelve cuanto se ha sacado (0 si no habia nada).
func sell_at(index: int) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var item: Dictionary = inventory[index]
	inventory.remove_at(index)
	var value := payout(item)
	_dirty = true
	inventory_changed.emit()
	return value


func sell_all() -> int:
	var total := 0
	var vender := inventory.duplicate()
	inventory.clear()
	for item in vender:
		total += payout(item)
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
##
## CON LA MEJORA ARMARIO SOLO, el armario lleno ya no es un no: si entre lo
## expuesto hay una pieza del MISMO TIPO que da menos que esta, entra esta y la
## otra vuelve al inventario. Es lo que quita el trabajo de ir comparando notas a
## mano, y por eso solo actua cuando el hueco falta: con sitio libre, exponer es
## sumar y nunca se cambia una pieza por otra (dos del mismo tipo suman los dos
## bonus, y cambiar una por otra no).
func locker_put(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	if not locker_free():
		return _locker_swap(index) if skill_owned(SkillTree.QOL_LOCKER) else false
	locker.append(inventory[index])
	inventory.remove_at(index)
	_dirty = true
	inventory_changed.emit()
	locker_changed.emit()
	return true


## El cambio del armario automatico: la pieza expuesta de este tipo que menos da,
## si da menos que la que se esta exponiendo. Devuelve true si ha cambiado algo.
##
## Se hace cambiando los dos objetos de sitio y no quitando y metiendo (que
## dejaria el armario con un hueco de mas y el inventario con uno de menos a mitad
## de la operacion), y no se toca nada si la de dentro ya es mejor: una mejora de
## "que se ordene solo" que empeora el armario cuando pulsas no es una mejora.
func _locker_swap(index: int) -> bool:
	var nuevo: Dictionary = inventory[index]
	var peor := -1
	for i in locker.size():
		if LootDB.kind_of(locker[i]) != LootDB.kind_of(nuevo):
			continue
		if peor < 0 or LootDB.bonus_for(locker[i]) < LootDB.bonus_for(locker[peor]):
			peor = i
	if peor < 0 or LootDB.bonus_for(nuevo) <= LootDB.bonus_for(locker[peor]):
		return false
	var fuera: Dictionary = locker[peor]
	locker[peor] = nuevo
	inventory[index] = fuera
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
	return float(kind_totals().get(kind_id, 0.0))


## Las cuatro sumas a la vez, para leerlas de una vez en el panel. Cada pieza
## del mismo tipo cuenta menos que la anterior (ver LootDB.locker_totals).
func kind_totals() -> Dictionary:
	return LootDB.locker_totals(locker)


## Cuanto sube el DANO del golpe: lo que dan las Cartas expuestas EN EL ARMARIO y
## lo que hay comprado en el arbol del rebirth. Son dos cosas distintas y cada
## una con su origen, pero el golpe solo tiene un multiplicador, asi que se
## juntan aqui y no en cada sitio que pega (el boton, los pinchos y la mesa).
func damage_multiplier() -> float:
	return (1.0 + kind_bonus("cards")) * (1.0 + skill_bonus("damage")) \
			* (1.0 + album_bonus("damage"))


## Cuanto se acelera la CARGA del boton (Zapatillas expuestas y la mejora de
## VELOCIDAD del arbol). El tiempo por ciclo se divide por esto: 1.0 es "igual
## que sin nada".
func charge_multiplier() -> float:
	return (1.0 + kind_bonus("sneakers")) * (1.0 + skill_bonus("speed")) \
			* (1.0 + album_bonus("speed"))


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
	return (1.0 + kind_bonus("vinyls")) * (1.0 + skill_bonus("money")) \
			* (1.0 + album_bonus("money"))


## Cuanto se multiplican las monedas de rebirth que da reiniciar (Electronica
## expuesta). No toca el dinero: toca el PREMIO del rebirth, que es lo que le da
## sentido a exponer electronica.
func rebirth_multiplier() -> float:
	return 1.0 + kind_bonus("electronics") + album_bonus("rebirth")


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
	# LA MESA SE VACIA, y lo primero: lo que hay encima es de la partida que se va.
	# Antes se quedaba puesta, y el botin sin vender se cobraba DESPUES del rebirth,
	# o sea que se podia pasar dinero de una partida a la siguiente dejando la mesa
	# llena antes de reiniciar. Se avisa ANTES del save_game() de abajo: el
	# guardado le pide la foto de la mesa a la pantalla, y tiene que salir vacia.
	table = []
	table_reset.emit()
	top_pack_price = 0
	top_pack_index = 0
	missions = []
	buyer = {}
	happy = {}
	charged_next = false
	frenzy_left = 0.0
	_fill_missions()
	money = START_MONEY
	items = []
	while items.size() < LootDB.item_count():
		items.append(0)
	inventory = []
	locker = []
	lifetime_earned = 0
	# Lo que sobraba de un golpe era de la partida que se va: la nueva empieza sin
	# nada en el aire.
	carry_damage = 0.0
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
	return LootDB.crit_chance(items) + album_bonus("crit")


func crit_mult() -> float:
	return LootDB.crit_mult(items)


func luck() -> float:
	return LootDB.luck(items)


func open_count() -> int:
	return table_slots()


func table_slots() -> int:
	return LootDB.table_slots(items) + int(album_bonus("table"))


func auto_buy_interval() -> float:
	return LootDB.auto_buy_interval(items)


## Dano por segundo de los Pinchos, con la mejora de PINCHOS del arbol encima.
## Se multiplica AQUI y no dentro de LootDB.spike_dps() porque ese calculo es el
## de los Pinchos de la tienda, y el arbol no es una pieza de la tienda.
func spike_dps() -> float:
	return LootDB.spike_dps(items, float(money)) * (1.0 + skill_bonus("spikes"))


## El dano que espera al siguiente golpe, y se lleva por delante: el que lo pide
## es el golpe que va a pegar, y lo que quede se vuelve a guardar despues (ver
## keep_carry). Devuelve siempre 0 si la mejora no esta comprada, para que quien
## golpea no tenga que saber si existe.
func take_carry() -> float:
	var amount := carry_damage
	carry_damage = 0.0
	return amount


## Guarda el dano que le ha sobrado a un golpe para el siguiente. Sin la mejora
## EL SOBRANTE NO SE TIRA, no guarda nada: es exactamente el desperdicio que
## quita, asi que aqui y no en quien golpea esta la regla.
func keep_carry(amount: float) -> void:
	if amount <= 0.0 or not skill_owned(SkillTree.QOL_CARRY):
		return
	carry_damage = amount


## ¿Este objeto es chatarra para la mejora SIN FICHA? Es una nota, no un precio:
## lo que vale un objeto sube con el escalon del sobre -una zapatilla comun vale
## cuarenta veces lo que una carta comun-, asi que un umbral en dinero tendria que
## cambiar con cada escalon y el jugador no sabria nunca cual es. La nota va de 1
## a 10 en todos los sobres y se ve en la ficha como estrellas, o sea que la
## mejora se puede explicar en una linea: "de tres estrellas o menos".
func auto_sell_chaff(item: Dictionary) -> bool:
	return skill_owned(SkillTree.QOL_CHAFF) \
			and int(item.get("grade", LootDB.GRADE_MAX)) <= LootDB.AUTO_SELL_GRADE


## Un paquete pide abrirse. game.gd decide cuantos mas arranca a la vez.
func request_open(element: Object) -> void:
	open_requested.emit(element)


# --------------------------------------------------------------------------- #
# El gameplay nuevo: pagos, eventos, habilidades, album y encargos
# --------------------------------------------------------------------------- #

## COBRAR UN OBJETO: el UNICO sitio por el que pasa el dinero de una venta (la
## mesa, la tarjeta, el inventario, la venta automatica). Aqui se aplican los
## eventos -la hora feliz dobla y el comprador VIP triplica- y se avisa a los
## encargos, asi que ninguna forma de vender se queda sin ellos.
func payout(item: Dictionary) -> int:
	var value := int(item.get("value", 0))
	var kind := LootDB.kind_of(item)
	if not happy.is_empty() and str(happy["kind"]) == kind:
		value = roundi(float(value) * Gameplay.HAPPY_MULT)
	if buyer_wants(item):
		value = roundi(float(value) * Gameplay.VIP_MULT)
		buyer = {}
		events_changed.emit()
		notice.emit("VENDIDO AL COMPRADOR VIP: " + Gameplay.mult_text(Gameplay.VIP_MULT),
			Palette.GOLD_XL)
		mission_event("vip", 1)
	add_money(value)
	return value


## Lo que se cobraria AHORA por un objeto (para ensenarlo en la tarjeta).
func payout_preview(item: Dictionary) -> int:
	var value := int(item.get("value", 0))
	if not happy.is_empty() and str(happy["kind"]) == LootDB.kind_of(item):
		value = roundi(float(value) * Gameplay.HAPPY_MULT)
	if buyer_wants(item):
		value = roundi(float(value) * Gameplay.VIP_MULT)
	return value


func buyer_wants(item: Dictionary) -> bool:
	return not buyer.is_empty() and LootDB.kind_of(item) == str(buyer["kind"]) \
			and int(item.get("grade", 0)) >= int(buyer["grade"])


## Se ha comprado un sobre: el mas caro de la partida decide el premio de los
## encargos y que sobre dorado sale.
func note_pack_bought(pack_id: String, price: int) -> void:
	if price > top_pack_price:
		top_pack_price = price
		top_pack_index = LootDB.pack_index(pack_id)
		_dirty = true


## El sobre que trae el sobre dorado: el mas caro que se ha comprado (mas
## Gameplay.GOLDEN_STEP, sin pasarse del ultimo), y como poco los vinilos.
func golden_pack_id() -> String:
	var i := clampi(maxi(top_pack_index + Gameplay.GOLDEN_STEP, 1), 0,
			LootDB.pack_count() - 1)
	return str(LootDB.pack_at(i)["id"])


## Los relojes de los eventos que duran (VIP y hora feliz) y de las habilidades.
## Los que hacen APARECER los eventos los lleva la pantalla de juego, que es la
## que sabe si la mesa esta a la vista.
func _tick_play(delta: float) -> void:
	var cambio := false
	if not buyer.is_empty():
		buyer["left"] = float(buyer["left"]) - delta
		if float(buyer["left"]) <= 0.0:
			buyer = {}
			cambio = true
	if not happy.is_empty():
		happy["left"] = float(happy["left"]) - delta
		if float(happy["left"]) <= 0.0:
			happy = {}
			cambio = true
	if cambio:
		events_changed.emit()
	frenzy_left = maxf(0.0, frenzy_left - delta)
	var listas := false
	for id in cooldowns.keys():
		cooldowns[id] = float(cooldowns[id]) - delta
		if float(cooldowns[id]) <= 0.0:
			cooldowns.erase(id)
			listas = true
	if listas:
		abilities_changed.emit()


## Empieza el comprador VIP: un tipo de botin al azar y la nota minima.
func start_buyer() -> void:
	var kinds := LootDB.kind_ids()
	buyer = {"kind": kinds[_rng_play.randi_range(0, kinds.size() - 1)],
		"grade": _rng_play.randi_range(Gameplay.VIP_GRADE.x, Gameplay.VIP_GRADE.y),
		"left": Gameplay.VIP_LIFE}
	events_changed.emit()


## Empieza la hora feliz de un tipo de botin al azar.
func start_happy() -> void:
	var kinds := LootDB.kind_ids()
	happy = {"kind": kinds[_rng_play.randi_range(0, kinds.size() - 1)],
		"left": Gameplay.HAPPY_LIFE}
	events_changed.emit()


# --- habilidades ------------------------------------------------------------ #

func ability_unlocked(id: String) -> bool:
	return skill_owned(id)


func ability_ready(id: String) -> bool:
	return ability_unlocked(id) and not cooldowns.has(id)


func ability_left(id: String) -> float:
	return float(cooldowns.get(id, 0.0))


## Gasta una habilidad (la pone a recargar). Devuelve false si no se puede usar.
## Lo que HACE cada una lo hace quien la usa: el golpe cargado lo cobra el
## siguiente golpe (take_charged), el frenesi lo mira la mesa (frenzy_left) y la
## lupa la aplica la tarjeta de revelado (regrade).
func use_ability(id: String) -> bool:
	if not ability_ready(id):
		return false
	cooldowns[id] = float(Gameplay.ability(id).get("cooldown", 60.0))
	if id == Gameplay.ABIL_CHARGE:
		charged_next = true
	elif id == Gameplay.ABIL_FRENZY:
		frenzy_left = Gameplay.FRENZY_TIME
	abilities_changed.emit()
	return true


## Un golpe perfecto: sube la racha (dos pasos en la zona dorada) y devuelve
## lo que multiplica el dano, con el perfecto, la zona dorada y la racha dentro.
func note_perfect(sweet: bool) -> float:
	streak += 2 if sweet else 1
	perfect_hits += 1
	streak_changed.emit(streak)
	return Gameplay.PERFECT_MULT * (Gameplay.SWEET_MULT if sweet else 1.0) \
			* Gameplay.streak_mult(streak)


## La racha se rompe (se ha pasado un sobre o se ha pulsado antes de tiempo).
func break_streak() -> void:
	if streak == 0:
		return
	streak = 0
	streak_changed.emit(streak)


## El golpe cargado se gasta en el primer golpe que lo pide.
func take_charged() -> float:
	if not charged_next:
		return 1.0
	charged_next = false
	abilities_changed.emit()
	return Gameplay.CHARGE_MULT


## La lupa del tasador: la nota del objeto se vuelve a tirar. El valor se
## escala por lo que vale la nota nueva frente a la vieja (lleva dentro el
## escalon del sobre y los multiplicadores, que no cambian), y el dibujo y la
## insignia de estado se cambian a los de la nota nueva.
func regrade(item: Dictionary) -> Dictionary:
	var nuevo := item.duplicate(true)
	var antes := int(item.get("grade", 1))
	var nota := LootDB.roll_grade(_rng_play)
	nuevo["grade"] = nota
	nuevo["value"] = maxi(1, roundi(float(item.get("value", 1))
			* LootDB.grade_mult(nota) / LootDB.grade_mult(antes)))
	nuevo["condition"] = LootDB.condition_for_grade(nota)
	var art := str(item.get("art", ""))
	var i := art.rfind("_psa")
	if i > 0:
		nuevo["art"] = "%s_psa%d" % [art.substr(0, i), nota]
	return nuevo


# --- album ---------------------------------------------------------------- #

## Un objeto que ha cambiado de nota (la lupa): cuenta para el album y para el
## encargo de nota como si acabara de salir, pero no como un objeto mas.
func note_regrade(item: Dictionary) -> void:
	_album_add(item)
	mission_event("grade", int(item.get("grade", 0)))

func _album_add(item: Dictionary) -> void:
	var key := Gameplay.album_key(item)
	if not Gameplay.album_items().has(key):
		return
	var grade := int(item.get("grade", 1))
	var completas := completed_sets()
	var nuevo := not album.has(key)
	if nuevo or grade > int(album[key]):
		album[key] = grade
		_dirty = true
		album_changed.emit()
	if nuevo:
		notice.emit("NUEVO EN EL ALBUM", Palette.CREAM)
	for set_id in completed_sets():
		if not completas.has(set_id):
			var s := Gameplay.set_by_id(set_id)
			celebrate.emit("COLECCION %s" % s["name"], "%s PARA SIEMPRE" % s["effect"])
			# Una coleccion de huecos de mesa cambia la mesa en el acto.
			items_changed.emit()


## ¿Esta completa esta coleccion? La de PERFECCION pide una nota (cualquier
## objeto con un 10); las demas, todos sus objetos vistos.
func set_complete(set_id: String) -> bool:
	var s := Gameplay.set_by_id(set_id)
	if s.is_empty():
		return false
	if s.has("grade"):
		for key in album:
			if int(album[key]) >= int(s["grade"]):
				return true
		return false
	for key in s["items"]:
		if not album.has(key):
			return false
	return true


func set_progress(set_id: String) -> Vector2i:
	var s := Gameplay.set_by_id(set_id)
	if s.has("grade"):
		return Vector2i(1 if set_complete(set_id) else 0, 1)
	var n := 0
	for key in s["items"]:
		if album.has(key):
			n += 1
	return Vector2i(n, (s["items"] as Array).size())


func completed_sets() -> Array:
	var out: Array = []
	for s in Gameplay.SETS:
		if set_complete(str(s["id"])):
			out.append(str(s["id"]))
	return out


## Lo que suman las colecciones completas a un stat.
func album_bonus(stat: String) -> float:
	var total := 0.0
	for s in Gameplay.SETS:
		if str(s["stat"]) == stat and set_complete(str(s["id"])):
			total += float(s["value"])
	return total


# --- encargos ---------------------------------------------------------------- #

## El premio de un encargo de dificultad media (el de "abre 25 sobres"): lo que
## se enseña cuando todavia no hay encargo concreto. Ver Gameplay.mission_reward.
func mission_reward() -> int:
	return Gameplay.mission_reward({"type": "open_any", "goal": 25}, top_pack_price)


## Rellena los huecos de encargos que falten, sin repetir tipo.
func _fill_missions() -> void:
	var cambio := false
	while missions.size() < Gameplay.MISSION_SLOTS:
		var usados: Array = []
		for m in missions:
			usados.append(str(m["type"]))
		var libres: Array = []
		for t in Gameplay.MISSION_TYPES:
			if not usados.has(str(t["type"])):
				libres.append(t)
		if libres.is_empty():
			break
		var t: Dictionary = libres[_rng_play.randi_range(0, libres.size() - 1)]
		missions.append(Gameplay.make_mission(_rng_play, t, top_pack_price))
		cambio = true
	if cambio:
		_dirty = true
		missions_changed.emit()


## El texto de un encargo, con su objetivo dentro (ver Gameplay.mission_text).
static func mission_text(m: Dictionary) -> String:
	return Gameplay.mission_text(m)


## Algo ha pasado que puede contar para un encargo. `value` es lo que cuenta:
## 1 por sobre, la nota del objeto, etc. Los que se cumplen se cobran solos y
## dejan sitio a uno nuevo.
func mission_event(type: String, value: int, kind: String = "") -> void:
	if missions.is_empty():
		_fill_missions()
	var hechos: Array = []
	var cambio := false
	for m in missions:
		var antes := int(m["progress"])
		if Gameplay.mission_step(m, type, value, kind):
			hechos.append(m)
		if int(m["progress"]) != antes:
			cambio = true
	for m in hechos:
		missions.erase(m)
		add_money(int(m["reward"]))
		notice.emit("ENCARGO CUMPLIDO: +" + PixelNumber.format(int(m["reward"])),
			Palette.GOLD_XL)
	if not hechos.is_empty():
		_fill_missions()
	if cambio or not hechos.is_empty():
		_dirty = true
		missions_changed.emit()


## La mesa que trae un guardado, limpia: fuera los sobres que ya no existan, las
## vidas sin sentido y el botin sin valor. Un guardado de antes de que se guardara
## la mesa no trae la clave y sale vacia, que es lo que habia.
static func _clean_table(raw) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		if d.has("pack"):
			var pack_id := str(d["pack"])
			if LootDB.pack_index(pack_id) == 0 and pack_id != str(LootDB.pack_at(0)["id"]):
				continue
			var max_hp := float(LootDB.pack_hp(pack_id))
			out.append({"pack": pack_id,
				"hp": clampf(float(d.get("hp", max_hp)), 1.0, max_hp)})
		elif d.has("loot") and typeof(d["loot"]) == TYPE_DICTIONARY:
			var item: Dictionary = d["loot"]
			if int(item.get("value", 0)) > 0:
				out.append({"loot": item})
	return out


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


# --- auto guardar ------------------------------------------------------------ #

## ¿Esta comprado el AUTO GUARDAR? Sin el, la fila de Ajustes sale en gris.
func autostore_unlocked() -> bool:
	return skill_owned(SkillTree.QOL_AUTOSTORE)


## ¿Esta trabajando? Comprado Y encendido.
func autostore_active() -> bool:
	return autostore_unlocked() and autostore_on


func set_autostore(on: bool) -> bool:
	if on and not autostore_unlocked():
		return false
	autostore_on = on
	_dirty = true
	settings_changed.emit()
	return true


## ¿Esta marcado este valor en una de las tres listas ("kinds", "grades",
## "rarities")? Las notas se guardan como numero.
func autostore_has(list_name: String, value) -> bool:
	return (_autostore_list(list_name)).has(value)


## Marca o desmarca un valor de una lista. Cada boton del panel es uno.
func autostore_toggle(list_name: String, value) -> void:
	var list := _autostore_list(list_name)
	if list.has(value):
		list.erase(value)
	else:
		list.append(value)
	_dirty = true
	settings_changed.emit()


func _autostore_list(list_name: String) -> Array:
	match list_name:
		"kinds":
			return autostore_kinds
		"grades":
			return autostore_grades
	return autostore_rarities


## ¿Se guarda este objeto? Tiene que estar marcado en las TRES listas.
func autostore_wants(item: Dictionary) -> bool:
	return autostore_kinds.has(LootDB.kind_of(item)) \
			and autostore_grades.has(int(item.get("grade", 0))) \
			and autostore_rarities.has(str(item.get("rarity", "common")))


## Lo que viene marcado de serie: todos los tipos y rarezas y las notas altas
## (8, 9 y 10). Guardar todo de serie llenaria el inventario en un minuto.
func _autostore_defaults() -> void:
	autostore_on = false
	autostore_kinds = LootDB.kind_ids()
	autostore_grades = [8, 9, 10]
	autostore_rarities = Palette.RARITY_ORDER.duplicate()


# --- la ficha del objeto ------------------------------------------------------ #

func set_card_mode(mode: String) -> void:
	card_mode = mode if CARD_MODES.has(mode) else "good"
	_dirty = true
	settings_changed.emit()


## ¿Merece este objeto la ficha grande? En "good": rareza rara o mejor, nota 8 o
## mas, o la primera vez que sale (`is_new`, nuevo en la libreta).
func card_worth(item: Dictionary, is_new: bool) -> bool:
	match card_mode:
		"always":
			return true
		"never":
			return false
	return str(item.get("rarity", "common")) != "common" \
			or int(item.get("grade", 0)) >= CARD_GOOD_GRADE or is_new


const CARD_GOOD_GRADE := 8


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
	_autostore_defaults()
	card_mode = "good"
	music_volume = 0.7
	sfx_volume = 0.45
	fullscreen = false
	carry_damage = 0.0
	lifetime_earned = 0
	packs_opened = 0
	items_found = 0
	best_grade = 0
	table = []
	table_reset.emit()
	album = {}
	missions = []
	top_pack_price = 0
	top_pack_index = 0
	perfect_hits = 0
	buyer = {}
	happy = {}
	cooldowns = {}
	charged_next = false
	streak = 0
	frenzy_left = 0.0
	_dirty = true
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	money_changed.emit(money)
	inventory_changed.emit()
	locker_changed.emit()
	items_changed.emit()
	skills_changed.emit()
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
		"autostore_on": autostore_on,
		"autostore_kinds": autostore_kinds,
		"autostore_grades": autostore_grades,
		"autostore_rarities": autostore_rarities,
		"card_mode": card_mode,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"lifetime_earned": lifetime_earned,
		"packs_opened": packs_opened,
		"items_found": items_found,
		"best_grade": best_grade,
		"table": table,
		"album": album,
		"missions": missions,
		"top_pack_price": top_pack_price,
		"top_pack_index": top_pack_index,
		"perfect_hits": perfect_hits,
	}


func save_game() -> void:
	_dirty = false
	# La foto de la mesa, si hay una partida en pantalla (ver `table`).
	if table_provider.is_valid():
		table = table_provider.call()
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
	# El auto guardar: un guardado de antes no trae nada y sale lo de serie. Las
	# listas se limpian contra lo que existe (JSON devuelve las notas como float).
	_autostore_defaults()
	autostore_on = bool(d.get("autostore_on", false))
	if typeof(d.get("autostore_kinds")) == TYPE_ARRAY:
		autostore_kinds = LootDB.kind_ids().filter(func(k): return (d["autostore_kinds"] as Array).has(k))
	if typeof(d.get("autostore_grades")) == TYPE_ARRAY:
		autostore_grades = []
		for g in d["autostore_grades"]:
			if int(g) >= 1 and int(g) <= LootDB.GRADE_MAX and not autostore_grades.has(int(g)):
				autostore_grades.append(int(g))
	if typeof(d.get("autostore_rarities")) == TYPE_ARRAY:
		autostore_rarities = Palette.RARITY_ORDER.filter(
				func(r): return (d["autostore_rarities"] as Array).has(r))
	card_mode = str(d.get("card_mode", "good"))
	if not CARD_MODES.has(card_mode):
		card_mode = "good"
	music_volume = float(d.get("music_volume", 0.7))
	sfx_volume = float(d.get("sfx_volume", 0.45))
	fullscreen = bool(d.get("fullscreen", false))
	lifetime_earned = int(d.get("lifetime_earned", 0))
	packs_opened = int(d.get("packs_opened", 0))
	items_found = int(d.get("items_found", 0))
	best_grade = int(d.get("best_grade", 0))
	table = _clean_table(d.get("table", []))
	album = {}
	var guardado_album = d.get("album", {})
	if typeof(guardado_album) == TYPE_DICTIONARY:
		for key in guardado_album:
			if Gameplay.album_items().has(str(key)):
				album[str(key)] = clampi(int(guardado_album[key]), 1, 10)
	missions = []
	var guardados_m = d.get("missions", [])
	if typeof(guardados_m) == TYPE_ARRAY:
		for m in guardados_m:
			if typeof(m) == TYPE_DICTIONARY and m.has("type") and m.has("goal"):
				missions.append(m)
	top_pack_price = int(d.get("top_pack_price", 0))
	top_pack_index = int(d.get("top_pack_index", 0))
	perfect_hits = int(d.get("perfect_hits", 0))
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
