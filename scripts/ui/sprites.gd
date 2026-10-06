# Sprites - acceso a los PNG de res://Sprites por nombre corto ("loot_vinyl").
#
# POR QUE HAY UN INDICE Y NO UNA REGLA
# ------------------------------------
# Los sprites viven en subcarpetas (res://Sprites/loot/, res://Sprites/ui/...)
# y el juego sigue pidiéndolos por el nombre corto, porque muchos nombres vienen
# de datos y no de código: loot_db.gd dice "art": "loot_card_foil_psa3" y aqui
# se traduce a la ruta real. Para no escribir la ruta en 100 sitios.
#
# El indice (res://Sprites/index.tsv) lo escribe tools/make_sprites.py, el mismo
# generador que coloca los ficheros. La alternativa — que esta clase dedujera la
# carpeta del prefijo con una regla propia — tiene dos listas del mismo sitio en
# dos lenguajes, y en cuanto alguien añade un prefijo nuevo se desincronizan sin
# que nada avise: el sprite se ve como un hueco y no hay error. Con el indice no
# puede pasar, porque lo escribe el que decide la carpeta.
#
# El indice se carga entero al arrancar (196 lineas, nada) y se guarda en un
# diccionario. A partir de ahi cada busqueda es una tabla.
class_name Sprites
extends RefCounted

const DIR := "res://Sprites/"
const INDEX := "res://Sprites/index.tsv"

static var _paths: Dictionary = {}
static var _cache: Dictionary = {}
static var _loaded := false


static func _load_index() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(INDEX, FileAccess.READ)
	if f == null:
		push_error("No se encuentra %s. Corre: python3 tools/make_sprites.py --all"
				% INDEX)
		return
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty() or line.begins_with("#"):
			continue
		# "<nombre corto>\t<carpeta/archivo.png>"
		var parts := line.split("\t")
		if parts.size() == 2:
			_paths[parts[0]] = parts[1]
	f.close()


## Ruta completa de un sprite por su nombre corto, o "" si no esta en el indice.
static func path_of(sprite_name: String) -> String:
	_load_index()
	if _paths.has(sprite_name):
		return str(_paths[sprite_name])
	return ""


## Todos los nombres del indice. Para poder revisarlo entero (el smoke test
## comprueba que no falte ninguno y que ninguno apunte a un fichero que no existe).
static func index_names() -> Array:
	_load_index()
	return _paths.keys()


## Devuelve la textura, o null si el nombre no existe (para no reventar al
## importar: un sprite pendiente se ve como hueco, no como error rojo).
static func tex(sprite_name: String) -> Texture2D:
	if _cache.has(sprite_name):
		return _cache[sprite_name]
	var t: Texture2D = null
	var rel := path_of(sprite_name)
	if rel == "":
		push_warning("Sprite no encontrado: %s (esta en el indice?)" % sprite_name)
	else:
		var full := DIR + rel
		if ResourceLoader.exists(full):
			t = load(full)
		else:
			push_warning("El indice dice %s pero Godot no lo tiene importado: %s"
					% [sprite_name, full])
	_cache[sprite_name] = t
	return t


## Solo comprueba si existe, sin cargarlo. Para no pedir en un bucle.
static func has(sprite_name: String) -> bool:
	return path_of(sprite_name) != ""


static var _used: Dictionary = {}


## El rectangulo de pixeles CON TINTA del sprite, medido sobre su lienzo.
##
## Hace falta porque todos los sprites se pintan sobre el mismo lienzo de 512
## para compartir escala, pero cada dibujo ocupa un trozo distinto de el: un
## sobre de cartas ocupa 256x496 (estrecho y alto) y una caja de zapatillas
## 480x272 (ancha y baja). Colocandolos y escalandolos por el LIENZO, los dos
## acaban midiendo lo mismo en pantalla, pero el de cartas sale flaco y el de
## zapatillas flotando en un hueco. Con esto se pueden escalar por su dibujo.
##
## Se mide una vez por sprite y se guarda: get_image() copia la textura a RAM.
## Si no se puede medir (textura nula o comprimida) devuelve el lienzo entero,
## que es la suposicion vieja y no rompe nada.
static func used_rect(sprite_name: String) -> Rect2:
	if _used.has(sprite_name):
		return _used[sprite_name]
	var rect := Rect2()
	var t := tex(sprite_name)
	if t == null:
		_used[sprite_name] = rect
		return rect
	var lienzo := Rect2(Vector2.ZERO, Vector2(t.get_size()))
	var img := t.get_image()
	var usado := Rect2i()
	if img != null:
		usado = img.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		rect = lienzo
	else:
		rect = Rect2(Vector2(usado.position), Vector2(usado.size))
	_used[sprite_name] = rect
	return rect
