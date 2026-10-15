# Prompts para generar sprites con IA

Sprites que es mejor generar con IA que por script: sobre todo los **paquetes con
la envoltura rasgada**, que son formas orgánicas y recortadas. Los que ya salen
bien por script (discos, cajas, gemas, auras, herramientas, insignias e iconos
de UI) están en `../tools/make_sprites.py` y **no hay que pedirlos a la IA**.

## Cómo se usa

Cada sprite se monta con **tres bloques fijos + una línea de sujeto**. Los tres
bloques son idénticos para todos los sprites: son los que garantizan que el
resultado encaje con los originales de Gemini que ya tienes.

```
[Bloque A: estilo]
[Bloque B: encuadre y fondo]
[Bloque C: negativo]
Sujeto: <línea de la tabla que toque>
```

Los sujetos están en español porque es el idioma del proyecto; si un resultado
sale raro, traduce solo la línea del sujeto al inglés y repite.

## Bloque A — Estilo

```
Sprite de pixel art para un videojuego incremental 2D. Un único objeto centrado,
vista de frente o ligero 3/4, estilo "pixel art HD" con píxeles grandes y
perfectamente visibles sobre una rejilla de 32x32 píxeles de arte, sin
suavizados ni antialiasing. Contorno oscuro grueso de 1-2 píxeles de rejilla
alrededor de toda la silueta. Iluminación coherente desde arriba-izquierda, cada
material resuelto con exactamente tres tonos (sombra, base y brillo), sin
degradados suaves. Sin sombra proyectada en el suelo.

Paleta obligatoria, usa solo estos tonos y sus vecinos inmediatos:
  contorno #101020
  marrones #402018 / #804828 / #A86030
  oros #A84808 / #E88000 / #F89810 / #F8C000 / #FFD858
  crema #FCECC4 / #D4B888
  gris plástico #BCC4D0 / #8C94A4 / #606878
  turquesa SOLO en gemas y detalles brillantes #3868A8 / #58D0C4
```

## Bloque B — Encuadre y fondo

```
Fondo totalmente transparente (PNG con canal alfa real, sin fondo blanco ni
damero dibujado). Lienzo cuadrado. El objeto ocupa alrededor del 80% del ancho y
queda centrado, con al menos 2 píxeles de rejilla de margen. Sin texto, sin
letras, sin números, sin logotipos, sin marcas de agua, sin marcos decorativos.
```

## Bloque C — Negativo

```
Evita: fondo blanco o de color, damero de transparencia dibujado, sombra
proyectada, desenfoque, degradados suaves, texturas fotorrealistas, perspectiva
3D compleja, varios objetos distintos en la misma imagen, partes del cuerpo
humano más allá de manos, texto o números.
```

## Ejemplo montado

> **[Bloque A]** + **[Bloque B]** + **[Bloque C]** +
> `Sujeto: un sobre de vinilo cuadrado de cartón marrón gastado, con el borde superior abierto y un vinilo negro asomando ligeramente, sellado con una cinta dorada.`

## Catálogo

### Paquetes: ya hechos

Los **cinco** (cerrado y roto) los genera el script y quedan bien, así que **no
hay que pedirlos a la IA**. Se quitaron de este catálogo. La sección de abajo se
queda vacía salvo que quieras refinar algún `_open` concreto.

> Si algún día hay que rehacer un desgarro más orgánico, estos eran los sujetos:
>
> | Nombre | Sujeto |
> |---|---|
> | `pack_vinyls_open` | una funda de vinilo rasgada por una esquina, con restos de cartón y el vinilo negro saliendo del todo |
> | `pack_sneakers_open` | una caja de zapatillas con la tapa levantada, papel de seda asomando y una zapatilla blanca con detalles dorados saliendo |
> | `pack_electronics_open` | una caja de electrónica con el plástico rasgado y arrancado, dejando ver el interior oscuro y un cable enrollado asomando |
> | `pack_misc_open` | un paquete genérico abierto y arrugado, con objetos variados asomando: un reloj, un cable y una pieza dorada |

### Objetos de botín: la cola que queda

Aquí es donde está el trabajo de verdad. Como el juego ahora **compra a ciegas**,
lo que define la partida es qué sale de dentro de la caja. Con cuatro objetos
únicos por categoría, abrir 200 cajas es una ruleta de cuatro caras: tolerable.
Con seis por el resto, mejor.

Reparto actual, que es el punto de partida:

| Categoría | Hay | Falta |
|---|---|---|
| Sobres de cartas | 4 (común, editada, vintage, holográfica) | 0 |
| Vinilos | 4 (sencillo, doble LP, edición numerada, color) | 0 |
| Zapatillas | 4 (blanca, de piel, a restaurar, limitada) | 0 |
| Electrónica | 5 (consola, auriculares, cámara, cartucho, portátil) | 1: cámara de fotos |
| Ítems varios | 6 (reloj, de bolsillo, zapatilla, cámara, cable, lingote) | 2: una joya, un violín |

> **Los cinco sobres están cerrados y el motivo importa.** Antes los de vinilos
> y zapatillas tenían cuatro filas apuntando al mismo PNG: abrir 200 cajas era
> una ruleta de una cara con cuatro precios. Ahora cada objeto tiene su dibujo
> en los cinco sobres. Cuando se añadan objetos, el mismo cuidado — la rareza
> puede repetir dibujo, el precio no puede ser la única diferencia.
>
> Lo que sí sale barato de añadir: **el mismo objeto puede salir en varios
> sobres** (la cámara está en electrónica y en varios, la zapatilla en
> zapatillas y en varios). Es lo natural en una casa de subastas y evita
> dibujar veinte objetos para cubrir cinco sobres.
>
> Y el nombre del objeto nuevo es de **modelo**, nunca de estado: el estado lo
> deduce la nota PSA, asi que "gastada" como nombre de sprite pondria una
> zapatilla rota con la insignia de *como nuevo* al lado.

> **Las 4 cartas sí se desgastan, y con otro código.** Cada una tiene sus diez notas
> (`loot_card_foil_psa1` … `_psa10`), pero el desgaste es `apply_card_wear()`, no
> `apply_wear()`: roce del borde, humedad, esquina doblada, pliegue y mancha de
> anillo, porque el cartón no se desgasta como una consola. Y hay cuatro dibujos
> distintos, no uno teñido por rareza. Ver [`README.md`](README.md).

> **Ojo con el número de archivos.** Cada objeto nuevo son 10 sprites, uno por nota
> PSA (`loot_<objeto>_psa1` … `_psa10`), no uno. Los 3 objetos que faltan serían
> 30 archivos, y salen todos del mismo dibujo base con `apply_wear()` encima, asi
> que el trabajo de dibujo real sigue siendo 9.
> Ver [`README.md`](README.md).

> Estos son los que **más conviene hacer por script**, porque son formas
> geométricas y el generador las saca limpias. Cada uno con su prefijo `loot_`.
>
> Cuando los haya, la caja y su contenido van juntos: `pack_vinyls` solo puede
> sacar vinilos, y eso es justo lo que el jugador tiene que aprender a leer.
| `pack_vinyls` | *(ya hecho)* |
| `pack_sneakers` | *(ya hecho)* |
| `pack_electronics` | *(ya hecho)* |
| `pack_misc` | *(ya hecho)* |

### Herramientas equipables: ya hechos

Las cuatro herramientas (`tool_cutter`, `tool_scissors`, `tool_gloves`,
`tool_crowbar`) las genera el script y quedaron bien, así que **no hay que
pedirlas a la IA**. Se quitaron de este catálogo.

> Si algún día hay que rehacer el guante, que es la forma más orgánica de las
> cuatro, el sujeto era: *un guante de trabajo grueso de cuero marrón con
> refuerzos y costuras doradas, puño ancho y gastado*.

### Iconos de interfaz: ya hechos

Ojo: las piezas de la **pantalla de inicio**, la **tienda** y la
**configuración** las genera el script (`ui_panel_*`, `ui_button_*`,
`ui_slot`, `ui_checkbox_*`, `ui_slider_*`, `ui_arrow_*`, `ui_icon_*`), y los
**números** (`num_*`).

También los doce sprites del **árbol de habilidades** (`skill_*`), que son arte
cerrado y no hay que pedir a la IA: los **4 emblemas de rama**
(`skill_diamond` calidad de vida, `skill_dollar` ganancias, `skill_lightning`
daño, `skill_cycle` herencia) y los **8 iconos de las opciones**
(`skill_drop` caída rápida, `skill_grid` mesa ordenada, `skill_sales` mejores
ventas, `skill_cheap` sobres baratos, `skill_rip_cash` dinero extra,
`skill_hit` golpe duro, `skill_double` golpe doble, `skill_heir` dinero
inicial). Qué dibuja cada uno y para qué opción es está en `README.md`, en
*El árbol de habilidades*.

Además, los siete iconos de segunda generación que quedaban pendientes aquí
(`ui_icon_auto_open`, `ui_icon_auto_buy`, `ui_icon_achievement`,
`ui_icon_market_event`, `ui_icon_inventory`, `ui_icon_display_case`,
`ui_icon_vitrine`) ya están hechos por script. **La sección queda vacía.**

### Estado de conservación: ya hechos

Las cuatro insignias `condition_*` las genera el script como discos del mismo
tamaño con un símbolo distinto, para que se lean como una familia en la ficha del
objeto. **No hay que pedirlas a la IA.**

## Post-proceso obligatorio

Lo que salga del generador **no** se mete tal cual en `Sprites/`. Primero se
guarda el original en `../source_art/` (para poder rehacerlo, porque normalizar
no tiene vuelta atrás) y luego se pasa por el normalizador, que quita el fondo,
recorta, centra, reescala con vecino más cercano y opcionalmente bloquea la
paleta:

```bash
# uno suelto, con nombre definitivo (SIN extensión: la carpeta la pone el prefijo)
python3 tools/normalize_sprite.py ../source_art/descarga.png \
    --name pack_vinyls --grid 32 --lock-palette

# un lote entero, sin renombrar
python3 tools/normalize_sprite.py ~/Baixades/lote/*.png --grid 32

# además forzando los colores exactos de la paleta del juego
python3 tools/normalize_sprite.py entrada.png --grid 32 --lock-palette
```

El destino lo decide el **prefijo** del `--name` (`pack_` → `packs/`, `loot_` →
`loot/`, `ui_icon_` → `ui/icons/`; tabla en `../tools/sprite_paths.py`) y la
herramienta añade la entrada a `Sprites/index.tsv`, que es como el juego los
encuentra. No hace falta crear carpetas ni tocar el índice a mano.

- `--grid 32` baja el sprite a la rejilla de 32 px y luego escala con factor
  entero: es lo que hace que los píxeles queden uniformes, como en los originales.
- `--lock-palette` es agresivo: aplana los degradados suaves de la IA a los tonos
  del juego. Va muy bien para unificar estilo y mal si la IA ya acertó con el
  sombreado, así que pruébalo y compara. **En los dos originales que ya hay hizo
  falta**: traían 29.333 y 14.680 colores, ninguno de la paleta.
- El normalizador además **deja el alfa en 0 o 255**. La IA viene con el borde
  suavizado y eso, en un juego con píxel duro, se ve como un halo. Se puede
  desactivar con `--soft-alpha` si de verdad lo quieres suave.
- `--dry-run` te dice qué haría sin escribir nada.
- Revisa siempre la hoja de contacto (`python3 tools/make_sprites.py --all --preview`)
  para juzgar el conjunto: un sprite puede verse bien solo y romper el estilo
  junto a los demás.

## Consejos para mantener la consistencia

1. **Trabaja siempre en la misma conversación** con el modelo de imagen. El estilo
   se mantiene mucho mejor si encadenas peticiones que si abres un chat nuevo por
   sprite.
2. **Genera primero el sprite más representativo** de cada familia (por ejemplo el
   paquete de vinilos), y luego pide los demás "en el mismo estilo que el anterior".
3. **Pide un objeto por imagen.** Si pides dos, el encuadre y el tamaño relativo
   se rompen y el recorte posterior queda mal.
4. **Rechaza cualquier resultado con fondo blanco.** El recorte por inundación del
   normalizador funciona bien con fondos planos, pero un fondo con degradado o
   ruido deja halos alrededor del contorno.
5. **Comprueba el tamaño relativo entre sprites:** una moneda tiene que ser
   pequeña y una caja de zapatillas grande. Si la IA devuelve todos los objetos
   ocupando el mismo lienzo, corrígelo después con `--size` o ajustando el margen.
6. **El turquesa es un acento, no un color de cuerpo.** Si un sprite sale con
   grandes zonas turquesa, está fuera de estilo: repítelo.
