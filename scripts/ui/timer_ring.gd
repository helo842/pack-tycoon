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

## LAS ZONAS DEL GOLPE PERFECTO, pintadas en el trozo del anillo que todavia no
## se ha recorrido: asi se ve DE ANTEMANO donde hay que pulsar, y no solo cuando
## ya se esta dentro. Con -1 no se pintan (ver TableElement._build_pack).
var zone_from := -1.0
var sweet_from := -1.0
var sweet_to := -1.0
const ZONE_COLOR := Palette.TEAL_L
const SWEET_COLOR := Color.WHITE

const BAND_IN := 6.0      # radio interior en celdas de rejilla
const BAND_OUT := 7.6     # radio exterior
const HEAD := 0.05        # cuanto se alarga la cabeza brillante


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(256, 256)


## La pista leida pixel a pixel, para saber que celdas son BORDE (ver _is_edge).
## Es la misma para todos los anillos, asi que se lee una vez.
static var _track_img: Image = null


## ¿Es borde esta celda del sprite? El anillo pintado no es un circulo perfecto
## (es pixel art), asi que la banda de radios de BAND_IN a BAND_OUT pilla a veces
## celdas del contorno oscuro o de fuera del dibujo. Esas no se pintan nunca: se
## pintaban, y el anillo salia con trozos del borde de color en vez de negros.
static func _is_edge(track: Texture2D, uv: Vector2) -> bool:
	if _track_img == null:
		_track_img = track.get_image()
		if _track_img != null and _track_img.is_compressed():
			_track_img.decompress()
	if _track_img == null:
		return false
	var px := _track_img.get_pixelv(Vector2i(
			clampi(int(uv.x * _track_img.get_width()), 0, _track_img.get_width() - 1),
			clampi(int(uv.y * _track_img.get_height()), 0, _track_img.get_height() - 1)))
	# Fuera del dibujo (transparente) o el contorno azul noche (Palette.OUTLINE).
	return px.a < 0.5 or (px.b > px.r + 0.04 and px.v < 0.3)


func _draw() -> void:
	var track := Sprites.tex("ui_timer_track")
	if track != null:
		draw_texture_rect(track, Rect2(Vector2.ZERO, size), false)

	var cell := Vector2(size.x, size.y) / float(GRID)
	var c := Vector2(size.x, size.y) * 0.5
	for gx in GRID:
		for gy in GRID:
			var centre := Vector2(gx + 0.5, gy + 0.5) * cell
			var d := centre - c
			var r := d.length() / cell.x
			if r < BAND_IN or r > BAND_OUT:
				continue
			if track != null and _is_edge(track, centre / size):
				continue
			# angulo medido desde las 12 en punto, en sentido horario
			var t := fposmod(PI * 0.5 - atan2(-d.y, d.x), TAU) / TAU
			if t > progress or progress <= 0.0:
				# Sin recorrer: solo se pinta si es una de las zonas del perfecto.
				if sweet_from >= 0.0 and t >= sweet_from and t < sweet_to:
					draw_rect(Rect2(Vector2(gx, gy) * cell, cell), SWEET_COLOR)
				elif zone_from >= 0.0 and t >= zone_from:
					draw_rect(Rect2(Vector2(gx, gy) * cell, cell), ZONE_COLOR)
				continue
			var col := ring_color if r > (BAND_IN + BAND_OUT) * 0.5 else inner_color
			if t >= progress - HEAD:
				col = head_color
			draw_rect(Rect2(Vector2(gx, gy) * cell, cell), col)
