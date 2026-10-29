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
   | **SOBRES** | gratis | 15.000 | 600.000 |
   | **VINILOS** | 500 | 40.000 | 1.500.000 |
   | **ZAPATILLAS** | 1.900 | 100.000 | 4.000.000 |
   | **ELECTRÓNICA** | 6.000 | 250.000 | 10.000.000 |

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
   **los mismos objetos**, multiplicados por el escalón (`vmult`), y el precio va
   en escalera de verdad: **ningún sobre de un escalón es más barato que los del
   anterior**. El escalón 2 arranca en 15.000 (el 1 llega a 6.000) y el 3 en
   600.000 (el 2 llega a 250.000). Cuando los escalones se cruzaban —SOBRES ORO a
   4.000, más barato que la ELECTRÓNICA del escalón 1— no había ninguna razón
   para comprar la electrónica ni las zapatillas del escalón 1: con el mismo
   precio por dinero y más botín arriba, lo racional era saltárselas, y se
   quedaban sin comprar nunca. A cambio, **cada sobre paga entre un 30 y un 45 % más de lo que
   cuesta**, sea cual sea el escalón: lo que compra subir de escalón es capital
   (mueve más dinero por el mismo porcentaje), no rentabilidad, así que ni el de
   arriba es un chollo ni el de abajo una pérdida. Y aguantan más: la vida va con
la **raíz** del precio (21,5 × √precio), así que los cuatro del escalón 1 son
215 (el básico, que es gratis, va puesto a mano), 480, 937 y 1.665, los del 2
son 2.633, 4.300, 6.799 y 10.750 y los del 3 son 16.654, 26.332, 43.000 y
67.989. Un sobre que cuesta cuatro veces más no es
   cuatro veces más duro, es el doble: eso deja el ritmo de la partida en el
   **daño del jugador** —los items— y no en lo caro que sea el sobre, y es lo
   que hace que una partida dure unos dieciséis minutos en vez de dos minutos. La
   **TIENDA** se ha quedado con los diez items.
2. **Clic en el paquete** → arranca la carga. Sale un anillo que se llena **por
   detrás del paquete**, rodeándolo, y el paquete va temblando. Cada carga
   completa es un **golpe**: el paquete tiene una resistencia y hacen falta
   **varios clics** para bajarla a cero, uno por ciclo (no se abre solo de una
   tirada). La resistencia **no se enseña en ninguna barra**: lo dice el propio
   dibujo, que se agrieta en tres tramos y acaba abierto. Un ciclo dura **1,65 s** y, sin
   nada comprado, cada golpe quita **45** de daño: el sobre básico (215 de vida,
   gratis) se abre en **cinco golpes**. El ritmo es lento **a propósito** —la
   barra bajaba tan rápido que no daba tiempo a verla— y quien lo devuelve son
   los **Guantes**, un 15 % de velocidad por nivel. A medida que se daña, el
   sprite cambia (agrietado, roto...).
3. Cuando la resistencia llega a cero, sale la **tarjeta de revelado**: objeto, rareza,
   estado de conservación, nota PSA de 1 a 10 y el valor final. Abajo tiene los
   dos botones de la decisión: **GUARDAR** (al inventario) y **VENDER** (dinero
   ahora). Cerrarla sin elegir —clic fuera, `ESPACIO` o `ESC`— deja el objeto en
   la mesa, que es la tercera salida.
4. El objeto se queda en la mesa. **Clic en él** y se vende; **arrastrarlo** lo
   aparta y hace sitio, como en los juegos de cachivaches. Al inventario solo va
   si se pulsa GUARDAR, y de ahí se vende **de uno en uno** (clic derecho en el
   objeto) o de golpe con **VENDER TODO**, en el panel del armario, que es donde
   vive el inventario desde que la tira de abajo de la pantalla es la vitrina.

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
paquete. Son **diez** —los ocho del `Idea.pdf`, los **Guantes** (velocidad) y el
**Dólar**, que abarata los sobres— y hay **dos clases**, que se distinguen de un vistazo en la tienda:

- **Los ocho con niveles suben de nivel**, hasta **8**: cada nivel cuesta ×1,6
  el anterior —las **Tijeras** y los **Guantes** aparte: sus tres primeras
  mejoras suben poco (×1,3 cada una, para que el principio no se ponga cuesta
  arriba) y a partir de la cuarta el precio se dispara (×2,8); el **Dólar** usa
  esa misma escalera suave con un salto menor (×2,3), de 1.500 a 163.000— y da
  más efecto.
  Cada nivel comprado de *cualquiera* de ellos sube el daño un 15 % sobre la
  base y acelera un 3 % la carga. La fila lleva los **puntos de nivel** a la
  vista y, al llegar al tope, deja de enseñar precio y pone **AL TOPE**.
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
| **Tijeras** | El item de daño: **+15 % de daño por golpe por nivel** (las tres primeras mejoras salen baratas y suben poco; después el precio se dispara) |
| **Guantes** | El item de velocidad: **+15 % de velocidad de golpe por nivel** (misma escalera que las Tijeras, un poco más caros) |
| **Trébol** | +2 % de peso a los objetos que no son comunes por nivel |
| **Cajón** | +2 huecos de mesa por nivel, y +5 por nivel a partir del 5 |
| **Ojo verde** | +5 % de probabilidad de crítico por nivel (el 40 % a los ocho) |
| **Láser** | +5 % de daño en cada crítico por nivel |
| **PC** | **Compra única**: enciende la compra automática (y solo eso: no necesita los Pinchos) |
| **Pinchos** | **Compra única**: encienden la apertura automática, golpean la mesa solos |
| **Armario** | Abre el panel del armario: expone objetos del inventario, **un hueco por nivel (de 1 a 8)** |
| **Dólar** | **-5 % de precio en todos los sobres por nivel** (un 40 % a los ocho). Las tres primeras mejoras son baratas y las últimas, muy caras |

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
de cada bonus debajo y **VENDER TODO** al pie, que vacía el inventario de una vez.

En el inventario **el clic izquierdo expone y el clic derecho vende ese objeto**,
y solo ese: es lo que hacía falta para deshacerse de lo barato sin tocar lo bueno,
que con VENDER TODO era todo o nada. El gesto no se ve, así que lo dicen dos
sitios: el tooltip de cada hueco («Exponer NOMBRE (+8 % DAÑO) - clic derecho:
vender por 1.234») y la leyenda **CLIC: EXPONER - CLIC DERECHO: VENDER UNO**, en
la columna del inventario entre su rótulo y los huecos. El objeto vendido sale del inventario y paga su valor, el mismo número
que enseña su hueco. Las vitrinas no se venden así: lo expuesto vuelve antes al
inventario, que es la regla que ya tenía.

La **barra de arriba** lleva, de izquierda a derecha: el dinero con su moneda, el
**contador de monedas de rebirth** (el cerdito dorado y su número), el contador de
la mesa, los tres iconos (apertura automática, compra automática y armario), el
**VENDER**, la **TIENDA** y el **REBIRTH**, con los ajustes en el extremo. La
chapa del REBIRTH es **del mismo tamaño que la de TIENDA** (256 px de ancho, con
el cerdito al lado de la palabra) y las monedas de rebirth tienen **contador
propio en la barra**, no solo dentro del árbol de mejoras: son la moneda con la
que se compra ese árbol, así que hay que saber cuántas quedan **sin abrir nada**. Como la barra ya iba justa, el grupo de la
derecha se corrió otra vez a la izquierda: los tres iconos están a 808/904/1000,
el VENDER a 1156, la TIENDA a 1400 y el REBIRTH a 1672; el dinero se ancla a 128
con 252 px de tope, el cerdito es **del mismo tamaño que la moneda del dinero** y
va **pegado al último dígito** (se recoloca cada vez que el contador gana o
pierde una cifra, así que no flota en medio de la barra cuando hay poco dinero), y
el contador de la mesa pasó a 24 px de letra en una caja de 192 a x 656 para no
tocarlos.

Los objetos que salen de los sobres caen en la mesa **repartidos y con aire**: se
recorre la mesa entera en una rejilla y se elige uno de los sitios que no pisan a
nadie (16 px de hueco entre cajas, que con el dibujo de dentro son 44 px de aire
a la vista), y solo cuando de verdad no cabe otro se apila. Antes se probaban 40
puntos al azar y salían tres objetos encima de otro con media mesa vacía al lado.

### El rebirth y el árbol de mejoras

El rebirth está en la **barra de la partida, pegada a la TIENDA**, y no en el menú:
es la otra cosa que se hace «cuando se para» (vender, entrar en la tienda y
reiniciar la partida), y además es algo que se hace jugando, porque el requisito
—el dinero— se junta dentro de la partida. El **menú no tiene nada de esto** —es
la pantalla de empezar—: estuvo ahí con su hucha, su contador y su chapa, y en una
partida nueva lo que se veía era una hucha con un cero y un «TE FALTAN 80.000» en
rojo, o sea un sistema anunciado antes de que el jugador supiera que existe.

La chapa **REBIRTH** se puede pulsar siempre, también cuando la partida todavía no
llega: abre el árbol, que es quien dice cuánto falta. Sale **apagada** mientras no
haya nada que decidir, como los dos iconos de las automatizaciones. Las monedas se
leen **en su contador de la barra**, al lado del dinero, y en el tooltip de la
chapa.

El rebirth **reinicia la partida entera** (dinero, items, inventario y armario) y
a cambio te llevas **monedas**, que ya no se pierden nunca más: se **gastan en el
árbol de mejoras**. Lo que pasa de una partida a la siguiente son las monedas y lo
que hayas comprado con ellas, y por eso el rebirth se hace **desde dentro del
árbol**: arriba está el botón, con lo que te llevas (cuántas monedas y cuánto
multiplica la Electrónica del armario), y debajo, lo que se compra con ellas.

**Las monedas ya no dan nada solas.** Cada una subía un 5 % el valor de todo lo
que vendías sin hacer nada, y eso dejaba el rebirth sin decisión: se acumulaba
solo. Ahora el dinero es **un nodo del árbol** que hay que comprar, y las monedas
solo valen lo que compres con ellas.

#### El árbol: la barra arriba, el árbol debajo

La barra del rebirth va **superpuesta al árbol** y no al lado, porque el árbol **se
arrastra con el ratón** (pulsar y mover lo desplaza, y nunca se puede perder de
vista) y el saldo, lo que te llevas y lo que falta tienen que seguir leyéndose
mientras te mueves. Los nodos **no son botones**: un botón de verdad se comería la
pulsación, así que no se podría empezar a arrastrar encima de un nodo, que es
donde se empieza casi siempre. Un nodo son dibujos, y quien sabe cuál has pulsado
es el propio panel.

**Pulsar un nodo no compra: abre su ficha.** La compra se decide dentro, con la
tela delante —lo que da el nodo, lo que cuesta y **lo que el árbol lleva sumado
ya** frente a **lo que sumará al comprarlo**—, y se paga con el botón COMPRAR. Es
la misma ficha que la tienda usa para sus items (mismo panel, mismas medidas) y la
misma regla: **la ficha no compra, pide la compra**, y quien cobra, suena y avisa
es el panel del árbol. Los números de la ficha salen de `Game.skill_bonus()` y del
`value` del nodo, así que no pueden mentir.

El árbol empieza con **una mejora en el centro** —**+30 % de dinero, una moneda**,
que es la puerta— y de ella salen **cuatro caminos en diagonal**, uno por cada
lado, de **tres monedas cada uno**:

| Camino | Lo que da |
|---|---|
| **CARTAS** (arriba a la izquierda) | +20 % de daño |
| **ZAPATILLAS** (arriba a la derecha) | +20 % de velocidad |
| **ARMARIO** (abajo a la izquierda) | +2 huecos de armario |
| **PINCHOS** (abajo a la derecha) | +30 % de daño de los Pinchos |

Cada nodo se pinta según lo que se pueda hacer con él: **en dorado** el comprado
(con la palabra COMPRADO en lugar del precio), **claro** el que ya te llega,
**apagado** el que no, y **cerrado** el que necesita el nodo anterior —y su
ficha, la de ese y la de todos, dice cuál hay que comprar antes y cuántas monedas
faltan—. Las líneas que los unen llevan el color de su camino.

#### La calidad de vida: la rama de abajo

Debajo del centro, y aparte de los cuatro caminos, hay una rama de
**interruptores**: no suman ningún número, quitan trabajo. Son de **un solo
nivel** y cuestan menos que un camino, porque no se comparan con un +20 % —se
compran o no se compran—:

| Interruptor | Lo que quita | Monedas |
|---|---|---|
| **ATAJOS** | T la tienda, A el armario, R el rebirth y V vende la mesa | 1 |
| **SIN FICHA** | los objetos de tres estrellas o menos se venden al salir, sin abrir la tarjeta | 2 |
| **SOBRANTE** | el daño que le sobra a un golpe pasa al siguiente sobre | 2 |
| **MESA LIMPIA** | lo que lleva doce segundos quieto en la mesa se vende solo | 3 |
| **ARMARIO SOLO** | con el armario lleno, entra la mejor pieza de su tipo y la peor vuelve al inventario | 4 |

Tres detalles que se ven poco y son los que las hacen buenas:

- **SIN FICHA mide estrellas, no dinero.** Lo que vale un objeto sube con el
  escalón del sobre (una zapatilla común vale cuarenta veces una carta común), así
  que un umbral en dinero habría que moverlo con cada escalón; la nota va de 1 a 10
  en todos los sobres y se ve como estrellas en la ficha. El corte está en tres
  porque la nota 4 ya vale la media: venderla sin preguntar sería tirar dinero del
  jugador.
- **MESA LIMPIA no corre con la ficha abierta.** La mesa se vacía mientras el
  jugador está en la tienda o en el armario, no mientras está decidiendo qué hacer
  con lo que acaba de salir.
- **ARMARIO SOLO no empeora nunca el armario.** Solo cambia cuando el hueco falta
  y lo de dentro da menos; con sitio libre siempre se suma, porque dos piezas del
  mismo tipo suman las dos.

La rama **baja tres filas y no cabe en la vista** al abrir el árbol: se llega a
ella arrastrando, que es para lo que está el arrastre (el centro y los cuatro
caminos sí se ven de entrada).

El árbol **suma** a lo que ya tienes, nunca lo sustituye: los huecos de armario del
árbol son huecos aunque no tengas el armario comprado (con el tope de los ocho que
dibuja el panel del armario) y su daño se multiplica con el de las Cartas
expuestas. Y **no se pierde al reiniciar**: es lo que hace que reiniciar signifique
algo, porque las monedas se ganan reiniciando y se gastan aquí. Lo que se pierde
es la partida: dinero, items, inventario y armario.

El primer rebirth pide **80.000 en el contador**, que son **unos dieciocho minutos
de partida** (dieciséis el jugador típico con el botín en su media, catorce el que
juega rápido y compra bien, y trece con el PC y los Pinchos puestos): lo justo
para subir los tres escalones de sobres, comprar media docena de mejoras y llegar
con ganas de reiniciar. Ese número no es una esperanza, es una medida: lo dice
`dev/balance.gd`, que juega la partida entera con los datos de verdad (ver «Cambiar
el equilibrio»). Cuando ese requisito se medía en **lo ganado en la partida** eran
también unos dieciocho minutos, así que el ritmo es el mismo; lo que cambió es
**qué** se mide.

El **requisito** y el **premio** se cuentan sobre lo mismo: **el dinero que hay en
el contador**. Se piden **80.000** para poder reiniciar y cada **1,5 millones** dan
una moneda, así que gastar en sobres y mejoras antes de reiniciar **aleja las dos
cosas** y guardar el dinero las acerca. El número del requisito es bajo (en el
contador de una partida se manejan miles, no millones) y **está medido**, no
elegido: sale de barrer con `dev/balance.gd` y quedarse con el que deja la partida
durando lo mismo que antes. La moneda de rebirth es **el cerdo dorado** (el mismo dibujo de la hucha,
pequeño, junto al número) y **la Electrónica del armario las multiplica**, que es
la razón de que el armario dé puntos de rebirth. Lo que no se pierde son las
estadísticas de la cuenta —paquetes abiertos, objetos encontrados, mejor nota—,
que son de la cuenta y no de la partida. Y mientras el requisito no llega, la
chapa y la barra del árbol **dicen cuánto falta**: un botón muerto y callado no
explica
nada.

**Un clic abre UN paquete, siempre: el pulsado.** Nada de arrancar varios de
golpe, porque eso convertía el bucle en machacar siempre el mismo sobre. Cuántos
paquetes caben **a la vez** lo dice la mesa: ocho de serie, y el Cajón los
amplía (+2 por nivel). Todos los huecos pueden estar cargando a la vez, y un
clic en otro mientras el primero está a medio abrir no hace nada (el que ya se
está trabajando sigue aceptando clics, y el turno se suelta cuando la caja se
rompe), así que el jugador tiene que ir pulsando uno y otro para que avancen
todos: insistir en el mismo no adelanta más que el suyo. Es la diferencia entre
jugar a mano y jugar con la mesa montada.

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

**La nota PSA es una pirámide apoyada en la 2-4**, no un reparto hacia arriba:
casi la mitad del botín sale tocado (nota 1-3), la 9 sale una de cada veintisiete
y la **10 una de cada cuarenta**. Y lo que vale cada nota es lo que hace que mirar
el número importe: la 1 vale un 0.61 del precio base, la 5 ya vale lo que antes
valía un 10 (1.25) y la 10 vale el doble que aquel 10 (2.50). O sea que un 10 no
es "un poco mejor": es el objeto que se guarda y el que se expone en el armario.
El **Trébol no toca la nota**, solo engorda el peso del botín raro, épico y
legendario (y por eso un 10 sigue saliendo una vez de cada cuarenta con el
Trébol al máximo).

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
  items/               los 9 items equipables de la tienda
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

# Cuánto dura una partida hasta el primer rebirth. Juega la partida entera con
# los datos de verdad y saca el informe (mediana, dispersión, lo que paga cada
# sobre). Hoy: unos 18 minutos el jugador normal y 13 el que juega rápido,
# compra bien y pone el PC y los Pinchos.
$G --headless --path . res://dev/BalanceTest.tscn

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

`smoke_test` toca las 478 cosas que se pueden romper sin que se note
mirando capturas: que la escalera de los doce sobres suba en precio, en botín, en
resistencia y **en dibujo** (los tres escalones de un tipo ya no comparten
sprite, y el arte de cada uno tiene que traer sus tres tramos de daño), que
**ningún sobre de un escalón baje del precio más alto del anterior** (con los
escalones cruzados, comprar la electrónica o las zapatillas del escalón 1 no
tenía ningún sentido), que **cada sobre pague de media entre un 30 y un 45 % más de lo que
cuesta** y que **su resistencia vaya con la raíz de su precio** (la curva de la
que sale cuánto dura la partida), y que **la partida dure lo que tiene que durar**
(el test vuelve a medirla con `dev/balance.gd`: el jugador normal llega al primer
rebirth entre 15 y 25 minutos, el que juega y compra bien al menos un minuto
antes, y con el PC y los Pinchos antes que haciendo clic), que el
sobre inicial no cobre nunca y los demás sí, que las doce filas de la columna
caben sin pisarse, que la columna tenga su **fondo opaco** y que vaya **detrás**
de los sobres, que el anillo avance y que se dibuje
**detrás** del paquete, que cada redonda del botón saque su **número de daño**
(naranja el golpe normal y amarillo el crítico, encima del paquete y con el daño
que toca), que los items de la tienda sean **diez cajas** en rejilla que no se
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
paquete y que el cupo sea el de la mesa (el que dice `Game.open_count()`, con el
que espera entrando en cuanto se suelta un hueco), que la apertura automática
se encienda solo con los
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
**las monedas de rebirth no den dinero por sí solas** (el cambio de fondo: antes
cada una subía un 5 % el valor de todo lo que vendes, para siempre, y el rebirth
se acumulaba sin que hubiera nada que decidir), que el árbol de mejoras traiga
**una mejora en el centro y cuatro caminos en diagonal**, que los cuatro
**cuesten lo que dice SkillTree** y que no se abran hasta comprar el centro, que
cada uno dé **lo suyo** (+20 % de daño, +20 % de velocidad, +2 huecos de armario
y +30 % de daño de los Pinchos) y que el del armario dé huecos **de verdad**
(expuestos, no un número en un rótulo), que **pulsar un nodo no compre nada por
sí solo** sino que abra su **ficha** —con su explicación larga entera, la de los
cinco, que tiene que caber en su hueco de cuatro líneas— y que desde ahí el botón
COMPRAR cobre lo mismo que el nodo, que el árbol **no se pierda al
reiniciar** la partida y que sus cinco nodos **quepan de una vez** en la pantalla
al abrirla (por debajo de la barra del rebirth), que la barra del rebirth
prometa **las mismas monedas que da** el rebirth y que el multiplicador de la
Electrónica entre en el premio, que esa barra se mida **también con el requisito
sin cumplir** (la línea de lo que falta es la más larga de la pantalla y con el
requisito cumplido está vacía: medirla entonces no medía nada), que la chapa del rebirth
esté en la barra de la partida **junto a la tienda** y que el menú ya no sepa
abrirlo (el rebirth se hace jugando, no en la pantalla de empezar) **ni lleve
moneda en el pie**, que un objeto del inventario se pueda vender **de uno en uno**
con el clic derecho (ese y solo ese, con el resto del inventario quieto), que la
tienda cierre, que se guarde el fichero, que ningún sprite ni ningún sonido se
quede fuera de su índice…

`input_test` manda clics y arrastres de verdad, que es lo que `smoke_test` no
puede hacer: pasa por el sistema de interfaz para pulsar GUARDAR y VENDER en la
tarjeta, para comprar un sobre en la columna de la izquierda, para pulsar una
caja de la tienda y comprar desde la ficha que abre, para agarrar un objeto de la
mesa y moverlo, para abrir el mini menú de la compra automática y marcar y
desmarcar un sobre en su lista, para abrir el armario desde su botón de la barra
exponer un objeto y devolverlo a su sitio y vender otro con el **clic derecho**
(el gesto que no se ve y que por eso hay que probar con el ratón de verdad), y
para abrir el árbol de mejoras desde la chapa REBIRTH de la barra (que está junto
a la tienda), **arrastrar el árbol** con el ratón, **comprar un nodo** con un clic
y reiniciar la partida desde el botón de la barra.

### Cambiar el equilibrio

Todo está en `scripts/data/loot_db.gd`, y solo ahí: precios, resistencia (`hp`),
daño, items, qué cae en cada paquete y cuánto vale. Añadir un objeto nuevo es
añadir una fila a la lista `loot` de un paquete; no hay que tocar la interfaz.

Dos reglas mandan sobre el precio de los sobres, y las dos se comprueban en
`smoke_test`, así que no se pueden romper sin que salte:

1. **Ningún sobre de un escalón es más barato que los del anterior.** El jugador
   no ve el `vmult` ni el id: ve la columna de precios, y con dos escalones
   cruzados el de arriba se come al de abajo (no se compra ni la electrónica ni
   las zapatillas del escalón 1 si un sobre de oro cuesta menos). Al tocar un
   precio hay que mirar el TECHO del escalón anterior, no solo los precios de su
   tipo.
2. **Cada sobre paga de media entre un 30 y un 45 % más de lo que cuesta**, en cualquier
   escalón. Por eso el `vmult` NO es el mismo número para los doce: lo que paga
   un sobre es lo que valen los objetos de su tabla, y el escalón multiplica ese
   total, así que un sobre que cuesta tres veces más que otro del mismo escalón
   tiene que multiplicar tres veces menos para pagar lo mismo por dinero. El
   SOBRES es el que más multiplica (su tabla es la que menos vale y su precio no
   puede bajar del techo del escalón de abajo) y el ELECTRÓNICA el que menos. Lo
   que decide si sigue cuadrando es `LootDB.pack_payout()`: la media de la tabla
   con la nota media y el `VALUE_SCALE`, por el `vmult`. Mover un precio sin
   mover su `vmult` es un timo (`el sobre caro paga menos de lo que cuesta`) y
   saltarse los baratos vuelve a ser lo racional si el de arriba paga más por
   dinero.

   **Ese 15 % ES toda la progresión del juego**, y es el número que estaba roto.
   Con el 350 % que había, el capital se multiplicaba por 4,5 en cada sobre, no
   había forma de gastarlo (la tienda no da para tanto) y la partida se
   terminaba en dos minutos: un PSA 10, o cualquier golpe de suerte, **era** la
   partida, y el resto de los objetos no valían para nada. Con el 15 % el dinero
   crece despacio, cada sobre cuenta y la tienda compite de verdad con la
   columna por el mismo dinero.
3. **La resistencia va con la raíz del precio** (`hp = 21,5 × √precio`), que es
   la otra mitad de lo mismo: el rato que dura una partida es la vida de los
   sobres partida por el daño del jugador, así que subir la vida es alargar la
   partida y bajar el exponente (vida más cerca del precio) hace que los sobres
   caros paguen más por segundo. Es la curva que se toca cuando la partida dura
   demasiado o demasiado poco, y el smoke test la comprueba sobre los doce
   sobres (con el 21,5 escrito a mano en el test, para que una tabla y una
   constante malas las dos no pasen la prueba juntas).

Con esas tres reglas cuadradas, **cuánto dura una partida hasta el primer
rebirth no se estima: se mide**. De eso se encarga `dev/balance.gd`, que juega la
partida entera —comprar, golpear, cobrar, subir de escalón, comprar mejoras— con
las fórmulas y los datos de verdad:

```bash
$G --headless --path . res://dev/BalanceTest.tscn
```

Hoy dice que un jugador normal (un clic cada 0,35 s, la tarjeta leída, y pagando
mejoras cuando le caben en el bolsillo) llega al primer rebirth en **unos
dieciocho minutos**; que el que juega rápido y compra bien —gastando a tirones
de una quinta parte del dinero en vez de vaciarse en cada mejora— lo hace en
**unos catorce**; y que con el PC y los Pinchos, en **unos trece**. Esos son los
números **sin dado**, que es con lo que se mide el test; con dado la mediana de
veinticinco partidas sale 16,8 / 15,8 / 14,6. Desde que la barra va a 1,65 s por
golpe cada golpe pesa más, así que el clic ya no decide la partida —el que juega
rápido gana un par de minutos, no cinco— y lo que manda es subir el daño pronto
sin comerse el dinero que hace falta para sobres: por eso el óptimo de gasto se
movió del 12 % al 20 % de golpe. El informe entero (la mediana, el 80 % central,
lo que paga cada sobre y cuánto tarda cada escalón) sale al ejecutarlo, y
`dev/README.md` explica cómo se lee.

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
huecos) con la vitrina a la vista en la pantalla de partida. Y la chapa REBIRTH
de la barra ya reinicia la partida a cambio de monedas, que se gastan en el árbol
de mejoras.

**Sistemas del documento que no están** — el árbol de habilidades **ya está** (es
el árbol del rebirth: la mejora del centro, cuatro caminos de números y la rama de
calidad de vida, con un nodo por camino de momento; estirar un camino es añadir
una fila a `SkillTree.NODES`), logros y eventos de mercado todavía no.

**Extras de la interfaz** — los deslizadores de volumen de los ajustes ya mueven
sus buses, y la casilla de venta automática enciende y apaga el ajuste. Falta el
**selector de idioma**, que está puesto pero sin nada detrás (no hay más texto que
el español), y el botón de empezar de cero (`hard_reset()` lo hace, pero solo lo
llaman las pruebas).
