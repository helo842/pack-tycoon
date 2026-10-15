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
# LA VIDA SUBIO UN 50 % de golpe (los doce valores, de una vez). Los sobres se
# abrian demasiado rapido: con los cuatro items de dano comprados la caja basica
# caia en dos clics y no daba tiempo ni a ver la barra. Alargar la vida y no la
# espera es a proposito: lo que se alarga es el rato que estas dandole al boton,
# no el rato que esperas mirando. Los tres escalones mantienen la proporcion que
# tenian entre si (el 2 es 1,5 veces el 1 y el 3 el doble del 1) para que un
# ESCALON siga siendo mas duro que el anterior tipo, y no solo mas caro.
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
		"id": "cards", "name": "SOBRES", "price": 0, "hp": 45, "vmult": 1.0,
		"art": "pack_cards", "art_open": "pack_cards_open",
		"loot": [
			{"id": "card_c", "name": "CARTA COMUN", "art": "loot_card_common", "graded": true,
				"kind": "cards", "rarity": "common", "value": 55, "w": 55},
			{"id": "card_r", "name": "CARTA EDICION LIMITADA", "art": "loot_card_edited", "graded": true,
				"kind": "cards", "rarity": "rare", "value": 260, "w": 30},
			{"id": "card_e", "name": "CARTA VIEJA", "art": "loot_card_vintage", "graded": true,
				"kind": "cards", "rarity": "epic", "value": 1150, "w": 12},
			{"id": "card_l", "name": "CARTA HOLOGRAFICA", "art": "loot_card_foil", "graded": true,
				"kind": "cards", "rarity": "legendary", "value": 5400, "w": 3},
		],
	},
	{
		"id": "vinyls", "name": "VINILOS", "price": 1000, "hp": 90, "vmult": 1.0,
		"art": "pack_vinyls", "art_open": "pack_vinyls_open",
		"loot": [
			{"id": "vinyl_c", "name": "VINILO", "art": "loot_vinyl", "graded": true,
				"kind": "vinyls", "rarity": "common", "value": 380, "w": 52},
			{"id": "vinyl_d", "name": "DOBLE LP", "art": "loot_vinyl_double", "graded": true,
				"kind": "vinyls", "rarity": "rare", "value": 1450, "w": 31},
			{"id": "vinyl_n", "name": "EDICION NUMERADA", "art": "loot_vinyl_numbered",
				"graded": true, "kind": "vinyls", "rarity": "epic", "value": 5200, "w": 14},
			{"id": "vinyl_x", "name": "PRENSADO EN COLOR", "art": "loot_vinyl_color",
				"graded": true, "kind": "vinyls", "rarity": "legendary", "value": 24000, "w": 3},
		],
	},
	{
		"id": "sneakers", "name": "ZAPATILLAS", "price": 6000, "hp": 180, "vmult": 1.0,
		"art": "pack_sneakers", "art_open": "pack_sneakers_open",
		"loot": [
			{"id": "shoe_c", "name": "ZAPATILLA BLANCA", "art": "loot_sneaker", "graded": true,
				"kind": "sneakers", "rarity": "common", "value": 1800, "w": 48},
			{"id": "shoe_l", "name": "ZAPATILLA DE PIEL", "art": "loot_sneaker_leather",
				"graded": true, "kind": "sneakers", "rarity": "rare", "value": 7200, "w": 32},
			{"id": "shoe_r", "name": "ZAPATILLA A RESTAURAR", "art": "loot_sneaker_restore",
				"graded": true, "kind": "sneakers", "rarity": "epic", "value": 28000, "w": 16},
			{"id": "shoe_x", "name": "ZAPATILLA LIMITADA",
				"art": "loot_sneaker_limited", "graded": true,
				"kind": "sneakers", "rarity": "legendary", "value": 130000, "w": 4},
		],
	},
	{
		"id": "electronics", "name": "ELECTRONICA", "price": 25000, "hp": 360, "vmult": 1.0,
		"art": "pack_electronics", "art_open": "pack_electronics_open",
		"loot": [
			{"id": "cons_c", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 6000, "w": 30},
			{"id": "head_c", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 4200, "w": 20},
			{"id": "cam_c", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 9000, "w": 18},
			{"id": "cart_c", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 1800, "w": 14},
			{"id": "hand_c", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 9000, "w": 7},
			{"id": "cons_r", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 20400, "w": 12},
			{"id": "head_r", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 14300, "w": 10},
			{"id": "cam_r", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 30600, "w": 10},
			{"id": "cart_r", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 6120, "w": 5},
			{"id": "hand_r", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 30600, "w": 5},
			{"id": "cons_e", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 90000, "w": 8},
			{"id": "head_e", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 63000, "w": 7},
			{"id": "cam_e", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 135000, "w": 7},
			{"id": "cart_e", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 27000, "w": 2},
			{"id": "hand_e", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 135000, "w": 4},
			{"id": "cons_l", "name": "CONSOLA", "art": "loot_console", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 330000, "w": 5},
			{"id": "head_l", "name": "AURICULARES", "art": "loot_headphones", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 231000, "w": 2},
			{"id": "cam_l", "name": "CAMARA", "art": "loot_camera", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 495000, "w": 3},
			{"id": "cart_l", "name": "CARTUCHO", "art": "loot_cartridge", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 99000, "w": 1},
			{"id": "hand_l", "name": "CONSOLA PORTATIL", "art": "loot_handheld", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 495000, "w": 2},
			# Los cuatro objetos que tenian sobre propio entran aqui: son los que le
			# faltaban a esta tabla para ser "lo caro" del juego, y sin un sitio se
			# quedaban sin salir nunca (y sus cuarenta sprites con ellos). Los
			# valores van puestos al nivel de esta tabla, no al que tenian.
			{"id": "cab_c", "name": "CABLE", "art": "loot_cable", "graded": true,
				"kind": "electronics", "rarity": "common", "value": 2200, "w": 6},
			{"id": "wat_r", "name": "RELOJ", "art": "loot_watch", "graded": true,
				"kind": "electronics", "rarity": "rare", "value": 15300, "w": 6},
			{"id": "ing_e", "name": "LINGOTE DE ORO", "art": "loot_ingot", "graded": true,
				"kind": "electronics", "rarity": "epic", "value": 90000, "w": 3},
			{"id": "pwt_l", "name": "RELOJ DE BOLSILLO", "art": "loot_pocket_watch", "graded": true,
				"kind": "electronics", "rarity": "legendary", "value": 495000, "w": 2},
		],
	},
	# --- los otros ocho sobres ------------------------------------------- #
	# Mismo botin que su escalon 1, mas caro y multiplicado. El precio y el vmult
	# van aparte a proposito: subir uno sin subir el otro seria un timo, y asi se
	# puede tocar el equilibrio sin reescribir ninguna tabla de objetos.
	# El NOMBRE y el DIBUJO cambian con el escalon; la tabla de botin no. El
	# escalon 2 va de pan de oro y el 3 de laca con joya (ver tools/make_sprites.py,
	# seccion "escalones 2 y 3"), asi que de un vistazo se sabe cual se esta
	# abriendo sin leer el precio. Los nombres tienen que caber a 28 px en la
	# columna de la izquierda (16 caracteres: PACK_NAME_BOX.x / 28), o UIKit
	# encoge los doce a la vez y el "SOBRES" de arriba se queda enano.
	{"id": "cards2", "name": "SOBRES ORO", "price": 4000, "hp": 68, "vmult": 20.0,
		"loot_id": "cards", "art": "pack_cards2", "art_open": "pack_cards2_open"},
	{"id": "vinyls2", "name": "VINILOS ORO", "price": 20000, "hp": 135, "vmult": 20.0,
		"loot_id": "vinyls", "art": "pack_vinyls2", "art_open": "pack_vinyls2_open"},
	{"id": "sneakers2", "name": "ZAPATILLAS ORO", "price": 120000, "hp": 270, "vmult": 20.0,
		"loot_id": "sneakers", "art": "pack_sneakers2", "art_open": "pack_sneakers2_open"},
	{"id": "electronics2", "name": "ELECTRONICA ORO", "price": 500000, "hp": 540,
		"vmult": 20.0, "loot_id": "electronics",
		"art": "pack_electronics2", "art_open": "pack_electronics2_open"},
	{"id": "cards3", "name": "SOBRES LUJO", "price": 80000, "hp": 90, "vmult": 400.0,
		"loot_id": "cards", "art": "pack_cards3", "art_open": "pack_cards3_open"},
	{"id": "vinyls3", "name": "VINILOS LUJO", "price": 400000, "hp": 180, "vmult": 400.0,
		"loot_id": "vinyls", "art": "pack_vinyls3", "art_open": "pack_vinyls3_open"},
	{"id": "sneakers3", "name": "ZAPATILLAS LUJO", "price": 2500000, "hp": 360,
		"vmult": 400.0, "loot_id": "sneakers",
		"art": "pack_sneakers3", "art_open": "pack_sneakers3_open"},
	{"id": "electronics3", "name": "ELECTRONICA LUJO", "price": 10000000, "hp": 720,
		"vmult": 400.0, "loot_id": "electronics",
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
# Se reparte hacia arriba (lo normal es que el objeto venga ya graduado) pero
# nunca sale un 10 fijo: el 10 es el premio gordo.
const GRADE_WEIGHTS: Array = [1, 1, 2, 3, 5, 7, 9, 12, 14, 16]
const PSA_MIN := 1
const GRADE_MAX := 10

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
const ITEM_COST_GROWTH := 1.9
## Niveles que tienen las piezas de las automatizaciones: una compra y ya.
const ITEM_SINGLE_LEVEL := 1

const ITEMS: Array = [
	{"id": "guantes", "name": "GUANTES", "art": "item_guantes", "base_cost": 900,
		"desc": "VARIOS PAQUETES A LA VEZ",
		"detail": "PUEDES TENER VARIOS PAQUETES CARGANDO A LA VEZ Y TE AGUANTAN EL TURNO. UN CLIC SIGUE EMPEZANDO SOLO EL PAQUETE QUE PULSAS."},
	{"id": "trebol", "name": "TREBOL", "art": "item_trebol", "base_cost": 1400,
		"desc": "MAS BOTIN RARO",
		"detail": "SUBE LAS PROBABILIDADES DE QUE SALGA BOTIN RARO, EPICO O LEGENDARIO. VALE PARA TODOS LOS SOBRES."},
	{"id": "cajon", "name": "CAJON", "art": "item_cajon", "base_cost": 2600,
		"desc": "MAS ESPACIO EN LA MESA",
		"detail": "MAS HUECOS EN LA MESA PARA DEJAR PAQUETES Y OBJETOS A LA VEZ. A PARTIR DEL NIVEL 5 CADA NIVEL DA TRES HUECOS EN VEZ DE DOS."},
	{"id": "ojo_verde", "name": "OJO VERDE", "art": "item_ojo_verde", "base_cost": 4200,
		"desc": "PROBABILIDAD DE CRITICO",
		"detail": "CADA GOLPE TIENE ESTA PROBABILIDAD DE SER CRITICO, Y UN CRITICO HACE EL DOBLE DE DANO Y SALE EN AMARILLO."},
	{"id": "laser", "name": "LASER", "art": "item_laser", "base_cost": 6000,
		"desc": "MAS DANO CRITICO",
		"detail": "SUBE EL DANO QUE HACE CADA GOLPE CRITICO. SIN CRITICOS NO HACE NADA, ASI QUE VA DETRAS DEL OJO VERDE."},
	{"id": "pc", "name": "PC", "art": "item_pc", "base_cost": 12000,
		"desc": "COMPRA LOS SOBRES SOLO",
		"detail": "COMPRA SOLO, AL RITMO QUE DICE AQUI, EL SOBRE MAS BARATO DE LOS QUE TENGAS MARCADOS EN SU MENU. SE PAGA UNA SOLA VEZ."},
	{"id": "pinchos", "name": "PINCHOS", "art": "item_pinchos", "base_cost": 20000,
		"desc": "ABRE LOS PAQUETES SOLO",
		"detail": "CON LA APERTURA AUTOMATICA ENCENDIDA GOLPEAN TODOS LOS PAQUETES DE LA MESA A LA VEZ, SIN QUE LES HAGAS CLIC. SE PAGAN UNA SOLA VEZ."},
	{"id": "armario", "name": "ARMARIO", "art": "item_armario", "base_cost": 35000,
		"desc": "EXPONE BOTIN Y DA SUS BONUS",
		"detail": "CADA OBJETO QUE EXPONGAS DA EL BONUS DE SU TIPO SEGUN SU NOTA PSA, DE UN 2 % EN LA NOTA 1 A UN 15 % EN LA 10: CARTAS DANO, ZAPATILLAS VELOCIDAD, VINILOS DINERO Y ELECTRONICA REBIRTH. EMPIEZAS CON UN HUECO Y LLEGAS A OCHO."},
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
## Dano de un golpe sin mejoras. Un paquete basico (45 de vida) son cuatro
## ciclos: con doce de dano, el cuarto golpe le sobra medio y el sobrante NO se
## guarda, cada caja empieza de cero.
const BASE_DAMAGE := 12.0
## Cada nivel comprado de CUALQUIER item suma un 18% al dano base. Los dos de
## compra unica (PC y Pinchos) aportan su unico nivel, que es lo que aportaba su
## primera compra.
const DAMAGE_PER_LEVEL := 0.18
## Segundos que tarda un ciclo de carga del boton. Es el ritmo al que se golpea.
const CHARGE_TIME := 0.55
## Cada nivel comprado acelera la carga un 5% (menos tiempo por golpe).
const CYCLE_SPEED_PER_LEVEL := 0.05

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
## Guantes: paquetes que se pueden llevar a la vez (1 sin item; +2 por nivel).
##
## OJO: NO son paquetes que se abren con un clic. Un clic arranca SIEMPRE un solo
## paquete, el pulsado; lo que sube con los Guantes es cuantos caben cargando al
## mismo tiempo. Con Guantes el jugador tiene que ir pulsando uno y otro en vez de
## machacar el mismo, que es justo lo que se queria quitar.
const OPEN_PER_LEVEL := 2
## Trebol: +2% de peso a los objetos no comunes por nivel.
const LUCK_PER_LEVEL := 0.02
## Cajon: huecos extra en la mesa. 2 por nivel, y 5 a partir del nivel 5.
const DRAWER_BASE := 2
const DRAWER_HIGH := 5
const DRAWER_HIGH_LEVEL := 5
## Mesa sin cajon.
const TABLE_BASE := 8
## Pinchos: dano por segundo a TODOS los paquetes de la mesa mientras la apertura
## automatica esta encendida. Antes eran seis por nivel; con una sola compra se
## queda en el nivel medio de los ocho, que una automatizacion que tarda cinco
## segundos por sobre no se usa.
const SPIKE_DPS := 24.0
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
const KIND_BONUS_MAX := 0.15

# --- el rebirth (la hucha) ------------------------------------------------ #
## Lo que hay que haberse ganado EN LA PARTIDA para poder reiniciarla. Es una
## meta redonda y a la vista (un millon) y no una cifra fina a proposito: el
## jugador tiene que poder leer el requisito y saber donde esta.
const REBIRTH_REQUIRE := 1000000
## Cada cuanto ganado sale UNA moneda de rebirth. Con el requisito de arriba, el
## primer rebirth son 1 moneda, y a partir de ahi la cuenta sube sola: ganar diez
## millones en una partida son diez monedas.
const REBIRTH_EARN_AT := 1000000
## Lo que suma CADA moneda de rebirth al valor de todo lo que vendes, para
## siempre (no se pierde en el siguiente rebirth). 5 % por moneda: con diez
## monedas todo vale la mitad mas, y hacen falta diez rebirths para llegar.
const REBIRTH_VALUE_PER_COIN := 0.05

# --------------------------------------------------------------------------- #
# EL ARBOL DE HABILIDADES (4 ramas x 2 opciones)
# --------------------------------------------------------------------------- #
#
# QUE ES. El Idea.pdf promete un arbol de cuatro ramas que se mejora con las
# monedas del rebirth:
#
#   1. Calidad de vida: que los paquetes caigan mas rapido o se apilen solos.
#   2. Ganancias: ganar mas por venta o que caiga dinero extra al rasgar.
#   3. Dano: pegar mas fuerte o tener probabilidad de dano doble.
#   4. Las ventajas permanentes del rebirth: sobres mas baratos y empezar las
#      partidas siguientes con dinero heredado (lo dice el propio documento al
#      explicar la hucha).
#
# SE PAGA CON MONEDAS DE REBIRTH, y de ahi que el arbol sea "el" arbol del
# rebirth: son la unica moneda que pasa de una partida a la siguiente (ver
# REBIRTH_VALUE_PER_COIN). Gastarlas tiene un coste de oportunidad de verdad
# -cada moneda que no se gasta sube un 5 % todo lo que vendes-, que es lo que
# hace que elegir rama importe.
#
# LO QUE SE COMPRA NO SE PIERDE. Ni el rebirth ni el reinicio de la partida
# tocan `skills`: es progresion de la CUENTA, como las monedas. Por eso el arbol
# es lo unico del juego que no se puede perder de ninguna manera (ver
# game_state.gd, do_rebirth()).
#
# DOS CLASES DE OPCION, igual que en la tienda: SIETE escaleras de cinco niveles
# (los numeros suben con cada nivel) y UNA de un solo nivel, que es la que no
# tiene numero que subir -"se colocan solos" es un si o un no-. En el panel la de
# un nivel se marca con COMPRA UNICA, el mismo rotulo que usan el PC y los
# Pinchos, para no inventar otro idioma en la misma pantalla.
#
# LOS PRECIOS SON CORTOS A PROPOSITO (1, 2, 3, 5 y 8 por nivel): una partida
# normal da entre una y diez monedas (ver REBIRTH_EARN_AT), asi que la primera
# mejora del arbol tiene que caber en la PRIMERA partida. Subir un arbol entero
# son 19 monedas y el arbol completo 114, que es una meta de muchas partidas y
# deja sitio para el resto del juego.
#
# LOS NOMBRES DE LAS OCHO OPCIONES MIDEN 14 CARACTERES O MENOS, y no es
# casualidad: en una casilla de 320 px con 24 de margen caben 296, y a 21 px por
# caracter -que es el tamano al que se leen los nombres- son exactamente 14. El
# panel los pinta TODOS al mismo tamano (ver skill_tree_panel.gd), asi que un
# nombre de 15 encogeria los ocho a 14 px y la pantalla entera se leeria mas
# pequeia. Es el mismo limite que el de la columna de sobres (16 caracteres a
# 28) y por eso los nombres se eligen mirando la cuenta.
const SKILL_MAX_LEVEL := 5
## Lo que cuesta el nivel 1, 2, 3, 4 y 5 de cualquier opcion con niveles.
const SKILL_COSTS: Array = [1, 2, 3, 5, 8]

const SKILL_BRANCHES: Array = [
	{
		"id": "vida", "name": "CALIDAD DE VIDA", "art": "skill_diamond",
		"options": [
			{"id": "caida", "name": "CAIDA RAPIDA", "art": "skill_drop", "max": 5,
				"desc": "LAS CAJAS TARDAN MENOS EN CAER A LA MESA."},
			{"id": "orden", "name": "MESA ORDENADA", "art": "skill_grid", "max": 1,
				"desc": "LOS PAQUETES Y LOS OBJETOS SE COLOCAN SOLOS EN UNA REJILLA ORDENADA, SIN PISARSE."},
		],
	},
	{
		"id": "ganancias", "name": "GANANCIAS", "art": "skill_dollar",
		"options": [
			{"id": "ventas", "name": "MEJORES VENTAS", "art": "skill_sales", "max": 5,
				"desc": "TODO LO QUE VENDES VALE MAS. SE SUMA AL ARMARIO Y A LAS MONEDAS."},
			{"id": "rasgar", "name": "DINERO EXTRA", "art": "skill_rip_cash", "max": 5,
				"desc": "CADA GOLPE TIENE ESTA PROBABILIDAD DE SOLTAR DINERO EXTRA, SEGUN LO QUE COSTE EL SOBRE."},
		],
	},
	{
		"id": "dano", "name": "DANO", "art": "skill_lightning",
		"options": [
			{"id": "golpe", "name": "GOLPE DURO", "art": "skill_hit", "max": 5,
				"desc": "SUBE EL DANO DE CADA GOLPE, ENCIMA DE LO QUE DAN LOS ITEMS Y LAS CARTAS DEL ARMARIO."},
			{"id": "doble", "name": "GOLPE DOBLE", "art": "skill_double", "max": 5,
				"desc": "CADA GOLPE TIENE ESTA PROBABILIDAD DE HACER EL DOBLE DE DANO. NO ES UN CRITICO: SE PUEDE SUMAR A UNO."},
		],
	},
	{
		"id": "herencia", "name": "HERENCIA", "art": "skill_cycle",
		"options": [
			{"id": "barato", "name": "SOBRES BARATOS", "art": "skill_cheap", "max": 5,
				"desc": "TODOS LOS SOBRES CUESTAN MENOS. VALE PARA LA COMPRA A MANO Y PARA LA AUTOMATICA."},
			{"id": "hereda", "name": "DINERO INICIAL", "art": "skill_heir", "max": 5,
				"desc": "CADA PARTIDA NUEVA EMPIEZA CON ESTE DINERO DE MAS, SUMADO AL DE SIEMPRE."},
		],
	},
]

# --- cuanto hace cada opcion ---------------------------------------------- #
## Caida rapida: segundos que se acortan de la caida (en fraccion) por nivel.
## La caida base son DROP_TIME segundos y se DIVIDE entre (1 + esto x nivel),
## como el tiempo de carga de las Zapatillas: asi el nivel 5 se queda en 0,24 s
## (un 43 % menos) y nunca llega a cero por muchos niveles que se compren.
const SKILL_DROP_PER_LEVEL := 0.15
## Segundos que tarda un objeto en caer a la mesa sin ninguna mejora.
##
## Vive aqui y no en la mesa por el mismo motivo que CHARGE_TIME: es un numero
## de equilibrio, y el arbol tiene que poder leerlo para acortarlo.
const DROP_TIME := 0.42
## Mejores ventas: +4 % al valor de todo lo que se vende por nivel (un +20 % a
## los cinco, que es la mitad de lo que da una moneda de rebirth).
const SKILL_SALES_PER_LEVEL := 0.04
## Dinero al rasgar: probabilidad por nivel (2 % por nivel, un 10 % a los cinco)
## de que un golpe suelte dinero.
const SKILL_RIP_CHANCE_PER_LEVEL := 0.02
## Lo que suelta ese golpe: un 10 % de lo que costo el sobre.##
## Es un porcentaje del PRECIO y no una cifra fija porque asi la mejora sigue
## valiendo lo mismo cuando la partida cambia de escalon de sobres (un sobre de
## diez milones devuelve un millon, que es mucho en valor absoluto y poco al
## lado de lo que hay dentro de ese sobre).
const RIP_CASH_RATE := 0.10
## Suelo del dinero al rasgar. El sobre gratuito cuesta 0, y sin suelo la mejora
## no haria absolutamente nada en el primer sobre de la partida, que es el que
## se abre cientos de veces al empezar.
const RIP_CASH_FLOOR := 20
## Golpe duro: +8 % de dano por nivel.
const SKILL_HIT_PER_LEVEL := 0.08
## Golpe doble: 2 % por nivel de que un golpe haga dano doble.
const SKILL_DOUBLE_CHANCE_PER_LEVEL := 0.02
## Sobres baratos: -3 % al precio de los sobres por nivel.
const SKILL_CHEAP_PER_LEVEL := 0.03
## Dinero heredado: lo que suma cada nivel al dinero con el que empieza una
## partida nueva.
##
## 2.500 por nivel y no un porcentaje: el dinero inicial (500) es una cifra que
## deja de significar nada en cuanto se abre el segundo escalon de sobres, y lo
## que hace falta al volver a empezar es poder comprar los primeros sobres sin
## volver a dar cien clics al gratuito.
const SKILL_HEIR_PER_LEVEL := 2500

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
## ITEM_MAX_LEVEL para los seis de estadisticas.
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
		"guantes":
			return "AGUANTAS %d A LA VEZ" % open_count(levels)
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
			return "%d OBJETOS EXPUESTOS" % locker_slots(levels)
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


## Dano de cada golpe: base mas el 18% por nivel comprado.
static func damage_per_hit(levels: Array) -> float:
	return BASE_DAMAGE * (1.0 + DAMAGE_PER_LEVEL * float(total_levels(levels)))


## Segundos por ciclo de carga. Baja con los niveles comprados.
static func charge_time(levels: Array) -> float:
	return CHARGE_TIME / (1.0 + CYCLE_SPEED_PER_LEVEL * float(total_levels(levels)))


## Probabilidad de critico: un 5 % por nivel del Ojo verde, y cero sin el.
static func crit_chance(levels: Array) -> float:
	return CRIT_CHANCE_PER_LEVEL * float(item_level(levels, "ojo_verde"))


## Multiplicador del critico. El Laser suma un 5% por nivel.
static func crit_mult(levels: Array) -> float:
	return CRIT_MULT_BASE + CRIT_MULT_PER_LEVEL * float(item_level(levels, "laser"))


## Cuantos paquetes se pueden llevar A LA VEZ (Guantes). Ver game.gd,
## _on_open_requested(): es el tope de paquetes empezados que caben a la vez.
static func open_count(levels: Array) -> int:
	return 1 + OPEN_PER_LEVEL * item_level(levels, "guantes")


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


## Dano por segundo de los Pinchos a todos los paquetes de la mesa.
##
## Los Pinchos NO van solos: esto es lo que pegan cuando la apertura automatica
## esta encendida (ver game.gd, _spike_step()). Apagada no hacen nada, porque
## entonces el que golpea es el jugador con el boton.
static func spike_dps(levels: Array) -> float:
	if item_level(levels, "pinchos") <= 0:
		return 0.0
	return SPIKE_DPS


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


## Lo que suma cada moneda de rebirth al valor de lo que vendes: la paga
## permanente que se lleva de una partida a la siguiente.
static func rebirth_value_mult(coins: int) -> float:
	return 1.0 + REBIRTH_VALUE_PER_COIN * float(maxi(0, coins))


## Las monedas que da reiniciar una partida con lo ganado en ella, ya con el
## bonus de la Electronica del armario dentro (ver Game.rebirth_multiplier()).
##
## Se calcula con SUELO y no redondeando a la mitad: las monedas de rebirth son
## un premio gordo y decir "te llevas 2" para luego dar 1 es la clase de mentira
## que se nota. Con el multiplicador del armario en 1.0 la cuenta es exacta.
static func rebirth_coins_for(earned: int, mult: float = 1.0) -> int:
	var base := int(earned / REBIRTH_EARN_AT)
	if base <= 0:
		return 1
	return maxi(1, int(floor(float(base) * maxf(mult, 1.0))))


# --------------------------------------------------------------------------- #
# El arbol de habilidades: consultas
# --------------------------------------------------------------------------- #

## Las cuatro ramas con sus dos opciones cada una, en el orden en que se
## ensehan. El panel las recorre de aqui: no hay ninguna lista de ramas escrita
## en la interfaz, que es lo que hace que anadir una rama sea anadir datos.
static func skill_branches() -> Array:
	return SKILL_BRANCHES


## Las ocho opciones EN UNA LISTA PLANA, en el orden del panel (las dos de la
## primera rama, luego las dos de la segunda...). Los tests la usan para
## recorrer el arbol entero sin saber de ramas.
static func skill_options() -> Array:
	var out: Array = []
	for branch in SKILL_BRANCHES:
		for option in branch["options"]:
			out.append(option)
	return out


## La fila de una opcion por su id. Devuelve {} si no existe, y quien pregunta
## tiene que poder distinguirlo: un id que no esta (un guardado viejo, una
## errata) no puede contestar los datos de otra opcion, que es como se acaba
## mejorando lo que no es.
static func skill_option(option_id: String) -> Dictionary:
	for branch in SKILL_BRANCHES:
		for option in branch["options"]:
			if str(option["id"]) == option_id:
				return option
	return {}


## ¿Existe esa opcion del arbol?
static func has_skill(option_id: String) -> bool:
	return not skill_option(option_id).is_empty()


## La rama a la que pertenece una opcion (su fila de SKILL_BRANCHES), o {}.
static func skill_branch_of(option_id: String) -> Dictionary:
	for branch in SKILL_BRANCHES:
		for option in branch["options"]:
			if str(option["id"]) == option_id:
				return branch
	return {}


## Niveles que puede llegar a tener una opcion (5 en las seis escaleras y 1 en
## las dos de compra unica). 0 si el id no existe.
static func skill_max(option_id: String) -> int:
	var option := skill_option(option_id)
	if option.is_empty():
		return 0
	return int(option["max"])


## Lo que cuesta el SIGUIENTE nivel de una opcion. -1 cuando no hay nada que
## comprar: porque ya esta al tope. Es "no hay precio", el mismo contrato que
## item_cost(), y por eso el panel puede usar el mismo rotulo AL TOPE.
static func skill_cost(option_id: String, current_level: int) -> int:
	var tope := skill_max(option_id)
	if tope <= 0 or current_level >= tope:
		return -1
	return int(SKILL_COSTS[clampi(current_level, 0, SKILL_COSTS.size() - 1)])


## Cuantas mejoras tiene el arbol entero. Es el tope de compras de una partida
## eterna (siete escaleras de 5 niveles mas 1 opcion de un nivel: 36).
static func skill_step_count() -> int:
	var total := 0
	for option in skill_options():
		total += int(option["max"])
	return total


## El efecto de una opcion a un nivel concreto, YA ESCRITO para leerlo.
##
## Devuelve TEXTO y no un numero por lo mismo que item_effect(): cada efecto se
## mide en lo suyo (por ciento, golpes, monedas) y decidir como se escribe eso es
## parte del dato. Asi el panel del arbol no puede mentir, y el dia que cambie
## una formula hay un solo sitio que tocar.
##
## El texto es CORTO a proposito (a 14 px caben 21 caracteres en el ancho de una
## casilla): el numero solo, con la unidad, y el nombre de la casilla diciendo de
## que va. "+8 % DE DANO" se lee; "EL DANO DE CADA GOLPE SUBE UN 8 POR CIENTO"
## no cabe en ningun sitio del panel.
static func skill_effect(option_id: String, level: int) -> String:
	var lvl := maxi(0, level)
	match option_id:
		"caida":
			return "+%d%% MAS RAPIDO" % roundi((1.0 - DROP_TIME / skill_drop_time(lvl)) * 100.0)
		"orden":
			return "SE COLOCAN SOLOS"
		"ventas":
			return "+%d%% AL VENDER" % roundi(SKILL_SALES_PER_LEVEL * float(lvl) * 100.0)
		"rasgar":
			return "%d%% DE GOLPES" % roundi(SKILL_RIP_CHANCE_PER_LEVEL * float(lvl) * 100.0)
		"golpe":
			return "+%d%% DE DANO" % roundi(SKILL_HIT_PER_LEVEL * float(lvl) * 100.0)
		"doble":
			return "%d%% DANO X2" % roundi(SKILL_DOUBLE_CHANCE_PER_LEVEL * float(lvl) * 100.0)
		"barato":
			return "-%d%% DE PRECIO" % roundi(SKILL_CHEAP_PER_LEVEL * float(lvl) * 100.0)
		"hereda":
			# Sin separador de millares a proposito: el que separa es
			# PixelNumber.format(), que vive en la capa de interfaz y aqui no se
			# puede usar sin que data/ empiece a depender de ui/. A 2.500 por nivel
			# el numero mas largo es 12500, que cabe de sobra en la casilla.
			return "+%d AL EMPEZAR" % skill_heir_money(lvl)
	return ""


## Segundos que tarda un objeto en caer a la mesa con la mejora a este nivel.
static func skill_drop_time(level: int) -> float:
	return DROP_TIME / (1.0 + SKILL_DROP_PER_LEVEL * float(maxi(0, level)))


## Lo que sube el valor de todo lo que se vende con la mejora "Mejores
## ventas": se multiplica, como el armario, y no se suma.
static func skill_sale_mult(level: int) -> float:
	return 1.0 + SKILL_SALES_PER_LEVEL * float(maxi(0, level))


## Probabilidad de que un golpe suelte dinero extra.
static func skill_rip_chance(level: int) -> float:
	return SKILL_RIP_CHANCE_PER_LEVEL * float(maxi(0, level))


## El dinero que suelta ese golpe, segun lo que costo el sobre.
static func skill_rip_cash(price: int) -> int:
	if price <= 0:
		return RIP_CASH_FLOOR
	return maxi(RIP_CASH_FLOOR, int(round(float(price) * RIP_CASH_RATE)))


## Lo que sube el dano de cada golpe: se multiplica sobre el dano que ya dan
## los items y el armario.
static func skill_damage_mult(level: int) -> float:
	return 1.0 + SKILL_HIT_PER_LEVEL * float(maxi(0, level))


## Probabilidad de que un golpe haga el DOBLE de dano (independiente del
## critico del Ojo verde: los dos se pueden sumar en el mismo golpe).
static func skill_double_chance(level: int) -> float:
	return SKILL_DOUBLE_CHANCE_PER_LEVEL * float(maxi(0, level))


## Lo que baja el precio de TODOS los sobres: se multiplica por (1 - esto).
static func skill_price_mult(level: int) -> float:
	return clampf(1.0 - SKILL_CHEAP_PER_LEVEL * float(maxi(0, level)), 0.1, 1.0)


## El dinero de mas con el que empieza una partida nueva.
static func skill_heir_money(level: int) -> int:
	return SKILL_HEIR_PER_LEVEL * maxi(0, level)


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


## Cuanto vale la nota. Va de 0.50 (nota 1) a 1.13 (nota 10).
##
## Antes la nota multiplicaba por 0.60..1.40 y encima el estado (0.30..1.25)
## hacia de factor aparte. Al derivar el estado de la nota, el multiplicador se
## reescalo para que la media se quede en 1: la media de la nota sale en 7.6, y
## 0.50 + 0.07*(7.6-1) da 0.96. Asi los precios de la tabla de arriba siguen
## valiendo lo que valian y no hay que reequilibrar los paquetes.
static func grade_mult(grade: int) -> float:
	return 0.50 + 0.07 * float(clampi(grade, PSA_MIN, GRADE_MAX) - 1)


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
