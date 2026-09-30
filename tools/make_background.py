#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_background.py - Genera los dos fondos del juego:

  - la trastienda del menu (bg_menu_backroom), con estanterias de cajas, vinilos
y sobres a los dos lados y una lampara calida en el centro. El centro queda
despejado a proposito, para el titulo y los botones.

  - la superficie de la mesa de la partida (bg_table), que es donde caen los
objetos y por donde se arrastran.

Los dos se dibujan a baja resolucion y se escalan con vecino mas cercano, asi
que heredan el mismo aspecto de pixel duro que los sprites. La trastienda va a
1/6 (320x180 x6) porque es un escenario y necesita detalle; la mesa va a 1/8
(228x94 x8), que es lo que mide un pixel de arte de los objetos que se ponen
encima, para que mesa y objeto tengan el mismo grano.

Uso:
    python3 tools/make_background.py
    python3 tools/make_background.py --scale 4
    python3 tools/make_background.py --seed 7 --name bg_menu_backroom.png
    python3 tools/make_background.py --table
"""

from __future__ import annotations

import argparse
import math
import os
import random
import sys
from typing import Tuple

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sprites import (  # noqa: E402  (paleta compartida con los sprites)
    BROWN, BROWN_D, BROWN_L, GOLD, GOLD_D, GOLD_HI, GOLD_L, GOLD_XL,
    OUTLINE, TEAL,
)
from sprite_paths import add_to_index, in_folder, rel_path  # noqa: E402

RGB = Tuple[int, int, int]

BASE_W, BASE_H = 320, 180
SCALE = 6

# La mesa. 228x94 x8 son 1824x752, que es exactamente el rectangulo de la mesa
# del juego (game.gd, TABLE_RECT): si cambia alli, se cambia aqui.
TABLE_W, TABLE_H = 228, 94
TABLE_SCALE = 8

TABLE_TOP: RGB = (122, 74, 44)      # madera de la superficie, bajo la luz
TABLE_BOT: RGB = (84, 48, 28)       # hacia el frente, que queda en sombra
TABLE_SEAM: RGB = (52, 29, 17)      # junta entre tablones
TABLE_RIM: RGB = (44, 25, 15)       # canto de la mesa
TABLE_HI: RGB = (168, 104, 60)      # luz del canto de arriba

WALL_TOP: RGB = (78, 48, 36)
WALL_BOT: RGB = (40, 24, 22)
PLANK_SEAM: RGB = (26, 16, 15)
FLOOR_TOP: RGB = (66, 40, 28)
FLOOR_BOT: RGB = (32, 19, 15)
LAMP_GLOW: RGB = (255, 198, 112)
SHELF_WOOD: RGB = (74, 46, 34)

FLOOR_Y = 148
SHELF_TOPS = (22, 54, 86, 118)
UNITS = ((0, 86), (234, 320))


# --------------------------------------------------------------------------- #
# Utilidades de color
# --------------------------------------------------------------------------- #

def clamp(v: float) -> int:
    return max(0, min(255, int(round(v))))


def mix(c1, c2, t: float) -> RGB:
    t = max(0.0, min(1.0, t))
    return tuple(clamp(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))  # type: ignore


def lighten(c: RGB, t: float) -> RGB:
    return mix(c, (255, 255, 255), t)


def darken(c: RGB, t: float) -> RGB:
    return mix(c, (0, 0, 0), t)


# --------------------------------------------------------------------------- #
# Objetos de las baldas (se dibujan apoyados en `bottom`)
# --------------------------------------------------------------------------- #

def item_box(d: ImageDraw.ImageDraw, x: int, bottom: int, w: int, h: int,
             body: RGB, tape: bool = True) -> None:
    top = bottom - h
    d.rectangle([x, top, x + w - 1, bottom - 1], fill=body)
    d.rectangle([x, top, x + w - 1, top + 1], fill=lighten(body, 0.25))
    d.rectangle([x, top, x, bottom - 1], fill=lighten(body, 0.12))
    d.rectangle([x + w - 1, top, x + w - 1, bottom - 1], fill=darken(body, 0.3))
    d.rectangle([x, bottom - 2, x + w - 1, bottom - 1], fill=darken(body, 0.35))
    if tape and w > 13:
        cx = x + w // 2
        d.rectangle([cx - 1, top, cx, bottom - 1], fill=GOLD_D)
        d.rectangle([cx - 1, top, cx - 1, bottom - 1], fill=GOLD)


def item_vinyl(d: ImageDraw.ImageDraw, x: int, bottom: int, h: int) -> None:
    w = h
    d.rectangle([x + 2, bottom - h, x + w - 2, bottom - 1], fill=(38, 34, 52))
    d.rectangle([x + 2, bottom - h, x + w - 2, bottom - h], fill=(60, 54, 78))
    d.ellipse([x + 4, bottom - h + 3, x + w - 4, bottom - 3], fill=(26, 22, 38))
    k = w // 2
    d.ellipse([x + k - 3, bottom - h // 2 - 3, x + k + 1, bottom - h // 2 + 1], fill=GOLD_D)
    d.ellipse([x + k - 2, bottom - h // 2 - 2, x + k, bottom - h // 2], fill=GOLD_XL)


def item_pack(d: ImageDraw.ImageDraw, x: int, bottom: int, w: int, h: int) -> None:
    top = bottom - h
    d.rectangle([x, top, x + w - 1, bottom - 1], fill=BROWN)
    d.rectangle([x, top, x + w - 1, top], fill=BROWN_L)
    d.rectangle([x + 2, top + 2, x + w - 3, bottom - 3], fill=(52, 30, 24))
    d.rectangle([x + 2, top + 2, x + w - 3, top + 2], fill=(92, 54, 36))
    d.point((x + w // 2, top + 3), fill=TEAL)
    d.point((x + w // 2, bottom - h // 2), fill=GOLD_XL)


def item_coins(d: ImageDraw.ImageDraw, x: int, bottom: int, n: int) -> None:
    for i in range(n):
        y = bottom - 2 - i * 2
        d.ellipse([x, y - 1, x + 8, y + 1], fill=GOLD_D)
        d.ellipse([x, y - 2, x + 8, y], fill=GOLD_XL)
        d.point((x + 3, y - 1), fill=GOLD_HI)


def item_piggy(d: ImageDraw.ImageDraw, x: int, bottom: int) -> None:
    d.ellipse([x, bottom - 9, x + 15, bottom - 1], fill=GOLD_D)
    d.ellipse([x + 1, bottom - 9, x + 14, bottom - 2], fill=GOLD_XL)
    d.ellipse([x + 2, bottom - 8, x + 10, bottom - 4], fill=GOLD_HI)
    d.rectangle([x + 1, bottom - 5, x + 3, bottom - 3], fill=GOLD_D)
    d.point((x + 7, bottom - 6), fill=OUTLINE)
    d.ellipse([x + 6, bottom - 12, x + 10, bottom - 8], fill=GOLD_XL)
    d.point((x + 7, bottom - 11), fill=GOLD_HI)


def fill_shelf(d: ImageDraw.ImageDraw, x0: int, x1: int, bottom: int,
               rng: random.Random) -> None:
    """Coloca objetos a lo largo de una balda hasta llenarla."""
    x = x0
    while x < x1 - 9:
        kind = rng.choices(
            ["box", "box", "box", "vinyl", "pack", "coins", "piggy"],
            weights=[5, 5, 5, 2, 3, 2, 1],
        )[0]

        if kind == "box":
            w = rng.randint(13, 21)
            h = rng.randint(15, 27)
            body = rng.choice([(122, 74, 44), (98, 58, 36), (140, 88, 50), (84, 50, 32)])
            item_box(d, x, bottom, w, h, body)
            x += w + rng.randint(1, 4)
        elif kind == "vinyl":
            h = rng.randint(17, 24)
            item_vinyl(d, x, bottom, h)
            x += h + rng.randint(1, 3)
        elif kind == "pack":
            w = rng.randint(10, 14)
            h = rng.randint(15, 18)
            item_pack(d, x, bottom, w, h)
            x += w + rng.randint(1, 4)
        elif kind == "coins":
            n = rng.randint(3, 7)
            item_coins(d, x, bottom, n)
            x += 11 + rng.randint(1, 4)
        else:
            item_piggy(d, x, bottom)
            x += 18 + rng.randint(2, 5)


# --------------------------------------------------------------------------- #
# Estructura
# --------------------------------------------------------------------------- #

def draw_shelf_unit(d: ImageDraw.ImageDraw, x0: int, x1: int,
                    rng: random.Random) -> None:
    # montantes laterales
    d.rectangle([x0, 0, x0 + 4, FLOOR_Y], fill=SHELF_WOOD)
    d.rectangle([x1 - 5, 0, x1 - 1, FLOOR_Y], fill=SHELF_WOOD)
    d.rectangle([x0, 0, x0 + 1, FLOOR_Y], fill=lighten(SHELF_WOOD, 0.22))
    d.rectangle([x1 - 5, 0, x1 - 4, FLOOR_Y], fill=lighten(SHELF_WOOD, 0.22))
    d.rectangle([x0 + 2, 0, x0 + 2, FLOOR_Y], fill=darken(SHELF_WOOD, 0.35))
    d.rectangle([x1 - 3, 0, x1 - 3, FLOOR_Y], fill=darken(SHELF_WOOD, 0.35))

    for top in SHELF_TOPS:
        fill_shelf(d, x0 + 6, x1 - 6, top, rng)
        # balda
        d.rectangle([x0, top, x1 - 1, top + 3], fill=SHELF_WOOD)
        d.rectangle([x0, top, x1 - 1, top], fill=lighten(SHELF_WOOD, 0.3))
        d.rectangle([x0, top + 3, x1 - 1, top + 3], fill=darken(SHELF_WOOD, 0.4))
        d.rectangle([x0, top + 4, x1 - 1, top + 5], fill=(30, 18, 15))


def draw_lamp(d: ImageDraw.ImageDraw, cx: int) -> None:
    d.rectangle([cx, 0, cx + 1, 5], fill=(26, 18, 16))
    d.polygon([(cx - 12, 5), (cx + 13, 5), (cx + 9, 15), (cx - 8, 15)],
              fill=(54, 34, 28))
    d.polygon([(cx - 12, 5), (cx + 13, 5), (cx + 12, 7), (cx - 11, 7)],
              fill=(88, 58, 44))
    d.rectangle([cx - 8, 15, cx + 9, 16], fill=GOLD_D)
    d.rectangle([cx - 6, 17, cx + 7, 18], fill=(255, 226, 155))
    d.rectangle([cx - 4, 19, cx + 5, 19], fill=(255, 240, 195))


# --------------------------------------------------------------------------- #
# Composición
# --------------------------------------------------------------------------- #

def build(seed: int, scale: int) -> Image.Image:
    """Dibuja la trastienda en BASE_W x BASE_H y la escala con NEAREST."""
    rng = random.Random(seed)
    w, h = BASE_W, BASE_H

    img = Image.new("RGB", (w, h), (0, 0, 0))
    px = img.load()

    lamp_x, lamp_y = w // 2, 28

    # 1. muro con tablones y halo de lampara
    for y in range(h):
        t = y / (h - 1)
        base = mix(WALL_TOP, WALL_BOT, t)
        for x in range(w):
            c = base
            if y < FLOOR_Y and x % 27 == 0:
                c = mix(c, PLANK_SEAM, 0.45)
            dist = math.hypot((x - lamp_x) * 0.8, (y - lamp_y) * 1.15)
            glow = max(0.0, 1.0 - dist / 150.0) ** 2
            px[x, y] = mix(c, LAMP_GLOW, glow * 0.5)

    # 2. suelo de tablones
    for y in range(FLOOR_Y, h):
        t = (y - FLOOR_Y) / max(1, h - FLOOR_Y)
        base = mix(FLOOR_TOP, FLOOR_BOT, t)
        for x in range(w):
            c = base
            if (y + (x // 40) * 3) % 9 == 0:
                c = mix(c, (22, 13, 11), 0.5)
            px[x, y] = c

    d = ImageDraw.Draw(img)

    # 3. lampara
    draw_lamp(d, lamp_x)

    # 4. estanterias laterales
    for ux0, ux1 in UNITS:
        draw_shelf_unit(d, ux0, ux1, rng)

    # 5. vinneta: oscurece las esquinas para que el centro respire
    cx, cy = w / 2, h / 2
    for y in range(h):
        for x in range(w):
            dist = math.hypot((x - cx) / (w / 2), (y - cy) / (h / 2))
            f = 1.0 - min(1.0, max(0.0, (dist - 0.55) / 0.8)) * 0.62
            r, g, b = px[x, y]
            px[x, y] = (clamp(r * f), clamp(g * f), clamp(b * f))

    # 6. polvo flotando en la luz
    for _ in range(90):
        x = rng.randint(int(w * 0.28), int(w * 0.72))
        y = rng.randint(int(h * 0.12), int(h * 0.85))
        r, g, b = px[x, y]
        px[x, y] = mix((r, g, b), (255, 228, 165), rng.uniform(0.15, 0.6))

    return img.resize((w * scale, h * scale), Image.NEAREST)


def build_table(seed: int, scale: int) -> Image.Image:
    """Dibuja la superficie de la mesa en TABLE_W x TABLE_H y la escala."""
    rng = random.Random(seed)
    w, h = TABLE_W, TABLE_H

    img = Image.new("RGB", (w, h), (0, 0, 0))
    px = img.load()

    # 1. superficie: tablones horizontales que se apagan hacia el frente
    for y in range(h):
        t = y / (h - 1)
        base = mix(TABLE_TOP, TABLE_BOT, t ** 1.2)
        for x in range(w):
            c = base
            # racha de veta suelta. La formula es fija (no aleatoria) para que
            # el dibujo no dependa del orden en que se recorra la imagen.
            if (x * 7 + y * 3) % 31 == 0:
                c = mix(c, TABLE_SEAM, 0.20)
            px[x, y] = c

    d = ImageDraw.Draw(img)

    # 2. juntas de los tablones
    for y in range(18, h - 8, 18):
        d.rectangle([4, y, w - 5, y], fill=TABLE_SEAM)
        d.rectangle([4, y + 1, w - 5, y + 1], fill=lighten(TABLE_BOT, 0.12))

    # 3. veta larga: rayas cortas en el sentido de la madera. Van encima de las
    # juntas para que la superficie no se lea como una cuadricula.
    for _ in range(90):
        x = rng.randint(6, w - 8)
        y = rng.randint(3, h - 8)
        n = rng.randint(4, 13)
        col = mix(TABLE_SEAM, TABLE_TOP, rng.uniform(0.25, 0.6))
        d.rectangle([x, y, min(x + n, w - 8), y], fill=col)

    # 4. canto: marco oscuro, luz arriba (la lampara esta arriba) y sombra
    # abajo, que es lo que dice "esta mesa es un tablero con grosor"
    d.rectangle([0, 0, w - 1, h - 1], outline=TABLE_RIM)
    d.rectangle([0, 0, w - 1, 1], fill=TABLE_HI)
    d.rectangle([0, h - 4, w - 1, h - 1], fill=darken(TABLE_RIM, 0.3))
    d.rectangle([0, 0, 2, h - 1], fill=mix(TABLE_RIM, TABLE_HI, 0.2))
    d.rectangle([w - 3, 0, w - 1, h - 1], fill=darken(TABLE_RIM, 0.2))

    # 5. vineta: el centro algo mas claro y las esquinas apagadas. Es lo que hace
    # que un objeto blanco no se funda con la madera del rincon.
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    for y in range(h):
        for x in range(w):
            dist = math.hypot((x - cx) / (w / 2.0), (y - cy) / (h / 2.0))
            f = 1.0 - min(1.0, max(0.0, (dist - 0.35) / 0.9)) * 0.38
            r, g, b = px[x, y]
            px[x, y] = (clamp(r * f), clamp(g * f), clamp(b * f))

    return img.resize((w * scale, h * scale), Image.NEAREST)


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    default_out = os.path.join(root, "Sprites")

    ap = argparse.ArgumentParser(description="Genera el fondo de la pantalla de inicio.")
    ap.add_argument("--out", default=default_out, help="carpeta destino (por defecto Sprites/)")
    ap.add_argument("--name", default="bg_menu_backroom.png", help="nombre del archivo de salida")
    ap.add_argument("--scale", type=int, default=SCALE,
                    help=f"factor de escalado entero (por defecto {SCALE}). "
                         f"Sobre {BASE_W}x{BASE_H}: 4 -> 1280x720, 6 -> 1920x1080")
    ap.add_argument("--seed", type=int, default=20260925,
                    help="semilla del desorden de las baldas (cambiala para otra variante)")
    ap.add_argument("--table", action="store_true",
                    help="en vez del fondo, la superficie de la mesa: escribe "
                         "bg_table.png (1824x752, el rectangulo de la mesa del juego)")
    ap.add_argument("--table-scale", type=int, default=TABLE_SCALE,
                    help=f"factor de escalado de la mesa (por defecto {TABLE_SCALE} "
                         f"-> 1824x752)")
    args = ap.parse_args()

    if args.table:
        img = build_table(args.seed, args.table_scale)
        args.name = "bg_table.png"
    else:
        img = build(args.seed, args.scale)

    os.makedirs(args.out, exist_ok=True)
    # La subcarpeta la decide el prefijo del nombre (bg_ -> backgrounds/), igual
    # que el generador de sprites. Ver tools/sprite_paths.py.
    path = in_folder(args.out, args.name)
    img.save(path)
    # Se apunta en el indice como cualquier otro sprite. Sin esto el juego no
    # lo encontraria por su nombre corto, porque el indice lo escribe quien
    # genera y aqui no es make_sprites.py.
    add_to_index(args.out, [rel_path(args.name)])
    print(f"  {img.width}x{img.height}  {os.path.relpath(path, root)}")


if __name__ == "__main__":
    main()
