# scenes/ - las escenas

Cada `.tscn` tiene **un solo nodo raiz** con su script de `scripts/screens/`
puesto. Todo lo demas —paneles, botones, etiquetas— se monta en codigo desde
`ui_kit.gd`.

No es descuido. Casi todas las piezas se repiten con parametros: una ranura por
paquete de la mesa, una estrella por punto de la nota PSA, un boton por
herramienta. En el editor habia que crear y alinear cientos de nodos a mano, y
cualquier cambio de posicion era editar veinte escenas. En codigo son bucles, y
cambiar el sitio de un boton es tocar una linea.

Cuando una escena si tiene estructura fija (un arbol con hijos, algo que un
diseñador quisería abrir en el editor), se hace aqui normalmente.

## Por que el editor se ve vacio

Consecuencia directa de lo de arriba: al abrir cualquiera de estos `.tscn` el
visor del editor sale **en blanco**. No es un fallo y no hay nada que arreglar.
El editor dibuja lo que hay escrito en el `.tscn`, y en estos ficheros solo hay
un nodo raiz sin hijos; los botones y los paneles no existen hasta que se
ejecuta el `_ready()`, y el `_ready()` solo corre al jugar.

Para ver el juego: **F5** (o el boton ▶ de arriba a la derecha). La escena
principal ya esta configurada (`run/main_scene` en `project.godot`), asi que F5
arranca el juego entero y no una escena suelta. Con **F6** se ejecuta solo la
escena que se tenga abierta, que para estas no sirve de nada.

```
Main.tscn          la escena principal: el punto de entrada del juego
Game.tscn          la partida
Menu.tscn          el menu de inicio
ShopPanel.tscn     la tienda
ItemCard.tscn      la ficha de un item de la tienda
AutoBuyPanel.tscn  el mini menu de la compra automatica
LockerPanel.tscn   el armario: el inventario y las vitrinas
RebirthPanel.tscn  la hucha: reiniciar la partida a cambio de monedas
SkillTreePanel.tscn el arbol de habilidades: 4 ramas x 2 opciones, en monedas
RevealCard.tscn    la tarjeta de revelado
SettingsPanel.tscn los ajustes
ui/
  game_theme.tres  el tema: la fuente y los colores por defecto de la interfaz
```

`game_theme.tres` esta aparte porque no es una pantalla: es un recurso, y
cualquier escena que lo use lo hereda sin nombrarlo.
