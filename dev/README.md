# dev/ - herramientas de desarrollo

No se empaquetan con el juego. Son las que se usan para comprobar que no se ha
roto nada, y hacen falta antes de dar cualquier cambio por bueno.

```
smoke_test.gd    el test automatico. Arranca el juego de verdad y comprueba
                 mas de 300 cosas: que se compra, que la mesa se llena, que el
                 sprite lleva la nota, que la fuente se escala entera, que los
                 indices de sprites y de sonidos estan completos
input_test.gd    el test del RATON. Manda clics y arrastres sinteticos y
                 comprueba que los reciben: menu, tienda, cerrar, la mesa, los
                 dos botones de la tarjeta, el arrastre de un objeto, la rueda
                 de la columna de sobres, el mini menu de la compra automatica
                 (que con los Pinchos, y no con el PC, no se abre), el armario
                 (su boton, exponer, devolver, el clic derecho que vende un
                 objeto del inventario y VENDER TODO) y la chapa REBIRTH
                 de la barra de la partida, que abre el arbol de mejoras (el
                 ARRASTRE del arbol con el raton, el clic en un nodo que abre SU
                 FICHA y el boton COMPRAR de esa ficha) y reinicia la partida
                 desde el boton de la barra
screenshots.gd   guarda un PNG de cada pantalla en user://shots/
probe_font.gd    mide de verdad cuanto ocupa cada rotulo con la fuente
probe_pop.gd     pinta un numero de dano normal y uno critico sobre el fondo y
                 guarda el PNG, para poder medir en el pixel que color sale:
                 los digitos ya vienen pintados de oro y el color del numero es
                 un tinte que los MULTIPLICA, asi que el color que se pide no es
                 el que se ve (ver damage_popup.gd)
```

## Por que hay DOS tests y no uno

`smoke_test` recorre el bucle entero, pero llamando a los metodos a mano
(`shop._on_pack(...)`), asi que nunca pasa un clic de verdad por el sistema de
interfaz. Eso dejo pasar un fallo gordo: la interfaz se veia, `smoke_test` salia
en verde y **ningun boton respondia**, porque los contenedores de `main.gd` se
comian los clics. `input_test` tapa ese hueco. Si se toca `main.gd`, se toca la
interfaz o se cambia la posicion de un boton, hay que pasar los dos.

### Como manda los clics (y el detalle que lo hacia mentir)

`Viewport.push_input(evento, true)`: el `true` es `in_local_coords`, o sea que la
posicion va en coordenadas del viewport (las mismas que devuelve
`get_global_rect()`), **no** en coordenadas de la ventana. Con `false`, Godot pasa
el punto por la transformacion de estirado y el clic cae en otro sitio: en una
ventana de 1280x720 sobre un diseno de 1920x1080, a un punto y medio de
distancia. Un test con ese fallo dice que los botones no funcionan cuando el que
esta mal es el test.

Y ojo con el raton del SISTEMA: `get_global_mouse_position()` pregunta al
`DisplayServer`, y sin ventana no hay raton, asi que devuelve cualquier cosa
(medido: `(0, -420)`) y no se mueve por muchos eventos que se le manden. El
arrastre de un objeto de la mesa usa la posicion que TRAE el evento
(`_hit.get_global_transform_with_canvas() * event.position`, que es exacto porque
Godot entrega la posicion ya pasada al espacio local del control que la recibe) y
no esa consulta. Si alguien vuelve a meter `get_global_mouse_position()` en el
arrastre, esto lo caza: el objeto dejaria de seguir al raton.

### El giro de rueda necesita las DOS mitades

`_wheel()` manda el giro como **pulsar Y soltar**, y no es un detalle: el
`Viewport` se queda con el control que recibe la pulsacion (`mouse_focus`) hasta
que ve el suelte. Un giro que solo pulsa deja el raton pegado al
`ScrollContainer` de la columna de sobres, y a partir de ahi el `ScrollContainer`
se come **todos** los clics de la pantalla: el test daba cuatro fallos en botones
que funcionan perfectamente.

En X11 el giro llega como `ButtonPress` **y** `ButtonRelease` (los botones 4 y 5)
y Godot pasa los dos, asi que el juego de verdad no tiene el problema; el que se
lo inventaba era la prueba. Costo una tarde encontrarlo, y por eso esta escrito
aqui: si alguien vuelve a mandar el giro suelto, van a fallar los botones de
despues y va a parecer que el fallo esta en el juego.

### Las capturas necesitan el POST-DRAW

`_shot()` espera a `RenderingServer.frame_post_draw` antes de leer la textura del
`SubViewport`, y sin eso las capturas salen **iguales sin fallar nada**: leer la
textura en mitad de un frame devuelve el frame ANTERIOR, asi que las treinta y
una pantallas de la tanda se guardan con la primera imagen repetida treinta y una
veces (medido: mismo md5 en 31 PNG de nombres distintos, y el `print("captura:")
diciendo 1920x1080 en todos). Es el peor fallo posible en una herramienta de
capturas, porque el PNG existe, pesa lo suyo y se abre: lo unico que no hace es
enseñar lo que se le pidio. Se detecta contando md5 distintos, que es lo que hay
que hacer antes de mirarse una tanda entera.

### El check de "cabe" mide la caja, no la tinta

`_check_cabe()` compara el rectangulo del nodo contra el recuadro, y ese
rectangulo sale de `UIKit.text_width()`. Cuando `text_width()` se queda corto, el
texto se dibuja mas ancho de lo que la caja cree y la fuga pasa el check: la
linea "YA TIENES ... MONEDAS" del panel del rebirth midio x 656..1718 de tinta
en un interior que acaba en 1696 (el `%` cortado por el marco), y el check la
daba por buena. Antes de fiarse de un verde en los paneles, la captura.La diferencia medida esta en un 6 % para esa linea, asi que el margen que hay que
dejar en un rotulo centrado no es 0: son los `text_width()` de sobra.

Y hay una segunda forma de dar por bueno lo que no cabe, que no tiene nada que
ver con `text_width()`: **medir en el estado equivocado**. El panel del rebirth
se medía abriendolo con el requisito ya cumplido, y en ese estado la linea de lo
que falta esta **vacia**, asi que la unica linea que cruza el panel de lado a lado
no la estaba midiendo nadie. Abierto como se abre casi siempre -sin requisito-
se dibujaba **128 px fuera del marco** por la derecha, porque estaba centrada en
la columna de los numeros (x 1152) y no con el panel (medido: tinta de x 480 a
1824 en un interior que acaba en 1696). Un check de encuadre tiene
que correr en el estado que el jugador va a ver.

## Cómo se ejecuta

```bash
G=~/Baixades/Godot_v4.7.2-stable_linux.x86_64

# el test, sin ventana
$G --headless --path . res://dev/SmokeTest.tscn
# debe acabar con "HUMO: todo correcto."

# el test del raton, sin ventana
$G --headless --path . res://dev/InputTest.tscn
# debe acabar con "RATON: todo correcto."
# (sale con 1 si algo falla, asi que sirve tal cual en un script)

# el reloj: juega la partida entera (comprar, golpear, cobrar, subir de escalon,
# comprar mejoras) y dice cuantos minutos se tarda en llegar al primer rebirth
$G --headless --path . res://dev/BalanceTest.tscn
# lo mismo con la vida de una partida paso a paso (dinero, niveles y sobre de
# cada momento): es lo que se mira cuando un jugador sale mas lento de lo que
# deberia y hay que ver DONDE se pierde el rato
$G --headless --path . res://dev/BalanceTest.tscn trace
# y el barrido de cuanto se gasta de golpe en mejoras, que es la decision con
# mas peso de la partida y la que menos se ve (gastar el 55 % del dinero en cada
# sobre se come su margen del 15 % y deja el dinero sin componer)
$G --headless --path . res://dev/BalanceTest.tscn shares

# las capturas, CON ventana: en headless el renderizador es el de mentiritas
# y get_viewport().get_texture() devuelve null, asi que no guarda nada.
DISPLAY=:1 $G --path . --display-driver x11 --rendering-driver opengl3 \
    res://dev/Screenshots.tscn
# quedan en ~/.local/share/godot/app_userdata/Pack Tycoon/shots/, a 1920x1080
#
# OJO con el tamano: los PNG salen de un SubViewport de 1920x1080, no de la
# ventana. La ventana la coloca el gestor de ventanas del escritorio y aqui la
# deja en 948x533, o sea el juego entero a la mitad de resolucion y con el
# texto ilegible. Por eso las capturas van 1:1 con el diseno y se pueden medir
# los pixeles directamente sin escala: si un nombre se sale del marco, en el
# PNG se ve.

# la sonda de la fuente
$G --headless --path . res://dev/ProbeFont.tscn

# la sonda del color de los numeros de dano, CON ventana: necesita renderizar de
# verdad (en headless la textura del viewport no existe)
$G --path . --rendering-driver opengl3 res://dev/ProbePop.tscn
# deja el PNG en ~/.local/share/godot/app_userdata/Pack Tycoon/shots/_probe_pop.png
```

Y si se acaba de anadir una escena o un `class_name` nuevo, antes hay que dejar
que Godot importe:

```bash
$G --headless --path . --import
```

Sin ese paso los dos tests se caen con `Could not find type "LockerPanel"` (el
proyecto no tiene la escena en su cache todavia) y parece que el fallo esta en el
codigo nuevo. Costo una vuelta entera de tests creerlo.

## El reloj: cuanto dura una partida (balance.gd)

Lo que dura una partida no se estima a ojo ni se comprueba mirando capturas: se
**mide**. `balance.gd` juega la partida entera —comprar el sobre mas caro que te
llega, golpearlo hasta abrirlo, cobrar el botin y volver a empezar, comprando
mejoras por el camino— con las FORMULAS y los DATOS de verdad del juego
(`LootDB.pack_payout()`, `roll_pack()`, `damage_per_hit()`, `charge_time()`,
`spike_dps()`, `item_cost()`...), asi que cambiar un precio o una vida y volver a
correr esto dice en un par de segundos que le ha pasado a la partida.

El reloj es la suma del tiempo de cada accion: los ciclos de carga (mas el hueco
entre clic y clic), la tarjeta de revelado y las compras. **No modela el raton ni
la interfaz**: no hay clics que fallan, ni dudas, ni cansancio. Por eso sus
tiempos son un SUELO —una persona hace lo mismo que dice aqui y algo mas—, no una
promesa optimista.

Juega de tres maneras, y las tres estan en el informe:

| Jugador | Como juega |
|---|---|
| `normal` | el sobre mas caro que puede y mejoras hasta el 30 % del dinero; clic cada 0,35 s y la tarjeta leida (1,6 s) |
| `optimizado` | clic cada 0,20 s, tarjeta en 1,1 s, **compra a tirones** (20 % del dinero de una vez, el óptimo que da el barrido con la barra a 1,65 s) y expone los vinilos en el armario |
| `automatico` | como el optimizado, mas el PC y los Pinchos: la mesa se abre sola y no hay tarjeta |

**El Dolar no entra en esta cuenta.** Su descuento se aplica en
`Game.pack_price()` y la simulacion calcula con los precios de `LootDB`, asi que
los tiempos de abajo son SIN el Dolar: como el descuento solo puede acortar la
partida, son un techo, no una promesa. Modelarlo pediria meter tambien el
ahorro en cada compra, que es otra cuenta y otro informe.

Hoy dice: **normal 24,7 min** (el 80 % central, 17,4 a 34,0), **optimizado 17,7** y
**automatico 16,2**. La banda que se considera sana para el normal es 20-30 y el
informe lo dice en voz alta al final. Ademas saca, para el lector:

- **Lo que paga cada sobre y lo que tarda**, contra su precio. Es la otra mitad
del equilibrio: si un sobre paga mas de lo que cuesta, subir de escalon deja de
ser una decision; si paga menos, nadie sube. Los doce van de x1,14 a x1,16.
- **Que sobres abre de verdad** el jugador normal. Si la fila del sobre GRATUITO
  se lleva una tajada, la partida se esta atascando en el escalon de abajo.
- **Sin dado** (el botin puesto en su media). Separa lo que decide la suerte de
  lo que decide el camino, y es la unica version que puede comprobar un test sin
  volverse loca (ver el check de equilibrio de `smoke_test`).

Los numeros salen de veinticinco partidas por jugador y el informe enseña el
**80 % central**, no el minimo y el maximo: con veinticinco partidas, una racha
buena en la ultima hace ver el juego roto.

## Que comprueba smoke_test.gd y por que

Los checks no son decorativos: cada uno tapa algo que ya se rompio alguna vez.

- Que el sprite del objeto lleve la nota PSA que toca. Si no, el desgaste no se
  ve y el jugador no puede creer el precio.
- Que las cuatro cartas sean cuatro dibujos distintos. Antes lo eran no: era un
  solo dibujo teñido por rareza, cuatro veces.
- Que la fuente del juego este cargada y que `text_width()` coincida con lo que
  mide de verdad. Si la fuente se pierde, el texto vuelve a la suave de Godot y
  se ve como estaba antes; si `text_width()` miente, los rotulos se cortan.
- Que los ocho rotulos largos del juego quepan en su caja. Todos se cortaban en
  silencio.
- Que todos los PNG esten en `Sprites/index.tsv`, que ninguna entrada apunte a
  un fichero que falte y que **carguen de verdad**. Lo ultimo no es lo mismo: si
  la cache de importacion se queda vieja (generar sprites con el editor cerrado)
  el PNG y el indice estan bien y el sprite sale igualmente como un hueco vacio.
  Se le pregunta al `.import` si Godot lo importa, porque la hoja de la fuente
  (`font_pack.png`) lleva `importer="skip"` y no es una textura.
- Que todos los WAV esten en `Sounds/index.tsv`, que carguen, que los dos buses
  existan y que el volumen de los ajustes llegue de verdad al bus. Un sonido
  fuera del indice tampoco da ningun error: simplemente no suena.
- Que el bucle de la musica este montado. El importador de Godot deja los WAV sin
  bucle a proposito, asi que si `_make_loop()` se rompiera, la musica sonaria una
  vez al arrancar y se callaria para el resto de la partida.
- Que el objeto NO se guarde solo. Estaba en la mesa y en el inventario a la vez
  porque la tarjeta de revelado lo metia al cerrarse. Ahora se comprueba que al
  abrirse la tarjeta el objeto esta en la mesa y el inventario vacio, que
  GUARDAR lo pasa al inventario y lo saca de la mesa, y que VENDER paga y lo
  saca de la mesa sin guardarlo.
- Que con la venta automatica encendida no salga la tarjeta, el objeto no llegue
  a la mesa y el dinero entre igual. Se llama al manejador de "paquete abierto"
  en vez de esperar los segundos de la apertura: lo que se prueba es esa rama, y
  no depende del reloj.
- Que el anillo de espera vaya **detras** del paquete (el orden de los hijos) y
  que sea mas ancho que el dibujo. Puesto delante lo tapaba entero: el sprite es
  un disco con agujero centrado en el mismo punto que el paquete.
- Que un objeto no pueda salir de la mesa al moverlo, y que soltarlo tras
  arrastrarlo no lo abra ni lo venda. El arrastre de verdad (pulsar, mover y
  soltar) lo prueba `input_test`.
- Que **un clic abra UN paquete y no varios**. El cupo de cuantos caben
  cargando a la vez es el de la mesa (`Game.open_count()`: ocho de serie, y el
  Cajon lo sube), asi que el check comprueba que sin comprar nada ya caben
  varios, que tras el primer clic solo carga uno (y el no pulsado sigue quieto),
  que pulsando cada uno cargan los ocho huecos y que al soltar un hueco el que
  esperaba entra. Antes era al reves (un clic arrancaba varios de golpe y el
  jugador machacaba el mismo sobre), y por eso la prueba mira el NUMERO de
  paquetes cargando y no solo que el clic llegue.
- Que el precio de un sobre quepa **en la banda blanca de su chapa**, no solo en
  el hueco del sprite. La cinta solo pinta una franja en medio (`PACK_TAG_INK`,
  un 59 % del alto), y con la chapa baja el número se leía encima de la cinta:
  el check mide contra la BANDA y pide 4 px de aire, que es lo que ocupa de más
  el contorno del número. Comprobado que caza el fallo: bajando la chapa a 56 px
  vuelve a fallar.
- Que la columna de sobres tenga **fondo propio y opaco**. Sin el, los nombres y
  los precios de ocho y nueve cifras se leian encima de las monedas y las baldas
  claras del fondo de la trastienda. El check mira el **alfa**: con menos de 1 el
  fondo se vuelve a transparentar, que es justo el fallo que se arreglo.
- Que la apertura automatica se encienda **solo con los Pinchos** y la compra
  automatica **solo con el PC**. Antes hacian falta las dos piezas para
  cualquiera de las dos, y comprar el PC y que su boton siguiera apagado se lee
  como que la compra no ha servido de nada.
- Que haya **dos clases de item y no se mezclen**: los siete con niveles suben
  hasta ocho (cada uno mas caro; las Tijeras y los Guantes suben poco en sus
  tres primeras mejoras, x1,3, y se disparan a partir de la cuarta) y el PC y
  los Pinchos son de
  compra unica, asi que su `item_cost()` contesta -1 en cuanto se tienen. La
  tienda lo dice con COMPRADO en esos dos y con AL TOPE en los que llegan a los
  ocho, y donde los otros llevan los puntos de nivel esos dos llevan el rotulo
  **COMPRA UNICA**: sin el, su fila solo se distinguia por lo que *no* tenia, y
  eso hay que deducirlo. Los dos rotulos son `Label` a proposito: antes aqui iba
  un "MAX" en un `PixelNumber`, que solo tiene glifos de digitos y por eso no
  dibujaba nada (la fila parecia tener un hueco roto).
- Que la escalera de la columna de sobres **suba tambien en resistencia**, no
  solo en precio: si el escalon de arriba fuera igual de blando, el precio solo
  compraria botin mejor. Y que el sobre basico pida **cinco golpes** con el dano
  base (215 de vida entre 45 de dano): se mira en golpes y no en el numero suelto,
  para que el check siga diciendo algo si cambia el dano base.
- Que **un escalon no se cuele por debajo del anterior** en precio, y que **cada
  sobre pague entre cuatro y cinco veces lo que cuesta**. Son los dos checks que
  faltaban porque la escalera se medía **tipo por tipo**, y así estaba todo en
  verde con el fallo delante: dentro de SOBRES subía (0 → 4.000 → 80.000) y
  dentro de ELECTRÓNICA también (25.000 → 500.000 → 10.000.000), pero de un
  escalón al siguiente el precio se **cruzaba**: SOBRES ORO a 4.000, más barato
  que la ELECTRÓNICA del escalón 1 (25.000). Con el botín multiplicado arriba,
  eso deja a la electrónica y a las zapatillas del escalón 1 sin comprador:
  nadie paga 25.000 por algo que un sobre de 4.000 da mejor. El primero mide los
  precios **por escalón** (el mínimo de uno tiene que pasar el máximo del
  anterior) y en la lista de fallos dice qué escalones se cruzan y por cuánto.
  Comprobado que caza el fallo: con los precios viejos `ningun sobre de un
  escalon baja del precio mas alto del anterior` FALLA y el test sale con 1; con
  los nuevos pasa. El segundo no admite opiniones, necesita un número:
  `LootDB.pack_payout()` calcula lo que paga de media un sobre —media ponderada
  de su tabla, con la nota media y el `VALUE_SCALE`, por su `vmult`; sin el
  Trébol ni el Armario, que son del jugador y del momento— y el check pide que
  **pague entre un 30 y un 45 % más de lo que cuesta**: entre x1,30 y x1,45, y hoy los doce van
  de x1,37 a x1,40. Es lo que obliga a que el `vmult` NO sea el mismo para los
  doce: al subir los precios del escalón 2 por encima del techo del 1, los que
  menos pagaban (SOBRES ORO, que tiene la tabla más barata) se quedaban pagando
  una cuarta parte de lo que cuestan. **Ese margen es toda la progresión del
  juego**: con el 350 % de antes el capital se multiplicaba por 4,5 en cada
  sobre, no había forma de gastarlo y la partida se terminaba en dos minutos (un
  PSA 10, o cualquier golpe de suerte, *era* la partida). Por eso el check es
  estrecho y no un "paga más de lo que cuesta".
- Que la **resistencia de cada sobre vaya con la raíz de su precio**
  (`hp = 21,5 × √precio`, con un 6 % de margen para los números redondos). El
  rato que dura una partida es la vida de los sobres partida por el daño del
  jugador, así que esta curva es el reloj del juego: un sobre fuera de la curva
  se ve en los minutos del informe de `balance.gd`. El 21,5 va **escrito a mano
  en el test** aunque también esté en `loot_db.gd`: si el test lo leyera de los
  datos, una tabla y una constante malas las dos seguirían pasando la prueba.
- Que **la partida dure lo que tiene que durar**. Es lo único de este juego que
  no se puede comprobar mirando una captura ni midiendo una pieza suelta (un
  precio, una vida): sale de la partida entera, así que el test llama a
  `dev/balance.gd` —la herramienta que juega la partida completa con las
  fórmulas y los datos de verdad— y pide que el jugador normal llegue al primer
  rebirth **entre 15 y 25 minutos**, que el que juega rápido y compra bien llegue
  **antes** que el normal y que el que pone el PC y los
  Pinchos llegue antes que el que hace clic. Se mide **sin dado** (el botín
  puesto en su media), que es lo único que da siempre el mismo número; con dado
  el resultado se mueve varios minutos de una partida a otra y un test que salta
  por suerte es peor que no tener test. La banda es ancha a propósito: esto es un
  guardia contra romper la partida, no un ajuste fino.
- Que **cada escalon de un tipo tenga su propio dibujo**. Los tres escalones
  compartian sprite (el mismo sobre dibujado tres veces en una columna de doce),
  y el fallo no da ningun error: sale el de siempre y no se nota. El check pide
  los tres artes distintos y que existan los cinco PNG de cada uno (el cerrado,
  el abierto y los tres tramos de dano), porque el dano NO se guarda en los
  datos: se deduce del nombre ("pack_cards" + "_d2" a secas), asi que un arte
  nuevo sin sus tres tramos se veria bien hasta el segundo golpe. Comprobado que
  caza el fallo: devolviendo el arte del escalon 2 al del 1, el check falla.
- Que **los doce nombres de sobre quepan a 28** en la caja del nombre. El tamano
  de la columna es el del nombre mas largo (`UIKit.row_size`), asi que un solo
  nombre de 17 caracteres encoge los doce a 21 y el de arriba se queda enano: es
  lo que pasa si alguien bautiza un escalon "DE DIAMANTE" en vez de "LUJO".
  Comprobado al reves: con "SOBRES DE DIAMANTE" el check falla y sale con 1.
- Que **cada redonda del boton saque su numero de dano**: el texto es el dano
  del golpe, sale ENCIMA del paquete (no debajo) y el color distingue el golpe
  normal del critico. El critico se prueba sin depender de la suerte: se compra
  el Ojo verde AL TOPE (la probabilidad es de un 5 % POR NIVEL, o sea el 40 % a
  los ocho: con el nivel 1 y treinta tiradas esto fallaba una vez de cada cinco,
  que es lo peor que puede hacer un test) y se golpea un paquete aparte -con la
  resistencia puesta por las nubes, y puesto que el de al lado hay que romperlo
  para seguir con el
  revelado- hasta que sale uno, y se pide que su numero sea el del critico (dano
  x multiplicador) y que sea mas grande que el del golpe normal. Los dos colores
  estan MEDIDOS sobre el pixel que sale en pantalla (`dev/probe_pop.gd`), porque
  los sprites de los digitos ya vienen pintados de oro y `PixelNumber` los
  multiplica por el color: pidiendo `Palette.GOLD` el numero sale marron oscuro,
  asi que el tinte mueve el verde (a la baja el naranja, por encima de 1 el
  amarillo). Ojo al buscarlos: **Godot renombra a los hermanos que se llaman
  igual** (DamagePop, DamagePop2...), asi que se buscan por marca
  (`DamagePopup.MARK`) y no por nombre.
- Que la tienda dibuje **una caja por item** y que las ocho quepan en la rejilla
  del panel sin pisarse. Es lo que no se ve mirando: un ancho de rejilla mal
  calculado se sale por el borde de abajo del panel y el marco no recorta nada,
  asi que la ultima fila desaparece sin un solo error. Se miden los ocho
  rectangulos contra el recuadro interior y entre si.
- Que el clic en una caja abra **la ficha del item**: el nombre, la descripcion
  larga ENTERA (el texto va partido en lineas con `UIKit.wrap()`, asi que se
  comprueban todas las lineas, no la primera), el numero del efecto de AHORA y el
  del nivel siguiente -los dos sacados de `LootDB.item_effect()`, que aplica la
  formula de verdad-, y que los dos numeros sean distintos (si no, el nivel no
  cambia nada y la ficha no esta diciendo la verdad).
- Que **se compre desde la ficha**: el boton COMPRAR de la ficha sube el nivel,
  cuesta lo mismo que comprando desde la caja, y los numeros de la ficha se
  repintan solos con el nivel nuevo (y siguen coincidiendo con `item_effect()`).
  Y las tres esquinas: sin dinero no compra, un item al tope dice AL TOPE y no
  trae ni boton ni chapa, y el PC y los Pinchos -de compra unica- dicen COMPRA
  UNICA antes y COMPRADO despues, con "AL COMPRARLO" en vez de un "NIVEL 1".
- Que **cada tipo de botin de su bonus, y no todos el mismo**: las cartas suben el
  dano, las zapatillas la velocidad de carga, los vinilos el dinero y la
  electronica los puntos de rebirth. Se comprueba por los cuatro lados, porque un
  `stat` mal puesto en la tabla de tipos (`LOOT_KINDS`) hace que dos tipos den lo
  mismo y eso no se ve en ninguna captura: las cuatro lineas del panel del
  armario salen iguales y todo parece correcto.
- Que el bonus de un objeto expuesto vaya **de la nota 1 a la nota 10**, o sea de
  un 2 % a un 15 %, y que el tipo lo diga la fila del botin (el campo `kind`) y
  no el dibujo ni el id: deducirlo del nombre es una regla escondida que se rompe
  sola en cuanto se anade un objeto con otro nombre.
- Que **la nota alta sea rara y el Trébol no la toque**. Se mide la TABLA
  (`GRADE_WEIGHTS`), que es fija: el 10 sale el 2,4 % y las 9 o más el 6,1 % del
  botín. Antes el 10 era la nota MÁS probable (22,9 %) y las 9-10 se llevaban el
  43 %, que es justo lo que se notaba abriendo sobres sin parar de sacar "como
  nuevo". El precio de la nota lleva además dos anclas escritas a mano -la 5
  vale lo que valía la 10 de antes (1,25) y la 10 el doble (2,50)- para que
  mover la curva se vea aquí y no dentro de un mes en el reloj de la partida.
  La independencia del Trébol se comprueba con la MISMA semilla: 500 tiradas con
  y sin suerte tienen que dar las mismas 500 notas y más rarezas con suerte. El
  dado del objeto gasta un número por tirada, así que si la nota se metiera en
  el dado de la suerte las dos listas se separarían; y si no se separaran por la
  nota pero tampoco cambiara la rareza, el check también falla.
- Que el armario tenga **exactamente los huecos de su nivel**: con el armario a 2
  caben dos objetos y el tercero NO entra, y el que se queda fuera sigue en el
  inventario (no se pierde por pulsar). Era la unica razon de subir el armario de
  nivel, asi que es justo lo que hay que fijar.
- Que **el tipo de un objeto sobreviva a la tirada** y que cada uno mueva su stat
  y solo el suyo. `roll_pack()` arma un diccionario NUEVO con los campos que usa la
  interfaz, y ahi se quedo fuera `kind`: `kind_of()` cae en su valor por defecto
  ("cards") y **todos los objetos expuestos subian el dano** (un vinilo y unas
  zapatillas dando mas dano, o sea el armario sin nada que decidir). Todos los
  checks de arriba miraban la FORMULA con objetos armados a mano, asi que la
  tirada que la alimenta nadie la miraba; el de las cartas pasaba incluso con el
  fallo dentro, porque su valor por defecto es justo "cards". Se comprueba el
  tipo que sale de cada paquete y el efecto con objetos de verdad: una zapatilla
  expuesta acelera la carga y NO toca el dano, un vinilo sube el valor y tampoco
  lo toca. Comprobado al reves: quitando la linea del `kind`, fallan siete.
- Que el inventario sea de **50 huecos** y que **ya no este en la pantalla de
  partida**: la tira de abajo es la vitrina y el inventario vive en el panel del
  armario. Se mira por el metodo que ya no existe y por el tamano, para que
  volver a meterlo en la pantalla se note.
- Que un objeto del inventario se pueda vender **de uno en uno**, con el clic
  derecho en su hueco, y que se venda ese y **solo ese**: sale del inventario,
  paga exactamente el valor que enseñaba el hueco y los demas objetos se quedan
  donde estaban. Es lo que faltaba desde que el inventario vive en el panel del
  armario, que solo sabia vaciarlo entero con VENDER TODO (todo o nada). El gesto
  no se ve, asi que el check mira tambien las dos cosas que lo explican: el
  tooltip de cada hueco y la leyenda de la columna, entre su rotulo y la rejilla
  (debajo de la rejilla no cabe: las 50 casillas siguen ahi, recortadas por la
  ventana del scroll pero en el arbol, y el check de los dibujos lo caza).
- Que la **vitrina de la partida** enseñe los objetos expuestos y que su rotulo
  cuente los huecos. Sin esto el armario seria un numero dentro de un panel y no
  algo que se ve mientras se juega.
- Que **el texto no se dibuje encima de un objeto** (`_check_sin_pisar_dibujos`,
  el check que habla de DIBUJOS y no de chapas). Los otros dos de encuadre solo
  miraban texto contra chapas, y este es el que cazo el solape de verdad: el
  rotulo de VENDER TODO comiendose 7 px del marco de la ultima fila del
  inventario. Los objetos son dibujos, y una chapa no es lo unico con lo que se
  puede chocar un rotulo.
- Que el rebirth **prometa lo que da**: las monedas que enseña la barra del
  arbol salen de `Game.pending_rebirth_coins()`, el MISMO calculo que usa
  `do_rebirth()`, y el multiplicador de la Electronica del armario entra en el
  premio (que es lo unico que hace que exponer electronica signifique algo). Se
  comprueba contra el numero que da de verdad, no contra una copia de la formula
  escrita al lado. Y tanto el **requisito** como las **monedas** se cuentan sobre
  **el dinero que hay en el contador en ese momento** (el requisito son 5.000 y
  una moneda por cada 1,5 M): hay un check con la partida entera ganada y el
  contador vacio que no deja reiniciar y da la moneda minima, otro con el
  contador a una unidad del requisito que todavia no deja, y otro con 12,5 M en
  el contador que tiene que dar 8. Si alguien vuelve a mirar `lifetime_earned`
  para el requisito, el primero falla.
- Que **las monedas de rebirth no den nada por si solas**, que es el cambio de
  fondo del arbol: cada una sumaba un 5 % al valor de todo lo que vendias, para
  siempre, y eso dejaba el rebirth sin decision (se acumulaba solo). El check
  pone cuarenta monedas y pide los cuatro multiplicadores a 1 y cero huecos de
  armario: si alguien devuelve la paga pasiva, falla.
- Que **pulsar un nodo no compre**: abre su FICHA (`SkillCard`), que es una
  pantalla nueva, y ahi no se cobra nada hasta que se pulsa COMPRAR. La ficha
  lleva el efecto de titulo, la linea corta y la explicacion larga del nodo
  ENTERA (partida con `UIKit.wrap()`, y se comprueba en los cinco que cabe en las
  cuatro lineas del hueco, porque la quinta se dibuja encima de los numeros), el
  estado (comprado, cerrado diciendo que falta antes, o cuantas monedas faltan) y
  los **dos numeros**: `AHORA, CON EL ARBOL` sale de `Game.skill_bonus()` y
  `AL COMPRARLO` del mismo numero mas el `value` del nodo, asi que no pueden
  mentir. Y se compra desde ahi: el boton cobra lo mismo que costaba el nodo y la
  ficha se repinta sola (COMPRADO y sin boton).
- Que el **arbol de mejoras** este entero: los cinco nodos de numeros (una mejora
  en el centro y cuatro caminos **en diagonal**, uno por cada lado, colgando del
  centro), que la
  del centro cueste **una moneda y de un 30 % mas de dinero**, que los cuatro
  caminos cuesten **tres** y den **+20 % de dano, +20 % de velocidad, +2 huecos de
  armario y +30 % de pinchos**, que **sin monedas no se compre**, que los caminos
  **no se abran sin el centro** y que **cada mejora se compre una sola vez**. Los
  cuatro efectos se miden contra los mismos numeros que usa la partida
  (`Game.damage_per_hit()`, `charge_time()`, `locker_slots()` y `spike_dps()`),
  que es donde se notan. Los Pinchos y el Armario se compran antes de mirar los
  numeros porque sin la pieza de la tienda no hay nada que medir: los Pinchos sin
  su pieza pegan **0**, y un 30 % de 0 es 0.
- Que el arbol **no se pierda al reiniciar** la partida (y que si se pierdan las
  piezas de la partida, el armario y los Pinchos): es lo que hace que reiniciar
  signifique algo, porque las monedas se ganan reiniciando y se gastan en el
  arbol. Y que el dano del armario **se multiplique con el** y no lo sustituya:
  una carta de nota 10 expuesta (+25 %) con el camino del dano comprado (+20 %)
  tiene que dar el producto (x1,5), no el mayor de los dos.
- Que la **rama de calidad de vida** este entera: cinco interruptores debajo del
  centro (atajos, sin ficha, sobrante, mesa limpia y armario solo), de **un solo
  nivel** y con los ids que consulta el juego (un id mal escrito seria una mejora
  que se paga y no hace nada), y que cada uno se pueda **traer a la vista
  arrastrando**, porque la rama es mas alta que la ventana del panel. Las cuatro
  reglas que tocan la partida se prueban donde viven: la **chatarra** por nota
  (3 o menos se vende, 4 no), el **sobrante** del golpe (sin la mejora se pierde,
  con ella espera al siguiente golpe y se gasta de una vez), el **armario** (con
  el hueco lleno cambia una pieza mejor y devuelve la peor al inventario, con una
  peor no toca nada, y sin la mejora el armario lleno sigue diciendo que no) y la
  **mesa limpia** (un objeto puesto de verdad, con su reloj vencido, se vende solo
  y cobra lo mismo que el clic; uno recien salido no se toca). Los **atajos** van
  en el test del raton: la tecla tiene que abrir la tienda, el armario y el arbol,
  la V tiene que vender la mesa, y **sin la mejora o con un panel abierto** no
  puede hacer nada.
- Que el **arbol quepa al abrirlo**: el centro y los cuatro caminos dentro del
  marco del panel y **por debajo de la barra del rebirth** (que va superpuesta y
  se come la franja de arriba). Se mira en el estado en el que se ve casi siempre
  -sin nada comprado, los cuatro caminos cerrados-. La rama de calidad de vida no
  entra (son tres filas de 320 en una vista de 800): se llega a ella arrastrando,
  y eso es lo que se comprueba, nodo por nodo.
- Que el **arrastre del arbol** mueva el dibujo y que su tope deje siempre un
  trozo de arbol a la vista: sin tope, arrastrar hacia un lado deja la pantalla
  vacia y no hay forma de volver. El tope se calcula sobre la caja ENTERA del
  dibujo (`SkillTree.bounds()`), no sobre el nodo del centro: el centro puede
  salirse por un lado mientras el resto sigue viendose. Y que la **barra no se
  mueva con el arbol**: el boton de reiniciar se queda en su sitio (es lo unico
  de la pantalla que no se arrastra).
- Que las **lineas del arbol** (las que unen el centro con cada camino) lleven el
  color que toca: dorado el camino comprado, ambar el que ya se puede comprar y
  apagado el cerrado. Se comprueba en la funcion que decide el color
  (`link_color`), que es la unica forma de mirarlo sin leer el pixel. Y el color
  se pide AL LIENZO que pinta las lineas: pedirle el repintado al mundo no pinta
  nada, y el sintoma era que comprabas una mejora y su linea seguia apagada. Eso
  no lo caza ningun check de los de encuadre: salio en la captura, mirandola.
- Que la **barra del arbol se mida tambien cuando la partida no llega al
  requisito**: la linea de lo que falta solo existe en ese estado (con el
  requisito cumplido esta vacia, texto ""), y medir un panel en el estado que no
  es el que se ve de verdad es como no medirlo. Es la leccion de la version
  anterior de esta pantalla: alli esa misma linea se dibujaba **128 px fuera del
  marco** y el check no la veia por estar midiendo el otro estado.
- Que el **menu no tenga rebirth ninguno**: ni hucha, ni contador, ni chapa, ni
  siquiera el metodo que lo abre, ni la moneda que hacia de adorno en su pie. La
  primera pantalla es para empezar, y el
  rebirth se hace jugando. Estuvo ahi y lo que se veia en una partida nueva era
  una hucha con un cero y un "TE FALTAN 1.000.000" en rojo, o sea un sistema
  anunciado antes de que el jugador supiera que existe; el que se deja ahi de
  nuevo se cae en este check.
- Que la chapa del rebirth este **en la barra de la partida, junto a la tienda**,
  y que sea la unica puerta a la hucha desde que el menu la perdio. Se comprueba
  por el lado que importa: la chapa se puede pulsar **aunque la partida no llegue
  al requisito** y abre su panel igual, porque el panel es el que dice cuanto
  falta (misma regla que los dos iconos de las automatizaciones: dim apagado, el
  clic sigue llegando).
- Que la barra traiga el **contador de monedas de rebirth** al lado del dinero
  (cerdito y numero, repintado con el valor de `Game.rebirth_coins`), que el
  cerdito **mida lo mismo que la moneda del dinero** (se comparan los dos dibujos,
  la tinta y no el lienzo) y que vaya **pegado al ultimo digito**: se mide el
  hueco con el contador en 500 -que es cuando un cerdito clavado en una x fija se
  queda flotando en medio de la barra- y con el dinero en su tope de 252 px. Con
  eso, que las tres anchuras no se pisen -dinero, cerdito+numero y rotulo de la
  mesa- y que la chapa del REBIRTH sea **del tamano de la de TIENDA** y lleve el
  cerdito al lado de la palabra. Todas se pueden romper sin un solo error a la
  vista: un numero mas ancho empuja el cerdito, y una chapa estrecha se lee como
  un boton de segunda.
- Que **lo que sale de los sobres no caiga encima de otra cosa**. Se llena la
  mesa hasta sus ocho huecos y se comprueba que ninguna de las ocho cajas se toca
  con otra ni se sale de la mesa, midiendo el sitio de REPOSO (`spot()`) y no
  `position`: mientras un objeto esta cayendo, `position` esta 260 px mas arriba y
  el que mide huecos se creeria que ese sitio esta libre. Antes los objetos se
  sorteaban entre 40 puntos al azar y salian tres apilados en un rincon teniendo
  media mesa vacia al lado.
- Que el **dinero no se pierda** en el camino: el requisito del rebirth se mide
  en el dinero que hay en el contador (5.000), igual que el premio (1 moneda por
  cada 1,5 M). Antes eran dos numeros de sitios distintos -lo ganado para el
  requisito, el contador para el premio- y el jugador leia que le faltaba un
  millon "de lo ganado" mientras tenia cuatro perras delante. Que despues de
  reiniciar la partida vuelva todo a cero
  (dinero, items, inventario, armario y las automatizaciones, que se caen con sus
  piezas) mientras las monedas y las estadisticas de la cuenta se quedan.
