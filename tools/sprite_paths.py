#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sprite_paths.py - donde vive cada sprite dentro de Sprites/.

Este modulo es la FUENTE DE VERDAD de la distribucion de ficheros. Lo importan
todos los generadores (make_sprites.py, make_background.py, make_screens.py,
make_font.py, normalize_sprite.py) para no tener cada uno su propia copia de la
tabla, que es como estas cosas se desincronizan sin que nadie se entere.

Y el juego no lo importa (es Python), pero lee el indice que genera
make_sprites.py a partir de aqui. Ese es el puente: esta tabla decide la
carpeta, el generador la aplica y escribe el indice, y el juego lo consume.

COMO SE DECIDE
--------------
Por el PREFIJO del archivo, y el prefijo ya decia que era cada cosa: loot_ era
botin, pack_ eran sobres, ui_ era interfaz. Esto no inventa una clasificacion
nueva, solo le da sitio a lo que el nombre ya decia.

    Sprites/
      loot/          loot_*                el botin (objetos y cartas)
      packs/         pack_*                los sobres que se compran
      tools/         tool_*                las herramientas
      items/         item_*                los items de la tienda equipables
      ui/panels/     ui_panel_*            los marcos de ventana
      ui/controls/   ui_*, menos iconos    botones, deslizadores, casillas
      ui/icons/      ui_icon_*             los iconos sueltos
      ui/indicators/ grade_ condition_     gema, estado, insignia, destello
                    rarity_ shadow_ fx_
                    skill_ currency_
      font/          num_* font_pack.*     la fuente y los digitos
      backgrounds/   bg_*                  los fondos
      mockups/       shot_*                las maquetas de referencia
"""

from __future__ import annotations

import os
from typing import Dict, List

# Prefijo de archivo -> subcarpeta de Sprites/.
#
# EL ORDEN IMPORTA en la busqueda: "ui_icon_" tiene que probarse antes que "ui_"
# o el prefijo corto se come al largo. Por eso no se itera este diccionario tal
# cual, sino la lista de claves ordenada de mas larga a mas corta
# (PREFIXES_LONGEST_FIRST).
FOLDER_BY_PREFIX: Dict[str, str] = {
    "loot": "loot",
    "pack": "packs",
    "tool": "tools",
    "item": "items",
    "ui_icon": "ui/icons",
    "ui_panel": "ui/panels",
    "ui_button": "ui/controls",
    "ui_checkbox": "ui/controls",
    "ui_slider": "ui/controls",
    "ui_timer": "ui/controls",
    "ui_arrow": "ui/controls",
    "ui": "ui/controls",
    "grade": "ui/indicators",
    "condition": "ui/indicators",
    "rarity": "ui/indicators",
    "shadow": "ui/indicators",
    "fx": "ui/indicators",
    "skill": "ui/indicators",
    "currency": "ui/indicators",
    "num": "font",
    "font": "font",
    "bg": "backgrounds",
    "shot": "mockups",
}

PREFIXES_LONGEST_FIRST: List[str] = sorted(FOLDER_BY_PREFIX, key=len, reverse=True)

# El nombre del indice. El juego lo lee (scripts/sprites.gd).
INDEX_NAME = "index.tsv"


def folder_for(file_name: str) -> str:
    """La subcarpeta de Sprites/ donde va un archivo, deducida de su nombre.

    Se pasa el NOMBRE COMPLETO (con .png) y no el prefijo suelto, para que no
    haya dos listas del mismo dato en el mismo fichero.
    """
    stem = file_name[:-4] if file_name.endswith(".png") else file_name
    for pre in PREFIXES_LONGEST_FIRST:
        if stem.startswith(pre):
            return FOLDER_BY_PREFIX[pre]
    raise KeyError(
        f"no se sabe en que carpeta va {file_name!r}: falta su prefijo en "
        f"FOLDER_BY_PREFIX (sprite_paths.py)")


def rel_path(file_name: str) -> str:
    """Ruta dentro de Sprites/, con carpetas: 'ui/icons/ui_icon_play.png'."""
    if not file_name.endswith(".png"):
        file_name += ".png"
    return f"{folder_for(file_name)}/{file_name}"


def in_folder(out_dir: str, file_name: str) -> str:
    """Ruta ABSOLUTA de un sprite dentro de la carpeta de sprites dada.

    Crea la carpeta si hace falta. La usan los generadores que escriben un
    fichero suelto (make_background, make_font, normalize_sprite) para no tener
    que acordarse de mkdir.
    """
    path = os.path.join(out_dir, rel_path(file_name))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def add_to_index(sprites_dir: str, rel_paths) -> int:
    """Añade sprites al indice sin reescribirlo entero. Devuelve cuantos entra.

    Lo necesitan las herramientas que meten un PNG que no ha generado
    make_sprites.py (por ahora normalize_sprite.py, que normaliza los sprites
    que salen de un generador de imagenes). Si no se registraran, el fichero
    estaria en Sprites/ pero el juego no lo encontraria por su nombre corto, que
    es justo como se cargan los sprites: se veria un hueco sin ningun error.

    Las entradas nuevas se anaden; las que ya estaban no se tocan. Asi el
    indice de make_sprites.py manda siempre sobre las sueltas.
    """
    index_path = os.path.join(sprites_dir, INDEX_NAME)
    cabeceras = [
        "# Indice de sprites: nombre corto<TAB>ruta dentro de Sprites/.",
        "# Lo genera tools/make_sprites.py. No editar a mano.",
        "# El juego lo lee en scripts/sprites.gd.",
    ]
    lineas: List[str] = []
    if os.path.exists(index_path):
        with open(index_path, encoding="utf-8") as fh:
            lineas = [l.rstrip("\n") for l in fh
                      if l.strip() and not l.startswith("#")]
    ya: Dict[str, str] = {}
    for l in lineas:
        parts = l.split("\t")
        if len(parts) == 2:
            ya[parts[0]] = parts[1]

    nuevos = 0
    for rel in rel_paths:
        stem = os.path.splitext(os.path.basename(rel))[0]
        if stem in ya:
            continue
        ya[stem] = rel
        nuevos += 1

    with open(index_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(cabeceras) + "\n")
        for stem in sorted(ya):
            fh.write(f"{stem}\t{ya[stem]}\n")
    return nuevos


def read_index(sprites_dir: str) -> Dict[str, str]:
    """Carga index.tsv y devuelve {nombre corto: ruta relativa}.

    La usa make_screens.py, que monta las maquetas con sprites ya colocados y no
    sabe en que carpeta esta cada uno. Si el indice no existe (por ejemplo la
    primera vez, antes de generar nada), cae a la carpeta plana y avisa: es
    preferible un maqueta incompleta a que la herramienta no arranque.
    """
    index_path = os.path.join(sprites_dir, INDEX_NAME)
    index: Dict[str, str] = {}
    if not os.path.exists(index_path):
        return index
    with open(index_path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) == 2:
                index[parts[0]] = parts[1]
    return index
