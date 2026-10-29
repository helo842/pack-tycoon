# SkillTree - el arbol de mejoras del rebirth: los nodos, lo que cuestan y lo
# que dan.
#
# QUE ES. El rebirth paga MONEDAS (una por cada 1,5 M que haya en el contador al
# reiniciar, ver LootDB.REBIRTH_COIN_AT) y esas monedas se gastan AQUI. Antes no
# se gastaban: cada moneda subia un 5 % el valor de lo que vendias, para siempre,
# y eso convertia el rebirth en una paga automatica en la que no habia nada que
# decidir. Ahora la moneda es una moneda de verdad: se cambia por una mejora.
#
# LA FORMA. Una mejora en el CENTRO (+30 % de dinero, la mas barata: es la puerta
# del arbol) y CUATRO CAMINOS DIAGONALES que salen de ella, uno por lado, y cada
# camino cuesta lo mismo que los otros (COST_BRANCH). Lo que dan los cuatro son
# las cuatro cosas que ya se pueden subir en el juego -el dano, la velocidad, los
# huecos del armario y los Pinchos-, para que el arbol no invente nada nuevo:
# aqui se compra mas de lo mismo.
#
# POR QUE ESTA AQUI Y NO EN Game. Esto es una tabla, como LootDB: cambiar un
# precio o anadir un nodo es tocar este fichero y nada mas. Game guarda que
# nodos tienes comprados y saca de aqui los multiplicadores; el panel dibuja lo
# que hay en esta lista, en las posiciones que hay en esta lista.
#
# LOS NODOS NUEVOS VAN AL FINAL DE SU CAMINO. El requisito de cada nodo es el
# anterior de su rama (`req`), asi que estirar un camino es anadir una fila con
# el pos mas lejos y el `req` del ultimo; ni Game ni el panel cambian.
class_name SkillTree
extends RefCounted

## Lo que se puede comprar: una compra por nodo (LEVELS), que es lo que pide el
## arbol de ahora. Vive aqui y no escrito en Game para que el dia que un nodo se
## pueda subir varias veces el maximo viaje con el nodo.
const LEVELS := 1

## La separacion de un camino: (+-SEP.x, +-SEP.y) son los cuatro centros
## diagonales. Las medidas estan elegidas para que el arbol ENTERO quepa de una
## vez en la ventana del panel (992x634 de dibujo en una vista de 1472x800, de la
## que el rebirth se queda los 150 de arriba): abrir el panel y ver los cinco
## nodos sin tocar nada es lo primero que se agradece, y el arrastre esta para
## cuando el arbol crezca, que es cuando hara falta. Los dos son multiplos de 8
## para no descuadrar el pixelado.
const SEP := Vector2(336, 208)

## Lo que cuesta una mejora de camino. Todas iguales a proposito: el que mira el
## arbol tiene que poder contar de un vistazo lo que le falta, y cuatro precios
## distintos convierten eso en una sopa de numeros.
const COST_BRANCH := 3
## Y lo que cuesta la del centro, que es la puerta: una moneda, o sea el primer
## rebirth. Si costara mas, el primer arbol comprado llegaria demasiado tarde.
const COST_CENTER := 1

## El nombre con el que se escribe cada stat en pantalla, y el que se lee en el
## aviso de compra. Uno solo para las dos cosas: dos nombres para el mismo stat
## se desincronizan solos.
const STAT_NAME := {
	"money": "DINERO",
	"damage": "DANO",
	"speed": "VELOCIDAD",
	"locker": "ARMARIO",
	"spikes": "PINCHOS",
}

## El unico stat que NO es un porcentaje: los huecos del armario son una cuenta
## (dos huecos mas, no un 2 % mas de no se que).
const SLOTS_STAT := "locker"

## Los nodos, EN ORDEN. El primero es el centro y los otros cuatro son los
## caminos diagonales, en el sentido de las agujas del reloj desde arriba a la
## izquierda.
##
## `stat` dice a que multiplicador entra (ver Game.skill_bonus y los cinco
## `*_multiplier`), `value` lo que suma por nivel, `pos` donde se dibuja en
## coordenadas del arbol (el centro es 0,0) y `req` el nodo que hay que tener
## antes: vacio es "no hace falta nada".
##
## `desc` Y `detail` SON EL TEXTO DE LA FICHA (ver skill_card.gd), como en los
## items de la tienda: `desc` es la linea corta que se lee de un vistazo y
## `detail` la explicacion larga, partida en lineas por UIKit.wrap(). La larga
## tiene que caber en DETAIL_LINES_MAX lineas (unas 40 letras cada una) y por eso
## esta escrita asi de corta: lo que no cabe se dibuja ENCIMA de los numeros de
## la ficha, y eso no da ningun error, solo una pantalla ilegible. El smoke test
## lo comprueba nodo por nodo.
##
## EN MAYUSCULAS, como todos los rotulos del juego: la fuente es de mapa de bits y
## NO TIENE MINUSCULAS, asi que una letra minuscula no sale "en minuscula", sale
## un cuadro de basura (paso con estas explicaciones, y no lo vio ningun check de
## los que miden si el texto cabe: el texto cabia). Hay un check que lo mira.
##
## EL DIBUJO DE CADA NODO ES EL DEL STAT, no un icono nuevo: los vinilos son el
## DINERO, las cartas el DANO y las zapatillas la VELOCIDAD (ver LootDB.LOOT_KINDS,
## que es donde estan esos tipos), y el armario y los pinchos son las dos piezas
## de la tienda que dan esas dos cosas. Asi el arbol se lee sin leyenda.
const NODES: Array = [
	{
		"id": "money", "stat": "money", "value": 0.30, "cost": COST_CENTER,
		"pos": Vector2(0, 0), "art": "pack_vinyls", "req": "",
		"desc": "TODO LO QUE VENDES VALE MAS",
		"detail": "SUBE EL VALOR DE TODO LO QUE VENDAS. ES LA PUERTA DEL ARBOL:"
			+ " LOS CAMINOS DE LOS LADOS NO SE ABREN SIN ELLA. SE SUMA A LOS"
			+ " VINILOS DEL ARMARIO.",
	},
	{
		"id": "damage", "stat": "damage", "value": 0.20, "cost": COST_BRANCH,
		"pos": Vector2(-SEP.x, -SEP.y), "art": "pack_cards", "req": "money",
		"desc": "LOS SOBRES CAEN ANTES",
		"detail": "MULTIPLICA EL DANO DE CADA GOLPE, O SEA LO QUE TARDA UN SOBRE"
			+ " EN ABRIRSE. SE SUMA A LAS CARTAS DEL ARMARIO. LOS PINCHOS VAN"
			+ " POR SU CUENTA.",
	},
	{
		"id": "speed", "stat": "speed", "value": 0.20, "cost": COST_BRANCH,
		"pos": Vector2(SEP.x, -SEP.y), "art": "pack_sneakers", "req": "money",
		"desc": "CADA GOLPE TARDA MENOS",
		"detail": "MULTIPLICA LA VELOCIDAD CON LA QUE AVANZA LA COLA DE LA MESA."
			+ " SE SUMA A LO QUE DAN LAS ZAPATILLAS DEL ARMARIO.",
	},
	{
		"id": "locker", "stat": "locker", "value": 2.0, "cost": COST_BRANCH,
		"pos": Vector2(-SEP.x, SEP.y), "art": "item_armario", "req": "money",
		"desc": "DOS HUECOS MAS PARA EXPONER",
		"detail": "DOS HUECOS MAS DE ARMARIO, O SEA DOS OBJETOS EXPUESTOS MAS:"
			+ " EL ARMARIO REPARTE LOS BONUS DE DANO, VELOCIDAD, DINERO Y"
			+ " REBIRTH.",
	},
	{
		"id": "spikes", "stat": "spikes", "value": 0.30, "cost": COST_BRANCH,
		"pos": Vector2(SEP.x, SEP.y), "art": "item_pinchos", "req": "money",
		"desc": "PINCHOS QUE HACEN MAS DANO",
		"detail": "MULTIPLICA EL DANO DE LOS PINCHOS, QUE SE REPARTE ENTRE LOS"
			+ " SOBRES DE LA MESA. SIN EL PC Y LOS PINCHOS NO HAY NADA QUE"
			+ " SUBIR.",
	},
]


# --------------------------------------------------------------------------- #
# Consultas
# --------------------------------------------------------------------------- #

static func node_count() -> int:
	return NODES.size()


static func node_at(index: int) -> Dictionary:
	return NODES[clampi(index, 0, NODES.size() - 1)]


## La fila de un nodo, o {} si ese id no existe. Devolver vacio y no el primero
## (como hace LootDB con los sobres) es a proposito: aqui el que pregunta casi
## siempre viene de un GUARDADO, y un nodo que ya no existe no puede convertirse
## en el nodo de al lado sin que nadie se entere.
static func node_by_id(id: String) -> Dictionary:
	for n in NODES:
		if str(n["id"]) == id:
			return n
	return {}


static func has_node(id: String) -> bool:
	return not node_by_id(id).is_empty()


## Todo lo que hay que tener antes de poder comprar un nodo. Vacio es "nada".
static func req_of(id: String) -> String:
	return str(node_by_id(id).get("req", ""))


## La linea corta de la ficha de un nodo.
static func desc_of(id: String) -> String:
	return str(node_by_id(id).get("desc", ""))


## Y la explicacion larga.
static func detail_of(id: String) -> String:
	return str(node_by_id(id).get("detail", ""))


static func levels_of(id: String) -> int:
	return LEVELS


## Como se escribe un stat al que el arbol lleva sumado `total`: "+30 % DE
## DINERO", "2 HUECOS DE ARMARIO". Se escribe DESDE el numero, no al lado: un
## texto escrito a mano se queda mintiendo en cuanto alguien toca el `value`.
##
## Lo usan las DOS caras de la ficha: lo que da un nodo (effect_text) y lo que
## lleva sumado el stat ahora mismo y lo que sumara al comprarlo (el AHORA y el
## AL COMPRARLO). Un solo sitio para el formato porque dos se desincronizan solos.
static func total_text(stat: String, total: float) -> String:
	if stat == SLOTS_STAT:
		return "%d HUECOS DE ARMARIO" % roundi(total)
	return "+%d %% DE %s" % [roundi(total * 100.0), str(STAT_NAME[stat])]


## Como se escribe el efecto de un nodo: "+30 % DE DINERO", "+2 HUECOS DE
## ARMARIO". Es el total de su stat con el signo de mas delante: un nodo SUMA.
##
## El signo NO lo pone total_text() para los huecos de armario (alli el total es
## una cuenta: "2 HUECOS DE ARMARIO"), y los de porcentaje ya lo llevan dentro
## ("+30 % DE DINERO"): anadirlo siempre daba "++30 % DE DINERO", que es lo que se
## vio en las capturas y no rompe ningun check (el texto sigue cabiendo).
static func effect_text(id: String) -> String:
	var n := node_by_id(id)
	if n.is_empty():
		return ""
	var stat := str(n["stat"])
	var texto := total_text(stat, float(n["value"]))
	return "+" + texto if stat == SLOTS_STAT else texto


## Los ids de los nodos, en orden.
static func ids() -> Array:
	var out: Array = []
	for n in NODES:
		out.append(str(n["id"]))
	return out


## Lo que hay DIBUJADO, en coordenadas del arbol: la caja de los nodos mas lo que
## se sale de ella. La usa el panel para centrar el arbol al abrir y para no
## dejarlo salir de la vista al arrastrar.
##
## Los margenes son los del dibujo de un nodo, no un numero redondo: medio lado
## de la chapa hacia arriba (NODE/2), el rotulo del efecto hacia abajo y la caja
## de ese rotulo hacia los lados. Con margenes de mas, el arbol se centra un poco
## alto y la barra del rebirth se le come la fila de arriba.
static func bounds() -> Rect2:
	# Se arranca con el PRIMER nodo y no con un rectangulo vacio de INF: un
	# rectangulo que empieza en INF tiene su final en INF, y merge() nunca lo baja
	# (el final se queda en INF y la caja sale infinita, con lo que el centrado y
	# los topes del arrastre dejan de significar nada).
	var box := Rect2(Vector2(NODES[0]["pos"]), Vector2.ZERO)
	for n in NODES:
		box = box.merge(Rect2(n["pos"], Vector2.ZERO))
	return box.grow_individual(160.0, 88.0, 160.0, 130.0)


## El nivel de cada nodo que trae un guardado, limpio: fuera los ids que ya no
## existan (o que se hayan escrito a mano en el fichero) y los niveles por encima
## del maximo. Devolver el diccionario limpio y no tocar el que llega es lo que
## permite que el guardado viejo no rompa nada.
static func clean_levels(raw) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for id in ids():
		var lvl := int((raw as Dictionary).get(id, 0))
		if lvl > 0:
			out[id] = clampi(lvl, 0, levels_of(id))
	return out
