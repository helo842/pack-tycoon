# Player - el jugador, que ahora es una persona en la trastienda.
#
# Antes no habia nadie: la camara era un punto fijo mirando la mesa y todo lo
# demas era interfaz. Ahora hay un cuerpo que anda por la habitacion, una cabeza
# que gira y una mira con la que se apunta a las cosas. El juego sigue siendo el
# mismo -los sobres, los items, la hucha-, pero hay que IR a por el.
#
# LAS TECLAS VAN EN EL CODIGO (ver ensure_actions) y no en project.godot. No es
# por capricho: son cinco acciones y escribirlas a mano en el fichero del
# proyecto es anadir cuarenta lineas de Object(InputEventKey,...) que nadie
# puede leer, para algo que se cambia una vez. Aqui se ven de un golpe y
# funcionan igual en las pruebas, que es donde importa.
#
# LA MIRA ES UN PUNTO DE PANTALLA, y ese es el detalle que deja todo lo demas
# como estaba. El juego de la mesa (game.gd) siempre ha mirado la mesa por RAYO
# desde un punto de la pantalla; con el raton capturado ese punto es el centro
# (la mira), asi que toda la mesa -el clic que abre, el arrastre, los numeros de
# dano- sigue funcionando sin tocar una linea. Y al arrastrar un objeto la mira
# se mueve con el raton y la camara se queda quieta: se agarra la carta y se
# mueve, en vez de girar la cabeza con la carta en la mano.
class_name Player
extends CharacterBody3D

## El jugador ha entrado en una accion y sigue teniendo la mira puesta. No se
## usa para el juego (quien mueve el dinero es game.gd), solo para las pruebas.
## La pista de que se ha usado algo.
signal used(what)

## Los ojos, sobre el origen del cuerpo. El cuerpo esta tumbado en el suelo, asi
## que esto es tambien la altura del jugador menos el radio del pie.
const EYE := 0.45
const RADIUS := 0.18
const HEIGHT := 1.20

## Andar y correr, en unidades por segundo. 1.5 son 1,5 m/s a escala humana: la
## sala mide 18x15 y se cruza en unos doce segundos, que es lo que se tarda en
## ir de la maquina a la vitrina.
const SPEED := 1.5
const SPRINT := 2.4
const ACCEL := 9.0

## Cuanto gira la cabeza por pixel de raton.
const LOOK_SENS := 0.0022
const PITCH_MAX := 84.0

## El vaiven al andar: la cabeza sube y baja un poco y cada bajada suena.
const BOB_SPEED := 11.0
const BOB := 0.02
const GRAVITY := 8.0

## Hasta donde llega la mira, en unidades. Mas alla de esto no se coge nada: el
## cartel de un cacharro que se ve al fondo de la sala no tiene que aparecer.
const RANGE := 3.6

var camera: Camera3D
## Lo que hay en la mira ahora mismo, o null.
var focus: Interactable = null
## Una pantalla esta abierta: el jugador no anda ni gira la cabeza.
var locked := false
## Se esta arrastrando un objeto de la mesa: la camara se queda quieta y la mira
## se mueve con el raton.
var dragging := false
## El jugador esta clavado en el sitio aunque no haya ninguna pantalla: es lo
## que pasa mientras se decide la tarjeta de revelado, que sale flotando delante
## de la cara. Se distingue de `locked` en que ahi la camara VIAJA hasta el
## cacharro y aqui no se mueve de donde esta.
var frozen := false

var _head: Node3D
var _yaw := 0.0
var _pitch := 0.0
## El punto de pantalla de la mira, en pixeles del viewport.
var _aim := Vector2.ZERO
var _bob_t := 0.0
var _bob_side := false
var _stations: Array = []
var _vp_size := Vector2(1920, 1080)
## Si el puntero esta libre (ver capture_mouse).
var _cursor_free := false

## De donde venia el jugador antes de pegarse a una pantalla, para devolverlo
## ahi al cerrarla.
var _back_pos := Vector3.ZERO
var _back_yaw := 0.0
var _back_pitch := 0.0


# --------------------------------------------------------------------------- #
# Teclas
# --------------------------------------------------------------------------- #

## Crea las acciones si no estan. Se puede llamar las veces que haga falta: sin
## esto, un proyecto recien clonado andaria con WASD y no con lo que diga nadie,
## y las pruebas no tendrian como pulsar nada.
static func ensure_actions() -> void:
	_bind("move_forward", KEY_W)
	_bind("move_back", KEY_S)
	_bind("move_left", KEY_A)
	_bind("move_right", KEY_D)
	_bind("sprint", KEY_SHIFT)
	_bind("interact", KEY_E)


static func _bind(action: String, key: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	var e := InputEventKey.new()
	# Por CODIGO FISICO y no por tecla: asi WASD sigue siendo el cuadrado de la
	# izquierda en un teclado AZERTY, que es donde esta la mano.
	e.physical_keycode = key
	InputMap.action_add_event(action, e)


# --------------------------------------------------------------------------- #
# Montaje
# --------------------------------------------------------------------------- #

## Las cosas a las que se les puede mirar. Las pone la sala (ver room.gd).
func setup(stations: Array) -> void:
	_stations = stations


func _ready() -> void:
	ensure_actions()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	shape.shape = cap
	add_child(shape)

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, EYE, 0.0)
	add_child(_head)

	camera = Camera3D.new()
	camera.name = "Eye"
	camera.fov = 70.0
	# Cerca de 3 cm: con la camara a 1,20 del suelo y las cosas a un palmo (el
	# cartel de una estacion), un plano cercano de 10 cm se come la mitad.
	camera.near = 0.03
	camera.far = 300.0
	camera.current = true
	_head.add_child(camera)

	_vp_size = Vector2(get_viewport().get_visible_rect().size)
	_aim = _vp_size * 0.5
	capture_mouse(true)


## El raton, capturado o libre. Libre mientras hay una pantalla delante (para
## poder pulsar en ella, que se hace con el puntero) y capturado para andar.
##
## El estado se guarda AQUI y no se le pregunta a Input.mouse_mode: en headless
## (que es como corren los tests) no hay ventana y el modo que contesta el
## servidor de pantalla es siempre el que estaba, asi que preguntarselo dejaria
## la cabeza sin girar justo en las pruebas.
func capture_mouse(on: bool) -> void:
	_cursor_free = not on
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE)


func mouse_is_free() -> bool:
	return _cursor_free


# --------------------------------------------------------------------------- #
# Andar
# --------------------------------------------------------------------------- #

func _physics_process(delta: float) -> void:
	_update_focus()
	if locked or frozen or dragging:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var dir := (transform.basis * Vector3(v.x, 0.0, v.y))
		dir.y = 0.0
		dir = dir.normalized()
		var speed := SPRINT if Input.is_action_pressed("sprint") else SPEED
		velocity.x = move_toward(velocity.x, dir.x * speed, ACCEL * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, ACCEL * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_bob_step(delta)


## El vaiven de la cabeza: sube y baja al andar y suena cada vez que toca abajo.
## Es medio carton de sonido -el juego no tiene pasos grabados y `sfx_click` a
## volumen bajo hace de zapato- pero es lo que dice que te estas moviendo cuando
## la camara no tiene nada cerca.
func _bob_step(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.05 or locked or frozen:
		_bob_t = lerpf(_bob_t, 0.0, 8.0 * delta)
	else:
		_bob_t += delta * BOB_SPEED * (speed / SPEED)
		if fmod(_bob_t, TAU) < PI:
			if not _bob_side:
				_bob_side = true
				Sound.play("sfx_click", -26.0, randf_range(0.7, 0.85))
		else:
			_bob_side = false
	_head.position.y = EYE + sin(_bob_t) * BOB


# --------------------------------------------------------------------------- #
# Mirar
# --------------------------------------------------------------------------- #

## Gira la cabeza. Lo llama game.gd y NO el motor, a proposito: el jugador vive
## dentro del SubViewport del mundo, y ahi no llega el raton de la ventana (cada
## viewport tiene su propia lista de nodos con input). El que reparte es la
## pantalla de juego, que si esta en el viewport de verdad, y le pasa al jugador
## solo lo que le toca.
##
## Devuelve si ha girado algo: no gira con una pantalla delante (el puntero esta
## libre), ni arrastrando una carta (lo que se mueve es la carta), ni con la
## tarjeta de revelado en la cara (que se decide con el puntero).
func look(relative: Vector2) -> bool:
	if locked or frozen or dragging or mouse_is_free():
		return false
	_yaw -= relative.x * LOOK_SENS
	_pitch = clampf(_pitch - relative.y * LOOK_SENS,
			-deg_to_rad(PITCH_MAX), deg_to_rad(PITCH_MAX))
	rotation.y = _yaw
	_head.rotation.x = _pitch
	return true


## Al salir de la partida (volver al menu) se suelta el raton: el menu es una
## pantalla normal con su puntero, y sin esto se quedaria capturado para siempre.
func _exit_tree() -> void:
	capture_mouse(false)


## El jugador pulsa la tecla: lo que tenga en la mira.
func use_focus() -> void:
	if focus == null or not is_instance_valid(focus):
		return
	if not focus.can_use():
		Sound.play("sfx_error")
		return
	focus.use(self)
	used.emit(focus)


# --------------------------------------------------------------------------- #
# La mira
# --------------------------------------------------------------------------- #

## El punto de pantalla al que apunta la mira. Es el centro, salvo mientras se
## arrastra una carta, que sigue al raton.
func aim() -> Vector2:
	return _aim


## Se agarra algo de la mesa: la mira vuelve al centro (donde estaba el raton al
## pulsar) y a partir de ahi se mueve con el.
func begin_drag() -> void:
	dragging = true
	_aim = _vp_size * 0.5


## El raton se ha movido mientras se arrastra. Se mueve la MIRA, no la camara.
func drag_aim(relative: Vector2) -> void:
	_aim = (_aim + relative).clamp(Vector2(4, 4), _vp_size - Vector2(4, 4))


func end_drag() -> void:
	dragging = false
	_aim = _vp_size * 0.5


## ¿Cuanto mide el viewport? Lo necesitan las pruebas para clicar en el centro.
func viewport_size() -> Vector2:
	return _vp_size


func eye() -> Camera3D:
	return camera


## Un rayo desde la camara por un punto de la pantalla, para quien tenga que
## preguntar que hay ahi (la mesa lo hace, y las pantallas tambien).
func ray_from(screen: Vector2) -> Array:
	return [camera.project_ray_origin(screen), camera.project_ray_normal(screen)]


# --------------------------------------------------------------------------- #
# Foco
# --------------------------------------------------------------------------- #

## Lo que hay en la mira ahora mismo. Se mira por RAYO y se queda lo mas cercano,
## que es lo que hace que una maquina tape a la pared que tiene detras.
func _update_focus() -> void:
	if locked:
		return
	var rays := ray_from(_aim)
	var from: Vector3 = rays[0]
	var dir: Vector3 = rays[1]
	var best: Interactable = null
	var best_d := INF
	for s in _stations:
		if not is_instance_valid(s):
			continue
		var hit = (s as Interactable).pick_box().intersects_ray(from, dir)
		if hit == null:
			continue
		var d: float = from.distance_to(hit)
		if d < best_d and d <= RANGE:
			best_d = d
			best = s
	_set_focus(best)


func _set_focus(next: Interactable) -> void:
	if next == focus:
		return
	if focus != null and is_instance_valid(focus):
		focus.focus_exit()
	focus = next
	if focus != null:
		focus.focus_enter()


# --------------------------------------------------------------------------- #
# Pegarse a una pantalla
# --------------------------------------------------------------------------- #

## El jugador se pone delante de una estacion para usar su pantalla. La camara
## se COLOCA de golpe y no se desliza: el viaje de la camara hasta la maquina
## dura un cuarto de segundo y lo unico que consigue es que el jugador no sepa
## cuando ha llegado. Se guarda de donde venia para devolverlo ahi al cerrar.
func lock_on(from: Vector3, at: Vector3) -> void:
	if locked:
		return
	locked = true
	_back_pos = global_position
	_back_yaw = rotation.y
	_back_pitch = _head.rotation.x
	velocity = Vector3.ZERO
	# LA ALTURA NO SE TOCA, y es el detalle que hace que un panel se vea entero.
	# El jugador anda por el suelo de la sala y no flota: se pone en la HORIZONTAL
	# del sitio de la vista (x, z) y mira al centro del cristal DESDE LOS OJOS que
	# ya tiene. Subiendolo a la altura del cristal pasaba una cosa que no se ve en
	# el codigo: la gravedad lo bajaba en el mismo frame, la camara acababa
	# mirando por DEBAJO de la pantalla y los botones de la parte de arriba del
	# panel se salian del encuadre. Se podian pulsar con el rayo -los clics
	# llegaban-, pero el jugador no los veia: medio panel invisible.
	global_position = Vector3(from.x, global_position.y, from.z)
	_head.position.y = EYE
	var eyes := global_position + Vector3(0.0, EYE, 0.0)
	var dir := (at - eyes)
	if dir.length() < 0.001:
		dir = Vector3(0, 0, -1)
	dir = dir.normalized()
	_yaw = atan2(-dir.x, -dir.z)
	_pitch = asin(clampf(dir.y, -1.0, 1.0))
	rotation.y = _yaw
	_head.rotation.x = _pitch
	_bob_t = 0.0
	capture_mouse(false)


## Clava al jugador donde esta y le suelta el puntero, sin moverlo de sitio.
## Es para lo que sale delante de la cara (la tarjeta de revelado).
func freeze(on: bool) -> void:
	frozen = on
	if on:
		velocity = Vector3.ZERO
	capture_mouse(not on)


func unfreeze() -> void:
	freeze(false)


## Devuelve al jugador a un sitio mirando a un punto. Lo usan las PRUEBAS, para
## empezar cada trozo en el mismo estado en vez de arrastrar el de antes (y no
## tener que andar por la sala entera en cada seccion).
func teleport(to: Vector3, look: Vector3) -> void:
	global_position = to
	velocity = Vector3.ZERO
	look_at_world(look)


## Apunta la camara a un punto del mundo. NO lo usa el juego (para eso esta el
## raton): lo usan las pruebas, que no tienen raton y necesitan mirar a la mesa
## igual que la mira un dedo.
func look_at_world(point: Vector3) -> void:
	var d := point - camera.global_position
	if d.length() < 0.001:
		return
	d = d.normalized()
	_yaw = atan2(-d.x, -d.z)
	_pitch = asin(clampf(d.y, -1.0, 1.0))
	rotation.y = _yaw
	_head.rotation.x = _pitch


func unlock() -> void:
	if not locked:
		return
	locked = false
	global_position = _back_pos
	rotation.y = _back_yaw
	_head.rotation.x = _back_pitch
	_yaw = _back_yaw
	_pitch = _back_pitch
	velocity = Vector3.ZERO
	capture_mouse(true)
