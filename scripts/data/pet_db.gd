# PetDB - las mascotas del GACHAPON (la tienda de mascotas, ver PetPanel).
#
# La tienda sale al comprar HYPER en la ascension. Tiene cuatro maquinas
# (MACHINES), cada una con sus seis mascotas propias: 1, 10 o 100 monedas de
# rebirth, o 1 punto de ascension la tirada. Repetir una mascota la sube de
# nivel. Unas suben el dinero o el rebirth, otras el dano, el critico, la
# velocidad, la suerte o los Pinchos. Las mascotas NO se pierden nunca, ni al
# ascender (solo hard_reset).
#
# Como AscensionTree: lo que da cada mascota vive aqui; Game solo guarda el
# nivel de cada una (Game.pets).
class_name PetDB
extends RefCounted

## El nivel maximo de cada mascota. Las que estan al maximo ya no salen en la
## maquina, asi que ninguna tirada se tira.
const MAX_LEVEL := 5

## Las MAQUINAS del gachapon, una por pagina de la tienda, cada una con SUS seis
## mascotas (dibujo y efecto propios). "currency" es con que se paga: "rebirth"
## (monedas de rebirth) o "ascension" (puntos de ascension). "suffix" es solo el
## dibujo de la maquina (tree_pet_machine<suffix>).
##
## "stat" de cada mascota es lo que sube (ver STAT_NAMES y Game.pet_bonus):
## money, rebirth, damage, speed (la carga del boton), luck, spikes (los
## Pinchos) multiplican; crit SUMA probabilidad de critico (0.01 = +1 %).
## "per_level" es lo que da CADA nivel. La probabilidad sale de la rareza
## (RARITY_WEIGHT): las raras dan mas.
## shortcut: los per_level de ORO, HIELO y COSMICA estan puestos a ojo, sin
## simular; si rompen el ritmo, se ajustan aqui (BalanceTest no los mira).
const MACHINES: Array = [
	{"id": "basic", "name": "NORMAL", "suffix": "", "cost": 1, "currency": "rebirth", "pets": [
		{"id": "dog", "name": "PERRO", "stat": "money", "per_level": 0.05, "rarity": "common"},
		{"id": "cat", "name": "GATO", "stat": "rebirth", "per_level": 0.05, "rarity": "common"},
		{"id": "frog", "name": "RANA", "stat": "money", "per_level": 0.10, "rarity": "rare"},
		{"id": "fish", "name": "PEZ", "stat": "rebirth", "per_level": 0.10, "rarity": "rare"},
		{"id": "fox", "name": "ZORRO", "stat": "money", "per_level": 0.25, "rarity": "legendary"},
		{"id": "dragon", "name": "DRAGON", "stat": "rebirth", "per_level": 0.25,
			"rarity": "legendary"},
	]},
	{"id": "gold", "name": "ORO", "suffix": "_gold", "cost": 10, "currency": "rebirth", "pets": [
		{"id": "hamster", "name": "HAMSTER", "stat": "speed", "per_level": 0.05, "rarity": "common"},
		{"id": "bunny", "name": "CONEJO", "stat": "luck", "per_level": 0.10, "rarity": "common"},
		{"id": "owl", "name": "BUHO", "stat": "crit", "per_level": 0.01, "rarity": "rare"},
		{"id": "parrot", "name": "LORO", "stat": "money", "per_level": 0.20, "rarity": "rare"},
		{"id": "turtle", "name": "TORTUGA", "stat": "spikes", "per_level": 0.40,
			"rarity": "legendary"},
		{"id": "bear", "name": "OSO", "stat": "damage", "per_level": 0.40, "rarity": "legendary"},
	]},
	{"id": "ice", "name": "HIELO", "suffix": "_ice", "cost": 100, "currency": "rebirth", "pets": [
		{"id": "penguin", "name": "PINGUINO", "stat": "speed", "per_level": 0.10,
			"rarity": "common"},
		{"id": "seal", "name": "FOCA", "stat": "money", "per_level": 0.20, "rarity": "common"},
		{"id": "octopus", "name": "PULPO", "stat": "spikes", "per_level": 0.40, "rarity": "rare"},
		{"id": "wolf", "name": "LOBO", "stat": "damage", "per_level": 0.40, "rarity": "rare"},
		{"id": "yeti", "name": "YETI", "stat": "crit", "per_level": 0.02, "rarity": "legendary"},
		{"id": "whale", "name": "BALLENA", "stat": "rebirth", "per_level": 0.80,
			"rarity": "legendary"},
	]},
	{"id": "cosmic", "name": "COSMICA", "suffix": "_cosmic", "cost": 1, "currency": "ascension",
		"pets": [
		{"id": "robot", "name": "ROBOT", "stat": "speed", "per_level": 0.20, "rarity": "common"},
		{"id": "alien", "name": "ALIEN", "stat": "luck", "per_level": 0.40, "rarity": "common"},
		{"id": "ghost", "name": "FANTASMA", "stat": "crit", "per_level": 0.03, "rarity": "rare"},
		{"id": "phoenix", "name": "FENIX", "stat": "rebirth", "per_level": 0.80, "rarity": "rare"},
		{"id": "unicorn", "name": "UNICORNIO", "stat": "money", "per_level": 1.60,
			"rarity": "legendary"},
		{"id": "golem", "name": "GOLEM", "stat": "damage", "per_level": 1.60,
			"rarity": "legendary"},
	]},
]

const RARITY_WEIGHT := {"common": 30, "rare": 15, "legendary": 5}

## Lo que sube cada "stat", en largo y en corto (el corto cabe en la ficha).
const STAT_NAMES := {
	"money": ["DINERO", "DINERO"], "rebirth": ["MONEDAS DE REBIRTH", "REBIRTH"],
	"damage": ["DANO", "DANO"], "speed": ["VELOCIDAD", "VELOCIDAD"],
	"crit": ["DE CRITICO", "CRITICO"], "luck": ["SUERTE", "SUERTE"],
	"spikes": ["PINCHOS", "PINCHOS"],
}

## Todas las mascotas de todas las maquinas, cada una con su "machine", su
## "weight" y su "art" (tree_pet_<id>). Las ids son las de siempre para las de la
## basica, y asi valen las partidas guardadas.
static var PETS: Array = _all_pets()


static func _all_pets() -> Array:
	var out: Array = []
	for m in MACHINES:
		for b in m["pets"]:
			var p: Dictionary = b.duplicate()
			p["art"] = "tree_pet_" + str(b["id"])
			p["weight"] = RARITY_WEIGHT[str(b["rarity"])]
			p["machine"] = m["id"]
			out.append(p)
	return out


static func machine(id: String) -> Dictionary:
	for m in MACHINES:
		if str(m["id"]) == id:
			return m
	return MACHINES[0]


static func pets_of(machine_id: String) -> Array:
	return PETS.filter(func(p: Dictionary) -> bool: return p["machine"] == machine_id)


static func pet_by_id(id: String) -> Dictionary:
	for p in PETS:
		if str(p["id"]) == id:
			return p
	return {}


## Lo que da una mascota en texto ("+10% DINERO"), con el nivel que se le pase.
## `short` usa el nombre corto, para que quepa en la ficha.
static func bonus_text(p: Dictionary, level: int, short := false) -> String:
	var que: String = STAT_NAMES[str(p["stat"])][1 if short else 0]
	return "+%d%% %s" % [roundi(float(p["per_level"]) * float(maxi(level, 1)) * 100.0), que]


## Una mascota al azar por su peso, entre las de la maquina `machine_id` que NO
## estan al maximo. "" si estan todas al maximo. `levels` es Game.pets.
static func roll(levels: Dictionary, machine_id: String = "basic") -> String:
	var pool := pets_of(machine_id)
	var total := 0
	for p in pool:
		if int(levels.get(p["id"], 0)) < MAX_LEVEL:
			total += int(p["weight"])
	if total == 0:
		return ""
	var r := randi() % total
	for p in pool:
		if int(levels.get(p["id"], 0)) >= MAX_LEVEL:
			continue
		r -= int(p["weight"])
		if r < 0:
			return str(p["id"])
	return ""
