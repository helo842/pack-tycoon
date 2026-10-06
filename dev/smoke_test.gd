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
	# Solo los escalones 1 llevan tabla propia: los otros dos apuntan a la de su
	# tipo, asi que recorrerlos todos seria comprobar tres veces lo mismo.
	for pack in LootDB.PACKS:
		if not pack.has("loot"):
			continue
		for item in LootDB.loot_table(str(pack["id"])):
			var nombre: String = str(item["name"])
			var t: int = UIKit.fit_size(nombre, 620.0, 42)
			_check("el nombre \"%s\" (%s) cabe en la tarjeta" % [nombre, pack["name"]],
					UIKit.text_width(nombre, t) <= 620.0 + 1.0)


## Deja la mesa vacia DE VERDAD. No basta con vaciar la lista: los elementos son
## hijos del nodo de la mesa, y los que siguen vivos reciben los Pinchos y
## cuentan para el siguiente trozo de la prueba.
func _empty_table(g: Node) -> void:
	for el in (g._elements as Array).duplicate():
		g._drop_element(el)
		el.queue_free()
	await get_tree().process_frame


func _screen() -> Node:
	for c in _main._screen_host.get_children():
		if c.get_script() != null and c.has_method("_spawn_pack"):
			_game = c
	return _game


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Cuantos paquetes de la mesa estan cargando AHORA MISMO.
func _cuantos_abriendo(g: Node) -> int:
	var n := 0
	for puesto in g._elements:
		if is_instance_valid(puesto) and (puesto as TableElement).is_opening():
			n += 1
	return n


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


## ¿Algun nodo del arbol dibuja este sprite? Sirve tanto para comprobar que algo
## esta puesto (la moneda del contador) como que algo quitado no ha vuelto.
func _usa_sprite(de: Node, nombre: String) -> bool:
	var quiero := Sprites.tex(nombre)
	var pila: Array = [de]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var t := n as TextureRect
		if t != null and t.texture == quiero:
			return true
		pila.append_array(n.get_children())
	return false


## ¿Este sprite se dibuja mas grande que `lado` en algun sitio del arbol?
##
## Es el check de la moneda gigante de los ajustes: los iconos se dibujaban con
## art(), que escala sobre el lienzo DEL SPRITE, y no todos miden lo mismo (los
## ui_icon_* son de 256, la moneda de 512), asi que uno salia al doble y tapaba
## media pantalla.
func _sprite_gigante(de: Node, nombre: String, lado: float) -> bool:
	var quiero := Sprites.tex(nombre)
	var pila: Array = [de]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var t := n as TextureRect
		if t != null and t.texture == quiero and t.size.x > lado:
			return true
		pila.append_array(n.get_children())
	return false


## ¿Algun rotulo del arbol dice esto? Con `empieza` en true vale con que EMPIECE
## por el texto, que es lo que hace falta para "DANO 12" sin saber el numero.
func _dice(de: Node, texto: String, empieza: bool = false) -> bool:
	var pila: Array = [de]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var l := n as Label
		if l != null and (l.text.begins_with(texto) if empieza else l.text == texto):
			return true
		pila.append_array(n.get_children())
	return false


## La tinta que de verdad se VE de un nodo: la de _tinta(), recortada por lo que
## la recorta. Hace falta desde que la columna de sobres tiene scroll: la lista
## mide 1632 px dentro de una ventana de 752, asi que hay rotulos y precios que
## existen en el arbol y no se ven. Sin recortarlos, los dos checks de "cabe en
## la pantalla" y "no pisa una chapa" saltaban con las filas que estan por
## debajo del scroll, que es justo donde no se ven.
func _visible(n: Control, solo_glifo: bool = false) -> Rect2:
	var r := _tinta(n, solo_glifo)
	var p := n.get_parent()
	while p != null:
		var c := p as Control
		if c != null and (c is ScrollContainer or c.clip_contents):
			r = r.intersection(c.get_global_rect())
		p = p.get_parent()
	return r


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
			var r := _visible(c)
			if r.size.x > 0.0 and r.size.y > 0.0 and not caja.encloses(r):
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
				var r := _visible(c, true)
				if r.size.x > 0.0 and r.size.y > 0.0:
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


## Hasta que nivel se compra cada item en el bloque de numeros extremos: todos
## al tope menos el ultimo, que se queda uno por debajo para que su chapa siga
## enseñando el precio mas largo de la tienda.
func _nivel_buscado(index: int, ultimo: int) -> int:
	var tope := Game.item_max_level(index)
	return tope if index < ultimo else tope - 1


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
	_check("el menu trae la moneda del pie", _usa_sprite(menu, "currency_coin"))
	_check("y a tamano normal", not _sprite_gigante(menu, "currency_coin", 96.0))

	# --- ajustes ---
	menu._on_settings()
	await get_tree().process_frame
	await _wait(0.2)
	var ajustes = _main._veil_host.get_child(0) if _main._veil_host.get_child_count() > 0 else null
	_check("los ajustes se abren", ajustes != null)
	# La moneda de la fila de VENTA AUTOMATICA es un sprite de 512: dibujada por
	# escala sobre su lienzo salia a 256 y tapaba las filas de al lado.
	_check("la moneda de los ajustes no es gigante",
		ajustes != null and not _sprite_gigante(ajustes, "currency_coin", 160.0))
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
	# El contador de dinero lleva la moneda delante, a tamano de contador.
	_check("la partida dibuja la moneda del contador", _usa_sprite(g, "currency_coin"))
	_check("a tamano de contador, no gigante",
		not _sprite_gigante(g, "currency_coin", 128.0))
	# Y el rotulo del dano sigue quitado: es un numero que no se consulta en
	# ninguna parte de la pantalla de partida.
	_check("la partida no lleva el rotulo de dano", not _dice(g, "DANO", true))
	# La columna de sobres de la izquierda: doce, comprables sin abrir nada.
	_check("la zona de sobres tiene una celda por sobre",
		g._pack_cells.size() == LootDB.pack_count())
	_check("hay doce sobres", LootDB.pack_count() == 12)
	# Cuatro tipos y tres escalones de cada uno, en el mismo orden: sobre, vinilo,
	# zapatillas, electronica, y otra vez con mas precio y mas botin. El NOMBRE
	# tambien sube de escalon (ORO / LUJO), no solo el precio: el escalon 2 va de
	# pan de oro y el 3 de laca con joya, y el rotulo lo dice.
	_check("y son cuatro tipos repetidos tres veces",
		LootDB.pack_at(0)["name"] == "SOBRES"
		and LootDB.pack_at(1)["name"] == "VINILOS"
		and LootDB.pack_at(2)["name"] == "ZAPATILLAS"
		and LootDB.pack_at(3)["name"] == "ELECTRONICA"
		and LootDB.pack_at(4)["name"] == "SOBRES ORO"
		and LootDB.pack_at(8)["name"] == "SOBRES LUJO"
		and LootDB.pack_at(11)["name"] == "ELECTRONICA LUJO")
	_check("el que mas cuesta es el de diez millones",
		LootDB.pack_at(LootDB.pack_count() - 1)["price"] == 10000000)
	# El nombre mas largo tiene que caber a 28 en la caja del nombre. Si no,
	# UIKit.row_size encoge los DOCE a la vez y el "SOBRES" de arriba se queda
	# enano: es facil de romper sin querer (basta bautizar un escalon "DE
	# DIAMANTE", un caracter de mas), asi que se comprueba en vez de confiar en
	# que nadie toque los nombres.
	var nombres: Array = []
	var nombre_mas_largo := ""
	for i in LootDB.pack_count():
		var n := str(LootDB.pack_at(i)["name"])
		nombres.append(n)
		if n.length() > nombre_mas_largo.length():
			nombre_mas_largo = n
	_check("los doce nombres de sobre caben a 28 en la columna (el mas largo: %s)"
			% nombre_mas_largo,
		UIKit.row_size(nombres, g.PACK_NAME_BOX.x, 28) == 28)
	# La columna tiene SCROLL: doce filas de 136 px son 1632 de lista en una
	# ventana de 752. Lo que hay que comprobar es que la lista es mas alta que su
	# ventana (si no, no habria nada que recorrer) y que las filas van una debajo
	# de otra sin pisarse DENTRO de la lista: sin scroll el paso se comprimia a 62
	# px para que cupieran las doce, y ese apinamiento es lo que se ha quitado.
	var filas: Array = []
	var alto := 0.0
	for cell in g._pack_cells:
		var r := (cell["button"] as Control).get_rect()
		filas.append(r)
		alto = maxf(alto, r.end.y)
	var solapan := false
	for i in filas.size():
		for j in range(i + 1, filas.size()):
			# Con medio pixel de margen: las filas son contiguas a proposito, y con
			# los redondeos del paso los bordes que se tocan salen a veces como un
			# solape de una billonesima. Lo que se busca es un solape de verdad, que
			# seria una franja de clic que se come a la de al lado.
			if (filas[i] as Rect2).grow(-0.5).intersects((filas[j] as Rect2).grow(-0.5)):
				solapan = true
	_check("las doce filas de sobres van una debajo de otra sin pisarse", not solapan)
	_check("y la lista es mas alta que su ventana: hay scroll",
		alto > g.PACK_ZONE.size.y + 1.0)
	# Cada sobre llena su hueco. El dibujo se escala por el DIBUJO (Sprites.
	# used_rect) y no por el lienzo de 512: los cuatro tipos ocupan trozos muy
	# distintos de su lienzo (cartas 256x496, zapatillas 480x272), asi que
	# escalando por el lienzo el de cartas salia flaco, el de zapatillas diminuto
	# y los dos dentro de un marco que les sobraba por todas partes. Con la caja
	# del dibujo, el lado mas largo del sobre siempre toca el borde de la suya.
	var flojos: Array = []
	var desbordan: Array = []
	for i in g._pack_cells.size():
		var arte: TextureRect = g._pack_cells[i]["art"]
		var usado := Sprites.used_rect(str(LootDB.pack_at(i)["art"]))
		var escala := arte.size.x / 512.0
		var dibujo := usado.size * escala
		if absf(maxf(dibujo.x, dibujo.y) - maxf(g.PACK_ART_BOX.x, g.PACK_ART_BOX.y)) > 1.0:
			flojos.append(str(LootDB.pack_at(i)["name"]))
		if dibujo.x > g.PACK_ART_BOX.x + 1.0 or dibujo.y > g.PACK_ART_BOX.y + 1.0:
			desbordan.append(str(LootDB.pack_at(i)["name"]))
	_check("los doce sobres llenan su hueco (manda el dibujo, no el lienzo)",
		flojos.is_empty() and desbordan.is_empty())
	# Y ya no van dentro de un marco de ranura: doce marcos naranjas seguidos se
	# comian la columna. La comprobacion es sobre la LISTA, porque el ui_slot
	# sigue usandose en la mesa, que es donde si pinta algo.
	var marcos := 0
	for hijo in (g._pack_scroll.get_child(0) as Control).get_children():
		var arte := hijo as TextureRect
		if arte != null and arte.texture == Sprites.tex("ui_slot"):
			marcos += 1
	_check("los sobres de la columna ya no van enmarcados", marcos == 0)
	# Detras de las filas va un FONDO NEGRO OPACO. La columna estuvo sin fondo, y
	# entonces los precios y los nombres se leian encima de las monedas y las
	# baldas de la trastienda: con nueve cifras no hay quien los lea. Se comprueba
	# que existe, que tapa la columna entera y que NO es translucido (un alfa por
	# debajo de 1 dejaria pasar el fondo otra vez, que es justo el fallo).
	var fondo := g.get_node_or_null("PackBackdrop") as ColorRect
	_check("la columna de sobres tiene fondo propio", fondo != null)
	if fondo != null:
		_check("y el fondo es OPACO, no translucido", fondo.color.a >= 0.999)
		_check("y tapa la columna entera",
			fondo.get_global_rect().encloses(g.PACK_ZONE.grow(-1.0)))
		_check("y va detras de los sobres",
			fondo.get_index() < g._pack_scroll.get_index())
	# La barra: que recorra la lista entera, que no salga con el gris redondeado
	# del tema de Godot y que vaya atenuada. A todo color y ancha era lo mas
	# llamativo de la pantalla, una franja naranja pegada a la mesa.
	var barra: VScrollBar = g._pack_scroll.get_v_scroll_bar()
	_check("la barra de scroll llega hasta el final de la lista",
		barra != null and barra.max_value > barra.page)
	var cacha: StyleBoxFlat = null
	if barra != null:
		cacha = barra.get_theme_stylebox("grabber") as StyleBoxFlat
	_check("y esta pintada con el dorado del juego, atenuado",
		cacha != null and cacha.bg_color.r == Palette.GOLD_D.r
			and cacha.bg_color.g == Palette.GOLD_D.g
			and cacha.bg_color.b == Palette.GOLD_D.b
			and cacha.bg_color.a < 1.0)
	# La escalera, tipo por tipo: cada escalon cuesta mas y multiplica mas el
	# botin, y los tres dan la misma lista de objetos (que es de donde sale que
	# subir de escalon no sea cambiar de juego).
	for tipo in 4:
		var escalones := [LootDB.pack_at(tipo), LootDB.pack_at(tipo + 4),
				LootDB.pack_at(tipo + 8)]
		var uno: Dictionary = escalones[0]
		var dos: Dictionary = escalones[1]
		var tres: Dictionary = escalones[2]
		_check("el escalon 2 de %s cuesta mas que el 1" % uno["name"],
			int(dos["price"]) > int(uno["price"]))
		_check("el escalon 3 de %s cuesta mas que el 2" % uno["name"],
			int(tres["price"]) > int(dos["price"]))
		# Y aguanta mas: subir de escalon es pagar mas por un sobre MAS DURO del
		# mismo tipo. Si el de arriba fuera igual de blando, el precio solo
		# compraria botin mejor, y los tres escalones se leeran como el mismo sobre
		# tres veces.
		_check("y el escalon 2 de %s aguanta mas que el 1" % uno["name"],
			LootDB.pack_hp(str(dos["id"])) > LootDB.pack_hp(str(uno["id"])))
		_check("y el escalon 3 aguanta mas que el 2 (%s)" % uno["name"],
			LootDB.pack_hp(str(tres["id"])) > LootDB.pack_hp(str(dos["id"])))
		_check("y paga mas por el mismo objeto (%s)" % uno["name"],
			LootDB.tier_mult(str(tres["id"])) > LootDB.tier_mult(str(dos["id"]))
			and LootDB.tier_mult(str(dos["id"])) > LootDB.tier_mult(str(uno["id"])))
		var tabla_uno := LootDB.loot_table(str(uno["id"]))
		_check("los tres escalones de %s dan los mismos objetos" % uno["name"],
			tabla_uno.size() > 0
			and tabla_uno.size() == LootDB.loot_table(str(dos["id"])).size()
			and tabla_uno.size() == LootDB.loot_table(str(tres["id"])).size())
	# Pero el DIBUJO si cambia con el escalon. Era el pendiente de siempre: los
	# tres escalones de un tipo compartian sprite y, en una columna de doce con el
	# mismo dibujo repetido tres veces, no habia forma de saber cual valia un
	# millon. Se comprueba el arte CERRADO, el ABIERTO y los tres tramos de dano de
	# los tres escalones, porque el dano no se guarda en los datos: se deduce del
	# nombre del arte ("pack_cards" + "_d2"), y un arte nuevo sin sus tres tramos
	# se veria bien hasta el segundo golpe.
	var repetidos: Array = []
	var sin_arte: Array = []
	for tipo in 4:
		var artes: Array = []
		for escalon in 3:
			var p: Dictionary = LootDB.pack_at(tipo + escalon * 4)
			var base := str(p["art"])
			artes.append(base)
			for nombre in [base, str(p["art_open"]),
					base + "_d1", base + "_d2", base + "_d3"]:
				if Sprites.tex(nombre) == null:
					sin_arte.append(nombre)
		if artes[0] == artes[1] or artes[1] == artes[2]:
			repetidos.append(str(LootDB.pack_at(tipo)["name"]))
	_check("cada escalon de un tipo tiene su propio dibujo", repetidos.is_empty())
	_check("y cada escalon tiene arte cerrado, abierto y los tres tramos de dano",
		sin_arte.is_empty())
	_check("el sobre inicial se anuncia como GRATIS", g._pack_cells[0]["free"].visible)
	_check("y los demas sobres no", not Game.pack_free("electronics"))
	_check("el precio del inicial es 0", Game.pack_price("cards") == 0)
	_check("el de los demas es el de loot_db",
		Game.pack_price("electronics")
		== int(LootDB.pack_by_id("electronics")["price"]))
	var start_money: int = Game.money

	# --- tienda ---
	g._open_shop()
	await get_tree().process_frame
	var shop = g._shop
	_check("la tienda se abre", shop != null)
	_check("hay 8 items", shop._item_cells.size() == LootDB.item_count())
	# La tienda se ha quedado con los items: ni sobres, ni titulo, ni moneda, ni
	# el rotulo del dano. Es facil que cualquiera de los cuatro vuelva al pintar
	# el panel, asi que se comprueba que no estan.
	_check("la tienda no vende sobres", not _usa_sprite(shop, "pack_cards"))
	_check("la tienda no lleva el titulo TIENDA", not _dice(shop, "TIENDA"))
	_check("la tienda no lleva el rotulo de dano", not _dice(shop, "DANO", true))
	_check("la tienda trae la moneda del contador", _usa_sprite(shop, "currency_coin"))
	_check_cabe("la tienda no saca texto del panel", shop, PANEL)
	_check_sin_encimarse("la tienda no pone texto encima de una chapa", shop)

	# El sobre inicial se compra DESDE LA COLUMNA de la izquierda, no desde el
	# panel, y no cuesta nada NUNCA (no es "el primero gratis").
	g._buy_pack("cards")
	await get_tree().process_frame
	await _wait(0.9)
	_check("el sobre inicial no cuesta nada", Game.money == start_money)
	_check("y sigue costando 0 despues de comprarlo", Game.pack_free("cards"))
	_check("su celda sigue diciendo GRATIS", g._pack_cells[0]["free"].visible)
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
	_check("sigue cargando", el.is_opening())
	# Un clic es UN golpe: al terminar el ciclo la caja baja resistencia y vuelve
	# a quedarse quieta esperando otro clic (no se abre sola de una tirada).
	await _wait(0.4)
	_check("un clic no abre la caja del todo", not el.is_opening())
	_check("la resistencia ha bajado", el.hp < el.max_hp)

	# --- los items suben el dano y aceleran la carga ---
	var cero := [0, 0, 0, 0, 0, 0, 0, 0]
	var d0 := LootDB.damage_per_hit(cero)
	var d1 := LootDB.damage_per_hit([3, 0, 0, 0, 0, 0, 0, 0])
	_check("los items suben el dano", d1 > d0)
	_check("los items aceleran la carga",
			LootDB.charge_time([3, 0, 0, 0, 0, 0, 0, 0]) < LootDB.charge_time(cero))
	_check("una caja necesita varios golpes",
			float(LootDB.pack_hp("cards")) / d0 >= 2.0)
	# La vida de los sobres subio un 50 % de golpe: el basico (45) pide CUATRO
	# ciclos con el dano base (12), no tres. Se mira en golpes y no en el numero
	# suelto para que la comprobacion siga diciendo algo si el dano base cambia.
	_check("un sobre basico aguanta cuatro golpes sin nada comprado (45 de vida)",
			ceili(float(LootDB.pack_hp("cards")) / d0) == 4)
	_check("el precio del item sube con el nivel",
			LootDB.item_cost(0, 1) > LootDB.item_cost(0, 0))
	_check("el item tope no tiene precio", LootDB.item_cost(0, 99) < 0)
	# DOS CLASES DE ITEM. Los seis de estadisticas tienen ITEM_MAX_LEVEL niveles;
	# el PC y los Pinchos son de COMPRA UNICA (un nivel y ya), porque su efecto es
	# un si o un no: pagarlos ocho veces no tendria sentido.
	var pc_i := LootDB.item_index("pc")
	var pin_i := LootDB.item_index("pinchos")
	_check("el PC y los Pinchos son de compra unica: un nivel y ya",
			LootDB.item_max_level(pc_i) == 1 and LootDB.item_max_level(pin_i) == 1)
	_check("y por eso no se pueden pagar dos veces",
		LootDB.item_cost(pc_i, 0) > 0 and LootDB.item_cost(pc_i, 1) < 0)
	_check("los seis de estadisticas llegan hasta los ocho niveles",
		LootDB.item_max_level(0) == LootDB.ITEM_MAX_LEVEL)
	_check("el Ojo verde da critico", LootDB.crit_chance([0, 0, 0, 1, 0, 0, 0, 0]) > 0.0)
	_check("el Laser sube el dano critico",
			LootDB.crit_mult([0, 0, 0, 0, 3, 0, 0, 0]) > LootDB.crit_mult(cero))
	_check("el Cajon da mas huecos de mesa",
			LootDB.table_slots([0, 0, 1, 0, 0, 0, 0, 0]) > LootDB.TABLE_BASE)

	# --- revelado ---
	# Hay que insistir: cada ciclo es un golpe y la caja no se abre sola. Se pulsa
	# hasta que salga la tarjeta, con un tope por si algo se quedara colgado.
	var clicks := 0
	while g._reveal == null and clicks < 40:
		if is_instance_valid(el) and el.can_open():
			el.start_opening()
		await _wait(0.3)
		clicks += 1
	_check("sale la tarjeta de revelado al insistir", g._reveal != null)
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
	# Varios clics otra vez: cada ciclo es un golpe.
	var clicks_sell := 0
	while g._reveal == null and clicks_sell < 40:
		if is_instance_valid(el_sell) and el_sell.can_open():
			el_sell.start_opening()
		await _wait(0.3)
		clicks_sell += 1
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
	var suelto: Dictionary = LootDB.roll_pack(RandomNumberGenerator.new(), "electronics")
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
	# Y suelta el turno de los paquetes a medias: si no, uno que se estaba
	# abriendo seguiria ocupando un hueco de los Guantes sin estar ya en la mesa.
	Game.items[LootDB.item_index("guantes")] = 1
	var a_medias: TableElement = g._spawn_pack("cards")
	g._on_open_requested(a_medias)
	_check("un paquete a medias ocupa su hueco del turno", g._worked.size() == 1)
	g._sell_all_table()
	_check("y vender todo lo suelta", g._worked.is_empty())
	# VENDER TODO no paga un paquete a medio abrir (solo vende botin), asi que se
	# quita de la mesa a mano para que no siga cargando por detras.
	a_medias.queue_free()
	Game.items[LootDB.item_index("guantes")] = 0
	await get_tree().process_frame

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
	var before_full: int = Game.money
	g._buy_pack("electronics")
	_check("con la mesa llena no entra nada mas", g.table_count() == 8)
	# La mesa se mira ANTES de cobrar: si no cabe, no se cobra y no hay que
	# devolver nada.
	_check("con la mesa llena no se cobra el sobre", Game.money == before_full)

	# --- automatizaciones: cada boton con SU pieza ---
	# La tienda se cierra antes de probar nada de esto: la compra automatica se
	# para mientras hay un panel abierto (no tiene sentido que compre mientras el
	# jugador mira la tienda), y con ella abierta desde hace veinte comprobaciones
	# lo que se probaria es la pausa, no la compra.
	g._close_shop()
	await get_tree().process_frame
	# Sin piezas ninguno de los dos botones enciende nada, y devuelven false para
	# que quien llama pueda decir QUE falta (ver game.gd, _locked_notice()). Es la
	# regla mas facil de romper sin querer: basta con dejar de mirarla en
	# set_auto_open().
	Game.items = [0, 0, 0, 0, 0, 0, 0, 0]
	_check("sin piezas no se enciende la apertura automatica",
		not Game.set_auto_open(true) and not Game.auto_open)
	_check("ni la compra automatica",
		not Game.set_auto_buy(true) and not Game.auto_buy)
	# LOS PINCHOS son la pieza de la APERTURA: con ellos se enciende la apertura, y
	# solo la apertura. Antes hacian falta los Pinchos Y el PC para CUALQUIERA de
	# las dos, asi que comprar el PC no servia de nada hasta tener tambien los
	# Pinchos: eso es exactamente lo que se ha quitado.
	Game.buy_item(LootDB.item_index("pinchos"))
	_check("con los Pinchos la apertura automatica ya se puede encender",
		Game.set_auto_open(true) and Game.auto_open)
	Game.set_auto_open(false)
	_check("y sin el PC la compra automatica sigue cerrada: esa es la otra pieza",
		not Game.auto_buy_unlocked() and not Game.set_auto_buy(true))
	# EL PC es la pieza de la COMPRA, y va por su cuenta: se comprueba con los
	# Pinchos quitados, que es la unica forma de saber que el PC no necesita nada
	# mas que a si mismo.
	Game.items[LootDB.item_index("pinchos")] = 0
	_check("sin los Pinchos la apertura automatica vuelve a cerrarse",
		not Game.auto_open_unlocked() and not Game.set_auto_open(true))
	Game.buy_item(LootDB.item_index("pc"))
	_check("y con el PC la compra automatica ya se puede encender",
		Game.set_auto_buy(true) and Game.auto_buy)
	Game.set_auto_buy(false)
	Game.items[LootDB.item_index("pinchos")] = 1

	# Y su mini menu: la compra automatica no es solo SI o NO, tambien es QUE se
	# compra. Se comprueba que abre, que trae los sobres de PAGO (el gratuito no
	# entra: la compra automatica lo salta siempre, asi que una casilla suya no
	# haria nada) y que no se sale del panel, como la tienda.
	g._open_auto_buy()
	await get_tree().process_frame
	var panel = g._auto_buy_panel
	_check("el boton de la compra automatica abre su mini menu", panel != null)
	if panel != null:
		_check("y trae los once sobres de pago, sin el gratuito",
			panel._cells.size() == LootDB.pack_count() - 1)
		_check_cabe("el mini menu no saca texto del panel", panel, PANEL)
		_check_sin_encimarse("el mini menu no pone texto encima de una chapa", panel)
		for i in panel._cells.size():
			_check_dentro_de("el precio del sobre %d cabe en su chapa" % (i + 1),
				panel._cells[i]["num"], panel._cells[i]["tag_node"])
		g._close_auto_buy()
		await get_tree().process_frame
	_check("y se cierra", g._auto_buy_panel == null)

	# Los Pinchos NO golpean con la apertura apagada: el item es la pieza que
	# permite encender la automatizacion, y encenderla es lo que los pone a
	# trabajar. Apagada, la mesa se abre a clics como siempre.
	await _empty_table(g)
	var quieto: TableElement = g._spawn_pack("electronics3")
	await _wait(1.0)
	_check("con la apertura apagada los Pinchos no tocan la mesa",
		quieto.is_waiting_pack() and is_equal_approx(quieto.hp, quieto.max_hp))
	_check("y ahora la apertura si se enciende", Game.set_auto_open(true))
	await _wait(1.0)
	_check("encendida, los Pinchos golpean solos",
		is_instance_valid(quieto) and quieto.hp < quieto.max_hp)
	Game.set_auto_open(false)

	# Y con la apertura encendida la mesa se abre sola. Un sobre basico tiene 45 de
	# vida y los Pinchos pegan 24 por segundo, asi que los tres se abren en poco
	# menos de dos segundos. Se deja la autoventa puesta para que no salte la
	# tarjeta de revelado, que para el reloj.
	await _empty_table(g)
	for k in 3:
		g._spawn_pack("cards")
	var opened_before: int = Game.packs_opened
	Game.set_auto_sell(true)
	Game.set_auto_open(true)
	await _wait(3.0)
	_check("la apertura automatica abre la mesa sola",
		Game.packs_opened > opened_before)
	Game.set_auto_open(false)
	Game.set_auto_sell(false)
	await _wait(0.4)
	await _empty_table(g)

	# --- sin Guantes la mesa lleva UN paquete a la vez ---
	Game.items[LootDB.item_index("guantes")] = 0
	var uno: TableElement = g._spawn_pack("electronics3")
	var dos: TableElement = g._spawn_pack("electronics3")
	g._on_open_requested(uno)
	_check("el paquete pulsado empieza a abrirse", uno.is_opening())
	_check("sin Guantes solo cabe uno a la vez", Game.open_count() == 1)
	g._on_open_requested(dos)
	_check("sin Guantes el segundo no arranca: de uno en uno", not dos.is_opening())
	_check("y el turno sigue siendo del primero", g._worked.has(uno))
	_check("el que ya estaba abriendose sigue", uno.is_opening())

	# --- con Guantes caben VARIOS A LA VEZ, pero un clic arranca UNO ---
	# Es la diferencia con lo que habia antes: un clic NO abria varios de golpe.
	# Los Guantes suben cuantos paquetes caben cargando al mismo tiempo, y el
	# jugador tiene que ir pulsando uno y otro para que avancen todos; machacar el
	# mismo no adelanta mas que el suyo. Ver _on_open_requested().
	Game.items[LootDB.item_index("guantes")] = 1
	await _empty_table(g)
	var lote: Array = []
	for k in 4:
		lote.append(g._spawn_pack("electronics3"))
	_check("con los Guantes caben tres a la vez", Game.open_count() == 3)
	g._on_open_requested(lote[0])
	_check("y un clic arranca UN paquete, no varios",
		_cuantos_abriendo(g) == 1)
	_check("y el que NO se ha pulsado sigue quieto",
		not (lote[1] as TableElement).is_opening())
	for k in [1, 2]:
		g._on_open_requested(lote[k])
	_check("pulsando cada uno, los tres cargan a la vez",
		_cuantos_abriendo(g) == 3)
	g._on_open_requested(lote[3])
	_check("pero el cuarto ya no entra: el cupo son tres",
		not (lote[3] as TableElement).is_opening() and g._worked.size() == 3)
	# Y al soltar uno, su hueco queda libre para el que esperaba.
	g._remove_from_table(lote[0])
	await get_tree().process_frame
	g._on_open_requested(lote[3])
	_check("y al soltar uno, el que esperaba entra",
		(lote[3] as TableElement).is_opening())
	Game.items[LootDB.item_index("guantes")] = 0

	# --- la compra automatica compra lo que diga su mini menu ---
	# Con la lista vacia no compra nada, que es una forma de apagarla sin apagar
	# el boton. Marcando solo los de arriba se apunta a lo caro; con los doce
	# marcados va subiendo de escalon sola.
	await _empty_table(g)
	for i in LootDB.pack_count():
		Game.set_auto_buy_wanted(str(LootDB.pack_at(i)["id"]), false)
	_check("una lista vacia deja la compra automatica sin nada que comprar",
		Game.auto_buy_packs.is_empty())
	Game.money = 100000000
	Game.set_auto_buy(true)
	await _wait(1.4)
	_check("sin nada marcado no compra ni un sobre", g.table_count() == 0)
	# Dos marcados muy distintos de precio: coge el barato.
	Game.set_auto_buy_wanted("vinyls", true)
	Game.set_auto_buy_wanted("vinyls3", true)
	await _wait(2.0)
	_check("con dos marcados coge el mas barato",
		g.table_count() > 0 and str(g._elements[0].pack["id"]) == "vinyls")
	var todos_marcados := true
	for puesto in g._elements:
		if str((puesto as TableElement).pack["id"]) != "vinyls":
			todos_marcados = false
	_check("y no compra ninguno que no este marcado", todos_marcados)
	Game.set_auto_buy(false)
	Game.set_auto_buy_wanted("vinyls", false)
	Game.set_auto_buy_wanted("vinyls3", false)
	await _empty_table(g)

	# --- tienda con dinero de sobra: compra y herramientas ---
	Game.money = 100000000
	g._open_shop()
	await get_tree().process_frame
	var shop2 = g._shop
	shop2._on_item(0)
	_check("comprar item sube el nivel", Game.item_level(0) == 1)
	_check("el dano sube", Game.damage_per_hit() > LootDB.BASE_DAMAGE)
	# Y el siguiente nivel cuesta mas y se cobra: los seis de estadisticas siguen
	# siendo una escalera. Lo que no se repite es la compra de las piezas de las
	# automatizaciones, que va en su propio check mas abajo.
	var money_item: int = Game.money
	var cost2 := Game.item_cost(0)
	_check("el segundo nivel cuesta mas que el primero",
		cost2 > int(LootDB.item_by_id("guantes")["base_cost"]))
	shop2._on_item(0)
	_check("y se cobra", Game.item_level(0) == 2 and Game.money == money_item - cost2)
	var money_paid: int = Game.money
	g._buy_pack("electronics")
	await _wait(1.0)
	_check("se puede comprar un paquete caro", g.table_count() == 1)
	_check("un sobre de pago si cobra",
		Game.money == money_paid - int(LootDB.pack_by_id("electronics")["price"]))
	shop2._close()
	await get_tree().process_frame
	_check("la tienda se cierra", g._shop == null)

	# --- numeros extremos ---
	# Todo lo anterior se mide con la partida recien empezada: dinero de tres
	# cifras y items sin comprar. El sitio donde algo se desborda de verdad es
	# aqui, con nueve digitos y la tienda casi entera comprada.
	Game.money = 99999999
	g._open_shop()
	await get_tree().process_frame
	var shop3 = g._shop
	# Se compran siete de los ocho y se deja el ultimo (EL ARMARIO) sin comprar a
	# proposito: es el item con el precio mas largo de la tienda, y con todos
	# comprados no quedaria ni una chapa de precio que medir.
	# El ULTIMO item (EL ARMARIO) se queda un nivel por debajo de su tope: es el
	# que enseña el precio mas largo de la tienda, y con todas las chapas
	# escondidas no quedaria ni una que medir.
	var ultimo := LootDB.item_count() - 1
	for i in LootDB.item_count():
		while Game.item_level(i) < _nivel_buscado(i, ultimo):
			shop3._on_item(i)
	shop3.refresh()
	await get_tree().process_frame
	for i in shop3._item_cells.size():
		var tope := Game.item_max_level(i)
		var cerrado: bool = Game.item_level(i) >= tope
		var rotulo: Label = shop3._item_cells[i]["owned"]
		_check("el item %d llega al nivel buscado" % (i + 1),
				Game.item_level(i) == _nivel_buscado(i, ultimo))
		_check("el item %d ya no se puede pagar solo si esta al tope" % (i + 1),
				(Game.item_cost(i) < 0) == cerrado)
		_check("la tienda escribe %s en el item %d" % [
				"COMPRADO" if tope <= 1 else "AL TOPE", i + 1],
				rotulo.visible == cerrado
				and (not cerrado or rotulo.text == ("COMPRADO" if tope <= 1 else "AL TOPE")))
		_check("el item %d lleva chapa de precio solo si le queda algo" % (i + 1),
				(shop3._item_cells[i]["tag_node"] as TextureRect).visible == not cerrado)
		# Los puntos de nivel: ninguno en el PC ni en los Pinchos (no hay niveles
		# que marcar) y los ocho en los de estadisticas.
		_check("el item %d lleva puntos de nivel solo si sube de nivel" % (i + 1),
				(shop3._item_cells[i]["pips"] as Array).size() == (0 if tope <= 1 else tope))
		# Y donde irian esos puntos, en el PC y en los Pinchos va el rotulo que
		# DICE que se compran una sola vez: sin el, la fila solo se distinguia por
		# lo que no tenia, y eso no se lee.
		_check("el item %d dice COMPRA UNICA solo si es de una sola compra" % (i + 1),
				(shop3._item_cells[i]["once"] != null) == (tope <= 1))
		_check_dentro_de("el precio del item %d cabe en la chapa" % (i + 1),
				shop3._item_cells[i]["cost"], shop3._item_cells[i]["tag_node"])
	for i in g._pack_cells.size():
		_check_dentro_de("el precio del sobre %d cabe en la chapa" % (i + 1),
				g._pack_cells[i]["price"], g._pack_cells[i]["tag_node"])
	# Y cabe en la BANDA BLANCA, que es otra cosa que caber en el hueco del sprite:
	# la cinta solo pinta una franja en medio (ver PACK_TAG_INK) y con la chapa
	# baja el precio se salia por arriba y por abajo, o sea que el numero se leia
	# ENCIMA de la cinta en vez de dentro. Se le deja 4 px de aire, que es lo que
	# ocupa de mas el contorno del numero por debajo.
	var banda_alto: float = g.PACK_TAG_SIZE.y * g.PACK_TAG_INK
	for i in g._pack_cells.size():
		var precio: Control = g._pack_cells[i]["price"]
		if not is_instance_valid(precio) or not precio.visible:
			continue
		var chapa: TextureRect = g._pack_cells[i]["tag_node"]
		var banda := Rect2(
				chapa.position + Vector2(0.0, (g.PACK_TAG_SIZE.y - banda_alto) * 0.5),
				Vector2(g.PACK_TAG_SIZE.x, banda_alto))
		_check("y el precio del sobre %d cabe en la BANDA blanca, no solo en el hueco" % (i + 1),
				banda.grow(-4.0).encloses(precio.get_rect()))
	# La fila del item comprado tiene que caber igual que las demas: cambia el
	# precio por el rotulo de COMPRADO, y el rotulo es mas ancho que la chapa.
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
