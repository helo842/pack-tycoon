# BlackMarket - el MERCADO NEGRO: la furgoneta, sus cajas y lo que sale de ellas.
#
# Se abre con el nodo MERCADO NEGRO del arbol del rebirth (SkillTree.MARKET,
# detras de LEYENDA y el mas caro). Desde entonces una FURGONETA aparca en el
# borde de la mesa cada VAN_EVERY segundos de juego y se queda VAN_LIFE. El reloj
# vive en Game (market_next) y NO se reinicia con el rebirth: en las partidas
# cortas del final de la telaraña no saldria nunca.
#
# LAS CAJAS se pagan con dinero normal y se abren AL MOMENTO en el panel. Su
# precio va por el sobre mas caro que has comprado en la partida (ref_price), asi
# que siempre son "caras". De cada una sale UNA cosa (OUTCOMES):
#   fake     una falsificacion: vale casi nada (pierdes la caja)
#   normal   un objeto de contrabando que vale mas o menos la caja
#   good     uno que vale varias veces la caja
#   jackpot  el golpe maestro
#   raid     REDADA: no sale nada y la poli se lleva una parte de tu dinero
#            (raid_share, nunca mas de RAID_CAP)
#
# QUE NO ROMPA EL RITMO: lo que paga un objeto es precio x mult x ROI, donde ROI
# es lo que pagan los sobres por cada moneda (Game.market_roi: el margen del
# sobre mas caro por tus multiplicadores). La media de "mult" esta sobre 1: una
# caja paga de media como gastar ese dinero en sobres, pero AL MOMENTO y con mucha
# varianza. Cada caja se vende UNA vez por visita, asi que no se puede encadenar.
# Lo mide dev/balance.gd (el jugador simulado compra las que le caben).
class_name BlackMarket
extends RefCounted

## Cada cuanto llega la furgoneta (segundos de juego, entre los dos), la primera
## vez tras comprar el nodo, y cuanto se queda.
const VAN_EVERY := Vector2(480.0, 600.0)
const VAN_FIRST := 60.0
const VAN_LIFE := 90.0

## CUANTO del rendimiento de los sobres se lleva una caja: paga precio x mult x
## ROI^ROI_POWER. Con 1 pagaba lo mismo que los sobres pero sin golpear, y el
## simulador bajaba el juego entero de 24,7 h a 14,2 h (al final de la telaraña el
## ROI es enorme y una visita valia por varias partidas).
const ROI_POWER := 0.3

## Lo que se puede llevar una redada, como mucho.
const RAID_CAP := 0.25

## Las cajas. "price" multiplica el precio del sobre mas caro comprado.
## "outcomes": peso y rango de "mult" (x el precio y el ROI). "raid_share" es la
## parte del dinero que se lleva la redada.
const BOXES: Array = [
	{"id": "bm_box_carton", "name": "Caja sin marca", "art": "tree_bm_box_carton",
		"price": 4.0, "risk": 1, "raid_share": 0.0, "outcomes": [
			{"id": "fake", "w": 40, "mult": Vector2(0.05, 0.25)},
			{"id": "normal", "w": 45, "mult": Vector2(0.7, 1.2)},
			{"id": "good", "w": 12, "mult": Vector2(2.0, 3.0)},
			{"id": "jackpot", "w": 3, "mult": Vector2(5.0, 5.0)},
		]},
	{"id": "bm_box_metal", "name": "Caja sellada", "art": "tree_bm_box_metal",
		"price": 15.0, "risk": 2, "raid_share": 0.10, "outcomes": [
			{"id": "fake", "w": 45, "mult": Vector2(0.05, 0.25)},
			{"id": "normal", "w": 29, "mult": Vector2(0.7, 1.2)},
			{"id": "good", "w": 13, "mult": Vector2(2.0, 4.0)},
			{"id": "jackpot", "w": 4, "mult": Vector2(8.0, 8.0)},
			{"id": "raid", "w": 9, "mult": Vector2(0.0, 0.0)},
		]},
	{"id": "bm_box_case", "name": "Maletín", "art": "tree_bm_box_case",
		"price": 50.0, "risk": 3, "raid_share": 0.20, "outcomes": [
			{"id": "fake", "w": 50, "mult": Vector2(0.05, 0.25)},
			{"id": "normal", "w": 18, "mult": Vector2(0.7, 1.2)},
			{"id": "good", "w": 12, "mult": Vector2(2.0, 5.0)},
			{"id": "jackpot", "w": 5, "mult": Vector2(10.0, 10.0)},
			{"id": "raid", "w": 15, "mult": Vector2(0.0, 0.0)},
		]},
]

## La rareza de lo que sale, por resultado (la usa el armario).
const OUTCOME_RARITY := {"fake": "common", "normal": "rare", "good": "epic",
	"jackpot": "legendary"}

## El sello de la tarjeta del resultado.
const OUTCOME_STAMP := {"fake": "FALSO", "normal": "CONTRABANDO", "good": "BUEN GOLPE",
	"jackpot": "GOLPE MAESTRO", "raid": "REDADA"}

## Los objetos de contrabando: dos de cada tipo, con dibujo propio
## (tools/loot_designs.py, prefijo bm_). Cuentan en el armario como su tipo.
const ITEMS: Array = [
	{"id": "bm_stolen_card", "name": "Carta robada", "art": "loot_bm_stolen_card", "kind": "cards"},
	{"id": "bm_misprint", "name": "Carta mal impresa", "art": "loot_bm_misprint", "kind": "cards"},
	{"id": "bm_bootleg", "name": "Vinilo pirata", "art": "loot_bm_bootleg", "kind": "vinyls"},
	{"id": "bm_lost_tape", "name": "Cinta perdida", "art": "loot_bm_lost_tape", "kind": "vinyls"},
	{"id": "bm_sample", "name": "Zapatilla de muestra", "art": "loot_bm_sample",
		"kind": "sneakers"},
	{"id": "bm_unreleased", "name": "Zapatilla sin estrenar", "art": "loot_bm_unreleased",
		"kind": "sneakers"},
	{"id": "bm_devkit", "name": "Consola de desarrollo", "art": "loot_bm_devkit",
		"kind": "electronics"},
	{"id": "bm_hot_watch", "name": "Reloj caliente", "art": "loot_bm_hot_watch",
		"kind": "electronics"},
	{"id": "bm_recalled", "name": "Juguete retirado", "art": "loot_bm_recalled", "kind": "toys"},
	{"id": "bm_prototype", "name": "Prototipo", "art": "loot_bm_prototype", "kind": "toys"},
]
## La falsificacion: un lingote de plomo pintado de dorado.
const FAKE := {"id": "bm_lead_ingot", "name": "Lingote de plomo", "art": "loot_bm_lead_ingot",
	"kind": "electronics"}


static func box_by_id(id: String) -> Dictionary:
	for b in BOXES:
		if str(b["id"]) == id:
			return b
	return {}


static func box_price(box: Dictionary, ref_price: int) -> int:
	return maxi(1, roundi(float(maxi(1, ref_price)) * float(box["price"])))


## La media de "mult" de una caja (sin contar lo que se lleva la redada).
static func expected_mult(box: Dictionary) -> float:
	var total := 0.0
	var peso := 0.0
	for o in box["outcomes"]:
		total += float(o["w"]) * (float(o["mult"].x) + float(o["mult"].y)) * 0.5
		peso += float(o["w"])
	return total / peso


## La probabilidad de redada de una caja.
static func raid_chance(box: Dictionary) -> float:
	var raid := 0.0
	var peso := 0.0
	for o in box["outcomes"]:
		peso += float(o["w"])
		if str(o["id"]) == "raid":
			raid += float(o["w"])
	return raid / peso


## La media de la nota PSA en multiplicador (para que la nota no cambie la media
## de lo que paga una caja: una nota alta paga mas y una baja menos).
static func _mean_grade_mult() -> float:
	var total := 0.0
	var peso := 0.0
	for i in LootDB.GRADE_WEIGHTS.size():
		total += float(LootDB.GRADE_WEIGHTS[i]) * LootDB.grade_mult(i + 1)
		peso += float(LootDB.GRADE_WEIGHTS[i])
	return total / peso


## ABRE una caja. `price` es lo que se ha pagado, `roi` lo que pagan los sobres por
## moneda, `money` el dinero que queda (para la redada) y `tier` el escalon del
## sobre de referencia (para el armario). Devuelve {"outcome", "item" (vacio en la
## redada), "loss" (lo que se lleva la redada)}.
static func open_box(rng: RandomNumberGenerator, box: Dictionary, price: int, roi: float,
		money: int, tier: int) -> Dictionary:
	var total := 0
	for o in box["outcomes"]:
		total += int(o["w"])
	var r := rng.randi_range(1, total)
	var pick: Dictionary = box["outcomes"][box["outcomes"].size() - 1]
	var acc := 0
	for o in box["outcomes"]:
		acc += int(o["w"])
		if r <= acc:
			pick = o
			break
	var outcome := str(pick["id"])
	if outcome == "raid":
		var share := minf(float(box["raid_share"]), RAID_CAP)
		return {"outcome": outcome, "item": {}, "loss": roundi(float(maxi(0, money)) * share)}
	var mult := rng.randf_range(float(pick["mult"].x), float(pick["mult"].y))
	var grade := LootDB.roll_grade(rng)
	var def: Dictionary = FAKE if outcome == "fake" else ITEMS[rng.randi_range(0, ITEMS.size() - 1)]
	var value := maxi(1, roundi(float(price) * mult * pow(maxf(roi, 0.0), ROI_POWER) * LootDB.grade_mult(grade)
			/ _mean_grade_mult()))
	var item := {
		"id": def["id"], "name": def["name"],
		"art": "%s_psa%d" % [str(def["art"]), grade],
		"rarity": OUTCOME_RARITY[outcome], "base_value": value,
		"condition": LootDB.condition_for_grade(grade), "grade": grade,
		"value": value, "kind": def["kind"], "tier": tier,
		"black_market": true,
	}
	return {"outcome": outcome, "item": item, "loss": 0}
