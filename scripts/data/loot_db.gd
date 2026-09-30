# LootDB - los datos del juego y las tiradas.
#
# Aqui vive todo lo que se puede cambiar para reequilibrar sin tocar la
# interfaz: precios, tiempos de espera, que cae en cada paquete y cuanto vale.
#
# DELIBERADO: solo hay 6 objetos unicos (vinilo, zapatilla, consola,
# auriculares, reloj y camara) mas las 4 cartas. La variedad de botin es lo
# primero que falta; cuando se creen mas sprites solo se anaden filas a la lista
# "loot" de cada paquete, sin tocar nada mas.
#
# EL SPRITE LLEVA LA NOTA PSA. Cada objeto fisico tiene diez dibujos
# (loot_vinyl_psa1 ... loot_vinyl_psa10) que salen del mismo dibujo base con una
# capa de desgaste encima, de modo que se ve cuanto esta usado: una consola con
# nota 1 sale rayada, sucia y con el plastico comido. Las cartas tambien: se
# rozan, se stainan, se pliegan y pierden la esquina, y ademas hay CUATRO
# dibujos distintos (comun, edicion limitada, vieja y holografica) en vez de un
# solo dibujo teñido por rareza. La rareza sigue mandando en la cabecera, pero
# ya no es lo unico que se ve: tambien esta el diseno.
#
# EL ESTADO SE SACA DE LA NOTA, no se tira aparte. Antes el estado de conservacion
# era una tirada independiente y podia contradecir al dibujo (nota 10 con el
# objeto roto). Ahora son la misma variable, que es ademas como funciona una casa
# de subastas de verdad: la graduacion ES el juicio sobre el estado.
#
# POR TANTO EL VALOR ES  base x multiplicador de nota  y nada mas. Se elimino el
# multiplicador de estado, y el de nota se reescalo para que el valor esperado de
# cada paquete se quede donde estaba (ver grade_mult).
class_name LootDB
extends RefCounted

# --------------------------------------------------------------------------- #
# Paquetes
# --------------------------------------------------------------------------- #
# "time" son los segundos de espera sin herramientas. Las herramientas no hacen
# dano: acortan la espera (la decision que se tomo al montar el juego).
const PACKS: Array = [
	{
		"id": "cards", "name": "SOBRES", "price": 150, "time": 1.4,
		"art": "pack_cards", "art_open": "pack_cards_open",
		"loot": [
			{"id": "card_c", "name": "CARTA COMUN", "art": "loot_card_common", "graded": true,
				"rarity": "common", "value": 55, "w": 55},
			{"id": "card_r", "name": "CARTA EDICION LIMITADA", "art": "loot_card_edited", "graded": true,
				"rarity": "rare", "value": 260, "w": 30},
			{"id": "card_e", "name": "CARTA VIEJA", "art": "loot_card_vintage", "graded": true,
				"rarity": "epic", "value": 1150, "w": 12},
			{"id": "card_l", "name": "CARTA HOLOGRAFICA", "art": "loot_card_foil", "graded": true,
				"rarity": "legendary", "value": 5400, "w": 3},
		],
	},
	{
		"id": "vinyls", "name": "VINILOS", "price": 850, "time": 2.0,
		"art": "pack_vinyls", "art_open": "pack_vinyls_open",
		"loot": [
			{"id": "vinyl_c", "name": "VINILO", "art": "loot_vinyl", "graded": true,
				"rarity": "common", "value": 380, "w": 52},
			{"id": "vinyl_d", "name": "DOBLE LP", "art": "loot_vinyl_double", "graded": true,
				"rarity": "rare", "value": 1450, "w": 31},
			{"id": "vinyl_n", "name": "EDICION NUMERADA", "art": "loot_vinyl_numbered",
				"graded": true, "rarity": "epic", "value": 5200, "w": 14},
			{"id": "vinyl_x", "name": "PRENSADO EN COLOR", "art": "loot_vinyl_color",
				"graded": true, "rarity": "legendary", "value": 24000, "w": 3},
		],
	},
	{
		"id": "sneakers", "name": "ZAPATILLAS", "price": 4200, "time": 2.8,
		"art": "pack_sneakers", "art_open": "pack_sneakers_open",
		"loot": [
			{"id": "shoe_c", "name": "ZAPATILLA BLANCA", "art": "loot_sneaker", "graded": true,
				"rarity": "common", "value": 1800, "w": 48},
			{"id": "shoe_l", "name": "ZAPATILLA DE PIEL", "art": "loot_sneaker_leather",
				"graded": true, "rarity": "rare", "value": 7200, "w": 32},
			{"id": "shoe_r", "name": "ZAPATILLA A RESTAURAR", "art": "loot_sneaker_restore",
				"graded": true, "rarity": "epic", "value": 28000, "w": 16},
			{"id": "shoe_x", "name": "ZAPATILLA LIMITADA",
				"art": "loot_sneaker_limited", "graded": true,
				"rarity": "legendary", "value": 130000, "w": 4},
		],
	},
	{
		"id": "electronics", "name": "ELECTRONICA", "price": 26000, "time": 3.8,
		"art": "pack_electronics", "art_open": "pack_electronics_open",
		"loot": [
			{"id": "cons_c", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"rarity": "common", "value": 6000, "w": 30},
			{"id": "head_c", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"rarity": "common", "value": 4200, "w": 20},
			{"id": "cam_c", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"rarity": "common", "value": 9000, "w": 18},
			{"id": "cart_c", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"rarity": "common", "value": 1800, "w": 14},
			{"id": "hand_c", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"rarity": "common", "value": 9000, "w": 7},
			{"id": "cons_r", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"rarity": "rare", "value": 20400, "w": 12},
			{"id": "head_r", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"rarity": "rare", "value": 14300, "w": 10},
			{"id": "cam_r", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"rarity": "rare", "value": 30600, "w": 10},
			{"id": "cart_r", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"rarity": "rare", "value": 6120, "w": 5},
			{"id": "hand_r", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"rarity": "rare", "value": 30600, "w": 5},
			{"id": "cons_e", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"rarity": "epic", "value": 90000, "w": 8},
			{"id": "head_e", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"rarity": "epic", "value": 63000, "w": 7},
			{"id": "cam_e", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"rarity": "epic", "value": 135000, "w": 7},
			{"id": "cart_e", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"rarity": "epic", "value": 27000, "w": 2},
			{"id": "hand_e", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"rarity": "epic", "value": 135000, "w": 4},
			{"id": "cons_l", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"rarity": "legendary", "value": 330000, "w": 5},
			{"id": "head_l", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"rarity": "legendary", "value": 231000, "w": 2},
			{"id": "cam_l", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"rarity": "legendary", "value": 495000, "w": 3},
			{"id": "cart_l", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"rarity": "legendary", "value": 99000, "w": 1},
			{"id": "hand_l", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"rarity": "legendary", "value": 495000, "w": 2},
		],
	},
	{
		"id": "misc", "name": "VARIOS", "price": 160000, "time": 5.0,
		"art": "pack_misc", "art_open": "pack_misc_open",
		"loot": [
			{"id": "wat_c", "name": "RELOJ", "art": "loot_watch", "graded": true,
				"rarity": "common", "value": 45000, "w": 30},
			{"id": "sho_c", "name": "ZAPATILLA", "art": "loot_sneaker", "graded": true,
				"rarity": "common", "value": 38000, "w": 13},
			{"id": "cam_c", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"rarity": "common", "value": 75000, "w": 12},
			{"id": "cab_c", "name": "CABLE", "art": "loot_cable", "graded": true,
				"rarity": "common", "value": 22000, "w": 6},
			{"id": "ing_c", "name": "LINGOTE DE ORO", "art": "loot_ingot", "graded": true,
				"rarity": "common", "value": 85000, "w": 5},
			{"id": "pwt_c", "name": "RELOJ DE BOLSILLO", "art": "loot_pocket_watch", "graded": true,
				"rarity": "common", "value": 130000, "w": 4},
			{"id": "wat_r", "name": "RELOJ", "art": "loot_watch", "graded": true,
				"rarity": "rare", "value": 153000, "w": 13},
			{"id": "sho_r", "name": "ZAPATILLA", "art": "loot_sneaker", "graded": true,
				"rarity": "rare", "value": 129000, "w": 8},
			{"id": "cam_r", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"rarity": "rare", "value": 255000, "w": 7},
			{"id": "cab_r", "name": "CABLE", "art": "loot_cable", "graded": true,
				"rarity": "rare", "value": 74800, "w": 3},
			{"id": "ing_r", "name": "LINGOTE DE ORO", "art": "loot_ingot", "graded": true,
				"rarity": "rare", "value": 289000, "w": 3},
			{"id": "pwt_r", "name": "RELOJ DE BOLSILLO", "art": "loot_pocket_watch", "graded": true,
				"rarity": "rare", "value": 442000, "w": 2},
			{"id": "wat_e", "name": "RELOJ", "art": "loot_watch", "graded": true,
				"rarity": "epic", "value": 675000, "w": 6},
			{"id": "sho_e", "name": "ZAPATILLA", "art": "loot_sneaker", "graded": true,
				"rarity": "epic", "value": 570000, "w": 4},
			{"id": "cam_e", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"rarity": "epic", "value": 1125000, "w": 3},
			{"id": "cab_e", "name": "CABLE", "art": "loot_cable", "graded": true,
				"rarity": "epic", "value": 330000, "w": 1},
			{"id": "ing_e", "name": "LINGOTE DE ORO", "art": "loot_ingot", "graded": true,
				"rarity": "epic", "value": 1275000, "w": 1},
			{"id": "pwt_e", "name": "RELOJ DE BOLSILLO", "art": "loot_pocket_watch", "graded": true,
				"rarity": "epic", "value": 1950000, "w": 1},
			{"id": "wat_l", "name": "RELOJ", "art": "loot_watch", "graded": true,
				"rarity": "legendary", "value": 2475000, "w": 2},
			{"id": "sho_l", "name": "ZAPATILLA", "art": "loot_sneaker", "graded": true,
				"rarity": "legendary", "value": 2090000, "w": 1},
			{"id": "cam_l", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"rarity": "legendary", "value": 4125000, "w": 1},
			{"id": "cab_l", "name": "CABLE", "art": "loot_cable", "graded": true,
				"rarity": "legendary", "value": 1210000, "w": 1},
			{"id": "ing_l", "name": "LINGOTE DE ORO", "art": "loot_ingot", "graded": true,
				"rarity": "legendary", "value": 4675000, "w": 1},
			{"id": "pwt_l", "name": "RELOJ DE BOLSILLO", "art": "loot_pocket_watch", "graded": true,
				"rarity": "legendary", "value": 7150000, "w": 1},
		],
	},
]

# --------------------------------------------------------------------------- #
# Estado de conservacion: la insignia que va con la nota en la tarjeta
# --------------------------------------------------------------------------- #
# No tiene peso ni multiplicador, es solo la etiqueta de la nota.
const CONDITIONS: Array = [
	{"id": "mint", "name": "COMO NUEVO", "art": "condition_mint", "min": 9},
	{"id": "good", "name": "BUEN ESTADO", "art": "condition_good", "min": 7},
	{"id": "worn", "name": "GASTADO", "art": "condition_worn", "min": 4},
	{"id": "broken", "name": "ROTO", "art": "condition_broken", "min": 1},
]

# --------------------------------------------------------------------------- #
# Nota PSA: la graduacion de 1 a 10 que se enseña en el badge
# --------------------------------------------------------------------------- #
# Se reparte hacia arriba (lo normal es que el objeto venga ya graduado) pero
# nunca sale un 10 fijo: el 10 es el premio gordo.
const GRADE_WEIGHTS: Array = [1, 1, 2, 3, 5, 7, 9, 12, 14, 16]
const PSA_MIN := 1
const GRADE_MAX := 10

# --------------------------------------------------------------------------- #
# Herramientas: acortan la espera. Cada nivel suma un 22% al divisor.
# --------------------------------------------------------------------------- #
const TOOL_SPEED_PER_LEVEL := 0.22
const TOOL_MAX_LEVEL := 5
const TOOL_COST_GROWTH := 1.85

const TOOLS: Array = [
	{"id": "cutter", "name": "CORTADOR", "art": "tool_cutter", "base_cost": 600},
	{"id": "scissors", "name": "TIJERAS", "art": "tool_scissors", "base_cost": 1200},
	{"id": "gloves", "name": "GUANTES", "art": "tool_gloves", "base_cost": 2400},
	{"id": "crowbar", "name": "PALANCA", "art": "tool_crowbar", "base_cost": 5000},
]


# --------------------------------------------------------------------------- #
# Consultas
# --------------------------------------------------------------------------- #

static func pack_count() -> int:
	return PACKS.size()


static func pack_at(index: int) -> Dictionary:
	return PACKS[clampi(index, 0, PACKS.size() - 1)]


static func pack_by_id(pack_id: String) -> Dictionary:
	for p in PACKS:
		if p["id"] == pack_id:
			return p
	return PACKS[0]


static func pack_index(pack_id: String) -> int:
	for i in PACKS.size():
		if PACKS[i]["id"] == pack_id:
			return i
	return 0


static func tool_count() -> int:
	return TOOLS.size()


static func tool_at(index: int) -> Dictionary:
	return TOOLS[clampi(index, 0, TOOLS.size() - 1)]


# --------------------------------------------------------------------------- #
# Economia de las herramientas
# --------------------------------------------------------------------------- #

static func tool_cost(index: int, current_level: int) -> int:
	if current_level >= TOOL_MAX_LEVEL:
		return -1          # -1 = al maximo
	var base: float = TOOLS[index]["base_cost"]
	return int(round(base * pow(TOOL_COST_GROWTH, current_level)))


## Segundos que se espera realmente con las herramientas que tengas compradas.
static func open_time(pack_id: String, tool_levels: Array) -> float:
	var base: float = pack_by_id(pack_id)["time"]
	return base / speed_multiplier(tool_levels)


static func speed_multiplier(tool_levels: Array) -> float:
	var total := 0
	for lvl in tool_levels:
		total += int(lvl)
	return 1.0 + TOOL_SPEED_PER_LEVEL * float(total)


# --------------------------------------------------------------------------- #
# Tiradas
# --------------------------------------------------------------------------- #

## Elige un objeto del paquete por peso.
static func roll_item(rng: RandomNumberGenerator, pack_id: String) -> Dictionary:
	var table: Array = pack_by_id(pack_id)["loot"]
	return _pick(rng, table, "w").duplicate(true)


## La insignia de estado que corresponde a una nota. 9-10 como nuevo, 7-8 buen
## estado, 4-6 gastado, 1-3 roto.
static func condition_for_grade(grade: int) -> Dictionary:
	for c in CONDITIONS:
		if grade >= int(c["min"]):
			return c
	return CONDITIONS[CONDITIONS.size() - 1]


## Nota de 1 a 10. Devuelve el entero; el multiplicador sale de grade_mult().
static func roll_grade(rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in GRADE_WEIGHTS:
		total += int(w)
	var r := rng.randi_range(1, total)
	var acc := 0
	for i in GRADE_WEIGHTS.size():
		acc += int(GRADE_WEIGHTS[i])
		if r <= acc:
			return i + 1
	return GRADE_MAX


## Cuanto vale la nota. Va de 0.50 (nota 1) a 1.13 (nota 10).
##
## Antes la nota multiplicaba por 0.60..1.40 y encima el estado (0.30..1.25)
## hacia de factor aparte. Al derivar el estado de la nota, el multiplicador se
## reescalo para que la media se quede en 1: la media de la nota sale en 7.6, y
## 0.50 + 0.07*(7.6-1) da 0.96. Asi los precios de la tabla de arriba siguen
## valiendo lo que valian y no hay que reequilibrar los 5 paquetes.
static func grade_mult(grade: int) -> float:
	return 0.50 + 0.07 * float(clampi(grade, PSA_MIN, GRADE_MAX) - 1)


## El nombre del sprite de un objeto segun su nota. Las cartas no se desgastan.
static func art_for(item: Dictionary, grade: int) -> String:
	if not bool(item.get("graded", false)):
		return str(item["art"])
	return "%s_psa%d" % [str(item["art"]), clampi(grade, PSA_MIN, GRADE_MAX)]


static func final_value(item: Dictionary, grade: int) -> int:
	var v: float = float(item["value"]) * grade_mult(grade)
	return maxi(1, int(round(v)))


## Numero de estrellas llenas de la nota (se dibujan 10 ranuras, llenas y vacias).
static func grade_stars(grade: int) -> int:
	return clampi(grade, 0, GRADE_MAX)


## Tirada completa de un paquete: objeto, nota, estado, sprite y valor final.
## El estado sale de la nota, asi que aqui no hay nada que repartir.
static func roll_pack(rng: RandomNumberGenerator, pack_id: String) -> Dictionary:
	var item := roll_item(rng, pack_id)
	var grade := roll_grade(rng)
	return {
		"id": item["id"], "name": item["name"], "art": art_for(item, grade),
		"rarity": item["rarity"], "base_value": item["value"],
		"condition": condition_for_grade(grade), "grade": grade,
		"value": final_value(item, grade),
	}


static func _pick(rng: RandomNumberGenerator, table: Array, weight_key: String) -> Dictionary:
	var total := 0.0
	for e in table:
		total += float(e[weight_key])
	var r := rng.randf() * total
	for e in table:
		r -= float(e[weight_key])
		if r <= 0.0:
			return e
	return table[table.size() - 1]
