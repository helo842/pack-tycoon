extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _main: Node = null


func _ready() -> void:
	Game.hard_reset()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	_main.show_game()
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout

	var g: Node = null
	for c in _main._screen_host.get_children():
		if c.has_method("_spawn_pack"):
			g = c
	print("--- juego: ", g != null)
	print("--- room: ", g._room != null, " player: ", g._player != null)
	var st: Station = g._room.terminal
	print("--- station: ", st, " screen: ", st.screen)
	print("--- viewport: ", st.screen.viewport, " en el arbol: ",
		st.screen.viewport.is_inside_tree())
	print("--- stage: ", st.screen.stage, " size ", st.screen.stage.size)

	g._open_shop()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var shop = g._shop
	print("--- shop: ", shop)
	if shop != null:
		print("--- shop ready: ", shop.is_node_ready(), " hijos: ", shop.get_child_count())
		print("--- celdas: ", shop._item_cells.size())
		print("--- shop size: ", shop.size, " pos ", shop.position)
		print("--- padre: ", shop.get_parent())
	print("--- locked_to: ", g._locked_to, " player locked: ", g._player.locked)
	print("--- cursor libre: ", g._player.mouse_is_free())
	g._close_shop()
	await get_tree().process_frame
	print("--- tras cerrar: shop ", g._shop, " panel ", st.has_panel())
	Sound.stop_all()
	get_tree().quit()
