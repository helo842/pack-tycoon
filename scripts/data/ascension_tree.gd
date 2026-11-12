# AscensionTree - las mejoras de la ASCENSION (el arbol morado, ver AscensionPanel).
#
# La ascension es el super-rebirth: se abre con el arbol del rebirth ENTERO
# comprado, lo borra TODO (partida, monedas, arbol, album) y da un PUNTO DE
# ASCENSION. Los puntos se gastan aqui y lo comprado aqui no se pierde nunca.
#
# Como SkillTree: lo que da y lo que cuesta cada nodo vive aqui; Game solo
# guarda que ids estan comprados (Game.asc_skills).
class_name AscensionTree
extends RefCounted

## "money_mult" MULTIPLICA el dinero (x3), no suma un porcentaje como el arbol
## del rebirth: es la recompensa de haberlo perdido todo.
const NODES: Array = [
	{
		"id": "hyper", "name": "HYPER", "art": "tree_asc_hyper", "cost": 1,
		"money_mult": 3.0, "desc": "X3 DE DINERO",
	},
]


static func node_by_id(id: String) -> Dictionary:
	for n in NODES:
		if str(n["id"]) == id:
			return n
	return {}
