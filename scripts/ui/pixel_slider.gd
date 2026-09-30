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


func _draw() -> void:
	var track := Sprites.tex("ui_slider_track")
	if track != null:
		draw_texture_rect(track, Rect2((size - track_size) * 0.5, track_size), false)
	var knob := Sprites.tex("ui_slider_knob")
	if knob != null:
		draw_texture_rect(knob, _knob_rect(), false)


func _knob_rect() -> Rect2:
	var x := (size.x - knob_size.x) * value
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _dragging:
		_dragging = false


func _set_from_x(x: float) -> void:
	var usable := maxf(1.0, size.x - knob_size.x)
	value = (x - knob_size.x * 0.5) / usable
