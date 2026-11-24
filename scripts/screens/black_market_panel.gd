# BlackMarketPanel - el MALETIN del mercado negro (estilo B de los mockups del
# 2026-11-24): la tapa de cuero con el titulo, el saldo y lo que le queda a la
# furgoneta; abajo, en el forro rojo, tres huecos de espuma con las cajas y sus
# etiquetas de papel colgando.
#
# Se abre pulsando la FURGONETA de la mesa (game.gd). Cada caja se compra una vez
# por visita y se abre AL MOMENTO: tiembla un poco y sale el resultado encima del
# maletin, con su sello (FALSO, CONTRABANDO, BUEN GOLPE, GOLPE MAESTRO o REDADA).
# Lo que sale se guarda o se vende ahi mismo, como en la tarjeta de revelado.
# La logica (precios, lo que sale, la redada) es de Game y BlackMarket.
class_name BlackMarketPanel
extends Control

signal closed()

## La tapa y la base del maletin, y su forro.
const LID := Rect2(200, 60, 1520, 360)
const LID_LINING := Rect2(240, 100, 1440, 290)
const BASE := Rect2(200, 430, 1520, 600)
const BASE_LINING := Rect2(240, 470, 1440, 520)
const HINGE := Rect2(180, 412, 1560, 36)
const BORDER := 6.0

const TITLE_POCKET := Rect2(300, 130, 720, 110)
const MONEY_PLATE := Rect2(1210, 130, 400, 72)
const TIMER_BAR := Rect2(1210, 236, 180, 26)
const CLOSE_CENTER := Vector2(1690, 92)

## Los tres huecos: centro x de cada uno, la espuma y la etiqueta.
const SLOT_X := [470.0, 960.0, 1450.0]
const FOAM := Vector2(360, 290)
const FOAM_Y := 510.0
const BOX_ART := Vector2(224, 224)
const TAG := Vector2(300, 130)
const TAG_Y := 840.0

## La tarjeta del resultado, encima de la base.
const RESULT := Rect2(460, 450, 1000, 560)

const LEATHER := Color8(58, 40, 34)
const LEATHER_L := Color8(84, 58, 48)
const LINING := Color8(110, 30, 40)
const LINING_D := Color8(92, 26, 36)
const POCKET := Color8(70, 20, 28)
const FOAM_COLOR := Color8(40, 34, 38)
const PAPER := Color8(246, 232, 196)
const INK := Color8(40, 30, 30)
const STAMP_RED := Color8(200, 50, 40)
const PIP_OFF := Color8(180, 164, 140)

var _money: PixelNumber
var _timer_fill: ColorRect
var _timer_label: Label
var _status: Label
## Por caja: {"art", "sold", "price", "hit"}.
var _slots: Dictionary = {}
## La tarjeta del resultado (null si no hay). Mientras esta, no se compra otra.
var _result: Control = null
var _pending: Dictionary = {}
var _busy := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(1920, 1080)
	add_child(UIKit.veil(0.6))
	_build_case()
	_build_lid()
	for i in BlackMarket.BOXES.size():
		_build_slot(BlackMarket.BOXES[i], float(SLOT_X[i]))
	var close := UIKit.close_button(CLOSE_CENTER, 104.0)
	close.pressed.connect(_close)
	add_child(close)
	Game.money_changed.connect(_on_money)
	Game.market_changed.connect(refresh)
	refresh()


func _rect(pos: Vector2, size: Vector2, color: Color, parent: Control = self) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Un rectangulo con borde oscuro (el contorno de todo el juego).
func _framed(r: Rect2, fill: Color, parent: Control = self) -> void:
	_rect(r.position - Vector2(BORDER, BORDER), r.size + Vector2(BORDER, BORDER) * 2.0,
			Palette.OUTLINE, parent)
	_rect(r.position, r.size, fill, parent)


func _build_case() -> void:
	_framed(LID, LEATHER)
	_rect(LID.position, Vector2(LID.size.x, 6), LEATHER_L)
	_rect(LID_LINING.position, LID_LINING.size, LINING_D)
	_framed(BASE, LEATHER)
	_rect(BASE_LINING.position, BASE_LINING.size, LINING)
	# Las costuras del forro: lineas verticales un tono mas oscuras.
	var x := BASE_LINING.position.x + 12.0
	while x < BASE_LINING.end.x:
		_rect(Vector2(x, BASE_LINING.position.y), Vector2(2, BASE_LINING.size.y), LINING_D)
		x += 24.0
	_framed(HINGE, Color8(40, 30, 26))
	for hx in [560.0, 1360.0]:
		_framed(Rect2(hx - 40.0, HINGE.position.y - 8.0, 80, HINGE.size.y + 16.0), Palette.GOLD_XL)


func _build_lid() -> void:
	_framed(TITLE_POCKET, POCKET)
	add_child(UIKit.label_at("Mercado negro", TITLE_POCKET.get_center(),
			TITLE_POCKET.size - Vector2(60, 30), 49, Palette.GOLD_XL,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	add_child(UIKit.label_at("Sin preguntas. Sin devoluciones.",
			Vector2(TITLE_POCKET.get_center().x, 290), Vector2(720, 36), 28, Palette.CREAM_D))
	_status = UIKit.label_at("", Vector2(TITLE_POCKET.get_center().x, 346), Vector2(720, 30), 21,
			Palette.CREAM)
	add_child(_status)
	_framed(MONEY_PLATE, Palette.NIGHT_D)
	add_child(UIKit.image("currency_coin", Vector2(MONEY_PLATE.position.x + 40.0,
			MONEY_PLATE.get_center().y), Vector2(56, 56)))
	_money = PixelNumber.new()
	_money.scale_factor = 0.40
	_money.max_width = MONEY_PLATE.size.x - 96.0
	add_child(_money)
	_framed(TIMER_BAR, Palette.NIGHT_D)
	_timer_fill = _rect(TIMER_BAR.position + Vector2(3, 3), TIMER_BAR.size - Vector2(6, 6),
			Color8(200, 60, 40))
	_timer_label = UIKit.label_at("", Vector2(TIMER_BAR.end.x + 100.0, TIMER_BAR.get_center().y),
			Vector2(170, 30), 21, Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_timer_label)


func _build_slot(box: Dictionary, cx: float) -> void:
	var id := str(box["id"])
	var foam := Rect2(cx - FOAM.x * 0.5, FOAM_Y, FOAM.x, FOAM.y)
	_framed(foam, FOAM_COLOR)
	var art := UIKit.image(str(box["art"]), foam.get_center(), BOX_ART)
	add_child(art)
	UIKit.bob(art, 3.0, 2.8, cx * 0.01)
	# La etiqueta de papel colgando del hueco, con su cordel.
	_rect(Vector2(cx + 60.0, foam.end.y - 4.0), Vector2(4, TAG_Y - foam.end.y + 8.0), Palette.CREAM_D)
	var tag := Rect2(cx - TAG.x * 0.5, TAG_Y, TAG.x, TAG.y)
	_framed(tag, PAPER)
	# Los tres nombres a la MISMA letra: la que le cabe al mas largo.
	var nombres: Array = BlackMarket.BOXES.map(func(b: Dictionary) -> String: return str(b["name"]))
	add_child(UIKit.label_at(str(box["name"]), Vector2(cx, TAG_Y + 22.0), Vector2(TAG.x - 30.0, 30),
			UIKit.row_size(nombres, TAG.x - 30.0, 28), INK))
	add_child(UIKit.label_at("Riesgo", Vector2(cx - 50.0, TAG_Y + 58.0), Vector2(110, 28), 21, INK))
	for k in 3:
		var pip := Rect2(cx + 20.0 + float(k) * 26.0, TAG_Y + 48.0, 20, 20)
		_framed(pip, STAMP_RED if k < int(box["risk"]) else PIP_OFF)
	var price := PixelNumber.new()
	price.scale_factor = 0.30
	price.max_width = TAG.x - 30.0
	add_child(price)
	var sold := UIKit.title_label_at("Vendida", foam.get_center(), Vector2(260, 60), 42, STAMP_RED)
	sold.rotation = -0.14
	sold.visible = false
	add_child(sold)
	var hit := UIKit.hit_area(self, Rect2(foam.position, Vector2(FOAM.x, TAG_Y + TAG.y - FOAM_Y)),
			str(box["name"]))
	hit.pressed.connect(_on_box.bind(id))
	_slots[id] = {"art": art, "sold": sold, "price": price, "hit": hit, "cx": cx}


func refresh() -> void:
	_on_money(Game.money)
	var frac := clampf(Game.van_left / BlackMarket.VAN_LIFE, 0.0, 1.0)
	_timer_fill.size.x = (TIMER_BAR.size.x - 6.0) * frac
	_timer_label.text = "Se va en %d s" % ceili(Game.van_left) if Game.van_here() else "Se ha ido"
	for id in _slots:
		var s: Dictionary = _slots[id]
		var vendida := Game.van_sold.has(id)
		(s["sold"] as Label).visible = vendida
		(s["art"] as Control).modulate = Color(0.4, 0.4, 0.45) if vendida else Color.WHITE
		var price: PixelNumber = s["price"]
		price.set_number(Game.box_price(str(id)))
		price.recolor(Color.WHITE if Game.money >= Game.box_price(str(id)) else Palette.PRICE_OFF)
		price.position = (Vector2(float(s["cx"]) - price.size.x * 0.5,
				TAG_Y + TAG.y - 30.0 - price.size.y * 0.5)).round()
	if _status.text == "":
		_status.text = "Cada caja, una vez por visita"


func _on_money(_value: int) -> void:
	_money.set_number(Game.money)
	_money.position = (Vector2(MONEY_PLATE.end.x - 16.0 - _money.size.x,
			MONEY_PLATE.get_center().y - _money.size.y * 0.5)).round()


func _on_box(id: String) -> void:
	if _busy or _result != null:
		return
	if not Game.van_here():
		_say("La furgoneta ya se ha ido", Palette.RUST_L)
		Sound.play("sfx_error")
		return
	if Game.van_sold.has(id):
		_say("Esa ya la has comprado. Vuelve en la próxima visita", Palette.RUST_L)
		Sound.play("sfx_error")
		return
	if Game.money < Game.box_price(id):
		_say("No te llega el dinero", Palette.RUST_L)
		Sound.play("sfx_error")
		return
	var r := Game.buy_box(id)
	if r.is_empty():
		return
	_busy = true
	Sound.click()
	# El suspense: la caja tiembla un momento antes de abrirse.
	var art: Control = _slots[id]["art"]
	var tw := create_tween()
	for i in 6:
		tw.tween_property(art, "rotation", 0.12 if i % 2 == 0 else -0.12, 0.07)
	tw.tween_property(art, "rotation", 0.0, 0.07)
	tw.tween_callback(_show_result.bind(r))


func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


## La tarjeta del resultado: sello, objeto (o la redada), valor y los botones.
func _show_result(r: Dictionary) -> void:
	_busy = false
	_pending = r
	_result = Control.new()
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	_result.size = Vector2(1920, 1080)
	add_child(_result)
	_framed(RESULT, Palette.NIGHT, _result)
	var outcome := str(r["outcome"])
	var stamp := UIKit.title_label_at(str(BlackMarket.OUTCOME_STAMP[outcome]),
			Vector2(RESULT.get_center().x, RESULT.position.y + 60.0), Vector2(700, 70), 56,
			STAMP_RED if outcome in ["fake", "raid"] else Palette.GOLD_XL)
	stamp.rotation = -0.06
	_result.add_child(stamp)
	UIKit.punch(stamp, 1.4)
	if outcome == "raid":
		Sound.play("sfx_error")
		_result.add_child(UIKit.label_at("La poli se ha llevado la caja y parte de tu dinero",
				Vector2(RESULT.get_center().x, RESULT.position.y + 200.0), Vector2(880, 36), 28,
				Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
		var lost := PixelNumber.new()
		lost.scale_factor = 0.5
		lost.color = Palette.RUST_L
		lost.set_text("-" + PixelNumber.format(int(r["loss"])))
		_result.add_child(lost)
		lost.position = (Vector2(RESULT.get_center().x - lost.size.x * 0.5,
				RESULT.position.y + 300.0 - lost.size.y * 0.5)).round()
		var ok := UIKit.small_button("Vaya", "", Vector2(RESULT.get_center().x, RESULT.end.y - 90.0), 260, 28)
		ok.pressed.connect(_dismiss)
		_result.add_child(ok)
		_say("Una redada. Mala suerte", Palette.RUST_L)
		return
	var item: Dictionary = r["item"]
	Sound.play("sfx_rare" if outcome in ["good", "jackpot"] else "sfx_tool")
	var art_c := Vector2(RESULT.position.x + 230.0, RESULT.position.y + 290.0)
	var glow := UIKit.image("rarity_glow_" + str(item["rarity"]), art_c, Vector2(300, 300))
	_result.add_child(glow)
	_result.add_child(UIKit.image(str(item["art"]), art_c, Vector2(256, 256)))
	var right := RESULT.position.x + 680.0
	_result.add_child(UIKit.label_at(str(item["name"]), Vector2(right, RESULT.position.y + 150.0),
			Vector2(520, 40), 35, Palette.CREAM))
	_result.add_child(UIKit.label_at("%s · Nota PSA %d" % [Palette.RARITY_NAME.get(str(item["rarity"]), ""),
			int(item["grade"])], Vector2(right, RESULT.position.y + 200.0), Vector2(520, 30), 21,
			Palette.RARITY.get(str(item["rarity"]), Palette.CREAM)))
	var value := PixelNumber.new()
	value.scale_factor = 0.5
	value.set_number(Game.payout_preview(item))
	_result.add_child(value)
	value.position = (Vector2(right - value.size.x * 0.5,
			RESULT.position.y + 280.0 - value.size.y * 0.5)).round()
	var veces := float(item["value"]) / float(maxi(1, int(r["price"])))
	_result.add_child(UIKit.label_at("La caja costó %s (x%s)" % [PixelNumber.format(int(r["price"])),
			String.num(veces, 1).replace(".", ",")], Vector2(right, RESULT.position.y + 340.0),
			Vector2(520, 30), 21, Palette.CREAM_D))
	var keep := UIKit.small_button("Guardar", "", Vector2(right - 140.0, RESULT.end.y - 90.0), 260, 28)
	keep.pressed.connect(_keep)
	_result.add_child(keep)
	var sell := UIKit.small_button("Vender", "", Vector2(right + 140.0, RESULT.end.y - 90.0), 260, 28)
	sell.pressed.connect(_sell)
	_result.add_child(sell)
	_say("Guárdalo para el armario o véndelo ya", Palette.CREAM)


func _keep() -> void:
	if not _pending.is_empty() and not (_pending["item"] as Dictionary).is_empty():
		Game.store(_pending["item"])
		Sound.click()
	_dismiss()


func _sell() -> void:
	if not _pending.is_empty() and not (_pending["item"] as Dictionary).is_empty():
		Game.payout(_pending["item"])
		Sound.play("sfx_sell")
	_dismiss()


func _dismiss() -> void:
	_pending = {}
	if _result != null:
		_result.queue_free()
		_result = null
	refresh()


## Cerrar con un resultado sin decidir lo VENDE: el objeto ya esta pagado y no
## se puede perder por cerrar el maletin.
func _close() -> void:
	if not _pending.is_empty() and not (_pending["item"] as Dictionary).is_empty():
		Game.payout(_pending["item"])
	_pending = {}
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
