# Station - un cacharro de la trastienda con pantalla.
#
# Es la pieza que convierte un panel de los de siempre en un objeto del mundo:
# la estacion trae su cristal (WorldScreen) y lo unico que sabe hacer es enseñar
# dentro el panel que le den y volver a apagarlo.
#
# EL CABLEADO LO PONE game.gd, no la estacion. Aqui no hay ni una linea del
# juego -ni tienda, ni armario, ni hucha-: eso vive en game.gd, que es quien
# tiene el estado. La estacion solo lleva tres cosas: donde esta, que se ve
# cuando la miras (el cartel de Interactable) y que pasa cuando le das a la
# tecla (`on_use`). Asi la misma clase sirve para el monitor de la tienda, la
# vitrina y el altar de la hucha, y añadir un cacharro nuevo es montar su
# geometria y darle un Callable.
class_name Station
extends Interactable

## El cristal. Lo monta quien construye la estacion (room.gd) y lo pasa aqui.
var screen: WorldScreen = null
## Que se hace al pulsar la tecla. Lo pone game.gd.
var on_use: Callable = Callable()
## ¿Se puede usar? Sirve para los cacharros que todavia no tienen corriente
## (una pieza sin comprar): con esto en false el cartel lo dice en vez de
## prometer algo que no pasa.
var on_can_use: Callable = Callable()
## El texto del cartel cuando NO se puede usar. Sin esto, un cacharro apagado no
## dice por que lo esta.
var locked_hint := ""

## Lo que dice el cartel cuando SI se puede usar, para los cacharros que dicen
## una cosa distinta cada vez que se miran: el interruptor de la apertura dice
## si esta encendida o apagada, y eso se mira justo para eso. Si no hay nada
## puesto vale `sign_hint`, que es el texto fijo de siempre.
var on_hint: Callable = Callable()

## El panel que se esta viendo ahora mismo, o null.
var _panel: Control = null


func can_use() -> bool:
	if on_can_use.is_valid():
		return bool(on_can_use.call())
	return true


## El texto del cartel de esta estacion. Se rehace cada vez que la mira se posa
## encima, y esa es la gracia: el de la hucha dice lo que falta y el de la
## maquina si te llega el dinero, sin que nadie abra nada.
func hint_line() -> String:
	if not can_use():
		return locked_hint
	if on_hint.is_valid():
		return "E  " + str(on_hint.call())
	return "E  " + sign_hint


## La estacion no le pasa nada a la accion: quien la ha puesto ahi (game.gd) ya
## sabe quien es su jugador, y colarle un argumento es pedirle a su funcion que
## acepte algo que no necesita (y un "Expected 0 argument(s)" cuando no lo hace).
func use(_player: Player) -> void:
	if on_use.is_valid():
		on_use.call()


## Cuelga un panel en el cristal y lo enciende.
func open_panel(panel: Control) -> void:
	_panel = panel
	screen.show_panel(panel)


## Quita el panel. El cristal se apaga solo si ademas nadie esta mirando: un
## monitor no se apaga porque cierres su panel mientras lo tienes delante.
func close_panel() -> void:
	if _panel == null:
		return
	_panel = null
	screen.clear_panel()
	if not is_focused():
		screen.set_lit(false)


func has_panel() -> bool:
	return _panel != null


func focus_enter() -> void:
	super()
	# Mirar un cacharro lo despierta: esto es lo que hace que las cosas
	# aparezcan al girar la cabeza.
	if screen != null and not screen.is_lit():
		screen.set_lit(true)


func focus_exit() -> void:
	super()
	if screen != null and _panel == null:
		screen.set_lit(false)
