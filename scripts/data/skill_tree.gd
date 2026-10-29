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
# Y TRES DE ESOS CAMINOS SIGUEN. El del dano, el de la velocidad y el de los
# Pinchos tienen DOS nodos mas cada uno, en la misma diagonal y mas lejos del
# centro: es lo unico que se puede seguir subiendo de una partida a otra sin que
# el juego invente un sistema nuevo, y por eso son los tres que crecen. Cada
# anillo cuesta mas que el anterior (COST_BRANCH, COST_BRANCH2, COST_BRANCH3) y
# da menos por moneda que el de antes, que es lo que hace que el arbol tenga fondo
# sin romper el principio de la partida. El del armario NO sigue: sus huecos son
# una cuenta (dos mas de golpe) y un cuarto anillo de armario seria media pantalla
# de exposicion.
#
# Y DEBAJO DEL CENTRO, LA CALIDAD DE VIDA. Los cuatro caminos diagonales son
# numeros que suben; la rama de abajo son INTERRUPTORES que quitan trabajo de
# encima (ver QOL_STAT): atajos de teclado, vender solo lo barato, el golpe que
# sobra, la mesa que se vacia y el armario que se ordena. Van aparte porque no se
# comparan con un +20 %: se compran o no se compran, y por eso son de un solo
# nivel y mucho mas baratos. La rama baja en dos columnas para no alargar el
# arbol como si fuera una cadena de cinco.
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
## diagonales, y cada anillo que sigue esta a otro tanto. Las medidas estan
## elegidas para que el PRIMER anillo quepa entero en la ventana del panel
## (1472x800, de la que el rebirth se queda los 150 de arriba): abrir el panel y
## ver el centro con sus cuatro caminos sin tocar nada es lo primero que se
## agradece, y el arrastre esta para el resto del arbol, que es lo que se sale.
##
## Los dos son multiplos de 8 para no descuadrar el pixelado. El alto (208) no se
## puede subir: el primer anillo entero, con su rotulo, tiene que caber entre la
## barra del rebirth y el borde de abajo del panel, y con 240 ya no cabe (se
## salia 14 px). Lo que asoma por detras de la barra lo resuelve el panel, que no
## pinta el rotulo de un nodo tapado (ver rebirth_panel.gd, _update_covers).
const SEP := Vector2(336, 208)

## Lo que cuesta una mejora de camino. Todas iguales a proposito: el que mira el
## arbol tiene que poder contar de un vistazo lo que le falta, y cuatro precios
## distintos convierten eso en una sopa de numeros.
const COST_BRANCH := 3
## Y lo que cuestan el SEGUNDO y el TERCER anillo de los tres caminos que siguen
## (el dano, la velocidad y los Pinchos). Un precio por anillo y no por camino,
## por lo mismo que arriba: los tres nodos de un anillo se ven a la misma
## distancia del centro y tienen que costar lo mismo, o el arbol deja de
## leerse como cuatro rayas y pasa a ser una lista de precios. Suben en cada
## anillo porque el segundo se compra con una partida ya montada (mas monedas
## por rebirth) y el tercero es el fondo del arbol.
const COST_BRANCH2 := 5
const COST_BRANCH3 := 8
## Y lo que cuesta la del centro, que es la puerta: una moneda, o sea el primer
## rebirth. Si costara mas, el primer arbol comprado llegaria demasiado tarde.
const COST_CENTER := 1

## La separacion vertical de la rama de abajo. 320 y no los 208 de SEP porque
## aqui los nodos van UNO DEBAJO DE OTRO y lo que hay que dejar libre es la
## chapa MAS su rotulo: medio lado (88) mas el rotulo, que cuelga a 202 del
## centro y mide 30 de alto (217). Con 240 el rotulo de arriba se metia dentro de
## la chapa de abajo y el test de encuadre lo cazaba; 320 es el primer multiplo
## de 8 que deja aire entre los dos.
const QOL_STEP := 320.0
## Y la separacion a los lados de las dos columnas de abajo: 176 pone una columna
## en -176 y la otra en 176, que con el rotulo de 320 de ancho deja 32 px entre
## los dos textos de una misma fila.
const QOL_SIDE := 176.0

## El precio de cada interruptor de calidad de vida. Suben al bajar la rama y no
## valen lo que un +20 %: los de arriba son un lujo barato (1) y el armario, que
## es el que mas trabajo quita, es el caro (4). La rama entera son 12 monedas, o
## sea ocho rebirth, y se puede comprar por partes en cualquier orden dentro de
## su columna.
const COST_QOL_KEYS := 1
const COST_QOL_CHAFF := 2
const COST_QOL_CARRY := 2
const COST_QOL_TABLE := 3
const COST_QOL_LOCKER := 4

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

## El stat de los INTERRUPTORES: no hay numero que sumar, el nodo se tiene o no
## se tiene. Game.skill_bonus() no lo consulta nunca (nadie pregunta por "qol"),
## asi que su `value` solo esta para que la fila tenga la misma forma que las
## demas; quien pregunta de verdad es Game.skill_owned(id), con los ids de abajo.
##
## Los ids van aqui y no escritos a mano en game.gd y en tabla_element.gd: son el
## nombre con el que media partida pregunta "¿tengo los atajos?", y un id suelto
## mal escrito no da ningun error, solo una mejora que no hace nada.
const QOL_STAT := "qol"
const QOL_KEYS := "qol_keys"
const QOL_CHAFF := "qol_chaff"
const QOL_CARRY := "qol_carry"
const QOL_TABLE := "qol_table"
const QOL_LOCKER := "qol_locker"

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

	# --- EL SEGUNDO Y EL TERCER ANILLO ------------------------------------ #
	#
	# El dano, la velocidad y los Pinchos siguen por su diagonal dos nodos mas.
	# Cada uno cuelga del anterior (`req`), asi que un camino se compra DE ARRIBA
	# ABAJO y no se puede saltar al fondo. El de arriba a la derecha (armario) no
	# sigue: sus huecos son de dos en dos y un cuarto anillo seria media pantalla
	# de exposicion, no una mejora.
	{
		"id": "damage_2", "stat": "damage", "value": 0.25, "cost": COST_BRANCH2,
		"pos": Vector2(-SEP.x * 2.0, -SEP.y * 2.0), "art": "pack_cards",
		"req": "damage",
		"desc": "LOS SOBRES CAEN AUN ANTES",
		"detail": "OTRO 25 % DE DANO ENCIMA DEL CAMINO DE ARRIBA. SE SUMA A EL"
			+ " Y A LAS CARTAS DEL ARMARIO: CON EL CAMINO Y ESTE, EL GOLPE VA"
			+ " POR ENCIMA DEL DOBLE.",
	},
	{
		"id": "damage_3", "stat": "damage", "value": 0.35, "cost": COST_BRANCH3,
		"pos": Vector2(-SEP.x * 3.0, -SEP.y * 3.0), "art": "pack_cards",
		"req": "damage_2",
		"desc": "EL GOLPE MAS DURO DEL ARBOL",
		"detail": "EL FONDO DEL CAMINO DEL DANO: 35 % MAS, QUE CON LOS DOS"
			+ " NODOS DE ARRIBA ES CASI EL DOBLE DE LO QUE PEGAS SIN EL"
			+ " ARBOL. LOS PINCHOS VAN POR SU CAMINO.",
	},
	{
		"id": "speed_2", "stat": "speed", "value": 0.25, "cost": COST_BRANCH2,
		"pos": Vector2(SEP.x * 2.0, -SEP.y * 2.0), "art": "pack_sneakers",
		"req": "speed",
		"desc": "LA COLA DE LA MESA ACELERA",
		"detail": "OTRO 25 % DE VELOCIDAD ENCIMA DEL CAMINO DE ARRIBA, QUE SE"
			+ " SUMA A EL Y A LAS ZAPATILLAS DEL ARMARIO.",
	},
	{
		"id": "speed_3", "stat": "speed", "value": 0.35, "cost": COST_BRANCH3,
		"pos": Vector2(SEP.x * 3.0, -SEP.y * 3.0), "art": "pack_sneakers",
		"req": "speed_2",
		"desc": "LA MESA NO PARA",
		"detail": "EL FONDO DEL CAMINO DE LA VELOCIDAD: 35 % MAS, QUE CON LOS"
			+ " DOS NODOS DE ARRIBA ES CASI EL DOBLE DE RAPIDO QUE SIN EL"
			+ " ARBOL.",
	},
	{
		"id": "spikes_2", "stat": "spikes", "value": 0.35, "cost": COST_BRANCH2,
		"pos": Vector2(SEP.x * 2.0, SEP.y * 2.0), "art": "item_pinchos",
		"req": "spikes",
		"desc": "LOS PINCHOS PICAN MAS",
		"detail": "OTRO 35 % DE DANO DE PINCHOS ENCIMA DEL CAMINO DE ARRIBA."
			+ " SE REPARTE ENTRE LOS SOBRES DE LA MESA, ASI QUE CON LA MESA"
			+ " LLENA ES DONDE MAS SE NOTA.",
	},
	{
		"id": "spikes_3", "stat": "spikes", "value": 0.50, "cost": COST_BRANCH3,
		"pos": Vector2(SEP.x * 3.0, SEP.y * 3.0), "art": "item_pinchos",
		"req": "spikes_2",
		"desc": "PINCHOS DE FIN DE PARTIDA",
		"detail": "EL FONDO DEL CAMINO DE LOS PINCHOS: 50 % MAS, EL NODO MAS"
			+ " FUERTE DEL ARBOL EN PORCENTAJE. CON LOS DOS DE ARRIBA LOS"
			+ " PINCHOS PEGAN MAS QUE NADA.",
	},

	# --- LA CALIDAD DE VIDA (los interruptores) --------------------------- #
	#
	# Lo que va de aqui abajo no sube ningun numero: quita trabajo. Se dibuja en
	# `effect` en vez de calcularse con el valor, porque un interruptor no tiene
	# "+20 %" que enseñar: debajo de la chapa va su nombre y ya esta.
	#
	# Y son de UN NIVEL, como todas: pagar dos veces por tener los atajos no
	# significa nada.
	{
		"id": QOL_KEYS, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_KEYS,
		"pos": Vector2(0, QOL_STEP), "art": "ui_icon_settings", "req": "money",
		"desc": "TECLAS EN VEZ DE LA BARRA",
		"detail": "T LA TIENDA, A EL ARMARIO, R EL REBIRTH Y V VENDE LA MESA."
			+ " ESC CIERRA LO QUE ESTE ABIERTO, COMO SIEMPRE.",
		"effect": "ATAJOS",
	},
	{
		"id": QOL_CHAFF, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_CHAFF,
		"pos": Vector2(-QOL_SIDE, QOL_STEP * 2.0), "art": "ui_tag_price",
		"req": QOL_KEYS,
		"desc": "LO BARATO SE VENDE SOLO",
		"detail": "LOS OBJETOS DE TRES ESTRELLAS O MENOS SE VENDEN NADA MAS"
			+ " SALIR, SIN ABRIR SU FICHA. EL DINERO ENTRA IGUAL.",
		"effect": "SIN FICHA",
	},
	{
		"id": QOL_CARRY, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_CARRY,
		"pos": Vector2(QOL_SIDE, QOL_STEP * 2.0), "art": "item_guantes",
		"req": QOL_KEYS,
		"desc": "EL GOLPE QUE SOBRA NO SE TIRA",
		"detail": "EL DANO QUE LE SOBRA A UN GOLPE PASA AL SIGUIENTE SOBRE"
			+ " QUE GOLPEES. CON LA CAJA A UN TOQUE, ESE GOLPE YA NO SE PIERDE.",
		"effect": "SOBRANTE",
	},
	{
		"id": QOL_TABLE, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_TABLE,
		"pos": Vector2(-QOL_SIDE, QOL_STEP * 3.0), "art": "ui_icon_auto_open",
		"req": QOL_CHAFF,
		"desc": "LA MESA SE VENDE SOLA",
		"detail": "LO QUE LLEVA UN RATO EN LA MESA SE VENDE AL PRECIO DE"
			+ " SIEMPRE. SIRVE PARA VOLVER DE LA TIENDA Y ENCONTRARLA LIBRE.",
		"effect": "MESA LIMPIA",
	},
	{
		"id": QOL_LOCKER, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_LOCKER,
		"pos": Vector2(QOL_SIDE, QOL_STEP * 3.0), "art": "ui_icon_display_case",
		"req": QOL_CARRY,
		"desc": "EXPONER YA NO ES COMPARAR",
		"detail": "AL EXPONER ALGO, SI YA HAY UNA PIEZA DE SU TIPO ENTRA LA"
			+ " MEJOR. LA PEOR VUELVE AL INVENTARIO.",
		"effect": "ARMARIO SOLO",
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
##
## Un interruptor NO suma nada: su texto es su nombre ("SIN FICHA"), escrito a
## mano en la fila, y es lo que se dibuja debajo de su chapa y lo que titula su
## ficha.
static func effect_text(id: String) -> String:
	var n := node_by_id(id)
	if n.is_empty():
		return ""
	if n.has("effect"):
		return str(n["effect"])
	var stat := str(n["stat"])
	var texto := total_text(stat, float(n["value"]))
	return "+" + texto if stat == SLOTS_STAT else texto


## ¿Este nodo es un interruptor de calidad de vida? Lo es todo el que no suma un
## numero a un stat, y lo preguntan la ficha (no tiene AHORA ni AL COMPRARLO de
## porcentajes) y los tests (que no le buscan un `value` con sentido).
static func is_qol(id: String) -> bool:
	var n := node_by_id(id)
	return not n.is_empty() and str(n["stat"]) == QOL_STAT


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
