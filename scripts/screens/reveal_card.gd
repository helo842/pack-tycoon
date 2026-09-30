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

func _build_title() -> void:
	# y=240 y no 140: el interior del panel empieza en y=188 (1600x960 con margen
	# de 9-slice de 8 px de arte = 128 px). A 140 el titulo se salia por arriba y
	# ademas se cruzaba con "NOTA PSA", que estaba a y=200.
	_card.add_child(UIKit.label_at("REVELADO", Vector2(960, 240), Vector2(1200, 90),
			64, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0))


func _build_object_column(rarity_id: String) -> void:
	# El interior del panel va de x=288 a x=1632. Con la columna en 500 la
	# gema se salia 60 px por la izquierda y el aviso se iba 82 px del marco.
	var centre := Vector2(560, 430)
	# Modulado en BLANCO (solo el alfa): el color de la rareza ya esta en el
	# sprite, y multiplicarlo por si mismo lo apagaba.
	var glow := UIKit.image("rarity_glow_" + rarity_id, centre, Vector2(512, 512),
			Color(1, 1, 1, 0.85))
	_card.add_child(glow)

	var art := UIKit.image(str(item.get("art", "loot_vinyl")), centre,
			Vector2(384, 384))
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

	# shrink: el nombre depende del botin, y "CARTA EDICION LIMITADA" son 22
	# caracteres (924 px a tamano 42) en una caja de 620. Sin encogerlo se sale.
	_card.add_child(UIKit.label_at(str(item.get("name", "OBJETO")),
			Vector2(560, 660), Vector2(560, 60), 42, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	# --- fila de rareza ---
	# La gema a 0,25 son 128 px: a 0,28 eran 143 y se comia el primer caracter
	# del rotulo, que empezaba en 360 y la gema acababa en 372.
	_card.add_child(UIKit.square("rarity_gem_" + rarity_id, Vector2(390, 750),
			0.25))
	_card.add_child(UIKit.label_at(Palette.RARITY_NAME.get(rarity_id, "COMUN"),
			Vector2(655, 750), Vector2(380, 60), 35,
			Palette.rarity(rarity_id), HORIZONTAL_ALIGNMENT_LEFT, 0, true))

	# --- fila de conservacion ---
	var cond: Dictionary = item.get("condition", {})
	var cond_art := str(cond.get("art", "condition_good"))
	_card.add_child(UIKit.art(cond_art, Vector2(390, 818), 0.25))
	# Solo el nombre: el estado se deduce de la nota y ya no multiplica por su
	# cuenta, asi que poner un "x1.25" aqui seria mentir sobre como se calcula el
	# valor. El premio de la nota se ve en el escudo de al lado.
	# shrink: el nombre del estado va de "COMO NUEVO" a "COMO NUEVO" (10 ch,
	# 350 px a tamano 35) en una caja de 440. Encogido por si se alarga.
	# y=818 y no 845: la fila de estado se sube para dejarle sitio al aviso de
	# abajo. Con las dos a 845 el texto se leia encima del "BUEN ESTADO".
	_card.add_child(UIKit.label_at(str(cond.get("name", "BUEN ESTADO")),
			Vector2(655, 818), Vector2(420, 60), 35,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_LEFT, 0, true))


## La columna derecha. Todas las medidas estan dentro del recuadro interior del
## panel, que en un panel de 1600x960 con margen de 8 arte-px va de x 288 a
## 1632 y de y 188 a 952. Pasarse se ve: el boton se salia por abajo.
func _build_grade_column() -> void:
	# cx=1240 y no 1290: con diez estrellas de 62 la fila media 692 px y
	# centrada en 1290 llegaba a 1636, cuatro pixeles por fuera del interior
	# (1632). A 1240 y con 58 de estrella la fila ocupa 652 y entra de sobra.
	var cx := 1240.0
	# La columna derecha se reparte entre 188 y 892, que es donde llega el
	# interior del panel. Antes el boton estaba en y=860 con 160 de alto, o sea
	# de 780 a 940: salia por debajo del marco y ademas tapaba el valor.
	_card.add_child(UIKit.label_at("NOTA PSA", Vector2(cx, 300), Vector2(700, 50),
			35, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true))

	# El escudo (grade_badge) viene vacio a proposito: el numero se pinta encima
	# con la fuente de numeros del juego.
	_card.add_child(UIKit.art("grade_badge", Vector2(cx, 420), 0.74))
	var grade := int(item.get("grade", 1))
	var num := PixelNumber.new()
	num.scale_factor = 0.55
	num.max_width = 150.0
	_card.add_child(num)
	num.set_number(grade)
	# El numero va CENTRADO en el escudo, que ahora esta en y=420.
	num.position = Vector2(cx, 420) - num.size * 0.5

	# La cinta va detras y a todo lo ancho: el sprite sangra por los dos lados
	# para eso, como banda sobre la que seLean las estrellas.
	_card.add_child(UIKit.image("grade_ribbon", Vector2(cx, 570), Vector2(680, 130)))

	# Diez estrellas: llenas hasta la nota y vacias detras. Asi se ve de un
	# vistazo cuanto falta para el 10.
	var stars := LootDB.grade_stars(grade)
	var size := 58.0
	var gap := 8.0
	var total := 10.0 * size + 9.0 * gap
	var x := cx - total * 0.5
	for i in 10:
		var tex := "grade_star_full" if i < stars else "grade_star_empty"
		_card.add_child(UIKit.image(tex, Vector2(x + size * 0.5, 570),
				Vector2(size, size)))
		x += size + gap


func _build_value() -> void:
	var cx := 1290.0
	_card.add_child(UIKit.label_at("VALOR", Vector2(cx, 680), Vector2(700, 50), 35,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0))
	# y=725: el numero mide 45 de alto, asi que a 740 llegaba hasta 762 y el
	# boton de GUARDAR empieza en 774. Quedaban 12 px, que en pantalla son 4 y
	# se leen como pegados. A 725 el hueco es de 27.
	var y := 725.0
	# La moneda a cx-200 y el numero a cx+30 dejaban el par descentrado: el
	# ojo iba a la moneda y el numero parecia algo suelto a su derecha.
	_card.add_child(UIKit.square("currency_coin", Vector2(cx - 150, y), 0.20))
	var num := PixelNumber.new()
	num.scale_factor = 0.62
	num.max_width = 420.0
	_card.add_child(num)
	num.set_number(int(item.get("value", 0)))
	# set_number() ya deja el size puesto, asi que se puede centrar sin adivinar.
	num.position = Vector2(cx + 60, y) - num.size * 0.5


## Los dos botones de decision: GUARDAR (al inventario) y VENDER (dinero ahora).
##
## Van sin icono a proposito. Las chapas son de 340x170 y el icono de
## plate_button mide el 58 % del alto (unos 99 px), asi que con icono el hueco
## del texto bajaba a 181 px y "GUARDAR" salia a 21 px. Sin el, el texto sube a
## 35 px, que es lo que estas dos acciones se merecen: son LA decision de la
## pantalla, no un boton secundario.
##
## Los dos empiezan en x=920 para no tocar la columna izquierda: el rotulo del
## estado llega hasta x=865 y el aviso de abajo hasta x=900.
func _build_buttons() -> void:
	var guardar := UIKit.plate_button("GUARDAR", "", Vector2(1090, 845),
			Vector2(340, 170), 40)
	guardar.pressed.connect(_store)
	_card.add_child(guardar)

	var vender := UIKit.plate_button("VENDER", "", Vector2(1462, 845),
			Vector2(340, 170), 40)
	vender.pressed.connect(_sell)
	_card.add_child(vender)

	# El aviso va en la columna izquierda, no debajo de la tarjeta: a y=920
	# estaba fuera del panel y se leia sobre el fondo. Y va como hijo de _card,
	# no de este nodo: sus coordenadas son las del panel, y colgado de aqui
	# caia en otro sitio y se leia encima de la fila de estado.
	# Dice lo que hace la TERCERA salida (cerrar sin elegir), que es el aviso
	# que hace falta ahora: antes bastaba un "continuar" porque cerrar guardaba
	# el objeto solo, y ahora ya no.
	var hint := UIKit.label_at("ESPACIO O CLIC PARA DEJARLO", Vector2(590, 880),
			Vector2(620, 40), 21, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0, true)
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
