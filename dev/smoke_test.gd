# smoke_test - prueba de integracion del bucle completo.
# Recorre el bucle entero sin tocar el raton: comprar, abrir, revelar, vender.
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")

## Interior de los paneles de overlay, medido sobre el sprite: ui_panel_shop.png
## y sus hermanos son de 1600x960 y se dibujan centrados (x 160..1760,
## y 60..1020), con un marco dorado de 48 px. Lo de dentro va de 224 a 1696 y
## de 140 a 940. Es la caja contra la que se comprueba que no se sale nada.
const PANEL := Rect2(224, 140, 1472, 800)
const PANTALLA := Rect2(0, 0, 1920, 1080)

var _main: MainRoot = null
var _game = null
var _fails: Array = []


func _ready() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  OK    ", what)
	else:
		print("  FALLA ", what)
		_fails.append(what)


## Que el indice de sprites este completo y bien.
##
## Los sprites viven en subcarpetas (Sprites/loot/, Sprites/ui/...) y el juego los
## pide por nombre corto, translatingido con Sprites/index.tsv. Si un sprite no
## esta en el indice se ve como un hueco en la pantalla sin ningun error, que es
## la forma mas mala de romperse. Este check recorre el arbol entero y avisa.
##
## El indice lo escribe tools/make_sprites.py. El recorrido de aqui es
## independiente a proposito: si los dos se equivocaran igual, compararlos no
## serviria de nada.
func _check_sprites() -> void:
	var en_disco: Array[String] = []
	_recorrer("res://Sprites", en_disco)
	_check("hay sprites que comprobar", en_disco.size() > 100)

	var faltan: Array[String] = []
	for rel in en_disco:
		if not rel.ends_with(".png"):
			continue
		if Sprites.path_of(rel.get_file().get_basename()) == "":
			faltan.append(rel)
	_check("todos los PNG estan en el indice", faltan.is_empty())
	for f in faltan:
		print("        sin indice: ", f)

	# Y al reves: que no haya entradas del indice que apunten a nada. Un indice
	# con rutas muertas hace que al borrar un sprite el juego se quede con la
	# entrada y avise en cada carga.
	var rotas: Array[String] = []
	for nombre in Sprites.index_names():
		var rel := Sprites.path_of(nombre)
		if rel == "" or not ResourceLoader.exists("res://Sprites/" + rel):
			rotas.append(nombre)
	_check("ninguna entrada del indice apunta a un fichero que falte",
			rotas.is_empty())
	for r in rotas:
		print("        entrada rota: ", r)

	# Y que CARGUEN. Es la fuga que se cuela entre las dos de arriba: el PNG y la
	# entrada del indice pueden estar bien y el sprite seguir saliendo como un
	# hueco vacio, porque el .import apunta a un .ctex que no esta en
	# .godot/imported/. Pasa al copiar el proyecto sin la cache de importacion
	# (que es lo que hace el rsync de aqui a ~/proyecto-godot), y no revienta
	# nada: sale un Control sin textura, sin un solo error de GDScript. Es el
	# hermano del check de los sonidos, que ya hacia esto mismo.
	var sin_cargar: Array[String] = []
	for nombre_png in Sprites.index_names():
		var ruta := Sprites.path_of(nombre_png)
		# Solo las texturas: el indice tambien lleva la fuente, y la hoja del
		# .fnt va con importer="skip" (no es una textura del juego).
		if not ruta.ends_with(".png") or not _lo_importa_godot("res://Sprites/" + ruta):
			continue
		if Sprites.tex(nombre_png) == null:
			sin_cargar.append(nombre_png)
	_check("todos los PNG del indice cargan", sin_cargar.is_empty())
	for s in sin_cargar:
		print("        no carga: ", s)


## ¿Godot importa este fichero?
##
## No todos los PNG del indice son texturas del juego: la hoja de la fuente
## (font_pack.png) lleva importer="skip", porque es la fuente del .fnt y no una
## imagen que el juego dibuje. Se le pregunta al propio .import en vez de llevar
## una lista de excepciones, que se queda vieja en cuanto entra otro caso.
func _lo_importa_godot(full: String) -> bool:
	var f := FileAccess.open(full + ".import", FileAccess.READ)
	if f == null:
		return true
	var txt := f.get_as_text()
	f.close()
	return not txt.contains("importer=\"skip\"")


## Que no falte ningun sonido, que carguen y que los volumenes lleguen al bus.
##
## Igual que con los sprites, un sonido que no esta en el indice no suena y no
## da ningun error, asi que no habria forma de enterarse jugando. Aqui se
## recorre la carpeta entera y se compara con Sounds/index.tsv.
func _check_sounds() -> void:
	var en_disco: Array[String] = []
	_recorrer("res://Sounds", en_disco)
	var wavs: Array[String] = []
	for rel in en_disco:
		if rel.ends_with(".wav"):
			wavs.append(rel)
	_check("hay sonidos que comprobar", wavs.size() >= 5)

	var sin_indice: Array[String] = []
	for rel in wavs:
		if not Sound.exists(rel.get_file().get_basename()):
			sin_indice.append(rel)
	_check("todos los WAV estan en el indice", sin_indice.is_empty())
	for f in sin_indice:
		print("        sin indice: ", f)

	var rotos: Array[String] = []
	for nombre in Sound.index_names():
		if not ResourceLoader.exists(Sound.path_of(nombre)) or Sound.stream(nombre) == null:
			rotos.append(nombre)
	_check("todos los sonidos del indice cargan", rotos.is_empty())
	for r in rotos:
		print("        entrada rota: ", r)

	# Los dos buses que crea el autoload. Sin ellos, los deslizadores de los
	# ajustes no tienen donde aplicar el volumen y se quedan en nada.
	for bus in [Sound.BUS_MUSIC, Sound.BUS_SFX]:
		_check("existe el bus %s" % bus, AudioServer.get_bus_index(bus) >= 0)

	# El bucle de la musica. El importador deja los WAV sin bucle a proposito
	# (si no, los efectos se repetirian solos), asi que si no se montara aqui la
	# musica sonaria una vez y se callaria para el resto de la partida.
	var musica := Sound.stream("music_backroom") as AudioStreamWAV
	_check("la musica esta en el indice", musica != null)
	if musica != null:
		_check("el bucle de la musica tiene fin", Sound.loop_end_frames(musica) > 1000)

	# Que el volumen de los ajustes llegue de verdad al bus, que es lo que unia
	# los dos deslizadores con el audio.
	var guardado := Game.sfx_volume
	Game.set_sfx_volume(0.0)
	_check("con el sonido a 0 el bus se silencia",
			AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.BUS_SFX)))
	Game.set_sfx_volume(guardado)
	_check("y al subirlo se vuelve a oir",
			not AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.BUS_SFX)))

	# Y que un efecto llegue de verdad a un reproductor: que el fichero se cargue
	# no sirve de nada si el pool no lo toca.
	Sound.play("sfx_click")
	var sonando := 0
	for p in Sound._players:
		if p.playing:
			sonando += 1
	_check("un efecto llega a un reproductor", sonando > 0)


## Lista un directorio y sus subdirectorios, recursivamente.
##
## Abre un DirAccess NUEVO en cada nivel a proposito: si se reutiliza el mismo
## para bajar y luego seguir iterando, el estado de la lista se pisa y esto se
## queda sin ramas (o entra en recursion infinita).
func _recorrer(ruta: String, salida: Array[String]) -> void:
	var dir := DirAccess.open(ruta)
	if dir == null:
		return
	# Primero el listado entero, y luego se procesa: es lo que permite
	# reutilizar el resultado sin depender del estado de dir.
	var nombres: Array[String] = []
	var carpetas: Array[String] = []
	dir.list_dir_begin()
	var nombre := dir.get_next()
	while nombre != "":
		if dir.current_is_dir():
			if not nombre.begins_with("."):
				carpetas.append(nombre)
		else:
			nombres.append(nombre)
		nombre = dir.get_next()
	dir.list_dir_end()
	for n in nombres:
		salida.append(ruta + "/" + n)
	for c in carpetas:
		_recorrer(ruta + "/" + c, salida)
##
## No es cosmetico: si la fuente deja de estar, el texto vuelve a la de Godot y
## se ve como estaba antes (fuave, en medio de la pantalla de pixeles). Y si
## text_width() deja de coincidir con lo que mide de verdad, los rotulos se
## cortan otra vez, que es justo el bug que se arreglo al pasarla.
func _check_fonts() -> void:
	var f: Font = UIKit.font()
	_check("la fuente del juego esta cargada", f != null)
	if f == null:
		return
	_check_sprites()
	_check("la fuente es la del proyecto, no la de Godot",
			f.get_font_name() == "PackTycoon")
	# El avance por caracter tiene que ser el tamano exacto, o el texto sale
	# estirado. Se mide con dos letras de mas, para no contar el redondeo del
	# ancho de la primera.
	var uno: float = f.get_string_size("H", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var dos: float = f.get_string_size("HH", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	_check("el avance por caracter es el tamano exacto",
			absf((dos - uno) - 28.0) < 0.01)
	_check("text_width coincide con la fuente",
			absf(UIKit.text_width("SOBRES", 28)
				- f.get_string_size("SOBRES", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x) < 0.01)
	# Ningun rotulo largo del juego puede salirse de su caja.
	for caso in [["ELECTRONICA", 224.0], ["ZAPATILLAS", 224.0],
			["AURICULARES", 340.0], ["CARTA EDICION LIMITADA", 620.0],
			["PANTALLA COMPLETA", 560.0], ["NOTA PSA", 700.0],
			["ESPACIO O CLIC PARA DEJARLO", 620.0],
			["PRIMERA VERSION - SIN LOGROS TODAVIA", 900.0]]:
		var texto: String = caso[0]
		var caja: float = caso[1]
		var encogido: int = UIKit.fit_size(texto, caja, 42)
		_check("\"%s\" cabe en su caja" % texto,
				UIKit.text_width(texto, encogido) <= caja + 1.0)

	# Lo mismo, pero sobre los DATOS: el nombre de cada objeto de cada paquete
	# tiene que caber en la caja de la tarjeta de revelado (620 px). Con una
	# lista escrita a mano esto se rompe en cuanto se anade un objeto y nadie
	# se entera hasta que se juega; leyendo loot_db no puede pasar.
	for pack in LootDB.PACKS:
		for item in pack["loot"]:
			var nombre: String = str(item["name"])
			var t: int = UIKit.fit_size(nombre, 620.0, 42)
			_check("el nombre \"%s\" (%s) cabe en la tarjeta" % [nombre, pack["name"]],
					UIKit.text_width(nombre, t) <= 620.0 + 1.0)


func _screen() -> Node:
	for c in _main._screen_host.get_children():
		if c.get_script() != null and c.has_method("_spawn_pack"):
			_game = c
	return _game


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --------------------------------------------------------------------------- #
# Que no se salga nada del marco
# --------------------------------------------------------------------------- #
## El rectangulo que ocupa la TINTA de un nodo, no su caja.
##
## Hace falta separar las dos cosas porque label_at() agranda la caja para que
## un texto largo no se corte, y los velos y las chapas son de 1920x1080: si se
## compararan cajas, saltarian casi todos los rotulos. Con la fuente de mapa de
## bits el ancho de un texto es exactamente tamano x caracteres, asi que la
## tinta se calcula sin adivinar nada.
func _tinta(n: Control, solo_glifo: bool = false) -> Rect2:
	var p := n as PixelNumber
	if p != null:
		# PixelNumber ya mide la tinta (ver pixel_number.gd).
		return p.get_global_rect()
	var l := n as Label
	if l == null:
		return Rect2()
	var fs: int = l.get_theme_font_size("font_size")
	var w := UIKit.text_width(l.text, fs)
	var linea := UIKit.text_height(fs)
	# La altura que da la fuente es la de la LINEA, con su interlineado: a tamano
	# 40 mide 66 px y el glifo ocupa 38. Para saber si un texto se sale de un
	# panel vale la linea (es lo que Godot recorta), pero para saber si se mete
	# debajo de una chapa hay que medir el glifo, que va centrado en la linea.
	var h: float = minf(linea, float(UIKit.font_step(fs))) if solo_glifo else linea
	var g := l.get_global_rect()
	var dx := 0.0
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		dx = (g.size.x - w) * 0.5
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		dx = g.size.x - w
	return Rect2(g.position + Vector2(dx, (g.size.y - linea) * 0.5 + (linea - h) * 0.5),
			Vector2(w, h))


func _texto_de(n: Control) -> String:
	var l := n as Label
	if l != null:
		return l.text
	var p := n as PixelNumber
	return p.get_text() if p != null else ""


## Las etiquetas y los numeros que se salen de `dentro`, con sus medidas.
func _fuera(de: Node, dentro: Rect2) -> Array:
	var malas: Array = []
	var pila: Array = [de]
	var caja := dentro.grow(1.0)
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var c := n as Control
		if c != null and (c is Label or c is PixelNumber) and c.visible:
			var r := _tinta(c)
			if r.size.x > 0.0 and not caja.encloses(r):
				malas.append("%s \"%s\" en (%.0f, %.0f) %.0fx%.0f" % [
					"numero" if c is PixelNumber else "rotulo", _texto_de(c),
					r.position.x, r.position.y, r.size.x, r.size.y])
		pila.append_array(n.get_children())
	return malas


## Check de que una pantalla no saca texto de donde puede. Cada fuga imprime su
## medida, que es lo que hace falta para saber que mover sin medir a ojo.
func _check_cabe(what: String, de: Node, dentro: Rect2) -> void:
	if de == null:
		return
	var malas := _fuera(de, dentro)
	_check(what, malas.is_empty())
	for m in malas:
		print("         fuera: ", m)


## Que ningun texto caiga encima de una chapa.
##
## Es la fuga que _check_cabe() no ve: el rotulo no se sale de la pantalla, se
## mete debajo de otro control. Pasaron dos (el rotulo del inventario sobre la
## chapa de VENDER TODO, y la moneda del menu sobre la de AJUSTES) y en las dos
## el sintoma era el mismo, texto partido por el marco de una chapa.
##
## Solo cuentan las chapas DIBUJADAS, no las zonas de pulsacion: hit_area() crea
## un Boton sin sprite que se lleva medio panel, y ahi los precios de la tienda
## estan dentro a proposito. Se salta la chapa a la que el rotulo pertenece (el
## texto de dentro de un boton si tiene que estar ahi) y la que este dentro del
## rotulo, que no puede pasar.
func _check_sin_encimarse(what: String, de: Node) -> void:
	if de == null:
		return
	var textos: Array = []
	var chapas: Array = []
	var pila: Array = [de]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var c := n as Control
		if c != null and c.visible:
			if c is Label or c is PixelNumber:
				var r := _tinta(c, true)
				if r.size.x > 0.0:
					textos.append([c, r])
			elif c is BaseButton and _es_chapa(c):
				chapas.append([c, _marco_de_chapa(c)])
		pila.append_array(n.get_children())
	var malas: Array = []
	for t in textos:
		var n: Control = t[0]
		var r: Rect2 = t[1]
		for c in chapas:
			var chapa: Control = c[0]
			if _uno_dentro_de(n, chapa) or _uno_dentro_de(chapa, n):
				continue
			var b: Rect2 = c[1]
			if not r.intersects(b):
				continue
			var solapa := r.intersection(b)
			malas.append("\"%s\" en (%.0f, %.0f) %.0fx%.0f encima de una chapa en (%.0f, %.0f) %.0fx%.0f (tapan %.0fx%.0f)" % [
				_texto_de(n), r.position.x, r.position.y, r.size.x, r.size.y,
				b.position.x, b.position.y, b.size.x, b.size.y,
				solapa.size.x, solapa.size.y])
	_check(what, malas.is_empty())
	for m in malas:
		print("         encimado: ", m)


## El rectangulo DIBUJADO de una chapa, no su caja.
##
## La caja del TextureRect incluye el margen transparente del sprite (16 px en las
## chapas del menu, 48 en los paneles) y comparar la tinta contra la caja daba
## por bueno un texto que en realidad no se toca de nada. Con el alfa del sprite
## se sabe donde empieza el marco de verdad, sin inventar margenes a ojo.
func _marco_de_chapa(b: BaseButton) -> Rect2:
	var fuera := Rect2()
	for h in b.get_children():
		var t := h as TextureRect
		if t == null or t.texture == null:
			continue
		var r := t.get_global_rect()
		var img := t.texture.get_image()
		if img == null:
			continue
		if img.is_compressed() and img.decompress() != OK:
			continue
		var caja: Rect2i = img.get_used_rect()
		if caja == null:
			continue
		var esc := Vector2(r.size.x / float(img.get_width()),
				r.size.y / float(img.get_height()))
		var dibujado := Rect2(r.position + Vector2(caja.position) * esc,
				Vector2(caja.size) * esc)
		if fuera.size == Vector2.ZERO:
			fuera = dibujado
		else:
			fuera = fuera.merge(dibujado)
	return fuera if fuera.size != Vector2.ZERO else b.get_global_rect()


## Un boton con chapa dibujada detras: plate_button(), small_button() e
## icon_button() anaden su TextureRect. hit_area() no anade ninguna y por eso
## queda fuera: es una zona invisible sobre la que se puede pulsar.
func _es_chapa(c: Control) -> bool:
	for h in c.get_children():
		var t := h as TextureRect
		if t != null and t.texture != null:
			return true
	return false


## Si `n` esta dentro de `de`, directamente o por el arbol de padres.
func _uno_dentro_de(n: Node, de: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p == de:
			return true
		p = p.get_parent()
	return false


## Que un numero quepa dentro del nodo que lo envuelve (la chapita del precio).
##
## Es el caso que mas se escapa: el numero se encoge con max_width, pero si
## alguien sube el numero de digitos sin subir el ancho, lo que se sale es la
## cifra y no se ve hasta que ya es muy tarde.
func _check_dentro_de(what: String, hijo: Control, padre: Control) -> void:
	if hijo == null or padre == null:
		_check(what, false)
		return
	var a := padre.get_global_rect()
	var b := hijo.get_global_rect()
	var ok := a.encloses(b)
	_check(what, ok)
	if not ok:
		print("         numero en ", str(b), " y la chapa es ", str(a))


## Un boton del arbol, buscado por el texto que lleva dentro.
##
## Las chapas de UIKit son un Button pelado con un Label dentro (el texto va en un
## hijo, no en button.text), asi que para pulsar GUARDAR o VENDER desde una prueba
## hay que buscar: primero el rotulo, y de ahi para arriba hasta el boton.
func _boton_de(de: Node, texto: String) -> BaseButton:
	var pila: Array = [de]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var l := n as Label
		if l != null and l.text == texto:
			var p := l.get_parent()
			while p != null:
				var b := p as BaseButton
				if b != null:
					return b
				p = p.get_parent()
		pila.append_array(n.get_children())
	return null


func _run() -> void:
	Game.hard_reset()
	await get_tree().process_frame
	_main = MAIN_SCENE.instantiate() as MainRoot
	add_child(_main)
	await get_tree().process_frame
	_check("la escena principal existe", _main != null)
	_check("el menu se monta", _main._screen_host.get_child_count() == 1)
	var menu := _main._screen_host.get_child(0)
	_check_cabe("el menu no saca texto de la pantalla", menu, PANTALLA)
	_check_sin_encimarse("el menu no pone texto encima de una chapa", menu)

	# --- ajustes ---
	menu._on_settings()
	await get_tree().process_frame
	await _wait(0.2)
	var ajustes = _main._veil_host.get_child(0) if _main._veil_host.get_child_count() > 0 else null
	_check("los ajustes se abren", ajustes != null)
	_check_cabe("los ajustes no sacan texto del panel", ajustes, PANEL)
	_check_sin_encimarse("los ajustes no ponen texto encima de una chapa", ajustes)
	# La casilla de venta automatica: el interruptor tiene que encender y apagar
	# el ajuste de verdad, y repintarse, que es lo unico que se ve.
	_check("los ajustes traen la casilla de venta automatica",
		ajustes != null and ajustes._sell_box != null and ajustes._screen_box != null)
	if ajustes != null and ajustes._sell_box != null:
		Game.set_auto_sell(false)
		ajustes._toggle_auto_sell()
		_check("la casilla enciende la venta automatica", Game.auto_sell)
		_check("y cambia el dibujo de la casilla",
			ajustes._sell_box.texture == Sprites.tex("ui_checkbox_on"))
		ajustes._toggle_auto_sell()
		_check("la casilla la vuelve a apagar", not Game.auto_sell)
		_check("y vuelve el dibujo de apagada",
			ajustes._sell_box.texture == Sprites.tex("ui_checkbox_off"))
		_check("las dos casillas estan separadas para no pisarse los clics",
			absf(ajustes._sell_box.position.y - ajustes._screen_box.position.y) >= 96.0)
	for c in _main._veil_host.get_children():
		_main.pop_veil(c)
	await get_tree().process_frame
	await _wait(0.2)

	_main.show_game()
	await get_tree().process_frame
	await _wait(0.2)
	var g = _screen()
	_check("la pantalla de juego se monta", g != null)
	_check("la partida empieza con dinero", Game.money > 0)
	_check_cabe("la pantalla de juego no saca texto de la pantalla", g, PANTALLA)
	_check_sin_encimarse("la mesa no pone texto encima de una chapa", g)
	var start_money: int = Game.money

	# --- tienda ---
	g._open_shop()
	await get_tree().process_frame
	var shop = g._shop
	_check("la tienda se abre", shop != null)
	_check("hay 5 celdas de paquete", shop._pack_cells.size() == LootDB.pack_count())
	_check("hay 4 herramientas", shop._tool_cells.size() == LootDB.tool_count())
	# El multiplicador de velocidad se creo con label_at() y se le olvido el
	# add_child: la etiqueta se quedaba sin padre y no se veia nunca, sin ningun
	# error. Este check mira lo mismo para que no vuelva a colarse.
	_check("el multiplicador de la tienda esta en pantalla",
		shop._speed != null and shop._speed.is_visible_in_tree()
		and shop._speed.text != "")
	_check_cabe("la tienda no saca texto del panel", shop, PANEL)
	_check_sin_encimarse("la tienda no pone texto encima de una chapa", shop)

	shop._on_pack("cards")
	await get_tree().process_frame
	await _wait(0.9)
	_check("comprar descuenta el precio", Game.money == start_money - 150)
	_check("el paquete cae en la mesa", g.table_count() == 1)
	_check("el paquete espera en la mesa", g._elements[0].is_waiting_pack())

	# --- apertura ---
	# El contador se lee ANTES de abrir: "encontrado" sube cuando el objeto sale
	# de la caja, no cuando se guarda ni cuando se vende.
	var found_before: int = Game.items_found
	var el: TableElement = g._elements[0]
	_check("el paquete se puede abrir", el.start_opening())
	await _wait(0.5)
	# El aro de espera tapaba el paquete. No es cuestion de darle el tamano justo:
	# ui_timer_track es un disco con un agujero centrado en el mismo sitio que el
	# dibujo del paquete, asi que puesto por delante su banda lo cruza de lado a
	# lado mida lo que mida. El arreglo es el ORDEN, y es lo que se comprueba.
	_check("el anillo de espera se dibuja detras del paquete",
		el._ring.get_index() < el._art.get_index())
	_check("el anillo es mas ancho que el dibujo del paquete",
		el._ring.size.x > TableElement.ART_SIZE.x)
	_check("el anillo avanza", el._ring.progress > 0.05)
	_check("sigue abriendose", el.is_opening())

	# --- las herramientas acortan la espera ---
	var t_cards := LootDB.open_time("cards", [0, 0, 0, 0])
	var t_fast := LootDB.open_time("cards", [3, 0, 0, 0])
	_check("las herramientas acortan la espera", t_fast < t_cards)
	_check("el precio de la herramienta sube con el nivel",
			LootDB.tool_cost(0, 1) > LootDB.tool_cost(0, 0))
	_check("la herramienta tope no tiene precio", LootDB.tool_cost(0, 99) < 0)

	# --- revelado ---
	await _wait(2.4)
	_check("sale la tarjeta de revelado", g._reveal != null)
	if g._reveal != null:
		var card = g._reveal
		_check_cabe("la tarjeta no saca texto del panel", card, PANEL)
		_check_sin_encimarse("la tarjeta no pone texto encima de una chapa", card)
		_check("el objeto tiene nombre", str(card.item.get("name", "")) != "")
		_check("el objeto tiene valor", int(card.item.get("value", 0)) > 0)
		var grade := int(card.item.get("grade", 0))
		_check("la nota PSA esta entre 1 y 10", grade >= 1 and grade <= LootDB.GRADE_MAX)
		_check("tiene estado de conservacion", card.item.has("condition"))
		# El sprite tiene que ser el de ESA nota: es la razon de existir de las
		# diez variantes. YA NO HAY EXCEPCION: los seis objetos fisicos y las
		# cuatro cartas se desgastan todos.
		var item = LootDB.roll_item(RandomNumberGenerator.new(), "electronics")
		var nota := LootDB.roll_grade(RandomNumberGenerator.new())
		_check("el sprite lleva la nota",
				LootDB.art_for(item, nota) == "%s_psa%d" % [item["art"], nota])
		_check("nota 10 y nota 1 valen distinto",
				LootDB.final_value(item, 10) > LootDB.final_value(item, 1))
		_check("el estado sale de la nota",
				LootDB.condition_for_grade(10)["id"] == "mint"
				and LootDB.condition_for_grade(2)["id"] == "broken")
		# Las cuatro cartas tienen que ser CUATRO DIBUJOS, no uno teñido por
		# rareza. Si alguien vuelve a poner la misma base, sale aqui.
		var artes := {}
		for carta in LootDB.pack_by_id("cards")["loot"]:
			_check("la carta se desgasta", bool(carta["graded"]))
			artes[str(carta["art"])] = true
		_check("las cuatro cartas son dibujos distintos", artes.size() == 4)
		# El objeto ya esta sobre la mesa cuando sale la tarjeta, y NO se ha
		# guardado solo: ese era el fallo de tenerlo a la vez en la mesa y en el
		# inventario. Ahora lo decide el jugador, con GUARDAR o con VENDER.
		_check("el botin ya esta en la mesa con la tarjeta abierta",
			g.table_count() == 1)
		_check("el botin no se guarda solo", Game.inventory.is_empty())
		_check("encontrar un objeto se apunta", Game.items_found == found_before + 1)
		var boton_guardar := _boton_de(card, "GUARDAR")
		var boton_vender := _boton_de(card, "VENDER")
		_check("la tarjeta trae el boton GUARDAR", boton_guardar != null)
		_check("la tarjeta trae el boton VENDER", boton_vender != null)
		if boton_guardar != null and boton_vender != null:
			var marco_g := _marco_de_chapa(boton_guardar)
			var marco_v := _marco_de_chapa(boton_vender)
			_check("los dos botones caben dentro del panel",
				PANEL.encloses(marco_g) and PANEL.encloses(marco_v))
			_check("los dos botones no se pisan", not marco_g.intersects(marco_v))
		# GUARDAR: el objeto pasa al inventario y DEJA la mesa.
		if boton_guardar != null:
			boton_guardar.pressed.emit()
		await get_tree().process_frame
	await _wait(0.8)
	_check_fonts()
	_check_sounds()
	_check("al elegir se cierra la tarjeta", g._reveal == null)
	_check("guardar mete el objeto en el inventario", Game.inventory.size() == 1)
	_check("guardar lo quita de la mesa", g.table_count() == 0)

	# --- vender desde el inventario ---
	var money_inv: int = Game.money
	g._sell_inventory_slot(0)
	await _wait(0.3)
	_check("lo guardado se puede vender", Game.inventory.is_empty())
	_check("vender del inventario suma el valor", Game.money > money_inv)

	# --- el otro boton: vender desde la tarjeta ---
	var el_sell: TableElement = g._spawn_pack("cards")
	_check("el segundo paquete se puede abrir", el_sell.start_opening())
	await _wait(2.2)
	_check("el objeto esta en la mesa antes de venderlo", g.table_count() == 1)
	var money_card: int = Game.money
	var vender: BaseButton = null
	if g._reveal != null:
		vender = _boton_de(g._reveal, "VENDER")
	_check("la tarjeta se abre otra vez", g._reveal != null and vender != null)
	if vender != null:
		vender.pressed.emit()
	await _wait(0.8)
	_check("vender desde la tarjeta paga", Game.money > money_card)
	_check("vender desde la tarjeta vacia la mesa", g.table_count() == 0)
	_check("vender desde la tarjeta no guarda nada", Game.inventory.is_empty())

	# --- cerrar sin elegir: el objeto se queda en la mesa ---
	var suelto: Dictionary = LootDB.roll_pack(RandomNumberGenerator.new(), "vinyls")
	var el_free: TableElement = g._spawn_loot(suelto)
	g._on_reveal_resolved(RevealCard.ACTION_LATER, suelto, el_free)
	await get_tree().process_frame
	_check("cerrar sin elegir deja el objeto en la mesa", g.table_count() == 1)
	_check("cerrar sin elegir no lo guarda", Game.inventory.is_empty())

	# --- arrastrar por la mesa ---
	# El objeto cae con un rebote, asi que primero se le deja aterrizar: mientras
	# cae lo mueve el tween de la caida, no el raton.
	await _wait(0.9)
	_check("el objeto tiene la mesa por limites", el_free.bounds == g.TABLE_RECT)
	el_free._move_to(Vector2(-9999, -9999))
	_check("no se puede sacar por arriba ni por la izquierda",
		el_free.position == g.TABLE_RECT.position)
	el_free._move_to(Vector2(9999, 9999))
	_check("no se puede sacar por abajo ni por la derecha",
		el_free.position == g.TABLE_RECT.end - el_free.size)
	# Y soltar tras arrastrar NO vende: para el boton eso fue moverlo, no un clic.
	el_free._travelled = TableElement.DRAG_SLOP + 10.0
	el_free._on_pressed()
	await get_tree().process_frame
	_check("soltar tras arrastrar no vende el botin", g.table_count() == 1)
	el_free._travelled = 0.0
	g._sell_all_table()
	await _wait(0.5)
	_check("vender todo recoge lo que quedaba", g.table_count() == 0)

	# --- venta automatica ---
	# Se llama al manejador de "paquete abierto" en vez de esperar los segundos de
	# la apertura: lo que se comprueba aqui es la rama de la autoventa, y esa no
	# depende del reloj.
	Game.set_auto_sell(true)
	var found_auto: int = Game.items_found
	var el_auto: TableElement = g._spawn_pack("cards")
	var money_auto: int = Game.money
	g._on_element_opened("cards", el_auto)
	await get_tree().process_frame
	_check("con autoventa no sale la tarjeta", g._reveal == null)
	_check("con autoventa el objeto no llega a la mesa", g.table_count() == 0)
	_check("con autoventa el objeto no va al inventario", Game.inventory.is_empty())
	_check("con autoventa el dinero entra solo", Game.money > money_auto)
	_check("con autoventa el objeto cuenta como encontrado",
		Game.items_found == found_auto + 1)
	Game.set_auto_sell(false)

	# --- topping de la mesa ---
	Game.money = 100000000
	while g.table_count() < 8:
		g._spawn_pack("cards")
	_check("la mesa se llena hasta 8", g.table_count() == 8)
	var before_refund: int = Game.money
	g._on_pack_chosen("cards")
	_check("con la mesa llena no entra nada mas", g.table_count() == 8)
	_check("con la mesa llena se devuelve el dinero",
			Game.money == before_refund + int(LootDB.pack_by_id("cards")["price"]))

	# --- automatizaciones ---
	var opened_before: int = Game.packs_opened
	Game.set_auto_buy(true)
	Game.set_auto_open(true)
	await _wait(3.0)
	_check("la automatizacion abre paquetes sola", Game.packs_opened > opened_before)
	Game.set_auto_buy(false)
	Game.set_auto_open(false)
	# Y una pasada mas con calma: puede quedar un paquete a medio abrir que saque
	# su tarjeta justo despues de apagar la automatizacion.
	await _wait(1.6)
	while g._reveal != null:
		g._reveal._dismiss()
		await get_tree().process_frame
		await _wait(0.3)
	g._sell_all_table()
	await _wait(0.5)
	_check("vender todo vacia la mesa", g.table_count() == 0)

	# --- tienda con dinero de sobra: compra y herramientas ---
	Game.money = 100000000
	g._open_shop()
	await get_tree().process_frame
	var shop2 = g._shop
	shop2._on_tool(0)
	_check("comprar herramienta sube el nivel", Game.tool_level(0) == 1)
	_check("la velocidad sube", Game.speed_multiplier() > 1.0)
	shop2._on_pack("electronics")
	await _wait(1.0)
	_check("se puede comprar un paquete caro", g.table_count() == 1)
	shop2._close()
	await get_tree().process_frame
	_check("la tienda se cierra", g._shop == null)

	# --- numeros extremos ---
	# Todo lo anterior se mide con la partida recien empezada: dinero de tres
	# cifras y herramientas de nivel 1. El sitio donde algo se desborda de verdad
	# es aqui, con nueve digitos y las chapitas de "MAX".
	Game.money = 99999999
	g._open_shop()
	await get_tree().process_frame
	var shop3 = g._shop
	for i in LootDB.tool_count():
		for _nivel in LootDB.TOOL_MAX_LEVEL:
			shop3._on_tool(i)
	shop3.refresh()
	await get_tree().process_frame
	for i in shop3._tool_cells.size():
		_check("la herramienta %d llega al tope" % (i + 1),
				Game.tool_level(i) == LootDB.TOOL_MAX_LEVEL)
		_check_dentro_de("el precio de la herramienta %d cabe en la chapa" % (i + 1),
				shop3._tool_cells[i]["cost"], shop3._tool_cells[i]["tag_node"])
	for i in shop3._pack_cells.size():
		_check_dentro_de("el precio del sobre %d cabe en la chapa" % (i + 1),
				shop3._pack_cells[i]["price"], shop3._pack_cells[i]["tag_node"])
	_check_cabe("la tienda con 99.999.999 no saca texto del panel", shop3, PANEL)
	_check_sin_encimarse("la tienda llena no pone texto encima de una chapa", shop3)
	# El contador de arriba es lo primero que se llena: son nueve digitos y el
	# rotulo de la mesa esta justo a la derecha.
	_check("el dinero no pisa el rotulo de la mesa",
			g._money.get_global_rect().end.x
			< g._table_label.get_global_rect().position.x - 8.0)
	shop3._close()
	await get_tree().process_frame

	# --- guardado ---
	Game.save_game()
	_check("el fichero de guardado existe", FileAccess.file_exists(Game.SAVE_PATH))

	print("")
	if _fails.is_empty():
		print("HUMO: todo correcto.")
	else:
		print("HUMO: %d fallos -> %s" % [_fails.size(), str(_fails)])
	# Al parar una voz, quien suelta su WAV es el hilo de audio. Si se sale en el
	# mismo frame, el motor avisa de recursos sin soltar al salir. Ver
	# Sound.stop_all(). El juego de verdad lo hace en Game._on_close().
	Sound.stop_all()
	# Tiempo REAL, no frames: en headless un frame dura casi nada y el hilo de
	# audio mezcla por su cuenta, asi que tres frames no le dan ni una vuelta.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if _fails.is_empty() else 1)
