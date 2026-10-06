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

## Huecos de mesa de base. Los amplia el Cajon (ver Game.table_slots()).
const INV_X0 := 660.0
const INV_STEP := 132.0
const INV_Y := 1000.0
const INV_SIDE := 128.0

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

## Cuantos puntos al azar se prueban para colocar un objeto nuevo. Ver _free_spot().
const SPOT_TRIES := 40

## Cada cuanto se aplica el dano de los Pinchos a la mesa (segundos).
const SPIKE_TICK := 0.25

var _table: Control
var _fx: Control
var _money: PixelNumber
var _table_label: Label
var _inv_label: Label
var _inv_slots: Array = []
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
var _reveal: RevealCard = null
var _auto_open_btn: Button = null
var _auto_buy_btn: Button = null
var _sell_btn: Button = null
var _rng := RandomNumberGenerator.new()

## Los paquetes que el jugador ha empezado a abrir y que siguen en la mesa.
##
## Es el "turno": el paquete que se empieza NO se suelta hasta que se rompe o
## sale de la mesa, y los Guantes amplian cuantos caben aqui a la vez. Un clic
## arranca un solo paquete (el pulsado), no varios: ver _on_open_requested().
var _worked: Array = []

var _buy_timer := 0.0
var _spike_timer := 0.0


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
	_build_inventory()

	Game.money_changed.connect(_on_money_changed)
	Game.inventory_changed.connect(_refresh_inventory)
	Game.items_changed.connect(_refresh_top)
	Game.open_requested.connect(_on_open_requested)
	Game.settings_changed.connect(_refresh_top)
	_refresh_inventory()
	_refresh_top()
	_on_money_changed(Game.money)


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
	price.set_number(int(pack["price"]))
	price.position = tag - price.size * 0.5
	# GRATIS al mismo tamano que los numeros (35 de fuente son 35 px de tinta,
	# frente a los 40 del numero): es un rotulo corto, y a 28 se leia mas pequeno
	# que los precios de al lado.
	var free_label := UIKit.label_at("GRATIS", tag,
			PACK_TAG_SIZE - Vector2(24, 4), 35, Palette.GOLD_XL,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true)
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
	_money.max_width = 470.0
	add_child(_money)
	_money.set_number(Game.money)
	# El contador se ancla por su IZQUIERDA, no por su centro: si no, cuando el
	# numero crece se sale por la pantalla en vez de empujar lo de al lado.
	_money.position = Vector2(128, 58 - _money.size.y * 0.5)	# Las cajas van anchas a proposito: label_at agranda la caja si el texto no
	# cabe y la centra, asi que una caja corta ("MESA 3/8" son 224 px en una de
	# 190) deslocaba el texto a la izquierda y lo pegaba al contador.
	_table_label = UIKit.label_at("", Vector2(690, 58), Vector2(250, 50), 28,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0)
	add_child(_table_label)
	# El rotulo del dano por golpe que habia aqui ("DANO 12") se ha quitado: es
	# un numero que se mira una vez y ocupa la franja de arriba, que es lo unico
	# que hay a la vista cuando la mesa esta llena.

	# El tooltip dice CON QUE PIEZA se enciende cada uno: son las dos unicas cosas
	# de la barra que no se pueden usar sin comprar algo antes, y el que mira el
	# boton apagado es justo el que necesita saber cual de las dos le falta.
	_auto_open_btn = UIKit.icon_button("ui_icon_auto_open", Vector2(1050, 58), 80.0,
			"Apertura automatica (con los Pinchos): abre sola los paquetes de la mesa")
	_auto_open_btn.pressed.connect(_toggle_auto_open)
	add_child(_auto_open_btn)

	_auto_buy_btn = UIKit.icon_button("ui_icon_auto_buy", Vector2(1145, 58), 80.0,
			"Compra automatica (con el PC): elige que sobres se compran solos")
	_auto_buy_btn.pressed.connect(_open_auto_buy)
	add_child(_auto_buy_btn)

	_sell_btn = UIKit.small_button("VENDER", "", Vector2(1350, 58), 240, 21,
			"ui_button_sell", "ui_button_sell")
	_sell_btn.pressed.connect(_sell_all_table)
	add_child(_sell_btn)

	var shop := UIKit.small_button("TIENDA", "ui_icon_shop", Vector2(1630, 58), 288, 32)
	shop.pressed.connect(_open_shop)
	add_child(shop)

	var settings := UIKit.icon_button("ui_icon_settings", Vector2(1856, 58), 80.0,
			"Ajustes")
	settings.pressed.connect(_open_settings)
	add_child(settings)


func _build_inventory() -> void:
	var sell_all := UIKit.small_button("VENDER TODO", "", Vector2(210, INV_Y), 384, 28,
		"ui_button_sell", "ui_button_sell")
	sell_all.pressed.connect(_sell_inventory)
	add_child(sell_all)

	# El rotulo va sobre su fila de huecos, no encima de la chapa de VENDER TODO.
	# Con el centro en (470, 928) la caja empezaba en x 270 y la chapa llega a
	# x 402: el texto se leia a la mitad, cortado por el marco de la chapa.
	# Y a y 918, no a 912: la linea de las baldas pasa por y 900..903 y a 912 la
	# cruzaba por arriba de las letras. Entre la linea (903) y los huecos (936)
	# quedan 33 px, y el rotulo mide 24.
	_inv_label = UIKit.label_at("", Vector2(800, 918), Vector2(400, 44), 26,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0)
	add_child(_inv_label)

	for i in Game.INVENTORY_SLOTS:
		var holder := UIKit.slot(Vector2(INV_X0 + float(i) * INV_STEP, INV_Y), INV_SIDE)
		add_child(holder)
		_inv_slots.append(holder)


# --------------------------------------------------------------------------- #
# La mesa
# --------------------------------------------------------------------------- #

## Un sitio libre para un objeto nuevo, dentro de la mesa.
##
## Se prueban SPOT_TRIES puntos al azar y se elige el que menos pisa a los que
## ya hay. Con eso salen repartidos solos y solo se solapan cuando de verdad no
## cabe otro, que es cuando el jugador los separa arrastrando: para eso se
## pueden mover. Sorteando a pelo, con ocho objetos de 300x340 en una mesa de
## 1344x752 la mitad caerian uno encima de otro desde el primer minuto.
func _free_spot() -> Vector2:
	var x0 := TABLE_RECT.position.x
	var y0 := TABLE_RECT.position.y
	var x1 := x0 + TABLE_RECT.size.x - TableElement.BOX.x
	var y1 := y0 + TABLE_RECT.size.y - TableElement.BOX.y
	var best := Vector2(x0, y0)
	var best_score := -1.0
	for i in SPOT_TRIES:
		var p := Vector2(_rng.randf_range(x0, x1), _rng.randf_range(y0, y1))
		var mine := Rect2(p, TableElement.BOX)
		var score := 0.0
		for el in _elements:
			if is_instance_valid(el):
				score += _overlap(mine, Rect2(el.position, TableElement.BOX))
		if best_score < 0.0 or score < best_score:
			best_score = score
			best = p
		if score <= 0.0:
			break
	return best


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
	el.sold.connect(_on_element_sold.bind(el))
	_table.add_child(el)
	# La caida la lleva el elemento: asi se puede cortar si el jugador lo agarra
	# antes de que aterrice. Ver TableElement.play_drop().
	el.play_drop(rest)
	_refresh_top()


func _drop_element(el: TableElement) -> void:
	_elements.erase(el)
	# El que se estaba trabajando suelta el turno al salir de la mesa: es lo que
	# deja empezar con otro (ver _on_open_requested).
	_worked.erase(el)
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
	_drop_element(el)
	Game.packs_opened += 1
	# La suerte (Trebol) engorda el botin no comun y el multiplicador del Armario
	# sube el valor de lo que sale.
	var item := LootDB.roll_pack(_rng, pack_id, Game.luck(), Game.value_multiplier())
	# Encontrado es una cosa y guardado es otra: se apunta aqui, cuando sale,
	# porque a partir de este punto puede venderse sin pasar por el inventario.
	Game.register_found(item)
	if Game.auto_sell:
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
	_main().push_overlay(card)


## Que hacer con el objeto cuando se cierra la tarjeta.
func _on_reveal_resolved(action: String, item: Dictionary, el: TableElement) -> void:
	if _reveal != null:
		_main().pop_overlay(_reveal)
		_reveal = null
	if action == RevealCard.ACTION_STORE:
		_store_revealed(item, el)
	elif action == RevealCard.ACTION_SELL:
		_sell_revealed(item, el)
	elif el == null:
		# Cerrada sin elegir y sin sitio en la mesa: se guarda, que es lo unico
		# que no pierde el objeto. Con sitio, se queda en la mesa y ya esta.
		_store_revealed(item, null)


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
		# nada: el dinero lo lleva siempre _sell_revealed.
		value = el.sell_instant()
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
	_drop_element(el)
	Game.add_money(value)
	Sound.play("sfx_sell")
	_float_text("+" + PixelNumber.format(value), at, Palette.GOLD_XL)


func _sell_all_table() -> void:
	var total := 0
	# Se suelta uno a uno con _drop_element() en vez de vaciar la lista de golpe:
	# asi un paquete que se estuviera abriendo deja libre su hueco en el turno, que
	# si no se queda ocupado por un elemento que ya no esta (ver _on_open_requested).
	for el in _elements.duplicate():
		if is_instance_valid(el):
			total += el.sell_instant()
		_drop_element(el)
	if total > 0:
		Game.add_money(total)
		Sound.play("sfx_sell_all")
		_float_text("+" + PixelNumber.format(total), Vector2(960, 500), Palette.GOLD_XL)
	_refresh_top()


func _sell_inventory() -> void:
	var total := Game.inventory_value()
	if total <= 0:
		Sound.play("sfx_error")
		Game.notice.emit("NO HAY NADA QUE VENDER", Palette.CREAM_D)
		return
	Game.sell_all()
	Sound.play("sfx_sell_all")
	_float_text("+" + PixelNumber.format(total), Vector2(960, 960), Palette.GOLD_XL)


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


## Los Pinchos: con la apertura automatica ENCENDIDA danan solos todos los
## paquetes de la mesa, sin que se les haga clic.
##
## Los Pinchos no van por su cuenta. Son la pieza que hace falta para poder
## encender la apertura automatica (ver LootDB.AUTO_ITEM_OPEN), y encenderla es
## lo que los pone a golpear: el jugador compra la pieza y le da al interruptor.
## Apagada, no hacen nada -la mesa se abre a clics, como siempre-, y por eso el
## dano se aplica AQUI y no en el propio item.
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
	var amount := dps * _spike_timer
	_spike_timer = 0.0
	for el in _elements:
		if is_instance_valid(el) and not el.is_loot():
			el.take_damage(amount)


## Un paquete ha pedido abrirse (el jugador le ha hecho clic).
##
## UN CLIC ES UN PAQUETE, y solo el pulsado: aqui no se arranca ninguno de
## propina. Lo que hacen los Guantes es subir cuantos paquetes se pueden llevar
## A LA VEZ (Game.open_count(): 1 sin ellos, 3 al nivel 1, 5 al 2...), que es
## otra cosa: con Guantes el jugador tiene que ir pulsando uno y otro para que
## avancen los tres, y machacar el mismo no adelanta mas que el suyo.
##
## El "turno" de cada paquete empezado no se suelta hasta que se rompe o sale de
## la mesa (ver _drop_element()), asi que los Guantes se notan en CUANTOS caben,
## no en cuantas veces hay que pulsar.
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
			Game.notice.emit("SIN GUANTES: DE UNO EN UNO" if hueco <= 1
					else "YA LLEVAS %d A LA VEZ" % hueco, Palette.RUST_L)
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
	if not table_free() or _shop != null or _auto_buy_panel != null or _reveal != null:
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
	# Los sobres de la izquierda se apagan cuando no te llega su precio, asi que
	# cualquier cambio de dinero los tiene que repintar.
	_refresh_packs()


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
		# El numero cambia de ancho al apagarse o al crecer: se vuelve a centrar.
		num.position = (cell["tag"] as Vector2) - num.size * 0.5


func _refresh_top() -> void:
	if is_instance_valid(_table_label):
		_table_label.text = "MESA %d/%d" % [table_count(), Game.table_slots()]
	# Cada boton de automatizacion se pinta bloqueado por SU pieza: el de abrir
	# espera a los Pinchos y el de comprar al PC. Apagado se ve que aun no sirve, y
	# el clic sigue llegando para poder decir cual falta (ver _locked_notice()).
	if is_instance_valid(_auto_open_btn):
		UIKit.set_icon_button_lit(_auto_open_btn, Game.auto_open)
		UIKit.dim_icon_button(_auto_open_btn, not Game.auto_open_unlocked())
	if is_instance_valid(_auto_buy_btn):
		UIKit.set_icon_button_lit(_auto_buy_btn, Game.auto_buy)
		UIKit.dim_icon_button(_auto_buy_btn, not Game.auto_buy_unlocked())
	if is_instance_valid(_sell_btn):
		_sell_btn.disabled = _count_table_loot() == 0


func _refresh_inventory() -> void:
	if is_instance_valid(_inv_label):
		_inv_label.text = "INVENTARIO %d/%d" % [Game.inventory.size(), Game.INVENTORY_SLOTS]
	for i in _inv_slots.size():
		var holder: Control = _inv_slots[i]
		for c in holder.get_children():
			if c.name != "Back":
				c.queue_free()
		if i >= Game.inventory.size():
			continue
		var item: Dictionary = Game.inventory[i]
		holder.add_child(UIKit.square(str(item.get("art", "loot_vinyl")),
				Vector2(INV_SIDE * 0.5, INV_SIDE * 0.5 - 8.0), 0.16))
		var num := PixelNumber.new()
		num.scale_factor = 0.15
		num.max_width = INV_SIDE - 12.0
		holder.add_child(num)
		num.set_number(int(item.get("value", 0)))
		num.position = Vector2(INV_SIDE * 0.5, INV_SIDE - 26.0) - num.size * 0.5
		var value := int(item.get("value", 0))
		UIKit.hit_area(holder, Rect2(Vector2.ZERO, Vector2(INV_SIDE, INV_SIDE)),
				"Vender por " + PixelNumber.format(value)).pressed.connect(
				_sell_inventory_slot.bind(i))


func _sell_inventory_slot(index: int) -> void:
	var got := Game.sell_at(index)
	if got > 0:
		Sound.play("sfx_sell")
		_float_text("+" + PixelNumber.format(got), Vector2(960, 960), Palette.GOLD_XL)


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


## "2.10" -> "2.1"
static func _trim(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _reveal != null:
		return
	if _settings != null:
		_main().pop_veil(_settings)
		_settings = null
	elif _auto_buy_panel != null:
		_close_auto_buy()
	elif _shop != null:
		_close_shop()
	else:
		Game.save_game()
		_main().show_menu()
	get_viewport().set_input_as_handled()
