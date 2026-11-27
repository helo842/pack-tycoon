# Auction - LAS SUBASTAS: la furgoneta VIP, sus lotes y la puja contra los rivales.
#
# Se abren con el hexagono SUBASTA de la ascension (AscensionTree.AUCTION, fuera de
# la telaraña y de 3 puntos). Desde entonces una FURGONETA ROJA Y DORADA aparca
# abajo a la izquierda de la mesa cada VAN_EVERY segundos de juego (unos 18 min) y
# se queda VAN_LIFE. Es otra furgoneta que la negra del mercado negro: su reloj es
# suyo (Game.auction_next) y tampoco se reinicia con el rebirth.
#
# CADA VISITA TRAE UN LOTE (LOTS) y se puja por el en la SALA DE SUBASTAS
# (AuctionPanel) contra dos pujadores inventados. Se puja con dinero normal:
#   - el reloj empieza en CLOCK s y cada puja (tuya o de un rival) le suma BID_TIME,
#     sin pasar de CLOCK;
#   - cada puja sube el precio un BID_STEP;
#   - cada rival tiene un TOPE SECRETO y se retira al llegar a el;
#   - cuando el reloj llega a cero gana quien va primero. SOLO PAGA QUIEN GANA:
#     perder no cuesta nada.
#
# LOS LOTES:
#   potion   una POCION (POTIONS) que se guarda en el estante y se toma cuando
#            quieras. Dos iguales suman tiempo; dos distintas, a la vez.
#   mythic   un MITICO (MYTHICS), uno por tipo, con su nota PSA. No se pierde
#            nunca y ocupa un hueco normal del armario (vale MYTHIC_LOCKER
#            legendarios). Si ya tienes el de ese tipo se queda el de mejor nota y
#            el otro se vende.
#   seal     el SELLO DE AUTENTICIDAD: +1 a la nota de un objeto del armario.
#   blind    el LOTE A CIEGAS: BLIND_MYTHIC de ser un mitico; si no, basura.
#   egg      un HUEVO: una de las tres mascotas que solo salen aqui (PetDB, la
#            maquina "auction": cuervo, mapache y rata).
#   star     la ESTRELLA FUGAZ: +1 punto de ascension. Es lo que hace que la
#            subasta pague lo que cuesta: el hexagono son 3 puntos, y sin esto
#            comprarlo pronto alargaba el juego entero de 24,6 h a 36,7 h (lo
#            demas apenas acelera el final, donde mandan puntos y monedas).
#
# EL PRECIO DE SALIDA va por el sobre mas caro de la partida (como las cajas del
# mercado negro, ver BlackMarket.box_price) por el "start" del lote, asi que la
# subasta cuesta lo mismo en proporcion al principio y al final del juego. Lo mide
# dev/balance.gd (el jugador simulado gana una parte de los lotes).
class_name Auction
extends RefCounted

## Cada cuanto llega la furgoneta VIP (segundos de juego, entre los dos), la
## primera vez tras comprar el hexagono, y cuanto se queda esperando.
const VAN_EVERY := Vector2(960.0, 1200.0)
const VAN_FIRST := 120.0
const VAN_LIFE := 90.0

## El reloj de la puja: empieza aqui, cada puja suma BID_TIME y no pasa de CLOCK.
const CLOCK := 20.0
const BID_TIME := 5.0
## Cada puja sube el precio esto (0,10 = +10 %).
const BID_STEP := 0.10
## El tope secreto de cada rival, en veces el precio de salida.
const RIVAL_CAP := Vector2(1.3, 2.6)
## Cuanto tarda un rival en contestar (segundos, entre los dos).
const RIVAL_WAIT := Vector2(1.0, 3.0)
const RIVAL_NAMES := ["Coleccionista", "La Duquesa", "El Barón", "Madame Rouge",
	"Don Tasador", "La Urraca"]

## La parte de lotes a ciegas que trae un mitico.
const BLIND_MYTHIC := 0.2
## Lo que vale la basura del lote a ciegas, en veces lo pagado.
const BLIND_JUNK := 0.15
## Un mitico en el armario vale esto en legendarios (ver LootDB.bonus_for).
const MYTHIC_LOCKER := 2.5
## El escalon de armario de los miticos (el de la tienda pro).
const MYTHIC_TIER := 5

## Los lotes: "w" es el peso al sortear y "start" el precio de salida en veces el
## sobre mas caro de la partida.
const LOTS: Array = [
	{"id": "potion_money", "type": "potion", "potion": "money", "w": 14, "start": 3.0},
	{"id": "potion_fury", "type": "potion", "potion": "fury", "w": 14, "start": 3.0},
	{"id": "potion_luck", "type": "potion", "potion": "luck", "w": 12, "start": 3.0},
	{"id": "potion_rain", "type": "potion", "potion": "rain", "w": 10, "start": 3.0},
	{"id": "mythic", "type": "mythic", "w": 14, "start": 12.0},
	{"id": "seal", "type": "seal", "w": 12, "start": 4.0},
	{"id": "blind", "type": "blind", "w": 14, "start": 5.0},
	{"id": "egg", "type": "egg", "w": 10, "start": 6.0},
	{"id": "star", "type": "star", "w": 13, "start": 8.0},
]

## Las pociones. "seconds" es lo que dura una (dos iguales suman).
const POTIONS := {
	"money": {"name": "Dinero x2", "art": "tree_potion_money", "seconds": 300.0,
		"desc": "x2 de dinero durante 5 min"},
	"fury": {"name": "Furia", "art": "tree_potion_fury", "seconds": 180.0,
		"desc": "x3 de daño durante 3 min"},
	"luck": {"name": "Suerte", "art": "tree_potion_luck", "seconds": 300.0,
		"desc": "Más rarezas y mejores notas durante 5 min"},
	"rain": {"name": "Lluvia de monedas", "art": "tree_potion_rain", "seconds": 300.0,
		"desc": "x1,5 monedas en cada rebirth durante 5 min"},
}
const POTION_ORDER := ["money", "fury", "luck", "rain"]
## Lo que hace cada una (lo leen Game.value_multiplier, damage_multiplier, luck y
## pending_rebirth_coins).
const POTION_MONEY := 2.0
const POTION_FURY := 3.0
const POTION_LUCK := 2.0
const POTION_RAIN := 1.5

## Los miticos, uno por tipo (dibujo propio con sus 10 notas en
## tools/loot_designs.py, prefijo myth_).
const MYTHICS: Array = [
	{"id": "myth_cards", "name": "Carta primigenia", "art": "loot_myth_cards", "kind": "cards"},
	{"id": "myth_vinyls", "name": "Máster original", "art": "loot_myth_vinyls", "kind": "vinyls"},
	{"id": "myth_sneakers", "name": "Par cero", "art": "loot_myth_sneakers", "kind": "sneakers"},
	{"id": "myth_electronics", "name": "Consola de oro", "art": "loot_myth_electronics",
		"kind": "electronics"},
	{"id": "myth_toys", "name": "Osito número uno", "art": "loot_myth_toys", "kind": "toys"},
]

## Lo que se ve de cada lote (nombre y dibujo; los miticos y el huevo se ven al
## ganarlos, en el pedestal va el dibujo del lote).
const LOT_INFO := {
	"mythic": {"name": "Objeto mítico", "art": "tree_auction_mythic",
		"desc": "Uno de los cinco míticos, con su nota. No se pierde nunca"},
	"seal": {"name": "Sello de autenticidad", "art": "tree_auction_seal",
		"desc": "+1 a la nota de un objeto del armario"},
	"blind": {"name": "Lote a ciegas", "art": "tree_auction_blind",
		"desc": "Sellado: puede ser un mítico... o basura"},
	"egg": {"name": "Huevo exclusivo", "art": "tree_auction_egg",
		"desc": "Una mascota que solo sale en subasta"},
	"star": {"name": "Estrella fugaz", "art": "tree_asc_star",
		"desc": "+1 punto de ascensión para la telaraña"},
}

# --- una subasta en marcha ------------------------------------------------- #

var lot: Dictionary = {}
var start_price := 0
var price := 0
## Quien va primero: "" (nadie ha pujado), "tu" o el nombre de un rival.
var leader := ""
var time_left := CLOCK
var rivals: Array = []    # [{name, cap, wait}]
var done := false
var _rng: RandomNumberGenerator


## Una subasta nueva. `rival_cut` baja el tope de los rivales (la Rata: 0,2 = un
## 20 % menos).
static func create(rng: RandomNumberGenerator, the_lot: Dictionary, start: int,
		rival_cut: float = 0.0) -> Auction:
	var a := Auction.new()
	a._rng = rng
	a.lot = the_lot
	a.start_price = maxi(1, start)
	a.price = a.start_price
	var names: Array = RIVAL_NAMES.duplicate()
	for i in 2:
		var k := rng.randi_range(0, names.size() - 1)
		a.rivals.append({"name": str(names[k]),
			"cap": roundi(float(a.start_price) * rng.randf_range(RIVAL_CAP.x, RIVAL_CAP.y)
				* clampf(1.0 - rival_cut, 0.1, 1.0)),
			"wait": rng.randf_range(RIVAL_WAIT.x, RIVAL_WAIT.y)})
		names.remove_at(k)
	return a


## Lo que hay que pujar para ir primero: el precio de salida si nadie ha pujado,
## y si no un BID_STEP mas.
func next_bid() -> int:
	if leader == "":
		return price
	return maxi(price + 1, ceili(float(price) * (1.0 + BID_STEP)))


## Pujas tu. Falla si ya ha acabado, si ya vas primero o si no te llega.
func player_bid(money: int) -> bool:
	if done or leader == "tu" or money < next_bid():
		return false
	_bid("tu")
	return true


func _bid(who: String) -> void:
	price = next_bid()
	leader = who
	time_left = minf(CLOCK, time_left + BID_TIME)


## Avanza el reloj. Devuelve lo que ha pasado en este rato: "" nada, el nombre del
## rival que ha pujado, o "fin".
func step(delta: float) -> String:
	if done:
		return ""
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		done = true
		return "fin"
	for r in rivals:
		if leader == str(r["name"]):
			continue
		r["wait"] = float(r["wait"]) - delta
		if float(r["wait"]) > 0.0:
			continue
		r["wait"] = _rng.randf_range(RIVAL_WAIT.x, RIVAL_WAIT.y)
		if next_bid() <= int(r["cap"]):
			_bid(str(r["name"]))
			return str(r["name"])
	return ""


func won() -> bool:
	return done and leader == "tu"


## ¿Siguen pujando los rivales? (los dos se han retirado: su tope no llega).
func rival_active(r: Dictionary) -> bool:
	return leader == str(r["name"]) or next_bid() <= int(r["cap"])


# --- datos ------------------------------------------------------------------ #

## Un lote al azar por su peso. `skip` son tipos que no pueden salir (el huevo con
## las tres mascotas al maximo).
static func roll_lot(rng: RandomNumberGenerator, skip: Array = []) -> Dictionary:
	var total := 0
	for l in LOTS:
		if not skip.has(str(l["type"])):
			total += int(l["w"])
	var r := rng.randi_range(1, maxi(1, total))
	for l in LOTS:
		if skip.has(str(l["type"])):
			continue
		r -= int(l["w"])
		if r <= 0:
			return l
	return LOTS[0]


static func lot_by_id(id: String) -> Dictionary:
	for l in LOTS:
		if str(l["id"]) == id:
			return l
	return {}


static func lot_price(the_lot: Dictionary, ref_price: int) -> int:
	return maxi(1, roundi(float(maxi(1, ref_price)) * float(the_lot.get("start", 1.0))))


## Nombre, dibujo y descripcion de un lote.
static func lot_name(the_lot: Dictionary) -> String:
	if str(the_lot.get("type", "")) == "potion":
		return "Poción: " + str(POTIONS[str(the_lot["potion"])]["name"])
	return str(LOT_INFO.get(str(the_lot.get("type", "")), {}).get("name", "Lote"))


static func lot_art(the_lot: Dictionary) -> String:
	if str(the_lot.get("type", "")) == "potion":
		return str(POTIONS[str(the_lot["potion"])]["art"])
	return str(LOT_INFO.get(str(the_lot.get("type", "")), {}).get("art", "tree_auction_blind"))


static func lot_desc(the_lot: Dictionary) -> String:
	if str(the_lot.get("type", "")) == "potion":
		return str(POTIONS[str(the_lot["potion"])]["desc"])
	return str(LOT_INFO.get(str(the_lot.get("type", "")), {}).get("desc", ""))


static func mythic_by_kind(kind: String) -> Dictionary:
	for m in MYTHICS:
		if str(m["kind"]) == kind:
			return m
	return {}


## Un mitico al azar con su nota (la mejor de dos tiradas: un mitico no sale
## destrozado tan a menudo como un sobre). `paid` pone su valor de venta.
static func make_mythic(rng: RandomNumberGenerator, paid: int) -> Dictionary:
	var def: Dictionary = MYTHICS[rng.randi_range(0, MYTHICS.size() - 1)]
	var grade := maxi(LootDB.roll_grade(rng), LootDB.roll_grade(rng))
	return mythic_item(def, grade, paid)


static func mythic_item(def: Dictionary, grade: int, paid: int) -> Dictionary:
	var value := maxi(1, roundi(float(maxi(1, paid)) * LootDB.grade_mult(grade)))
	return {
		"id": def["id"], "name": def["name"],
		"art": "%s_psa%d" % [str(def["art"]), grade],
		"rarity": "legendary", "base_value": value, "grade": grade,
		"condition": LootDB.condition_for_grade(grade), "value": value,
		"kind": def["kind"], "tier": MYTHIC_TIER, "mythic": true,
	}


## La basura del lote a ciegas: un lingote de plomo que se vende por poco.
static func junk_item(rng: RandomNumberGenerator, paid: int) -> Dictionary:
	var grade := LootDB.roll_grade(rng)
	var value := maxi(1, roundi(float(paid) * BLIND_JUNK))
	return {"id": BlackMarket.FAKE["id"], "name": BlackMarket.FAKE["name"],
		"art": "%s_psa%d" % [str(BlackMarket.FAKE["art"]), grade], "rarity": "common",
		"grade": grade, "condition": LootDB.condition_for_grade(grade), "value": value,
		"base_value": value, "kind": BlackMarket.FAKE["kind"], "tier": 1}


## Sube la nota de un objeto un punto (el sello), con su dibujo y su valor.
static func sealed(item: Dictionary) -> Dictionary:
	var nuevo := item.duplicate(true)
	var antes := int(item.get("grade", 1))
	var nota := mini(10, antes + 1)
	nuevo["grade"] = nota
	nuevo["value"] = maxi(1, roundi(float(item.get("value", 1)) * LootDB.grade_mult(nota)
			/ LootDB.grade_mult(antes)))
	nuevo["condition"] = LootDB.condition_for_grade(nota)
	var art := str(item.get("art", ""))
	var i := art.rfind("_psa")
	if i > 0:
		nuevo["art"] = "%s_psa%d" % [art.substr(0, i), nota]
	return nuevo
