# TimerRing3D - el anillo de espera de un paquete, en 3D.
#
# Es el hermano 3D de TimerRing: mismo dibujo, misma API (progress y size), pero
# vive en el mundo en vez de en el canvas. Un quad que mira a +Z (a la camara) y
# un ShaderMaterial que pinta la pista del sprite y el relleno por angulo (ver
# timer_ring.gdshader). Del orden se encarga render_priority: va POR DETRAS del
# dibujo del paquete, que es lo que hace que el aro lo rodee en vez de taparlo.
class_name TimerRing3D
extends MeshInstance3D

const SHADER := preload("res://scripts/ui/timer_ring.gdshader")
const PIXEL := Sprite3DKit.PIXEL

## Tamano del anillo en pixeles logicos (el mismo numero que en 2D). El sprite
## ui_timer_track mide 256 de lienzo y su banda va de 2,3 a 8,5 celdas de radio,
## asi que a 320 px el aro sobresale del dibujo del paquete (256) por los lados.
var size := Vector2(320.0, 320.0):
	set(v):
		size = v
		_apply_size()

## Cuanto esta recorrido, de 0 a 1.
var progress := 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		if _mat != null:
			_mat.set_shader_parameter("progress", progress)
		# Sin nada recorrido el anillo no se ve: el dibujo del 2D lo apagaba
		# bajandole el alfa, y aqui se hace igual con la transparencia del nodo.
		visible = progress > 0.0

var _mat: ShaderMaterial = null


func _init() -> void:
	# La malla es un quad de 1x1 y el tamano lo pone la ESCALA (size * PIXEL), que
	# es lo que deja las dos cosas separadas: el quad no se toca al cambiar de
	# tamano y las UV siguen yendo de 0 a 1, que es lo que lee el shader.
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("track", Sprites.tex("ui_timer_track"))
	_mat.set_shader_parameter("ring_color", Palette.GOLD)
	_mat.set_shader_parameter("inner_color", Palette.GOLD_HI)
	_mat.set_shader_parameter("head_color", Palette.GOLD_XL)
	_mat.set_shader_parameter("progress", 0.0)
	material_override = _mat
	# Va DETRAS del dibujo del paquete (ver TableElement._build_pack). En 3D el
	# orden lo manda el MATERIAL y no el nodo (MeshInstance3D no tiene
	# render_priority): cuanto mas alto, mas tarde se pinta.
	_mat.render_priority = 0
	visible = false
	_apply_size()


func _apply_size() -> void:
	scale = Vector3(size.x * PIXEL, size.y * PIXEL, 1.0)
