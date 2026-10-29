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
# LA CIFRA DEL REQUISITO (80.000) SALIO DE AQUI, barriendo: con 50.000 el normal
# llegaba en 16,3 min y con 120.000 en 22,0, asi que 80.000 es lo que deja el
# primer rebirth en los mismos ~18 minutos que daba el requisito viejo (lo
# ganado: era un millon). Menos de 50.000 se sale de la banda por abajo y mas de
# 120.000 alarga la partida de mas.
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
const BAND := Vector2(15.0, 25.0)
## Paso de la simulacion automatica (segundos). Con la mesa abriendose sola el
## tiempo va en tirones: mas fino no cambia nada y multiplica el rato de espera.
const AUTO_STEP := 0.25

const STRATEGIES: Array = [
	{
		"id": "normal", "click": 0.35, "card": 1.6, "share": 0.30, "auto": false,
		"locker": false,
		"order": ["tijeras", "guantes", "trebol", "cajon", "ojo_verde", "laser",
			"pc", "pinchos", "armario"],
	},
	{
		"id": "optimizado", "click": 0.20, "card": 1.1, "share": 0.20, "auto": false,
		"locker": true,
		"order": ["tijeras", "guantes", "trebol", "cajon", "ojo_verde", "laser",
			"pc", "pinchos", "armario"],
	},
	{
		"id": "automatico", "click": 0.20, "card": 0.0, "share": 0.20, "auto": true,
		"locker": true,
		"order": ["tijeras", "guantes", "trebol", "cajon", "ojo_verde", "laser",
			"pc", "pinchos", "armario"],
	},
]
## Lo que tarda la compra automatica entre sobre y sobre (LootDB.AUTO_BUY_INTERVAL)
## y los sobres que caben en la mesa sin Cajon.
const AUTO_BUY := 0.75


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
	# SE PARA CUANDO EL CONTADOR LLEGA AL REQUISITO, que es la regla del rebirth
	# desde que su requisito se mide en el dinero que TIENES y no en lo ganado (ver
	# Game.can_rebirth). El requisito de la partida no es "hacer tal cosa": es
	# "tener tanto dinero a la vez" (LootDB.REBIRTH_REQUIRE), asi que este bucle
	# mira `money` y no `earned`, que se sigue llevando solo para el informe.
	while money < LootDB.REBIRTH_REQUIRE and t < CAP:
		if trace and opened % 20 == 0:
			print("    %6.1f min  dinero %9d  niveles %2d  sobres %4d  ahora %s"
				% [t / 60.0, money, LootDB.total_levels(levels), opened,
					_best_pack(money)])
		var price := 0
		if bool(st["auto"]) and LootDB.item_level(levels, "pinchos") > 0 \
				and LootDB.item_level(levels, "pc") > 0:
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
			t += _pack_seconds(levels, pack_id, st)
			var gain := _loot(levels, locker, pack_id, st, rng, fixed_loot)
			money += gain
			earned += gain
			opened += 1
			paid += price
			income += gain
			rungs[pack_id] = int(rungs.get(pack_id, 0)) + 1
		var buy := _shop(st, levels, money)
		money = int(buy["money"])
		spent += int(buy["spent"])
	if money < LootDB.REBIRTH_REQUIRE:
		return {"minutes": INF, "packs": opened, "spent": spent, "levels": 0}
	var roi := float(income) / float(paid) if paid > 0 else 0.0
	return {"minutes": t / 60.0, "packs": opened, "spent": spent,
		"levels": LootDB.total_levels(levels), "roi": roi, "rungs": rungs}


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
	var hit := _average_hit(levels)
	var hits := int(ceil(float(LootDB.pack_hp(pack_id)) / maxf(0.001, hit)))
	return float(hits) * _cycle(levels, st) + float(st["card"])


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
	var click := float(st["click"])
	var best := charge + click
	var k := 2
	while k <= LootDB.open_count(levels) and k <= LootDB.table_slots(levels):
		best = minf(best, maxf(charge, float(k) * click))
		k += 1
	return best


func _average_hit(levels: Array) -> float:
	var crit := LootDB.crit_chance(levels) * (LootDB.crit_mult(levels) - 1.0)
	return LootDB.damage_per_hit(levels) * (1.0 + crit)


## Lo que paga un sobre: el botin de verdad (roll_pack, con su rareza y su nota)
## o, en la pasada "sin suerte", su valor medio (pack_payout).
func _loot(levels: Array, locker: Array, pack_id: String, st: Dictionary,
		rng: RandomNumberGenerator, fixed_loot: bool) -> int:
	var mult := 1.0
	for item in locker:
		mult += LootDB.bonus_for(item)
	if fixed_loot:
		return int(round(LootDB.pack_payout(pack_id) * mult))
	var loot := LootDB.roll_pack(rng, pack_id, LootDB.luck(levels), mult)
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
	return int(loot["value"])


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
	var args := OS.get_cmdline_args()
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
