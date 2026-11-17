# LibretaPanel - el album de colecciones y los encargos.
#
# Dos columnas dentro del panel de siempre (interior de x 288 a 1632, de y 188 a
# 952):
#
#   ALBUM      a la izquierda, en dos paginas (flechas a los lados del rotulo,
#              como las maquinas de las mascotas): OBJETOS, una
#              fila por coleccion (ver Gameplay.SETS) con su nombre, lo que da y
#              sus objetos (los que no has visto en silueta; los vistos con el
#              dibujo de su MEJOR nota y esa nota debajo), y MASCOTAS, una fila
#              por maquina del gachapon (Gameplay.PET_SETS) con sus seis
#              mascotas. Una coleccion completa sale en oro.
#   ENCARGOS   a la derecha: los tres en curso, con lo que piden, lo que llevas y
#              lo que pagan. Se cobran solos al cumplirse.
#
# El album es de la cuenta (no se pierde al reiniciar) y los encargos de la
# partida. Lo que dicen los dos sale de Game: este panel solo pinta.
class_name LibretaPanel
extends Control

signal closed()

const TITLE_Y := 240.0
const HEAD_Y := 304.0

const ALBUM_X := 320.0
## Siete colecciones (con JUGUETES): a 96 la ultima se salia por abajo del
## panel, asi que van a 84 y empiezan un poco mas arriba.
const ROW0_Y := 360.0
const ROW_STEP := 84.0
const ICON := 64.0
const ICON_X0 := 664.0
const ICON_STEP := 76.0
## El ancho de la columna de nombres (de ALBUM_X a los iconos).
const NAME_W := 330.0

const MISSION_X := 1120.0
const MISSION_W := 480.0
const MISSION_H := 144.0
const MISSION_Y0 := 336.0
const MISSION_STEP := 164.0

## La pagina del album: 0 objetos, 1 mascotas.
var _page := 0
var _album_head: Label = null
var _album_note: Label = null
var _rows: Control = null
var _missions: Control = null
## Un solo tamano para los nombres y otro para lo que dan, el que le cabe al mas
## largo: con uno por fila, "CARTAS" salia a 28 y "ZAPATILLAS" a 21, y la columna
## se leia como un fallo y no como una lista (lo mismo que la de sobres, ver
## game.gd, _build_pack_zone()).
var _name_size := 28
var _effect_size := 21


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))
	add_child(UIKit.label_at("Libreta", Vector2(960, TITLE_Y), Vector2(1200, 70), 48,
			Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var close := UIKit.close_button(UIKit.PANEL_CLOSE)
	close.pressed.connect(_close)
	add_child(close)

	_album_head = UIKit.label_at("", Vector2(ALBUM_X + 380, HEAD_Y), Vector2(420, 44),
			35, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0)
	add_child(_album_head)
	for lado in [-1, 1]:
		var c := Vector2(ALBUM_X + 380 + lado * 250.0, HEAD_Y - 4.0)
		add_child(UIKit.image("ui_arrow_left" if lado < 0 else "ui_arrow_right", c,
				Vector2(48, 48)))
		UIKit.hit_area(self, Rect2(c - Vector2(32, 32), Vector2(64, 64)),
				"Otra página del álbum").pressed.connect(_set_page.bind(-1))
	add_child(UIKit.label_at("Encargos", Vector2(MISSION_X + MISSION_W * 0.5, HEAD_Y),
			Vector2(MISSION_W, 44), 35, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0))
	# La raya entre las dos columnas.
	var raya := ColorRect.new()
	raya.color = Color(Palette.GOLD_D, 0.6)
	raya.position = Vector2(1092, 300)
	raya.size = Vector2(4, 600)
	raya.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raya)

	_rows = Control.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)
	_missions = Control.new()
	_missions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_missions)

	_album_note = UIKit.label_at("", Vector2(ALBUM_X + 380, 916), Vector2(760, 30), 21,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0)
	add_child(_album_note)
	add_child(UIKit.label_at("Se cobran solos al cumplirse",
			Vector2(MISSION_X + MISSION_W * 0.5, 916), Vector2(MISSION_W, 30), 21,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	var nombres: Array = []
	var efectos: Array = []
	for s in Gameplay.all_sets():
		nombres.append("%s  %d/%d" % [s["name"], 9, 9])
		efectos.append(str(s["effect"]))
	_name_size = UIKit.row_size(nombres, NAME_W, 28)
	_effect_size = UIKit.row_size(efectos, NAME_W, 21)

	Game.album_changed.connect(refresh)
	Game.missions_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	for c in _rows.get_children():
		c.queue_free()
	for c in _missions.get_children():
		c.queue_free()
	var sets: Array = Gameplay.SETS if _page == 0 else Gameplay.PET_SETS
	for i in sets.size():
		# Las de mascotas son cuatro: van mas separadas.
		_paint_set(sets[i], ROW0_Y + (0.0 if _page == 0 else 30.0)
				+ float(i) * (ROW_STEP if _page == 0 else 140.0))
	_album_head.text = "Álbum: objetos" if _page == 0 else "Álbum: mascotas"
	_album_note.text = "El álbum de objetos no se pierde al reiniciar" if _page == 0 \
			else "Completa una máquina y su bonus es tuyo aunque no las equipes"
	_album_note.add_theme_font_size_override("font_size",
			UIKit.fit_size(_album_note.text, 740.0, 21))
	for i in Game.missions.size():
		_paint_mission(Game.missions[i], MISSION_Y0 + float(i) * MISSION_STEP)


## Una fila del album: nombre y progreso arriba, lo que da debajo, y los objetos.
func _paint_set(s: Dictionary, y: float) -> void:
	var id := str(s["id"])
	var hecha := Game.set_complete(id)
	var prog := Game.set_progress(id)
	var color := Palette.GOLD_XL if hecha else Palette.CREAM
	_rows.add_child(UIKit.label_at("%s  %d/%d" % [s["name"], prog.x, prog.y],
			Vector2(ALBUM_X + NAME_W * 0.5, y - 16), Vector2(NAME_W, 34), _name_size, color,
			HORIZONTAL_ALIGNMENT_LEFT, 0))
	_rows.add_child(UIKit.label_at(str(s["effect"]), Vector2(ALBUM_X + NAME_W * 0.5, y + 20),
			Vector2(NAME_W, 30), _effect_size, Palette.GOLD_XL if hecha else Palette.CREAM_D,
			HORIZONTAL_ALIGNMENT_LEFT, 0))
	if s.has("machine"):
		_paint_pets(str(s["machine"]), y)
		return
	var items: Array = s["items"]
	if items.is_empty():
		# La de PERFECCION no tiene objetos: pide una nota. Se pinta el escudo de
		# la nota PSA (el de la tarjeta de revelado) con su numero y, al lado, a
		# que vale: el texto entero en una linea no cabia ni a 14.
		var nota := int(s.get("grade", 10))
		var centro := Vector2(ICON_X0 + ICON * 0.5, y)
		_rows.add_child(UIKit.slot(centro, ICON + 8.0))
		var escudo := UIKit.fit_art("grade_badge", centro, Vector2(ICON - 14, ICON - 10))
		if not hecha:
			escudo.modulate = Color(1, 1, 1, 0.55)
		_rows.add_child(escudo)
		var n := PixelNumber.new()
		n.scale_factor = 0.2
		n.max_width = ICON
		_rows.add_child(n)
		n.set_number(nota)
		n.position = centro - n.size * 0.5
		_rows.add_child(UIKit.label_at("En cualquier objeto",
				Vector2(ICON_X0 + ICON + 24 + 150, y), Vector2(300, 30), 21,
				color, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
		return
	for j in items.size():
		var key := str(items[j])
		var centro := Vector2(ICON_X0 + float(j) * ICON_STEP + ICON * 0.5, y)
		var visto := Game.album.has(key)
		var nota := int(Game.album.get(key, 10))
		_rows.add_child(UIKit.slot(centro, ICON + 8.0))
		var art := UIKit.fit_art("%s_psa%d" % [key, nota], centro + Vector2(0, -4),
				Vector2(ICON - 10, ICON - 10))
		# Lo que no has visto, en silueta: se sabe que existe y que falta.
		if not visto:
			art.modulate = Color(0.0, 0.0, 0.0, 0.75)
		_rows.add_child(art)
		if visto:
			var n := PixelNumber.new()
			n.scale_factor = 0.18
			n.max_width = ICON
			_rows.add_child(n)
			n.set_number(nota)
			n.position = centro + Vector2(0, ICON * 0.5 - 10) - n.size * 0.5


## Las seis mascotas de una maquina: el dibujo si la tienes (con su nivel
## debajo), en silueta si no.
func _paint_pets(machine: String, y: float) -> void:
	var mascotas := PetDB.pets_of(machine)
	for j in mascotas.size():
		var p: Dictionary = mascotas[j]
		var nivel := Game.pet_level(str(p["id"]))
		var centro := Vector2(ICON_X0 + float(j) * ICON_STEP + ICON * 0.5, y)
		_rows.add_child(UIKit.slot(centro, ICON + 8.0))
		var art := UIKit.fit_art(str(p["art"]), centro + Vector2(0, -4),
				Vector2(ICON - 10, ICON - 10))
		if nivel <= 0:
			art.modulate = Color(0.0, 0.0, 0.0, 0.75)
		_rows.add_child(art)
		if nivel > 0:
			var n := PixelNumber.new()
			n.scale_factor = 0.18
			n.max_width = ICON
			_rows.add_child(n)
			n.set_number(nivel)
			n.position = centro + Vector2(0, ICON * 0.5 - 10) - n.size * 0.5


## Pasa a la otra pagina del album (son dos: las dos flechas hacen lo mismo).
func _set_page(_step: int) -> void:
	Sound.click()
	_page = 1 - _page
	refresh()


## Un encargo: la caja, lo que pide (en dos lineas si hace falta), la barra de
## lo que llevas y lo que paga.
func _paint_mission(m: Dictionary, y: float) -> void:
	var box := Panel.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(MISSION_X, y)
	box.size = Vector2(MISSION_W, MISSION_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.NIGHT
	sb.border_color = Palette.GOLD_D
	sb.set_border_width_all(4)
	box.add_theme_stylebox_override("panel", sb)
	_missions.add_child(box)

	var lineas := UIKit.wrap(Game.mission_text(m), MISSION_W - 40.0, 21)
	for k in mini(2, lineas.size()):
		_missions.add_child(UIKit.label_at(lineas[k],
				Vector2(MISSION_X + MISSION_W * 0.5, y + 30 + k * 30),
				Vector2(MISSION_W - 40, 28), 21, Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0))
	# La barra de lo que llevas.
	var meta := 1 if str(m["type"]) == "grade" else int(m["goal"])
	var hecho := clampi(int(m["progress"]), 0, meta)
	# De izquierda a derecha: la barra (160), lo que llevas, la moneda y el premio.
	# Con la barra a 240 el "17/25" se metia debajo de la moneda.
	var barra := Rect2(MISSION_X + 20, y + 96, 160, 24)
	var fondo := ColorRect.new()
	fondo.color = Palette.NIGHT_DD
	fondo.position = barra.position
	fondo.size = barra.size
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_missions.add_child(fondo)
	var lleno := ColorRect.new()
	lleno.color = Palette.GOLD
	lleno.position = barra.position + Vector2(4, 4)
	lleno.size = Vector2((barra.size.x - 8) * float(hecho) / float(maxi(1, meta)),
			barra.size.y - 8)
	lleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_missions.add_child(lleno)
	# Lo que llevas, con la letra de los rotulos (las cifras no tienen barra).
	_missions.add_child(UIKit.label_at("%d/%d" % [hecho, meta],
			Vector2(barra.end.x + 60, barra.get_center().y), Vector2(110, 28), 21,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0))
	# El premio: la moneda y lo que paga, a la derecha.
	_missions.add_child(UIKit.square("currency_coin", Vector2(MISSION_X + 336, y + 108),
			0.08))
	var premio := PixelNumber.new()
	premio.scale_factor = 0.26
	premio.max_width = 100.0
	_missions.add_child(premio)
	premio.set_number(int(m["reward"]))
	premio.position = Vector2(MISSION_X + 364, y + 108 - premio.size.y * 0.5)


func _close() -> void:
	Sound.click()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
