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
                 de la columna de sobres y el mini menu de la compra automatica
                 (que con los Pinchos, y no con el PC, no se abre)
screenshots.gd   guarda un PNG de cada pantalla en user://shots/
probe_font.gd    mide de verdad cuanto ocupa cada rotulo con la fuente
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
```

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
- Que las dos casillas de los ajustes (pantalla completa y venta automatica)
  enciendan y apaguen el ajuste de verdad y cambien de dibujo, y que esten a 96
  px o mas de distancia, que es lo que mide su zona de clic.
