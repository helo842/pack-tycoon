# SkillTree - el arbol de mejoras del rebirth: los nodos, lo que cuestan y lo
# que dan.
#
# QUE ES. El rebirth paga MONEDAS (una por cada 1,5 M que haya en el contador al
# reiniciar, ver LootDB.rebirth_coins_for) y esas monedas se gastan AQUI. Antes no
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
# sin romper el principio de la partida. El del armario no sigue con mas huecos
# (media pantalla de exposicion): sigue con el CAMINO DEL REBIRTH (COST_REQUIRE).
#
# Y DEBAJO DEL CENTRO, LA CALIDAD DE VIDA. Los cuatro caminos diagonales son
# numeros que suben; la rama de abajo son INTERRUPTORES que quitan trabajo de
# encima (ver QOL_STAT): guardar lo que eliges, el golpe que sobra, la tienda que
# se compra sola (AUTO_ITEMS) y el armario que se ordena. Van aparte porque no se
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
## Las tres de debajo del AUTO GUARDAR van a 352 una de otra: a 176
## los tres rotulos de esa fila se pisaban.
const QOL_WIDE := 352.0

## El precio de cada interruptor de calidad de vida. Suben al bajar la rama y no
## valen lo que un +20 %: los de arriba son un lujo barato (1) y el armario, que
## es el que mas trabajo quita, es el caro (4). La rama entera son 12 monedas, o
## sea ocho rebirth, y se puede comprar por partes en cualquier orden dentro de
## su columna.
const COST_QOL_CARRY := 2
const COST_QOL_LOCKER := 4
## Las compras automaticas de la tienda: suben de una en una por la columna.
const COST_QOL_AUTO_TOOLS := 3
const COST_QOL_AUTO_LUCK := 4
const COST_QOL_AUTO_CRIT := 5
## TORMENTA DORADA, la que alarga la GOLDEN RAIN.
const COST_RAIN_PLUS := 3
## El AUTO GUARDAR: la puerta de la rama (cuelga del centro) porque es el que
## mas trabajo quita en cuanto la partida se llena de fichas.
const COST_QOL_AUTOSTORE := 2
## Las habilidades tenian su precio prestado de SIN FICHA (2) y de MESA LIMPIA
## (3); al quitar SIN FICHA se quedan con sus numeros propios.
const COST_ABIL_CHARGE := 2
const COST_ABIL := 3

## LAS DOS RAMAS DE LOS LADOS (la de la punteria a la izquierda y la de los
## eventos a la derecha). Aqui SI cada nodo cuesta segun lo que da, y no por
## anillo: lo flojo (el combo, +1 % por paso) es barato y lo que mas cambia la
## partida (la zona dorada ancha, los dorados mas a menudo) es lo caro. Por eso
## cada rama va de barato a caro: se compra de dentro afuera.
##
## dev/balance.gd arbol dijo que con +50 % y 2-6 monedas estas dos ramas apenas
## se notaban (7,8 -> 7,7 min hasta el siguiente rebirth, por 27 monedas): se
## doblo lo que dan y se bajo el precio.
const COST_COMBO := 1
const COST_STREAK := 2
const COST_SWEET := 3
const COST_HAPPY := 1
const COST_VIP := 2
const COST_BOSS := 3
const COST_GOLDEN := 4
## Donde empiezan esas dos ramas (dos SEP.x desde el centro, para que el primer
## nodo no se meta entre el dano y el armario) y lo que hay de nodo a nodo: 480
## y no 336 porque sus rotulos ("+60 % DE ZONA DORADA") miden mas de 320 y a
## 336 se pisaban en la captura.
const SIDE_START := 672.0
const SIDE_STEP := 480.0

## Lo que se devuelve al cargar una partida que tenia comprado un nodo que ya no
## existe (ATAJOS y SIN FICHA se quitaron por inutiles, MESA LIMPIA porque la mesa
## ya no guarda objetos y el TASADOR porque lo sustituye la GOLDEN RAIN): sin esto,
## las monedas gastadas en ellos se perdian sin aviso.
const REFUND := {"qol_keys": 1, "qol_chaff": 2, "qol_table": 3, "abil_appraise": 3}

## EL CAMINO DEL REBIRTH: el del armario sigue por su diagonal con dos nodos que
## hacen el rebirth mas fuerte, no obligatorio (la partida avanza igual sin el):
## que pida menos y que pague mas. Los mas caros del arbol porque cada rebirth
## que se acorta o que paga una moneda mas se nota en TODAS las partidas que
## vienen despues. Son la base de la futura ASCENSION (un rebirth del rebirth).
const COST_REQUIRE := 6
const COST_COINS := 10

## LEYENDA: la corona del arbol, MUY grande (BIG_SCALE) y arriba del todo. Pide
## TODO el arbol (ver reqs_of) y NO SE DIBUJA hasta tenerlo (ver rebirth_panel.gd,
## node_shown): es el premio de haberlo comprado entero, no un nodo mas que se ve
## desde el principio. Da de todo: +100 % de dinero, +50 % de dano, velocidad y
## Pinchos, y las habilidades recargan el doble de rapido.
const LEGEND := "legend"
const COST_LEGEND := 15
const BIG_SCALE := 2.0

## LOS FINALES DE CAMINO: un nodo grande (CAP_SCALE, menos que LEYENDA) al final
## de cada camino. Fuertes en lo suyo pero menos que LEYENDA. El de abajo
## (FABRICA) no sube numeros: automatiza.
const CAP_SCALE := 1.25
const COST_CAP := 10
const COST_CAP_REBIRTH := 12
const COST_CAP_SIDE := 6
const FACTORY := "qol_factory"
const COST_FACTORY := 8
## Lo que suma la mejora del centro al dinero con el que empieza cada partida
## (stat "start", ver Game.start_money). 25.000 es el sobre de VINILOS 2 nada
## mas empezar: el primer rebirth se nota en el primer minuto.
const START_BONUS := 25000.0

## El nombre con el que se escribe cada stat en pantalla, y el que se lee en el
## aviso de compra. Uno solo para las dos cosas: dos nombres para el mismo stat
## se desincronizan solos.
const STAT_NAME := {
	"money": "DINERO",
	"damage": "DANO",
	"speed": "VELOCIDAD",
	"locker": "ARMARIO",
	"spikes": "PINCHOS",
	"streak": "RACHA",
	"sweet": "ZONA ORO",
	"combo": "COMBO",
	"happy": "HORA FELIZ",
	"boss": "TIEMPO JEFE",
	"golden": "DORADOS",
	"vip": "PAGO VIP",
	"require": "REBAJA",
}

## El unico stat que NO es un porcentaje: los huecos del armario son una cuenta
## (dos huecos mas, no un 2 % mas de no se que).
const SLOTS_STAT := "locker"
## Y la otra cuenta: monedas de rebirth de mas en cada rebirth.
const COINS_STAT := "coins"

## El stat de los INTERRUPTORES: no hay numero que sumar, el nodo se tiene o no
## se tiene. Game.skill_bonus() no lo consulta nunca (nadie pregunta por "qol"),
## asi que su `value` solo esta para que la fila tenga la misma forma que las
## demas; quien pregunta de verdad es Game.skill_owned(id), con los ids de abajo.
##
## Los ids van aqui y no escritos a mano en game.gd y en tabla_element.gd: son el
## nombre con el que media partida pregunta "¿tengo los atajos?", y un id suelto
## mal escrito no da ningun error, solo una mejora que no hace nada.
const QOL_STAT := "qol"
const QOL_CARRY := "qol_carry"
const QOL_LOCKER := "qol_locker"
const QOL_AUTOSTORE := "qol_autostore"
const QOL_AUTO_TOOLS := "qol_auto_tools"
const QOL_AUTO_LUCK := "qol_auto_luck"
const QOL_AUTO_CRIT := "qol_auto_crit"
## El nodo que alarga la GOLDEN RAIN (ver Gameplay.RAIN_EXTRA).
const RAIN_PLUS := "abil_rain_plus"

## Que items de la tienda deja comprar solos cada nodo de compra automatica. Los
## ids son los de LootDB.ITEMS. La tienda pone el boton AUTO en los que salgan
## aqui con su nodo comprado.
const AUTO_ITEMS := {
	QOL_AUTO_TOOLS: ["tijeras", "guantes"],
	QOL_AUTO_LUCK: ["trebol", "ojo_verde"],
	QOL_AUTO_CRIT: ["armario", "laser"],
}

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
## CADA NODO TIENE SU PROPIO DIBUJO, tree_<id> (tools/tree_designs.py): el
## objeto de su nombre (MAZA una maza, CACTUS un cactus...). Antes reutilizaban
## sprites del stat (el sobre de cartas para el dano, las zapatillas para la
## velocidad...) y media docena de nodos eran el mismo dibujo, con nombres que no
## casaban ("MAZA" con un sobre de cartas).
const NODES: Array = [
	{
		"id": "money", "stat": "money", "value": 0.50, "cost": COST_CENTER,
		"bonus": {"start": START_BONUS},
		"pos": Vector2(0, 0), "art": "tree_money", "req": "",
		"desc": "VENDES MAS Y SALES CON 25.000",
		"detail": "TODO LO QUE VENDES VALE UN 50 % MAS Y CADA PARTIDA EMPIEZA"
			+ " CON 25.000 EN VEZ DE 500. ES LA PUERTA DEL ARBOL: NADA SE"
			+ " ABRE SIN ELLA.",
		"effect": "TRASTIENDA",
	},
	{
		"id": "damage", "stat": "damage", "value": 0.20, "cost": COST_BRANCH,
		"pos": Vector2(-SEP.x, -SEP.y), "art": "tree_damage", "req": "money",
		"desc": "LOS SOBRES CAEN ANTES",
		"detail": "MULTIPLICA EL DANO DE CADA GOLPE, O SEA LO QUE TARDA UN SOBRE"
			+ " EN ABRIRSE. SE SUMA A LAS CARTAS DEL ARMARIO. LOS PINCHOS VAN"
			+ " POR SU CUENTA.",
		"effect": "BATE",
	},
	{
		"id": "speed", "stat": "speed", "value": 0.20, "cost": COST_BRANCH,
		"pos": Vector2(SEP.x, -SEP.y), "art": "tree_speed", "req": "money",
		"desc": "CADA GOLPE TARDA MENOS",
		"detail": "MULTIPLICA LA VELOCIDAD CON LA QUE AVANZA LA COLA DE LA MESA."
			+ " SE SUMA A LO QUE DAN LAS ZAPATILLAS DEL ARMARIO.",
		"effect": "REFLEJOS",
	},
	{
		"id": "locker", "stat": "locker", "value": 2.0, "cost": COST_BRANCH,
		"pos": Vector2(-SEP.x, SEP.y), "art": "tree_locker", "req": "money",
		"desc": "DOS HUECOS MAS PARA EXPONER",
		"detail": "DOS HUECOS MAS DE ARMARIO, O SEA DOS OBJETOS EXPUESTOS MAS:"
			+ " EL ARMARIO REPARTE LOS BONUS DE DANO, VELOCIDAD, DINERO Y"
			+ " REBIRTH.",
		"effect": "ESCAPARATE",
	},
	{
		"id": "spikes", "stat": "spikes", "value": 0.30, "cost": COST_BRANCH,
		"pos": Vector2(SEP.x, SEP.y), "art": "tree_spikes", "req": "money",
		"desc": "PINCHOS QUE HACEN MAS DANO",
		"detail": "MULTIPLICA EL DANO DE LOS PINCHOS, QUE SE REPARTE ENTRE LOS"
			+ " SOBRES DE LA MESA. SIN EL PC Y LOS PINCHOS NO HAY NADA QUE"
			+ " SUBIR.",
		"effect": "ESPINAS",
	},

	# --- EL SEGUNDO Y EL TERCER ANILLO ------------------------------------ #
	#
	# El dano, la velocidad y los Pinchos siguen por su diagonal dos nodos mas.
	# Cada uno cuelga del anterior (`req`), asi que un camino se compra DE ARRIBA
	# ABAJO y no se puede saltar al fondo. El del armario sigue con el camino del
	# rebirth, mas abajo.
	{
		"id": "damage_2", "stat": "damage", "value": 0.25, "cost": COST_BRANCH2,
		"pos": Vector2(-SEP.x * 2.0, -SEP.y * 2.0), "art": "tree_damage_2",
		"req": "damage",
		"desc": "LOS SOBRES CAEN AUN ANTES",
		"detail": "OTRO 25 % DE DANO ENCIMA DEL CAMINO DE ARRIBA. SE SUMA A EL"
			+ " Y A LAS CARTAS DEL ARMARIO: CON EL CAMINO Y ESTE, EL GOLPE VA"
			+ " POR ENCIMA DEL DOBLE.",
		"effect": "PALANCA",
	},
	{
		"id": "damage_3", "stat": "damage", "value": 0.35, "cost": COST_BRANCH3,
		"pos": Vector2(-SEP.x * 3.0, -SEP.y * 3.0), "art": "tree_damage_3",
		"req": "damage_2",
		"desc": "EL GOLPE MAS DURO DEL ARBOL",
		"detail": "EL FONDO DEL CAMINO DEL DANO: 35 % MAS, QUE CON LOS DOS"
			+ " NODOS DE ARRIBA ES CASI EL DOBLE DE LO QUE PEGAS SIN EL"
			+ " ARBOL. LOS PINCHOS VAN POR SU CAMINO.",
		"effect": "MAZA",
	},
	{
		"id": "speed_2", "stat": "speed", "value": 0.25, "cost": COST_BRANCH2,
		"pos": Vector2(SEP.x * 2.0, -SEP.y * 2.0), "art": "tree_speed_2",
		"req": "speed",
		"desc": "LA COLA DE LA MESA ACELERA",
		"detail": "OTRO 25 % DE VELOCIDAD ENCIMA DEL CAMINO DE ARRIBA, QUE SE"
			+ " SUMA A EL Y A LAS ZAPATILLAS DEL ARMARIO.",
		"effect": "CARRERILLA",
	},
	{
		"id": "speed_3", "stat": "speed", "value": 0.35, "cost": COST_BRANCH3,
		"pos": Vector2(SEP.x * 3.0, -SEP.y * 3.0), "art": "tree_speed_3",
		"req": "speed_2",
		"desc": "LA MESA NO PARA",
		"detail": "EL FONDO DEL CAMINO DE LA VELOCIDAD: 35 % MAS, QUE CON LOS"
			+ " DOS NODOS DE ARRIBA ES CASI EL DOBLE DE RAPIDO QUE SIN EL"
			+ " ARBOL.",
		"effect": "VELOCISTA",
	},
	{
		"id": "spikes_2", "stat": "spikes", "value": 0.35, "cost": COST_BRANCH2,
		"pos": Vector2(SEP.x * 2.0, SEP.y * 2.0), "art": "tree_spikes_2",
		"req": "spikes",
		"desc": "LOS PINCHOS PICAN MAS",
		"detail": "OTRO 35 % DE DANO DE PINCHOS ENCIMA DEL CAMINO DE ARRIBA."
			+ " SE REPARTE ENTRE LOS SOBRES DE LA MESA, ASI QUE CON LA MESA"
			+ " LLENA ES DONDE MAS SE NOTA.",
		"effect": "CARDO",
	},
	{
		"id": "spikes_3", "stat": "spikes", "value": 0.50, "cost": COST_BRANCH3,
		"pos": Vector2(SEP.x * 3.0, SEP.y * 3.0), "art": "tree_spikes_3",
		"req": "spikes_2",
		"desc": "PINCHOS DE FIN DE PARTIDA",
		"detail": "EL FONDO DEL CAMINO DE LOS PINCHOS: 50 % MAS, EL NODO MAS"
			+ " FUERTE DEL ARBOL EN PORCENTAJE. CON LOS DOS DE ARRIBA LOS"
			+ " PINCHOS PEGAN MAS QUE NADA.",
		"effect": "CACTUS",
	},

	# --- EL CAMINO DEL REBIRTH (sigue al del armario) ---------------------- #
	{
		"id": "require", "stat": "require", "value": 0.15, "cost": COST_REQUIRE,
		"pos": Vector2(-SEP.x * 2.0, SEP.y * 2.0), "art": "tree_require",
		"req": "locker",
		"desc": "EL REBIRTH PIDE MENOS",
		"detail": "EL REBIRTH SE PUEDE HACER CON UN 15 % MENOS DE DINERO EN EL"
			+ " CONTADOR. LAS MONEDAS SE CUENTAN IGUAL.",
		"effect": "REGATEO",
	},
	{
		"id": "coins", "stat": COINS_STAT, "value": 1.0, "cost": COST_COINS,
		"pos": Vector2(-SEP.x * 3.0, SEP.y * 3.0), "art": "tree_coins",
		"req": "require",
		"desc": "CADA REBIRTH PAGA MAS",
		"detail": "UNA MONEDA DE REBIRTH MAS CADA VEZ QUE REINICIES, ENCIMA DE"
			+ " LO QUE DE EL CONTADOR Y LA ELECTRONICA.",
		"effect": "PROPINA",
	},

	# --- LEYENDA (el nodo grande del final) ------------------------------- #
	{
		"id": LEGEND, "stat": "money", "value": 1.0, "cost": COST_LEGEND,
		"bonus": {"damage": 0.5, "speed": 0.5, "spikes": 0.5},
		# Sin `req`: lo pide TODO, y eso lo calcula reqs_of() (escrito a mano aqui
		# se quedaria corto en cuanto se anadiera un nodo).
		"pos": Vector2(0, -QOL_STEP * 4.25), "art": "tree_legend",
		"req": [], "scale": BIG_SCALE,
		"desc": "LA MEJORA DEFINITIVA",
		"detail": "+100 % DINERO Y +50 % DANO, VELOCIDAD Y PINCHOS. Y LAS"
			+ " HABILIDADES SE RECARGAN EL DOBLE DE RAPIDO. PIDE TODO EL ARBOL.",
		"effect": "LEYENDA",
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
		"id": QOL_CARRY, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_CARRY,
		"pos": Vector2(0, QOL_STEP * 2.0), "art": "tree_qol_carry",
		"req": QOL_AUTOSTORE,
		"desc": "EL GOLPE QUE SOBRA NO SE TIRA",
		"detail": "EL DANO QUE LE SOBRA A UN GOLPE PASA AL SIGUIENTE SOBRE"
			+ " QUE GOLPEES. CON LA CAJA A UN TOQUE, ESE GOLPE YA NO SE PIERDE.",
		"effect": "SOBRANTE",
	},
	# LAS COMPRAS AUTOMATICAS DE LA TIENDA: APRENDIZ y AMULETO bajan por la
	# izquierda y ENCARGADO (armario y laser) cuelga de ARMARIO SOLO por la
	# derecha, para que la rama quede simetrica con FABRICA abajo en medio. Cada
	# nodo deja comprar solos dos items (ver AUTO_ITEMS); en la tienda
	# sale un boton AUTO en esos items, y de todos los que tengan el AUTO puesto se
	# compra primero el mas barato (ver Game.auto_item_pick).
	{
		"id": QOL_AUTO_TOOLS, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_AUTO_TOOLS,
		"pos": Vector2(-QOL_WIDE, QOL_STEP * 2.0), "art": "tree_qol_auto_tools",
		"req": QOL_AUTOSTORE,
		"desc": "TIJERAS Y GUANTES SOLOS",
		"detail": "LAS TIJERAS Y LOS GUANTES DE LA TIENDA SE COMPRAN SOLOS EN"
			+ " CUANTO TE LLEGA. EN LA TIENDA, EL BOTON AUTO LOS APAGA.",
		"effect": "APRENDIZ",
	},
	{
		"id": QOL_AUTO_LUCK, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_AUTO_LUCK,
		"pos": Vector2(-QOL_WIDE, QOL_STEP * 3.0), "art": "tree_qol_auto_luck",
		"req": QOL_AUTO_TOOLS,
		"desc": "TREBOL Y OJO VERDE SOLOS",
		"detail": "LA SUERTE (TREBOL) Y LA PROBABILIDAD DE CRITICO (OJO VERDE)"
			+ " SE COMPRAN SOLAS. PRIMERO SIEMPRE LO MAS BARATO.",
		"effect": "AMULETO",
	},
	{
		"id": QOL_AUTO_CRIT, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_AUTO_CRIT,
		"pos": Vector2(QOL_WIDE, QOL_STEP * 3.0), "art": "tree_qol_auto_crit",
		"req": QOL_LOCKER,
		"desc": "ARMARIO Y LASER SOLOS",
		"detail": "EL ARMARIO Y EL DANO CRITICO (LASER) SE COMPRAN SOLOS."
			+ " PRIMERO SIEMPRE LO MAS BARATO DE LO QUE TENGA EL AUTO.",
		"effect": "ENCARGADO",
	},
	{
		"id": QOL_LOCKER, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_LOCKER,
		"pos": Vector2(QOL_WIDE, QOL_STEP * 2.0), "art": "tree_qol_locker",
		"req": QOL_AUTOSTORE,
		"desc": "EXPONER YA NO ES COMPARAR",
		"detail": "AL EXPONER ALGO, SI YA HAY UNA PIEZA DE SU TIPO ENTRA LA"
			+ " MEJOR. LA PEOR VUELVE AL INVENTARIO.",
		"effect": "ARMARIO SOLO",
	},
	{
		"id": QOL_AUTOSTORE, "stat": QOL_STAT, "value": 1.0, "cost": COST_QOL_AUTOSTORE,
		"pos": Vector2(0, QOL_STEP), "art": "tree_qol_autostore",
		"req": "money",
		"desc": "GUARDA LO QUE TU ELIJAS",
		"detail": "EN AJUSTES ELIGES TIPO, PSA Y RAREZA. LO QUE CUMPLE SE GUARDA"
			+ " SOLO EN EL INVENTARIO; LO DEMAS SE VENDE SOLO. SIN FICHAS.",
		"effect": "AUTO GUARDAR",
	},

	# --- LAS HABILIDADES (la rama de arriba) ------------------------------ #
	#
	# Tres botones con recarga que aparecen en la barra de abajo a la derecha
	# (ver Gameplay.ABILITIES y game.gd). Son interruptores como los de calidad
	# de vida -se tienen o no- pero de accion: se pulsan en mitad de la partida.
	# Suben desde el centro, al contrario que la calidad de vida, y el golpe
	# cargado es la puerta de las otras dos.
	{
		"id": "abil_charge", "stat": QOL_STAT, "value": 1.0, "cost": COST_ABIL_CHARGE,
		"pos": Vector2(0, -QOL_STEP), "art": "tree_abil_charge", "req": "money",
		"desc": "UN GOLPE QUE VALE POR CINCO",
		"detail": "HABILIDAD (TECLA 1): EL SIGUIENTE GOLPE QUE DES HACE X5 DE"
			+ " DANO. SE RECARGA EN 40 S.",
		"effect": "GOLPE CARGADO",
	},
	{
		"id": "abil_frenzy", "stat": QOL_STAT, "value": 1.0, "cost": COST_ABIL,
		"pos": Vector2(-QOL_SIDE, -QOL_STEP * 2.0), "art": "tree_abil_frenzy",
		"req": "abil_charge",
		"desc": "LA MESA SE GOLPEA SOLA",
		"detail": "HABILIDAD (TECLA 2): DURANTE 8 S TODOS LOS SOBRES DE LA MESA"
			+ " SE GOLPEAN SOLOS, SIN CLICS. SE RECARGA EN 90 S.",
		"effect": "FRENESI",
	},
	{
		"id": "abil_rain", "stat": QOL_STAT, "value": 1.0, "cost": COST_ABIL,
		"pos": Vector2(QOL_SIDE, -QOL_STEP * 2.0), "art": "tree_abil_rain",
		"req": "abil_charge",
		"desc": "LLUEVEN OBJETOS HOLO",
		"detail": "HABILIDAD (TECLA 3): 10 S EN LOS QUE CADA OBJETO DE LOS SOBRES"
			+ " QUE COMPRES TIENE UN 30 % DE SALIR HOLO: BRILLA Y VALE EL"
			+ " DOBLE. SE RECARGA EN 80 S.",
		"effect": "GOLDEN RAIN",
	},
	{
		"id": RAIN_PLUS, "stat": QOL_STAT, "value": 1.0, "cost": COST_RAIN_PLUS,
		"pos": Vector2(QOL_SIDE, -QOL_STEP * 3.0), "art": "tree_abil_rain_plus",
		"req": "abil_rain",
		"desc": "LA GOLDEN RAIN DURA MAS",
		"detail": "LA GOLDEN RAIN DURA 10 S MAS: 20 S EN LOS QUE LOS SOBRES QUE"
			+ " COMPRES PUEDEN TRAER OBJETOS HOLO.",
		"effect": "TORMENTA DORADA",
	},
	# --- LA PUNTERIA (rama de la izquierda) ------------------------------- #
	#
	# Lo que sube el golpe perfecto y el combo (ver Gameplay). Numeros, como los
	# caminos diagonales, pero cada uno con su precio: ver COST_COMBO.
	{
		"id": "combo", "stat": "combo", "value": 1.0, "cost": COST_COMBO,
		"pos": Vector2(-SIDE_START, 0), "art": "tree_combo", "req": "money",
		"desc": "EL COMBO AGUANTA MAS",
		"detail": "EL TIEMPO ENTRE SOBRE Y SOBRE PARA NO PERDER EL COMBO DE"
			+ " APERTURA DURA EL DOBLE.",
		"effect": "RITMO",
	},
	{
		"id": "streak", "stat": "streak", "value": 1.0, "cost": COST_STREAK,
		"pos": Vector2(-SIDE_START - SIDE_STEP, 0), "art": "tree_streak", "req": "combo",
		"desc": "CADA PERFECTO SEGUIDO PEGA MAS",
		"detail": "CADA PASO DE LA RACHA DE PERFECTOS SUBE EL GOLPE EL DOBLE"
			+ " DE LO NORMAL. CON LA RACHA LLENA SE NOTA MUCHO.",
		"effect": "EN RACHA",
	},
	{
		"id": "sweet", "stat": "sweet", "value": 1.0, "cost": COST_SWEET,
		"pos": Vector2(-SIDE_START - SIDE_STEP * 2.0, 0), "art": "tree_sweet", "req": "streak",
		"desc": "LA ZONA DORADA ES MAS ANCHA",
		"detail": "EL TRAMO BLANCO DEL ANILLO ES EL DOBLE: MAS GOLPES EN LA"
			+ " ZONA DORADA, QUE PEGAN MAS Y SUMAN DOS A LA RACHA.",
		"effect": "PUNTO DULCE",
	},

	# --- LOS EVENTOS (rama de la derecha) --------------------------------- #
	#
	# Lo que dura o lo a menudo que sale cada evento (ver Gameplay, Eventos).
	{
		"id": "happy", "stat": "happy", "value": 1.0, "cost": COST_HAPPY,
		"pos": Vector2(SIDE_START, 0), "art": "tree_happy",
		"req": "money",
		"desc": "LA HORA FELIZ DURA MAS",
		"detail": "LA HORA FELIZ, LA QUE HACE QUE UN TIPO DE BOTIN VALGA MAS,"
			+ " DURA EL DOBLE.",
		"effect": "FIESTA",
	},
	{
		"id": "vip", "stat": "vip", "value": 0.50, "cost": COST_VIP,
		"pos": Vector2(SIDE_START + SIDE_STEP, 0), "art": "tree_vip", "req": "happy",
		"desc": "EL COMPRADOR VIP PAGA MAS",
		"detail": "EL COMPRADOR VIP PAGA UN 50 % MAS DE LO QUE YA PAGABA: DE X2"
			+ " A X3.",
		"effect": "CLIENTE DE ORO",
	},
	{
		"id": "boss", "stat": "boss", "value": 0.60, "cost": COST_BOSS,
		"pos": Vector2(SIDE_START + SIDE_STEP * 2.0, 0), "art": "tree_boss", "req": "vip",
		"desc": "MAS TIEMPO PARA EL JEFE",
		"detail": "EL RELOJ DEL JEFE DE SOBRE DURA UN 60 % MAS. MAS JEFES ROTOS"
			+ " SON MAS OBJETOS BUENOS.",
		"effect": "PRORROGA",
	},
	{
		"id": "golden", "stat": "golden", "value": 0.75, "cost": COST_GOLDEN,
		"pos": Vector2(SIDE_START + SIDE_STEP * 3.0, 0), "art": "tree_golden",
		"req": "boss",
		"desc": "MAS SOBRES DORADOS",
		"detail": "LOS SOBRES DORADOS SALEN UN 75 % MAS A MENUDO Y ESPERAN UN"
			+ " 75 % MAS EN LA MESA ANTES DE IRSE.",
		"effect": "FIEBRE DEL ORO",
	},
	# --- LOS FINALES DE CAMINO (nodos grandes, ver CAP_SCALE) -------------- #
	{
		"id": "cap_damage", "stat": "damage", "value": 0.60, "cost": COST_CAP,
		"pos": Vector2(-SEP.x * 4.0, -SEP.y * 4.0), "art": "tree_cap_damage",
		"req": "damage_3", "scale": CAP_SCALE,
		"desc": "FIN DEL CAMINO DEL DANO",
		"detail": "UN 60 % MAS DE DANO DE GOLPE, ENCIMA DE TODO EL CAMINO.",
		"effect": "MARTILLO",
	},
	{
		"id": "cap_speed", "stat": "speed", "value": 0.60, "cost": COST_CAP,
		"pos": Vector2(SEP.x * 4.0, -SEP.y * 4.0), "art": "tree_cap_speed",
		"req": "speed_3", "scale": CAP_SCALE,
		"desc": "FIN DEL CAMINO DE VELOCIDAD",
		"detail": "UN 60 % MAS DE VELOCIDAD DE GOLPE, ENCIMA DE TODO EL CAMINO.",
		"effect": "TURBO",
	},
	{
		"id": "cap_spikes", "stat": "spikes", "value": 0.80, "cost": COST_CAP,
		"pos": Vector2(SEP.x * 4.0, SEP.y * 4.0), "art": "tree_cap_spikes",
		"req": "spikes_3", "scale": CAP_SCALE,
		"desc": "FIN DEL CAMINO DE PINCHOS",
		"detail": "UN 80 % MAS DE DANO DE PINCHOS, ENCIMA DE TODO EL CAMINO.",
		"effect": "ERIZO",
	},
	{
		"id": "cap_rebirth", "stat": COINS_STAT, "value": 1.0, "cost": COST_CAP_REBIRTH,
		"bonus": {"require": 0.10},
		"pos": Vector2(-SEP.x * 4.0, SEP.y * 4.0), "art": "tree_cap_rebirth",
		"req": "coins", "scale": CAP_SCALE,
		"desc": "FIN DEL CAMINO DEL REBIRTH",
		"detail": "OTRA MONEDA MAS EN CADA REBIRTH Y EL REBIRTH PIDE UN 10 % MENOS"
			+ " (SE SUMA A LA REBAJA).",
		"effect": "HUCHA DE ORO",
	},
	{
		"id": "cap_aim", "stat": "streak", "value": 1.0, "cost": COST_CAP_SIDE,
		"bonus": {"sweet": 0.5},
		"pos": Vector2(-SIDE_START - SIDE_STEP * 3.0, 0), "art": "tree_cap_aim",
		"req": "sweet", "scale": CAP_SCALE,
		"desc": "FIN DE LA PUNTERIA",
		"detail": "LA RACHA PEGA OTRO 100 % MAS POR PASO Y LA ZONA DORADA CRECE"
			+ " OTRO 50 %.",
		"effect": "OJO DE HALCON",
	},
	{
		"id": "cap_events", "stat": "golden", "value": 0.50, "cost": COST_CAP_SIDE,
		"bonus": {"happy": 0.5, "vip": 0.25, "boss": 0.4},
		"pos": Vector2(SIDE_START + SIDE_STEP * 4.0, 0), "art": "tree_cap_events",
		"req": "golden", "scale": CAP_SCALE,
		"desc": "FIN DE LOS EVENTOS",
		"detail": "MAS DORADOS (+50 %), HORA FELIZ MAS LARGA (+50 %), VIP QUE PAGA"
			+ " MAS (+25 %) Y MAS RELOJ PARA EL JEFE (+40 %).",
		"effect": "IMAN",
	},
	{
		"id": FACTORY, "stat": QOL_STAT, "value": 1.0, "cost": COST_FACTORY,
		# EL FINAL DE LA RAMA, como en las demas: debajo de todo, en medio, y
		# colgando de lo ultimo de cada columna (AMULETO, SOBRANTE y ENCARGADO).
		"pos": Vector2(0, QOL_STEP * 4.0), "art": "tree_qol_factory",
		"req": [QOL_AUTO_LUCK, QOL_CARRY, QOL_AUTO_CRIT], "scale": CAP_SCALE,
		"desc": "LA PARTIDA SE JUEGA SOLA",
		"detail": "CADA PARTIDA EMPIEZA CON LOS PINCHOS Y EL PC, Y LO AUTOMATICO"
			+ " SIGUE ENCENDIDO TRAS EL REBIRTH. CERRADO GANAS HASTA DOS HORAS.",
		"effect": "FABRICA",
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


## Lo que hay que tener antes de poder comprar un nodo: el primero de sus
## requisitos (LEYENDA pide dos, ver reqs_of). Vacio es "nada".
static func req_of(id: String) -> String:
	var r := reqs_of(id)
	return str(r[0]) if not r.is_empty() else ""


## TODOS los requisitos de un nodo. `req` es un id o una lista de ids. LEYENDA
## pide todos los demas nodos del arbol.
static func reqs_of(id: String) -> Array:
	if id == LEGEND:
		var todos := ids()
		todos.erase(LEGEND)
		return todos
	var r = node_by_id(id).get("req", "")
	if typeof(r) == TYPE_ARRAY:
		return r
	return [] if str(r) == "" else [str(r)]


## Lo que suma un nodo a un stat: su `value` si es su stat, y lo de `bonus`
## (LEYENDA y el centro dan varias cosas a la vez).
static func node_bonus(n: Dictionary, stat: String) -> float:
	var total := float(n["value"]) if str(n["stat"]) == stat else 0.0
	return total + float((n.get("bonus", {}) as Dictionary).get(stat, 0.0))


## Lo grande que se dibuja un nodo (1 los normales, BIG_SCALE el del final).
static func scale_of(id: String) -> float:
	return float(node_by_id(id).get("scale", 1.0))


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
	if stat == COINS_STAT:
		return "%d MONEDA EXTRA" % roundi(total)
	return "+%d %% DE %s" % [roundi(total * 100.0), str(STAT_NAME[stat])]


## Como se escribe el efecto de un nodo: "+30 % DE DINERO", "+2 HUECOS DE
## ARMARIO". Es el total de su stat con el signo de mas delante: un nodo SUMA.
##
## El signo NO lo pone total_text() para los huecos de armario (alli el total es
## una cuenta: "2 HUECOS DE ARMARIO"), y los de porcentaje ya lo llevan dentro
## ("+30 % DE DINERO"): anadirlo siempre daba "++30 % DE DINERO", que es lo que se
## vio en las capturas y no rompe ningun check (el texto sigue cabiendo).
##
## Un interruptor NO suma nada: su texto es su nombre ("MESA LIMPIA"), escrito a
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
	return "+" + texto if stat in [SLOTS_STAT, COINS_STAT] else texto


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
		# Lo que un nodo grande se sale de mas por cada lado (88 es medio nodo).
		var extra := Vector2.ONE * 88.0 * (scale_of(str(n["id"])) - 1.0)
		box = box.merge(Rect2(Vector2(n["pos"]) - extra, extra * 2.0))
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
