#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_font.py - las fuentes de texto del juego.

EL JUEGO USA TRES LETRAS, NI UNA MAS (elegidas el 2026-11-17 sobre una hoja de
muestras):

    TITULOS   font_titulo   mayusculas de trazo doble, contorno y sombra. Las
                            cabeceras de los paneles, los revelados y los
                            carteles que van encima de la mesa.
    TEXTO     font_texto    mayusculas Y minusculas, cada letra con su ancho y
                            sin contorno. Botones, fichas, avisos, la ayuda.
    NUMEROS   num_*.png     los digitos dorados de PixelNumber (dinero, precios
                            y saldos). No salen de aqui: los saca make_sprites.

Este script saca las dos primeras. Cada una son dos ficheros en Sprites/font/:
la hoja (.png) con los glifos y su descripcion BMFont (.fnt), que Godot importa
como FontFile sin plugins.

LA ESCALA
---------
Las dos dicen "size=7" en el .fnt: 7 es la altura de la mayuscula en pixeles
de arte, y Godot escala la hoja por font_size / 7. Por eso UIKit.FONT_STEP es 7
y todo tamano de letra se redondea a 7, 14, 21, 28...: asi cada pixel de arte
sale como un cuadrado entero (ver fix_import y tools/check_font_size.py).

LAS LETRAS
----------
Los patrones viven en font_patterns.py: mayusculas, digitos y signos de 5x7
(LETTERS y GLYPHS), las minusculas de 5x9 con descenso (LOWER), las mayusculas
con tilde y la enye (marked_caps) y los signos de abrir (EXTRA_SIGNS).

Cada glifo ocupa SU ancho de tinta mas un pixel de aire (la "I" es estrecha y la
"M" ancha): con todas igual de anchas los textos largos habia que encogerlos
hasta no leerse. En la de titulos las minusculas se dibujan como mayusculas,
asi que cualquier texto sale bien en cualquiera de las dos.

EL COLOR
--------
La tinta va en BLANCO y Godot la tiñe con el font_color de cada Label; el
contorno y la sombra de los titulos van en #101020, el oscuro del juego.

Uso:
    python3 tools/make_font.py            # las dos
    python3 tools/make_font.py --preview  # y una hoja de comprobacion en tools/
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from typing import Dict, List, Tuple

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from font_patterns import (GLYPHS, LETTERS, LOWER, EXTRA_SIGNS, NAME_TO_CHAR,  # noqa: E402
                           marked_caps, tall)
from sprite_paths import add_to_index, in_folder, rel_path  # noqa: E402

INK = (255, 255, 255, 255)
DARK = (16, 16, 32, 255)

## Las dos fuentes. "bold" dobla el trazo a la derecha, "outline" pinta un aro
## de 1 px alrededor de la tinta, "shadow" lo repite 1 px abajo a la derecha y
## "lower" decide si las minusculas son minusculas de verdad.
STYLES: Dict[str, Dict[str, bool]] = {
    "font_texto": {"bold": False, "outline": False, "shadow": False, "lower": True},
    "font_titulo": {"bold": True, "outline": True, "shadow": True, "lower": False},
}

## Ancho del espacio, en pixeles de arte (sin contar el aire de la letra).
SPACE_W = 3
## La linea: 1 fila de margen arriba, 7 de mayuscula, 2 de descenso y 1 de aire.
## El glifo mide 11 filas porque lleva 2 mas ENCIMA para las tildes: esas
## sobresalen 1 px por encima de la linea (yoffset negativo), que no choca con
## nada porque el descenso de la linea de arriba acaba antes.
TOP = 1
CAP_H = 7
ABOVE = 2
ROWS = ABOVE + 9
LINE_H = TOP + 9 + 1
BASE = TOP + CAP_H


def charset(lower: bool) -> Dict[str, List[str]]:
    """Caracter -> patron de 9 filas, para todos los caracteres de la fuente."""
    out: Dict[str, List[str]] = {}
    for name, p in list(GLYPHS.items()) + list(LETTERS.items()):
        ch = NAME_TO_CHAR.get(name, name)
        if ch != " ":
            out[ch] = tall(p)
    for ch, p in EXTRA_SIGNS.items():
        out[ch] = tall(p)
    for ch, p in marked_caps(LETTERS).items():
        out[ch] = p
    for ch, p in LOWER.items():
        if lower:
            out[ch] = p
        else:
            # En la de titulos la minuscula es la mayuscula (con su tilde).
            out[ch] = out[ch.upper()]
    return out


def ink_of(pattern: List[str], bold: bool) -> Tuple[set, int]:
    """Los pixeles de tinta del glifo, pegados a la izquierda, y su ancho."""
    tinta = {(x, y) for y, row in enumerate(pattern) for x, c in enumerate(row) if c == "1"}
    if bold:
        tinta |= {(x + 1, y) for (x, y) in tinta}
    if not tinta:
        return set(), 0
    x0 = min(x for x, _ in tinta)
    tinta = {(x - x0, y) for (x, y) in tinta}
    return tinta, max(x for x, _ in tinta) + 1


def build(style: Dict[str, bool]) -> Tuple[Image.Image, List[Tuple[str, int, int, int, int, int]]]:
    """Pinta la hoja (una fila por glifo, uno detras de otro) y devuelve donde
    quedo cada uno: (caracter, x, ancho de celda, alto de celda, xadvance, xoffset)."""
    glifos = charset(style["lower"])
    borde = 1 if style["outline"] else 0
    sombra = 1 if style["shadow"] else 0
    celdas = []
    for ch in sorted(glifos):
        tinta, w = ink_of(glifos[ch], style["bold"])
        celdas.append((ch, tinta, w))

    alto = ROWS + 2 * borde + sombra
    ancho_total = sum(w + 2 * borde + sombra + 1 for _, _, w in celdas)
    img = Image.new("RGBA", (ancho_total, alto), (0, 0, 0, 0))
    px = img.load()
    donde = []
    x = 0
    for ch, tinta, w in celdas:
        cw = w + 2 * borde + sombra
        pintar = {(tx + borde, ty + borde) for (tx, ty) in tinta}
        oscuro = set()
        if sombra:
            oscuro |= {(a + 1, b + 1) for (a, b) in pintar}
        if borde:
            oscuro |= {(a + dx, b + dy) for (a, b) in pintar
                       for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
        for (a, b) in oscuro - pintar:
            px[x + a, b] = DARK
        for (a, b) in pintar:
            px[x + a, b] = INK
        # El avance: la tinta y 1 px entre letra y letra (en los titulos ese px es
        # el contorno que comparten las dos).
        avance = w + 1
        donde.append((ch, x, cw, alto, avance, -borde))
        x += cw + 1
    return img, donde


def build_fnt(donde, style: Dict[str, bool], page: str) -> str:
    borde = 1 if style["outline"] else 0
    out = [f'info face="PackTycoon" size={CAP_H} bold={int(style["bold"])} italic=0 charset="" '
           f'unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
           f"common lineHeight={LINE_H} base={BASE} scaleW=0 scaleH=0 pages=1 packed=0",
           f'page id=0 file="{page}"',
           f"chars count={len(donde) + 1}",
           f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 "
           f"xadvance={SPACE_W + 1 + borde} page=0 chnl=15"]
    for ch, x, cw, ch_h, avance, xoff in donde:
        out.append(f"char id={ord(ch)} x={x} y=0 width={cw} height={ch_h} xoffset={xoff} "
                   f"yoffset={TOP - ABOVE - borde} xadvance={avance} page=0 chnl=15")
    out.append("kernings count=0")
    return "\n".join(out) + "\n"


def fix_import(ruta_fnt: str) -> bool:
    """Deja el .import de la fuente en scaling_mode=1 (solo escala entera).

    Godot escribe ese fichero al importar con escalado libre por defecto, que
    deja la letra con pixeles de dos tamanos. Se parchea el que ya escribio
    Godot porque el uid y la ruta de .godot/imported/ los pone el importador.
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


def preview(sprites: str, out: str) -> None:
    """Las dos fuentes escritas con frases del juego, a escala 4."""
    frases = ["MASCOTAS  ¡NUEVA MASCOTA!  TIRADA X5",
              "Clic en una mascota para ponerla o quitarla.",
              "Te faltan 10 monedas · Daño +75% · Búho · ¿Seguro?",
              "Árbol, Pingüino, Electrónica, Música, Créditos"]
    filas = []
    for nombre in STYLES:
        img = Image.open(os.path.join(sprites, "font", nombre + ".png")).convert("RGBA")
        with open(os.path.join(sprites, "font", nombre + ".fnt"), encoding="utf-8") as fh:
            chars = {int(m[0]): tuple(map(int, m[1:])) for m in re.findall(
                r"char id=(\d+) x=(\d+) y=\d+ width=(\d+) height=(\d+) xoffset=(-?\d+) "
                r"yoffset=-?\d+ xadvance=(\d+)", fh.read())}
        for f in frases:
            linea = Image.new("RGBA", (900, ROWS + 4), (90, 60, 40, 255))
            x = 2
            for c in f:
                cx, cw, chh, xoff, adv = chars.get(ord(c), chars[ord("?")])
                if cw:
                    g = img.crop((cx, 0, cx + cw, chh))
                    linea.alpha_composite(g, (x + xoff, 0))
                x += adv
            filas.append(linea.resize((linea.width * 4, linea.height * 4), Image.NEAREST))
    hoja = Image.new("RGBA", (filas[0].width, sum(f.height for f in filas)))
    y = 0
    for f in filas:
        hoja.alpha_composite(f, (0, y))
        y += f.height
    hoja.save(out)


def main() -> int:
    ap = argparse.ArgumentParser(description="Las fuentes de texto del juego.")
    ap.add_argument("--preview", action="store_true",
                    help="escribe tambien tools/_font_preview.png")
    args = ap.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sprites = os.path.join(root, "Sprites")
    for nombre, style in STYLES.items():
        img, donde = build(style)
        png = in_folder(sprites, nombre + ".png")
        img.save(png)
        ruta_fnt = png[:-4] + ".fnt"
        with open(ruta_fnt, "w", encoding="utf-8") as fh:
            fh.write(build_fnt(donde, style, nombre + ".png"))
        add_to_index(sprites, [rel_path(nombre + ".png")])
        if not fix_import(ruta_fnt):
            print("AVISO: aun no hay %s.import; importa con Godot (--import) y "
                  "vuelve a ejecutar esto para dejar scaling_mode=1" % (nombre + ".fnt"),
                  file=sys.stderr)
        print(f"{nombre}: {len(donde)} glifos, hoja {img.width}x{img.height}")
    if args.preview:
        out = os.path.join(root, "tools", "_font_preview.png")
        preview(sprites, out)
        print("Preview:", out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
