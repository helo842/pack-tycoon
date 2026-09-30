# Palette - los mismos tokens de color que tools/make_sprites.py
#
# Vive en GDScript porque hay cosas que el juego dibuja en tiempo real (el
# anillo del temporizador, el destello de una venta) y no como sprites. Si
# cambia un color aqui, cámbialo también en make_sprites.py.
class_name Palette
extends RefCounted

const OUTLINE := Color8(16, 16, 32)
const CREAM := Color8(252, 236, 196)
const CREAM_D := Color8(212, 184, 136)
const CREAM_L := Color8(250, 232, 190)
const GOLD_D := Color8(168, 72, 8)
const GOLD := Color8(232, 128, 0)
const GOLD_L := Color8(248, 152, 16)
const GOLD_XL := Color8(248, 192, 0)
const GOLD_HI := Color8(255, 216, 88)
const TEAL_L := Color8(88, 208, 196)
const RUST_L := Color8(182, 80, 54)
const NIGHT_DD := Color8(12, 9, 20)
const NIGHT_D := Color8(16, 13, 26)
const NIGHT := Color8(22, 18, 32)
const NIGHT_L := Color8(30, 25, 44)
const NIGHT_LL := Color8(36, 30, 50)
const SHINE := Color8(255, 232, 176)
const SHINE_HI := Color8(255, 240, 200)

# El color de cada rareza (el "base" de RARITIES en make_sprites.py).
const RARITY := {
	"common": Color8(154, 160, 170),
	"rare": Color8(64, 132, 200),
	"epic": Color8(140, 82, 200),
	"legendary": GOLD_XL,
}

const RARITY_NAME := {
	"common": "COMUN",
	"rare": "RARO",
	"epic": "EPICO",
	"legendary": "LEGENDARIO",
}

const RARITY_ORDER: Array[String] = ["common", "rare", "epic", "legendary"]


## Un color de rareza con alfa, para auras y textos.
static func rarity(rarity_id: String, alpha: float = 1.0) -> Color:
	var c: Color = RARITY.get(rarity_id, CREAM)
	return Color(c.r, c.g, c.b, alpha)
