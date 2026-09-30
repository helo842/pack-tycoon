# screenshots - guarda un PNG de cada pantalla en user://shots/.
# Arranca el juego de verdad, va pasando por todas las pantallas y guarda un PNG
# de cada una, para revisarlas sin tener delante la pantalla del usuario.
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const REVEAL_SCENE := preload("res://scenes/RevealCard.tscn")
const OUT := "user://shots/"

## Las capturas se hacen dentro de un SubViewport de 1920x1080 y no de la
## ventana. La ventana la coloca el gestor de ventanas del escritorio (3840x1080
## en dos monitores) y la deja en 948x533, o sea el juego entero a la mitad de
## resolucion: el texto salia borroso y no se podia ni leer un nombre. En el
## SubViewport el PNG sale 1:1 con el diseño, que es como hay que revisarlo.
const SHOT_SIZE := Vector2i(1920, 1080)

var _main: MainRoot = null
var _vp: SubViewport = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_vp = SubViewport.new()
	_vp.size = SHOT_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	add_child(_vp)
	_run()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	var img := _vp.get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("captura: ", name, " ", img.get_width(), "x", img.get_height())


func _screen() -> Node:
	for c in _main._screen_host.get_children():
		if c.has_method("_spawn_pack"):
			return c
	return null


## Pone un item del paquete "pack" con la nota "nota" en la tarjeta de revelado y
## guarda una captura. Se usa para ver de un vistazo que el sprite lleva el
## desgaste: la misma carta con nota 1 y con nota 10 tienen que verse distintas.
func _volcar_caso(nombre: String, pack: String, nota: int, item_id: String = "") -> void:
	var item: Dictionary = LootDB.roll_item(RandomNumberGenerator.new(), pack)
	if item_id != "":
		# Para ver un objeto concreto: la tirada es aleatoria y no sirve para
		# comprobar que un sprite nuevo sale bien en la tarjeta.
		for candidato in LootDB.pack_by_id(pack)["loot"]:
			if candidato["id"] == item_id:
				item = candidato.duplicate(true)
	item["grade"] = nota
	item["art"] = LootDB.art_for(item, nota)
	item["condition"] = LootDB.condition_for_grade(nota)
	item["value"] = LootDB.final_value(item, nota)
	var card := REVEAL_SCENE.instantiate() as RevealCard
	card.show_item(item)
	# La tarjeta ya no se cierra sola: dice que se ha decidido (guardar, vender o
	# dejar) y se borra sola al emitirlo. Aqui solo hay que sacarla de la capa.
	card.resolved.connect(_on_card_resolved)
	_main.push_overlay(card)
	await _frames(4)
	await _wait(0.7)
	print("  volcando %s -> %s nota %d" % [nombre, card.item["art"], card.item["grade"]])
	await _shot(nombre)
	card._dismiss()
	await _frames(3)
	await _wait(0.3)


## La tarjeta ha dicho que se ha decidido con el objeto: hay que quitarla de la
## capa, o se queda encima de la pantalla al hacer la siguiente captura.
func _on_card_resolved(_action: String) -> void:
	for c in _main._overlay_host.get_children():
		_main.pop_overlay(c)


func _run() -> void:
	Game.hard_reset()
	_main = MAIN_SCENE.instantiate() as MainRoot
	_vp.add_child(_main)
	await _frames(5)
	await _wait(0.4)
	await _shot("01_menu")

	# Ajustes desde el menu
	var menu := _main._screen_host.get_child(0)
	menu._on_settings()
	await _frames(4)
	await _shot("02_settings")
	for c in _main._veil_host.get_children():
		_main.pop_veil(c)
	await _frames(2)

	# Partida
	_main.show_game()
	await _frames(5)
	await _wait(0.4)
	var g = _screen()
	await _shot("03_game")

	# Tienda
	g._open_shop()
	await _frames(4)
	await _shot("04_shop")

	# Comprar y ver el paquete en la mesa
	Game.money = 900000
	g._shop._on_pack("electronics")
	await _frames(2)
	g._close_shop()
	await _frames(4)
	g._spawn_pack("cards")
	g._spawn_pack("vinyls")
	await _wait(1.2)
	await _shot("05_table")

	# La mesa con objetos de verdad repartidos: es donde se ve si el sorteo de
	# sitio los reparte o los apila, y si la mesa tiene superficie.
	for i in 5:
		g._spawn_loot(LootDB.roll_pack(RandomNumberGenerator.new(), "cards"))
	await _wait(1.2)
	await _shot("05b_mesa_llena")

	# Apertura a media carga, para ver el anillo
	var el: TableElement = g._elements[0]
	el.start_opening()
	await _wait(0.5)
	await _shot("06_opening")

	# Tarjeta de revelado
	await _wait(3.5)
	await _shot("07_reveal")
	if g._reveal != null:
		g._reveal._dismiss()
	await _frames(4)
	await _wait(1.0)

	# Mesa con botin + inventario
	Game.store(LootDB.roll_pack(RandomNumberGenerator.new(), "vinyls"))
	Game.store(LootDB.roll_pack(RandomNumberGenerator.new(), "cards"))
	Game.store(LootDB.roll_pack(RandomNumberGenerator.new(), "sneakers"))
	Game.tools = [2, 1, 0, 0]
	await _frames(4)
	await _shot("08_inventario")

	# El MISMO objeto con nota 1 y con nota 10, para comparar de un vistazo que
	# el sprite lleva el desgaste. Esto es lo que hay que mirar cuando se toque
	# apply_wear() en el generador. Se hace con un fisico y con una carta porque
	# wears_cartas() es un codigo distinto al de los objetos.
	for caso in [["07b_psa1", 1], ["07c_psa10", 10]]:
		await _volcar_caso(caso[0], "electronics", caso[1])
	for caso in [["07d_carta_psa1", 1], ["07e_carta_psa10", 10]]:
		await _volcar_caso(caso[0], "cards", caso[1])
	await _frames(2)

	# Un retrato por cada objeto de los dos packs que tienen cuatro dibujos
	# distintos. Es la unica forma de verlos al tamano y la luz del juego, y de
	# pillarse si un nombre se encoge mas de la cuenta o si un sprite no se
	# distingue del de al lado.
	for caso in [["10_doble_lp", "vinyls", "vinyl_d"],
			["11_numerada", "vinyls", "vinyl_n"],
			["12_color", "vinyls", "vinyl_x"],
			["13_piel", "sneakers", "shoe_l"],
			["14_restaurar", "sneakers", "shoe_r"],
			["15_limitada", "sneakers", "shoe_x"],
			["16_cartucho", "electronics", "cart_c"],
			["17_portatil", "electronics", "hand_c"],
			["18_cable", "misc", "cab_c"],
			["19_lingote", "misc", "ing_c"],
			["20_bolsillo", "misc", "pwt_c"]]:
		await _volcar_caso(caso[0], caso[1], 8, caso[2])

	# Tienda con dinero para ver las herramientas
	Game.money = 5000000
	g._open_shop()
	await _frames(4)
	await _shot("09_shop_lleno")

	print("capturas listas")
	# Ver Sound.stop_all(): al parar una voz, quien suelta su WAV es el hilo de
	# audio. Salir en el mismo frame da un aviso de recursos sin soltar al salir, y
	# esta herramienta sale por su cuenta, sin pasar por Game._on_close().
	Sound.stop_all()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
