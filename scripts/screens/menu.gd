# Menu - la pantalla de inicio.
#
# Fondo de trastienda, el titulo y dos chapas. Es la maqueta shot_start.png
# montada con los mismos sprites y las mismas medidas.
#
# Y NADA MAS: aqui no hay hucha. El rebirth VIVIO en este menu (arriba a la
# derecha, la hucha con su contador) y se quito: el rebirth se hace jugando -el
# requisito es el dinero que tienes en el contador-, asi que su sitio es la
# pantalla de partida, al lado de la tienda (ver game.gd, _open_rebirth). En el
# menu lo que se hacia era mirar, y en una partida nueva lo que se veia era una
# hucha con un cero y un "TE FALTAN 1.000.000" en rojo antes de saber siquiera
# que era un rebirth.
extends Control

const SETTINGS_SCENE := preload("res://scenes/SettingsPanel.tscn")

var _settings: SettingsPanel = null


## Donde va cada palabra del titulo. Con estos centros (y "Pack" a 84 px) quedan
## ~30 px de aire entre "Pack" y "Tycoon" contando contorno y sombra, que no se
## cierran ni con la onda en contra (WAVE_AMP), y "Tycoon" no llega al
## subtitulo (y 480).
const PACK_Y := 178.0
const TYCOON_Y := 362.0
## La onda: cuanto sube y baja cada letra (px), lo rapido que va y el desfase
## entre una letra y la siguiente.
const WAVE_AMP := 7.0
const WAVE_SPEED := 2.6
const WAVE_STEP := 0.55

## Las letras del titulo: [Label, y de reposo, numero en la onda].
var _letters: Array = []


func _ready() -> void:
	# El fondo ya viene a 1920x1080, que es justo el tamano de la pantalla base.
	add_child(UIKit.image("bg_menu_backroom", Vector2(960, 540), Vector2(1920, 1080)))
	# Polvo a la luz de la lampara, por toda la trastienda.
	add_child(UIKit.dust(Rect2(0, 80, 1920, 1000), 40))

	_build_title()
	_build_buttons()


func _build_title() -> void:
	# El titulo va con label_at y no con label + size a mano: asi la caja se
	# agranda si el texto no cabe y nunca se recorta por los lados, que es lo que
	# le pasaba al subtitulo con la caja de 900.
	#
	# Y NO lleva destello detras. El fx_shine que habia sobre el fondo de la
	# trastienda se leia como un halo azulado, no como luz, y el usuario lo quito
	# a proposito: sin el, el titulo se apoya en el fondo oscuro y se lee mejor.
	# La fuente del titulo no lleva contorno: el borde negro se veia como una
	# sombra gorda sobre el fondo y el usuario lo quito.
	#
	# Las dos palabras van SEPARADAS (antes "Pack" se montaba sobre "Tycoon": la
	# letra de titulos es mas alta que la de antes) y cada letra suelta, para que
	# el titulo ondule (ver _process).
	_wavy_word("Pack", PACK_Y, 84, Palette.CREAM, 0)
	_wavy_word("Tycoon", TYCOON_Y, 140, Palette.GOLD_XL, 4)
	# A 480 el rotulo queda a 32 px de la chapa de JUGAR (que sube hasta y 512).
	add_child(UIKit.label_at("Abre paquetes. A ciegas.", Vector2(960, 480),
			Vector2(1200, 60), 35, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0))


## Una palabra del titulo, letra a letra y centrada en x 960. Cada letra se
## coloca por el ancho de lo que lleva delante (la letra de titulos tiene cada
## letra de su ancho) y se apunta en _letters para moverla. `first` es el numero
## de la primera letra en la onda, para que "Tycoon" siga a "Pack".
func _wavy_word(text: String, center_y: float, font_size: int, color: Color,
		first: int) -> void:
	var f := UIKit.font_for(font_size, false, color)
	var step := UIKit.font_step(font_size)
	var x0 := 960.0 - UIKit.text_width(text, font_size, false, color) * 0.5
	var alto := UIKit.text_height(font_size)
	for i in text.length():
		var antes := f.get_string_size(text.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, step).x
		var ancho := f.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, step).x
		var l := UIKit.label(text[i], font_size, color)
		l.size = Vector2(ancho, alto)
		l.position = Vector2(x0 + antes, center_y - alto * 0.5).round()
		add_child(l)
		_letters.append([l, l.position.y, first + i])


## LA ONDA DEL TITULO: cada letra sube y baja un poco, un pelin despues que la de
## su izquierda, asi que por el titulo pasa una ola. En pixeles enteros, para no
## emborronar la letra.
func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for d in _letters:
		(d[0] as Control).position.y = roundf(float(d[1])
				+ sin(t * WAVE_SPEED - float(d[2]) * WAVE_STEP) * WAVE_AMP)


func _build_buttons() -> void:
	# 512x256 en vez de 448x224: el hueco real para el texto (el cuerpo oscuro
	# de la chapa menos el icono) es lo que dicta el tamano de la letra, y con
	# la chapa mas estrecha "AJUSTES" se encogia a 28 px mientras "JUGAR" se
	# quedaba en 49 y las dos lineas no parecian del mismo juego.
	var play := UIKit.plate_button("Jugar", "ui_icon_play", Vector2(960, 640),
			Vector2(512, 256), 49)
	play.pressed.connect(_on_play)
	add_child(play)

	var settings := UIKit.plate_button("Ajustes", "ui_icon_settings", Vector2(960, 900),
			Vector2(512, 256), 42)
	settings.pressed.connect(_on_settings)
	add_child(settings)


# --------------------------------------------------------------------------- #

func _on_play() -> void:
	Sound.click()
	var main := MainRoot.get_root()
	if main != null:
		main.show_game()


func _on_settings() -> void:
	if _settings != null:
		return
	Sound.click()
	_settings = SETTINGS_SCENE.instantiate() as SettingsPanel
	var main := MainRoot.get_root()
	if main != null:
		main.push_veil(_settings)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# ESC cierra la capa de arriba y solo esa. Al menu solo le queda un panel
	# (ajustes): la hucha se fue a la barra de la partida.
	if _settings != null:
		var main := MainRoot.get_root()
		if main != null:
			main.pop_veil(_settings)
		_settings = null
		get_viewport().set_input_as_handled()
