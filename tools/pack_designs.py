#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""pack_designs.py - los dibujos de los paquetes (los cuatro tipos, tres escalones).

Sustituye a los paquetes que habia en make_sprites.py, que eran rectangulos
marrones o dorados casi iguales entre si (un sobre, una funda y dos cajas del
mismo carton) con un agujero negro como dano. Aqui cada tipo tiene su silueta y
su motivo, para que en la columna y en la mesa se distingan sin leer el nombre:

  SOBRES       sobre de cartas metalizado, sellado arriba y abajo en zigzag,
               con un brillo en diagonal y un abanico de cartas de emblema
  VINILOS      funda cuadrada con arte de atardecer retro y el disco asomando
               por la derecha
  ZAPATILLAS   caja de zapatillas en perspectiva (tapa y frente) con un rayo de
               marca y la etiqueta de la talla
  ELECTRONICA  caja de producto con la foto de una consola, franja de color y
               cinta de precinto

El escalon cambia los MATERIALES y no el dibujo: el 1 es de colores, el 2 de pan
de oro y el 3 de laca negra con joyas. Asi se reconoce el tipo por la forma y el
escalon por el material.

EL DANO DEJA SALIR LA LUZ. Los tres tramos (d1, d2, d3) se pintan encima del
dibujo cerrado: rozaduras, despues un desgarro con luz dentro y al final una raja
grande que brilla. Antes era un agujero negro, que se leia como un sobre vacio en
vez de como uno a punto de abrirse.

Mismas reglas que el resto del arte (ver make_sprites.py): rejilla de 32,
contorno de 1 px que pone el generador, alfa binaria y solo colores de la paleta
o derivados con shade() dentro del +-45 % que acepta el auditor.

Este modulo NO importa make_sprites: recibe el modulo como argumento (ver
install()), porque make_sprites es quien lo importa a el y una importacion de
vuelta lo cargaria dos veces.
"""

from __future__ import annotations

import random
from typing import Callable, Dict, List, Tuple

from PIL import Image, ImageChops, ImageDraw

M = None  # el modulo make_sprites, puesto por install()


def _pal() -> Dict[str, Tuple[int, int, int, int]]:
    return {k: getattr(M, k) for k in dir(M) if k.isupper()
            and isinstance(getattr(M, k), tuple) and len(getattr(M, k)) == 4}


# --------------------------------------------------------------------------- #
# Materiales por tipo y escalon
# --------------------------------------------------------------------------- #

def _materials(kind: str, tier: int) -> Dict[str, tuple]:
    P = _pal()
    sh = M.shade
    epic = M.RARITIES["epic"]
    gold = dict(hi=P["GOLD_HI"], l=P["GOLD_XL"], m=P["GOLD_L"], d=P["GOLD"],
                dd=P["GOLD_D"])
    cream = dict(hi=P["WHITE"], l=P["CREAM_L"], m=P["CREAM"], d=P["CREAM_D"],
                 dd=P["CRINKLE"])
    # LA LACA DEL ESCALON 3 ES MORADA, no negra: en negro se perdia contra la
    # columna de sobres (que es casi negra) y su silueta solo la sacaba el oro.
    # El morado es el de la rareza epica, que ya es "lo caro" en todo el juego.
    lacquer = dict(hi=epic.light, l=epic.base, m=epic.dark, d=sh(epic.dark, -0.3),
                   dd=sh(epic.dark, -0.45))
    if kind == "cards":
        if tier == 1:
            return dict(body=dict(hi=P["TEAL_L"], l=sh(P["TEAL"], 0.25), m=P["TEAL"],
                                  d=P["TEAL_D"], dd=sh(P["TEAL_D"], -0.35)),
                        trim=gold, accent=P["GOLD_XL"], star=P["GOLD_XL"])
        if tier == 2:
            return dict(body=gold, trim=cream, accent=P["CREAM"], star=P["RED"])
        return dict(body=lacquer, trim=gold, accent=epic.light, star=epic.base)
    if kind == "vinyls":
        if tier == 1:
            return dict(sky=dict(hi=P["GOLD_HI"], l=P["GOLD_XL"], m=P["GOLD_L"],
                                 d=P["RED_L"], dd=P["RED"]),
                        sleeve=cream, sun=P["CREAM_L"], disc=P["DARK"],
                        disc_l=P["SLATE"], label=P["RED_L"], label_l=P["GOLD_XL"])
        if tier == 2:
            return dict(sky=dict(hi=P["WHITE"], l=P["CREAM_L"], m=P["GOLD_HI"],
                                 d=P["GOLD_XL"], dd=P["GOLD_L"]),
                        sleeve=gold, sun=P["WHITE"], disc=P["GOLD_D"],
                        disc_l=P["GOLD"], label=P["CREAM"], label_l=P["WHITE"])
        # el disco de LUJO es de vinilo de color (morado), no negro: negro sobre
        # la columna oscura no se veia
        return dict(sky=dict(hi=epic.light, l=epic.base, m=epic.dark,
                             d=sh(epic.dark, -0.3), dd=sh(epic.dark, -0.45)),
                    sleeve=dict(hi=P["GOLD_HI"], l=P["GOLD_XL"], m=P["GOLD"],
                                d=P["GOLD_D"], dd=sh(P["GOLD_D"], -0.3)),
                    sun=P["GOLD_HI"], disc=epic.dark, disc_l=epic.base,
                    label=P["GOLD_XL"], label_l=P["GOLD_HI"])
    if kind == "sneakers":
        if tier == 1:
            return dict(box=dict(hi=P["RED_L"], l=sh(P["RED"], 0.15), m=P["RED"],
                                 d=P["RED_D"], dd=sh(P["RED_D"], -0.3)),
                        lid=cream, bolt=P["CREAM"], bolt_d=P["CREAM_D"], tag=P["WHITE"])
        if tier == 2:
            return dict(box=gold, lid=cream, bolt=P["WHITE"], bolt_d=P["CREAM"],
                        tag=P["CREAM_L"])
        return dict(box=lacquer, lid=gold, bolt=P["GOLD_XL"], bolt_d=P["GOLD"],
                    tag=P["GOLD_HI"])
    # electronics
    if tier == 1:
        return dict(box=dict(hi=P["WHITE"], l=P["WHITE"], m=P["STEEL"], d=P["STEEL_D"],
                             dd=P["STEEL_DD"]),
                    band=P["TEAL"], band_l=P["TEAL_L"], band_d=P["TEAL_D"],
                    tape=P["GOLD_XL"], tape_d=P["GOLD"])
    if tier == 2:
        return dict(box=gold, band=P["DARK_SOFT"], band_l=P["SLATE"], band_d=P["NIGHT"],
                    tape=P["CREAM"], tape_d=P["CREAM_D"])
    return dict(box=lacquer, band=P["GOLD"], band_l=P["GOLD_HI"], band_d=P["GOLD_D"],
                tape=P["TEAL_L"], tape_d=P["TEAL"])


# --------------------------------------------------------------------------- #
# Piezas
# --------------------------------------------------------------------------- #

def _zigzag(s, x0: int, x1: int, y: int, color, up: bool) -> None:
    """Borde sellado en zigzag: un diente cada dos columnas."""
    for x in range(x0, x1 + 1):
        if (x - x0) % 2 == 0:
            s.px(x, y - 1 if up else y + 1, color)


def _gem(s, cx: int, cy: int, tier: int) -> None:
    """Joya del escalon 3 (diamante de la paleta de make_sprites)."""
    M._draw_diamond(s, cx, cy, 2)


# --------------------------------------------------------------------------- #
# SOBRES: sobre de cartas metalizado
# --------------------------------------------------------------------------- #

CARDS_BOX = (9, 2, 22, 29)


def draw_cards(s, tier: int) -> None:
    m = _materials("cards", tier)
    b, t = m["body"], m["trim"]
    x0, x1, y0, y1 = 9, 22, 2, 29
    # cuerpo con volumen de cilindro: luz a la izquierda, sombra a la derecha
    s.rect(x0, y0 + 3, x1, y1 - 3, b["m"])
    s.rect(x0, y0 + 3, x0 + 1, y1 - 3, b["l"])
    s.rect(x0 + 2, y0 + 3, x0 + 2, y1 - 3, b["hi"] if tier != 3 else b["l"])
    s.rect(x1 - 1, y0 + 3, x1, y1 - 3, b["d"])
    # brillo metalizado en diagonal, la seña del sobre de cartas: dos rayas
    # paralelas de abajo a la izquierda a arriba a la derecha
    s.line([(x0 + 2, y1 - 6), (x1 - 2, y0 + 6)], b["hi"])
    s.line([(x0 + 2, y1 - 4), (x1 - 1, y0 + 7)], b["l"])
    # sellos de arriba y de abajo, con el zigzag
    for yy in (y0, y1 - 2):
        s.rect(x0, yy, x1, yy + 2, t["m"])
        s.rect(x0, yy, x1, yy, t["l"])
        s.rect(x0, yy + 2, x1, yy + 2, t["dd"])
        for x in range(x0 + 1, x1, 2):
            s.px(x, yy + 1, t["d"])      # el estriado del sellado
    _zigzag(s, x0, x1, y0, t["m"], up=True)
    _zigzag(s, x0, x1, y1, t["dd"], up=False)
    # el emblema: una carta con una estrella, y otra carta detras asomando
    P = _pal()
    cx, cy = 16, 14
    # la de detras, un poco a la izquierda y mas arriba, con su canto del color
    # de sombra del sobre y no negro (en negro se leia como un marco vacio)
    s.rect(cx - 7, cy - 5, cx - 2, cy + 4, b["dd"])
    s.rect(cx - 6, cy - 4, cx - 3, cy + 3, P["CREAM_D"])
    s.rect(cx - 6, cy - 4, cx - 3, cy - 4, P["CREAM"])
    s.rect(cx - 4, cy - 3, cx + 3, cy + 7, P["OUTLINE"])   # la de delante
    s.rect(cx - 3, cy - 2, cx + 2, cy + 6, P["CREAM"])
    s.rect(cx - 3, cy - 2, cx + 2, cy - 2, P["WHITE"])
    s.rect(cx - 3, cy + 6, cx + 2, cy + 6, P["CREAM_D"])
    star = m["star"]
    sx, sy = cx - 1, cy + 2        # la estrella: cruz de 5 con las puntas
    s.dots([(sx, sy - 2), (sx - 1, sy - 1), (sx, sy - 1), (sx + 1, sy - 1),
            (sx - 2, sy), (sx - 1, sy), (sx, sy), (sx + 1, sy), (sx + 2, sy),
            (sx - 1, sy + 1), (sx + 1, sy + 1), (sx - 2, sy + 2), (sx + 2, sy + 2)], star)
    s.px(sx, sy, M.shade(star, 0.3))
    # rotulo: una banda con letras de mentira
    s.rect(x0 + 2, 23, x1 - 2, 24, b["dd"])
    s.dots([(x, 23) for x in range(x0 + 3, x1 - 2, 2)], m["accent"])
    if tier == 3:
        _gem(s, 15, 6, tier)


def draw_cards_open(s, tier: int) -> None:
    """El sobre rasgado por arriba y las cartas saliendo en abanico."""
    P = _pal()
    m = _materials("cards", tier)
    # las cartas que salen, detras del sobre
    colors = [M.RARITIES["rare"], M.RARITIES["epic"], M.RARITIES["legendary"]]
    for i, (dx, top) in enumerate([(-6, 3), (0, 1), (6, 3)]):
        cx = 15 + dx
        r = colors[i]
        s.rect(cx - 3, top, cx + 3, top + 12, r.dark)
        s.rect(cx - 2, top + 1, cx + 2, top + 11, P["CREAM"])
        s.rect(cx - 2, top + 1, cx + 2, top + 1, P["WHITE"])
        s.rect(cx - 1, top + 3, cx + 1, top + 6, r.base)
        s.px(cx - 1, top + 3, r.light)
    # el sobre, de la mitad para abajo
    b, t = m["body"], m["trim"]
    x0, x1, y0, y1 = 9, 22, 12, 29
    s.rect(x0, y0, x1, y1 - 3, b["m"])
    s.rect(x0, y0, x0 + 1, y1 - 3, b["l"])
    s.rect(x1 - 1, y0, x1, y1 - 3, b["d"])
    for i in range(6):
        s.px(x0 + 6 + i // 2, y1 - 5 - i * 2, b["hi"])
    s.rect(x0, y1 - 2, x1, y1, t["m"])
    s.rect(x0, y1 - 2, x1, y1 - 2, t["l"])
    s.rect(x0, y1, x1, y1, t["dd"])
    _zigzag(s, x0, x1, y1, t["dd"], up=False)
    # el borde rasgado: dientes irregulares de color claro
    rng = random.Random(77 + tier)
    for x in range(x0, x1 + 1):
        h = rng.randint(0, 2)
        s.rect(x, y0 - h, x, y0, b["l"] if x < x1 - 1 else b["d"])
        s.px(x, y0 - h, b["hi"])
    # destellos
    s.dots([(4, 4), (26, 6), (5, 9)], P["SHINE_HI"])
    s.dots([(27, 2), (3, 13)], P["GOLD_HI"])


# --------------------------------------------------------------------------- #
# VINILOS: funda con arte de atardecer y el disco asomando
# --------------------------------------------------------------------------- #

VINYLS_BOX = (3, 6, 21, 27)


def _disc(s, cx: int, cy: int, r: int, m) -> None:
    P = _pal()
    s.ellipse(cx - r, cy - r, cx + r, cy + r, m["disc"])
    for rr in range(r - 2, 3, -2):
        s.ring(cx - rr, cy - rr, cx + rr, cy + rr, m["disc_l"])
    s.ellipse(cx - 3, cy - 3, cx + 3, cy + 3, m["label"])
    s.ellipse(cx - 2, cy - 2, cx + 1, cy + 1, m["label_l"])
    s.px(cx, cy, P["OUTLINE"])
    s.dots([(cx + r - 3, cy - r + 3), (cx + r - 2, cy - r + 5)], P["VINYL_SHEEN"])


def draw_vinyls(s, tier: int) -> None:
    m = _materials("vinyls", tier)
    P = _pal()
    _disc(s, 20, 16, 9, m)                     # el disco, detras de la funda
    x0, x1, y0, y1 = 3, 21, 6, 27
    sl, sky = m["sleeve"], m["sky"]
    s.rect(x0, y0, x1, y1, sl["m"])            # marco de la funda
    s.rect(x0, y0, x1, y0, sl["hi"])
    s.rect(x0, y0, x0, y1, sl["l"])
    s.rect(x1, y0, x1, y1, sl["d"])
    s.rect(x0, y1, x1, y1, sl["dd"])
    # el arte: un atardecer a franjas con el sol asomando
    ax0, ay0, ax1, ay1 = x0 + 2, y0 + 2, x1 - 2, y1 - 2
    bands = [sky["hi"], sky["l"], sky["m"], sky["d"], sky["dd"]]
    h = ay1 - ay0 + 1
    for i, c in enumerate(bands):
        ya = ay0 + i * h // len(bands)
        yb = ay0 + (i + 1) * h // len(bands) - 1
        s.rect(ax0, ya, ax1, yb, c)
    s.pie(ax0 + 3, ay0 + 5, ax1 - 3, ay1 + 2, 180, 360, m["sun"])
    # las rayas del sol que cortan el disco (lo que hace que sea retro)
    for y in (ay0 + 10, ay0 + 12, ay0 + 14):
        s.rect(ax0 + 3, y, ax1 - 3, y, sky["d"])
    # suelo: la linea del horizonte
    s.rect(ax0, ay1 - 2, ax1, ay1, sky["dd"])
    s.rect(ax0, ay1 - 2, ax1, ay1 - 2, sky["d"])
    # pegatina de precio en la esquina
    s.rect(ax0, ay0, ax0 + 3, ay0 + 2, P["CREAM_L"])
    s.px(ax0 + 1, ay0 + 1, P["RED"])
    if tier == 3:
        _gem(s, (ax0 + ax1) // 2, ay0 + 3, tier)


def draw_vinyls_open(s, tier: int) -> None:
    m = _materials("vinyls", tier)
    P = _pal()
    _disc(s, 17, 11, 9, m)                     # el disco, fuera y arriba
    # la funda, caida y de lado, abajo
    sl, sky = m["sleeve"], m["sky"]
    x0, x1, y0, y1 = 4, 27, 20, 28
    s.rect(x0, y0, x1, y1, sl["m"])
    s.rect(x0, y0, x1, y0, sl["hi"])
    s.rect(x0, y1, x1, y1, sl["dd"])
    s.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, sky["m"])
    s.rect(x0 + 2, y0 + 2, x1 - 2, y0 + 3, sky["l"])
    s.rect(x0 + 2, y1 - 3, x1 - 2, y1 - 2, sky["dd"])
    s.pie(12, y0 + 3, 20, y1 + 3, 180, 360, m["sun"])
    s.dots([(3, 4), (28, 8), (27, 3)], P["SHINE_HI"])
    s.dots([(5, 15), (29, 14)], P["GOLD_HI"])


# --------------------------------------------------------------------------- #
# ZAPATILLAS: caja en perspectiva
# --------------------------------------------------------------------------- #

SNEAKERS_BOX = (2, 9, 29, 27)


def _bolt(s, x: int, y: int, m) -> None:
    """El rayo de la marca: una franja en zigzag que cruza la caja."""
    pts = [(x, y + 3), (x + 5, y), (x + 9, y + 3), (x + 14, y), (x + 18, y + 3)]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        s.line([(ax, ay), (bx, by)], m["bolt"], 2)
        s.line([(ax, ay + 2), (bx, by + 2)], m["bolt_d"], 1)


def _shoebox_body(s, m, y_top: int) -> None:
    bx = m["box"]
    x0, x1, y1 = 2, 29, 27
    s.rect(x0, y_top, x1, y1, bx["m"])
    s.rect(x0, y_top, x0, y1, bx["d"])
    s.rect(x1, y_top, x1, y1, bx["d"])
    s.rect(x0, y1, x1, y1, bx["dd"])
    s.rect(x0 + 1, y_top, x1 - 1, y_top + 1, bx["dd"])   # sombra bajo la tapa


def draw_sneakers(s, tier: int) -> None:
    m = _materials("sneakers", tier)
    P = _pal()
    lid, bx = m["lid"], m["box"]
    # la cara de arriba de la tapa, en perspectiva
    s.poly([(5, 9), (26, 9), (29, 13), (2, 13)], lid["l"])
    s.line([(5, 9), (26, 9)], lid["hi"])
    s.line([(4, 11), (27, 11)], lid["m"])
    # el canto de la tapa
    s.rect(1, 13, 30, 16, lid["m"])
    s.rect(1, 13, 30, 13, lid["hi"])
    s.rect(1, 16, 30, 16, lid["dd"])
    s.rect(1, 13, 1, 16, lid["d"])
    s.rect(30, 13, 30, 16, lid["d"])
    _shoebox_body(s, m, 17)
    s.rect(3, 19, 28, 19, bx["l"])                       # luz del frente
    _bolt(s, 5, 20, m)
    # la etiqueta de la talla, con su silueta de zapatilla
    s.rect(21, 21, 27, 25, m["tag"])
    s.rect(21, 25, 27, 25, M.shade(m["tag"], -0.2))
    s.dots([(22, 23), (23, 23), (24, 23), (25, 23), (26, 24), (22, 24), (23, 22)],
           P["OUTLINE"] if tier != 3 else P["NIGHT"])
    if tier == 3:
        _gem(s, 15, 11, tier)


def draw_sneakers_open(s, tier: int) -> None:
    m = _materials("sneakers", tier)
    P = _pal()
    lid = m["lid"]
    # la tapa, levantada y torcida arriba a la derecha
    s.poly([(9, 2), (28, 5), (27, 9), (8, 6)], lid["m"])
    s.line([(9, 2), (28, 5)], lid["hi"])
    s.line([(8, 6), (27, 9)], lid["dd"])
    # papel de seda y la zapatilla asomando
    _shoebox_body(s, m, 15)
    s.rect(3, 12, 28, 15, P["TISSUE"])
    s.dots([(5, 12), (11, 13), (24, 12)], P["WHITE"])
    # la zapatilla (puntera, cordones y suela)
    s.poly([(7, 13), (12, 8), (17, 8), (23, 12), (24, 15), (7, 15)], P["RED_L"])
    s.rect(7, 14, 24, 15, P["CREAM"])
    s.dots([(13, 10), (15, 10), (14, 11), (16, 11)], P["WHITE"])
    s.rect(18, 11, 22, 12, P["RED"])
    bx = m["box"]
    s.rect(3, 17, 28, 17, bx["l"])
    _bolt(s, 5, 19, m)
    s.dots([(4, 4), (30, 11), (6, 8)], P["SHINE_HI"])


# --------------------------------------------------------------------------- #
# ELECTRONICA: caja de producto
# --------------------------------------------------------------------------- #

ELECTRONICS_BOX = (6, 4, 25, 28)


def draw_electronics(s, tier: int) -> None:
    m = _materials("electronics", tier)
    P = _pal()
    bx = m["box"]
    x0, x1, y0, y1 = 6, 25, 6, 28
    # tapa en perspectiva (la caja es mas alta que ancha)
    s.poly([(x0 + 2, 3), (x1 - 2, 3), (x1, y0), (x0, y0)], bx["l"])
    s.line([(x0 + 2, 3), (x1 - 2, 3)], bx["hi"])
    # el precinto que cruza la tapa
    s.rect(14, 3, 17, y0, m["tape"])
    s.rect(17, 3, 17, y0, m["tape_d"])
    # la cara de delante
    s.rect(x0, y0 + 1, x1, y1, bx["m"])
    s.rect(x0, y0 + 1, x0, y1, bx["l"])
    s.rect(x1 - 1, y0 + 1, x1, y1, bx["d"])
    s.rect(x0, y1, x1, y1, bx["dd"])
    # la franja de color de la marca, en diagonal por la esquina
    s.poly([(x0, y1 - 7), (x0 + 7, y1), (x0, y1)], m["band"])
    s.line([(x0, y1 - 7), (x0 + 7, y1)], m["band_l"])
    s.poly([(x1 - 1, y0 + 1), (x1, y0 + 1), (x1, y0 + 5)], m["band_d"])
    # la foto del producto: una consola con su pantalla encendida
    s.rect(x0 + 3, 10, x1 - 3, 19, P["OUTLINE"])
    s.rect(x0 + 4, 11, x1 - 4, 18, P["DARK_SOFT"])
    s.rect(x0 + 6, 12, x1 - 6, 16, P["LCD_D"])
    s.rect(x0 + 7, 13, x1 - 7, 15, P["LCD"])
    s.dots([(x0 + 8, 13), (x0 + 9, 14)], P["LCD_L"])
    s.dots([(x0 + 4, 14), (x1 - 4, 13), (x1 - 4, 15)], P["RED_L"])   # botones
    s.px(x0 + 5, 15, P["TEAL_L"])
    # el nombre del producto, con letras de mentira
    s.rect(x0 + 3, 21, x1 - 3, 22, m["band_d"])
    s.dots([(x, 21) for x in range(x0 + 4, x1 - 3, 2)], m["band_l"])
    # el sello de calidad, abajo a la derecha (en el 3, una joya montada)
    if tier == 3:
        _gem(s, x1 - 4, y1 - 3, tier)
    else:
        s.ellipse(x1 - 6, y1 - 5, x1 - 2, y1 - 1, m["tape"])
        s.px(x1 - 4, y1 - 3, m["tape_d"])


def draw_electronics_open(s, tier: int) -> None:
    m = _materials("electronics", tier)
    P = _pal()
    bx = m["box"]
    x0, x1, y0, y1 = 6, 25, 14, 28
    # la consola saliendo de la caja
    s.rect(8, 3, 23, 13, P["OUTLINE"])
    s.rect(9, 4, 22, 12, P["DARK_SOFT"])
    s.rect(11, 5, 20, 10, P["LCD_D"])
    s.rect(12, 6, 19, 9, P["LCD"])
    s.dots([(13, 6), (14, 7)], P["LCD_L"])
    s.dots([(10, 7), (21, 6), (21, 8)], P["RED_L"])
    # las solapas abiertas
    s.poly([(x0, y0), (x0 - 3, y0 - 5), (x0 + 3, y0 - 4), (x0 + 5, y0)], bx["l"])
    s.poly([(x1, y0), (x1 + 3, y0 - 5), (x1 - 3, y0 - 4), (x1 - 5, y0)], bx["d"])
    # la caja
    s.rect(x0, y0, x1, y1, bx["m"])
    s.rect(x0, y0, x1, y0, bx["dd"])
    s.rect(x0, y0 + 1, x0, y1, bx["l"])
    s.rect(x1 - 1, y0 + 1, x1, y1, bx["d"])
    s.rect(x0, y1, x1, y1, bx["dd"])
    s.poly([(x0, y1 - 6), (x0 + 6, y1), (x0, y1)], m["band"])
    s.rect(x0 + 3, y0 + 4, x1 - 3, y0 + 5, m["band_d"])
    s.dots([(3, 3), (28, 5), (27, 1)], P["SHINE_HI"])
    s.dots([(4, 9), (28, 11)], P["GOLD_HI"])


# --------------------------------------------------------------------------- #
# El dano: rozaduras, desgarro con luz y raja
# --------------------------------------------------------------------------- #

def _masked(s, paint) -> None:
    """Pinta `paint(draw)` SOLO donde ya hay paquete: el dano no se sale de la
    silueta (fuera de ella seria un pixel suelto con su contorno)."""
    layer = Image.new("RGBA", (s.w, s.h), (0, 0, 0, 0))
    paint(ImageDraw.Draw(layer))
    mask = ImageChops.multiply(layer.split()[3], s.img.split()[3])
    s.img.paste(layer, (0, 0), mask)


def _bite(s, x1: int, y0: int, size: int) -> None:
    """Una mordida en la esquina de arriba a la derecha: CAMBIA LA SILUETA, y el
    contorno que pone el generador la sigue, asi que se lee como carton roto."""
    alpha = s.img.split()[3]
    # la esquina de verdad del dibujo, no la de la caja: se busca el primer pixel
    # opaco desde arriba a la derecha
    for y in range(y0, y0 + 6):
        for x in range(x1, x1 - 6, -1):
            if alpha.getpixel((x, y)) > 0:
                for i in range(size):
                    for j in range(size - i):
                        if 0 <= x - i < s.w and 0 <= y + j < s.h:
                            s.img.putpixel((x - i, y + j), (0, 0, 0, 0))
                return


def _tear(d, x0: int, x1: int, y: int, P, glow: int, seed: int) -> None:
    """Un desgarro horizontal, COLUMNA A COLUMNA: el borde levantado (claro), la
    raja (oscura) y debajo la luz del botin que hay dentro. Por columnas y no con
    lineas en diagonal: las diagonales dejaban los colores escalonados y la raja
    se leia como un tablero de ajedrez."""
    rng = random.Random(seed)
    yy = y
    for x in range(x0, x1 + 1):
        if (x - x0) % 2 == 0 and x > x0:
            yy = max(y - 1, min(y + 1, yy + rng.choice((-1, 0, 1))))
        d.point((x, yy - 1), fill=P["CREAM_D"])
        d.point((x, yy), fill=P["NIGHT"])
        for k in range(1, glow + 1):
            d.point((x, yy + k), fill=P["SHINE_HI"] if k == 1 else P["GOLD_XL"])


def damage(s, stage: int, box: Tuple[int, int, int, int], seed: int) -> None:
    """Capa de dano sobre un paquete cerrado. Todo dentro de su silueta.

    d1: rozaduras y una mordida pequena en la esquina.
    d2: la mordida crece y aparece un desgarro con la luz del botin dentro.
    d3: el desgarro cruza el paquete, se abre un segundo y la luz se escapa.
    """
    P = _pal()
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    w = x1 - x0
    rng = random.Random(seed * 31 + stage)

    def paint(d) -> None:
        for _ in range(1 + stage):                     # rozaduras
            x = rng.randint(x0 + 2, x1 - 4)
            y = rng.randint(y0 + 3, y1 - 4)
            d.line([(x, y), (x + 1, y + 1)], fill=P["CREAM_D"])
        if stage >= 2:
            half = max(2, w // 5) if stage == 2 else max(3, w // 3)
            _tear(d, cx - half, cx + half, cy - 2, P, 1 if stage == 2 else 2, seed)
        if stage >= 3:
            _tear(d, cx - 3, cx + 3, cy + 5, P, 1, seed + 7)
            for dx, dy in ((-5, -6), (6, -5), (-4, 8)):
                d.point((cx + dx, cy + dy), fill=P["SHINE_HI"])
    _masked(s, paint)
    _bite(s, x1, y0, 1 + stage)


# --------------------------------------------------------------------------- #
# Registro
# --------------------------------------------------------------------------- #

KINDS = {
    "cards": (draw_cards, draw_cards_open, CARDS_BOX),
    "vinyls": (draw_vinyls, draw_vinyls_open, VINYLS_BOX),
    "sneakers": (draw_sneakers, draw_sneakers_open, SNEAKERS_BOX),
    "electronics": (draw_electronics, draw_electronics_open, ELECTRONICS_BOX),
}


def items() -> Dict[str, Callable]:
    """Las 60 claves de LOOT_ITEMS (sin el prefijo pack_): por tipo y escalon,
    cerrado, abierto y los tres tramos de dano."""
    out: Dict[str, Callable] = {}
    for kind, (closed, opened, box) in KINDS.items():
        for tier in (1, 2, 3):
            key = kind if tier == 1 else f"{kind}{tier}"
            seed = hash(kind) % 997 + tier * 13 if False else (len(kind) * 37 + tier * 13)

            def c(s, f=closed, t=tier):
                f(s, t)

            def o(s, f=opened, t=tier):
                f(s, t)
            out[key] = c
            out[f"{key}_open"] = o
            for stage in (1, 2, 3):
                def d(s, f=closed, t=tier, st=stage, b=box, sd=seed):
                    f(s, t)
                    damage(s, st, b, sd)
                out[f"{key}_d{stage}"] = d
    return out


def install(module) -> Dict[str, Callable]:
    """Lo llama make_sprites con su propio modulo. Devuelve las claves nuevas."""
    global M
    M = module
    return items()
