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
const LIBRETA_SCENE := preload("res://scenes/LibretaPanel.tscn")

## La LIBRETA (album y encargos): su chapa va al lado de la del armario.
const LIBRETA_BTN_CENTER := Vector2(480, 1000)
const LIBRETA_BTN_W := 200.0
## La barra de HABILIDADES, abajo a la derecha (despues de la vitrina, que acaba
## en x 1648). Tres botones de 72 con su numero de recarga encima.
const ABIL_X0 := 1712.0
const ABIL_STEP := 80.0
const ABIL_Y := 1000.0
const ABIL_SIDE := 72.0
## La banda de los eventos, ABAJO de la mesa: una linea por evento en curso, la
## primera pegada al borde y la segunda encima. Estuvo arriba y no valia: los
## avisos (Main._toast) salen justo ahi, y un "SOBRE DORADO" encima de la linea
## del VIP no se leia ni lo uno ni lo otro; ademas tapaba el borde de arriba de
## los paquetes de la primera fila. Abajo solo queda el hueco que deja la caja
## (BOX) por debajo del dibujo de la segunda fila, y por eso es fina (34 px).
const EVENT_BAND_BOTTOM := 888.0
const EVENT_LINE_H := 34.0

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
## Cada cuanto compra sola la tienda (un nivel cada vez): lo bastante lento para
## que se vea cada compra y no se vacie el dinero de golpe en un frame.
const AUTO_ITEMS_EVERY := 0.5

var _table: Control
var _fx: Control
var _shake_tween: Tween = null
var _money_shown := 0
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
## El objeto de la tarjeta abierta. Hace falta para la foto de la mesa (ver
## _snapshot_table): solo existe en la tarjeta, y cerrar el juego con ella
## abierta no puede tirarlo.
var _reveal_data: Dictionary = {}

var _buy_timer := 0.0
## El reloj de la compra automatica de la tienda (ver _auto_items_step).
var _items_timer := 0.0
var _spike_timer := 0.0
## Los relojes que hacen APARECER los eventos (ver Gameplay). Solo corren con la
## mesa a la vista (ver _events_step).
var _golden_timer := Gameplay.GOLDEN_FIRST
var _vip_timer := Gameplay.VIP_FIRST
var _happy_timer := Gameplay.HAPPY_FIRST
var _boss_timer := Gameplay.BOSS_FIRST
## El combo de apertura (ver Gameplay.COMBO_WINDOW): cuantos sobres seguidos y el
## tiempo que queda para romper el siguiente sin perderlo.
var _combo := 0
var _combo_left := 0.0
var _streak_label: Label = null
var _combo_label: Label = null
var _combo_bar: ColorRect = null
var _libreta: Control = null
var _event_band: Control = null
var _event_lines: Array = []
## Los tres botones de habilidad: {id, button, num}.
var _abil_buttons: Array = []
## Cuanto lleva cada botin quieto en la mesa, en segundos, para la mejora MESA
## LIMPIA. Se lleva por elemento y no se le pregunta al elemento porque el reloj
## es de la pantalla: el objeto no sabe si el jugador esta mirando su ficha o
## comprando, y los dos son motivos para no venderlo.


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
	_build_libreta_button()
	_build_abilities()
	_build_event_band()
	_build_hud()

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
	Game.events_changed.connect(_refresh_event_band)
	Game.abilities_changed.connect(_refresh_abilities)
	Game.skills_changed.connect(_refresh_abilities)
	_refresh_locker()
	_refresh_top()
	_on_money_changed(Game.money)
	# La mesa de la ultima vez (ver Game.table) y, a partir de aqui, la foto de la
	# mesa que se lleva cada guardado la saca esta pantalla.
	_restore_table()
	Game.table_provider = _snapshot_table
	# Lo ganado con el juego cerrado (ver Game.OFFLINE_RATE), contado una vez.
	if Game.offline_earned > 0:
		_show_offline.call_deferred(Game.offline_earned)
		Game.offline_earned = 0


func _show_offline(amount: int) -> void:
	if _main() != null:
		_main().banner("MIENTRAS NO ESTABAS",
				"LOS PINCHOS GANARON %s" % LootDB.short_number(amount))


func _exit_tree() -> void:
	# Por si la pantalla se va en mitad de un hitstop.
	Engine.time_scale = 1.0
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
	# GRATIS SE ESCRIBE CON LAS CIFRAS DEL PRECIO: es un PixelNumber como el de al
	# lado, con las letras dibujadas en el mismo estilo que los numeros (bisel
	# dorado y contorno, ver PixelNumber.GLYPHS). Con la fuente de texto se veia
	# como otra letra, con o sin contorno.
	var free_label := PixelNumber.new()
	free_label.scale_factor = 0.55
	free_label.max_width = PACK_TAG_SIZE.x - 20.0
	free_label.color = Palette.CREAM
	list.add_child(free_label)
	free_label.set_text("GRATIS")
	free_label.position = tag - free_label.size * 0.5
	free_label.visible = false

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
	UIKit.juice(b, [art], 1.1)
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
	_money_shown = Game.money
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
			LOCK_BTN_W, 21)
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
		UIKit.juice(b, [holder], 1.08)
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
	el.bounds = TABLE_RECT
	el.opened.connect(_on_element_opened.bind(el))
	el.damaged.connect(_on_element_damaged.bind(el))
	el.perfect_hit.connect(_on_perfect_hit.bind(el))
	el.early_click.connect(_on_early_click.bind(el))
	el.landed.connect(_on_landed)
	_table.add_child(el)
	# La caida la lleva el elemento: asi se puede cortar si el jugador lo agarra
	# antes de que aterrice. Ver TableElement.play_drop().
	el.play_drop(rest)
	_refresh_top()


## El golpe de un objeto contra la mesa: un ruido sordo y la mesa tiembla un
## momento. Con la mesa restaurada caen muchos a la vez; el temblor se reinicia.
func _on_landed() -> void:
	Sound.play("sfx_open", -10.0, 0.55)
	_shake(1.0)


## La mesa tiembla. `k` es la fuerza: 1 es lo que tiembla al caer un objeto.
func _shake(k: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for off in [Vector2(0, 7), Vector2(-4, -3), Vector2(3, 2), Vector2.ZERO]:
		_shake_tween.tween_property(_table, "position", off * k, 0.04)


## Un instante de juego congelado (el "hitstop"): el golpe se siente como un
## golpe. Se vuelve a la velocidad normal con un reloj de tiempo REAL, que el de
## siempre tambien va a camara lenta.
func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(
			func() -> void: Engine.time_scale = 1.0)


## Un sobre roto a golpes: estalla en trozos, la mesa da un golpe y el jefe, ademas,
## congela el juego un instante.
func _on_pack_broken(el: TableElement) -> void:
	if not is_instance_valid(el) or _fx == null:
		return
	var color := Palette.GOLD_XL if el.golden else (Palette.RUST_L if el.boss else Palette.CREAM)
	_burst(el.global_position + TableElement.ART_CENTER, color, 40 if el.boss else 22)
	_shake(3.0 if el.boss else 1.6)
	if el.boss:
		_hitstop(0.12)


## Trozos que saltan de un punto y caen (en la capa de avisos, para que no se vayan
## con el sobre que se borra).
func _burst(at: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 620.0
	p.gravity = Vector2(0, 1400)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 8.0
	p.scale_amount_max = 16.0
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	_fx.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _drop_element(el: TableElement) -> void:
	_elements.erase(el)
	# El que se estaba trabajando suelta el turno al salir de la mesa: es lo que
	# deja empezar con otro (ver _on_open_requested).
	_worked.erase(el)
	_refresh_top()


# --------------------------------------------------------------------------- #
# La mesa guardada
# --------------------------------------------------------------------------- #

## La foto de la mesa para el guardado: cada sobre con la vida que le queda (y si
## lo trajo la GOLDEN RAIN). Tambien entra el objeto de la tarjeta abierta y los
## que esperan tarjeta: existen y no estan en ningun otro sitio del guardado (al
## volver se guardan en el inventario, ver _restore_table).
func _snapshot_table() -> Array:
	var out: Array = []
	for el in _elements:
		if not is_instance_valid(el):
			continue
		if el.boss:
			# El jefe es un evento con reloj: no vuelve con la mesa guardada (volveria
			# como un sobre normal con la vida de un jefe).
			continue
		out.append({"pack": str(el.pack.get("id", "cards")), "hp": maxf(1.0, el.hp),
				"rain": el.rain})
	if not _reveal_data.is_empty():
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
			var el := _spawn_pack(str(d["pack"]), bool(d.get("rain", false)))
			el.set_hp(float(d.get("hp", el.max_hp)))
		elif d.has("loot"):
			# Un objeto que se quedo a medio decidir (o, en un guardado de antes, que
			# estaba tirado en la mesa): la mesa ya no guarda objetos, asi que va al
			# inventario. Con el inventario lleno, store() lo vende y avisa.
			Game.store(d["loot"])


## La mesa se vacia sin cobrar nada: un rebirth o un reinicio (ver
## Game.table_reset). Los elementos salen de la lista EN EL ACTO, antes de que se
## borren de verdad, para que el guardado que viene detras ya no los vea y para
## que una venta o una apertura a medias no pueda pagar en la partida nueva (ver
## el guarda de _on_element_opened).
func _clear_table() -> void:
	for el in _elements:
		if is_instance_valid(el):
			el.queue_free()
	_elements.clear()
	_worked.clear()
	_reveal_queue.clear()
	_combo = 0
	_combo_left = 0.0
	_refresh_combo()
	_refresh_top()


## `rain`: comprado durante la GOLDEN RAIN (ver TableElement.rain). Va antes de
## meterlo en la mesa porque el brillo se monta al entrar.
func _spawn_pack(pack_id: String, rain: bool = false) -> TableElement:
	var el := TableElement.new()
	el.setup_pack(LootDB.pack_by_id(pack_id))
	el.rain = rain
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
	var cell := _pack_cell_of(pack_id)
	if not table_free():
		Sound.play("sfx_error")
		Game.notice.emit("MESA LLENA", Palette.RUST_L)
		UIKit.shake(cell.get("art"))
		return
	var price := Game.pack_price(pack_id)
	if not Game.can_afford(price):
		Sound.play("sfx_error")
		Game.notice.emit("NO TE LLEGA", Palette.RUST_L)
		UIKit.shake(cell.get("art"))
		return
	Game.spend(price)
	Game.note_pack_bought(pack_id, price)
	Sound.play("sfx_buy")
	UIKit.punch(cell.get("art"), 1.2)
	_spawn_pack(pack_id, Game.rain_left > 0.0)


## La celda de la columna de un sobre (para animarla al comprar o al fallar).
func _pack_cell_of(pack_id: String) -> Dictionary:
	for i in _pack_cells.size():
		if str(LootDB.pack_at(i)["id"]) == pack_id:
			return _pack_cells[i]
	return {}
	_refresh_packs()


func _on_element_opened(pack_id: String, el: TableElement) -> void:
	# Un sobre que ya no es de la mesa (se vacio con un rebirth mientras se rompia)
	# no da botin: era de la partida anterior.
	if not _elements.has(el):
		return
	_drop_element(el)
	Game.packs_opened += 1
	# EL COMBO: solo los sobres rotos a golpes, uno detras de otro.
	var mult := 1.0
	if el.broken_by_hit:
		_combo = _combo + 1 if _combo_left > 0.0 else 1
		_combo_left = _combo_window()
		mult = Gameplay.combo_mult(_combo)
		_refresh_combo()
		_on_pack_broken(el)
	var rolls := Gameplay.BOSS_LOOT if el.boss else 1
	var min_grade := Gameplay.GOLDEN_MIN_GRADE if el.golden \
			else (Gameplay.BOSS_MIN_GRADE if el.boss else 0)
	if el.golden:
		Game.mission_event("golden", 1)
	if el.boss:
		Sound.play("sfx_sell_all")
		_main().banner("JEFE DERROTADO", "%d OBJETOS CON NOTA %d O MAS" % [rolls, min_grade])
	Game.mission_event("open", 1, _pack_kind(pack_id))
	for i in rolls:
		# La suerte (Trebol) engorda el botin no comun y el multiplicador del Armario
		# sube el valor de lo que sale (y el combo, si lo hay).
		var item := LootDB.roll_pack(_rng, pack_id, Game.luck(), Game.value_multiplier() * mult)
		# EL SOBRE DORADO y EL JEFE traen la nota alta: se vuelve a tirar hasta
		# llegar al minimo (con la misma regla que la lupa del tasador, que escala
		# el valor).
		var vueltas := 0
		while int(item["grade"]) < min_grade and vueltas < 200:
			item = Game.regrade(item)
			vueltas += 1
		# LA GOLDEN RAIN: lo que sale de un sobre comprado en la lluvia puede salir
		# HOLO (brilla y vale el doble).
		if el.rain and _rng.randf() < Gameplay.RAIN_HOLO_CHANCE:
			item = Gameplay.make_holo(item)
		_deliver(item)


## Lo que se hace con un objeto recien salido de un sobre: la libreta y luego, en
## este orden, el auto guardar, la venta automatica, la venta sin ficha o la ficha.
##
## NADA SE QUEDA EN LA MESA. Antes lo que no tenia ficha caia en la mesa y se
## quedaba ahi hasta que alguien lo vendia (el "limbo"); ahora cada objeto acaba
## en el inventario o vendido en el momento, y en la mesa solo hay sobres.
func _deliver(item: Dictionary) -> void:
	# Encontrado es una cosa y guardado es otra: se apunta aqui, cuando sale,
	# porque a partir de este punto puede venderse sin pasar por el inventario.
	Game.register_found(item)
	# EL AUTO GUARDAR manda sobre todo lo demas: es el filtro que el jugador ha
	# elegido valor por valor (ver Game.autostore_wants).
	if Game.autostore_active():
		_autostore(item)
		return
	# La venta automatica de los ajustes: todo se vende sin pasar por la mesa.
	if Game.auto_sell:
		_sell_quietly(item)
		return
	# LA FICHA SOLO PARA LO QUE MERECE PARARSE (Ajustes > FICHA; en LO BUENO, lo
	# epico y lo legendario): lo demas se vende con un rotulo pequeño y la partida
	# no se para.
	if not Game.card_worth(item):
		_sell_with_label(item)
		return
	_reveal_item(item)


## El AUTO GUARDAR: lo que cumple el filtro va al inventario y lo demas se vende,
## los dos sin ficha. Con el inventario lleno, Game.store() lo vende y avisa: no
## hay otro sitio donde dejarlo.
func _autostore(item: Dictionary) -> void:
	if not Game.autostore_wants(item):
		_sell_quietly(item)
		return
	if Game.store(item):
		Sound.play("sfx_click")
		_float_label("GUARDADO" + (" HOLO" if Gameplay.is_holo(item) else ""),
				_table_point(), Palette.CREAM)
	else:
		Sound.play("sfx_sell")


## Un objeto que no merece ficha: se vende en el momento, con un rotulo que sube
## y se va (nombre, nota y precio) para que se sepa que ha salido.
func _sell_with_label(item: Dictionary) -> void:
	Sound.play("sfx_open")
	var value := Game.payout(item)
	Sound.play("sfx_sell")
	var at := _table_point()
	_float_label("%s%s  PSA %d" % ["HOLO " if Gameplay.is_holo(item) else "",
			str(item.get("name", "")), int(item.get("grade", 0))], at, Palette.CREAM)
	_float_text("+" + PixelNumber.format(value), at + Vector2(0, 40), Palette.GOLD_XL)


## Un rotulo de texto que sube y se desvanece (el de _float_text es de cifras).
func _float_label(text: String, at: Vector2, color: Color) -> void:
	if _fx == null:
		return
	var l := UIKit.label_at(text, at, Vector2(420, 32), 21, color,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 70.0, 1.3).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.9)
	tw.chain().tween_callback(l.queue_free)


## Venta automatica: el objeto se vende nada mas salir, sin tarjeta y sin mesa.
func _sell_quietly(item: Dictionary) -> void:
	var value := Game.payout(item)
	Sound.play("sfx_sell")
	_float_text("+" + PixelNumber.format(value), _table_point(), Palette.GOLD_XL)


func _reveal_item(item: Dictionary) -> void:
	# Con una tarjeta abierta, este espera su turno (ver _reveal_queue).
	if _reveal != null:
		_reveal_queue.append(item)
		return
	# Primero el sonido de que se ha abierto; el del premio lo pone la ficha cuando
	# se ensena, al final del suspense (ver RevealCard._reveal_now).
	Sound.play("sfx_open")

	# El objeto NO va a la mesa: la tarjeta solo se cierra eligiendo GUARDAR o
	# VENDER (ver RevealCard), asi que no hay un "luego" en el que dejarlo tirado.
	var card := REVEAL_SCENE.instantiate() as RevealCard
	card.show_item(item)
	card.resolved.connect(_on_reveal_resolved.bind(item))
	_reveal = card
	_reveal_data = item
	_main().push_overlay(card)


## Que hacer con el objeto cuando se cierra la tarjeta: GUARDAR o VENDER.
func _on_reveal_resolved(action: String, item: Dictionary) -> void:
	if _reveal != null:
		_main().pop_overlay(_reveal)
		_reveal = null
	_reveal_data = {}
	if action == RevealCard.ACTION_SELL:
		_sell_revealed(item)
	else:
		_store_revealed(item)
	# Y la siguiente que estuviera esperando.
	if not _reveal_queue.is_empty():
		_reveal_item(_reveal_queue.pop_front())


## Al inventario.
func _store_revealed(item: Dictionary) -> void:
	var stored := Game.store(item)
	# store() ya vende y avisa solo cuando el inventario esta lleno; el sonido lo
	# pone aqui para que se oiga igual que las demas ventas.
	Sound.play("sfx_click" if stored else "sfx_sell")


func _sell_revealed(item: Dictionary) -> void:
	var value := Game.payout(item)
	Sound.play("sfx_sell")
	_float_text("+" + PixelNumber.format(value), TABLE_RECT.get_center(), Palette.GOLD_XL)


## Un sobre que se va de la mesa sin abrirse (el dorado que nadie golpeo, el jefe
## que se escapo).
func _remove_from_table(el: TableElement) -> void:
	if el == null or not is_instance_valid(el):
		return
	_drop_element(el)
	el.queue_free()
	_refresh_top()


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


# --------------------------------------------------------------------------- #
# Automatizaciones
# --------------------------------------------------------------------------- #

func _process(delta: float) -> void:
	_refresh_event_band()
	_refresh_abilities()
	if _reveal != null:
		return
	_golden_step(delta)
	_boss_step(delta)
	_combo_step(delta)
	_frenzy_step()
	if _table_clear():
		_events_step(delta)
	if Game.auto_buy:
		_buy_timer -= delta
		if _buy_timer <= 0.0:
			_buy_timer = Game.auto_buy_interval()
			_auto_buy_step()
	_spike_step(delta)
	_auto_items_step(delta)


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
		if is_instance_valid(el):
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
			or _reveal != null or _rebirth != null or _settings != null or _libreta != null:
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
	Game.note_pack_bought(best, best_price)
	_spawn_pack(best, Game.rain_left > 0.0)
	_refresh_packs()


## LA COMPRA AUTOMATICA DE LA TIENDA (nodos APRENDIZ, AMULETO y ENCARGADO): cada
## AUTO_ITEMS_EVERY segundos sube un nivel del item MAS BARATO de los que tienen
## el AUTO puesto, si llega el dinero (ver Game.auto_item_pick). Con el rebirth
## abierto no, por lo mismo que la compra de sobres: alli se decide con el
## dinero que hay. Con la tienda abierta si: se ve subir el nivel en la caja.
func _auto_items_step(delta: float) -> void:
	_items_timer -= delta
	if _items_timer > 0.0:
		return
	_items_timer = AUTO_ITEMS_EVERY
	if _rebirth != null or _settings != null:
		return
	var i := Game.auto_item_pick()
	if i < 0 or not Game.can_afford(Game.item_cost(i)):
		return
	if not Game.buy_item(i):
		return
	Sound.play("sfx_tool", -8.0)
	_float_label("AUTO: %s NV %d" % [str(LootDB.item_at(i)["name"]), Game.item_level(i)],
			Vector2(1400, 120), Palette.GOLD_XL)


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
		# El contador da un salto cuando entra dinero: es lo que se mira al vender.
		if value > _money_shown:
			UIKit.punch(_money, 1.15)
		_money_shown = value
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
		var rotulo: Control = cell["free"]
		num.visible = not free
		rotulo.visible = free
		if free:
			continue
		# recolor() y no `color =`: con las mismas cifras set_number() no repinta,
		# y el precio se quedaba gris aun llegandote el dinero.
		num.recolor(Palette.CREAM if affordable else Palette.PRICE_OFF)
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
		var dibujo := UIKit.fit_art(str(item.get("art", "loot_vinyl")),
				Vector2(LOCK_SIDE * 0.5, LOCK_SIDE * 0.5 - 8.0),
				Vector2(LOCK_SIDE * 0.62, LOCK_SIDE * 0.62))
		# Un objeto HOLO (GOLDEN RAIN) brilla tambien aqui.
		if Gameplay.is_holo(item):
			UIKit.holo(dibujo)
		holder.add_child(dibujo)
		# A 0,22 y no a 0,15: a 0,15 la cifra media 11 px y no se leia desde la
		# silla. Un poco mas abajo que antes para no tocar el dibujo.
		var num := PixelNumber.new()
		num.scale_factor = 0.22
		num.max_width = LOCK_SIDE - 12.0
		holder.add_child(num)
		num.set_number(int(item.get("value", 0)))
		num.position = Vector2(LOCK_SIDE * 0.5, LOCK_SIDE - 22.0) - num.size * 0.5
		b.tooltip_text = "Armario: %s expuesto" % str(item.get("name", ""))


# --------------------------------------------------------------------------- #
# El gameplay nuevo: eventos, golpe perfecto, habilidades y libreta
# --------------------------------------------------------------------------- #

## El tipo de un sobre (cards2 -> cards): lo que cuentan los encargos.
static func _pack_kind(pack_id: String) -> String:
	return pack_id.rstrip("0123456789")


## Los relojes que hacen aparecer los eventos. Solo corren con la mesa a la vista.
func _events_step(delta: float) -> void:
	_golden_timer -= delta
	if _golden_timer <= 0.0:
		_golden_timer = Gameplay.between(_rng, Gameplay.GOLDEN_EVERY) \
				/ (1.0 + Game.skill_bonus("golden"))
		spawn_golden()
	_boss_timer -= delta
	if _boss_timer <= 0.0:
		_boss_timer = Gameplay.between(_rng, Gameplay.BOSS_EVERY)
		spawn_boss()
	_vip_timer -= delta
	if _vip_timer <= 0.0:
		_vip_timer = Gameplay.between(_rng, Gameplay.VIP_EVERY)
		if Game.buyer.is_empty():
			Game.start_buyer()
			Sound.play("sfx_rare")
			_main().banner("COMPRADOR VIP  %s" % Gameplay.mult_text(Game.vip_mult()),
					event_texts()[0].split("  -  ")[0].get_slice(": ", 1))
	_happy_timer -= delta
	if _happy_timer <= 0.0:
		_happy_timer = Gameplay.between(_rng, Gameplay.HAPPY_EVERY)
		if Game.happy.is_empty():
			Game.start_happy()
			Sound.play("sfx_rare")
			_main().banner("HORA FELIZ  %s" % Gameplay.mult_text(Gameplay.HAPPY_MULT),
					event_texts()[-1].split("  -  ")[0].get_slice(": ", 1))


## Pone un SOBRE DORADO en la mesa (si cabe). Devuelve el elemento o null.
func spawn_golden() -> TableElement:
	if not table_free():
		return null
	var el := TableElement.new()
	el.setup_pack(LootDB.pack_by_id(Game.golden_pack_id()))
	el.setup_golden()
	_add_element(el)
	Sound.play("sfx_rare")
	_main().banner("SOBRE DORADO", "ABRELO ANTES DE QUE SE VAYA")
	return el


## El reloj de los sobres dorados que nadie ha empezado: parpadean los ultimos
## tres segundos y despues se van sin dar nada.
func _golden_step(delta: float) -> void:
	for el in _elements.duplicate():
		if not is_instance_valid(el) or not el.golden:
			continue
		if el.started():
			el.golden_tick()
			continue
		el.golden_left -= delta
		el.golden_tick()
		if el.golden_left <= 3.0:
			el.modulate.a = 0.45 if int(el.golden_left * 6.0) % 2 == 0 else 1.0
		if el.golden_left <= 0.0:
			_remove_from_table(el)


## El FRENESI: mientras dura, todos los sobres quietos de la mesa se empiezan a
## golpear solos (sin el cupo del turno: es la gracia de la habilidad).
func _frenzy_step() -> void:
	if Game.frenzy_left <= 0.0:
		return
	for el in _elements:
		if is_instance_valid(el) and el.can_open():
			el.start_opening()


## Un golpe perfecto: el rotulo con lo que ha multiplicado, un sonido que sube de
## tono con la racha y un temblor (mas fuerte en la zona dorada). La cuenta de
## perfectos la lleva Game.note_perfect().
func _on_perfect_hit(sweet: bool, mult: float, el: TableElement) -> void:
	Game.mission_event("perfect", 1)
	Sound.play("sfx_tool", -4.0, minf(2.2, 1.0 + 0.09 * float(Game.streak)))
	if sweet:
		Sound.play("sfx_rare", -6.0, 1.5)
		_shake(1.8)
		_hitstop(0.05)
	else:
		_shake(0.8)
	if not is_instance_valid(el) or _fx == null:
		return
	var at: Vector2 = el.global_position + Vector2(TableElement.BOX.x * 0.5, 40.0)
	var texto := ("DORADO! " if sweet else "PERFECTO! ") + Gameplay.mult_text(snappedf(mult, 0.1))
	var l := UIKit.label_at(texto, at, Vector2(300, 40), 35 if sweet else 28,
			Palette.GOLD_HI if sweet else Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(l)
	UIKit.punch(l, 1.35 if sweet else 1.15)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


## Se ha pulsado antes de tiempo: el anillo ha perdido un trozo y la racha se ha ido.
func _on_early_click(el: TableElement) -> void:
	Sound.play("sfx_error", -10.0, 1.3)
	if is_instance_valid(el):
		_float_label("PRONTO", el.global_position + Vector2(TableElement.BOX.x * 0.5, 40.0),
				Palette.RUST_L)


# --- la racha y el combo --------------------------------------------------------- #

## Los dos contadores de arriba de la mesa: la RACHA de perfectos (con lo que
## multiplica) y el COMBO de apertura (con lo que sube el botin y una barra que se
## vacia con el tiempo que queda para encadenar el siguiente).
func _build_hud() -> void:
	var y := TABLE_RECT.position.y + 26.0
	_streak_label = UIKit.label_at("", Vector2(TABLE_RECT.position.x + 230.0, y),
			Vector2(400, 36), 28, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0)
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_streak_label)
	_combo_label = UIKit.label_at("", Vector2(TABLE_RECT.end.x - 230.0, y),
			Vector2(400, 36), 28, Palette.TEAL_L, HORIZONTAL_ALIGNMENT_CENTER, 0)
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo_label)
	_combo_bar = ColorRect.new()
	_combo_bar.color = Palette.TEAL_L
	_combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_bar.position = Vector2(TABLE_RECT.end.x - 330.0, y + 22.0)
	_combo_bar.size = Vector2(200, 6)
	add_child(_combo_bar)
	Game.streak_changed.connect(_on_streak_changed)
	_on_streak_changed(Game.streak)
	_refresh_combo()


func _on_streak_changed(streak: int) -> void:
	if _streak_label == null:
		return
	var antes := _streak_label.visible
	_streak_label.visible = streak >= 2
	if streak >= 2:
		_streak_label.text = "RACHA %d  %s" % [streak,
				Gameplay.mult_text(snappedf(Gameplay.streak_mult(streak,
						Game.skill_bonus("streak")), 0.01))]
		UIKit.punch(_streak_label, 1.2)
	elif antes:
		# Se ha roto con algo de racha: que se note que se ha perdido.
		_float_label("RACHA ROTA", _streak_label.position + _streak_label.size * 0.5,
				Palette.RUST_L)


## El reloj del combo: si se acaba sin romper otro sobre, el combo vuelve a cero.
func _combo_step(delta: float) -> void:
	if _combo_left <= 0.0:
		return
	_combo_left -= delta
	if _combo_left <= 0.0:
		_combo = 0
		_refresh_combo()
		return
	_combo_bar.size.x = 200.0 * _combo_left / _combo_window()


func _refresh_combo() -> void:
	if _combo_label == null:
		return
	var hay := _combo >= 2
	_combo_label.visible = hay
	_combo_bar.visible = hay
	if hay:
		_combo_label.text = "COMBO %d  +%d %%" % [_combo,
				roundi((Gameplay.combo_mult(_combo) - 1.0) * 100.0)]
		_combo_bar.size.x = 200.0 * _combo_left / _combo_window()
		UIKit.punch(_combo_label, 1.15)


# --- el jefe ------------------------------------------------------------------- #

## Pone un JEFE en la mesa (si cabe): el sobre del dorado con la vida de
## Gameplay.BOSS_HITS golpes tuyos. Devuelve el elemento o null.
func spawn_boss() -> TableElement:
	if not table_free():
		return null
	var el := TableElement.new()
	el.setup_pack(LootDB.pack_by_id(Game.golden_pack_id()))
	var vida := Gameplay.BOSS_LIFE * (1.0 + Game.skill_bonus("boss"))
	el.setup_boss(Game.damage_per_hit() * Gameplay.BOSS_HITS, vida)
	_add_element(el)
	Sound.play("sfx_rare", 0.0, 0.6)
	_shake(2.5)
	_main().banner("JEFE DE SOBRE", "ROMPELO EN %d S" % roundi(vida))
	return el


## El reloj del jefe corre desde que aparece; si llega a cero se va sin dar nada.
func _boss_step(delta: float) -> void:
	for el in _elements.duplicate():
		if not is_instance_valid(el) or not el.boss:
			continue
		el.boss_left -= delta
		el.boss_tick()
		if el.boss_left <= 0.0 and not el.is_busy():
			Sound.play("sfx_error")
			Game.notice.emit("EL JEFE SE HA ESCAPADO", Palette.RUST_L)
			_remove_from_table(el)


# --- la banda de los eventos --------------------------------------------------- #

func _build_event_band() -> void:
	_event_band = Control.new()
	_event_band.name = "EventBand"
	_event_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_event_band)
	for i in 2:
		var back := ColorRect.new()
		back.color = Color(0.02, 0.015, 0.04, 0.82)
		back.position = Vector2(TABLE_RECT.position.x + 16,
				EVENT_BAND_BOTTOM - float(i + 1) * EVENT_LINE_H)
		back.size = Vector2(TABLE_RECT.size.x - 32, EVENT_LINE_H - 4)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_event_band.add_child(back)
		var l := UIKit.label_at("", back.position + back.size * 0.5,
				back.size - Vector2(24, 0), 21, Palette.GOLD_XL,
				HORIZONTAL_ALIGNMENT_CENTER, 0)
		_event_band.add_child(l)
		_event_lines.append({"back": back, "label": l})
	_refresh_event_band()


## Una linea por evento en curso, con lo que pide y los segundos que le quedan.
func event_texts() -> Array:
	var out: Array = []
	if not Game.buyer.is_empty():
		out.append("COMPRADOR VIP: %s CON NOTA %d O MAS PAGA %s  -  %d S" % [
			str(LootDB.kind_row(str(Game.buyer["kind"]))["name"]),
			int(Game.buyer["grade"]), Gameplay.mult_text(Game.vip_mult()),
			ceili(float(Game.buyer["left"]))])
	if not Game.happy.is_empty():
		out.append("HORA FELIZ: LOS OBJETOS DE %s VALEN %s  -  %d S" % [
			str(LootDB.kind_row(str(Game.happy["kind"]))["name"]),
			Gameplay.mult_text(Gameplay.HAPPY_MULT), ceili(float(Game.happy["left"]))])
	return out


func _refresh_event_band() -> void:
	if _event_lines.is_empty():
		return
	var textos := event_texts()
	for i in _event_lines.size():
		var linea: Dictionary = _event_lines[i]
		var hay := i < textos.size()
		(linea["back"] as ColorRect).visible = hay
		(linea["label"] as Label).visible = hay
		if hay and (linea["label"] as Label).text != textos[i]:
			(linea["label"] as Label).text = textos[i]


# --- la barra de habilidades --------------------------------------------------- #

func _build_abilities() -> void:
	for i in Gameplay.ABILITIES.size():
		var a: Dictionary = Gameplay.ABILITIES[i]
		var centro := Vector2(ABIL_X0 + float(i) * ABIL_STEP, ABIL_Y)
		var b := UIKit.icon_button(str(a["art"]), centro, ABIL_SIDE,
				"%s (tecla %d): %s" % [str(a["name"]).capitalize(), i + 1,
					str(a["desc"]).to_lower()])
		b.pressed.connect(_use_ability.bind(str(a["id"])))
		add_child(b)
		var num := PixelNumber.new()
		num.scale_factor = 0.30
		num.max_width = ABIL_SIDE - 8.0
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(num)
		_abil_buttons.append({"id": str(a["id"]), "button": b, "num": num,
			"center": centro})
	_refresh_abilities()


func _use_ability(id: String) -> void:
	if not Game.ability_unlocked(id):
		Sound.play("sfx_error")
		Game.notice.emit("SE DESBLOQUEA EN EL ARBOL DEL REBIRTH", Palette.RUST_L)
		return
	if not Game.use_ability(id):
		Sound.play("sfx_error")
		Game.notice.emit("TODAVIA SE ESTA RECARGANDO", Palette.RUST_L)
		return
	Sound.play("sfx_tool")
	for a in _abil_buttons:
		if str(a["id"]) == id:
			UIKit.punch(a["button"], 1.25)
	if id == Gameplay.ABIL_FRENZY:
		_main().banner("FRENESI!", "TODOS LOS SOBRES SE GOLPEAN SOLOS %d S" % int(Gameplay.FRENZY_TIME))
	elif id == Gameplay.ABIL_RAIN:
		_main().banner("GOLDEN RAIN!", "%d S: LOS SOBRES QUE COMPRES PUEDEN SALIR HOLO"
				% int(Game.rain_left))
	else:
		Game.notice.emit(str(Gameplay.ability(id)["name"]) + "!", Palette.GOLD_XL)


## Cada boton: apagado si no se tiene o si recarga (con los segundos encima) y
## encendido mientras el golpe cargado espera o el frenesi dura.
func _refresh_abilities() -> void:
	for a in _abil_buttons:
		var id := str(a["id"])
		var b: Button = a["button"]
		var num: PixelNumber = a["num"]
		if not is_instance_valid(b):
			continue
		var tiene := Game.ability_unlocked(id)
		var listo := Game.ability_ready(id)
		UIKit.dim_icon_button(b, not listo)
		var activo := (id == Gameplay.ABIL_CHARGE and Game.charged_next) \
				or (id == Gameplay.ABIL_FRENZY and Game.frenzy_left > 0.0) \
				or (id == Gameplay.ABIL_RAIN and Game.rain_left > 0.0)
		UIKit.set_icon_button_lit(b, activo)
		var falta := ceili(Game.ability_left(id)) if tiene and not listo else 0
		num.visible = falta > 0
		if falta > 0:
			num.set_number(falta)
			num.position = (a["center"] as Vector2) - num.size * 0.5


# --- la libreta ----------------------------------------------------------------- #

func _build_libreta_button() -> void:
	var b := UIKit.small_button("LIBRETA", "", LIBRETA_BTN_CENTER, LIBRETA_BTN_W, 21)
	b.tooltip_text = "Libreta: el album de colecciones y los encargos"
	b.pressed.connect(_open_libreta)
	add_child(b)


func _open_libreta() -> void:
	if _libreta != null:
		return
	Sound.click()
	_libreta = LIBRETA_SCENE.instantiate()
	_libreta.closed.connect(_close_libreta)
	_main().push_veil(_libreta)


func _close_libreta() -> void:
	if _libreta != null:
		_main().pop_veil(_libreta)
		_libreta = null


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


## Los atajos de teclado (van siempre, ya no se compran): T la tienda, A el armario, R el rebirth y V
## vende la mesa. Todo lo que estaba a un viaje de raton a la barra. 1, 2 y 3
## usan las habilidades.
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
	var code := key.keycode if key.keycode != 0 else key.physical_keycode
	# Las habilidades van con 1, 2 y 3 SIEMPRE (no son de la mejora de atajos:
	# son botones que se pulsan en mitad de la accion).
	if _table_clear():
		var n := [KEY_1, KEY_2, KEY_3].find(code)
		if n >= 0 and n < Gameplay.ABILITIES.size():
			_use_ability(str(Gameplay.ABILITIES[n]["id"]))
			return true
	if not _table_clear():
		return false
	match code:
		KEY_T:
			_open_shop()
		KEY_A:
			_open_locker()
		KEY_R:
			_open_rebirth()
		_:
			return false
	return true


## Lo que aguanta el combo entre sobre y sobre, con el nodo COMBO del arbol.
func _combo_window() -> float:
	return Gameplay.COMBO_WINDOW * (1.0 + Game.skill_bonus("combo"))


## ¿No hay nada abierto encima de la mesa? Es la condicion de los atajos.
func _table_clear() -> bool:
	return _reveal == null and _settings == null and _locker == null \
			and _shop == null and _rebirth == null and _auto_buy_panel == null \
			and _libreta == null


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
	elif _libreta != null:
		_close_libreta()
	elif _auto_buy_panel != null:
		_close_auto_buy()
	elif _shop != null:
		_close_shop()
	else:
		Game.save_game()
		_main().show_menu()
	get_viewport().set_input_as_handled()
