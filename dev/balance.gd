# balance - cuanto tarda una partida en llegar al primer rebirth.
#
# EL REBIRTH SE PARA CUANDO TIENE EL DINERO EN EL CONTADOR: el requisito no es
# una meta de lo ganado, es tener LootDB.REBIRTH_REQUIRE a la vez (ver
# Game.can_rebirth), asi que la partida acaba en cuanto el contador los toca. El
# jugador modelado gasta en sobres y mejoras como siempre hasta ese momento, que
# es lo que hace el que juega rapido: reiniciar en cuanto se puede. Si alguna vez
# deja de cuadrar con la partida de verdad, lo primero que hay que mirar es esa
# decision (no el resto de la simulacion, que no depende del requisito): el
# jugador de verdad, al ver lo que le falta, deja de comprar y llega ANTES de lo
# que dice esta herramienta.
#
# LA CIFRA DEL REQUISITO (hoy 150.000) SALIO DE AQUI, barriendo: con 100.000 el
# normal llegaba en 14,2 min, con 120.000 en 14,9 y con 130.000 en 15,5. Con el
# gameplay nuevo (ver _gp_events y "clasico") bajaba a menos de doce y se volvio
# a barrer: margen de los sobres a 2,06 y requisito a 150.000 dan 14,7. El
# objetivo es que la PRIMERA MONEDA de rebirth caiga sobre los quince minutos y
# que por el camino se note que se va comprando: eso lo mide el informe del
# RITMO (cuando se abre cada escalon y el rato mas largo sin comprar nada).
# ESTE FICHERO ES LA HERRAMIENTA DE MEDIDA DEL EQUILIBRIO, no un adorno. Que la
# partida dure lo que tiene que durar (un cuarto de hora largo hasta poder
# menos si se juega bien) no se comprueba mirando capturas: se comprueba
# contando. Aqui se simula la partida entera con las formulas y los DATOS de
# verdad -LootDB.pack_payout, roll_pack, damage_per_hit, charge_time,
# item_cost...-, asi que cambiar un precio o una vida y volver a correr esto
# dice en un par de segundos que ha pasado.
#
#   $G --headless --path . res://dev/BalanceTest.tscn
#
# QUE MODELA Y QUE NO
# -------------------
# Modela el bucle: comprar el sobre mas caro que te llega, golpearlo hasta
# abrirlo, cobrar el botin y volver a empezar, comprando mejoras por el camino.
# El reloj es la suma del tiempo de cada accion: los ciclos de carga (mas el
# hueco entre clic y clic), la tarjeta de revelado y las compras.
#
# NO modela el raton ni la interfaz: no hay clics que fallan, ni dudas, ni
# cansancio. Por eso sus tiempos son un SUELO: una persona puede hacer lo mismo
# que dice aqui, pero no mas rapido.## LAS TRES FORMAS DE JUGAR
## ------------------------
##   normal      compra el sobre mas caro que puede y, cuando la mejora le
##               "cabe" en el bolsillo, la paga: hasta el 30 % de lo que lleva
##               en cada compra. Clic normal (0,35 s entre golpes) y lee la
##               tarjeta (1,6 s).
##   optimizado  ademas de jugar mas rapido (clic de 0,20 s y tarjeta en 1,1 s),
##               COMPRA MEJOR: gasta como mucho un 20 % del dinero de una vez, que
##               es lo que midio el barrido de _sweep_shares() con la barra a
##               1,65 s, y expone los vinilos en el armario para multiplicar lo que
##               cobra.
##   automatico  como el optimizado, pero ademas compra el PC y los Pinchos: la
##               mesa se abre sola y no hay tarjeta (venta automatica). Su ritmo
##               lo pone el dano repartido de los Pinchos.
##
## El "share" es la palanca mas gorda que tiene el jugador y no se ve: gastar de
## golpe el 55 % del dinero en mejoras se come el margen de los sobres (entre un 30 y un 45 %) y
## deja la partida bastante mas lenta; el que compra a tirones llega antes. Es lo
## que modela el jugador "optimizado" con su share del 20 %.
##
## El 20 % no es un numero de gusto: el barrido (BalanceTest "shares") da 25,2 /
## 19,1 / 15,1 / 15,7 / 20,1 minutos para gastar el 5, 10, 20, 35 y 55 % de una
## vez. Antes de frenar la barra el optimo estaba en el 12 %; con la carga a
## 1,65 s cada golpe pesa mas y subir el dano pronto paga mas que guardar el
## dinero, asi que el optimo se movio al 20 %. Si se vuelve a tocar el ritmo de
## la carga, hay que volver a pasar el barrido.
#
# El "sin suerte" que se imprime al final es el mismo jugador normal con el
# botin fijo en su media (LootDB.pack_payout): lo que se separa de la mediana es
# lo que decide el dado.
extends Node

## Tope de simulacion: dos horas. Una partida que no llegue al rebirth en ese
## rato es que no llega, y hay que enterarse en vez de esperar para siempre.
const CAP := 7200.0
## Banda en la que tiene que caer el jugador NORMAL. Es la promesa del juego:
## "un cuarto de hora largo". El optimizado cae por debajo y el que juega mal
## por encima, y eso esta bien: lo que no vale es que la partida se acabe en un
## suspiro. La banda se abrio de 20-30 a 15-25 al bajar la vida de los sobres y
## poner las Tijeras de daño baratas al principio: se pidio que al principio no
## se arrastrara y que el juego pudiera ir un poco mas rapido.
##
## CON LA BARRA FRENADA se quedo al filo por abajo: con el daño base x2,5 y la
## carga x3, el dano por segundo subia tanto que el jugador normal bajaba a
## once minutos, y la mesa de los Guantes lo aceleraba mas todavia. La vida de
## los sobres volvio a subir (la curva paso de 14,3 a 21,5 x raiz(precio), ver
## loot_db) hasta devolver al normal a ~17 min dentro de la banda: es la palanca
## que el README manda tocar cuando la partida dura demasiado poco.
##
## Y SE CENTRO EN LOS QUINCE MINUTOS: se pidio que la primera moneda de rebirth
## caiga sobre el cuarto de hora y que por el camino se note que se va
## comprando. La banda es de 12 a 19 (quince con margen por los dos lados): por
## debajo la primera moneda llega sin haber jugado, y por encima vuelve el atasco.
const BAND := Vector2(12.0, 19.0)
## Paso de la simulacion automatica (segundos). Con la mesa abriendose sola el
## tiempo va en tirones: mas fino no cambia nada y multiplica el rato de espera.
const AUTO_STEP := 0.25

const STRATEGIES: Array = [
	{
		"id": "normal", "click": 0.35, "card": 1.6, "share": 0.30, "auto": false,
		"locker": false, "perfect": 0.30, "catch": 0.8,
		"order": ["tijeras", "guantes", "trebol", "cajon", "ojo_verde", "laser",
			"pc", "pinchos", "armario"],
	},
	{
		"id": "optimizado", "click": 0.20, "card": 1.1, "share": 0.20, "auto": false,
		"locker": true, "perfect": 0.60, "catch": 1.0,
		"order": ["tijeras", "guantes", "trebol", "cajon", "ojo_verde", "laser",
			"pc", "pinchos", "armario"],
	},
	{
		"id": "automatico", "click": 0.20, "card": 0.0, "share": 0.20, "auto": true,
		"locker": true, "perfect": 0.60, "catch": 1.0,
		"order": ["tijeras", "guantes", "trebol", "cajon", "ojo_verde", "laser",
			"pc", "pinchos", "armario"],
	},
]
## Lo que tarda la compra automatica entre sobre y sobre (LootDB.AUTO_BUY_INTERVAL)
## y los sobres que caben en la mesa sin Cajon.
const AUTO_BUY := 0.75

## EL GAMEPLAY DE LA RAMA "gameplay" (ver scripts/data/gameplay.gd): golpes
## perfectos, sobre dorado, comprador VIP, hora feliz, encargos y album. Todo eso
## mete dinero o dano por fuera del bucle de siempre, asi que la partida se
## simula CON ello (es lo que va a jugar la gente) y la banda se mide asi. Con
## "clasico" en la linea de comandos se apaga, para comparar con la de antes.
##
## Cada jugador lleva dos cifras mas: "perfect" es la parte de sus golpes que
## caen en el ultimo trozo del anillo (el normal acierta uno de cada tres, el
## optimizado mas de la mitad, y el automatico igual mientras juega a mano: los
## Pinchos no aciertan nunca) y "catch" la parte
## de los sobres dorados que llega a coger antes de que se vayan.
## Las habilidades no entran: se compran en el arbol del rebirth, asi que en la
## primera partida no hay ninguna.
var gameplay := true
var _gp: Dictionary = {}
## Para medir cada pieza por separado: "sin_dorado", "sin_vip", "sin_feliz",
## "sin_encargos", "sin_perfecto" y "sin_album" en la linea de comandos apagan
## esa sola cosa.
var _off: Array = []


## Una partida entera: devuelve los minutos, los sobres abiertos, los niveles
## comprados y lo que se fue en la tienda.
func simulate(strategy: int, seed_value: int, fixed_loot: bool = false,
		trace: bool = false, share: float = -1.0) -> Dictionary:
	var st: Dictionary = STRATEGIES[strategy].duplicate()
	if share >= 0.0:
		st["share"] = share
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var money := Game.START_MONEY
	var levels: Array = []
	for i in LootDB.item_count():
		levels.append(0)
	var t := 0.0
	var earned := 0
	var opened := 0
	var spent := 0
	var paid := 0
	var income := 0
	var rungs: Dictionary = {}
	var locker: Array = []
	var table: Array = []
	var buy_left := 0.0
	# EL RITMO, ademas del minuto final: cuando se abre por primera vez cada sobre
	# (los escalones que se van desbloqueando) y el rato mas largo que pasa sin
	# comprar ninguna mejora. Es lo que dice si "se nota que vas mejorando": una
	# partida de quince minutos con diez minutos seguidos sin comprar nada es una
	# partida de quince minutos que se hace larga.
	var first_open: Dictionary = {}
	var last_buy := 0.0
	var max_gap := 0.0
	var first_buy := -1.0
	_gp_reset(st, seed_value)
	# SE PARA CUANDO EL CONTADOR LLEGA AL REQUISITO, que es la regla del rebirth
	# desde que su requisito se mide en el dinero que TIENES y no en lo ganado (ver
	# Game.can_rebirth). El requisito de la partida no es "hacer tal cosa": es
	# "tener tanto dinero a la vez" (LootDB.REBIRTH_REQUIRE), asi que este bucle
	# mira `money` y no `earned`, que se sigue llevando solo para el informe.
	while money < LootDB.REBIRTH_REQUIRE and t < CAP:
		if trace and opened % 10 == 0:
			print("    %6.1f min  dinero %9d  niveles %2d  sobres %4d  ahora %s"
				% [t / 60.0, money, LootDB.total_levels(levels), opened,
					_best_pack(money)])
		var price := 0
		if bool(st["auto"]) and LootDB.item_level(levels, "pinchos") > 0 \
				and LootDB.item_level(levels, "pc") > 0:
			_gp["t"] = t
			var spin := _step_auto(st, levels, locker, table, buy_left, AUTO_STEP,
				money, earned, opened, rungs, rng, fixed_loot, paid, income)
			t += AUTO_STEP
			money = int(spin["money"])
			earned = int(spin["earned"])
			opened = int(spin["opened"])
			buy_left = float(spin["buy_left"])
			paid += int(spin["paid"])
			income += int(spin["income"])
		else:
			var pack_id := _best_pack(money)
			price = int(LootDB.pack_by_id(pack_id)["price"])
			money -= price
			_gp_bought(pack_id, price)
			t += _pack_seconds(levels, pack_id, st)
			_gp["t"] = t
			var gain := _loot(levels, locker, pack_id, st, rng, fixed_loot)
			money += gain
			earned += gain
			opened += 1
			paid += price
			income += gain
			rungs[pack_id] = int(rungs.get(pack_id, 0)) + 1
			if not first_open.has(pack_id):
				first_open[pack_id] = t
		# Los eventos que han tocado en este rato y los encargos que se han cumplido.
		var extra := _gp_events(st, levels, locker, rng, fixed_loot, t)
		money += int(extra["money"])
		earned += int(extra["money"])
		income += int(extra["money"])
		opened += int(extra["opened"])
		t += float(extra["seconds"])
		var buy := _shop(st, levels, money)
		money = int(buy["money"])
		spent += int(buy["spent"])
		if int(buy["spent"]) > 0:
			if first_buy < 0.0:
				first_buy = t
			max_gap = maxf(max_gap, t - last_buy)
			last_buy = t
	if money < LootDB.REBIRTH_REQUIRE:
		return {"minutes": INF, "packs": opened, "spent": spent, "levels": 0}
	max_gap = maxf(max_gap, t - last_buy)
	var roi := float(income) / float(paid) if paid > 0 else 0.0
	return {"minutes": t / 60.0, "packs": opened, "spent": spent,
		"levels": LootDB.total_levels(levels), "roi": roi, "rungs": rungs,
		"first_open": first_open, "max_gap": max_gap / 60.0,
		"first_buy": first_buy / 60.0, "gp": _gp.duplicate()}


## Los paquetes de una partida automatica: los Pinchos reparten su dano entre los
## que hay en la mesa, y la compra automatica mete uno cada 0,75 s.
func _step_auto(st: Dictionary, levels: Array, locker: Array, table: Array,
		buy_left: float, dt: float, money: int, earned: int, opened: int,
		rungs: Dictionary, rng: RandomNumberGenerator, fixed_loot: bool,
		paid: int, income: int) -> Dictionary:
	var dps := LootDB.spike_dps(levels, float(money))
	var n := maxi(1, table.size())
	for i in table.size():
		var row: Array = table[i]
		row[0] = float(row[0]) - dps * dt / float(n)
	var done: Array = []
	for row in table:
		if float(row[0]) <= 0.0:
			done.append(row)
	for row in done:
		table.erase(row)
		var gain := _loot(levels, locker, str(row[1]), st, rng, fixed_loot)
		money += gain
		earned += gain
		income += gain
		opened += 1
		rungs[str(row[1])] = int(rungs.get(str(row[1]), 0)) + 1
	buy_left -= dt
	if buy_left <= 0.0:
		buy_left = AUTO_BUY
		if table.size() < LootDB.table_slots(levels):
			var pack_id := _best_pack(money)
			var price := int(LootDB.pack_by_id(pack_id)["price"])
			if price <= money:
				money -= price
				paid += price
				_gp_bought(pack_id, price)
				table.append([float(LootDB.pack_hp(pack_id)) / maxf(0.001, dps), pack_id])
	return {"money": money, "earned": earned, "opened": opened,
		"buy_left": buy_left, "paid": paid, "income": income}


## El sobre mas caro que se puede pagar: es lo que hace un jugador que quiere
## subir, y lo que hace buena a la columna. Sin dinero para ninguno, el gratuito.
##
## El gratuito tambien cuenta para el jugador que se queda sin blanca: la compra
## automatica lo SALTA (game.gd, _auto_buy_step()) pero el jugador lo puede
## coger a mano cuando quiere, y sin eso una partida sin dinero se quedaria
## parada para siempre.
func _best_pack(money: int) -> String:
	var best := ""
	var best_price := -1
	for i in LootDB.pack_count():
		var p: Dictionary = LootDB.pack_at(i)
		var price := int(p["price"])
		if price > 0 and price <= money and price > best_price:
			best_price = price
			best = str(p["id"])
	return best if best != "" else "cards"


## Segundos que cuesta abrir un sobre: un ciclo de carga por golpe, mas el hueco
## entre clic y clic, mas la tarjeta de revelado. El critico va dentro del dano
## medio, que es lo que se nota a lo largo de una partida.
func _pack_seconds(levels: Array, pack_id: String, st: Dictionary) -> float:
	var hit := _average_hit(levels) * _perfect_factor(st)
	var hits := int(ceil(float(LootDB.pack_hp(pack_id)) / maxf(0.001, hit)))
	if gameplay:
		_gp["perfect_acc"] = float(_gp.get("perfect_acc", 0.0)) \
				+ float(hits) * float(st.get("perfect", 0.0))
	return float(hits) * _cycle(levels, st) + float(st["card"])


## Lo que da de mas, de media, acertar el golpe perfecto: la parte de golpes que
## caen en el ultimo trozo del anillo pegan PERFECT_MULT veces.
func _perfect_factor(st: Dictionary) -> float:
	if not gameplay or _off.has("perfecto"):
		return 1.0
	return 1.0 + float(st.get("perfect", 0.0)) * (Gameplay.PERFECT_MULT - 1.0)


## Segundos por golpe (un ciclo de carga + el clic que lo arranca), con el
## cupo de la mesa dentro.
##
## Con UN paquete en el aire el ciclo es carga + clic: el paquete se queda
## esperando a que el jugador vuelva a pulsarlo y ese hueco se paga entero.
##
## Con varios en el aire el hueco del clic se ESCONDE: mientras uno carga, el
## jugador esta pulsando el otro. Pero los clics no son gratis y el jugador no
## tiene mas que dos manos: si lleva k paquetes, cada uno recibe un clic cada k
## huecos, y su ciclo no baja de k x clic. El mejor numero de paquetes en el aire
## -y por tanto lo que valen de verdad los huecos de la mesa- es el primero que
## tapa la carga, y a partir de ahi subir el cupo (el Cajon) no da nada. Por eso
## el ciclo se queda con el MEJOR k que quepa en la mesa, no con el que tienes.
func _cycle(levels: Array, st: Dictionary) -> float:
	var charge := LootDB.charge_time(levels)
	if gameplay and not _off.has("perfecto"):
		# El golpe perfecto llega antes: se pulsa entre PERFECT_FROM y el final del anillo.
		charge *= 1.0 - float(st.get("perfect", 0.0)) * (1.0 - (1.0 + Gameplay.PERFECT_FROM) * 0.5)
		charge /= 1.0 + _album_bonus("speed")
	var click := float(st["click"])
	var best := charge + click
	var slots := LootDB.table_slots(levels) + int(_album_bonus("table"))
	var k := 2
	while k <= slots:
		best = minf(best, maxf(charge, float(k) * click))
		k += 1
	return best


func _average_hit(levels: Array) -> float:
	var crit := (LootDB.crit_chance(levels) + _album_bonus("crit")) \
			* (LootDB.crit_mult(levels) - 1.0)
	return LootDB.damage_per_hit(levels) * (1.0 + crit) * (1.0 + _album_bonus("damage"))


## Lo que paga un sobre: el botin de verdad (roll_pack, con su rareza y su nota)
## o, en la pasada "sin suerte", su valor medio (pack_payout).
func _loot(levels: Array, locker: Array, pack_id: String, st: Dictionary,
		rng: RandomNumberGenerator, fixed_loot: bool) -> int:
	var mult := 1.0
	for item in locker:
		mult += LootDB.bonus_for(item)
	mult *= 1.0 + _album_bonus("money")
	_gp_mission("open", 1, pack_id.rstrip("0123456789"))
	if fixed_loot:
		return int(round(LootDB.pack_payout(pack_id) * mult))
	var loot := LootDB.roll_pack(rng, pack_id, LootDB.luck(levels), mult)
	return _gp_sell(_keep(levels, locker, loot, st))


## El armario (ver _loot): devuelve el objeto tal cual, para cobrarlo.
func _keep(levels: Array, locker: Array, loot: Dictionary, st: Dictionary) -> Dictionary:
	# El armario: el que lo mira expone los mejores vinilos que ha encontrado
	# -los vinilos son el tipo que sube el DINERO-, hasta llenar sus huecos.
	if bool(st["locker"]) and LootDB.item_level(levels, "armario") > 0 \
			and str(loot["kind"]) == "vinyls":
		locker.append(loot)
		if locker.size() > LootDB.locker_slots(levels):
			var worst := 0
			for i in locker.size():
				if LootDB.bonus_for(locker[i]) < LootDB.bonus_for(locker[worst]):
					worst = i
			locker.remove_at(worst)
	return loot


# --------------------------------------------------------------------------- #
# El gameplay nuevo (eventos, encargos, album y golpe perfecto)
# --------------------------------------------------------------------------- #
# Copia de las reglas de Game (payout, mission_event, _album_add...) en pequeno,
# sin la interfaz: lo que pasa, cuando pasa y lo que paga. Lleva su propio dado
# (semilla + 7777) para que encender o apagar esto no cambie el botin de los
# sobres de siempre y las dos partidas se puedan comparar sobre la misma suerte.

func _gp_reset(st: Dictionary, seed_value: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + 7777
	_gp = {"rng": r, "t": 0.0, "top_price": 0, "top_index": 0,
		"golden_at": Gameplay.GOLDEN_FIRST, "vip_at": Gameplay.VIP_FIRST,
		"happy_at": Gameplay.HAPPY_FIRST, "buyer": {}, "happy": {},
		"missions": [], "pending": 0, "perfect_acc": 0.0, "perfect_done": 0,
		"album": {}, "bonus": {}, "perfect10": false,
		"golden_n": 0, "golden_money": 0, "vip_n": 0, "vip_money": 0,
		"happy_money": 0, "missions_n": 0, "missions_money": 0, "sets": [],
		"auto": bool(st["auto"])}
	if gameplay:
		_gp_fill_missions()


func _gp_bought(pack_id: String, price: int) -> void:
	if price > int(_gp.get("top_price", 0)):
		_gp["top_price"] = price
		_gp["top_index"] = LootDB.pack_index(pack_id)


func _album_bonus(stat: String) -> float:
	if not gameplay or _gp.is_empty() or _off.has("album"):
		return 0.0
	return float(_gp["bonus"].get(stat, 0.0))


## Lo que cobra un objeto al venderlo, con la hora feliz y el VIP dentro, y lo
## que eso cuenta para el album y los encargos.
func _gp_sell(loot: Dictionary) -> int:
	var value := int(loot["value"])
	if not gameplay:
		return value
	_gp_album(loot)
	var t := float(_gp["t"])
	var kind := LootDB.kind_of(loot)
	var happy: Dictionary = _gp["happy"]
	if not _off.has("feliz") and not happy.is_empty() and t < float(happy["until"]) and str(happy["kind"]) == kind:
		var extra := roundi(float(value) * (Gameplay.HAPPY_MULT - 1.0))
		_gp["happy_money"] = int(_gp["happy_money"]) + extra
		value += extra
	var buyer: Dictionary = _gp["buyer"]
	if not _off.has("vip") and not buyer.is_empty() and t < float(buyer["until"]) and str(buyer["kind"]) == kind \
			and int(loot["grade"]) >= int(buyer["grade"]):
		var extra := roundi(float(value) * (Gameplay.VIP_MULT - 1.0))
		_gp["vip_money"] = int(_gp["vip_money"]) + extra
		_gp["vip_n"] = int(_gp["vip_n"]) + 1
		value += extra
		_gp["buyer"] = {}
		_gp_mission("vip", 1)
	_gp_mission("grade", int(loot["grade"]))
	return value


func _gp_album(loot: Dictionary) -> void:
	var album: Dictionary = _gp["album"]
	album[Gameplay.album_key(loot)] = true
	if int(loot["grade"]) >= 10:
		_gp["perfect10"] = true
	var bonus: Dictionary = {}
	var sets: Array = []
	for s in Gameplay.SETS:
		var done := true
		if (s["items"] as Array).is_empty():
			done = bool(_gp["perfect10"])
		for key in s["items"]:
			if not album.has(str(key)):
				done = false
		if done:
			sets.append(str(s["id"]))
			bonus[str(s["stat"])] = float(bonus.get(str(s["stat"]), 0.0)) + float(s["value"])
	_gp["bonus"] = bonus
	_gp["sets"] = sets


func _gp_fill_missions() -> void:
	var missions: Array = _gp["missions"]
	var r: RandomNumberGenerator = _gp["rng"]
	while missions.size() < Gameplay.MISSION_SLOTS:
		var usados: Array = []
		for m in missions:
			usados.append(str(m["type"]))
		var libres: Array = []
		for ty in Gameplay.MISSION_TYPES:
			if not usados.has(str(ty["type"])):
				libres.append(ty)
		var ty: Dictionary = libres[r.randi_range(0, libres.size() - 1)]
		var kinds := LootDB.kind_ids()
		missions.append({"type": str(ty["type"]), "goal": int(ty["goal"]), "progress": 0,
			"reward": maxi(Gameplay.REWARD_MIN,
				roundi(float(_gp["top_price"]) * Gameplay.REWARD_PACKS)),
			"kind": kinds[r.randi_range(0, kinds.size() - 1)]})


## Game.mission_event en pequeno: lo cumplido se apunta en "pending" y lo cobra
## la vuelta del bucle (ver _gp_events).
func _gp_mission(type: String, value: int, kind: String = "") -> void:
	if not gameplay or _gp.is_empty():
		return
	var missions: Array = _gp["missions"]
	var hechos: Array = []
	for m in missions:
		var ty := str(m["type"])
		if ty == "grade":
			if type == "grade" and value >= int(m["goal"]):
				m["progress"] = 1
		elif ty == "open_kind":
			if type == "open" and kind == str(m["kind"]):
				m["progress"] = int(m["progress"]) + value
		elif (ty == "open_any" and type == "open") or ty == type:
			m["progress"] = int(m["progress"]) + value
		if int(m["progress"]) >= (1 if ty == "grade" else int(m["goal"])):
			hechos.append(m)
	for m in hechos:
		missions.erase(m)
		_gp["pending"] = int(_gp["pending"]) + int(m["reward"])
		_gp["missions_n"] = int(_gp["missions_n"]) + 1
		_gp["missions_money"] = int(_gp["missions_money"]) + int(m["reward"])
	if not hechos.is_empty():
		_gp_fill_missions()


## Lo que ha pasado hasta el segundo `t`: aparecen los eventos que tocan, se abre
## el sobre dorado (si se llega a tiempo) y se cobran los encargos cumplidos.
## Devuelve el dinero, los sobres y los segundos de mas.
func _gp_events(st: Dictionary, levels: Array, locker: Array,
		rng: RandomNumberGenerator, fixed_loot: bool, t: float) -> Dictionary:
	var out := {"money": 0, "opened": 0, "seconds": 0.0}
	if not gameplay:
		return out
	var r: RandomNumberGenerator = _gp["rng"]
	# Los golpes perfectos de los sobres abiertos, de uno en uno al encargo.
	var perfect := int(floor(float(_gp["perfect_acc"])))
	if perfect > int(_gp["perfect_done"]):
		_gp_mission("perfect", perfect - int(_gp["perfect_done"]))
		_gp["perfect_done"] = perfect
	var kinds := LootDB.kind_ids()
	while t >= float(_gp["vip_at"]):
		_gp["buyer"] = {"kind": kinds[r.randi_range(0, kinds.size() - 1)],
			"grade": r.randi_range(Gameplay.VIP_GRADE.x, Gameplay.VIP_GRADE.y),
			"until": float(_gp["vip_at"]) + Gameplay.VIP_LIFE}
		_gp["vip_at"] = float(_gp["vip_at"]) + Gameplay.between(r, Gameplay.VIP_EVERY)
	while t >= float(_gp["happy_at"]):
		_gp["happy"] = {"kind": kinds[r.randi_range(0, kinds.size() - 1)],
			"until": float(_gp["happy_at"]) + Gameplay.HAPPY_LIFE}
		_gp["happy_at"] = float(_gp["happy_at"]) + Gameplay.between(r, Gameplay.HAPPY_EVERY)
	while t >= float(_gp["golden_at"]):
		_gp["golden_at"] = float(_gp["golden_at"]) + Gameplay.between(r, Gameplay.GOLDEN_EVERY)
		if r.randf() >= float(st.get("catch", 1.0)) or _off.has("dorado"):
			continue
		var i := clampi(maxi(int(_gp["top_index"]) + Gameplay.GOLDEN_STEP, 1), 0,
				LootDB.pack_count() - 1)
		var pack_id := str(LootDB.pack_at(i)["id"])
		if bool(st["auto"]) and LootDB.item_level(levels, "pinchos") > 0 \
				and LootDB.item_level(levels, "pc") > 0:
			out["seconds"] = float(out["seconds"]) + float(LootDB.pack_hp(pack_id)) \
					/ maxf(0.001, LootDB.spike_dps(levels, float(LootDB.REBIRTH_REQUIRE) * 0.5))
		else:
			out["seconds"] = float(out["seconds"]) + _pack_seconds(levels, pack_id, st)
		var gain := _gp_golden_loot(levels, locker, pack_id, rng, fixed_loot)
		_gp_mission("golden", 1)
		_gp["golden_n"] = int(_gp["golden_n"]) + 1
		_gp["golden_money"] = int(_gp["golden_money"]) + gain
		out["money"] = int(out["money"]) + gain
		out["opened"] = int(out["opened"]) + 1
	if not _off.has("encargos"):
		out["money"] = int(out["money"]) + int(_gp["pending"])
	_gp["pending"] = 0
	return out


## El botin del sobre dorado: el del sobre, con la nota subida al minimo dorado
## a base de volver a tirarla (como hace game.gd con Game.regrade).
func _gp_golden_loot(levels: Array, locker: Array, pack_id: String,
		rng: RandomNumberGenerator, fixed_loot: bool) -> int:
	var mult := 1.0
	for item in locker:
		mult += LootDB.bonus_for(item)
	mult *= 1.0 + _album_bonus("money")
	_gp_mission("open", 1, pack_id.rstrip("0123456789"))
	if fixed_loot:
		# La media de las notas del 7 al 10 contra la media de todas.
		var top := 0.0
		var top_w := 0.0
		var all := 0.0
		var all_w := 0.0
		for g in range(1, LootDB.GRADE_WEIGHTS.size() + 1):
			var w := float(LootDB.GRADE_WEIGHTS[g - 1])
			all += w * LootDB.grade_mult(g)
			all_w += w
			if g >= Gameplay.GOLDEN_MIN_GRADE:
				top += w * LootDB.grade_mult(g)
				top_w += w
		return roundi(LootDB.pack_payout(pack_id) * mult * (top / top_w) / (all / all_w))
	var loot := LootDB.roll_pack(rng, pack_id, LootDB.luck(levels), mult)
	var r: RandomNumberGenerator = _gp["rng"]
	var vueltas := 0
	while int(loot["grade"]) < Gameplay.GOLDEN_MIN_GRADE and vueltas < 200:
		var g := LootDB.roll_grade(r)
		loot["value"] = maxi(1, roundi(float(loot["value"]) * LootDB.grade_mult(g)
				/ LootDB.grade_mult(int(loot["grade"]))))
		loot["grade"] = g
		vueltas += 1
	return _gp_sell(loot)


## La tienda: una mejora por vuelta, la primera del orden que le llega al
## bolsillo (y que no se lleve mas de una fraccion del dinero, que el dinero
## tambien hace falta para sobres).
func _shop(st: Dictionary, levels: Array, money: int) -> Dictionary:
	for item_id in st["order"]:
		var idx := LootDB.item_index(str(item_id))
		if idx < 0:
			continue
		var cost := LootDB.item_cost(idx, LootDB.item_level(levels, str(item_id)))
		if cost < 0 or float(cost) > float(money) * float(st["share"]):
			continue
		levels[idx] = int(levels[idx]) + 1
		if OS.get_cmdline_args().has("buys"):
			print("      compra %-9s nv%d  %7d  (dinero %d)" % [item_id, int(levels[idx]), cost, money])
		return {"money": money - cost, "spent": cost}
	return {"money": money, "spent": 0}


# --------------------------------------------------------------------------- #
# El informe
# --------------------------------------------------------------------------- #

func _ready() -> void:
	# Con "trace" en la linea de comandos, ademas del informe saca la vida de
	# una partida (dinero, niveles y sobre de cada momento) para ver DONDE se
	# pierde el rato. Es lo que se mira cuando un jugador sale mas lento de lo que
	# deberia -el optimizado, sin ir mas lejos-: el informe da el minuto final,
	# esto da el camino.
	#
	# Con "buys" la traza dice ademas CADA mejora que compra el jugador (que, que
	# nivel, cuanto y con cuanto dinero en el bolsillo): es lo que se mira cuando
	# el informe del ritmo dice que hay un rato largo sin comprar nada.
	#   $G --headless --path . res://dev/BalanceTest.tscn trace buys
	var args := OS.get_cmdline_args()
	if args.has("clasico"):
		gameplay = false
	for a in args:
		if str(a).begins_with("sin_"):
			_off.append(str(a).substr(4))
	if args.has("trace"):
		for i in STRATEGIES.size():
			print("traza de %s (semilla 0):" % STRATEGIES[i]["id"])
			simulate(i, 0, false, true)
	if args.has("shares"):
		_sweep_shares()

	report()
	get_tree().quit(0)


func report(runs: int = 25) -> void:
	_packs_report()
	print("EQUILIBRIO: minutos hasta el primer rebirth (%d partidas por jugador)"
		% runs)
	for i in STRATEGIES.size():
		var times: Array = []
		var packs := 0
		var levels := 0
		var spent := 0
		for seed_value in runs:
			var r := simulate(i, seed_value)
			if float(r["minutes"]) < INF:
				times.append(float(r["minutes"]))
				packs += int(r["packs"])
				levels += int(r["levels"])
				spent += int(r["spent"])
		if times.is_empty():
			print("  %-11s no llega al rebirth en dos horas" % STRATEGIES[i]["id"])
			continue
		times.sort()
		print("  %-11s mediana %5.1f min   el 80 %% central [%4.1f .. %4.1f]   sobres %4d   niveles %2d   tienda %8d"
			% [STRATEGIES[i]["id"], _median(times), _quantile(times, 0.1),
				_quantile(times, 0.9), packs / times.size(), levels / times.size(),
				spent / times.size()])
	if runs >= 25:
		_rungs_report(0, runs)
		_pace_report(0, runs)
		_gameplay_report(0, runs)
	# La misma partida con el botin puesto en su MEDIA, sin dado. Lo que se separa
	# de la mediana de arriba es lo que decide la suerte, y estas son las cifras
	# que puede comprobar un test sin volverse loco (ver fixed_minutes()).
	print("  sin dado (botin en su media):")
	for i in STRATEGIES.size():
		print("    %-11s %5.1f min" % [STRATEGIES[i]["id"], fixed_minutes(i)])
	var normal := _normal_median(runs)
	var verdict := "OK" if normal >= BAND.x and normal <= BAND.y else "FUERA DE BANDA"
	print("  -> jugador normal %.1f min, banda %.0f-%.0f: %s"
		% [normal, BAND.x, BAND.y, verdict])


## Lo que paga cada sobre de media, contra lo que cuesta. Es el otro extremo del
## equilibrio: si un sobre paga mas de lo que cobra, subir de escalon es
## obligatorio; si paga menos, nadie sube y la partida se queda en el escalon de
## abajo. La columna "x precio" deberia quedarse en el margen de la partida (un
## 15 %) en los doce sobres, y el tiempo de apertura dice si el escalon caro
## cuesta mas rato por el mismo dinero.
func _packs_report() -> void:
	print("SOBRES: lo que pagan y lo que tardan (sin items, un ciclo de 1,65 s)")
	for i in LootDB.pack_count():
		var p: Dictionary = LootDB.pack_at(i)
		var pack_id := str(p["id"])
		var price := int(p["price"])
		var payout := LootDB.pack_payout(pack_id)
		var hits := int(ceil(float(LootDB.pack_hp(pack_id)) / LootDB.BASE_DAMAGE))
		print("  %-13s precio %9d   paga %11d   x precio %5.2f   %3d golpes  %5.1f s"
			% [pack_id, price, roundi(payout),
				(float(payout) / float(price)) if price > 0 else 0.0, hits,
				float(hits) * LootDB.CHARGE_TIME])


## Que sobres abre de verdad el jugador normal, sumando todas las partidas. Si
## la fila del sobre GRATUITO se lleva una tajada, es que la partida se atasca en
## el escalon de abajo y el jugador se pasa el rato dandole al boton por calderilla.
func _rungs_report(strategy: int, runs: int) -> void:
	var total: Dictionary = {}
	var packs := 0
	for seed_value in runs:
		var r := simulate(strategy, seed_value)
		if float(r["minutes"]) >= INF:
			continue
		var rungs: Dictionary = r["rungs"]
		for key in rungs:
			total[key] = int(total.get(key, 0)) + int(rungs[key])
		packs += int(r["packs"])
	var rows: Array = []
	for key in total:
		rows.append([key, total[key]])
	rows.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var line := "  sobres del jugador normal: "
	for row in rows.slice(0, 6):
		line += "%s %d%%   " % [row[0], roundi(100.0 * float(row[1]) / float(maxi(1, packs)))]
	print(line)


## EL RITMO del jugador normal: en que minuto abre por primera vez cada sobre
## (la mediana de las partidas que llegan a abrirlo) y el rato mas largo que se
## pasa sin comprar ninguna mejora. El minuto final dice cuanto dura la partida;
## esto dice si se hace larga. Un escalon que tarda diez minutos en llegar despues
## del anterior, o cinco minutos seguidos sin nada que comprar, es una partida que
## se atasca aunque el total salga en la banda.
func _pace_report(strategy: int, runs: int) -> void:
	var firsts: Dictionary = {}
	var gaps: Array = []
	var first_buys: Array = []
	for seed_value in runs:
		var r := simulate(strategy, seed_value)
		if float(r["minutes"]) >= INF:
			continue
		gaps.append(float(r["max_gap"]))
		first_buys.append(float(r["first_buy"]))
		var fo: Dictionary = r["first_open"]
		for key in fo:
			if not firsts.has(key):
				firsts[key] = []
			(firsts[key] as Array).append(float(fo[key]) / 60.0)
	var line := "  primer sobre de cada escalon (mediana, min): "
	for i in LootDB.pack_count():
		var pack_id := str(LootDB.pack_at(i)["id"])
		if not firsts.has(pack_id) or (firsts[pack_id] as Array).size() * 2 < runs:
			continue
		line += "%s %.1f   " % [pack_id, _median(firsts[pack_id])]
	print(line)
	gaps.sort()
	print("  primera mejora comprada: mediana %.1f min" % _median(first_buys))
	print("  rato mas largo sin comprar una mejora: mediana %.1f min, el peor %.1f"
		% [_median(gaps), _quantile(gaps, 1.0) if not gaps.is_empty() else INF])


## Cuanto gasta en mejoras el jugador de cada vuelta, y cuanto le cuesta. Es la
## decision con mas peso de la partida y la que menos se ve: gastar el 30 % del
## dinero en cada sobre se come el margen del sobre (entre un 30 y un 45 %) y el dinero deja de
## componer, asi que el jugador se queda dos horas en los sobres de siempre. Aqui
## se ve el punto dulce.
func _sweep_shares(runs: int = 9) -> void:
	print("COMPRAR MEJORAS: minutos hasta el rebirth segun lo que se gasto de una vez")
	for share in [0.05, 0.10, 0.20, 0.35, 0.55]:
		var times: Array = []
		var levels := 0
		for seed_value in runs:
			var r := simulate(0, seed_value, false, false, float(share))
			if float(r["minutes"]) < INF:
				times.append(float(r["minutes"]))
				levels += int(r["levels"])
		print("  gasta hasta el %2d %% del dinero: mediana %5.1f min   niveles %2d"
			% [roundi(float(share) * 100.0), _median(times),
				levels / maxi(1, times.size())])


## De donde sale el dinero de mas del gameplay nuevo en la partida del jugador
## normal: cuantas veces pasa cada cosa y lo que mete, de media por partida.
func _gameplay_report(strategy: int, runs: int) -> void:
	if not gameplay:
		print("  gameplay nuevo: APAGADO (clasico)")
		return
	var sum := {"golden_n": 0, "golden_money": 0, "vip_n": 0, "vip_money": 0,
		"happy_money": 0, "missions_n": 0, "missions_money": 0}
	var sets := 0
	var earned := 0.0
	var n := 0
	for seed_value in runs:
		var r := simulate(strategy, seed_value)
		if float(r["minutes"]) >= INF:
			continue
		n += 1
		var gp: Dictionary = r["gp"]
		for key in sum:
			sum[key] = int(sum[key]) + int(gp[key])
		sets += (gp["sets"] as Array).size()
	n = maxi(1, n)
	print("  gameplay nuevo (normal, media por partida): %d dorados (%d), %d VIP (+%d), hora feliz (+%d), %d encargos (%d), %.1f colecciones"
		% [int(sum["golden_n"]) / n, int(sum["golden_money"]) / n,
			int(sum["vip_n"]) / n, int(sum["vip_money"]) / n,
			int(sum["happy_money"]) / n, int(sum["missions_n"]) / n,
			int(sum["missions_money"]) / n, float(sets) / float(n)])


func _normal_median(runs: int) -> float:
	var times: Array = []
	for seed_value in runs:
		var r := simulate(0, seed_value)
		if float(r["minutes"]) < INF:
			times.append(float(r["minutes"]))
	return _median(times)


## El valor por debajo del cual cae esa fraccion de las partidas (0.1 = la
## partida rapida de cada diez). Mirar los extremos de 25 partidas miente -una
## racha buena en la ultima hace ver el juego roto-, asi que el informe enseña el
## 80 % central y deja fuera las dos colas.
func _quantile(values: Array, q: float) -> float:
	if values.is_empty():
		return INF
	var i := clampi(roundi(q * float(values.size() - 1)), 0, values.size() - 1)
	return float(values[i])


## Los minutos de un jugador con el botin puesto en su MEDIA (sin dado). Es la
## medida estable, la unica que puede comprobar un test: con dado el numero se
## mueve varios minutos de una partida a otra, y un test que salta por suerte es
## peor que no tener test. Ademas no depende de la semilla: sin tiradas no hay
## azar, asi que dos ejecuciones dan el mismo minuto.
func fixed_minutes(strategy: int) -> float:
	return float(simulate(strategy, 0, true)["minutes"])


func _median(values: Array) -> float:
	if values.is_empty():
		return INF
	var v := values.duplicate()
	v.sort()
	return float(v[v.size() / 2])
