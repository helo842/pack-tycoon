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

La primera vez Godot importa los 306 PNG de `Sprites/` (tarda unos segundos).
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

1. **TIENDA** → compras un paquete a ciegas. Cae en un punto al azar de la mesa.
2. **Clic en el paquete** → arranca la espera. Sale un anillo que se llena **por
   detrás del paquete**, rodeándolo, y el paquete va temblando.
3. Cuando el anillo se llena, sale la **tarjeta de revelado**: objeto, rareza,
   estado de conservación, nota PSA de 1 a 10 y el valor final. Abajo tiene los
   dos botones de la decisión: **GUARDAR** (al inventario) y **VENDER** (dinero
   ahora). Cerrarla sin elegir —clic fuera, `ESPACIO` o `ESC`— deja el objeto en
   la mesa, que es la tercera salida.
4. El objeto se queda en la mesa. **Clic en él** y se vende; **arrastrarlo** lo
   aparta y hace sitio, como en los juegos de cachivaches. Al inventario solo va
   si se pulsa GUARDAR, y de ahí también se puede vender (un clic por hueco, o
   VENDER TODO de una vez).

La mesa es una superficie de verdad, no una rejilla de huecos: el sprite
`bg_table` la dibuja entera (1824×752) y los objetos caen donde quieren, con un
sorteo de 40 puntos al azar que se queda con el que menos pisa a los demás. Se
arrastran manteniendo pulsado y no pueden salirse de ella. Caben **8** a la vez.

Encima hay dos automatizaciones, los dos iconos de la barra superior:

| Icono | Qué hace |
|---|---|
| `ui_icon_auto_open` | Abre sola los paquetes que estén esperando en la mesa |
| `ui_icon_auto_buy`  | Compra sola el paquete más barato que puedas pagar |

Y en **AJUSTES**, la casilla de **venta automática**: con ella puesta, todo lo que
salga de una caja se vende en el momento, sin tarjeta de revelado y sin llegar a
tocar la mesa.

Las **herramientas** (cortador, tijeras, guantes, palanca) no hacen daño:
acortan la espera. Cada nivel suma un 22 % al divisor, hasta 5 niveles por
herramienta. La barra superior muestra el multiplicador actual (`x2.32`).

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

Sprites/               306 PNG, en subcarpetas (ver Sprites/README.md)
  loot/                el botín: 17 objetos y 4 cartas, 10 notas PSA cada uno
  packs/               los sobres que se compran, cerrado y abierto
  tools/               las herramientas equipables
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
  Main.tscn Game.tscn Menu.tscn ShopPanel.tscn
  RevealCard.tscn SettingsPanel.tscn
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

`smoke_test` toca las 186 cosas que se pueden romper sin que se note
mirando capturas: que comprar descuente, que el anillo avance y que se dibuje
**detrás** del paquete, que las herramientas acorten la espera, que la mesa no
pase de 8, que con la mesa llena se devuelva el dinero, que GUARDAR meta el
objeto en el inventario y lo saque de la mesa (y VENDER al contrario), que con la
venta automática el objeto no llegue ni a la mesa, que arrastrar no venda el
botín y que no se pueda sacar de la mesa, que la tienda cierre, que se guarde el
fichero, que ningún sprite ni ningún sonido se quede fuera de su índice…

`input_test` manda clics y arrastres de verdad, que es lo que `smoke_test` no
puede hacer: pasa por el sistema de interfaz para pulsar GUARDAR y VENDER en la
tarjeta, y para agarrar un objeto de la mesa y moverlo.

### Cambiar el equilibrio

Todo está en `scripts/data/loot_db.gd`, y solo ahí: precios, tiempos de espera, qué
cae en cada paquete y cuánto vale. Añadir un objeto nuevo es añadir una fila a
la lista `loot` de un paquete; no hay que tocar la interfaz.

---

## Qué falta

**Variedad de botín** — ya está resuelta. Los cinco sobres dan un dibujo
distinto por objeto: cartas 4, vinilos 4, zapatillas 4, electrónica 5 y varios
6, cada uno con sus diez notas PSA. Quedan un par de objetos por añadir (una
cámara de fotos y un violín), repartidos en `Sprites/PROMPTS.md`.

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

**Sistemas del documento que no están** — árbol de habilidades (4 ramas × 2
opciones), inventario expandible, vitrina/armario, logros, rebirth con la hucha
de oro, eventos de mercado.

**Inventario fijo en 10 huecos** — si se llena, el botín se vende solo y sale un
aviso. Ampliarlo es parte del sistema de inventario que falta.

**Extras de la interfaz** — los deslizadores de volumen de los ajustes ya mueven
sus buses, y la casilla de venta automática enciende y apaga el ajuste. Falta el
**selector de idioma**, que está puesto pero sin nada detrás (no hay más texto que
el español), y el botón de empezar de cero (`hard_reset()` lo hace, pero solo lo
llaman las pruebas).
