# scripts/ - el codigo del juego

GDScript, repartido por lo que hace cada cosa y no por antiguedad. Los
ficheros se referencian entre si por `class_name` (que es global), no por ruta,
asi que mover uno aqui no obliga a tocar a los demas.

```
core/       lo que esta siempre vivo
  main.gd         MainRoot: la raiz que va cambiando de pantalla
  game_state.gd   el autoload "Game": dinero, inventario (50 huecos), el armario
                  con sus bonus, las monedas de rebirth, los ajustes y el guardado
  audio.gd        el autoload "Sound": efectos, musica y los tres buses
  palette.gd      los tokens de color que Tambien usa el generador

data/       lo que se toca para reequilibrar el juego
  loot_db.gd      precios, tiempos, que cae en cada paquete, cuanto vale, los
                  items de la tienda (siete con ocho niveles y dos piezas de
                  compra unica: ver item_max_level), con que pieza se enciende
                  cada automatizacion, los cuatro tipos de botin con el stat que
                  sube cada uno (LOOT_KINDS), los huecos del armario y el precio
                  del rebirth (el requisito y las monedas)
  skill_tree.gd   el arbol de mejoras que se paga con monedas de rebirth: los
                  cinco nodos (uno en el centro y cuatro caminos en diagonal),
                  lo que cuesta cada uno, lo que da y donde se dibuja

ui/         las piezas de interfaz, reutilizables
  ui_kit.gd       fabrica de controles: etiquetas, botones, paneles, sprites
                  (image, square, art y fit_art, que escala por el dibujo)
  sprites.gd      carga un PNG por nombre corto usando Sprites/index.tsv, y
                  mide la tinta de cada sprite (used_rect) para poder escalar
                  por el dibujo y no por el lienzo
  pixel_number.gd numeros grandes con los sprites num_*
  damage_popup.gd el numero de dano de un golpe: naranja el normal y amarillo el
                  critico (los digitos ya vienen pintados de oro, asi que el
                  color es un TINTE que los multiplica: ver la nota del fichero)
  pixel_slider.gd deslizador con los sprites ui_slider_*
  timer_ring.gd   el anillo de la espera

screens/    una clase por pantalla
  menu.gd           el menu de inicio
  game.gd           la partida: la mesa, la columna de sobres (con scroll y sus
                    constantes PACK_*), el bucle y las automatizaciones
  shop_panel.gd     la tienda: los diez items como CAJAS en rejilla, y el clic
                    en una abre su ficha
  item_card.gd      la ficha de un item: la descripcion larga, los numeros del
                    efecto de ahora y del nivel siguiente, y el boton de
                    comprar (que PIDE la compra a la tienda, no la hace)
  auto_buy_panel.gd el mini menu de la compra automatica (que sobres se compran)
  locker_panel.gd   el armario: el inventario a la IZQUIERDA y las vitrinas a la
                    DERECHA, con la suma de los cuatro bonus y VENDER TODO
  rebirth_panel.gd  el arbol de mejoras: la barra de arriba (el rebirth, lo que
                    te llevas y lo que falta) superpuesta al arbol, que se
                    arrastra con el raton; pulsar un nodo abre su ficha
  skill_card.gd     la ficha de una mejora del arbol: lo que da, lo que el stat
                    lleva sumado y lo que sumara, el precio y el boton de
                    comprar (que PIDE la compra al arbol, no la hace)
  reveal_card.gd    la tarjeta de revelado
  settings_panel.gd los ajustes
  table_element.gd  un objeto de la mesa: el paquete que se abre, el botin que
                    se vende, y se arrastra por la mesa
```

## Que NO va aqui

- **Los sprites** estan en `Sprites/`, en subcarpetas. Se piden por nombre
  corto (`Sprites.tex("loot_vinyl_psa7")`) y la ruta la resuelve
  `Sprites/index.tsv`, que escribe el generador de Python. **Y los sonidos**
  igual, en `Sounds/` con `Sound.play("sfx_sell")` y su propio `index.tsv`.
  Son dos indices y no uno porque son dos medios distintos, pero la idea es
  la misma: el codigo pide un nombre, nunca una ruta.
- **Las escenas** estan en `scenes/`, y son practicamente vacias: cada una tiene
  un unico nodo raiz con el script de `screens/` puesto. Todo lo demas se monta
  en codigo desde `ui_kit.gd`, porque casi todas las piezas se repiten con
  parametros (una ranura por paquete, una estrella por punto de la nota PSA) y
  en codigo salen de un bucle.
- **Las herramientas de desarrollo** estan en `dev/` y no se empaquetan.
- **Los generadores de Python** estan en `tools/`.

## El orden de las capas

`data/` no depende de nada de la interfaz. `ui/` no sabe nada del juego, solo de
sprites. `screens/` es lo unico que las mezcla. Asi que se puede cambiar la
interfaz entera sin tocar los datos, y reequilibrar el juego sin abrir un
fichero de la interfaz.

**El audio es una capa aparte, y por eso lo pone `screens/`.** `Sound` sabe
reproducir un nombre y nada mas: no conoce el juego. Quien decide que vender
suena es `game.gd`, que es quien vende. Si `Sound` supiera que existe algo
llamado "vender" habria que tocar el audio cada vez que se toca una regla.

**Quien decide es la pantalla, no la tarjeta.** `reveal_card.gd` dice QUE se ha
elegido (`resolved("store")`, `"sell"` o `"later"`) y se cierra; quien mueve el
dinero, el inventario y la mesa es `game.gd`, que es quien los tiene. Por eso
GUARDAR no mete nada en el inventario por su cuenta: solo lo pide. Y por eso
cerrar sin elegir es una tercera respuesta y no un "no ha pasado nada".
