# Sonda del anillo de espera. NO es una prueba: es una herramienta para MIRAR,
# como probe_pop.gd.
#
# Pinta el anillo de un sobre en cuatro momentos de la carga (recien empezado, a
# mitad, dentro del tramo perfecto y en la zona dorada) sobre el arte del sobre,
# a tamano de mesa y ampliado, y guarda el PNG. Sirve para ver de un vistazo si
# las zonas del golpe perfecto (TimerRing.zone_from) se leen y no pisan el borde.
#
#   $G --path . --rendering-driver opengl3 res://dev/ProbeRing.tscn
#   (queda en user://shots/_probe_ring.png)
extends Node

const SHOT_SIZE := Vector2i(1600, 900)
const MOMENTS := [0.02, 0.5, 0.86, 0.94]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots/")
	var vp := SubViewport.new()
	vp.size = SHOT_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var root := Control.new()
	root.size = Vector2(SHOT_SIZE)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.04)
	bg.size = Vector2(SHOT_SIZE)
	root.add_child(bg)
	for i in MOMENTS.size():
		var p: float = MOMENTS[i]
		# Arriba a tamano de mesa (320), abajo al doble para ver las celdas.
		for row in 2:
			var side := 320.0 if row == 0 else 360.0
			var centre := Vector2(200.0 + 400.0 * float(i), 200.0 if row == 0 else 640.0)
			var ring := TimerRing.new()
			ring.size = Vector2(side, side)
			ring.position = centre - ring.size * 0.5
			ring.zone_from = Gameplay.PERFECT_FROM
			ring.sweet_from = Gameplay.SWEET_FROM
			ring.sweet_to = Gameplay.SWEET_TO
			ring.progress = p
			if p >= Gameplay.SWEET_FROM and p < Gameplay.SWEET_TO:
				ring.head_color = TimerRing.SWEET_COLOR
			elif p >= Gameplay.PERFECT_FROM:
				ring.head_color = TimerRing.ZONE_COLOR
			root.add_child(ring)
			if row == 0:
				root.add_child(UIKit.image("pack_cards", centre, Vector2(256, 256)))
		var l := UIKit.label_at("%d %%" % roundi(p * 100.0), Vector2(200.0 + 400.0 * float(i), 860.0),
				Vector2(300, 40), 28, Palette.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0)
		root.add_child(l)
	for i in 3:
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	img.save_png("user://shots/_probe_ring.png")
	print("SONDA: ", ProjectSettings.globalize_path("user://shots/_probe_ring.png"))
	get_tree().quit()
