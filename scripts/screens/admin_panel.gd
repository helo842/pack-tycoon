# AdminPanel - trampas para PROBAR el juego sin tener que jugarlo entero.
#
# Se abre desde Ajustes (boton ADMIN), que solo sale en una version de
# depuracion (desde el editor o un export "con depuracion"): en el juego
# exportado normal no existe. Una fila por cosa: su valor ahora mismo y dos
# botones, uno que QUITA y otro que DA. Cada boton guarda.
class_name AdminPanel
extends Control

signal closed()

const TITLE_Y := 240.0
const ROW_Y0 := 340.0
## Los botones pequenos miden de alto 0.45 de su ancho (200 -> 90): el paso de
## fila tiene que ser mayor que eso o se pisan, que es lo que pasaba con 600/120.
const ROW_STEP := 100.0
const BTN_W := 200.0
const LABEL_X := 720.0
const MINUS_X := 1240.0
const PLUS_X := 1480.0
const HINT_Y := 915.0

## Cada fila: nombre, lo que se ve de valor, y [rotulo, accion] de quitar y de dar.
var _acciones := [
	["DINERO", func() -> String: return LootDB.short_number(Game.money),
		["-1000 M", _quitar_dinero], ["+1000 M", _dar_dinero]],
	["MONEDAS REBIRTH", func() -> String: return str(Game.rebirth_coins),
		["-100", _quitar_monedas], ["+100", _dar_monedas]],
	["PUNTOS ASCENSION", func() -> String: return str(Game.ascension_points),
		["-1", _quitar_punto], ["+1", _dar_punto]],
	["ARBOL REBIRTH", func() -> String: return "%d NODOS" % Game.skills.size(),
		["VACIAR", _arbol_vacio], ["LLENAR", _arbol_entero]],
	["PIEZAS", _texto_piezas,
		["A CERO", _piezas_a_cero], ["MAXIMO", _piezas_al_maximo]],
	["MASCOTAS", func() -> String: return "%d/%d" % [Game.pets.size(), PetDB.PETS.size()],
		["QUITAR", _mascotas_fuera], ["MAXIMO", _mascotas_al_maximo]],
]
var _valores: Array[Label] = []


func _ready() -> void:
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))
	add_child(UIKit.label_at("ADMIN", Vector2(960, TITLE_Y), Vector2(1400, 70),
			48, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var close := UIKit.close_button(UIKit.PANEL_CLOSE)
	close.pressed.connect(_close)
	add_child(close)

	for i in _acciones.size():
		var y := ROW_Y0 + i * ROW_STEP
		var l := UIKit.label_at("", Vector2(LABEL_X, y), Vector2(720, 60), 30,
				Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
		_valores.append(l)
		add_child(l)
		for lado in [2, 3]:
			var b := UIKit.small_button(str(_acciones[i][lado][0]), "",
					Vector2(MINUS_X if lado == 2 else PLUS_X, y), BTN_W, 26,
					"ui_button_sell" if lado == 2 else "ui_button_small",
					"ui_button_sell" if lado == 2 else "ui_button_small_pressed")
			b.pressed.connect(_hacer.bind(i, lado))
			add_child(b)
	_refrescar()
	add_child(UIKit.label_at("SOLO PARA PROBAR: NO SALE EN EL JUEGO EXPORTADO",
			Vector2(960, HINT_Y), Vector2(1360, 40), 24, Palette.CREAM_D,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))


## lado 2 = quitar, lado 3 = dar.
func _hacer(i: int, lado: int) -> void:
	Sound.click()
	(_acciones[i][lado][1] as Callable).call()
	# Todo lo que pinta la partida escucha alguna de estas: se avisan todas.
	Game._dirty = true
	Game.money_changed.emit(Game.money)
	Game.items_changed.emit()
	Game.skills_changed.emit()
	Game.settings_changed.emit()
	Game.save_game()
	Game.notice.emit("ADMIN: %s %s" % [_acciones[i][0], _acciones[i][lado][0]], Palette.GOLD_XL)
	_refrescar()


func _refrescar() -> void:
	for i in _valores.size():
		_valores[i].text = "%s: %s" % [_acciones[i][0], (_acciones[i][1] as Callable).call()]


func _texto_piezas() -> String:
	var n := 0
	var tope := 0
	for i in LootDB.item_count():
		n += Game.item_level(i)
		tope += Game.item_max_level(i)
	return "NIVEL %d/%d" % [n, tope]


func _dar_dinero() -> void:
	Game.add_money(1_000_000_000)


func _quitar_dinero() -> void:
	Game.money = maxi(0, Game.money - 1_000_000_000)


func _dar_monedas() -> void:
	Game.rebirth_coins += 100


func _quitar_monedas() -> void:
	Game.rebirth_coins = maxi(0, Game.rebirth_coins - 100)


func _dar_punto() -> void:
	Game.ascension_points += 1


func _quitar_punto() -> void:
	Game.ascension_points = maxi(0, Game.ascension_points - 1)


func _arbol_entero() -> void:
	for id in SkillTree.ids():
		Game.skills[str(id)] = SkillTree.levels_of(str(id))
	Game._factory_pieces()


## Sin FABRICA no hay automaticos, como en _reset_run.
func _arbol_vacio() -> void:
	Game.skills = {}
	Game.auto_open = false
	Game.auto_buy = false


func _piezas_al_maximo() -> void:
	for i in LootDB.item_count():
		Game.items[i] = Game.item_max_level(i)


## Como al empezar partida: a cero, salvo lo que regala FABRICA.
func _piezas_a_cero() -> void:
	for i in LootDB.item_count():
		Game.items[i] = 0
	Game._factory_pieces()
	var fabrica := Game.skill_owned(SkillTree.FACTORY)
	Game.auto_open = fabrica and Game.auto_open
	Game.auto_buy = fabrica and Game.auto_buy


func _mascotas_al_maximo() -> void:
	for p in PetDB.PETS:
		Game.pets[str(p["id"])] = PetDB.MAX_LEVEL


func _mascotas_fuera() -> void:
	Game.pets = {}


## Quien lo abrio (Ajustes) lo saca del velo con pop_veil.
func _close() -> void:
	Sound.click()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
