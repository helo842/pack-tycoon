# RevealCard - la tarjeta de revelado.
#
# Es lo que sale cuando un paquete se abre: el objeto con su rareza, su estado
# de conservacion, la nota PSA y lo que vale. Es una ventana modal: hasta que no
# se cierra no se puede tocar la mesa.
#
# Las cinco cosas que se ensean estan separadas a proposito, porque son las
# cuatro variables del objeto mas el resultado:
#   objeto + rareza (a la izquierda)  ->  que es
#   conservacion + nota (a la derecha) ->  en que estado
#   valor (abajo)                      ->  cuanto dinero da
class_name RevealCard
extends Control

## Que ha decidido el jugador con el objeto: "store" (al inventario), "sell"
## (venderlo) o "later" (cerrar sin decidir, y el objeto se queda en la mesa).
##
## Hay que decirlo, y no basta con "se ha cerrado": el objeto ya no se guarda
## solo al salir de la tarjeta, asi que quien la cierre tiene que saber si el
## jugador eligio guardar, vender o dejarlo.
signal resolved(action: String)

const PANEL := "ui_panel_reveal"
const ACTION_STORE := "store"
const ACTION_SELL := "sell"
const ACTION_LATER := "later"

var item: Dictionary = {}

var _card: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# El destello de fondo, del color de la rareza: es el unico sitio donde se
	# usa el alfa graduado del sprite y por eso se nota.
	var rarity_id := str(item.get("rarity", "common"))
	var veil := UIKit.veil(0.72)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var flash := ColorRect.new()
	flash.color = Palette.rarity(rarity_id, 0.0)
	flash.size = Vector2(1920, 1080)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.45, 0.10)
	ft.tween_property(flash, "color:a", 0.0, 0.55)

	# El panel se anade ANTES que _card: el orden de add_child es el orden de
	# capas, y si el panel fuera despues taparia justo lo que quiere enseñar.
	add_child(UIKit.panel(PANEL))

	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	_build_title()
	_build_object_column(rarity_id)
	_build_grade_column()
	_build_value()
	_build_buttons()

	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK)
	pop.set_ease(Tween.EASE_OUT)
	_card.scale = Vector2(0.86, 0.86)
	_card.pivot_offset = Vector2(960, 540)
	pop.tween_property(_card, "scale", Vector2.ONE, 0.28)


func show_item(data: Dictionary) -> void:
	item = data


# --------------------------------------------------------------------------- #
# El diseno
# --------------------------------------------------------------------------- #
#
# El interior del panel va de x 288 a 1632 y de y 188 a 952. Se reparte asi:
#
#   y 208..296   la FRANJA del color de la rareza, con el NOMBRE del objeto: es
#                lo primero que se lee (antes era un "REVELADO" que no decia nada
#                y el nombre iba pequeno debajo del dibujo)
#   izquierda    la VITRINA: el objeto grande sobre su pedestal, con el brillo de
#                la rareza detras y el borde de su color; debajo, la gema y la
#                rareza
#   derecha      la FUNDA PSA, como las de verdad: la etiqueta crema con la nota
#                enorme y el estado, y las diez estrellas dentro de la funda (antes
#                iban sobre una cinta roja que se comia las estrellas vacias)
#   abajo dcha.  el VALOR y los dos botones
#
# Todas las cajas son StyleBoxFlat en colores de la paleta y medidas multiplo de
# 8, para que no desentonen con el pixel art de los sprites.

const BAND := Rect2(288, 208, 1344, 88)
const SHOWCASE := Rect2(336, 328, 560, 456)
const SHOWCASE_ART := 336.0
const SLAB := Rect2(952, 328, 632, 320)
const SLAB_LABEL := Rect2(976, 352, 584, 152)
const SLAB_STARS_Y := 584.0
const VALUE_Y := 704.0
const BUTTONS_Y := 856.0


## Una caja plana con borde, en coordenadas de la tarjeta.
func _box(rect: Rect2, bg: Color, border: Color, width: int = 4) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	p.add_theme_stylebox_override("panel", sb)
	_card.add_child(p)
	return p


func _build_title() -> void:
	var rarity_id := str(item.get("rarity", "common"))
	var c := Palette.rarity(rarity_id)
	# La franja: el color de la rareza oscurecido de fondo y el puro en los
	# filos, de lado a lado del interior del panel.
	# El oro oscurecido sale verde oliva, asi que el legendario lleva el naranja
	# oscuro del marco del panel.
	var fondo := Palette.GOLD_D if rarity_id == "legendary" else c.darkened(0.55)
	_box(BAND, fondo, c, 0)
	for y in [BAND.position.y, BAND.end.y - 4.0]:
		var filo := ColorRect.new()
		filo.color = c
		filo.position = Vector2(BAND.position.x, y)
		filo.size = Vector2(BAND.size.x, 4)
		filo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card.add_child(filo)
	# shrink: "CARTA EDICION LIMITADA" son 22 letras; a 49 no caben en 1200.
	_card.add_child(UIKit.label_at(str(item.get("name", "OBJETO")),
			BAND.get_center(), Vector2(1200, 70), 49, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))


func _build_object_column(rarity_id: String) -> void:
	var c := Palette.rarity(rarity_id)
	# La vitrina: fondo de noche y el borde de la rareza.
	_box(SHOWCASE, Palette.NIGHT_D, c, 4)
	var centre := SHOWCASE.get_center() + Vector2(0, -16)
	# El brillo de la rareza detras del objeto, latiendo despacio.
	var glow := UIKit.image("rarity_glow_" + rarity_id, centre, Vector2(480, 480),
			Color(1, 1, 1, 0.9))
	_card.add_child(glow)
	var gt := create_tween().set_loops()
	gt.tween_property(glow, "modulate:a", 0.45, 1.1)
	gt.tween_property(glow, "modulate:a", 0.9, 1.1)
	# El pedestal: una peana de dos escalones bajo el objeto.
	var peana_y := SHOWCASE.end.y - 64.0
	_box(Rect2(centre.x - 136, peana_y, 272, 24), c.darkened(0.45), Palette.OUTLINE, 4)
	_box(Rect2(centre.x - 132, peana_y + 4, 264, 4), c.lightened(0.15), c, 0)
	_box(Rect2(centre.x - 168, peana_y + 20, 336, 32), c.darkened(0.65), Palette.OUTLINE, 4)

	var art := UIKit.image(str(item.get("art", "loot_vinyl")), centre,
			Vector2(SHOWCASE_ART, SHOWCASE_ART))
	_card.add_child(art)
	art.scale = Vector2(0.7, 0.7)
	art.pivot_offset = art.size * 0.5
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(art, "scale", Vector2.ONE, 0.30)

	var shine := UIKit.art("fx_shine", centre, 1.3, Color(1, 1, 1, 0.0))
	_card.add_child(shine)
	var st := create_tween()
	st.tween_interval(0.18)
	st.tween_property(shine, "modulate:a", 0.85, 0.18)
	st.tween_property(shine, "modulate:a", 0.0, 0.35)
	# La rareza, debajo de la vitrina: la gema y el nombre, juntos y centrados.
	var fila_y := SHOWCASE.end.y + 52.0
	var nombre := str(Palette.RARITY_NAME.get(rarity_id, "COMUN"))
	var ancho := 72.0 + 16.0 + UIKit.text_width(nombre, 35)
	var x0 := SHOWCASE.get_center().x - ancho * 0.5
	_card.add_child(UIKit.square("rarity_gem_" + rarity_id, Vector2(x0 + 36, fila_y),
			0.14))
	_card.add_child(UIKit.label_at(nombre, Vector2(x0 + 88 + UIKit.text_width(nombre, 35)
			* 0.5, fila_y), Vector2(UIKit.text_width(nombre, 35), 50), 35, c,
			HORIZONTAL_ALIGNMENT_CENTER, 0))


## La funda PSA: una caja de plastico (gris claro) con la etiqueta crema arriba y
## las estrellas dentro.
func _build_grade_column() -> void:
	var grade := int(item.get("grade", 1))
	_box(SLAB, Color(Palette.NIGHT_LL), Palette.CREAM_D, 4)
	_box(SLAB.grow(-12), Palette.NIGHT_L, Palette.NIGHT, 4)
	# La etiqueta: roja con el filo claro, como la de las fundas de verdad. Roja
	# y no crema porque la letra del juego lleva su contorno oscuro: en oscuro
	# sobre crema se empastaba, y en crema sobre rojo se lee con la misma letra.
	_box(SLAB_LABEL, Color8(132, 52, 36), Palette.RUST_L, 8)
	var lx := SLAB_LABEL.position.x + 32.0
	_card.add_child(UIKit.label_at("PSA", Vector2(lx + 63, SLAB_LABEL.position.y + 46),
			Vector2(126, 50), 42, Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0))
	var cond: Dictionary = item.get("condition", {})
	_card.add_child(UIKit.art(str(cond.get("art", "condition_good")),
			Vector2(lx + 28, SLAB_LABEL.position.y + 108), 0.16))
	_card.add_child(UIKit.label_at(str(cond.get("name", "BUEN ESTADO")),
			Vector2(lx + 72 + 140, SLAB_LABEL.position.y + 108), Vector2(280, 40), 28,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0, true))
	# La nota, ENORME, en su recuadro rojo a la derecha de la etiqueta.
	var nota_box := Rect2(SLAB_LABEL.end.x - 176, SLAB_LABEL.position.y + 16, 152, 120)
	_box(nota_box, Palette.CREAM_L, Palette.OUTLINE, 4)
	var num := PixelNumber.new()
	num.scale_factor = 0.9
	num.max_width = nota_box.size.x - 24.0
	_card.add_child(num)
	num.set_number(grade)
	num.position = nota_box.get_center() - num.size * 0.5

	# Las diez estrellas, dentro de la funda y sobre su fondo oscuro.
	var stars := LootDB.grade_stars(grade)
	var size := 48.0
	var gap := 8.0
	var total := 10.0 * size + 9.0 * gap
	var x := SLAB.get_center().x - total * 0.5
	for i in 10:
		var tex := "grade_star_full" if i < stars else "grade_star_empty"
		_card.add_child(UIKit.image(tex, Vector2(x + size * 0.5, SLAB_STARS_Y),
				Vector2(size, size)))
		x += size + gap


func _build_value() -> void:
	var cx := SLAB.get_center().x
	_card.add_child(UIKit.label_at("VALOR", Vector2(SLAB.position.x + 72, VALUE_Y),
			Vector2(144, 50), 35, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0))
	_card.add_child(UIKit.square("currency_coin", Vector2(cx - 40, VALUE_Y), 0.18))
	var num := PixelNumber.new()
	num.scale_factor = 0.62
	num.max_width = 360.0
	_card.add_child(num)
	num.set_number(int(item.get("value", 0)))
	num.position = Vector2(cx + 16, VALUE_Y - num.size.y * 0.5)


## Los dos botones de decision: GUARDAR (al inventario) y VENDER (dinero ahora),
## sin icono para que el texto salga grande: son LA decision de la pantalla.
func _build_buttons() -> void:
	var guardar := UIKit.plate_button("GUARDAR", "", Vector2(SLAB.position.x + 152,
			BUTTONS_Y), Vector2(304, 152), 35)
	guardar.pressed.connect(_store)
	_card.add_child(guardar)

	var vender := UIKit.plate_button("VENDER", "", Vector2(SLAB.end.x - 152, BUTTONS_Y),
			Vector2(304, 152), 35)
	vender.pressed.connect(_sell)
	_card.add_child(vender)

	# La tercera salida (cerrar sin elegir), debajo de la rareza.
	var hint := UIKit.label_at("ESPACIO O CLIC PARA DEJARLO EN LA MESA",
			Vector2(SHOWCASE.get_center().x, SHOWCASE.end.y + 112), Vector2(560, 32),
			21, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
	_card.add_child(hint)


# --------------------------------------------------------------------------- #

## Al inventario. Si esta lleno, Game.store() lo vende y avisa el solo.
func _store() -> void:
	_finish(ACTION_STORE)


## Dinero ahora.
func _sell() -> void:
	_finish(ACTION_SELL)


## Cerrar sin elegir: el objeto se queda en la mesa, donde se puede mover y
## vender con un clic, como cualquier otro botin.
func _dismiss() -> void:
	_finish(ACTION_LATER)


func _finish(action: String) -> void:
	resolved.emit(action)
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()
