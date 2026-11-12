# Main - el raiz. Solo cambia de pantalla y mantiene los avisos por encima.
#
# Hay tres contenedores y cada uno tiene su regla:
#   screen_host  la pantalla activa (menu o partida), una sola
#   veil_host    los paneles que tapan (tienda, ajustes): click fuera = cerrar
#   overlay_host la tarjeta de revelado, que no se puede saltar
class_name MainRoot
extends Control

const MENU_SCENE := preload("res://scenes/Menu.tscn")
const GAME_SCENE := preload("res://scenes/Game.tscn")

var _screen_host: Control
var _veil_host: Control
## Los paneles que se estan cerrando: salen del velo en el acto (has_veil() ya
## no los ve) y aqui terminan su animacion de salida antes de borrarse.
var _closing_host: Control
var _overlay_host: Control
var _toast_host: Control
var _current: Control = null
var _toast: Label = null
var _toast_tween: Tween = null

## Referencia a si mismo. Las pantallas lo usan para encontrar al padre sin
## depender de get_tree().current_scene, que solo funciona si esta escena es la
## principal (y en las pruebas no lo es).
static var instance: MainRoot = null


func _ready() -> void:
	instance = self
	_screen_host = _host("Screen")
	_veil_host = _host("Veil")
	_closing_host = _host("Closing")
	_overlay_host = _host("Overlay")
	_toast_host = _host("Toast")

	_toast = UIKit.label("", 44, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0)
	_toast.size = Vector2(1920, 70)
	_toast.position = Vector2(0, 150)
	_toast.modulate.a = 0.0
	_toast_host.add_child(_toast)

	Game.notice.connect(_on_notice)
	Game.celebrate.connect(banner)
	# La musica es la misma en el menu y en la partida: es el fondo de la
	# tienda, no de una pantalla concreta. Por eso arranca aqui, en la raiz, y
	# no la para nadie al cambiar de pantalla.
	Sound.play_music(Sound.MUSIC)
	# La historia del principio (IntroScreen) sale al abrir el juego y acaba en
	# el menu. Solo si Main es la escena principal: las pruebas de dev/ montan
	# Main a mano y esperan el menu enseguida.
	if get_tree().current_scene == self:
		_swap(IntroScreen.new())
	else:
		show_menu()


## El raiz de la partida. Devuelve null solo si aun no se ha montado.
static func get_root() -> MainRoot:
	return instance


## Un contenedor a pantalla completa donde colgar una capa (pantalla, velo,
## tarjeta o aviso).
##
## Va en MOUSE_FILTER_IGNORE y no en PASS, y no da igual: los cuatro miden
## 1920x1080 y se anaden en orden de capas, asi que el ultimo (Toast) queda
## ENCIMA de todo. Godot busca el control bajo el cursor del ultimo hijo al
## primero, y cualquier Control visible que contenga el punto cuenta, tambien
## los PASS. Con PASS, el contenedor de avisos respondia a TODOS los clics del
## juego y ningun boton llegaba a recibirlos; con IGNORE el clic cae en el
## primer hijo que si lo quiera. No hace falta que el contenedor corte nada:
## cada capa trae su propio bloqueo (el velo es un ColorRect STOP, la tarjeta
## de revelado se pone ella misma en STOP, y el aviso es un Label IGNORE).
func _host(node_name: String) -> Control:
	var c := Control.new()
	c.name = node_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


# --------------------------------------------------------------------------- #
# Cambio de pantalla
# --------------------------------------------------------------------------- #

func show_menu() -> void:
	_swap(MENU_SCENE.instantiate())


func show_game() -> void:
	_swap(GAME_SCENE.instantiate())


func _swap(next: Control) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	next.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_host.add_child(next)
	_current = next
	# El cambio de pantalla (menu <-> partida) entra fundido, no de golpe.
	next.modulate.a = 0.0
	next.create_tween().tween_property(next, "modulate:a", 1.0, 0.3)


# --------------------------------------------------------------------------- #
# Capas
# --------------------------------------------------------------------------- #

## Un panel que tapa la pantalla y se cierra con ESC.
func push_veil(panel: Control) -> void:
	_veil_host.add_child(panel)
	_pop_in(panel)


func pop_veil(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	# Sale del velo EN EL ACTO (has_veil() y quien busque en el velo ya no lo
	# ven) y se queda en _closing_host, sordo, mientras se encoge y se apaga.
	panel.process_mode = Node.PROCESS_MODE_DISABLED
	panel.propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	panel.reparent(_closing_host, false)
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 0.0, 0.14)
	tw.tween_property(panel, "scale", Vector2(0.94, 0.94), 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(panel.queue_free)


## La entrada de un panel: aparece y crece desde el centro con un pequeno
## rebote. El velo (siempre el primer hijo) se agranda por fuera de la pantalla
## para que al escalar el panel no se le vea el borde.
func _pop_in(panel: Control) -> void:
	var veil := panel.get_child(0) as ColorRect if panel.get_child_count() > 0 else null
	if veil != null:
		veil.position -= Vector2(200, 200)
		veil.size += Vector2(400, 400)
	panel.pivot_offset = Vector2(960, 540)
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.26) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func has_veil() -> bool:
	return _veil_host.get_child_count() > 0


func push_overlay(node: Control) -> void:
	_overlay_host.add_child(node)
	_pop_in(node)


func pop_overlay(node: Control) -> void:
	if is_instance_valid(node):
		node.queue_free()


func has_overlay() -> bool:
	return _overlay_host.get_child_count() > 0


# --------------------------------------------------------------------------- #
# Avisos
# --------------------------------------------------------------------------- #

func _on_notice(text: String, color: Color) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast.position.y = 175
	_toast_tween = create_tween()
	_toast_tween.set_parallel()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_property(_toast, "position:y", 150.0, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain()
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


## EL CARTEL DE LOS EVENTOS: baja desde arriba con rebote, se queda un rato y
## vuelve a subir. Con gold = true toda la pantalla destella en dorado: es lo
## que marca un momento x2 (VIP, hora feliz, frenesi, sobre dorado).
func banner(title: String, subtitle: String = "", gold: bool = true) -> void:
	if gold:
		var flash := ColorRect.new()
		flash.color = Color(Palette.GOLD_HI, 0.0)
		flash.size = Vector2(1920, 1080)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_host.add_child(flash)
		var ft := flash.create_tween()
		ft.tween_property(flash, "color:a", 0.38, 0.08)
		ft.tween_property(flash, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD)
		ft.tween_callback(flash.queue_free)

	var plate := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.NIGHT_DD, 0.94)
	box.border_color = Palette.GOLD_XL
	box.set_border_width_all(5)
	box.set_corner_radius_all(6)
	box.shadow_color = Color(Palette.GOLD, 0.45)
	box.shadow_size = 18
	plate.add_theme_stylebox_override("panel", box)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size = Vector2(1100, 120 if subtitle != "" else 90)
	var rest_y := 24.0
	plate.position = Vector2((1920 - plate.size.x) * 0.5, -plate.size.y - 30)
	plate.pivot_offset = plate.size * 0.5
	_toast_host.add_child(plate)
	var t := UIKit.label_at(title, Vector2(plate.size.x * 0.5, 44), Vector2(plate.size.x - 40, 60),
			UIKit.fit_size(title, plate.size.x - 40, 42), Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0)
	t.pivot_offset = t.size * 0.5
	plate.add_child(t)
	if subtitle != "":
		plate.add_child(UIKit.label_at(subtitle, Vector2(plate.size.x * 0.5, 92),
				Vector2(plate.size.x - 40, 36), UIKit.fit_size(subtitle, plate.size.x - 40, 21),
				Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0))

	var tw := plate.create_tween()
	tw.tween_property(plate, "position:y", rest_y, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Un latido del titulo al llegar, para que el ojo vaya ahi.
	tw.tween_property(t, "scale", Vector2(1.08, 1.08), 0.12)
	tw.tween_property(t, "scale", Vector2.ONE, 0.18)
	tw.tween_interval(2.0)
	tw.tween_property(plate, "position:y", -plate.size.y - 30, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(plate.queue_free)


## EL CONFETI DE UNA MEJORA: una lluvia desde arriba a lo ancho de la pantalla, dos
## chorros desde los lados y una luz de colores que pasa por toda la pantalla.
## Cantidad normalita a proposito (unos cien papelitos en total): es un premio de
## un segundo, no una fiesta que tape la partida.
const CONFETTI_COLORS: Array = [Color8(248, 192, 0), Color8(232, 72, 96),
	Color8(88, 208, 196), Color8(120, 150, 255), Color8(160, 220, 90), Color8(252, 236, 196)]


func confetti() -> void:
	_confetti_burst(Vector2(960, -20), Vector2(960, 8), Vector2(0, 1), 30.0, 60,
			Vector2(150, 380))
	_confetti_burst(Vector2(-10, 640), Vector2(4, 120), Vector2(1, -1.2), 22.0, 22,
			Vector2(600, 900))
	_confetti_burst(Vector2(1930, 640), Vector2(4, 120), Vector2(-1, -1.2), 22.0, 22,
			Vector2(600, 900))
	# La luz: un velo que pasa por tres colores y se apaga, muy suave.
	var light := ColorRect.new()
	light.size = Vector2(1920, 1080)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.color = Color(CONFETTI_COLORS[0], 0.0)
	_toast_host.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "color", Color(CONFETTI_COLORS[0], 0.22), 0.08)
	tw.tween_property(light, "color", Color(CONFETTI_COLORS[1], 0.16), 0.2)
	tw.tween_property(light, "color", Color(CONFETTI_COLORS[2], 0.12), 0.2)
	tw.tween_property(light, "color", Color(CONFETTI_COLORS[3], 0.0), 0.45)
	tw.tween_callback(light.queue_free)


func _confetti_burst(at: Vector2, extents: Vector2, dir: Vector2, spread: float,
		amount: int, speed: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = _confetti_tex()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = amount
	p.lifetime = 2.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector2(0, 520)
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 4.5
	# Cada papelito sale de un color de la lista (rampa en escalones, no mezcla).
	var colores := Gradient.new()
	colores.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in CONFETTI_COLORS.size():
		offs.append(float(i) / float(CONFETTI_COLORS.size()))
		cols.append(CONFETTI_COLORS[i])
	colores.offsets = offs
	colores.colors = cols
	p.color_initial_ramp = colores
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	_toast_host.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Un papelito: un rectangulo blanco de 4x2 (el color lo pone la rampa).
static var _paper: Texture2D = null
static func _confetti_tex() -> Texture2D:
	if _paper == null:
		var img := Image.create(4, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_paper = ImageTexture.create_from_image(img)
	return _paper
