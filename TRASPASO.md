# TRASPASO — Pack Tycoon en primera persona (estado a 9 de octubre de 2026)

Este documento es para **cualquier IA o persona** que siga trabajando mañana en esto.
Se escribe para que no haya que releer la conversación entera: aquí está lo que se
ha hecho, lo que queda, cómo se comprueba y con qué estilo se trabaja.

---

## 1. El proyecto en dos líneas

- **Qué es**: *Pack Tycoon*, un juego de Godot 4.7 de abrir sobres y vender botín.
  Antes era un juego 2D de mesa (todo interfaz encima de un dibujo de trastienda).
- **Ruta**: `/home/usuari-tarda/Escriptori/Héctor/proyecto-godot`
- **Motor**: `Godot_v4.7.2-stable_linux.x86_64`, en
  `/home/usuari-tarda/Escriptori/Héctor/Godot_v4.7.2-stable_linux.x86_64`
- **Idioma del código**: **GDScript con todos los comentarios y textos en ESPAÑOL**
  (con tildes en los comentarios nuevos, sin tildes en los textos de la interfaz
  porque la fuente de píxeles no las tiene). Los nombres de funciones y variables
  también en español (`_room`, `_soltar`, `hint_line`, `sign_name`...).
- **Estilo del proyecto (IMPORTANTE)**: los comentarios no dicen *qué* hace el
  código, dicen **por qué** está así y **qué se rompe** si se cambia. Ver
  `scripts/world/player.gd` o `scripts/world/world_screen.gd`: son el modelo a
  imitar. Nada de comentarios obvios tipo `# recorre la lista`.

## 2. Qué se ha hecho (resumen del cambio grande)

El juego se ha convertido en un **juego en primera persona** dentro de una
trastienda 3D, sin menús: todo lo que se hacía con botones se hace ahora
**andando hasta un cacharro de la sala y pulsando E mirándolo**.

### Piezas nuevas (scripts/world/)
- `interactable.gd` — base de todo lo que se puede mirar. Al entrar en la mira
  **aparece su cartel flotante** (billboard, `WorldLabel`) con el nombre y lo que
  se puede hacer; al salir, se va solo. Es la clave de "las cosas aparecen
  girando la cabeza".
- `station.gd` — un cacharro con cristal. Tiene `on_use` (Callable),
  `on_can_use`, `locked_hint` y `on_hint` (texto dinámico del cartel).
  **No sabe nada del juego**: quien lo cablea es `game.gd`.
- `world_screen.gd` — **una pantalla de verdad**: un `SubViewport` de 1920x1080
  pegado en un quad 3D. Los paneles viejos (`ShopPanel`, `LockerPanel`...) **no se
  reescribieron**: se cuelgan dentro de su `stage` y se ven en el mundo. El ratón
  entra por **rayo**: `uv_at()` (mundo → píxel del lienzo) y `feed()` (reenvía el
  evento al SubViewport). `world_point_for_canvas()` es el inverso y lo usan los
  tests para clicar donde se ve el botón.
- `world_label.gd` — texto 3D con la fuente de píxeles del juego.
- `player.gd` — el jugador: `CharacterBody3D`, WASD + ratón para girar la cabeza,
  mira en el centro de la pantalla, `lock_on()` para pegarse a una pantalla,
  `freeze()` para la tarjeta de revelado, `teleport()`/`look_at_world()` para los
  tests. Las teclas se crean **por código** (`ensure_actions()`), no en
  `project.godot`.
- `room.gd` (`class_name Backroom`) — toda la trastienda en código: suelo, paredes,
  luces, la mesa y los cacharros. La mesa **sigue en las mismas coordenadas** que
  en 2D (`TABLE_RECT` en píxeles lógicos, 1 px = 0.01 unidades).

### La sala tiene 8 cacharros
| Cacharro | Dónde | Qué hace |
|---|---|---|
| `vending` MAQUINA DE SOBRES | pared norte x=7.4 | su cristal enseña **solo la columna de sobres** (`region`); comprar la lista |
| `terminal` TERMINAL DE LA TIENDA | pared oeste z=4.6 | abre `ShopPanel` (los items) |
| `vitrine` VITRINA DEL ARMARIO | pared este z=5.0 | abre `LockerPanel` + 8 nichos 3D con lo expuesto |
| `altar` HUCHA | pared norte x=17 | abre `RebirthPanel` (con requisito) |
| `clipboard` AJUSTES | pared oeste z=8.6 | abre `SettingsPanel` |
| `sellbox` CAJA DE VENTA | pared norte x=12.4 | **vende la mesa entera al momento** (no abre nada) |
| `opener` APERTURA AUTOMATICA | pared norte x=9.9 | **enciende/apaga los Pinchos**; el cartel dice SI/NO |
| `pc` ORDENADOR | pared oeste z=6.7 | abre `AutoBuyPanel` (gated por el item `pc`) |
| `holo` | delante de la cara | la tarjeta de revelado, flotando |

### La barra de arriba ya NO tiene botones
Antes tenía 6 chapas (apertura auto, compra auto, armario, VENDER, TIENDA,
ajustes). Ahora solo quedan **el dinero**, **MESA x/y** y el rótulo
"MIRA UN CACHARRO Y PULSA E". **No queda ningún menú que abrir con una tecla de
función**: todo se hace delante de algo de la habitación. La tira 2D de la vitrina
de abajo se ha quedado como **rótulo** (se le quitó su botón ARMARIO).

## 3. Estado de la verificación (último resultado real)

```
$G --headless --path . res://dev/InputTest.tscn    -> EXIT=0   "RATON: todo correcto."  (110 OK)
$G --headless --path . res://dev/SmokeTest.tscn    -> EXIT=0   "HUMO: todo correcto."   (430+ OK)
```
donde `G="/home/usuari-tarda/Escriptori/Héctor/Godot_v4.7.2-stable_linux.x86_64"`.
Los dos están **en verde** con el estado actual de los ficheros.

> Ojo: el smoke test se lanzó ANTES de los últimos retoques de la barra y de los
> tres cacharros nuevos. **Vuelve a pasarlo** como primera tarea del día: los
> métodos que usa (`_open_shop`, `_open_locker`, `_sell_all_table`,
> `_open_auto_buy`) siguen existiendo, pero conviene confirmarlo.

## 4. Problemas encontrados y CÓMO se resolvieron (para no volver a caer)

1. **El cristal se montaba del tamaño por defecto.** En `WorldScreen`, la malla se
   construye en `_init()`, que corre **antes** de que `room.gd` le asigne
   `size_units`. Resultado: el quad se dibujaba a 3.2x1.8 siempre y los clics
   (que sí medían con el tamaño pedido) caían en otro sitio del que se veía.
   → Arreglado con un **setter** de `size_units` que redimensiona la malla.
2. **La cámara miraba al medio de la mesa, no al del cristal.** Cada estación tenía
   `view_from`/`view_at` escritos a mano y no coincidían con la altura de su
   pantalla. Los botones de arriba del panel salían **fuera del encuadre**: se
   podían pulsar por rayo, pero el jugador no los veía.
   → `room.gd` tiene ahora `_place_screen(st, at, dist)` que pone el cristal **y**
   la vista a la altura del cristal (regla: la cámara mira al **centro del cristal**).
3. **`lock_on()` subía al jugador a la altura del cristal y la gravedad lo bajaba
   en el mismo frame**: la cámara acababa mirando por debajo del panel (el mismo
   síntoma que el punto 2). → `Player.lock_on()` **no toca la altura**: coloca la
   horizontal (x, z) y mira al cristal **desde los ojos** que ya tiene.
   Los tests hacen lo mismo con el helper `_stand_before(st)` de `input_test.gd`.
4. **`TableElement._ground_at()` devolvía un punto espejado.** Mirando hacia
   arriba (las cartas son más altas que el jugador) el rayo no corta el plano de la
   mesa por delante: `t <= 0` y el punto salía **detrás** del jugador, así que al
   arrastrar la carta saltaba a la punta opuesta de la mesa.
   → Devuelve `Vector2.INF`; `drag_to()` no mueve nada y `press_at()` mide desde el
   centro del objeto.
5. **El arrastre con la mesa de refilón.** La mesa se mira casi de canto (los ojos
   están 0.5 unidades por encima), así que el punto de la mesa se mueve muchísimo
   por cada píxel de ratón. Un arrastre largo desde el otro lado de la sala acaba
   pidiendo un punto **fuera de la mesa** y se recorta al borde (`_move_to`).
   → No es un fallo: es geometría. El test arrastra **desde el borde de la mesa**,
   que es como se arrastra de verdad.
6. **Test intermitente (el peor tipo).** El paquete de la sección anterior aterriza
   en un punto **al azar**; si la carta nueva caía encima, el rayo de la mira daba
   al paquete y no a la carta. Pasaba unas veces sí y otras no.
   → El test hace `await _empty_table()` antes de arrastrar (sitio fijo, mesa limpia).

## 5. Qué queda por hacer (orden recomendado)

1. **Pasar el smoke test** con el estado actual (ver §3, nota) y arreglar lo que salga.
2. **Documentación**: `README.md`, `dev/README.md`, `scripts/README.md` y
   `scenes/README.md` están **a medias** respecto a este cambio: hay que documentar
   `scripts/world/` (los ocho cacharros, el rayo del ratón, `_place_screen`, los
   helpers de test `_stand_before` / `_click_canvas`) y quitar las referencias a la
   barra de botones que ya no existe. **Es lo que más falta.**
3. **Capturas**: `dev/screenshots.gd` existe y antes funcionaba con Xvfb
   (`~/.local/share/godot/app_userdata/Pack Tycoon/shots/`). Hay que reencuadrarlo
   para la cámara nueva: ahora conviene una captura de la sala, una de la máquina
   de sobres y una de la tarjeta flotando delante de la cara.
4. **Repasar el encuadre de los cacharros con el juego abierto** (no en headless):
   sobre todo la **vitrina** (su sitio queda dentro del cuerpo de la mesa, ver §6).
5. **Nombres/limpieza**: `scenes/README.md` y los comentarios que aún digan "botón
   de la barra".
6. Si se quiere seguir con "estilo Clover Pit": ideas naturales encima de lo hecho
   son **arrastrar el botín hasta la caja de venta** (en vez de vender toda la
   mesa), un **reloj/cierre de turno**, y que los objetos expuestos en la vitrina
   se puedan **coger con la mano** desde el mueble.

## 6. Trampas conocidas / cosas raras a propósito (no "arreglar" sin leer)

- **La escala es rara y es a propósito**: el mundo 3D heredó las medidas del 2D
  (1 px lógico = 0.01) y una carta de 256 px son **2.56 unidades**, o sea el doble
  de alto que el jugador (1.20). La sala está construida **alrededor de la mesa**,
  no al revés: cambiar la escala de la mesa movería todas las coordenadas del juego
  (`TABLE_RECT`, el sorteo de sitio, los límites, los tests). Se lee como un almacén
  de objetos gigantes, que es justo lo que vende el juego.
- **El jugador se planta dentro del cuerpo de la mesa** en el terminal, la vitrina,
  el altar y el atril (sus sitios quedan 0.2-0.5 unidades dentro del rectángulo de
  la mesa). El cuerpo de la mesa es sólido, así que la física lo empuja hacia fuera
  un poco y la cámara se queda algo más cerca de lo previsto. Se nota poco, pero
  **si se quiere pulir**: bajar `dist` en `_place_screen()` para esos cuatro, o
  recortar el cuerpo de la mesa.
- **El jugador vive dentro de un `SubViewport`** (para que el 3D y el 2D se puedan
  mezclar). Por eso **el ratón y las teclas NO llegan al jugador**: los reparte
  `game.gd._unhandled_input()` (girar la cabeza, E, arrastre) y las pantallas
  reciben el ratón reenviado por `WorldScreen.feed()`.
- **`main.gd` es el que tiene las capas** (`screen_host`, `veil_host`,
  `overlay_host`, `toast_host`) y va en `MOUSE_FILTER_IGNORE` a propósito: si el
  raíz o los hosts están en `STOP`, **se comen todos los clics** y el mundo deja de
  responder sin ningún error. En la partida **no hay ni un `push_veil()`**.
- **La fuente de píxeles sólo tiene tamaños múltiplos de 7** (`UIKit.FONT_STEP`).
  Nunca pasar un `font_size` a pelo a Godot.
- Los tests imprimen `DIAGCLIC` / `DIAGMB` (y los diagnósticos que se añadan): son
  para depurar y **no se quitan**, sirven para leer un fallo del log.

## 7. Cómo se comprueba (comandos exactos)

```bash
G="/home/usuari-tarda/Escriptori/Héctor/Godot_v4.7.2-stable_linux.x86_64"
cd /home/usuari-tarda/Escriptori/Héctor/proyecto-godot

# El test del ratón (rápido, 110 comprobaciones): menús, cristales, clics por rayo,
# arrastre, tarjeta de revelado, cacharros.
timeout 400 "$G" --headless --path . res://dev/InputTest.tscn > /tmp/in.log 2>&1; echo "EXIT=$?"
grep -nE "^  MAL|^RATON|SCRIPT ERROR" /tmp/in.log        # tiene que decir "todo correcto."
grep -cE "^  OK" /tmp/in.log

# El test del juego entero (lento, ~1-2 min, 430+ comprobaciones).
timeout 500 "$G" --headless --path . res://dev/SmokeTest.tscn > /tmp/sm.log 2>&1; echo "EXIT=$?"
grep -nE "^  MAL|^HUMO|SCRIPT ERROR" /tmp/sm.log
```
- **Exit code 0 = verde.** El runner sale con `quit(1)` si hay algún `MAL`.
- `EXIT=124` significa que se agotó el `timeout`: subirlo, no es un fallo del juego.
- Un `SCRIPT ERROR: Parse Error` en el log tumba el test entero (0 comprobaciones):
  leer la primera línea del log, no las últimas.
- **Ojo con los nombres**: `input_test.gd` es un `_run()` enorme; si se declara una
  variable dos veces en el mismo ámbito (pasó con `caja`) el script no compila.

## 8. Cómo trabajar en este repo (estilo que funciona aquí)

1. **Leer antes de escribir**: los ficheros tienen comentarios que explican el porqué;
   casi todos los "arreglos evidentes" ya se probaron y fallaron (ver §4 y §6).
2. **Comprobar con los dos tests** antes de dar algo por hecho; y si el cambio toca
   una interacción nueva, **añadir sus comprobaciones** a `dev/input_test.gd`
   (sección nueva con `print("...:")` y `_check(cond, "frase en español")`).
3. Los tests **teleportan** al jugador (`_stand_before`) en vez de andar: no
   convertirlos en pruebas de paseo.
4. **Los textos y los nombres de las comprobaciones van en español**, en minúscula y
   sin tildes (por la fuente y por coherencia con el resto).
5. No hay que pedir permiso para tocar `scripts/world/*`, `game.gd`, `room.gd` ni
   los tests: es donde vive este trabajo.

## 9. Ficheros tocados en esta última sesión

- `scripts/world/player.gd` — `lock_on()` no toca la altura (§4.3).
- `scripts/world/room.gd` — `_place_screen()`, vistas a la altura del cristal,
  `pick_half` que llega al cristal, y los tres cacharros nuevos
  (`_build_sellbox`, `_build_opener`, `_build_pc`).
- `scripts/world/world_screen.gd` — setter de `size_units` (§4.1).
- `scripts/world/station.gd` — `on_hint` (texto dinámico del cartel).
- `scripts/screens/table_element.gd` — `_ground_at()` con `Vector2.INF` (§4.4).
- `scripts/screens/game.gd` — barra sin botones, cableado de los tres cacharros,
  `_open_auto_buy` en el ordenador, `_on_settings_closed` simplificado, la tira de
  la vitrina como rótulo.
- `dev/input_test.gd` — `_stand_before()`, secciones de la tienda / compra
  automática / armario reescritas para el flujo "mirar + E", sección nueva de la
  caja y el interruptor, arrastre determinista.

## 10. Primera orden del día (copiar y pegar)

```
Lee TRASPASO.md entero y sigue el estilo que describe. Primero pasa el SmokeTest
(comando en §7) y arregla lo que salga. Después dedícate al punto 2 de §5:
documentar scripts/world/ en README.md, dev/README.md y scripts/README.md, y quitar
las referencias a la barra de botones que ya no existe. No cambies el diseño sin
leer §4 y §6.
```
