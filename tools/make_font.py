#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_font.py - la fuente de texto del juego.

HASTA AHORA el texto era lo unico que no era pixel art: los rotulos usaban la
fuente de Godot, que es suave, y se leia fatal encima de un fondo de pixeles.
Los numeros si eran pixel art (PixelNumber con los sprites num_*), pero un
parrafo con la fuente de Godot en medio de una pantalla de pixeles canta mucho.

Este script saca la fuente de verdad. Escribe dos cosas en Sprites/:

    font_pack.png   la hoja con todos los glifos, en una rejilla
    font_pack.fnt   la description de la hoja, en formato BMFont (texto)

Godot 4 importa el .fnt como FontFile y ya se puede poner en el tema. No hace
falta ningun plugin: BMFont es un formato que el editor entiende de serie.

POR QUE NO SE USA num_sheet.png
------------------------------
Los digitos de num_sheet.png son sprites sueltos con bisel dorado, pensados para
 Pintarse GRANDES (los precios). Para un rotulo de 32 px quedarian enormes y con
un contorno de 8 px de grosor. Aqui el glifo es de 5x7 de arte, con el contorno
de 1 px, y la hoja va a escala 1: el que agranda es Godot, con filtro NEAREST.

EL COLOR
--------
Los glifos se pintan en BLANCO PURO (#FFFFFF) con contorno en #101020, el mismo
que usa el resto del juego. No se tiñen aqui. Godot multiplica el glifo por el
color que le pida el tema (font_color), asi que el mismo .fnt sirve para un
rotulo crema, uno dorado y uno gris. Si se pintaran de color fijo habria que
hacer una fuente por cada color.

Se puede cambiar con --ink y --outline, pero dejarlos en blanco es lo que hace
que el tema pueda poner el texto del color que quiera.

EL TAMANO
---------
--scale decide cuanto se agranda cada glifo. La hoja se escribe YA escalada, y
la linea "info size=" del .fnt dice cuantos pixeles miden los glifos. Godot
calcula el tamano real dividiendo por eso, asi que --scale 4 con glifos de 5x7
da una fuente que thinks 20 px de alto. Los tamanyos que el juego pide (28, 32,
40, 48...) tienen que caer en multiplos de size*5/7 para que no queden
desalineados; con size=7 (--scale 1) cualquier tamano es multiplo y no hay
problema. Ver la nota de make_font_preview().

Uso:
    python3 tools/make_font.py
    python3 tools/make_font.py --scale 4
    python3 tools/make_font.py --preview          # hoja de comprobacion
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from typing import Dict, List, Tuple

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from font_patterns import GLYPHS, GLYPH_H, GLYPH_W, LETTERS, NAME_TO_CHAR  # noqa: E402
from sprite_paths import add_to_index, in_folder, rel_path  # noqa: E402

# --------------------------------------------------------------------------- #
# La tabla de caracteres
# --------------------------------------------------------------------------- #

# Orden de los glifos en la hoja. Se ordena para que las letras contiguas
# ocupen filas contiguas, que es mas facil de mirar cuando hay que retocar un
# patron. El espacio va el ultimo porque no se ve.
GLYPH_ORDER: List[str] = (
    list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    + list("0123456789")
    + [name for name in NAME_TO_CHAR if name != "space"]
    + ["space"]
)

# El glifo mide 5 de ancho, pero la celda mide 7: 5 de tinta y 1 de contorno a
# cada lado. Sin esa fila de aire el contorno se come el glifo de al lado.
CELL_W = GLYPH_W + 2
CELL_H = GLYPH_H + 2

# Alto de la linea: la celda mas un par de pixeles de aire, para que las lineas
# de un parrafo no se toquen.
LINE_HEIGHT = CELL_H + 2

# Pixeles desde el borde de la celda hasta la primera fila de tinta. INK_X es el
# margen a la izquierda; el de la derecha lo aporta el ancho de celda.
INK_X = 1
INK_TOP = 1


def pattern_for(name: str) -> List[str]:
    """Devuelve el patron 5x7 del glifo `name`, salga de donde salga.

    Los digitos y los signos de numero estan en GLYPHS (los usaba PixelNumber);
    las letras, en LETTERS. Un nombre que no exista en ninguno de los dos es un
    error de escritura, no un glifo que se pueda saltar en silencio.
    """
    if name in LETTERS:
        return LETTERS[name]
    if name in GLYPHS:
        return GLYPHS[name]
    raise KeyError(f"no hay patron para el glifo {name!r}")


def char_for(name: str) -> str:
    """El caracter que dibuja el glifo `name` (la 'A' de 'A', el ' ' de 'space')."""
    if name in NAME_TO_CHAR:
        return NAME_TO_CHAR[name]
    return name


def glyphs_in_order() -> List[Tuple[str, str, List[str]]]:
    """(nombre, caracter, patron) de cada glifo, en el orden de la hoja."""
    return [(n, char_for(n), pattern_for(n)) for n in GLYPH_ORDER]


# --------------------------------------------------------------------------- #
# La hoja
# --------------------------------------------------------------------------- #

def _ink_cells(pattern: List[str]) -> List[Tuple[int, int]]:
    """Los (x, y) de arte del patron que llevan tinta."""
    out: List[Tuple[int, int]] = []
    for y, row in enumerate(pattern):
        for x, ch in enumerate(row):
            if ch == "1":
                out.append((x, y))
    return out


def build_sheet(scale: int, ink, outline) -> Tuple[Image.Image, Dict[str, Tuple[int, int]]]:
    """Pinta la hoja y devuelve la imagen con donde ha quedado cada glifo.

    El contorno se pinta antes que la tinta, en los ocho vecinos de cada pixel
    de tinta. Asi el glifo queda con un aro de 1 px de arte, que es el mismo
    criterio que usa el resto del generador: el #101020 automatico.
    """
    cols = 16
    glifos = glyphs_in_order()
    rows = (len(glifos) + cols - 1) // cols
    w = cols * CELL_W * scale
    h = rows * CELL_H * scale
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    donde: Dict[str, Tuple[int, int]] = {}

    for i, (name, _ch, pattern) in enumerate(glifos):
        ox = (i % cols) * CELL_W * scale
        oy = (i // cols) * CELL_H * scale
        donde[name] = (ox, oy)
        tinta = _ink_cells(pattern)
        tinta_set = set(tinta)

        # Contorno: los vecinos de la tinta que no son tinta.
        for (x, y) in tinta:
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if (nx, ny) in tinta_set:
                        continue
                    if not (0 <= nx < GLYPH_W and 0 <= ny < GLYPH_H):
                        continue
                    for sy in range(scale):
                        for sx in range(scale):
                            px[ox + (nx + INK_X) * scale + sx,
                               oy + (ny + INK_TOP) * scale + sy] = outline

        # Tinta encima, para que el contorno nunca se coma el glifo.
        for (x, y) in tinta:
            for sy in range(scale):
                for sx in range(scale):
                    px[ox + (x + INK_X) * scale + sx,
                       oy + (y + INK_TOP) * scale + sy] = ink

    return img, donde


# --------------------------------------------------------------------------- #
# El .fnt (BMFont en texto)
# --------------------------------------------------------------------------- #

def build_fnt(donde: Dict[str, Tuple[int, int]], scale: int, page_name: str) -> str:
    """El .fnt en formato BMFont.

    Godot lee estos tres bloques: "info" (de que tamano es la fuente), "common"
    (la altura de linea y donde esta la linea base) y "chars" (un glifo por
    linea, con su rectangulo dentro de la hoja).

    El "size" es el alto real del glifo en pixeles de la hoja. Con --scale 4 son
    28 px, y Godoct trata eso como "el tamano 1" de la fuente: un Label con
    font_size 28 sale exacto y uno de 56 sale al doble.
    """
    glifos = glyphs_in_order()
    glifo_h = GLYPH_H * scale
    size = glifo_h
    line = LINE_HEIGHT * scale
    base = (GLYPH_H + INK_TOP) * scale

    out: List[str] = []
    out.append(f'info face="PackTycoon" size={size} bold=0 italic=0 charset="" '
               f'unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0')
    out.append(f'common lineHeight={line} base={base} scaleW=0 scaleH=0 pages=1 packed=0')
    out.append(f'page id=0 file="{page_name}"')
    out.append(f"chars count={len(glifos)}")

    for name, ch, _pattern in glifos:
        ox, oy = donde[name]
        code = ord(ch)
        # Cada glifo ocupa su celda entera, con el contorno dentro: por eso el
        # rectangulo es el ancho de la celda y no el del patron.
        out.append(
            f"char id={code} x={ox} y={oy} width={CELL_W * scale} height={CELL_H * scale} "
            f"xoffset=0 yoffset={INK_TOP * scale} xadvance={CELL_W * scale} "
            f"page=0 chnl=15"
        )

    # El salto de linea que usa Godot cuando le pides multilinea.
    out.append("kernings count=0")
    return "\n".join(out) + "\n"


# --------------------------------------------------------------------------- #
# Comprobacion
# --------------------------------------------------------------------------- #

def make_font_preview(scale: int = 6) -> Image.Image:
    """Una hoja con todas las letras escritas, para mirar si se leen.

    No se escribe en Sprites/ porque es una hoja de comprobacion, no un sprite
    del juego: va a tools/_font_preview.png y esta en el .gitignore.
    """
    glifos = glyphs_in_order()
    img, donde = build_sheet(scale, (255, 255, 255, 255), (16, 16, 32, 255))

    # Frases de prueba con todo lo que aparece en el juego de verdad.
    muestras = [
        "PACK TYCOON",
        "ABRE PAQUETES. A CIEGAS.",
        "SOBRES / VINILOS / ZAPATILLAS",
        "MESA 0/8   INVENTARIO 0/10",
        "CARTAS COMUNES RARAS EPICAS",
        "TARJETA DE REVELADO - NOTA 10",
        "COMPRAR / VENDER / TIENDA / AJUSTES",
        "1.234.567  5.000.000  -5% +3",
        "PRIMERA VERSION: SIN LOGROS TODAVIA",
    ]
    # Ancho de la muestra en celdas, para partirla en lineas si no cabe.
    celdas_por_linea = 30
    lineas: List[str] = []
    for m in muestras:
        palabras = m.split(" ")
        actual = ""
        for p in palabras:
            if len(actual) + len(p) + 1 > celdas_por_linea:
                lineas.append(actual)
                actual = p
            else:
                actual = f"{actual} {p}" if actual else p
        if actual:
            lineas.append(actual)

    ancho = celdas_por_linea * CELL_W * scale
    alto_linea = CELL_H * scale + 8
    out = Image.new("RGBA", (ancho, len(lineas) * alto_linea + 8), (20, 18, 30, 255))
    px = out.load()
    for li, texto in enumerate(lineas):
        x = 4
        y = 4 + li * alto_linea
        for ch in texto:
            if ch == " ":
                x += CELL_W * scale
                continue
            name = _name_for_char(ch)
            if name is None:
                x += CELL_W * scale
                continue
            ox, oy = donde[name]
            gl = img.crop((ox, oy, ox + CELL_W * scale, oy + CELL_H * scale))
            out.paste(gl, (x, y), gl)
            x += CELL_W * scale
    return out


def _name_for_char(ch: str):
    for name, c in NAME_TO_CHAR.items():
        if c == ch:
            return name
    if ch in GLYPH_ORDER:
        return ch
    return None


# --------------------------------------------------------------------------- #

def fix_import(ruta_fnt: str) -> bool:
    """Deja el .import de la fuente en scaling_mode=1 (solo escala entera).

    Godot escribe ese fichero al importar, y su valor por defecto es 2
    (escalado libre), que deja la letra con pixeles de dos tamanos y la hace
    verse borrosa a cuanto se agranda. El ajuste se pierde cada vez que se
    regenera la fuente o se mueve de carpeta, asi que en vez de confiar en que
    el fichero versionado siga bien, se corrige aqui.

    Se parchea el fichero que Godot ya escribio en vez de escribirlo desde cero,
    porque el uid y la ruta de .godot/imported/ los pone el importador.
    """
    ruta_import = ruta_fnt + ".import"
    if not os.path.exists(ruta_import):
        return False
    with open(ruta_import, encoding="utf-8") as fh:
        texto = fh.read()
    if "scaling_mode=1" in texto:
        return True
    nuevo = re.sub(r"^scaling_mode=\d+$", "scaling_mode=1", texto, flags=re.M)
    if nuevo == texto:
        nuevo = texto.rstrip("\n") + "\nscaling_mode=1\n"
    with open(ruta_import, "w", encoding="utf-8") as fh:
        fh.write(nuevo)
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--scale", type=int, default=1,
                    help="cuanto se agranda cada glifo en la hoja (1 por defecto)")
    ap.add_argument("--ink", default="#FFFFFF",
                    help="color de la tinta del glifo; blanco para que el tema lo tiña")
    ap.add_argument("--outline", default="#101020",
                    help="color del contorno de 1 px de arte")
    ap.add_argument("--preview", action="store_true",
                    help="escribe ademas tools/_font_preview.png con todo escrito")
    args = ap.parse_args()

    if args.scale < 1:
        print("--scale tiene que ser 1 o mayor", file=sys.stderr)
        return 2

    def _rgb(hexs: str) -> Tuple[int, int, int, int]:
        h = hexs.lstrip("#")
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sprites = os.path.join(root, "Sprites")
    os.makedirs(sprites, exist_ok=True)

    # La fuente va a Sprites/font/, decided por su prefijo como cualquier otro
    # sprite (ver sprite_paths.py). El .fnt tiene que vivir al lado de su PNG
    # porque dentro lleva la ruta relativa de la pagina.
    img, donde = build_sheet(args.scale, _rgb(args.ink), _rgb(args.outline))
    png = in_folder(sprites, "font_pack.png")
    img.save(png)

    fnt = build_fnt(donde, args.scale, "font_pack.png")
    ruta_fnt = png[:-4] + ".fnt"
    with open(ruta_fnt, "w", encoding="utf-8") as fh:
        fh.write(fnt)
    # La hoja tambien se apunta en el indice, por si algun dia se pide por
    # nombre corto y no por ruta. El .fnt no: no es un sprite, se carga por
    # ruta desde ui_kit.gd.
    add_to_index(sprites, [rel_path("font_pack.png")])

    # El .import tiene que quedar en escala entera; si Godot todavia no ha
    # importado el .fnt no hay fichero que parchear, y se avisa.
    if fix_import(ruta_fnt):
        print("Import: scaling_mode=1 (solo escalas enteras)")
    else:
        print("AVISO: aun no hay font_pack.fnt.import; cuando Godot importe la "
              "fuente, ejecuta otra vez make_font.py para dejar scaling_mode=1",
              file=sys.stderr)

    print(f"Fuente: {os.path.relpath(ruta_fnt, root)}  "
          f"({len(GLYPH_ORDER)} glifos, hoja {img.width}x{img.height})")
    print(f"Hoja:   {os.path.relpath(png, root)}")

    if args.preview:
        prev = make_font_preview()
        ruta_prev = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 "_font_preview.png")
        prev.save(ruta_prev)
        print(f"Preview: {ruta_prev}  ({prev.width}x{prev.height})")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
