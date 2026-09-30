# dev/ - herramientas de desarrollo

No se empaquetan con el juego. Son las que se usan para comprobar que no se ha
roto nada, y hacen falta antes de dar cualquier cambio por bueno.

```
smoke_test.gd    el test automatico. Arranca el juego de verdad y comprueba
                 mas de 180 cosas: que se compra, que la mesa se llena, que el
                 sprite lleva la nota, que la fuente se escala entera, que los
                 indices de sprites y de sonidos estan completos
input_test.gd    el test del RATON. Manda clics y arrastres sinteticos y
                 comprueba que los reciben: menu, tienda, cerrar, la mesa, los
                 dos botones de la tarjeta y el arrastre de un objeto
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
- Que las dos casillas de los ajustes (pantalla completa y venta automatica)
  enciendan y apaguen el ajuste de verdad y cambien de dibujo, y que esten a 96
  px o mas de distancia, que es lo que mide su zona de clic.
