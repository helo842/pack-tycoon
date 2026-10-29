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


func _ready() -> void:
	# El fondo ya viene a 1920x1080, que es justo el tamano de la pantalla base.
	add_child(UIKit.image("bg_menu_backroom", Vector2(960, 540), Vector2(1920, 1080)))

	_build_title()
	_build_buttons()
	_build_footer()


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
	add_child(UIKit.title_label_at("PACK", Vector2(960, 210), Vector2(1200, 150), 112,
			Palette.CREAM))
	add_child(UIKit.title_label_at("TYCOON", Vector2(960, 345), Vector2(1200, 170), 140,
			Palette.GOLD_XL))
	# A 480 el rotulo queda a 32 px de la chapa de JUGAR (que sube hasta y 512).
	add_child(UIKit.label_at("ABRE PAQUETES. A CIEGAS.", Vector2(960, 480),
			Vector2(1200, 60), 35, Palette.CREAM_D, HORIZONTAL_ALIGNMENT_CENTER, 0))


func _build_buttons() -> void:
	# 512x256 en vez de 448x224: el hueco real para el texto (el cuerpo oscuro
	# de la chapa menos el icono) es lo que dicta el tamano de la letra, y con
	# la chapa mas estrecha "AJUSTES" se encogia a 28 px mientras "JUGAR" se
	# quedaba en 49 y las dos lineas no parecian del mismo juego.
	var play := UIKit.plate_button("JUGAR", "ui_icon_play", Vector2(960, 640),
			Vector2(512, 256), 49)
	play.pressed.connect(_on_play)
	add_child(play)

	var settings := UIKit.plate_button("AJUSTES", "ui_icon_settings", Vector2(960, 900),
			Vector2(512, 256), 42)
	settings.pressed.connect(_on_settings)
	add_child(settings)


func _build_footer() -> void:
	# SIN MONEDA. Hubo una (currency_coin, en la esquina de abajo a la izquierda)
	# y el usuario la quito: en el arranque no hay dinero que contar -la partida no
	# ha empezado-, asi que el unico adorno del menu era un cero que no significa
	# nada todavia. El dinero aparece donde se gana, en la barra de la partida.
	#
	# El texto a y 1045, no a 1030: la chapa de AJUSTES llega a 1028 y a 1030 el
	# rotulo le pasaba por debajo al marco de la chapa.
	# label_at y no label + size a mano: el texto son 36 caracteres (756 px a
	# tamano 21) y la caja de 900 se queda corta si se pide mas.
	add_child(UIKit.label_at("PRIMERA VERSION - SIN LOGROS TODAVIA",
			Vector2(960, 1045), Vector2(900, 50), 30, Palette.CREAM_D,
			HORIZONTAL_ALIGNMENT_CENTER, 0, true))


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
