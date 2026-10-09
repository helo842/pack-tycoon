# DamagePopup - el numero de dano que sale al terminar la redonda de un golpe.
#
# Un ciclo de la carga del boton es un golpe: cuando el aro se cierra del todo,
# el paquete pierde resistencia y aqui sale cuanto le ha quitado. El COLOR dice
# si el golpe ha sido normal (naranja) o critico (amarillo), que es la unica
# forma de enterarse de que el Ojo verde y el Laser estan haciendo algo: el
# destello del paquete dura dos frames y no se llega a leer.
#
# Es la misma pieza que los avisos de venta (ver game.gd, _float_text): sube y se
# desvanece sola. Se hace con PixelNumber y no con una etiqueta porque un numero
# de dano es un numero, y en este juego los numeros se dibujan con los glifos del
# kit (los mismos de los precios y del dinero).
class_name DamagePopup
extends RefCounted

## El golpe normal, en naranja, y el critico, en amarillo. Y no son un color de la
## paleta tal cual, aunque lo parezcan: los sprites de los digitos (num_*.png) YA
## vienen pintados de oro (amarillo arriba, naranja en el cuerpo y marron abajo) y
## PixelNumber.color los MULTIPLICA, asi que un tinte plano solo los apaga: con
## Palette.GOLD el numero sale marron oscuro y con GOLD_HI sale casi igual que
## cualquier otro numero del juego.
##
## Lo que de verdad mueve el color es el VERDE del tinte: bajarlo apaga el dorado
## a naranja puro y subirlo por encima de 1 lo enciende a amarillo. Los dos estan
## medidos sobre el pixel que sale en pantalla (ver dev/probe_pop.gd): el cuerpo
## del digito sale naranja (232, 96, 0) en un golpe normal y amarillo (232, 218, 0)
## en un critico.
const NORMAL := Color(1.0, 0.75, 0.0)
const CRIT := Color(1.0, 1.7, 0.5)

## Cuanto sube el numero antes de desaparecer, y lo que tarda en hacerlo.
const RISE := 88.0
const LIFE := 0.85
## Tamano del numero del golpe normal y del critico.
const SIZE := 0.34
const CRIT_SIZE := 0.46

## Desplazamiento al azar del numero alrededor del punto donde sale, para que dos
## golpes seguidos no se apilen exactamente uno encima del otro. No es un adorno:
## con los items al tope un ciclo de carga dura 0,16 s, y en ese rato el numero
## sube 16 px cuando el digito mide 33 de alto, asi que sin separarlos dos golpes
## seguidos se tapan y no se lee ninguno. Es un poco a los lados y un poco hacia
## abajo; la subida los vuelve a juntar mas arriba, que es donde ya no importa.
const JITTER_X := 56.0
const JITTER_Y := 22.0

## Marca del nodo, para poder reconocerlo desde fuera.
##
## NO se busca por el nombre aunque el nombre este puesto: Godot RENOMBRA a los
## hermanos que se llaman igual (DamagePop, DamagePop2, DamagePop3...) porque dos
## hijos de un mismo padre no pueden compartir nombre, asi que buscar el nombre
## exacto encuentra solo el primero de la tanda. Con la marca no hay duda, y una
## marca no se la lleva por delante el motor.
const MARK := "damage_popup"

static var _rng := RandomNumberGenerator.new()
static var _seeded := false


## Saca el numero en `parent`, en el punto `at` (en coordenadas de `parent`).
##
## Devuelve el nodo, que es lo que necesitan las pruebas para leerle el color y
## el texto sin ir a buscarlo por el arbol.
##
## El color se pone ANTES del texto y no despues: PixelNumber solo lo aplica al
## construir los glifos (ver pixel_number.gd, _rebuild), asi que al reves el
## numero saldria blanco.
static func pop(parent: CanvasItem, at: Vector2, amount: float, crit: bool) -> PixelNumber:
	var num := PixelNumber.new()
	num.name = "DamagePop"
	num.set_meta(MARK, true)
	num.color = CRIT if crit else NORMAL
	num.scale_factor = CRIT_SIZE if crit else SIZE
	num.set_number(roundi(amount))
	parent.add_child(num)
	if not _seeded:
		_rng.randomize()
		_seeded = true
	var donde := at + Vector2(_rng.randf_range(-JITTER_X, JITTER_X),
			_rng.randf_range(0.0, JITTER_Y))
	num.position = donde - num.size * 0.5
	num.pivot_offset = num.size * 0.5
	# Entra pequeño y crece de golpe: el golpe se tiene que notar en el numero,
	# no solo en el paquete.
	num.scale = Vector2(0.7, 0.7)
	var rise := num.position.y - RISE
	var tw := num.create_tween()
	tw.set_parallel(true)
	tw.tween_property(num, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(num, "position:y", rise, LIFE) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(num, "modulate:a", 0.0, LIFE * 0.45).set_delay(LIFE * 0.55)
	tw.chain().tween_callback(num.queue_free)
	return num
