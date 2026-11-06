# AutoStorePanel - el filtro del AUTO GUARDAR.
#
# Un boton por cada valor que se puede guardar: los cuatro TIPOS, las diez notas
# PSA y las cuatro RAREZAS. Cada boton se enciende y se apaga por separado, asi
# que se puede pedir "solo PSA 2 y PSA 10" o "solo vinilos". Un objeto se guarda
# si su tipo, su nota y su rareza estan encendidos (las tres filas); si no, se
# vende solo. Ver Game.autostore_wants.
#
# Se abre desde Ajustes (boton ELEGIR), y solo existe con la mejora comprada:
# sin ella la fila de Ajustes no tiene boton.
class_name AutoStorePanel
extends Control

signal closed()

## Mismas medidas que el resto de paneles de ui_panel_shop: interior de x 224 a
## 1696 y de y 140 a 940.
const TITLE_Y := 240.0
const LABEL_X := 340.0
const ROW_KIND_Y := 400.0
const ROW_GRADE_Y := 560.0
const ROW_RARITY_Y := 700.0
const HINT_Y := 850.0
## Tipos y rarezas: cuatro chapas de 260 cada 280. Notas: diez de 104 cada 116.
const WIDE_X0 := 620.0
const WIDE_STEP := 280.0
const WIDE_W := 260.0
const NARROW_X0 := 560.0
const NARROW_STEP := 116.0
const NARROW_W := 104.0
## Un boton apagado se ve gris: encendido o no es lo unico que dice.
const OFF := Color(0.42, 0.42, 0.5, 1.0)

## Cada boton con su lista y su valor, para repintarlos todos de una vez.
var _buttons: Array = []
var _wide_size := 28


func _ready() -> void:
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))
	add_child(UIKit.label_at("AUTO GUARDAR", Vector2(960, TITLE_Y), Vector2(1400, 70),
			48, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var close := UIKit.close_button(UIKit.PANEL_CLOSE)
	close.pressed.connect(_close)
	add_child(close)

	# UN tamano de letra para los ocho botones anchos: con uno por boton,
	# ZAPATILLAS y LEGENDARIO salian a la mitad que CARTAS y se leia como un fallo.
	var kinds := LootDB.kind_ids()
	var rarezas: Array = Palette.RARITY_ORDER
	var textos: Array = []
	for k in kinds:
		textos.append(str(LootDB.kind_row(k)["name"]))
	for r in rarezas:
		textos.append(str(Palette.RARITY_NAME[r]))
	_wide_size = UIKit.row_size(textos, WIDE_W * (1.0 - 2.0 * UIKit.SMALL_BODY.x), 28)

	_row_label("TIPO", ROW_KIND_Y)
	for i in kinds.size():
		_toggle_button(str(LootDB.kind_row(kinds[i])["name"]), "kinds", kinds[i],
				Vector2(WIDE_X0 + float(i) * WIDE_STEP, ROW_KIND_Y), WIDE_W, _wide_size)
	_row_label("PSA", ROW_GRADE_Y)
	for g in range(1, LootDB.GRADE_MAX + 1):
		_toggle_button(str(g), "grades", g,
				Vector2(NARROW_X0 + float(g - 1) * NARROW_STEP, ROW_GRADE_Y), NARROW_W, 28)
	_row_label("RAREZA", ROW_RARITY_Y)
	for i in rarezas.size():
		_toggle_button(str(Palette.RARITY_NAME[rarezas[i]]), "rarities", rarezas[i],
				Vector2(WIDE_X0 + float(i) * WIDE_STEP, ROW_RARITY_Y), WIDE_W, _wide_size)

	add_child(UIKit.label_at("SE GUARDA SI CUMPLE LAS TRES FILAS. LO DEMAS SE VENDE SOLO",
			Vector2(960, HINT_Y), Vector2(1360, 40), 24, Palette.CREAM_D,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	refresh()


func _row_label(text: String, y: float) -> void:
	add_child(UIKit.label_at(text, Vector2(LABEL_X, y), Vector2(200, 50), 35,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, true))


func _toggle_button(text: String, list_name: String, value, center: Vector2,
		width: float, font_size: int) -> void:
	var b := UIKit.small_button(text, "", center, width, font_size)
	b.tooltip_text = "Guardar " + text
	b.pressed.connect(_on_toggle.bind(list_name, value))
	add_child(b)
	_buttons.append({"button": b, "list": list_name, "value": value})


func refresh() -> void:
	for e in _buttons:
		var on := Game.autostore_has(str(e["list"]), e["value"])
		(e["button"] as Button).modulate = Color.WHITE if on else OFF


func _on_toggle(list_name: String, value) -> void:
	Sound.click()
	Game.autostore_toggle(list_name, value)
	refresh()


func _close() -> void:
	Sound.click()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
