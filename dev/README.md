# dev/ - herramientas de desarrollo

No se empaquetan con el juego. Son las que se usan para comprobar que no se ha
roto nada, y hacen falta antes de dar cualquier cambio por bueno.

```
smoke_test.gd    el test automatico. Arranca el juego de verdad y comprueba
                 mas de 500 cosas: que se compra, que la mesa se llena, que el
                 sprite lleva la nota, que la fuente se escala entera, que los
                 indices de sprites y de sonidos estan completos, que el armario
                 y el rebirth dan lo que prometen y que el ARBOL DE HABILIDADES
                 mueve los numeros que dice mover (dano, valor, precio, caida,
                 dinero al rasgar, golpes dobles y dinero inicial) y sobrevive
                 al rebirth
input_test.gd    el test del RATON. Manda clics y arrastres sinteticos y
                 comprueba que los reciben: menu, tienda, cerrar, la mesa, los
                 dos botones de la tarjeta, el arrastre de un objeto, la rueda
                 de la columna de sobres, el mini menu de la compra automatica
                 (que con los Pinchos, y no con el PC, no se abre), el armario
                 (su boton, exponer, devolver, el clic derecho que vende un
                 objeto del inventario y VENDER TODO), la chapa REBIRTH
                 de la barra de la partida (que abre la hucha y reinicia la
                 partida desde el boton de su panel) y el ARBOL DE HABILIDADES
                 (la chapa de la hucha, el clic en una casilla que compra de
                 verdad, la casilla sin monedas que se pulsa pero no compra y el
                 cerrar que devuelve a la hucha)
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
- Que **un clic abra UN paquete y no varios**. Los Guantes suben cuantos
  paquetes caben cargando a la vez (`Game.open_count()`: 1 sin ellos, 3 al nivel
  1...), asi que el check arranca cuatro con Guantes nivel 1, comprueba que tras
  el primer clic solo carga uno, que pulsando cada uno cargan los tres, que el
  cuarto no entra, y que al soltar un hueco el que esperaba entra. Antes era al
  reves (un clic arrancaba los tres de golpe y el jugador machacaba el mismo
  sobre), y por eso la prueba mira el NUMERO de paquetes cargando y no solo que
  el clic llegue.
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
- Que haya **dos clases de item y no se mezclen**: los seis de estadisticas
  suben hasta ocho niveles (cada uno mas caro) y el PC y los Pinchos son de
  compra unica, asi que su `item_cost()` contesta -1 en cuanto se tienen. La
  tienda lo dice con COMPRADO en esos dos y con AL TOPE en los que llegan a los
  ocho, y donde los otros llevan los puntos de nivel esos dos llevan el rotulo
  **COMPRA UNICA**: sin el, su fila solo se distinguia por lo que *no* tenia, y
  eso hay que deducirlo. Los dos rotulos son `Label` a proposito: antes aqui iba
  un "MAX" en un `PixelNumber`, que solo tiene glifos de digitos y por eso no
  dibujaba nada (la fila parecia tener un hueco roto).
- Que la escalera de la columna de sobres **suba tambien en resistencia**, no
  solo en precio: si el escalon de arriba fuera igual de blando, el precio solo
  compraria botin mejor. Y que el sobre basico pida **cuatro golpes** con el
  dano base (45 de vida entre 12 de dano): se mira en golpes y no en el numero
  suelto, para que el check siga diciendo algo si cambia el dano base.
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
- Que el rebirth **prometa lo que da**: las monedas que enseña el panel salen de
  `Game.pending_rebirth_coins()`, el MISMO calculo que usa `do_rebirth()`, y el
  multiplicador de la Electronica del armario entra en el premio (que es lo unico
  que hace que exponer electronica signifique algo). Se comprueba contra el
  numero que da de verdad, no contra una copia de la formula escrita al lado.
- Que el panel del rebirth **quepa tambien cuando la partida no llega al
  requisito**. La linea de lo que falta ("TE FALTAN 1.000.000 DE LO GANADO EN
  ESTA PARTIDA") es la mas larga del juego -48 caracteres- y la unica que cruza el
  panel de lado a lado: estaba centrada en la columna de los numeros (x 1152) y
  se dibujaba **128 px fuera del marco** por el lado derecho (tinta de x 480 a
  1824 en un interior que acaba en 1696). El check viejo no la
  veia porque medía el panel con el requisito CUMPLIDO, y ahi esa linea esta
  vacia (texto ""), asi que no medía nada; ahora se mide en los dos estados. La
  linea se centra con el panel (x 960) en la misma caja que el texto del trato, y
  encoge a paso de fuente entero si el numero se hace largo.
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
- Que el requisito del rebirth se mida en **lo ganado en la partida**
  (`lifetime_earned`) y no en el dinero que se tenga: guardar el dinero para el
  final no cambia nada. Y que despues de reiniciar la partida vuelva todo a cero
  (dinero, items, inventario, armario y las automatizaciones, que se caen con sus
  piezas) mientras las monedas y las estadisticas de la cuenta se quedan.
