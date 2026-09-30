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
	_overlay_host = _host("Overlay")
	_toast_host = _host("Toast")

	_toast = UIKit.label("", 44, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0)
	_toast.size = Vector2(1920, 70)
	_toast.position = Vector2(0, 150)
	_toast.modulate.a = 0.0
	_toast_host.add_child(_toast)

	Game.notice.connect(_on_notice)
	# La musica es la misma en el menu y en la partida: es el fondo de la
	# tienda, no de una pantalla concreta. Por eso arranca aqui, en la raiz, y
	# no la para nadie al cambiar de pantalla.
	Sound.play_music("music_backroom")
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


# --------------------------------------------------------------------------- #
# Capas
# --------------------------------------------------------------------------- #

## Un panel que tapa la pantalla y se cierra con ESC.
func push_veil(panel: Control) -> void:
	_veil_host.add_child(panel)


func pop_veil(panel: Control) -> void:
	if is_instance_valid(panel):
		panel.queue_free()


func has_veil() -> bool:
	return _veil_host.get_child_count() > 0


func push_overlay(node: Control) -> void:
	_overlay_host.add_child(node)


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
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
