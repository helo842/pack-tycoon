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
# Cada paquete tiene "hp": su resistencia. Ya no se abre esperando un tiempo,
# sino golpeandolo: cada carga del boton resta el dano del jugador (ver
# damage_per_hit) y hacen faltan varios ciclos hasta romper la caja. La vida
# sube con el nivel del paquete, que es su escalon de precio.
#
# LA VIDA VA CON LA RAIZ DEL PRECIO, no con el precio: hp = 21,5 x raiz(precio)
# (redondeado a numeros legibles). Un sobre que cuesta CUATRO veces mas no es
# cuatro veces mas duro, es el doble. Eso deja el ritmo de la partida en manos
# del DANO del jugador -los items-, que es la escalera que se sube comprando, y
# hace que dos sobres seguidos duren un rato parecido aunque el precio se haya
# multiplicado por tres. Los cuatro tipos de un escalon van de blando a duro en
# el mismo orden que su precio (SOBRES, VINILOS, ZAPATILLAS, ELECTRONICA).
#
# ESTA CURVA ES LA QUE DECIDE CUANTO DURA LA PARTIDA, y por eso esta medida y no
# elegida a ojo: subir la vida es alargar el rato que estas dandole al boton, y
# bajar el exponente (vida mas cerca del precio) hace que los sobres caros paguen
# mas por segundo y la partida se acorta. Cuanto se sube lo dice dev/balance.gd,
# que simula la partida entera: hoy el primer rebirth cae sobre los 17 minutos.
#
# SON DOCE: CUATRO TIPOS x TRES ESCALONES. Primero van los cuatro de siempre
# -SOBRES, VINILOS, ZAPATILLAS, ELECTRONICA- y luego se repiten dos veces mas,
# en el mismo orden, cada vez mas caros y con el botin multiplicado (ver
# "vmult"). El primero de todos (SOBRES) cuesta 0: es el sobre inicial, gratis
# en cualquier momento de la partida, para que nunca se quede sin poder abrir
# nada. El ultimo (ELECTRONICA 3) cuesta diez millones.
#
# LOS TRES ESCALONES DE UN TIPO COMPARTEN TABLA DE BOTIN. La escribe entera el
# escalon 1 en su propio "loot", y los otros dos solo dicen de quien es
# ("loot_id") y cuanto multiplican el valor ("vmult"). Subir de escalon es
# pagar mas por el mismo botin multiplicado, y no hay que mantener doce listas
# de objetos que se irian desincronizando (y con ellas los pesos y las rarezas).
#
# Lo que SI cambia con el escalon es el nombre y el dibujo del sobre: el 2 va de
# pan de oro y el 3 de laca con joya. Antes los tres escalones de un tipo
# compartian el mismo sprite, y en una columna de doce con el mismo dibujo
# repetido tres veces no habia forma de saber cual valia un millon.
const PACKS: Array = [
	{
		"id": "cards", "name": "SOBRES", "price": 0, "hp": 215, "vmult": 0.8,
		"art": "pack_cards", "art_open": "pack_cards_open",
		"loot": [
			{"id": "card_c", "name": "CARTA COMUN", "art": "loot_card_common", "graded": true,
				"kind": "cards", "rarity": "common", "value": 60, "w": 55},
			{"id": "card_r", "name": "CARTA EDICION LIMITADA", "art": "loot_card_edited", "graded": true,
				"kind": "cards", "rarity": "rare", "value": 85, "w": 30},
			{"id": "card_e", "name": "CARTA VIEJA", "art": "loot_card_vintage", "graded": true,
				"kind": "cards", "rarity": "epic", "value": 135, "w": 12},
			{"id": "card_l", "name": "CARTA HOLOGRAFICA", "art": "loot_card_foil", "graded": true,
				"kind": "cards", "rarity": "legendary", "value": 210, "w": 3},
		],
	},
	{
		"id": "vinyls", "name": "VINILOS", "price": 500, "hp": 480, "vmult": 1.2,
		"art": "pack_vinyls", "art_open": "pack_vinyls_open",
		"loot": [
			{"id": "vinyl_c", "name": "VINILO", "art": "loot_vinyl", "graded": true,
				"kind": "vinyls", "rarity": "common", "value": 170, "w": 52},
			{"id": "vinyl_d", "name": "DOBLE LP", "art": "loot_vinyl_double", "graded": true,
				"kind": "vinyls", "rarity": "rare", "value": 235, "w": 31},
			{"id": "vinyl_n", "name": "EDICION NUMERADA", "art": "loot_vinyl_numbered",
				"graded": true, "kind": "vinyls", "rarity": "epic", "value": 380, "w": 14},
			{"id": "vinyl_x", "name": "PRENSADO EN COLOR", "art": "loot_vinyl_color",
				"graded": true, "kind": "vinyls", "rarity": "legendary", "value": 600, "w": 3},
		],
	},
	{
		"id": "sneakers", "name": "ZAPATILLAS", "price": 1900, "hp": 937, "vmult": 1.2,
		"art": "pack_sneakers", "art_open": "pack_sneakers_open",
		"loot": [
			{"id": "shoe_c", "name": "ZAPATILLA BLANCA", "art": "loot_sneaker", "graded": true,
				"kind": "sneakers", "rarity": "common", "value": 620, "w": 48},
			{"id": "shoe_l", "name": "ZAPATILLA DE PIEL", "art": "loot_sneaker_leather",
				"graded": true, "kind": "sneakers", "rarity": "rare", "value": 860, "w": 32},
			{"id": "shoe_r", "name": "ZAPATILLA A RESTAURAR", "art": "loot_sneaker_restore",
				"graded": true, "kind": "sneakers", "rarity": "epic", "value": 1400, "w": 16},
			{"id": "shoe_x", "name": "ZAPATILLA LIMITADA",
				"art": "loot_sneaker_limited", "graded": true,
				"kind": "sneakers", "rarity": "legendary", "value": 2200, "w": 4},
		],
	},
	{
		"id": "electronics", "name": "ELECTRONICA", "price": 6000, "hp": 1665, "vmult": 1.2,
		"art": "pack_electronics", "art_open": "pack_electronics_open",
		"loot": [
			{"id": "cons_c", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 1900, "w": 30},
			{"id": "head_c", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 1700, "w": 20},
			{"id": "cam_c", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 2300, "w": 18},
			{"id": "cart_c", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 1200, "w": 14},
			{"id": "hand_c", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 2100, "w": 7},
			{"id": "cons_r", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 2600, "w": 12},
			{"id": "head_r", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 2200, "w": 10},
			{"id": "cam_r", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 2900, "w": 10},
			{"id": "cart_r", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 1700, "w": 5},
			{"id": "hand_r", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 2700, "w": 5},
			{"id": "cons_e", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 4400, "w": 8},
			{"id": "head_e", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 3600, "w": 7},
			{"id": "cam_e", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 5100, "w": 7},
			{"id": "cart_e", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 2900, "w": 2},
			{"id": "hand_e", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 4500, "w": 4},
			{"id": "cons_l", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 6900, "w": 5},
			{"id": "head_l", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 5800, "w": 2},
			{"id": "cam_l", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 8000, "w": 3},
			{"id": "cart_l", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 5000, "w": 1},
			{"id": "hand_l", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 7400, "w": 2},
			# Los cuatro objetos que tenian sobre propio entran aqui: son los que le
			# faltaban a esta tabla para ser "lo caro" del juego, y sin un sitio se
			# quedaban sin salir nunca (y sus cuarenta sprites con ellos). Los
			# valores van puestos al nivel de esta tabla, no al que tenian.
			{"id": "cab_c", "name": "CABLE", "art": "loot_cable", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 1400, "w": 6},
			{"id": "wat_r", "name": "RELOJ", "art": "loot_watch", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 2000, "w": 6},
			{"id": "ing_e", "name": "LINGOTE DE ORO", "art": "loot_ingot", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 3900, "w": 3},
			{"id": "pwt_l", "name": "RELOJ DE BOLSILLO", "art": "loot_pocket_watch", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 7600, "w": 2},
		],
	},
	# --- los otros ocho sobres ------------------------------------------- #
	# Mismo botin que su escalon 1, mas caro y multiplicado. El NOMBRE y el
	# DIBUJO cambian con el escalon; la tabla de botin no. El escalon 2 va de pan
	# de oro y el 3 de laca con joya (ver tools/make_sprites.py, seccion "escalones
	# 2 y 3"), asi que de un vistazo se sabe cual se esta abriendo sin leer el
	# precio. Los nombres tienen que caber a 28 px en la columna de la izquierda
	# (16 caracteres: PACK_NAME_BOX.x / 28), o UIKit encoge los doce a la vez y el
	# "SOBRES" de arriba se queda enano.
	#
	# DOS REGLAS, Y LAS DOS SE COMPRUEBAN (dev/smoke_test.gd). El precio y el vmult
	# se tocan juntos: subir uno sin subir el otro es un timo.
	#
	# 1. NINGUN SOBRE DE UN ESCALON ES MAS BARATO QUE LOS DEL ANTERIOR. Antes no
	#    era asi: SOBRES ORO costaba 4.000 y la ELECTRONICA del escalon 1 cuesta
	#    6.000, o sea que un sobre de CALIDAD 2 era mas barato que el de calidad 1
	#    MAS CARO. El escalon de arriba multiplica el botin, asi que lo racional era
	#    saltarse la electronica y las zapatillas del escalon 1 -que no se compraban
	#    nunca- y esperar al sobre de arriba. Cada escalon empieza por encima del
	#    techo del anterior: el 2 empieza en 15.000 (el 1 llega a 6.000) y el 3 en
	#    600.000 (el 2 llega a 250.000).
	#
	# 2. CADA SOBRE PAGA UN POCO MAS DE LO QUE CUESTA: entre un 30 y un 45 %, en cualquier
	#    escalon. De ahi salen los vmult de abajo, que NO son el mismo numero para
	#    los doce: lo que paga un sobre es lo que valen los objetos de su tabla, y
	#    el escalon multiplica ese total. Un sobre que cuesta tres veces mas que
	#    otro del mismo escalon tiene que multiplicar tres veces menos para pagar
	#    lo mismo por dinero. Ese 15 % es TODO el margen de la partida, y esta
	#    medido: con un 350 % (que es lo que habia) la partida se terminaba en dos
	#    minutos, porque el capital se multiplicaba por 4,5 en cada sobre y no
	#    habia forma de gastarlo. Ver dev/balance.gd y LootDB.pack_payout().
	#
	# El SOBRES es el que mas multiplica de su escalon, y no es un capricho: su
	# tabla es la que menos vale (cartas de 60 a 210) y su precio no puede bajar
	# del techo del escalon de abajo, asi que sin un vmult mucho mas alto pagaria
	# una decima parte de lo que cuesta. El ELECTRONICA hace lo contrario: su tabla
	# es la mas cara y su vmult es el mas bajo.
	{"id": "cards2", "name": "SOBRES ORO", "price": 15000, "hp": 2633, "vmult": 103.0,
		"loot_id": "cards", "art": "pack_cards2", "art_open": "pack_cards2_open"},
	{"id": "vinyls2", "name": "VINILOS ORO", "price": 40000, "hp": 4300, "vmult": 96.0,
		"loot_id": "vinyls", "art": "pack_vinyls2", "art_open": "pack_vinyls2_open"},
	{"id": "sneakers2", "name": "ZAPATILLAS ORO", "price": 100000, "hp": 6799, "vmult": 62.0,
		"loot_id": "sneakers", "art": "pack_sneakers2", "art_open": "pack_sneakers2_open"},{"id": "electronics2", "name": "ELECTRONICA ORO", "price": 250000, "hp": 10750, "vmult": 50.0, "loot_id": "electronics",
		"art": "pack_electronics2", "art_open": "pack_electronics2_open"},
	{"id": "cards3", "name": "SOBRES LUJO", "price": 600000, "hp": 16654, "vmult": 4080.0,
		"loot_id": "cards", "art": "pack_cards3", "art_open": "pack_cards3_open"},{"id": "vinyls3", "name": "VINILOS LUJO", "price": 1500000, "hp": 26332, "vmult": 3600.0, "loot_id": "vinyls",
		"art": "pack_vinyls3", "art_open": "pack_vinyls3_open"},{"id": "sneakers3", "name": "ZAPATILLAS LUJO", "price": 4000000, "hp": 43000, "vmult": 2520.0, "loot_id": "sneakers",
		"art": "pack_sneakers3", "art_open": "pack_sneakers3_open"},{"id": "electronics3", "name": "ELECTRONICA LUJO", "price": 10000000, "hp": 67989, "vmult": 1980.0, "loot_id": "electronics",
		"art": "pack_electronics3", "art_open": "pack_electronics3_open"},
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
# LA MAYORIA DEL BOTIN VIENE TOCADO, y el 10 es el premio gordo de verdad. La
# tabla es una piramide que se apoya en la 2-4 y se afila hacia arriba, con la
# probabilidad de cada nota escrita debajo:
#
#     nota   1     2     3     4     5     6    7     8    9    10
#     peso  11    13    13    12    10     8    6     4    3     2     (de 82)
#     %   13,4  15,9  15,9  14,6  12,2   9,8  7,3   4,9  3,7   2,4
#
# ANTES ERA AL REVES: la tabla iba de 1 a 16, con el 10 como la nota MAS
# probable (el 22,9 %) y casi la mitad del botin saliendo en 9 o 10. Se pidio
# justo lo contrario -que las notas altas sean raras-, asi que la piramide se ha
# dado la vuelta. El 10 sale una vez de cada cuarenta y pico; el 9, una de cada
# veintisiete. La cola no se aplana: cada nota alta es mas rara que la de abajo.
#
# LA FORMA NO ES CAPRICHO: es la que deja el valor MEDIO del sobre donde estaba.
# Las notas 5 y 10 valen ahora mucho mas (ver GRADE_MULT), asi que si la tabla
# siguiera cargada por arriba cada sobre pagaria un 20 % mas de lo que cuesta y
# el margen de la partida se iria por la ventana. Con esta piramide la nota media
# baja de 7,6 a 4,2 y la media de valor se queda en 1,136 (antes 1,131): medio
# punto de mas, que es lo que el test de los sobres mide como margen (1,39 contra
# 1,38) y lo que deja las partidas donde estaban.
#
# LA SUERTE DEL TREBOL NO ENTRA AQUI. La tabla es fija: el Trebol solo engorda el
# peso del botin raro, epico y legendario (ver _lucky_weight), nunca la nota. Un
# 10 con el Trebol al maximo sigue saliendo una vez de cada cuarenta.
const GRADE_WEIGHTS: Array = [11, 13, 13, 12, 10, 8, 6, 4, 3, 2]
const PSA_MIN := 1
const GRADE_MAX := 10

# --- calidad de vida (los interruptores del arbol) ------------------------- #
#
# Los dos numeros que necesitan las dos mejoras que no son un multiplicador. Van
# aqui y no en la escena porque son equilibrio, igual que el precio de un sobre:
# el dia que la chatarra sea otra, se toca este numero y ya esta.

## Hasta que nota un objeto cuenta como CHATARRA para la mejora SIN FICHA, que
## lo vende sin abrir su tarjeta. Tres y no cuatro porque la nota 4 ya vale lo
## mismo que la media (grade_mult 1.02): vender eso sin preguntar es tirar dinero
## del jugador, y con la 3 (0.86) se vende el 45 % de lo que sale -los pesos de
## GRADE_WEIGHTS- que es justo el trozo que nadie mira.
const AUTO_SELL_GRADE := 3

## Segundos que un objeto puede quedarse quieto en la mesa antes de que la
## mejora MESA LIMPIA lo venda. Doce: lo que tarda uno en mirar una ficha o en
## comprar en la tienda, para que no se venda delante de sus narices lo que
## acaba de salir. Mas corto y la mejora parece que roba; mas largo y la mesa se
## llena igual, que es lo que quita.
const AUTO_SELL_TABLE_AFTER := 12.0

# --------------------------------------------------------------------------- #
# Items equipables (ITEMS SHOP del Idea.pdf)
# --------------------------------------------------------------------------- #
# Sustituyen a las cuatro herramientas. Antes solo acortaban la espera; ahora
# cambian como se abre el paquete: suben el dano, la suerte, el espacio de la
# mesa o la automatizacion. Todos se compran con el mismo dinero.
#
# DOS CLASES DE ITEM, y se nota en la tienda:
#
#   - Los seis de ESTADISTICAS suben de nivel: ocho niveles, cada uno mas caro
#     que el anterior (x1.9) y mas efecto. Es la escalera de siempre.
#   - El PC y los PINCHOS son de COMPRA UNICA: se pagan una vez y ya esta. Su
#     efecto es un si o un no -la automatizacion esta encendida o no-, asi que
#     pagarlos ocho veces no tendria sentido. En la tienda, una fila con precio
#     es algo que aun no tienes (o que puedes subir) y una que pone COMPRADO es
#     una pieza que ya no se vende.
#
# Quien decide cual es cual NO es una lista aparte: son AUTO_ITEM_OPEN y
# AUTO_ITEM_BUY, que son los mismos ids que encienden las automatizaciones. Ver
# item_max_level().
const ITEM_MAX_LEVEL := 8
const ITEM_COST_GROWTH := 1.6
## Niveles que tienen las piezas de las automatizaciones: una compra y ya.
const ITEM_SINGLE_LEVEL := 1

## LAS TIJERAS (el item de dano) tienen su propia escalera de precios EN DOS
## TRAMOS: las tres primeras mejoras son baratas y suben poco -SOFT_COST_GROWTH,
## un 30 % cada una, la mitad de rapido que el x1,6 del resto de la tienda-, y a
## partir de la cuarta el precio se DISPARA (x2,8 sobre lo que costaba la
## tercera). Es lo que se pidio: al principio el dano sale barato y se nota
## enseguida, y en las partidas avanzadas es donde cuesta. La tienda usa el
## mismo item_cost() que los demas, que solo cambia la cuenta para estos dos ids.
const TIJERAS_SOFT_LEVELS := 3
const TIJERAS_COST_GROWTH := 2.8
## Cuanto sube cada una de las tres primeras mejoras sobre la anterior. Antes las
## tres costaban EXACTAMENTE lo mismo, y eso se leia como que el segundo y el
## tercer nivel salian gratis: se pidio que cada una cueste mas que la de antes,
## pero sin que el principio de partida se vuelva lento (de ahi el x1,3 y no el
## x1,6 de la tienda, ni el x2,8 del tramo caro).
const SOFT_COST_GROWTH := 1.3
## LOS GUANTES tienen la MISMA escalera que las Tijeras -tres mejoras baratas que
## suben poco y despues x2,8- pero un poco mas caros: son el segundo item que se
## paga en una partida, cuando el dano ya esta encarrilado y lo que se nota es
## el ritmo.
const GLOVES_SOFT_LEVELS := 3
const GLOVES_COST_GROWTH := 2.8
## EL DOLAR (el item que ABASTA los sobres) usa la misma escalera en dos tramos,
## pero con un salto mas suave: tres mejoras baratas que suben poco (x1,3) y a
## partir de la cuarta x2,3 sobre lo que costaba la tercera. Son 1.500 la primera
## y unas 163.000 la octava: el descuento se nota en TODO lo que compres, asi que
## el ultimo nivel es de los mas caros de la tienda A PROPOSITO, y aun asi se
## paga solo en una partida larga.

const DOLAR_SOFT_LEVELS := 3
const DOLAR_COST_GROWTH := 2.3

## LOS PRECIOS DE LA TIENDA SE DOBLARON de golpe cuando el margen de los sobres
## bajo del 350 % al 15 %. Con la partida nueva (unos dieciseis minutos hasta el
## primer rebirth, un millon ganado) estos numeros son los que hacen que una mejora sea
## una decision -unos miles al principio, decenas de miles a mitad de partida- y
## no un tramite: la tienda es el otro sitio donde se va el dinero, junto con los
## sobres, y las dos cosas compiten.
const ITEMS: Array = [
	{"id": "tijeras", "name": "TIJERAS", "art": "item_tijeras", "base_cost": 540,
		"desc": "MAS DANO POR GOLPE",
		"detail": "SUBE EL DANO DE CADA GOLPE UN 15 % POR NIVEL. LAS TRES PRIMERAS MEJORAS SON BARATAS Y SUBEN POCO; DESPUES EL PRECIO SE DISPARA."},
	{"id": "trebol", "name": "TREBOL", "art": "item_trebol", "base_cost": 840,
		"desc": "MAS BOTIN RARO",
		"detail": "SUBE LAS PROBABILIDADES DE QUE SALGA BOTIN RARO, EPICO O LEGENDARIO. LA NOTA PSA NO CAMBIA. VALE PARA TODOS LOS SOBRES."},
	{"id": "cajon", "name": "CAJON", "art": "item_cajon", "base_cost": 1560,
		"desc": "MAS ESPACIO EN LA MESA",
		"detail": "MAS HUECOS EN LA MESA PARA DEJAR PAQUETES Y OBJETOS A LA VEZ. A PARTIR DEL NIVEL 5 CADA NIVEL DA CINCO HUECOS EN VEZ DE DOS."},
	{"id": "ojo_verde", "name": "OJO VERDE", "art": "item_ojo_verde", "base_cost": 2520,
		"desc": "PROBABILIDAD DE CRITICO",
		"detail": "CADA GOLPE TIENE ESTA PROBABILIDAD DE SER CRITICO, Y UN CRITICO HACE EL DOBLE DE DANO Y SALE EN AMARILLO."},
	{"id": "laser", "name": "LASER", "art": "item_laser", "base_cost": 3600,
		"desc": "MAS DANO CRITICO",
		"detail": "SUBE EL DANO QUE HACE CADA GOLPE CRITICO. SIN CRITICOS NO HACE NADA, ASI QUE VA DETRAS DEL OJO VERDE."},
	{"id": "pc", "name": "PC", "art": "item_pc", "base_cost": 24000,
		"desc": "COMPRA LOS SOBRES SOLO",
		"detail": "COMPRA SOLO, AL RITMO QUE DICE AQUI, EL SOBRE MAS BARATO DE LOS QUE TENGAS MARCADOS EN SU MENU. SE PAGA UNA SOLA VEZ."},
	{"id": "pinchos", "name": "PINCHOS", "art": "item_pinchos", "base_cost": 40000,
		"desc": "ABRE LOS PAQUETES SOLO",
		"detail": "CON LA APERTURA AUTOMATICA ENCENDIDA GOLPEAN TODOS LOS PAQUETES DE LA MESA A LA VEZ, SIN QUE LES HAGAS CLIC. SE PAGAN UNA SOLA VEZ."},
	{"id": "armario", "name": "ARMARIO", "art": "item_armario", "base_cost": 35000,
		"desc": "EXPONE BOTIN Y DA SUS BONUS",
		"detail": "CADA OBJETO EXPUESTO DA EL BONUS DE SU TIPO SEGUN SU NOTA PSA (DEL 2 % AL 15 %): CARTAS DANO, ZAPATILLAS VELOCIDAD, VINILOS DINERO Y ELECTRONICA REBIRTH."},
	# EL NOVENO, Y VA AL FINAL A PROPOSITO: los niveles de un guardado se leen
	# por POSICION, asi que anadir un item en medio muda de sitio los niveles de
	# todos los que vienen detras y una partida vieja se encontraria el dano
	# donde tenia la suerte. Al final no mueve a nadie.
	{"id": "guantes", "name": "GUANTES", "art": "item_guantes", "base_cost": 720,
		"desc": "MAS VELOCIDAD DE GOLPE",
		"detail": "ACELERA LA CARGA UN 15 % POR NIVEL: LOS GOLPES SALEN MAS SEGUIDOS. LAS TRES PRIMERAS SON BARATAS Y SUBEN POCO; DESPUES EL PRECIO SE DISPARA."},
	# EL DECIMO, TAMBIEN AL FINAL y por lo mismo: los niveles de una partida
	# guardada se leen por POSICION (ver game_state.gd), asi que meterlo en medio
	# le cambiaria el item a los niveles de todo el que viniera detras.
	{"id": "dolar", "name": "DOLAR", "art": "item_dolar", "base_cost": 1500,
		"desc": "SOBRES MAS BARATOS",
		"detail": "BAJA EL PRECIO DE TODOS LOS SOBRES UN 5 % POR NIVEL, HASTA UN 40 % CON LOS OCHO. LAS TRES PRIMERAS SON BARATAS Y LAS ULTIMAS MUY CARAS."},
]

## CADA AUTOMATIZACION VA CON SU PIEZA. Los Pinchos son la fuerza (golpean la
## mesa en vez del dedo del jugador) y el PC es la cabeza (el que compra solo).
##
## Antes hacian falta LAS DOS para encender CUALQUIERA de las dos, y eso se
## quito: comprar el PC y que el boton siguiera apagado por no tener los Pinchos
## solo se lee como que la compra no ha servido de nada. Ahora cada boton mira su
## pieza, y comprar una enciende lo suyo sin esperar a la otra.
const AUTO_ITEM_OPEN := "pinchos"
const AUTO_ITEM_BUY := "pc"

# --- el dano y la apertura ------------------------------------------------- #
## Dano de un golpe sin mejoras. El sobre basico (215 de vida) son cinco
## ciclos: con cuarenta y cinco de dano el quinto le sobra algo y el sobrante NO
## se guarda, cada caja empieza de cero. Subio de 18 a 45 en el mismo cambio que
## freno la carga a un tercio (ver CHARGE_TIME): el golpe tarda mas, pero pega
## mas, y el ritmo de la partida no se va al garete.
const BASE_DAMAGE := 45.0
## Cada nivel comprado de CUALQUIER item suma un 15% al dano base. Los dos de
## compra unica (PC y Pinchos) aportan su unico nivel. El item de dano son las
## TIJERAS (ver su escalera de precios en item_cost).
##
## El 25 % de antes hacia que los items lo fueran TODO: con los diez a tope se
## llegaba a casi x40 de dano por segundo, y quien compraba bien se pasaba la
## partida en la mitad de tiempo que quien compraba mal -el jugador no llegaba a
## mirar los sobres-. Ahora el dano sube un 15 % por nivel y los Guantes suman
## aparte su 15 % de velocidad, asi que el TOPE sigue siendo alto (x9,7 de dano
## por x3,9 de velocidad, unos x38 de dano por segundo), pero ya no se llega ahi
## en cuatro compras baratas: Tijeras y Guantes dan las tres primeras mejoras
## baratas (cada una un 30 % mas cara que la anterior) y a partir de ahi
## multiplican por 2,8, y el resto de items suben x1,6 por nivel. El principio de
## partida lo decide el jugador y no la tienda.
const DAMAGE_PER_LEVEL := 0.15
## Segundos que tarda un ciclo de carga del boton. Es el ritmo al que se golpea.
## Un ciclo es un golpe y un clic: la caja no se abre sola de una tirada.
##
## ANTES ERAN 0,55 Y SE FRENO A PROPOSITO: la barra bajaba tan rapido que no
## daba tiempo a verla. Ahora un ciclo tarda el triple, y para que el ritmo no
## se fuera al garete el dano base subio x2,5 en el mismo cambio (ver
## BASE_DAMAGE). Lo que devuelve la velocidad es el item de los GUANTES.
const CHARGE_TIME := 1.65
## Cada nivel comprado acelera la carga un 3% (menos tiempo por golpe).
const CYCLE_SPEED_PER_LEVEL := 0.03
## Los GUANTES: el item de VELOCIDAD. Cada nivel acelera la carga un 15 % mas,
## en la misma cuenta que el 3 % de arriba (el tiempo se divide por 1 + lo que
## sumen los dos). Los tres primeros niveles cuestan lo mismo y despues el
## precio se dispara (ver GLOVES_COST_GROWTH): el ritmo se nota desde la
## primera compra, pero llevarlo al tope es cosa de partidas avanzadas.
const GLOVES_SPEED_PER_LEVEL := 0.15

# --- el critico (Ojo verde + Laser) --------------------------------------- #
## Probabilidad de critico POR NIVEL del Ojo verde: un 5 % por nivel, o sea un
## 40 % con los ocho.
##
## Antes era un 50 % fijo en cuanto comprabas el Ojo verde, y eso lo convertia en
## un interruptor: comprarlo una vez y ya no habia nada mas que subir. Con el 5 %
## por nivel el Ojo verde es una escalera como los demas items (cada nivel se
## paga y se nota) y los ocho niveles juntos no llegan ni a la mitad de los
## golpes, que es lo que se quiere: los criticos siguen siendo un premio.
const CRIT_CHANCE_PER_LEVEL := 0.05
## El critico multiplica el dano; el Laser sube ese multiplicador por nivel.
const CRIT_MULT_BASE := 2.0
const CRIT_MULT_PER_LEVEL := 0.05

# --- otros efectos -------------------------------------------------------- #
## Cuantos paquetes se pueden llevar a la vez: el cupo es el de la mesa (ver
## table_slots). NO HAY ITEM DE CUPO (los Guantes volvieron a la tienda como
## item de VELOCIDAD, ver GLOVES_SPEED_PER_LEVEL), y un clic sigue arrancando
## SIEMPRE un solo paquete, el pulsado; lo que limita es cuantos caben cargando
## a la vez, que es la mesa.
## Trebol: +2% de peso a los objetos no comunes por nivel.
const LUCK_PER_LEVEL := 0.02
## Dolar: descuento sobre el precio de TODOS los sobres. Un 5 % por nivel, o sea
## un 40 % con los ocho.
##
## Se aplica en game_state.pack_price(), que es el UNICO sitio donde se decide lo
## que cuesta un sobre: la columna de la partida y la compra automatica pasan por
## ahi, asi que el descuento no se queda aplicado a medias en una de las dos.
const PACK_DISCOUNT_PER_LEVEL := 0.05
## Cajon: huecos extra en la mesa. 2 por nivel, y 5 a partir del nivel 5.
const DRAWER_BASE := 2
const DRAWER_HIGH := 5
const DRAWER_HIGH_LEVEL := 5
## Mesa sin cajon.
const TABLE_BASE := 8
## Pinchos: fraccion del ritmo de golpes del JUGADOR que reparten entre los
## paquetes de la mesa mientras la apertura automatica esta encendida.
##
## Antes eran 24 de dano por segundo fijos, y hacian dos cosas mal: se quedaban
## cortos en cuanto el jugador subia el dano (el item dejaba de notarse) y eran
## una barbaridad al principio, porque el dano se aplicaba ENTERO a cada paquete
## de la mesa: con los ocho huecos llenos eso es ocho veces el dano del jugador
## y, con el PC y la venta automatica, la partida se abria sola. Ahora pegan el
## 60 % de lo que pega el jugador por segundo REPARTIDO entre los paquetes de la
## mesa: la mesa entera avanza como avanza tu dedo. Sube con los items de dano
## -el item sigue sirviendo toda la partida- y no se multiplica por el numero de
## paquetes, que es lo que lo desequilibraba.
const SPIKE_SHARE := 1.0
## Los Pinchos escalan con el dinero de la partida: cada 10x de dinero que llevas
## suma este 50 % a lo que pegan. Asi en partidas avanzadas siguen notandose.
const SPIKE_PER_DECADE := 0.5
## PC: segundos entre compras automaticas. Con el PC comprado van siempre a este
## ritmo; el valor lento es el de una partida sin PC (que ya no puede pasar,
## porque la compra automatica no se enciende sin el).
const AUTO_BUY_INTERVAL := 0.75
const AUTO_BUY_BASE := 1.2
## Armario: objetos que se pueden exponer. UNO POR NIVEL, de 1 a 8.
##
## Hoy son 8 y no 3 porque el armario ya no es un adorno: cada objeto expuesto da
## el bonus de su tipo (ver LOOT_KINDS) y subirlo de nivel es la forma de poner
## mas piezas a la vez. Con 3 huecos el armario se llenaba en la primera partida y
## dejar de subirlo era lo optimo.
const LOCKER_SLOTS_MAX := 8

# --- lo que da cada tipo de botin expuesto -------------------------------- #
## LAS CUATRO CATEGORIAS NO DAN LO MISMO. Cada tipo de botin, expuesto en el
## armario, aporta su bonus: las cartas suben el dano del golpe, las zapatillas
## aceleran la carga del boton, los vinilos suben el valor de lo que vendes y la
## electronica da mas puntos de rebirth.
##
## El tipo va escrito en cada fila de botin, en "kind" (ver kind_of()), y NO se
## deduce del id ni del dibujo: deducirlo seria una regla escondida que se rompe
## sola en cuanto se anade un objeto con un nombre que no empiece por lo que
## toca. Aqui vive tambien como se llama el bonus para leerlo en la interfaz.
const LOOT_KINDS: Array = [
	{"id": "cards", "name": "CARTAS", "stat": "DANO", "art": "pack_cards"},
	{"id": "vinyls", "name": "VINILOS", "stat": "DINERO", "art": "pack_vinyls"},
	{"id": "sneakers", "name": "ZAPATILLAS", "stat": "VELOCIDAD", "art": "pack_sneakers"},
	{"id": "electronics", "name": "ELECTRONICA", "stat": "REBIRTH", "art": "pack_electronics"},
]
## Lo que aporta UN objeto expuesto segun su nota PSA: de un 2 % en la nota 1 a un
## 15 % en la nota 10, repartido a partes iguales (ver kind_bonus).
##
## Son porcentajes bajos a proposito: un armario lleno de piezas de nota 10 son
## ocho objetos y cada categoria cuenta los suyos, asi que con cuatro categorias
## llenas se llega a un +120 % repartido entre dano, velocidad, dinero y rebirth,
## que ya es una barbaridad sin romper el juego por el camino.
const KIND_BONUS_MIN := 0.02
const KIND_BONUS_MAX := 0.25

# --- el rebirth (la hucha) ------------------------------------------------ #
## Lo que hay que TENER EN EL CONTADOR para poder reiniciarla. Se cuenta el dinero
## que hay EN EL MOMENTO de pulsar REBIRTH (lo mismo que el premio), y no lo
## ganado a lo largo de la partida: el cerdo se lleva lo que hay dentro, asi que
## el requisito es juntarlo y no gastarlo.
##
## LA CIFRA SALE DE MEDIR (dev/balance.gd), no de elegir un numero redondo: en el
## contador de una partida normal hay MILES, no millones -el dinero entra y sale
## comprando sobres-, asi que el millon que pedia el requisito viejo no se junta
## "en el contador" ni en horas. Con 80.000 (0,8 M), el jugador normal llega al
## primer rebirth en ~18 minutos, que es lo que tardaba con el requisito en lo
## ganado: barrer dio 16,3 min con 50.000 y 22,0 con 120.000, y 80.000 es el que
## conserva el ritmo.
const REBIRTH_REQUIRE := 80000
## Cada cuanto DINERO EN EL CONTADOR sale UNA moneda de rebirth. Se cuenta lo que
## tengas EN EL MOMENTO de pulsar REBIRTH, no lo ganado en la partida: el cerdo
## se lleva el dinero que hay dentro, asi que gastarlo antes de reiniciar cuesta
## monedas y guardarlo las da. Con 1,5 millones por moneda, el primer rebirth
## (que se hace con el contador justo en el requisito) da la moneda minima y las
## buenas son las que se terminan con la hucha llena: reiniciar en cuanto se
## puede es una moneda, y aguantar es la unica forma de llevarse mas.
const REBIRTH_COIN_AT := 1500000
## Y LAS MONEDAS SE GASTAN EN EL ARBOL DE MEJORAS, que es donde esta lo que dan
## (ver SkillTree): +30 % de dinero, +20 % de dano, +20 % de velocidad, +2
## huecos de armario y +30 % de pinchos, un nodo cada uno.
##
## Antes cada moneda sumaba un 5 % al valor de lo que vendias SIN hacer nada, y a
## ese precio no habia nada que decidir: se acumulaba sola y el rebirth se hacia
## por inercia. Aqui ya no queda nada de esa paga.

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


## Resistencia de un paquete. Sube con su nivel (su escalon de precio).
static func pack_hp(pack_id: String) -> int:
	return int(pack_by_id(pack_id)["hp"])


## Los objetos que pueden salir de un sobre.
##
## Los escalones 2 y 3 no llevan tabla propia: apuntan a la del escalon 1 con
## "loot_id". Si el id apunta a si mismo (o a nada) se contesta la tabla del
## primer sobre, que es la que siempre existe.
static func loot_table(pack_id: String) -> Array:
	var pack := pack_by_id(pack_id)
	if pack.has("loot"):
		return pack["loot"]
	var source := str(pack.get("loot_id", ""))
	if source == "" or source == str(pack["id"]) or not _has_loot(source):
		return PACKS[0].get("loot", [])
	return pack_by_id(source)["loot"]


static func _has_loot(pack_id: String) -> bool:
	for p in PACKS:
		if p["id"] == pack_id and p.has("loot"):
			return true
	return false


## Lo que multiplica el valor del botin en este escalon del sobre. Es la otra
## mitad del par precio/recompensa: subir de escalon sube los dos, y este numero
## es el que hace que el sobre caro pague mas por el mismo objeto.
static func tier_mult(pack_id: String) -> float:
	return float(pack_by_id(pack_id).get("vmult", 1.0))


## Lo que paga DE MEDIA un paquete: la media de su tabla de botin (ponderada por
## "w") con la nota media y el VALUE_SCALE, todo por su multiplicador de escalon.
##
## Es la mitad "recompensa" del par precio/recompensa, y existe para poder
## COMPROBAR que las dos mitades van juntas: el precio de un sobre tiene que ser
## mas o menos la misma fraccion de lo que paga, en cualquier escalon. Si el
## sobre de arriba pagara menos por dinero que el de abajo, subir de escalon
## seria pagar mas para ganar menos; y si pagara mas, saltarse los baratos seria
## lo racional. Los dos casos rompen la escalera, y los dos se miden con esto.
##
## No cuenta el Trebol (que sube las rarezas) ni el Armario (que multiplica lo
## que dan los objetos expuestos): los dos son del jugador y del momento de la
## partida. Esto es el suelo, con la partida recien empezada y sin nada expuesto.
static func pack_payout(pack_id: String) -> float:
	var total := 0.0
	var peso := 0.0
	for row in loot_table(pack_id):
		total += float(row["value"]) * float(row.get("w", 1))
		peso += float(row.get("w", 1))
	if peso <= 0.0:
		return 0.0
	var nota := 0.0
	var peso_nota := 0.0
	for i in GRADE_WEIGHTS.size():
		nota += float(GRADE_WEIGHTS[i]) * grade_mult(i + 1)
		peso_nota += float(GRADE_WEIGHTS[i])
	return total / peso * (nota / peso_nota) * VALUE_SCALE * tier_mult(pack_id)


static func item_count() -> int:
	return ITEMS.size()


static func item_at(index: int) -> Dictionary:
	return ITEMS[clampi(index, 0, ITEMS.size() - 1)]


static func item_by_id(item_id: String) -> Dictionary:
	for it in ITEMS:
		if it["id"] == item_id:
			return it
	return ITEMS[0]


## Indice de un item por su id. -1 si no existe.
static func item_index(item_id: String) -> int:
	for i in ITEMS.size():
		if ITEMS[i]["id"] == item_id:
			return i
	return -1


## Nivel comprado de un item concreto dentro del array de niveles.
static func item_level(levels: Array, item_id: String) -> int:
	var i := item_index(item_id)
	if i < 0 or i >= levels.size():
		return 0
	return int(levels[i])


# --------------------------------------------------------------------------- #
# Economia de las herramientas
# --------------------------------------------------------------------------- #

## Niveles que tiene un item. 1 para el PC y los Pinchos (compra unica) y
## ITEM_MAX_LEVEL para los siete con niveles.
static func item_max_level(index: int) -> int:
	var item_id := str(ITEMS[clampi(index, 0, ITEMS.size() - 1)]["id"])
	if item_id == AUTO_ITEM_OPEN or item_id == AUTO_ITEM_BUY:
		return ITEM_SINGLE_LEVEL
	return ITEM_MAX_LEVEL


## Lo que cuesta el SIGUIENTE nivel de un item. -1 cuando ya no hay nada que
## vender: porque es de compra unica y ya lo tienes, o porque esta al tope. Es
## "no hay precio", que es lo que la tienda necesita para saber que esa fila ya
## no se puede pagar (y no un precio de cero, que se leeria como un chollo).
static func item_cost(index: int, current_level: int) -> int:
	if current_level >= item_max_level(index):
		return -1
	var base: float = ITEMS[clampi(index, 0, ITEMS.size() - 1)]["base_cost"]
	# TIJERAS Y GUANTES, EN DOS TRAMOS. Las tres primeras mejoras suben poco
	# (SOFT_COST_GROWTH) y a partir de la cuarta el precio se dispara sobre lo que
	# costaba la TERCERA, no sobre la base: asi el salto se nota de verdad (x2,8
	# del ultimo precio barato) aunque las tres primeras ya no valgan lo mismo.
	# El resto de la tienda sigue con su escalera de siempre, x1,6 por nivel.
	var item_id := str(ITEMS[clampi(index, 0, ITEMS.size() - 1)]["id"])
	if item_id == "tijeras" or item_id == "guantes" or item_id == "dolar":
		# El Dolar entra en el mismo tramo doble aunque su salto sea mas suave:
		# tres mejoras seguidas y baratas, y a partir de ahi el precio se separa.
		var growth: float = TIJERAS_COST_GROWTH
		var soft: int = TIJERAS_SOFT_LEVELS
		if item_id == "guantes":
			growth = GLOVES_COST_GROWTH
			soft = GLOVES_SOFT_LEVELS
		elif item_id == "dolar":
			growth = DOLAR_COST_GROWTH
			soft = DOLAR_SOFT_LEVELS
		var suaves := mini(current_level, soft - 1)
		var saltos := maxi(0, current_level - (soft - 1))
		return int(round(base * pow(SOFT_COST_GROWTH, suaves) * pow(growth, saltos)))
	return int(round(base * pow(ITEM_COST_GROWTH, current_level)))


## Una tabla de niveles con UN item puesto al nivel pedido y los demas a cero.
##
## Es lo que deja preguntar "y si este estuviera en el nivel 4" sin tocar la
## partida: las funciones de efecto de abajo solo miran el nivel de SU item
## (crit_chance solo mira el Ojo verde, table_slots solo el Cajon...), asi que
## con los demas a cero se lee el efecto de ese item y nada mas. Lo usa la ficha
## de la tienda para enseñar los numeros de AHORA y los del nivel siguiente.
static func levels_with(index: int, level: int) -> Array:
	var levels: Array = []
	for i in ITEMS.size():
		levels.append(level if i == clampi(index, 0, ITEMS.size() - 1) else 0)
	return levels


## El efecto de un item a un nivel concreto, ya escrito para leerlo.
##
## Devuelve TEXTO y no un numero porque cada efecto se mide en lo suyo (paquetes,
## por ciento, segundos, dano por segundo) y decidir como se escribe eso es parte
## del dato, no del dibujo: asi la ficha de la tienda y cualquier otro sitio que
## lo enseñe dicen exactamente lo mismo.
static func item_effect(index: int, level: int) -> String:
	var levels := levels_with(index, level)
	match str(item_at(index)["id"]):
		"tijeras":
			# El numero es lo que APORTA ese nivel, no lo acumulado: sin comprar no
			# aporta nada, y por eso el nivel 1 y el 2 salen distintos en la ficha
			# (con lo acumulado los dos dirian "+15 %" y no se veria que comprar
			# sirve de algo).
			return "+%d%% DE DANO POR GOLPE" % (roundi(DAMAGE_PER_LEVEL * 100.0)
				if level > 0 else 0)
		"guantes":
			# Lo mismo que las Tijeras, pero con la velocidad: lo que aporta ESTE
			# nivel, no el acumulado (ver el comentario de arriba).
			return "+%d%% DE VELOCIDAD" % (roundi(GLOVES_SPEED_PER_LEVEL * 100.0)
				if level > 0 else 0)
		"trebol":
			return "+%d%% DE BOTIN RARO" % roundi(LUCK_PER_LEVEL * float(level) * 100.0)
		"cajon":
			return "%d HUECOS EN LA MESA" % table_slots(levels)
		"ojo_verde":
			return "%d%% DE GOLPES CRITICOS" % roundi(crit_chance(levels) * 100.0)
		"laser":
			return "X%s DE DANO EN UN CRITICO" % short_number(crit_mult(levels))
		"pc":
			return "UN SOBRE CADA %s S" % short_number(auto_buy_interval(levels))
		"pinchos":
			return "%d DE DANO POR SEGUNDO" % roundi(spike_dps(levels))
		"armario":
			# En singular con uno: la ficha del primer nivel decia "1 OBJETOS
			# EXPUESTOS", y eso se lee en la pantalla donde se decide comprarlo.
			var huecos := locker_slots(levels)
			return "1 OBJETO EXPUESTO" if huecos == 1 else "%d OBJETOS EXPUESTOS" % huecos
		"dolar":
			# Aqui SI se lee el ACUMULADO y no lo que aporta el nivel, al contrario
			# que en las Tijeras y los Guantes: un descuento del 5 % no dice gran
			# cosa, y lo que hay que ver es que al nivel 8 el sobre vale un 40 %
			# menos. En la ficha sale el de ahora y el del nivel siguiente.
			return "-%d%% DE PRECIO EN LOS SOBRES" % roundi(
					pack_discount(levels) * 100.0)
	return ""


## "2.10" -> "2.1". Para los numeros con decimales de los efectos (el
## multiplicador del critico y los segundos del PC), que son los unicos que no se
## escriben con un entero.
static func short_number(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


## Suma de niveles de todos los items. Es la medida de "cuanto llevo mejorado" y
## lo que multiplica el dano base y acelera la carga.
static func total_levels(levels: Array) -> int:
	var total := 0
	for lvl in levels:
		total += int(lvl)
	return total


## Dano de cada golpe: base mas el 15 % por nivel comprado.
static func damage_per_hit(levels: Array) -> float:
	return BASE_DAMAGE * (1.0 + DAMAGE_PER_LEVEL * float(total_levels(levels)))


## Segundos por ciclo de carga. Baja con los niveles comprados, y los GUANTES
## son los que la bajan de verdad: su 15 % por nivel va en la misma cuenta que
## el 3 % que da cualquier item (CHARGE_TIME / (1 + los dos)).
static func charge_time(levels: Array) -> float:
	return CHARGE_TIME / (1.0 + CYCLE_SPEED_PER_LEVEL * float(total_levels(levels))
			+ GLOVES_SPEED_PER_LEVEL * float(item_level(levels, "guantes")))


## Lo que baja el precio de los sobres: un 5 % por nivel del Dolar, o sea un
## 40 % con los ocho. Devuelve una FRACCION (0.4), no un porcentaje.
static func pack_discount(levels: Array) -> float:
	return PACK_DISCOUNT_PER_LEVEL * float(item_level(levels, "dolar"))


## Probabilidad de critico: un 5 % por nivel del Ojo verde, y cero sin el.
static func crit_chance(levels: Array) -> float:
	return CRIT_CHANCE_PER_LEVEL * float(item_level(levels, "ojo_verde"))


## Multiplicador del critico. El Laser suma un 5% por nivel.
static func crit_mult(levels: Array) -> float:
	return CRIT_MULT_BASE + CRIT_MULT_PER_LEVEL * float(item_level(levels, "laser"))


## Cuantos paquetes se pueden llevar A LA VEZ. Ver game.gd,
## _on_open_requested(): es el tope de paquetes empezados que caben a la vez.
##
## El cupo es el de la mesa (ver table_slots), sin comprar nada. Hubo un item
## que abria el cupo de uno en uno y en la practica no se notaba -el jugador
## machacaba el mismo sobre-, asi que fuera. Los Guantes volvieron despues como
## item de VELOCIDAD, que es lo que de verdad se echaba en falta (ver
## charge_time). Lo que limita es donde caben los paquetes, que es la mesa.
static func open_count(levels: Array) -> int:
	return table_slots(levels)


## Multiplicador de peso de los objetos no comunes (Trebol).
static func luck(levels: Array) -> float:
	return 1.0 + LUCK_PER_LEVEL * float(item_level(levels, "trebol"))


## Huecos de mesa: la base mas el Cajon (2 por nivel, 5 desde el nivel 5).
static func table_slots(levels: Array) -> int:
	var lvl := item_level(levels, "cajon")
	var extra := int(mini(lvl, DRAWER_HIGH_LEVEL)) * DRAWER_BASE
	if lvl > DRAWER_HIGH_LEVEL:
		extra += (lvl - DRAWER_HIGH_LEVEL) * DRAWER_HIGH
	return TABLE_BASE + extra


## Segundos entre compras automaticas. El PC es de compra unica, asi que el ritmo
## es el de su unico nivel; sin el PC va al lento (que hoy no se alcanza: la
## compra automatica no se enciende sin el, ver auto_buy_unlocked()).
static func auto_buy_interval(levels: Array) -> float:
	if item_level(levels, "pc") <= 0:
		return AUTO_BUY_BASE
	return AUTO_BUY_INTERVAL


## Dano por segundo TOTAL de los Pinchos, repartido entre los paquetes de la mesa
## (ver game.gd, _spike_step()). Es una fraccion del ritmo de golpes del jugador
## -su dano por segundo de carga continua-, asi que sube con los items de dano.
##
## Los Pinchos NO van solos: esto es lo que pegan cuando la apertura automatica
## esta encendida. Apagada no hacen nada, porque entonces el que golpea es el
## jugador con el boton.
static func spike_dps(levels: Array, money: float = 0.0) -> float:
	if item_level(levels, "pinchos") <= 0:
		return 0.0
	var scale := 1.0 + SPIKE_PER_DECADE * log(1.0 + maxf(0.0, money) / 1000.0) / log(10.0)
	return SPIKE_SHARE * scale * damage_per_hit(levels) / charge_time(levels)


## ¿Se puede encender la apertura automatica? Hace falta SU pieza: los Pinchos.
static func auto_open_unlocked(levels: Array) -> bool:
	return item_level(levels, AUTO_ITEM_OPEN) > 0


## ¿Se puede encender la compra automatica? Hace falta SU pieza: el PC.
static func auto_buy_unlocked(levels: Array) -> bool:
	return item_level(levels, AUTO_ITEM_BUY) > 0


## Huecos del Armario: uno por nivel comprado (de 1 a 8). Sin el armario, cero:
## sin la pieza no hay vitrina donde poner nada.
static func locker_slots(levels: Array) -> int:
	return clampi(item_level(levels, "armario"), 0, LOCKER_SLOTS_MAX)


## Los ids de los tipos de botin, en el orden en que se enseñan.
static func kind_ids() -> Array:
	var ids: Array = []
	for k in LOOT_KINDS:
		ids.append(str(k["id"]))
	return ids


## La fila de un tipo de botin (su nombre y el del bonus que da).
static func kind_row(kind_id: String) -> Dictionary:
	for k in LOOT_KINDS:
		if str(k["id"]) == kind_id:
			return k
	return LOOT_KINDS[0]


## El tipo de un objeto del botin. "cards" si la fila no lo trae, para que un
## objeto nuevo sin el campo no reviente el armario (dara el bonus de las cartas,
## que es el mas facil de ver y por tanto el que antes se detecta).
static func kind_of(item: Dictionary) -> String:
	var k := str(item.get("kind", ""))
	for row in LOOT_KINDS:
		if str(row["id"]) == k:
			return k
	return "cards"


## Lo que aporta un objeto expuesto al bonus de su tipo, segun su nota PSA: del
## 2 % de la nota 1 al 15 % de la nota 10.
static func kind_bonus(kind_id: String, grade: int) -> float:
	var t := clampf(float(grade - PSA_MIN) / float(GRADE_MAX - PSA_MIN), 0.0, 1.0)
	return lerpf(KIND_BONUS_MIN, KIND_BONUS_MAX, t)


## Lo que aporta ESTE objeto expuesto, ya con su tipo y su nota.
static func bonus_for(item: Dictionary) -> float:
	return kind_bonus(kind_of(item), int(item.get("grade", PSA_MIN)))


## Las monedas que da reiniciar una partida con el DINERO QUE HAYA EN EL
## CONTADOR en ese momento, ya con el bonus de la Electronica del armario dentro
## (ver Game.rebirth_multiplier()).
##
## Se pasa el dinero que se tiene, no lo ganado: es lo que el jugador ve en la
## barra y lo que el cerdo se lleva al romperse. Por eso `amount` se llama asi y
## no `earned`, que es la confusion que este cambio ha venido a quitar de en
## medio.
##
## Se calcula con SUELO y no redondeando a la mitad: las monedas de rebirth son
## un premio gordo y decir "te llevas 2" para luego dar 1 es la clase de mentira
## que se nota. Con el multiplicador del armario en 1.0 la cuenta es exacta. Y
## nunca baja de 1: un rebirth que diera cero monedas seria un boton que cobra
## toda la partida y no paga nada.
static func rebirth_coins_for(amount: int, mult: float = 1.0) -> int:
	var base := int(maxi(0, amount) / REBIRTH_COIN_AT)
	if base <= 0:
		return 1
	return maxi(1, int(floor(float(base) * maxf(mult, 1.0))))


# --------------------------------------------------------------------------- #
# Tiradas
# --------------------------------------------------------------------------- #

## Elige un objeto del paquete por peso. `luck` (>1) engorda el peso de todo lo
## que no es comun, que es el efecto del Trebol.
static func roll_item(rng: RandomNumberGenerator, pack_id: String,
		luck: float = 1.0) -> Dictionary:
	var table: Array = loot_table(pack_id)
	var total := 0.0
	for e in table:
		total += _lucky_weight(e, luck)
	var r := rng.randf() * total
	for e in table:
		r -= _lucky_weight(e, luck)
		if r <= 0.0:
			return e.duplicate(true)
	return table[table.size() - 1].duplicate(true)


static func _lucky_weight(entry: Dictionary, luck: float) -> float:
	var w := float(entry["w"])
	if str(entry.get("rarity", "common")) == "common":
		return w
	return w * luck


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


## Cuanto vale la nota, de 0.61 (nota 1) a 2.50 (nota 10): la 10 vale cuatro
## veces lo que la 1. La curva se dispara hacia arriba porque la nota alta tiene
## que ser un PREMIO: antes iba de 0.80 a 1.25 (un 56 %, casi plano) y el 10 no
## se notaba en el bolsillo.
##
## LAS DOS ANCLAS SON LAS QUE PIDIO EL JUGADOR, y estan puestas a mano a
## proposito para que el smoke test las pueda comprobar:
##   - la 5 vale 1.25, que es EXACTAMENTE lo que valia la 10 de antes;
##   - la 10 vale 2.50, el DOBLE que valia la 10 de antes.
## Y las de abajo, un poco por debajo de lo que valian antes (la 1 baja de 0.80 a
## 0.61), que es lo que hace que ensenar una nota baja se note: el botin tocado
## se vende por menos y el 10 se guarda siempre.
##
## La curva es convexa (cada tramo sube mas que el anterior) para que la 9 tampoco
## sea "casi un 10": la 8 ya vale casi el doble que la 4.
##
## La tabla de los sobres esta cuadrada con la MEDIA de esta curva dentro (ver
## LootDB.pack_payout(), que es lo que usa el smoke test para saber que un sobre
## paga lo que tiene que pagar), asi que tocar un solo numero sin volver a mirar
## GRADE_WEIGHTS descuadra el equilibrio.
const GRADE_MULT: Array = [0.61, 0.72, 0.86, 1.02, 1.25, 1.45, 1.68, 1.95, 2.22, 2.50]


static func grade_mult(grade: int) -> float:
	return float(GRADE_MULT[clampi(grade, PSA_MIN, GRADE_MAX) - PSA_MIN])


## El nombre del sprite de un objeto segun su nota. Las cartas no se desgastan.
static func art_for(item: Dictionary, grade: int) -> String:
	if not bool(item.get("graded", false)):
		return str(item["art"])
	return "%s_psa%d" % [str(item["art"]), clampi(grade, PSA_MIN, GRADE_MAX)]


## Multiplicador global de lo que valen los objetos. Es la palanca para subir o
## bajar TODAS las ganancias de golpe cuando la partida se atasca por ganar poco.
const VALUE_SCALE := 2.2


static func final_value(item: Dictionary, grade: int) -> int:
	var v: float = float(item["value"]) * grade_mult(grade) * VALUE_SCALE
	return maxi(1, int(round(v)))


## Numero de estrellas llenas de la nota (se dibujan 10 ranuras, llenas y vacias).
static func grade_stars(grade: int) -> int:
	return clampi(grade, 0, GRADE_MAX)


## Tirada completa de un paquete: objeto, nota, estado, sprite y valor final.
## El estado sale de la nota, asi que aqui no hay nada que repartir.
##
## Al valor se le aplican DOS multiplicadores: el del escalon del sobre (vmult,
## que es lo que hace que el mismo objeto valga 400 veces mas en ELECTRONICA 3
## que en ELECTRONICA) y el del Armario, que va aparte porque lo pone el jugador.
static func roll_pack(rng: RandomNumberGenerator, pack_id: String,
		luck: float = 1.0, value_mult: float = 1.0) -> Dictionary:
	var item := roll_item(rng, pack_id, luck)
	var grade := roll_grade(rng)
	# El valor final lleva el bonus del Armario: lo que dan de mas los objetos
	# expuestos se paga al encontrar el botin, no al venderlo, para que el numero
	# que se ve en la tarjeta sea el que se cobra.
	var value := maxi(1, int(round(float(final_value(item, grade))
			* value_mult * tier_mult(pack_id))))
	return {
		"id": item["id"], "name": item["name"], "art": art_for(item, grade),
		"rarity": item["rarity"], "base_value": item["value"],
		"condition": condition_for_grade(grade), "grade": grade,
		"value": value,
		# EL TIPO VIAJA CON EL OBJETO. Esta linea parece de relleno y es la que
		# decide que hace el armario: sin "kind", kind_of() cae en su valor por
		# defecto ("cards") y TODOS los objetos expuestos suben el dano, que es
		# justo lo que pasaba (un vinilo y una zapatilla dando mas dano). No da
		# ningun error, no rompe ningun check de encuadre y en el panel se ve como
		# cuatro lineas que suman donde no toca. El diccionario de aqui es NUEVO
		# (roll_item devuelve una copia de la fila del paquete y este la recorta a
		# los campos que usa la interfaz), asi que lo que no se copie aqui se
		# pierde por el camino.
		"kind": kind_of(item),
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
