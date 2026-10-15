# Interactable - algo del mundo a lo que se le puede mirar y darle a la tecla.
#
# LO QUE HACE QUE ESTO NO SEA UN MENU: cuando la mira se posa encima, el cartel
# aparece. No se abre nada, no se pausa nada y no se tapa la pantalla: el nombre
# y la tecla se dibujan EN EL AIRE, encima de la cosa que estas mirando, y se
# van solos cuando apartas la vista. Es la diferencia entre "pulsa TAB para
# abrir el inventario" y "mira la vitrina y te dice lo que hay dentro".
#
# El cartel va en BILLBOARD: mira siempre a la camara. Un cartel pegado a un
# cacharro se ve de canto en cuanto lo miras desde un lado, y estas cosas se
# miran desde donde se puede, no desde enfrente.
#
# Quien decide QUE se puede usar y con que tecla es de quien sea la accion: la
# estacion no sabe nada del juego, le dan un Callable (ver station.gd).
class_name Interactable
extends Node3D

## El nombre del cacharro: "MAQUINA DE SOBRES", "HUCHA".
var sign_name := ""
## Lo que se puede hacer, corto: "COMPRAR SOBRES".
var sign_hint := ""
## Desde donde se mira al usarlo y a donde mira la camara, en coordenadas
## LOCALES. Van en local a proposito: asi una estacion girada para pegarse a una
## pared (el terminal de la tienda) no necesita ninguna cuenta distinta.
var view_from := Vector3(0.0, 1.6, 1.9)
var view_at := Vector3(0.0, 1.6, 0.0)
## Donde flota su cartel, en local.
var card_at := Vector3(0.0, 2.7, 0.3)
## El cajon por el que le tiene que dar el rayo de la mira, en local y desde el
## origen del nodo. Ancho a proposito: apuntar a un cacharro grande con un rayo
## fino es una punteria que no aporta nada.
var pick_half := Vector3(1.2, 1.4, 0.9)

var _card: Node3D = null
var _card_shown := false
var _tween: Tween = null
## El texto con el que se construyo el cartel. El cartel lleva su tamano escrito
## (la chapa de debajo se ajusta al texto), asi que si el texto cambia hay que
## rehacerlo: es lo que pasa con la hucha, que dice cuanto falta y cambia cada
## vez que entra dinero.
var _built := ""


## La linea de la tecla que sale debajo del nombre. Es un metodo y no una
## variable porque hay cacharros que la cambian solos (ver station.gd).
func hint_line() -> String:
	return sign_hint


## El cartel se crea cuando hace falta, no en _ready: casi todas las estaciones
## se miran alguna vez, pero solo se construye una vez y con el texto ya puesto.
func _build_card() -> void:
	if _card != null:
		return
	_card = Node3D.new()
	_built = sign_name + "\n" + hint_line()
	_card.name = "Sign"
	_card.position = card_at
	_card.visible = false

	var name_size := 30
	var hint_size := 21
	var w := maxf(UIKit.text_width(sign_name, name_size),
			UIKit.text_width(hint_line(), hint_size)) + 56.0
	var h := float(name_size + hint_size) + 34.0
	# El fondo es el mismo marco de ranura que usan la columna de sobres y el
	# armario: un cuadrado oscuro redondeado. El texto del juego es crema y sobre
	# la chapa clara de los precios no se leeria.
	var back := Sprite3DKit.sprite("ui_slot", Vector2(w, h))
	back.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	Sprite3DKit.priority_of(back, 7)
	_card.add_child(back)

	var dy := float(hint_size) * Sprite3DKit.PIXEL * 0.5 + 4.0 * Sprite3DKit.PIXEL
	var name_label := WorldLabel.make(sign_name, name_size, Palette.CREAM, true)
	name_label.position = Vector3(0.0, dy, 0.05)
	_card.add_child(name_label)
	var hint_label := WorldLabel.make(hint_line(), hint_size, Palette.GOLD_XL, true)
	hint_label.position = Vector3(0.0, -dy, 0.05)
	_card.add_child(hint_label)

	add_child(_card)


## El cacharro ha entrado en la mira.
func focus_enter() -> void:
	if _card_shown:
		return
	_card_shown = true
	# El cartel viejo se tira si su texto ya no vale: la chapa de debajo tiene el
	# ancho del texto con el que se hizo.
	if _card != null and _built != sign_name + "\n" + hint_line():
		_card.queue_free()
		_card = null
	_build_card()
	_card.visible = true
	_show_card(true)


## La mira ha salido.
func focus_exit() -> void:
	if not _card_shown:
		return
	_card_shown = false
	_show_card(false)


func is_focused() -> bool:
	return _card_shown


func _show_card(on: bool) -> void:
	if _card == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_card.scale = Vector3.ONE * 0.85 if on else Vector3.ONE
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_card, "scale", Vector3.ONE if on else Vector3.ONE * 0.9, 0.12)
	for c in _card.get_children():
		if c is WorldLabel or c is Sprite3D:
			var shown := (c as Node3D)
			shown.modulate.a = 1.0 if on else 0.0
	if not on:
		_tween.chain().tween_callback(_hide_card)


func _hide_card() -> void:
	if _card != null and not _card_shown:
		_card.visible = false


# --------------------------------------------------------------------------- #
# Uso
# --------------------------------------------------------------------------- #

## ¿Se puede usar ahora mismo? La estacion contesta lo que le hayan puesto (ver
## station.gd): una maquina puede estar sin corriente, o la mesa llena.
func can_use() -> bool:
	return true


## El jugador ha pulsado la tecla con esto en la mira.
func use(_player: Player) -> void:
	pass


## Un punto y una direccion del mundo a los que apunta la camara al usarlo.
func view_from_point() -> Vector3:
	return global_transform * view_from


func view_at_point() -> Vector3:
	return global_transform * view_at


## El cajon del rayo de la mira, en el mundo.
func pick_box() -> AABB:
	var c := global_transform * Vector3.ZERO
	var half := Vector3(pick_half.x, pick_half.y, pick_half.z)
	return AABB(c - half, half * 2.0)
