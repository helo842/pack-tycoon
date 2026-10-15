# WorldLabel - un rotulo en el mundo, con la fuente del juego.
#
# Es el hermano 3D de las etiquetas de UIKit, y existe por el mismo motivo que
# Sprite3DKit: el mundo ya no es una pantalla, pero el texto del juego no tiene
# por que cambiar. Misma fuente (font_pack), mismo ajuste al multiplo de
# FONT_STEP y el mismo tamano en "pixeles logicos" (PIXEL = 0.01), asi que un
# rotulo de 34 px mide lo mismo que mediria en la interfaz de antes: 0.34
# unidades.
#
# El texto del mundo NO lleva contorno. La fuente del juego ya trae su borde
# oscuro pintado (ver ui_kit.gd), y el contorno de Label3D por encima lo unico
# que hace es engordar las letras: en la mesa se probo y se quito.
class_name WorldLabel
extends Label3D

## El mismo pixel logico que el resto del mundo 3D. Ver Sprite3DKit.PIXEL.
const PIXEL := 0.01


## Un rotulo suelto. `billboard` lo deja siempre mirando a la camara, que es lo
## que quieren los carteles que aparecen al mirar una cosa (si no, un cartel
## pegado a un cacharro se ve de canto en cuanto se mira desde el lado).
static func make(text: String, size: int = 34, color: Color = Palette.CREAM,
		billboard: bool = false) -> WorldLabel:
	var l := WorldLabel.new()
	l.text = text
	l.font = UIKit.font()
	l.font_size = UIKit.font_step(size)
	l.pixel_size = PIXEL
	l.modulate = color
	l.outline_size = 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.texture_filter = Sprite3DKit.FILTER
	l.no_depth_test = true
	l.double_sided = true
	l.render_priority = 8
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l


## El ancho que ocupa el texto, en unidades del mundo. Es lo que necesitan los
## carteles para saber que tamano tiene que tener la chapa que va debajo.
func width_units() -> float:
	var longest := 0.0
	for line in text.split("\n"):
		longest = maxf(longest, UIKit.text_width(line, font_size))
	return longest * PIXEL


## El alto de la caja de texto, en unidades. Cuenta las lineas de verdad: un
## rotulo de dos lineas ocupa el doble y la chapa de debajo tiene que crecer.
func height_units() -> float:
	return float(font_size) * PIXEL * float(maxi(1, text.split("\n").size()))
