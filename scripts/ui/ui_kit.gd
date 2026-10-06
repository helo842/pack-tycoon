# UIKit - piezas de interfaz montadas a mano con los sprites del kit.
#
# Todo se construye en codigo en vez de en el editor porque la mayoria de las
# piezas se repiten con parametros (una ranura por paquete, una estrella por
# punto de la nota PSA) y asi se generan con un bucle. Las escenas .tscn se
# quedan con un unico nodo raiz, para que la estructura se vea en el editor.
#
# LA FUENTE
# ----------
# El texto ya no usa la fuente de Godot: usa font_pack.fnt, que sale de
# tools/make_font.py y es pixel art como todo lo demas. El glifo mide 5x7 de
# arte, asi que el tamano 7 es su "1" y cualquiertamano sale entero.
#
# FONT_STEP = 7 es lo que hace que eso sea cierto. Todo lo que se pasa como
# font_size se ajusta al multiplo de 7 mas cercano ANTES de llegar a Godot, y
# por eso el codigo puede pedir 40 y sale 42 sin que nadie se entere. Si se
# pidiera 40 tal cual, Godot lo estiraria por 5.7 y cada pixel de la fuente
# saldria de un tamano distinto. tools/check_font_size.py avisa si esto se
# rompe.
#
# Por el mismo motivo el contorno oscuro se ha quitado: la fuente ya lo trae
# pintado (1 px de #101020, el mismo que usa el resto del juego), y el contorno
# de Godot por encima solo servia para la fuente suave de antes.
class_name UIKit
extends RefCounted

## Multiplo de 16 px: el arte esta escalado x16, asi que cualquiertamano que no
## sea multiplo de eso descuadra los pixeles de arte al estirar.
const GRID := 16.0

## Multiplo obligatorio de los tamanos de fuente. 7 px es la altura de un glifo
## de arte, asi que 7, 14, 21, 28... son las unicas escalas enteras que existen.
const FONT_STEP := 7

## La fuente del juego, cargada de Sprites/font/font_pack.fnt.
##
## Se carga por ruta y no por nombre corto a proposito: el .fnt no es un sprite,
## es una fuente, asi que no va en el indice de Sprites/index.tsv. El resto de la
## interfaz si se pide por nombre corto (ver Sprites.tex).
const FONT_PATH := "res://Sprites/font/font_pack.fnt"

## La fuente del TITULO de la pantalla de inicio: la misma, pero sin el contorno
## oscuro que trae pintado font_pack. El borde negro se veia como una sombra
## gorda sobre el fondo de la trastienda, y el titulo se lee mejor en plano.
## La genera tools/make_font.py --name font_title --outline "#10102000".
const TITLE_FONT_PATH := "res://Sprites/font/font_title.fnt"

## Margen del CUERPO OSCURO de las chapas de boton, en fraccion del sprite.
## El cuerpo no ocupa el sprite entero (alrededor hay un marco dorado y un
## margen transparente), asi que un texto que cabe "en el boton" se sale de la
## chapa. Medido sobre ui_button_plate.png y ui_button_small.png.
const PLATE_BODY := Vector2(0.094, 0.1875)
const SMALL_BODY := Vector2(0.15, 0.33)

static var _font: Font = null
static var _title_font: Font = null


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
	return _font


## La fuente sin contorno. Solo la usa el titulo de la pantalla de inicio.
static func title_font() -> Font:
	if _title_font == null:
		_title_font = load(TITLE_FONT_PATH) as Font
	return _title_font


## Ajusta un tamano pedido al multiplo de FONT_STEP mas cercano. Nunca baja de
## un paso, para que ningun texto se quede en un solo pixel de alto.
static func font_step(size: int) -> int:
	if size <= FONT_STEP:
		return FONT_STEP
	return maxi(FONT_STEP, int(round(float(size) / float(FONT_STEP))) * FONT_STEP)


## Ancho en pixeles de un texto con la fuente del juego.
##
## No hace falta medir nada: el glifo mide 7 px de arte de celda (5 de tinta y
## 2 de contorno) y el .fnt dice que su unidad es 1, asi que a tamano N cada
## caracter ocupa N pixeles exactos. El texto es de ancho N x numero de
## caracteres, y siempre cabe en la cuenta.
##
## Con la fuente suave de antes esto no era cierto (una "i" ocupaba menos que
## una "W"), asi que los rotulos se dimensionaban a ojo. Ahora se puede calcular.
static func text_width(text: String, font_size: int) -> float:
	return float(font_step(font_size)) * float(text.length())


## El mayor tamano (multiplo de FONT_STEP) con el que `text` cabe en `box_width`.
## Se usa para que un rotulo largo no se salga de su caja: antes se ajustaba a
## ojo y con la fuente nueva manyos se salian.
static func fit_size(text: String, box_width: float, max_size: int = 96) -> int:
	var n := maxi(1, text.length())
	var best := FONT_STEP
	for k in range(1, font_step(max_size) / FONT_STEP + 1):
		var s := k * FONT_STEP
		if float(s) * float(n) <= box_width:
			best = s
	return best


## El tamano que hace caber TODA una lista de textos en la misma caja.
##
## Es lo que hay que usar cuando los nombres van en fila o en columna (los sobres
## de la zona de compra, los items de la tienda). Encoger cada uno por su cuenta hace que
## "SOBRES" salga a 28 px y "ELECTRONICA" a 14, y una fila con tres tamanos
## distintos se lee como un fallo, no como un diseno.
static func row_size(texts: Array, box_width: float, max_size: int = 96) -> int:
	var result := font_step(max_size)
	for t in texts:
		result = mini(result, fit_size(str(t), box_width, max_size))
	return result


static func snap(v: float) -> float:
	return snappedf(v, GRID)


# --------------------------------------------------------------------------- #
# Etiquetas
# --------------------------------------------------------------------------- #
## Etiqueta con la fuente del juego. El tamano se ajusta a escala entera sola.
static func label(text: String, font_size: int = 40, color: Color = Palette.CREAM,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	if font() != null:
		l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", font_step(font_size))
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		l.add_theme_constant_override("outline_size", outline)
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
		size = fit_size(text, box.x, font_size)
	var l := label(text, size, color, align, outline)
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var needed := Vector2(text_width(text, size), text_height(size))
	l.size = Vector2(maxf(box.x, needed.x), maxf(box.y, needed.y))
	l.position = center - l.size * 0.5
	return l


## Igual que label_at() pero con la fuente SIN contorno, para el titulo. Las dos
## fuentes comparten rejilla, asi que miden igual y todo lo de label_at vale.
static func title_label_at(text: String, center: Vector2, box: Vector2,
		font_size: int = 40, color: Color = Palette.CREAM,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, font_size, color, align, 0)
	if title_font() != null:
		l.add_theme_font_override("font", title_font())
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var needed := Vector2(text_width(text, font_size), text_height(font_size))
	l.size = Vector2(maxf(box.x, needed.x), maxf(box.y, needed.y))
	l.position = center - l.size * 0.5
	return l


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
		var l := label(text, fit_size(text, ancho_texto, font_size),
			Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
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
	var text_x0 := inner_x0
	if icon != "":
		var ih := s.y * 0.45
		b.add_child(_icon(icon, Vector2(inner_x0 + ih * 0.5, s.y * 0.5), ih))
		text_x0 = inner_x0 + ih + s.y * 0.08
	if text != "":
		var l := label(text, fit_size(text, inner_x1 - text_x0, font_size),
			Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		l.anchor_left = 0.0
		l.anchor_right = 1.0
		l.anchor_top = 0.0
		l.anchor_bottom = 1.0
		l.offset_left = text_x0
		l.offset_right = inner_x1 - s.x
		b.add_child(l)

	b.button_down.connect(func() -> void: plate.texture = Sprites.tex(pressed_sprite))
	b.button_up.connect(func() -> void: plate.texture = Sprites.tex(sprite))
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


## El boton de cerrar, que es el sprite entero (ui_button_close, 256x256).
static func close_button(center: Vector2, side: float = 96.0) -> Button:
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
	parent.add_child(b)
	return b
