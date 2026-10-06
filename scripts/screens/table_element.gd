# TableElement - lo que hay encima de la mesa.
#
# Un elemento es una de dos cosas y nunca las dos a la vez:
#   - un PAQUETE cerrado: se le hace clic, se espera (las herramientas acortan
#     la espera) y se abre solo.
#   - un BOTIN: ya no hace falta abrirlo, se le hace clic y se vende.
#
# El elemento se encarga de su propio reloj y de su propio arte; quien decide
# que hacer con el es game.gd, que es quien tiene la mesa.
class_name TableElement
extends Control

## El paquete se abrio: hay que tirar la carta de revelado.
signal opened(pack_id: String)
## Se vendio este botin por esta cantidad, en este punto de la pantalla.
signal sold(value: int, at: Vector2)

enum State { CLOSED, OPENING, OPENED, LOOT }

const BOX := Vector2(300, 340)          # caja que ocupa el elemento en la mesa
const ART_CENTER := Vector2(150, 140)   # centro del sprite, en coordenadas suyas
const SHADOW_CENTER := Vector2(150, 268)
const TAG_CENTER := Vector2(150, 292)
const ART_SIZE := Vector2(256, 256)     # el 512 del catalogo a la mitad
const TAG_SIZE := Vector2(200, 88)      # 20x10 de arte al doble que antes
const SHADOW_SIZE := Vector2(128, 128)
## Tamano del anillo de espera. Tiene que ser bastante mas grande que el dibujo
## del paquete para que se le vea la vuelta por fuera (ver _build_pack()): el
## sprite ui_timer_track dibuja su banda de 2,3 a 8,5 celdas de radio, o sea que
## a 320 px el aro llega hasta 171 px del centro y el paquete se queda en 128
## por el lado corto.
const RING_SIZE := Vector2(320, 320)
const HIT_RECT := Rect2(Vector2(20, 10), Vector2(260, 330))

## Barra de resistencia. Va en la parte de arriba de la caja, para que se vea
## cuanto le queda sin tapar el dibujo ni la chapita del precio.
const HP_BAR_POS := Vector2(30, 6)
const HP_BAR_SIZE := Vector2(240, 20)
const HP_FILL_PAD := 3.0

## Cuanto hay que mover el raton para que un movimiento cuente como arrastre y
## no como un clic. Por debajo de esto es un clic con el pulso temblando.
const DRAG_SLOP := 8.0

var state: State = State.CLOSED
var pack: Dictionary = {}
var loot: Dictionary = {}

## Resistencia. Baja a golpes de carga (o de los Pinchos) hasta romper la caja.
var hp: float = 1.0
var max_hp: float = 1.0

## Zona de la mesa por la que se puede mover el objeto, en coordenadas del
## padre. Es la mesa ENTERA, no el hueco que le queda al elemento: el que se
## coloca dentro es el propio elemento, y quien lo pide lo recorta el.
## La pone quien lo crea (game.gd), que es quien sabe donde esta la mesa.
var bounds := Rect2()

var _rng := RandomNumberGenerator.new()
var _art: TextureRect = null
var _ring: TimerRing = null
var _hp_fill: ColorRect = null
var _charge := 0.0
var _total := 1.0
var _busy := false

var _hit: Button = null
var _dragging := false
var _drag_from_mouse := Vector2.ZERO
var _drag_from_pos := Vector2.ZERO
var _travelled := 0.0
var _drop_tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size = BOX
	pivot_offset = BOX * 0.5
	_rng.randomize()


func _ready() -> void:
	if loot.is_empty():
		_build_pack()
	else:
		_build_loot()


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

func setup_pack(pack_data: Dictionary) -> void:
	pack = pack_data
	state = State.CLOSED
	max_hp = float(LootDB.pack_hp(str(pack_data.get("id", "cards"))))
	hp = max_hp


func setup_loot(item: Dictionary) -> void:
	loot = item
	state = State.LOOT


func _build_pack() -> void:
	# El ANILLO VA DELANTE DE TODO MENOS DEL PAQUETE, y es justo lo que hace que
	# no lo tape. El sprite ui_timer_track es un disco con un agujero en medio:
	# medido pixel a pixel, su banda pintada va de 2,3 a 8,5 celdas de radio (36
	# a 137 px de un lienzo de 256), o sea un aro de mas de seis celdas de grosor.
	# Y el paquete no es un cuadrado: su parte pintada es un rectangulo de 128x248
	# centrado en el mismo sitio que el aro. Con el aro delante, su banda cruza el
	# paquete de lado a lado y lo tapa (era el fallo que se veia). Detras, el
	# paquete se come la mitad de dentro del aro y solo quedan a la vista los
	# arcos que sobresalen por los lados, que es como tiene que leerse un anillo
	# de espera: rodeando al paquete, no encima.
	_ring = TimerRing.new()
	_ring.size = RING_SIZE
	_ring.position = ART_CENTER - RING_SIZE * 0.5
	_ring.progress = 0.0
	_ring.modulate.a = 0.0
	add_child(_ring)

	_art = UIKit.image(str(pack.get("art", "pack_cards")), ART_CENTER, ART_SIZE)
	add_child(_art)
	add_child(UIKit.image("shadow_small", SHADOW_CENTER, SHADOW_SIZE,
			Color(1, 1, 1, 0.55)))

	# La barra de resistencia va encima, en el margen transparente de arriba del
	# sprite, para que se lea sin tapar el dibujo de la caja.
	_build_hp_bar()

	# La chapita del precio va DESPUES del aro para que se lea por encima (el aro
	# le pasa por detras a la altura de abajo), y la zona de clic va la ultima de
	# todas para que el clic lo siga cogiendo el boton.
	#
	# El sobre gratuito (precio 0, el inicial) NO lleva chapita: un "0" ahi no
	# dice nada, y lo que dice que es gratis es la columna de sobres.
	if int(pack.get("price", 0)) > 0:
		_add_tag(int(pack.get("price", 0)))
	_hit = UIKit.hit_area(self, HIT_RECT, "Abrir %s" % pack.get("name", ""))
	_hit.pressed.connect(_on_pressed)
	_hit.gui_input.connect(_on_hit_input)


func _build_loot() -> void:
	var rarity_id := str(loot.get("rarity", "common"))
	# Modulado en BLANCO (solo el alfa): el sprite ya trae el color de su rareza,
	# y tintarlo otra vez con el mismo tono solo multiplicaba y lo oscurecia.
	var glow := UIKit.image("rarity_glow_" + rarity_id, ART_CENTER, ART_SIZE,
			Color(1, 1, 1, 0.5))
	glow.modulate.a = 0.0
	add_child(glow)
	var tw := create_tween()
	tw.tween_property(glow, "modulate:a", 0.9, 0.5)
	tw.tween_property(glow, "modulate:a", 0.45, 0.9)
	tw.set_loops()

	_art = UIKit.image(str(loot.get("art", "loot_vinyl")), ART_CENTER, ART_SIZE)
	add_child(_art)
	add_child(UIKit.image("shadow_small", SHADOW_CENTER, SHADOW_SIZE,
			Color(1, 1, 1, 0.55)))
	_add_tag(int(loot.get("value", 0)), 146.0)

	_hit = UIKit.hit_area(self, HIT_RECT, "Vender por " + PixelNumber.format(
			int(loot.get("value", 0))))
	_hit.pressed.connect(_on_pressed)
	_hit.gui_input.connect(_on_hit_input)


## La barra de resistencia: fondo oscuro y relleno que se acorta a cada golpe.
## Los dos son ColorRect planos, como los puntos de nivel de la tienda, porque
## son informacion, no arte.
func _build_hp_bar() -> void:
	var back := ColorRect.new()
	back.color = Color(0.05, 0.04, 0.08, 0.82)
	back.position = HP_BAR_POS
	back.size = HP_BAR_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_hp_fill = ColorRect.new()
	_hp_fill.color = _bar_color(1.0)
	_hp_fill.position = HP_BAR_POS + Vector2(HP_FILL_PAD, HP_FILL_PAD)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_fill)
	_refresh_hp_bar()


## Color del relleno: verde arriba, rojo abajo. Es lo unico del juego con esta
## escala de color, y es a proposito: la vida se tiene que leer de un vistazo.
func _bar_color(frac: float) -> Color:
	if frac > 0.5:
		return Color(0.35, 0.75, 0.42)
	if frac > 0.25:
		return Color(0.85, 0.65, 0.20)
	return Color(0.80, 0.28, 0.22)


func _refresh_hp_bar() -> void:
	if _hp_fill == null:
		return
	var frac := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var inner := HP_BAR_SIZE - Vector2(HP_FILL_PAD, HP_FILL_PAD) * 2.0
	_hp_fill.size = Vector2(maxf(0.0, inner.x * frac), inner.y)
	_hp_fill.color = _bar_color(frac)


## Cambia el sprite del paquete segun lo danado que este. Es lo que pide el PDF:
## la caja se va abriendo (agrietandose) a cada golpe, no de golpe al final.
func _refresh_damage_art() -> void:
	if _art == null:
		return
	_art.texture = Sprites.tex(_damage_art_name())


func _damage_art_name() -> String:
	var base := str(pack.get("art", "pack_cards"))
	var frac := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	if frac > 0.72:
		return base
	if frac > 0.45:
		return base + "_d1"
	if frac > 0.22:
		return base + "_d2"
	return base + "_d3"


## La chapita de valor con el numero dentro.
##
## El texto se pone ANTES de colocar: el ancho del PixelNumber depende de
## cuantos digitos tiene, asi que si se colocara con el texto vacio el numero
## saldria pegado a la esquina de la chapita en vez de centrado.
##
## La escala es 0,34 y no mas pequena porque a 0,25 (lo que estaba antes) los
## digitos salian con 18 px de alto dentro de una chapita de 80: se veian, pero
## como un apunte al margen. Los 24 px de ahora son los mismos que el texto de
## la interfaz, y es lo unico que se lee de un vistazo en la mesa llena.
func _add_tag(value: int, max_width: float = 0.0) -> PixelNumber:
	add_child(UIKit.image("ui_tag_price", TAG_CENTER, TAG_SIZE))
	var num := PixelNumber.new()
	num.name = "Price"
	num.scale_factor = 0.34
	num.max_width = maxf(max_width, TAG_SIZE.x - 22.0)
	add_child(num)
	num.set_number(value)
	num.position = TAG_CENTER - num.size * 0.5
	return num


# --------------------------------------------------------------------------- #
# Apertura
# --------------------------------------------------------------------------- #

func can_open() -> bool:
	return state == State.CLOSED and not _busy


## Arranca la cuenta atras. Devuelve false si el elemento no era un paquete
## cerrado.
func start_opening() -> bool:
	if not can_open():
		return false
	state = State.OPENING
	_total = maxf(0.05, Game.charge_time())
	_charge = 0.0
	# El rasgado va aqui y no en el clic: asi suena tambien cuando abre la
	# automatizacion, que es la mitad de las aperturas de una partida larga.
	Sound.play("sfx_rip")
	_ring.modulate.a = 1.0
	set_process(true)
	_tap(false)
	return true


## La caida al entrar en la mesa: aparece desde arriba, crece y rebota hasta
## quedarse en su sitio.
##
## La lleva el propio elemento y no quien lo coloca (game.gd) porque hay que
## poder cortarla: si el jugador agarra el objeto mientras todavia esta cayendo,
## el tween seguiria moviendolo por su cuenta por debajo del raton y el arrastre
## no responderia. Ver _stop_drop().
func play_drop(rest: Vector2) -> void:
	position = rest + Vector2(0, -260)
	scale = Vector2(0.7, 0.7)
	modulate.a = 0.0
	_drop_tween = create_tween()
	_drop_tween.set_trans(Tween.TRANS_BOUNCE)
	_drop_tween.set_ease(Tween.EASE_OUT)
	_drop_tween.set_parallel(true)
	_drop_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_drop_tween.tween_property(self, "scale", Vector2.ONE, 0.24)
	_drop_tween.chain()
	_drop_tween.tween_property(self, "position", rest, 0.42)


## Se agarra el objeto: se corta la caida y se deja puesto y entero, no a medio
## aparecer. Da igual que se corte en el primer frame que en el ultimo.
func _stop_drop() -> void:
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	_drop_tween = null
	modulate.a = 1.0
	scale = Vector2.ONE


## Cada latigazo de la carga sacude el paquete. Es el "estallido de material"
## que pedia el Idea.pdf, pero sin sonido: ese sprite de sonido todavia no
## existe. En un golpe critico la sacudida es mas fuerte y el paquete destella.
func _tap(crit: bool) -> void:
	if _art == null:
		return
	_art.scale = Vector2(1.18, 0.82) if crit else Vector2(1.08, 0.92)
	var tw := create_tween()
	tw.tween_property(_art, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	if crit:
		_art.modulate = Color(1.7, 1.2, 0.8)
		create_tween().tween_property(_art, "modulate", Color.WHITE, 0.22)


func _process(delta: float) -> void:
	if state != State.OPENING:
		set_process(false)
		return
	_charge += delta
	var p := clampf(_charge / _total, 0.0, 1.0)
	_ring.progress = p
	if p >= 1.0:
		# Un ciclo completo es un golpe. La vida no baja de golpe, pero sube
		# otra vez la carga: por eso hacen falta varios ciclos para abrir.
		_charge = 0.0
		_strike()


## Un golpe: resta a la resistencia el dano del jugador (con critico si toca) y,
## si llega a cero, la caja se rompe y sale el botin.
func _strike() -> void:
	var dmg := Game.damage_per_hit()
	var crit := false
	if Game.crit_chance() > 0.0 and _rng.randf() < Game.crit_chance():
		crit = true
		dmg *= Game.crit_mult()
	hp = maxf(0.0, hp - dmg)
	_tap(crit)
	if hp <= 0.0:
		if _art != null:
			_art.texture = Sprites.tex(str(pack.get("art_open", "pack_cards_open")))
		_refresh_hp_bar()
		_finish()
		return
	_refresh_damage_art()
	_refresh_hp_bar()
	# Un ciclo es un golpe y un clic: si la caja aguanta, vuelve a quedar quieta
	# esperando a que el jugador vuelva a pulsarla. Sin esto se abriria sola de
	# una tirada encadenando ciclos.
	state = State.CLOSED
	set_process(false)
	_ring.progress = 0.0
	_ring.modulate.a = 0.0


## Dano externo (los Pinchos) sin pasar por la carga del boton. Si rompe la caja
## se abre igual, y si estaba quieta tambien: los Pinchos trabajan solos.
func take_damage(amount: float) -> void:
	if _busy or state == State.LOOT or state == State.OPENED or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		if _art != null:
			_art.texture = Sprites.tex(str(pack.get("art_open", "pack_cards_open")))
		_refresh_hp_bar()
		_finish()
		return
	_refresh_damage_art()
	_refresh_hp_bar()


func _finish() -> void:
	state = State.OPENED
	set_process(false)
	_busy = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.16)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(_emit_opened)


func _emit_opened() -> void:
	opened.emit(str(pack.get("id", "cards")))
	queue_free()


# --------------------------------------------------------------------------- #
# Venta
# --------------------------------------------------------------------------- #

func _on_pressed() -> void:
	# Si se ha arrastrado, el boton tambien suelta `pressed` al soltar dentro,
	# pero lo que ha hecho el jugador es MOVER el objeto, no pulsarlo. Sin esto,
	# mover un paquete lo abria y mover un botin lo vendia.
	if _travelled > DRAG_SLOP:
		return
	if _busy:
		return
	if state == State.CLOSED:
		# Lo pide al juego y no lo hace el solo: quien sabe cuantos paquetes caben
		# cargando a la vez (los Guantes) es game.gd, no el elemento.
		Game.request_open(self)
	elif state == State.LOOT:
		_sell()


# --------------------------------------------------------------------------- #
# Arrastre
# --------------------------------------------------------------------------- #

## Mover el objeto por la mesa manteniendo pulsado.
##
## El objeto se coloca en su sitio de partida MAS lo que se ha movido el raton
## desde que se pulso, con la posicion del raton que trae cada evento (ver
## _point()). Lo que NO se usa es `event.relative`, que viene en el mismo espacio
## local del boton: con el objeto escalado (durante la caida) el desplazamiento
## saldria multiplicado por la escala.
func _on_hit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_stop_drop()
			_dragging = true
			_travelled = 0.0
			_drag_from_mouse = _point(mb.position)
			_drag_from_pos = position
			_raise()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var d := _point(mm.position) - _drag_from_mouse
		_travelled = maxf(_travelled, d.length())
		_move_to(_drag_from_pos + d)


## El punto del raton del evento, en coordenadas del viewport.
##
## En _gui_input() el motor entrega la posicion ya transformada al espacio LOCAL
## del boton que recibe el evento, asi que deshacer esa transformacion devuelve
## el punto exacto de la pantalla. Se calcula asi y no con
## get_global_mouse_position() porque esa consulta pregunta al raton del SISTEMA
## (en una prueba sin ventana no hay raton y devuelve cualquier cosa), y ademas
## al no depender de ningun cache el objeto no se queda atras por mucho que se
## mueva el raton de una tirada.
func _point(local: Vector2) -> Vector2:
	return _hit.get_global_transform_with_canvas() * local


## Pone el objeto en un punto de la mesa, sin dejarlo salir de ella.
func _move_to(p: Vector2) -> void:
	var wanted := p
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		wanted.x = clampf(wanted.x, bounds.position.x,
				bounds.position.x + bounds.size.x - size.x)
		wanted.y = clampf(wanted.y, bounds.position.y,
				bounds.position.y + bounds.size.y - size.y)
	position = wanted


## El que se esta moviendo pasa al frente. Sin esto, arrastrar un objeto de
## debajo de otro lo deja por debajo mientras se mueve, que es justo cuando mas
## hace falta verlo.
func _raise() -> void:
	var p := get_parent()
	if p is Control:
		p.move_child(self, p.get_child_count() - 1)


func _sell() -> void:
	if _busy:
		return
	_busy = true
	var value := int(loot.get("value", 0))
	var at := global_position + size * 0.5
	var rise := position.y - 70.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.28)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_property(self, "position:y", rise, 0.28).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(_emit_sold.bind(value, at))


func _emit_sold(value: int, at: Vector2) -> void:
	sold.emit(value, at)
	queue_free()


## Para el boton de "vender todo": devuelve el valor y se borra.
func sell_instant() -> int:
	if state != State.LOOT:
		return 0
	var value := int(loot.get("value", 0))
	queue_free()
	return value


func is_waiting_pack() -> bool:
	return state == State.CLOSED


func is_opening() -> bool:
	return state == State.OPENING


func is_loot() -> bool:
	return state == State.LOOT
