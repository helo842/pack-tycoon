# Sprite3DKit - las mismas piezas que UIKit, pero para el mundo 3D.
#
# El juego pasa a ser 3D de verdad: la mesa, los sobres y el botin son nodos 3D
# (Sprite3D y MeshInstance3D) y no Controls. Lo que NO cambia es el arte: los
# mismos PNG del kit se pegan en quad 3D, asi que el catalogo entero (17 objetos,
# 4 cartas, los paquetes) sigue valiendo tal cual.
#
# LA ESCALA
# ---------
# PIXEL = 0.01 es lo que hace que el mundo 3D hable el mismo idioma que el 2D:
# un pixel logico (los de TABLE_RECT, los de TableElement.BOX) son 0.01
# unidades. Con eso las medidas del juego -que estan pensadas en pixeles- se
# pueden usar tal cual en 3D sin convertirlas a mano en cada sitio, y un cambio
# de balance que mueva una x en 2D mueve lo mismo en 3D.
#
# Es ademas el pixel_size por defecto de Sprite3D, asi que un sprite de 512 se
# dibuja de 5.12 unidades: solo hay que escalarlo para que mida lo que mide en 2D
# (ver size_px).
class_name Sprite3DKit
extends RefCounted

## Un pixel logico = 0.01 unidades. Ver la cabecera.
const PIXEL := 0.01

## El filtro de todos los materiales del mundo. NEAREST y no LINEAR: el arte es
## pixel art y suavizarlo lo ensucia, que es lo mismo que pide project.godot para
## las texturas del canvas.
const FILTER := BaseMaterial3D.TEXTURE_FILTER_NEAREST


## Un sprite 3D con el tamano que tendria en 2D, en pixeles logicos.
##
## Sprite3D escala con `scale`, y su tamano natural es el de la textura x
## `pixel_size`. Aqui se le pasa el tamano que se quiere (el mismo numero que se
## le pasaria a UIKit.image) y se calcula el factor: 512 de textura con 256
## pedidos son escala 0.5.
static func sprite(sprite_name: String, size_px: Vector2,
		modulate: Color = Color.WHITE) -> Sprite3D:
	var s := Sprite3D.new()
	var t := Sprites.tex(sprite_name)
	s.texture = t
	s.pixel_size = PIXEL
	s.texture_filter = FILTER
	s.centered = true
	s.modulate = modulate
	var base := Vector2(512.0, 512.0)
	if t != null and t.get_width() > 0 and t.get_height() > 0:
		base = Vector2(t.get_width(), t.get_height())
	s.scale = Vector3(size_px.x / base.x, size_px.y / base.y, 1.0)
	return s


## Un quad de color plano, sin textura. Es el equivalente 3D de los ColorRect que
## el juego usa para la barra de resistencia: informacion, no arte.
##
## El tamano va en pixeles logicos. `size` del QuadMesh se puede tocar despues
## (es lo que hace la barra al bajar).
static func quad(size_px: Vector2, color: Color, priority: int = 0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size_px * PIXEL
	var m := MeshInstance3D.new()
	m.mesh = q
	m.material_override = flat_material(color)
	priority_of(m, priority)
	return m


## Cambia el orden de dibujo de un nodo translucido.
##
## NO es una tonteria de cada tipo de nodo, y por eso esta aqui: Sprite3D y
## Label3D llevan `render_priority` en el nodo, y MeshInstance3D no lo tiene
## -el suyo va en el MATERIAL-. Escribirlo a mano en cada sitio era una fuente de
## errores de compilacion garantizada ("render_priority not declared"), asi que
## se pregunta y se pone donde toca.
static func priority_of(node: Node, priority: int) -> void:
	if node == null:
		return
	if node.get("render_priority") != null:
		node.set("render_priority", priority)
		return
	if node is MeshInstance3D and node.material_override != null:
		node.material_override.render_priority = priority


## Un material plano y sin luz, con el color exacto de la paleta.
static func flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.texture_filter = FILTER
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Un quad tumbado (el suelo y la mesa), con una textura. PlaneMesh ya nace en el
## plano XZ, asi que no hay que rotarlo.
static func floor(sprite_name: String, size_units: Vector2) -> MeshInstance3D:
	var p := PlaneMesh.new()
	p.size = size_units
	var m := MeshInstance3D.new()
	m.mesh = p
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = Sprites.tex(sprite_name)
	mat.texture_filter = FILTER
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	return m
