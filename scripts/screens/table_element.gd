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
## Ha terminado una redonda de la carga: este golpe ha quitado esto, y era
## critico o no. Lo pinta quien tiene la capa de los avisos (ver game.gd,
## _on_element_damaged()), que es el mismo que pinta los avisos de venta.
signal damaged(amount: float, crit: bool)
## El jugador ha dado un GOLPE PERFECTO: ha pulsado el sobre en el ultimo trozo
## del anillo (ver Gameplay.PERFECT_FROM). `sweet` si ha sido en la zona dorada y
## `mult` lo que ha multiplicado el dano (con la racha). Lo pinta game.gd.
signal perfect_hit(sweet: bool, mult: float)
## El jugador ha pulsado ANTES del tramo perfecto: el anillo ha perdido un trozo
## y la racha se ha roto (ver Gameplay.EARLY_PENALTY).
signal early_click()

enum State { CLOSED, OPENING, OPENED, LOOT }

const BOX := Vector2(300, 340)          # caja que ocupa el elemento en la mesa
const ART_CENTER := Vector2(150, 140)   # centro del sprite, en coordenadas suyas
const SHADOW_CENTER := Vector2(150, 268)
const ART_SIZE := Vector2(256, 256)     # el 512 del catalogo a la mitad
const SHADOW_SIZE := Vector2(128, 128)
## Tamano del anillo de espera. Tiene que ser bastante mas grande que el dibujo
## del paquete para que se le vea la vuelta por fuera (ver _build_pack()): el
## sprite ui_timer_track dibuja su banda de 2,3 a 8,5 celdas de radio, o sea que
## a 320 px el aro llega hasta 171 px del centro y el paquete se queda en 128
## por el lado corto.
const RING_SIZE := Vector2(320, 320)
const HIT_RECT := Rect2(Vector2(20, 10), Vector2(260, 330))

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
var _charge := 0.0
var _total := 1.0
var _busy := false

## Donde queda el objeto cuando acaba de caer. Mientras vuela, position esta
## DROP_HEIGHT px mas arriba, asi que quien mide huecos en la mesa no puede mirar position:
## un objeto a medio caer no ocupa su sitio todavia (ver spot()).
var rest_spot := Vector2.ZERO
## Desde cuanto mas arriba cae un objeto al entrar en la mesa.
const DROP_HEIGHT := 420.0
## Toca la mesa al acabar la caida (game.gd sacude la mesa con el golpe).
signal landed()

var _hit: Button = null
var _dragging := false
var _drag_from_mouse := Vector2.ZERO
var _drag_from_pos := Vector2.ZERO
var _travelled := 0.0
var _drop_tween: Tween = null

## EL SOBRE DORADO: un sobre que aparece solo y se va si no se le da el primer
## golpe en Gameplay.GOLDEN_LIFE segundos. Lo que trae (mejor nota) lo decide
## game.gd al abrirse; aqui solo vive el brillo y el reloj.
var golden := false
var golden_left := 0.0
var _golden_glow: TextureRect = null
## El rotulo de debajo ("DORADO 7 S"): sin el, el reloj solo se ve en los tres
## ultimos segundos (cuando parpadea) y el jugador no sabe que se le va a ir.
var _golden_tag: Label = null

## EL JEFE: un sobre con mucha vida y un reloj que corre desde que aparece. Lo
## que trae y el reloj los lleva game.gd; aqui viven el aspecto y el rotulo.
var boss := false
var boss_left := 0.0
var _boss_tag: Label = null

## Se ha roto a golpes del jugador (y no por los Pinchos): es lo que cuenta para
## el combo de apertura (ver game.gd, _on_element_opened).
var broken_by_hit := false

## Un clic justo despues de arrancar la carga no es "pulsar antes de tiempo": es
## el doble clic de empezar. Por debajo de estos segundos no se castiga.
const EARLY_GRACE := 0.2


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


## Cambia el botin de un objeto que ya esta en la mesa (la lupa del tasador le
## cambia la nota): el dibujo y el aviso del boton, con el valor nuevo.
func set_loot(item: Dictionary) -> void:
	if state != State.LOOT:
		return
	loot = item
	if _art != null:
		_art.texture = Sprites.tex(str(item.get("art", "loot_vinyl")))
	if _hit != null:
		_hit.tooltip_text = "Vender por " + PixelNumber.format(int(item.get("value", 0)))


## La vida de un sobre que vuelve a la mesa desde un guardado (ver
## Game.table): se pone despues de montarlo, con el dibujo ya hecho, para que la
## caja salga agrietada como estaba. Nunca baja de 1: un sobre guardado a cero
## estaba rompiendose, y lo que tiene que pasar es que el siguiente golpe lo abra.
func set_hp(value: float) -> void:
	if state == State.LOOT:
		return
	hp = clampf(value, 1.0, max_hp)
	_refresh_damage_art()


## Lo convierte en sobre dorado. Va despues de setup_pack() y antes de entrar en
## el arbol (el brillo se monta en _build_pack).
func setup_golden() -> void:
	golden = true
	golden_left = Gameplay.GOLDEN_LIFE


## Pone al dia el rotulo del sobre dorado. Empezado ya no se va, asi que el
## reloj sobra: el rotulo se queda en "DORADO" y vuelve a verse entero (si se le
## dio el primer golpe en mitad del parpadeo, se quedaba medio transparente).
func golden_tick() -> void:
	if not golden:
		return
	if started():
		modulate.a = 1.0
		if _golden_tag != null:
			_golden_tag.text = "DORADO"
		return
	if _golden_tag != null:
		_golden_tag.text = "DORADO  %d S" % ceili(maxf(0.0, golden_left))


## Lo convierte en JEFE, con su vida y su reloj. Como setup_golden(): despues
## de setup_pack() y antes de entrar en el arbol.
func setup_boss(hp_value: float, life: float) -> void:
	boss = true
	boss_left = life
	max_hp = maxf(max_hp, hp_value)
	hp = max_hp


## Pone al dia el rotulo del jefe: lo que le queda de vida y de reloj.
func boss_tick() -> void:
	if _boss_tag == null:
		return
	_boss_tag.text = "JEFE  %d %%  %d S" % [ceili(hp / maxf(1.0, max_hp) * 100.0),
			ceili(maxf(0.0, boss_left))]
	_boss_tag.modulate = Color.WHITE if boss_left > 5.0 \
			else (Color(1.6, 0.6, 0.5) if int(boss_left * 4.0) % 2 == 0 else Color.WHITE)


## ¿Se ha empezado ya? Un sobre dorado empezado no se va.
func started() -> bool:
	return state != State.CLOSED or hp < max_hp


func _build_pack() -> void:
	if golden:
		# El brillo dorado detras de todo, latiendo: es lo que dice "este es
		# distinto" en una mesa llena de sobres iguales.
		# A 1,75 veces el dibujo: el brillo es un degradado suave y el paquete tapa
		# su centro, asi que a 1,35 solo asomaba un borde que no se veia.
		_golden_glow = UIKit.image("rarity_glow_legendary", ART_CENTER, ART_SIZE * 1.75,
				Color(1.3, 1.15, 0.6, 1.0))
		add_child(_golden_glow)
		var gt := create_tween().set_loops()
		gt.tween_property(_golden_glow, "modulate:a", 0.6, 0.45)
		gt.tween_property(_golden_glow, "modulate:a", 1.0, 0.45)
		_golden_tag = UIKit.label_at("", Vector2(BOX.x * 0.5, ART_CENTER.y + ART_SIZE.y * 0.5 + 12),
				Vector2(BOX.x, 30), 21, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0)
		add_child(_golden_tag)
		golden_tick()
	if boss:
		# El jefe late en rojo detras, como el dorado en oro: se ve de lejos que
		# no es un sobre mas.
		var aura := UIKit.image("rarity_glow_legendary", ART_CENTER, ART_SIZE * 1.9,
				Color(1.6, 0.35, 0.3, 1.0))
		add_child(aura)
		var at := create_tween().set_loops()
		at.tween_property(aura, "modulate:a", 0.55, 0.3)
		at.tween_property(aura, "modulate:a", 1.0, 0.3)
		_boss_tag = UIKit.label_at("", Vector2(BOX.x * 0.5, ART_CENTER.y + ART_SIZE.y * 0.5 + 12),
				Vector2(BOX.x, 30), 21, Palette.RUST_L, HORIZONTAL_ALIGNMENT_CENTER, 0)
		add_child(_boss_tag)
		boss_tick()
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
	_ring.zone_from = Gameplay.PERFECT_FROM
	_ring.sweet_from = Gameplay.SWEET_FROM
	_ring.sweet_to = Gameplay.SWEET_TO
	_ring.modulate.a = 0.0
	add_child(_ring)

	_art = UIKit.image(str(pack.get("art", "pack_cards")), ART_CENTER, ART_SIZE)
	add_child(_art)
	if golden:
		_art.modulate = Color(1.25, 1.1, 0.55)
	elif boss:
		_art.modulate = Color(1.35, 0.7, 0.65)
	add_child(UIKit.image("shadow_small", SHADOW_CENTER, SHADOW_SIZE,
			Color(1, 1, 1, 0.55)))

	# NO HAY BARRA DE RESISTENCIA, y es a proposito: la caja ya dice como va
	# -se agrieta en tres tramos y acaba abierta (ver _refresh_damage_art)- y una
	# barra mas encima del dibujo era ruido sobre el unico sitio donde se mira.
	#
	# SIN CHAPITA DE PRECIO. Cada objeto de la mesa llevaba su numero colgado de
	# la chapa ui_tag_price y el usuario la quito: el precio ya esta en la columna
	# de sobres (y en el aviso al pasar por encima), y repetido debajo de cada
	# caja lo unico que hacia era tapar la mesa. Aqui manda el dibujo del sobre.
	#
	# La zona de clic va la ultima de todas para que el clic lo coja el boton.
	_hit = UIKit.hit_area(self, HIT_RECT, "Abrir %s" % pack.get("name", ""))
	_hit.pressed.connect(_on_pressed)
	_hit.gui_input.connect(_on_hit_input)
	UIKit.juice(_hit, [_art], 1.06)


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
	# Sin chapita de valor, por lo mismo que el paquete. Lo que vale el botin se
	# sigue diciendo en el aviso del boton y en su tarjeta de revelado.

	_hit = UIKit.hit_area(self, HIT_RECT, "Vender por " + PixelNumber.format(
			int(loot.get("value", 0))))
	_hit.pressed.connect(_on_pressed)
	_hit.gui_input.connect(_on_hit_input)
	UIKit.juice(_hit, [_art], 1.06)


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
	rest_spot = rest
	position = rest + Vector2(0, -DROP_HEIGHT)
	scale = Vector2(0.85, 1.12)
	modulate.a = 0.0
	# Mientras cae va por ENCIMA de la barra de arriba, que se dibuja despues.
	z_index = 1
	_drop_tween = create_tween()
	# Cae acelerando (como algo que se suelta), no frenando.
	_drop_tween.set_parallel(true)
	_drop_tween.tween_property(self, "modulate:a", 1.0, 0.1)
	_drop_tween.tween_property(self, "position", rest, 0.34) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# El choque: se aplasta contra la mesa, levanta polvo y rebota a su forma.
	_drop_tween.chain().tween_callback(_on_landed)
	_drop_tween.tween_property(self, "scale", Vector2(1.22, 0.78), 0.06)
	_drop_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.38) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_landed() -> void:
	z_index = 0
	landed.emit()
	var dust := CPUParticles2D.new()
	dust.position = Vector2(BOX.x * 0.5, BOX.y - 40.0)
	dust.emitting = false
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 18
	dust.lifetime = 0.5
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(BOX.x * 0.35, 4)
	dust.direction = Vector2(0, -1)
	dust.spread = 80.0
	dust.initial_velocity_min = 80.0
	dust.initial_velocity_max = 220.0
	dust.gravity = Vector2(0, 400)
	dust.scale_amount_min = 6.0
	dust.scale_amount_max = 12.0
	dust.color = Color(Palette.CREAM_D, 0.8)
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	dust.color_ramp = fade
	add_child(dust)
	move_child(dust, 0)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


## El sitio que OCUPA el objeto en la mesa: el de reposo mientras cae y el suyo
## cuando ya esta puesto (o cuando el jugador lo ha movido).
func spot() -> Vector2:
	if _drop_tween != null and _drop_tween.is_valid():
		return rest_spot
	return position


## Se agarra el objeto: se corta la caida y se deja puesto y entero, no a medio
## aparecer. Da igual que se corte en el primer frame que en el ultimo.
func _stop_drop() -> void:
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	_drop_tween = null
	modulate.a = 1.0
	scale = Vector2.ONE
	z_index = 0


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
	# EL TRAMO DEL GOLPE PERFECTO: las zonas ya estan pintadas en el anillo (ver
	# TimerRing.zone_from), asi que aqui solo cambia la PUNTA que avanza: turquesa
	# dentro del tramo perfecto y blanca en la ZONA DORADA. Antes se tenia todo el
	# anillo, y eso tapaba los colores de las zonas.
	if p >= Gameplay.SWEET_FROM and p < Gameplay.SWEET_TO:
		_ring.head_color = TimerRing.SWEET_COLOR
	elif p >= Gameplay.PERFECT_FROM:
		_ring.head_color = TimerRing.ZONE_COLOR
	else:
		_ring.head_color = Palette.GOLD_XL
	if p >= 1.0:
		# Un ciclo completo es un golpe. La vida no baja de golpe, pero sube
		# otra vez la carga: por eso hacen falta varios ciclos para abrir.
		_charge = 0.0
		# Se le ha pasado al jugador: la vuelta ha acabado sin que lo pulse, y eso
		# rompe la racha. Con el FRENESI no, que ahi los sobres van solos.
		if Game.frenzy_left <= 0.0:
			Game.break_streak()
		_strike()


## Un golpe: resta a la resistencia el dano del jugador (con critico si toca) y,
## si llega a cero, la caja se rompe y sale el botin.
func _strike(perfect: bool = false, sweet: bool = false) -> void:
	# El golpe cargado (habilidad) se gasta en el primer golpe del jugador, y el
	# perfecto multiplica (con la zona dorada y la racha dentro, ver
	# Game.note_perfect): los dos son del dedo del jugador, por eso van aqui y no en
	# take_damage() (que es de los Pinchos).
	var dmg := Game.damage_per_hit() * Game.take_charged()
	if perfect:
		var mult := Game.note_perfect(sweet)
		dmg *= mult
		perfect_hit.emit(sweet, mult)
	var crit := false
	if Game.crit_chance() > 0.0 and _rng.randf() < Game.crit_chance():
		crit = true
		dmg *= Game.crit_mult()
	# El sobrante del golpe anterior entra AQUI, ya hecho dano y sin critico: se
	# gano cuando se gano, y volver a multiplicarlo por el critico de este golpe lo
	# haria crecer solo por cambiar de caja. Devuelve 0 si la mejora no esta.
	dmg += Game.take_carry()
	# La vida de ANTES, para saber cuanto ha sobrado de este golpe. Sin esto, el
	# hp queda clavado en cero y el sobrante se pierde, que es justo lo que arregla
	# la mejora EL SOBRANTE NO SE TIRA.
	var before := hp
	hp = maxf(0.0, hp - dmg)
	_tap(crit)
	# El numero sale AQUI, antes de mirar si la caja se ha roto: el golpe que la
	# rompe tambien hace su dano y tambien se tiene que leer.
	#
	# Y sale solo en la redonda del boton, no en take_damage(): los Pinchos pegan
	# cada cuarto de segundo a TODOS los paquetes de la mesa, y un numero por
	# paquete cada cuarto de segundo no se lee, se ve como basura encima de la
	# mesa. La redonda es del jugador; el goteo de los Pinchos ya lo dice la caja
	# agrietandose (ver _refresh_damage_art).
	damaged.emit(dmg, crit)
	if hp <= 0.0:
		# Lo que le ha sobrado a este golpe espera al siguiente sobre (ver
		# Game.keep_carry, que no guarda nada sin la mejora).
		Game.keep_carry(dmg - before)
		broken_by_hit = true
		if _art != null:
			_art.texture = Sprites.tex(str(pack.get("art_open", "pack_cards_open")))
		_finish()
		return
	_refresh_damage_art()
	_ring.modulate = Color.WHITE
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
		_finish()
		return
	_refresh_damage_art()


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
		# cargando a la vez (el cupo de la mesa) es game.gd, no el elemento.
		Game.request_open(self)
	elif state == State.OPENING:
		try_perfect()
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
##
## Un botin que YA se esta vendiendo (el clic arranca una animacion corta y paga
## al final, ver _sell) devuelve 0 y no se toca: su venta ya esta en marcha y la
## paga ella. Antes lo cobraba otra vez aqui, y si la animacion acababa en el
## mismo frame el objeto se pagaba dos veces.
func sell_instant() -> int:
	if state != State.LOOT or _busy:
		return 0
	var value := int(loot.get("value", 0))
	queue_free()
	return value


## Pulsar el sobre mientras carga: en el ultimo trozo del anillo es un GOLPE
## PERFECTO (sale ya y pega PERFECT_MULT, mas en la zona dorada y con racha);
## antes de ese trozo el anillo pierde Gameplay.EARLY_PENALTY de la vuelta y la
## racha se rompe. Devuelve si ha sido perfecto.
func try_perfect() -> bool:
	if state != State.OPENING or _busy:
		return false
	var p := _charge / maxf(0.001, _total)
	if p < Gameplay.PERFECT_FROM:
		if _charge >= EARLY_GRACE:
			_charge = maxf(0.0, _charge - Gameplay.EARLY_PENALTY * _total)
			Game.break_streak()
			early_click.emit()
			if _art != null:
				UIKit.shake(_art)
		return false
	_charge = 0.0
	_strike(true, p >= Gameplay.SWEET_FROM and p < Gameplay.SWEET_TO)
	return true


## Progreso de la carga, de 0 a 1 (para los tests y el frenesi).
func charge_progress() -> float:
	return clampf(_charge / maxf(0.001, _total), 0.0, 1.0) if state == State.OPENING else 0.0


func is_waiting_pack() -> bool:
	return state == State.CLOSED


func is_opening() -> bool:
	return state == State.OPENING


func is_loot() -> bool:
	return state == State.LOOT


## ¿Esta a mitad de algo que ya no se puede parar? (abriendose del todo o
## vendiendose). Quien vende a granel lo mira para no pisar esa venta.
func is_busy() -> bool:
	return _busy
