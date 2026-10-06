# Sprites

Sprites del juego de paquetes descrito en `../Idea.pdf`. Todos son **pixel art con
fondo transparente**, contorno oscuro grueso y una paleta cálida compartida, para
que un sprite generado con IA y uno generado por script se puedan poner juntos en
la misma mesa sin que se note el salto de estilo.

## Cómo está repartida la carpeta

Nada está suelto en la raíz. Se divide por **de qué es cada sprite**, y la
decisión sale de su prefijo, que ya lo decía: `loot_` era botín, `pack_` eran
sobres, `ui_` era interfaz. No es una clasificación inventada, es el nombre, solo
que con sitio debajo.

```
Sprites/
  index.tsv           DONDE ESTA CADA SPRITE (nombre corto -> ruta). Lo genera
                      tools/make_sprites.py y lo lee el juego.
  loot/               loot_*      el botin: 6 objetos + 4 cartas, 10 notas cada uno
  packs/              pack_*      los sobres que se compran, cerrado y roto
  tools/              tool_*      las herramientas que acortan la apertura
  ui/
    panels/           ui_panel_*  los marcos de ventana
    controls/         ui_*        botones, deslizadores, casillas, flechas
    icons/            ui_icon_*   los iconos sueltos
    indicators/       grade_ condition_ rarity_ shadow_ fx_ skill_ currency_
  font/               num_*  font_pack.*   los digitos y la fuente del juego
  backgrounds/        bg_*        los fondos de pantalla completa y la mesa
  mockups/            shot_*      las maquetas de referencia
```

**El juego no pide rutas, pide nombres.** `Sprites.tex("loot_vinyl_psa7")`, en
`../scripts/ui/sprites.gd`, lee `index.tsv`, busca la fila y carga la ruta que
pone ahí. Así que las carpetas son para las personas y para el generador, no una
cosa que el código tenga que conocer. Si mañana `loot/` pasa a `botin/`, se
cambia en `tools/sprite_paths.py`, se regenera el índice y el juego sigue
funcionando sin tocar una línea de GDScript.

> **La tabla prefijo → carpeta está en `../tools/sprite_paths.py`**, no aquí. Es
> la fuente de verdad de la estructura y la importan todos los generadores, para
> que no haya cinco copias de la misma lista desincronizadas. El prefijo más
> largo gana: `ui_icon_shop` va a `ui/icons/` y no a `ui/controls/`, que es lo
> que pasaría si se recorriera el diccionario tal cual.

**Para mover un sprite, dos caminos.** Si el nombre no cambia, se edita la tabla
de `sprite_paths.py` y se vuelve a generar. Si lo que cambia es el nombre, hay
que tocar tres sitios: la tabla, la fila de `index.tsv` y el código que lo pide
por nombre corto (`grep` del nombre viejo). Renombrar el PNG a mano sin pasar por
el índice deja un sprite en disco que el juego no encuentra, y eso falla en
silencio, que es la peor forma de fallar.

**Los ficheros `.import` no se editan a mano.** Los pone Godot al importar y no
son arte: son la configuración de importación de ese PNG. El único que hay que
mantener a mano es el de la fuente (`font_pack.fnt.import`, con
`scaling_mode=1`), y está versionado a propósito.

## Contenido de la carpeta

### Monedas (originales de Gemini, ya normalizados)

| Archivo | Qué es | Origen |
|---|---|---|
| `ui/indicators/currency_coins.png` | Montón de monedas, moneda principal | `Gemini_..._c0f4hcc0f4hcc0f4-removebg-preview.png` |
| `ui/indicators/currency_piggy.png` | Hucha de cerdito de oro, moneda de rebirth | `Gemini_..._1kmv1g1kmv1g1kmv-removebg-preview.png` |

Estos dos **no** los genera el script: son la imagen de Gemini pasada por
`tools/normalize_sprite.py --grid 32 --lock-palette`, que la deja en la rejilla
del juego y con la paleta exacta. Sin ese paso tenían 29.333 y 14.680 colores y
253 niveles de alfa, y junto a los sprites del script se veían de otra familia.

> Los dos PNG **crudos** se conservan sin tocar en `../source_art/`, con el
> nombre que les dio el generador de imágenes. El script no los toca, así que
> `--all` no los pisa. Para rehacer los normalizados:
>
> ```bash
> python3 tools/normalize_sprite.py \
>     ../source_art/Gemini_Generated_Image_c0f4hcc0f4hcc0f4-removebg-preview.png \
>     --name currency_coins --grid 32 --lock-palette
> ```
>
> `--name` **sin extensión**: la carpeta la decide `sprite_paths.py` a partir del
> prefijo (`currency_` → `ui/indicators/`) y la herramienta añade la entrada al
> índice, así que el juego lo encuentra sin hacer nada más.
>
> (`currency_coin`, la **moneda suelta** de los precios, sí la dibuja el script.
> Es la tercera, y es la que usan las pantallas: la pila y la hucha son para
> cuando se llegue al rebirth.)
>
> **No hay un tercer original.** Una versión anterior de este README mencionaba
> un `Gemini_..._nnqqwjnnqqwjnnqq` (el sobre de cartas) que nunca llegó a la
> carpeta. Como mucho, ese papel lo cubre ahora `loot_card_*`.

### Generados por `tools/make_sprites.py`

Todo lo que hay en `Sprites/` sale de ahí, salvo los dos de las monedas que
vienen de un generador de imágenes. La carpeta `loot/` (**210 PNG**) es el
botín: 17 objetos × 10 notas de desgaste, 4 cartas × 10 notas, y las gemas y
auras de rareza en `ui/indicators/`:

```
loot/                            ui/indicators/
  loot_vinyl_psa1 … _psa10         rarity_gem_common.png     rarity_glow_common.png
  loot_vinyl_double_psa1 … _psa10  rarity_gem_rare.png       rarity_glow_rare.png
  loot_vinyl_numbered_psa1 … _psa10 rarity_gem_epic.png      rarity_glow_epic.png
  loot_vinyl_color_psa1 … _psa10   rarity_gem_legendary.png  rarity_glow_legendary.png
  loot_sneaker_psa1 … _psa10
  loot_sneaker_leather_psa1 … _psa10
  loot_sneaker_restore_psa1 … _psa10
  loot_sneaker_limited_psa1 … _psa10
  loot_console_psa1 … _psa10
  loot_handheld_psa1 … _psa10
  loot_cartridge_psa1 … _psa10
  loot_headphones_psa1 … _psa10
  loot_watch_psa1 … _psa10
  loot_pocket_watch_psa1 … _psa10
  loot_camera_psa1 … _psa10
  loot_cable_psa1 … _psa10
  loot_ingot_psa1 … _psa10
  loot_card_common_psa1 … _psa10
  loot_card_edited_psa1 … _psa10
  loot_card_vintage_psa1 … _psa10
  loot_card_foil_psa1 … _psa10
```

> **Ya no hay un `loot_card_rare.png` ni un `loot_card_epic.png`.** Antes las
> cuatro cartas eran un dibujo teñido por rareza; ahora son cuatro dibujos
> distintos (`common`, `edited`, `vintage`, `foil`) porque una edición limitada
> no es una carta común más brillante. Ver "Cartas coleccionables", más abajo.

### Los objetos y su nota PSA (`loot_*_psa1` … `loot_*_psa10`)

Cada objeto físico tiene **diez sprites**, uno por nota PSA. Los diecisiete
objetos son 170 archivos, todos en `loot/`:

```
loot_vinyl_psa10.png        …  loot_vinyl_psa1.png
loot_vinyl_double_psa10.png …  loot_vinyl_double_psa1.png
loot_vinyl_numbered_psa10.png … loot_vinyl_numbered_psa1.png
loot_vinyl_color_psa10.png  …  loot_vinyl_color_psa1.png
loot_sneaker_psa10.png      …  loot_sneaker_psa1.png
loot_sneaker_leather_psa10.png … loot_sneaker_leather_psa1.png
loot_sneaker_restore_psa10.png … loot_sneaker_restore_psa1.png
loot_sneaker_limited_psa10.png … loot_sneaker_limited_psa1.png
loot_console_psa10.png      …  loot_console_psa1.png
loot_handheld_psa10.png     …  loot_handheld_psa1.png
loot_cartridge_psa10.png    …  loot_cartridge_psa1.png
loot_headphones_psa10.png   …  loot_headphones_psa1.png
loot_watch_psa10.png        …  loot_watch_psa1.png
loot_pocket_watch_psa10.png …  loot_pocket_watch_psa1.png
loot_camera_psa10.png       …  loot_camera_psa1.png
loot_cable_psa10.png        …  loot_cable_psa1.png
loot_ingot_psa10.png        …  loot_ingot_psa1.png
```

> **El nombre del objeto habla del MODELO, nunca del estado.** El estado lo
> deduce la nota PSA, asi que un sprite llamado `sneaker_worn` (se empezó por
> ahi y se renombró a `sneaker_leather`) pondria una zapatilla rota con la
> insignia de *como nuevo* al lado. Un color distinto es un modelo distinto, y
> su nota sigue hablando de lo gastado que tenga. Esto no es una manía del
> nombre: es la misma regla que hace que el estado se deduzca de la nota.

Las tres zapatillas nuevas no son tres funciones sueltas: `_sneaker()` dibuja la
silueta con la paleta que le pases, y cada variante la llama y le añade encima
lo suyo. Así las cuatro son **la misma zapatilla** en distinto cuero, que es lo
que hace falta para que el jugador las compare de un vistazo en la tarjeta de
revelado en vez de mirar los nombres. La unica que se sale de la silueta es
`sneaker_restore`, que se pinta con `_tintar_zona()`: una cinta cruzando el
sprite a proposito, porque lo que dice "a medias" es la cinta, no el color.

**Ya no existe un `loot_vinyl.png` a secas**: sería el mismo dibujo que la nota
10 y tener las dos cosas invita a equivocarse al elegir.

Las diez salen del **mismo dibujo base** con una capa de desgaste encima
(`apply_wear()` en `tools/make_sprites.py`), así que cuando se toca el dibujo de
un objeto solo se toca en un sitio. El desgaste es acumulativo y va por tramos:

| Nota | Qué se ve |
|---|---|
| 10 | Intacto |
| 9 | Mugre |
| 8 | Mugre y arañazos |
| 7 | + desgaste de canto, el perfil aclarado |
| 6 | Mugre densa |
| 5 | + mellas en el perfil |
| 4 | Arañazos profundos |
| 3 | + manchas |
| 2 | + grietas |
| 1 | Esquinas comidas y grieta abierta |

Tres detalles que no son evidentes y que costaron un rato:

- **La semilla es fija por (objeto, nota).** Sin eso, regenerar el catálogo daría
  un dibujo distinto cada vez y no se podrían comparar dos notas entre sí.
- **El tinte se cuantiza al 1 %.** El auditor solo admite la rejilla de `shade()`
  en pasos del 1 %, así que un factor como 0.135 saca el sprite de la paleta.
- **Los tintes se aplican al color original, no al ya teñido.** Dos `shade()`
  seguidos caen fuera de esa rejilla. `Wear` guarda el color de paleta de cada
  píxel por eso.

Para revisar el desgaste de un objeto:

```bash
python3 tools/make_sprites.py --wear-sheet watch    # tools/_wear_watch.png
python3 tools/make_sprites.py --wear-sheet cards    # tools/_wear_cards.png
```

### Cartas coleccionables (`loot/loot_card_*`)

Son **cuatro dibujos distintos** (`card_common`, `card_edited`, `card_vintage`,
`card_foil`), no uno teñido por rareza. Antes lo eran, y por eso el paquete de
cartas sacaba siempre el mismo dibujo en cuatro paletas: el 78,8 % de los
píxeles era idéntico entre las cuatro.

| Base | Qué es |
|---|---|
| `card_common` | Cartón liso, sin adornos, con una piedra de acero en el medallón |
| `card_edited` | Edición limitada: marco dorado, arte color crema, banda de serie y sello rojo |
| `card_vintage` | Tono sepia con filigrana de puntos en el marco y un retrato dentro |
| `card_foil` | Holográfica: bandas diagonales de cuatro colores sobre fondo noche, con destellos |

Cada una tiene sus diez notas: `loot_card_foil_psa1` … `_psa10`.

**El desgaste de carta es otro código** (`apply_card_wear()`, no `apply_wear()`),
porque el cartón no se desgasta como una consola. Lo que se le mete: roce del
borde que se aclora, roces sueltos en la cara, puntitos de humedad (*foxing*),
esquina doblada a partir de la nota 4, pliegue con línea clara y su sombra a
partir de la 6, mancha de anillo (un vaso) en la 8 y un segundo pliegue en la 1.

```python
# tools/make_sprites.py
w = Wear(s, f"card:{key}:{wear}")
w.paint(x, y, CREAM)   # color absoluto, no un shade() del color de antes
w.erase(x, y)          # borra el píxel (mellas, esquina doblada)
```

`paint()` existe justo para lo que no es "más claro": un tinte tiene que poder
cambiar de color, no solo aclararse. El resto del desgaste se hace con
`w.tint()`, que sí va por la rejilla de `shade()`.

**El tono viejo de la vintage va en el dibujo, no en el desgaste.** Una carta vieja
es vieja por definición: su PSA 10 es "mint *para su edad*", no "sin usar". Si el
sepia fuera capa de desgaste, la vintage con nota 10 se vería nueva y la común
con nota 1 se vería vieja, que es justo al revés de como funciona una casa de
subastas.

Revisar las cuatro filas × diez notas de golpe:

```bash
python3 tools/make_sprites.py --wear-sheet cards   # tools/_wear_cards.png
```

### Herramientas equipables (`tools/tool_*`)

**Acortan el tiempo de apertura** del paquete. 512×512, rejilla de 32 ×16.

```
tool_cutter.png       cúter de hoja retráctil, mango dorado remachado
tool_scissors.png     tijeras abiertas en aspa, anillas doradas
tool_gloves.png       guante de trabajo de cuero, punera remachada
tool_crowbar.png      palanca de acero con gancho y cinta en el mango
```

### Paquetes (`packs/pack_*`)

Lo que se compra **a ciegas**. Cada categoría tiene dos estados: el cerrado, que
es lo que cae en la mesa, y el roto, que es lo que se ve cuando termina de
abrirse. El estado roto reutiliza el cuerpo del cerrado y le arranca la parte de
arriba, así que se ve que es la misma caja y no otro objeto parecido.

Los cuatro de categoría salen **en tres escalones**, y el escalón se ve en el
dibujo, no solo en el precio: el 1 es el de siempre (cartón, plástico, madera),
el 2 va forrado de pan de oro y el 3 es laca oscura con filetes de oro y una
joya. El archivo lleva el escalón pegado al nombre (`pack_cards`,
`pack_cards2`, `pack_cards3`) y **cada escalón trae sus propios tramos de daño**
(`_d1`, `_d2`, `_d3`). Eso último no es opcional: el daño no se guarda en los
datos, se deduce del nombre del arte (`"pack_cards2" + "_d2"`), así que un
escalón con arte nuevo y sin sus tres tramos se ve bien hasta el segundo golpe.
Las tres versiones comparten coordenadas a propósito — el contorno no se toca —
o al partirse el sobre se vería otra caja y no se reconocería lo que se golpea.

La laca del escalón 3 **no es negro puro a propósito**: el fondo de la columna
de sobres es casi negro (0.02, 0.015, 0.04) y un sobre negro se leería como un
hueco en la tienda sin ningún error. Va de gris violáceo
(`DARK_SOFT`/`SLATE`/`NIGHT`) con un filete de oro por fuera, que es lo que
separa el sobre del fondo.

| Archivo | Qué es |
|---|---|
| `pack_cards.png` | Sobre de cartas coleccionables, vertical, con gema turquesa y borde en sierra |
| `pack_cards_open.png` | El mismo sobre rasgado, con dos cartas asomando |
| `pack_vinyls.png` | Funda cuadrada de cartón con cinta dorada y el vinilo asomando |
| `pack_vinyls_open.png` | La misma funda rasgada por una esquina, con el vinilo fuera |
| `pack_sneakers.png` | Caja de zapatillas ancha, tapa dorada y etiqueta |
| `pack_sneakers_open.png` | La misma caja con la tapa levantada y una zapatilla saliendo |
| `pack_electronics.png` | Caja más alta que ancha, en plástico oscuro con bandas doradas |
| `pack_electronics_open.png` | La misma con el plástico rasgado y un cable enrollado dentro |
| `pack_misc.png` | Paquete genérico sellado con cinta cruzada, sin marca |
| `pack_misc_open.png` | El mismo abierto y arrugado, con objetos variados dentro |
| `pack_*2.png` / `pack_*2_open.png` | El escalón **ORO**: el mismo sobre forrado de pan de oro, con el sello de lacre, la banda batida y los destellos |
| `pack_*3.png` / `pack_*3_open.png` | El escalón **LUJO**: laca oscura con filete de oro, oro macizo y una joya tallada en turquesa |
| `pack_*_d1/d2/d3.png` | Los tres tramos de daño, por escalón: rayajos, esquina levantada y agujero. El dibujo del tramo sale del sobre CERRADO de su escalón |

### El flujo de apertura, revela y venta

Las piezas que hacen funcionar el bucle de *comprar → esperar → revelar →
vender*. Van repartidas entre `ui/panels/`, `ui/controls/` y
`ui/indicators/`.

| Archivo | Tamaño | Qué es |
|---|---|---|
| `shadow_small/medium/large.png` | 128/256/512 | Sombra difuminada bajo el objeto de la mesa. Sin contorno y con alfa graduado. |
| `ui_timer_track.png` | 256×256 | Anillo de espera vacío, la pista |
| `ui_timer_fill.png` | 256×256 | **Un cuarto** de anillo, para que el juego lo gire cuatro veces |
| `ui_panel_reveal.png` | 1600×960 | Tarjeta de revelado. Cuerpo casi negro, al contrario que la tienda, para que el objeto destaque |
| `fx_shine.png` | 256×256 | Destello de fondo al salir un botín raro o legendario |
| `ui_tag_price.png` | 320×160 | Chapita de valor que se pone bajo un objeto |
| `ui_button_sell.png` | 320×144 | Botón de vender. Cuerpo oscuro: es una acción de perder |
| `currency_coin.png` | 512×512 | Moneda suelta para los precios |

> **El anillo de espera va partido en dos a propósito.** `ui_timer_fill` es un
> cuarto de círculo, no un anillo entero: así el juego lo rota 90° cuatro veces y
> el relleno es exacto en cualquier punto del progreso, sin parpadeo ni sprites
> intermedios. `ui_timer_fill` **no lleva contorno** (se come el hueco central
> al girar) y `ui_timer_track` sí, porque es la pieza fija.
>
> Las sombras son **múltiplos enteros entre sí** (128 / 256 / 512) para que
> la que el juego elija pueda encogerse con vecino más cercano sin
> romper la rejilla.

### Graduación PSA (`ui/indicators/grade_*`)

La nota va de 1 a 10. El número **no** está en el sprite: se pinta en el juego
con la fuente `num_*` que ya existía, de modo que subir de nota es cambiar
estrellas y no rehacer el icono.

```
grade_badge.png        escudo donde va el número (vacío a propósito)
grade_star_full.png    estrella llena
grade_star_half.png    media estrella
grade_star_empty.png   estrella vacía
grade_ribbon.png       cinta de encabezado de la ficha
```

La estrella es una **máscara de texto** (`STAR_MASK` en el generador), igual que
los dígitos de `font_patterns.py`, y no una fórmula: la primera versión usaba
una ecuación de ancho lineal y salía un rombo en vez de una estrella.

> Con 5 estrellas y medias, la nota de 1 a 10 sale sin ningún sprite extra:
> 1 = vacía, 2 = vacía + ½… hasta 5 = 5 llenas. Si prefieres la nota numérica
> grande en vez de estrellas, `grade_badge` + `num_*` ya lo dan.

### Pantalla de inicio

Tres carpetas distintas para tres cosas distintas: la placa es un control, los
iconos son iconos y el fondo es un fondo.

```
ui/controls/ui_button_plate.png          ui/icons/ui_icon_play.png
ui/controls/ui_button_plate_pressed.png  ui/icons/ui_icon_settings.png
backgrounds/bg_menu_backroom.png
```

| Archivo | Tamaño | Para qué |
|---|---|---|
| `ui_button_plate.png` | 512×256 | Placa de botón, **sin texto**. Admite rebanado en 9: el centro es plano, así que se estira a lo ancho sin deformarse. Margen de 9-slice: 3 px de arte = **48 px** por lado. |
| `ui_button_plate_pressed.png` | 512×256 | La misma placa en estado pulsado (más oscura y con el contenido hundido 1 px). |
| `ui_icon_play.png` | 256×256 | Triángulo de play, tres tonos. |
| `ui_icon_settings.png` | 256×256 | Engranaje de ocho dientes. |
| `bg_menu_backroom.png` | 1920×1080 | Fondo de la trastienda. |

Los dos iconos y la placa son **piezas independientes**: el texto lo pone Godot
encima, así que puedes cambiar la etiqueta sin rehacer el arte.

### La fuente y los números (`font/`)

Aquí vive todo lo que se lee. Es lo único de `Sprites/` que Godot carga por su
propio cuenta — y por eso va aparte: los demás son pictures y este es un
`FontFile`.

```
font/num_0 … num_9      num_comma   num_period   num_minus   num_plus   num_percent
font/num_sheet.png      <- los 15 glifos en fila, para importarlos como fuente
font/font_pack.png      <- la hoja de la fuente del juego (letras, digitos, signos)
font/font_pack.fnt      <- la fuente en formato BMFont; esto es lo que carga el tema
```

**Hay dos fuentes, y no es un descuido.** `num_*` es la del **contador de dinero**
(montada a mano con `pixel_number.gd`, porque los numeros cambian cada frame y
cargar una fuente entera para eso seria tonto). `font_pack` es la de **todo el
texto** de las pantallas, y va como `default_font` del tema
(`../scenes/ui/game_theme.tres`).

`font_pack` la genera `../tools/make_font.py` a partir de los mismos patrones 5×7
de `font_patterns.py`: 57 glifos, celda de 7×9 px (5×7 de tinta + 1 de contorno),
blanco puro con contorno `#101020` de 1 px, y `size=7`.

> **Lo que hace que no se vea borroso es `scaling_mode=1`** en
> `font_pack.fnt.import`: solo deja escalas enteras. La fuente mide 7 px de alto,
> asi que en pantalla sale a 21, 28, 42… veces, y los pixeles caen siempre en el
> mismo sitio. `tools/check_font_size.py` comprueba que los tres sitios (el
> `.fnt`, el `.import` y `const FONT_STEP := 7` en `ui_kit.gd`) siguen de
> acuerdo, porque si uno se queda atras la letra se ve correcta en un sitio y
> blanda en otro.
>
> Y como el ancho es **exacto** (un glifo por celda, sin kerning ni espaciado
> lateral), medir un texto es multiplicar, no preguntar a Godot:
> `UIKit.text_width("SOBRES", 28)` son 6 × 28 = 168 px. Se usa para colocar y para
> encoger las etiquetas largas en vez de recortarlas.

| Dato | Valor |
|---|---|
| Tamaño por glifo | **64×96 px** (celda de 8×12 px de arte × escala 8) |
| Avance entre glifos | **64 px** exactos, todos los glifos en la misma celda |
| Hoja | `num_sheet.png` = **960×96**, 15 glifos en fila |

> **Ojo con la escala:** los números van a escala **8**, la mitad que el resto de
> sprites, porque a escala 16 cada dígito mediría 128×192 px y no cabría un
> contador. Si necesitas texto **aún más pequeño** (precios dentro de las
> ranuras), reduce el PNG a la mitad en Godot con filtro *nearest*: 64→32 px es
> exacto, así que los píxeles siguen nítidos (2 px de arte en vez de 4).

### Las 4 habilidades principales (`ui/indicators/skill_*`)

El juego **no** usa un árbol de habilidades: son 4 habilidades fijas a las que se
les compran mejoras. Sus iconos, a 256×256:

| Archivo | Qué representa |
|---|---|
| `skill_diamond.png` | Diamante (calidad del botín). Turquesa, como la gema de las cartas. |
| `skill_lightning.png` | Rayo (velocidad de apertura). |
| `skill_dollar.png` | Símbolo de dólar (ganancias). |
| `skill_cycle.png` | Flechas circulares mordiéndose la cola (reinicio / Rebirth). |

### Estado de conservación (`ui/indicators/condition_*`)

Insignias pequeñas que se superponen en la ficha del objeto, al lado de la nota.

**Ya no son una tirada aparte**: se deducen de la nota PSA (9-10 como nuevo,
7-8 buen estado, 4-6 gastado, 1-3 roto). Antes lo eran, y podía pasar que un
objeto saliera con nota 10 y el sprite roto, o al revés. Ahora son la misma
variable, que es como trabaja una casa de subastas: la graduación *es* el juicio
sobre el estado. Y el desgaste se ve en el propio sprite.

```
condition_mint.png     disco turquesa con destello de cuatro puntas
condition_good.png     disco verde con marca de verificación
condition_worn.png     disco de oro apagado con grieta fina
condition_broken.png   disco rojo oscuro con grieta grande y dentada
```

| Dato | Valor |
|---|---|
| Tamaño | **256×256** (16×16 de arte × 16) |
| Zona de arte | 3–12 px de los 16; el resto es margen para el contorno |

> Es el único sitio donde la paleta usa **verde y rojo**. La regla de abajo
> reserva el turquesa, no prohíbe otros acentos, y aquí son insignias de 13×13
> px, no masas de color. Los tonos son `GREEN_D/GREEN/GREEN_L` y
> `RED_D/RED/RED_L`.

### Iconos de interfaz de segunda generación (`ui/icons/ui_icon_*`)

Los que completan la cola de `PROMPTS.md`. Todos a 256×256.

```
ui_icon_auto_open.png     sobre abierto + insignia de repetición
ui_icon_auto_buy.png      bolsa de compra + insignia de repetición
ui_icon_achievement.png   trofeo dorado con destellos
ui_icon_market_event.png  gráfico ascendente con moneda en la punta
ui_icon_inventory.png     rejilla de 3x3 casillas
ui_icon_display_case.png  vitrina de cristal con estante dorado
ui_icon_vitrine.png       estantería de tres baldas con un objeto en cada una
```

> La insignia de repetición de `auto_open` y `auto_buy` son las dos mismas
> flechas circulares, con una chapa oscura detrás para que no se fundan con el
> objeto. `auto_buy` reutiliza a propósito la silueta de `ui_icon_shop` (la
> bolsa), para que la única diferencia entre "comprar" y "comprar solo" sea la
> insignia.

### Kit de tienda y configuración (`ui/panels/` y `ui/controls/`)

Piezas sueltas para montar los dos menús en Godot:

```
ui_panel_shop.png              ui_panel_settings.png
ui_slot.png                    ui_button_small.png            ui_button_small_pressed.png
ui_button_close.png            ui_checkbox_on.png             ui_checkbox_off.png
ui_slider_track.png            ui_slider_knob.png             ui_arrow_left.png
ui_arrow_right.png             ui_icon_shop.png               ui_icon_sound.png
ui_icon_music.png              ui_icon_plus.png
```

| Archivo | Tamaño | Notas |
|---|---|---|
| `ui_panel_shop.png` | 1600×960 | Marco de ventana, rebanable en 9. Margen de 9-slice: **8 px de arte = 128 px** por lado. Cuerpo marrón cálido. |
| `ui_panel_settings.png` | 1600×960 | Mismo esqueleto, cuerpo azul oscuro. Este sí es rebanable a cualquier tamaño. |
| `ui_slot.png` | 256×256 | Ranura de objeto vacía. |
| `ui_button_small.png` / `_pressed.png` | 320×144 | Botón compacto para acciones dentro de un panel. |
| `ui_button_close.png` | 256×256 | Botón redondo de cerrar. |
| `ui_checkbox_on/off.png` | 160×160 | Casilla de marcar. |
| `ui_slider_track.png` | 416×96 | Canaleta del deslizador. |
| `ui_slider_knob.png` | 128×192 | Mando del deslizador (más alto que la canaleta, es lo normal). |
| `ui_arrow_left/right.png` | 160×160 | Flechas de navegación e idioma. |
| `ui_icon_shop/sound/music/plus.png` | 256×256 | Iconos de sección y del botón de mejora. |

### Pantallas de ejemplo (`mockups/shot_*`)

Maquetas de referencia a 1920×1080, hechas con las piezas de arriba. **No son
assets reutilizables**: sirven para ver cómo encaja todo y para copiar la
distribución.

| Archivo | Contenido |
|---|---|
| `shot_start.png` | Inicio: título y botones de jugar y ajustes sobre el fondo de la trastienda. |
| `shot_shop.png` | Tienda: contador de dinero, 8 ranuras con objeto y precio, botón de mejora y cerrar. |
| `shot_settings.png` | Configuración: dos deslizadores (música y efectos), casilla de pantalla completa y selector de idioma. |

> El único texto no-pixel-art de estas maquetas son las **etiquetas** (MUSIC,
> LANGUAGE...), puestas con una fuente de sistema. Los **números sí son los
tuyos**, montados con `num_*`. Cuando decidas la fuente de texto del juego,
sustituye las etiquetas.

> Las maquetas colocan los iconos dentro de los paneles **a la mitad** (128 px en
> vez de 256). Reducir a la mitad con filtro *nearest* es exacto, así que sigue
> siendo pixel art limpio. Es lo que conviene hacer para los elementos que van
> dentro de una ventana.

## Reglas de estilo

Estas son las reglas que hacen que todo encaje. Si vas a producir un sprite nuevo
(a mano, por script o con IA), respétalas:

1. **Rejilla de arte de 32×32**, escalada por un entero con **vecino más cercano**
   (`NEAREST`). Nunca interpolación bilineal: el píxel tiene que quedar duro.
   Escala por defecto: **×16 → 512×512**.
2. **Contorno oscuro de 1 píxel de rejilla** (`#101020`) alrededor de toda la
   silueta. Es lo que separa el objeto del fondo de la mesa.
3. **Luz desde arriba-izquierda.** Cada material usa 3 tonos: oscuro (sombra),
   medio (base) y claro (brillo superior). Sin degradados suaves.
4. **Sin sombra proyectada** ni suelo en el propio PNG: el sombreado se resuelve
   en el juego.
5. **Turquesa reservado**: `#3868A8` / `#58D0C4` **solo** en gemas y detalles
   brillantes (el acento frío de las cartas originales). No lo uses en cuerpos
   grandes o el estilo se vuelve frío.
6. **Encuadre**: el objeto ocupa ~80 % del ancho del lienzo y queda centrado.
   Deja 1–2 píxeles de rejilla de margen como mínimo.
7. **Formato**: PNG con alpha real. Sin texto, sin marcas de agua, sin fondo.

## Paleta

Definida en `../tools/make_sprites.py` (constantes `RGBA`). Es la fuente de
verdad: si añades un tono al script, refléjalo aquí.

### Neutros y estructura

| Token | Hex | Uso |
|---|---|---|
| `OUTLINE` | `#101020` | Contorno de todo el sprite |
| `DARK` | `#181424` | Negros de material (vinilo, huecos) |
| `DARK_SOFT` | `#30283C` | Sombras suaves sobre metal |
| `WHITE` | `#F4F4F8` | Blanco de tela (zapatilla) |
| `CREAM` | `#FCECC4` | Cuerpo claro, agujas, suela |
| `CREAM_D` | `#D4B888` | Sombra del crema / suela |
| `STEEL` | `#BCC4D0` | Carcasas plásticas |
| `STEEL_D` | `#8C94A4` | Sombra de plástico |
| `STEEL_DD` | `#606878` | Biseles y huecos de plástico |
| `SLATE` | `#484054` | Tapa de la cámara |
| `WOOD_DD` | `#140C0A` | El hueco más profundo |
| `WOOD_D` | `#1E120F` | Interior de casilla y mando |
| `WOOD_M` | `#261612` | Interior de la ranura de objeto |
| `WOOD_L` | `#2C1A15` | Canaleta del deslizador |

### Cálidos (paleta principal)

| Token | Hex | Uso |
|---|---|---|
| `BROWN_D` | `#402018` | Hueco del panel, cuero oscuro |
| `BROWN` | `#804828` | Cuerpo de cuero / panel |
| `BROWN_L` | `#A86030` | Brillo del cuero |
| `GOLD_D` | `#A84808` | Oro en sombra |
| `GOLD` | `#E88000` | Base metálica |
| `GOLD_L` | `#F89810` | Oro claro |
| `GOLD_XL` | `#F8C000` | Oro brillante (monedas) |
| `GOLD_HI` | `#FFD858` | Highlight especular |

### Fríos (solo acentos)

| Token | Hex | Uso |
|---|---|---|
| `TEAL` | `#3868A8` | Acento frío, esquinas de las cartas |
| `TEAL_D` | `#24406C` | Cristal de objetivo |
| `TEAL_L` | `#58D0C4` | Gema turquesa, destello |
| `LCD` | `#6EC88C` | Pantalla de la consola |
| `LCD_D` | `#204838` | Marco de la pantalla |
| `LCD_L` | `#48A870` | Zonas vivas de la pantalla |
| `VINYL_SHEEN` | `#5C5874` | Brillo del vinilo |

### Rarezas

Las cuatro rarezas del documento. **Legendario reutiliza el oro del juego**, así
que encaja sin costuras con las monedas y la hucha.

| Rareza | Sombra | Base | Brillo | Aura |
|---|---|---|---|---|
| Común | `#5C626C` | `#9AA0AA` | `#CED4DA` | `#BAC0C8` |
| Raro | `#205494` | `#4084C8` | `#7AB8EE` | `#60A8E8` |
| Épico | `#582C8C` | `#8C52C8` | `#BC86EE` | `#AA74E8` |
| Legendario | `#B07000` | `#F8C000` | `#FFD858` | `#FFC830` |

### Estado de conservación

Solo para las insignias `condition_*`. Son el único sitio con verde y rojo.

| Estado | Sombra | Base | Brillo |
|---|---|---|---|
| Mint | `#24406C` | `#3868A8` | `#58D0C4` (turquesa de la paleta) |
| Good | `#1E5C2E` | `#2E8C46` | `#56C46A` |
| Worn | `#A84808` | `#C07B4D` | `#E8B27C` (derivados de `GOLD_D`) |
| Broken | `#6E1A18` | `#A82A22` | `#D2503C` |

### Rojo de la grieta y botón de cerrar

| Token | Hex | Uso |
|---|---|---|
| `RUST_D` | `#843424` | Cuerpo del botón de cerrar |
| `RUST_L` | `#B65036` | Brillo del botón de cerrar |
| `CRACK_D` | `#140606` | Grieta de un objeto roto |

## Convención de nombres

```
<prefijo>_<nombre>[_<rarezas>].png
```

El prefijo no es solo documentación: **decide en qué subcarpeta va el fichero**
(tabla en `../tools/sprite_paths.py`). Por eso un nombre no se cambia por gusto:
cambiarlo toca la tabla, el índice y el código que lo pide.

| Prefijo | Carpeta | Cuándo |
|---|---|---|
| `loot_` | `loot/` | Objetos que salen de dentro del paquete. Los físicos llevan `_psa1` … `_psa10` |
| `pack_` | `packs/` | Paquetes, sobres y envoltorios, en sus estados cerrado y roto |
| `tool_` | `tools/` | Herramientas equipables que acortan la apertura |
| `ui_panel_` | `ui/panels/` | Marcos de ventana, rebanables en 9 |
| `ui_button_` `ui_checkbox_` `ui_slider_` `ui_timer_` `ui_arrow_` `ui_slot` `ui_tag_` | `ui/controls/` | Botones, casillas, deslizadores, anillo de espera, flechas, ranura, chapa de precio |
| `ui_icon_` | `ui/icons/` | Iconos sueltos |
| `grade_` | `ui/indicators/` | Graduación PSA: estrellas, escudo y cinta |
| `condition_` | `ui/indicators/` | Insignias de estado de conservación |
| `rarity_` | `ui/indicators/` | Insignias, gemas y auras de rareza |
| `shadow_` | `ui/indicators/` | Sombras difuminadas de la mesa |
| `fx_` | `ui/indicators/` | Efectos sueltos (destellos, partículas) |
| `skill_` | `ui/indicators/` | Iconos de las 4 habilidades principales |
| `currency_` | `ui/indicators/` | Monedas y recursos (moneda suelta, pila, hucha) |
| `num_` `font_` | `font/` | Glifos de los números y la fuente del juego |
| `bg_` | `backgrounds/` | Fondos de pantalla completa |
| `shot_` | `mockups/` | Pantallas de ejemplo ya maquetadas |

Todo en `snake_case`, sin espacios ni el sufijo `-removebg-preview` que mete la
herramienta de recorte de fondos.

**Un prefijo nuevo obliga a tocar tres sitios**, porque los tres guardan la misma
tabla: `tools/sprite_paths.py` (a dónde va), `Sprites/index.tsv` (a dónde está)
y el `grep` del nombre en `scripts/` y `dev/` (qué lo pide). Añadir el prefijo
solo a la documentación es como no añadirlo.

## Generar sprites por script

```bash
python3 tools/make_sprites.py --list                       # qué se puede generar
python3 tools/make_sprites.py --all                        # catálogo completo
python3 tools/make_sprites.py --only sneaker camera        # solo algunos
python3 tools/make_sprites.py --only card --rarity epic    # una rareza concreta
python3 tools/make_sprites.py --all --preview              # + rejilla de control
python3 tools/make_sprites.py --all --audit                # + revisión de estilo
```

Cada generador escribe en la subcarpeta que le toca (`sprite_paths.py` la elige a
partir del nombre) y apunta su destino en `index.tsv`. `make_sprites.py` es el
que **reescribe** el índice entero, pero relee antes lo que había y conserva las
entradas que no son suyas, así que da igual el orden en que se lancen. El que
manda sobre las suyas sigue siendo `--all`: si una entrada apunta a un fichero
que ya no está, desaparece. Por eso los sprites de fuera se añaden con
`normalize_sprite.py`, que escribe la fila por ti.

`--preview` escribe `tools/_preview.png`: una hoja de contacto con todo el
catálogo sobre fondo a cuadros (para juzgar transparencia y contornos de un
vistazo). Útil antes de dar un lote por bueno.

`--audit` es lo que evita que un sprite nuevo rompa el estilo sin que nadie se
entere. Revisa cuatro cosas y sale con **código 1** si encuentra algo:

| Comprobación | Qué detecta |
|---|---|
| Contorno recortado | El arte llega al borde del lienzo, así que el contorno de 1 px se sale y el sprite se ve cortado. |
| Escala no entera | Un bloque de `scale` px con dos colores: el píxel deja de ser duro. |
| Alfa no binario | Sombreado suave en un sprite que debería tener borde duro. Solo se permite en auras, sombras y el destello. |
| Color fuera de paleta | Un tono que no está en la paleta: delata un sprite colado de otra fuente. |
| Prefijo duplicado | Un archivo llamado `grade_grade_star_full.png`. Pasa porque las claves de los registros llevan o no el prefijo según como se registraran, y si lo llevan *y* el `UiSpec` lo vuelve a poner, sale doble. Ya ha pasado dos veces, así que se comprueba. |

Las piezas de 9-slice que sangran a propósito (`ui_panel_*`, `ui_button_plate*`,
`ui_button_small*`, `ui_button_sell`, `ui_slot`, `ui_slider_track`,
`grade_ribbon`) están en una lista blanca, porque su marco tiene que llegar al
borde para poder estirarse.

### Generar los fondos

```bash
python3 tools/make_background.py                                    # trastienda 1920x1080
python3 tools/make_background.py --scale 4                          # trastienda 1280x720
python3 tools/make_background.py --seed 7 --name bg_menu_v2.png     # otra tirada
python3 tools/make_background.py --table                            # mesa 1344x752
python3 tools/make_background.py --table --table-scale 4            # mesa 672x376
```

Se dibuja a **320×180** y se escala con un factor entero (`--scale`), así que el
mismo comando te da cualquier resolución sin romper la rejilla: 4 → 1280×720,
6 → 1920×1080. `--seed` cambia el desorden de las cajas de las estanterías.

> **Nota sobre la rejilla del fondo**: el fondo usa 6 px de pantalla por píxel de
> arte (320×180 × 6), no 16 como los sprites. Es deliberado: a 16 px por píxel de
> arte las estanterías quedarían en bloques enormes sin detalle. Es la práctica
> habitual (los fondos van a una rejilla más fina que los objetos). El centro
> queda despejado y en penumbra cálida a propósito, para que el título y los
> botones se lean encima.

**La mesa va al revés: 8 px por píxel de arte** (168×94 × 8 = 1344×752), que es
justo lo que mide un píxel de arte de un objeto de la mesa. Así el grano de la
madera y el del objeto que se apoya encima son el mismo, y la mesa no parece un
fondo pegado detrás. El rectángulo es el que usa el juego (`TABLE_RECT` en
`screens/game.gd`, en (528, 140)): de ahí para dentro nacen los objetos y hasta
ahí se pueden arrastrar, así que si se cambia el tamaño hay que cambiar los dos.
Son 168 y no 228 porque a la izquierda está la **columna de sobres**
(`PACK_ZONE`, en (32, 140) y 480 de ancho, con scroll).

### Componer las pantallas de ejemplo

```bash
python3 tools/make_screens.py                    # Sprites/mockups/shot_*.png
python3 tools/make_screens.py --size 1280x720    # a otra resolucion
```

Antes de ejecutarlo asegúrate de tener generados el fondo, el kit y los números:

```bash
python3 tools/make_sprites.py --all && python3 tools/make_background.py && python3 tools/make_screens.py
```

### Añadir un objeto nuevo

1. Abre `tools/make_sprites.py`.
2. Escribe `def draw_mi_objeto(s: Sprite) -> None:` dibujando a 1 píxel de arte
   sobre el lienzo de 32×32 con las primitivas `rect`, `ellipse`, `ring`, `poly`,
   `line`, `px` y `dots`.
3. Si el objeto debe recolorearse por rareza, usa la firma
   `(s: Sprite, rarity: Rarity)` y añádelo a `RARITY_ITEMS` con su prefijo en
   `RARITY_PREFIX`. Si no, añádelo a `LOOT_ITEMS`.
4. Genera con `--preview` y revisa la hoja de contacto.

El contorno `#101020` se añade automáticamente; no lo dibujes a mano. Para un
sprite que no debe llevar contorno (como un aura), pon `s.want_outline = False`.

Los sprites de interfaz se registran en `UI_ITEMS` con un `UiSpec`, que además
del tamaño lleva el **prefijo** del archivo y, si hace falta, una **escala
propia** (`scale=`), que es como los números salen a escala 8 mientras el resto
va a 16.

### Reducir un sprite a la mitad

Dividir por 2 con vecino más cercano es **exacto**: cada bloque de 16 px pasa a
uno de 8 px, así que sigue siendo pixel art nítido. Es lo correcto para meter
iconos grandes dentro de un panel. Lo que **no** hay que hacer es escalar por
factores no enteros (×0,75, ×1,5...): ahí los bloques salen de tamaños distintos
y el ojo lo nota.

## Normalizar sprites generados con IA

Lo que devuelve el generador de imágenes **no** se copia tal cual: pasa cada PNG
por `tools/normalize_sprite.py`, que quita el fondo, recorta el sobrante, centra
el objeto, reescala con vecino más cercano, deja el alfa en dos valores y
opcionalmente bloquea la paleta a los colores exactos de arriba.

```bash
python3 tools/normalize_sprite.py ~/Baixades/descarga.png \
    --name pack_vinyls --grid 32 --lock-palette
python3 tools/normalize_sprite.py ~/Baixades/lote/*.png --grid 32
```

El destino lo pone el prefijo del `--name` (`pack_` → `packs/`), y la
herramienta **añade la entrada al índice** por si sola, que es lo que hace que el
juego lo encuentre sin tocar nada. Los originales se dejan en `../source_art/`,
fuera de `Sprites/`, porque ahí Godot no los importa.

> **El paso del alfa importa más de lo que parece.** Una imagen de IA viene con
> el borde suavizado: los dos originales de Gemini traían 253 niveles de alfa.
> `--grid 32` los deja en 13, y solo porque la imagen es pequeña siguen
> *"pareciendo* duros; sobre la mesa se ven como un halo. El normalizador los
> baja a 0 o 255 por defecto, que es lo que usa el resto del juego. Si de verdad
> quieres el alfa suave, `--soft-alpha` lo deja como estaba.

Usa `--grid 32` siempre: baja el sprite a la rejilla de arte y luego escala con
factor entero, que es lo que deja los píxeles uniformes. Detalles de cada opción
en [`PROMPTS.md`](PROMPTS.md#post-proceso-obligatorio).

## Sprites que faltan

El script cubre bien las formas geométricas (discos, cajas, carcasas), pero
peor las formas orgánicas y las escenas complejas. Para los paquetes con la
envoltura a medio rasgar es mejor tirar de IA: están prompts listos, sprite a
sprite, en [`PROMPTS.md`](PROMPTS.md).

Pendiente a día de hoy:

```
loot_*  faltan ~3 objetos: 1 mas en electrónica, 2 en varios
```

Los `pack_*` (cerrados y rotos), los `tool_*`, los `condition_*`, los `grade_*`,
las sombras y los siete iconos de UI de segunda generación ya están hechos por
script, así que salen de la lista.

> **Lo que ya no es un problema: sobres con una sola cara.** El de vinilos y el
> de zapatillas.tenian las cuatro filas apuntando al mismo PNG, asi que abrir
> 200 sobres era una ruleta de una cara con cuatro precios. Ahora cada uno de
> esos dos sobres da un dibujo distinto. Los de electrónica y varios ya tenian
> tres objetos, pero comparten dibujo entre filas de distinta rareza, que es
> menos grave: ahi la rareza y el valor justifican el salto.
>
> El reparto de lo que queda esta en `PROMPTS.md`, por categoría.

---

## Dónde se usan

Desde la v1 del juego (ver `../README.md`). El juego los pide **por nombre corto**,
nunca por ruta: `Sprites.tex("loot_vinyl_psa7")` en `../scripts/ui/sprites.gd`
consulta `index.tsv` y carga lo que pone. Y los coloca `UIKit`
(`../scripts/ui/ui_kit.gd`), que es quien sabe si algo va a `square()` (arte de
512, escalado ×512) o a `art()` (arte de 256, escalado sobre su tamaño real).

Excepción: el anillo de espera **no** se pinta con `ui_timer_fill`, que es solo
un cuarto de anillo. `../scripts/ui/timer_ring.gd` lo dibuja celda a celda sobre
la misma rejilla de `ui_timer_track`, y `ui_timer_fill` queda sin usar de momento.

Y la fuente no pasa por el índice: `font_pack.fnt` va como `default_font` del
tema (`../scenes/ui/game_theme.tres`), y `UIKit` la carga por `res://` porque
una fuente no es una picture.
