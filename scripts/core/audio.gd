# Sound - el autoload de audio. Es el hermano de Sprites, pero para el sonido.
#
# POR QUE NO HAY UN .tres DE BUSES
# ---------------------------------
# Los tres buses (Master, Music y Sfx) se crean en codigo al arrancar en vez de
# en un layout de audio del proyecto. Son tres lineas, no cambian nunca, y asi
# no hay un recurso binario mas que mantener. Lo que si importa es que EXISTAN:
# sin el bus no hay donde aplicar el deslizador de volumen, y los deslizadores
# del panel de ajustes se quedaban en nada (aunque se guardaran en el fichero).
#
# POR QUE SE PIDE EL SONIDO POR NOMBRE Y NO POR RUTA
# --------------------------------------------------
# Igual que los sprites: los ficheros viven en subcarpetas (Sounds/sfx/,
# Sounds/music/) y quien los pide solo sabe "quiero el de vender". El indice
# (Sounds/index.tsv) lo escribe tools/make_sounds.py, que es el mismo que decide
# en que carpeta va cada cosa, asi que no puede desincronizarse.
#
# POR QUE HAY UN POOL DE REPRODUCTORES
# ------------------------------------
# Un solo AudioStreamPlayer corta el sonido anterior al empezar otro, y aqui se
# solapan a menudo (vender cinco cosas seguidas, la campana del revelado encima
# del rasgado...). Con un pool de 12, cada efecto coge el siguiente libre y los
# que se pisan suenan juntos, que es lo que se espera.
extends Node

const DIR := "res://Sounds/"
const INDEX := "res://Sounds/index.tsv"

## Reproductores simultaneos. No hace falta mas: por encima de eso ya no se
## distingue nada y solo suma ruido.
const POOL := 12

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "Sfx"

## Sonidos que se repiten mucho y necesitan variar un poco para no sonar a
## metralleta. El resto van siempre igual a proposito: un aviso que cambia de
## tono cada vez deja de reconocerse.
const JITTER := {
	"sfx_click": 0.06,   # +/- 6 %
	"sfx_sell": 0.04,
}

var _paths: Dictionary = {}
var _cache: Dictionary = {}
var _loaded := false

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer = null
var _music_name := ""

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_buses()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	# El bucle lo lleva el propio AudioStreamWAV, asi que el reproductor no tiene
	# que enterarse de cuando acaba la pista.
	_music.finished.connect(_on_music_finished)
	add_child(_music)
	apply_volumes()
	Game.settings_changed.connect(apply_volumes)


# --------------------------------------------------------------------------- #
# Indice
# --------------------------------------------------------------------------- #

func _load_index() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(INDEX, FileAccess.READ)
	if f == null:
		push_error("No se encuentra %s. Corre: python3 tools/make_sounds.py --all" % INDEX)
		return
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty() or line.begins_with("#"):
			continue
		# "<nombre corto>\t<carpeta/archivo.wav>"
		var parts := line.split("\t")
		if parts.size() == 2:
			_paths[parts[0]] = parts[1]
	f.close()


## Ruta completa de un sonido por su nombre corto, o "" si no esta en el indice.
func path_of(sound_name: String) -> String:
	_load_index()
	if _paths.has(sound_name):
		return DIR + str(_paths[sound_name])
	return ""


## Todos los nombres del indice. Para que el test los pueda recorrer enteros.
func index_names() -> Array:
	_load_index()
	return _paths.keys()


## Se llama exists() y no has() a proposito: has() es de Dictionary, y un
## metodo con ese nombre en un autoload se confunde al leerlo.
func exists(sound_name: String) -> bool:
	_load_index()
	return _paths.has(sound_name)


## El stream, o null si el nombre no existe (para que un sonido que falte se
## quede mudo en vez de reventar a mitad de una partida).
func stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var s: AudioStream = null
	var full := path_of(sound_name)
	if full == "":
		push_warning("Sonido no encontrado: %s (esta en el indice?)" % sound_name)
	elif ResourceLoader.exists(full):
		s = load(full)
	else:
		push_warning("El indice dice %s pero Godot no lo tiene importado: %s"
				% [sound_name, full])
	_cache[sound_name] = s
	return s


# --------------------------------------------------------------------------- #
# Buses
# --------------------------------------------------------------------------- #

func _ensure_buses() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)


## Crea el bus si no existe y lo cuelga del Master. Devuelve su indice.
func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, BUS_MASTER)
	return idx


## Los dos deslizadores del panel de ajustes acaban aqui.
func apply_volumes() -> void:
	_set_bus_volume(BUS_MUSIC, Game.music_volume)
	_set_bus_volume(BUS_SFX, Game.sfx_volume)


func _set_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# Silenciar de verdad en el 0: en decibelios, 0 linea no es silencio (-inf),
	# y con linear_to_db(0) el bus se queda en un volumen rarisimo.
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


# --------------------------------------------------------------------------- #
# Reproduccion
# --------------------------------------------------------------------------- #

## Un efecto. `pitch` es un multiplicador de tono: 1.0 es el original.
func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(sound_name)
	if s == null:
		return
	var jitter := float(JITTER.get(sound_name, 0.0))
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-jitter, jitter))
	p.play()


## El clic de los botones. Va aparte porque lleva el temblor de tono: dos clics
## seguidos identicos suenan a error de audio, no a boton.
func click() -> void:
	play("sfx_click")


func play_music(sound_name: String) -> void:
	if _music == null or (_music_name == sound_name and _music.playing):
		return
	var s := stream(sound_name)
	if s == null:
		return
	_music_name = sound_name
	_music.stream = _make_loop(s)
	_music.play()


func stop_music() -> void:
	if _music != null:
		_music.stop()
	_music_name = ""


## Para absolutamente todo (musica y efectos).
##
## Hace falta al cerrar el juego: una voz que sigue sonando sujeta su WAV, y el
## que lo suelta es el hilo de audio, que ya no vuelve a mezclar. Sin esto, Godot
## avisa al salir de "resources still in use at exit" y de instancias
## perdidas. Como la musica es un bucle infinito, pasaba SIEMPRE al cerrar.
func stop_all() -> void:
	stop_music()
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null


func is_music_playing() -> bool:
	return _music != null and _music.playing


func _on_music_finished() -> void:
	# Solo se llega aqui si el bucle del stream no ha podido montarse (un
	# formato que no es WAV, por ejemplo). Se vuelve a empezar para que la
	# musica no se quede muda a mitad de partida.
	if _music_name != "":
		_music.play()


## Convierte un WAV suelto en un bucle infinito.
##
## El importador de Godot deja los WAV en "sin bucle" a proposito, y no se puede
## poner el bucle por defecto en todos: los efectos, que son WAV iguales, se
## pondrian a repetirse sin parar. Asi que el bucle se monta aqui, y solo para
## la musica.
func _make_loop(s: AudioStream) -> AudioStream:
	var wav := s as AudioStreamWAV
	if wav == null:
		return s
	var out := wav.duplicate() as AudioStreamWAV
	if out == null:
		return s
	out.loop_begin = 0
	# En fotogramas, y sacado de la duracion en vez del tamano en bytes: asi da
	# igual si el WAV acaba importado en 8 bits, en 16 o comprimido.
	out.loop_end = loop_end_frames(out)
	out.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return out


## Ultimo fotograma del bucle. El test lo mira para comprobar que el bucle se
## monto de verdad.
func loop_end_frames(wav: AudioStreamWAV) -> int:
	return maxi(1, int(round(wav.get_length() * float(wav.mix_rate))))


func _notification(what: int) -> void:
	# Al cerrar la ventana (o al salir del arbol) se corta el sonido. Es la mitad
	# de la historia; la otra mitad esta en Game._on_close(), que es quien da el
	# medio frame de margen antes de salir. Ver stop_all().
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		stop_all()
