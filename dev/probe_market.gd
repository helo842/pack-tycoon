# probe_market - capturas del MERCADO NEGRO (furgoneta, maletin y resultados) en
# user://shots/, con el patron del SubViewport de screenshots.gd.
#   $G --headless --path . res://dev/ProbeMarket.tscn
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const OUT := "user://shots/"

var _vp: SubViewport
var _main: MainRoot


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1920, 1080)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_run()


func _shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(OUT + name + ".png")
	print("captura: ", name)


func _run() -> void:
	Game.hard_reset()
	Game.market_unlocked = true
	Game.money = 80_000_000
	Game.note_pack_bought("toys3", int(LootDB.pack_by_id("toys3")["price"]))
	_main = MAIN_SCENE.instantiate() as MainRoot
	_vp.add_child(_main)
	await get_tree().create_timer(0.3).timeout
	_main.show_game()
	await get_tree().create_timer(0.5).timeout
	var g = null
	for c in _main._screen_host.get_children():
		if c.has_method("_spawn_pack"):
			g = c
	Game.market_next = 0.01
	g._events_step(0.1)
	await get_tree().create_timer(0.6).timeout
	await _shot("30_furgoneta")
	g._open_market()
	await get_tree().create_timer(0.6).timeout
	await _shot("31_maletin")
	var m: BlackMarketPanel = g._market
	# Un resultado de cada clase, a mano (la tirada es al azar).
	for outcome in ["jackpot", "fake", "raid"]:
		var item := {}
		if outcome != "raid":
			item = {"id": "bm_devkit", "name": "Consola de desarrollo",
				"art": "loot_bm_devkit_psa9" if outcome == "jackpot" else "loot_bm_lead_ingot_psa4",
				"rarity": BlackMarket.OUTCOME_RARITY[outcome], "grade": 9, "value": 5_400_000,
				"kind": "electronics", "tier": 3, "condition": LootDB.condition_for_grade(9)}
		m._show_result({"outcome": outcome, "item": item, "loss": 3_200_000, "price": 1_080_000})
		await get_tree().create_timer(0.5).timeout
		await _shot("32_resultado_" + outcome)
		m._dismiss()
	Game.van_sold = ["bm_box_carton"]
	m.refresh()
	await _shot("33_maletin_vendida")
	g._close_market()
	# El nodo del arbol, detras de LEYENDA (con todo comprado menos el).
	for id in SkillTree.ids():
		Game.skills[str(id)] = 1
	Game.skills.erase(SkillTree.MARKET)
	Game.market_unlocked = false
	Game.rebirth_coins = 40
	g._open_rebirth()
	await get_tree().create_timer(0.6).timeout
	var rp = g._rebirth
	rp._set_offset(rp._view.size * 0.5 - SkillTree.node_by_id(SkillTree.MARKET)["pos"] * rp.zoom()
			+ Vector2(0, 120))
	await get_tree().create_timer(0.4).timeout
	await _shot("34_arbol_mercado")
	get_tree().quit(0)
