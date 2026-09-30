#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_sprites.py - Generador procedural de sprites pixel-art.

Estilo objetivo (Sprites/*.png de Gemini + Idea.pdf):
  - rejilla base pequena (~32px) escalada con NEAREST -> pixel duro y grande
  - contorno oscuro de 1px de rejilla
  - paleta dorada/calida dominante + turquesa reservada a gemas y detalles
  - fondo transparente, objeto centrado y aislado

Uso:
    python3 tools/make_sprites.py --all
    python3 tools/make_sprites.py --list
    python3 tools/make_sprites.py --only vinyl sneaker camera
    python3 tools/make_sprites.py --only card --rarity rare legendary
    python3 tools/make_sprites.py --all --preview
"""

from __future__ import annotations

import argparse
import math
import os
import random
import sys
from dataclasses import dataclass
from functools import partial
from typing import Callable, Dict, List, Optional, Sequence, Tuple

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from font_patterns import DOLLAR_S, FONT_ORDER, GLYPH_H, GLYPH_W, GLYPHS  # noqa: E402
from sprite_paths import folder_for, read_index  # noqa: E402

RGBA = Tuple[int, int, int, int]

# --------------------------------------------------------------------------- #
# Configuracion global
# --------------------------------------------------------------------------- #

BASE = 32          # lado de la rejilla de dibujo (en "pixeles de arte")
SCALE = 16         # factor de escalado NEAREST -> 512x512

# --------------------------------------------------------------------------- #
# Paleta (muestreada de Sprites/*.png para mantener coherencia entre sprites)
# --------------------------------------------------------------------------- #

OUTLINE    = (16, 16, 32, 255)     # #101020  contorno
DARK       = (24, 20, 36, 255)
DARK_SOFT  = (48, 40, 60, 255)
BROWN_D    = (64, 32, 24, 255)
BROWN      = (128, 72, 40, 255)    # #804828
BROWN_L    = (168, 96, 48, 255)
GOLD_D     = (168, 72, 8, 255)     # #A84808
GOLD       = (232, 128, 0, 255)    # #E88000
GOLD_L     = (248, 152, 16, 255)   # #F89810
GOLD_XL    = (248, 192, 0, 255)    # #F8C000
GOLD_HI    = (255, 216, 88, 255)   # #F8D040
CREAM      = (252, 236, 196, 255)
CREAM_D    = (212, 184, 136, 255)
TEAL       = (56, 104, 168, 255)   # #3868A8
TEAL_D     = (36, 64, 108, 255)
TEAL_L     = (88, 208, 196, 255)
WHITE      = (244, 244, 248, 255)
STEEL      = (188, 196, 208, 255)
STEEL_D    = (140, 148, 164, 255)
STEEL_DD   = (96, 104, 120, 255)
LCD        = (110, 200, 140, 255)

# Verdes y rojos: solo para las insignias de estado de conservacion (condition_*).
# La paleta no los tenia y hacen falta para "buen estado" en verde y "roto" en
# rojo. No son un cuerpo grande sino insignias de 16x16, asi que no rompen la
# regla de no meter colores frios en masas.
GREEN_D   = (30, 92, 46, 255)      # #1E5C2E
GREEN     = (46, 140, 70, 255)     # #2E8C46
GREEN_L   = (86, 196, 106, 255)    # #56C46A
RED_D     = (110, 26, 24, 255)     # #6E1A18
RED       = (168, 42, 34, 255)     # #A82A22
RED_L     = (210, 80, 60, 255)     # #D2503C

# Marrones muy oscuros: huecos de ranura, interior de casilla y canaleta del
# deslizador. Antes eran literales sueltos en el codigo; el auditor los senalaba
# como colores fuera de la paleta, asi que ahora son tokens como los demas.
WOOD_DD   = (20, 12, 10, 255)      # #140C0A  el hueco mas profundo
WOOD_D    = (30, 18, 15, 255)      # #1E120F  interior de casilla y mando
WOOD_M    = (38, 22, 18, 255)      # #261612  interior de la ranura de objeto
WOOD_L    = (44, 26, 21, 255)      # #2C1A15  canaleta del deslizador

# Tonos sueltos que tambien estaban en el codigo sin token.
VINYL_SHEEN = (92, 88, 116, 255)   # #5C5874  brillo del vinilo
SLATE     = (72, 64, 84, 255)      # #484054  tapa de la camara
LCD_D     = (32, 72, 56, 255)      # #204838  marco de la pantalla
LCD_L     = (72, 168, 112, 255)    # #48A870  zonas vivas de la pantalla
RUST_D    = (132, 52, 36, 255)     # #843424  cuerpo del boton de cerrar
RUST_L    = (182, 80, 54, 255)     # #B65036  brillo del boton de cerrar
CRACK_D   = (20, 6, 6, 255)        # #140606  grieta de un objeto roto

# Materiales de los paquetes y los casi negros de la tarjeta de revelado. El
# auditor los exigio como tokens: estaban escritos a pelo en el codigo y la
# paleta es la fuente de verdad.
CARD      = (92, 60, 40, 255)      # #5C3C28  carton de la funda de vinilo
CARD_L    = (140, 96, 64, 255)     # #8C6040  carton iluminado
SHOE_D    = (150, 96, 60, 255)     # #96603C  sombra bajo la tapa de la caja
TISSUE    = (222, 222, 232, 255)   # #DEDEE8  papel de seda
PLASTIC   = (46, 40, 58, 255)      # #2E283A  interior del plastico
CRINKLE   = (170, 146, 106, 255)   # #AA926A  pliegue del envoltorio
CRINKLE_L = (190, 168, 128, 255)   # #BEA880  brillo del pliegue
SHADOW    = (12, 8, 16, 255)       # #0C0810  sombra proyectada
NIGHT_DD  = (12, 9, 20, 255)       # #0C0914
NIGHT_D   = (16, 13, 26, 255)      # #100D1A
NIGHT     = (22, 18, 32, 255)      # #161220
NIGHT_L   = (30, 25, 44, 255)      # #1E192C
NIGHT_LL  = (36, 30, 50, 255)      # #241E32
SHINE     = (255, 232, 176, 255)   # #FFE8B0  halo del destello
SHINE_HI  = (255, 240, 200, 255)   # #FFF0C8  rayos del destello
CREAM_L   = (250, 232, 190, 255)   # #FAE8BE  interior de la chapita de precio
STAR_OFF  = (58, 46, 40, 255)      # #3A2E28  estrella vacia
STAR_OFF_D = (34, 26, 24, 255)     # #221A18  contorno de la estrella vacia
STAR_OFF_L = (86, 68, 58, 255)     # #56443A  especular de la estrella vacia

TRANSPARENT: RGBA = (0, 0, 0, 0)

# Lista plana de la paleta, para herramientas que la necesiten
# (ver tools/normalize_sprite.py, opcion --lock-palette).
PALETTE: List[RGBA] = [
    OUTLINE, DARK, DARK_SOFT,
    BROWN_D, BROWN, BROWN_L,
    GOLD_D, GOLD, GOLD_L, GOLD_XL, GOLD_HI,
    CREAM, CREAM_D,
    TEAL, TEAL_D, TEAL_L, LCD, LCD_D, LCD_L,
    WHITE, STEEL, STEEL_D, STEEL_DD, SLATE,
    GREEN_D, GREEN, GREEN_L, RED_D, RED, RED_L,
    WOOD_DD, WOOD_D, WOOD_M, WOOD_L,
    VINYL_SHEEN, RUST_D, RUST_L, CRACK_D,
    CARD, CARD_L, SHOE_D, TISSUE, PLASTIC, CRINKLE, CRINKLE_L, SHADOW,
    NIGHT_DD, NIGHT_D, NIGHT, NIGHT_L, NIGHT_LL,
    SHINE, SHINE_HI, CREAM_L, STAR_OFF, STAR_OFF_D, STAR_OFF_L,
]


# --------------------------------------------------------------------------- #
# Raridades (Comun / Raro / Epico / Legendario)
# --------------------------------------------------------------------------- #

@dataclass(frozen=True)
class Rarity:
    name: str
    dark: RGBA
    base: RGBA
    light: RGBA
    glow: RGBA


RARITIES: Dict[str, Rarity] = {
    "common": Rarity(
        "common",
        dark=(92, 98, 108, 255),
        base=(154, 160, 170, 255),
        light=(206, 212, 218, 255),
        glow=(186, 192, 200, 255),
    ),
    "rare": Rarity(
        "rare",
        dark=(32, 84, 148, 255),
        base=(64, 132, 200, 255),
        light=(122, 186, 238, 255),
        glow=(96, 168, 232, 255),
    ),
    "epic": Rarity(
        "epic",
        dark=(88, 44, 140, 255),
        base=(140, 82, 200, 255),
        light=(188, 134, 238, 255),
        glow=(170, 116, 232, 255),
    ),
    "legendary": Rarity(
        "legendary",
        dark=(176, 112, 0, 255),
        base=GOLD_XL,
        light=GOLD_HI,
        glow=(255, 200, 48, 255),
    ),
}

RARITY_ORDER: List[str] = ["common", "rare", "epic", "legendary"]


# --------------------------------------------------------------------------- #
# Lienzo de pixel-art
# --------------------------------------------------------------------------- #

class Sprite:
    """Lienzo de rejilla. Se dibuja a 1px de arte y se escala despues.

    Por defecto cuadrado (BASE x BASE); los botones lo necesitan rectangular.
    """

    def __init__(self, w: int = BASE, h: Optional[int] = None) -> None:
        self.w = w
        self.h = h if h is not None else w
        self.img = Image.new("RGBA", (self.w, self.h), TRANSPARENT)
        self.d = ImageDraw.Draw(self.img)
        self.want_outline = True

    # -- primitivas -------------------------------------------------------- #
    def rect(self, x0: int, y0: int, x1: int, y1: int, fill: RGBA) -> None:
        self.d.rectangle([x0, y0, x1, y1], fill=fill)

    def ellipse(self, x0: int, y0: int, x1: int, y1: int, fill: RGBA) -> None:
        self.d.ellipse([x0, y0, x1, y1], fill=fill)

    def ring(self, x0: int, y0: int, x1: int, y1: int, fill: RGBA, width: int = 1) -> None:
        self.d.ellipse([x0, y0, x1, y1], outline=fill, width=width)

    def arc(self, x0: int, y0: int, x1: int, y1: int, start: float, end: float,
            fill: RGBA, width: int = 1) -> None:
        self.d.arc([x0, y0, x1, y1], start, end, fill=fill, width=width)

    def pie(self, x0: int, y0: int, x1: int, y1: int, start: float, end: float,
            fill: RGBA) -> None:
        self.d.pieslice([x0, y0, x1, y1], start, end, fill=fill)

    def poly(self, points: Sequence[Tuple[int, int]], fill: RGBA) -> None:
        self.d.polygon(list(points), fill=fill)

    def line(self, points: Sequence[Tuple[int, int]], fill: RGBA, width: int = 1) -> None:
        self.d.line(list(points), fill=fill, width=width)

    def px(self, x: int, y: int, fill: RGBA) -> None:
        self.d.point((x, y), fill=fill)

    def dots(self, coords: Sequence[Tuple[int, int]], fill: RGBA) -> None:
        for x, y in coords:
            self.px(x, y, fill)

    # -- salida ------------------------------------------------------------ #
    def render(self, scale: int = SCALE) -> Image.Image:
        img = self.img
        if self.want_outline:
            img = add_outline(img)
        return img.resize((self.w * scale, self.h * scale), Image.NEAREST)


def add_outline(img: Image.Image, color: RGBA = OUTLINE) -> Image.Image:
    """Anade 1px de contorno oscuro alrededor de las zonas opacas."""
    alpha = img.split()[3]
    grown = alpha.filter(ImageFilter.MaxFilter(3))
    ring = ImageChops.subtract(grown, alpha)
    layer = Image.new("RGBA", img.size, TRANSPARENT)
    layer.paste(Image.new("RGBA", img.size, color), (0, 0), ring)
    return Image.alpha_composite(layer, img)


def shade(c: RGBA, t: float) -> RGBA:
    """Aclara (t>0) u oscurece (t<0) un color de la paleta."""
    ref = (255, 255, 255) if t >= 0 else (0, 0, 0)
    k = min(1.0, abs(t))
    return (
        int(c[0] + (ref[0] - c[0]) * k),
        int(c[1] + (ref[1] - c[1]) * k),
        int(c[2] + (ref[2] - c[2]) * k),
        c[3],
    )


# --------------------------------------------------------------------------- #
# Piezas reutilizables
# --------------------------------------------------------------------------- #

def draw_gem(s: Sprite, cx: int, cy: int, r: int, rarity: Rarity) -> None:
    """Gema rombica facetada, como la del sobre original pero tintada por rareza."""
    top = (cx, cy - r)
    right = (cx + r, cy)
    bottom = (cx, cy + r)
    left = (cx - r, cy)
    s.poly([top, (cx, cy), left], rarity.light)      # cara sup-izq (brillo)
    s.poly([top, right, (cx, cy)], rarity.base)      # cara sup-der
    s.poly([left, (cx, cy), bottom], rarity.base)    # cara inf-izq
    s.poly([(cx, cy), right, bottom], rarity.dark)   # cara inf-der (sombra)
    spark = max(1, r // 2)
    s.px(cx - spark, cy - spark, WHITE)
    if r >= 4:
        s.px(cx - spark - 1, cy - spark, rarity.light)


# --------------------------------------------------------------------------- #
# Objetos de botin (paleta natural)
# --------------------------------------------------------------------------- #

def draw_vinyl(s: Sprite) -> None:
    s.ellipse(3, 3, 28, 28, DARK)                     # disco
    s.ellipse(4, 4, 27, 27, DARK_SOFT)
    for r in (11, 9, 7):
        s.ring(16 - r, 16 - r, 16 + r, 16 + r, DARK)
    s.ellipse(11, 11, 20, 20, GOLD)                   # etiqueta
    s.ring(12, 12, 19, 19, GOLD_HI)
    s.ellipse(15, 15, 16, 16, CREAM)                  # agujero central
    s.dots([(8, 9), (9, 7), (7, 11)], VINYL_SHEEN)   # brillo del vinilo


def _tintar_zona(s: Sprite, puntos: Sequence[Tuple[int, int]], color: RGBA) -> None:
    """Pinta `color` solo donde ya hay arte dentro del poligono.

    Hace falta para las variantes que son medio objeto y medio otra cosa (una
    zapatilla a medio limpiar, un vinilo con media etiqueta). Sin esto, pintar el
    poligono a pelo se saldria de la silueta y dejaria un escalon de color sobre
    el fondo transparente, que el auditor marca como alfa intermedia.

    El recorte sale del propio alfa del lienzo, que es la silueta real: no hay
    que mantener una copia de la forma.
    """
    mask = Image.new("L", (s.w, s.h), 0)
    ImageDraw.Draw(mask).polygon([(x + 0.5, y + 0.5) for x, y in puntos], fill=255)
    mask = ImageChops.multiply(mask, s.img.split()[3])
    s.img.paste(Image.new("RGBA", (s.w, s.h), color), (0, 0), mask)


def draw_vinyl_double(s: Sprite) -> None:
    """Doble LP: dos discos, el de atras asomando por arriba a la derecha.

    Se dibuja el trasero primero y el delantero encima, para que el solape lea
    como profundidad y no como un disco con un bulto raro.
    """
    # ---- disco de atras ----
    s.ellipse(12, 3, 28, 19, DARK)
    s.ellipse(13, 4, 27, 18, DARK_SOFT)
    for r in (6, 4):
        s.ring(20 - r, 11 - r, 20 + r, 11 + r, DARK)
    s.ellipse(17, 8, 23, 14, GOLD)                    # etiqueta del trasero
    s.ellipse(19, 10, 21, 12, CREAM)                  # agujero
    s.dots([(24, 6), (25, 8), (23, 5)], VINYL_SHEEN)  # brillo en el canto

    # ---- disco de delante ----
    s.ellipse(3, 12, 19, 28, DARK)
    s.ellipse(4, 13, 18, 27, DARK_SOFT)
    for r in (6, 4):
        s.ring(11 - r, 20 - r, 11 + r, 20 + r, DARK)
    s.ellipse(8, 17, 14, 23, GOLD)                    # etiqueta
    s.ring(9, 18, 13, 22, GOLD_HI)
    s.ellipse(10, 19, 12, 21, CREAM)                  # agujero
    s.dots([(6, 16), (7, 14), (5, 18)], VINYL_SHEEN)


def draw_vinyl_numbered(s: Sprite) -> None:
    """Edicion numerada: el disco de siempre con etiqueta crema y numerada.

    El numero va impreso en el centro en vez de haber agujero: en las
    prensaciones numeradas la pegatina tapa el eje, y asi se distingue de un
    vistazo del vinilo normal solo con la etiqueta.
    """
    s.ellipse(3, 3, 28, 28, DARK)
    s.ellipse(4, 4, 27, 27, DARK_SOFT)
    for r in (11, 9, 7):
        s.ring(16 - r, 16 - r, 16 + r, 16 + r, DARK)

    s.ellipse(10, 10, 21, 21, CREAM)                  # etiqueta grande
    s.ring(10, 10, 21, 21, CREAM_D)
    s.ellipse(12, 12, 19, 19, RED)                    # centro numerado
    s.ring(12, 12, 19, 19, RED_D)
    stamp_glyph(s, GLYPHS["7"], ox=12, oy=11, color=CREAM)  # el 007 del lote
    s.dots([(8, 9), (9, 7), (7, 11)], VINYL_SHEEN)    # brillo del vinilo
    s.px(24, 8, GOLD_L)                               # filete del borde


def draw_vinyl_color(s: Sprite) -> None:
    """Prensado en color: vinilo violeta translucido en vez de negro.

    Es el unico botin que usa los tonos de una rareza, y a proposito: el
    prensado en color es exactamente lo que se paga en un vinilo, asi que el
    color tiene que leerse sin mirar el texto. Los tres tonos son los mismos
    que usa la gema de rareza, con lo que sigue entrando en la paleta que
    admite el auditor.
    """
    violeta = RARITIES["epic"]
    s.ellipse(3, 3, 28, 28, violeta.dark)
    s.ellipse(4, 4, 27, 27, violeta.base)
    for r in (11, 9, 7):
        s.ring(16 - r, 16 - r, 16 + r, 16 + r, violeta.dark)
    s.ellipse(11, 11, 20, 20, CREAM)                  # etiqueta
    s.ring(12, 12, 19, 19, CREAM_D)
    s.ellipse(15, 15, 16, 16, CREAM_D)                # agujero
    s.dots([(8, 9), (9, 7), (7, 11)], violeta.light)  # el vinilo translucido
    s.line([(22, 6), (25, 9)], violeta.light)


def _sneaker(s: Sprite, cuerpo: RGBA, cuerpo_d: RGBA, suela: RGBA, suela_d: RGBA,
             franja: RGBA, franja_l: RGBA) -> None:
    """La silueta de la zapatilla, con la paleta que le pase cada variante.

    Las cuatro comparten forma a proposito (la base y sus tres variantes): hay que poder distinguir
    "una zapatilla roja" de "una zapatilla gastada" sin leer, y eso se sostiene
    sobre la misma silueta. Cambia el color y luego cada variante anade su
    propio detalle encima.
    """
    # ---- suela ----
    s.poly([(2, 27), (2, 24), (6, 23), (26, 22), (29, 23),
            (29, 26), (27, 27)], suela_d)
    s.poly([(3, 25), (6, 24), (26, 23), (28, 24), (27, 25), (3, 26)], suela)

    # ---- cuerpo ----
    s.poly([(4, 24), (4, 13), (7, 11), (11, 12), (15, 15), (20, 17),
            (26, 18), (29, 21), (29, 24)], cuerpo)
    s.poly([(4, 23), (20, 20), (27, 21), (29, 24), (4, 24)], cuerpo_d)

    # ---- abertura del tobillo ----
    s.poly([(6, 12), (8, 11), (11, 13), (12, 15), (9, 16), (6, 16)], DARK)

    # ---- cordones ----
    s.line([(11, 15), (14, 15)], DARK)
    s.line([(12, 17), (15, 17)], DARK)
    s.line([(13, 19), (16, 19)], DARK)

    # ---- franja lateral ----
    s.poly([(5, 21), (20, 19), (25, 20), (24, 22), (5, 23)], franja)
    s.poly([(5, 21), (20, 19), (22, 19), (23, 20), (5, 22)], franja_l)


def draw_sneaker(s: Sprite) -> None:
    _sneaker(s, WHITE, CREAM_D, CREAM, CREAM_D, GOLD, GOLD_HI)


def draw_sneaker_leather(s: Sprite) -> None:
    """De piel: el mismo modelo en cuero marron en vez de lona blanca.

    El nombre es de MODELO y no de estado, a proposito. El estado de un objeto
    lo deduce la nota PSA, asi que un sprite que dijera "gastada" pondria una
    zapatilla rota al lado de la insignia de "como nuevo", que es justo el
    yerro que el resto del juego evita. Un color distinto es un modelo
    distinto, y su nota sigue hablando de lo gastado que tenga.
    """
    _sneaker(s, BROWN, BROWN_D, CREAM_D, BROWN_D, GOLD_D, GOLD)
    s.line([(24, 12), (27, 15)], BROWN_D)            # pliegue del cuero
    s.dots([(12, 14), (18, 17), (23, 20)], BROWN_L)  # grano de la piel


def draw_sneaker_restore(s: Sprite) -> None:
    """A medio restaurar: la punta limpia y el talon sin tocar, con cinta.

    Lo que hace legible el estado es la CINTA, no el color: la parte sucia se
    limita al tercio de atras y para en el borde de la suela, porque si se
    tiñe la suela entera el sprite se lee como dos zapatillas superpuestas en
    vez de como una a medias.
    """
    _sneaker(s, WHITE, CREAM_D, CREAM, CREAM_D, GOLD, GOLD_HI)
    # el tercio de atras sucio, recortado a la silueta y sin llegar a la suela
    _tintar_zona(s, [(19, 10), (31, 13), (31, 23), (19, 23)], BROWN)
    s.dots([(23, 17), (26, 19), (21, 20)], BROWN_D)
    # cinta de enmascarar cruzando el corte, con su sombra al lado
    s.line([(18, 10), (16, 26)], TISSUE)
    s.line([(20, 10), (18, 26)], CREAM_D)
    # espuma del jabon en la parte ya limpia
    s.dots([(13, 14), (15, 15), (14, 17)], WHITE)
    s.px(12, 15, CREAM_L)


def draw_sneaker_limited(s: Sprite) -> None:
    """Edicion limitada: gamuza roja con ojetes y talon dorados.

    El rojo tambien esta en las insignias de estado roto, pero aqui va en un
    cuerpo grande y no en un disco de 13 px: lo que se ve es una zapatilla roja,
    no una alerta.
    """
    _sneaker(s, RED, RED_D, CREAM, CREAM_D, GOLD, GOLD_HI)
    s.poly([(7, 12), (10, 12), (13, 15), (11, 17), (8, 15)], RED_L)  # brillo
    s.px(21, 12, GOLD_L)                              # ojete superior
    s.px(23, 14, GOLD_L)
    s.poly([(26, 19), (29, 20), (29, 22), (26, 21)], GOLD)  # talon dorado
    s.line([(26, 23), (29, 23)], GOLD_D)              # suela bajo el talon
    s.dots([(16, 13), (18, 15)], RED_L)


def draw_console(s: Sprite) -> None:
    # carcasa con esquinas biseladas
    s.poly(
        [(8, 3), (24, 3), (26, 5), (26, 28), (24, 30), (8, 30), (6, 28), (6, 5)],
        STEEL,
    )
    s.poly([(8, 3), (24, 3), (26, 5), (26, 7), (6, 7), (6, 5)], WHITE)
    # pantalla
    s.rect(8, 8, 24, 19, STEEL_DD)
    s.rect(9, 9, 23, 18, LCD_D)
    s.rect(10, 10, 22, 17, LCD)
    s.rect(11, 11, 19, 13, LCD_L)
    s.rect(11, 15, 21, 16, LCD_L)
    # cruceta
    s.rect(10, 22, 15, 23, DARK_SOFT)
    s.rect(12, 20, 13, 25, DARK_SOFT)
    # botones
    s.ellipse(20, 21, 22, 23, GOLD_D)
    s.ellipse(23, 24, 25, 26, GOLD_D)
    # altavoz
    s.dots([(21, 28), (23, 28), (25, 28)], STEEL_DD)


def draw_headphones(s: Sprite) -> None:
    # diadema
    s.d.arc([3, 3, 28, 28], 180, 360, fill=GOLD_D, width=5)
    s.d.arc([3, 3, 28, 28], 180, 360, fill=GOLD, width=3)
    s.d.arc([4, 4, 27, 27], 195, 345, fill=GOLD_HI, width=1)
    # orejeras
    s.ellipse(1, 15, 11, 29, GOLD_D)
    s.ellipse(20, 15, 30, 29, GOLD_D)
    s.ellipse(3, 17, 9, 27, DARK_SOFT)
    s.ellipse(22, 17, 28, 27, DARK_SOFT)
    s.poly([(4, 19), (8, 19), (8, 22), (4, 22)], BROWN_L)
    s.poly([(23, 19), (27, 19), (27, 22), (23, 22)], BROWN_L)


def draw_watch(s: Sprite) -> None:
    # correa
    s.rect(13, 3, 19, 14, BROWN)
    s.rect(13, 20, 19, 29, BROWN)
    s.rect(13, 3, 15, 14, BROWN_L)
    s.rect(13, 20, 15, 29, BROWN_L)
    s.rect(13, 26, 19, 28, GOLD_D)
    # caja
    s.ellipse(7, 7, 25, 25, GOLD_D)
    s.ellipse(8, 8, 24, 24, GOLD_XL)
    s.ellipse(10, 10, 22, 22, CREAM)
    # marcas
    s.dots([(16, 11), (16, 21), (11, 16), (21, 16)], BROWN_D)
    # agujas
    s.line([(16, 16), (16, 11)], DARK)
    s.line([(16, 16), (20, 18)], DARK)
    s.px(16, 16, GOLD_D)
    # corona
    s.rect(25, 14, 26, 18, GOLD_L)


def draw_camera(s: Sprite) -> None:
    # visor / flash
    s.rect(7, 8, 12, 12, CREAM)
    s.rect(20, 8, 26, 12, GOLD_HI)
    s.rect(21, 9, 25, 11, GOLD)
    # cuerpo
    s.rect(4, 11, 28, 26, DARK_SOFT)
    s.rect(5, 12, 27, 14, SLATE)
    s.rect(4, 24, 28, 26, DARK)
    # empunadura
    s.rect(5, 15, 9, 25, BROWN)
    s.rect(5, 15, 6, 25, BROWN_L)
    # objetivo
    s.ellipse(11, 13, 23, 27, DARK)
    s.ellipse(12, 14, 22, 26, STEEL_DD)
    s.ellipse(14, 16, 20, 24, TEAL_D)
    s.px(15, 17, TEAL_L)
    s.px(16, 18, TEAL_L)
    # boton disparador
    s.rect(18, 6, 22, 8, GOLD_D)


# --------------------------------------------------------------------------- #
# Objetos que anaden a electronica y a varios
#
# Los tres de electronica y los tres de varios llegan tarde y por un motivo
# concreto: con 3 y con 1 objetosrespectively, abrir un sobre era repetir el
# mismo dibujo. Un objeto mas por fila es lo que hace que la rareza cambie
# ALGO y no solo el numero.
# --------------------------------------------------------------------------- #

def draw_cartridge(s: Sprite) -> None:
    """Cartucho de consola: carcasa gris, etiqueta de color y la muesca del
    conector abajo.

    Es el objeto mas barato de electronica. La etiqueta va en turquesa porque
    es el unico sitio donde el acento frio se puede permitir: una mancha de 11
    px, no un cuerpo.
    """
    s.poly([(8, 4), (24, 4), (26, 6), (26, 29), (6, 29), (6, 6)], STEEL)
    s.poly([(8, 4), (24, 4), (25, 5), (7, 5)], WHITE)       # luz del canto
    s.rect(6, 20, 7, 27, STEEL_D)                          # lateral en sombra
    s.rect(6, 27, 26, 29, STEEL_DD)                         # base
    # etiqueta
    s.rect(9, 8, 23, 19, CREAM)
    s.rect(9, 8, 23, 9, WHITE)
    s.rect(9, 17, 23, 19, CREAM_D)
    s.rect(11, 10, 21, 15, TEAL_D)
    s.rect(11, 10, 21, 10, TEAL)
    s.dots([(12, 12), (15, 13), (18, 12)], CREAM)
    # muesca del conector con sus contactos
    s.rect(12, 22, 20, 25, DARK)
    s.rect(12, 22, 20, 22, DARK_SOFT)
    s.dots([(14, 24), (16, 24), (18, 24)], GOLD_D)
    # nervios de agarre en el canto
    s.dots([(6, 10), (6, 13), (6, 16), (6, 19)], STEEL_DD)


def draw_handheld(s: Sprite) -> None:
    """Consola portatil de las antiguas, en HORIZONTAL y con dos agarres.

    La primera version era vertical como `console` y con la pantalla en medio:
    en la hoja de contacto se confundian las dos. Por eso esta es apaisada, con
    los botones redondos saliendose del cuerpo y la pantalla descentrada a la
    izquierda. La diferencia de silueta es lo que las separa, no el detalle.
    """
    s.poly([(7, 8), (25, 8), (28, 11), (28, 22), (25, 25), (7, 25),
            (4, 22), (4, 11)], STEEL)
    s.poly([(7, 8), (25, 8), (26, 9), (6, 9)], WHITE)          # luz del canto
    s.rect(4, 23, 28, 25, STEEL_D)                             # base en sombra
    s.rect(4, 11, 5, 22, STEEL_D)                              # lateral
    # pantalla, a la izquierda y con marco grueso
    s.rect(9, 11, 21, 22, STEEL_DD)
    s.rect(10, 12, 20, 21, LCD_D)
    s.rect(11, 13, 19, 20, LCD)
    s.rect(11, 15, 19, 16, LCD_L)
    s.rect(13, 13, 17, 13, LCD_L)
    # cruceta
    s.rect(22, 12, 27, 13, DARK_SOFT)
    s.rect(24, 10, 25, 15, DARK_SOFT)
    s.rect(22, 12, 27, 12, DARK)
    s.rect(24, 10, 25, 10, DARK)
    # boton de arranque
    s.ellipse(23, 17, 27, 21, GOLD_D)
    s.ellipse(24, 18, 26, 20, GOLD)
    # altavoz
    s.dots([(7, 21), (8, 22), (9, 21)], STEEL_DD)


def draw_cable(s: Sprite) -> None:
    """Cable enrollado en dos vueltas, con un conector en cada extremo."""
    s.ring(3, 8, 22, 27, TEAL_D, width=3)
    s.ring(10, 3, 29, 22, TEAL_D, width=3)
    s.ring(4, 9, 21, 26, TEAL, width=1)
    s.ring(11, 4, 28, 21, TEAL, width=1)
    # conectores en las dos puntas
    s.rect(2, 15, 7, 20, STEEL)
    s.rect(2, 16, 7, 16, STEEL_DD)
    s.rect(2, 19, 7, 19, STEEL_DD)
    s.rect(24, 4, 29, 9, STEEL)
    s.rect(24, 8, 29, 8, STEEL_DD)
    s.rect(24, 4, 29, 4, WHITE)


def draw_ingot(s: Sprite) -> None:
    """Lingote de oro, en escorzo de dos caras.

    La clave es la PROPORCION: la cara de delante es mas alta que la de arriba.
    Al revés (que es como se dibuja a ojo) sale un montoncito y no una barra.
    """
    s.poly([(10, 5), (22, 5), (27, 14), (5, 14)], GOLD_L)     # cara de arriba
    s.poly([(10, 5), (22, 5), (23, 7), (9, 7)], GOLD_HI)       # canto de luz
    s.poly([(5, 14), (27, 14), (27, 28), (5, 28)], GOLD)       # cara de delante
    s.poly([(5, 14), (27, 14), (27, 16), (5, 16)], GOLD_L)     # bisel
    # Arista entre las dos caras. Sin ella GOLD_L y GOLD se funden (son tonos
    # contiguos) y el lingote se lee como un montoncito en vez de un bloque.
    s.rect(5, 14, 27, 14, GOLD_D)
    s.poly([(5, 26), (27, 26), (27, 28), (5, 28)], GOLD_D)     # sombra baja
    s.poly([(25, 14), (27, 14), (27, 28), (25, 26)], GOLD_D)   # canto lateral
    # marcas de la acuna, estampadas en la cara de delante
    s.dots([(9, 20), (13, 20), (17, 20), (21, 20)], GOLD_D)
    s.dots([(11, 23), (15, 23), (19, 23)], GOLD_D)
    s.dots([(12, 9), (16, 9), (20, 9)], GOLD_D)


def draw_pocket_watch(s: Sprite) -> None:
    """Reloj de bolsillo con cadena: el objeto de lujo del paquete de varios.

    No es `watch` (que lleva correa): aqui lo que lo identifica es la argolla
    con la cadena saliendo por detras, que es justo la silueta de un reloj de
    bolsillo colgado de un perista.
    """
    s.arc(2, 2, 30, 30, 195, 345, fill=GOLD_D, width=2)        # cadena
    s.dots([(4, 8), (7, 5), (11, 3)], GOLD)
    s.ring(12, 5, 20, 13, GOLD_D, width=2)                     # argolla
    s.rect(15, 8, 17, 11, GOLD_D)                               # corona
    s.px(15, 8, GOLD_HI)
    s.ellipse(7, 11, 25, 29, GOLD_D)                            # caja
    s.ellipse(8, 12, 24, 28, GOLD_XL)
    s.ellipse(10, 14, 22, 26, CREAM)
    s.ellipse(11, 15, 21, 25, WHITE)
    s.dots([(16, 16), (16, 23), (12, 20), (20, 20)], BROWN_D)  # marcas
    s.line([(16, 20), (16, 16)], DARK)                         # agujas
    s.line([(16, 20), (20, 22)], DARK)
    s.px(16, 20, GOLD_D)


# --------------------------------------------------------------------------- #
# Paquetes: lo que compras a ciegas
#
# Cada categoria tiene dos estados: cerrado (lo que cae en la mesa) y roto (lo
# que se ve cuando termina de abrirse). El cuerpo se dibuja una vez y el estado
# roto lo reutiliza y le arranca la parte de arriba, para que la silueta sea
# claramente la misma caja y no dos objetos parecidos.
# --------------------------------------------------------------------------- #

def _serrated_top(s: Sprite, x0: int, x1: int, y: int, alto: int = 2) -> None:
    """Borde en sierra de un sobre de cartas."""
    for x in range(x0, x1 + 1):
        if (x - x0) % 2 == 0:
            s.rect(x, y, x, y + alto, GOLD_D)
        else:
            s.rect(x, y, x, y, GOLD_D)


def draw_pack_cards(s: Sprite) -> None:
    """Sobre de cartas coleccionables, cerrado."""
    x0, x1, y0, y1 = 9, 22, 3, 29
    s.rect(x0, y0, x1, y1, GOLD)                 # marco
    s.rect(x0, y0, x1, y1 - 2, GOLD_L)           # luz del marco
    s.rect(x0, y0 + 2, x1, y1, GOLD_D)
    s.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, BROWN)
    s.rect(x0 + 1, y0 + 1, x1 - 1, y0 + 3, BROWN_L)
    s.rect(x0 + 1, y1 - 3, x1 - 1, y1 - 1, BROWN_D)
    # esquinas turquesa
    s.dots([(x0 + 2, y0 + 2), (x1 - 2, y0 + 2),
            (x0 + 2, y1 - 2), (x1 - 2, y1 - 2)], TEAL)
    # gema central
    draw_gem(s, 15, 15, 3, RARITIES["rare"])
    # sierra del borde superior
    _serrated_top(s, x0, x1, y0 - 2)


def draw_pack_cards_open(s: Sprite) -> None:
    """El mismo sobre, rasgado por arriba, con cartas asomando."""
    draw_pack_cards(s)
    # desgarro: se borra la parte de arriba del sobre
    s.rect(8, 0, 23, 9, TRANSPARENT)
    # borde rasgado, con el interior oscuro
    s.poly([(9, 11), (11, 7), (14, 10), (17, 6), (20, 10), (22, 8), (22, 11)], DARK)
    s.rect(9, 11, 22, 13, DARK)
    s.line([(9, 11), (22, 11)], GOLD_D)
    s.dots([(10, 8), (13, 7), (16, 6), (19, 7), (21, 9)], GOLD_D)
    # cartas bien asomando por encima del desgarro
    s.rect(10, 1, 15, 8, CREAM)
    s.rect(10, 1, 15, 1, WHITE)
    s.rect(10, 4, 15, 4, CREAM_D)
    s.px(12, 2, TEAL)
    s.rect(16, 2, 21, 9, CREAM)
    s.rect(16, 2, 21, 2, WHITE)
    s.rect(16, 5, 21, 5, CREAM_D)
    s.px(18, 3, RED)


def draw_pack_vinyls(s: Sprite) -> None:
    """Funda cuadrada de vinilo, cerrada."""
    x0, x1, y0, y1 = 4, 27, 6, 28
    s.rect(x0, y0, x1, y1, BROWN)                # carton
    s.rect(x0, y0, x1, y0 + 1, BROWN_L)
    s.rect(x0, y1 - 1, x1, y1, BROWN_D)
    s.rect(x0, y0, x0, y1, BROWN_L)
    s.rect(x1, y0, x1, y1, BROWN_D)
    s.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, CARD)   # tapa interior
    s.rect(x0 + 1, y0 + 1, x1 - 1, y0 + 2, BROWN_L)
    # cinta dorada cruzando
    s.rect(x0, 15, x1, 17, GOLD)
    s.rect(x0, 15, x1, 15, GOLD_L)
    s.rect(x0, 17, x1, 17, GOLD_D)
    # canton superior derecho gastado
    s.poly([(22, 6), (27, 6), (27, 11)], CARD_L)
    s.line([(22, 11), (27, 6)], CREAM_D)
    # un poco de vinilo negro asomando
    s.rect(x0 + 2, y0 - 2, x1 - 2, y0, DARK)


def draw_pack_vinyls_open(s: Sprite) -> None:
    """La misma funda, rasgada por una esquina, con el vinilo fuera."""
    draw_pack_vinyls(s)
    # el vinilo sale entero por la esquina superior derecha
    s.ellipse(14, 1, 30, 19, DARK)
    s.ellipse(15, 2, 29, 18, DARK_SOFT)
    s.ellipse(20, 7, 24, 11, GOLD_D)
    s.ellipse(20, 7, 23, 10, GOLD_XL)
    s.ring(16, 3, 28, 17, DARK)
    # desgarro del carton
    s.poly([(12, 6), (16, 9), (20, 6), (24, 9), (27, 6), (27, 12), (12, 12)], DARK)
    s.line([(12, 12), (27, 12)], GOLD_D)
    s.dots([(13, 7), (17, 10), (21, 7), (25, 10)], GOLD_D)
    s.px(14, 6, CREAM_D)
    s.px(23, 6, CREAM_D)


def draw_pack_sneakers(s: Sprite) -> None:
    """Caja de zapatillas, cerrada."""
    x0, x1, y0, y1 = 2, 29, 12, 26
    s.rect(x0, y0, x1, y1, CREAM)                # cuerpo
    s.rect(x0, y0, x1, y0 + 2, GOLD)             # tapa dorada
    s.rect(x0, y0, x1, y0, GOLD_HI)
    s.rect(x0, y0 + 2, x1, y0 + 3, GOLD_D)
    s.rect(x0, y1 - 1, x1, y1, CREAM_D)
    s.rect(x0, y0, x0, y1, CREAM_D)              # lateral en sombra
    s.rect(x0 + 1, y0 + 4, x1 - 1, y0 + 6, SHOE_D)  # sombreado bajo la tapa
    # etiqueta dorada en el lateral
    s.rect(8, 19, 23, 24, GOLD_D)
    s.rect(9, 20, 22, 23, GOLD)
    s.rect(9, 20, 22, 20, GOLD_L)
    s.rect(11, 21, 20, 22, BROWN)                # texto falso de la etiqueta
    # albaran
    s.rect(4, 15, 7, 18, CREAM_D)
    s.dots([(5, 16), (6, 17)], BROWN_D)


def draw_pack_sneakers_open(s: Sprite) -> None:
    """La misma caja con la tapa levantada y una zapatilla saliendo."""
    # tapa levantada, por detras
    s.poly([(2, 12), (8, 5), (27, 5), (29, 12)], CREAM)
    s.poly([(8, 5), (27, 5), (27, 7), (9, 7)], CREAM_D)   # canto de la tapa
    s.poly([(2, 12), (8, 5), (9, 7), (3, 12)], CREAM_D)    # lateral en sombra
    # papel de seda
    s.poly([(4, 13), (9, 9), (22, 9), (27, 13)], WHITE)
    s.poly([(4, 13), (9, 9), (15, 9), (10, 13)], TISSUE)
    # zapatilla blanca saliendo
    s.poly([(10, 18), (11, 13), (15, 12), (19, 15), (24, 16), (27, 19), (27, 21), (10, 21)], WHITE)
    s.poly([(10, 20), (27, 19), (27, 21), (10, 21)], CREAM_D)   # suela
    s.poly([(12, 16), (19, 15), (23, 16), (22, 18), (12, 18)], GOLD)   # franja
    s.px(14, 14, CREAM_D)
    # cuerpo de la caja
    s.rect(2, 13, 29, 26, CREAM)
    s.rect(2, 13, 29, 15, CREAM_D)
    s.rect(2, 25, 29, 26, CREAM_D)
    s.rect(2, 13, 2, 26, CREAM_D)
    s.rect(8, 19, 23, 24, GOLD_D)
    s.rect(9, 20, 22, 23, GOLD)
    s.rect(9, 20, 22, 20, GOLD_L)
    s.rect(11, 21, 20, 22, BROWN)


def draw_pack_electronics(s: Sprite) -> None:
    """Caja de electronica envuelta en plastico, cerrada."""
    x0, x1, y0, y1 = 9, 22, 3, 28
    s.rect(x0, y0, x1, y1, DARK_SOFT)            # plastico oscuro
    s.rect(x0, y0, x0 + 2, y1, SLATE)            # brillo del plastico
    s.rect(x1 - 1, y0, x1, y1, DARK)
    s.rect(x0, y1 - 1, x1, y1, DARK)
    s.dots([(x0 + 1, 6), (x0 + 1, 10), (x0 + 1, 18)], STEEL_DD)   # brillos
    s.dots([(x0 + 2, 8), (x0 + 2, 16)], PLASTIC)
    # bandas doradas
    s.rect(x0, 8, x1, 10, GOLD)
    s.rect(x0, 8, x1, 8, GOLD_L)
    s.rect(x0, 10, x1, 10, GOLD_D)
    s.rect(x0, 20, x1, 22, GOLD)
    s.rect(x0, 20, x1, 20, GOLD_L)
    s.rect(x0, 22, x1, 22, GOLD_D)
    # precinto
    s.rect(13, 3, 18, 28, GOLD_D)
    s.rect(14, 3, 16, 28, GOLD)
    s.rect(14, 3, 14, 28, GOLD_L)
    s.dots([(15, 6), (15, 9), (15, 24)], GOLD_HI)
    # etiqueta
    s.rect(11, 13, 20, 18, CREAM)
    s.rect(11, 13, 20, 13, WHITE)
    s.dots([(13, 15), (16, 15), (18, 16), (13, 17)], BROWN_D)


def draw_pack_electronics_open(s: Sprite) -> None:
    """La misma caja con el plastico rasgado y arrancado."""
    draw_pack_electronics(s)
    # plastico descolgandose por un lado
    s.poly([(19, 3), (26, 6), (27, 14), (22, 12), (20, 8)], DARK_SOFT)
    s.poly([(19, 3), (26, 6), (27, 8), (21, 6)], SLATE)
    s.dots([(24, 10), (25, 12)], STEEL_DD)
    # hueco rasgado, con el interior oscuro
    s.rect(7, 11, 24, 20, DARK)
    s.poly([(7, 11), (10, 9), (14, 11), (18, 8), (24, 11), (24, 20), (7, 20)], DARK)
    s.poly([(7, 11), (10, 9), (14, 11), (18, 8), (24, 11), (24, 13), (7, 13)], PLASTIC)
    # bordes del desgarro
    s.dots([(8, 11), (12, 10), (16, 10), (20, 9), (23, 11)], STEEL_D)
    # cable enrollado asomando
    s.arc(11, 13, 21, 19, 20, 340, fill=TEAL_D, width=2)
    s.arc(12, 14, 20, 18, 30, 300, fill=TEAL, width=1)
    s.px(20, 15, GOLD_HI)


def draw_pack_misc(s: Sprite) -> None:
    """Paquete generico sellado, sin marca."""
    s.poly([(7, 5), (24, 3), (28, 9), (27, 24), (22, 28), (9, 27), (4, 21), (5, 10)], CREAM_D)
    s.poly([(7, 5), (24, 3), (28, 9), (26, 12), (9, 12), (5, 11)], CREAM)
    s.poly([(5, 18), (9, 12), (26, 12), (27, 24), (22, 28), (9, 27), (4, 21)], CREAM_D)
    # pliegues
    s.line([(9, 12), (13, 24)], CRINKLE)
    s.line([(20, 12), (18, 25)], CRINKLE)
    s.dots([(11, 16), (23, 14), (8, 20)], CRINKLE_L)
    # cinta dorada cruzada
    s.rect(4, 15, 28, 18, GOLD)
    s.rect(4, 15, 28, 15, GOLD_L)
    s.rect(4, 18, 28, 18, GOLD_D)
    s.rect(13, 5, 17, 27, GOLD)
    s.rect(13, 5, 13, 27, GOLD_L)
    s.rect(17, 5, 17, 27, GOLD_D)
    s.px(15, 9, GOLD_HI)
    s.px(15, 24, GOLD_HI)


def draw_pack_misc_open(s: Sprite) -> None:
    """El mismo paquete, abierto y arrugado, con objetos asomando."""
    # objetos que asoman por la abertura
    s.ellipse(9, 3, 20, 14, GOLD_D)             # moneda
    s.ellipse(10, 4, 19, 12, GOLD)
    s.ellipse(12, 6, 17, 10, GOLD_XL)
    s.rect(21, 4, 24, 14, BROWN)                # trozo de madera
    s.rect(21, 4, 24, 6, BROWN_L)
    s.arc(4, 6, 11, 13, 0, 360, fill=TEAL_D, width=2)   # cable
    s.arc(4, 6, 11, 13, 30, 300, fill=TEAL, width=1)
    draw_pack_misc(s)
    # abertura rasgada arriba
    s.poly([(6, 12), (10, 8), (15, 12), (19, 7), (24, 11), (27, 12), (27, 14), (6, 14)], DARK)
    s.poly([(6, 12), (10, 8), (15, 12), (19, 7), (24, 11), (27, 12), (27, 13), (6, 13)], BROWN_D)
    s.dots([(7, 12), (12, 9), (17, 10), (21, 8), (26, 12)], CREAM_D)
    # la cinta sigue cerrada en la parte de abajo: esta envoltura es arrugada,
    # no rasgada de una vez
    s.rect(4, 15, 28, 18, GOLD)
    s.rect(4, 15, 28, 15, GOLD_L)
    s.rect(4, 18, 28, 18, GOLD_D)


# --------------------------------------------------------------------------- #
# Sombras de mesa
#
# El README prohibe la sombra dentro del sprite ("el sombreado se resuelve en el
# juego"), asi que aqui va la pieza que la dibuja. Sin contorno y con alfa
# graduado, como las auras: por eso van en la lista blanca del auditor.
#
# Los tres tamaños son multiplos enteros entre si (128 / 256 / 512) para que
# el que el juego elija pueda encogerse con vecino mas cercano sin romper la rejilla.
# --------------------------------------------------------------------------- #

def draw_shadow(s: Sprite, radio: int) -> None:
    """Elipse negra difuminada, como la sombra que cae bajo un objeto."""
    s.want_outline = False
    cx = cy = s.w / 2.0
    anillos = [(radio, 26), (radio - 1, 44), (radio - 2, 66),
               (radio - 3, 92), (radio - 4, 124), (radio - 5, 160)]
    for r, a in anillos:
        if r < 2:
            break
        s.ellipse(cx - r, cy - r * 0.55, cx + r, cy + r * 0.55, (SHADOW[0], SHADOW[1], SHADOW[2], a))


def draw_shadow_small(s: Sprite) -> None:
    draw_shadow(s, 5)


def draw_shadow_medium(s: Sprite) -> None:
    draw_shadow(s, 9)


def draw_shadow_large(s: Sprite) -> None:
    draw_shadow(s, 14)


# --------------------------------------------------------------------------- #
# Graduacion PSA (nota de 1 a 10)
#
# El numero no va aqui: se pinta en el juego con la fuente num_* que ya existe.
# Estos sprites son solo el marco, las estrellas y la cinta, para que subir de
# nota sea cambiar estrellas y no rehacer el icono entero.
# --------------------------------------------------------------------------- #

def draw_grade_badge(s: Sprite) -> None:
    """Escudo donde va la nota. Vacio a proposito: el numero lo pone Godot."""
    s.poly([(4, 2), (11, 2), (11, 9), (7, 14), (4, 9)], GOLD)
    s.poly([(4, 2), (11, 2), (11, 3), (5, 3)], GOLD_HI)
    s.poly([(10, 3), (11, 3), (11, 9), (7, 14), (7, 13)], GOLD_D)
    s.poly([(5, 3), (10, 3), (10, 9), (7, 12), (5, 9)], CREAM)
    s.poly([(5, 3), (10, 3), (10, 4), (6, 4)], WHITE)
    s.poly([(9, 4), (10, 4), (10, 9), (7, 12), (7, 11)], CREAM_D)
    s.dots([(5, 5), (5, 6)], WHITE)


# Estrella de cinco puntas como mascara de texto, igual que la fuente de
# numeros en font_patterns.py. La primera version la generaba con una formula
# de ancho lineal y salia un rombo, no una estrella.
STAR_MASK = [
    ".....X.....",
    ".....X.....",
    "....XXX....",
    "....XXX....",
    "XXXXXXXXXXX",
    ".XXXXXXXXX.",
    "..XXXXXXX..",
    "..XX...XX..",
    ".XXX...XXX.",
    "XX.......XX",
]
STAR_X, STAR_Y = 2, 2      # hueco arriba a la izquierda dentro del lienzo de 16


def _star_pixels():
    mask = set()
    for dy, linea in enumerate(STAR_MASK):
        for dx, ch in enumerate(linea):
            if ch == "X":
                mask.add((STAR_X + dx, STAR_Y + dy))
    return mask


def draw_grade_star_full(s: Sprite) -> None:
    """Estrella llena: la nota la sube."""
    mask = _star_pixels()
    for x, y in mask:
        s.px(x, y, GOLD)
    for x, y in mask:                     # sombra en el canto inferior derecho
        if (x, y + 1) not in mask or (x + 1, y) not in mask:
            s.px(x, y, GOLD_D)
    s.px(7, 4, GOLD_HI)                   # especular en la punta de arriba
    s.px(6, 5, GOLD_HI)


def draw_grade_star_half(s: Sprite) -> None:
    """Media estrella: la nota es intermedia."""
    mask = _star_pixels()
    for x, y in mask:
        s.px(x, y, STAR_OFF)
    for x, y in mask:                     # solo se rellena la mitad izquierda
        if x < 7:
            s.px(x, y, GOLD)
    for x, y in mask:
        if (x, y + 1) not in mask or (x + 1, y) not in mask or (x - 1, y) not in mask:
            s.px(x, y, STAR_OFF_D)
    for y in range(STAR_Y, STAR_Y + len(STAR_MASK)):
        if (7, y) in mask:
            s.px(7, y, GOLD_D)            # linea de corte de la media


def draw_grade_star_empty(s: Sprite) -> None:
    """Estrella vacia: lo que queda por ganar."""
    mask = _star_pixels()
    for x, y in mask:
        s.px(x, y, STAR_OFF)
    for x, y in mask:
        if (x, y + 1) not in mask or (x + 1, y) not in mask or (x - 1, y) not in mask:
            s.px(x, y, STAR_OFF_D)
    s.px(7, 4, STAR_OFF_L)


def draw_grade_ribbon(s: Sprite) -> None:
    """Cinta de encabezado para la ficha del objeto."""
    w = s.w
    s.rect(0, 2, w - 1, 9, RED_D)               # cinta
    s.rect(0, 2, w - 1, 3, RED)
    s.rect(0, 8, w - 1, 9, (70, 16, 14, 255))
    s.rect(0, 2, 1, 9, RED_L)
    # puntas en cola de golondrina
    s.poly([(0, 2), (3, 2), (1, 7), (3, 12), (0, 12)], RED)
    s.px(1, 4, RED_L)
    s.poly([(w - 1, 2), (w - 4, 2), (w - 2, 7), (w - 4, 12), (w - 1, 12)], RED)
    s.px(w - 2, 4, RED_L)
    s.rect(2, 4, w - 3, 7, GOLD_D)              # filete dorado
    s.rect(2, 4, w - 3, 4, GOLD)
    s.rect(2, 6, w - 3, 6, GOLD_D)


# --------------------------------------------------------------------------- #
# Flujo de apertura: esperar, revelar, vender
# --------------------------------------------------------------------------- #

def draw_timer_track(s: Sprite) -> None:
    """Anillo de espera, vacio. Se dibuja una vez y el relleno va encima."""
    s.ellipse(1, 1, 14, 14, WOOD_M)           # canal
    s.ellipse(2, 2, 13, 13, WOOD_DD)
    s.ellipse(4, 4, 11, 11, TRANSPARENT)      # hueco central
    s.ring(1, 1, 14, 14, GOLD_D, width=1)     # aro exterior
    s.dots([(4, 2), (5, 2)], GOLD_L)          # brillo del aro


def draw_timer_fill(s: Sprite) -> None:
    """Cuarto de anillo que el juego gira cuatro veces para llenar la espera.

    Sin contorno a proposito: es una pieza que rota sobre la pista, y el borde
    oscuro se comeria el hueco central al girar.
    """
    s.want_outline = False
    s.pie(1, 1, 14, 14, 270, 360, GOLD)
    s.pie(2, 2, 13, 13, 270, 360, GOLD_HI)
    s.line([(8, 8), (8, 2)], GOLD_HI)


def draw_panel_reveal(s: Sprite) -> None:
    """Tarjeta de revelado: donde se enseña objeto, rareza, nota y valor.

    Mismo esqueleto de 9-slice que los otros paneles (100x60 de arte, margen 8)
    para que Godot use los mismos margenes, pero cuerpo casi negro: el objeto
    tiene que destacar sobre el, al contrario que en la tienda.
    """
    w, h = s.w, s.h
    s.rect(1, 1, w - 2, h - 2, GOLD_D)
    s.rect(2, 2, w - 3, h - 3, GOLD_L)
    s.rect(3, 3, w - 4, h - 4, GOLD_D)
    s.rect(4, 4, w - 5, h - 5, NIGHT)
    s.rect(4, 4, w - 5, 4, NIGHT_LL)       # bisel superior
    s.rect(4, h - 5, w - 5, h - 5, NIGHT_DD)
    # hueco reservado para el objeto, en el centro
    s.rect(28, 12, 71, 45, NIGHT_D)
    s.rect(28, 12, 71, 13, NIGHT_L)
    s.dots([(6, 6), (w - 7, 6), (6, h - 7), (w - 7, h - 7)], GOLD)
    for cx, cy in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        s.px(cx, cy, TRANSPARENT)


def draw_fx_shine(s: Sprite) -> None:
    """Destello de fondo al revelar un botin raro o legendario."""
    s.want_outline = False
    cx = cy = s.w / 2.0
    for r, a in ((15, 34), (13, 58), (11, 84), (9, 112), (7, 142), (5, 174), (3, 208)):
        s.ellipse(cx - r, cy - r, cx + r, cy + r, (SHINE[0], SHINE[1], SHINE[2], a))
    # cuatro radios en cruz, que es como se lee un destello de verdad; con ocho
    # los pixeles salian tan sueltos que parecia ruido y no un brillo
    for ang in (0, 90, 180, 270):
        dx, dy = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        for i in range(3, 16):
            s.px(int(cx + dx * i), int(cy + dy * i),
                 (SHINE_HI[0], SHINE_HI[1], SHINE_HI[2], max(30, 200 - i * 14)))


def draw_tag_price(s: Sprite) -> None:
    """Chapita de valor que se pone bajo un objeto de la mesa."""
    w, h = s.w, s.h
    punta = [(3, 2), (w - 4, 2), (w - 2, h // 2), (w - 4, h - 3), (3, h - 3), (1, h // 2)]
    s.poly(punta, CREAM)
    s.poly([(4, 3), (w - 5, 3), (w - 3, h // 2), (w - 5, h - 4), (4, h - 4), (2, h // 2)], CREAM_D)
    s.poly([(5, 4), (w - 6, 4), (w - 4, h // 2), (w - 6, h - 5), (5, h - 5), (3, h // 2)], CREAM_L)
    s.ellipse(4, h // 2 - 1, 6, h // 2 + 1, CREAM_D)     # agujero de la chapita
    s.rect(4, h // 2 - 1, 6, h // 2 - 1, CREAM)


def draw_button_sell(s: Sprite) -> None:
    """Boton de vender. Sin texto: la etiqueta la pone Godot."""
    w, h = s.w, s.h
    s.rect(1, 1, w - 2, h - 2, GOLD_L)
    s.rect(2, 2, w - 3, h - 3, GOLD_D)
    s.rect(3, 3, w - 4, h - 4, NIGHT_L)                   # cuerpo oscuro, es accion de perder
    s.rect(3, 3, w - 4, 4, NIGHT_LL)
    s.rect(3, h - 4, w - 4, h - 4, NIGHT_DD)
    for cx, cy in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        s.px(cx, cy, TRANSPARENT)


def draw_coin(s: Sprite) -> None:
    """Moneda suelta, para los precios. La pila es currency_coins.

    Lleva la misma estrella de la graduacion en relieve. La primera version
    encadenaba cuatro anillos concentricos y mas bien parecia una diana que una
    moneda; con un solo relieve se lee de un vistazo.
    """
    s.ellipse(3, 3, 28, 28, GOLD_D)            # canto
    s.ellipse(4, 4, 27, 27, GOLD)
    s.ellipse(6, 6, 25, 25, GOLD_XL)           # cara
    s.ellipse(8, 8, 23, 23, GOLD_L)            # brillo interior
    s.ellipse(10, 10, 21, 21, GOLD_XL)         # campo donde va el relieve
    s.arc(4, 4, 27, 27, 200, 300, fill=GOLD_HI, width=1)
    s.px(9, 8, WHITE)
    s.px(8, 9, WHITE)
    # estrella en relieve, la misma mascara de la graduacion pero reducida
    for dy, linea in enumerate(STAR_MASK):
        for dx, ch in enumerate(linea):
            if ch == "X":
                s.px(11 + dx // 2, 12 + dy // 2, GOLD_D)


# --------------------------------------------------------------------------- #
# Herramientas equipables (acortan el tiempo de apertura)
# --------------------------------------------------------------------------- #

def draw_cutter(s: Sprite) -> None:
    """Cuter de hoja retráctil en diagonal: mango dorado y hoja de acero.

    Va en diagonal de abajo-derecha a arriba-izquierda. La hoja sale del hueco
    del mango y el boton deslizante lleva un brillo para que se lea que es lo
    que se pulsa.
    """
    # ---- hoja (sale por el extremo superior izquierdo) ----
    s.poly([(3, 12), (5, 4), (8, 5), (7, 13)], STEEL)
    s.poly([(5, 4), (8, 5), (7, 7), (4, 11)], STEEL_D)   # bisel oscuro
    s.poly([(3, 12), (5, 4), (6, 5), (4, 12)], STEEL_DD)  # filo
    # punta
    s.px(4, 3, STEEL)
    s.px(5, 3, STEEL_D)

    # ---- hueco de la hoja ----
    s.rect(7, 12, 12, 15, DARK_SOFT)
    s.rect(8, 12, 11, 12, GOLD_D)

    # ---- mango ----
    s.poly([(11, 12), (13, 11), (28, 26), (28, 29), (25, 29), (10, 15)], GOLD)
    # brillo del canto superior-izquierdo del mango
    s.poly([(11, 12), (13, 11), (28, 26), (26, 27), (12, 14)], GOLD_L)
    s.poly([(11, 12), (13, 11), (14, 12), (12, 13)], GOLD_HI)
    # sombra del canto inferior-derecho
    s.poly([(10, 15), (25, 29), (28, 29), (28, 26), (13, 12)], GOLD_D)

    # ---- remaches del mango ----
    s.dots([(16, 19), (19, 22), (22, 25)], GOLD_D)
    s.px(16, 19, GOLD_HI)   # el de la luz; los otros dos se quedan en sombra
    # boton deslizante
    s.rect(19, 20, 23, 24, GOLD_HI)
    s.rect(19, 23, 23, 24, GOLD_D)
    s.rect(19, 20, 19, 24, GOLD_L)


def draw_scissors(s: Sprite) -> None:
    """Tijeras abiertas en aspa, con las anillas del mango en dorado."""
    cx = cy = 16
    # ---- hojas cruzadas ----
    s.line([(9, 8), (23, 24)], STEEL, width=2)
    s.line([(23, 8), (9, 24)], STEEL, width=2)
    # bisel: filo claro arriba-izq, sombra abajo-derecha
    s.line([(9, 8), (23, 24)], STEEL_DD, width=1)
    s.line([(10, 9), (21, 21)], STEEL_D, width=1)
    s.line([(23, 8), (9, 24)], STEEL_DD, width=1)
    s.line([(22, 9), (11, 21)], STEEL_D, width=1)
    # puntas afiladas
    s.poly([(9, 8), (11, 8), (10, 10)], STEEL)
    s.poly([(23, 8), (21, 8), (22, 10)], STEEL)
    s.poly([(23, 24), (23, 26), (21, 24)], STEEL)
    s.poly([(9, 24), (9, 26), (11, 24)], STEEL)
    # ---- pivote ----
    s.ellipse(14, 14, 17, 17, GOLD_D)
    s.ellipse(15, 15, 16, 16, GOLD_HI)

    # ---- anillas ----
    s.ring(3, 18, 14, 29, GOLD_D, width=3)
    s.ring(4, 19, 13, 28, GOLD, width=2)
    s.ring(18, 18, 29, 29, GOLD_D, width=3)
    s.ring(19, 19, 28, 28, GOLD, width=2)
    s.arc(4, 19, 13, 28, 170, 260, fill=GOLD_L, width=1)   # brillo
    s.arc(19, 19, 28, 28, 170, 260, fill=GOLD_L, width=1)


def draw_gloves(s: Sprite) -> None:
    """Guante de trabajo de cuero: la forma mas organica del catalogo.

    A 16 px una mano con cinco dedos sale como un borron, asi que el guante se
    lee por su silueta de tres golpes: cuatro dedos arriba, un pulgar que asoma
    a un lado y una punera ancha abajo. La punera es lo que lo distingue de un
    bolso; por eso va mas ancha que la palma y lleva remaches.
    """
    # ---- dedos: cuatro bloques arriba, separados por una muesca ----
    s.rect(7, 2, 8, 9, BROWN)       # indice
    s.rect(9, 1, 11, 9, BROWN)      # corazon
    s.rect(12, 2, 13, 9, BROWN)     # anular
    s.rect(14, 3, 15, 9, BROWN)     # menique
    # luz en el canto izquierdo de cada dedo
    s.rect(7, 2, 7, 9, BROWN_L)
    s.rect(9, 1, 9, 9, BROWN_L)
    s.rect(12, 2, 12, 9, BROWN_L)
    s.rect(14, 3, 14, 9, BROWN_L)
    s.rect(9, 1, 11, 1, BROWN_L)    # punta mas alta iluminada
    # sombra entre dedos
    s.rect(8, 3, 8, 9, BROWN_D)
    s.rect(11, 3, 11, 9, BROWN_D)
    s.rect(13, 3, 13, 9, BROWN_D)
    s.px(15, 3, BROWN_D)

    # ---- palma ----
    s.rect(6, 9, 15, 14, BROWN)
    s.rect(6, 9, 7, 14, BROWN_L)
    s.rect(14, 9, 15, 14, BROWN_D)
    s.rect(6, 13, 15, 14, BROWN_D)

    # ---- pulgar, asomando a la izquierda ----
    s.poly([(6, 10), (3, 11), (2, 15), (4, 17), (6, 16)], BROWN)
    s.poly([(6, 10), (3, 11), (2, 15), (4, 15)], BROWN_L)
    s.poly([(2, 15), (4, 17), (6, 16), (5, 15)], BROWN_D)

    # ---- punera ancha, mas ancha que la palma ----
    s.rect(4, 14, 17, 14, BROWN_L)      # canto de la punera
    s.rect(4, 15, 17, 17, BROWN)
    s.rect(4, 17, 17, 18, BROWN_D)      # sombra inferior
    s.rect(4, 15, 4, 18, BROWN_L)       # canto iluminado
    s.rect(17, 15, 17, 18, BROWN_D)
    # remaches de la punera
    s.dots([(6, 16), (10, 16), (14, 16)], GOLD_D)
    s.px(6, 16, GOLD_HI)      # el de la luz; el del medio se queda en sombra
    s.px(14, 16, GOLD_HI)
    # costura bajo el pulgar
    s.line([(3, 16), (6, 16)], GOLD_D)


def draw_crowbar(s: Sprite) -> None:
    """Palanca corta: un extremo curvado en gancho, mango con cinta."""
    # ---- varilla de acero ----
    s.line([(4, 4), (22, 22)], STEEL, width=3)
    s.line([(4, 4), (22, 22)], STEEL_DD, width=1)
    s.line([(5, 4), (23, 22)], STEEL_D, width=1)      # canto en sombra
    s.line([(4, 3), (5, 3)], STEEL)                    # punta superior
    s.px(6, 6, WHITE)                                  # brillo especular

    # ---- gancho del extremo superior ----
    s.arc(2, 2, 12, 12, 95, 200, fill=STEEL, width=3)
    s.arc(2, 2, 12, 12, 95, 200, fill=STEEL_DD, width=1)
    s.poly([(1, 6), (4, 6), (4, 10), (1, 10)], STEEL)
    s.poly([(1, 6), (4, 6), (4, 8), (1, 8)], STEEL_DD)

    # ---- mordaza / pala del extremo inferior ----
    s.poly([(20, 20), (24, 20), (29, 27), (27, 29), (22, 25)], STEEL)
    s.poly([(20, 20), (24, 20), (26, 23), (22, 23)], STEEL_DD)
    s.poly([(27, 29), (29, 27), (29, 29)], STEEL_D)

    # ---- cinta aislante en el mango ----
    s.line([(11, 11), (17, 17)], BROWN, width=5)
    s.line([(11, 10), (17, 16)], BROWN_L, width=1)
    s.line([(11, 13), (17, 19)], BROWN_D, width=1)
    # vueltas de la cinta
    s.dots([(12, 10), (14, 12), (16, 14)], BROWN_D)
    s.dots([(13, 11), (15, 13), (17, 15)], BROWN_L)

# --------------------------------------------------------------------------- #
# Objetos con variante de rareza
# --------------------------------------------------------------------------- #

def draw_card(s: Sprite, rarity: Rarity) -> None:
    """Sobre/carta: mismo esqueleto que el sprite original, tintado por rareza."""
    s.rect(6, 2, 25, 29, rarity.base)          # marco
    s.rect(6, 2, 25, 3, rarity.light)          # bisel superior
    s.rect(6, 28, 25, 29, rarity.dark)         # bisel inferior
    s.rect(8, 4, 23, 27, BROWN_D)              # hueco
    s.rect(9, 5, 22, 26, BROWN)                # panel interior
    s.rect(9, 5, 22, 6, BROWN_L)               # bisel del panel
    s.dots([(9, 5), (21, 5), (9, 25), (21, 25)], TEAL)   # esquinas
    s.rect(10, 9, 21, 22, GOLD_D)              # marco del medallon
    s.rect(10, 9, 21, 10, GOLD_L)
    s.rect(11, 10, 20, 21, BROWN_D)            # fondo del medallon
    draw_gem(s, 16, 16, 4, rarity)


# --------------------------------------------------------------------------- #
# Las cuatro cartas coleccionables
# --------------------------------------------------------------------------- #
#
# Hasta ahora havia UNA carta teñida por rareza: las cuatro Sprites eran el
# mismo dibujo con el marco y la gema de otro color (un 79% de los pixeles era
# identico entre ellas). Abrir 200 sobres sacaba siempre la misma carta en
# cuatro paletas.
#
# Ahora son cuatro dibujos de verdad, y cada uno lleva su propia rareza: asi el
# paquete de cartas conserva exactamente la misma estructura de probabilidades y
# los mismos valores de antes, pero de verdad hay cuatro cosas distintas.
#
# Las cuatro comparten esqueleto (x 6..25, y 2..29) para que se lean como una
# familia. La rareza la pone el diseno, no un tinte encima.

CARD_X0, CARD_X1 = 6, 25
CARD_Y0, CARD_Y1 = 2, 29


def draw_card_common(s: Sprite) -> None:
    """Carta basica: carton sin adornos, una piedra en el medallon."""
    s.rect(CARD_X0, CARD_Y0, CARD_X1, CARD_Y1, CARD)
    s.rect(CARD_X0, CARD_Y0, CARD_X1, 3, CARD_L)
    s.rect(CARD_X0, 28, CARD_X1, 29, BROWN_D)
    s.rect(7, 4, 24, 27, BROWN_D)
    s.rect(8, 5, 23, 26, BROWN)
    s.rect(8, 5, 23, 6, BROWN_L)
    s.dots([(8, 5), (23, 5), (8, 26), (23, 26)], GOLD_D)
    s.rect(11, 10, 20, 21, GOLD_D)
    s.rect(11, 10, 20, 11, GOLD)
    s.rect(12, 11, 19, 20, BROWN_D)
    s.ellipse(14, 13, 17, 16, STEEL_D)     # la piedra
    s.ellipse(14, 13, 16, 15, STEEL)
    s.px(15, 14, WHITE)


def draw_card_edited(s: Sprite) -> None:
    """Edicion limitada: marco dorado fino, arte claro, serie numerada y sello."""
    s.rect(7, 2, 24, 29, GOLD_D)
    s.rect(7, 2, 24, 3, GOLD)
    s.rect(7, 28, 24, 29, shade(GOLD_D, -0.3))
    s.rect(8, 4, 23, 26, NIGHT_D)
    s.rect(8, 4, 23, 5, NIGHT_L)
    s.rect(10, 7, 21, 18, CREAM)          # arte
    s.rect(10, 7, 21, 8, CREAM_L)
    s.dots([(10, 7), (21, 7), (10, 18), (21, 18)], GOLD)
    s.rect(10, 20, 21, 21, GOLD_D)        # banda de serie
    s.dots([(11, 20), (13, 20), (15, 20), (17, 20), (19, 20), (21, 20)], GOLD_L)
    s.ellipse(17, 12, 21, 16, RED)         # sello de edicion
    s.ellipse(18, 13, 20, 15, RED_L)


def draw_card_vintage(s: Sprite) -> None:
    """Carta vieja: tono sepia, filigrana en el marco y un retrato dentro.

    El tono viejo va en el DIBULO y no en el desgaste: una vintage es vieja por
    definicion, asi que su PSA 10 es "mint para su edad", no "sin usar".
    """
    s.rect(CARD_X0, CARD_Y0, CARD_X1, CARD_Y1, CARD_L)
    s.rect(CARD_X0, CARD_Y0, CARD_X1, 3, CREAM_D)
    s.rect(CARD_X0, 28, CARD_X1, 29, BROWN_D)
    s.rect(7, 4, 24, 27, BROWN)
    s.rect(8, 5, 23, 26, CARD)
    s.rect(8, 5, 23, 6, CARD_L)
    # filigrana del marco
    s.dots([(9, 3), (12, 3), (15, 3), (18, 3), (21, 3)], BROWN_D)
    s.dots([(9, 28), (12, 28), (15, 28), (18, 28), (21, 28)], BROWN_D)
    s.dots([(7, 8), (7, 12), (7, 16), (7, 20), (7, 24)], BROWN_D)
    s.dots([(24, 8), (24, 12), (24, 16), (24, 20), (24, 24)], BROWN_D)
    # retrato: cabeza y hombros
    s.ellipse(14, 10, 17, 13, BROWN_D)
    s.ellipse(14, 10, 16, 12, BROWN)
    s.poly([(11, 21), (13, 16), (18, 16), (20, 21)], BROWN_D)


def draw_card_foil(s: Sprite) -> None:
    """Holografica: bandas de foil en diagonal sobre el interior oscuro.

    El arcoiris se falsea con cuatro colores de la paleta en bandas. Pintarlo de
    verdad con seis tonos de verdad seria justo el tipo de color que el auditor
    marca como colado de otra fuente.
    """
    s.rect(CARD_X0, CARD_Y0, CARD_X1, CARD_Y1, TEAL_D)
    s.rect(CARD_X0, CARD_Y0, CARD_X1, 3, TEAL_L)
    s.rect(CARD_X0, 28, CARD_X1, 29, NIGHT_DD)
    s.rect(7, 4, 24, 27, NIGHT)
    bandas = (TEAL_L, CREAM, GOLD_XL, GOLD_L)
    for y in range(5, 27):
        t = int((y - 5) * 0.5)
        for x in range(9, 23):
            s.px(x, y, bandas[(((x - 9) - t) // 3) % 4])
    s.rect(8, 4, 23, 5, NIGHT_LL)          # borde del hueco
    s.rect(8, 26, 23, 27, NIGHT_DD)
    s.dots([(9, 5), (22, 5), (9, 26), (22, 26)], WHITE)
    s.dots([(12, 8), (20, 23), (15, 16)], SHINE_HI)   # destellos


def draw_rarity_gem(s: Sprite, rarity: Rarity) -> None:
    draw_gem(s, 16, 16, 13, rarity)


def draw_rarity_glow(s: Sprite, rarity: Rarity) -> None:
    """Aura radial suave bajo el botin, del color de su rareza.

    El alfa se calcula pixel a pixel segun la distancia al centro, no apilando
    elipses: apiladas salian anillos duros, porque cada elipse pinta su alfa
    entera y el borde de la siguiente se nota como un escalon. Con el degradado
    continuo el halo va del nucleo claro al transparente sin cortes.

    El color va de una version aclarada del tono de la rareza en el centro al
    tono base en el borde, asi que el aura tiene nucleo en vez de ser una mancha
    plana. Se aclara con shade() a proposito: el auditor solo admite colores de
    la paleta y sus derivados, y un blend a mano se saldria de la rejilla.

    El juego modula este sprite con BLANCO (solo el alfa): el color de la rareza
    ya viene aqui, asi que tintarlo otra vez solo lo oscurecia.
    """
    s.want_outline = False          # es un aura: sin contorno, por diseno
    cx = cy = (s.w - 1) / 2.0
    reach = 15.6                    # radio donde el alfa llega a cero
    core = 6.0                      # radio del nucleo aclarado
    strength = 0.95                 # alfa maxima, en el centro

    for y in range(s.h):
        for x in range(s.w):
            d = math.hypot(x - cx, y - cy)
            t = 1.0 - d / reach
            if t <= 0.0:
                continue
            alpha = int((t ** 1.7) * strength * 255.0)
            if alpha <= 0:
                continue
            k = round(max(0.0, min(0.5, (1.0 - d / core) * 0.5)), 2)
            col = shade(rarity.glow, k)
            s.px(x, y, (col[0], col[1], col[2], alpha))


# --------------------------------------------------------------------------- #
# Pantalla de inicio: placas de boton e iconos
# --------------------------------------------------------------------------- #

def draw_button_plate(s: Sprite, pressed: bool = False) -> None:
    """Placa de boton vacia (24x8 px de arte). El texto lo pone Godot encima.

    Pensada para rebanado en 9: el centro es plano, asi que se puede estirar.
    """
    w, h = s.w, s.h
    inset = 1 if pressed else 0        # al pulsar, el contenido baja 1px

    s.rect(1, 1, w - 2, h - 2, GOLD_D if pressed else GOLD_L)   # aro exterior
    s.rect(2, 2, w - 3, h - 3, GOLD_D)                          # aro interior

    body_top = 3 + inset
    s.rect(3, body_top, w - 4, h - 4, BROWN_D)                  # cuerpo
    s.rect(3, body_top, w - 4, h - 5, BROWN)
    if not pressed:
        s.rect(3, 3, w - 4, 4, BROWN_L)                         # bisel superior

    # esquinas redondeadas + remaches
    for cx, cy in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        s.px(cx, cy, TRANSPARENT)
    s.dots([(6, 6), (w - 7, 6), (6, h - 7), (w - 7, h - 7)],
           GOLD_D if pressed else GOLD)


def draw_icon_play(s: Sprite) -> None:
    """Triangulo de reproducir con bisel a lo largo de los dos bordes."""
    # el glifo deja aire alrededor para que encaje dentro del marco de la placa
    s.poly([(4, 4), (11, 8), (4, 12)], GOLD)
    s.line([(5, 5), (10, 7)], GOLD_HI, width=2)     # borde superior iluminado
    s.line([(5, 11), (9, 9)], GOLD_D, width=2)      # borde inferior en sombra


def draw_icon_settings(s: Sprite) -> None:
    """Engranaje de ocho dientes.

    Se dibuja pixel a pixel con un perfil de radio que oscila con el angulo
    (coseno de 8 lobulos): asi los dientes nacen del cuerpo y el resultado sale
    limpio a esta resolucion, en vez de embotarse como al unir circulos y lineas.
    """
    cx = cy = 7.5
    hueco, cuerpo, diente = 1.5, 2.8, 2.2

    for y in range(s.h):
        for x in range(s.w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r < hueco:
                continue
            ang = math.atan2(dy, dx)
            exterior = cuerpo + diente * (0.5 + 0.5 * math.cos(8 * ang))
            if r > exterior:
                continue
            grados = math.degrees(ang) % 360
            if 200 <= grados <= 250:
                s.px(x, y, GOLD_HI)     # luz desde arriba-izquierda
            elif 20 <= grados <= 70:
                s.px(x, y, GOLD_D)      # sombra abajo-derecha
            else:
                s.px(x, y, GOLD)


# --------------------------------------------------------------------------- #
# Numeros (fuente de pixel art, patrones en font_patterns.py)
# --------------------------------------------------------------------------- #

FONT_CELL_W, FONT_CELL_H = 8, 12     # celda de cada glifo (deja sitio al contorno)
FONT_PAD_X, FONT_PAD_Y = 1, 2
FONT_SCALE = 8                       # la mitad que los sprites: a escala 16 serian enormes


def stamp_glyph(s: Sprite, pattern: Sequence[str], ox: int = 0, oy: int = 0,
                color: Optional[RGBA] = None) -> None:
    """Pinta un patron 5x7 con bisel vertical, desplazado (ox, oy).

    `color` fuerza un tono plano en vez del bisel dorado. Hace falta cuando el
    glifo va sobre un fondo del mismo color: el bisel se perderia y el numero
    no se leeria (el 7 de la edicion numerada, dorado sobre rojo).
    """
    if color is not None:
        for row, linea in enumerate(pattern):
            for col, ch in enumerate(linea):
                if ch == "1":
                    s.px(ox + FONT_PAD_X + col, oy + FONT_PAD_Y + row, color)
        return
    ancho = len(pattern[0])
    topes: Dict[int, int] = {}
    fondos: Dict[int, int] = {}
    for col in range(ancho):
        filas = [r for r in range(len(pattern)) if pattern[r][col] == "1"]
        if filas:
            topes[col] = filas[0]
            fondos[col] = filas[-1]

    for row, linea in enumerate(pattern):
        for col, ch in enumerate(linea):
            if ch != "1":
                continue
            if row == topes.get(col):
                color = GOLD_HI
            elif row == fondos.get(col):
                color = GOLD_D
            else:
                color = GOLD
            s.px(ox + FONT_PAD_X + col, oy + FONT_PAD_Y + row, color)


def draw_font_glyph(s: Sprite, key: str) -> None:
    stamp_glyph(s, GLYPHS[key])


def draw_font_sheet(s: Sprite) -> None:
    """Todos los glifos en fila, para importarlos como fuente de mapa de bits."""
    for i, key in enumerate(FONT_ORDER):
        stamp_glyph(s, GLYPHS[key], ox=i * FONT_CELL_W)


# --------------------------------------------------------------------------- #
# Las 4 habilidades principales
# --------------------------------------------------------------------------- #

def draw_skill_diamond(s: Sprite) -> None:
    """Diamante: calidad del botin."""
    s.poly([(5, 3), (11, 3), (13, 6), (3, 6)], TEAL)          # corona
    s.poly([(3, 6), (13, 6), (8, 14)], TEAL_D)                # pabellon
    s.poly([(8, 6), (13, 6), (8, 14)], TEAL)                  # mitad derecha
    s.poly([(5, 3), (11, 3), (9, 5), (7, 5)], TEAL_L)         # mesa
    s.poly([(5, 3), (7, 5), (3, 6)], TEAL_L)
    s.dots([(6, 4), (7, 4)], WHITE)


def draw_skill_lightning(s: Sprite) -> None:
    """Rayo: velocidad de apertura.

    El rayo va de y=2 a y=14 en un lienzo de 16, para que el contorno de 1 px que
    anade render() quepa entero. Con los vertices en 1 y 15 se salia del canvas.
    """
    s.poly([(9, 2), (4, 9), (7, 9), (5, 14), (12, 6), (9, 6)], GOLD_XL)
    s.poly([(9, 2), (4, 9), (6, 9), (9, 4)], GOLD_HI)         # filo iluminado
    s.poly([(7, 9), (5, 14), (12, 6), (10, 6)], GOLD_D)       # rama en sombra


def draw_skill_dollar(s: Sprite) -> None:
    """Simbolo de dolar: ganancias."""
    s.rect(7, 1, 8, 14, GOLD_D)          # barra vertical
    s.rect(7, 1, 7, 14, GOLD_L)
    stamp_glyph(s, DOLLAR_S, ox=4, oy=1)  # la S encima


def _point_in_triangle(p: Tuple[float, float], a: Tuple[float, float],
                       b: Tuple[float, float], c: Tuple[float, float]) -> bool:
    """Si el punto p cae dentro (o en el borde) del triangulo a-b-c."""
    def _side(p1: Tuple[float, float], p2: Tuple[float, float],
              p3: Tuple[float, float]) -> float:
        return ((p1[0] - p3[0]) * (p2[1] - p3[1])
                - (p2[0] - p3[0]) * (p1[1] - p3[1]))
    d1, d2, d3 = _side(p, a, b), _side(p, b, c), _side(p, c, a)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)


def draw_skill_cycle(s: Sprite) -> None:
    """Tres flechas curvas persiguiendose en circulo: reinicio / Rebirth.

    Cada flecha es un arco con una punta triangular en su extremo, y las tres
    van separadas: entre la punta de una y la cola de la siguiente queda un
    hueco, asi que no se tocan y se leen como tres flechas y no como un anillo.

    Se dibuja a 32x32 en vez de a 16x16 como sus hermanas porque a 16 no caben
    tres flechas legibles una vez anadido el contorno de 1 px: salia un anillo
    roto con bultos. El UiSpec lo saca a 256 con scale=8, asi que el archivo
    mide lo mismo que los otros tres iconos de habilidad.
    """
    cx = cy = (s.w - 1) / 2.0
    radius = 11.0       # radio de la linea media del arco
    half = 1.0          # medio grosor -> arco de 2 px de arte
    span = 70.0         # grados de arco que ocupa cada flecha
    gap = 50.0          # grados de hueco hasta la cola de la siguiente
    head_len = 4.5      # cuanto sobresale la punta por delante del arco
    head_half = 3.6     # media anchura de la base de la punta

    for k in range(3):
        tail = 270.0 + float(k) * (span + gap)
        head = tail + span
        for y in range(s.h):
            for x in range(s.w):
                d = math.hypot(x - cx, y - cy)
                if abs(d - radius) > half:
                    continue
                ang = math.degrees(math.atan2(y - cy, x - cx)) % 360.0
                if (ang - tail) % 360.0 <= span:
                    # tres tonos: canto exterior en sombra, cuerpo en el oro base
                    s.px(x, y, GOLD if d < radius else GOLD_D)

        # Punta: triangulo con la base radial y el vertice hacia delante, de
        # modo que apunta en el sentido de la marcha (horario).
        t = math.radians(head)
        bx = cx + radius * math.cos(t)
        by = cy + radius * math.sin(t)
        tx, ty = -math.sin(t), math.cos(t)      # tangente (sentido horario)
        nx, ny = math.cos(t), math.sin(t)       # normal (radial)
        tip = (bx + tx * head_len, by + ty * head_len)
        b1 = (bx - nx * head_half, by - ny * head_half)
        b2 = (bx + nx * head_half, by + ny * head_half)
        for y in range(s.h):
            for x in range(s.w):
                if _point_in_triangle((x, y), tip, b1, b2):
                    s.px(x, y, GOLD_XL)


# --------------------------------------------------------------------------- #
# Insignias de estado de conservacion
#
# El documento aplica un multiplicador al valor final segun el estado del
# objeto, asi que son cuatro insignias pequenas que se superponen en la ficha.
# Todas son el mismo disco con un simbolo distinto, para que en la ficha del
# objeto se lean como una misma familia.
# --------------------------------------------------------------------------- #

def _badge_disc(s: Sprite, dark: RGBA, base: RGBA, light: RGBA) -> None:
    """Disco de la insignia, con aro oscuro y brillo arriba-izquierda."""
    s.ellipse(3, 3, 12, 12, dark)          # aro exterior
    s.ellipse(4, 4, 11, 11, base)          # cuerpo
    s.ellipse(5, 5, 9, 8, light)           # brillo superior
    s.arc(4, 4, 11, 11, 200, 300, fill=light, width=1)   # canto iluminado
    s.dots([(5, 5), (5, 6)], WHITE)        # especular


def draw_condition_mint(s: Sprite) -> None:
    """Mint: turquesa, con un destello de cuatro puntas."""
    _badge_disc(s, TEAL_D, TEAL, TEAL_L)
    s.poly([(7, 5), (8, 7), (10, 8), (8, 9), (7, 11), (6, 9), (4, 8), (6, 7)], WHITE)
    s.px(7, 8, TEAL_L)


def draw_condition_good(s: Sprite) -> None:
    """Good: verde, con una marca de verificacion."""
    _badge_disc(s, GREEN_D, GREEN, GREEN_L)
    s.line([(5, 8), (7, 10)], WHITE, width=2)
    s.line([(7, 10), (10, 5)], WHITE, width=2)


def draw_condition_worn(s: Sprite) -> None:
    """Worn: dorado apagado, con una grieta fina."""
    _badge_disc(s, GOLD_D, shade(GOLD_D, 0.10), shade(GOLD_D, 0.28))
    s.line([(7, 4), (6, 7), (8, 9), (7, 11)], DARK)     # grieta irregular
    s.px(7, 4, BROWN_D)


def draw_condition_broken(s: Sprite) -> None:
    """Broken: rojo oscuro, con una grieta grande y dentada."""
    _badge_disc(s, RED_D, RED, RED_L)
    s.poly([(7, 3), (8, 6), (6, 7), (9, 9), (7, 12)], CRACK_D)
    s.poly([(9, 6), (10, 8), (8, 9), (10, 11)], CRACK_D)  # dientes
    s.px(7, 5, RED_L)


# --------------------------------------------------------------------------- #
# Kit de interfaz (tienda y configuracion)
# --------------------------------------------------------------------------- #

PANEL_9SLICE = 8        # margen de rebanado en 9, en px de arte (= 128 px a escala 16)


def draw_panel(s: Sprite, body: RGBA) -> None:
    """Marco de ventana rebanable en 9: el centro es plano, asi que se estira."""
    w, h = s.w, s.h
    s.rect(1, 1, w - 2, h - 2, GOLD_D)
    s.rect(2, 2, w - 3, h - 3, GOLD_L)
    s.rect(3, 3, w - 4, h - 4, GOLD_D)
    s.rect(4, 4, w - 5, h - 5, body)
    s.rect(4, 4, w - 5, 4, shade(body, 0.20))        # bisel superior
    s.rect(4, h - 5, w - 5, h - 5, shade(body, -0.30))
    s.dots([(6, 6), (w - 7, 6), (6, h - 7), (w - 7, h - 7)], GOLD)
    for cx, cy in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        s.px(cx, cy, TRANSPARENT)


def draw_slot(s: Sprite) -> None:
    """Ranura de objeto vacia del inventario y de la tienda."""
    w, h = s.w, s.h
    s.rect(1, 1, w - 2, h - 2, GOLD_D)
    s.rect(2, 2, w - 3, h - 3, shade(BROWN_D, -0.2))
    s.rect(3, 3, w - 4, h - 4, WOOD_M)
    s.rect(3, 3, w - 4, 4, WOOD_DD)        # sombra interior
    s.rect(3, 3, 4, h - 4, WOOD_DD)
    s.rect(3, h - 5, w - 4, h - 4, shade(BROWN_L, -0.1))
    for cx, cy in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        s.px(cx, cy, TRANSPARENT)


def draw_button_small(s: Sprite, pressed: bool = False) -> None:
    """Boton compacto para acciones dentro de un panel (comprar, equipar...)."""
    w, h = s.w, s.h
    inset = 1 if pressed else 0
    s.rect(1, 1, w - 2, h - 2, GOLD_D if pressed else GOLD_L)
    s.rect(2, 2, w - 3, h - 3, GOLD_D)
    s.rect(3, 3 + inset, w - 4, h - 4, BROWN_D)
    s.rect(3, 3 + inset, w - 4, h - 5, BROWN)
    if not pressed:
        s.rect(3, 3, w - 4, 3, BROWN_L)
    for cx, cy in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        s.px(cx, cy, TRANSPARENT)


def draw_button_close(s: Sprite) -> None:
    """Boton redondo de cerrar (aspa)."""
    d = s.w
    s.ellipse(1, 1, d - 2, d - 2, GOLD_D)
    s.ellipse(2, 2, d - 3, d - 3, RUST_D)
    s.d.arc([2, 2, d - 3, d - 3], 185, 275, fill=RUST_L, width=2)  # brillo
    # el aspa necesita recorrido de sobra: con trazos cortos se embota en un borron
    mid = d // 2
    s.line([(mid - 4, mid - 4), (mid + 3, mid + 3)], CREAM, width=2)
    s.line([(mid + 3, mid - 4), (mid - 4, mid + 3)], CREAM, width=2)


def draw_checkbox(s: Sprite, checked: bool) -> None:
    """Casilla de marcar, para los ajustes."""
    w, h = s.w, s.h
    s.rect(1, 1, w - 2, h - 2, GOLD_D)
    s.rect(2, 2, w - 3, h - 3, WOOD_D)
    if checked:
        s.rect(3, 3, w - 4, h - 4, GOLD)
        s.rect(3, 3, w - 4, 3, GOLD_HI)
        s.rect(3, h - 4, w - 4, h - 4, GOLD_D)
        s.dots([(4, 5), (5, 6), (6, 6), (7, 5), (7, 4)], WOOD_D)
    for cx, cy in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        s.px(cx, cy, TRANSPARENT)


def draw_slider_track(s: Sprite) -> None:
    """Canaleta del deslizador de volumen."""
    w, h = s.w, s.h
    s.rect(1, 1, w - 2, h - 2, WOOD_L)
    s.rect(1, 1, w - 2, 1, WOOD_DD)
    s.rect(1, h - 2, w - 2, h - 2, BROWN_L)


def draw_slider_knob(s: Sprite) -> None:
    """Mando del deslizador."""
    w, h = s.w, s.h
    s.rect(1, 1, w - 2, h - 2, GOLD_D)
    s.rect(1, 1, w - 2, 2, GOLD_L)
    s.rect(2, 3, w - 3, h - 4, BROWN)
    s.rect(2, 3, w - 3, 3, BROWN_L)
    s.rect(w // 2 - 1, 5, w // 2, h - 6, WOOD_D)
    for cx, cy in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        s.px(cx, cy, TRANSPARENT)


def draw_arrow(s: Sprite, direction: str) -> None:
    """Flecha de navegacion (pagina siguiente / anterior)."""
    if direction == "right":
        s.poly([(2, 1), (2, 8), (8, 5)], GOLD)
        s.poly([(3, 3), (3, 5), (6, 5)], GOLD_HI)
        s.poly([(3, 7), (3, 5), (6, 5)], GOLD_D)
    else:
        s.poly([(8, 1), (8, 8), (2, 5)], GOLD)
        s.poly([(7, 3), (7, 5), (4, 5)], GOLD_HI)
        s.poly([(7, 7), (7, 5), (4, 5)], GOLD_D)


def draw_icon_shop(s: Sprite) -> None:
    """Bolsa de la compra, para el boton de la tienda."""
    s.d.arc([5, 1, 11, 7], 180, 360, fill=GOLD, width=2)
    s.poly([(3, 5), (13, 5), (12, 13), (4, 13)], BROWN)
    s.rect(3, 5, 13, 6, BROWN_L)
    s.rect(4, 13, 12, 13, shade(BROWN, -0.4))
    s.rect(3, 9, 13, 10, GOLD_D)
    s.rect(3, 9, 13, 9, GOLD)


def draw_icon_sound(s: Sprite) -> None:
    """Altavoz con ondas, para el ajuste de efectos de sonido."""
    s.poly([(2, 6), (5, 6), (8, 3), (8, 12), (5, 9), (2, 9)], GOLD)
    s.rect(2, 6, 5, 6, GOLD_HI)         # bisel del altavoz
    s.rect(2, 9, 5, 9, GOLD_D)
    s.rect(2, 6, 2, 9, GOLD_HI)
    s.d.arc([8, 4, 12, 11], 300, 420, fill=GOLD_L, width=2)     # onda interior
    s.d.arc([10, 3, 14, 12], 300, 420, fill=GOLD_D, width=2)    # onda exterior


def draw_icon_music(s: Sprite) -> None:
    """Nota musical, para el ajuste de musica."""
    s.rect(9, 2, 10, 11, GOLD)
    s.rect(9, 2, 13, 3, GOLD)
    s.rect(9, 2, 9, 3, GOLD_HI)
    s.ellipse(5, 9, 10, 13, GOLD)
    s.ellipse(6, 10, 9, 12, GOLD_HI)


def draw_icon_plus(s: Sprite) -> None:
    """Signo mas, para el boton de comprar mejora."""
    s.rect(6, 2, 9, 13, GOLD)
    s.rect(2, 6, 13, 9, GOLD)
    s.rect(6, 2, 7, 13, GOLD_HI)
    s.rect(2, 6, 13, 7, GOLD_HI)
    s.rect(8, 8, 9, 13, GOLD_D)
    s.rect(8, 8, 13, 9, GOLD_D)


# --------------------------------------------------------------------------- #
# Iconos de interfaz de segunda generacion
#
# Los quezelos que quedaban pendientes en PROMPTS.md. Todos reutilizan las
# piezas que ya habia (arcos de draw_skill_cycle, cuerpo de draw_icon_shop,
# aro de draw_panel) en vez de dibujar de cero, para que compartan silueta.
# --------------------------------------------------------------------------- #

def _repeat_badge(s: Sprite, cx: int, cy: int) -> None:
    """Insignia de repeticion en una esquina: dos flechas circulares.

    Sin chapa de fondo. La primera version llenaba un disco negro que tapaba el
    objeto entero; no hace falta porque el contorno que anade render() ya separa
    las flechas de lo que haya debajo, igual que separa cualquier otra pieza.

    El centro se queda en cx=10: las puntas asoman 1 px fuera del arco y con 11
    el extremo derecho se salia del lienzo de 16.
    """
    r = 3
    box = (cx - r, cy - r, cx + r, cy + r)
    s.arc(*box, 205, 335, fill=GOLD, width=1)
    s.arc(*box, 25, 155, fill=GOLD, width=1)
    s.poly([(cx + r - 1, cy - r), (cx + r + 1, cy - r), (cx + r, cy - r + 3)], GOLD_XL)
    s.poly([(cx - r - 1, cy + r), (cx - r + 1, cy + r), (cx - r, cy - r + 3)], GOLD_XL)


def draw_icon_auto_open(s: Sprite) -> None:
    """Auto open: un sobre abierto del que asoma una carta."""
    # ---- carta asomando por la abertura ----
    s.rect(5, 4, 10, 9, CREAM)
    s.rect(5, 4, 10, 4, WHITE)
    s.rect(5, 6, 10, 6, CREAM_D)
    s.px(7, 5, TEAL)
    # ---- solapa levantada ----
    s.poly([(2, 9), (5, 6), (11, 6), (12, 9)], BROWN_L)
    s.line([(3, 8), (11, 8)], BROWN_D)
    s.line([(2, 9), (12, 9)], GOLD_D)
    # ---- cuerpo del sobre ----
    s.poly([(2, 9), (12, 9), (11, 14), (3, 14)], BROWN)
    s.poly([(2, 9), (12, 9), (12, 10), (2, 10)], BROWN_D)
    s.poly([(3, 13), (11, 13), (11, 14), (3, 14)], BROWN_D)
    s.line([(7, 10), (7, 13)], BROWN_D)
    # ---- insignia de automatico, esquina superior derecha ----
    _repeat_badge(s, 10, 4)


def draw_icon_auto_buy(s: Sprite) -> None:
    """Auto buy: la bolsa de la compra."""
    # ---- asas ----
    s.arc(4, 4, 10, 10, 180, 360, fill=GOLD_D, width=2)
    s.arc(4, 4, 10, 10, 180, 360, fill=GOLD, width=1)
    # ---- cuerpo de la bolsa ----
    s.poly([(2, 8), (12, 8), (11, 14), (3, 14)], BROWN)
    s.poly([(2, 8), (12, 8), (12, 9), (2, 9)], BROWN_L)
    s.poly([(3, 13), (11, 13), (11, 14), (3, 14)], BROWN_D)
    s.rect(2, 10, 12, 10, GOLD)                          # banda dorada
    s.rect(2, 11, 12, 11, GOLD_D)
    # ---- insignia de automatico, esquina superior derecha ----
    _repeat_badge(s, 10, 4)


def draw_icon_achievement(s: Sprite) -> None:
    """Trofeo dorado con base de madera y destellos."""
    # ---- base ----
    s.rect(4, 13, 12, 14, BROWN_D)
    s.rect(4, 13, 12, 13, BROWN)
    s.rect(3, 14, 13, 14, BROWN_L)
    # ---- columna ----
    s.rect(7, 10, 9, 13, GOLD_D)
    s.rect(7, 10, 7, 13, GOLD)
    # ---- copa ----
    s.poly([(4, 4), (12, 4), (11, 9), (8, 11), (5, 9)], GOLD)
    s.poly([(4, 4), (12, 4), (12, 5), (4, 5)], GOLD_L)
    s.poly([(5, 8), (11, 8), (11, 9), (8, 11), (5, 9)], GOLD_D)
    # asas
    s.ring(1, 4, 5, 8, GOLD_D, width=1)
    s.ring(11, 4, 14, 8, GOLD_D, width=1)
    # ---- destellos: dos estrellas de cuatro puntas ----
    for sx, sy in ((3, 2), (13, 2)):
        s.px(sx, sy, WHITE)
        s.px(sx - 1, sy, GOLD_XL)
        s.px(sx + 1, sy, GOLD_XL)
        s.px(sx, sy - 1, GOLD_XL)
        s.px(sx, sy + 1, GOLD_XL)


def draw_icon_market_event(s: Sprite) -> None:
    """Grafico ascendente dorado con una moneda en la punta de la flecha."""
    # ---- ejes ----
    s.line([(2, 2), (2, 14)], STEEL_D, width=1)
    s.line([(2, 14), (14, 14)], STEEL_D, width=1)
    # ---- linea ascendente ----
    s.line([(3, 12), (6, 9), (9, 11), (12, 5)], GOLD, width=2)
    s.line([(3, 11), (6, 8), (9, 10), (12, 4)], GOLD_HI, width=1)
    # punta de la flecha
    s.poly([(12, 4), (14, 4), (14, 6)], GOLD_XL)
    # ---- moneda en la punta ----
    s.ellipse(10, 2, 14, 6, GOLD_D)
    s.ellipse(11, 3, 13, 5, GOLD_XL)
    s.px(12, 3, GOLD_HI)
    # ---- barras de fondo ----
    s.rect(4, 13, 5, 14, GOLD_D)
    s.rect(7, 13, 8, 14, GOLD_D)
    s.rect(10, 13, 11, 14, GOLD_D)


def draw_icon_inventory(s: Sprite) -> None:
    """Rejilla de 3x3 casillas con bordes dorados (el icono de inventario)."""
    for gy in range(3):
        for gx in range(3):
            x, y = 2 + gx * 4, 2 + gy * 4
            s.rect(x, y, x + 3, y + 3, GOLD_D)          # marco
            s.rect(x + 1, y + 1, x + 2, y + 2, BROWN_D)  # hueco
    # casillas llenas alternas, para que no sea un rejiyon vacio
    s.rect(3, 3, 4, 4, GOLD)
    s.rect(7, 7, 8, 8, GOLD)
    s.rect(11, 11, 12, 12, GOLD)
    s.rect(11, 3, 12, 4, TEAL)      # una de acento turquesa
    s.rect(3, 11, 4, 12, GOLD_HI)


def draw_icon_display_case(s: Sprite) -> None:
    """Vitrina de cristal pequena con un estante interior dorado."""
    # ---- peana ----
    s.rect(3, 13, 13, 14, BROWN_D)
    s.rect(3, 13, 13, 13, BROWN)
    s.rect(4, 12, 12, 12, BROWN_L)
    # ---- montantes y tapa ----
    s.rect(2, 2, 3, 12, GOLD_D)      # montante izquierdo
    s.rect(13, 2, 14, 12, GOLD_D)    # montante derecho
    s.rect(2, 2, 14, 3, GOLD)        # tapa
    s.rect(2, 2, 14, 2, GOLD_L)      # brillo de la tapa
    s.rect(2, 3, 14, 3, GOLD_D)
    # ---- estante interior ----
    s.rect(4, 8, 12, 9, GOLD_XL)     # balda dorada
    s.rect(4, 9, 12, 9, GOLD_D)
    # ---- cristal (velo turquesa muy suave) ----
    s.rect(4, 4, 12, 7, TEAL_D)
    s.rect(4, 4, 12, 4, TEAL)
    s.dots([(5, 5), (5, 6)], TEAL_L)  # reflejo en el vidrio


def draw_icon_vitrine(s: Sprite) -> None:
    """Estanteria de exposicion con tres baldas y un objeto en cada una."""
    # ---- marco ----
    s.rect(2, 1, 3, 14, BROWN_D)      # montante izquierdo
    s.rect(13, 1, 14, 14, BROWN_D)    # montante derecho
    s.rect(2, 1, 14, 2, BROWN)        # travesano superior
    s.rect(2, 1, 14, 1, BROWN_L)
    # ---- baldas ----
    for y in (5, 9, 13):
        s.rect(3, y, 13, y, GOLD_XL)
        s.rect(3, y + 1, 13, y + 1, GOLD_D)
    # ---- un objeto dorado en cada balda ----
    for x, y, w in ((5, 3, 3), (9, 7, 4), (6, 11, 3)):
        s.rect(x, y, x + w, y + 1, GOLD)
        s.rect(x, y, x + w, y, GOLD_L)
        s.rect(x, y + 1, x + w, y + 1, GOLD_D)
    # un toque turquesa en el objeto del medio
    s.px(11, 7, TEAL_L)
    s.px(10, 8, TEAL)


# --------------------------------------------------------------------------- #
# Registro
# --------------------------------------------------------------------------- #

# --------------------------------------------------------------------------- #
# Desgaste por nota PSA
# --------------------------------------------------------------------------- #
#
# Un objeto de botin no tiene un solo sprite, tiene DIEZ: uno por nota PSA, de 1
# a 10. La nota 10 es el objeto intacto y la 1 es un cascote. Todas las
# variantes salen del MISMO dibujo base con una capa de desgaste encima, asi que
# cuando se toca el dibujo del objeto solo hay que tocarlo en un sitio.
#
# El desgaste es acumulativo y va por tramos, para que se lea de un vistazo sin
# tener que mirar el numero:
#
#   10  intacto
#    9  mugre
#    8  mugre + arañazos
#    7  + desgaste de canto (el perfil, aclarado)
#    6  mugre densa
#    5  + mellas en el perfil
#    4  arañazos profundos
#    3  + manchas
#    2  + grietas
#    1  esquinas comidas y grieta abierta
#
# La semilla es fija por (objeto, nota). Sin eso, regenerar el catalogo daria
# un dibujo distinto cada vez y no se podrian comparar dos notas entre si.

PSA_MIN, PSA_MAX = 1, 10


def _alpha_grid(s: Sprite) -> List[int]:
    """Los alfas del lienzo en una lista mutable, para no llamar a getpixel()
    en los 1024 pixeles. Los pixelos borrados actualizan la misma lista, asi que
    las etapas de desgaste posteriores los ven como huecos."""
    return list(s.img.getchannel("A").tobytes())


def _edge_where(alpha: Sequence[int], w: int, h: int, band: int) -> set:
    """Pixeles opacos que tienen un vecino transparente a `band` de distancia."""
    out = set()
    for y in range(h):
        for x in range(w):
            if not alpha[y * w + x]:
                continue
            for dy in range(-band, band + 1):
                for dx in range(-band, band + 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not alpha[ny * w + nx]:
                        out.add((x, y))
                        break
                else:
                    continue
                break
    return out


def _away_from_mid(color: RGBA, k: float) -> float:
    """Cuanto tinte hace falta para que algo se vea sobre ESTE color.

    La mugre sobre un cuerpo oscuro (un vinilo) se ve aclarando; sobre uno claro
    (una caja) oscureciendo. Sin esto, el desgaste solo se veria en la mitad
    clara del catalogo.
    """
    r, g, b, _ = color
    return k if (r + g + b) / 3.0 < 110.0 else -k


class Wear:
    """Aplica tintes y picados guardando el color de paleta original.

    Importa: el auditor solo admite shade() de un color de la paleta. Si se
    tiñera el color YA teñido, dos shade() seguidos caen fuera de la rejilla de
    tonos que el auditor acepta y el sprite se marcaria como fuera de paleta.
    Aqui se guarda el color original de cada pixel y siempre se tiñe desde el.
    """

    def __init__(self, s: Sprite) -> None:
        self.s = s
        self.alpha = _alpha_grid(s)
        self.base: Dict[Tuple[int, int], RGBA] = {}
        for y in range(s.h):
            for x in range(s.w):
                if self.alpha[y * s.w + x]:
                    self.base[(x, y)] = s.img.getpixel((x, y))

    def tint(self, x: int, y: int, t: float) -> None:
        original = self.base.get((x, y))
        if original is None:
            return
        # El tinte se cuantiza al 1 %. El auditor solo admite la rejilla de
        # shade() en pasos del 1 %, asi que un factor como 0.135 sale de la
        # paleta y marca el sprite. Cuantizar aqui, y no en cada etapa, deja el
        # desgaste libre de acordarse de la regla.
        pct = max(-45, min(45, int(round(t * 100))))
        self.s.px(x, y, shade(original, pct / 100.0))

    def erase(self, x: int, y: int) -> None:
        if (x, y) not in self.base:
            return
        del self.base[(x, y)]
        self.alpha[y * self.s.w + x] = 0
        self.s.px(x, y, TRANSPARENT)

    def color_at(self, x: int, y: int) -> Optional[RGBA]:
        return self.base.get((x, y))

    ## Pone un color de paleta tal cual, sin pasar por shade(). Para lo que no es
    ## "lo mismo pero mas claro" sino otra cosa: un sello rojo, una mancha de
    ## humedad, la linea de un pliegue. El color nuevo pasa a ser la base, para
    ## que un tinte posterior se aplique sobre lo que se ve.
    def paint(self, x: int, y: int, color: RGBA) -> None:
        if (x, y) not in self.base:
            return
        self.s.px(x, y, color)
        self.base[(x, y)] = color


def _blob(w: Wear, start: Tuple[int, int], n: int) -> List[Tuple[int, int]]:
    """Hasta n pixeles opacos contiguos a start, a 4 vecinos.

    Sin esto el desgaste sale como un filtro de ruido uniforme, y un objeto usado
    no lo esta: tiene zonas lisas y zonas tocadas. Un manchas va pegado a donde
    se agarra, no repartido por todo.
    """
    out: List[Tuple[int, int]] = []
    frontier = [start]
    seen = {start}
    while frontier and len(out) < n:
        x, y = frontier.pop(0)
        if (x, y) in seen or w.color_at(x, y) is None:
            continue
        seen.add((x, y))
        out.append((x, y))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            frontier.append((x + dx, y + dy))
    return out


def _wear_fade(w: Wear, rng: random.Random, interior: List[Tuple[int, int]],
               wear: int) -> None:
    """Zonas amplias y tenues. Es lo que mas separa una nota de la siguiente: el
    uso no deja motas, deja grandes superficies deslucidas."""
    for _ in range(1 + wear // 3):
        start = interior[rng.randrange(len(interior))]
        for x, y in _blob(w, start, 14 + 9 * wear):
            color = w.color_at(x, y)
            if color is not None:
                w.tint(x, y, _away_from_mid(color, (5 + 3 * wear) / 100.0))


def _wear_grime(w: Wear, rng: random.Random, hot: List[Tuple[int, int]],
                wear: int) -> None:
    """Moteado de mugre, en racimos y con preferencia por el canto y las esquinas,
    que es donde se coge el objeto."""
    for _ in range(wear + 1):
        start = hot[rng.randrange(len(hot))]
        for x, y in _blob(w, start, rng.randint(2, 5)):
            color = w.color_at(x, y)
            if color is not None:
                w.tint(x, y, _away_from_mid(color, (8 + 4 * wear) / 100.0))


def _wear_scratches(w: Wear, rng: random.Random, hot: List[Tuple[int, int]],
                    wear: int) -> None:
    """Arañazos: rayas de tono fijo. Con nota alta son tenues; a partir de la 4
    se les anade una segunda mas profunda."""
    for i in range(wear):
        x, y = hot[rng.randrange(len(hot))]
        dx, dy = rng.choice(((1, 0), (0, 1), (1, 1), (1, -1)))
        largo = rng.randint(4, 7)
        t = rng.choice((0.36, -0.36))
        for _ in range(largo):
            if w.color_at(x, y) is not None:
                w.tint(x, y, t)
            x += dx
            y += dy
    if wear >= 4:
        x, y = hot[rng.randrange(len(hot))]
        dx, dy = rng.choice(((1, 0), (1, 1), (0, 1)))
        for _ in range(rng.randint(4, 6)):
            if w.color_at(x, y) is not None:
                w.tint(x, y, -0.40)
            x += dx
            y += dy


def _wear_edges(w: Wear, rng: random.Random, edge: set, wear: int) -> None:
    """Desgaste de canto: el perfil clarito, como cuando un objeto se ha
    rozado muchas veces y se ha llegado a la capa de debajo."""
    p = min(0.9, 0.14 + 0.075 * wear)
    for x, y in edge:
        if rng.random() < p:
            t = 0.28 if rng.random() < 0.65 else -0.28
            w.tint(x, y, t)


def _wear_chips(w: Wear, rng: random.Random, edge: List[Tuple[int, int]],
                wear: int) -> None:
    """Mellas: se cae pintura del perfil. Cada mella puede comerse un vecino,
    para que no salgan como puntos redondos."""
    for _ in range(wear - 4):
        x, y = edge[rng.randrange(len(edge))]
        w.erase(x, y)
        if rng.random() < 0.6:
            w.erase(x + rng.randint(-1, 1), y + rng.randint(-1, 1))


def _wear_stains(w: Wear, rng: random.Random, edge: List[Tuple[int, int]],
                 wear: int) -> None:
    """Manchas: liquido que se ha secado. Sale pegado al perfil, que es donde
    escurre."""
    for _ in range(wear - 6):
        x, y = edge[rng.randrange(len(edge))]
        for _ in range(rng.randint(4, 7)):
            w.tint(x, y, -0.35)
            x += rng.randint(-1, 1)
            y += rng.randint(0, 2)
        w.tint(x, y, 0.22)


def _wear_cracks(w: Wear, rng: random.Random, edge: List[Tuple[int, int]],
                 wear: int) -> None:
    """Grietas en CRACK_D, que es un token de la paleta justo para esto."""
    for _ in range(wear - 7):
        x, y = edge[rng.randrange(len(edge))]
        dx, dy = rng.choice(((1, 0), (0, 1), (1, 1), (1, -1)))
        for _ in range(rng.randint(4, 9)):
            if w.color_at(x, y) is not None:
                w.s.px(x, y, CRACK_D)
            x += dx
            y += dy


def _wear_broken_corner(w: Wear, rng: random.Random, edge: List[Tuple[int, int]]) -> None:
    """Solo en la nota 1: una esquina comida de verdad."""
    x, y = edge[rng.randrange(len(edge))]
    for dy in range(2):
        for dx in range(2):
            w.erase(x + dx, y + dy)


def apply_wear(s: Sprite, wear: int, seed_key: str) -> None:
    """Deteriora el lienzo segun la nota PSA. `wear` va de 0 (nota 10, intacto)
    a 9 (nota 1, cascote). Con wear 0 no toca nada."""
    if wear <= 0:
        return
    rng = random.Random(f"psa:{seed_key}:{wear}")
    w = Wear(s)
    edge = _edge_where(w.alpha, s.w, s.h, 1)
    deep = _edge_where(w.alpha, s.w, s.h, 2) - edge
    interior = [(x, y) for y in range(s.h) for x in range(s.w)
                if (x, y) in w.base and (x, y) not in deep]
    if not interior:
        return

    # Las zonas de uso se muestrean cinco veces mas hacia el canto que hacia el
    # centro: el desgaste se ve en el perfil, no en la mitad de la cara.
    hot = sorted(deep) * 3 + sorted(edge) * 2 + interior

    _wear_fade(w, rng, interior, wear)
    _wear_grime(w, rng, hot, wear)
    _wear_scratches(w, rng, hot, wear)
    _wear_edges(w, rng, edge, wear)
    if wear >= 5:
        _wear_chips(w, rng, sorted(edge), wear)
    if wear >= 7:
        _wear_stains(w, rng, sorted(edge), wear)
    if wear >= 8:
        _wear_cracks(w, rng, sorted(edge), wear)
    if wear >= 9:
        _wear_broken_corner(w, rng, sorted(edge))


# --------------------------------------------------------------------------- #
# Desgaste de una carta
# --------------------------------------------------------------------------- #
#
# No es el de un objeto. Una consola no se raya ni se astilla igual que una
# carta: lo que pasa a una carta es que se dobla, se le aclora el borde de tanto
# meterla en la funda, se le roce el arte y le salen puntitos de humedad. Copiar
# el apply_wear() de los objetos aqui daria mugre en las grietas y esquinas
# comidas, que en una carta son cosas que no existen.
#
#   10  intacta
#    9  el borde se aclora
#    8  + roce en el arte
#    7  + puntos de humedad
#    6  + pliegue
#    5  esquina doblada
#    4  esquina mas doblada
#    3  segundo pliegue
#    2  + mancha de anillo
#    1  esquina partida, dos pliegues y humedad por todas partes

def _card_rub(w: Wear, rng: random.Random, edge: set, wear: int) -> None:
    """El borde se aclora. El carton se desgasta y por debajo sale el color claro
    del interiors: es el sintoma mas inconfundible de una carta muy manoseada."""
    p = min(0.85, 0.12 + 0.07 * wear)
    for x, y in edge:
        if rng.random() < p:
            w.paint(x, y, shade(CREAM_D, -0.25 + 0.04 * wear))


def _card_scuff(w: Wear, rng: random.Random, arte: List[Tuple[int, int]],
                wear: int) -> None:
    """Roces en el arte:.clear, como si el dedo se hubiera pasado mil veces."""
    for _ in range(wear):
        start = arte[rng.randrange(len(arte))]
        for x, y in _blob(w, start, rng.randint(2, 4)):
            w.tint(x, y, 0.34)


def _card_foxing(w: Wear, rng: random.Random, arte: List[Tuple[int, int]],
                 wear: int) -> None:
    """Puntitos de humedad: las manchas oxidadas que salen en el papel viejo."""
    for _ in range(wear):
        x, y = arte[rng.randrange(len(arte))]
        w.paint(x, y, shade(BROWN_L, -0.15))
        if rng.random() < 0.5:
            w.paint(x + 1, y, shade(BROWN_L, -0.05))


def _card_bent_corner(w: Wear, rng: random.Random, wear: int) -> None:
    """Esquina doblada. Un triangulo, no un cuadrado: una esquina doblada deja el
    triangulo del papel Levantandose."""
    lado = wear - 3                       # 2 en la nota 5, hasta 6 en la 9
    esquinas = [(CARD_X0, CARD_Y0, 1, 1), (CARD_X1, CARD_Y0, -1, 1),
                (CARD_X0, CARD_Y1, 1, -1), (CARD_X1, CARD_Y1, -1, -1)]
    cx, cy, sx, sy = esquinas[rng.randrange(len(esquinas))]
    for i in range(lado):
        for j in range(lado - i):
            w.erase(cx + sx * i, cy + sy * j)


def _card_crease(w: Wear, rng: random.Random) -> None:
    """Pliegue. Una linea clara con su sombra al lado, que es como se ve un
    pliegue cuando le da la luz de canto."""
    if rng.random() < 0.5:
        x = rng.randint(9, 22)
        for y in range(CARD_Y0, CARD_Y1 + 1):
            w.paint(x, y, shade(CREAM, -0.05))
            w.paint(x + 1, y, shade(BROWN, -0.25))
    else:
        y = rng.randint(7, 24)
        for x in range(CARD_X0, CARD_X1 + 1):
            w.paint(x, y, shade(CREAM, -0.05))
            w.paint(x, y + 1, shade(BROWN, -0.25))


def _card_ring_stain(w: Wear) -> None:
    """Mancha de anillo: una taza apoyada en la carta. BROWN_D es un token de la
    paleta, asi que entra sin problema en el auditor."""
    w.s.ring(11, 11, 19, 19, BROWN_D)


def apply_card_wear(s: Sprite, wear: int, seed_key: str) -> None:
    """Desgaste de carta. `wear` va de 0 (nota 10) a 9 (nota 1)."""
    if wear <= 0:
        return
    rng = random.Random(f"card:{seed_key}:{wear}")
    w = Wear(s)
    edge = _edge_where(w.alpha, s.w, s.h, 1)
    arte = [p for p in w.base if p not in edge]
    if not arte:
        return

    _card_rub(w, rng, edge, wear)
    _card_scuff(w, rng, arte, wear)
    _card_foxing(w, rng, arte, wear)
    if wear >= 5:
        _card_bent_corner(w, rng, wear)
    if wear >= 6:
        _card_crease(w, rng)
    if wear >= 8:
        _card_ring_stain(w)
    if wear >= 9:
        _card_crease(w, rng)


# --------------------------------------------------------------------------- #
# Desgaste de un cable
# --------------------------------------------------------------------------- #
#
# El apply_wear() de los objetos esta pensado para superficies anchas: una caja,
# una consola, un lingote. El cable es al reves, una linea de tres pixeles que
# se enrolla dos vueltas, y ahi el desgaste sale como un ruido fino repartido por
# toda la vuelta: cambia mas color que ningun otro objeto del catalogo (206 de
# 542 pixeles entre la nota 10 y la 1) y a pesar de eso la nota 10 y la nota 1 se
# confundian a ojo. Es el unico sitio donde el desgaste se notaba en el numero
# y no en la imagen.
#
# Lo que de verdad marca el desgaste de un cable son tres cosas, y las tres se
# leen de un vistazo:
#
#   10 intacto, azul vivo
#    9 el azul se apaga en un tramo
#    8 + otro tramo
#    7 + la funda gris ya
#    6 + rozadura
#    5 + un pliegue lechoso
#    4 + otro pliegue
#    3 + medio cable gris
#    2 + los conectores sin brillo
#    1 + el cable casi gris y los conectores picados

def apply_cable_wear(s: Sprite, wear: int, seed_key: str) -> None:
    """Desgaste de cable, encima del generico. `wear` va de 0 (nota 10) a 9 (nota 1)."""
    if wear <= 0:
        return
    w = Wear(s)
    rng = random.Random(f"cable:{seed_key}:{wear}")
    _cable_fade(w, rng, wear)
    _cable_kinks(w, rng, wear)
    _cable_chips(w, rng, wear)


def _cable_pixels(w: Wear) -> List[Tuple[int, int]]:
    """Los pixeles de la vaina azul, en un orden estable (recorre el lienzo)."""
    return [p for p, c in sorted(w.base.items()) if c in (TEAL, TEAL_D)]


def _cable_fade(w: Wear, rng: random.Random, wear: int) -> None:
    """El azul se apaga a gris, y se apaga a trozos grandes y contiguos.

    Aqui esta casi todo el ganho: el desgaste generico va a pixeles sueltos, y
    sobre una curva de tres pixeles de ancho eso no se ve. Un manchon de diez
    pixeles grises, en cambio, se lee a un metro de distancia.
    """
    if wear < 2:
        return
    for _ in range(1 + wear // 2):
        sheath = _cable_pixels(w)
        if not sheath:
            return
        for x, y in _blob(w, sheath[rng.randrange(len(sheath))], 6 + 8 * wear):
            if w.color_at(x, y) in (TEAL, TEAL_D):
                w.paint(x, y, shade(STEEL_D, rng.choice((0.08, 0.22))))


def _cable_kinks(w: Wear, rng: random.Random, wear: int) -> None:
    """Pliegues: donde el cable se dobla de mas, el plastico se vuelve lechoso.

    El pliegue va en claro y el fundido va en oscuro. Si los dos tiraran para el
    mismo lado, el cable gastado seria solo una mancha gris y se perderian los dos
    sintomas: el descolorido es la funda vieja, el claro es el pliegue.
    """
    for _ in range(max(0, wear - 4)):
        sheath = _cable_pixels(w)
        if not sheath:
            return
        x, y = sheath[rng.randrange(len(sheath))]
        dx, dy = rng.choice(((1, 0), (0, 1), (1, 1)))
        for _ in range(rng.randint(3, 5)):
            if w.color_at(x, y) in (TEAL, TEAL_D):
                w.paint(x, y, STEEL)
            x += dx
            y += dy


def _cable_chips(w: Wear, rng: random.Random, wear: int) -> None:
    """Los conectores pierden el brillo y se pican.

    El metal de un conector muy usado esta opaco y con los bordes comidos, que es
    justo lo contrario de la punta blanca y limpia con la que sale dibujado. Sin
    esto, el extremo del cable se ve igual de nuevo que en la nota 10.
    """
    metal = [p for p, c in sorted(w.base.items()) if c in (STEEL, WHITE)]
    if not metal:
        return
    p = min(0.8, 0.12 * (wear - 2))
    for x, y in metal:
        if rng.random() < p:
            w.paint(x, y, shade(STEEL_DD, 0.25))
    for _ in range(max(0, wear - 7)):
        x, y = metal[rng.randrange(len(metal))]
        w.erase(x, y)


EXTRA_WEAR: Dict[str, Callable[[Sprite, int, str], None]] = {
    "cable": apply_cable_wear,
}


def graded_item(base_key: str) -> Callable[[int], Item]:
    """Devuelve el dibujante del objeto base para cada nota PSA.

    El dibujo base se llama siempre igual y encima se pone el desgaste, asi que
    las diez notas de un objeto son el mismo objeto: solo cambia cuanto esta
    usado.
    """
    base = LOOT_ITEMS[base_key]
    extra = EXTRA_WEAR.get(base_key)

    def make(wear: int) -> Item:
        def draw(s: Sprite) -> None:
            base(s)
            apply_wear(s, wear, base_key)
            if extra is not None:
                # el generico pone la mugre; el especifico, la estructura que
                # hace que la nota se lea de un vistazo
                extra(s, wear, base_key)
        return draw

    return make


Item = Callable[[Sprite], None]
RarityItem = Callable[[Sprite, Rarity], None]

LOOT_ITEMS: Dict[str, Item] = {
    "vinyl": draw_vinyl,
    "vinyl_double": draw_vinyl_double,
    "vinyl_numbered": draw_vinyl_numbered,
    "vinyl_color": draw_vinyl_color,
    "sneaker": draw_sneaker,
    "sneaker_leather": draw_sneaker_leather,
    "sneaker_restore": draw_sneaker_restore,
    "sneaker_limited": draw_sneaker_limited,
    "console": draw_console,
    "handheld": draw_handheld,
    "cartridge": draw_cartridge,
    "headphones": draw_headphones,
    "watch": draw_watch,
    "pocket_watch": draw_pocket_watch,
    "camera": draw_camera,
    "cable": draw_cable,
    "ingot": draw_ingot,
    # las cuatro cartas coleccionables. Se quedan aqui solo para que el
    # registro de abajo pueda leerlas como dibujo base; al final se borran sus
    # claves y solo sobreviven las diez notas de cada una.
    "card_common": draw_card_common,
    "card_edited": draw_card_edited,
    "card_vintage": draw_card_vintage,
    "card_foil": draw_card_foil,
    # herramientas equipables: acortan el tiempo de apertura del paquete
    "cutter": draw_cutter,
    "scissors": draw_scissors,
    "gloves": draw_gloves,
    "crowbar": draw_crowbar,
    # paquetes: lo que se compra a ciegas, en sus dos estados
    "cards": draw_pack_cards,
    "cards_open": draw_pack_cards_open,
    "vinyls": draw_pack_vinyls,
    "vinyls_open": draw_pack_vinyls_open,
    "sneakers": draw_pack_sneakers,
    "sneakers_open": draw_pack_sneakers_open,
    "electronics": draw_pack_electronics,
    "electronics_open": draw_pack_electronics_open,
    "misc": draw_pack_misc,
    "misc_open": draw_pack_misc_open,
    # sombras de mesa, en multiplos enteros
    "small": draw_shadow_small,
    "medium": draw_shadow_medium,
    "large": draw_shadow_large,
    # moneda suelta (la pila es currency_coins, de Gemini)
    "coin": draw_coin,
}

# Los diecisiete objetos que tienen una variante por nota PSA. Se registro de la nota
# 10 a la 1 para que la hoja de contactos se lea como una degradacion de izquierda
# a derecha. El objeto base sin nota desaparece del catalogo: seria el mismo
# dibujo que la nota 10 y tener las dos cosas invita a equivocarse al elegir.
#
# Las cartas coleccionables tambien se desgastarian, pero llevan la rareza en
# dibujo y eso ya es un eje de variacion de por si: entran en otra pasada.
GRADED_ITEMS: List[str] = [
    "vinyl", "vinyl_double", "vinyl_numbered", "vinyl_color",
    "sneaker", "sneaker_leather", "sneaker_restore", "sneaker_limited",
    "console", "handheld", "cartridge", "headphones",
    "watch", "pocket_watch", "camera", "cable", "ingot",
]

for _base in GRADED_ITEMS:
    _make = graded_item(_base)
    for _psa in range(PSA_MAX, PSA_MIN - 1, -1):
        LOOT_ITEMS[f"{_base}_psa{_psa}"] = _make(PSA_MAX - _psa)
    del LOOT_ITEMS[_base]


# Las cuatro cartas: mismo mecanismo de diez notas, pero con el desgaste de
# carta. Se registran aparte porque el dibujo base entra por una funcion normal
# de LOOT_ITEMS y no por RARITY_ITEMS (ya no hay una carta teñida por rareza).
CARD_ITEMS: List[str] = ["card_common", "card_edited", "card_vintage", "card_foil"]

for _base in CARD_ITEMS:
    _dibujar = LOOT_ITEMS[_base]

    def _make_card(psa: int, fn: Item = _dibujar, key: str = _base) -> Item:
        def draw(s: Sprite) -> None:
            fn(s)
            apply_card_wear(s, PSA_MAX - psa, key)
        return draw

    for _psa in range(PSA_MAX, PSA_MIN - 1, -1):
        LOOT_ITEMS[f"{_base}_psa{_psa}"] = _make_card(_psa)
    del LOOT_ITEMS[_base]

GRADED_ITEMS = GRADED_ITEMS + CARD_ITEMS

RARITY_ITEMS: Dict[str, RarityItem] = {
    "gem": draw_rarity_gem,
    "glow": draw_rarity_glow,
}

@dataclass(frozen=True)
class UiSpec:
    """Sprite de interfaz: lienzo propio, prefijo de archivo y escala opcional."""
    w: int
    h: int
    draw: Item
    prefix: str = "ui"
    scale: Optional[int] = None      # None -> la escala global (--scale)


UI_ITEMS: Dict[str, UiSpec] = {
    # --- pantalla de inicio ---
    "button_plate": UiSpec(32, 16, partial(draw_button_plate, pressed=False)),
    "button_plate_pressed": UiSpec(32, 16, partial(draw_button_plate, pressed=True)),
    "icon_play": UiSpec(16, 16, draw_icon_play),
    "icon_settings": UiSpec(16, 16, draw_icon_settings),

    # --- iconos de las 4 habilidades principales ---
    "diamond": UiSpec(16, 16, draw_skill_diamond, prefix="skill"),
    "lightning": UiSpec(16, 16, draw_skill_lightning, prefix="skill"),
    "dollar": UiSpec(16, 16, draw_skill_dollar, prefix="skill"),
    # cycle a 32x32 y scale 8: a 16x16 no caben las tres flechas (ver la
    # funcion); el PNG sale igual a 256 que sus hermanas.
    "cycle": UiSpec(32, 32, draw_skill_cycle, prefix="skill", scale=8),

    # --- kit de interfaz ---
    "panel_shop": UiSpec(100, 60, partial(draw_panel, body=BROWN_D)),
    "panel_settings": UiSpec(100, 60, partial(draw_panel, body=(34, 30, 48, 255))),
    "slot": UiSpec(16, 16, draw_slot),
    "button_small": UiSpec(20, 9, partial(draw_button_small, pressed=False)),
    "button_small_pressed": UiSpec(20, 9, partial(draw_button_small, pressed=True)),
    "button_close": UiSpec(16, 16, draw_button_close),
    "checkbox_on": UiSpec(10, 10, partial(draw_checkbox, checked=True)),
    "checkbox_off": UiSpec(10, 10, partial(draw_checkbox, checked=False)),
    "slider_track": UiSpec(26, 6, draw_slider_track),
    "slider_knob": UiSpec(8, 12, draw_slider_knob),
    "arrow_left": UiSpec(10, 10, partial(draw_arrow, direction="left")),
    "arrow_right": UiSpec(10, 10, partial(draw_arrow, direction="right")),
    "icon_shop": UiSpec(16, 16, draw_icon_shop),
    "icon_sound": UiSpec(16, 16, draw_icon_sound),
    "icon_music": UiSpec(16, 16, draw_icon_music),
    "icon_plus": UiSpec(16, 16, draw_icon_plus),

    # --- insignias de estado de conservacion ---
    # Las claves van sin "condition_" porque el prefijo ya lo pone UiSpec.
    "mint": UiSpec(16, 16, draw_condition_mint, prefix="condition"),
    "good": UiSpec(16, 16, draw_condition_good, prefix="condition"),
    "worn": UiSpec(16, 16, draw_condition_worn, prefix="condition"),
    "broken": UiSpec(16, 16, draw_condition_broken, prefix="condition"),

    # --- iconos de interfaz de segunda generacion ---
    "icon_auto_open": UiSpec(16, 16, draw_icon_auto_open),
    "icon_auto_buy": UiSpec(16, 16, draw_icon_auto_buy),
    "icon_achievement": UiSpec(16, 16, draw_icon_achievement),
    "icon_market_event": UiSpec(16, 16, draw_icon_market_event),
    "icon_inventory": UiSpec(16, 16, draw_icon_inventory),
    "icon_display_case": UiSpec(16, 16, draw_icon_display_case),
    "icon_vitrine": UiSpec(16, 16, draw_icon_vitrine),

    # --- flujo de apertura: esperar, revelar, vender ---
    "timer_track": UiSpec(16, 16, draw_timer_track),
    "timer_fill": UiSpec(16, 16, draw_timer_fill),
    "panel_reveal": UiSpec(100, 60, draw_panel_reveal),
    "shine": UiSpec(16, 16, draw_fx_shine, prefix="fx"),
    "tag_price": UiSpec(20, 10, draw_tag_price),
    "button_sell": UiSpec(20, 9, draw_button_sell),

    # --- graduacion PSA (1 a 10) ---
    # Las claves no llevan "grade_": el prefijo ya lo pone UiSpec, y si lo
    # llevaran saldria "grade_grade_star_full".
    "badge": UiSpec(16, 16, draw_grade_badge, prefix="grade"),
    "star_full": UiSpec(16, 16, draw_grade_star_full, prefix="grade"),
    "star_half": UiSpec(16, 16, draw_grade_star_half, prefix="grade"),
    "star_empty": UiSpec(16, 16, draw_grade_star_empty, prefix="grade"),
    "ribbon": UiSpec(40, 8, draw_grade_ribbon, prefix="grade"),
}

# Los numeros entran en el registro uno por uno (clave = el propio caracter).
for _key in GLYPHS:
    UI_ITEMS[_key] = UiSpec(FONT_CELL_W, FONT_CELL_H,
                            partial(draw_font_glyph, key=_key),
                            prefix="num", scale=FONT_SCALE)
UI_ITEMS["sheet"] = UiSpec(len(FONT_ORDER) * FONT_CELL_W, FONT_CELL_H,
                           draw_font_sheet, prefix="num", scale=FONT_SCALE)

RARITY_PREFIX = {"gem": "rarity", "glow": "rarity"}

# Prefijo de archivo para los objetos de LOOT_ITEMS que no son botin suelto.
# Mismo patron que RARITY_PREFIX: sin esto, output_name() los llamaria "loot_".
ITEM_PREFIX: Dict[str, str] = {
    "cutter": "tool",
    "scissors": "tool",
    "gloves": "tool",
    "crowbar": "tool",
    "cards": "pack",
    "cards_open": "pack",
    "vinyls": "pack",
    "vinyls_open": "pack",
    "sneakers": "pack",
    "sneakers_open": "pack",
    "electronics": "pack",
    "electronics_open": "pack",
    "misc": "pack",
    "misc_open": "pack",
    "small": "shadow",
    "medium": "shadow",
    "large": "shadow",
    "coin": "currency",
}


# --------------------------------------------------------------------------- #
# DONDE VA CADA SPRITE
# --------------------------------------------------------------------------- #
#
# La tabla de carpetas vive en tools/sprite_paths.py, no aqui. Es el mismo sitio
# que usan make_background.py, make_screens.py, make_font.py y
# normalize_sprite.py, y de ahi sale tambien el indice que lee el juego
# (Sprites/index.tsv). Tener la misma tabla en cuatro ficheros es la forma mas
# rapida de que se desincronicen sin que avise nadie: uno pone "ui_icon_" en
# ui/ y otro lo deja en ui/icons/, y el juego se come un hueco sin error.
#
# Lo unico que hace este generador es decidir el NOMBRE (output_name) y pedir la
# carpeta (folder_for), y montar la ruta con las dos.


def write_index(path: str, rel_paths: Sequence[str]) -> None:
    """Escribe Sprites/index.tsv: el nombre corto y su ruta, separados por tab.

    El juego carga este fichero en vez de adivinar la carpeta por el prefijo. La
    diferencia importa: si la carpeta se decidiera en el juego con una regla
    parecida, las dos listas se desincronizarian en cuanto alguien añadiese un
    sprite con un prefijo nuevo, y se veria un hueco en la pantalla sin saber por
    que. Aqui el indice lo escribe el mismo generador que coloca el fichero, asi
    que no puede mentir.

    El formato es TSV y no JSON porque se lee de un vistazo (un sprite por
    linea) y se puede comentar en una revision de codigo.

    CONSERVA LO QUE NO ES DE ESTE GENERADOR. Hay sprites en Sprites/ que no
    salen de aqui (los dos que vienen de un generador de imagenes, y lo que
    escriban make_font / make_background / make_screens). Si al reescribir el
    indice se olvidara de ellos, quedarian en disco sin entrada: el juego los
    buscaria por nombre corto y no los encontraria, sin error, que es la peor
    forma de romperse. Asi que se relee lo que habia y se sobrevive a los que
    este script no genera, siempre que el fichero siga existiendo (asi una
    entrada borrada a mano si se cae al reescribir).
    """
    sprites_dir = os.path.dirname(os.path.abspath(path))
    previos = read_index(sprites_dir)

    generadas: Dict[str, str] = {}
    for p in rel_paths:
        stem = os.path.splitext(os.path.basename(p))[0]
        generadas[stem] = p

    for stem, rel in previos.items():
        if stem in generadas:
            continue  # mandan las de este generador
        if os.path.exists(os.path.join(sprites_dir, rel)):
            generadas[stem] = rel

    with open(path, "w", encoding="utf-8") as fh:
        fh.write("# Indice de sprites: nombre corto<TAB>ruta dentro de Sprites/.\n")
        fh.write("# Lo genera tools/make_sprites.py. No editar a mano.\n")
        fh.write("# El juego lo lee en scripts/ui/sprites.gd.\n")
        for stem in sorted(generadas):
            fh.write(f"{stem}\t{generadas[stem]}\n")


def output_path(kind: str, name: str, rarity_key: Optional[str] = None) -> str:
    """Ruta relativa dentro de Sprites/, con carpetas: 'ui/icons/ui_icon_play.png'."""
    return f"{folder_for(output_name(kind, name, rarity_key))}/{output_name(kind, name, rarity_key)}"


def output_name(kind: str, name: str, rarity_key: Optional[str] = None) -> str:
    if kind == "ui":
        prefix = UI_ITEMS[name].prefix
    elif kind == "rarity":
        prefix = RARITY_PREFIX[name]
    else:
        prefix = ITEM_PREFIX.get(name, "loot")
    if rarity_key:
        return f"{prefix}_{name}_{rarity_key}.png"
    return f"{prefix}_{name}.png"


def _pide(only: Optional[Sequence[str]], name: str) -> bool:
    """Si una entrada de --only trae este nombre.

    Un nombre pedido vale si coincide EXACTO con el de la entrada o si es la
    base de la que sale: `--only sneaker` tiene que generar las diez notas de
    la zapatilla, no fallar con "nada que generar" como hacia antes, porque en
    el catalogo solo existen `sneaker_psa1` … `sneaker_psa10`.

    El enganche es con "_" y no con cualquier prefijo a proposito: `--only vinyl`
    saca el botin de vinilos pero no el paquete `vinyls`, que es otra cosa y
    tiene su propio nombre. Para ese esta el nombre exacto.
    """
    if not only:
        return True
    return any(name == o or name.startswith(f"{o}_") for o in only)


def planned_outputs(
    only: Optional[Sequence[str]] = None,
    rarities: Optional[Sequence[str]] = None,
) -> List[Tuple[str, str, Optional[str]]]:
    """Devuelve [(kind, name, rarity|None)] en orden de generacion."""
    rarities = list(rarities) if rarities else list(RARITY_ORDER)
    entries: List[Tuple[str, str, Optional[str]]] = []

    for name in LOOT_ITEMS:
        if not _pide(only, name):
            continue
        entries.append(("loot", name, None))

    for name in RARITY_ITEMS:
        if not _pide(only, name):
            continue
        for rarity_key in rarities:
            entries.append(("rarity", name, rarity_key))

    for name in UI_ITEMS:
        if not _pide(only, name):
            continue
        entries.append(("ui", name, None))

    return entries


def build_entry_sprite(kind: str, name: str, rarity_key: Optional[str]) -> Sprite:
    """Construye el lienzo (sin escalar) de una entrada del catalogo."""
    if kind == "ui":
        spec = UI_ITEMS[name]
        s = Sprite(spec.w, spec.h)
        spec.draw(s)
        return s
    s = Sprite()
    if kind == "loot":
        LOOT_ITEMS[name](s)
    else:
        assert rarity_key is not None
        RARITY_ITEMS[name](s, RARITIES[rarity_key])
    return s


def render_entry(kind: str, name: str, rarity_key: Optional[str], scale: int) -> Image.Image:
    return render_sprite(build_entry_sprite(kind, name, rarity_key),
                         entry_scale(kind, name, scale))


def entry_scale(kind: str, name: str, scale: int) -> int:
    """Escala de salida de una entrada (los numeros van a la mitad, a proposito)."""
    if kind == "ui":
        return UI_ITEMS[name].scale or scale
    return scale


def render_sprite(s: Sprite, scale: int) -> Image.Image:
    return s.render(scale)


# --------------------------------------------------------------------------- #
# Auditoria de estilo
#
# Comprueba automaticamente lo que hasta ahora habia que mirar a ojo, para que
# un sprite nuevo no rompa el estilo sin que nadie se entere. Se ejecuta con
# --audit y avisa de:
#   1. arte pegado al borde -> el contorno de 1 px se sale del lienzo y se ve cortado
#   2. escala no entera -> el pixel queda irregular
#   3. alfa con degradados en un sprite que deberia tener alfa binaria
#   4. colores fuera de la paleta -> delata un sprite que se coló de otra fuente
# --------------------------------------------------------------------------- #

# Piezas de 9-slice: su marco tiene que sangrar hasta el borde para poder
# estirarse. El recorte de contorno no les aplica por diseno.
FULL_BLEED = {
    "panel_shop", "panel_settings",          # marcos de ventana
    "panel_reveal",                          # tarjeta de revelado
    "button_plate", "button_plate_pressed",  # placa grande del menu
    "button_small", "button_small_pressed",  # boton compacto
    "button_sell",                           # boton de vender
    "slot",                                  # ranura de objeto
    "slider_track",                          # canaleta del deslizador
    "ribbon",                                # cinta, sangra por los dos lados
}

# Los unicos sprites con alfa graduado: auras, sombras y destello. Es justo lo
# que son, asi que el auditor no les exige alfa binaria.
GRADIENT_ALPHA = {"glow", "small", "medium", "large", "shine"}


def validate_names() -> List[str]:
    """Detecta nombres de archivo con el prefijo duplicado.

    Las claves de los registros pueden llevar o no el prefijo del archivo, segun
    como se registraran. Si lo llevan Y el UiSpec/ITEM_PREFIX vuelve a ponerlo,
    el archivo sale como "grade_grade_star_full.png". Pasa dos veces en este
    archivo, asi que se comprueba en vez de confiar en la memoria.
    """
    malos: List[str] = []
    for kind, name in (("loot", n) for n in LOOT_ITEMS):
        salida = output_name(kind, name)
        prefijo = salida.split("_")[0]
        if name.startswith(prefijo + "_"):
            malos.append(salida)
    for name, spec in UI_ITEMS.items():
        salida = output_name("ui", name)
        if name.startswith(spec.prefix + "_"):
            malos.append(salida)
    return malos


def allowed_colors() -> set:
    """Paleta admisible: la base, las rarezas y los tonos derivados de shade().

    El generador no solo pinta colores de la paleta: draw_panel(), draw_slot() y
    draw_icon_shop() ademas oscurecen o aclaran cuerpos con shade(). Se recorre
    una rejilla fina de factores para que cualquier bisel que se acepte hoy siga
    valiendo si manana se ajusta el factor.
    """
    base = set(PALETTE)
    for rarity in RARITIES.values():
        base.update({rarity.dark, rarity.base, rarity.light, rarity.glow})
    # cuerpo del panel de ajustes: es un bisel, no un token de la paleta
    base.add((34, 30, 48, 255))
    derived = set()
    for color in base:
        for i in range(-45, 46):
            derived.add(shade(color, i / 100.0))
    return base | derived


def audit_sprite(s: Sprite, img: Image.Image, name: str, scale: int) -> List[str]:
    """Devuelve la lista de problemas de un sprite (vacia si esta limpio)."""
    problems: List[str] = []

    # 1. el arte no debe pegarse al borde, o el contorno se recorta
    if s.want_outline and name not in FULL_BLEED:
        alpha = s.img.split()[3].load()
        w, h = s.img.size
        edges = []
        if any(alpha[x, 0] > 0 for x in range(w)):
            edges.append("arriba")
        if any(alpha[x, h - 1] > 0 for x in range(w)):
            edges.append("abajo")
        if any(alpha[0, y] > 0 for y in range(h)):
            edges.append("izquierda")
        if any(alpha[w - 1, y] > 0 for y in range(h)):
            edges.append("derecha")
        if edges:
            problems.append(f"arte pegado al borde ({', '.join(edges)}): "
                            f"el contorno se sale del lienzo")

    # 2. escala entera: cada bloque de `scale` px debe ser de un solo color
    px = img.load()
    for by in range(0, img.height, scale):
        for bx in range(0, img.width, scale):
            ref = px[bx, by]
            for dy in range(scale):
                for dx in range(scale):
                    if px[bx + dx, by + dy] != ref:
                        problems.append(f"escala no entera cerca de ({bx},{by})")
                        break
                else:
                    continue
                break
            else:
                continue
            break

    # 3. alfa: binaria salvo en las auras
    if name not in GRADIENT_ALPHA:
        levels = {px[x, y][3]
                  for y in range(0, img.height, 4)
                  for x in range(0, img.width, 4)}
        intermedios = levels - {0, 255}
        if intermedios:
            n = len(intermedios)
            problems.append(f"alfa con {n} nivel{'es' if n > 1 else ''} "
                            f"intermedio{'s' if n > 1 else ''} "
                            f"(deberia ser binaria 0/255)")

    # 4. paleta. Se compara en RGB y no en RGBA: las auras son el unico sprite
    # con alfa graduado y su color base si esta en la paleta.
    allowed = {(c[0], c[1], c[2]) for c in allowed_colors()}
    fuera = set()
    for y in range(0, img.height, 3):
        for x in range(0, img.width, 3):
            r, g, b, a = px[x, y]
            if a > 0 and (r, g, b) not in allowed:
                fuera.add((r, g, b))
    if fuera:
        muestras = ", ".join(f"#{r:02X}{g:02X}{b:02X}" for r, g, b in sorted(fuera)[:4])
        problems.append(f"{len(fuera)} color(es) fuera de la paleta: {muestras}")

    return problems


def build_audit_report(problems: List[Tuple[str, List[str]]],
                       nombres_malos: Optional[List[str]] = None) -> str:
    """Formatea el informe de la auditoria."""
    lineas: List[str] = []
    if nombres_malos:
        lineas.append("NOMBRES: prefijo duplicado en:")
        for n in nombres_malos:
            lineas.append(f"      - {n}")
    if not problems and not nombres_malos:
        lineas.append("AUDITORIA: todo correcto.")
        return "\n".join(lineas)
    if problems:
        lineas.append(f"AUDITORIA: {len(problems)} sprite(s) con problemas.")
        for name, avisos in problems:
            lineas.append(f"  {name}")
            for aviso in avisos:
                lineas.append(f"      - {aviso}")
    return "\n".join(lineas)


# --------------------------------------------------------------------------- #
# Preview
# --------------------------------------------------------------------------- #

def build_preview(entries: List[Tuple[str, str, Optional[str], Image.Image]]) -> Image.Image:
    cols = 5
    cell, pad, label_h = 150, 8, 16
    rows = max(1, (len(entries) + cols - 1) // cols)
    width = cols * (cell + pad) + pad
    height = rows * (cell + label_h + pad) + pad
    sheet = Image.new("RGBA", (width, height), (96, 96, 104, 255))
    d = ImageDraw.Draw(sheet)
    check = 30
    for by in range(0, height, check):
        for bx in range(0, width, check):
            if (bx // check + by // check) % 2 == 0:
                d.rectangle([bx, by, bx + check - 1, by + check - 1], fill=(120, 120, 130, 255))

    for i, (kind, name, rarity_key, img) in enumerate(entries):
        row, col = divmod(i, cols)
        x = pad + col * (cell + pad)
        y = pad + row * (cell + label_h + pad)
        # cada sprite cabe entero en su celda, conservando su proporcion
        f = min(cell / img.width, cell / img.height)
        nw = max(1, int(img.width * f))
        nh = max(1, int(img.height * f))
        sheet.alpha_composite(
            img.resize((nw, nh), Image.NEAREST),
            (x + (cell - nw) // 2, y + (cell - nh) // 2),
        )
        label = output_name(kind, name, rarity_key).replace(".png", "")
        d.text((x, y + cell + 2), label, fill=(232, 222, 196, 255))

    return sheet


def build_wear_sheet(bases: Sequence[str], scale: int = 8) -> Image.Image:
    """Las diez notas de cada objeto, de la 10 a la 1, un objeto por fila.

    Es la hoja que hay que mirar cuando se toca apply_wear(): a tamano normal en
    la hoja de contactos general no se aprecia si la nota 6 esta mas gastada que
    la 5 o igual.
    """
    cell = 32 * scale
    pad, label_h, tag_w = 12, 18, 96
    width = tag_w + PSA_MAX * (cell + pad) + pad
    height = len(bases) * (cell + label_h + pad) + pad
    sheet = Image.new("RGBA", (width, height), (34, 30, 48, 255))
    d = ImageDraw.Draw(sheet)
    font = _tiny_font()
    for fila, base in enumerate(bases):
        y = pad + fila * (cell + label_h + pad)
        d.text((6, y + cell // 2), base.replace("card_", ""),
               fill=(248, 192, 0, 255), font=font)
        for i, psa in enumerate(range(PSA_MAX, PSA_MIN - 1, -1)):
            img = render_entry("loot", f"{base}_psa{psa}", None, scale)
            x = tag_w + i * (cell + pad)
            sheet.alpha_composite(img, (x, y))
            d.rectangle([x - 1, y - 1, x + cell, y + cell], outline=(168, 72, 8, 255))
            d.text((x + 2, y + cell + 2), str(psa), fill=(252, 236, 196, 255),
                   font=font)
    return sheet


def _tiny_font():
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, 14)
    return ImageFont.load_default()


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    default_out = os.path.join(root, "Sprites")

    ap = argparse.ArgumentParser(description="Genera sprites pixel-art para el juego.")
    ap.add_argument("--out", default=default_out, help="carpeta destino (por defecto Sprites/)")
    ap.add_argument("--scale", type=int, default=SCALE, help=f"factor de escalado (por defecto {SCALE})")
    ap.add_argument("--only", nargs="*", metavar="NAME",
                    help="genera solo estos sprites: "
                         + ", ".join(list(LOOT_ITEMS) + list(RARITY_ITEMS) + list(UI_ITEMS)))
    ap.add_argument("--rarity", nargs="*", choices=RARITY_ORDER,
                    help="restringe las variantes de rareza a generar")
    ap.add_argument("--all", action="store_true", help="genera todo el catalogo")
    ap.add_argument("--list", action="store_true", help="lista los sprites disponibles")
    ap.add_argument("--preview", action="store_true",
                    help="ademas, escribe _preview.png con todo el catalogo en rejilla")
    ap.add_argument("--audit", action="store_true",
                    help="revisa el estilo de cada sprite (contorno recortado, escala "
                         "entera, alfa, paleta) y avisa de lo que se escape")
    ap.add_argument("--wear-sheet", metavar="OBJETO", choices=GRADED_ITEMS + ["cards"],
                    help="escribe tools/_wear_<objeto>.png con las 10 notas PSA en "
                         "fila, para revisar como degrada. 'cards' son las cuatro "
                         "cartas, una por fila")
    args = ap.parse_args()

    if args.wear_sheet:
        bases = CARD_ITEMS if args.wear_sheet == "cards" else [args.wear_sheet]
        out = build_wear_sheet(bases)
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            f"_wear_{args.wear_sheet}.png")
        out.save(path)
        print(f"Hoja de desgaste: {path}  ({out.width}x{out.height})")
        return

    if args.list:
        print("Objetos de botin :", ", ".join(LOOT_ITEMS))
        print("Con rareza       :", ", ".join(RARITY_ITEMS))
        print("Rarezas          :", ", ".join(RARITY_ORDER))
        print("Interfaz         :", ", ".join(UI_ITEMS))
        return

    if not args.all and not args.only:
        ap.print_help()
        print("\nUsa --all o --only <nombre> para generar sprites.")
        return

    only = args.only or None
    entries = planned_outputs(only, args.rarity)
    if not entries:
        print("Nada que generar con esos filtros.")
        return

    os.makedirs(args.out, exist_ok=True)
    preview_entries: List[Tuple[str, str, Optional[str], Image.Image]] = []
    audit_problems: List[Tuple[str, List[str]]] = []

    for kind, name, rarity_key in entries:
        sprite = build_entry_sprite(kind, name, rarity_key)
        scale = entry_scale(kind, name, args.scale)
        img = sprite.render(scale)
        rel = output_path(kind, name, rarity_key)
        path = os.path.join(args.out, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path)
        preview_entries.append((kind, name, rarity_key, img))
        print(f"  {img.width}x{img.height}  {os.path.relpath(path, root)}")
        if args.audit:
            avisos = audit_sprite(sprite, img, name, scale)
            if avisos:
                audit_problems.append((rel, avisos))

    print(f"\n{len(entries)} sprites escritos en {os.path.relpath(args.out, root)}/")

    # El indice: nombre corto -> ruta. El juego lo lee para no tener que saber
    # en que carpeta vive cada cosa (ver scripts/sprites.gd).
    written = [output_path(k, n, r) for k, n, r in entries]
    write_index(os.path.join(args.out, "index.tsv"), written)

    if args.audit:
        print()
        malos = validate_names()
        print(build_audit_report(audit_problems, malos))
        if audit_problems or malos:
            sys.exit(1)

    if args.preview:
        sheet = build_preview(preview_entries)
        sheet_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview.png")
        sheet.save(sheet_path)
        print(f"Preview: {sheet_path}")


if __name__ == "__main__":
    main()
