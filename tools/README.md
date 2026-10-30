# tools/ - los generadores del arte y del sonido

Todo el arte del juego sale de aqui, y tambien todos los sonidos. No hay ningun
PNG dibujado a mano en `Sprites/` ni ningun WAV descargado en `Sounds/`: se
generan con Python, se auditan y se vuelven a generar. Eso es lo que hace que 193
sprites que tienen que encajar entre si (misma paleta, mismo grosor de linea,
misma rejilla) se puedan cambiar todos a la vez, y que los once sonidos suenen a
la misma familia.

Los sprites usan **Pillow**; los sonidos, solo la **libreria estandar** (`wave`,
`array`, `math`), porque sintetizar ondas cuadradas no necesita nada mas.

```
sprite_paths.py     DONDE VA CADA SPRITE. La fuente de verdad de la estructura
                    de carpetas; la importan todos los demas generadores
make_sprites.py     el generador principal: el catalogo completo y el auditor
pack_designs.py     los dibujos de los PAQUETES (cuatro tipos, tres escalones,
                    cerrado, abierto y los tres tramos de dano). Lo enchufa
                    make_sprites.py, que es quien los escribe y los audita
font_patterns.py    los patrones 5x7 de cada glifo, aparte para poder retocar
                    una letra sin tocar el resto del generador
make_font.py        la fuente del juego (hoja + .fnt) a partir de los patrones
normalize_sprite.py para meter un sprite que viene de fuera (un generador de
                    imagenes) en el formato del juego
make_background.py  los dos fondos: la trastienda y la superficie de la mesa
make_screens.py     maquetas de las pantallas, en Sprites/mockups/
mockup_pack_quality.py
                    prueba de calidad del sobre: el mismo dibujo a 128 y a 256, y
                    la hoja comparativa con el de 32 de ahora
make_sounds.py      los sonidos (efectos y musica), en Sounds/
check_font_size.py  comprueba que la fuente se escala a pixeles enteros
```

## El orden

Cada generador es independiente salvo por una cosa: `Sprites/index.tsv`, que es
la lista de donde vive cada sprite y la que lee el juego. Quien lo escribe es
`make_sprites.py`, y los demas lo anaden al generar lo suyo. **El orden da
igual**: `make_sprites.py --all` relee el indice antes de reescribirlo y se queda con las
entradas que no son suyas siempre que el fichero siga existiendo, asi que no
tira lo que han puesto los demas.

```bash
python3 tools/make_sprites.py --all    # catalogo + indice
python3 tools/make_font.py              # fuente -> Sprites/font/
python3 tools/make_background.py        # trastienda -> Sprites/backgrounds/
python3 tools/make_background.py --table  # mesa -> Sprites/backgrounds/bg_table.png
python3 tools/make_screens.py           # maquetas -> Sprites/mockups/
python3 tools/make_sounds.py --all      # sonidos -> Sounds/ (+ su propio indice)
```

> Los sonidos tienen **su propio indice** (`Sounds/index.tsv`), aparte del de los
> sprites: son otro medio, con otra clase de fichero, y mezclarlos en una lista
> con `loot_vinyl_psa7` no ayudaria a nadie. El unico generador que escribe en
> cada uno es el suyo.

> Eso no significa que el indice se pueda editar a mano y esperar a que nadie lo
> toque. `--all` manda sobre las entradas suyas y descarta las que apuntan a un
> fichero que ya no esta. Si anades un sprite, anadelo con la herramienta
> (`normalize_sprite.py` lo hace solo), no a mano.

> **Ojo con la cache de importacion.** Si se generan sprites con el editor
> CERRADO, los PNG cambian pero `.godot/imported/` se queda con los viejos, y el
> juego no los carga: el sprite se ve como un hueco, sin un solo error de
> GDScript (el motor solo deja un `Failed loading resource` en la consola). Con
> el editor abierto Godot reimporta solo; sin el, hay que pedirlo a mano:
>
> ```bash
> $G --headless --import --path .
> ```
>
> `dev/SmokeTest.tscn` lo caza desde que comprueba que todos los PNG del indice
> cargan de verdad, no solo que esten en el indice.

## Lo habitual

```bash
python3 tools/make_sprites.py --all --audit   # generar todo y revisarlo
python3 tools/make_sounds.py --all --audit    # lo mismo, con los sonidos
python3 tools/make_sprites.py --only cart_foil
python3 tools/make_sprites.py --wear-sheet cards   # hoja de desgaste
python3 tools/make_sprites.py --preview            # catalogo en rejilla
```

`--audit` sale con codigo 1 si algo se sale del estilo (contorno recortado,
escala no entera, color fuera de la paleta, alfa que no es 0/255). En los sonidos
comprueba otra cosa (silencio, saturacion, duracion y chasquidos), porque un
sonido no tiene pixeles. Es lo que hay que pasar antes de dar algo por bueno.

## Por que Python y no el editor de Godot

Porque los sprites se repiten: diez notas de desgaste por objeto, cuatro
variantes de rareza, la misma paleta en todo. A mano serian cientos de ficheros
que se desincronizan en cuanto se cambia un color. Con un generador, cambiar el
oro de la paleta es cambiar una linea y volver a ejecutar.
