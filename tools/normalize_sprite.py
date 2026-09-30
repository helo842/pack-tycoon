#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
normalize_sprite.py - Normaliza sprites generados con IA (Gemini, etc.) para que
encajen con los del juego:

    1. quita el fondo (relleno por inundacion desde las esquinas)
    2. recorta el sobrante transparente
    3. encaja el objeto en un lienzo cuadrado centrado
    4. reescala con vecino mas cercano -> pixel duro, sin interpolacion
    5. (opcional) bloquea la paleta a los colores exactos del juego
    6. deja el alfa en dos valores, como el resto de los sprites del juego

Uso:
    python3 tools/normalize_sprite.py bajadas/*.png --out Sprites/
    python3 tools/normalize_sprite.py bajadas/*.png --out Sprites/ --size 512 --margin 0.06
    python3 tools/normalize_sprite.py sprite.png --out Sprites/ --name pack_vinyls.png
    python3 tools/normalize_sprite.py sprite.png --out Sprites/ --no-bg --lock-palette
    python3 tools/normalize_sprite.py sprite.png --out Sprites/ --grid 32
    python3 tools/normalize_sprite.py sprite.png --out Sprites/ --grid 32 --soft-alpha
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import List, Optional

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprite_paths import add_to_index, in_folder  # noqa: E402

try:  # paleta compartida con el generador procedural
    from make_sprites import PALETTE  # type: ignore
except Exception:  # pragma: no cover - la herramienta sigue siendo usable sin ella
    PALETTE = []

# Sufijos que meten las herramientas de recorte de fondos y que no queremos
# arrastrar en los nombres de archivo del proyecto.
NOISE_SUFFIXES = ("-removebg-preview", "-removebg", "_removebg_preview", "-preview")


# --------------------------------------------------------------------------- #
# Pasos del pipeline
# --------------------------------------------------------------------------- #

def remove_background(img: Image.Image, tol: int = 32) -> Image.Image:
    """Hace transparente el fondo conexo a las esquinas."""
    im = img.convert("RGBA")
    if im.split()[3].getextrema()[0] == 0:
        return im  # ya viene con alpha

    w, h = im.size
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for seed in seeds:
        if im.getpixel(seed)[3] == 0:
            continue
        ImageDraw.floodfill(im, seed, (0, 0, 0, 0), thresh=tol)
    return im


def trim(img: Image.Image) -> Image.Image:
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img


def snap_to_grid(img: Image.Image, grid: int) -> Image.Image:
    """Reduce el sprite a `grid` px de lado (rejilla de arte) con NEAREST."""
    w, h = img.size
    if w >= h:
        nw, nh = grid, max(1, round(h * grid / w))
    else:
        nh, nw = grid, max(1, round(w * grid / h))
    return img.resize((nw, nh), Image.NEAREST)


def fit_canvas(img: Image.Image, size: int, margin: float,
               integer_scale: bool = False) -> Image.Image:
    """Centra el objeto en un lienzo cuadrado `size` x `size`."""
    target = max(1, int(round(size * (1.0 - 2.0 * margin))))
    w, h = img.size
    if w < 1 or h < 1:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    factor = min(target / w, target / h)
    if integer_scale:
        factor = max(1, int(factor))

    nw = max(1, int(round(w * factor)))
    nh = max(1, int(round(h * factor)))
    scaled = img.resize((nw, nh), Image.NEAREST)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((size - nw) // 2, (size - nh) // 2))
    return canvas


def lock_palette(img: Image.Image, palette: List[tuple]) -> Image.Image:
    """Sustituye cada pixel opaco por el color de paleta mas cercano."""
    if not palette:
        return img

    cache: dict = {}
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src = img.load()
    dst = out.load()

    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            key = (r, g, b)
            hit = cache.get(key)
            if hit is None:
                best, best_d = palette[0], None
                for pr, pg, pb, _ in palette:
                    d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
                    if best_d is None or d < best_d:
                        best, best_d = (pr, pg, pb, 255), d
                hit = cache[key] = best
            dst[x, y] = (hit[0], hit[1], hit[2], a)
    return out


# --------------------------------------------------------------------------- #
# Utilidades
# --------------------------------------------------------------------------- #

def clean_stem(stem: str) -> str:
    for suffix in NOISE_SUFFIXES:
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
    return stem


def binarize_alpha(img: Image.Image, threshold: int = 128) -> Image.Image:
    """Deja el alfa en dos valores: 0 o 255.

    Una imagen de IA viene con el borde suavizado: cientos de niveles de alfa
    que son antialiasing, no pixel art. El resto del juego usa alfa binaria
    (contorno duro), asi que cualquier valor por encima del umbral pasa a opaco
    y el resto a transparente. Sin esto el sprite pegado a la mesa parece
    borroso aunque la rejilla este bien.
    """
    r, g, b, a = img.split()
    a = a.point(lambda v: 255 if v >= threshold else 0)
    return Image.merge("RGBA", (r, g, b, a))


def normalize(path: str, args: argparse.Namespace) -> Optional[Image.Image]:
    try:
        img = Image.open(path)
    except Exception as exc:
        print(f"  ! no se puede abrir {path}: {exc}", file=sys.stderr)
        return None

    img = img.convert("RGBA")
    if not args.no_bg:
        img = remove_background(img, args.tol)
    img = trim(img)

    integer_scale = False
    if args.grid:
        img = snap_to_grid(img, args.grid)
        integer_scale = True

    img = fit_canvas(img, args.size, args.margin, integer_scale)

    if args.lock_palette:
        img = lock_palette(img, PALETTE)

    if not args.soft_alpha:
        img = binarize_alpha(img, args.alpha_threshold)

    return img


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Normaliza sprites de IA al formato del juego "
                    "(fondo, recorte, encuadre, rejilla y paleta).")
    ap.add_argument("files", nargs="+", help="PNGs de entrada")
    ap.add_argument("--out", default="Sprites", help="carpeta destino (por defecto Sprites/)")
    ap.add_argument("--size", type=int, default=512, help="lado final del lienzo (por defecto 512)")
    ap.add_argument("--margin", type=float, default=0.06,
                    help="margen por lado, en fraccion del lienzo (por defecto 0.06)")
    ap.add_argument("--tol", type=int, default=32,
                    help="tolerancia del recorte de fondo 0-255 (por defecto 32)")
    ap.add_argument("--grid", type=int, default=0,
                    help="baja a esta rejilla de arte antes de escalar (p. ej. 32) "
                         "y usa factor entero -> pixeles uniformes")
    ap.add_argument("--no-bg", action="store_true", help="no tocar el fondo")
    ap.add_argument("--lock-palette", action="store_true",
                    help="forzar los colores exactos de la paleta del juego")
    ap.add_argument("--soft-alpha", action="store_true",
                    help="conservar el alfa suavizado de la IA en vez de "
                         "dejarlo binario (0/255), que es lo que usa el juego")
    ap.add_argument("--alpha-threshold", type=int, default=128,
                    help="nivel de alfa a partir del cual un pixel se opone "
                         "completamente (por defecto 128)")
    ap.add_argument("--name", default=None,
                    help="nombre de salida (solo si hay un unico archivo de entrada)")
    ap.add_argument("--dry-run", action="store_true", help="no escribir nada, solo informar")
    args = ap.parse_args()

    if args.name and len(args.files) > 1:
        ap.error("--name solo se puede usar con un unico archivo de entrada")

    if args.lock_palette and not PALETTE:
        print("aviso: no se pudo cargar la paleta, --lock-palette se ignora", file=sys.stderr)

    if not args.dry_run:
        os.makedirs(args.out, exist_ok=True)

    written = 0
    escritos: List[str] = []
    for path in args.files:
        img = normalize(path, args)
        if img is None:
            continue

        if args.name:
            out_name = args.name
        else:
            out_name = clean_stem(os.path.splitext(os.path.basename(path))[0]) + ".png"

        # La subcarpeta la decide el prefijo del nombre (loot_ -> loot/,
        # ui_icon_ -> ui/icons/...). Si el nombre no lleva un prefijo conocido
        # se avisa: el juego carga los sprites por nombre corto a traves del
        # indice, asi que un nombre sin prefijo se queda en la raiz y no lo
        # encontraria nadie.
        try:
            out_path = in_folder(args.out, out_name)
        except KeyError:
            out_path = os.path.join(args.out, out_name)
            print(f"  aviso: {out_name!r} no tiene un prefijo conocido, asi que "
                  f"no se sabe en que subcarpeta va. Ponle prefijo (loot_, "
                  f"pack_, ui_...) o no lo encontrara el juego.", file=sys.stderr)
        if not args.dry_run:
            img.save(out_path)
        print(f"  {img.width}x{img.height}  {out_path}")
        escritos.append(os.path.relpath(out_path, args.out).replace(os.sep, "/"))
        written += 1

    if not args.dry_run and escritos:
        n = add_to_index(args.out, escritos)
        print(f"  {n} sprite(s) añadidos al indice (Sprites/index.tsv)")

    print(f"\n{written} sprite(s) normalizado(s)" + (" (dry-run)" if args.dry_run else f" en {args.out}/"))


if __name__ == "__main__":
    main()
