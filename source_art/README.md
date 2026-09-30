# source_art/ - el arte de partida

Los PNG originales de los que salio alguna pieza del juego, **sin tocar**. No son
del juego: Godot no los importa y no entran en la carpeta `Sprites/` a proposito,
que es donde vive lo que de verdad se usa.

Estan aqui para dos cosas:

1. **No perderlos.** Los sprites del juego se generan con `tools/`, y lo que
   sale de un generador de imagenes se normaliza con `tools/normalize_sprite.py`
   (recorte, encuadre a la rejilla de 32, paleta del juego, alfa binario). El
   proceso no es reversible: una vez normalizado, el original es lo unico que
   queda si se quiere cambiar algo.
2. **Saber de donde sale cada cosa.** Los dos ficheros son la pila de monedas y
   la chapa de la tienda, que son de lo poco que no se dibuja con codigo.

Para meter un sprite nuevo de aqui dentro:

```bash
python3 tools/normalize_sprite.py source_art/<fichero>.png --name <prefijo>_<nombre>.png
```

El prefijo es lo que decide la subcarpeta de destino (ver
`tools/sprite_paths.py`). La herramienta lo anade al indice, asi que el juego lo
encuentra por su nombre.
