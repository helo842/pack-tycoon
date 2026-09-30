# input_test - el test del RATON.
#
# smoke_test.gd recorre el bucle entero, pero lo hace llamando a los metodos a
# mano (`shop._on_pack(...)`), asi que nunca pasa un clic de verdad por el
# sistema de interfaz. Ese hueco dejo pasar un fallo gordo: la interfaz se veia,
# smoke_test salia en verde y ningun boton respondia, porque los contenedores de
# main.gd se comian todos los clics. Este test manda clics sinteticos con
# Viewport.push_input() y comprueba que el boton los recibe.
#
# COMO SE MANDAN LOS CLICS
# ------------------------
# push_input(evento, true): el `true` es in_local_coords, o sea que la posicion
# va en coordenadas del viewport (las mismas que devuelve get_global_rect()), y
# NO en coordenadas de la ventana. Con `false` Godot pasa el punto por la
# transformacion de estirado y el clic cae en otro sitio: en una ventana de
# 1280x720 sobre un diseno de 1920x1080 se va a un punto y medio de distancia.
# Ese detalle hace que un test mal escrito diga que los botones no funcionan
# cuando el que esta mal es el test.
class_name InputTest
extends Node

const MAIN := preload("res://scenes/Main.tscn")

var _fails: int = 0
var _main: MainRoot = null


func _ready() -> void:
	await _run()
	print("RATON: %s" % ("todo correcto." if _fails == 0 else "%d fallos." % _fails))
	# Al parar una voz, quien suelta su WAV es el hilo de audio. Si se sale en el
	# mismo frame, el motor avisa de recursos sin soltar al salir. Ver
	# Sound.stop_all(). El juego de verdad lo hace en Game._on_close().
	Sound.stop_all()
	# Tiempo REAL, no frames: en headless un frame dura casi nada y el hilo de
	# audio mezcla por su cuenta, asi que tres frames no le dan ni una vuelta.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  OK    ", what)
	else:
		_fails += 1
		print("  MAL   ", what)


func _run() -> void:
	# Una partida guardada de una sesion anterior puede venir con la autoventa y
	# las automatizaciones encendidas, y entonces el paquete se abriria solo y no
	# habria tarjeta que pulsar.
	Game.set_auto_sell(false)
	Game.set_auto_open(false)
	Game.set_auto_buy(false)
	_main = MAIN.instantiate() as MainRoot
	add_child(_main)
	await _frames(3)

	print("Menu:")
	var play := _find_button(_main._screen_host, "JUGAR")
	_check(play != null, "el boton JUGAR existe")
	_check(_click(play), "el clic en JUGAR llega al boton")
	await _frames(3)
	_check(_main._current != null and _main._current.name == "Game",
		"JUGAR cambia a la pantalla de partida")

	print("Partida:")
	var shop := _find_button(_main._current, "TIENDA")
	_check(shop != null, "el boton TIENDA existe")
	_check(_click(shop), "el clic en TIENDA llega al boton")
	await _frames(3)
	_check(_main.has_veil(), "TIENDA abre su panel")

	# El boton de cerrar no tiene texto: se busca por su tooltip.
	var close := _find_tooltip(_main._veil_host, "Cerrar")
	_check(close != null, "el panel trae boton de cerrar")
	if close != null and _click(close):
		await _frames(3)
		_check(not _main.has_veil(), "el boton de cerrar cierra el panel")

	# La mesa: el clic que abre un paquete. Es la interaccion principal del
	# juego y va por otro camino distinto al de las chapas (el elemento de la
	# mesa es un Control con zona de clic invisible encima).
	# `Node` y no el tipo real: asi se puede llamar a lo interno de game.gd sin
	# que el analizador de tipos se queje, que es lo que hace smoke_test.
	var game: Node = _main._current
	# Hay que dejarle ATERRIZAR. El objeto entra cayendo desde arriba y mientras
	# cae su zona de clic esta 260 px mas arriba de donde acaba, o sea en la barra
	# superior, que va por encima de la mesa y se come el clic. Sin esta espera el
	# test dice que la mesa no responde cuando el que no ha esperado es el test.
	var el: TableElement = game._spawn_pack("cards")
	await _wait(0.8)
	var hit := _find_tooltip(el, "Abrir " + str(LootDB.pack_by_id("cards").get("name", "")))
	_check(hit != null, "el paquete de la mesa tiene zona de clic")
	_check(_click(hit), "el clic en el paquete llega a la mesa")
	await _frames(3)
	_check(el.state == TableElement.State.OPENING, "el paquete empieza a abrirse")

	print("Tarjeta de revelado:")
	await _wait(2.2)
	var card: Node = game._reveal
	_check(card != null, "el paquete se abre solo y sale la tarjeta")
	if card != null:
		_check(_find_button(card, "GUARDAR") != null, "la tarjeta trae el boton GUARDAR")
		var vender := _find_button(card, "VENDER")
		_check(vender != null, "la tarjeta trae el boton VENDER")
		if vender != null:
			_check(_click(vender), "el clic en VENDER llega al boton")
			await _frames(3)
			_check(game._reveal == null, "VENDER cierra la tarjeta")
			_check(game.table_count() == 0, "VENDER quita el objeto de la mesa")

	print("Arrastrar por la mesa:")
	var botin: TableElement = game._spawn_loot(
		LootDB.roll_pack(RandomNumberGenerator.new(), "vinyls"))
	# Hay que dejarle aterrizar: mientras cae lo mueve el tween de la entrada, no
	# el raton.
	await _wait(0.9)
	# Y se le pone en un sitio conocido: el objeto nace en un punto al azar de la
	# mesa, y si naciera pegado a un borde el arrastre de abajo lo frenarian los
	# limites y la prueba diria que el raton y el objeto se han separado.
	var rincon: Vector2 = game.TABLE_RECT.position + Vector2(60, 60)
	botin._move_to(rincon)
	await _frames(2)
	var desde: Vector2 = botin.get_global_rect().get_center()
	_drag(desde, desde + Vector2(260, 130))
	await _wait(0.4)
	_check(botin.position.distance_to(rincon + Vector2(260, 130)) < 4.0,
		"el objeto se queda pegado al raton")
	# La venta tarda 0,28 s en desaparecer: se espera para que, si el arrastre se
	# hubiera tomado por un clic, la mesa ya estuviera vacia y se viera aqui.
	_check(botin.state == TableElement.State.LOOT,
		"soltar tras arrastrar no vende el botin")
	_check(game.table_count() == 1, "el objeto arrastrado sigue en la mesa")

	print("Menu otra vez:")
	_main.show_menu()
	await _frames(3)
	var settings := _find_button(_main._screen_host, "AJUSTES")
	_check(_click(settings), "el clic en AJUSTES llega al boton")
	await _frames(3)
	_check(_main.has_veil(), "AJUSTES abre su panel")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Espera de reloj de verdad: el anillo de apertura cuenta segundos, no frames, y
## en headless los frames duran casi nada.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Un arrastre completo: pulsar sobre el objeto, mover el raton a trozos y
## soltar. Se mueve en pasos y no de un salto porque el objeto sigue al raton: si
## el raton se fuera de golpe mucho mas alla, el movimiento cae fuera del objeto
## y el objeto (que todavia no se ha movido) no lo recibe.
func _drag(from: Vector2, to: Vector2, steps: int = 13) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	down.global_position = from
	get_viewport().push_input(down, true)
	for i in range(1, steps + 1):
		var at := from.lerp(to, float(i) / float(steps))
		var m := InputEventMouseMotion.new()
		m.position = at
		m.global_position = at
		m.relative = at - from.lerp(to, float(i - 1) / float(steps))
		get_viewport().push_input(m, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	up.global_position = to
	get_viewport().push_input(up, true)


## Un clic completo (raton -> pulsar -> soltar) sobre el centro del boton.
## Devuelve si el boton llego a emitir `pressed`.
func _click(b: Button) -> bool:
	if b == null:
		return false
	var at: Vector2 = b.get_global_rect().get_center()
	# Array y no un bool: las lambdas de GDScript copian los locales, asi que un
	# bool de fuera nunca cambiaria. El array si es la misma referencia.
	var got := [false]
	var cb := func() -> void: got[0] = true
	b.pressed.connect(cb)
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	get_viewport().push_input(m, true)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	get_viewport().push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	up.global_position = at
	get_viewport().push_input(up, true)
	if b.pressed.is_connected(cb):
		b.pressed.disconnect(cb)
	return got[0]


## Los botones con texto (plate_button y small_button) llevan una Label hija:
## se localizan por el texto de esa etiqueta.
func _find_button(n: Node, text: String) -> Button:
	if n is Button:
		for c in n.get_children():
			if c is Label and (c as Label).text == text:
				return n
	for c in n.get_children():
		var found := _find_button(c, text)
		if found != null:
			return found
	return null


func _find_tooltip(n: Node, tip: String) -> Button:
	if n is Button and (n as Button).tooltip_text == tip:
		return n
	for c in n.get_children():
		var found := _find_tooltip(c, tip)
		if found != null:
			return found
	return null
