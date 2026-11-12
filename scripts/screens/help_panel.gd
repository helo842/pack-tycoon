# HelpPanel - la ayuda: como va el golpe perfecto y el juego en resumen.
#
# Se abre desde Ajustes (boton AYUDA, encima de CREDITOS). A la izquierda un
# anillo de verdad (TimerRing) cargando en bucle sobre un sobre, que acierta
# siempre en la zona dorada: se ve donde hay que pulsar en vez de leerlo. A la
# derecha los pasos del juego.
#
# Los numeros salen de Gameplay y LootDB, no van escritos a mano: si cambia el
# equilibrio, la ayuda cambia con el.
class_name HelpPanel
extends Control

signal closed()

## Mismas medidas que CreditsPanel (ui_panel_shop): interior de x 224 a 1696 y de
## y 140 a 940.
const LEFT_X := 520.0
const RIGHT := Rect2(860, 300, 800, 620)
const RING_CENTER := Vector2(LEFT_X, 495)
## Como en la mesa, el sobre tiene que quedar DENTRO del aro de color (6 de 16
## celdas de radio): a 300 el aro empieza en 112 px y el sobre de 160 llega a 89.
const RING_SIZE := Vector2(300, 300)
## El anillo de la demo pulsa aqui (dentro de la zona dorada) y vuelve a empezar.
const DEMO_HIT := 0.945
const DEMO_TIME := 1.65

var _ring: TimerRing
var _pack: TextureRect
var _t := 0.0


func _ready() -> void:
	add_child(UIKit.veil(0.62))
	add_child(UIKit.panel("ui_panel_shop"))
	add_child(UIKit.label_at("AYUDA", Vector2(960, 220), Vector2(1400, 70),
			48, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var close := UIKit.close_button(UIKit.PANEL_CLOSE)
	close.pressed.connect(_close)
	add_child(close)
	_build_perfect()
	_build_steps()


## Columna izquierda: el anillo de muestra, la leyenda de colores y tres lineas.
func _build_perfect() -> void:
	add_child(UIKit.label_at("GOLPE PERFECTO", Vector2(LEFT_X, 310), Vector2(560, 50), 28,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	_ring = TimerRing.new()
	_ring.size = RING_SIZE
	_ring.position = RING_CENTER - RING_SIZE * 0.5
	_ring.zone_from = Gameplay.PERFECT_FROM
	_ring.sweet_from = Gameplay.SWEET_FROM
	_ring.sweet_to = Gameplay.SWEET_TO
	add_child(_ring)
	_pack = UIKit.image("pack_cards", RING_CENTER, Vector2(160, 160))
	add_child(_pack)

	_legend(TimerRing.ZONE_COLOR, "TURQUESA: GOLPE X%s" % Gameplay.PERFECT_MULT, 680)
	_legend(TimerRing.SWEET_COLOR, "BLANCO (DORADO): X%s MAS" % Gameplay.SWEET_MULT, 724)
	_text("PULSA EL SOBRE CUANDO LA PUNTA DEL ANILLO PASE POR EL TURQUESA. SEGUIDOS"
			+ " SUMAN RACHA. SI PULSAS ANTES, PIERDES UN TROZO DE VUELTA Y LA RACHA.",
			Rect2(250, 760, 560, 160), 14, Palette.CREAM_D)


func _legend(color: Color, text: String, y: float) -> void:
	var sq := ColorRect.new()
	sq.color = color
	sq.size = Vector2(28, 28)
	sq.position = Vector2(270, y - 14)
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sq)
	add_child(UIKit.label_at(text, Vector2(540, y), Vector2(480, 40), 21, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_LEFT, 0, true))


## Columna derecha: el juego en seis pasos.
func _build_steps() -> void:
	add_child(UIKit.label_at("COMO SE JUEGA", Vector2(RIGHT.get_center().x, 310),
			Vector2(RIGHT.size.x, 50), 28, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, true))
	var steps := [
		"1. COMPRA SOBRES EN LA COLUMNA DE LA IZQUIERDA: CAEN EN LA MESA.",
		"2. PULSA UN SOBRE: SE CARGA SU ANILLO Y CADA VUELTA ES UN GOLPE. SIN VIDA, SE ABRE.",
		"3. SALE UN OBJETO CON RAREZA Y NOTA DEL 1 AL 10. LO NORMAL SE VENDE SOLO; LO BUENO LO GUARDAS O LO VENDES.",
		"4. MEJORA EN LA TIENDA Y EXPON LO MEJOR EN EL ARMARIO: DA BONUS.",
		"5. CON %s HAZ REBIRTH: MONEDAS PARA EL ARBOL, QUE NO SE PIERDE." \
				% PixelNumber.format(LootDB.REBIRTH_REQUIRE),
		"TECLAS: T TIENDA, A ARMARIO, R ARBOL, 1 2 3 HABILIDADES, ESC MENU.",
	]
	_text("\n".join(steps), Rect2(RIGHT.position + Vector2(0, 60), RIGHT.size - Vector2(0, 60)),
			21, Palette.CREAM)


## Un bloque de texto que salta de linea solo, dentro de `box`.
func _text(text: String, box: Rect2, font_size: int, color: Color) -> void:
	var l := UIKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.add_theme_constant_override("line_spacing", 6)
	l.position = box.position
	l.size = box.size
	add_child(l)


## La demo: el anillo carga como en la mesa y "pulsa" en la zona dorada.
func _process(delta: float) -> void:
	_t += delta
	var p := _t / DEMO_TIME
	if p >= DEMO_HIT:
		_t = 0.0
		p = 0.0
		UIKit.punch(_pack, 1.15)
	_ring.progress = p
	if p >= Gameplay.SWEET_FROM and p < Gameplay.SWEET_TO:
		_ring.head_color = TimerRing.SWEET_COLOR
	elif p >= Gameplay.PERFECT_FROM:
		_ring.head_color = TimerRing.ZONE_COLOR
	else:
		_ring.head_color = Palette.GOLD_XL


## Quien lo abrio (Ajustes) lo saca del velo con pop_veil, como los creditos.
func _close() -> void:
	Sound.click()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
