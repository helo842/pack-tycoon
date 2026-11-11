# PixelSlider - deslizador con el aspecto de ui_slider_track / ui_slider_knob.
#
# El HSlider de Godot brings su propio estilo, que aqui romperia el pixel art, y
# ademas el grosor de la pista tiene que ser el del sprite. Se hace a mano: la
# pista es el sprite entero y el pomo se mueve encima.
class_name PixelSlider
extends Control

signal value_changed(value: float)

## Ancho y alto de la pista importada, ya al tamano final.
@export var track_size: Vector2 = Vector2(416, 48)
@export var knob_size: Vector2 = Vector2(64, 96)

var value: float = 0.7:
	set(v):
		var nv := clampf(v, 0.0, 1.0)
		if is_equal_approx(nv, value):
			return
		value = nv
		_move_knob()
		value_changed.emit(value)

var _dragging := false


func _init() -> void:
	custom_minimum_size = track_size
	size = track_size


func _ready() -> void:
	# La pista y el pomo se pintan en _draw: asi el pomo queda por encima de la
	# pista sin tener que estar moviendo el orden de los hijos.
	set_process_input(true)
	_move_knob()


## Un pixel de arte, en pantalla: la pista (52x6 de arte) se pinta a 416x48 y el
## mando (8x12) a 64x96, o sea 8 px por pixel de arte en los dos.
const ART_PX := 8.0


func _draw() -> void:
	var pista := _track_rect()
	var track := Sprites.tex("ui_slider_track")
	if track != null:
		draw_texture_rect(track, pista, false)
	# EL RELLENO: el hueco de la canaleta (filas 2-3 del arte, desde la columna 2)
	# en dorado hasta el centro del mando, para que se lea el volumen de un vistazo.
	# Se ajusta a la rejilla de 8 px para no romper el pixelado.
	var desde := pista.position.x + ART_PX * 2.0
	var hasta := snappedf(_knob_rect().get_center().x, ART_PX)
	if hasta > desde:
		draw_rect(Rect2(desde, pista.position.y + ART_PX * 2.0, hasta - desde, ART_PX),
			Palette.GOLD_D)
		draw_rect(Rect2(desde, pista.position.y + ART_PX * 3.0, hasta - desde, ART_PX),
			Palette.GOLD)
	var knob := Sprites.tex("ui_slider_knob")
	if knob != null:
		draw_texture_rect(knob, _knob_rect(), false)


## Donde va la pista: centrada en el control. El control puede ser mas grande que
## la pista (el panel de ajustes lo hace de 560 para que el clic sea comodo), y
## por eso el mando se mueve DENTRO DE LA PISTA y no de punta a punta del control:
## antes, a 0 se salia 72 px por la izquierda y se metia encima del rotulo.
func _track_rect() -> Rect2:
	return Rect2(((size - track_size) * 0.5).round(), track_size)


func _knob_rect() -> Rect2:
	var pista := _track_rect()
	var x := pista.position.x + (pista.size.x - knob_size.x) * value
	return Rect2(Vector2(x, (size.y - knob_size.y) * 0.5), knob_size)


func _move_knob() -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_from_x(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()


## EL ARRASTRE NO SE CORTA AL SALIR DE LA BARRA: Godot sigue mandando el
## movimiento al control en el que empezo el clic hasta que se suelta, y eso es lo
## que deja llevar el pomo a 0 (o a 1) pasandose del borde. Antes se cortaba al
## salir, y un arrastre rapido hacia la izquierda se quedaba en un 3-5 %: para
## silenciar habia que ir despacito hasta el borde exacto.


func _set_from_x(x: float) -> void:
	var pista := _track_rect()
	var usable := maxf(1.0, pista.size.x - knob_size.x)
	value = (x - pista.position.x - knob_size.x * 0.5) / usable
