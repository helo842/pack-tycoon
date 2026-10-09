# PACK TYCOON — primera versión jugable

Incremental 2D de abrir paquetes, hecho en **Godot 4.7** con los sprites que genera
`tools/make_sprites.py`. El documento de diseño original (`Idea.pdf`) no se publica
aqui; este README explica lo mismo que hacia falta saber de el.

Esta es la **v1**: el bucle principal funciona de principio a fin y se puede
jugar. No está todo lo del documento (el final está en *Qué falta*).

---

## Cómo abrirlo

Apunta `G` al ejecutable de Godot 4.7 de tu máquina (puedes bajarlo de
[godotengine.org](https://godotengine.org/download) si no lo tienes):

```bash
G=/ruta/a/Godot_v4.7.2-stable_linux.x86_64

cd "ruta/de/este/proyecto"
$G --path . --editor
```

Y para jugar sin editor:

```bash
$G --path .
```

La primera vez Godot importa los 330 PNG de `Sprites/` (tarda unos segundos).
A partir de ahí, botón de arriba a la derecha para jugar.

### El editor se ve vacío, ¿está roto?

No. Al abrir el proyecto el visor del editor sale **en blanco a propósito**:
las escenas tienen un solo nodo y toda la interfaz se monta en código (ver
*Las escenas tienen un solo nodo*, más abajo). El editor solo dibuja lo que hay
escrito en el `.tscn`, y ahí no hay ningún botón todavía.

Para ver el juego hay que **ejecutarlo**: `F5`, o el botón **▶** de arriba a la
derecha. En 10 segundos se ve la pantalla de inicio con JUGAR y AJUSTES.

---

## El bucle

1. **Columna de sobres de la izquierda** → compras un paquete a ciegas, sin abrir
   ningún menú. Cae en un punto al azar de la mesa. Hay **doce sobres: cuatro
   tipos × tres escalones**, alternados en la columna (sobre, vinilo, zapatillas,
   electrónica, y otra vez con más precio y más botín):

   | | escalón 1 | escalón 2 | escalón 3 |
   |---|---|---|---|
   | **SOBRES** | gratis | 4.000 | 80.000 |
   | **VINILOS** | 1.000 | 20.000 | 400.000 |
   | **ZAPATILLAS** | 6.000 | 120.000 | 2.500.000 |
   | **ELECTRÓNICA** | 25.000 | 500.000 | 10.000.000 |

   La columna **tiene scroll**: doce filas de 232 px son 2784 px de lista en una
   ventana de 752, así que la columna es una ventana a la lista larga (rueda del
   ratón o la barra, fina y atenuada) en vez de doce filas apinadas. En la
   ventana se ven tres filas y pico. La columna es ancha lo que le deja la mesa:
   ensancharla pedía rehacer la mesa y su fondo, así que todo lo que creció
   (dibujo, nombre y precio, un 50 % más grandes) creció hacia abajo, y el scroll
   es el precio que se paga por eso.

   Cada fila va en **dos líneas**: el **nombre** arriba en crema, a lo ancho de
   toda la columna, y debajo el hueco del sobre con la chapita del precio al
   lado. El nombre estuvo a la derecha del dibujo y ahí no había forma de
   agrandarlo: al lado de un hueco de 176 px quedaban 294 px, y «ELECTRÓNICA 3»
   ocupa 273 px ya a tamaño 21 (la fuente mide 7 px de ancho por carácter a
   tamaño 7). Con el nombre arriba cabe a 28 sin tocar el dibujo.

   La chapita del precio es **alta a propósito**, no solo ancha: el dibujo de la
   cinta solo pinta una banda en medio (un 59 % del alto con el que se estira, ver
   `PACK_TAG_INK`), así que con la chapa baja el número se salía por arriba y por
   abajo y se leía *encima* de la cinta. El smoke test compara el precio contra la
   **banda**, no contra el hueco del sprite.

   El hueco del sobre es un cuadrado oscuro sin marco con el **dibujo del sobre
   escalado por su dibujo** (`UIKit.fit_art` mide la tinta con
   `Sprites.used_rect`), de forma que los cuatro tipos llenan su hueco aunque
   ocupen trozos muy distintos del lienzo de 512 (las cartas 256×496, las
   zapatillas 480×272) — con el marco de ranura que había antes, dentro quedaba
   siempre un hueco de más.

   Detrás de todo eso va un **fondo negro opaco** (`PackBackdrop`, un `ColorRect`
   sin alfa). La columna estuvo sin fondo, y sobre las monedas, las cajas y los
   estantes claros de la trastienda los nombres y los precios de ocho y nueve
   cifras no había quien los leyera: con un fondo propio, la columna es una
   tienda y no un texto pegado al decorado. La raya dorada de su borde derecho
   (`PackEdge`) es la misma que separa la barra de arriba de la mesa.

   El **SOBRES** del primer escalón es gratis en cualquier momento de la partida
   (su chapita pone GRATIS): además del sobre con el que se empieza, es el seguro
   para no quedarse nunca sin poder abrir nada. Los tres escalones de un tipo dan
   **los mismos objetos**, cada vez multiplicados: subir de escalón es pagar más
   por lo mismo ×20 (escalón 2) o ×400 (escalón 3). Y aguantan más: la vida de un
   escalón 1 es 45, 90, 180 y 360, y los escalones 2 y 3 van a 1,5 y a 2 veces
   eso. La **TIENDA** se ha quedado con los ocho items.
2. **Clic en el paquete** → arranca la carga. Sale un anillo que se llena **por
   detrás del paquete**, rodeándolo, y el paquete va temblando. Cada carga
   completa es un **golpe**: el paquete tiene una resistencia (la barra de
   arriba de la caja) y hacen falta **varios clics** para bajarla a cero, uno
   por ciclo (no se abre solo de una tirada). A medida que se daña, el sprite
   cambia (agrietado, roto...).
3. Cuando la resistencia llega a cero, sale la **tarjeta de revelado**: objeto, rareza,
   estado de conservación, nota PSA de 1 a 10 y el valor final. Abajo tiene los
   dos botones de la decisión: **GUARDAR** (al inventario) y **VENDER** (dinero
   ahora). Cerrarla sin elegir —clic fuera, `ESPACIO` o `ESC`— deja el objeto en
   la mesa, que es la tercera salida.
4. El objeto se queda en la mesa. **Clic en él** y se vende; **arrastrarlo** lo
   aparta y hace sitio, como en los juegos de cachivaches. Al inventario solo va
   si se pulsa GUARDAR, y de ahí se vende de golpe con **VENDER TODO**, en el
   panel del armario, que es donde vive el inventario desde que la tira de abajo
   de la pantalla es la vitrina.

La mesa es una superficie de verdad, no una rejilla de huecos: el sprite
`bg_table` la dibuja entera (1344×752, que es lo que le deja la columna de
sobres) y los objetos caen donde quieren, con un
sorteo de 40 puntos al azar que se queda con el que menos pisa a los demás.Se arrastran manteniendo pulsado y no pueden salirse de ella. Caben **8** a la vez
(el **Cajón** amplía ese límite).

Encima hay dos automatizaciones, los dos iconos de la barra superior. **Cada una
necesita su pieza** (los Pinchos y el PC): hasta que no la tienes, su botón sale
atenuado y al pulsarlo el aviso dice qué falta.

| Icono | Qué hace | Pieza |
|---|---|---|
| `ui_icon_auto_open` | Abre sola los paquetes que estén esperando en la mesa | Pinchos |
| `ui_icon_auto_buy`  | Compra sola el más barato de los sobres marcados en su mini menú | PC |

Y en **AJUSTES**, la casilla de **venta automática**: con ella puesta, todo lo que
salga de una caja se vende en el momento, sin tarjeta de revelado y sin llegar a
tocar la mesa.

Los **items** de la tienda ya no acortan la espera: cambian **cómo se abre** el
paquete. Son los ocho del `Idea.pdf` y hay **dos clases**, que se distinguen de
un vistazo en la tienda:

- **Los seis de estadísticas suben de nivel**, hasta **8**: cada nivel cuesta
  ×1,9 el anterior y da más efecto, y cada nivel comprado de *cualquiera* de
  ellos sube el daño un 18 % sobre la base y acelera un 5 % la carga. La fila
  lleva los **puntos de nivel** a la vista y, al llegar al tope, deja de
  enseñar precio y pone **AL TOPE**.
- **El PC y los Pinchos son de compra única**: se pagan una vez y ya está. Su
  efecto es un sí o un no —la automatización está encendida o no—, así que
  pagarlos ocho veces no tendría sentido. Su fila lo **dice**: donde los otros
  llevan los puntos de nivel pone **COMPRA ÚNICA**, y al comprarlos quita la
  chapa del precio y pone **COMPRADO**. Sin ese rótulo la fila solo se
  distinguía por lo que *no* tenía (ni puntos ni segundo precio), y eso hay que
  deducirlo; con él, que no vuelvan a la tienda deja de ser una sorpresa.

Quién es cuál no lo decide una lista aparte: son `LootDB.AUTO_ITEM_OPEN` y
`LootDB.AUTO_ITEM_BUY` (los mismos ids que encienden las automatizaciones), y lo
contesta `LootDB.item_max_level()`.

| Item | Qué hace |
|---|---|
| **Guantes** | Suben cuántos paquetes caben **a la vez** cargando (+2 por nivel): un clic sigue arrancando uno |
| **Trébol** | +2 % de peso a los objetos que no son comunes por nivel |
| **Cajón** | +2 huecos de mesa por nivel, y +5 por nivel a partir del 5 |
| **Ojo verde** | +5 % de probabilidad de crítico por nivel (el 40 % a los ocho) |
| **Láser** | +5 % de daño en cada crítico por nivel |
| **PC** | **Compra única**: enciende la compra automática (y solo eso: no necesita los Pinchos) |
| **Pinchos** | **Compra única**: encienden la apertura automática, golpean la mesa solos |
| **Armario** | Abre el panel del armario: expone objetos del inventario, **un hueco por nivel (de 1 a 8)** |

### El armario: exponer objetos

El armario es un **trato con vuelta atrás**: un objeto expuesto sale del
inventario (ya no se puede vender) y a cambio da el bonus de su tipo, que es la
única forma de subir los cuatro stats del juego. Se pulsa el objeto en el
inventario y entra en la vitrina; se pulsa en la vitrina y vuelve. Sin la pieza
comprada no hay huecos donde ponerlo, y por eso el armario sube de nivel como
los demás items: **un hueco por nivel, de 1 a 8**, y los ocho marcos se dibujan
siempre —los que no son tuyos, apagados— para que se vea que subirlo sirve para
algo.

**Los cuatro tipos de botín no dan lo mismo**, y cada uno va a su stat:

| Tipo de botín | Qué sube |
|---|---|
| **CARTAS** | el daño del golpe |
| **VINILOS** | el dinero que dan las ventas |
| **ZAPATILLAS** | la velocidad de carga del clic |
| **ELECTRÓNICA** | las monedas de rebirth |

Cuánto aporta cada objeto lo decide **su nota PSA**: de un **2 % en la nota 1 a
un 15 % en la 10**, repartido a partes iguales. Son porcentajes bajos a
propósito: ocho vitrinas llenas de piezas de nota 10 son +120 % repartido entre
los cuatro stats, y con el armario lleno el jugador ya nota que trabaja.

En la pantalla de partida **no hay inventario**: la tira de abajo es **la
vitrina** (los objetos expuestos de un vistazo, y cada hueco abre el panel), y la
chapa **ARMARIO** de la barra de arriba va pegada a las dos automatizaciones, que
son las tres cosas que se encienden y se miran de reojo mientras la mesa trabaja.
Dentro del panel está lo que hace falta para decidir: **el inventario a la
izquierda** (50 huecos, con scroll) y **las vitrinas a la derecha**, con la suma
de cada bonus debajo y **VENDER TODO** al pie, que es la única forma de vaciar el
inventario desde que vive aquí.

### El rebirth (la hucha)

En el **menú**, arriba a la derecha, está la hucha: las monedas que llevas y el
botón de REBIRTH, que abre su panel. El rebirth **reinicia la partida entera**
(dinero, items, inventario y armario) y a cambio te llevas **monedas**, que ya no
se pierden nunca más: **cada moneda sube un 5 % el valor de todo lo que vendas**,
para siempre. Es la única cosa del juego que pasa de una partida a la siguiente,
y por eso vive en el menú y detrás de un panel que explica el trato antes de
aceptarlo (lo que se pierde, lo que te llevas y cuánto multiplica la Electrónica
del armario).

El requisito se mide en **lo ganado en la partida** (un millón), no en el dinero
que tengas en el bolsillo: guardarlo para el final no cambia nada. Las monedas
son una por cada millón ganado y **la Electrónica del armario las multiplica**,
que es la razón de que el armario dé puntos de rebirth. Lo que no se pierde son
las estadísticas de la cuenta —paquetes abiertos, objetos encontrados, mejor
nota—, que son de la cuenta y no de la partida. Y mientras el requisito no llega,
el botón y su panel **dicen cuánto falta**: un botón muerto y callado no explica
nada.

**Un clic abre UN paquete, siempre: el pulsado.** Nada de arrancar varios de
golpe, porque eso convertía el bucle en machacar siempre el mismo sobre. Lo que
suben los Guantes es cuántos paquetes caben **a la vez**: sin ellos la mesa
lleva uno solo, y un clic en otro mientras el primero está a medio abrir no hace
nada (el que ya se está trabajando sigue aceptando clics, y el turno se suelta
cuando la caja se rompe). Con Guantes caben 3 (5 al nivel 2, y así), y el jugador
tiene que ir pulsando uno y otro para que avancen todos: insistir en el mismo no
adelanta más que el suyo. Es la diferencia entre jugar a mano y jugar con la mesa
montada, y el motivo de que los Guantes sean el primer item del catálogo.

### Las automatizaciones: cada botón con su pieza

**Cada automatización va con SU item, y con ese solo.** El botón de la
**apertura automática** se enciende con los **Pinchos**; el de la **compra
automática**, con el **PC**. Comprar una pieza enciende lo suyo sin esperar a la
otra: antes hacían falta los Pinchos **y** el PC para cualquiera de las dos, y
comprar el PC y que su botón siguiera apagado solo se lee como que la compra no
ha servido de nada. Mientras falta la pieza de un botón, ese botón sale atenuado
y, al pulsarlo, el aviso dice **qué pieza falta** (`LootDB.AUTO_ITEM_OPEN` y
`LootDB.AUTO_ITEM_BUY`).

- La **apertura automática** son los Pinchos: al encenderla, los Pinchos golpean
  solos todos los paquetes de la mesa. Apagada no hacen nada —el que golpea es el
  jugador—, así que el item comprado no basta: hay que darle al interruptor.
- La **compra automática** es el PC, y su botón abre un **mini menú**
  (`AutoBuyPanel`) donde se marca qué sobres se compran solos. Compra **el más
  barato de los marcados** que puedas pagar: con los once marcados va subiendo de
  escalón sola según te enriqueces, y marcando solo los de arriba se apunta a lo
  caro. El sobre gratuito no sale en la lista porque la compra automática lo
  salta siempre (si entrara, se quedaría en él para siempre).

**El desgaste va en el sprite.** Cada objeto tiene diez dibujos
(`loot_vinyl_psa1` … `loot_vinyl_psa10`): el que sale de la caja se ve rayado,
sucio o con el plástico comido según la nota. La insignia de estado **se deduce
de la nota** (9-10 como nuevo, 7-8 buen estado, 4-6 gastado, 1-3 roto), no es una
tirada aparte, así que nunca contradice al dibujo. Por lo mismo el valor es solo
`base × multiplicador de nota`; el multiplicador de estado se eliminó y el de nota
se reescaló para que los precios de la tabla sigan valiendo lo que valían.

Las cartas también llevan las diez notas, y además son **cuatro dibujos
distintos** —común, edición limitada, vieja y holográfica— en vez de uno teñido
por rareza. El cartón se desgasta distinto a una consola (roce, humedad, esquina
doblada, pliegue, mancha de anillo), así que el desgaste de carta es otro código
en el generador.

La nota PSA reparte hacia arriba pero nunca es 10 fijo: el 10 es el premio gordo.

### Teclado

| Tecla | Qué hace |
|---|---|
| `ESPACIO` / `ENTER` | Cerrar la tarjeta sin elegir: el objeto se queda en la mesa |
| `ESC` | Cierra el panel abierto; si no hay ninguno, vuelve al menú |

La partida se guarda sola (cada 30 s si ha cambiado algo, y al salir) en
`user://packtycoon.json`.

---

## Cómo está montado

Cada carpeta tiene su propio README con el detalle. Este es el mapa:

```
project.godot          1920x1080, estirado canvas_items/keep, filtro NEAREST
icon.svg

Sprites/               330 PNG, en subcarpetas (ver Sprites/README.md)
  loot/                el botín: 17 objetos y 4 cartas, 10 notas PSA cada uno
  packs/               los sobres que se compran: cerrado, abierto y 3 de daño
                       (el juego usa cuatro: SOBRES, VINILOS, ZAPATILLAS y
                       ELECTRONICA; el de VARIOS queda de reserva)
  tools/               las herramientas antiguas (ya no se usan)
  items/               los 8 items equipables de la tienda
  ui/panels/           los marcos de ventana
  ui/controls/         botones, deslizadores, casillas, flechas, ranuras
  ui/icons/            los iconos sueltos
  ui/indicators/       gemas, estados, insignias de nota, sombras, moneda
  font/                la fuente del juego (font_pack.fnt) y los dígitos
  backgrounds/         el fondo de la trastienda y la superficie de la mesa
  mockups/             las maquetas de las pantallas
  index.tsv            nombre corto -> ruta. Lo lee el juego

Sounds/                11 WAV, en subcarpetas (ver Sounds/README.md)
  sfx/                 los efectos: moneda, rasgado, revelado, error...
  music/               la musica de fondo, un bucle que no llama la atencion
  index.tsv            nombre corto -> ruta. Lo lee el juego

scripts/               el código, por capas (ver scripts/README.md)
  core/                main, game_state y audio (los dos autoloads) y palette
  data/                loot_db: precios, botín, rarezas, PSA
  ui/                  ui_kit, sprites, y los controles con sprite
  screens/             una clase por pantalla

scenes/                un nodo raíz por pantalla (ver scenes/README.md)
  Main.tscn Game.tscn Menu.tscn ShopPanel.tscn AutoBuyPanel.tscn
  LockerPanel.tscn RebirthPanel.tscn ItemCard.tscn RevealCard.tscn
  SettingsPanel.tscn
  ui/game_theme.tres   el tema: la fuente y los colores de la interfaz

tools/                 los generadores de Python (ver tools/README.md)
dev/                   el test automático y las capturas (ver dev/README.md)
source_art/            el arte de partida, sin usar por el juego
```

Tres decisiones que explican casi todo lo demás:

**Las escenas tienen un solo nodo.** Toda la interfaz se monta en código, en el
`_ready()` de la escena. La razón es que casi todo lo repetitivo (una ranura por
paquete, una estrella por punto de la nota) se genera con un bucle, y así de
verdad. Las escenas existen para que la estructura se vea en el editor y para
tener los `.tscn` bien declarados.

**Los números no usan una fuente de Godot, son sprites.** `PixelNumber` compone
los `num_*.png` (glifos de 5×7 escalados ×8) en fila. Motivo: los numeros cambian
cada frame, y montar una fuente entera para eso seria tirar. El **resto del texto
ya es pixel art**: `tools/make_font.py` genera `Sprites/font/font_pack.fnt`, una
fuente de mapa de bits de 57 glifos con contorno incluido, que va como
`default_font` del tema. Se escala solo a multiplos enteros de 7 px
(`scaling_mode=1` + `UIKit.FONT_STEP`), asi que nunca sale borrosa. Las dos
fuentes salen de los mismos patrones 5x7 de `tools/font_patterns.py`.

**El anillo de espera se dibuja en tiempo real.** El sprite `ui_timer_fill` es
solo un cuarto de anillo (el generador lo hizo así a propósito: "el juego lo gira
cuatro veces"), y estirarlo deforma el chaflán. `TimerRing` pinta en su lugar
celda a celda sobre la misma rejilla de 16×16 del sprite `ui_timer_track`, con
los mismos colores. Sale un anillo pixel a pixel de verdad.

**El anillo se dibuja DETRÁS del paquete**, y ese es el arreglo, no un detalle.
El sprite `ui_timer_track` es un disco con un agujero: medido píxel a píxel, su
banda pintada va de 36 a 137 px de un lienzo de 256. El paquete, además, no es un
cuadrado: su parte pintada es un rectángulo de 128×248 **centrado en el mismo
punto** que el anillo. Puesto delante, la banda del anillo cruza el paquete de
lado a lado lo grande que sea (era el fallo que se veía: el círculo tapaba el
paquete entero). Detrás, el paquete se come la mitad de dentro del anillo y solo
se ven los arcos que sobresalen por los lados, que es lo que se quiere de un
anillo de espera. Hay un check que lo fija: el anillo tiene que ir *antes* que el
dibujo en el árbol.

---

## Para desarrollo

```bash
G=/ruta/a/Godot_v4.7.2-stable_linux.x86_64

# Prueba de integración: recorre el bucle entero sin ratón y dice qué falla.
$G --headless --path . res://dev/SmokeTest.tscn     # sale con 0 si todo pasa

# Prueba del ratón: manda clics de verdad a los botones.
# smoke_test llama a los métodos a mano, así que no pasa por la interfaz; esta
# comprueba justo eso (menú, tienda, cerrar y la mesa).
$G --headless --path . res://dev/InputTest.tscn     # sale con 0 si todo pasa

# Un PNG de cada pantalla en user://shots/, para revisar la interfaz.
$G --rendering-driver opengl3 --path . res://dev/Screenshots.tscn
```

Si se acaba de añadir una escena o un `class_name` nuevo, Godot tiene que
importar antes (`$G --headless --path . --import`) o los dos tests se caen con
`Could not find type "LockerPanel"` y parece un fallo del juego cuando el que
falta es el paso de la importación.

`smoke_test` toca las 429 cosas que se pueden romper sin que se note
mirando capturas: que la escalera de los doce sobres suba en precio, en botín, en
resistencia y **en dibujo** (los tres escalones de un tipo ya no comparten
sprite, y el arte de cada uno tiene que traer sus tres tramos de daño), que el
sobre inicial no cobre nunca y los demás sí, que las doce filas de la columna
caben sin pisarse, que la columna tenga su **fondo opaco** y que vaya **detrás**
de los sobres, que el anillo avance y que se dibuje
**detrás** del paquete, que cada redonda del botón saque su **número de daño**
(naranja el golpe normal y amarillo el crítico, encima del paquete y con el daño
que toca), que los items de la tienda sean **ocho cajas** en rejilla que no se
pisen, que al pulsar una se abra su **ficha** con la descripción larga y los
números del efecto de ahora y del nivel siguiente (y que esos números se
repinten al comprar), que se compre desde esa misma ficha, que los items suban
el daño y aceleren la carga, que el
precio de un item suba con cada nivel y desaparezca en el tope, que el PC y los
Pinchos no se puedan pagar dos veces (y que la tienda los marque con COMPRADO y
con el rótulo COMPRA ÚNICA, con puntos de nivel solo en los seis que los tienen),
que una caja necesite varios golpes, que la mesa no pase de 8, que con la mesa llena no se cobre el sobre, que la tienda ya no venda sobres ni lleve título ni el rótulo del daño y sí la moneda del contador, que la moneda de los ajustes no salga gigante, que GUARDAR meta el
objeto en el inventario y lo saque de la mesa (y VENDER al contrario), que con la
venta automática el objeto no llegue ni a la mesa, que un clic arranque un solo
paquete y que sin Guantes solo se trabaje uno a la vez (y que con ellos el cupo
sea el que dice `Game.open_count()`, con el que espera entrando en cuanto se
suelta un hueco), que la apertura automática se encienda solo con los
Pinchos y la compra automática solo con el PC, que los Pinchos no toquen la mesa con la
apertura apagada, que la compra automática compre solo lo marcado en su mini
menú y coja el más barato de lo marcado, que arrastrar no venda el botín y que
no se pueda sacar de la mesa, que **cada tipo de botín dé su bonus** (cartas el
daño, vinilos el dinero, zapatillas la velocidad y electrónica el rebirth) y que
ese bonus vaya de un **2 % en la nota 1 a un 15 % en la 10**, que la probabilidad
de crítico sea de un **5 % por nivel** del Ojo verde, que el armario tenga
**exactamente los huecos de su nivel** (con dos, el tercer objeto no entra) y que
exponer **saque el objeto del inventario** y devolverlo lo devuelva, que el
inventario sea de **50 huecos** y ya no esté en la pantalla de partida, que la
vitrina de la partida enseñe lo expuesto, que **el texto no se dibuje encima de
un objeto** (el check que cazó un solape de verdad en el panel del armario), que
el panel del rebirth prometa **las mismas monedas que da** el rebirth y que el
multiplicador de la Electrónica entre en el premio, que la tienda cierre, que se
guarde el fichero, que ningún sprite ni ningún sonido se quede fuera de su
índice…

`input_test` manda clics y arrastres de verdad, que es lo que `smoke_test` no
puede hacer: pasa por el sistema de interfaz para pulsar GUARDAR y VENDER en la
tarjeta, para comprar un sobre en la columna de la izquierda, para pulsar una
caja de la tienda y comprar desde la ficha que abre, para agarrar un objeto de la
mesa y moverlo, para abrir el mini menú de la compra automática y marcar y
desmarcar un sobre en su lista, para abrir el armario desde su botón de la barra
y exponer un objeto y devolverlo a su sitio, y para reiniciar la partida desde la
hucha del menú.

### Cambiar el equilibrio

Todo está en `scripts/data/loot_db.gd`, y solo ahí: precios, resistencia (`hp`),
daño, items, qué cae en cada paquete y cuánto vale. Añadir un objeto nuevo es
añadir una fila a la lista `loot` de un paquete; no hay que tocar la interfaz.

---

## Qué falta

**Variedad de botín** — ya está resuelta. Cada objeto tiene su dibujo propio y
cada sobre va por temas: cartas, vinilos, zapatillas y electrónica, que además
absorbió los relojes, los lingotes y los cables para que ningún objeto se quede
sin sobre del que salir. Quedan un par de objetos por añadir (una cámara de fotos
y un violín), repartidos en `Sprites/PROMPTS.md`.

> Lo que había era peor de lo que parecía: los sobres de vinilos y de zapatillas
> tenían cuatro filas apuntando al mismo PNG, así que abrir 200 cajas era una
> ruleta de una cara con cuatro precios. Electronica y varios compartían
> dibujo entre filas de distinta rareza.

**Las cartas ya se desgastan**, y además son cuatro dibujos distintos y no uno
teñido por rareza, que es lo que había antes. El desgaste de carta es otro
código (`apply_card_wear()`): roce de borde, humedad, esquina doblada, pliegue y
mancha de anillo.

**Sonido** — ya está: once WAV que genera `tools/make_sounds.py` (diez efectos y
una música de fondo en bucle) y los deslizadores de MÚSICA y SONIDOS enchufados a
los buses de verdad. Ver `Sounds/README.md`. Queda **un sonido por material**: hoy
el rasgado es el mismo en un sobre de cartón que en una caja de plástico, que era
justo lo que pedía el documento.

**Fuente del texto** — ya está: `font_pack.fnt`, mapa de bits propio. Lo que queda
es qué pasa con la fuente de los **números**, que aún se componen con sprites
(`PixelNumber`) en vez de usarse como fuente.

**El armario, la vitrina y el rebirth** — ya están. El armario deja de ser un
adorno: expone objetos (uno por hueco de su nivel, de 1 a 8), cada uno da el
bonus de su tipo según su nota PSA, y su panel lleva el inventario al lado (50
huecos) con la vitrina a la vista en la pantalla de partida. Y la hucha del menú
ya reinicia la partida a cambio de monedas, que suben para siempre el valor de lo
que vendes.

**Sistemas del documento que no están** — árbol de habilidades (4 ramas × 2
opciones), logros, eventos de mercado.

**Extras de la interfaz** — los deslizadores de volumen de los ajustes ya mueven
sus buses, y la casilla de venta automática enciende y apaga el ajuste. Falta el
**selector de idioma**, que está puesto pero sin nada detrás (no hay más texto que
el español), y el botón de empezar de cero (`hard_reset()` lo hace, pero solo lo
llaman las pruebas).
