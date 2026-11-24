# UIKit - piezas de interfaz montadas a mano con los sprites del kit.
#
# Todo se construye en codigo en vez de en el editor porque la mayoria de las
# piezas se repiten con parametros (una ranura por paquete, una estrella por
# punto de la nota PSA) y asi se generan con un bucle. Las escenas .tscn se
# quedan con un unico nodo raiz, para que la estructura se vea en el editor.
#
# LAS LETRAS (tres, ni una mas: elegidas el 2026-11-17)
# ------------------------------------------------------
#   TEXTO    font_texto.fnt: mayusculas y minusculas, cada letra con su ancho,
#            sin contorno. Botones, fichas, avisos, la ayuda.
#   TITULO   font_titulo.fnt: mayusculas de trazo doble con contorno y sombra.
#            Las cabeceras y todo texto GRANDE (TITLE_MIN o mas), y los carteles
#            que van encima de la mesa o de un brillo (los que piden `outline`).
#   NUMEROS  PixelNumber: los digitos dorados del dinero, precios y saldos.
# label() elige entre las dos primeras por esa regla, asi que nadie tiene que
# acordarse: un texto grande es un titulo y uno normal es texto.
#
# Las dos salen de tools/make_font.py y son pixel art: la mayuscula mide 7 px de
# arte, asi que el tamano 7 es su "1". FONT_STEP = 7 hace que cualquier tamano
# salga entero: todo font_size se ajusta al multiplo de 7 mas cercano ANTES de
# llegar a Godot (40 -> 42). Si se pidiera 40 tal cual, Godot estiraria por 5.7
# y cada pixel saldria de un tamano distinto. tools/check_font_size.py avisa si
# esto se rompe. Y ningun texto baja de MIN_SIZE: por debajo no se lee.
class_name UIKit
extends RefCounted

## Multiplo de 16 px: el arte esta escalado x16, asi que cualquiertamano que no
## sea multiplo de eso descuadra los pixeles de arte al estirar.
const GRID := 16.0

## Multiplo obligatorio de los tamanos de fuente. 7 px es la altura de un glifo
## de arte, asi que 7, 14, 21, 28... son las unicas escalas enteras que existen.
const FONT_STEP := 7

## El tamano mas pequeno de cualquier texto (x2). A 7 (x1) no se leia nada.
const MIN_SIZE := 14

## Desde este tamano (x6) un texto es un TITULO y va con font_titulo.
const TITLE_MIN := 42

## `outline` de label() que obliga a la letra de TEXTO: los botones van siempre
## con ella, sea cual sea su tamano (en la hoja elegida, los botones son TEXTO).
const TEXT_ONLY := -1

## La letra de TEXTO y la de TITULOS (ver arriba). Se cargan por ruta: el .fnt no
## es un sprite y no va en Sprites/index.tsv.
const FONT_PATH := "res://Sprites/font/font_texto.fnt"
const TITLE_FONT_PATH := "res://Sprites/font/font_titulo.fnt"

## Margen del CUERPO OSCURO de las chapas de boton, en fraccion del sprite.
## El cuerpo no ocupa el sprite entero (alrededor hay un marco dorado y un
## margen transparente), asi que un texto que cabe "en el boton" se sale de la
## chapa. Medido sobre ui_button_plate.png y ui_button_small.png.
const PLATE_BODY := Vector2(0.094, 0.1875)
const SMALL_BODY := Vector2(0.15, 0.33)

static var _font: Font = null
static var _title_font: Font = null


## La letra de TEXTO.
static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
	return _font


## La letra de TITULOS.
static func title_font() -> Font:
	if _title_font == null:
		_title_font = load(TITLE_FONT_PATH) as Font
	return _title_font


## Ajusta un tamano pedido al multiplo de FONT_STEP mas cercano. Nunca baja de
## MIN_SIZE, para que ningun texto se quede tan pequeno que no se lea.
static func font_step(size: int) -> int:
	return maxi(MIN_SIZE, int(round(float(size) / float(FONT_STEP))) * FONT_STEP)


## La letra que lleva un texto: TITULO si es grande o si pide contorno
## (`cartel`), TEXTO si no. Un texto OSCURO nunca es titulo: la de titulos trae
## contorno oscuro y en tinta oscura se empasta ("NORMAL 1/4" sobre el carton
## salia una mancha); oscuro sobre papel o carton es el estilo de TEXTO.
static func font_for(font_size: int, cartel := false, color := Color.WHITE) -> Font:
	if color.get_luminance() < 0.35:
		return font()
	return title_font() if cartel or font_step(font_size) >= TITLE_MIN else font()


## Ancho en pixeles de un texto con la letra que le toca (ver font_for). Cada
## letra tiene su ancho (la I es estrecha), asi que se mide de verdad.
static func text_width(text: String, font_size: int, cartel := false,
		color := Color.WHITE) -> float:
	var f := font_for(font_size, cartel, color)
	if f == null:
		return float(font_step(font_size)) * float(text.length())
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_step(font_size)).x


## El mayor tamano (multiplo de FONT_STEP, sin bajar de MIN_SIZE) con el que
## `text` cabe en `box_width`. Si ni al minimo cabe, el minimo: mejor que se
## salga un poco que no se lea.
static func fit_size(text: String, box_width: float, max_size: int = 96,
		cartel := false, color := Color.WHITE) -> int:
	var s := font_step(max_size)
	while s > MIN_SIZE and text_width(text, s, cartel, color) > box_width:
		s -= FONT_STEP
	return s


## El tamano que hace caber TODA una lista de textos en la misma caja.
##
## Es lo que hay que usar cuando los nombres van en fila o en columna (los sobres
## de la zona de compra, los items de la tienda). Encoger cada uno por su cuenta hace que
## "Sobres" salga a 28 px y "Electrónica" a 14, y una fila con tres tamanos
## distintos se lee como un fallo, no como un diseno.
static func row_size(texts: Array, box_width: float, max_size: int = 96,
		cartel := false) -> int:
	var result := font_step(max_size)
	for t in texts:
		result = mini(result, fit_size(str(t), box_width, max_size, cartel))
	return result


static func snap(v: float) -> float:
	return snappedf(v, GRID)


## Parte un texto en lineas que caben en `box_width`, a un tamano dado: se
## llena cada linea por palabras, midiendo con la letra de verdad. Una palabra
## sola mas larga que la caja se queda entera en su linea, que se lee mejor que
## una palabra cortada por la mitad.
static func wrap(text: String, box_width: float, font_size: int) -> PackedStringArray:
	var lineas := PackedStringArray()
	var actual := ""
	for palabra in text.split(" ", false):
		var p := str(palabra)
		if actual == "":
			actual = p
		elif text_width(actual + " " + p, font_size) <= box_width:
			actual += " " + p
		else:
			lineas.append(actual)
			actual = p
	if actual != "":
		lineas.append(actual)
	return lineas


# --------------------------------------------------------------------------- #
# Etiquetas
# --------------------------------------------------------------------------- #
## Etiqueta con la letra que le toca (font_for: TITULO si es grande o lleva
## `outline`, TEXTO si no). El tamano se ajusta a escala entera solo. `outline`
## ya no pinta un contorno de Godot: 1 o mas pide la letra de titulos (que lo
## trae), y TEXT_ONLY (-1) obliga a la de texto aunque sea grande (botones).
static func label(text: String, font_size: int = 40, color: Color = Palette.CREAM,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	# La fuente es de mapa de bits a 7 px y se escala x3, x8...: sin NEAREST explicito
	# Godot la estira con filtro lineal y la letra sale borrosa (dev/probe_font.gd no
	# lo veia porque el contorno de la fuente vieja lo tapaba).
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var f := font() if outline == TEXT_ONLY else font_for(font_size, outline > 0, color)
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", font_step(font_size))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Coloca la etiqueta y le da un tamano fijo, para poder centrarla con el
## normal sin depender de que Godot mida el texto.
static func place(l: Control, center: Vector2) -> Control:
	l.size = l.get_combined_minimum_size()
	l.position = center - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	return l


## Etiqueta ya colocada: se le pasa el centro y la caja donde vive. Casi todas
## las etiquetas del juego son "un texto en algum sitio fijo", asi que esto
## evita tres lineas por cada una.
##
## La caja se AGRANDA por los dos lados si el texto no cabe, de modo que la
## etiqueta nunca se recorta. No cambia donde se ve el texto (sigue centrado en
## `center`), solo le da sitio. Sin esto, un rotulo un poco mas largo de lo
## previsto se cortaba por los dos lados sin avisar, que es como se notaba
## "PANTALLA C◻MPLETA" y "ESPACIO O CLIC PARA ◻ONTINUAR".
##
## `shrink` encoge la LETRA en vez de agrandar la caja, para cuando el texto
## largo choca con otra cosa de la pantalla. Con shrink la caja no crece, asi
## que si tampoco cabe sale igual: por eso las dos cosas van juntas y no se
## eligieron al azar en cada sitio.
static func label_at(text: String, center: Vector2, box: Vector2,
		font_size: int = 40, color: Color = Palette.CREAM,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER,
		outline: int = 0, shrink: bool = false) -> Label:
	var size := font_size
	if shrink:
		size = fit_size(text, box.x, font_size, outline > 0, color)
	var l := label(text, size, color, align, outline)
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var needed := Vector2(text_width(text, size, outline > 0, color), text_height(size))
	l.size = Vector2(maxf(box.x, needed.x), maxf(box.y, needed.y))
	l.position = center - l.size * 0.5
	return l


## Lo mismo que label_at() sin encoger ni contorno. Se queda por los sitios que
## ya la llaman: la letra la elige label() por el tamano, como en todos.
static func title_label_at(text: String, center: Vector2, box: Vector2,
		font_size: int = 40, color: Color = Palette.CREAM,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return label_at(text, center, box, font_size, color, align)


## Alto en pixeles que ocupa una linea de texto, con la fuente del juego.
##
## Se usa text_height() y no l.get_theme_font("font").get_height() porque en
## una etiqueta que todavia no esta en el arbol, get_theme_font() devuelve la
## fuente del tema y no la override: ahi se perdia la mitad del alto y el texto
## se salia por abajo. Ver dev/probe_font.gd.
static func text_height(font_size: int) -> float:
	if font() == null:
		return float(font_step(font_size))
	return font().get_height(font_step(font_size))


# --------------------------------------------------------------------------- #
# Piezas de fondo
# --------------------------------------------------------------------------- #

## Un sprite colocado por su centro y con el tamano que se le pida. Casi todos
## los sprites del kit son de 512x512, por eso hay tambien square().
static func image(sprite_name: String, center: Vector2, size: Vector2,
		modulate: Color = Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.tex(sprite_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = modulate
	t.size = size
	t.pivot_offset = size * 0.5
	t.position = center - size * 0.5
	return t


## Los sprites del catalogo son 512x512, salvo los numeros (64x96), la fuente
## y los iconos de 256. square() es para los de 512.
## Sprite cuadrado a escala. Ojo al NOMBRE: son dos cosas distintas.
##
## square() multiplica SIEMPRE 512, porque casi todos los sprites del kit son de
## 512x512 (los de 32x32 de arte a escala 16). Los que son de 16x16 de arte
## miden 256: grade_*, condition_*, fx_shine y todos los ui_icon_*. Esos hay que
## ponerlos con art() o con image(), porque square() los estira al doble y de
## paso los deja borrosos.
static func square(sprite_name: String, center: Vector2, scale_factor: float,
		modulate: Color = Color.WHITE) -> TextureRect:
	return image(sprite_name, center, Vector2(512, 512) * scale_factor, modulate)


## Sprite a escala de SU PROPIO tamano, no de 512. Para los de 256 y los de
## cualquier otra medida. Multiplica el factor sobre el tamano real del sprite,
## asi que 0.5 siempre es la mitad, tanto si el sprite es de 256 como de 512.
static func art(sprite_name: String, center: Vector2, scale_factor: float,
		modulate: Color = Color.WHITE) -> TextureRect:
	var tex := Sprites.tex(sprite_name)
	var lado: float = 512.0
	if tex != null:
		lado = float(maxi(tex.get_width(), tex.get_height()))
	return image(sprite_name, center, Vector2(lado, lado) * scale_factor, modulate)


## Sprite escalado por su DIBUJO (ver Sprites.used_rect) hasta que entra entero
## en una caja, y centrado en ella.
##
## square() y art() escalan por el lienzo, que es lo correcto para un objeto
## suelto, pero deja los dibujos que no llenan su lienzo pequenos y de tamanos
## distintos entre si. Aqui manda el dibujo: el de cartas (estrecho y alto) y el
## de zapatillas (ancho y bajo) llenan la caja cada uno por su lado, asi que en
## pantalla se ven del mismo tamano en vez de uno flaco y otro diminuto.
##
## Mantiene la proporcion: nunca deforma. Si el lienzo esta vacio (un sprite que
## no carga) cae en image() con la caja entera, para no reventar.
static func fit_art(sprite_name: String, center: Vector2, box: Vector2,
		modulate: Color = Color.WHITE) -> TextureRect:
	var t := Sprites.tex(sprite_name)
	if t == null:
		return image(sprite_name, center, box, modulate)
	var lienzo := Vector2(t.get_size())
	var usado := Sprites.used_rect(sprite_name)
	if usado.size.x <= 0.0 or usado.size.y <= 0.0:
		usado = Rect2(Vector2.ZERO, lienzo)
	var s := minf(box.x / usado.size.x, box.y / usado.size.y)
	var node := image(sprite_name, Vector2.ZERO, lienzo * s, modulate)
	# image() coloca por el centro del LIENZO; aqui hay que colocar por el centro
	# del dibujo, que esta desplazado dentro del lienzo.
	node.position = center - (usado.position + usado.size * 0.5) * s
	return node


## Panel de 9-slice. Los paneles son 1600x960 y caben enteros en 1920x1080, asi
## que van a escala 1 y no hay que estirarlos.
static func panel(sprite_name: String, center: Vector2 = Vector2(960, 540)) -> TextureRect:
	return image(sprite_name, center, Vector2(1600, 960))


## Velo oscuro detras de un panel, para que la mesa de detras se lea al borde.
static func veil(alpha: float = 0.55) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.02, 0.015, 0.04, alpha)
	c.size = Vector2(1920, 1080)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


# --------------------------------------------------------------------------- #
# Botones
# --------------------------------------------------------------------------- #

## Boton con la chapa de ui_button_plate. Al pulsarse cambia a la variante
## presionada, que es justo para lo que se hizo esa segunda chapa.
##
## El boton es un Button plano (sin estilo propio) con la chapa, el icono y el
## texto como hijos. Al pulsar sale el modulate del Button, no un estilo.
static func plate_button(text: String, icon: String, center: Vector2,
		size: Vector2 = Vector2(384, 192), font_size: int = 48) -> Button:
	var s := Vector2(snap(size.x), snap(size.x * 0.5))
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = s
	b.pivot_offset = s * 0.5
	b.position = center - s * 0.5

	var plate := _fill(b, "ui_button_plate")
	# El cuerpo oscuro de la chapa no es el boton entero: son los margenes de
	# PLATE_BODY. El texto tiene que caber DENTRO del cuerpo, no dentro del
	# boton. Centrado en el boton, "JUGAR" y "AJUSTES" se salian por el borde
	# derecho de la chapa y la ultima letra quedaba cortada.
	var inner_x0 := s.x * PLATE_BODY.x
	var inner_x1 := s.x * (1.0 - PLATE_BODY.x)
	var text_x0 := inner_x0
	if icon != "":
		var ih := s.y * 0.58
		# _icon se coloca con anclas y offsets: poner size despues lo pisaria.
		b.add_child(_icon(icon, Vector2(inner_x0 + ih * 0.5, s.y * 0.5), ih))
		text_x0 = inner_x0 + ih + s.x * 0.03

	if text != "":
		# El hueco real que queda para el texto, y el tamano que cabe ahi. Con la
		# fuente suave anterior el texto se desbordaba en silencio; ahora se
		# mide (ver text_width) y se encoge, que es lo unico que se puede hacer
		# sin rehacer la chapa.
		var ancho_texto := maxf(28.0, inner_x1 - text_x0)
		# Medido con la letra de texto (el color oscuro la elige), que es la que va.
		var l := label(text, fit_size(text, ancho_texto, font_size, false, Palette.OUTLINE),
			Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, TEXT_ONLY)
		l.anchor_left = 0.0
		l.anchor_right = 1.0
		l.anchor_top = 0.0
		l.anchor_bottom = 1.0
		l.offset_left = text_x0
		l.offset_right = inner_x1 - s.x
		b.add_child(l)

	b.button_down.connect(func() -> void: plate.texture = Sprites.tex("ui_button_plate_pressed"))
	b.button_up.connect(func() -> void: plate.texture = Sprites.tex("ui_button_plate"))
	b.focus_entered.connect(func() -> void: plate.modulate = Color(1.1, 1.1, 1.1))
	b.focus_exited.connect(func() -> void: plate.modulate = Color.WHITE)
	juice(b)
	return b


## Version pequena de la chapa (ui_button_small, 320x144 nativo, es decir
## 2.22:1). Acepta otras chapas del kit, por ejemplo ui_button_sell, que es
## justo del mismo tamano pero con el cuerpo oscuro de "esto te quita dinero".
static func small_button(text: String, icon: String, center: Vector2,
		width: float = 320, font_size: int = 30,
		sprite: String = "ui_button_small",
		pressed_sprite: String = "ui_button_small_pressed") -> Button:
	var s := Vector2(snap(width), snap(width * 0.45))
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = s
	b.pivot_offset = s * 0.5
	b.position = center - s * 0.5

	var plate := _fill(b, sprite)
	# Mismo criterio que en plate_button, con el margen del cuerpo de la chapa
	# pequeña (SMALL_BODY). "VENDER TODO" se salia de la barra por los dos lados.
	var inner_x0 := s.x * SMALL_BODY.x
	var inner_x1 := s.x * (1.0 - SMALL_BODY.x)
	# El icono se comia el 30 % del ancho de la chapa, y en un boton con icono
	# eso es justo lo que separa "letra grande" de "letra de periodico": TIENDA
	# salia a 14 px mientras VENDER, sin icono, salia a 28, y las dos chapas
	# parecian de dos juegos distintos. Ahora el texto empieza donde acaba el
	# icono y el hueco se reparte con la medida de verdad.
	#
	# Y AUN ASI SALIAN A 14: con el icono entero dentro del cuerpo, a TIENDA le
	# quedaban 120 px y a REBIRTH lo mismo, y a 21 piden 126 y 147. El icono va
	# ahora MONTADO SOBRE EL MARCO de la izquierda (su centro casi en el borde del
	# cuerpo, como una insignia) y un punto mas pequeno, y el texto empieza justo
	# donde acaba. Asi los dos caben a 21, el mismo tamano que VENDER al lado.
	var text_x0 := inner_x0
	if icon != "":
		var ih := s.y * 0.42
		b.add_child(_icon(icon, Vector2(inner_x0 + ih * 0.1, s.y * 0.5), ih))
		text_x0 = inner_x0 + ih * 0.6 + 2.0
	if text != "":
		var l := label(text, fit_size(text, inner_x1 - text_x0, font_size, false,
			Palette.OUTLINE), Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, TEXT_ONLY)
		l.anchor_left = 0.0
		l.anchor_right = 1.0
		l.anchor_top = 0.0
		l.anchor_bottom = 1.0
		l.offset_left = text_x0
		l.offset_right = inner_x1 - s.x
		b.add_child(l)

	b.button_down.connect(func() -> void: plate.texture = Sprites.tex(pressed_sprite))
	b.button_up.connect(func() -> void: plate.texture = Sprites.tex(sprite))
	juice(b)
	return b


## Boton de icono cuadrado: el propio sprite hace de fondo y no hay chapa.
## Queda en dos capas (el icono apagado y el encendido) porque estos iconos son
## interruptores: auto-apertura y auto-compra.
static func icon_button(icon: String, center: Vector2, side: float = 96.0,
		tooltip: String = "") -> Button:
	var s := snap(side)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tooltip
	b.size = Vector2(s, s)
	b.pivot_offset = Vector2(s, s) * 0.5
	b.position = center - Vector2(s, s) * 0.5
	# Una ranura detras: sin fondo, el icono apagado no se distingue de un
	# sprite que se ha olvidado cargar.
	var back := _fill(b, "ui_slot")
	back.name = "Back"
	back.modulate = Color(0.8, 0.8, 0.8)
	var off := _fill(b, icon)
	off.name = "Off"
	var lit := _fill(b, icon)
	lit.name = "Lit"
	lit.visible = false
	b.set_meta("lit", false)
	_paint_icon_button(b, false)
	b.button_down.connect(func() -> void: b.modulate = Color(0.8, 0.8, 0.85))
	b.button_up.connect(func() -> void: b.modulate = Color.WHITE)
	b.focus_entered.connect(func() -> void: b.modulate = Color(1.2, 1.2, 1.2))
	b.focus_exited.connect(func() -> void: b.modulate = Color.WHITE)
	juice(b, [], 1.1)
	return b


## Enciende o apaga el icono de un icon_button().
static func set_icon_button_lit(button: Button, lit: bool) -> void:
	button.set_meta("lit", lit)
	var glow := button.get_node_or_null("Lit")
	if glow != null:
		glow.visible = lit
	_paint_icon_button(button, lit)


## Marca un icon_button() como BLOQUEADO: se sigue viendo y se sigue pulsando,
## pero apagado, para que se lea "esto todavia no se puede usar".
##
## No se deshabilita a proposito. Un boton deshabilitado no recibe el clic, y el
## clic es justo lo que hace falta para poder decir QUE falta comprar (ver
## game.gd, _locked_notice()): un boton muerto y callado no explica nada.
static func dim_icon_button(button: Button, dim: bool) -> void:
	button.set_meta("dim", dim)
	_paint_icon_button(button, bool(button.get_meta("lit", false)))


static func _paint_icon_button(b: Button, lit: bool) -> void:
	# El bloqueado se pinta a la mitad. El factor se aplica a los colores y NO al
	# alfa: Color * numero multiplica tambien el alfa, y el fondo de la ranura se
	# volveria translucido en vez de oscuro.
	var k := 0.5 if bool(b.get_meta("dim", false)) else 1.0
	var off := b.get_node_or_null("Off")
	if off != null:
		off.modulate = _scaled(Color.WHITE if lit else Color(0.72, 0.72, 0.8, 1.0), k)
	var back := b.get_node_or_null("Back")
	if back != null:
		back.modulate = _scaled(Color(0.8, 0.8, 0.8), k)


static func _scaled(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


## Donde va el cerrar de los paneles: la esquina de arriba a la derecha que
## ui_panel_shop y ui_panel_settings traen recortada (PANEL_FLAP en
## make_sprites.py: 8 px de arte = 128 px). La solapa la tapa justo.
const PANEL_CLOSE := Vector2(1680, 140)
const PANEL_CLOSE_SIDE := 128.0


## El boton de cerrar: la solapa doblada de la esquina del panel (ui_button_close).
## Se coloca en PANEL_CLOSE con su lado, PANEL_CLOSE_SIDE.
static func close_button(center: Vector2, side: float = PANEL_CLOSE_SIDE) -> Button:
	var s := snap(side)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Cerrar"
	b.size = Vector2(s, s)
	b.pivot_offset = Vector2(s, s) * 0.5
	b.position = center - Vector2(s, s) * 0.5
	var tr := _fill(b, "ui_button_close")
	b.button_down.connect(func() -> void: tr.modulate = Color(0.7, 0.7, 0.7))
	b.button_up.connect(func() -> void: tr.modulate = Color.WHITE)
	juice(b, [], 1.1)
	return b


# --------------------------------------------------------------------------- #
# Internos
# --------------------------------------------------------------------------- #

static func _fill(parent: Control, sprite_name: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.tex(sprite_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(t)
	return t


## Un icono dentro de un boton, centrado donde se le diga.
##
## Las cuatro anclas van a 0 a proposito: asi los offsets son medidas desde la
## esquina del padre. Con las anclas a 1 los offsets se suman al tamano del
## padre y el icono sale estirado el doble de grande y descuadrado.
static func _icon(sprite_name: String, anchor_center: Vector2, side: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.tex(sprite_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.offset_left = anchor_center.x - side * 0.5
	t.offset_right = anchor_center.x + side * 0.5
	t.offset_top = anchor_center.y - side * 0.5
	t.offset_bottom = anchor_center.y + side * 0.5
	return t


# --------------------------------------------------------------------------- #
# Ranuras
# --------------------------------------------------------------------------- #

## Una ranura de ui_slot con su contenido. El fondo se llama "Back", para que
## quien la rellene pueda vaciarla sin cargarse el fondo:
##     for c in holder.get_children():
##         if c.name != "Back": c.queue_free()
static func slot(center: Vector2, side: float = 256.0) -> Control:
	var holder := Control.new()
	holder.size = Vector2(side, side)
	holder.pivot_offset = holder.size * 0.5
	holder.position = center - holder.size * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := TextureRect.new()
	back.name = "Back"
	back.texture = Sprites.tex("ui_slot")
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.size = holder.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)
	return holder


## Boton invisible que hace de zona de clic de un objeto de la mesa.
static func hit_area(parent: Control, rect: Rect2, tooltip: String = "") -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tooltip
	b.size = rect.size
	b.position = rect.position
	# La mano al pasar por encima: sin dibujo propio, es lo que dice "esto se
	# pulsa". El crecer lo pone quien la crea, pasando SU dibujo a juice().
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(b)
	return b


# --------------------------------------------------------------------------- #
# Animaciones de los botones
# --------------------------------------------------------------------------- #

## LO QUE HACE TODO LO QUE SE PULSA: al pasar el raton crece un poco (`grow`), al
## pulsar se hunde y al soltar vuelve, con la mano de cursor. `targets` son los
## dibujos que se mueven; vacio, el propio boton. Las zonas de clic invisibles
## (hit_area) pasan su dibujo, porque escalar una zona invisible no se ve.
##
## Solo toca la ESCALA, nunca el modulate: el modulate ya lo usan los botones
## para decir otras cosas (apagado, bloqueado, encendido) y se pisarian.
static func juice(b: BaseButton, targets: Array = [], grow: float = 1.06) -> void:
	if targets.is_empty():
		targets = [b]
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for t in targets:
		if t is Control and t != b:
			(t as Control).pivot_offset = (t as Control).size * 0.5
	b.mouse_entered.connect(_scale_to.bind(targets, grow, 0.14))
	b.mouse_exited.connect(_scale_to.bind(targets, 1.0, 0.14))
	b.button_down.connect(_scale_to.bind(targets, 0.93, 0.06))
	b.button_up.connect(func() -> void:
		_scale_to(targets, grow if b.is_hovered() else 1.0, 0.18))


static func _scale_to(targets: Array, to: float, seconds: float) -> void:
	for t in targets:
		if not is_instance_valid(t) or not (t is CanvasItem) or not t.is_inside_tree():
			continue
		# has_meta antes: get_meta con null de reserva se queja si no existe.
		if t.has_meta("juice_tw"):
			var old = t.get_meta("juice_tw")
			if old is Tween and (old as Tween).is_valid():
				(old as Tween).kill()
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "scale", Vector2.ONE * to, seconds) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.set_meta("juice_tw", tw)


## Un golpe de escala que vuelve solo: para "esto acaba de cambiar" (una compra,
## un nivel, el dinero que sube).
static func punch(node: CanvasItem, amount: float = 1.25) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size * 0.5
	var tw := _restart_tween(node, "punch_tw")
	tw.tween_property(node, "scale", Vector2.ONE * amount, 0.07)
	tw.tween_property(node, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Un "no" con la cabeza: para lo que no se puede hacer (no te llega, mesa llena).
static func shake(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	# La x de reposo se guarda la primera vez: dos "no" seguidos no lo desplazan.
	if not node.has_meta("shake_x0"):
		node.set_meta("shake_x0", node.position.x)
	var x0: float = node.get_meta("shake_x0")
	var tw := _restart_tween(node, "shake_tw")
	for off in [10.0, -8.0, 6.0, -4.0, 0.0]:
		tw.tween_property(node, "position:x", x0 + off, 0.04)


## Un tween nuevo para `node` que mata el anterior de la misma clave. Sin esto,
## dos punch() seguidos (vender rapido) eran dos tweens peleando por la escala.
static func _restart_tween(node: CanvasItem, key: String) -> Tween:
	if node.has_meta(key):
		var old = node.get_meta(key)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := node.create_tween()
	node.set_meta(key, tw)
	return tw


# --------------------------------------------------------------------------- #
# Movimiento de ambiente (2026-11-17: "que se vea fluido y movido")
# --------------------------------------------------------------------------- #

## FLOTAR: el dibujo sube y baja `amp` px con una onda de `period` segundos, sin
## parar. `phase` (en vueltas, 0..1) lo desfasa, para que una fila de dibujos no
## se mueva a la vez como un bloque. En pixeles enteros, para no emborronar el
## pixel art. El tween vive en el nodo: se acaba solo cuando el nodo se va.
static func bob(node: Control, amp: float = 4.0, period: float = 2.6, phase: float = 0.0) -> void:
	if node == null:
		return
	var base := node.position.y
	var tw := node.create_tween().set_loops()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(node):
			node.position.y = roundf(base + sin(t) * amp),
		TAU * phase, TAU * (phase + 1.0), period)


## APARECER: los dibujos de un panel entran uno detras de otro, creciendo con un
## rebote y encendiendose. Solo toca la escala y el self_modulate, asi que no
## pisa el modulate que usa cada panel para decir apagado o bloqueado.
static func pop_in(nodes: Array, step: float = 0.035, from: float = 0.35) -> void:
	for i in nodes.size():
		var n := nodes[i] as Control
		if n == null or not is_instance_valid(n):
			continue
		n.pivot_offset = n.size * 0.5
		n.scale = Vector2.ONE * from
		n.self_modulate.a = 0.0
		var tw := n.create_tween().set_parallel()
		tw.tween_property(n, "scale", Vector2.ONE, 0.32).set_delay(step * i) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "self_modulate:a", 1.0, 0.18).set_delay(step * i)


## POLVO EN EL AIRE: motas claras que suben despacio por `area`, como en una
## trastienda con luz. Va detras de lo que se pulsa; no recibe clics.
static func dust(area: Rect2, amount: int = 28) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = area.get_center()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area.size * 0.5
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.direction = Vector2(0.2, -1.0)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.3, Color(1, 1, 1, 1.0))
	fade.add_point(0.7, Color(1, 1, 1, 1.0))
	p.color_ramp = fade
	p.color = Color(Palette.SHINE, 0.22)
	return p


## EL BRILLO HOLO (GOLDEN RAIN): un arcoiris que barre el dibujo en diagonal y un
## destello blanco que pasa por encima, solo donde el sprite tiene tinta. Va como
## material del dibujo, asi que sirve igual en la tarjeta, el inventario, la
## vitrina o un sobre de la mesa. Un solo Shader para todos.
const HOLO_SHADER := """
shader_type canvas_item;
uniform float strength = 0.5;
vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec3 rainbow = hue(fract(UV.x * 1.4 + UV.y - TIME * 0.5));
	float band = pow(0.5 + 0.5 * sin((UV.x + UV.y) * 8.0 - TIME * 3.0), 8.0);
	c.rgb = mix(c.rgb, c.rgb * 0.55 + rainbow * 0.65, strength) + vec3(band * 0.45);
	COLOR = c;
}
"""
static var _holo_shader: Shader = null


static func holo(node: CanvasItem) -> void:
	if node == null:
		return
	if _holo_shader == null:
		_holo_shader = Shader.new()
		_holo_shader.code = HOLO_SHADER
	var m := ShaderMaterial.new()
	m.shader = _holo_shader
	node.material = m
