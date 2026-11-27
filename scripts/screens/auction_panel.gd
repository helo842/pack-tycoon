# AuctionPanel - la SALA DE SUBASTAS (estilo B de los mockups del 2026-11-27): el
# lote en un pedestal bajo un foco, la pizarra con la puja actual y quien la lleva,
# el reloj, el boton de pujar y los dos rivales con su paleta abajo a la izquierda.
#
# Se abre pulsando la FURGONETA VIP de la mesa (game.gd) y trae la subasta ya
# empezada (Game.auction_start). Al acabar cae un SELLO sobre el lote (estilo A del
# resultado): dorado «¡Tuyo!» si ganas, rojo con el nombre del rival si no. Perder
# no cuesta nada. Cerrar la sala a media puja es retirarse: la furgoneta se va.
# La logica (reloj, rivales, lo que da cada lote) es de Auction y Game.
class_name AuctionPanel
extends Control

signal closed()

const LOT_CENTER := Vector2(960, 430)
const LOT_SIZE := Vector2(288, 288)
const BOARD := Rect2(1360, 250, 460, 280)
const TIMER_BAR := Rect2(1400, 566, 300, 26)
const BID_CENTER := Vector2(1590, 690)
const MONEY_PLATE := Rect2(80, 60, 400, 72)
const CLOSE_CENTER := Vector2(1830, 80)
const RIVAL_X := [250.0, 560.0]
const RIVAL_Y := 840.0
const RIVAL_SIZE := Vector2(224, 224)
const RIVAL_ARTS := ["tree_auction_rival_a", "tree_auction_rival_b", "tree_auction_rival_c"]

const BOARD_GREEN := Color8(20, 44, 32)
const BOARD_WOOD := Color8(120, 86, 56)
const PEDESTAL := Color8(70, 50, 44)
const PEDESTAL_D := Color8(50, 36, 32)
const STAMP_RED := Color8(200, 50, 40)
const MYTHIC_PURPLE := Color8(200, 150, 250)

var auction: Auction
var _money: PixelNumber
var _price: PixelNumber
var _leader: Label
var _timer_fill: ColorRect
var _timer_label: Label
var _bid: Button
var _bid_label: Label
var _status: Label
var _lot_art: Control
var _rival_nodes: Array = []   # [{art, name, note}]
var _result: Dictionary = {}
var _ended := false


func _init(a: Auction = null) -> void:
	auction = a


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(1920, 1080)
	add_child(UIKit.veil(0.9))
	_build_room()
	_build_board()
	_build_rivals()
	var close := UIKit.close_button(CLOSE_CENTER, 104.0)
	close.tooltip_text = "Retirarse: la furgoneta se va"
	close.pressed.connect(_close)
	add_child(close)
	Game.money_changed.connect(_on_money)
	_on_money(Game.money)
	_paint()


func _rect(pos: Vector2, sz: Vector2, color: Color, parent: Control = self) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _framed(r: Rect2, fill: Color, edge: Color = Palette.OUTLINE, w: float = 6.0) -> void:
	_rect(r.position - Vector2(w, w), r.size + Vector2(w, w) * 2.0, edge)
	_rect(r.position, r.size, fill)


## El foco, el pedestal, el lote y los rotulos de arriba.
func _build_room() -> void:
	add_child(UIKit.image("rarity_glow_legendary", LOT_CENTER, Vector2(720, 720)))
	# El pedestal: la columna que se estrecha y la base.
	for i in 6:
		var w := 200.0 + float(i) * 16.0
		_rect(Vector2(LOT_CENTER.x - w * 0.5, 600.0 + float(i) * 26.0), Vector2(w, 26),
				PEDESTAL if i % 2 == 0 else PEDESTAL_D)
	_framed(Rect2(LOT_CENTER.x - 170.0, 756, 340, 36), PEDESTAL_D, Palette.OUTLINE, 4.0)
	_lot_art = UIKit.fit_art(Auction.lot_art(auction.lot), LOT_CENTER, LOT_SIZE)
	add_child(_lot_art)
	UIKit.bob(_lot_art, 4.0, 2.6)
	add_child(UIKit.title_label_at("Subasta", Vector2(960, 70), Vector2(600, 80), 56,
			Palette.GOLD_XL))
	add_child(UIKit.label_at(Auction.lot_name(auction.lot), Vector2(960, 150), Vector2(1000, 44),
			35, MYTHIC_PURPLE, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	add_child(UIKit.label_at(Auction.lot_desc(auction.lot), Vector2(960, 196), Vector2(1100, 32),
			21, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	_status = UIKit.label_at("", Vector2(960, 860), Vector2(700, 36), 28, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_status)
	_framed(MONEY_PLATE, Palette.NIGHT_D)
	add_child(UIKit.image("currency_coin", Vector2(MONEY_PLATE.position.x + 40.0,
			MONEY_PLATE.get_center().y), Vector2(56, 56)))
	_money = PixelNumber.new()
	_money.scale_factor = 0.40
	_money.max_width = MONEY_PLATE.size.x - 96.0
	add_child(_money)


## La pizarra con la puja actual y quien la lleva, el reloj y el boton.
func _build_board() -> void:
	_framed(BOARD, BOARD_GREEN, BOARD_WOOD, 12.0)
	add_child(UIKit.label_at("Puja actual", Vector2(BOARD.get_center().x, BOARD.position.y + 40.0),
			Vector2(400, 36), 28, Palette.CREAM))
	_price = PixelNumber.new()
	_price.scale_factor = 0.5
	_price.max_width = BOARD.size.x - 40.0
	add_child(_price)
	_leader = UIKit.label_at("", Vector2(BOARD.get_center().x, BOARD.end.y - 50.0),
			Vector2(420, 36), 28, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_leader)
	_framed(TIMER_BAR, Palette.NIGHT_D, Palette.OUTLINE, 3.0)
	_timer_fill = _rect(TIMER_BAR.position + Vector2(3, 3), TIMER_BAR.size - Vector2(6, 6),
			Palette.GOLD_XL)
	_timer_label = UIKit.label_at("", Vector2(TIMER_BAR.end.x + 60.0, TIMER_BAR.get_center().y),
			Vector2(100, 30), 21, Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_timer_label)
	_bid = UIKit.small_button("Pujar +10 %", "", BID_CENTER, 360, 28)
	_bid.pressed.connect(_on_bid)
	add_child(_bid)
	_bid_label = UIKit.label_at("", BID_CENTER + Vector2(0, 80), Vector2(460, 30), 21,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	add_child(_bid_label)


func _build_rivals() -> void:
	var arts: Array = RIVAL_ARTS.duplicate()
	arts.shuffle()
	for i in auction.rivals.size():
		var r: Dictionary = auction.rivals[i]
		var c := Vector2(float(RIVAL_X[i]), RIVAL_Y)
		var art := UIKit.fit_art(str(arts[i]), c, RIVAL_SIZE)
		add_child(art)
		var name_l := UIKit.label_at(str(r["name"]), c + Vector2(0, 140), Vector2(300, 30), 21,
				Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
		add_child(name_l)
		var note := UIKit.label_at("", c + Vector2(0, -150), Vector2(300, 30), 21, Palette.GOLD_XL,
				HORIZONTAL_ALIGNMENT_CENTER, 0, true)
		add_child(note)
		_rival_nodes.append({"art": art, "name": name_l, "note": note})


func _on_money(value: int) -> void:
	_money.set_number(value)
	_money.position = (Vector2(MONEY_PLATE.position.x + 80.0,
			MONEY_PLATE.get_center().y - _money.size.y * 0.5)).round()


# --------------------------------------------------------------------------- #
# La puja
# --------------------------------------------------------------------------- #

func _process(delta: float) -> void:
	if _ended or auction == null:
		return
	var ev := auction.step(delta)
	if ev == "fin":
		_finish()
		return
	if ev != "":
		Sound.play("sfx_click", 0.0, 0.8)
		for i in auction.rivals.size():
			if str(auction.rivals[i]["name"]) == ev:
				UIKit.punch(_rival_nodes[i]["art"], 1.15)
				(_rival_nodes[i]["note"] as Label).text = PixelNumber.format(auction.price)
	_paint()


func _on_bid() -> void:
	if _ended:
		return
	if not auction.player_bid(Game.money):
		Sound.play("sfx_error")
		UIKit.shake(_bid)
		if auction.leader == "tu":
			_say("Ya vas primero", Palette.CREAM_D)
		else:
			_say("No te llega para pujar", Palette.RUST_L)
		return
	Sound.play("sfx_buy")
	UIKit.punch(_bid, 1.15)
	_say("", Palette.CREAM)
	_paint()


func _paint() -> void:
	_price.set_number(auction.price)
	_price.position = (Vector2(BOARD.get_center().x - _price.size.x * 0.5,
			BOARD.get_center().y - _price.size.y * 0.5)).round()
	match auction.leader:
		"":
			_leader.text = "Precio de salida"
		"tu":
			_leader.text = "La llevas tú"
		_:
			_leader.text = auction.leader
	_leader.add_theme_color_override("font_color",
			Palette.GOLD_XL if auction.leader == "tu" else Palette.CREAM_D)
	var frac := clampf(auction.time_left / Auction.CLOCK, 0.0, 1.0)
	_timer_fill.size.x = (TIMER_BAR.size.x - 6.0) * frac
	_timer_fill.color = Palette.GOLD_XL if auction.time_left > 5.0 else STAMP_RED
	_timer_label.text = "%d s" % ceili(auction.time_left)
	_bid_label.text = "Tu puja: %s" % PixelNumber.format(auction.next_bid()) \
			if auction.leader != "tu" else "Esperando a los rivales..."
	var puede := auction.leader != "tu" and Game.money >= auction.next_bid() and not _ended
	_bid.modulate = Color.WHITE if puede else Color(0.55, 0.55, 0.62, 1.0)
	for i in auction.rivals.size():
		var activo := auction.rival_active(auction.rivals[i])
		(_rival_nodes[i]["art"] as CanvasItem).modulate = Color.WHITE if activo \
				else Color(0.45, 0.45, 0.5, 1.0)
		if not activo:
			(_rival_nodes[i]["note"] as Label).text = "Se retira"


func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


# --------------------------------------------------------------------------- #
# El resultado: el sello sobre el lote
# --------------------------------------------------------------------------- #

func _finish() -> void:
	_ended = true
	_bid.visible = false
	_bid_label.visible = false
	_paint()
	if auction.won():
		_result = Game.auction_win(auction)
	if not _result.is_empty():
		_won()
	elif auction.leader == "":
		_stamp("Desierta", Palette.CREAM_D, 0.08)
		Sound.play("sfx_error")
		_lines(["Nadie ha pujado: la furgoneta se va"], [Palette.CREAM_D])
	else:
		var quien := auction.leader if auction.leader != "tu" else "Nadie"
		_stamp(quien, STAMP_RED, 0.16)
		Sound.play("sfx_error")
		_lines(["Se lo lleva por %s" % PixelNumber.format(auction.price),
				"No te cuesta nada. La próxima furgoneta, en unos 18 min"],
				[Palette.CREAM, Palette.CREAM_D])
	var ok := UIKit.small_button("Seguir", "", Vector2(960, 1010), 260, 28)
	ok.pressed.connect(_close)
	add_child(ok)


func _won() -> void:
	Sound.play("sfx_rare")
	Sound.play("sfx_sell_all")
	_stamp("¡Tuyo!", Palette.GOLD_XL, -0.2)
	MainRoot.get_root().confetti()
	var textos: Array = ["Ganado por %s" % PixelNumber.format(int(_result["price"]))]
	var colores: Array = [Palette.CREAM]
	match str(_result["type"]):
		"potion":
			textos.append("Al estante de pociones: tómala cuando quieras")
		"seal":
			textos.append("Úsalo en el armario: +1 a la nota de un objeto")
		"star":
			textos.append("+1 punto de ascensión: gástalo en la telaraña")
		"egg":
			var pet := PetDB.pet_by_id(str(_result.get("pet", "")))
			if not pet.is_empty():
				_swap_art(str(pet["art"]))
				textos.append("%s: %s (equípala en Mascotas)" % [pet["name"],
						PetDB.bonus_text(pet, Game.pet_level(str(pet["id"])), true)])
		"blind", "mythic":
			var item: Dictionary = _result.get("item", {})
			if not item.is_empty():
				_swap_art(str(item["art"]))
			if str(_result.get("blind", "")) == "junk":
				textos.append("Era basura: %s, vendido por %s" % [item["name"],
						PixelNumber.format(int(_result.get("sold", 0)))])
				colores.append(Palette.RUST_L)
			else:
				var kept: Dictionary = _result.get("kept", item)
				textos.append("%s · Mítico · PSA %d" % [item["name"], int(item["grade"])])
				colores.append(MYTHIC_PURPLE)
				if kept != item:
					textos.append("Ya tenías uno mejor (PSA %d): vendido por %s" % [
							int(kept["grade"]), PixelNumber.format(int(_result.get("sold", 0)))])
				else:
					textos.append("No se pierde nunca: se coloca solo en tu armario")
	while colores.size() < textos.size():
		colores.append(Palette.CREAM_D)
	_lines(textos, colores)


func _swap_art(art: String) -> void:
	var nuevo := UIKit.fit_art(art, LOT_CENTER, LOT_SIZE)
	add_child(nuevo)
	move_child(nuevo, _lot_art.get_index())
	_lot_art.queue_free()
	_lot_art = nuevo
	UIKit.punch(_lot_art, 1.2)


## El sello que cae sobre el lote, girado (letra de texto: la de titulos trae
## contorno y no se puede teñir de rojo).
func _stamp(text: String, color: Color, angle: float) -> void:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := UIKit.text_width(text, 70, false, Palette.OUTLINE) + 80.0
	box.size = Vector2(w, 130)
	box.position = LOT_CENTER - box.size * 0.5
	box.pivot_offset = box.size * 0.5
	box.rotation = angle
	add_child(box)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.border_color = color
	sb.set_border_width_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = box.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(panel)
	var l := UIKit.label(text, 70, color, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_ONLY)
	l.size = box.size
	box.add_child(l)
	box.scale = Vector2(2.2, 2.2)
	box.modulate.a = 0.0
	var tw := box.create_tween().set_parallel()
	tw.tween_property(box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, 0.12)


func _lines(textos: Array, colores: Array) -> void:
	_status.text = ""
	for i in textos.size():
		add_child(UIKit.label_at(str(textos[i]), Vector2(960, 840.0 + float(i) * 44.0),
				Vector2(1100, 36), 28 if i == 0 else 21, colores[i], HORIZONTAL_ALIGNMENT_CENTER, 0,
				true))


func _close() -> void:
	Sound.click()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
