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
	# Se empieza de CERO, no solo apagando automatizaciones: una partida guardada
	# puede traer items comprados (los Pinchos y el PC, sin ir mas lejos, son los
	# que encienden las automatizaciones y abririan la mesa antes de que el test
	# llegue a pulsarla). smoke_test deja el guardado con todo al maximo, asi que
	# los dos tests se pisarian.
	Game.hard_reset()
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

	# La tienda en cajas y su ficha. Es el camino entero con el raton: el clic en
	# la caja abre la ficha del item, y desde la ficha se compra. El dinero se pone
	# a mano porque una partida nueva no llega a los guantes (900).
	Game.money = 100000
	var caja := _find_tooltip(_main._veil_host, "Ver ficha de GUANTES")
	_check(caja != null, "cada item de la tienda se dibuja como una caja")
	_check(_click(caja), "el clic en la caja llega al boton")
	await _frames(3)
	var ficha := _main._overlay_host.get_child(0)
	_check(ficha != null, "y abre la ficha del item encima de la tienda")
	if ficha != null:
		var nivel_antes: int = Game.item_level(0)
		var comprar := _find_button(ficha, "COMPRAR")
		_check(comprar != null, "la ficha trae el boton de comprar")
		_check(_click(comprar), "el clic en COMPRAR llega al boton")
		await _frames(3)
		_check(Game.item_level(0) == nivel_antes + 1, "y compra la mejora desde la ficha")
		var cerrar_ficha := _find_tooltip(_main._overlay_host, "Cerrar")
		_check(cerrar_ficha != null, "la ficha trae boton de cerrar")
		if cerrar_ficha != null:
			_check(_click(cerrar_ficha), "el clic en cerrar de la ficha llega al boton")
			await _frames(3)
		_check(_main._overlay_host.get_child_count() == 0, "y la ficha se quita de encima")
		_check(_main.has_veil(), "sin cerrar la tienda que hay detras")

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
	# Y al cerrarse el aro sale el numero del golpe. Es la comprobacion del numero
	# de dano que pasa por un clic de verdad: el aro tarda lo suyo en dar la vuelta,
	# asi que hay que esperar a que termine la redonda.
	await _wait(0.7)
	var pops := 0
	for c in game._fx.get_children():
		var n := c as PixelNumber
		if n != null and n.has_meta(DamagePopup.MARK):
			pops += 1
	_check(pops > 0, "y el golpe saca su numero de dano en la mesa")

	print("Tarjeta de revelado:")
	# La caja necesita varios golpes y cada uno es un clic. Lo que prueba ESTE
	# test es que el clic llega al boton (arriba queda comprobado), asi que las
	# pulsaciones que faltan se hacen con start_opening() hasta que salga la
	# tarjeta.
	var clicks := 0
	while game._reveal == null and clicks < 40:
		if is_instance_valid(el) and el.can_open():
			el.start_opening()
		await _wait(0.3)
		clicks += 1
	var card: Node = game._reveal
	_check(card != null, "el paquete se abre al insistir y sale la tarjeta")
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
		LootDB.roll_pack(RandomNumberGenerator.new(), "electronics"))
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

	print("Zona de sobres:")
	var celdas: Array = game._pack_cells
	_check(celdas.size() == LootDB.pack_count(), "la columna trae los doce sobres")
	if not celdas.is_empty():
		# Esta es la compra de verdad: un clic en la columna de la izquierda, sin
		# abrir ningun panel de por medio. La primera celda es SOBRES, el sobre
		# inicial, que no cuesta nada.
		var antes: int = game.table_count()
		var dinero: int = Game.money
		_check(_click(celdas[0]["button"]),
			"el clic en el sobre de la izquierda llega al boton")
		await _frames(3)
		_check(game.table_count() == antes + 1, "el sobre comprado cae en la mesa")
		_check(Game.money == dinero, "el sobre inicial es gratis: no cobra nada")

		# La rueda del raton sobre la lista. Se manda el giro justo encima de una
		# fila (que es donde se usa) y no en el hueco de al lado, que es el caso que
		# importa: si el boton de la fila se comiera el evento, no habria scroll a
		# mano.
		var scroll: ScrollContainer = game._pack_scroll
		var quieto: int = scroll.scroll_vertical
		_wheel(game.PACK_ZONE.get_center(), MOUSE_BUTTON_WHEEL_DOWN)
		await _frames(4)
		_check(scroll.scroll_vertical > quieto, "la rueda recorre la lista de sobres")
		_check(scroll.scroll_vertical
			<= int(scroll.get_v_scroll_bar().max_value),
			"y no se pasa del final de la lista")


	print("Compra automatica:")
	# Con la partida recien empezada no hay PC, asi que el boton esta BLOQUEADO:
	# el clic tiene que llegar igual (es lo unico que permite explicar que falta)
	# pero no puede abrir nada.
	var auto_btn := _find_tooltip(game,
			"Compra automatica (con el PC): elige que sobres se compran solos")
	_check(auto_btn != null, "el boton de la compra automatica existe")
	_check(_click(auto_btn), "el clic en el boton bloqueado llega igual")
	await _frames(3)
	_check(not _main.has_veil(), "bloqueado no abre el mini menu")

	# Con los PINCHOS el boton sigue bloqueado: esa es la pieza de la apertura, no
	# la de la compra. Es la comprobacion que se rompe sola si alguien vuelve a
	# juntar las dos piezas en un mismo candado.
	Game.money = 100000000
	Game.buy_item(LootDB.item_index("pinchos"))
	_check(_click(auto_btn), "con los Pinchos el clic llega igual")
	await _frames(3)
	_check(not _main.has_veil(), "pero no abre nada: el PC es la otra pieza")

	# Con el PC, el mismo boton abre su lista.
	Game.buy_item(LootDB.item_index("pc"))
	_check(_click(auto_btn), "con el PC el clic llega al boton")
	await _frames(3)
	_check(_main.has_veil(), "y abre el mini menu de la compra automatica")
	var panel: Node = null
	for c in _main._veil_host.get_children():
		if c is AutoBuyPanel:
			panel = c
	_check(panel != null, "el panel abierto es el de la compra automatica")
	if panel != null:
		# El sobre gratuito no entra en la lista: la compra automatica lo salta
		# siempre, asi que una casilla suya no haria nada.
		_check(panel._cells.size() == LootDB.pack_count() - 1,
			"la lista trae los once sobres de pago")
		# Un clic en una fila marca o desmarca ese sobre: es la unica forma de
		# decir QUE se compra solo.
		var marcados: int = Game.auto_buy_packs.size()
		_check(_click(panel._cells[0]["button"]),
			"el clic en una fila de la lista llega")
		await _frames(2)
		_check(Game.auto_buy_packs.size() == marcados - 1,
			"esa fila deja de comprarse sola")
		_check(_click(panel._cells[0]["button"]),
			"el clic otra vez llega igual")
		await _frames(2)
		_check(Game.auto_buy_packs.size() == marcados,
			"y la vuelve a marcar")
		var cerrar := _find_tooltip(_main._veil_host, "Cerrar")
		_check(cerrar != null and _click(cerrar), "el mini menu tiene cerrar")
		await _frames(3)
		_check(not _main.has_veil(), "y el cerrar cierra el mini menu")

	print("Armario:")
	# Hacen falta las dos cosas: la pieza (sin armario no hay vitrina donde
	# exponer) y algo guardado. El objeto se mete con Game.store y no jugando,
	# porque lo que prueba esta seccion es el panel, no la tirada.
	Game.store(LootDB.roll_pack(RandomNumberGenerator.new(), "cards"))
	Game.buy_item(LootDB.item_index("armario"))
	await _frames(3)
	_check(Game.locker_slots() == 1, "el armario comprado da su primer hueco")

	# El boton de la barra de arriba. Va buscado por su tooltip y no por el
	# texto: la tira de la vitrina tiene otra chapa que tambien dice ARMARIO, y
	# con el texto a secas el test podria estar pulsando la otra.
	var locker_btn := _find_tooltip(game,
			"Armario: expone objetos y da sus bonus (con la pieza comprada)")
	_check(locker_btn != null, "el boton del armario esta en la barra")
	_check(_click(locker_btn), "el clic en el boton del armario llega")
	await _frames(3)
	_check(_main.has_veil(), "y abre el panel del armario")
	var armario: Node = null
	for c in _main._veil_host.get_children():
		if c is LockerPanel:
			armario = c
	_check(armario != null, "el panel abierto es el del armario")
	if armario != null:
		# Exponer es un clic en un hueco del inventario: el objeto sale de la
		# rejilla de la izquierda y aparece en la vitrina de la derecha.
		var guardado: int = Game.inventory.size()
		_check(guardado > 0, "hay algo guardado que exponer")
		_check(_click(armario._inv_cells[0]["button"]),
			"el clic en un hueco del inventario llega")
		await _frames(3)
		_check(Game.locker.size() == 1 and Game.inventory.size() == guardado - 1,
			"y expone el objeto: sale del inventario y entra en el armario")
		# Y la vuelta: exponer no puede ser una decision sin deshacer.
		_check(_click(armario._locker_cells[0]["button"]),
			"el clic en la vitrina llega")
		await _frames(3)
		_check(Game.locker.is_empty() and Game.inventory.size() == guardado,
			"y devolverlo lo saca del armario y lo devuelve al inventario")
		# VENDER TODO es la unica forma de vaciar el inventario desde que vive
		# aqui y no en la pantalla de partida.
		var money_inv: int = Game.money
		var vender_todo := _find_button(armario, "VENDER TODO")
		_check(vender_todo != null, "el panel del armario trae VENDER TODO")
		_check(_click(vender_todo), "el clic en VENDER TODO llega al boton")
		await _frames(3)
		_check(Game.inventory.is_empty(), "y vende de golpe lo que hay en el inventario")
		_check(Game.money > money_inv, "pagando su valor")
		var cerrar_arm := _find_tooltip(_main._veil_host, "Cerrar")
		_check(cerrar_arm != null, "el panel del armario trae boton de cerrar")
		if cerrar_arm != null:
			_check(_click(cerrar_arm), "el clic en cerrar del armario llega al boton")
			await _frames(3)
			_check(not _main.has_veil(), "y el cerrar cierra el panel del armario")

	print("Menu otra vez:")
	_main.show_menu()
	await _frames(3)

	# La hucha: el requisito se mide en lo GANADO en la partida y una partida de
	# prueba no llega al millon jugando, asi que se pone a mano. Es una variable
	# del estado, no un atajo del panel: el panel lee lo mismo que lee el boton.
	Game.lifetime_earned = LootDB.REBIRTH_REQUIRE
	await _frames(2)
	var rebirth_btn := _find_button(_main._screen_host, "REBIRTH")
	_check(rebirth_btn != null, "el menu trae el boton de REBIRTH")
	_check(_click(rebirth_btn), "el clic en REBIRTH llega al boton")
	await _frames(3)
	var hucha: Node = null
	for c in _main._veil_host.get_children():
		if c is RebirthPanel:
			hucha = c
	_check(hucha != null, "y abre el panel de la hucha")
	if hucha != null:
		# El premio que ENSEÑA el panel y el que DA el rebirth tienen que ser el
		# mismo numero: sale del mismo calculo, y aqui se comprueba de verdad
		# pulsando el boton.
		var premio: int = Game.pending_rebirth_coins()
		_check(premio >= 1, "el panel promete al menos una moneda")
		var monedas_antes: int = Game.rebirth_coins
		_check(_click(hucha._go), "el clic en REBIRTH del panel llega al boton")
		await _frames(3)
		_check(Game.rebirth_coins == monedas_antes + premio,
			"y reinicia la partida dando las monedas que prometia el panel")
		_check(Game.lifetime_earned == 0 and not Game.can_rebirth(),
			"la partida vuelve a cero: el requisito hay que ganarselo otra vez")
		_check(not _main.has_veil(), "y el panel se cierra solo al reiniciar")

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


## Un giro de rueda. Va aparte de _click porque el scroll no se prueba con un
## clic: lo que se comprueba es que el evento LLEGA al ScrollContainer.
##
## Se mandan las DOS mitades, pulsar y soltar, y no es un detalle. El Viewport
## se queda con el control que recibe la pulsacion del raton (mouse_focus) hasta
## que ve el suelte; un giro que solo pulsa deja el raton pegado al
## ScrollContainer, y a partir de ahi el ScrollContainer se come TODOS los clics
## de la pantalla y ningun boton vuelve a responder. En X11 el giro llega como
## ButtonPress Y ButtonRelease (los botones 4 y 5), y Godot los pasa los dos; en
## la prueba hay que hacer lo mismo o el test se inventa un fallo que no existe.
func _wheel(at: Vector2, button: int) -> void:
	for pulsar in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pulsar
		e.factor = 1.0
		e.position = at
		e.global_position = at
		get_viewport().push_input(e, true)


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
