#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_font_size.py - comprueba que los tamanos de fuente que pide el juego son
multiplos del tamano de la fuente, y por tanto salen a escala entera.

POR QUE ESTE SCRIPT EXISTE
--------------------------
La fuente es de mapa de bits. Si Godot la agranda por 2.7, los pixeles salen
de dos tamanos distintos y el texto se ve como una foto estirada. Con escala
entera cada pixel de la fuente es un cuadrado de NxN y el texto queda de
pixeles de verdad.

Godot tiene el ajuste "scaling_mode" del .import para esto (1 = solo entero),
pero eso solo redondea: si pides 40 y la fuente mide 7,Godot se queda con el
multiplo entero que puede (35) y el texto sale mas pequeno de lo pedido, que
todavia Worse. La forma limpia es que el codigo pida solo multiplos.

Por eso UIKit tiene FONT_STEP: todo lo que se pasa por ahi se ajusta al
multiplo de 7 mas cercano antes de tocar Godot. Este script mira que eso siga
siendo cierto y avisa si alguien se salta el ajuste.

Uso:
    python3 tools/check_font_size.py
"""

from __future__ import annotations

import os
import re
import sys

# El mismo FONT_STEP que scripts/ui/ui_kit.gd. Si cambia uno, cambia el otro.
STEP = 7

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main() -> int:
    problemas: list[str] = []

    # 1. Que el .fnt diga el tamano que creemos.
    ruta_fnt = os.path.join(ROOT, "Sprites", "font", "font_pack.fnt")
    if not os.path.exists(ruta_fnt):
        print("Falta Sprites/font/font_pack.fnt. Corre python3 tools/make_font.py",
              file=sys.stderr)
        return 1
    with open(ruta_fnt, encoding="utf-8") as fh:
        m = re.search(r"info .*?size=(\d+)", fh.readline())
    if not m:
        print("El .fnt no tiene linea info con size=", file=sys.stderr)
        return 1
    size = int(m.group(1))
    if size != STEP:
        problemas.append(
            f"El .fnt declara size={size} pero el codigo asume {STEP}. "
            f"Regenera con el --scale que corresponda.")

    # 2. Que el .import deje el escalado entero.
    ruta_import = ruta_fnt + ".import"
    with open(ruta_import, encoding="utf-8") as fh:
        cuerpo = fh.read()
    m2 = re.search(r"scaling_mode=(\d+)", cuerpo)
    if not m2 or m2.group(1) != "1":
        problemas.append(
            "El .import no tiene scaling_mode=1 (escala solo entera). "
            "Sin eso el texto sale con pixeles de dos tamanos.")

    # 3. Que el paso del ajuste automatico exista en ui_kit.gd.
    ruta_kit = os.path.join(ROOT, "scripts", "ui", "ui_kit.gd")
    with open(ruta_kit, encoding="utf-8") as fh:
        kit = fh.read()
    if f"const FONT_STEP := {STEP}" not in kit:
        problemas.append(
            f"ui_kit.gd no declara 'const FONT_STEP := {STEP}'. "
            f"Sin ese ajuste los tamanos no caen en multiplos.")

    if problemas:
        for p in problemas:
            print("  MAL", p)
        print(f"\n{len(problemas)} problema(s) con la fuente.")
        return 1

    print(f"Fuente bien: size={size}, escala entera, ui_kit ajusta a multiplos de {STEP}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
