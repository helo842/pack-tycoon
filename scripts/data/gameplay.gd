# Gameplay - los numeros de lo que rompe la rutina de "golpear, cobrar, mejorar".
#
# El bucle de siempre (comprar un sobre, golpearlo, cobrar, subir el dano o la
# velocidad) funciona, pero a los diez minutos es siempre lo mismo. Lo de aqui
# anade cuatro cosas, y cada una ataca un trozo distinto de la monotonia:
#
#   EVENTOS       cosas que aparecen solas y se van: el SOBRE DORADO (abrelo
#                 antes de que desaparezca), el COMPRADOR VIP (paga el doble por
#                 un tipo de objeto con nota minima) y la HORA FELIZ (un tipo de
#                 botin vale x1,5 un rato). Son sorpresas y obligan a mirar.
#   GOLPE PERFECTO  pulsar el sobre justo cuando el anillo esta a punto de
#                 llenarse da un golpe mas fuerte y adelantado: el clic deja de ser
#                 "pulsar y esperar" y pasa a tener punteria.
#   HABILIDADES   tres botones con recarga que se compran en el arbol del
#                 rebirth: GOLPE CARGADO, FRENESI y LUPA DEL TASADOR.
#   LIBRETA       el ALBUM (colecciones que dan un bonus para siempre) y los
#                 ENCARGOS (misiones cortas que pagan dinero).
#
# Esto es una tabla, como LootDB y SkillTree: el estado vive en Game y lo que se
# ve en la pantalla de juego y en la libreta. Para reequilibrar se tocan estos
# numeros y se vuelve a pasar dev/balance.gd.
#
# LOS NUMEROS DE AQUI SALIERON DEL SIMULADOR. La primera version (dorado del
# escalon de arriba con nota 7, VIP x3, hora feliz x2, golpe perfecto x2,
# encargos de dos sobres, colecciones del 10 %) dejaba el primer rebirth en SEIS
# minutos: en esta economia un sobre del escalon alto es un tercio del requisito,
# asi que cualquier regalo pesa muchisimo. Se recortaron todos (dorado dos
# escalones por debajo, VIP x2, hora feliz x1,5, perfecto x1,5, encargos de 0,3
# sobres, colecciones del 5 %) y aun asi la suma bajaba la partida a doce
# minutos; el resto lo pusieron el margen de los sobres y el requisito (ver
# LootDB.VALUE_SCALE y REBIRTH_REQUIRE).
class_name Gameplay
extends RefCounted

# --------------------------------------------------------------------------- #
# Eventos
# --------------------------------------------------------------------------- #
# Cada evento tiene su propio reloj: cuando llega a cero aparece, y el siguiente
# se sortea entre los dos extremos. Los relojes solo corren con la mesa a la
# vista (sin la tarjeta de revelado ni paneles encima): un evento que empieza y
# acaba mientras estas en la tienda es un evento que no has visto.

## El sobre dorado: cada cuanto aparece (segundos, entre los dos) y cuanto se
## queda en la mesa esperando a que le des el primer golpe. Una vez empezado ya
## no se va.
const GOLDEN_EVERY := Vector2(150.0, 240.0)
const GOLDEN_FIRST := 75.0
const GOLDEN_LIFE := 10.0
## Lo que trae: el botin del sobre mas caro que hayas comprado (GOLDEN_STEP
## escalones por encima) con la nota como minimo en GOLDEN_MIN_GRADE, y gratis.
##
## EL ESCALON DE MAS SE PROBO Y SE QUITO: con el botin del sobre SIGUIENTE, un
## dorado valia lo que diez sobres normales (cada escalon paga dos veces y media
## el anterior, y la nota alta lo multiplica otra vez), y como el que sale luego
## es el del escalon nuevo, la partida se aceleraba sola. dev/balance.gd daba el
## primer rebirth en seis minutos. Con el escalon que ya tienes, un dorado es un
## buen regalo y no una partida resuelta.
const GOLDEN_STEP := -2
const GOLDEN_MIN_GRADE := 8

## El comprador VIP: cada cuanto llega, cuanto espera, cuanto paga de mas y la
## nota minima que pide (se sortea entre las dos).
const VIP_EVERY := Vector2(150.0, 240.0)
const VIP_FIRST := 90.0
const VIP_LIFE := 45.0
const VIP_MULT := 2.0
const VIP_GRADE := Vector2i(5, 8)

## La hora feliz: un tipo de botin vale HAPPY_MULT veces mas al venderlo.
const HAPPY_EVERY := Vector2(150.0, 220.0)
const HAPPY_FIRST := 150.0
const HAPPY_LIFE := 30.0
const HAPPY_MULT := 1.5

# --------------------------------------------------------------------------- #
# El golpe perfecto
# --------------------------------------------------------------------------- #

## A partir de que parte del anillo cuenta como perfecto pulsar el sobre que se
## esta cargando (0.8 = el ultimo quinto). Antes de eso el clic no hace nada,
## como siempre.
const PERFECT_FROM := 0.8
## Lo que multiplica el dano un golpe perfecto.
const PERFECT_MULT := 1.5

## LA RACHA: cada perfecto seguido suma STREAK_STEP al multiplicador del
## perfecto, hasta STREAK_MAX pasos. Se rompe si un sobre que has empezado tu
## termina la vuelta sin que lo pulses (se te ha pasado) o si pulsas antes de
## tiempo. Es lo que hace que la punteria valga mas que machacar muchos sobres:
## llevar pocos y acertar todos sube la racha, y llevar muchos la rompe.
const STREAK_STEP := 0.08
const STREAK_MAX := 3
## LA ZONA DORADA: un trozo estrecho dentro del tramo perfecto. Acertar ahi
## multiplica el perfecto otra vez y suma dos a la racha.
const SWEET_FROM := 0.92
const SWEET_TO := 0.97
const SWEET_MULT := 1.25
## Pulsar ANTES del tramo perfecto ya no es gratis: el anillo pierde esta parte
## de la vuelta y la racha se rompe. Sin esto, machacar el sobre no costaba nada.
const EARLY_PENALTY := 0.15


## Lo que multiplica la racha al golpe perfecto (la primera vez, nada).
static func streak_mult(streak: int) -> float:
	return 1.0 + STREAK_STEP * float(clampi(streak - 1, 0, STREAK_MAX))


# --------------------------------------------------------------------------- #
# El combo de apertura
# --------------------------------------------------------------------------- #
# Romper sobres a golpes uno detras de otro, sin dejar pasar COMBO_WINDOW
# segundos entre uno y otro, sube el combo. Cada paso de combo sube COMBO_STEP el
# valor de lo que sale del sobre, hasta COMBO_MAX pasos. Los Pinchos no cuentan:
# es un premio al ritmo del jugador, no a la automatizacion.
const COMBO_WINDOW := 3.0
const COMBO_STEP := 0.01
const COMBO_MAX := 10


static func combo_mult(combo: int) -> float:
	return 1.0 + COMBO_STEP * float(clampi(combo - 1, 0, COMBO_MAX))


# --------------------------------------------------------------------------- #
# El jefe
# --------------------------------------------------------------------------- #
# Un sobre gigante que aparece cada cierto rato y hay que romper antes de que se
# acabe su reloj (que corre desde que aparece). Su vida va con TU dano: son
# BOSS_HITS golpes normales, asi que sin perfectos ni habilidades no se llega, y
# con racha si. Roto a tiempo suelta BOSS_LOOT objetos del sobre del dorado con
# la nota como poco en BOSS_MIN_GRADE. Si se acaba el reloj, se va sin nada.
const BOSS_EVERY := Vector2(240.0, 360.0)
const BOSS_FIRST := 210.0
const BOSS_LIFE := 25.0
const BOSS_HITS := 16.0
const BOSS_LOOT := 2
const BOSS_MIN_GRADE := 6

# --------------------------------------------------------------------------- #
# El revelado
# --------------------------------------------------------------------------- #
## Las veces que el revelado se pasa de rareza un momento y vuelve atras (el
## "casi"). Solo cuando hay una rareza por encima de la que ha salido.
const NEAR_MISS_CHANCE := 0.25

# --------------------------------------------------------------------------- #
# Habilidades (se desbloquean en el arbol: ver SkillTree, rama de arriba)
# --------------------------------------------------------------------------- #

const ABIL_CHARGE := "abil_charge"
const ABIL_FRENZY := "abil_frenzy"
const ABIL_APPRAISE := "abil_appraise"

## Las tres, en el orden de la barra (y de las teclas 1, 2 y 3).
const ABILITIES: Array = [
	{"id": ABIL_CHARGE, "name": "GOLPE CARGADO", "art": "item_guantes",
		"cooldown": 40.0,
		"desc": "EL SIGUIENTE GOLPE HACE X5 DE DANO"},
	{"id": ABIL_FRENZY, "name": "FRENESI", "art": "skill_lightning",
		"cooldown": 90.0,
		"desc": "8 S: TODOS LOS SOBRES DE LA MESA SE GOLPEAN SOLOS"},
	{"id": ABIL_APPRAISE, "name": "LUPA DEL TASADOR", "art": "ui_icon_zoom_in",
		"cooldown": 75.0,
		"desc": "EN LA TARJETA: VUELVE A TIRAR LA NOTA DEL OBJETO"},
]
const CHARGE_MULT := 5.0
const FRENZY_TIME := 8.0

# --------------------------------------------------------------------------- #
# El album: colecciones
# --------------------------------------------------------------------------- #
# Un objeto cuenta como "visto" en cuanto sale de un sobre, con cualquier nota
# (se apunta su mejor nota). Completar una coleccion da su bonus PARA SIEMPRE:
# el album es de la cuenta, como las estadisticas, y no se pierde al reiniciar.
#
# Cada coleccion da una cosa DISTINTA a proposito: si todas dieran dano o
# dinero, completarlas seria mas de lo mismo, que es justo lo que se quiere
# arreglar. `stat` es lo que suma (ver Game.album_bonus) y `value` cuanto.
const SETS: Array = [
	{"id": "cards", "name": "CARTAS", "stat": "damage", "value": 0.05,
		"effect": "+5 % DANO",
		"items": ["loot_card_common", "loot_card_edited", "loot_card_vintage",
			"loot_card_foil"]},
	{"id": "vinyls", "name": "VINILOS", "stat": "money", "value": 0.05,
		"effect": "+5 % DINERO",
		"items": ["loot_vinyl", "loot_vinyl_double", "loot_vinyl_numbered",
			"loot_vinyl_color"]},
	{"id": "sneakers", "name": "ZAPATILLAS", "stat": "speed", "value": 0.05,
		"effect": "+5 % VELOCIDAD",
		"items": ["loot_sneaker", "loot_sneaker_leather", "loot_sneaker_restore",
			"loot_sneaker_limited"]},
	{"id": "games", "name": "CONSOLAS", "stat": "crit", "value": 0.03,
		"effect": "+3 % CRITICOS",
		"items": ["loot_console", "loot_handheld", "loot_cartridge",
			"loot_headphones", "loot_camera"]},
	{"id": "treasure", "name": "TESOROS", "stat": "table", "value": 1.0,
		"effect": "+1 HUECO MESA",
		"items": ["loot_watch", "loot_pocket_watch", "loot_cable", "loot_ingot"]},
	{"id": "perfect", "name": "PERFECCION", "stat": "rebirth", "value": 0.10,
		"effect": "+10 % REBIRTH", "grade": 10,
		"items": []},
]

# --------------------------------------------------------------------------- #
# Encargos
# --------------------------------------------------------------------------- #
# Tres a la vez. Al cumplir uno se cobra solo (con un aviso) y entra otro nuevo.
#
# EL PREMIO VA CON LO QUE CUESTA HACERLO. Antes todos pagaban lo mismo (un 30 %
# del sobre mas caro), y "abre 25 sobres" pagaba igual que "saca un 9": unos se
# hacian solos y otros no valian la pena. Ahora cada encargo sabe cuantos SOBRES
# cuesta de media cumplirlo (mission_packs) y paga REWARD_PER_PACK del sobre mas
# caro de la partida por cada uno, con un minimo y un tope: lo dificil paga mas
# y todo vale lo mismo al principio que al final.
#
# Y EL DE GUARDAR pide un tipo y una nota EXACTA ("GUARDA 3 CARTAS CON PSA 2"):
# es lo que da sentido a guardar notas bajas, y al filtro del AUTO GUARDAR (que
# deja elegir cada nota por separado). Cuenta al entrar en el inventario.

const MISSION_SLOTS := 3
const REWARD_PER_PACK := 0.022
const REWARD_MIN := 150
## Lo que se cuenta como "un sobre" de un encargo, entre estos topes: ni uno que
## se hace solo paga una miseria, ni uno de suerte pura paga una partida.
const MISSION_PACKS_MIN := 8.0
const MISSION_PACKS_MAX := 60.0
## Pedir un tipo concreto obliga a comprar ese sobre y no el que tocaria: cuesta
## un poco mas que abrir cualquiera.
const KIND_EFFORT := 1.3
## Lo que tarda de media en salir un sobre dorado o un VIP, en sobres.
const EVENT_PACKS := 12.0
## Golpes perfectos que se sacan de media por sobre jugando normal.
const PERFECT_PER_PACK := 3.0

## Las clases de encargo. `goal` es lo que hay que llegar a contar (en "grade"
## y "store" se sortea, ver make_mission); `text` lleva el objetivo.
const MISSION_TYPES: Array = [
	{"type": "open_any", "goal": 25, "text": "ABRE %d SOBRES"},
	{"type": "open_kind", "goal": 10, "text": "ABRE %d SOBRES DE %s"},
	{"type": "grade", "goal": 9, "text": "SACA UNA NOTA %d O MAS"},
	{"type": "perfect", "goal": 40, "text": "HAZ %d GOLPES PERFECTOS"},
	{"type": "golden", "goal": 1, "text": "ABRE %d SOBRE DORADO"},
	{"type": "vip", "goal": 1, "text": "VENDE %d OBJETO AL VIP"},
	{"type": "store", "goal": 1, "text": "GUARDA %d %s CON PSA %d"},
]


## Un encargo nuevo de la fila `row`. Lo usan la partida (Game._fill_missions) y
## el simulador del equilibrio, para que los dos sorteen lo mismo.
static func make_mission(rng: RandomNumberGenerator, row: Dictionary, top_price: int) -> Dictionary:
	var kinds := LootDB.kind_ids()
	var m := {"type": str(row["type"]), "goal": int(row["goal"]), "progress": 0,
		"kind": "", "grade": 0}
	match m["type"]:
		"open_kind":
			m["kind"] = kinds[rng.randi_range(0, kinds.size() - 1)]
		"grade":
			m["goal"] = rng.randi_range(8, 10)
		"store":
			m["kind"] = kinds[rng.randi_range(0, kinds.size() - 1)]
			m["grade"] = rng.randi_range(1, LootDB.GRADE_MAX)
			# Cuantos: tres de las notas que salen a menudo, uno de las raras.
			var p := grade_chance(int(m["grade"]))
			m["goal"] = 3 if p >= 0.1 else (2 if p >= 0.05 else 1)
	m["reward"] = mission_reward(m, top_price)
	return m


## La probabilidad de que un objeto salga con la nota `grade` exacta.
static func grade_chance(grade: int) -> float:
	var total := 0.0
	for w in LootDB.GRADE_WEIGHTS:
		total += float(w)
	return float(LootDB.GRADE_WEIGHTS[clampi(grade, 1, LootDB.GRADE_MAX) - 1]) / total


## Los sobres que cuesta de media cumplir el encargo: la medida de su dificultad.
static func mission_packs(m: Dictionary) -> float:
	var goal := float(m.get("goal", 1))
	var packs := goal
	match str(m.get("type", "")):
		"open_kind":
			packs = goal * KIND_EFFORT
		"grade":
			var p := 0.0
			for g in range(int(goal), LootDB.GRADE_MAX + 1):
				p += grade_chance(g)
			packs = 1.0 / maxf(p, 0.001)
		"perfect":
			packs = goal / PERFECT_PER_PACK
		"golden", "vip":
			packs = EVENT_PACKS * goal
		"store":
			packs = goal / grade_chance(int(m.get("grade", 1))) * KIND_EFFORT
	return clampf(packs, MISSION_PACKS_MIN, MISSION_PACKS_MAX)


static func mission_reward(m: Dictionary, top_price: int) -> int:
	return maxi(REWARD_MIN, roundi(float(top_price) * REWARD_PER_PACK * mission_packs(m)))


## Algo ha pasado que puede contar para el encargo `m` (lo cambia). Devuelve si
## ya esta cumplido. `value` es lo que cuenta (1 por sobre, la nota del objeto...).
static func mission_step(m: Dictionary, type: String, value: int, kind: String = "") -> bool:
	var t := str(m["type"])
	if t == "grade":
		if type == "grade" and value >= int(m["goal"]):
			m["progress"] = 1
		return int(m["progress"]) >= 1
	if t == "store":
		if type == "store" and kind == str(m["kind"]) and value == int(m.get("grade", 0)):
			m["progress"] = int(m["progress"]) + 1
	elif t == "open_kind":
		if type == "open" and kind == str(m["kind"]):
			m["progress"] = int(m["progress"]) + value
	elif (t == "open_any" and type == "open") or t == type:
		m["progress"] = int(m["progress"]) + value
	return int(m["progress"]) >= int(m["goal"])


## El texto de un encargo, con su objetivo dentro.
static func mission_text(m: Dictionary) -> String:
	for t in MISSION_TYPES:
		if str(t["type"]) == str(m["type"]):
			match str(m["type"]):
				"open_kind":
					return str(t["text"]) % [int(m["goal"]),
						str(LootDB.kind_row(str(m["kind"]))["name"])]
				"store":
					return str(t["text"]) % [int(m["goal"]),
						str(LootDB.kind_row(str(m["kind"]))["name"]), int(m["grade"])]
			return str(t["text"]) % int(m["goal"])
	return ""


# --------------------------------------------------------------------------- #
# Consultas
# --------------------------------------------------------------------------- #

static func ability(id: String) -> Dictionary:
	for a in ABILITIES:
		if str(a["id"]) == id:
			return a
	return {}


static func set_by_id(id: String) -> Dictionary:
	for s in SETS:
		if str(s["id"]) == id:
			return s
	return {}


## El nombre del objeto en el album: el dibujo sin la nota ("loot_vinyl_psa3" ->
## "loot_vinyl"). Se usa el DIBUJO y no el id de la fila porque una consola rara
## y una comun son la misma consola para una coleccion.
static func album_key(item: Dictionary) -> String:
	var art := str(item.get("art", ""))
	var i := art.rfind("_psa")
	return art.substr(0, i) if i > 0 else art


## Todos los objetos que caben en el album, en el orden en que se ensenan.
static func album_items() -> Array:
	var out: Array = []
	for s in SETS:
		for key in s["items"]:
			if not out.has(key):
				out.append(key)
	return out


## Un multiplicador escrito como lo lee la gente: "X2", "X1,5".
static func mult_text(m: float) -> String:
	if is_equal_approx(m, roundf(m)):
		return "X%d" % roundi(m)
	return ("X%.1f" % m).replace(".", ",")


## Un numero al azar entre los dos extremos de un Vector2.
static func between(rng: RandomNumberGenerator, v: Vector2) -> float:
	return rng.randf_range(v.x, v.y)
