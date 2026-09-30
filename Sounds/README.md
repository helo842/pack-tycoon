# Sounds

Los sonidos del juego. **No hay ni un fichero descargado de internet**: los once
WAV salen de `../tools/make_sounds.py`, que los sintetiza con ondas cuadradas,
triangulares y ruido filtrado. Es la misma idea que `Sprites/` y por el mismo
motivo: once sonidos que tienen que sonar a la misma familia se cambian todos a
la vez cambiando una línea del generador.

Es la primera versión con sonido. Hasta ahora el menú decía *"PRIMERA VERSION -
SIN SONIDO TODAVIA"*, y los dos deslizadores del panel de ajustes (MUSICA y
SONIDOS) se guardaban en el fichero pero no hacían nada, porque no había ni
audio que subir ni bajar.

## Cómo está repartida la carpeta

```
Sounds/
  index.tsv           DONDE ESTA CADA SONIDO (nombre corto -> ruta). Lo genera
                      tools/make_sounds.py y lo lee el juego.
  sfx/                sfx_*     los once efectos
  music/              music_*   la musica de fondo
```

**El juego no pide rutas, pide nombres.** `Sound.play("sfx_sell")`, en
`../scripts/core/audio.gd`, lee `index.tsv` y carga lo que pone ahí. La carpeta
la decide el prefijo del nombre (`music_` → `music/`, el resto → `sfx/`), igual
que en los sprites, así que mover un sonido de sitio es tocar el generador y
volver a ejecutarlo, no el código.

> **Por qué `.wav` y no `.ogg`.** Godot importa los dos, pero el WAV lo lee sin
> dependencias y la síntesis ya lo escribe en PCM. Además, música de 23 s en
> mono a 22050 Hz ocupa 1 MB: no hay nada que ganar comprimiéndolo, y un
> códec de más es un paso de más que se puede romper.
>
> **Y van sin comprimir, con `compress/mode = 0` en `project.godot`.** Godot
> comprime los WAV con QOA (con pérdida) por defecto, y una onda cuadrada es el
> peor caso posible para un códec con pérdida: le mete pre-eco y la emborrona,
> que es justo lo contrario de lo que se busca con este estilo. Es el mismo
> motivo por el que los PNG van con `compress/mode = 0` en el mismo sitio. De
> paso, sin comprimir, el bucle de la música cae en el fotograma exacto.

## Los once sonidos

| Nombre corto | Cuándo suena | Duración |
|---|---|---|
| `sfx_click` | Pulsar un botón (menú, tienda, cerrar) | 0,06 s |
| `sfx_toggle` | Encender o apagar auto-apertura y auto-compra | 0,17 s |
| `sfx_buy` | Comprar un paquete | 0,27 s |
| `sfx_rip` | Empezar a abrir un paquete (clic o auto-apertura) | 0,46 s |
| `sfx_open` | Sale la tarjeta de revelado | 0,60 s |
| `sfx_rare` | Encima de `sfx_open`, si lo que sale es épico o legendario | 1,10 s |
| `sfx_sell` | Vender un objeto (de la mesa o del inventario) | 0,21 s |
| `sfx_sell_all` | VENDER o VENDER TODO | 0,64 s |
| `sfx_error` | No te llega el dinero, mesa llena, no hay nada que vender | 0,32 s |
| `sfx_tool` | Comprar una mejora de herramienta | 0,74 s |
| `music_backroom` | Siempre, de fondo, en bucle | 22,86 s |

Tres decisiones que no se ven en la tabla:

- **Los dos sonidos de la moneda son el mismo motivo.** `sfx_buy`, `sfx_sell` y
  `sfx_sell_all` son las dos notas de la moneda de toda la vida (B5 y E6), con
  más o menos notas según lo que se esté cobrando. Así el oído aprende una sola
  cosa: "esto es dinero". El error es lo contrario a propósito: grave y bajando.
- **`sfx_rare` es una capa, no un sonido aparte.** Va ENCIMA de `sfx_open`, no en
  su lugar. En ese orden se entiende "algo ha salido" y luego "y es bueno"; si
  sustituyera al otro, un legendario sonaría distinto a un común desde el primer
  milisegundo y se perdería la sorpresa.
- **El clic lleva temblor de tono y los demás no.** Dos clics seguidos idénticos
  suenan a error de audio, no a botón; pero un aviso que cambia de tono cada vez
  deja de reconocerse. Está en la tabla `JITTER` de `../scripts/core/audio.gd`, y
  es una lista corta a propósito: solo `sfx_click` y `sfx_sell`.

## La música

Un bucle de 8 compases a 84 BPM sobre cuatro acordes (Am - F - C - G, dos
compases cada uno) con tres voces muy separadas de volumen:

| Voz | Qué es | Volumen |
|---|---|---|
| Bajo | La fundamental, triangular, un golpe por compás | 0,22 |
| Colchón | Las tres notas del acorde, con 0,35 s de ataque para que no golpee | 0,055 |
| Arpegio | Tres notas del acorde, una octava arriba, con huecos | 0,075 |

**La regla es que no tiene que llamar la atención.** Si se nota, está alta. Por
eso no hay melodía reconocible: una melodía generada por script se tararea mal, y
un bucle que se tararea mal molesta a la tercera vuelta. Lo que hay es colchón
armónico, que aguanta dos horas sin cansar.

**El bucle se cierra con las puntas fundidas** (50 ms de fundido en cada punta,
`fade_edges()`). Sin eso, entre la última muestra y la primera hay un escalón y
se oye un chasquido cada vuelta. Aun así el fundido no basta: el bucle de verdad
se monta en el juego (ver abajo).

## Volumen: los tres buses

`../scripts/core/audio.gd` crea **en código** tres buses de audio:

```
Master
  ├─ Music   musica_volume del guardado (0,7 por defecto)
  └─ Sfx     sfx_volume del guardado (0,45 por defecto)
```

No hay un `.tres` de buses del proyecto y es a propósito: son tres líneas, no
cambian nunca, y así no hay un recurso binario más que mantener. Lo que sí
importa es que **existan**: sin el bus no hay dónde aplicar el volumen, y era
exactamente lo que pasaba antes. Ahora `Game.set_music_volume()` y
`Game.set_sfx_volume()` emiten `settings_changed`, el autoload lo escucha y
mueve el bus. Los dos deslizadores de los ajustes hacen algo de verdad.

El deslizador de SONIDOS suena al moverse (un clic de referencia cada 5 %). Es
la única forma de oír cómo va a sonar sin salir de los ajustes.

## Dos cosas de Godot que hay que saber

**1. Los WAV se importan SIN bucle, y el bucle lo pone el juego.** El importador
de Godot deja todos los WAV en "sin bucle", y no se puede poner el bucle por
defecto en `project.godot`: los efectos son WAV iguales que la música, y se
pondrían a repetirse solos. Así que `Sound._make_loop()` duplica el stream de la
música y le pone `loop_mode = LOOP_FORWARD` y el último fotograma como fin. El
fin se saca de `get_length() * mix_rate`, no del tamaño en bytes, para que dé
igual si un día el WAV se importa a 8 bits o comprimido.

**2. Cerrar el juego con la música puesta da aviso si se sale de golpe.** Al
parar una voz, quien suelta su WAV es el hilo de audio, que mezcla por su cuenta;
si el juego sale en el mismo frame, Godot avisa al salir de *"resources still in
use at exit"* y de instancias perdidas. Como la música es un bucle infinito,
sonaba **siempre** al cerrar. Por eso `Game._on_close()` (en
`../scripts/core/game_state.gd`) corta el sonido y espera 0,15 s antes de llamar
a `quit()`, y por eso `Game` pone `get_tree().auto_accept_quit = false`: el
cierre lo lleva el juego, no el motor.

> Los tests hacen lo mismo antes de salir (`Sound.stop_all()` + `create_timer`).
> Y tiene que ser **tiempo real, no frames**: en headless un frame dura casi
> nada y el hilo de audio no le da ni una vuelta.

## Generar los sonidos

```bash
python3 tools/make_sounds.py --all             # los once, reescribe index.tsv
python3 tools/make_sounds.py --all --audit     # + revisión (sale con 1 si algo falla)
python3 tools/make_sounds.py --list
python3 tools/make_sounds.py --only sfx_click  # solo uno, para iterar
```

Tarda **un segundo** en generarlo todo, así que se puede cambiar una frecuencia y
volver a escuchar sin pensarlo.

`--audit` no puede juzgar si un sonido es bonito, pero caza los cuatro fallos que
se cuelan solos:

| Comprobación | Qué detecta |
|---|---|
| Silencio | Un sonido que sale casi mudo: un volumen mal puesto en la mezcla. |
| Saturación | El pico que llega a 1,0: el altavoz lo recorta y suena a chicharra. |
| Duración | Menos de 20 ms (no se oye) o más de 45 s (no es un efecto). |
| Chasquido | Empieza o acaba fuera de cero: se oye un "clic" al arrancar o al repetirse. |

> El auditor **no** comprueba la frecuencia ni el contenido espectral. Si un
> sonido suena a lo que no es, eso lo oye una persona; el script solo evita los
> cuatro fallos que no avisan de ninguna otra forma.

## Añadir un sonido

1. Abre `../tools/make_sounds.py`.
2. Escribe `def sfx_mi_sonido() -> List[float]:` montando el buffer con `blank()`,
   `tone()`, `noise()`, `place()` y `notes()`. El volumen final no se escribe ahí:
   `normalize()` lo deja en `SFX_PEAK`, así que en la función va la **mezcla**
   (qué suena más que qué), no el volumen.
3. Añádelo al registro `SFX` (o a `MUSIC` si es de fondo). El prefijo del nombre
   decide la carpeta.
4. `python3 tools/make_sounds.py --all --audit` y, si lo ha cogido la auditoría,
   arreglarlo.
5. Que suene en algún sitio: `Sound.play("sfx_mi_sonido")` donde corresponda.
6. `Sounds/index.tsv` **no se toca a mano**: lo reescribe el generador.
