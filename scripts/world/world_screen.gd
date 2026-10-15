# WorldScreen - una pantalla de verdad en el mundo.
#
# LOS PANELES DEL JUEGO NO SE HAN REESCRITO. Siguen siendo los mismos Control de
# siempre (ShopPanel, LockerPanel, RebirthPanel...), con su maquetacion en
# pixeles de 1920x1080. Lo unico que cambia es DONDE se dibujan: en vez de
# colgarse encima de la pantalla del jugador, cuelgan de un SubViewport cuyo
# lienzo se pega en un quad 3D. Asi la tienda es un monitor al que te acercas,
# el armario una vitrina con su pantalla y la hucha un altar: lo que antes era
# un menu que tapaba el juego ahora es un cacharro de la habitacion.
#
# LA ENTRADA VA POR RAYO. Un SubViewport que no esta dentro de un
# SubViewportContainer no recibe el raton solo: hay que darselo a mano. Lo que
# hace feed() es convertir el punto del raton de la pantalla del jugador en un
# pixel del lienzo (a traves de la UV del quad) y empujar ahi el evento. El
# inverso -de un pixel del lienzo a un punto del mundo- es
# world_point_for_canvas(), y lo usan las pruebas para clicar un boton del panel
# como lo haria un dedo: apuntando al sitio donde se ve.
#
# `region` es que trozo del lienzo se ve en el cristal. La maquina de sobres lo
# usa para enseñar SOLO la columna de sobres (que en el lienzo de 1920x1080 ocupa
# su franja de la izquierda) en lugar de un lienzo entero con la columna en una
# esquina y negro por todo lo demas.
class_name WorldScreen
extends Node3D

## El lienzo de los paneles: el mismo de la pantalla del juego, que es para el
## que estan maquetados todos los Control.
const CANVAS := Vector2i(1920, 1080)

## El color del cristal apagado. Un quad sin textura se dibuja blanco y una
## pantalla apagada tiene que ser una mancha oscura.
const COLOR_OFF := Color(0.09, 0.08, 0.13, 1.0)

## El trozo del lienzo que se ve, en pixeles del lienzo.
var region := Rect2(0, 0, 1920, 1080)
## El tamano del cristal en el mundo, en unidades.
##
## Es un SETTER y no una variable pelada porque la malla se construye en el
## _init(), que corre antes de que quien lo monta pueda asignarle el tamano: sin
## esto el quad se queda con el tamano por defecto y el cristal sale del tamano
## que no es (el panel se ve enorme y descentrado, y como uv_at() sigue midiendo
## con el tamano pedido, los clics caen donde NO se ve el boton).
var size_units := Vector2(3.2, 1.8):
	set(v):
		size_units = v
		if quad != null:
			(quad.mesh as QuadMesh).size = v
## La lampara que se enciende con la pantalla: da el pego de que la pantalla
## alumbra lo que tiene delante.
var lamp_energy := 1.6
var lamp_color := Color(1.0, 0.85, 0.6)

var viewport: SubViewport = null
## El Control raiz del lienzo, donde se cuelgan los paneles.
var stage: Control = null
var quad: MeshInstance3D = null

var _mat: StandardMaterial3D = null
var _lamp: OmniLight3D = null
var _lit := false


func _init() -> void:
	viewport = SubViewport.new()
	viewport.name = "Panel"
	viewport.size = CANVAS
	# El lienzo es solo interfaz: sin 3D dentro se ahorra medio viewport.
	viewport.disable_3d = true
	# Opaco: un monitor no deja ver la pared que tiene detras. El negro de fondo
	# es el que hace que los paneles (que traen su propio velo) se lean.
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)

	stage = Control.new()
	stage.name = "Stage"
	stage.size = Vector2(CANVAS)
	# IGNORE: quien corta el raton son los controles del panel, que son los que
	# tienen que recibirlo. El lienzo entero no puede comerse nada.
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(stage)

	# El cristal, un quad que mira a +Z (que es la direccion a la que apunta el
	# nodo, asi que la pantalla "mira" hacia donde mira la estacion que la lleva).
	var q := QuadMesh.new()
	q.size = size_units
	quad = MeshInstance3D.new()
	quad.name = "Glass"
	quad.mesh = q
	_mat = StandardMaterial3D.new()
	# Unshaded: una pantalla emite luz, no la recibe. Y asi los colores del panel
	# salen tal cual, sin que la lampara de la sala los tina.
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# LINEAR y no NEAREST como el resto del juego: aqui no se ven pixeles de
	# arte, se ve un lienzo de 1920x1080 reducido a tres unidades, y con NEAREST
	# el texto pequeno se rompe en escalones.
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_mat.albedo_color = COLOR_OFF
	_mat.render_priority = 4
	quad.material_override = _mat
	add_child(quad)

	_lamp = OmniLight3D.new()
	_lamp.light_color = lamp_color
	_lamp.omni_range = 3.2
	_lamp.position = Vector3(0.0, 0.0, 0.5)
	_lamp.light_energy = 0.0
	add_child(_lamp)


## Enciende o apaga el cristal. Encendida RENDERIZA el lienzo cada frame (una
## pantalla con un panel dentro tiene animaciones: botones que se pulsan, fichas
## que se abren), y apagada no renderiza nada: deja de dibujar el ultimo frame,
## que en una pantalla sin panel es negro.
func set_lit(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	if on:
		_mat.albedo_texture = viewport.get_texture()
		_mat.albedo_color = Color(1, 1, 1, 1)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_mat.albedo_texture = null
		_mat.albedo_color = COLOR_OFF
	_lamp.light_energy = lamp_energy if on else 0.0


func is_lit() -> bool:
	return _lit


# --------------------------------------------------------------------------- #
# Paneles
# --------------------------------------------------------------------------- #

## Cuelga un panel en el cristal. El panel es un Control de 1920x1080 tal cual,
## asi que se le fija el tamano: dentro de un SubViewport no hay ventana que se
## lo de, y sin esto los controles anclados salen con el tamano de su minimo.
func show_panel(panel: Control) -> void:
	# El panel se estira por ANCLAS y no por un tamano puesto a mano: los paneles
	# del juego ya vienen anclados a pantalla completa, y asignarles el tamano a
	# un Control anclado es pedirle a Godot que lo ignore (avisa por consola).
	# El lienzo mide 1920x1080, que es para lo que estan montados todos.
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(panel)
	set_lit(true)


## Quita el panel que hubiera. La pantalla se queda encendida y en negro: es lo
## que se ve al cerrar un panel (el monitor sigue ahi).
func clear_panel() -> void:
	for c in stage.get_children():
		# Los paneles del juego se borran solos al cerrarse (su _close() hace
		# queue_free y avisa por la señal `closed`), asi que puede llegarse aqui
		# con uno ya en la cola de borrado.
		if c.is_queued_for_deletion():
			continue
		stage.remove_child(c)
		c.queue_free()


func panel() -> Control:
	return stage.get_child(0) as Control if stage.get_child_count() > 0 else null


# --------------------------------------------------------------------------- #
# Raton
# --------------------------------------------------------------------------- #

## La UV (0..1) del cristal por la que pasa un rayo, o null si el rayo no le da
## o le da por detras. El cuarto valor de retorno que se usa es "null", asi que
## el tipo es Variant: un Vector2 o nada.
func uv_at(origin: Vector3, dir: Vector3) -> Variant:
	if quad == null:
		return null
	var inv := quad.global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 0.000001:
		return null
	var t := -o.z / d.z
	if t <= 0.0:
		return null
	var p := o + d * t
	var half := size_units * 0.5
	if absf(p.x) > half.x or absf(p.y) > half.y:
		return null
	# La UV de un QuadMesh de Godot va con la v creciendo hacia ARRIBA, o sea al
	# reves que el lienzo (donde la y crece hacia abajo). Aqui se pasa ya a
	# coordenadas de lienzo, que es de lo que hablan show_panel y feed().
	return Vector2(p.x / size_units.x + 0.5, 0.5 - p.y / size_units.y)


## Un punto de LIENZO (pixeles del panel: 1920x1080) llevado al mundo. Es lo que
## necesitan las pruebas para clicar un boton del panel: se apunta al sitio
## donde el boton se ve, no a una coordenada inventada.
func world_point_for_canvas(canvas: Vector2) -> Vector3:
	var u := (canvas.x - region.position.x) / region.size.x
	var v := (canvas.y - region.position.y) / region.size.y
	var local := Vector3((u - 0.5) * size_units.x, (0.5 - v) * size_units.y, 0.0)
	return quad.global_transform * local


## Reenvia al panel un evento que ha pasado por encima del cristal en la UV
## `uv`. El evento se copia: el original lo sigue necesitando el juego (el mismo
## clic puede tener que mirar la mesa si no le ha dado a la pantalla).
func feed(event: InputEvent, uv: Vector2) -> void:
	var at := region.position + Vector2(uv.x * region.size.x, uv.y * region.size.y)
	var e := event.duplicate()
	if e is InputEventMouse:
		var m := e as InputEventMouse
		m.position = at
		m.global_position = at
		if m is InputEventMouseMotion:
			# El movimiento relativo del raton de verdad no vale dentro del
			# lienzo: ahi el puntero esta quieto en el sitio donde le ha dado el
			# rayo, y lo que se mueve es la camara.
			(m as InputEventMouseMotion).relative = Vector2.ZERO
	viewport.push_input(e, true)
