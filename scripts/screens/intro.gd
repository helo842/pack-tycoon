# IntroScreen - la historia del principio, antes del menu.
#
# Un cuento mudo en cinco vinetas, como la intro de The Binding of Isaac: una
# pagina de papel en el centro, dibujos sencillos y paso de pagina entre una y
# otra. SIN NARRADOR: solo dibujos (lo unico escrito es lo que sale DENTRO del
# movil, que es parte del dibujo).
#
#   1 NOCHE    un chaval en la cama, de noche, con la cara iluminada por el movil
#   2 VIDEO    el video vertical: alguien abre un sobre, sale una carta MITO, mil
#              corazones y "+1.000.000"
#   3 IDEA     al chaval se le ponen los ojos de dolar: "si abro cajas me hago
#              millonario"
#   4 HUCHA    rompe la hucha a martillazos
#   5 TIENDA   la trastienda llena de sobres: aqui empieza el juego
#
# Un clic (o una tecla) la salta en cualquier momento. Sale cada vez que se abre
# el juego, pero solo si Main es la escena principal: las pruebas de dev/ montan
# Main a mano y esperan el menu enseguida (ver MainRoot._ready).
#
# El chaval no tiene sprite: es pixel art escrito aqui mismo con letras (ver Pix
# y KID), a la misma escala gorda que el resto del juego.
class_name IntroScreen
extends Control

## Cada vineta y lo que dura. Suman unos 17 s.
const SCENES := [["_scene_night", 3.0], ["_scene_video", 5.4], ["_scene_idea", 3.0],
		["_scene_piggy", 2.8], ["_scene_shop", 3.4]]
## La pagina de papel y la zona de dibujo dentro (16:9).
const PAGE := Vector2(1520, 890)
const STAGE := Vector2(1440, 810)

## Pixel art del chaval, 16x17. Cada letra es un color de KID_COLORS; "." vacio.
## Los ojos son las columnas 4-5 y 10-11, filas 6-7 (en KID_GRIN, signos de dolar).
const KID := [
	"....OOOOOOOO....",
	"...OHHHHHHHHO...",
	"..OHHHHHHHHHHO..",
	"..OHHHHHHHHHHO..",
	"..OHHSSSSSSHHO..",
	"..OHSSSSSSSSHO..",
	"..OSEESSSSEESO..",
	"..OSEPSSSSEPSO..",
	"..OSSSSSSSSSSO..",
	"..OSrSSSSSSrSO..",
	"..OSSSSMMSSSSO..",
	"...OSSSSSSSSO...",
	"....OOSSSSOO....",
	"..OOTTTTTTTTOO..",
	".OTTTTTTTTTTTTO.",
	"OTTTTTTWWTTTTTTO",
	"OTTTTTTWWTTTTTTO",
]
## El mismo con la sonrisa de oreja a oreja y LOS OJOS HECHOS SIGNOS DE DOLAR
## ("D"): cada ojo es una S de 3x5 (columnas 4-6 y 9-11, filas 5-9) cruzada por
## la raya del $ en verde oscuro ("d", columnas 5 y 10). La raya ya no asoma por
## arriba y por abajo: con ella median 7 de alto y se veian demasiado largos.
## Con piel alrededor: pegados al contorno parecian dos manchas verdes.
const KID_GRIN := [
	"....OOOOOOOO....",
	"...OHHHHHHHHO...",
	"..OHHHHHHHHHHO..",
	"..OHHHHHHHHHHO..",
	"..OHHSSSSSSHHO..",
	"..OSDdDSSDdDSO..",
	"..OSDdSSSDdSSO..",
	"..OSDdDSSDdDSO..",
	"..OSSdDSSSdDSO..",
	"..OSDdDSSDdDSO..",
	"..OSOWWWWWWOSO..",
	"...OSOMMMMOSO...",
	"....OOSSSSOO....",
	"..OOTTTTTTTTOO..",
	".OTTTTTTTTTTTTO.",
	"OTTTTTTWWTTTTTTO",
	"OTTTTTTWWTTTTTTO",
]
const KID_COLORS := {
	"O": Palette.OUTLINE, "H": Color8(110, 64, 36), "S": Color8(246, 200, 156),
	"r": Color8(236, 140, 120), "E": Color.WHITE, "P": Palette.OUTLINE,
	"M": Color8(140, 40, 52), "T": Color8(232, 72, 96), "W": Palette.CREAM,
	"D": Color8(40, 160, 70), "d": Color8(16, 84, 36),
}
const HEART := [".HH.HH.", "HHHHHHH", "HHHHHHH", ".HHHHH.", "..HHH..", "...H..."]
const BUBBLE := [".WWWWW.", "WWWWWWW", "WWWWWWW", ".WWWWW.", "..W....", "......."]
const SHARE := ["....W..", "....WW.", "WWWWWWW", "W...WW.", "W...W..", "......."]
const MOON := ["..YYY.", ".YY...", "YY....", "YY....", ".YY...", "..YYY."]
const HAMMER := ["..GGGGGG..", ".GGGGGGGG.", ".GGGGGGGG.", "..GGGGGG..", "....BB....",
		"....BB....", "....BB....", "....BB....", "....BB....", "....BB....",
		"....BB....", "....BB...."]
const ICON_COLORS := {
	"H": Color8(240, 56, 88), "W": Color.WHITE, "Y": Palette.GOLD_HI,
	"G": Color8(150, 150, 170), "B": Color8(120, 72, 40),
}
const COMMENTS := ["NO PUEDE SER", "QUE SUERTE", "YO TAMBIEN QUIERO", "MILLONARIO"]

var _page: Control
var _stage: Control
var _world: Control = null
var _story: Tween = null
var _done := false


## Un dibujo de pixel art hecho con letras: cada letra de `rows` es una celda de
## `px` pixeles del color que diga `colors`.
class Pix extends Control:
	var rows: Array = []
	var colors: Dictionary = {}
	var px := 8.0

	func setup(r: Array, c: Dictionary, p: float) -> Pix:
		rows = r
		colors = c
		px = p
		size = Vector2(str(r[0]).length(), r.size()) * p
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()
		return self

	func _draw() -> void:
		for y in rows.size():
			var row := str(rows[y])
			for x in row.length():
				var ch := row[x]
				if colors.has(ch):
					draw_rect(Rect2(Vector2(x, y) * px, Vector2(px, px)), colors[ch])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rect(Vector2.ZERO, Vector2(1920, 1080), Palette.NIGHT_DD))
	# La pagina: papel con borde, que se balancea un poco como si la sujetaran.
	_page = Control.new()
	_page.size = PAGE
	_page.position = (Vector2(1920, 1080) - PAGE) * 0.5
	_page.pivot_offset = PAGE * 0.5
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	_page.add_child(_rect(Vector2(-8, -8), PAGE + Vector2(16, 16), Palette.OUTLINE))
	_page.add_child(_rect(Vector2.ZERO, PAGE, Palette.CREAM_D))
	_stage = Control.new()
	_stage.size = STAGE
	_stage.position = (PAGE - STAGE) * 0.5
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_stage)
	var sway := _page.create_tween().set_loops()
	sway.tween_property(_page, "rotation", 0.006, 1.6).set_trans(Tween.TRANS_SINE)
	sway.tween_property(_page, "rotation", -0.006, 1.6).set_trans(Tween.TRANS_SINE)

	var hint := UIKit.label_at("CLIC PARA SALTAR", Vector2(1720, 1060), Vector2(360, 30), 14,
			Palette.CREAM_D, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(hint)
	var ht := hint.create_tween().set_loops()
	ht.tween_property(hint, "modulate:a", 0.35, 0.8)
	ht.tween_property(hint, "modulate:a", 1.0, 0.8)

	_story = create_tween()
	for i in SCENES.size():
		_story.tween_callback(_turn_page.bind(str(SCENES[i][0]), i > 0))
		_story.tween_interval(float(SCENES[i][1]))
	_story.tween_callback(_finish)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_finish()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_finish()
		get_viewport().set_input_as_handled()


## Fin de la historia (o salto): fundido a negro y al menu.
func _finish() -> void:
	if _done:
		return
	_done = true
	if _story != null:
		_story.kill()
	var black := _rect(Vector2.ZERO, Vector2(1920, 1080), Color(0, 0, 0, 0))
	add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void:
		var main := MainRoot.get_root()
		if main != null:
			main.show_menu()
		else:
			queue_free())


## El paso de pagina: la pagina se pliega (escala x a 0), se cambia el dibujo y se
## despliega. La primera vineta entra sin pliegue.
func _turn_page(scene: String, flip: bool) -> void:
	if not flip:
		_build(scene)
		return
	Sound.play("sfx_click", -8.0, 0.7)
	var tw := _page.create_tween()
	tw.tween_property(_page, "scale:x", 0.02, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_build.bind(scene))
	tw.tween_property(_page, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Cambia el dibujo: los tweens de cada vineta cuelgan de su _world, asi que al
## borrarlo se paran solos (y un salto a mitad no deja sonidos sueltos).
func _build(scene: String) -> void:
	if _world != null:
		_world.queue_free()
	_world = Control.new()
	_world.size = STAGE
	_world.pivot_offset = STAGE * 0.5
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_world)
	call(scene, _world)


# --------------------------------------------------------------------------- #
# Las vinetas
# --------------------------------------------------------------------------- #

## 1 NOCHE: la habitacion a oscuras, el chaval en la cama mirando el movil, y la
## "camara" que se acerca al movil.
func _scene_night(w: Control) -> void:
	w.add_child(_rect(Vector2.ZERO, STAGE, Color8(18, 20, 44)))
	# Ventana con luna y estrellas que parpadean.
	w.add_child(_rect(Vector2(150, 100), Vector2(320, 250), Palette.CREAM_D))
	w.add_child(_rect(Vector2(164, 114), Vector2(292, 222), Color8(34, 46, 96)))
	w.add_child(_rect(Vector2(304, 114), Vector2(12, 222), Palette.CREAM_D))
	w.add_child(_rect(Vector2(164, 219), Vector2(292, 12), Palette.CREAM_D))
	w.add_child(_pix(MOON, ICON_COLORS, 12, Vector2(390, 165)))
	for s in [Vector2(200, 150), Vector2(250, 280), Vector2(370, 290), Vector2(420, 260)]:
		var star := _rect(s, Vector2(10, 10), Palette.GOLD_HI)
		w.add_child(star)
		var st := star.create_tween().set_loops()
		st.tween_property(star, "modulate:a", 0.2, randf_range(0.3, 0.7))
		st.tween_property(star, "modulate:a", 1.0, randf_range(0.3, 0.7))
	# Cama: cabecero alto detras de toda la cabeza (bajo y estrecho parecian dos
	# orejas), almohada, chaval y manta por delante.
	w.add_child(_rect(Vector2(470, 210), Vector2(500, 420), Palette.OUTLINE))
	w.add_child(_rect(Vector2(482, 222), Vector2(476, 408), Color8(96, 58, 40)))
	w.add_child(_rect(Vector2(500, 420), Vector2(440, 120), Palette.CREAM))
	var kid := _pix(KID, KID_COLORS, 20, Vector2(720, 470))
	w.add_child(kid)
	w.add_child(_rect(Vector2(360, 600), Vector2(720, 230), Color8(64, 90, 170)))
	w.add_child(_rect(Vector2(360, 600), Vector2(720, 16), Color8(96, 124, 206)))
	# La luz del movil en la cara: un parpadeo azulado.
	var lt := kid.create_tween().set_loops()
	lt.tween_property(kid, "modulate", Color(0.7, 0.95, 1.2), 0.25)
	lt.tween_property(kid, "modulate", Color(0.55, 0.7, 1.0), 0.35)
	var screen := _phone(w, Vector2(720, 650), Vector2(140, 220))
	screen.get_parent().rotation = -0.08
	_feed(screen)
	# Zoom al movil.
	w.pivot_offset = Vector2(720, 640)
	w.create_tween().tween_property(w, "scale", Vector2(1.8, 1.8), 3.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## 2 VIDEO: el movil a pantalla completa con un video vertical de alguien
## abriendo un sobre. Golpes, destello, carta MITO, corazones y +1.000.000.
func _scene_video(w: Control) -> void:
	w.add_child(_rect(Vector2.ZERO, STAGE, Color8(10, 8, 18)))
	var scr := _phone(w, Vector2(720, 405), Vector2(420, 780))
	var sz := scr.size
	var bg := UIKit.image("bg_table", sz * 0.5, sz)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scr.add_child(bg)
	scr.add_child(_rect(Vector2.ZERO, sz, Color(0, 0, 0, 0.25)))
	scr.add_child(UIKit.label_at("PACKMILLONARIO", Vector2(150, 34), Vector2(260, 30), 14,
			Palette.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 4))
	var live := _rect(Vector2(sz.x - 120, 20), Vector2(100, 30), Color8(232, 40, 72))
	scr.add_child(live)
	live.add_child(UIKit.label_at("EN VIVO", Vector2(50, 15), Vector2(96, 26), 14, Color.WHITE))

	var center := Vector2(165, 320)
	var pack := UIKit.image("pack_cards4", center, Vector2(250, 250))
	scr.add_child(pack)
	var tw := w.create_tween()
	for i in 4:
		tw.tween_interval(0.3)
		tw.tween_callback(func() -> void:
			Sound.play("sfx_open", -10.0, 0.55 + 0.1 * i)
			pack.scale = Vector2(1.18, 0.86)
			pack.rotation = 0.12 * (1 if i % 2 == 0 else -1))
		tw.tween_property(pack, "scale", Vector2.ONE, 0.12)
		tw.parallel().tween_property(pack, "rotation", 0.0, 0.12)
	tw.tween_interval(0.2)
	tw.tween_callback(_reveal.bind(scr, center, pack))

	# La columna de iconos de la derecha, con contadores.
	var x := sz.x - 44
	var heart := _pix(HEART, ICON_COLORS, 8, Vector2(x, 330))
	scr.add_child(heart)
	scr.add_child(_pix(BUBBLE, ICON_COLORS, 8, Vector2(x, 440)))
	scr.add_child(_pix(SHARE, ICON_COLORS, 8, Vector2(x, 540)))
	var likes := UIKit.label_at("0", Vector2(x, 378), Vector2(90, 24), 14, Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, 4)
	scr.add_child(likes)
	scr.add_child(UIKit.label_at("12K", Vector2(x, 488), Vector2(90, 24), 14, Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, 4))
	scr.add_child(UIKit.label_at("8K", Vector2(x, 588), Vector2(90, 24), 14, Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, 4))
	w.create_tween().tween_method(func(v: float) -> void:
		likes.text = "%dK" % int(v), 1.0, 999.0, 5.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# Corazones que suben desde el icono, mas seguidos tras el destello.
	var ht := w.create_tween().set_loops(26)
	ht.tween_interval(0.2)
	ht.tween_callback(_float_heart.bind(scr, heart.position + heart.size * 0.5))

	# La barrita de progreso del video, abajo.
	var bar := _rect(Vector2(0, sz.y - 8), Vector2(0, 8), Color.WHITE)
	scr.add_child(bar)
	w.create_tween().tween_property(bar, "size:x", sz.x, 5.4)


## El destello del video: el sobre se va, sale la carta con su brillo, monedas,
## el +1.000.000 y los comentarios.
func _reveal(scr: Control, center: Vector2, pack: Control) -> void:
	Sound.play("sfx_rare")
	pack.visible = false
	var glow := UIKit.image("rarity_glow_legendary", center, Vector2(420, 420))
	scr.add_child(glow)
	glow.create_tween().set_loops().tween_property(glow, "rotation", TAU, 6.0).as_relative()
	var card := UIKit.image("loot_card_foil_psa10", center, Vector2(240, 240))
	UIKit.holo(card)
	card.scale = Vector2(0.1, 0.1)
	scr.add_child(card)
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_coin_burst(scr, center, 40)
	var flash := _rect(Vector2.ZERO, scr.size, Color.WHITE)
	scr.add_child(flash)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.4)

	var money := UIKit.label_at("+1.000.000", Vector2(160, 480), Vector2(280, 50),
			28, Palette.GOLD_XL, HORIZONTAL_ALIGNMENT_CENTER, 6)
	money.pivot_offset = money.size * 0.5
	money.scale = Vector2(0.2, 0.2)
	scr.add_child(money)
	var mt := money.create_tween()
	mt.tween_property(money, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK)
	mt.tween_property(money, "scale", Vector2.ONE, 0.15)
	mt.tween_property(money, "position:y", money.position.y - 30, 1.6)

	var ct := scr.create_tween()
	for i in COMMENTS.size():
		ct.tween_interval(0.45)
		ct.tween_callback(_comment.bind(scr, str(COMMENTS[i]), i))


func _comment(scr: Control, text: String, i: int) -> void:
	var l := UIKit.label_at(text, Vector2(0, 0), Vector2(10, 24), 14, Palette.CREAM,
			HORIZONTAL_ALIGNMENT_LEFT, 4)
	l.position = Vector2(-l.size.x, 620 + 26 * (i % 4) - 26 * 3)
	scr.add_child(l)
	l.create_tween().tween_property(l, "position:x", 16.0, 0.2).set_trans(Tween.TRANS_BACK)


func _float_heart(scr: Control, from: Vector2) -> void:
	var h := _pix(HEART, ICON_COLORS, randf_range(4, 7), from)
	scr.add_child(h)
	var tw := h.create_tween().set_parallel()
	tw.tween_property(h, "position", h.position + Vector2(randf_range(-90, 10), -randf_range(160, 260)), 1.1)
	tw.tween_property(h, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(h.queue_free)


## 3 IDEA: primer plano del chaval; los ojos se le vuelven signos de dolar y piensa en
## el sobre = dinero.
func _scene_idea(w: Control) -> void:
	w.add_child(_rect(Vector2.ZERO, STAGE, Palette.GOLD_D))
	var shine := UIKit.art("fx_shine", Vector2(520, 420), 4.0, Color(1, 1, 1, 0.45))
	w.add_child(shine)
	shine.create_tween().set_loops().tween_property(shine, "rotation", TAU, 8.0).as_relative()
	var kid := _pix(KID, KID_COLORS, 28, Vector2(520, 480))
	w.add_child(kid)
	var tw := w.create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(func() -> void:
		Sound.play("sfx_sell")
		kid.setup(KID_GRIN, KID_COLORS, 28)
		UIKit.punch(kid, 1.08))
	tw.tween_interval(0.45)
	tw.tween_callback(_thought.bind(w, kid))


## El bocadillo de pensamiento: sobre = dinero.
func _thought(w: Control, kid: Pix) -> void:
	var dots := [Vector2(735, 420), Vector2(780, 385), Vector2(830, 350)]
	for i in dots.size():
		var d := _rect(dots[i] - Vector2(12, 12) * (i + 1), Vector2(24, 24) * (i + 1), Palette.CREAM)
		w.add_child(d)
	var bubble := Control.new()
	bubble.size = Vector2(520, 300)
	bubble.position = Vector2(860, 30)
	bubble.pivot_offset = Vector2(0, 300)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(_rect(Vector2(-8, -8), bubble.size + Vector2(16, 16), Palette.OUTLINE))
	bubble.add_child(_rect(Vector2.ZERO, bubble.size, Palette.CREAM))
	bubble.add_child(UIKit.image("pack_cards", Vector2(110, 150), Vector2(220, 220)))
	bubble.add_child(UIKit.label_at("=", Vector2(250, 150), Vector2(80, 80), 63, Palette.OUTLINE))
	bubble.add_child(UIKit.image("loot_ingot_psa10", Vector2(400, 120), Vector2(200, 200)))
	bubble.add_child(UIKit.image("currency_coins", Vector2(410, 220), Vector2(170, 170)))
	w.add_child(bubble)
	bubble.scale = Vector2(0.1, 0.1)
	bubble.create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var kt := kid.create_tween().set_loops()
	kt.tween_property(kid, "position:y", kid.position.y - 14, 0.18)
	kt.tween_property(kid, "position:y", kid.position.y, 0.18)


## 4 HUCHA: tres martillazos y la hucha revienta en monedas.
func _scene_piggy(w: Control) -> void:
	w.add_child(_rect(Vector2.ZERO, STAGE, Color8(52, 30, 46)))
	w.add_child(_rect(Vector2(0, 600), Vector2(STAGE.x, 210), Color8(80, 50, 40)))
	var piggy := UIKit.image("currency_piggy", Vector2(720, 450), Vector2(440, 440))
	w.add_child(piggy)
	var hammer := _pix(HAMMER, ICON_COLORS, 22, Vector2(1000, 260))
	hammer.pivot_offset = Vector2(5, 12) * 22
	hammer.rotation = -1.0
	w.add_child(hammer)
	var tw := w.create_tween()
	for i in 3:
		tw.tween_property(hammer, "rotation", -1.0, 0.18).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(hammer, "rotation", 0.35, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if i < 2:
			tw.tween_callback(func() -> void:
				Sound.play("sfx_open", -6.0, 0.5)
				piggy.scale = Vector2(1.12, 0.84)
				piggy.rotation = 0.06 * (i + 1))
			tw.tween_property(piggy, "scale", Vector2.ONE, 0.12)
	tw.tween_callback(_smash.bind(w, piggy))


func _smash(w: Control, piggy: Control) -> void:
	Sound.play("sfx_sell_all")
	piggy.visible = false
	var c := piggy.position + piggy.size * 0.5
	for i in 10:
		var shard := _rect(c - Vector2(16, 16), Vector2(32, 32), Color8(244, 150, 170))
		shard.pivot_offset = Vector2(16, 16)
		w.add_child(shard)
		var dir := Vector2.RIGHT.rotated(TAU * i / 10.0 + randf_range(-0.2, 0.2))
		var st := shard.create_tween().set_parallel()
		st.tween_property(shard, "position", shard.position + dir * randf_range(250, 420), 0.6) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(shard, "rotation", randf_range(-6, 6), 0.6)
		st.tween_property(shard, "modulate:a", 0.0, 0.6).set_delay(0.3)
	_coin_burst(w, c, 80)
	var flash := _rect(Vector2.ZERO, STAGE, Palette.GOLD_HI)
	w.add_child(flash)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.35)
	var pile := UIKit.image("currency_coins", c + Vector2(0, 80), Vector2(320, 320))
	pile.scale = Vector2(0.1, 0.1)
	w.add_child(pile)
	pile.create_tween().tween_property(pile, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 5 TIENDA: la trastienda; los sobres caen uno tras otro y hacen montana, y el
## chaval, con sus ojos de dolar, da saltos al lado.
func _scene_shop(w: Control) -> void:
	w.add_child(UIKit.image("bg_menu_backroom", STAGE * 0.5, STAGE, Color(0.8, 0.8, 0.85)))
	var kid := _pix(KID_GRIN, KID_COLORS, 16, Vector2(280, 600))
	w.add_child(kid)
	var kt := kid.create_tween().set_loops()
	kt.tween_property(kid, "position:y", kid.position.y - 30, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kt.tween_property(kid, "position:y", kid.position.y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var packs := [["pack_cards", Vector2(760, 660)], ["pack_vinyls", Vector2(960, 660)],
			["pack_sneakers", Vector2(1160, 660)], ["pack_electronics", Vector2(860, 500)],
			["pack_toys", Vector2(1060, 500)], ["pack_cards2", Vector2(960, 340)]]
	var tw := w.create_tween()
	for p in packs:
		tw.tween_interval(0.22)
		tw.tween_callback(_drop_pack.bind(w, str(p[0]), p[1]))


func _drop_pack(w: Control, art: String, at: Vector2) -> void:
	var pack := UIKit.image(art, at - Vector2(0, 700), Vector2(220, 220))
	w.add_child(pack)
	var tw := pack.create_tween()
	tw.tween_property(pack, "position:y", at.y - 110, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Sound.play("sfx_buy", -6.0)
		pack.scale = Vector2(1.2, 0.8))
	tw.tween_property(pack, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --------------------------------------------------------------------------- #
# Piezas
# --------------------------------------------------------------------------- #

func _rect(pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Un Pix ya colocado por su centro.
func _pix(rows: Array, colors: Dictionary, px: float, center: Vector2) -> Pix:
	var p := Pix.new().setup(rows, colors, px)
	p.position = center - p.size * 0.5
	return p


## Un movil (carcasa negra con borde) centrado en `center`. Devuelve su pantalla,
## que recorta lo que se le meta dentro.
func _phone(w: Control, center: Vector2, sz: Vector2) -> Control:
	var body := _rect(center - sz * 0.5, sz, Palette.OUTLINE)
	body.pivot_offset = sz * 0.5
	w.add_child(body)
	body.add_child(_rect(Vector2(6, 6), sz - Vector2(12, 12), Palette.NIGHT_LL))
	var m := Vector2(sz.x * 0.06, sz.y * 0.06)
	var screen := _rect(m, sz - m * 2.0, Color8(30, 40, 70))
	screen.clip_contents = true
	body.add_child(screen)
	return screen


## Lo que se ve en el movil de lejos: bloques de colores que suben (un feed).
func _feed(screen: Control) -> void:
	var cols := [Palette.TEAL_L, Color8(240, 56, 88), Palette.GOLD_XL, Color8(120, 150, 255)]
	var h := screen.size.y
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(strip)
	for i in 8:
		strip.add_child(_rect(Vector2(6, i * h * 0.5 + 6), Vector2(screen.size.x - 12, h * 0.5 - 12),
				cols[i % cols.size()]))
	var tw := strip.create_tween().set_loops()
	tw.tween_property(strip, "position:y", -h * 2.0, 1.2).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(strip, "position:y", 0.0, 0.0)


## Una explosion de monedas que salen hacia arriba y caen.
func _coin_burst(parent: Control, at: Vector2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = Sprites.tex("currency_coin")
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 1.6
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 350.0
	p.initial_velocity_max = 750.0
	p.gravity = Vector2(0, 1200)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.1
	parent.add_child(p)
	p.emitting = true
