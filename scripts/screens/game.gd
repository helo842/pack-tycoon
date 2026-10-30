# Game - la pantalla de juego.
#
# Aqui esta el bucle entero:
#   1. se compra un sobre en la COLUMNA DE LA IZQUIERDA y cae en la mesa
#   2. se le hace clic y se espera (los items acortan la espera)
#   3. sale la tarjeta de revelado
#   4. el objeto cae en la mesa y se vende
#
# La mesa tiene tope de 8 elementos, que es el "limite maximo de elementos
# simultaneos" del Idea.pdf. Cuando esta llena no se puede comprar mas.
#
# Los sobres se compran aqui y no en la tienda a proposito: abrir y comprar es
# el 90 % de lo que se hace en una partida, y tener que abrir un panel para
# comprar el siguiente sobre convierte cada ciclo en tres clics de mas.
extends Control

const SHOP_SCENE := preload("res://scenes/ShopPanel.tscn")
const REVEAL_SCENE := preload("res://scenes/RevealCard.tscn")
const SETTINGS_SCENE := preload("res://scenes/SettingsPanel.tscn")
const AUTO_BUY_SCENE := preload("res://scenes/AutoBuyPanel.tscn")
const LOCKER_SCENE := preload("res://scenes/LockerPanel.tscn")
const REBIRTH_SCENE := preload("res://scenes/RebirthPanel.tscn")

## La tira de abajo, debajo de la mesa: LA VITRINA. Antes eran los diez huecos
## del inventario, que ahora vive en su panel (ver LockerPanel) junto al armario.
##
## Lo que se enseña aqui es lo que hay EXPUESTO, que es la informacion que hacia
## falta tener a la vista mientras se juega: los cuatro bonus del armario
## (dano, velocidad, dinero y rebirth) estan puestos justo por esto, asi que
## saber que hay dentro sin abrir nada es parte de la partida. Del inventario, en
## cambio, no hay nada que mirar mientras se abre: se vacia en su panel.
##
## Los huecos van en la MISMA rejilla que tenia el inventario (misma x, mismo
## paso y mismo lado) porque el armario son ocho como mucho y el hueco del
## noveno y el decimo se quedan sin usar: mover los que hay para ponerlos en el
## centro seria cambiar la pantalla entera para no ganar nada.
const LOCK_X0 := 660.0
const LOCK_STEP := 132.0
const LOCK_Y := 1000.0
const LOCK_SIDE := 128.0
## La chapa que abre el armario, donde estaba el VENDER TODO del inventario. Mas
## estrecha que aquella (300 en vez de 384) para que la chapa no llegue tan
## abajo: mide 0,45 del ancho de alto, y con 384 se le comian 6 px por debajo de
## la pantalla.
const LOCK_BTN_CENTER := Vector2(210, 1000)
const LOCK_BTN_W := 300.0

## La chapa del REBIRTH, en la barra de arriba y PEGADA A LA TIENDA.
##
## ESTUVO EN EL MENU Y AHI NO VA, y no es una manía de colocacion: el rebirth se
## hace JUGANDO (el requisito es el dinero que tienes en el contador), asi que su
## sitio es donde se juega, al lado de las otras dos cosas que se hacen "cuando se para"
## (vender y entrar en la tienda). En el menu solo estorbaba: aparecia antes de
## que el jugador supiera que era, con un cero y un "TE FALTAN 1.000.000" en rojo
## en la primera pantalla del juego.
##
## POR ESO LA BARRA SE HA APRETADO, Y DOS VECES. Primero entro la chapa del
## rebirth, que no cabia entre el rotulo de la mesa y los ajustes; despues se le
## pidio ser DEL TAMANO DE LA TIENDA, con el cerdito al lado de la palabra, y un
## contador de monedas de rebirth pegado al dinero. Asi que el grupo de la derecha
## se movio otra vez a la izquierda: los tres iconos van a 808/904/1000 (antes
## 832/932/1032), VENDER a 1156 (antes 1192), TIENDA a 1400 (antes 1440) y
## REBIRTH a 1672 con la misma chapa de 256 que la tienda (antes 200). El dinero
## sigue anclado a 128, con 252 px de tope, y a su derecha va el grupo de las
## monedas de rebirth (cerdito y numero), pegado al ultimo digito. El rotulo de la
## mesa se queda en 656 y 24 px de letra (antes 660 y 28) para dejarle su hueco al
## contador nuevo. Los huecos de la fila son de 16 px.
const REBIRTH_CENTER := Vector2(1672, 58)
const REBIRTH_W := 256.0
## El cerdito que marca las monedas de rebirth en la barra, pegado al dinero.
##
## A 0.17, que es la MISMA escala de la moneda del contador: la tinta del cerdito
## (406x448 de un lienzo de 512) sale a 69x76 px y la de la moneda (448x448) a
## 76x76, asi que los dos se ven del mismo tamano. A 0.12 media 49 px y al lado de
## la moneda de verdad se leia como un icono de segunda fila.
##
## LA X NO ES FIJA: se pega al numero del dinero alli donde acaba (ver
## _coloca_monedas_rebirth()). Antes estaba clavada en 458, o sea a la derecha del
## hueco que el dinero PUEDE llegar a ocupar: con 500 en el contador el cerdito
## flotaba a 210 px del ultimo digito, solo en medio de la barra.
const REBIRTH_COIN_SCALE := 0.17
## Aire entre el ultimo digito del dinero y el cerdito, y entre el cerdito y su
## numero.
const REBIRTH_COIN_GAP := 14.0
const REBIRTH_COINS_GAP := 8.0
## El numero de monedas: mas pequeno que el del dinero, que es el que se mira
## todo el rato. Cabe en dos cifras sin encogerse.
const REBIRTH_COUNT_SCALE := 0.40
const REBIRTH_COUNT_MAX_W := 52.0
## Donde empieza el contador del dinero y cuanto puede crecer antes de encogerse.
## 252 y no 288: el cerdito, ahora del tamano de la moneda, ocupa 87 px mas a su
## derecha y con 288 el grupo se metia debajo del rotulo de la mesa.
const MONEY_X := 128.0
const MONEY_MAX_W := 252.0

## La mesa: donde caen los objetos. Es el rectangulo ENTERO de la superficie
## (el mismo que ocupa el sprite bg_table), y de ahi para dentro se recorta
## todo: el sitio donde nace un objeto, hasta donde se puede arrastrar y por
## donde se pasea. 1344 y 752 son multiplos de 8, que es lo que mide un pixel de
## arte de la mesa, para que el sprite no se deforme al dibujarlo: el fondo se
## genera con estas MISMAS medidas (tools/make_background.py, TABLE_W/TABLE_H),
## asi que si cambia una hay que cambiar la otra y volver a generarlo.
##
## La mesa ya no llega al borde izquierdo: la columna de sobres le come esos
## 368 px de ancho (ver PACK_ZONE).
const TABLE_RECT := Rect2(528, 140, 1344, 752)

## La columna de sobres, a la IZQUIERDA de la mesa: la misma franja de alto que
## la mesa (140..892) y el ancho que le deja la mesa al empezar en 528.
##
## La lista de dentro TIENE SCROLL (ver _build_pack_zone): en 752 px de alto no
## caben doce sobres con el dibujo y el texto en su tamano, asi que la columna es
## una ventana a una lista mas larga en vez de doce filas apinadas.
##
## TODO ESTA MAS GRANDE QUE ANTES, y el precio de eso es scroll: cada fila pide
## 232 px (antes 140) y con doce sobres la lista son 2784 px, asi que en la
## ventana se ven tres filas y pico en vez de cinco. Fue una peticion explicita:
## el dibujo, el nombre y -sobre todo- el precio se leian mal de pequenos, y la
## columna tenia sitio de sobra hacia abajo.
const PACK_ZONE := Rect2(32, 140, 480, 752)
## Ancho de la barra de scroll, pegada al borde derecho de la columna. Sale del
## ancho util: la zona de clic de una fila acaba antes de la barra.
const PACK_SCROLL_W := 10.0
## Alto de fila. Ya NO sale de repartir la columna entre los sobres que haya: con
## el scroll, cada fila mide lo que tiene que medir y lo que sobra se baja con la
## rueda.
## 232 y no menos: media fila son 116 px y el dibujo (176 px de alto colocado a
## PACK_ART_DY) acaba en el centro mas 114. Con un paso mas corto se saldria por
## debajo de su fila y la ultima fila de la lista quedarria cortada por el scroll.
const PACK_ROW_STEP := 232.0
## El hueco del dibujo de cada sobre: un cuadrado oscuro redondeado, SIN marco,
## centrado a PACK_ART_X y a PACK_ART_DY del centro de la fila, con el sobre
## escalado por su DIBUJO para que entre entero (ver UIKit.fit_art). Antes aqui
## iba un ui_slot: doce marcos naranjas seguidos, y dentro de cada uno el sobre
## ocupaba la mitad, porque el marco mide lo mismo para todos y los dibujos no.
const PACK_ART_BOX := Vector2(176.0, 176.0)
const PACK_ART_X := 104.0
const PACK_ART_DY := 26.0
## Donde empieza la chapita del precio: 16 de margen, el hueco del dibujo (176) y
## 16 de aire.
const PACK_TEXT_X := 208.0
## EL NOMBRE VA ARRIBA, a lo ancho de TODA la columna, y debajo van el dibujo y la
## chapita del precio, uno al lado del otro.
##
## Antes el nombre iba a la derecha del dibujo, y ahi no habia manera de
## agrandarlo: al lado de un hueco de 176 px solo quedaban 294 px de ancho, y el
## nombre mas largo del catalogo no cabia ni a 21 (un caracter ocupa el tamano de
## la fuente: la del juego mide 7 px de ancho por caracter a tamano 7). Con el
## nombre arriba, la caja es la columna entera (448 px) y el mas largo cabe justo
## a 28: "ELECTRONICA LUJO" son 16 caracteres, 448 px exactos. Un caracter mas y
## UIKit encogeria los doce nombres a la vez.
const PACK_NAME_BOX := Vector2(448, 36)
const PACK_NAME_X := 16.0
const PACK_NAME_DY := -88.0
## La chapita del precio, al lado del dibujo.
##
## ALTA A PROPOSITO, y no solo ancha: el dibujo de la cinta solo pinta una banda
## fina en medio (medido, un 59 % del alto con el que se estire), asi que a 56 px
## la banda blanca se quedaba en 33 y el numero -36 px de tinta mas el contorno-
## la DESBORDABA por arriba y por abajo. Se veia el precio encima de la cinta en
## vez de dentro. A 88 la banda son 52 px y el numero cabe con aire.
##
## El ancho lo manda la columna: el numero en pantalla es la mitad del ancho de la
## cinta (los glifos son celdas de 8x12 de arte con la tinta en medio), asi que
## ensanchar la chapa es lo unico que hace grande un precio de ocho cifras.
const PACK_TAG_SIZE := Vector2(256, 88)
const PACK_TAG_DY := 26.0
## Fraccion del alto de la chapa que ocupa su BANDA BLANCA de verdad.
##
## No es 1: el sprite de la cinta (ui_tag_price) deja arriba y abajo un borde que
## se desvanece, y sobre el fondo negro eso no se lee como banda blanca. Medido
## sobre una captura (bbox de los pixeles claros contra el alto con el que se
## dibuja), la banda util es un 59 %. La usa el smoke test para comprobar que el
## numero cabe DENTRO de la banda, que es otra cosa que caber en el hueco del
## sprite: con la chapa baja el precio cabia en el sprite y se salia de la banda.
const PACK_TAG_INK := 0.59

## Cada cuanto se prueban sitios para colocar un objeto nuevo, y cuanto aire
## tiene que quedar entre las cajas. Ver _free_spot().
const SPOT_STEP := 32.0
## Las cajas son de 300x340 y el dibujo de dentro de 256x256, asi que 16 px de
## hueco entre cajas son 44 px de aire a la vista. Con este paso y este hueco los
## OCHO objetos que caben en la mesa entran sin pisarse.
const SPOT_PAD := 16.0

## Cada cuanto se aplica el dano de los Pinchos a la mesa (segundos).
const SPIKE_TICK := 0.25

var _table: Control
var _fx: Control
var _money: PixelNumber
## El contador de monedas de rebirth de la barra: el cerdito y, a su derecha, el
## numero. Es la unica moneda del juego que no se gasta, asi que se lee de reojo
## mientras se juega. El cerdito se guarda para poder moverlo: va pegado al
## dinero, y el dinero cambia de ancho (ver _coloca_monedas_rebirth).
var _rebirth_coin: TextureRect
var _rebirth_count: PixelNumber
var _table_label: Label
var _locker_label: Label
var _locker_slots: Array = []
var _elements: Array = []
## Las celdas de la columna de sobres, para poder repintarlas (precio,
## apagado si no te llega y GRATIS en el gratuito).
var _pack_cells: Array = []
var _pack_name_size := 28
## La ventana de la columna de sobres: es lo que se mueve con la rueda.
var _pack_scroll: ScrollContainer = null
var _shop: ShopPanel = null
var _settings: SettingsPanel = null
var _auto_buy_panel: AutoBuyPanel = null
var _locker: LockerPanel = null
var _rebirth: RebirthPanel = null
var _reveal: RevealCard = null
var _auto_open_btn: Button = null
var _auto_buy_btn: Button = null
var _locker_btn: Button = null
var _rebirth_btn: Button = null
var _sell_btn: Button = null
var _rng := RandomNumberGenerator.new()

## Los paquetes que el jugador ha empezado a abrir y que siguen en la mesa.
##
## Es el "turno": el paquete que se empieza NO se suelta hasta que se rompe o
## sale de la mesa, y el cupo de cuantos caben aqui a la vez es el de la mesa
## (ver LootDB.open_count()). Un clic arranca un solo paquete (el pulsado), no
## varios: ver _on_open_requested().
var _worked: Array = []

## LAS TARJETAS DE REVELADO VAN DE UNA EN UNA. Con varios paquetes cargando a la
## vez, dos podian romperse mientras la primera tarjeta seguia abierta, y la
## segunda se pintaba ENCIMA y le quitaba el sitio a la primera en `_reveal`: al
## cerrar la de arriba la de abajo se quedaba sola, con la compra automatica y
## los Pinchos otra vez en marcha por debajo. Lo que sale con una tarjeta abierta
## espera aqui su turno.
var _reveal_queue: Array = []
## El objeto de la tarjeta abierta y su elemento en la mesa (null si no cabia).
## Hacen falta para la foto de la mesa (ver _snapshot_table): un objeto que no
## cabia en la mesa solo existe en la tarjeta, y cerrar el juego con ella abierta
## no puede tirarlo.
var _reveal_data: Dictionary = {}
var _reveal_el: TableElement = null

var _buy_timer := 0.0
var _spike_timer := 0.0
## Cuanto lleva cada botin quieto en la mesa, en segundos, para la mejora MESA
## LIMPIA. Se lleva por elemento y no se le pregunta al elemento porque el reloj
## es de la pantalla: el objeto no sabe si el jugador esta mirando su ficha o
## comprando, y los dos son motivos para no venderlo.
var _loot_age := {}


func _ready() -> void:
	_rng.randomize()
	add_child(UIKit.image("bg_menu_backroom", Vector2(960, 540), Vector2(1920, 1080)))

	# El orden de add_child es el orden de capas: primero lo que va detras.
	_build_table_area()
	_build_pack_zone()

	_table = Control.new()
	_table.name = "Table"
	_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_table)

	_fx = Control.new()
	_fx.name = "Fx"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	_build_top_bar()
	_build_locker()

	Game.money_changed.connect(_on_money_changed)
	# La tira de abajo se repinta con las DOS senales: con los objetos expuestos
	# (locker_changed) y con los niveles comprados (items_changed), porque un
	# nivel mas de armario son huecos nuevos que dejan de estar apagados. Sin la
	# segunda, comprar el armario no se notaba hasta el siguiente objeto expuesto.
	Game.locker_changed.connect(_refresh_locker)
	Game.items_changed.connect(_refresh_locker)
	Game.items_changed.connect(_refresh_top)
	# El Dolar cambia el PRECIO de los sobres, no solo el nivel de un item: la
	# columna de la izquierda tiene que seguir diciendo lo que se cobra.
	Game.items_changed.connect(_refresh_packs)
	Game.open_requested.connect(_on_open_requested)
	Game.settings_changed.connect(_refresh_top)
	Game.table_reset.connect(_clear_table)
	_refresh_locker()
	_refresh_top()
	_on_money_changed(Game.money)
	# La mesa de la ultima vez (ver Game.table) y, a partir de aqui, la foto de la
	# mesa que se lleva cada guardado la saca esta pantalla.
	_restore_table()
	Game.table_provider = _snapshot_table


func _exit_tree() -> void:
	# La pantalla se va (al menu, o se cierra el juego): la ultima foto de la mesa
	# se queda en Game y esta pantalla deja de ser quien la da.
	Game.table = _snapshot_table()
	if Game.table_provider.is_valid() and Game.table_provider.get_object() == self:
		Game.table_provider = Callable()


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

func _build_table_area() -> void:
	# La mesa. Antes esto era una franja oscura con ocho ranuras fijas en
	# rejilla, y los objetos caian siempre en las mismas casillas. Ahora es una
	# superficie (sprite generado con tools/make_background.py --table) y los
	# objetos caen donde quieren y se pueden mover.
	add_child(UIKit.image("bg_table", TABLE_RECT.get_center(), TABLE_RECT.size))

	var line := ColorRect.new()
	line.color = Color(Palette.GOLD_D, 0.55)
	line.position = Vector2(40, 900)
	line.size = Vector2(1840, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)


## La columna de sobres de la izquierda: cada uno con su precio, comprable sin
## abrir ningun menu.
##
## Antes estaban en el panel de la tienda y habia que abrirlo para cada compra.
## Comprar y abrir es el 90 % de lo que se hace en una partida, asi que ahora la
## tienda se queda con los items (que se compran de vez en cuando) y los sobres
## viven aqui, a un clic de la mesa.
func _build_pack_zone() -> void:
	# FONDO NEGRO OPACO, y sin transparencia ninguna.
	#
	# Aqui hubo un fondo tenue y luego ninguno (los dos se probaron y se quitaron,
	# porque sobre las baldas de la trastienda una franja oscura se leia como un
	# parche pegado). El problema de no tenerlo es el otro: los precios, los
	# nombres y los dibujos de la columna se leian ENCIMA de las monedas, las
	# cajas y los estantes claros del fondo, y un numero de nueve cifras sobre una
	# pila de monedas no hay quien lo lea. La columna es una tienda, y una tienda
	# tiene su propio fondo.
	var backdrop := ColorRect.new()
	backdrop.name = "PackBackdrop"
	backdrop.color = Color(0.02, 0.015, 0.04, 1.0)
	backdrop.position = PACK_ZONE.position
	backdrop.size = PACK_ZONE.size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	# Y una raya dorada en su borde derecho, la misma que separa la barra de
	# arriba de la mesa: sin ella el negro de la columna y la penumbra del fondo
	# se tocan y no se ve donde acaba una cosa y empieza la otra.
	var edge := ColorRect.new()
	edge.name = "PackEdge"
	edge.color = Color(Palette.GOLD_D, 0.7)
	edge.position = Vector2(PACK_ZONE.position.x + PACK_ZONE.size.x, PACK_ZONE.position.y)
	edge.size = Vector2(4.0, PACK_ZONE.size.y)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)

	# La columna es una VENTANA a una lista mas larga. Doce sobres a 232 px son
	# 2784 px, y en los 752 de la columna (140..892) no caben ni de lejos: apinando
	# las filas a 62 px se veian todos, pero el dibujo, el nombre y el precio se
	# quedaban en nada. Con el scroll cada fila mide lo que tiene que medir y lo
	# que no cabe se baja con la rueda.
	_pack_scroll = ScrollContainer.new()
	_pack_scroll.position = PACK_ZONE.position
	_pack_scroll.size = PACK_ZONE.size
	_pack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_pack_scroll)
	_style_pack_scrollbar()

	# El contenido: un Control de la altura de TODOS los sobres, y las celdas son
	# hijas SUYAS, no de la pantalla. Si colgaran de la pantalla se quedarian
	# quietas al hacer scroll (el dibujo se mueve con el contenedor) y la zona de
	# clic de cada sobre acabaria en otro sitio que su dibujo.
	var list := Control.new()
	list.name = "PackList"
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.custom_minimum_size = Vector2(0.0, float(LootDB.pack_count()) * PACK_ROW_STEP)
	_pack_scroll.add_child(list)

	# Un solo tamano para todos los nombres, y el que manda es el mas largo: con
	# uno por celda, ELECTRONICA saldria a 35 px y SOBRES a 35 igual, pero el
	# numero del escalon no cuadraria con su nombre, y la columna se leeria como un
	# fallo en vez de como una lista.
	#
	# 28 es el tope Y ES JUSTO: el nombre mas largo, "ELECTRONICA LUJO", son 16
	# caracteres, y a 28 px por caracter son 448 px, el ancho exacto de la caja.
	# 35 serian 560 y no caben. Por eso los escalones se anuncian con una palabra
	# corta (ORO / LUJO) y no con "DE DIAMANTE": un caracter de mas en un solo
	# nombre encoge los doce a 21, y el "SOBRES" de arriba se queda enano.
	var nombres: Array = []
	for i in LootDB.pack_count():
		nombres.append(LootDB.pack_at(i)["name"])
	_pack_name_size = UIKit.row_size(nombres, PACK_NAME_BOX.x, 28)

	for i in LootDB.pack_count():
		_pack_cells.append(_pack_cell(list, LootDB.pack_at(i), i))


## La barra de scroll, con los colores del juego y SIN gritar.
##
## El ScrollContainer de Godot trae la barra con el tema por defecto (gris, con
## las esquinas redondeadas) y en una pantalla entera de pixel art se lee como un
## pegote. Se le cambian los cuatro dibujos por rectangulos planos de la paleta:
## la barra es informacion, no arte, y el juego ya dibuja asi la vida de los
## paquetes y los puntos de nivel de los items.
##
## La cacha va ATENUADA y fina a proposito. A todo color y 12 px de ancho era lo
## mas llamativo de la pantalla -una franja naranja pegada a la mesa que competia
## con los sobres-, cuando el scroll es una ayuda que se usa un segundo y no se
## vuelve a mirar. Con 10 px y al 70 % se ve si la lista sigue, sin mandar.
func _style_pack_scrollbar() -> void:
	var bar := _pack_scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(PACK_SCROLL_W, 0.0)
	bar.add_theme_stylebox_override("scroll", _flat_box(Color(0.02, 0.015, 0.04, 0.45)))
	bar.add_theme_stylebox_override("grabber", _flat_box(Color(Palette.GOLD_D, 0.7)))
	bar.add_theme_stylebox_override("grabber_highlight", _flat_box(Color(Palette.GOLD, 0.9)))
	bar.add_theme_stylebox_override("grabber_pressed", _flat_box(Palette.GOLD_XL))


static func _flat_box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	return sb


## El hueco de un sobre en la columna: un cuadrado oscuro redondeado y ya esta.
##
## Sustituye al ui_slot (marco naranja grueso con el interior hundido). Con doce
## filas seguidas, doce marcos naranjas se comian la columna, y como cada dibujo
## de sobre ocupa un trozo distinto de su lienzo dentro del marco siempre sobraba
## hueco. Aqui el fondo no dibuja nada: solo separa el sobre del negro de la
## columna, y por eso ahora es OPACO y un punto mas claro que el fondo (con el
## negro detras, translucido no se veria y sin el cuadro cada dibujo flotaria en
## el vacio en vez de caer dentro de su hueco).
static func _pack_back(centre: Vector2) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = PACK_ART_BOX
	p.pivot_offset = p.size * 0.5
	p.position = centre - p.size * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.NIGHT_L
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Una fila de la columna: el nombre arriba, a lo ancho de toda la columna, y
## debajo el dibujo del sobre con la chapita del precio al lado. Todo cuelga de
## `list`, que es lo que se mueve al hacer scroll; las coordenadas de aqui son de
## la LISTA, no de la pantalla.
##
## `mid` es el centro de la FILA (el paso por el indice); el dibujo no va a esa
## altura sino un poco mas abajo (PACK_ART_DY), porque el nombre le ha quitado el
## trozo de arriba.
func _pack_cell(list: Control, pack: Dictionary, index: int) -> Dictionary:
	var mid := (float(index) + 0.5) * PACK_ROW_STEP
	var centre := Vector2(PACK_ART_X, mid + PACK_ART_DY)
	var back := _pack_back(centre)
	list.add_child(back)
	# fit_art y no square: escala por el DIBUJO (ver Sprites.used_rect), asi que el
	# sobre llena el hueco que le toca en vez de quedarse pequeno en el centro.
	var art := UIKit.fit_art(str(pack["art"]), centre, PACK_ART_BOX)
	list.add_child(art)

	# El nombre va arriba y a lo ancho de TODA la columna, alineado a la izquierda
	# con el dibujo de abajo (los dos empiezan a x 16). Uno por fila y todos a la
	# misma x: en una lista de doce, un nombre centrado por su cuenta no se alinea
	# con los de arriba ni con los de abajo.
	list.add_child(UIKit.label_at(str(pack["name"]),
			Vector2(PACK_NAME_X + PACK_NAME_BOX.x * 0.5, mid + PACK_NAME_DY),
			PACK_NAME_BOX, _pack_name_size, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_LEFT, 0, true))

	# El precio va en la misma chapita que en la mesa. Cuando el sobre es el
	# gratuito la chapita lleva el rotulo GRATIS y no el numero: un "0" se lee
	# como un precio roto, y el rotulo dice lo que pasa.
	var tag := Vector2(PACK_TEXT_X + PACK_TAG_SIZE.x * 0.5, mid + PACK_TAG_DY)
	var tag_node := UIKit.image("ui_tag_price", tag, PACK_TAG_SIZE)
	list.add_child(tag_node)
	var price := PixelNumber.new()
	# El numero se encoge solo si no cabe en la chapa (max_width), asi que este
	# factor es el tamano de los precios normales: 0.55 son 40 px de tinta de alto
	# (44 con el contorno, dentro de los 52 de la banda blanca) y un avance de 35
	# px por cifra. Los de ocho y nueve cifras (ELECTRONICA ORO y LUJO) se quedan en lo
	# que les deja el ancho de la chapa, que es lo mas grande que se puede hacer
	# sin salirse de la columna.
	price.scale_factor = 0.55
	price.max_width = PACK_TAG_SIZE.x - 20.0
	list.add_child(price)
	# Game.pack_price() y NO pack["price"]: el Dolar descuenta el precio de todos
	# los sobres, y la columna tiene que enseñar lo que se cobra de verdad (ver
	# game_state.pack_price). _refresh_packs() lo vuelve a poner al comprar.
	price.set_number(Game.pack_price(str(pack["id"])))
	price.position = tag - price.size * 0.5
	# GRATIS al mismo tamano que los numeros (35 de fuente son 35 px de tinta,
	# frente a los 40 del numero): es un rotulo corto, y a 28 se leia mas pequeno
	# que los precios de al lado.
	#
	# EN OSCURO Y SIN CONTORNO, y no en oro con el contorno de la fuente: la cinta
	# es crema, y el oro claro con su borde oscuro encima se leia como un borron
	# (relleno casi del color de la cinta y solo el contorno a la vista). Es la
	# MISMA fuente en su version sin contorno, la del titulo del menu.
	var free_label := UIKit.title_label_at("GRATIS", tag,
			PACK_TAG_SIZE - Vector2(24, 4), 35, Palette.NIGHT,
			HORIZONTAL_ALIGNMENT_CENTER)
	free_label.visible = false
	list.add_child(free_label)

	# La zona de clic es la fila ENTERA (nombre, ranura y chapita), no solo el
	# dibujo del sobre: esto es un boton de compra, no un objeto que se arrastra.
	# Acaba antes de la barra de scroll, que esta encima de la columna.
	# Sin tooltip, como el resto: el nombre y el precio ya estan a la vista.
	var b := UIKit.hit_area(list, Rect2(
			Vector2(4.0, mid - PACK_ROW_STEP * 0.5),
			Vector2(PACK_ZONE.size.x - PACK_SCROLL_W - 8.0, PACK_ROW_STEP)), "")
	# PASS y no STOP: pulsar tiene que seguir funcionando igual, pero la rueda del
	# raton tiene que poder llegar al ScrollContainer que hay detras. Con el STOP
	# por defecto el boton de la fila se comeria el giro justo encima de la lista,
	# que es donde se usa.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(_buy_pack.bind(str(pack["id"])))
	return {"art": art, "back": back, "price": price, "tag": tag,
			"tag_node": tag_node, "free": free_label, "button": b}


func _build_top_bar() -> void:
	# Franja oscura detras: sin ella el dinero y los botones se leen encima de
	# las baldas del fondo y no se distinguen bien.
	var bar := ColorRect.new()
	bar.color = Color(0.02, 0.015, 0.04, 0.66)
	bar.size = Vector2(1920, 112)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var line := ColorRect.new()
	line.color = Color(Palette.GOLD_D, 0.7)
	line.position = Vector2(0, 112)
	line.size = Vector2(1920, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	add_child(UIKit.square("currency_coin", Vector2(74, 58), 0.17))
	_money = PixelNumber.new()
	_money.scale_factor = 0.48
	# 252 Y NO 470: el contador del dinero ya no tiene la franja entera para el
	# -a su lado vive el de monedas de rebirth-, asi que este es su presupuesto.
	# "99.999.999" son 307 px y se encoge un 18 %, y a partir de ahi el numero se
	# hace mas pequeno en vez de comerse el cerdito de al lado.
	_money.max_width = MONEY_MAX_W
	add_child(_money)
	_money.set_number(Game.money)
	# El contador se ancla por su IZQUIERDA, no por su centro: si no, cuando el
	# numero crece se sale por la pantalla en vez de empujar lo de al lado.
	_money.position = Vector2(MONEY_X, 58 - _money.size.y * 0.5)

	# LAS MONEDAS DE REBIRTH, AL LADO DE LAS NORMALES. Son la paga permanente y
	# hasta ahora solo se veian dentro del panel de la hucha (y en su tooltip): un
	# numero que decide cuanto valen TODAS las ventas no puede estar detras de un
	# clic. Se dibuja el mismo cerdito dorado que la moneda del panel, DEL TAMANO de
	# la moneda del contador, y los dos se colocan pegados al dinero en
	# _coloca_monedas_rebirth().
	_rebirth_coin = UIKit.square("currency_piggy", Vector2.ZERO, REBIRTH_COIN_SCALE)
	add_child(_rebirth_coin)
	_rebirth_count = PixelNumber.new()
	_rebirth_count.scale_factor = REBIRTH_COUNT_SCALE
	_rebirth_count.max_width = REBIRTH_COUNT_MAX_W
	add_child(_rebirth_count)
	# El numero va ANTES que la posicion: PixelNumber mide su texto al construir
	# los glifos, y sin texto el alto es cero.
	_rebirth_count.set_number(Game.rebirth_coins)
	_coloca_monedas_rebirth()

	# Las cajas van anchas a proposito: label_at agranda la caja si el texto no
	# cabe y la centra, asi que una caja corta deslocaba el texto y lo pegaba al
	# contador. Aqui la caja es EXACTA (8 caracteres a 24 son 192) porque el hueco
	# lo mandan los contadores de la izquierda y el primer icono. La letra baja de
	# 28 a 24 por eso mismo: son 32 px de barra que se lleva el cerdito.
	_table_label = UIKit.label_at("", Vector2(656, 58), Vector2(192, 50), 24,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0)
	add_child(_table_label)
	# El rotulo del dano por golpe que habia aqui ("DANO 12") se ha quitado: es
	# un numero que se mira una vez y ocupa la franja de arriba, que es lo unico
	# que hay a la vista cuando la mesa esta llena.

	# El tooltip dice CON QUE PIEZA se enciende cada uno: son las dos unicas cosas
	# de la barra que no se pueden usar sin comprar algo antes, y el que mira el
	# boton apagado es justo el que necesita saber cual de las dos le falta.
	# LA FILA VA DE IZQUIERDA A DERECHA POR USO: primero las tres cosas que se
	# encienden y se miran de reojo mientras la mesa trabaja (apertura, compra y
	# armario) y despues las tres que se hacen cuando se PARA (vender, tienda y
	# reiniciar la partida). El armario va pegado a las automatizaciones por eso, y
	# el rebirth pegado a la tienda por lo mismo.
	_auto_open_btn = UIKit.icon_button("ui_icon_auto_open", Vector2(808, 58), 80.0,
			"Apertura automatica (con los Pinchos): abre sola los paquetes de la mesa")
	_auto_open_btn.pressed.connect(_toggle_auto_open)
	add_child(_auto_open_btn)

	_auto_buy_btn = UIKit.icon_button("ui_icon_auto_buy", Vector2(904, 58), 80.0,
			"Compra automatica (con el PC): elige que sobres se compran solos")
	_auto_buy_btn.pressed.connect(_open_auto_buy)
	add_child(_auto_buy_btn)

	_locker_btn = UIKit.icon_button("ui_icon_vitrine", Vector2(1000, 58), 80.0,
			"Armario: expone objetos y da sus bonus (con la pieza comprada)")
	_locker_btn.pressed.connect(_open_locker)
	add_child(_locker_btn)

	_sell_btn = UIKit.small_button("VENDER", "", Vector2(1156, 58), 200, 21,
			"ui_button_sell", "ui_button_sell")
	_sell_btn.pressed.connect(_sell_all_table)
	add_child(_sell_btn)

	var shop := UIKit.small_button("TIENDA", "ui_icon_shop", Vector2(1400, 58), 256, 32)
	shop.pressed.connect(_open_shop)
	add_child(shop)

	# LA HUCHA, AL LADO DE LA TIENDA Y DEL MISMO TAMANO QUE ELLA: misma chapa de
	# 256 y mismo pedido de fuente, con el cerdito al lado de la palabra como la
	# tienda lleva su icono. Antes era una chapa pequeña (200 y fuente 21) y se
	# leia como un boton secundario al lado del boton grande de la tienda, cuando es
	# la otra forma de parar la partida. El rotulo se encoge lo que haga falta para
	# caber al lado del dibujo, igual que en TIENDA (fit_size).
	_rebirth_btn = UIKit.small_button("REBIRTH", "currency_piggy", REBIRTH_CENTER,
			REBIRTH_W, 32)
	_rebirth_btn.pressed.connect(_open_rebirth)
	add_child(_rebirth_btn)

	var settings := UIKit.icon_button("ui_icon_settings", Vector2(1856, 58), 80.0,
			"Ajustes")
	settings.pressed.connect(_open_settings)
	add_child(settings)


## La vitrina que hay al lado de la mesa: los objetos EXPUESTOS en el armario,
## de un vistazo y sin abrir nada.
##
## La chapa de la izquierda abre el panel del armario (donde estan el inventario
## y las vitrinas), y cada hueco tambien: lo que se mira es el hueco, y obligar a
## apuntar a la chapa para ver lo que hay dentro de un objeto seria un paso de
## mas para lo unico que se puede hacer con el, que es abrirlo.
func _build_locker() -> void:
	var open := UIKit.small_button("ARMARIO", "ui_icon_vitrine", LOCK_BTN_CENTER,
			LOCK_BTN_W, 21, "ui_button_sell", "ui_button_sell")
	open.tooltip_text = "Armario: expone objetos y da sus bonus"
	open.pressed.connect(_open_locker)
	add_child(open)

	# El rotulo va sobre su fila de huecos, no encima de la chapa. Y a y 918, no a
	# 912: la linea de las baldas pasa por y 900..903 y a 912 la cruzaba por arriba
	# de las letras. Entre la linea (903) y los huecos (936) quedan 33 px, y el
	# rotulo mide 24.
	_locker_label = UIKit.label_at("", Vector2(800, 918), Vector2(400, 44), 26,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0)
	add_child(_locker_label)

	# Los ocho huecos del TOPE del armario, no los que se tienen: los que todavia
	# no son tuyos se dibujan apagados y asi se ve lo que da subirlo de nivel (un
	# hueco mas), que es justo lo que no se veia cuando el armario exponia solo.
	for i in LootDB.LOCKER_SLOTS_MAX:
		var holder := UIKit.slot(Vector2(LOCK_X0 + float(i) * LOCK_STEP, LOCK_Y),
				LOCK_SIDE)
		add_child(holder)
		var b := UIKit.hit_area(self, Rect2(
				Vector2(LOCK_X0 + float(i) * LOCK_STEP, LOCK_Y)
					- Vector2(LOCK_SIDE, LOCK_SIDE) * 0.5,
				Vector2(LOCK_SIDE, LOCK_SIDE)), "Armario: ver los objetos expuestos")
		b.pressed.connect(_open_locker)
		_locker_slots.append({"holder": holder, "button": b})


# --------------------------------------------------------------------------- #
# La mesa
# --------------------------------------------------------------------------- #

## Las casillas donde caen los objetos, repartidas por toda la mesa.
##
## Son una rejilla con una casilla por objeto que cabe A LA VEZ (Game.table_slots())
## y ocupan la mesa entera, no el rincon que les dejan los que ya hay. Con los
## ocho huecos de serie salen cuatro columnas de 336 px y dos filas de 376, o sea
## cajas de 300x340 con 18 px de holgura por lado SIEMPRE, aunque las ocho esten
## puestas: es lo que hace que se vean y se puedan pulsar una por una.
##
## Con mas huecos (el Cajon) la rejilla se aprieta sola. Cuando la casilla se
## queda mas pequena que la caja, el objeto ya no cabe sin pisar al de al lado y
## eso no lo arregla el reparto: ahi se sigue colocando, pero encima.
func _slot_cells() -> Array:
	var n := maxi(1, Game.table_slots())
	var cols := clampi(int(floor(TABLE_RECT.size.x / TableElement.BOX.x)), 1, n)
	var rows := int(ceil(float(n) / float(cols)))
	var cell := Vector2(TABLE_RECT.size.x / float(cols), TABLE_RECT.size.y / float(rows))
	var celdas: Array = []
	for r in rows:
		for c in cols:
			if celdas.size() >= n:
				break
			celdas.append(Rect2(TABLE_RECT.position
					+ Vector2(float(c) * cell.x, float(r) * cell.y), cell))
	return celdas


## Un punto dentro de su casilla, con un temblor corto para que la mesa no parezca
## un tablero. El temblor deja SIEMPRE 8 px de aire hasta el borde de la casilla,
## asi que dos vecinos no se tocan ni en el peor caso (8 + 8).
func _jitter_in(cell: Rect2) -> Vector2:
	var margen := Vector2(
			maxf(0.0, (cell.size.x - TableElement.BOX.x) * 0.5 - 8.0),
			maxf(0.0, (cell.size.y - TableElement.BOX.y) * 0.5 - 8.0))
	var centro := cell.get_center() - TableElement.BOX * 0.5
	return centro + Vector2(_rng.randf_range(-margen.x, margen.x),
			_rng.randf_range(-margen.y, margen.y))


## Un sitio libre para un objeto nuevo, dentro de la mesa, CON AIRE alrededor.
##
## Se prueba primero en las casillas de la rejilla y se coge, al azar entre las
## que estan limpias, una. Eso es lo que hace que dos objetos que salen de dos
## sobres no caigan uno encima de otro: antes cada uno caia en uno de 40 puntos
## sorteados al azar y en las capturas salian tres apilados en un rincon, con los
## dibujos comiendose entre si, teniendo media mesa vacia al lado.
##
## Si no queda ninguna casilla limpia -la mesa llena, o el jugador ha arrastrado
## objetos encima de otras casillas- se barre la mesa entera en pasos de
## SPOT_STEP y se coge el sitio que menos pisa, contando SPOT_PAD de aire alrededor
## de cada objeto. De ahi solo se sale mejor si el jugador los separa arrastrando,
## que para eso se pueden mover.
func _free_spot() -> Vector2:
	var libres: Array = []
	for cell in _slot_cells():
		var p := _jitter_in(cell)
		if _spot_score(p) <= 0.0:
			libres.append(p)
	if not libres.is_empty():
		return libres[_rng.randi_range(0, libres.size() - 1)]

	var x0 := TABLE_RECT.position.x
	var y0 := TABLE_RECT.position.y
	var x1 := x0 + TABLE_RECT.size.x - TableElement.BOX.x
	var y1 := y0 + TABLE_RECT.size.y - TableElement.BOX.y
	var mejor := Vector2(x0, y0)
	var mejor_score := INF
	var y := y0
	while y <= y1 + 0.5:
		var x := x0
		while x <= x1 + 0.5:
			var score := _spot_score(Vector2(x, y))
			if score <= 0.0:
				libres.append(Vector2(x, y))
			elif score < mejor_score:
				mejor_score = score
				mejor = Vector2(x, y)
			x += SPOT_STEP
		y += SPOT_STEP
	if not libres.is_empty():
		return libres[_rng.randi_range(0, libres.size() - 1)]
	return mejor


## Cuanto pisa un candidato a los objetos que ya hay, con SPOT_PAD de aire.
## Cero es sitio limpio.
func _spot_score(p: Vector2) -> float:
	var mine := Rect2(p, TableElement.BOX)
	var score := 0.0
	for el in _elements:
		if is_instance_valid(el):
			score += _overlap(mine,
					Rect2(el.spot(), TableElement.BOX).grow(SPOT_PAD))
	return score


static func _overlap(a: Rect2, b: Rect2) -> float:
	var i := a.intersection(b)
	return maxf(0.0, i.size.x) * maxf(0.0, i.size.y)


## Un punto al azar de la mesa, para los avisos flotantes.
func _table_point() -> Vector2:
	return TABLE_RECT.position + Vector2(
			_rng.randf_range(80.0, TABLE_RECT.size.x - 80.0),
			_rng.randf_range(80.0, TABLE_RECT.size.y - 80.0))


func table_count() -> int:
	return _elements.size()


func table_free() -> bool:
	return _elements.size() < Game.table_slots()


func _add_element(el: TableElement) -> void:
	# El sitio se busca ANTES de meterlo en la lista: _free_spot() mira donde
	# estan los demas, y el que se esta colocando todavia no esta.
	var rest := _free_spot()
	_elements.append(el)
	if el.is_loot():
		_loot_age[el] = 0.0
	el.bounds = TABLE_RECT
	el.opened.connect(_on_element_opened.bind(el))
	el.sold.connect(_on_element_sold.bind(el))
	el.damaged.connect(_on_element_damaged.bind(el))
	_table.add_child(el)
	# La caida la lleva el elemento: asi se puede cortar si el jugador lo agarra
	# antes de que aterrice. Ver TableElement.play_drop().
	el.play_drop(rest)
	_refresh_top()


func _drop_element(el: TableElement) -> void:
	_elements.erase(el)
	_loot_age.erase(el)
	# El que se estaba trabajando suelta el turno al salir de la mesa: es lo que
	# deja empezar con otro (ver _on_open_requested).
	_worked.erase(el)
	_refresh_top()


# --------------------------------------------------------------------------- #
# La mesa guardada
# --------------------------------------------------------------------------- #

## La foto de la mesa para el guardado: cada sobre con la vida que le queda y cada
## botin sin vender. Tambien entra lo que esta esperando tarjeta y el objeto de la
## tarjeta abierta si no cabia en la mesa: los dos existen y no estan en ningun
## otro sitio del guardado.
func _snapshot_table() -> Array:
	var out: Array = []
	for el in _elements:
		if not is_instance_valid(el):
			continue
		if el.is_loot():
			out.append({"loot": (el.loot as Dictionary).duplicate(true)})
		else:
			out.append({"pack": str(el.pack.get("id", "cards")), "hp": maxf(1.0, el.hp)})
	if not _reveal_data.is_empty() and (_reveal_el == null or not _elements.has(_reveal_el)):
		out.append({"loot": _reveal_data.duplicate(true)})
	for item in _reveal_queue:
		out.append({"loot": (item as Dictionary).duplicate(true)})
	return out


## Vuelve a poner en la mesa lo que habia la ultima vez (ver Game.table).
func _restore_table() -> void:
	var saved: Array = Game.table.duplicate(true)
	Game.table = []
	for entry in saved:
		var d: Dictionary = entry
		if d.has("pack"):
			var el := _spawn_pack(str(d["pack"]))
			el.set_hp(float(d.get("hp", el.max_hp)))
		elif d.has("loot"):
			_spawn_loot(d["loot"])


## La mesa se vacia sin cobrar nada: un rebirth o un reinicio (ver
## Game.table_reset). Los elementos salen de la lista EN EL ACTO, antes de que se
## borren de verdad, para que el guardado que viene detras ya no los vea y para
## que una venta o una apertura a medias no pueda pagar en la partida nueva (ver
## los guardas de _on_element_opened y _on_element_sold).
func _clear_table() -> void:
	for el in _elements:
		if is_instance_valid(el):
			el.queue_free()
	_elements.clear()
	_worked.clear()
	_loot_age.clear()
	_reveal_queue.clear()
	_refresh_top()


func _spawn_pack(pack_id: String) -> TableElement:
	var el := TableElement.new()
	el.setup_pack(LootDB.pack_by_id(pack_id))
	_add_element(el)
	return el


## Crea el botin en la mesa y DEVUELVE el elemento: quien lo pide lo necesita
## para poder venderlo o quitarlo despues (la tarjeta de revelado, sin ir mas
## lejos, decide sobre el objeto que ya esta puesto).
func _spawn_loot(item: Dictionary) -> TableElement:
	var el := TableElement.new()
	el.setup_loot(item)
	_add_element(el)
	return el


# --------------------------------------------------------------------------- #
# Bucle: compra, apertura, revelado, venta
# --------------------------------------------------------------------------- #

## El armario: el inventario a la izquierda y las vitrinas a la derecha (ver
## LockerPanel). Se abre SIEMPRE, tenga o no la pieza el jugador: dentro esta
## tambien el inventario, y vender lo guardado no depende del armario.
func _open_locker() -> void:
	if _locker != null:
		return
	Sound.click()
	_locker = LOCKER_SCENE.instantiate() as LockerPanel
	_locker.closed.connect(_close_locker)
	_main().push_veil(_locker)


func _close_locker() -> void:
	Sound.click()
	if _locker != null:
		_main().pop_veil(_locker)
		_locker = null
	_refresh_top()


## La hucha: el panel del rebirth (ver RebirthPanel). Se abre SIEMPRE, tambien
## cuando la partida no da para reiniciarla: el panel es justo el que dice que
## falta, y una chapa que no hace nada no explica nada (misma regla que las dos
## automatizaciones y que la vitrina).
func _open_rebirth() -> void:
	if _rebirth != null:
		return
	Sound.click()
	_rebirth = REBIRTH_SCENE.instantiate() as RebirthPanel
	_rebirth.closed.connect(_close_rebirth)
	_main().push_veil(_rebirth)


func _close_rebirth() -> void:
	if _rebirth != null:
		_main().pop_veil(_rebirth)
		_rebirth = null
	_refresh_rebirth()


func _open_shop() -> void:
	if _shop != null:
		return
	Sound.click()
	_shop = SHOP_SCENE.instantiate() as ShopPanel
	_shop.closed.connect(_close_shop)
	_main().push_veil(_shop)


func _close_shop() -> void:
	Sound.click()
	if _shop != null:
		_main().pop_veil(_shop)
		_shop = null


## Comprar un sobre de la columna de la izquierda. Es la unica puerta de entrada
## de paquetes desde que la tienda se quedo con los items.
func _buy_pack(pack_id: String) -> void:
	# La mesa se mira ANTES de cobrar: es mas claro no cobrar que cobrar y
	# devolver, que es lo que hacia la tienda cuando el sobre no cabia.
	if not table_free():
		Sound.play("sfx_error")
		Game.notice.emit("MESA LLENA", Palette.RUST_L)
		return
	var price := Game.pack_price(pack_id)
	if not Game.can_afford(price):
		Sound.play("sfx_error")
		Game.notice.emit("NO TE LLEGA", Palette.RUST_L)
		return
	Game.spend(price)
	Sound.play("sfx_buy")
	_spawn_pack(pack_id)
	_refresh_packs()


func _on_element_opened(pack_id: String, el: TableElement) -> void:
	# Un sobre que ya no es de la mesa (se vacio con un rebirth mientras se rompia)
	# no da botin: era de la partida anterior.
	if not _elements.has(el):
		return
	_drop_element(el)
	Game.packs_opened += 1
	# La suerte (Trebol) engorda el botin no comun y el multiplicador del Armario
	# sube el valor de lo que sale.
	var item := LootDB.roll_pack(_rng, pack_id, Game.luck(), Game.value_multiplier())
	# Encontrado es una cosa y guardado es otra: se apunta aqui, cuando sale,
	# porque a partir de este punto puede venderse sin pasar por el inventario.
	Game.register_found(item)
	# Dos formas de vender sin pasar por la mesa: la venta automatica de los
	# ajustes (todo) y la mejora SIN FICHA del arbol (solo la chatarra, ver
	# Game.auto_sell_chaff). La de los ajustes va primero porque es la que pidio el
	# jugador para TODA la partida.
	if Game.auto_sell or Game.auto_sell_chaff(item):
		_sell_quietly(item)
		return
	_reveal_item(item)


## Venta automatica: el objeto se vende nada mas salir, sin tarjeta y sin mesa.
func _sell_quietly(item: Dictionary) -> void:
	var value := int(item.get("value", 0))
	Game.add_money(value)
	Sound.play("sfx_sell")
	_float_text("+" + PixelNumber.format(value), _table_point(), Palette.GOLD_XL)


func _reveal_item(item: Dictionary) -> void:
	# Con una tarjeta abierta, este espera su turno (ver _reveal_queue).
	if _reveal != null:
		_reveal_queue.append(item)
		return
	# Primero el sonido de que se ha abierto, y ENCIMA el del premio si toca:
	# en ese orden se entiende "algo ha salido" y luego "y es bueno".
	Sound.play("sfx_open")
	var rarity_id := str(item.get("rarity", "common"))
	if rarity_id == "epic" or rarity_id == "legendary":
		Sound.play("sfx_rare")

	# El objeto cae en la mesa ANTES de la tarjeta, asi que cuando se cierra ya
	# esta puesto, en su sitio, y se puede mover y vender como cualquier otro.
	# Y NO se guarda solo en el inventario: eso lo decide el boton GUARDAR o
	# VENDER. Antes se hacia las dos cosas y el objeto acababa duplicado, en la
	# mesa y en el inventario a la vez.
	var el: TableElement = null
	if table_free():
		el = _spawn_loot(item)

	var card := REVEAL_SCENE.instantiate() as RevealCard
	card.show_item(item)
	card.resolved.connect(_on_reveal_resolved.bind(item, el))
	_reveal = card
	_reveal_data = item
	_reveal_el = el
	_main().push_overlay(card)


## Que hacer con el objeto cuando se cierra la tarjeta.
func _on_reveal_resolved(action: String, item: Dictionary, el: TableElement) -> void:
	if _reveal != null:
		_main().pop_overlay(_reveal)
		_reveal = null
	_reveal_data = {}
	_reveal_el = null
	if action == RevealCard.ACTION_STORE:
		_store_revealed(item, el)
	elif action == RevealCard.ACTION_SELL:
		_sell_revealed(item, el)
	elif el == null:
		# Cerrada sin elegir y sin sitio en la mesa: se guarda, que es lo unico
		# que no pierde el objeto. Con sitio, se queda en la mesa y ya esta.
		_store_revealed(item, null)
	# Y la siguiente que estuviera esperando.
	if not _reveal_queue.is_empty():
		_reveal_item(_reveal_queue.pop_front())


## Al inventario. El objeto DEJA la mesa: no puede estar en los dos sitios.
func _store_revealed(item: Dictionary, el: TableElement) -> void:
	var stored := Game.store(item)
	_remove_from_table(el)
	# store() ya vende y avisa solo cuando el inventario esta lleno; el sonido lo
	# pone aqui para que se oiga igual que las demas ventas.
	Sound.play("sfx_click" if stored else "sfx_sell")


func _sell_revealed(item: Dictionary, el: TableElement) -> void:
	var value := int(item.get("value", 0))
	var at := TABLE_RECT.get_center()
	if el != null and is_instance_valid(el):
		at = el.global_position + el.size * 0.5
		# sell_instant() coge el valor del elemento y lo borra, pero no ingresa
		# nada: el dinero lo lleva siempre _sell_revealed. Si devuelve 0 es que el
		# objeto ya se estaba vendiendo solo, y esa venta es la que paga.
		var instant := el.sell_instant()
		if instant <= 0:
			return
		value = instant
		_drop_element(el)
	Game.add_money(value)
	Sound.play("sfx_sell")
	_float_text("+" + PixelNumber.format(value), at, Palette.GOLD_XL)
	_refresh_top()


func _remove_from_table(el: TableElement) -> void:
	if el == null or not is_instance_valid(el):
		return
	_drop_element(el)
	el.queue_free()
	_refresh_top()


func _on_element_sold(value: int, at: Vector2, el: TableElement) -> void:
	# Lo que se vendia cuando la mesa se vacio (un rebirth) no paga en la partida
	# nueva.
	if not _elements.has(el):
		return
	_drop_element(el)
	Game.add_money(value)
	Sound.play("sfx_sell")
	_float_text("+" + PixelNumber.format(value), at, Palette.GOLD_XL)


## Ha terminado una redonda de la carga de ese paquete: el numero del dano sale
## encima de su dibujo, en naranja o en amarillo si el golpe ha sido critico.
##
## Lo pinta esta capa (_fx) y no el elemento por el mismo motivo que los avisos
## de venta: el elemento que rompe la caja se va con un tween de escala y alfa
## (ver TableElement._finish()), y un numero colgado de el se iria con la caja
## justo en el golpe que mas interesa leer.
func _on_element_damaged(amount: float, crit: bool, el: TableElement) -> void:
	if _fx == null or not is_instance_valid(el):
		return
	# La capa de los avisos y la mesa son las dos hijos de esta pantalla puestos
	# en el origen, asi que las coordenadas de una valen en la otra: es lo mismo
	# que hace la venta, que pasa el global_position del elemento a _float_text().
	var at: Vector2 = el.global_position \
			+ Vector2(TableElement.BOX.x * 0.5, TableElement.ART_CENTER.y - 36.0)
	DamagePopup.pop(_fx, at, amount, crit)


func _sell_all_table() -> void:
	var total := 0
	# Se suelta uno a uno con _drop_element() en vez de vaciar la lista de golpe.
	#
	# SOLO EL BOTIN. Antes se soltaban TODOS los elementos, tambien los sobres
	# cerrados: sell_instant() no los vende (devuelve 0 y no los borra), asi que
	# se quedaban dibujados en la mesa pero fuera de la lista. La mesa contaba
	# huecos que no tenia, los Pinchos dejaban de golpearlos y la compra se podia
	# pasar del tope. Y un botin que ya se estaba vendiendo tampoco se suelta: su
	# venta paga sola al acabar (ver TableElement.sell_instant).
	for el in _elements.duplicate():
		if not is_instance_valid(el):
			_drop_element(el)
			continue
		if not el.is_loot():
			continue
		var value: int = el.sell_instant()
		if value > 0:
			total += value
			_drop_element(el)
	if total > 0:
		Game.add_money(total)
		Sound.play("sfx_sell_all")
		_float_text("+" + PixelNumber.format(total), Vector2(960, 500), Palette.GOLD_XL)
	_refresh_top()


# --------------------------------------------------------------------------- #
# Automatizaciones
# --------------------------------------------------------------------------- #

func _process(delta: float) -> void:
	if _reveal != null:
		return
	if Game.auto_buy:
		_buy_timer -= delta
		if _buy_timer <= 0.0:
			_buy_timer = Game.auto_buy_interval()
			_auto_buy_step()
	_spike_step(delta)
	_table_broom_step(delta)


## La mejora MESA LIMPIA: lo que lleva AUTO_SELL_TABLE_AFTER segundos quieto en la
## mesa se vende solo, al mismo precio que si se pulsara.
##
## El reloj no corre con la ficha de revelado abierta (ver _process, que sale
## antes), y esa es la mitad de la mejora: la mesa se vacia mientras el jugador
## esta en otra pantalla, no mientras esta decidiendo que hacer con lo que acaba
## de salir.
##
## Se vende con el camino de siempre (_on_element_sold) colgado de la venta
## instantanea: el dinero, el sonido y el aviso flotante son los mismos que los
## de un clic, que es lo que hace que la mejora no cambie las cuentas.
func _table_broom_step(delta: float) -> void:
	if not Game.skill_owned(SkillTree.QOL_TABLE):
		# Sin la mejora no se lleva la cuenta: apagarla y volver a encenderla no
		# puede vender de golpe lo que se acumulo mientras estaba apagada.
		_loot_age.clear()
		return
	for el in _loot_age.keys():
		if not is_instance_valid(el) or not _elements.has(el) or not el.is_loot():
			_loot_age.erase(el)
			continue
		_loot_age[el] = float(_loot_age[el]) + delta
		if float(_loot_age[el]) < LootDB.AUTO_SELL_TABLE_AFTER or el.is_busy():
			continue
		var at: Vector2 = el.global_position + el.size * 0.5
		# Tipado a mano: `el` sale del diccionario y GDScript no sabe que es un
		# TableElement, asi que no puede deducir el tipo de lo que devuelve.
		var value: int = el.sell_instant()
		_on_element_sold(value, at, el)


## Los Pinchos: con la apertura automatica ENCENDIDA danan solos los paquetes
## de la mesa, sin que se les haga clic.
##
## Los Pinchos no van por su cuenta. Son la pieza que hace falta para poder
## encender la apertura automatica (ver LootDB.AUTO_ITEM_OPEN), y encenderla es
## lo que los pone a golpear: el jugador compra la pieza y le da al interruptor.
## Apagada, no hacen nada -la mesa se abre a clics, como siempre-, y por eso el
## dano se aplica AQUI y no en el propio item.
##
## EL DANO ES UN TOTAL QUE SE REPARTE entre los paquetes que hay en la mesa, no
## una cantidad por paquete. Es la diferencia entre una automatizacion y una
## barbaridad: dando a cada paquete el dano entero, ocho paquetes en la mesa eran
## ocho veces el dano del jugador y con el PC y la venta automatica la partida se
## terminaba sola. Repartido, la mesa entera avanza al ritmo de tu dedo (ver
## LootDB.SPIKE_SHARE).
##
## El dano se acumula y se aplica a tirones para que la barra de cada paquete
## baje de forma continua y no a saltos de frame.
func _spike_step(delta: float) -> void:
	if not Game.auto_open:
		# Se tira lo acumulado: si no, al encenderla se aplicaria de golpe todo
		# el tiempo que ha estado apagada.
		_spike_timer = 0.0
		return
	var dps := Game.spike_dps()
	if dps <= 0.0:
		return
	_spike_timer += delta
	if _spike_timer < SPIKE_TICK:
		return
	var packs: Array = []
	for el in _elements:
		if is_instance_valid(el) and not el.is_loot():
			packs.append(el)
	var amount := dps * _spike_timer / float(maxi(1, packs.size()))
	_spike_timer = 0.0
	for el in packs:
		el.take_damage(amount)


## Un paquete ha pedido abrirse (el jugador le ha hecho clic).
##
## UN CLIC ES UN PAQUETE, y solo el pulsado: aqui no se arranca ninguno de
## propina. Lo que sube el cupo es cuantos paquetes se pueden llevar A LA VEZ
## (Game.open_count(), que hoy es el de la mesa), que es otra cosa: el jugador
## tiene que ir pulsando uno y otro para que avancen todos, y machacar el mismo
## no adelanta mas que el suyo.
##
## El "turno" de cada paquete empezado no se suelta hasta que se rompe o sale de
## la mesa (ver _drop_element()), asi que el cupo se nota en CUANTOS caben, no en
## cuantas veces hay que pulsar.
func _on_open_requested(el: Object) -> void:
	if not (el is TableElement) or not is_instance_valid(el):
		return
	var pack := el as TableElement
	# Ya se esta cargando: el clic no hace nada (no se encola un segundo golpe).
	if not pack.can_open():
		return
	if not _worked.has(pack):
		var hueco := Game.open_count()
		if _worked.size() >= hueco:
			Sound.play("sfx_error")
			Game.notice.emit("YA LLEVAS %d A LA VEZ" % hueco, Palette.RUST_L)
			return
		_worked.append(pack)
	pack.start_opening()


## Un paso de la compra automatica: coge el sobre MAS BARATO de los que el
## jugador tiene marcados en su mini menu (ver AutoBuyPanel) que pueda pagar, y
## lo compra.
##
## "El mas barato de los marcados" es lo que hace que el menu sirva de algo: con
## los doce marcados va subiendo de escalon sola segun se enriquece, y marcando
## solo los de arriba se apunta a lo caro.
func _auto_buy_step() -> void:
	# Tampoco con el REBIRTH abierto: alli se esta decidiendo si reiniciar con el
	# dinero que hay, y el requisito y las monedas se miden en el contador. Antes la
	# compra seguia gastando por debajo del panel y el numero bajaba mientras se
	# leia. Ni con los ajustes, por lo mismo que con la tienda.
	if not table_free() or _shop != null or _auto_buy_panel != null or _locker != null \
			or _reveal != null or _rebirth != null or _settings != null:
		return
	var best := ""
	var best_price := 1 << 60
	for i in LootDB.pack_count():
		var p: Dictionary = LootDB.pack_at(i)
		var pack_id := str(p["id"])
		if not Game.auto_buy_wants(pack_id):
			continue
		var price := Game.pack_price(pack_id)
		# El sobre gratuito se SALTA a proposito: si entrara, la automatizacion
		# se quedaria comprandolo para siempre y no gastaria un duro en los de
		# pago, que es justo para lo que sirve la compra automatica. El gratuito
		# es la red de seguridad y se compra a mano.
		if price <= 0:
			continue
		if price <= Game.money and price < best_price:
			best_price = price
			best = pack_id
	if best == "":
		return
	Game.spend(best_price)
	_spawn_pack(best)
	_refresh_packs()


## Enciende o apaga la apertura automatica: los Pinchos empiezan a golpear la
## mesa solos. Sin los Pinchos lo dice y no enciende nada (el PC no hace falta
## para esto: cada automatizacion va con su pieza).
func _toggle_auto_open() -> void:
	if not Game.auto_open_unlocked():
		_locked_notice(LootDB.AUTO_ITEM_OPEN)
		return
	Sound.play("sfx_toggle")
	Game.set_auto_open(not Game.auto_open)
	_refresh_top()
	var que := "PINCHOS ACTIVOS" if Game.auto_open else "NO"
	Game.notice.emit("AUTO APERTURA: " + que, Palette.CREAM_D)


## El boton de la compra automatica ABRE su mini menu en vez de encenderse y
## apagarse. La compra automatica no es solo SI o NO: tambien es QUE se compra,
## y eso no cabe en un boton de la barra (ver AutoBuyPanel).
func _open_auto_buy() -> void:
	if not Game.auto_buy_unlocked():
		_locked_notice(LootDB.AUTO_ITEM_BUY)
		return
	if _auto_buy_panel != null:
		return
	Sound.click()
	_auto_buy_panel = AUTO_BUY_SCENE.instantiate() as AutoBuyPanel
	_auto_buy_panel.closed.connect(_close_auto_buy)
	_main().push_veil(_auto_buy_panel)


func _close_auto_buy() -> void:
	Sound.click()
	if _auto_buy_panel != null:
		_main().pop_veil(_auto_buy_panel)
		_auto_buy_panel = null
	_refresh_top()


## Aviso de que esa automatizacion todavia no existe: dice QUE pieza falta, que
## es lo unico util ("no puedes" no lleva a ningun sitio). Se le pasa la pieza
## de ESE boton, asi que el de la apertura habla de los Pinchos y el de la compra
## del PC, y ninguno de los dos nombra a la del otro.
func _locked_notice(item_id: String) -> void:
	Sound.play("sfx_error")
	var name := str(LootDB.item_by_id(item_id)["name"])
	Game.notice.emit("HACEN FALTA: " + name, Palette.RUST_L)


# --------------------------------------------------------------------------- #
# Refresco de la interfaz
# --------------------------------------------------------------------------- #

func _on_money_changed(value: int) -> void:
	if is_instance_valid(_money):
		_money.set_number(value)
		# El dinero cambio de ancho (o de cifras): el cerdito se vuelve a pegar a
		# su ultimo digito.
		_coloca_monedas_rebirth()
	# Los sobres de la izquierda se apagan cuando no te llega su precio, asi que
	# cualquier cambio de dinero los tiene que repintar.
	_refresh_packs()
	# Y la chapa de la hucha se enciende con lo GANADO en la partida: el dinero que
	# entra es justo lo que mueve el requisito del rebirth, asi que se repinta aqui.
	_refresh_rebirth()


## El estado de las celdas de sobres: apagadas si no te llega el precio y
## con GRATIS en el que todavia es gratuito.
func _refresh_packs() -> void:
	for i in _pack_cells.size():
		var cell: Dictionary = _pack_cells[i]
		if not is_instance_valid(cell["art"]):
			continue
		var pack_id := str(LootDB.pack_at(i)["id"])
		var free := Game.pack_free(pack_id)
		var affordable := free or Game.can_afford(Game.pack_price(pack_id))
		(cell["art"] as TextureRect).modulate = Color.WHITE if affordable \
				else Color(0.55, 0.55, 0.62, 1.0)
		var num: PixelNumber = cell["price"]
		var rotulo: Label = cell["free"]
		num.visible = not free
		rotulo.visible = free
		if free:
			continue
		num.color = Palette.CREAM if affordable else Palette.RUST_L
		# El numero se reescribe porque el Dolar abarata los sobres: set_number()
		# no reconstruye nada si el valor no ha cambiado (ver pixel_number.gd),
		# asi que repintar por cada moneda que entra no cuesta nada.
		num.set_number(Game.pack_price(pack_id))
		# El numero cambia de ancho al apagarse o al crecer: se vuelve a centrar.
		num.position = (cell["tag"] as Vector2) - num.size * 0.5


## Pone el cerdito y su numero justo detras del ultimo digito del dinero.
##
## El ancho del dinero se mide con _money.size.x, que es el de SUS CELDAS (ver
## PixelNumber._rebuild) y no cambia al subir un digito: solo cuando el contador
## gana o pierde una cifra. Por eso el cerdito se pega de verdad al numero y aun
## asi no baila con cada venta.
##
## Va SIN centrar en el hueco que le queda a la barra: los dos huecos que manda
## son los de arriba (REBIRTH_COIN_GAP y REBIRTH_COINS_GAP), y el cerdito puede
## acabar en cualquier sitio entre el dinero y el rotulo de la mesa. Es lo que
## pide el que mira el contador: las monedas se leen como parte del dinero.
func _coloca_monedas_rebirth() -> void:
	if not is_instance_valid(_money) or not is_instance_valid(_rebirth_coin) \
			or not is_instance_valid(_rebirth_count):
		return
	var x := MONEY_X + _money.size.x + REBIRTH_COIN_GAP
	# UIKit.image() coloca por centro y el nodo se mueve por su esquina: la
	# izquierda del cerdito es la x que se pide, sin restarle nada.
	_rebirth_coin.position = Vector2(x, 58 - _rebirth_coin.size.y * 0.5)
	_rebirth_count.position = Vector2(x + _rebirth_coin.size.x + REBIRTH_COINS_GAP,
			58 - _rebirth_count.size.y * 0.5)


func _refresh_top() -> void:
	if is_instance_valid(_table_label):
		_table_label.text = "MESA %d/%d" % [table_count(), Game.table_slots()]
	# Las monedas de rebirth solo cambian al reiniciar, y eso emite
	# settings_changed; pero el repintado va aqui, con el resto de la barra, para
	# no tener un camino aparte que se pueda olvidar.
	if is_instance_valid(_rebirth_count):
		_rebirth_count.set_number(Game.rebirth_coins)
		_coloca_monedas_rebirth()
	# Cada boton de automatizacion se pinta bloqueado por SU pieza: el de abrir
	# espera a los Pinchos y el de comprar al PC. Apagado se ve que aun no sirve, y
	# el clic sigue llegando para poder decir cual falta (ver _locked_notice()).
	if is_instance_valid(_auto_open_btn):
		UIKit.set_icon_button_lit(_auto_open_btn, Game.auto_open)
		UIKit.dim_icon_button(_auto_open_btn, not Game.auto_open_unlocked())
	if is_instance_valid(_auto_buy_btn):
		UIKit.set_icon_button_lit(_auto_buy_btn, Game.auto_buy)
		UIKit.dim_icon_button(_auto_buy_btn, not Game.auto_buy_unlocked())
	# El armario se marca apagado mientras no se tenga la pieza, como las dos
	# automatizaciones: NO se bloquea el boton (dentro esta el inventario, que se
	# usa desde el primer minuto), pero de un vistazo se ve que todavia no hay
	# vitrina donde exponer nada.
	if is_instance_valid(_locker_btn):
		UIKit.dim_icon_button(_locker_btn, Game.locker_slots() <= 0)
	if is_instance_valid(_sell_btn):
		_sell_btn.disabled = _count_table_loot() == 0
	_refresh_rebirth()


## La chapa del rebirth: apagada mientras la partida no de para reiniciarla.
##
## El tooltip dice QUE falta, que es lo unico util de una chapa apagada. Las
## monedas ya no viven aqui: tienen su propio contador en la barra, al lado del
## dinero (ver _build_top_bar), asi que el tooltip se queda con la explicacion de
## la chapa apagada y con el recuerdo de cuantas llevas.
##
## Depende del DINERO QUE HAY EN EL CONTADOR, que cambia con todo lo que entra y
## sale de la partida (ver _on_money_changed) y no solo con los items: por eso no
## basta con _refresh_top, que se llama por las otras senales.
func _refresh_rebirth() -> void:
	if not is_instance_valid(_rebirth_btn):
		return
	var puede := Game.can_rebirth()
	_rebirth_btn.modulate = Color.WHITE if puede else Color(0.55, 0.55, 0.62, 1.0)
	if puede:
		_rebirth_btn.tooltip_text = "REBIRTH: la hucha (%d monedas): reinicia la partida a cambio de monedas" % Game.rebirth_coins
	else:
		_rebirth_btn.tooltip_text = ("REBIRTH: te faltan %s en el contador"
			% PixelNumber.format(Game.rebirth_missing()))


## La tira de la vitrina: el rotulo y los ocho huecos.
func _refresh_locker() -> void:
	if is_instance_valid(_locker_label):
		_locker_label.text = "ARMARIO %d/%d EXPUESTOS" % [Game.locker_size(),
				Game.locker_slots()]
	var slots := Game.locker_slots()
	for i in _locker_slots.size():
		var holder: Control = _locker_slots[i]["holder"]
		var b: Button = _locker_slots[i]["button"]
		for c in holder.get_children():
			if c.name != "Back":
				holder.remove_child(c)
				c.queue_free()
		var back := holder.get_node_or_null("Back") as TextureRect
		if back != null:
			back.modulate = Color.WHITE if i < slots else Color(0.35, 0.35, 0.4, 1.0)
		if i >= Game.locker.size():
			continue
		var item: Dictionary = Game.locker[i]
		# fit_art y no square: los objetos no llenan igual su lienzo y escalados
		# por el lienzo se verian de tres tamanos distintos en la misma fila.
		holder.add_child(UIKit.fit_art(str(item.get("art", "loot_vinyl")),
				Vector2(LOCK_SIDE * 0.5, LOCK_SIDE * 0.5 - 8.0),
				Vector2(LOCK_SIDE * 0.62, LOCK_SIDE * 0.62)))
		# A 0,22 y no a 0,15: a 0,15 la cifra media 11 px y no se leia desde la
		# silla. Un poco mas abajo que antes para no tocar el dibujo.
		var num := PixelNumber.new()
		num.scale_factor = 0.22
		num.max_width = LOCK_SIDE - 12.0
		holder.add_child(num)
		num.set_number(int(item.get("value", 0)))
		num.position = Vector2(LOCK_SIDE * 0.5, LOCK_SIDE - 22.0) - num.size * 0.5
		b.tooltip_text = "Armario: %s expuesto" % str(item.get("name", ""))


func _count_table_loot() -> int:
	var n := 0
	for el in _elements:
		if is_instance_valid(el) and el.is_loot():
			n += 1
	return n


# --------------------------------------------------------------------------- #
# Detalles de pantalla
# --------------------------------------------------------------------------- #

func _float_text(text: String, at: Vector2, color: Color) -> void:
	var num := PixelNumber.new()
	num.scale_factor = 0.5
	num.set_text(text)
	num.color = color
	_fx.add_child(num)
	num.position = at - num.size * 0.5
	var rise := num.position.y - 90.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(num, "position:y", rise, 0.9).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(num, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(num.queue_free)


func _open_settings() -> void:
	if _settings != null:
		return
	Sound.click()
	_settings = SETTINGS_SCENE.instantiate() as SettingsPanel
	_settings.closed.connect(_on_settings_closed)
	_main().push_veil(_settings)


func _on_settings_closed() -> void:
	_settings = null


func _main() -> MainRoot:
	return MainRoot.get_root()


## Los atajos de la mejora ATAJOS: T la tienda, A el armario, R el rebirth y V
## vende la mesa. Todo lo que estaba a un viaje de raton a la barra.
##
## SE MIRAN ANTES QUE EL ESC y solo con la partida DESPEJADA: si hay una ficha de
## revelado o cualquier panel abierto, la letra no hace nada. Si no fuera asi, la
## T abriria la tienda encima de la ficha del objeto que estas decidiendo -y peor:
## la V venderia la mesa desde dentro de una pantalla en la que la mesa ni se ve.
##
## La tecla se lee de `keycode` y, si viene a cero, de `physical_keycode`: con una
## distribucion que no sea la espanola, la tecla fisica es la que el jugador
## pulsa y la que esta escrita en el menu.
func _hotkey(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if not Game.skill_owned(SkillTree.QOL_KEYS) or not _table_clear():
		return false
	var code := key.keycode if key.keycode != 0 else key.physical_keycode
	match code:
		KEY_T:
			_open_shop()
		KEY_A:
			_open_locker()
		KEY_R:
			_open_rebirth()
		KEY_V:
			_sell_all_table()
		_:
			return false
	return true


## ¿No hay nada abierto encima de la mesa? Es la condicion de los atajos.
func _table_clear() -> bool:
	return _reveal == null and _settings == null and _locker == null \
			and _shop == null and _rebirth == null and _auto_buy_panel == null


## "2.10" -> "2.1"
static func _trim(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


func _unhandled_input(event: InputEvent) -> void:
	if _hotkey(event):
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _reveal != null:
		return
	if _settings != null:
		_main().pop_veil(_settings)
		_settings = null
	elif _locker != null:
		_close_locker()
	elif _auto_buy_panel != null:
		_close_auto_buy()
	elif _shop != null:
		_close_shop()
	else:
		Game.save_game()
		_main().show_menu()
	get_viewport().set_input_as_handled()
