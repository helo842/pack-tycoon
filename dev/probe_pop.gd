# Sonda del color de los numeros de dano. NO es una prueba: es una herramienta
# para MIRAR, como probe_font.gd.
#
# Hace falta porque el color que se le pide a un numero no es el que sale: los
# sprites de los digitos (num_*.png) ya vienen pintados de oro (amarillo arriba,
# naranja en el cuerpo y marron abajo) y PixelNumber.color los MULTIPLICA, asi
# que pedir Palette.GOLD no da naranja sino marron oscuro. Aqui se pintan un
# golpe normal y un critico sobre el fondo y sobre el arte de un sobre, y se
# guarda el PNG para poder leer el pixel exacto con el que sale cada uno.
#
#   $G --path . --rendering-driver opengl3 res://dev/ProbePop.tscn
#   (queda en ~/.local/share/godot/app_userdata/Pack Tycoon/shots/_probe_pop.png)
#
# Las medidas que salieron de aqui estan escritas en damage_popup.gd: el cuerpo
# del digito sale naranja (232, 96, 0) en un golpe normal y amarillo (232, 218, 0)
# en un critico. Si alguien toca esos tintes, esto es lo que hay que volver a
# medir.
extends Node

const SHOT_SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots/")
	var vp := SubViewport.new()
	vp.size = SHOT_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.04)
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	root.add_child(UIKit.image("pack_cards", Vector2(300, 300), Vector2(256, 256)))
	var normal := DamagePopup.pop(root, Vector2(900, 300), 14.0, false)
	var crit := DamagePopup.pop(root, Vector2(1300, 300), 28.0, true)
	for n in [normal, crit]:
		var p := n as PixelNumber
		# Se congela la subida para medir el color de la tinta en su sitio.
		p.position = Vector2(200.0 if p == normal else 600.0, 200.0)
		p.scale = Vector2.ONE
		p.modulate = Color.WHITE
	for i in 3:
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	img.save_png("user://shots/_probe_pop.png")
	print("SONDA: ", img.get_width(), "x", img.get_height())
	print("  normal en ", str(normal.get_global_rect()), " color ", str(normal.color))
	print("  critico en ", str(crit.get_global_rect()), " color ", str(crit.color))
	get_tree().quit()
