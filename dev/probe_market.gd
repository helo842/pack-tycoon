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
	g._close_rebirth()
	await _auction_shots(g)
	get_tree().quit(0)


## LAS SUBASTAS: la furgoneta VIP junto a la negra con el estante de pociones, la
## sala a media puja, el sello de ganar y el de perder, el armario con miticos y
## sello, el hexagono de la telaraña y la pagina de las mascotas exclusivas.
func _auction_shots(g) -> void:
	Game.asc_skills = {"hyper": true, AscensionTree.AUCTION: true}
	Game.ascensions = 1
	Game.potions = {"money": 2, "luck": 1, "rain": 3}
	Game.potion_left = {"fury": 125.0, "money": 252.0}
	Game.auction_changed.emit()
	Game.auction_next = 0.01
	Game.market_next = 0.01
	g._events_step(0.1)
	await get_tree().create_timer(0.8).timeout
	await _shot("35_furgoneta_vip")
	Game.auction_lot = "mythic"
	g._open_auction()
	await get_tree().create_timer(0.5).timeout
	var sala: AuctionPanel = g._auction
	sala.auction._bid("tu")
	sala.auction._bid(str(sala.auction.rivals[0]["name"]))
	sala._paint()
	await _shot("36_sala_subasta")
	sala.auction.leader = "tu"
	sala.auction.rivals = []
	sala.auction.time_left = 0.02
	await get_tree().create_timer(1.0).timeout
	await _shot("37_subasta_ganada")
	g._close_auction()
	Game.auction_left = 60.0
	Game.auction_done = false
	Game.auction_lot = "potion_fury"
	g._open_auction()
	await get_tree().create_timer(0.3).timeout
	sala = g._auction
	sala.auction._bid("La Duquesa")
	for r in sala.auction.rivals:
		r["cap"] = 0
	sala.auction.time_left = 0.02
	await get_tree().create_timer(1.0).timeout
	await _shot("38_subasta_perdida")
	g._close_auction()
	# El armario con dos miticos (uno puesto y otro esperando) y sellos.
	Game.items[LootDB.item_index("armario")] = 4
	Game.locker = []
	for i in 3:
		Game.store(LootDB.roll_pack(RandomNumberGenerator.new(), "vinyls3"))
		Game.locker_put(0)
	Game.mythics = {
		"cards": Auction.mythic_item(Auction.mythic_by_kind("cards"), 10, 9000000),
		"toys": Auction.mythic_item(Auction.mythic_by_kind("toys"), 7, 9000000)}
	Game.seals = 2
	Game.items_changed.emit()
	g._open_locker()
	await get_tree().create_timer(0.6).timeout
	await _shot("39_armario_miticos")
	g._close_locker()
	await get_tree().create_timer(0.3).timeout
	await _shot("39b_vitrina_miticos")
	# El hexagono, fuera de la telaraña.
	Game.ascension_points = 3
	Game.asc_skills = {"hyper": true}
	g._open_ascension()
	await get_tree().create_timer(0.6).timeout
	var asc = g._ascension
	asc._set_offset(asc.WEB_VIEW.size * 0.5 - AscensionPanel.node_pos(AscensionTree.AUCTION) * asc.zoom())
	asc._on_node_pressed(AscensionTree.AUCTION)
	await get_tree().create_timer(0.4).timeout
	await _shot("40_telarana_subasta")
	g._close_ascension()
	Game.pets = {"rat": 2, "crow": 1}
	g._open_pets()
	await get_tree().create_timer(0.5).timeout
	g._pets._step_page(-1)
	await get_tree().create_timer(0.5).timeout
	await _shot("41_mascotas_subasta")
	g._close_pets()
