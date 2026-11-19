# AscensionTree - las mejoras de la ASCENSION (el arbol morado, ver AscensionPanel).
#
# La ascension es el super-rebirth: se abre con el arbol del rebirth ENTERO
# comprado, lo borra TODO (partida, monedas, arbol, album) y da PUNTOS DE
# ASCENSION. Los puntos se gastan aqui y lo comprado aqui no se pierde nunca.
#
# ES UNA TELARANA: HYPER en el centro y seis HILOS que salen de el, cada uno con
# cuatro anillos (1, 2, 3 y 4 puntos). Cada nodo pide el de dentro de su hilo. HYPER
# es exagerado A PROPOSITO (x3 de dinero por 1 punto): es lo que hace que la
# segunda ascension llegue antes que la primera.
#
# Hilos: tres de FARM (dinero, golpe, rebirth), uno de AUTOMATIZACION, uno de
# HERENCIA (lo que no se pierde al ascender) y uno de ESTRELLAS (mas puntos y
# mascotas).
#
# Como SkillTree: lo que da y lo que cuesta cada nodo vive aqui; Game solo
# guarda que ids estan comprados (Game.asc_skills) y que interruptores estan
# apagados (Game.asc_off).
class_name AscensionTree
extends RefCounted

## Lo que cuesta cada anillo (el 0 es HYPER).
const RING_COST := [1, 1, 2, 3, 4]

## Los nombres de los hilos, en el orden de "spoke" (0 a la derecha y en el
## sentido del reloj, de 60 en 60 grados).
const SPOKES := ["Dinero", "Rebirth", "Automático", "Herencia", "Estrellas", "Golpe"]

## Los efectos de cada nodo:
##  "mult": MULTIPLICA un stat (money, damage, speed, spikes, rebirth y require,
##          que es lo que pide el rebirth: 0,7 = -30 %).
##  "add":  SUMA (points: puntos de mas por ascension; pet_slots: huecos de
##          mascota; start_money: dinero de mas al empezar cada partida).
##  "flag": algo que no es un numero (ver Game.asc_flag). Los de "toggle" se
##          encienden y se apagan pulsando el nodo ya comprado.
const NODES: Array = [
	{"id": "hyper", "name": "HYPER", "art": "tree_asc_hyper", "spoke": -1, "ring": 0,
		"mult": {"money": 3.0}, "desc": "x3 de dinero"},

	# Hilo 0: DINERO
	{"id": "asc_money_1", "name": "Bolsa", "art": "tree_asc_money_1", "spoke": 0, "ring": 1,
		"mult": {"money": 1.5}, "desc": "x1,5 de dinero"},
	{"id": "asc_money_2", "name": "Cofre", "art": "tree_asc_money_2", "spoke": 0, "ring": 2,
		"mult": {"money": 2.0}, "desc": "x2 de dinero"},
	{"id": "asc_money_3", "name": "Supernova", "art": "tree_asc_money_3", "spoke": 0, "ring": 3,
		"mult": {"money": 3.0}, "desc": "x3 de dinero"},
	{"id": "asc_money_4", "name": "Galaxia", "art": "tree_asc_money_4", "spoke": 0, "ring": 4,
		"mult": {"money": 5.0}, "desc": "x5 de dinero"},

	# Hilo 1: REBIRTH
	{"id": "asc_rebirth_1", "name": "Eco", "art": "tree_asc_rebirth_1", "spoke": 1, "ring": 1,
		"mult": {"rebirth": 1.5}, "desc": "x1,5 de monedas de rebirth"},
	{"id": "asc_rebirth_2", "name": "Atajo", "art": "tree_asc_rebirth_2", "spoke": 1, "ring": 2,
		"mult": {"require": 0.7}, "desc": "El rebirth pide un 30 % menos"},
	{"id": "asc_rebirth_3", "name": "Big bang", "art": "tree_asc_rebirth_3", "spoke": 1,
		"ring": 3, "mult": {"rebirth": 2.0}, "desc": "x2 de monedas de rebirth"},
	{"id": "asc_rebirth_4", "name": "Multiverso", "art": "tree_asc_rebirth_4", "spoke": 1,
		"ring": 4, "mult": {"rebirth": 3.0}, "desc": "x3 de monedas de rebirth"},

	# Hilo 2: AUTOMATIZACION (interruptores)
	{"id": "asc_auto_abil", "name": "Piloto", "art": "tree_asc_auto_abil", "spoke": 2,
		"ring": 1, "flag": "auto_abil", "toggle": true,
		"desc": "Las habilidades se usan solas"},
	{"id": "asc_auto_tree", "name": "Jardinero", "art": "tree_asc_auto_tree", "spoke": 2,
		"ring": 2, "flag": "auto_tree", "toggle": true,
		"desc": "El árbol del rebirth se compra solo"},
	{"id": "asc_auto_rebirth", "name": "Auto rebirth", "art": "tree_asc_auto_rebirth",
		"spoke": 2, "ring": 3, "flag": "auto_rebirth", "toggle": true,
		"desc": "Hace el rebirth por ti (al doble de monedas) hasta tener el árbol entero"},
	{"id": "asc_auto_perfect", "name": "Perfección", "art": "tree_asc_auto_perfect",
		"spoke": 2, "ring": 4, "flag": "auto_perfect", "toggle": true,
		"desc": "Todos tus golpes salen perfectos solos, en la zona dorada"},

	# Hilo 3: HERENCIA (lo que no se pierde al ascender)
	{"id": "asc_keep_album", "name": "Recuerdo", "art": "tree_asc_keep_album", "spoke": 3,
		"ring": 1, "flag": "keep_album", "desc": "Al ascender no pierdes el álbum"},
	{"id": "asc_keep_qol", "name": "Herencia", "art": "tree_asc_keep_qol", "spoke": 3,
		"ring": 2, "flag": "keep_qol", "desc": "Guardas calidad de vida y habilidades"},
	# Dinero NORMAL en cada partida, y por debajo de lo que pide el rebirth con
	# todas las rebajas (unos 394.000): con mas se podria reiniciar en bucle sin
	# jugar. Lo comprueba el test de humo.
	{"id": "asc_seed", "name": "Semilla", "art": "tree_asc_seed", "spoke": 3, "ring": 3,
		"add": {"start_money": 250000.0},
		"desc": "Cada partida empieza con 250.000 de dinero más"},
	{"id": "asc_keep_locker", "name": "Legado", "art": "tree_asc_keep_locker", "spoke": 3,
		"ring": 4, "flag": "keep_locker",
		"desc": "El rebirth y la ascensión no te quitan lo expuesto en el armario"},

	# Hilo 4: ESTRELLAS (mas puntos y mascotas)
	{"id": "asc_points_1", "name": "Estrella doble", "art": "tree_asc_points_1", "spoke": 4,
		"ring": 1, "add": {"points": 1.0}, "desc": "+1 punto por ascensión"},
	{"id": "asc_pet_slot", "name": "Collar", "art": "tree_asc_pet_slot", "spoke": 4,
		"ring": 2, "add": {"pet_slots": 1.0}, "desc": "+1 hueco de mascota"},
	{"id": "asc_points_2", "name": "Constelación", "art": "tree_asc_points_2", "spoke": 4,
		"ring": 3, "add": {"points": 2.0}, "desc": "+2 puntos por ascensión"},
	{"id": "asc_points_3", "name": "Nebulosa", "art": "tree_asc_points_3", "spoke": 4,
		"ring": 4, "add": {"points": 3.0}, "desc": "+3 puntos por ascensión"},

	# Hilo 5: GOLPE
	{"id": "asc_hit_1", "name": "Fuerza", "art": "tree_asc_hit_1", "spoke": 5, "ring": 1,
		"mult": {"damage": 1.5}, "desc": "x1,5 de daño"},
	{"id": "asc_hit_2", "name": "Rayo", "art": "tree_asc_hit_2", "spoke": 5, "ring": 2,
		"mult": {"speed": 1.5}, "desc": "x1,5 de velocidad"},
	{"id": "asc_hit_3", "name": "Cometa", "art": "tree_asc_hit_3", "spoke": 5, "ring": 3,
		"mult": {"damage": 2.0, "spikes": 2.0}, "desc": "x2 de daño y de pinchos"},
	{"id": "asc_hit_4", "name": "Meteorito", "art": "tree_asc_hit_4", "spoke": 5, "ring": 4,
		"mult": {"damage": 3.0}, "desc": "x3 de daño"},
]


static func node_by_id(id: String) -> Dictionary:
	for n in NODES:
		if str(n["id"]) == id:
			return n
	return {}


static func ids() -> Array:
	return NODES.map(func(n: Dictionary) -> String: return str(n["id"]))


static func cost_of(id: String) -> int:
	var n := node_by_id(id)
	return 0 if n.is_empty() else int(RING_COST[int(n["ring"])])


## El nodo que hay que tener antes: el del anillo de dentro del mismo hilo, y
## HYPER para el primer anillo. "" para HYPER.
static func req_of(id: String) -> String:
	var n := node_by_id(id)
	if n.is_empty() or int(n["ring"]) == 0:
		return ""
	if int(n["ring"]) == 1:
		return "hyper"
	for m in NODES:
		if int(m["spoke"]) == int(n["spoke"]) and int(m["ring"]) == int(n["ring"]) - 1:
			return str(m["id"])
	return ""


static func node_at(spoke: int, ring: int) -> Dictionary:
	for n in NODES:
		if int(n["spoke"]) == spoke and int(n["ring"]) == ring:
			return n
	return {}
