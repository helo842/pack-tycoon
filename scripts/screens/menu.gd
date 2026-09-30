# Menu - la pantalla de inicio.
#
# Fondo de trastienda, el titulo y dos chapas. Es la maqueta shot_start.png
# montada con los mismos sprites y las mismas medidas.
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
	var t := UIKit.label("PACK", 128, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0)
	t.size = Vector2(900, 160)
	t.position = Vector2(510, 150)
	add_child(t)

	var s := UIKit.label("TYCOON", 128, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 0)
	s.size = Vector2(900, 160)
	s.position = Vector2(510, 300)
	add_child(s)

	var sub := UIKit.label("ABRE PAQUETES. A CIEGAS.", 40, Palette.CREAM_D,
			HORIZONTAL_ALIGNMENT_CENTER, 0)
	sub.size = Vector2(900, 60)
	# A 460 el rotulo quedaba a 1 px del marco de la chapa de JUGAR (que sube
	# hasta y 512). Con 450 el hueco es de 11 px por arriba y por abajo.
	sub.position = Vector2(510, 450)
	add_child(sub)

	# El destello_detras del titulo: el sprite fx_shine, que es lo unico con
	# alfa graduado del catalogo y por eso sirve justo para esto.
	var shine := UIKit.art("fx_shine", Vector2(960, 300), 2.6, Color(1, 1, 1, 0.16))
	shine.modulate.a = 0.0
	add_child(shine)
	var tw := create_tween().set_loops()
	tw.tween_property(shine, "modulate:a", 0.30, 2.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(shine, "modulate:a", 0.10, 2.1).set_trans(Tween.TRANS_SINE)


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
	# La moneda va al rincon, no en linea con el texto: el sprite son 72 px y la
	# chapa de AJUSTES baja hasta y 1028, asi que entre la chapa y el borde solo
	# quedan 52 px, y en cualquier x debajo de la chapa la moneda le cae encima.
	# A la izquierda del pie no hay nada.
	var money := UIKit.square("currency_coin", Vector2(200, 1000), 0.14)
	add_child(money)
	# El texto a y 1045, no a 1030: la chapa de AJUSTES llega a 1028 y a 1030 el
	# rotulo le pasaba por debajo al marco de la chapa.
	# label_at y no label + size a mano: el texto son 36 caracteres (756 px a
	# tamano 21) y la caja de 900 se queda corta si se pide mas.
	add_child(UIKit.label_at("PRIMERA VERSION - SIN LOGROS TODAVIA",
			Vector2(1210, 1045), Vector2(900, 50), 30, Palette.CREAM_D,
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
	if event.is_action_pressed("ui_cancel") and _settings != null:
		var main := MainRoot.get_root()
		if main != null:
			main.pop_veil(_settings)
		_settings = null
		get_viewport().set_input_as_handled()
