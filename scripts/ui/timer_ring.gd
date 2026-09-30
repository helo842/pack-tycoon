# TimerRing - el anillo de espera de un paquete.
#
# El sprite ui_timer_fill es solo un cuarto de anillo (el generador lo hizo asi a
# proposito: "el juego lo gira cuatro veces"), y estirarlo para que crezca
# deforma el chaflan. Ademas, rellenar un sector de verdad es trabajo de shader.
#
# Asi que aqui se dibuja celda a celda sobre la misma rejilla de 16x16 del
# sprite ui_timer_track: se pinta la pista importada y encima se marcan las
# celdas cuyo angulo ya ha sido recorrido. Sale un anillo pixel a pixel de
# verdad, con el mismo grosor y los mismos colores que el sprite.
class_name TimerRing
extends Control

## Tamano de la rejilla del sprite original (ui_timer_track son 16x16 de arte).
const GRID := 16

@export var progress: float = 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()

@export var ring_color: Color = Palette.GOLD:
	set(v):
		ring_color = v
		queue_redraw()

@export var inner_color: Color = Palette.GOLD_HI:
	set(v):
		inner_color = v
		queue_redraw()

@export var head_color: Color = Palette.GOLD_XL:
	set(v):
		head_color = v
		queue_redraw()

const BAND_IN := 6.0      # radio interior en celdas de rejilla
const BAND_OUT := 7.6     # radio exterior
const HEAD := 0.05        # cuanto se alarga la cabeza brillante


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(256, 256)


func _draw() -> void:
	var track := Sprites.tex("ui_timer_track")
	if track != null:
		draw_texture_rect(track, Rect2(Vector2.ZERO, size), false)

	if progress <= 0.0:
		return

	var cell := Vector2(size.x, size.y) / float(GRID)
	var c := Vector2(size.x, size.y) * 0.5
	for gx in GRID:
		for gy in GRID:
			var centre := Vector2(gx + 0.5, gy + 0.5) * cell
			var d := centre - c
			var r := d.length() / cell.x
			if r < BAND_IN or r > BAND_OUT:
				continue
			# angulo medido desde las 12 en punto, en sentido horario
			var t := fposmod(PI * 0.5 - atan2(-d.y, d.x), TAU) / TAU
			if t > progress:
				continue
			var col := ring_color if r > (BAND_IN + BAND_OUT) * 0.5 else inner_color
			if t >= progress - HEAD:
				col = head_color
			draw_rect(Rect2(Vector2(gx, gy) * cell, cell), col)
