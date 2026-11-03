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
# El premio va en "sobres": REWARD_PACKS veces el precio del sobre mas caro que
# hayas comprado en la partida, con un minimo, para que valga lo mismo al
# principio que al final.

const MISSION_SLOTS := 3
const REWARD_PACKS := 0.3
const REWARD_MIN := 150

## Las clases de encargo. `goal` es lo que hay que llegar a contar; `text` lleva
## %d para el objetivo (y %s para el tipo de sobre en open_kind).
const MISSION_TYPES: Array = [
	{"type": "open_any", "goal": 25, "text": "ABRE %d SOBRES"},
	{"type": "open_kind", "goal": 10, "text": "ABRE %d SOBRES DE %s"},
	{"type": "grade", "goal": 9, "text": "SACA UNA NOTA %d O MAS"},
	{"type": "perfect", "goal": 40, "text": "HAZ %d GOLPES PERFECTOS"},
	{"type": "golden", "goal": 1, "text": "ABRE %d SOBRE DORADO"},
	{"type": "vip", "goal": 1, "text": "VENDE %d OBJETO AL VIP"},
]


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
