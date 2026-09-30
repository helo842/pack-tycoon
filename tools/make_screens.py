#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_screens.py - Compone dos pantallas de ejemplo a 1920x1080 con las piezas
del kit de interfaz, para que se vea como queda todo junto: la tienda de objetos
y el menu de configuracion.

Ojo: son MAQUETAS de referencia, no assets reutilizables. El texto de las
etiquetas esta puesto con una fuente normal de sistema (es lo unico del juego que
no es pixel art todavia) y los precios si usan los numeros reales del juego.

Uso:
    python3 tools/make_screens.py
    python3 tools/make_screens.py --out Sprites
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Dict

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprite_paths import add_to_index, in_folder, read_index, rel_path  # noqa: E402

CLEAR = (252, 236, 196, 255)
INK = (16, 16, 32, 255)

DIGIT_FILES = {
    "0": "num_0", "1": "num_1", "2": "num_2", "3": "num_3", "4": "num_4",
    "5": "num_5", "6": "num_6", "7": "num_7", "8": "num_8", "9": "num_9",
    ",": "num_comma", ".": "num_period", "-": "num_minus", "+": "num_plus",
    "%": "num_percent",
}

FONT_CANDIDATES = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
)


# Indice nombre corto -> ruta. Lo escribe make_sprites.py al generar; asi esta
# herramienta no necesita saber en que subcarpeta vive cada sprite.
_INDEX: Dict[str, str] = {}


def load(sprite_dir: str, name: str) -> Image.Image:
    """Abre un sprite por su nombre corto, con la ruta que diga el indice."""
    rel = _INDEX.get(name)
    if rel is None:
        # Sin indice (o con un nombre que no esta): se prueba en la raiz, que es
        # como estaban los sprites antes de separarlos en carpetas.
        rel = name + ".png"
    path = os.path.join(sprite_dir, rel)
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"falta el sprite {name!r} (se buscaria en {path}).\n"
            f"  Si es un sprite del juego, comprueba el nombre en "
            f"Sprites/index.tsv: puede que se llamara de otra forma.\n"
            f"  Si es nuevo, generar con: python3 tools/make_sprites.py --all")
    return Image.open(path).convert("RGBA")


def halve(img: Image.Image) -> Image.Image:
    """Reduce a la mitad con NEAREST: es exacto, asi que los pixeles siguen limpios."""
    return img.resize((img.width // 2, img.height // 2), Image.NEAREST)


def get_font(size: int) -> ImageFont.ImageFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def render_number(sprite_dir: str, text: str, half: bool = False) -> Image.Image:
    """Monta un numero con los sprites reales del juego."""
    glyphs = [load(sprite_dir, DIGIT_FILES[ch]) for ch in text if ch in DIGIT_FILES]
    if half:
        glyphs = [halve(g) for g in glyphs]
    out = Image.new("RGBA", (sum(g.width for g in glyphs), glyphs[0].height), (0, 0, 0, 0))
    x = 0
    for g in glyphs:
        out.alpha_composite(g, (x, 0))
        x += g.width
    return out


def paste(base: Image.Image, img: Image.Image, x: int, y: int, anchor_center: bool = False) -> None:
    if anchor_center:
        x -= img.width // 2
        y -= img.height // 2
    base.alpha_composite(img, (x, y))


def label(d: ImageDraw.ImageDraw, x: int, y: int, text: str, size: int = 40,
          fill=CLEAR, center: bool = False) -> None:
    d.text((x, y), text, font=get_font(size), fill=fill,
           anchor="mm" if center else "lm", stroke_width=3, stroke_fill=INK)


# --------------------------------------------------------------------------- #
# Pantalla de inicio
# --------------------------------------------------------------------------- #

def build_start(sprite_dir: str, bg: Image.Image) -> Image.Image:
    shot = bg.copy()
    d = ImageDraw.Draw(shot)
    label(d, 960, 250, "PACK TYCOON", 110, center=True)

    plate = load(sprite_dir, "ui_button_plate")
    x = (1920 - plate.width) // 2
    for i, (icon, text) in enumerate((("ui_icon_play", "PLAY"),
                                      ("ui_icon_settings", "SETTINGS"))):
        y = 470 + i * 290
        paste(shot, plate, x, y)
        paste(shot, load(sprite_dir, icon), x, y)
        label(d, x + 300, y + plate.height // 2, text, 46)
    return shot


# --------------------------------------------------------------------------- #
# Tienda
# --------------------------------------------------------------------------- #

def build_shop(sprite_dir: str, bg: Image.Image) -> Image.Image:
    shot = bg.copy()
    # Los nombres van con la nota porque los sprites sueltos (loot_vinyl.png)
    # ya no existen: ahora hay diez por objeto, y en una tienda tiene sentido
    # enseñar piezas de nota distinta para que se vea el desgaste de un vistazo.
    pump_items = ["loot_vinyl_psa8", "loot_sneaker_psa6", "loot_console_psa7",
                  "loot_card_foil_psa9", "loot_headphones_psa5",
                  "loot_watch_psa4", "loot_camera_psa3",
                  "loot_card_vintage_psa6"]
    prices = ["450", "1,200", "3,400", "9,999", "780", "2,150", "5,600", "14,000"]

    paste(shot, load(sprite_dir, "ui_panel_shop"), 160, 60)
    d = ImageDraw.Draw(shot)
    label(d, 960, 128, "SHOP", 76, center=True)

    # franja superior: dinero, boton de mejora y cerrar
    paste(shot, render_number(sprite_dir, "12,450"), 320, 196)
    paste(shot, load(sprite_dir, "ui_button_small"), 800, 190)
    paste(shot, halve(load(sprite_dir, "ui_icon_plus")), 818, 198)
    label(d, 950, 262, "UPGRADE", 34)
    paste(shot, halve(load(sprite_dir, "ui_button_close")), 1480, 186)

    slot = load(sprite_dir, "ui_slot")
    # banda oscura tras el precio: si no, no se lee sobre el objeto
    band = Image.new("RGBA", (224, 44), (18, 10, 8, 205))
    xs = [424, 696, 968, 1240]
    ys = [350, 630]
    i = 0
    for y in ys:
        for x in xs:
            paste(shot, slot, x, y)
            # objeto dentro de la ranura, a la mitad (mitad de 512 = 256, exacto)
            paste(shot, halve(load(sprite_dir, pump_items[i])), x + 12, y - 4)
            paste(shot, band, x + 16, y + 198)
            price = render_number(sprite_dir, prices[i], half=True)
            paste(shot, price, x + (256 - price.width) // 2, y + 199)
            i += 1

    return shot


# --------------------------------------------------------------------------- #
# Configuracion
# --------------------------------------------------------------------------- #

def build_settings(sprite_dir: str, bg: Image.Image) -> Image.Image:
    shot = bg.copy()
    d = ImageDraw.Draw(shot)

    paste(shot, load(sprite_dir, "ui_panel_settings"), 160, 60)
    d = ImageDraw.Draw(shot)
    label(d, 960, 128, "SETTINGS", 76, center=True)
    paste(shot, halve(load(sprite_dir, "ui_button_close")), 1480, 186)

    track = load(sprite_dir, "ui_slider_track")
    knob = load(sprite_dir, "ui_slider_knob")
    y = 240
    for icon, text, value in (("ui_icon_music", "MUSIC", 0.7),
                              ("ui_icon_sound", "SOUND EFFECTS", 0.45)):
        paste(shot, halve(load(sprite_dir, icon)), 320, y - 30)
        label(d, 480, y + 40, text, 42)
        paste(shot, track, 900, y + 30)
        paste(shot, knob, 900 + int((track.width - knob.width) * value), y - 18)
        y += 165

    paste(shot, load(sprite_dir, "ui_checkbox_on"), 900, y + 15)
    label(d, 480, y + 90, "FULLSCREEN", 42)
    y += 165

    paste(shot, halve(load(sprite_dir, "ui_arrow_left")), 860, y + 20)
    paste(shot, halve(load(sprite_dir, "ui_arrow_right")), 1180, y + 20)
    label(d, 480, y + 90, "LANGUAGE", 42)
    label(d, 1060, y + 88, "ENGLISH", 40, center=True)
    return shot


# --------------------------------------------------------------------------- #

def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser(description="Compone las pantallas de ejemplo del juego.")
    ap.add_argument("--out", default=os.path.join(root, "Sprites"), help="carpeta de los sprites")
    ap.add_argument("--size", default="1920x1080", help="resolucion de salida (por defecto 1920x1080)")
    args = ap.parse_args()

    sprite_dir = os.path.abspath(args.out)
    w, h = (int(v) for v in args.size.lower().split("x"))
    _INDEX.update(read_index(sprite_dir))
    if not _INDEX:
        print("aviso: no hay indice en Sprites/index.tsv; se buscara en la raiz. "
              "Corre python3 tools/make_sprites.py --all", file=sys.stderr)
    bg = load(sprite_dir, "bg_menu_backroom").resize((w, h), Image.NEAREST)

    for name, builder in (("shot_start", build_start),
                          ("shot_shop", build_shop),
                          ("shot_settings", build_settings)):
        img = builder(sprite_dir, bg)
        # Las maquetas van a Sprites/mockups/, decided por el prefijo shot_.
        path = in_folder(sprite_dir, name + ".png")
        img.convert("RGB").save(path)
        add_to_index(sprite_dir, [rel_path(name + ".png")])
        print(f"  {img.width}x{img.height}  {os.path.relpath(path, root)}")


if __name__ == "__main__":
    main()
