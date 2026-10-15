# Backroom - la trastienda, que ahora es un sitio de verdad.
#
# Esto es la habitacion donde pasa el juego: el suelo, las paredes, el techo, las
# luces y los cuatro cacharros con pantalla (la maquina de sobres, el terminal
# de la tienda, la vitrina del armario y el altar de la hucha) mas el atril de
# los ajustes. Todo se monta en codigo, como el resto del juego, y con las
# mismas piezas: los dibujos son los PNG del kit (Sprite3DKit) y los colores son
# los de la paleta. No hay ni un modelo 3D nuevo.
#
# LA MESA NO SE HA MOVIDO. El plano de la mesa sigue en y=0 y con las mismas
# medidas de siempre (TABLE_RECT por TableElement.S), porque media partida
# -el sorteo de sitio, los limites, el arrastre, las pruebas- habla de esas
# coordenadas. Lo que hace la sala es CONSTRUIR ALREDEDOR: el suelo esta a
# -0,55 (o sea que la mesa queda a la altura de una mesa de trabajo), las
# paredes a 18x15 unidades y el techo a 6. Asi el jugador (1,20 de alto, con los
# ojos a 0,45 sobre su origen) mira la mesa desde arriba y desde fuera, que es
# lo que se pedia: una habitacion, no una mesa girada.
#
# LA ESCALA SORPRENDE Y HAY QUE DECIRLO: las cartas de la mesa miden 2,5
# unidades y el jugador 1,20, asi que son el doble de altas que el. No es un
# fallo de cuentas: el mundo 3D heredo las medidas del 2D (1 pixel logico =
# 0,01) y una carta de 256 px son 2,56 m. La sala esta construida a la escala de
# la mesa y no al reves, porque cambiar la escala de la mesa habria movido todas
# las coordenadas del juego. Se lee como un almacen de objetos gigantes, que es
# justo lo que vende el juego: cosas enormes que no te puedes permitir.
class_name Backroom
extends Node3D

## El suelo, en unidades. La mesa esta a 0 y tiene que quedar a la altura de una
## mesa de trabajo, no a ras de suelo.
const FLOOR_Y := -0.55
const CEIL_Y := 6.0

## La habitacion, en unidades del mundo: x de 2.8 a 21.2 y z de -2 a 13.2,
## colocada alrededor de la mesa (que va de x 5.28 a 18.72 y de z 1.4 a 8.92).
const X0 := 2.8
const X1 := 21.2
const Z0 := -2.0
const Z1 := 13.2

## Donde aparece el jugador: al sur de la mesa, mirando al norte (que es hacia
## donde mira un nodo sin girar: -Z). De frente tiene la mesa y, detras, la
## maquina de sobres y la hucha.
const SPAWN := Vector3(12.0, FLOOR_Y + 0.6, 10.6)

## Altura local a la que flota el cartel de una estacion, y a que distancia por
## delante. Delante y no encima PORQUE NO CABE: con los ojos a media unidad del
## suelo, un cartel encima de una maquina de tres unidades se sale del encuadre y
## no se lee. Delante queda a la altura de la vista y se lee sin mover la cabeza.
const CARD_Y := 1.45
const CARD_Z := 1.20

# Los colores de la sala, que no son de nadie mas: paredes de yeso viejo, madera
# oscura para los muebles y un suelo de baldosa sucia.
const PLASTER := Color(0.17, 0.15, 0.20, 1.0)
const WOOD := Color(0.23, 0.16, 0.12, 1.0)
const WOOD_D := Color(0.15, 0.10, 0.08, 1.0)

## Las cinco estaciones, para que el jugador tenga a que apuntar.
var stations: Array = []
## El rectangulo de la MESA, en unidades del mundo. Lo pone game.gd antes de
## build() con TABLE_RECT (que va en pixeles logicos del juego) pasado por la
## conversion de siempre: 1 pixel = 0.01. La sala no sabe nada del juego; solo
## sabe donde tiene que dejar el hueco de la mesa.
var table_rect := Rect2()
var vending: Station = null
var terminal: Station = null
var vitrine: Station = null
var altar: Station = null
var clipboard: Station = null
## Los tres cacharros que sustituyen a los botones que antes estaban en la barra
## de arriba: la caja donde se vende la mesa, el interruptor de la apertura
## automatica y el ordenador de la compra automatica. Los dos primeros no tienen
## pantalla -no abren nada, HACEN algo- y el tercero abre su lista en un monitor
## pequeño. Con los cinco de arriba, en la sala esta TODO lo que se puede hacer:
## no queda ni un menu que abrir con una tecla de funcion.
var sellbox: Station = null
var opener: Station = null
var pc: Station = null
## El cristal flotante donde sale la tarjeta de revelado. No es una estacion: no
## se anda hasta el, aparece delante de la cara cuando se abre un sobre.
var holo: WorldScreen = null

var _niches: Array = []


## Monta la habitacion. Va aparte del _ready y se llama a mano (ver game.gd):
## quien construye necesita las estaciones ya puestas para poder cablearlas.
func build() -> void:
	_floor()
	_walls()
	_counter()
	_decor()
	_build_vending()
	_build_terminal()
	_build_vitrine()
	_build_altar()
	_build_clipboard()
	_build_sellbox()
	_build_opener()
	_build_pc()
	_build_holo()


# --------------------------------------------------------------------------- #
# Piezas
# --------------------------------------------------------------------------- #

func _mat(color: Color, rough: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	# Las caras de dentro se ven: se mira una caja desde fuera y desde dentro (la
	# maquina desde delante, su hueco desde arriba), y una cara que no se dibuja
	# deja ver el fondo de la sala a traves del mueble.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Una caja del mundo. `collide` le pone cuerpo fisico: lo usan el suelo, las
## paredes y la mesa, que son lo unico con lo que el jugador choca.
func _box(size: Vector3, pos: Vector3, color: Color, rot_deg := Vector3.ZERO,
		collide := false) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var m := MeshInstance3D.new()
	m.mesh = bm
	m.material_override = _mat(color)
	m.position = pos
	m.rotation_degrees = rot_deg
	add_child(m)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		m.add_child(body)
	return m


func _light(pos: Vector3, energy: float = 1.7, range_units: float = 12.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.87, 0.68)
	l.light_energy = energy
	l.omni_range = range_units
	l.shadow_enabled = false
	add_child(l)
	return l


## Una chapa con un dibujo del kit, de pie contra una pared o colgada.
func _sign(sprite_name: String, size_px: Vector2, pos: Vector3,
		rot_deg := Vector3.ZERO) -> Sprite3D:
	var s := Sprite3DKit.sprite(sprite_name, size_px)
	s.position = pos
	s.rotation_degrees = rot_deg
	add_child(s)
	return s


## Una estacion pelada: el nodo con su cartel, su cajon de rayo y sus vistas.
## La geometria de cada una la pone quien la llama.
func _station(name_text: String, hint: String, pos: Vector3, yaw_deg: float,
		screen_units: Vector2, region: Rect2) -> Station:
	var s := Station.new()
	s.name = name_text.replace(" ", "")
	s.sign_name = name_text
	s.sign_hint = hint
	s.position = pos
	s.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	s.card_at = Vector3(0.0, CARD_Y, CARD_Z)
	add_child(s)
	var sc := WorldScreen.new()
	sc.size_units = screen_units
	sc.region = region
	# El cristal SÍ se cuelga de la estacion: un WorldScreen que no entra en el
	# arbol no monta su SubViewport y los paneles se quedan sin _ready (el panel
	# existe, pero vacio). Es un fallo que no da ningun error: solo deja la
	# tienda en negro.
	s.add_child(sc)
	s.screen = sc
	stations.append(s)
	return s


## Pone el cristal en su sitio Y la vista del jugador a la altura del cristal.
##
## Las dos cosas van juntas y por eso es un metodo y no dos lineas en cada
## cacharro: la camara mira al CENTRO del cristal, y si el cristal esta a 1,93 y
## la vista a 1,05 lo que queda en medio de la pantalla es la mesa. La vista se
## pasa en coordenadas LOCALES (x, z) y la altura sale del propio cristal; los
## pies del jugador los deja Player.lock_on, que no toca la altura.
func _place_screen(st: Station, at: Vector3, dist: float = 2.2) -> void:
	st.screen.position = at
	st.view_from = Vector3(0.0, at.y, dist)
	st.view_at = Vector3(0.0, at.y, 0.0)


# --------------------------------------------------------------------------- #
# La habitacion
# --------------------------------------------------------------------------- #

func _floor() -> void:
	# Un damero de baldosa sucia. No es un sprite: el kit no tiene suelos, y un
	# suelo de un solo color a lo largo de 18 unidades se lee como un vacio.
	var pm := PlaneMesh.new()
	pm.size = Vector2(X1 - X0, Z1 - Z0)
	var m := MeshInstance3D.new()
	m.mesh = pm
	m.position = Vector3((X0 + X1) * 0.5, FLOOR_Y, (Z0 + Z1) * 0.5)
	var mat := _mat(Color(1, 1, 1, 1))
	# El damero se dibuja en una Image de 2x2 y el material la repite. No hay
	# CheckerTexture en Godot 4, y un suelo de un solo color a lo largo de 18
	# unidades se lee como un vacio: con esto salen baldosas cuadradas del
	# tamano de una persona, que es lo que da la escala de la habitacion.
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(0.21, 0.19, 0.23))
	img.set_pixel(1, 0, Color(0.15, 0.13, 0.17))
	img.set_pixel(0, 1, Color(0.15, 0.13, 0.17))
	img.set_pixel(1, 1, Color(0.21, 0.19, 0.23))
	mat.albedo_texture = ImageTexture.create_from_image(img)
	# NEAREST como el resto del juego: la baldosa tiene que verse cuadrada y con
	# su canto, no difuminada.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(9.0, 9.0, 1.0)
	m.material_override = mat
	add_child(m)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(X1 - X0 + 2.0, 1.0, Z1 - Z0 + 2.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3((X0 + X1) * 0.5, FLOOR_Y - 0.5, (Z0 + Z1) * 0.5)
	add_child(body)

	# El techo, mirando hacia abajo.
	var cm := PlaneMesh.new()
	cm.size = Vector2(X1 - X0, Z1 - Z0)
	var ceil := MeshInstance3D.new()
	ceil.mesh = cm
	ceil.position = Vector3((X0 + X1) * 0.5, CEIL_Y, (Z0 + Z1) * 0.5)
	ceil.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	ceil.material_override = _mat(Color(0.09, 0.08, 0.11, 1.0))
	add_child(ceil)


func _walls() -> void:
	var w := X1 - X0
	var d := Z1 - Z0
	var h := CEIL_Y - FLOOR_Y
	var t := 0.4
	var mid_y := (FLOOR_Y + CEIL_Y) * 0.5
	var mid_x := (X0 + X1) * 0.5
	var mid_z := (Z0 + Z1) * 0.5
	# Las cuatro paredes, con su zocalo de madera. El zocalo no es adorno: es lo
	# que dice donde acaba el suelo, que en una habitacion sin sombras es la
	# unica pista de que hay una pared.
	for spec in [[Vector3(w + t * 2.0, h, t), Vector3(mid_x, mid_y, Z0 - t * 0.5)],
			[Vector3(w + t * 2.0, h, t), Vector3(mid_x, mid_y, Z1 + t * 0.5)],
			[Vector3(t, h, d + t * 2.0), Vector3(X0 - t * 0.5, mid_y, mid_z)],
			[Vector3(t, h, d + t * 2.0), Vector3(X1 + t * 0.5, mid_y, mid_z)]]:
		_box(spec[0], spec[1], PLASTER, Vector3.ZERO, true)
	for spec in [[Vector3(w, 1.1, 0.08), Vector3(mid_x, FLOOR_Y + 0.55, Z0 + 0.05)],
			[Vector3(w, 1.1, 0.08), Vector3(mid_x, FLOOR_Y + 0.55, Z1 - 0.05)],
			[Vector3(0.08, 1.1, d), Vector3(X0 + 0.05, FLOOR_Y + 0.55, mid_z)],
			[Vector3(0.08, 1.1, d), Vector3(X1 - 0.05, FLOOR_Y + 0.55, mid_z)]]:
		_box(spec[0], spec[1], WOOD_D)


## La mesa: la superficie es el sprite de siempre (bg_table) y debajo va el
## cuerpo, que es lo que hace que sea una mesa y no un plano flotante.
func _counter() -> void:
	var r: Rect2 = table_rect
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var cx := (r.position.x + r.end.x) * 0.5
	var cz := (r.position.y + r.end.y) * 0.5
	var w := r.size.x
	var d := r.size.y
	# Cuerpo de madera, de -0,55 a 0: el tablero queda a la altura de una mesa.
	_box(Vector3(w, -FLOOR_Y, d), Vector3(cx, FLOOR_Y * 0.5, cz), WOOD, Vector3.ZERO, true)
	# Y el canto de arriba, un poco mas ancho, para que se vea el grosor del
	# tablero en vez de un corte seco.
	_box(Vector3(w + 0.14, 0.08, d + 0.14), Vector3(cx, -0.04, cz), WOOD_D)
	var top := Sprite3DKit.floor("bg_table", Vector2(w, d))
	top.name = "CounterTop"
	top.position = Vector3(cx, 0.004, cz)
	add_child(top)

	_light(Vector3(cx, 3.6, cz), 2.0, 14.0)
	_light(Vector3(X0 + 2.4, 3.6, Z0 + 2.4), 1.5, 10.0)
	_light(Vector3(X1 - 2.4, 3.6, Z0 + 2.4), 1.5, 10.0)
	_light(Vector3(cx, 3.6, Z1 - 1.6), 1.4, 10.0)


## El rectangulo de la mesa, en unidades del mundo. Es TABLE_RECT (que va en
## pixeles logicos) pasado por la conversion de siempre: 1 pixel = 0.01.
func _decor() -> void:
	# Una balda con tres sobres de pie, entre el terminal y el atril: es lo que
	# dice que esto es la trastienda de una tienda de sobres y no un almacen
	# cualquiera.
	_box(Vector3(0.34, 0.1, 2.6), Vector3(X0 + 0.22, 0.85, 7.4), WOOD)
	var i := 0
	for pack_id in ["pack_cards", "pack_vinyls", "pack_sneakers"]:
		var s := _sign(pack_id, Vector2(112, 112),
				Vector3(X0 + 0.42, 1.35, 6.6 + float(i) * 0.8), Vector3(0, 90, 0))
		s.modulate = Color(0.85, 0.85, 0.9, 1.0)
		i += 1
	# Los carteles de las paredes: los mismos iconos que usaba la barra de
	# arriba, colgados donde toca. El de la tienda sobre el terminal y el de la
	# vitrina sobre la vitrina, que es lo que hace que se sepa que son sin mirar.
	_sign("ui_icon_shop", Vector2(150, 150), Vector3(X0 + 0.3, 2.75, 4.6), Vector3(0, 90, 0))
	_sign("ui_icon_vitrine", Vector2(150, 150), Vector3(X1 - 0.3, 2.9, 5.0), Vector3(0, -90, 0))
	# Un par de cajas apiladas en la esquina: llenan el sitio mas vacio de la
	# habitacion (la esquina sureste) y dan una referencia de tamano.
	_box(Vector3(0.9, 0.9, 0.9), Vector3(X1 - 1.2, FLOOR_Y + 0.45, Z1 - 1.3), WOOD_D,
			Vector3(0, 18, 0))
	_box(Vector3(0.7, 0.7, 0.7), Vector3(X1 - 1.35, FLOOR_Y + 1.25, Z1 - 1.45), WOOD,
			Vector3(0, -12, 0))


# --------------------------------------------------------------------------- #
# Los cacharros
# --------------------------------------------------------------------------- #

## La maquina de sobres: el sitio donde se compran. Enseña SOLO la columna de
## sobres (ver WorldScreen.region), no el lienzo entero, porque la columna ocupa
## su franja de la izquierda y el resto del lienzo es negro.
func _build_vending() -> void:
	vending = _station("MAQUINA DE SOBRES", "COMPRAR SOBRES", Vector3(7.4, FLOOR_Y, -1.55),
			0.0, Vector2(1.7, 2.2), Rect2(16, 120, 496, 640))
	# El cajon del rayo llega hasta ARRIBA del cristal, no hasta media maquina: la
	# vista apunta al centro de la pantalla (1,35) y un cajon que acabara a 1,8 no
	# recogeria el rayo de quien mira al cristal desde el suelo.
	vending.pick_half = Vector3(1.7, 2.4, 1.1)
	_box(Vector3(2.5, 2.7, 1.0), Vector3(0.0, 1.35, -0.5), Color(0.30, 0.11, 0.09, 1.0),
			Vector3.ZERO, true)
	# El cristal, en su marco, sobre la cara de delante.
	_box(Vector3(1.9, 2.4, 0.06), Vector3(0.0, 1.35, 0.01), Color(0.05, 0.04, 0.06, 1.0))
	_place_screen(vending, Vector3(0.0, 1.35, 0.03), 2.3)
	# Y la bandeja por donde salen, abajo del todo.
	_box(Vector3(2.0, 0.22, 0.34), Vector3(0.0, 0.14, 0.22), WOOD_D)
	# La maquina esta encendida siempre: los precios de los sobres se miran
	# mientras se anda por la sala, no solo cuando se esta delante.
	vending.screen.set_lit(true)


## El terminal de la tienda: un mostrador con su monitor, en la pared oeste.
## Enseña el panel de la tienda entero (ShopPanel), que ya trae su propio velo y
## su marco: en el cristal se ve como lo que es, una tienda en una pantalla.
func _build_terminal() -> void:
	terminal = _station("TERMINAL DE LA TIENDA", "ABRIR TIENDA", Vector3(3.5, FLOOR_Y, 4.6),
			90.0, Vector2(2.6, 1.46), Rect2(0, 0, 1920, 1080))
	terminal.pick_half = Vector3(1.7, 2.4, 1.0)
	_box(Vector3(3.2, 0.75, 1.1), Vector3(0.0, 0.37, -0.05), WOOD, Vector3.ZERO, true)
	_box(Vector3(2.9, 1.8, 0.34), Vector3(0.0, 1.75, -0.2), WOOD_D)
	_box(Vector3(2.45, 1.35, 0.05), Vector3(0.0, 1.72, 0.005), Color(0.05, 0.04, 0.06, 1.0))
	_place_screen(terminal, Vector3(0.0, 1.72, 0.035), 2.0)


## La vitrina: el mueble del armario. Su cristal es el panel (LockerPanel, con el
## inventario y los huecos) y DEBAJO tiene los ocho nichos de verdad, donde se
## ven los objetos expuestos. Es la parte del juego que mas gana con esto: antes
## el armario era una tira de dibujos en el pie de la pantalla y ahora es un
## mueble en el que se ve lo que has puesto a la venta.
func _build_vitrine() -> void:
	vitrine = _station("VITRINA DEL ARMARIO", "ABRIR ARMARIO", Vector3(X1 - 0.6, FLOOR_Y, 5.0),
			-90.0, Vector2(2.8, 1.58), Rect2(0, 0, 1920, 1080))
	vitrine.pick_half = Vector3(1.9, 2.9, 1.0)
	_box(Vector3(4.4, 2.9, 0.9), Vector3(0.0, 1.45, -0.5), WOOD, Vector3.ZERO, true)
	_box(Vector3(3.0, 1.75, 0.34), Vector3(0.0, 1.95, -0.25), WOOD_D)
	_box(Vector3(2.6, 1.45, 0.05), Vector3(0.0, 1.93, 0.02), Color(0.05, 0.04, 0.06, 1.0))
	_place_screen(vitrine, Vector3(0.0, 1.93, 0.05), 2.2)
	# Los ocho nichos, dos filas de cuatro, con su cristal delante.
	for i in 8:
		var col := i % 4
		var row := floori(float(i) / 4.0)
		var px := -1.35 + float(col) * 0.9
		var py := 0.55 - float(row) * 0.62
		_box(Vector3(0.8, 0.5, 0.42), Vector3(px, py, -0.28), Color(0.09, 0.07, 0.10, 1.0))
		var niche := Node3D.new()
		niche.name = "Niche%d" % i
		niche.position = Vector3(px, py + 0.02, -0.28)
		add_child(niche)
		_niches.append(niche)


## El altar de la hucha: un pedestal con el cerdito y, encima, su pantalla (el
## panel del rebirth). Al fondo del todo, a la derecha de la maquina.
func _build_altar() -> void:
	altar = _station("HUCHA", "REINICIAR LA PARTIDA", Vector3(17.0, FLOOR_Y, -1.5),
			0.0, Vector2(2.5, 1.4), Rect2(0, 0, 1920, 1080))
	altar.pick_half = Vector3(1.6, 4.4, 1.0)
	_box(Vector3(1.6, 0.9, 1.0), Vector3(0.0, 0.45, -0.3), WOOD, Vector3.ZERO, true)
	_box(Vector3(1.9, 0.08, 1.2), Vector3(0.0, 0.93, -0.3), WOOD_D)
	# El cerdito, de pie sobre el pedestal y mirando a la sala.
	var piggy := _sign("currency_piggy", Vector2(150, 150), Vector3(0.0, 1.6, -0.25))
	piggy.modulate = Color(1.0, 0.95, 0.85, 1.0)
	_box(Vector3(3.0, 0.1, 0.5), Vector3(0.0, 2.5, -0.4), WOOD_D)
	_box(Vector3(2.7, 1.5, 0.34), Vector3(0.0, 3.25, -0.25), WOOD_D)
	_box(Vector3(2.35, 1.15, 0.05), Vector3(0.0, 3.23, -0.05), Color(0.05, 0.04, 0.06, 1.0))
	# El cristal de la hucha esta por encima de la cabeza, asi que se mira desde
	# mas lejos que los demas: de cerca habria que doblar el cuello.
	_place_screen(altar, Vector3(0.0, 3.23, -0.02), 3.2)


## El atril de los ajustes: un tablero colgado de la pared oeste, al lado del
## terminal. Dentro van los ajustes y, detras, el mini menu de la compra
## automatica: los dos son "cosas que se tocan una vez", asi que comparten
## cacharro y no hay dos muebles iguales en la sala.
func _build_clipboard() -> void:
	clipboard = _station("AJUSTES", "ABRIR AJUSTES", Vector3(3.4, FLOOR_Y, 8.6),
			90.0, Vector2(2.4, 1.35), Rect2(0, 0, 1920, 1080))
	clipboard.pick_half = Vector3(1.6, 2.2, 0.8)
	_box(Vector3(0.16, 2.4, 2.9), Vector3(-0.3, 1.05, 0.0), WOOD, Vector3.ZERO, true)
	_box(Vector3(0.05, 1.6, 2.6), Vector3(0.0, 1.25, 0.0), Color(0.05, 0.04, 0.06, 1.0))
	_place_screen(clipboard, Vector3(0.03, 1.25, 0.0), 1.9)


## La caja de venta: un cajon de madera en la pared del fondo donde se tira lo
## que hay en la mesa y se cobra al momento. NO tiene pantalla y no abre nada:
## se mira, se pulsa la tecla y el dinero entra, con su aviso y su sonido. El
## cartel dice si hay algo que vender, que es todo lo que hace falta saber.
func _build_sellbox() -> void:
	sellbox = _station("CAJA DE VENTA", "VENDER LA MESA", Vector3(12.4, FLOOR_Y, -1.6), 0.0,
			Vector2(1.0, 0.5), Rect2(0, 0, 1920, 1080))
	sellbox.pick_half = Vector3(1.1, 1.7, 0.9)
	_box(Vector3(1.5, 1.25, 0.95), Vector3(0.0, 0.62, -0.4), WOOD_D, Vector3.ZERO, true)
	# El borde y la boca oscura: sin el hueso del canto, un cajon de un solo color
	# se lee como un bloque.
	_box(Vector3(1.62, 0.12, 1.05), Vector3(0.0, 1.28, -0.4), WOOD)
	_box(Vector3(1.24, 0.05, 0.75), Vector3(0.0, 1.32, -0.4), Color(0.04, 0.03, 0.05, 1.0))


## El interruptor de la apertura automatica: un armario pequeno con la chapa de
## los Pinchos encima. Encendido o apagado lo dice su propio cartel (ver
## Station.on_hint), y esa es toda la interfaz que necesita: se mira y se lee.
func _build_opener() -> void:
	opener = _station("APERTURA AUTOMATICA", "ENCENDER LOS PINCHOS",
			Vector3(9.9, FLOOR_Y, -1.6), 0.0, Vector2(1.0, 0.5), Rect2(0, 0, 1920, 1080))
	opener.pick_half = Vector3(0.95, 1.6, 0.85)
	_box(Vector3(1.3, 1.7, 0.8), Vector3(0.0, 0.85, -0.42), WOOD_D, Vector3.ZERO, true)
	_box(Vector3(1.42, 0.1, 0.9), Vector3(0.0, 1.72, -0.42), WOOD)
	# La chapa es el dibujo de la PIEZA que hace falta, no un icono cualquiera: el
	# que mira el cacharro apagado ve de un golpe cual de las dos piezas le falta.
	var art := str(LootDB.item_by_id(LootDB.AUTO_ITEM_OPEN)["art"])
	var plate := _sign(art, Vector2(96, 96), Vector3(0.0, 1.15, 0.0))
	Sprite3DKit.priority_of(plate, 3)


## El ordenador de la compra automatica: un mostrador bajito con su monitor, al
## lado del terminal de la tienda. Aqui se elige QUE sobres se compran solos (ver
## AutoBuyPanel), asi que este si abre una pantalla: en la suya.
func _build_pc() -> void:
	pc = _station("ORDENADOR", "COMPRA AUTOMATICA", Vector3(X0, FLOOR_Y, 6.7), 90.0,
			Vector2(1.5, 0.84), Rect2(0, 0, 1920, 1080))
	pc.pick_half = Vector3(1.1, 2.0, 0.9)
	_box(Vector3(1.7, 0.78, 0.9), Vector3(0.0, 0.39, -0.15), WOOD, Vector3.ZERO, true)
	_box(Vector3(1.5, 1.05, 0.45), Vector3(0.0, 1.32, -0.35), WOOD_D)
	_box(Vector3(1.36, 0.9, 0.05), Vector3(0.0, 1.3, -0.12), Color(0.05, 0.04, 0.06, 1.0))
	_place_screen(pc, Vector3(0.0, 1.3, -0.09), 1.6)


## El cristal que aparece delante de la cara con la tarjeta de revelado. No es
## una estacion (no se anda hasta el): lo coloca game.gd delante de la camara
## cuando sale un objeto, que es donde el jugador esta mirando.
func _build_holo() -> void:
	holo = WorldScreen.new()
	holo.name = "Holo"
	holo.size_units = Vector2(3.0, 1.69)
	add_child(holo)


## Los objetos expuestos, dentro de los nichos. Los mete game.gd cada vez que
## cambia el armario (ver _refresh_locker).
func set_vitrine_items(items: Array) -> void:
	for i in _niches.size():
		var niche: Node3D = _niches[i]
		for c in niche.get_children():
			niche.remove_child(c)
			c.queue_free()
		if i >= items.size():
			continue
		var item: Dictionary = items[i]
		var art := str(item.get("art", "loot_vinyl"))
		var s := Sprite3DKit.sprite(art, Vector2(64, 64))
		Sprite3DKit.priority_of(s, 3)
		# El dibujo se escala por su tinta y no por su lienzo: los objetos del
		# catalogo no llenan igual su PNG y sin esto unos salen grandes y otros
		# pequeños en la misma fila de nichos.
		s.rotation_degrees = Vector3(0.0, -90.0, 0.0)
		niche.add_child(s)
