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


## Los numeros de dano que hay AHORA MISMO colgando de una capa.
##
## Se reconocen por su MARCA y no por su color: el color es justo lo que se
## quiere comprobar, y filtrar por lo que estas midiendo convierte la
## comprobacion en una pregunta al aire. La capa de los avisos tambien lleva los
## "+" de las ventas, y esos no son golpes.
##
## Y tampoco por el NOMBRE, aunque el nodo lo lleve: Godot renombra a los
## hermanos repetidos (DamagePop, DamagePop2...), asi que por nombre exacto solo
## se encuentra el primero. Ver DamagePopup.MARK.
func _popups(de: Node) -> Array:
	var salida: Array = []
	if de == null:
		return salida
	for c in de.get_children():
		var n := c as PixelNumber
		if n != null and n.has_meta(DamagePopup.MARK):
			salida.append(n)
	return salida


## El texto de la primera etiqueta de un arbol que EMPIECE por esto.
##
## Hace falta para leer un rotulo del que no se sabe el numero: _dice() pregunta
## por un texto exacto, y "AHORA: 7 A LA VEZ" cambia con el nivel. Devuelve "" si
## no hay ninguna, que es lo que distingue "no esta" de "esta y dice esto".
func _etiqueta(de: Node, empieza: String) -> String:
	var pila: Array = [de]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var l := n as Label
		if l != null and l.text.begins_with(empieza):
			return l.text
		pila.append_array(n.get_children())
	return ""


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


## El primer TextureRect del arbol que lleva ese sprite, o null.
func _sprite_de(de: Node, nombre: String) -> TextureRect:
	var quiero := Sprites.tex(nombre)
	var pila: Array = [de]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var t := n as TextureRect
		if t != null and t.texture == quiero:
			return t
		pila.append_array(n.get_children())
	return null


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
## Los rotulos de una pantalla que llevan alguna minuscula.
##
## La fuente del juego es de mapa de bits y NO TIENE MINUSCULAS: una letra
## minuscula no sale "en minuscula", sale un cuadro de basura, y los checks de
## encuadre no lo ven porque el texto cabe igual. Paso con las explicaciones de la
## ficha de una mejora, que estaban escritas en minusculas y salian ilegibles.
func _minusculas_en(de: Node) -> Array:
	var malas: Array = []
	var pila: Array = [de]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var l := n as Label
		if l != null and l.text != "" and l.text != l.text.to_upper():
			malas.append(l.text)
		pila.append_array(n.get_children())
	return malas


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


## El rectangulo DIBUJADO de un sprite: su TINTA, no su lienzo.
##
## El lienzo de estos sprites es de 512x512 con el dibujo en medio, asi que
## comparar la caja del TextureRect contra un texto dice que se pisan siempre.
## Con el alfa del sprite (get_used_rect) se sabe donde empieza la tinta de
## verdad, sin inventar margenes a ojo.
func _dibujo(t: TextureRect) -> Rect2:
	if t.texture == null:
		return Rect2()
	var r := t.get_global_rect()
	var img := t.texture.get_image()
	if img == null:
		return r
	if img.is_compressed() and img.decompress() != OK:
		return r
	var caja: Rect2i = img.get_used_rect()
	var esc := Vector2(r.size.x / float(img.get_width()),
			r.size.y / float(img.get_height()))
	return Rect2(r.position + Vector2(caja.position) * esc, Vector2(caja.size) * esc)


## Textos cuya tinta se mete debajo de un DIBUJO, sin que el dibujo lo contenga
## (un numero dentro de su chapa SI lo contiene, y eso no es un fallo).
##
## Es la fuga que no ve ninguno de los otros checks: el texto no se sale de la
## pantalla ni pisa una chapa, se mete debajo del DIBUJO que tiene al lado. Paso
## en la ficha de la tienda, con las lineas de la descripcion dibujadas encima
## del dibujo del objeto (la columna de texto se colocaba por su BORDE y
## label_at() coloca por su CENTRO: ver item_card.gd, COL_X y COL_MID). En una
## captura eso se ve, pero no se mide, y el fallo volvio dos veces.
## `tapado` es la franja de una capa que va POR ENCIMA: la barra del rebirth se
## dibuja DESPUES del arbol, asi que un dibujo que se mete debajo de ella no es
## una fuga, esta tapado. Sin esto, el arbol colandose por debajo de la barra
## -que es como esta hecho a proposito- saltaba como si tuviera el saldo escrito
## encima de las chapas.
func _pisados(de: Node, tapado := Rect2()) -> Array:
	var textos: Array = []
	var dibujos: Array = []
	var pila: Array = [de]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var c := n as Control
		if c != null and c.visible:
			if c is Label or c is PixelNumber:
				var r := _visible(c, true)
				if r.size.x > 0.0 and r.size.y > 0.0:
					textos.append([c, r])
			elif c is TextureRect and (c as TextureRect).texture != null:
				var b := _dibujo(c as TextureRect)
				var tapada: bool = tapado.size.x > 0.0 and tapado.intersects(b)
				if b.size.x > 0.0 and b.size.y > 0.0 and not tapada:
					dibujos.append([c, b])
		pila.append_array(n.get_children())
	var malas: Array = []
	for t in textos:
		for d in dibujos:
			var a: Rect2 = t[1]
			var b: Rect2 = d[1]
			# Los glifos de un numero son hijos SUYOS: no cuentan.
			if _uno_dentro_de(d[0], t[0]):
				continue
			if b.encloses(a) or a.encloses(b):
				continue
			if a.intersects(b):
				malas.append("\"%s\" %s pisa %s %s" % [_texto_de(t[0]), str(a),
						str((d[0] as TextureRect).texture.resource_path).get_file(), str(b)])
	return malas


## Check de que una pantalla no dibuje texto encima de un objeto. Cada fuga
## imprime lo que pisa y donde, que es lo que hace falta para saber que mover.
func _check_sin_pisar_dibujos(what: String, de: Node, tapado := Rect2()) -> void:
	if de == null:
		return
	var malas := _pisados(de, tapado)
	_check(what, malas.is_empty())
	for m in malas:
		print("         encima del dibujo: ", m)


## La franja de la barra del rebirth, en coordenadas de pantalla: lo que queda
## debajo de ella esta tapado por una capa que se pinta DESPUES del arbol.
func _franja_barra(panel: Node) -> Rect2:
	return Rect2(panel.VIEW_POS, Vector2(panel.VIEW_SIZE.x, panel.BAR_H))


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
##
## `tapado` es la franja de la capa que se pinta POR ENCIMA (la barra del
## rebirth): un texto que cae debajo no se ve, asi que no ensucia nada.
func _check_sin_encimarse(what: String, de: Node, tapado := Rect2()) -> void:
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
				var tapada: bool = tapado.size.x > 0.0 and tapado.intersects(r)
				if r.size.x > 0.0 and r.size.y > 0.0 and not tapada:
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


## La caja que ocupa el DIBUJO del arbol en la pantalla: la de SkillTree.bounds()
## movida por el arrastre que tenga el panel. Es lo que se mira para saber si el
## arbol sigue a la vista (el tope del arrastre se calcula sobre esta caja).
func _caja_del_arbol(arbol: RebirthPanel) -> Rect2:
	var b := SkillTree.bounds()
	return Rect2(b.position + arbol._offset + arbol.VIEW_POS, b.size)


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
## Pulsar el COMPRAR de una ficha (SkillCard o ItemCard).
##
## Existe para que las pruebas del arbol digan lo que hacen -"se compra desde la
## ficha"- y no como se pulsa: el boton lleva el texto en un Label hijo, asi que
## buscarlo y soltarle un pressed.emit() son tres lineas que se repiten. Devuelve
## false si esa ficha no trae boton, que es lo que se comprueba cuando el nodo ya
## esta comprado.
func _pulsa_comprar(ficha: Node) -> bool:
	var b := _boton_de(ficha, "COMPRAR")
	if b == null:
		return false
	b.pressed.emit()
	return true


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
	# El menu es el titulo, el subtitulo y dos chapas, y NADA MAS: la moneda que
	# hacia de adorno en el pie (abajo a la izquierda) se quito, porque en el
	# arranque no hay dinero que contar. Aqui solo se puede comprobar que no
	# vuelve, que es lo unico que le queda por decir a este check.
	_check("el menu no lleva ninguna moneda", not _usa_sprite(menu, "currency_coin"))

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
	# LAS MONEDAS DE REBIRTH, AL LADO DEL DINERO: el cerdito y su numero, en la
	# barra. Es la unica moneda que no se gasta y decide cuanto valen todas las
	# ventas, asi que no puede vivir solo dentro del panel de la hucha.
	_check("la barra trae el contador de monedas de rebirth",
		g._rebirth_count != null
		and g._rebirth_count.get_text() == PixelNumber.format(Game.rebirth_coins))
	_check("y el cerdito del contador esta en la barra",
		_usa_sprite(g, "currency_piggy"))
	# EL CERDITO, DEL TAMANO DE LA MONEDA DEL DINERO. Se comparan los dos DIBUJOS
	# (la tinta, no el lienzo, que es de 512 para los dos pero no lo llenan igual),
	# que es justo lo que se mira al lado de un contador: si uno mide la mitad que
	# el otro, el pequeno se lee como un icono de segunda fila. Y la moneda se
	# busca por el arbol porque es la primera del juego.
	var moneda := _sprite_de(g, "currency_coin")
	var cerdito: TextureRect = g._rebirth_coin
	var alto_moneda: float = _dibujo(moneda).size.y if moneda != null else 0.0
	var alto_cerdito: float = _dibujo(cerdito).size.y if cerdito != null else 0.0
	_check("el cerdito del contador mide lo mismo que la moneda del dinero",
		alto_moneda > 0.0 and absf(alto_cerdito - alto_moneda) <= alto_moneda * 0.06)

	# Y VA PEGADO AL DINERO, alli donde acaba el numero: el hueco entre el ultimo
	# digito y la tinta del cerdito se mide de verdad, con el contador en pequeno
	# (que es cuando antes se quedaba flotando en medio de la barra) y en su tope.
	var saldo_antes: int = Game.money
	for saldo in [500, 999999999]:
		Game.money = int(saldo)
		g._on_money_changed(int(saldo))
		await get_tree().process_frame
		var hueco: float = _dibujo(cerdito).position.x - g._money.get_global_rect().end.x
		# 40 px es un digito y medio: mas que eso ya no se lee como "las monedas
		# del dinero", y menos que 0 es que una cosa esta encima de la otra.
		_check("con %s en el contador el cerdito va pegado al dinero (%d px)"
				% [PixelNumber.format(int(saldo)), roundi(hueco)],
			hueco >= 0.0 and hueco <= 40.0)
	Game.money = saldo_antes
	g._on_money_changed(saldo_antes)

	# Las tres anchuras no se pueden tocar: dinero, cerdito+numero y rotulo de la
	# mesa. Se mide con el numero EN SU TOPE, que es cuando el dinero se encoge.
	_check("el dinero no pisa el contador de rebirth ni el rotulo de la mesa",
		g._money.get_global_rect().end.x < _dibujo(cerdito).position.x - 8.0
		and g._rebirth_count.get_global_rect().end.x
			< g._table_label.get_global_rect().position.x - 8.0)
	# LA CHAPA DEL REBIRTH, DEL TAMANO DE LA TIENDA Y CON EL CERDITO. Antes era
	# una chapa pequeña sin icono, y al lado de la tienda se leia como un boton
	# secundario cuando es la otra forma de parar la partida.
	var tienda := _boton_de(g, "TIENDA")
	_check("la chapa del rebirth es del tamano de la tienda",
		tienda != null and g._rebirth_btn.size == tienda.size)
	_check("y lleva el cerdito al lado de la palabra",
		_usa_sprite(g._rebirth_btn, "currency_piggy"))
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
	# LA ESCALERA SE MIDE DE ESCALON A ESCALON, NO SOLO DENTRO DE UN TIPO.
	# El bucle de arriba mira cada tipo por su cuenta, y eso dejaba pasar el fallo
	# de verdad: dentro de SOBRES todo subia (0 -> 4.000 -> 80.000) y dentro de
	# ELECTRONICA tambien (25.000 -> 500.000 -> 10.000.000), pero de un escalon al
	# siguiente el precio se CRUZABA: SOBRES ORO costaba 4.000 y la ELECTRONICA
	# del escalon 1 cuesta 25.000, o sea que un sobre de calidad 2 era mas barato
	# que el de calidad 1 mas caro. Y como el escalon de arriba multiplica el
	# botin, el jugador no tiene ninguna razon para comprar la electronica ni las
	# zapatillas del escalon 1: se las salta y compra el sobre de arriba. El
	# jugador no ve ni el id ni el multiplicador: ve la columna de precios, asi
	# que lo que se pide aqui es lo que ve - cualquier sobre de un escalon cuesta
	# mas que TODOS los del anterior.
	var precios_por_escalon: Array = []
	for escalon in 3:
		var precios: Array = []
		for tipo in 4:
			precios.append(int(LootDB.pack_at(tipo + escalon * 4)["price"]))
		precios_por_escalon.append(precios)
	var cruzados: Array = []
	for escalon in 2:
		var abajo: int = int((precios_por_escalon[escalon] as Array).max())
		var arriba: int = int((precios_por_escalon[escalon + 1] as Array).min())
		if arriba <= abajo:
			cruzados.append("los de %d llegan a %d y los de %d empiezan en %d"
				% [escalon + 1, abajo, escalon + 2, arriba])
	_check("ningun sobre de un escalon baja del precio mas alto del anterior",
		cruzados.is_empty())
	for c in cruzados:
		print("        cruzados: ", c)
	# Y CADA SOBRE PAGA LO QUE CUESTA, en cualquier escalon. Se mide lo que paga
	# de media su tabla (LootDB.pack_payout: la media ponderada de los objetos con
	# la nota media y el VALUE_SCALE) por su multiplicador de escalon, que es lo
	# que se cobra al vender el botin. El precio tiene que ir con la recompensa:
	# si el sobre caro pagara menos por dinero que el barato, subir de escalon
	# seria pagar mas para ganar menos; y si pagara mas, saltarse los baratos
	# seria lo racional, que es el problema que se ha venido a arreglar.
	#
	# ESE MARGEN ES TODA LA PROGRESION DEL JUEGO, y es lo que estaba roto: con el
	# 350 % que habia, el capital se multiplicaba por 4,5 en cada sobre, no habia
	# forma de gastarlo y la partida se terminaba en dos minutos, o sea que un
	# PSA 10 -o cualquier golpe de suerte- ERA la partida. Ahora los doce pagan un
	# 30-45 %, el mismo en cualquier escalon: la escalera es de CAPITAL (cada escalon
	# mueve mas dinero por la misma proporcion) y no de rentabilidad. El sobre
	# inicial no entra en la cuenta: es gratis y no tiene proporcion.
	var timos: Array = []
	var peor := 99.0
	var mejor := 0.0
	for i in LootDB.pack_count():
		var precio := int(LootDB.pack_at(i)["price"])
		if precio <= 0:
			continue
		var vuelta := LootDB.pack_payout(str(LootDB.pack_at(i)["id"])) / float(precio)
		peor = minf(peor, vuelta)
		mejor = maxf(mejor, vuelta)
		if vuelta < 1.30 or vuelta > 1.45:
			timos.append("%s paga x%.2f" % [LootDB.pack_at(i)["name"], vuelta])
	_check("cada sobre paga de media entre un 30 y un 45 %% mas de lo que cuesta (de x%.2f a x%.2f)"
			% [peor, mejor],
		timos.is_empty())
	for t in timos:
		print("        descuadrado: ", t)
	# LA NOTA PSA: las altas son RARAS y el 10 es el premio. Se mide la tabla, que
	# es fija, y no una tirada: un test que depende de la suerte es peor que no
	# tenerlo. Antes el 10 era la nota MAS probable (el 22,9 %) y las 9 y 10 se
	# llevaban casi la mitad del botin, que es lo que el jugador notaba al abrir
	# sobres sin parar de sacar "como nuevo".
	var peso_total := 0
	for w in LootDB.GRADE_WEIGHTS:
		peso_total += int(w)
	var peso_alta := 0
	for i in LootDB.GRADE_WEIGHTS.size():
		if i + 1 >= 9:
			peso_alta += int(LootDB.GRADE_WEIGHTS[i])
	var p_diez := 100.0 * float(LootDB.GRADE_WEIGHTS[LootDB.GRADE_MAX - 1]) / float(peso_total)
	_check("la nota 10 es rara (sale el %.1f %% de las veces)" % p_diez, p_diez <= 5.0)
	_check("y las 9 o mas no pasan del 10 %",
		100.0 * float(peso_alta) / float(peso_total) <= 10.0)
	# Y el precio de la nota: la 5 vale lo que valia la 10, y la 10 el doble de
	# aquella. Son las dos anclas que se pidieron, escritas como numero a mano
	# para que moverlas sin querer se vea aqui.
	_check("la nota 5 vale lo que valia la 10 de antes",
		is_equal_approx(LootDB.grade_mult(5), 1.25))
	_check("y la nota 10 el doble que la 10 de antes",
		is_equal_approx(LootDB.grade_mult(10), 2.50))
	_check("una nota baja vale menos que antes", LootDB.grade_mult(1) < 0.80)
	var notas_bajas: Array = []
	for grado in range(2, LootDB.GRADE_MAX + 1):
		if LootDB.grade_mult(grado) <= LootDB.grade_mult(grado - 1):
			notas_bajas.append(grado)
	_check("cada nota vale mas que la de abajo", notas_bajas.is_empty())
	# EL TREBOL NO TOCA LA NOTA, SOLO LA RAREZA. Se comprueba con la MISMA semilla
	# y la misma cantidad de tiradas: el dado del objeto gasta los mismos numeros
	# con cualquier suerte (un randf por tirada), asi que si la nota se metiera
	# dentro del dado de la suerte las dos listas se separarian. Y la rareza SI
	# tiene que cambiar, o el Trebol no estaria haciendo nada.
	var sin_suerte := RandomNumberGenerator.new()
	var con_suerte := RandomNumberGenerator.new()
	sin_suerte.seed = 20261023
	con_suerte.seed = 20261023
	var niveles: Array = []
	for i in LootDB.item_count():
		niveles.append(0)
	niveles[LootDB.item_index("trebol")] = LootDB.ITEM_MAX_LEVEL
	var con_luck := LootDB.luck(niveles)
	var notas_distintas := 0
	var raras_sin := 0
	var raras_con := 0
	for i in 500:
		var a := LootDB.roll_pack(sin_suerte, "electronics", 1.0)
		var b := LootDB.roll_pack(con_suerte, "electronics", con_luck)
		if int(a["grade"]) != int(b["grade"]):
			notas_distintas += 1
		if str(a["rarity"]) != "common":
			raras_sin += 1
		if str(b["rarity"]) != "common":
			raras_con += 1
	_check("la suerte no cambia ni una nota (%d de 500 distintas)" % notas_distintas,
		notas_distintas == 0)
	_check("y con el Trebol al maximo salen mas raros (%d contra %d de 500)"
			% [raras_con, raras_sin], raras_con > raras_sin)
	# LA RESISTENCIA VA CON LA RAIZ DEL PRECIO (hp = 21,5 x raiz(precio)): un sobre
	# cuatro veces mas caro no es cuatro veces mas duro, es el doble. Esa curva es
	# la que decide cuanto DURA la partida -el rato es la vida partida por el dano
	# del jugador- y de ella salen los minutos de dev/balance.gd, asi que un sobre
	# que se salga de la curva se ve en el reloj aunque nadie mire la tabla. El
	# 21,5 se escribe aqui a mano a proposito: si el test lo leyera de loot_db, una
	# tabla y una constante malas las dos seguirian pasando la prueba.
	var descuadrados: Array = []
	for pack in LootDB.PACKS:
		var precio := int(pack["price"])
		if precio <= 0:
			continue
		var esperado := 21.5 * sqrt(float(precio))
		if absf(float(pack["hp"]) - esperado) > esperado * 0.06:
			descuadrados.append("%s con %d de vida (le tocaban %d)"
				% [pack["name"], pack["hp"], roundi(esperado)])
	_check("la resistencia de cada sobre va con la raiz de su precio",
		descuadrados.is_empty())
	for d in descuadrados:
		print("        descuadrado: ", d)
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

	# --- el DOLAR: sobres mas baratos ---
	# El descuento se aplica en Game.pack_price(), asi que se mide ahí y no en la
	# formula: lo que importa es que la columna de la partida cobre -y ENSEÑE- el
	# precio rebajado, no que la cuenta sea bonita.
	var i_dolar := LootDB.item_index("dolar")
	var i_vinyls := -1
	for i in LootDB.pack_count():
		if str(LootDB.pack_at(i)["id"]) == "vinyls":
			i_vinyls = i
	var base_vinyls := int(LootDB.pack_by_id("vinyls")["price"])
	_check("el Dolar cuesta 900 en su primer nivel",
		LootDB.item_cost(i_dolar, 0) == 900)
	# La escalera: las tres primeras baratas y despues el salto, con la ultima
	# MUY cara (el descuento se nota en todo lo que compres).
	var escalera: Array = []
	for nivel in LootDB.item_max_level(i_dolar):
		escalera.append(LootDB.item_cost(i_dolar, nivel))
	var sube_siempre := true
	for i in range(1, escalera.size()):
		if int(escalera[i]) <= int(escalera[i - 1]):
			sube_siempre = false
	_check("y cada nivel del Dolar cuesta mas que el anterior", sube_siempre)
	_check("y el ultimo es de los caros de la tienda (%d)" % int(escalera[-1]),
		int(escalera[-1]) > 100000)
	Game.items[i_dolar] = 0
	_check("sin el Dolar el sobre cuesta su precio",
		Game.pack_price("vinyls") == base_vinyls)
	Game.items[i_dolar] = LootDB.item_max_level(i_dolar)
	_check("y con el Dolar al tope, un 40 %% menos (%s)" % PixelNumber.format(
			roundi(float(base_vinyls) * 0.6)),
		Game.pack_price("vinyls") == roundi(float(base_vinyls) * 0.6))
	Game.items[i_dolar] = 4
	_check("y a la mitad de la escalera, un 20 % menos",
		Game.pack_price("vinyls") == roundi(float(base_vinyls) * 0.8))
	_check("el sobre gratuito sigue gratis con el Dolar al tope",
		Game.pack_price("cards") == 0)
	g._refresh_packs()
	var celda_dolar: Dictionary = g._pack_cells[i_vinyls]
	_check("y la columna de sobres enseña el precio rebajado",
		(celda_dolar["price"] as PixelNumber).get_text()
		== PixelNumber.format(Game.pack_price("vinyls")))
	Game.items[i_dolar] = 0
	g._refresh_packs()

	var start_money: int = Game.money

	# --- tienda ---
	g._open_shop()
	await get_tree().process_frame
	var shop = g._shop
	_check("la tienda se abre", shop != null)
	_check("hay diez items", shop._item_cells.size() == LootDB.item_count())
	# La tienda se ha quedado con los items: ni sobres, ni titulo, ni moneda, ni
	# el rotulo del dano. Es facil que cualquiera de los cuatro vuelva al pintar
	# el panel, asi que se comprueba que no estan.
	_check("la tienda no vende sobres", not _usa_sprite(shop, "pack_cards"))
	_check("la tienda no lleva el titulo TIENDA", not _dice(shop, "TIENDA"))
	_check("la tienda no lleva el rotulo de dano", not _dice(shop, "DANO", true))
	_check("la tienda trae la moneda del contador", _usa_sprite(shop, "currency_coin"))
	_check_cabe("la tienda no saca texto del panel", shop, PANEL)
	_check_sin_encimarse("la tienda no pone texto encima de una chapa", shop)

	# LAS CAJAS. Cada item se dibuja como una caja de 264x264 en rejilla de cinco
	# por dos. Es una medida que se sale por abajo sin que nada mas lo note (el
	# marco del panel no recorta), asi que se mide: las diez dentro del recuadro
	# interior y ninguna pisando a otra.
	var cajas: Array = []
	var sin_filete: Array = []
	for i in shop._item_cells.size():
		var celda: Dictionary = shop._item_cells[i]
		var caja_fondo: ColorRect = celda["back"]
		cajas.append(Rect2(caja_fondo.position, caja_fondo.size))
		if (celda["frame"] as Array).size() != 4:
			sin_filete.append(str(i + 1))
	_check("cada item de la tienda se dibuja como una caja", sin_filete.is_empty())
	var fuera_caja: Array = []
	var pisadas: Array = []
	for i in cajas.size():
		if not PANEL.encloses(cajas[i]):
			fuera_caja.append("%d: %s" % [i + 1, str(cajas[i])])
		for j in range(i + 1, cajas.size()):
			if (cajas[i] as Rect2).intersects(cajas[j]):
				pisadas.append("%d-%d" % [i + 1, j + 1])
	_check("y las diez cajas caben en la rejilla del panel", fuera_caja.is_empty())
	_check("sin pisarse ninguna con otra", pisadas.is_empty())
	for f in fuera_caja:
		print("         caja fuera: ", f)
	for p in pisadas:
		print("         cajas pisadas: ", p)
	_check("la caja lleva dentro el dibujo del item",
		_usa_sprite(shop._item_cells[0]["art"], "item_tijeras"))

	# LA FICHA. La caja no compra: abre la ficha del item (ver ItemCard), que es
	# donde estan la descripcion larga y los numeros que cambian con el nivel.
	var tijeras := LootDB.item_index("tijeras")
	var capas_antes: int = _main._overlay_host.get_child_count()
	shop._open_card(tijeras)
	await get_tree().process_frame
	var ficha = shop._card
	_check("el clic en una caja abre la ficha del item", ficha != null)
	_check("y la ficha se cuelga de la capa de encima, no dentro del panel",
		ficha != null and ficha.get_parent() == _main._overlay_host)
	if ficha != null:
		_check("la ficha dice de que item es", _dice(ficha, "TIJERAS"))
		# La descripcion larga NO cabe en una linea (por eso UIKit.wrap()): se
		# comprueba que estan TODAS sus lineas, no solo la primera.
		var faltan: Array = []
		for linea in UIKit.wrap(str(LootDB.item_at(tijeras)["detail"]),
				ItemCard.COL_W, 21):
			if not _dice(ficha, str(linea)):
				faltan.append(str(linea))
		_check("la ficha trae la descripcion larga entera", faltan.is_empty())
		for f in faltan:
			print("         falta la linea: ", f)
		# Y CABE. El hueco de la descripcion aguanta cuatro lineas antes de la
		# raya (ver ItemCard.DETAIL_LINES_MAX): la quinta se dibuja encima de los
		# numeros de AHORA y NIVEL 1, y eso no da ningun error, solo una ficha
		# ilegible. Se mira en TODOS los items, porque la ficha enseña el que se
		# pulse y el test solo abre el de las Tijeras.
		var largos: Array = []
		for i in LootDB.item_count():
			var n := UIKit.wrap(str(LootDB.item_at(i).get("detail", "")),
					ItemCard.COL_W, 21).size()
			if n > ItemCard.DETAIL_LINES_MAX:
				largos.append("%s (%d lineas)" % [LootDB.item_at(i)["name"], n])
		_check("la descripcion de los diez items cabe en la ficha", largos.is_empty())
		for l in largos:
			print("         se sale de la ficha: ", l)
		# LOS NUMEROS. El de AHORA y el que tendra al subir, los dos sacados de la
		# formula de verdad (LootDB.item_effect): la ficha no puede decir una cosa y
		# el juego hacer otra.
		_check("la ficha ense\u00f1a el efecto que tiene AHORA",
			_etiqueta(ficha, "AHORA:") == "AHORA: " + LootDB.item_effect(tijeras, 0))
		_check("y el que tendra en el nivel siguiente",
			_etiqueta(ficha, "NIVEL 1:") == "NIVEL 1: " + LootDB.item_effect(tijeras, 1))
		_check("los dos numeros son distintos: el efecto sube con el nivel",
			LootDB.item_effect(1, 0) != LootDB.item_effect(1, 1))
		_check_dentro_de("el precio de la ficha cabe en su chapa",
			ficha.find_child("Cost", true, false), ficha.find_child("Tag", true, false))
		_check_cabe("la ficha no saca texto del panel", ficha, PANEL)
		_check_sin_encimarse("la ficha no pone texto encima de una chapa", ficha)
		var comprar := _boton_de(ficha, "COMPRAR")
		_check("la ficha trae el boton de comprar", comprar != null)
		# Y SIN DINERO no compra: la ficha pide la compra a la tienda, que es la que
		# cobra, y por eso el nivel no sube ni se gasta nada. El dinero se pone a
		# mano un punto por debajo del precio: desde que las Tijeras cuestan 300, el
		# dinero de una partida nueva (500) SI llega, y esta prueba es de la ficha
		# sin dinero, no de la partida nueva.
		_check("y el item no esta comprado todavia", Game.item_level(tijeras) == 0)
		var dinero_ficha: int = Game.money
		Game.money = LootDB.item_cost(tijeras, 0) - 1
		if comprar != null:
			comprar.pressed.emit()
		await get_tree().process_frame
		_check("sin dinero la ficha no compra", Game.item_level(tijeras) == 0)
		Game.money = dinero_ficha
	shop._close_card()
	await get_tree().process_frame
	_check("cerrar la ficha deja la tienda abierta y sin nada encima",
		g._shop == shop and shop._card == null
		and _main._overlay_host.get_child_count() == capas_antes)

	# La ficha de una pieza de compra unica: donde iria el nivel siguiente dice lo
	# que pasa AL COMPRARLA, que es lo unico que se puede decidir con ella.
	shop._open_card(LootDB.item_index("pc"))
	await get_tree().process_frame
	var ficha_pc = shop._card
	_check("la ficha del PC dice que es de una sola compra",
		ficha_pc != null and _dice(ficha_pc, "PC") and _dice(ficha_pc, "COMPRA UNICA"))
	_check("y anuncia lo que pasa al comprarlo, no un nivel siguiente",
		ficha_pc != null and _etiqueta(ficha_pc, "AL COMPRARLO:") != ""
		and _etiqueta(ficha_pc, "NIVEL 1:") == "")
	shop._close_card()
	await get_tree().process_frame

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
	# SIN BARRA DE VIDA: la resistencia se lee en el dibujo, que se agrieta. La
	# barra era un ColorRect oscuro encima del paquete, asi que "no hay ninguna"
	# se puede comprobar: si vuelve, este check la caza.
	var barras := 0
	for c in el.get_children():
		if c is ColorRect:
			barras += 1
	_check("el paquete no lleva barra de vida: lo dice el dibujo", barras == 0)
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
	# La espera va con la CARGA REAL y no con un numero fijo: el ciclo base es de
	# 1,65 s desde que la barra se freno, y volver a tocarlo no puede romper esto
	# (con 0,4 s fijos se cumplia porque el ciclo viejo medía 0,55; con el de
	# ahora ese numero se queda corto y el check diria que la caja se abre sola).
	await _wait(Game.charge_time() + 0.3)
	_check("un clic no abre la caja del todo", not el.is_opening())
	_check("la resistencia ha bajado", el.hp < el.max_hp)
	# Y EL DIBUJO ES EL UNICO AVISO QUE QUEDA, que es lo que se pidio al quitar la
	# barra: con la caja a media resistencia tiene que estar en su tramo agrietado.
	# Se mira en un paquete aparte para no romper el que sigue el test.
	var roto: TableElement = g._spawn_pack("cards")
	await get_tree().process_frame
	roto.take_damage(roto.max_hp * 0.5)
	_check("a media resistencia el dibujo del paquete esta agrietado",
		roto._art != null and roto._art.texture == Sprites.tex("pack_cards_d1"))
	g._drop_element(roto)
	roto.queue_free()
	await get_tree().process_frame

	# --- el numero del dano ---
	# Al cerrarse el aro sale el numero del golpe ENCIMA del paquete, con la misma
	# pieza que los avisos de venta. Sin el Ojo verde la probabilidad de critico es
	# CERO, asi que este es un golpe normal y su numero tiene que salir en naranja.
	var pops := _popups(g._fx)
	_check("el golpe saca su numero de dano en la mesa", pops.size() >= 1)
	if not pops.is_empty():
		var num: PixelNumber = pops[pops.size() - 1]
		_check("y dice el dano que ha hecho el golpe",
			num.get_text() == PixelNumber.format(roundi(Game.damage_per_hit())))
		_check("un golpe normal sale en naranja",
			num.color == DamagePopup.NORMAL and num.color != DamagePopup.CRIT)
		_check("y el numero sale encima del paquete, no debajo de el",
			num.get_global_rect().get_center().y < el.get_global_rect().get_center().y)

	# Y UN CRITICO SALE EN AMARILLO, y mas grande. Para no depender de la suerte se
	# pone el Ojo verde AL TOPE y se le dan sesenta tiradas. El tope y el numero de
	# tiradas son parte del arreglo, no adorno: la probabilidad es de un 5 % POR
	# NIVEL (LootDB.CRIT_CHANCE_PER_LEVEL), asi que con el nivel 1 y treinta tiradas
	# esto fallaba una vez de cada cinco por pura mala suerte, que es la peor clase
	# de test (dice que el juego esta roto cuando el que tiene mala suerte es el que
	# lo mira). Al 8 son el 40 % y no fallar sale gratis: la probabilidad de que no
	# salga ninguno son 0,6^60. Y se golpea un paquete APARTE -el de arriba hay que
	# romperlo para seguir con el revelado- con la resistencia puesta por las nubes,
	# que asi aguanta las tiradas sin romperse.
	var crit_pop: PixelNumber = null
	var normal_pop: PixelNumber = null
	var crudo: TableElement = g._spawn_pack("cards")
	await get_tree().process_frame
	Game.items[LootDB.item_index("ojo_verde")] = 8
	_check("el Ojo verde enciende el critico", Game.crit_chance() > 0.0)
	var hp_guardada := crudo.hp
	crudo.hp = 1000000.0
	crudo.max_hp = 1000000.0
	for i in 60:
		crudo._strike()
		for p in _popups(g._fx):
			var n: PixelNumber = p
			if n.color == DamagePopup.CRIT and crit_pop == null:
				crit_pop = n
			elif n.color == DamagePopup.NORMAL and normal_pop == null:
				normal_pop = n
		if crit_pop != null and normal_pop != null:
			break
	_check("un golpe critico saca su numero en amarillo", crit_pop != null)
	_check("y su numero es el del critico, el doble que el del golpe normal",
		crit_pop != null and crit_pop.get_text() == PixelNumber.format(
				roundi(Game.damage_per_hit() * Game.crit_mult())))
	_check("el numero del critico es mas grande que el del golpe normal",
		crit_pop != null and normal_pop != null
		and crit_pop.scale_factor > normal_pop.scale_factor)
	Game.items[LootDB.item_index("ojo_verde")] = 0
	crudo.hp = hp_guardada
	crudo.max_hp = float(LootDB.pack_hp("cards"))
	g._drop_element(crudo)
	crudo.queue_free()
	await get_tree().process_frame

	# --- los items suben el dano y aceleran la carga ---
	var cero := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var d0 := LootDB.damage_per_hit(cero)
	var d1 := LootDB.damage_per_hit([3, 0, 0, 0, 0, 0, 0, 0, 0])
	_check("los items suben el dano", d1 > d0)
	_check("los items aceleran la carga",
			LootDB.charge_time([3, 0, 0, 0, 0, 0, 0, 0, 0]) < LootDB.charge_time(cero))
	# LOS GUANTES: el item de VELOCIDAD. Su 15 % por nivel tiene que notarse mas
	# que el 3 % que da cualquier otro nivel, o no seria el item de la velocidad
	# (ver LootDB.GLOVES_SPEED_PER_LEVEL).
	var gu := LootDB.item_index("guantes")
	var ti := LootDB.item_index("tijeras")
	var con_guantes: Array = cero.duplicate()
	con_guantes[gu] = 8
	var con_tijeras: Array = cero.duplicate()
	con_tijeras[ti] = 8
	_check("los Guantes aceleran la carga",
			LootDB.charge_time(con_guantes) < LootDB.charge_time(cero))
	_check("y aceleran mas que ocho niveles de cualquier otro item",
			LootDB.charge_time(con_guantes) < LootDB.charge_time(con_tijeras))
	_check("la ficha del Guante dice lo que da",
			LootDB.item_effect(gu, 1) == "+15% DE VELOCIDAD")
	# Y SU PRECIO: la misma escalera que las Tijeras -tres mejoras baratas que
	# suben poco y despues el salto- pero un poco mas caro.
	# LAS TRES PRIMERAS YA NO CUESTAN LO MISMO: cada una sube un 30 % sobre la
	# anterior, que es lo que se pidio para que subir el segundo nivel no se lea
	# como que el precio no se mueve. Pero sube POCO (x1,3, por debajo del x1,6
	# de la tienda) para no poner cuesta arriba el principio de partida.
	var gu1: int = LootDB.item_cost(gu, 1)
	var gu2: int = LootDB.item_cost(gu, 2)
	_check("cada una de las tres primeras mejoras del Guante cuesta mas que la de antes",
			gu1 > LootDB.item_cost(gu, 0) and gu2 > gu1)
	_check("pero suben poco: la tercera no llega al doble de la primera",
			gu2 < LootDB.item_cost(gu, 0) * 2)
	_check("y la cuarta se dispara sobre la tercera",
			LootDB.item_cost(gu, 3) > gu2 * 2.0)
	# Las Tijeras siguen la MISMA escalera: si alguien toca una y no la otra, el
	# dano y la velocidad dejan de poder compararse.
	var ti1: int = LootDB.item_cost(ti, 1)
	var ti2: int = LootDB.item_cost(ti, 2)
	_check("las Tijeras suben igual que los Guantes en las tres primeras",
			ti1 > LootDB.item_cost(ti, 0) and ti2 > ti1 and ti2 < LootDB.item_cost(ti, 0) * 2)
	_check("y su cuarta tambien se dispara",
			LootDB.item_cost(ti, 3) > ti2 * 2.0)
	_check("los Guantes son un poco mas caros que las Tijeras",
			LootDB.item_cost(gu, 0) > LootDB.item_cost(ti, 0)
			and LootDB.item_cost(gu, 0) <= LootDB.item_cost(ti, 0) * 2)
	_check("una caja necesita varios golpes",
			float(LootDB.pack_hp("cards")) / d0 >= 2.0)
	# El basico (215 de vida, precio cero: su vida va puesta a mano, no sale de
	# la curva) pide CINCO golpes con el dano base (45). Se mira en golpes y no
	# en el numero suelto para que la comprobacion siga diciendo algo si el dano
	# base cambia.
	_check("un sobre basico aguanta cinco golpes sin nada comprado (215 de vida)",
			ceili(float(LootDB.pack_hp("cards")) / d0) == 5)
	_check("el precio de un item normal sube con el nivel",
			LootDB.item_cost(1, 1) > LootDB.item_cost(1, 0))
	_check("el item tope no tiene precio", LootDB.item_cost(0, 99) < 0)
	# DOS CLASES DE ITEM. Los siete con niveles tienen ITEM_MAX_LEVEL niveles;
	# el PC y los Pinchos son de COMPRA UNICA (un nivel y ya), porque su efecto es
	# un si o un no: pagarlos ocho veces no tendria sentido.
	var pc_i := LootDB.item_index("pc")
	var pin_i := LootDB.item_index("pinchos")
	_check("el PC y los Pinchos son de compra unica: un nivel y ya",
			LootDB.item_max_level(pc_i) == 1 and LootDB.item_max_level(pin_i) == 1)
	_check("y por eso no se pueden pagar dos veces",
		LootDB.item_cost(pc_i, 0) > 0 and LootDB.item_cost(pc_i, 1) < 0)
	_check("los siete con niveles llegan hasta los ocho niveles",
		LootDB.item_max_level(0) == LootDB.ITEM_MAX_LEVEL)
	_check("el Ojo verde da critico", LootDB.crit_chance([0, 0, 0, 1, 0, 0, 0, 0, 0]) > 0.0)
	_check("el Laser sube el dano critico",
			LootDB.crit_mult([0, 0, 0, 0, 3, 0, 0, 0, 0]) > LootDB.crit_mult(cero))
	_check("el Cajon da mas huecos de mesa",
			LootDB.table_slots([0, 0, 1, 0, 0, 0, 0, 0, 0]) > LootDB.TABLE_BASE)

	# --- equilibrio ---
	# CUANTO DURA UNA PARTIDA. Es lo unico que no se puede comprobar mirando una
	# captura ni midiendo una pieza suelta -un precio, una vida-: sale de la partida
	# entera, y la mide dev/balance.gd (ver dev/README.md), que juega la partida
	# completa con las formulas y los datos de verdad. Aqui solo se llama a esa
	# herramienta, en su version SIN DADO (el botin puesto en su media), que es la
	# unica que da siempre el mismo numero y por tanto la unica que puede pasar por
	# un test sin volverse loca.
	#
	# La banda es ancha a proposito: esto es un guardia contra ROMPER la partida
	# -que se acabe en dos minutos o que no se acabe nunca-, no un ajuste fino. El
	# numero fino (la mediana de veinticinco partidas, el 80 % central, lo que
	# cuesta cada sobre) esta en el informe de la herramienta.
	var bal = load("res://dev/balance.gd").new()
	var normal: float = bal.fixed_minutes(0)
	var optimo: float = bal.fixed_minutes(1)
	var automatico: float = bal.fixed_minutes(2)
	_check("el jugador normal llega al primer rebirth en la banda (de 12 a 19 min): %.1f"
			% normal,
		normal >= 12.0 and normal <= 19.0)
	# El margen era de TRES minutos cuando el ritmo lo ponia el clic; con la barra
	# a 1,65 s el cuello de botella pasa a ser la CARGA, que la pagan los dos
	# igual (los Guantes son para todos), asi que la diferencia se queda en algo
	# mas de dos minutos. Lo que se exige sigue siendo lo que importa: que jugar
	# rapido y comprar bien llegue ANTES.
	_check("el que juega rapido y compra bien llega antes que el normal (%.1f contra %.1f)"
			% [optimo, normal],
		optimo < normal)
	_check("y con el PC y los Pinchos, antes que el que hace clic (%.1f contra %.1f)"
			% [automatico, optimo],
		automatico <= optimo)
	bal.free()

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

	# --- vender desde el panel del armario ---
	# El inventario YA NO esta en la pantalla de partida: vive en el panel del
	# armario (ver LockerPanel), que es el unico sitio desde el que se vende. Se
	# abre con el mismo metodo que llama su boton y se vende todo lo guardado.
	g._open_locker()
	await get_tree().process_frame
	var armario = g._locker
	_check("el boton del armario abre su panel", armario != null)
	var money_inv: int = Game.money
	if armario != null:
		armario._sell_all()
	await _wait(0.3)
	_check("lo guardado se puede vender", Game.inventory.is_empty())
	_check("vender del inventario suma el valor", Game.money > money_inv)
	if armario != null:
		g._close_locker()
		await get_tree().process_frame
	_check("y el panel del armario se cierra", g._locker == null)

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
	# abriendo seguiria ocupando un hueco de la mesa sin estar ya en ella.
	Game.items[LootDB.item_index("tijeras")] = 1
	var a_medias: TableElement = g._spawn_pack("cards")
	g._on_open_requested(a_medias)
	_check("un paquete a medias ocupa su hueco del turno", g._worked.size() == 1)
	g._sell_all_table()
	# VENDER solo vende BOTIN: un sobre (cerrado o a medio abrir) se queda en la
	# mesa, en la lista y con su turno. Antes se soltaba de la lista pero seguia
	# dibujado, y la mesa contaba un hueco libre que no tenia.
	_check("vender todo no toca los sobres de la mesa",
		g._elements.has(a_medias) and g.table_count() == 1)
	_check("y el que se estaba abriendo conserva su turno", g._worked.has(a_medias))
	# Se quita de la mesa a mano, por el camino de siempre, para que no siga
	# cargando por detras.
	g._drop_element(a_medias)
	a_medias.queue_free()
	_check("y al salir de la mesa suelta el turno", g._worked.is_empty())
	Game.items[LootDB.item_index("tijeras")] = 0
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
	# REPARTIDOS Y CON AIRE: dos objetos no pueden caer uno encima de otro. Antes
	# cada uno caia en un punto sorteado entre 40 y en las capturas se veian tres
	# apilados en un rincon teniendo media mesa vacia al lado, con los dibujos
	# comiendose entre si (ver _free_spot()). Se mira la caja de cada uno, que es
	# un poco mas grande que su dibujo: si las cajas no se tocan, los dibujos
	# tampoco y ademas queda aire entre ellos.
	var apilados := 0
	var colgando := 0
	for i in g._elements.size():
		var caja: Rect2 = Rect2(g._elements[i].spot(), TableElement.BOX)
		if not g.TABLE_RECT.encloses(caja):
			colgando += 1
		for j in range(i + 1, g._elements.size()):
			if caja.intersects(Rect2(g._elements[j].spot(), TableElement.BOX)):
				apilados += 1
	_check("los ocho objetos de la mesa no se pisan entre ellos", apilados == 0)
	_check("y ninguno se sale de la mesa", colgando == 0)
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
	Game.items = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
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

	# Y con la apertura encendida la mesa se abre sola. Los Pinchos NO pegan una
	# cantidad fija: pegan una fraccion del ritmo de golpes del jugador
	# (LootDB.SPIKE_SHARE) REPARTIDA entre los paquetes de la mesa, asi que el
	# ritmo depende de lo que lleve comprado. Con el dano base son unos 13 por
	# segundo entre los tres sobres, y el basico tiene 150 de vida: la mesa tarda
	# unos veinte segundos. Se espera de sobra y se deja la autoventa puesta para
	# que no salte la tarjeta de revelado, que para el reloj.
	await _empty_table(g)
	for k in 3:
		g._spawn_pack("cards")
	var opened_before: int = Game.packs_opened
	Game.set_auto_sell(true)
	Game.set_auto_open(true)
	await _wait(25.0)
	_check("la apertura automatica abre la mesa sola",
		Game.packs_opened > opened_before)
	Game.set_auto_open(false)
	Game.set_auto_sell(false)
	await _wait(0.4)
	await _empty_table(g)

	# --- el cupo de paquetes a la vez es el de la mesa, sin comprar nada ---
	Game.items[LootDB.item_index("tijeras")] = 0
	var uno: TableElement = g._spawn_pack("electronics3")
	var dos: TableElement = g._spawn_pack("electronics3")
	g._on_open_requested(uno)
	_check("el paquete pulsado empieza a abrirse", uno.is_opening())
	_check("sin comprar nada ya caben varios paquetes a la vez", Game.open_count() > 1)
	g._on_open_requested(dos)
	_check("el segundo tambien arranca a la vez", dos.is_opening())
	_check("el que ya estaba abriendose sigue", uno.is_opening())

	# --- caben VARIOS PAQUETES A LA VEZ, pero un clic arranca UNO ---
	# Es la diferencia con lo que habia antes: un clic NO abria varios de golpe.
	# Lo que sube con el Cajon es cuantos paquetes caben cargando al mismo tiempo,
	# y el jugador tiene que ir pulsando uno y otro para que avancen todos;
	# machacar el mismo no adelanta mas que el suyo. Ver _on_open_requested().
	Game.items[LootDB.item_index("cajon")] = 1
	await _empty_table(g)
	var lote: Array = []
	for k in 8:
		lote.append(g._spawn_pack("electronics3"))
	_check("con el Cajon el cupo es el maximo (10) y la mesa lo limita", Game.open_count() == 10)
	g._on_open_requested(lote[0])
	_check("y un clic arranca UN paquete, no varios",
		_cuantos_abriendo(g) == 1)
	_check("y el que NO se ha pulsado sigue quieto",
		not (lote[1] as TableElement).is_opening())
	for k in [1, 2, 3, 4, 5, 6, 7]:
		g._on_open_requested(lote[k])
	_check("pulsando cada uno, los ocho huecos cargan a la vez",
		_cuantos_abriendo(g) == 8)
	_check("la mesa tiene ocho huecos por defecto",
		Game.table_slots() == 10 and g._worked.size() == 8)
	# Y al soltar uno, su hueco queda libre para el que esperaba.
	g._remove_from_table(lote[0])
	await get_tree().process_frame
	g._on_open_requested(lote[5])
	_check("y al soltar uno, el que esperaba entra",
		(lote[5] as TableElement).is_opening())
	Game.items[LootDB.item_index("cajon")] = 0

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
	# LAS TIJERAS (item 0) no siguen la escalera general: las tres primeras
	# mejoras suben poco (x1,3) y solo a partir de la cuarta el precio se
	# dispara. El check de arriba ("el dano sube") ya miro que el nivel subia;
	# aqui se mira la ESCALERA, que es la parte que se pidio.
	var base_ti: int = int(LootDB.item_by_id("tijeras")["base_cost"])
	_check("la segunda mejora de las Tijeras cuesta mas que la primera, pero poco",
			cost2 > base_ti and cost2 < int(round(float(base_ti) * 1.5)))
	shop2._on_item(0)
	_check("y se cobra", Game.item_level(0) == 2 and Game.money == money_item - cost2)
	# Y en cuanto se pasa de las tres primeras el precio si se dispara: es la otra
	# mitad de la regla, y sin ella el item seria barato toda la partida. Con el
	# nivel 3 (tres compras) el siguiente nivel ya es la cuarta mejora, que es la
	# primera cara.
	Game.money = 100000000
	shop2._on_item(0)
	var cost5 := Game.item_cost(0)
	_check("a partir de la cuarta el precio de las Tijeras se dispara",
		Game.item_level(0) == 3 and cost5 > cost2 * 2)
	var money_paid: int = Game.money
	g._buy_pack("electronics")
	await _wait(1.0)
	_check("se puede comprar un paquete caro", g.table_count() == 1)
	_check("un sobre de pago si cobra",
		Game.money == money_paid - int(LootDB.pack_by_id("electronics")["price"]))

	# Y se compra DESDE LA PROPIA FICHA, que es para lo que esta: con los numeros
	# delante (lo que tienes y lo que tendras) y a un clic. Lo que hace la ficha es
	# PEDIR la compra; el que cobra es la tienda, asi que tiene que costar y avisar
	# igual que comprando desde la caja.
	var capas2: int = _main._overlay_host.get_child_count()
	shop2._open_card(1)
	await get_tree().process_frame
	var ficha2 = shop2._card
	_check("la ficha se abre tambien con dinero de sobra", ficha2 != null)
	if ficha2 != null:
		var nivel_antes: int = Game.item_level(1)
		var antes := _etiqueta(ficha2, "AHORA:")
		var money_ficha: int = Game.money
		var coste_ficha := Game.item_cost(1)
		var boton := _boton_de(ficha2, "COMPRAR")
		if boton != null:
			boton.pressed.emit()
		await get_tree().process_frame
		_check("comprar desde la ficha sube el nivel",
			Game.item_level(1) == nivel_antes + 1)
		_check("y cuesta lo mismo que comprar desde la caja",
			Game.money == money_ficha - coste_ficha)
		# Los numeros se repintan solos al subir el nivel (la ficha escucha
		# Game.items_changed): es lo que se le pide a una ficha de mejoras.
		var despues := _etiqueta(ficha2, "AHORA:")
		_check("y los numeros de la ficha cambian con el nivel",
			despues != "" and despues != antes
			and despues == "AHORA: " + LootDB.item_effect(1, Game.item_level(1)))
		_check("y sigue enseñando el del nivel siguiente",
			_etiqueta(ficha2, "NIVEL %d:" % (Game.item_level(1) + 1))
			== "NIVEL %d: " % (Game.item_level(1) + 1)
			+ LootDB.item_effect(1, Game.item_level(1) + 1))
	# Y NO SOLO UNA: la ficha de los DIEZ items, una por una. La captura
	# 04b solo puede enseñar una, y el fallo que se escapa con una sola es justo el
	# que no se ve: una ficha que enseña el nombre o el numero de OTRO item (los
	# cuatro sitios donde se lee el indice se cruzan con facilidad), o una
	# descripcion larga que se sale de la columna de texto.
	# La ficha del Trebol de arriba sigue abierta: hay que cerrarla, o _open_card()
	# no abre la siguiente y el bucle leeria la del Trebol en vez de la de cada item.
	shop2._close_card()
	await get_tree().process_frame
	var malas_fichas: Array = []
	for i in LootDB.item_count():
		shop2._open_card(i)
		await get_tree().process_frame
		var ficha_i = shop2._card
		if ficha_i == null:
			malas_fichas.append("item %d: no abre" % (i + 1))
			continue
		var item_i: Dictionary = LootDB.item_at(i)
		if not _dice(ficha_i, str(item_i["name"])):
			malas_fichas.append("item %d: no lleva su nombre (%s)"
					% [i + 1, str(item_i["name"])])
		var suyo := "AHORA: " + LootDB.item_effect(i, Game.item_level(i))
		if _etiqueta(ficha_i, "AHORA:") != suyo:
			malas_fichas.append("item %d: el numero de AHORA no es el suyo (dice \"%s\" y son \"%s\")"
					% [i + 1, _etiqueta(ficha_i, "AHORA:"), suyo])
		for linea in UIKit.wrap(str(item_i["detail"]), ItemCard.COL_W, 21):
			if not _dice(ficha_i, str(linea)):
				malas_fichas.append("item %d: le falta la linea \"%s\""
						% [i + 1, str(linea)])
		for f in _fuera(ficha_i, PANEL):
			malas_fichas.append("item %d: se sale del panel %s" % [i + 1, str(f)])
		# Y el texto no encima del DIBUJO, que es el fallo que se colo aqui: la
		# descripcion larga se dibujaba sobre el objeto.
		_check_sin_pisar_dibujos("la ficha del item %d no dibuja el texto encima del objeto"
				% (i + 1), ficha_i)
		shop2._close_card()
		await get_tree().process_frame
	_check("las diez fichas son de su item, con su nombre, su descripcion y su numero",
		malas_fichas.is_empty())
	for f in malas_fichas:
		print("         ficha: ", f)

	# Y la ficha NO deja rastro al cerrarse: la capa de encima vuelve a tener
	# exactamente los mismos hijos que antes de abrirla.
	shop2._open_card(0)
	await get_tree().process_frame
	shop2._close_card()
	await get_tree().process_frame
	_check("y al cerrarla no se queda colgada encima de la mesa",
		_main._overlay_host.get_child_count() == capas2)
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
	# Se compran todos menos el ULTIMO (LOS GUANTES), que se queda un nivel por
	# debajo de su tope a proposito: es el item con el precio mas largo de la
	# tienda, y con todas compradas no quedaria ni una chapa de precio que medir.
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
		# que marcar) y los ocho en los que suben de nivel.
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

	# La ficha de un item que ya no se puede subir mas: donde estaria el boton dice
	# AL TOPE, y no hay ni chapa de precio ni nada que pulsar. Y el numero de AHORA
	# sigue estando, que es lo que se ha comprado.
	shop3._open_card(1)
	await get_tree().process_frame
	var ficha3 = shop3._card
	_check("la ficha de un item al tope lo dice y no trae boton",
		ficha3 != null and _dice(ficha3, "AL TOPE")
		and _boton_de(ficha3, "COMPRAR") == null
		and ficha3.find_child("Tag", true, false) == null)
	_check("y sigue enseñando el numero que tiene",
		ficha3 != null and _etiqueta(ficha3, "AHORA:")
		== "AHORA: " + LootDB.item_effect(1, Game.item_level(1)))
	_check_cabe("la ficha al tope no saca texto del panel", ficha3, PANEL)
	shop3._close_card()
	await get_tree().process_frame
	shop3._open_card(LootDB.item_index("pc"))
	await get_tree().process_frame
	_check("la ficha del PC comprado dice COMPRADO",
		shop3._card != null and _dice(shop3._card, "COMPRADO"))
	shop3._close_card()
	await get_tree().process_frame
	shop3._close()
	await get_tree().process_frame

	# --- el armario: exponer, huecos y bonus ---
	# El armario es un TRATO con vuelta atras: el objeto sale del inventario (deja
	# de poder venderse), entra en una vitrina y da el bonus de SU tipo. Aqui se
	# comprueba el trato entero, que es lo que no se ve en una captura: lo que
	# sale de un sitio, lo que entra en el otro, lo que sube el stat y que los
	# huecos son los del nivel comprado.
	Game.money = 100000000
	Game.inventory.clear()
	Game.locker.clear()
	Game.items[LootDB.item_index("armario")] = 2
	var rng_arm := RandomNumberGenerator.new()
	var carta10 := LootDB.roll_item(rng_arm, "cards")
	carta10["grade"] = LootDB.GRADE_MAX
	carta10["value"] = LootDB.final_value(carta10, LootDB.GRADE_MAX)
	carta10["art"] = LootDB.art_for(carta10, LootDB.GRADE_MAX)
	Game.store(carta10)
	# DOS objetos mas, para poder llenar los dos huecos y comprobar que el tercero
	# NO entra: los huecos son la unica razon de subir el armario de nivel.
	for i in 2:
		var extra := LootDB.roll_item(rng_arm, "vinyls")
		extra["grade"] = LootDB.PSA_MIN
		extra["value"] = LootDB.final_value(extra, LootDB.PSA_MIN)
		extra["art"] = LootDB.art_for(extra, LootDB.PSA_MIN)
		Game.store(extra)
	_check("el armario empieza con los huecos que dice su nivel", Game.locker_slots() == 2)
	g._open_locker()
	await get_tree().process_frame
	var arm = g._locker
	_check("el boton del armario abre su panel", arm != null)
	if arm != null:
		_check("y trae los %d huecos del inventario" % Game.INVENTORY_SLOTS,
			arm._inv_cells.size() == Game.INVENTORY_SLOTS)
		_check("y los ocho marcos del tope del armario",
			arm._locker_cells.size() == LootDB.LOCKER_SLOTS_MAX)
		var dano_antes: float = Game.damage_per_hit()
		var inv_antes: int = Game.inventory.size()
		# Exponer es pulsar el objeto en la rejilla de la izquierda.
		arm._inv_cells[0]["button"].pressed.emit()
		await get_tree().process_frame
		_check("exponer saca el objeto del inventario",
			Game.inventory.size() == inv_antes - 1)
		_check("y lo mete en el armario", Game.locker.size() == 1)
		# La nota PSA manda en el bonus: la 10 da el tope de LootDB y la 1 el minimo.
		_check("una carta de nota 10 da el tope del bonus",
			is_equal_approx(Game.kind_bonus("cards"), LootDB.KIND_BONUS_MAX))
		_check("y la misma carta con nota 1 daria el minimo",
			is_equal_approx(LootDB.bonus_for({"kind": "cards", "grade": 1}),
				LootDB.KIND_BONUS_MIN))
		_check("y el dano del golpe sube con ella",
			is_equal_approx(Game.damage_per_hit(),
				dano_antes * (1.0 + LootDB.KIND_BONUS_MAX)))
		# Cada tipo va a lo suyo y no todo al dano: son cuatro stats distintos.
		_check("las zapatillas dan velocidad",
			str(LootDB.kind_row("sneakers")["stat"]) == "VELOCIDAD")
		_check("los vinilos dan dinero",
			str(LootDB.kind_row("vinyls")["stat"]) == "DINERO")
		_check("la electronica da rebirth",
			str(LootDB.kind_row("electronics")["stat"]) == "REBIRTH")
		# Los huecos son los del nivel: con dos, el tercero no entra y el objeto se
		# queda donde estaba (no se pierde por pulsar).
		arm._inv_cells[0]["button"].pressed.emit()
		await get_tree().process_frame
		_check("con los dos huecos llenos cabe un segundo objeto", Game.locker.size() == 2)
		arm._inv_cells[0]["button"].pressed.emit()
		await get_tree().process_frame
		_check("y el tercero ya no entra",
			Game.locker.size() == 2 and Game.inventory.size() == 1)
		# La vitrina de la pantalla de partida enseña lo que hay expuesto.
		_check("la vitrina de la partida enseña el objeto expuesto",
			g._locker_slots[0]["holder"].get_child_count() > 1)
		_check("y su rotulo cuenta los huecos",
			g._locker_label.text == "ARMARIO %d/%d EXPUESTOS" % [Game.locker_size(),
				Game.locker_slots()])
		# Devolverlo lo saca de la vitrina: exponer no puede ser sin vuelta atras.
		arm._locker_cells[0]["button"].pressed.emit()
		await get_tree().process_frame
		_check("pulsar un objeto expuesto lo devuelve al inventario",
			Game.locker.size() == 1 and Game.inventory.size() == 2)

		# --- VENDER UNO: el clic derecho ---
		# VENDER TODO es todo o nada. El inventario es donde se guarda lo que
		# todavia no se ha decidido (se vende el barato y se expone el bueno), asi
		# que el clic derecho vende el objeto de ESE hueco y solo ese. Se monta un
		# inventario de dos objetos CONOCIDOS y distintos, para poder decir cual de
		# los dos se ha ido.
		Game.inventory.clear()
		var rico := LootDB.roll_item(rng_arm, "cards")
		rico["grade"] = LootDB.GRADE_MAX
		rico["value"] = LootDB.final_value(rico, LootDB.GRADE_MAX)
		rico["art"] = LootDB.art_for(rico, LootDB.GRADE_MAX)
		var barato := LootDB.roll_item(rng_arm, "vinyls")
		barato["grade"] = LootDB.PSA_MIN
		barato["value"] = LootDB.final_value(barato, LootDB.PSA_MIN)
		barato["art"] = LootDB.art_for(barato, LootDB.PSA_MIN)
		Game.store(rico)
		Game.store(barato)
		await get_tree().process_frame
		_check("la rejilla del inventario trae los dos objetos",
			Game.inventory.size() == 2)
		var plata_uno: int = Game.money
		arm._sell_one(0)
		await get_tree().process_frame
		_check("vender uno saca UN objeto del inventario", Game.inventory.size() == 1)
		_check("y se lleva el de ese hueco, no otro",
			str(Game.inventory[0].get("name", "")) == str(barato.get("name", "")))
		# Paga el MISMO valor que el hueco estaba enseñando: la casilla no puede
		# decir una cifra y cobrar otra.
		_check("y paga el valor que enseñaba el hueco",
			Game.money == plata_uno + int(rico["value"]))
		_check("sin tocar lo expuesto en el armario", Game.locker.size() == 1)
		# Un hueco vacio no cobra: vender fuera de la rejilla no hace nada.
		var plata_dos: int = Game.money
		arm._sell_one(Game.inventory.size())
		_check("vender un hueco vacio no cobra nada", Game.money == plata_dos)
		# Y el gesto hay que PODER DESCUBRIRLO: en la casilla no se ve, asi que
		# esta en la leyenda de la columna y en el tooltip de cada hueco.
		_check("la columna trae la leyenda de los dos gestos",
			_dice(arm, "CLIC: EXPONER - CLIC DERECHO: VENDER UNO"))
		_check("y el tooltip del hueco dice por cuanto se vende",
			arm._inv_cells[0]["button"].tooltip_text.contains("clic derecho: vender por "))
		Game.inventory.clear()
		await get_tree().process_frame

		_check_cabe("el panel del armario no saca texto del panel", arm, PANEL)
		_check_sin_encimarse("el panel del armario no pone texto encima de una chapa", arm)
		_check_sin_pisar_dibujos("el panel del armario no dibuja el texto encima de un objeto", arm)
		g._close_locker()
		await get_tree().process_frame
	_check("y el panel del armario se cierra", g._locker == null)
	_check("la tira de la vitrina trae los ocho huecos del tope",
		g._locker_slots.size() == LootDB.LOCKER_SLOTS_MAX)
	# El inventario de la pantalla de partida se ha quitado a proposito: vive en el
	# panel del armario, que es donde se decide que se expone y que se vende.
	_check("el inventario ya no vive en la pantalla de partida",
		not g.has_method("_refresh_inventory") and Game.INVENTORY_SLOTS == 50)

	# --- el armario con objetos de la TIRADA DE VERDAD ---
	# Lo de arriba expone objetos armados a mano (roll_item + nota forzada), que es
	# como se comprueban las formulas. Pero lo que le llega al jugador sale de
	# roll_pack(), que arma un diccionario NUEVO con los campos que usa la
	# interfaz: ahi se quedo fuera "kind", kind_of() cayo en su valor por defecto
	# ("cards") y todos los objetos expuestos subian el DANO. Ningun check lo
	# cazaba porque todos miraban la formula, no la tirada que la alimenta.
	var rng_tipo := RandomNumberGenerator.new()
	for paquete in LootDB.kind_ids():
		_check("la tirada de %s viaja con su tipo" % paquete,
			LootDB.kind_of(LootDB.roll_pack(rng_tipo, str(paquete))) == str(paquete))

	# Y CADA TIPO MUEVE SU STAT Y SOLO EL SUYO. Es lo que el jugador ve al exponer
	# una zapatilla y luego un vinilo: si los dos suben el dano, el armario no
	# tiene nada que decidir.
	Game.inventory.clear()
	Game.locker.clear()
	var dano_base: float = Game.damage_per_hit()
	Game.store(LootDB.roll_pack(rng_tipo, "sneakers"))
	var carga_base: float = Game.charge_time()
	Game.locker_put(0)
	_check("una zapatilla expuesta acelera la carga", Game.charge_time() < carga_base)
	_check("y no toca el dano", is_equal_approx(Game.damage_per_hit(), dano_base))
	Game.inventory.clear()
	Game.locker.clear()
	Game.store(LootDB.roll_pack(rng_tipo, "vinyls"))
	var valor_base: float = Game.value_multiplier()
	Game.locker_put(0)
	_check("un vinilo expuesto sube el valor de lo que se vende",
		Game.value_multiplier() > valor_base)
	_check("y tampoco toca el dano", is_equal_approx(Game.damage_per_hit(), dano_base))
	Game.inventory.clear()
	Game.locker.clear()

	# --- guardado ---
	Game.save_game()
	_check("el fichero de guardado existe", FileAccess.file_exists(Game.SAVE_PATH))

	# --- rebirth: la hucha ---
	# UNA SOLA CUENTA: EL CONTADOR. Tanto el REQUISITO para poder reiniciar como LAS
	# MONEDAS que da se miran sobre el dinero que hay EN ESE MOMENTO (ver
	# Game.can_rebirth y Game.pending_rebirth_coins), asi que guardarlo adelanta el
	# reinicio Y sube el premio, y gastarlo aleja las dos cosas. Antes eran dos
	# numeros de sitios distintos -lo ganado para el requisito, el contador para el
	# premio- y esa es justo la confusion que se quito: se pedia un requisito que no
	# era el dinero que el jugador tenia delante.
	#
	# LA CHAPA VIVE EN LA BARRA DE LA PARTIDA, al lado de la tienda, y el menu ya no
	# sabe nada de ella: el rebirth se hace JUGANDO, no se mira antes de empezar.
	# Se comprueba por los dos lados.
	Game.inventory.clear()
	Game.locker.clear()
	for i in Game.items.size():
		Game.items[i] = 0
	Game.rebirth_coins = 0
	Game.money = Game.START_MONEY
	_check("con el contador vacio el rebirth da la moneda minima",
		Game.pending_rebirth_coins() == 1)
	# LO GANADO NO CUENTA: se puede haber ganado la partida entera y no llegar ni al
	# requisito ni a mas monedas si el dinero no esta en el contador. Es el check que
	# distingue las dos formas de contar, y el que se romperia volviendo a mirar
	# lifetime_earned.
	Game.lifetime_earned = LootDB.REBIRTH_REQUIRE * 100
	_check("y lo ganado no da monedas ni deja reiniciar si no esta en el contador",
		not Game.can_rebirth() and Game.pending_rebirth_coins() == 1)
	Game.money = LootDB.REBIRTH_REQUIRE - 1
	_check("con el contador a una unidad del requisito todavia no se puede",
		not Game.can_rebirth() and Game.rebirth_missing() == 1)
	Game.money = LootDB.REBIRTH_REQUIRE
	_check("con el requisito en el contador ya se puede reiniciar",
		Game.can_rebirth() and Game.rebirth_missing() == 0
		and Game.pending_rebirth_coins() == 1)
	Game.money = LootDB.REBIRTH_COIN_AT * 8 + LootDB.REBIRTH_COIN_AT / 2
	_check("una moneda por cada 1,5 M del contador (8 con 12,5 M)",
		Game.pending_rebirth_coins() == 8)
	_check("y sin armario el multiplicador del rebirth es 1",
		is_equal_approx(Game.rebirth_multiplier(), 1.0))
	# La ELECTRONICA expuesta es lo unico que sube el premio del rebirth: por eso
	# el tipo de cada objeto importa y no todos dan lo mismo.
	var chip := LootDB.roll_item(RandomNumberGenerator.new(), "electronics")
	chip["grade"] = LootDB.GRADE_MAX
	Game.locker.append(chip)
	_check("la electronica expuesta sube el multiplicador del rebirth",
		is_equal_approx(Game.rebirth_multiplier(), 1.0 + LootDB.KIND_BONUS_MAX))
	Game.money = LootDB.REBIRTH_COIN_AT * 10
	_check("y con quince millones en el contador da mas monedas que sin ella",
		Game.pending_rebirth_coins() > 10
		and Game.pending_rebirth_coins()
			== LootDB.rebirth_coins_for(Game.money, Game.rebirth_multiplier()))
	# La chapa de la barra: abre el panel de la hucha, y lo abre TAMBIEN cuando la
	# partida todavia no da para reiniciarla (entonces el panel es el que dice
	# cuanto falta, que es lo unico util). El estado se pone a mano porque asignar
	# el dinero no emite nada: en el juego lo mueven add_money y spend.
	Game.rebirth_coins = 0
	Game.money = 0
	g._refresh_rebirth()
	await get_tree().process_frame
	_check("la chapa del rebirth esta en la barra de la partida",
		g._rebirth_btn != null)
	_check("y sale apagada cuando la partida no da para reiniciarla",
		g._rebirth_btn.modulate != Color.WHITE and not Game.can_rebirth())
	g._rebirth_btn.pressed.emit()
	await get_tree().process_frame
	var hucha = g._rebirth
	_check("el clic abre el panel aunque no se pueda reiniciar", hucha != null)
	if hucha != null:
		# ESTA ES LA CARA QUE SE VE CASI SIEMPRE: el panel SIN poder reiniciar
		# todavia, con la linea de lo que falta. Y es el estado en el que hay que
		# medirlo, porque en el otro esa linea esta VACIA.
		#
		# El check de encuadre de mas abajo se hacia solo con el requisito
		# cumplido, o sea con `_missing.text == ""`: una etiqueta sin texto mide 0
		# de ancho, asi que _check_cabe() la saltaba sin decir nada. Y esa es justo
		# la linea mas larga de la pantalla (47 caracteres) y la unica que cruza el
		# panel de lado a lado: abierta de verdad se dibujaba 114 px FUERA del marco
		# por la derecha, centrada en la columna de los numeros en vez de con el
		# panel. Un check de encuadre tiene que correr en el estado que el jugador
		# va a ver, no en el que le deja el test.
		_check("el panel dice lo que falta cuando no se puede reiniciar",
			hucha._missing.text.begins_with("TE FALTAN"))
		# Y LO QUE FALTA ES DEL DINERO QUE TIENES, no de lo ganado en la partida:
		# el requisito compara con el contador (ver LootDB.REBIRTH_REQUIRE), asi
		# que la nota que lo explica tiene que hablar de lo que hay ahora. Estuvo
		# diciendo "DE LO GANADO EN LA PARTIDA", que es otra regla y descoloca al
		# que mira el numero que tiene delante en la barra.
		_check("y la nota dice que es del dinero que tienes ahora",
			hucha._missing_note.text.contains("TENGAS AHORA")
				and not hucha._missing_note.text.contains("GANADO"))
		# LA MONEDA DE REBIRTH ES EL CERDO DORADO. Se pide el dibujo de la hucha y
		# que NO este el de la moneda del dinero: la unidad del premio y la moneda de
		# los precios eran el mismo PNG, y por eso el rebirth se leia como calderilla.
		_check("la moneda del premio es el cerdo dorado, no la moneda del dinero",
			_usa_sprite(hucha, "currency_piggy")
				and not _usa_sprite(hucha, "currency_coin"))
		_check("y esa linea cabe en el marco del panel",
			PANEL.encloses(_visible(hucha._missing, true)))
		_check_cabe("el panel del rebirth no saca texto del panel ni sin el requisito",
			hucha, PANEL)
		hucha._close()
		await get_tree().process_frame
	_check("y el cerrar quita el panel", g._rebirth == null)

	# Y con el dinero del contador, la chapa se enciende y el panel enseña lo que te
	# llevarias.
	Game.money = LootDB.REBIRTH_REQUIRE * 3
	g._refresh_rebirth()
	_check("con el dinero del contador la chapa se enciende",
		g._rebirth_btn.modulate == Color.WHITE)
	g._rebirth_btn.pressed.emit()
	await get_tree().process_frame
	hucha = g._rebirth
	_check("y vuelve a abrir el panel de la hucha", hucha != null)
	if hucha != null:
		var premio: int = Game.pending_rebirth_coins()
		_check("el panel enseña las monedas que va a dar",
			hucha._coins.get_text() == PixelNumber.format(premio))
		_check_cabe("el panel del rebirth no saca texto del panel", hucha, PANEL)
		_check_sin_encimarse("el panel del rebirth no pone texto encima de una chapa", hucha,
			_franja_barra(hucha))
		_check_sin_pisar_dibujos("el panel del rebirth no dibuja el texto encima de la hucha",
			hucha, _franja_barra(hucha))
		var coins_antes: int = Game.rebirth_coins
		hucha._go.pressed.emit()
		await get_tree().process_frame
		_check("el rebirth da las monedas que prometia",
			Game.rebirth_coins == coins_antes + premio)
		_check("y el contador de la barra se repinta con las nuevas",
			g._rebirth_count.get_text() == PixelNumber.format(Game.rebirth_coins))
		_check("y la partida vuelve a empezar de cero",
			Game.money == Game.START_MONEY and Game.locker.is_empty()
			and Game.inventory.is_empty() and Game.item_level(0) == 0)
		_check("y el panel se cierra solo", g._rebirth == null)
	# --- el arbol de mejoras: las monedas se GASTAN ---
	#
	# LAS MONEDAS YA NO DAN NADA SOLAS. Antes cada una sumaba un 5 % al valor de
	# todo lo que vendias, para siempre, y el rebirth se acumulaba sin que hubiera
	# nada que decidir. Ahora son una moneda de verdad: se cambian por una mejora
	# del arbol (SkillTree) y hasta que se compra no dan nada. Este es el check que
	# vigila justo eso.
	for i in Game.items.size():
		Game.items[i] = 0
	Game.locker.clear()
	Game.inventory.clear()
	Game.skills = {}
	Game.rebirth_coins = 40
	_check("las monedas de rebirth ya no dan dinero por si solas",
		is_equal_approx(Game.value_multiplier(), 1.0)
		and is_equal_approx(Game.damage_multiplier(), 1.0)
		and is_equal_approx(Game.charge_multiplier(), 1.0)
		and Game.locker_slots() == 0 and is_equal_approx(Game.spike_dps(), 0.0))

	# La forma del arbol: UNA mejora en el centro y CUATRO caminos DIAGONALES,
	# uno por cada lado, enchufados al centro.
	# Dieciseis: el centro, cuatro caminos de los que tres siguen dos nodos mas
	# (dano, velocidad y Pinchos) y cinco INTERRUPTORES de calidad de vida en la
	# rama de abajo.
	_check("el arbol trae dieciseis mejoras", SkillTree.node_count() == 16)
	# LOS TRES CAMINOS QUE SIGUEN: cada anillo esta en SU diagonal (2 x SEP y
	# 3 x SEP) y cuelga del nodo de antes, asi que un camino se compra de arriba
	# abajo y no se puede empezar por el fondo.
	var cadenas_ok := true
	var cadenas_precio := true
	for par in [["damage", "damage_2", "damage_3"], ["speed", "speed_2", "speed_3"],
			["spikes", "spikes_2", "spikes_3"]]:
		for k in range(1, par.size()):
			var id_hijo := str(par[k])
			var id_padre := str(par[k - 1])
			var pos_hijo: Vector2 = SkillTree.node_by_id(id_hijo)["pos"]
			var pos_padre: Vector2 = SkillTree.node_by_id(id_padre)["pos"]
			if SkillTree.req_of(id_hijo) != id_padre \
					or pos_hijo != SkillTree.node_by_id(str(par[0]))["pos"] * float(k + 1) \
					or float(SkillTree.node_by_id(id_hijo)["value"]) \
						<= float(SkillTree.node_by_id(id_padre)["value"]):
				cadenas_ok = false
			if Game.skill_cost(id_hijo) != (SkillTree.COST_BRANCH2 if k == 1
					else SkillTree.COST_BRANCH3):
				cadenas_precio = false
	_check("y dano, velocidad y pinchos siguen dos nodos mas por su diagonal",
		cadenas_ok)
	_check("y cada anillo cuesta mas que el de antes, igual en los tres caminos",
		cadenas_precio and SkillTree.COST_BRANCH < SkillTree.COST_BRANCH2
		and SkillTree.COST_BRANCH2 < SkillTree.COST_BRANCH3)
	var diagonales := 0
	var cuelgan_del_centro := 0
	var interruptores: Array = []
	for id in SkillTree.ids():
		if str(id) == "money":
			continue
		if SkillTree.is_qol(str(id)):
			interruptores.append(str(id))
			continue
		var pos: Vector2 = SkillTree.node_by_id(str(id))["pos"]
		if absf(pos.x) == absf(SkillTree.SEP.x) and absf(pos.y) == absf(SkillTree.SEP.y):
			diagonales += 1
		if SkillTree.req_of(str(id)) == "money":
			cuelgan_del_centro += 1
	_check("y los cuatro caminos van en diagonal, uno en cada lado", diagonales == 4)
	_check("y los cuatro salen de la mejora del centro", cuelgan_del_centro == 4)
	# LA RAMA DE LA CALIDAD DE VIDA: cinco interruptores, todos por debajo del
	# centro y todos de UN NIVEL (pagar dos veces por tener los atajos no
	# significa nada). Sus ids son los que consulta el juego para saber si quitar
	# trabajo de encima, asi que si uno deja de existir, la mejora no hace nada y
	# no da ningun error: se mira aqui.
	_check("y debajo cuelgan cinco interruptores de calidad de vida",
		interruptores.size() == 5)
	var qol_abajo := true
	var qol_un_nivel := true
	var qol_precios: Array = []
	for id in interruptores:
		if float(SkillTree.node_by_id(str(id))["pos"].y) <= 0.0:
			qol_abajo = false
		if not is_equal_approx(float(SkillTree.levels_of(str(id))), 1.0):
			qol_un_nivel = false
		qol_precios.append(int(SkillTree.node_by_id(str(id))["cost"]))
	_check("y los cinco van por debajo del centro", qol_abajo)
	_check("y cada uno se compra una sola vez", qol_un_nivel)
	# Los cinco ids tienen que ser los que usa el juego, no otros: un id mal
	# escrito en la tabla seria una mejora que se paga y no hace nada.
	_check("y son los interruptores que el juego consulta",
		interruptores.has(SkillTree.QOL_KEYS) and interruptores.has(SkillTree.QOL_CHAFF)
		and interruptores.has(SkillTree.QOL_CARRY)
		and interruptores.has(SkillTree.QOL_TABLE)
		and interruptores.has(SkillTree.QOL_LOCKER))
	# Y EL PRECIO: baratos y en subida. Un interruptor cuesta menos que un camino
	# (+20 %) porque quita trabajo, no potencia; y el armario, que es el que mas
	# quita, es el caro de la rama.
	_check("y la rama entera cuesta doce monedas, de la mas barata a la mas cara",
		qol_precios.min() == SkillTree.COST_QOL_KEYS
		and qol_precios.max() == SkillTree.COST_QOL_LOCKER
		and Game.skill_cost(SkillTree.QOL_LOCKER) < SkillTree.COST_BRANCH * 2)
	_check("la del centro da un 30 % mas de dinero",
		is_equal_approx(float(SkillTree.node_by_id("money")["value"]), 0.30))
	_check("y los cuatro caminos cuestan lo mismo",
		Game.skill_cost("damage") == SkillTree.COST_BRANCH
		and Game.skill_cost("speed") == SkillTree.COST_BRANCH
		and Game.skill_cost("locker") == SkillTree.COST_BRANCH
		and Game.skill_cost("spikes") == SkillTree.COST_BRANCH)

	# CADA MEJORA TIENE SU TEXTO PARA LA FICHA, como los items de la tienda: una
	# linea corta y una explicacion larga. Se miran los CINCO y no el que se abra,
	# porque la ficha enseña el que se pulse: un texto que no cabe (mas de
	# DETAIL_LINES_MAX lineas) se dibuja ENCIMA de los numeros del AHORA y del
	# AL COMPRARLO y eso no da ningun error, solo una pantalla ilegible.
	var sin_texto: Array = []
	var textos_largos: Array = []
	var textos_anchos: Array = []
	for id_arbol in SkillTree.ids():
		if SkillTree.desc_of(str(id_arbol)) == "" \
				or SkillTree.detail_of(str(id_arbol)) == "":
			sin_texto.append(str(id_arbol))
		var lineas := UIKit.wrap(SkillTree.detail_of(str(id_arbol)),
				SkillCard.COL_W, 21).size()
		if lineas > SkillCard.DETAIL_LINES_MAX:
			textos_largos.append("%s (%d lineas)" % [str(id_arbol), lineas])
		if UIKit.text_width(SkillTree.desc_of(str(id_arbol)), 28) > SkillCard.COL_W:
			textos_anchos.append(str(id_arbol))
	# LA FUENTE DEL JUEGO ES DE MAPA DE BITS Y NO TIENE MINUSCULAS: una letra
	# minuscula no sale "en minuscula", sale un cuadro de basura. Y no lo ve
	# ninguno de los checks de encuadre, porque el texto CABE: se vio en la
	# captura de la ficha, con las cuatro lineas de explicacion ilegibles. Se mira
	# el TEXTO de los cinco nodos, y ademas lo que se dibuja en la ficha y en el
	# arbol, que es donde aparecen esas letras.
	var con_minusculas: Array = []
	for id_txt in SkillTree.ids():
		for texto in [SkillTree.desc_of(str(id_txt)), SkillTree.detail_of(str(id_txt)),
				SkillTree.effect_text(str(id_txt))]:
			if str(texto) != str(texto).to_upper():
				con_minusculas.append(str(texto))
	_check("el texto de las mejoras va en mayusculas (la fuente no tiene minusculas)",
		con_minusculas.is_empty())
	for m in con_minusculas:
		print("         con minusculas: ", m)
	# Y el signo del efecto se suma UNA vez: "+30 % DE DINERO", no "++30 %". Se
	# vio en la captura del arbol, escrito en los cinco nodos y sin romper nada.
	var con_doble: Array = []
	for id_efe in SkillTree.ids():
		if SkillTree.effect_text(str(id_efe)).begins_with("++"):
			con_doble.append(SkillTree.effect_text(str(id_efe)))
	_check("y el efecto lleva el signo una sola vez", con_doble.is_empty())
	_check("y cada mejora trae el texto de su ficha", sin_texto.is_empty())
	_check("y la explicacion de las cinco cabe en la ficha", textos_largos.is_empty())
	_check("y su linea corta tampoco se sale", textos_anchos.is_empty())
	for t in sin_texto + textos_largos + textos_anchos:
		print("         se sale de la ficha: ", t)

	# Y como se compra: primero el centro (una moneda), y los caminos no se abren
	# hasta tenerlo. Sin monedas no se compra nada.
	Game.rebirth_coins = 0
	_check("sin monedas no se compra el centro",
		not Game.can_buy_skill("money") and not Game.buy_skill("money")
		and not Game.skill_owned("money"))
	_check("y los caminos estan cerrados hasta comprar el centro",
		not Game.skill_unlocked("damage") and not Game.buy_skill("damage")
		and Game.skill_cost("damage") == SkillTree.COST_BRANCH)
	Game.rebirth_coins = 1
	_check("con una moneda se compra el centro", Game.buy_skill("money"))
	_check("y cuesta esa moneda", Game.rebirth_coins == 0)
	_check("y a partir de ahi todo vale un 30 % mas",
		is_equal_approx(Game.value_multiplier(), 1.30))

	# Los cuatro caminos, cada uno con lo suyo. Los Pinchos y el Armario son
	# piezas de la tienda y sin ellas no hay nada que medir (los Pinchos sin la
	# pieza pegan 0), asi que se compran antes de mirar los numeros.
	Game.items[LootDB.item_index("pinchos")] = 1
	Game.items[LootDB.item_index("armario")] = 2
	Game.rebirth_coins = SkillTree.COST_BRANCH * 4
	var dano_arbol0: float = Game.damage_per_hit()
	var carga_arbol0: float = Game.charge_time()
	var huecos_base: int = Game.locker_slots()
	var pinchos_base: float = Game.spike_dps()
	Game.buy_skill("damage")
	_check("el camino del dano da un 20 % mas de dano",
		is_equal_approx(Game.damage_multiplier(), 1.20)
		and is_equal_approx(Game.damage_per_hit(), dano_arbol0 * 1.20))
	Game.buy_skill("speed")
	_check("el de la velocidad, un 20 % mas de velocidad",
		is_equal_approx(Game.charge_multiplier(), 1.20)
		and is_equal_approx(Game.charge_time(), carga_arbol0 / 1.20))
	Game.buy_skill("locker")
	_check("el del armario, dos huecos mas para exponer",
		Game.locker_slots() == huecos_base + 2)
	Game.buy_skill("spikes")
	_check("y el de los pinchos, un 30 % mas de dano de pinchos",
		Game.spike_dps() > pinchos_base
		and is_equal_approx(Game.spike_dps(), pinchos_base * 1.30))
	_check("y las doce monedas se han gastado enteras", Game.rebirth_coins == 0)
	_check("y una mejora comprada no se puede comprar dos veces",
		Game.skill_cost("damage") < 0 and not Game.buy_skill("damage"))
	# Y EL ARBOL NO SUSTITUYE AL ARMARIO: las dos cosas multiplican lo mismo. Una
	# carta de nota maxima expuesta (un +25 %) con el camino del dano comprado
	# (un +20 %) tiene que dar el producto, no el mayor de los dos.
	var carta_psa10 := LootDB.roll_item(RandomNumberGenerator.new(), "cards")
	carta_psa10["grade"] = LootDB.GRADE_MAX
	Game.locker.clear()
	Game.locker.append(carta_psa10)
	_check("el dano del armario se multiplica con el del arbol",
		is_equal_approx(Game.damage_multiplier(), (1.0 + LootDB.KIND_BONUS_MAX) * 1.20))
	Game.locker.clear()

	# EL ARBOL NO SE PIERDE AL REINICIAR, y es lo que hace que reiniciar valga la
	# pena: las monedas se ganan reiniciando y se gastan en el arbol, asi que un
	# rebirth que se llevara las mejoras por delante seria pagar por nada. Las
	# piezas de la partida (el armario, los pinchos) si se van.
	Game.locker.clear()
	Game.locker.append(chip)
	# Con dos millones en el contador se pasa el requisito de sobra (que es lo que
	# se mira para poder reiniciar) y el premio son dos monedas.
	Game.money = LootDB.REBIRTH_COIN_AT * 2
	Game.do_rebirth()
	_check("el arbol de mejoras se queda al reiniciar la partida",
		Game.skill_owned("money") and Game.skill_owned("damage")
		and Game.skill_owned("speed") and Game.skill_owned("locker")
		and Game.skill_owned("spikes"))
	_check("y con el arbol la partida nueva sigue valiendo mas",
		is_equal_approx(Game.value_multiplier(), 1.30)
		and is_equal_approx(Game.damage_multiplier(), 1.20))
	_check("y las piezas de la partida si se pierden",
		Game.item_level(LootDB.item_index("armario")) == 0
		and Game.item_level(LootDB.item_index("pinchos")) == 0)
	_check("y los huecos del armario del arbol siguen ahi",
		Game.locker_slots() == 2)

	# --- el panel del arbol: el dibujo y los clics ---
	# Se abre SIN nada comprado y con monedas de sobra: es el estado en el que se
	# ve el arbol entero de una vez, con el centro en medio y los cuatro caminos
	# cerrados hasta que se compre la mejora del centro.
	Game.skills = {}
	Game.rebirth_coins = 12
	g._refresh_rebirth()
	g._open_rebirth()
	await get_tree().process_frame
	var arbol = g._rebirth
	_check("la chapa del rebirth abre el arbol", arbol != null)
	if arbol != null:
		_check("y el panel dibuja los dieciseis nodos",
			arbol._nodes.size() == SkillTree.node_count())
		# AL ABRIRLO SE VE LO DE SIEMPRE: el centro y los cuatro caminos, dentro del
		# marco y por DEBAJO de la barra del rebirth, que es lo unico fijo de la
		# pantalla. La rama de calidad de vida baja tres filas mas de lo que mide la
		# vista, asi que NO entra al abrir y se llega a ella arrastrando: eso se
		# comprueba en el bloque de abajo, porque es la mitad de como se usa.
		# Solo el PRIMER anillo: el arbol crece hacia fuera por la diagonal y lo
		# de fuera se alcanza arrastrando, que es justo para lo que esta el
		# arrastre (igual que la rama de calidad de vida, que baja tres filas).
		var dentro := true
		var debajo := true
		var primer_anillo: Array = ["money", "damage", "speed", "locker", "spikes"]
		for id in primer_anillo:
			var r: Rect2 = arbol.node_rect(str(id))
			if not PANEL.encloses(r):
				dentro = false
			if r.position.y < PANEL.position.y + arbol.BAR_H:
				debajo = false
		_check("el centro y los cuatro caminos caben en el panel nada mas abrirlo", dentro)
		_check("y ninguno se cuela debajo de la barra del rebirth", debajo)
		# LA RAMA DE ABAJO SE ALCANZA ARRASTRANDO. Se mueve el arbol por el mismo
		# camino que el raton (_set_offset, que es lo que llama el arrastre) y se
		# mira que sus cinco nodos entren en la vista del panel. Sin esto, la rama
		# nueva seria un dibujo que existe y no se puede tocar.
		var offset_ini: Vector2 = arbol._offset
		# NO ENTRA ENTERA al abrir (son tres filas de 320 y la vista mide 800): lo
		# que se mira es que haga falta arrastrar, o sea que alguno de sus nodos se
		# quede fuera. La primera fila si asoma, y eso es bueno: se ve que hay algo
		# mas abajo.
		var qol_fuera_al_abrir := 0
		for id in interruptores:
			if not PANEL.encloses(arbol.node_rect(str(id))):
				qol_fuera_al_abrir += 1
		_check("la rama de calidad de vida no entra entera al abrir el arbol",
			qol_fuera_al_abrir > 0)
		# Cada uno se lleva al centro de la vista por separado: la rama entera no
		# cabe de una vez (son tres filas de 320 y la vista mide 800), y lo que hay
		# que poder hacer es llegar a CUALQUIERA de ellos arrastrando, que es como
		# se usa un arbol mas alto que la ventana.
		var inalcanzables: Array = []
		for id in interruptores:
			var centro_nodo: Vector2 = SkillTree.node_by_id(str(id))["pos"]
			arbol._set_offset(Vector2(offset_ini.x,
				arbol.VIEW_SIZE.y * 0.5 - centro_nodo.y))
			if not PANEL.encloses(arbol.node_rect(str(id))):
				inalcanzables.append(str(id))
		_check("y arrastrando se llega a cada nodo de la rama", inalcanzables.is_empty())
		for m in inalcanzables:
			print("         no se alcanza: ", m)
		# Y CON LA RAMA A LA VISTA, sus rotulos se dibujan y no se salen: el mismo
		# check de encuadre que se le hace al resto del arbol, que arriba no la ve
		# porque la vista recorta lo que queda por debajo.
		arbol._set_offset(Vector2(offset_ini.x,
			arbol.VIEW_SIZE.y * 0.5 - float(SkillTree.node_by_id(SkillTree.QOL_TABLE)["pos"].y)))
		_check_cabe("la rama de calidad de vida no saca texto de la vista", arbol, PANEL)
		_check_sin_encimarse("y no pone texto encima de las chapas de la rama", arbol)
		# AQUI NO SE MIRA EL "TEXTO ENCIMA DE UN DIBUJO", y es a proposito: al bajar
		# el arbol, sus nodos pasan POR DEBAJO de la barra fija (asi esta hecho, la
		# barra va superpuesta y el arbol se cuela por debajo), asi que el check
		# encuentra los rotulos del saldo encima de las chapas que acaban de subir.
		# Eso no es una fuga: es la capa de arriba tapando lo que pasa por debajo.
		var raras_qol := _minusculas_en(arbol)
		_check("y sus rotulos no tienen letras minusculas", raras_qol.is_empty())
		for r in raras_qol:
			print("         con minusculas: ", r)
		# El arbol vuelve a donde estaba: los checks de abajo pulsan nodos y miden
		# el precio del DANO, que se colocan con el desplazamiento de apertura.
		arbol._set_offset(offset_ini)
		# Las posiciones no se guardan por duplicado en el panel: son las del
		# arbol, asi que lo que se comprueba es que el dibujo esta DONDE dice
		# SkillTree (si el panel se inventara sus coordenadas, esto falla).
		var colocado := true
		for id in SkillTree.ids():
			var quiero: Vector2 = SkillTree.node_by_id(str(id))["pos"]
			var centro: Vector2 = arbol._nodes[str(id)]["center"]
			if not centro.is_equal_approx(quiero):
				colocado = false
		_check("y cada nodo esta donde dice el arbol", colocado)
		# Y EL DIBUJO ENTERO (los nodos y sus rotulos, la caja de SkillTree) cabe
		# en la ventana del panel tal y como se abre: aqui, sin arrastrar nada.
		var vista_ini := Rect2(PANEL.position, arbol.VIEW_SIZE)
		var caben_los_cinco := true
		for id in primer_anillo:
			if not vista_ini.encloses(arbol.node_rect(str(id))):
				caben_los_cinco = false
		_check("y el centro y los cuatro caminos se ven de una vez al abrirlo",
			caben_los_cinco)
		# Y LOS ANILLOS DE FUERA NO SE VEN AL ABRIR, pero se llega a ellos
		# arrastrando: es lo mismo que se hace con la rama de calidad de vida, y
		# es la razon de que el arbol se pueda mover.
		var fuera_al_abrir := true
		for id in ["damage_3", "speed_3", "spikes_3"]:
			if vista_ini.encloses(arbol.node_rect(str(id))):
				fuera_al_abrir = false
		_check("y el fondo de los caminos queda fuera al abrir el arbol",
			fuera_al_abrir)
		var fondo_alcanzable := true
		for id in ["damage_3", "speed_3", "spikes_3"]:
			var pos_fondo: Vector2 = SkillTree.node_by_id(str(id))["pos"]
			# Centrado en los DOS ejes: el fondo se abre hacia los lados, asi que
			# llevar solo la y no lo dejaria a la vista.
			arbol._set_offset(arbol._clamp_offset(Vector2(
				arbol.VIEW_SIZE.x * 0.5 - pos_fondo.x,
				arbol.VIEW_SIZE.y * 0.5 - pos_fondo.y)))
			if not vista_ini.encloses(arbol.node_rect(str(id))):
				fondo_alcanzable = false
		_check("y arrastrando se llega al fondo de los tres caminos", fondo_alcanzable)
		arbol._set_offset(offset_ini)
		_check_cabe("el arbol no saca texto del panel", arbol, PANEL)
		var raras_arbol := _minusculas_en(arbol)
		_check("el arbol no tiene letras minusculas", raras_arbol.is_empty())
		for r in raras_arbol:
			print("         con minusculas: ", r)
		_check_sin_encimarse("el arbol no pone texto encima de una chapa", arbol,
			_franja_barra(arbol))
		_check_sin_pisar_dibujos("el arbol no dibuja texto encima de los nodos", arbol,
			_franja_barra(arbol))
		# EL PRECIO VA EN SU FILA, debajo del dibujo del nodo: el cerdito y su
		# numero, uno detras del otro. El numero lo coloca el panel a mano (mide lo
		# que ocupan sus cifras), asi que olvidarse de colocarlo lo deja en la
		# ESQUINA de la chapa, que es un sitio donde cabe y no se ve mal del todo:
		# eso paso, y por eso se comprueba la fila y no solo que quepa.
		var cerdo: Rect2 = _dibujo(arbol._nodes["damage"]["coin"])
		var precio: Rect2 = arbol._nodes["damage"]["cost"].get_global_rect()
		var chapa_dano: Rect2 = arbol.node_rect("damage")
		_check("el coste del nodo se dibuja en su fila: el numero detras del cerdito",
			precio.position.x > cerdo.end.x
			and absf(precio.get_center().y - cerdo.get_center().y) < 8.0
			and cerdo.position.y > chapa_dano.position.y + chapa_dano.size.y * 0.6)
		# Con el centro sin comprar, los cuatro caminos estan CERRADOS: pulsarlos
		# no cobra nada y su ficha dice cual hay que comprar antes.
		_check("sin el centro comprado los cuatro caminos estan cerrados",
			arbol._state_of("damage") == "locked"
			and arbol._state_of("spikes") == "locked"
			and arbol.link_color("damage") == arbol.LINK_DIM)
		# Y PULSAR UN NODO NO LO COMPRA: abre su FICHA (SkillCard), que es donde
		# estan el precio y el boton. Antes el clic gastaba a ciegas y lo unico que
		# explicaba lo que acababas de pagar era una linea de aviso que se borraba
		# al siguiente clic.
		arbol._tap("damage")
		await get_tree().process_frame
		var ficha_nodo = arbol._card
		_check("pulsar un nodo abre su ficha en vez de comprarlo",
			ficha_nodo != null and ficha_nodo.skill_id() == "damage"
			and not Game.skill_owned("damage") and Game.rebirth_coins == 12)
		_check("y la ficha se cuelga de la capa de encima, no dentro del panel",
			ficha_nodo != null and ficha_nodo.get_parent() == _main._overlay_host)
		if ficha_nodo != null:
			# Lo que dice de un nodo cerrado: cual hay que comprar antes, cuanto
			# cuesta y que es lo que va a cambiar. Los dos numeros salen de Game y
			# de SkillTree, o sea que no pueden mentir.
			_check("la ficha de un nodo cerrado dice cual falta antes",
				_dice(ficha_nodo, "ANTES: " + SkillTree.effect_text("money")))
			_check("y trae su explicacion larga entera",
				_dice(ficha_nodo, str(UIKit.wrap(SkillTree.detail_of("damage"),
					SkillCard.COL_W, 21)[0])))
			_check("y el numero que tendra al comprarlo",
				_dice(ficha_nodo, "AL COMPRARLO: " + SkillTree.total_text("damage",
					Game.skill_bonus("damage") + 0.20)))
			# El boton ESTA aunque no se pueda comprar (un boton escondido o muerto
			# no explica nada) y quien comprueba de verdad es el panel, que lo dice
			# en la barra: mismo camino que la chapa del rebirth.
			_check("la ficha trae el boton de comprar",
				_boton_de(ficha_nodo, "COMPRAR") != null)
			var raras := _minusculas_en(ficha_nodo)
			_check("y no hay ninguna letra minuscula en la ficha", raras.is_empty())
			for r in raras:
				print("         con minusculas: ", r)
			_check("y pulsarlo en un nodo cerrado no cobra nada",
				_pulsa_comprar(ficha_nodo) and not Game.skill_owned("damage")
				and Game.rebirth_coins == 12
				and arbol._hint_label.text.begins_with("ANTES"))
			ficha_nodo._close()
			await get_tree().process_frame
		_check("y al cerrar la ficha el arbol se queda sin ella", arbol._card == null)
		# El clic: se pulsa DONDE SE VE el nodo (no en un id), que es lo que hace
		# el jugador y lo que prueba de paso el paso de pantalla a arbol.
		_check("pulsar donde se ve un nodo acierta cual es",
			arbol._node_at(arbol._nodes["money"]["center"]) == "money")
		arbol._tap(arbol._node_at(arbol._nodes["money"]["center"]))
		await get_tree().process_frame
		var ficha_centro = arbol._card
		_check("y abre la ficha del centro",
			ficha_centro != null and ficha_centro.skill_id() == "money")
		if ficha_centro != null:
			# Los dos numeros que hacen falta para decidir: lo que el arbol lleva
			# sumado AHORA y lo que llevara al comprarlo.
			_check("la ficha trae el numero de AHORA y el de despues",
				_dice(ficha_centro, "AHORA, CON EL ARBOL: "
					+ SkillTree.total_text("money", Game.skill_bonus("money")))
				and _dice(ficha_centro, "AL COMPRARLO: "
					+ SkillTree.total_text("money", 0.30)))
			# Y LA FICHA CABE Y NO PISA NADA: es una pantalla nueva, y una linea de
			# texto encima del dibujo del nodo no da ningun error (solo una ficha
			# ilegible), asi que se mira con los mismos checks que la tienda.
			_check_cabe("la ficha de la mejora no saca texto del panel", ficha_centro, PANEL)
			_check_sin_encimarse("la ficha no pone texto encima de una chapa", ficha_centro)
			_check_sin_pisar_dibujos("la ficha no dibuja texto encima del nodo", ficha_centro)
			_check("y comprar desde la ficha compra la mejora del centro",
				_pulsa_comprar(ficha_centro) and Game.skill_owned("money")
				and Game.rebirth_coins == 11
				and is_equal_approx(Game.value_multiplier(), 1.30))
			_check("y el aviso de la barra lo dice",
				arbol._hint_label.text.begins_with("COMPRADO"))
			await get_tree().process_frame
			# Y LA FICHA SE REPINTA SOLA (Game.skills_changed): el nodo pasa a
			# COMPRADO y el boton de comprar desaparece, que es lo unico que se
			# puede hacer con el ya.
			_check("y la ficha se repinta con el nodo ya comprado",
				_dice(ficha_centro, "COMPRADO")
				and _boton_de(ficha_centro, "COMPRAR") == null)
			ficha_centro._close()
			await get_tree().process_frame
		_check("y el nodo se pone en COMPRADO",
			not arbol._nodes["money"]["cost"].visible
			and not arbol._nodes["money"]["coin"].visible
			and arbol._nodes["money"]["done"].visible)
		# Y EL COMPRADO VA DONDE IBA EL PRECIO, no en medio de la chapa: el rotulo
		# se coloca por su centro y el nodo por su esquina, y equivocarse ahi (que
		# es lo que paso) deja la palabra escrita ENCIMA del dibujo del nodo sin
		# que ningun check de "cabe" se entere, porque cabe de sobra.
		var comprado: Rect2 = _visible(arbol._nodes["money"]["done"], true)
		var chapa_money: Rect2 = arbol.node_rect("money")
		_check("y el COMPRADO se dibuja en la fila del coste, abajo de la chapa",
			comprado.position.y > chapa_money.position.y + chapa_money.size.y * 0.6)
		# Y un frame antes de medir: los glifos del precio que se acaba de vaciar se
		# sueltan con queue_free() (ver pixel_number.gd, _rebuild), asi que en el
		# mismo frame en que se compra todavia estan en el arbol.
		await get_tree().process_frame
		_check_sin_pisar_dibujos("y con la mejora comprada tampoco pisa el dibujo", arbol,
			_franja_barra(arbol))
		_check("y con el centro comprado los caminos se abren",
			arbol._state_of("damage") == "ready"
			and arbol._state_of("locker") == "ready")
		arbol._tap("speed")
		await get_tree().process_frame
		var ficha_speed = arbol._card
		_check("comprar un camino se lleva tres monedas",
			ficha_speed != null and _pulsa_comprar(ficha_speed)
			and Game.skill_owned("speed") and Game.rebirth_coins == 8)
		if ficha_speed != null:
			ficha_speed._close()
			await get_tree().process_frame
		_check("y sube la velocidad de la partida de verdad",
			is_equal_approx(Game.charge_multiplier(), 1.20)
			and arbol._state_of("speed") == "owned")
		# LA LINEA DEL CAMINO CAMBIA DE COLOR con lo que se puede hacer con el, y
		# el cambio se pide al lienzo que la pinta (pedirlo al mundo no repinta
		# nada, que es el fallo que se cazo mirando la captura: comprabas la mejora
		# y la linea seguia apagada).
		_check("la linea del camino comprado se enciende",
			arbol.link_color("money") == arbol.LINK_DONE
			and arbol.link_color("spikes") == arbol.LINK_OPEN
			and arbol._lines != null)
		# Una mejora ya comprada: su ficha lo dice y no trae NADA que comprar.
		var saldo2: int = Game.rebirth_coins
		arbol._tap("speed")
		await get_tree().process_frame
		var ficha_ya = arbol._card
		_check("la ficha de una mejora comprada lo dice y no cobra monedas",
			ficha_ya != null and _dice(ficha_ya, "COMPRADO")
			and _boton_de(ficha_ya, "COMPRAR") == null
			and not _pulsa_comprar(ficha_ya)
			and Game.rebirth_coins == saldo2)
		if ficha_ya != null:
			ficha_ya._close()
			await get_tree().process_frame
		# Sin monedas para el siguiente: la ficha dice cuanto falta, pulsar
		# COMPRAR no cobra nada y la barra repite lo que falta.
		Game.rebirth_coins = 0
		arbol.refresh()
		arbol._tap("spikes")
		await get_tree().process_frame
		var ficha_pobre = arbol._card
		_check("sin monedas la ficha dice cuanto falta y no compra nada",
			ficha_pobre != null
			and _dice(ficha_pobre, "TE FALTAN %d MONEDAS"
				% Game.skill_missing_coins("spikes"))
			and not (_pulsa_comprar(ficha_pobre) and Game.skill_owned("spikes"))
			and Game.rebirth_coins == 0 and not Game.skill_owned("spikes")
			and arbol._hint_label.text.begins_with("TE FALTAN")
			and arbol._state_of("spikes") == "poor")
		if ficha_pobre != null:
			ficha_pobre._close()
			await get_tree().process_frame

		# TODAS LAS FICHAS, UNA POR UNA. Los checks de arriba abren las de un nodo
		# cerrado, la del centro y la de un camino sin monedas, pero NUNCA la de un
		# interruptor: y la de un interruptor reventaba entera (pulsar uno cerraba
		# el juego) porque se le pedia el texto de un porcentaje que no tiene. El
		# fallo no dejaba la ficha a medias, se llevaba por delante el montaje, asi
		# que lo que se mira es que esten las DOS lineas de abajo, que son las que
		# se escriben despues del numero.
		var fichas_rotas: Array = []
		for id_ficha in SkillTree.ids():
			arbol._tap(str(id_ficha))
			await get_tree().process_frame
			var f = arbol._card
			var bien := f != null and _dice(f, SkillTree.effect_text(str(id_ficha)))
			if bien and Game.skill_owned(str(id_ficha)):
				bien = _dice(f, "COMPRADO")
			elif bien:
				# Las dos lineas se escriben con el numero detras, asi que se mira el
				# principio del texto (empieza = true) y no la linea entera.
				bien = _dice(f, "AHORA, CON EL ARBOL: ", true)
				if SkillTree.is_qol(str(id_ficha)):
					bien = _dice(f, "AHORA: ", true) and _dice(f, "AL COMPRARLO: ", true)
				else:
					bien = bien and _dice(f, "AL COMPRARLO: ", true)
			if not bien:
				fichas_rotas.append(str(id_ficha))
			if f != null:
				f._close()
				await get_tree().process_frame
		_check("la ficha de los dieciseis nodos se monta entera", fichas_rotas.is_empty())
		for f_rota in fichas_rotas:
			print("         ficha rota: ", f_rota)
		# Y SE MIRA UNA DE INTERRUPTOR ENTERA, con los mismos checks de encuadre
		# que la del centro: no tiene numeros de porcentaje, sino AHORA: APAGADO /
		# AL COMPRARLO: ENCENDIDO, y esa linea tambien puede acabar encima del
		# dibujo o fuera del marco sin que nada avise.
		arbol._tap(SkillTree.QOL_KEYS)
		await get_tree().process_frame
		var ficha_qol = arbol._card
		_check("la ficha de un interruptor se abre",
			ficha_qol != null and ficha_qol.skill_id() == SkillTree.QOL_KEYS)
		if ficha_qol != null:
			_check_cabe("y no saca texto del panel", ficha_qol, PANEL)
			_check_sin_encimarse("y no pone texto encima de una chapa", ficha_qol)
			_check_sin_pisar_dibujos("y no dibuja texto encima del nodo", ficha_qol)
			ficha_qol._close()
			await get_tree().process_frame

		# El arrastre: el arbol se mueve y el tope no lo deja salir de la vista.
		var antes_drag: Vector2 = arbol.node_point("money")
		arbol._set_offset(arbol._offset + Vector2(120, 80))
		_check("arrastrar mueve el arbol", arbol.node_point("money") != antes_drag)
		# EL TOPE: por mucho que se arrastre, un trozo del DIBUJO del arbol (su
		# caja entera, no un nodo suelto: el nodo del centro puede salirse por un
		# lado mientras el resto sigue a la vista) se queda dentro de la vista.
		# Sin tope, arrastrar hacia un lado deja la pantalla vacia.
		var vista := Rect2(PANEL.position, arbol.VIEW_SIZE)
		arbol._set_offset(Vector2(-99999, -99999))
		var dentro_neg: Rect2 = _caja_del_arbol(arbol).intersection(vista)
		_check("y arrastrando hasta el tope no se puede sacar de la vista",
			dentro_neg.size.x >= arbol.KEEP - 1.0 and dentro_neg.size.y >= arbol.KEEP - 1.0)
		arbol._set_offset(Vector2(99999, 99999))
		var dentro_pos: Rect2 = _caja_del_arbol(arbol).intersection(vista)
		_check("por el otro lado tampoco",
			dentro_pos.size.x >= arbol.KEEP - 1.0 and dentro_pos.size.y >= arbol.KEEP - 1.0)
		arbol._set_offset(arbol._centered_offset())
		# Y el boton de reiniciar sigue en su sitio, en la barra: la barra no se
		# mueve con el arbol (que es justo lo que se pide de una barra).
		var punto_go: Vector2 = arbol._go.get_global_rect().get_center()
		arbol._set_offset(arbol._offset + Vector2(-160, 120))
		_check("y la barra no se mueve con el arbol",
			arbol._go.get_global_rect().get_center() == punto_go)
		arbol._close()
		await get_tree().process_frame
	_check("y el cerrar quita el arbol", g._rebirth == null)

	# --- LA CALIDAD DE VIDA, DENTRO DE LA PARTIDA -------------------------- #
	#
	# Los cuatro interruptores que tocan la partida se prueban donde vive cada
	# regla. Los atajos van aparte, en el test del raton, que es donde hay teclas.
	#
	# SIN FICHA: la chatarra es una NOTA, no un precio. Lo que vale un objeto sube
	# con el escalon del sobre (cuarenta veces de los SOBRES a ELECTRONICA), asi que
	# un umbral en dinero tendria que cambiar con cada escalon; la nota va de 1 a 10
	# en todos y se ve como estrellas en la ficha.
	Game.skills = {}
	_check("sin la mejora, la chatarra se sigue mirando una por una",
		not Game.auto_sell_chaff({"grade": 1}))
	Game.skills[SkillTree.QOL_CHAFF] = 1
	_check("y con SIN FICHA lo de tres estrellas o menos se vende sin abrir ficha",
		Game.auto_sell_chaff({"grade": 1}) and Game.auto_sell_chaff({"grade": 3})
			and not Game.auto_sell_chaff({"grade": 4}))

	# EL SOBRANTE: el dano que le sobra a un golpe no se tira, espera al siguiente.
	Game.skills = {}
	Game.carry_damage = 0.0
	Game.keep_carry(40.0)
	_check("sin EL SOBRANTE, el dano que sobra de un golpe se pierde",
		is_zero_approx(Game.take_carry()))
	Game.skills[SkillTree.QOL_CARRY] = 1
	Game.keep_carry(40.0)
	_check("y con ella espera al siguiente sobre y se gasta de una vez",
		is_equal_approx(Game.take_carry(), 40.0)
			and is_zero_approx(Game.carry_damage))

	# ARMARIO SOLO: cuando el armario esta lleno, exponer una pieza mejor de su
	# tipo cambia una por otra; una peor no toca nada (una mejora que empeora el
	# armario al pulsar no es una mejora), y con hueco libre siempre se suma.
	Game.items = []
	while Game.items.size() < LootDB.item_count():
		Game.items.append(0)
	Game.skills = {SkillTree.QOL_LOCKER: 1, "locker": 1}
	var flojo := {"kind": "cards", "grade": 2, "value": 100, "art": "loot_card_common_psa2"}
	var otro := {"kind": "vinyls", "grade": 2, "value": 100, "art": "loot_vinyl_psa2"}
	Game.locker = [flojo.duplicate(), otro.duplicate()]
	Game.inventory = [{"kind": "cards", "grade": 9, "value": 900, "art": "loot_card_common_psa9"},
		{"kind": "cards", "grade": 1, "value": 50, "art": "loot_card_common_psa1"}]
	Game.locker_put(0)
	_check("con ARMARIO SOLO, una pieza mejor entra en el armario lleno",
		LootDB.bonus_for(Game.locker[0]) > LootDB.bonus_for(flojo)
			and Game.locker.size() == 2 and Game.inventory.size() == 2)
	_check("y la que estaba vuelve al inventario, que no se pierde nada",
		int(Game.inventory[0].get("grade", 0)) == 2)
	var antes_peor: float = LootDB.bonus_for(Game.locker[0])
	_check("y una pieza peor no cambia nada",
		not Game.locker_put(1) and is_equal_approx(LootDB.bonus_for(Game.locker[0]), antes_peor))
	# Y sin la mejora, el armario lleno sigue diciendo que no: el cambio es lo que
	# se paga, no una forma distinta de contar los huecos.
	Game.skills = {"locker": 1}
	Game.locker = [flojo.duplicate(), otro.duplicate()]
	Game.inventory = [{"kind": "cards", "grade": 9, "value": 900}]
	_check("y sin ella el armario lleno no deja exponer nada",
		not Game.locker_put(0) and Game.locker.size() == 2)

	# MESA LIMPIA: lo que lleva un rato quieto en la mesa se vende solo, al mismo
	# precio que el clic. Se prueba con un objeto puesto de verdad en la mesa, no
	# con el reloj a mano, porque lo que hay que comprobar es que pasa por el
	# camino de la venta de siempre (dinero, sonido y aviso).
	var botin := {"id": "card_c", "name": "CARTA COMUN", "art": "loot_card_common_psa5",
		"rarity": "common", "grade": 5, "value": 500, "kind": "cards"}
	Game.skills = {}
	var esperando: TableElement = g._spawn_loot(botin.duplicate())
	g._loot_age[esperando] = LootDB.AUTO_SELL_TABLE_AFTER + 30.0
	g._table_broom_step(0.016)
	_check("sin MESA LIMPIA, la mesa no vende nada sola", g._elements.has(esperando))
	if is_instance_valid(esperando):
		g._remove_from_table(esperando)
	Game.skills = {SkillTree.QOL_TABLE: 1}
	var dinero_antes: int = Game.money
	var viejo: TableElement = g._spawn_loot(botin.duplicate())
	g._loot_age[viejo] = LootDB.AUTO_SELL_TABLE_AFTER + 1.0
	g._table_broom_step(0.016)
	_check("y con ella, lo que lleva un rato en la mesa se vende solo",
		not g._elements.has(viejo) and g._loot_age.is_empty())
	_check("y el dinero entra igual que si se pulsara", Game.money == dinero_antes + 500)
	# Y lo recien salido NO se toca: la mejora vende lo que se ha quedado, no lo
	# que acaba de caer delante del jugador.
	var recien: TableElement = g._spawn_loot(botin.duplicate())
	g._loot_age[recien] = 0.0
	g._table_broom_step(0.016)
	_check("y no vende lo que acaba de salir", g._elements.has(recien))
	if is_instance_valid(recien):
		g._remove_from_table(recien)
	Game.skills = {}

	# --- los fallos de la mesa que se arreglaron -------------------------- #
	#
	# LAS TARJETAS DE REVELADO VAN DE UNA EN UNA. Con dos paquetes rompiendose
	# mientras la primera tarjeta seguia abierta, la segunda se pintaba encima y
	# la primera se quedaba huerfana al cerrar la de arriba.
	await _empty_table(g)
	Game.set_auto_sell(false)
	var capas_cola: int = _main._overlay_host.get_child_count()
	var roto_a: TableElement = g._spawn_pack("cards")
	var roto_b: TableElement = g._spawn_pack("cards")
	g._on_element_opened("cards", roto_a)
	g._on_element_opened("cards", roto_b)
	await get_tree().process_frame
	_check("dos sobres rotos a la vez sacan UNA tarjeta",
		g._reveal != null and _main._overlay_host.get_child_count() == capas_cola + 1)
	_check("y el segundo espera su turno", g._reveal_queue.size() == 1)
	if g._reveal != null:
		g._reveal._finish(RevealCard.ACTION_SELL)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("al cerrar la primera sale la segunda, sola",
		g._reveal != null and g._reveal_queue.is_empty()
		and _main._overlay_host.get_child_count() == capas_cola + 1)
	if g._reveal != null:
		g._reveal._finish(RevealCard.ACTION_SELL)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("y al cerrar la segunda no queda ninguna",
		g._reveal == null and _main._overlay_host.get_child_count() == capas_cola)
	for cola_el in [roto_a, roto_b]:
		if is_instance_valid(cola_el):
			cola_el.queue_free()
	await _empty_table(g)

	# UN BOTIN QUE YA SE ESTA VENDIENDO no se vuelve a cobrar con VENDER: el clic
	# arranca una animacion que paga al final, y VENDER lo pagaba otra vez.
	var vendiendo: TableElement = g._spawn_loot(botin.duplicate())
	await get_tree().process_frame
	var dinero_venta: int = Game.money
	vendiendo._sell()
	_check("un botin a medio vender no se vende otra vez de golpe",
		vendiendo.sell_instant() == 0 and is_instance_valid(vendiendo))
	g._sell_all_table()
	await _wait(0.6)
	_check("y se cobra una sola vez",
		Game.money == dinero_venta + int(botin["value"]) and g.table_count() == 0)

	# EL REBIRTH VACIA LA MESA. Antes la mesa se quedaba puesta y el botin sin
	# vender se cobraba en la partida nueva: se podia pasar dinero de una partida a
	# la siguiente dejando la mesa llena antes de reiniciar.
	await _empty_table(g)
	var monedas_mesa: int = Game.rebirth_coins
	var en_mesa: TableElement = g._spawn_loot(botin.duplicate())
	g._spawn_pack("vinyls")
	Game.money = LootDB.REBIRTH_REQUIRE
	Game.do_rebirth()
	_check("el rebirth vacia la mesa", g.table_count() == 0 and Game.table.is_empty())
	var dinero_nuevo: int = Game.money
	if is_instance_valid(en_mesa):
		en_mesa._emit_sold(int(botin["value"]), Vector2.ZERO)
	_check("y lo que quedaba en ella no paga en la partida nueva",
		Game.money == dinero_nuevo)
	Game.rebirth_coins = monedas_mesa
	await get_tree().process_frame

	# LA MESA SE GUARDA. Salir al menu tiraba los sobres ya pagados y el botin sin
	# vender; ahora vuelven al entrar, el sobre con la vida que le quedaba.
	var guardado_sobre: TableElement = g._spawn_pack("sneakers")
	guardado_sobre.set_hp(300.0)
	g._spawn_loot(botin.duplicate())
	_main.show_menu()
	await get_tree().process_frame
	_check("al salir al menu la mesa queda guardada", Game.table.size() == 2)
	_main.show_game()
	await get_tree().process_frame
	g = _screen()
	var vuelto_sobre := false
	var vuelto_botin := false
	for mesa_vuelta in g._elements:
		if mesa_vuelta.is_loot() and int(mesa_vuelta.loot.get("value", 0)) == int(botin["value"]):
			vuelto_botin = true
		elif not mesa_vuelta.is_loot() and str(mesa_vuelta.pack.get("id", "")) == "sneakers" \
				and is_equal_approx(mesa_vuelta.hp, 300.0):
			vuelto_sobre = true
	_check("y al volver estan los dos: el sobre con su vida y el botin",
		g.table_count() == 2 and vuelto_sobre and vuelto_botin)
	await _empty_table(g)
	Game.table = []

	# Y EL MENU NO SABE NADA DE ESTO. El menu que se ve al arrancar (y al salir de
	# la partida) no tiene hucha ni forma de abrirla: el rebirth se hace jugando, y
	# ahi se queda. Se mira al final porque cambiar de pantalla deja la partida sin
	# usar, y esto es lo ultimo que queda por comprobar.
	_main.show_menu()
	await get_tree().process_frame
	var inicio = _main._screen_host.get_child(0)
	_check("el menu ya no trae la hucha: no sabe abrir el rebirth",
		inicio != null and not inicio.has_method("_on_rebirth")
		and not inicio.has_method("_refresh_rebirth"))

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
