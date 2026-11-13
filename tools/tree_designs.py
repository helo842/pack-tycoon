#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tree_designs.py - un dibujo PROPIO para cada nodo del arbol del rebirth.

Antes los nodos reutilizaban sprites de otras cosas (el sobre de cartas para el
dano, las zapatillas para la velocidad, las tijeras para el MARTILLO...), asi que
media docena de nodos eran el mismo dibujo y el nombre no casaba con lo que se
veia ("MAZA" con un sobre de cartas). Aqui cada nodo lleva el objeto de su
nombre (el "effect" de SkillTree.NODES): MAZA es una maza, CACTUS un cactus,
FIESTA unos globos...

Se escriben como tree_<id del nodo>.png en Sprites/tree/ (ver sprite_paths.py).
Mismas reglas que el resto del arte: rejilla de 32, contorno de 1 px que pone el
generador (por eso nada toca los bordes 0 y 31), alfa binaria y colores de la
paleta. Este modulo no importa make_sprites: lo recibe en install(), como
loot_designs.
"""

from __future__ import annotations

import math
from typing import Callable, Dict, List, Tuple

M = None  # el modulo make_sprites, puesto por install()

# Los colores se copian del modulo en install(): asi los dibujos se leen como los
# de make_sprites (GOLD, STEEL...) sin un P("...") en cada linea.
OUTLINE = DARK = DARK_SOFT = BROWN_D = BROWN = BROWN_L = None
GOLD_D = GOLD = GOLD_L = GOLD_XL = GOLD_HI = CREAM = CREAM_D = CREAM_L = None
TEAL = TEAL_D = TEAL_L = WHITE = STEEL = STEEL_D = STEEL_DD = SLATE = None
GREEN_D = GREEN = GREEN_L = RED_D = RED = RED_L = RUST_D = RUST_L = None
WOOD_D = WOOD_DD = CARD = CARD_L = CRINKLE = CRINKLE_L = TRANSPARENT = None
LEATHER_HI = LEATHER_L = LEATHER = NIGHT_LL = None
PURPLE_D = PURPLE = PURPLE_L = None
TISSUE = LEATHER_D = LCD = LCD_D = LCD_L = STAR_OFF_L = None


def _star(cx: float, cy: float, r_out: float, r_in: float) -> List[Tuple[int, int]]:
    pts = []
    for i in range(10):
        r = r_out if i % 2 == 0 else r_in
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((round(cx + r * math.cos(a)), round(cy + r * math.sin(a))))
    return pts


def _coin(s, x0: int, y0: int, d: int = 5) -> None:
    s.ellipse(x0, y0, x0 + d, y0 + d, GOLD)
    s.ellipse(x0, y0, x0 + d - 1, y0 + d - 1, GOLD_XL)
    s.px(x0 + 1, y0 + 1, GOLD_HI)


def _speed_lines(s, ys, x0: int = 1, x1: int = 5, color=None) -> None:
    for y in ys:
        s.rect(x0, y, x1, y, color or TEAL_L)


# --------------------------------------------------------------------------- #
# El centro y las cuatro ramas
# --------------------------------------------------------------------------- #

def draw_money(s) -> None:
    """TRASTIENDA: la tiendecita con toldo de rayas y el letrero de la moneda."""
    s.rect(5, 12, 26, 29, CARD_L)                     # fachada
    s.rect(25, 12, 26, 29, CARD)
    s.rect(7, 15, 11, 20, TEAL_D)                     # escaparates
    s.rect(20, 15, 24, 20, TEAL_D)
    s.dots([(8, 16), (9, 16), (21, 16), (22, 16)], TEAL_L)
    s.rect(13, 18, 18, 29, WOOD_D)                    # puerta
    s.rect(13, 18, 18, 18, BROWN)
    s.px(17, 24, GOLD_XL)
    s.rect(3, 7, 28, 11, RED_L)                       # toldo
    for x in range(6, 28, 6):
        s.rect(x, 7, x + 2, 11, CREAM)
    for x in range(4, 28, 3):                         # festones del toldo
        s.px(x, 12, RED if (x // 3) % 2 == 0 else CREAM_D)
    s.rect(8, 2, 23, 6, BROWN)                        # letrero
    s.rect(8, 2, 23, 2, BROWN_L)
    _coin(s, 13, 2, 4)
    s.rect(17, 4, 21, 4, GOLD_D)


def draw_damage(s) -> None:
    """BATE: un bate de madera en diagonal, con la cinta del mango."""
    s.line([(6, 25), (12, 19)], WOOD_D, 2)             # mango
    s.line([(12, 19), (18, 13)], BROWN, 4)
    s.line([(17, 14), (24, 7)], BROWN, 6)              # el cuerpo, que engorda
    s.ellipse(20, 3, 28, 11, BROWN)                    # la punta redonda
    s.line([(14, 15), (24, 5)], BROWN_L, 2)            # el brillo de la madera
    s.line([(7, 23), (10, 20)], RED_L, 2)              # la cinta del puno
    s.ellipse(3, 24, 8, 29, BROWN)                     # el pomo
    s.px(5, 26, BROWN_L)


def draw_speed(s) -> None:
    """REFLEJOS: un cronometro con lineas de velocidad."""
    s.rect(14, 1, 17, 2, STEEL)                       # boton
    s.rect(15, 3, 16, 5, STEEL_D)
    s.rect(23, 5, 25, 7, STEEL_D)
    s.ellipse(6, 5, 27, 27, GOLD)                     # caja
    s.ellipse(6, 5, 26, 26, GOLD_XL)
    s.ellipse(8, 7, 25, 25, CREAM)                    # esfera
    s.arc(9, 8, 22, 22, 190, 260, WHITE)
    for x, y in ((16, 9), (16, 23), (9, 16), (23, 16)):
        s.px(x, y, BROWN_D)
    s.line([(16, 16), (16, 10)], RED)                 # agujas
    s.line([(16, 16), (21, 19)], OUTLINE)
    s.px(16, 16, GOLD_D)
    _speed_lines(s, (11, 16, 21), 1, 4)


def draw_locker(s) -> None:
    """ESCAPARATE: una vitrina de cristal con una copa dentro."""
    s.rect(4, 3, 27, 5, BROWN)                        # tapa
    s.rect(4, 3, 27, 3, BROWN_L)
    s.rect(5, 6, 26, 23, TEAL_D)                      # cristal
    s.rect(5, 6, 5, 23, GOLD_D)
    s.rect(26, 6, 26, 23, GOLD_D)
    s.ellipse(11, 9, 20, 16, GOLD)                    # la copa
    s.ellipse(11, 9, 19, 14, GOLD_XL)
    s.rect(11, 9, 20, 11, GOLD_XL)
    s.px(13, 11, GOLD_HI)
    s.rect(15, 16, 16, 19, GOLD)
    s.rect(12, 20, 19, 22, GOLD_D)
    s.rect(12, 20, 19, 20, GOLD)
    s.line([(7, 20), (12, 7)], TEAL_L)                # reflejos del cristal
    s.line([(22, 22), (25, 14)], TEAL_L)
    s.rect(3, 24, 28, 29, BROWN)                      # peana
    s.rect(3, 24, 28, 25, BROWN_L)
    s.rect(3, 29, 28, 29, BROWN_D)


def draw_spikes(s) -> None:
    """ESPINAS: un tallo de rosa lleno de espinas."""
    s.line([(8, 29), (20, 10)], GREEN_D, 3)
    s.line([(8, 28), (19, 10)], GREEN)
    for x, y, dx in ((10, 25, -3), (13, 21, 3), (15, 17, -3), (18, 14, 3)):
        s.poly([(x, y - 1), (x + dx, y - 2), (x, y + 1)], GREEN_L)
    s.ellipse(3, 14, 11, 19, GREEN)                   # hoja
    s.line([(4, 17), (10, 16)], GREEN_D)
    s.ellipse(15, 2, 28, 13, RED)                     # la rosa
    s.ellipse(16, 3, 26, 10, RED_L)
    s.arc(18, 4, 25, 11, 0, 300, RED_D)
    s.arc(20, 5, 23, 8, 90, 360, RED_D)


# --------------------------------------------------------------------------- #
# El camino del dano, la velocidad y los pinchos
# --------------------------------------------------------------------------- #

def draw_damage_2(s) -> None:
    """PALANCA: una palanca de acero con el punyo de cinta roja."""
    s.line([(7, 28), (21, 7)], STEEL_D, 3)
    s.line([(6, 27), (20, 6)], STEEL)
    s.arc(18, 2, 28, 12, 180, 30, STEEL_D, 3)         # el gancho
    s.arc(18, 2, 28, 12, 190, 330, STEEL)
    s.line([(9, 25), (13, 19)], RED, 4)               # cinta del punyo
    s.line([(9, 23), (12, 19)], RED_L)
    s.dots([(5, 29), (8, 29)], STEEL_DD)              # las unyas de abajo


def draw_damage_3(s) -> None:
    """MAZA: bola de acero con pinchos en un mango de madera."""
    cx, cy = 20.5, 11.0
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        tip = (round(cx + 10 * math.cos(a)), round(cy + 10 * math.sin(a)))
        b1 = (round(cx + 5 * math.cos(a - 0.4)), round(cy + 5 * math.sin(a - 0.4)))
        b2 = (round(cx + 5 * math.cos(a + 0.4)), round(cy + 5 * math.sin(a + 0.4)))
        s.poly([b1, tip, b2], STEEL_D)
    s.line([(5, 28), (16, 16)], BROWN, 3)             # mango
    s.line([(5, 27), (15, 16)], BROWN_L)
    s.dots([(8, 24), (10, 22), (12, 20)], GOLD_D)
    s.ellipse(3, 26, 7, 30, GOLD)
    s.ellipse(14, 5, 27, 17, STEEL_D)                 # la bola
    s.ellipse(14, 5, 25, 15, STEEL)
    s.dots([(17, 8), (18, 8), (17, 9)], WHITE)


def draw_speed_2(s) -> None:
    """CARRERILLA: zapatilla de correr con lineas de velocidad."""
    s.poly([(7, 22), (9, 12), (15, 11), (20, 16), (27, 18), (29, 22)], RED_L)
    s.poly([(9, 19), (28, 19), (29, 22), (7, 22)], RED)
    s.rect(8, 11, 11, 14, RED)                        # talonera
    s.dots([(13, 13), (15, 14), (17, 15), (19, 16)], WHITE)  # cordones
    s.line([(11, 18), (24, 19)], WHITE)
    s.rect(6, 23, 29, 25, WHITE)                      # suela
    s.rect(6, 25, 29, 25, STEEL_D)
    _speed_lines(s, (13, 17, 21), 1, 4, GOLD_XL)


def draw_speed_3(s) -> None:
    """VELOCISTA: la zapatilla con alas, dorada."""
    for i, y in enumerate((5, 8, 11)):                # el ala, tres plumas
        s.ellipse(2 + i * 2, y, 14, y + 4, WHITE)
        s.rect(4 + i * 2, y + 3, 14, y + 3, STEEL)
    s.poly([(9, 23), (11, 13), (17, 12), (22, 17), (28, 19), (30, 23)], GOLD_XL)
    s.poly([(11, 20), (29, 20), (30, 23), (9, 23)], GOLD)
    s.rect(11, 14, 15, 14, GOLD_HI)
    s.dots([(16, 14), (18, 15), (20, 16)], WHITE)
    s.rect(8, 24, 30, 26, CREAM)
    s.rect(8, 26, 30, 26, CREAM_D)


def draw_spikes_2(s) -> None:
    """CARDO: la flor del cardo, morada, sobre su cabeza de pinchos."""
    s.line([(16, 29), (16, 21)], GREEN_D, 2)
    s.poly([(15, 26), (7, 22), (10, 26), (6, 28)], GREEN)     # hojas pinchudas
    s.poly([(17, 25), (25, 21), (22, 25), (26, 27)], GREEN)
    s.ellipse(9, 4, 23, 14, PURPLE)                   # la flor
    for x in range(10, 23, 2):
        s.line([(x, 12), (16 + (x - 16) * 1.3, 3)], PURPLE_L)
    s.ellipse(10, 12, 22, 23, GREEN)                  # la cabeza
    s.ellipse(11, 13, 19, 20, GREEN_L)
    for x, y in ((12, 15), (15, 14), (18, 15), (13, 18), (16, 17), (19, 18), (15, 21)):
        s.px(x, y, GREEN_D)
    for x, y, dx in ((10, 16, -3), (22, 16, 3), (11, 20, -3), (21, 20, 3)):
        s.poly([(x, y - 1), (x + dx, y), (x, y + 1)], GREEN_D)


def draw_spikes_3(s) -> None:
    """CACTUS: un saguaro en su maceta de barro."""
    s.rect(6, 9, 10, 17, GREEN)                       # brazo izquierdo
    s.rect(6, 15, 14, 18, GREEN)
    s.rect(6, 9, 6, 17, GREEN_L)
    s.rect(22, 6, 26, 14, GREEN)                      # brazo derecho
    s.rect(18, 12, 26, 15, GREEN)
    s.rect(26, 6, 26, 14, GREEN_D)
    s.ellipse(12, 2, 20, 8, GREEN)                    # tronco
    s.rect(12, 5, 20, 22, GREEN)
    s.rect(13, 4, 14, 22, GREEN_L)
    s.rect(19, 5, 20, 22, GREEN_D)
    s.rect(16, 5, 16, 22, GREEN_D)
    for x, y in ((12, 8), (20, 11), (12, 14), (20, 18), (7, 11), (25, 9), (14, 19)):
        s.px(x, y, WHITE)
    s.dots([(16, 2), (15, 1), (17, 1)], RED_L)        # la flor
    s.rect(7, 21, 25, 23, RUST_L)                     # maceta
    s.poly([(8, 24), (24, 24), (22, 30), (10, 30)], RUST_D)
    s.rect(7, 21, 25, 21, LEATHER_L)


# --------------------------------------------------------------------------- #
# El rebirth
# --------------------------------------------------------------------------- #

def draw_require(s) -> None:
    """REGATEO: una etiqueta de precio con la flecha roja de rebaja."""
    s.line([(2, 4), (8, 12)], GOLD_D)                 # el cordel
    s.poly([(3, 16), (9, 9), (27, 9), (27, 23), (9, 23)], CREAM_D)
    s.poly([(4, 16), (9, 10), (26, 10), (26, 21), (9, 21)], CREAM)
    s.ellipse(6, 14, 9, 17, CRINKLE)                  # el agujero
    for y in (13, 16, 19):
        s.rect(12, y, 21, y, STEEL_D)
    s.rect(18, 15, 22, 24, RED)                       # la flecha hacia abajo
    s.poly([(14, 24), (26, 24), (20, 30)], RED)
    s.rect(18, 15, 19, 24, RED_L)


def draw_coins(s) -> None:
    """PROPINA: el bote de las propinas, lleno, y una moneda que cae dentro."""
    s.rect(7, 11, 24, 28, TEAL_D)                     # el cristal
    s.ellipse(7, 25, 24, 30, TEAL_D)
    for x0, y0 in ((9, 23), (14, 24), (19, 23), (11, 20), (17, 20), (14, 17)):
        _coin(s, x0, y0, 4)
    s.rect(9, 12, 9, 25, TEAL_L)                      # reflejo
    s.px(10, 13, WHITE)
    s.rect(6, 8, 25, 10, STEEL)                       # boca del bote
    s.rect(6, 10, 25, 10, STEEL_D)
    s.rect(11, 13, 20, 15, CREAM)                     # la etiqueta
    s.rect(14, 14, 17, 14, GOLD_D)
    _coin(s, 13, 1, 5)


def draw_legend(s) -> None:
    """LEYENDA: la corona."""
    s.poly([(4, 21), (4, 9), (10, 15), (16, 5), (22, 15), (28, 9), (28, 21)], GOLD_XL)
    s.poly([(16, 5), (22, 15), (28, 9), (28, 21), (16, 21)], GOLD)
    for x0, y0 in ((2, 6), (14, 2), (26, 6)):
        s.ellipse(x0, y0, x0 + 4, y0 + 4, GOLD_HI)
    s.rect(4, 20, 28, 27, GOLD)                       # la banda
    s.rect(4, 20, 28, 21, GOLD_HI)
    s.rect(4, 27, 28, 27, GOLD_D)
    s.ellipse(7, 22, 11, 26, RED_L)
    s.ellipse(14, 22, 18, 26, TEAL_L)
    s.ellipse(21, 22, 25, 26, RED_L)
    s.dots([(8, 23), (15, 23), (22, 23)], WHITE)


# --------------------------------------------------------------------------- #
# Calidad de vida (la rama de abajo)
# --------------------------------------------------------------------------- #

def draw_qol_carry(s) -> None:
    """SOBRANTE: un bumeran, que vuelve (el golpe que sobra no se pierde)."""
    s.line([(16, 6), (4, 24)], BROWN, 6)
    s.line([(16, 6), (27, 24)], BROWN, 6)
    s.ellipse(12, 3, 20, 10, BROWN)                    # el codo, redondeado
    s.line([(15, 5), (5, 20)], BROWN_L, 2)             # el canto claro
    s.line([(17, 5), (26, 20)], BROWN_L, 2)
    s.rect(8, 15, 10, 17, GOLD_XL)                     # las rayas pintadas
    s.rect(21, 15, 23, 17, GOLD_XL)


def draw_qol_auto_tools(s) -> None:
    """APRENDIZ: la caja de herramientas, con un destornillador y una llave."""
    s.line([(7, 15), (9, 6)], STEEL_D, 2)              # destornillador
    s.rect(7, 2, 11, 7, GOLD_XL)
    s.rect(7, 2, 8, 7, GOLD_HI)
    s.line([(24, 15), (25, 6)], STEEL, 2)              # llave inglesa
    s.ellipse(21, 2, 28, 8, STEEL)
    s.rect(24, 1, 25, 4, TRANSPARENT)
    s.rect(11, 9, 20, 10, STEEL_D)                    # asa
    s.rect(11, 9, 12, 15, STEEL_D)
    s.rect(19, 9, 20, 15, STEEL_D)
    s.rect(3, 15, 28, 28, RED)                        # la caja
    s.rect(3, 15, 28, 16, RED_L)
    s.rect(3, 20, 28, 20, RED_D)
    s.rect(3, 28, 28, 28, RED_D)
    s.rect(14, 18, 17, 22, GOLD)
    s.px(14, 18, GOLD_HI)


def draw_qol_auto_luck(s) -> None:
    """AMULETO: el colgante dorado con la gema turquesa, en su cadena."""
    for i in range(6):
        s.px(5 + i * 2, 2 + i * 2, GOLD_D)
        s.px(26 - i * 2, 2 + i * 2, GOLD_D)
    s.rect(15, 12, 16, 14, GOLD_D)
    s.ellipse(8, 13, 23, 29, GOLD)
    s.ellipse(8, 13, 22, 27, GOLD_XL)
    s.arc(10, 15, 20, 25, 180, 260, GOLD_HI)
    s.ellipse(11, 17, 19, 25, TEAL)
    s.ellipse(12, 18, 17, 23, TEAL_L)
    s.dots([(13, 19), (14, 19)], WHITE)


def draw_qol_auto_crit(s) -> None:
    """ENCARGADO: la carpeta con pinza y la lista de tareas marcada."""
    s.rect(6, 4, 25, 29, BROWN)
    s.rect(6, 4, 7, 29, BROWN_L)
    s.rect(8, 7, 23, 27, CREAM)
    s.rect(12, 2, 19, 6, STEEL)                       # la pinza
    s.rect(12, 6, 19, 6, STEEL_D)
    s.rect(15, 3, 16, 3, STEEL_DD)
    for y in (10, 15, 20):
        s.rect(10, y, 12, y + 2, CREAM_D)
        s.line([(10, y + 1), (11, y + 2), (13, y - 1)], GREEN)
        s.rect(15, y + 1, 21, y + 1, STEEL_D)
    s.rect(10, 25, 12, 25, STEEL_D)


def draw_qol_locker(s) -> None:
    """ARMARIO SOLO: la llave del armario."""
    s.ellipse(2, 8, 14, 20, GOLD)                     # el ojo de la llave
    s.ellipse(2, 8, 13, 19, GOLD_XL)
    s.ellipse(5, 11, 10, 16, TRANSPARENT)
    s.arc(3, 9, 12, 18, 180, 260, GOLD_HI)
    s.rect(13, 12, 29, 16, GOLD)                      # la tija
    s.rect(13, 12, 29, 13, GOLD_XL)
    s.rect(14, 12, 29, 12, GOLD_HI)
    s.rect(21, 17, 23, 22, GOLD)                      # los dientes
    s.rect(26, 17, 28, 20, GOLD)
    s.rect(21, 17, 21, 22, GOLD_XL)


def draw_qol_autostore(s) -> None:
    """AUTO GUARDAR: la caja de carton con la flecha verde que mete dentro."""
    s.poly([(5, 16), (1, 12), (10, 12), (13, 16)], CRINKLE)      # solapas
    s.poly([(26, 16), (30, 12), (21, 12), (18, 16)], CRINKLE_L)
    s.rect(5, 16, 26, 29, CARD_L)
    s.rect(5, 16, 26, 17, CRINKLE_L)
    s.rect(24, 18, 26, 29, CARD)
    s.rect(14, 18, 17, 29, CREAM_D)                   # cinta
    s.rect(13, 1, 18, 8, GREEN)                       # la flecha
    s.poly([(9, 8), (22, 8), (15, 15)], GREEN)
    s.rect(13, 1, 14, 9, GREEN_L)


# --------------------------------------------------------------------------- #
# Las habilidades (arriba)
# --------------------------------------------------------------------------- #

def draw_abil_charge(s) -> None:
    """GOLPE CARGADO: el guante de boxeo con chispas de carga."""
    s.ellipse(4, 11, 11, 20, RED)                     # pulgar
    s.ellipse(7, 5, 25, 22, RED)
    s.ellipse(9, 6, 18, 13, RED_L)
    s.arc(8, 6, 25, 22, 0, 90, RED_D)
    s.rect(10, 21, 22, 28, WHITE)                     # punyo
    s.rect(10, 24, 22, 24, STEEL_D)
    s.rect(10, 28, 22, 28, STEEL)
    s.poly([(27, 1), (23, 7), (25, 7), (23, 12), (29, 5), (27, 5)], GOLD_XL)
    s.dots([(3, 4), (4, 7), (29, 14)], GOLD_HI)


def draw_abil_frenzy(s) -> None:
    """FRENESI: una llamarada."""
    s.poly([(16, 1), (22, 9), (26, 7), (27, 18), (22, 29), (10, 29), (5, 18), (7, 9),
            (11, 13), (12, 5)], RED)
    s.poly([(16, 7), (21, 14), (23, 20), (19, 28), (12, 28), (9, 20), (11, 15), (13, 17)],
           GOLD)
    s.poly([(16, 14), (20, 21), (17, 28), (13, 27), (12, 21)], GOLD_XL)
    s.ellipse(13, 22, 18, 28, GOLD_HI)


def draw_abil_rain(s) -> None:
    """GOLDEN RAIN: una nube que llueve monedas."""
    for x0, y0, x1, y1 in ((3, 6, 13, 15), (9, 2, 22, 14), (18, 5, 28, 15)):
        s.ellipse(x0, y0, x1, y1, WHITE)
    s.rect(6, 10, 25, 15, WHITE)
    s.rect(6, 15, 25, 15, STEEL)
    s.arc(10, 3, 20, 12, 190, 260, CREAM_L)
    for x0, y0 in ((6, 18), (14, 20), (21, 17), (9, 25), (18, 25)):
        _coin(s, x0, y0, 4)


def draw_abil_rain_plus(s) -> None:
    """TORMENTA DORADA: nubarron con el rayo de oro."""
    for x0, y0, x1, y1 in ((2, 7, 12, 16), (8, 2, 22, 15), (18, 6, 29, 16)):
        s.ellipse(x0, y0, x1, y1, SLATE)
    s.rect(5, 11, 26, 17, SLATE)
    s.arc(9, 3, 20, 13, 190, 260, STEEL_DD)
    s.rect(5, 17, 26, 17, DARK_SOFT)
    s.poly([(18, 14), (11, 23), (15, 23), (12, 30), (22, 19), (17, 19), (21, 14)], GOLD_XL)
    s.poly([(15, 23), (12, 30), (22, 19), (19, 19)], GOLD)
    s.dots([(6, 21), (25, 22), (8, 26)], GOLD_HI)


def draw_combo(s) -> None:
    """RITMO: el metronomo."""
    s.poly([(11, 3), (20, 3), (26, 28), (5, 28)], BROWN)
    s.poly([(12, 5), (19, 5), (23, 26), (8, 26)], CREAM_D)
    for y in range(8, 24, 4):
        s.px(15, y, BROWN_D)
    s.line([(15, 25), (22, 6)], STEEL_D, 2)           # el pendulo
    s.rect(18, 12, 21, 14, GOLD)
    s.px(18, 12, GOLD_HI)
    s.rect(4, 27, 27, 29, BROWN_D)
    s.rect(4, 27, 27, 27, BROWN_L)
    s.rect(13, 2, 18, 3, BROWN_L)


def draw_streak(s) -> None:
    """EN RACHA: una estrella-cometa con su estela de fuego."""
    s.poly([(2, 29), (13, 12), (20, 19)], RED)
    s.poly([(5, 26), (14, 14), (18, 18)], GOLD)
    s.poly([(8, 23), (15, 16), (16, 17)], GOLD_XL)
    s.poly(_star(20, 11, 10, 4.5), GOLD_XL)
    s.poly(_star(20, 11, 6, 2.7), GOLD_HI)
    s.dots([(18, 8), (19, 8)], WHITE)


def draw_sweet(s) -> None:
    """PUNTO DULCE: un caramelo envuelto (la zona dorada es lo mas dulce)."""
    s.poly([(2, 9), (9, 14), (9, 18), (2, 23), (4, 16)], GOLD_XL)    # envoltorio
    s.poly([(29, 9), (22, 14), (22, 18), (29, 23), (27, 16)], GOLD_XL)
    s.line([(3, 12), (8, 15)], GOLD_HI)
    s.line([(28, 12), (23, 15)], GOLD)
    s.ellipse(7, 8, 24, 24, WHITE)
    for y in range(8, 25):
        for x in range(7, 25):
            inside = ((x - 15.5) / 8.5) ** 2 + ((y - 16) / 8) ** 2 <= 1.0
            if inside and (x + y) % 6 < 2:
                s.px(x, y, RED_L)
    s.arc(9, 10, 20, 20, 190, 250, CREAM_L)


def draw_happy(s) -> None:
    """FIESTA: dos globos de fiesta con su cuerda."""
    s.ellipse(15, 2, 28, 17, GOLD)                     # el de detras, dorado
    s.ellipse(16, 3, 26, 14, GOLD_XL)
    s.poly([(20, 17), (23, 17), (21, 19)], GOLD)
    s.line([(21, 19), (19, 23), (17, 29)], CREAM_D)
    s.ellipse(3, 5, 18, 22, RED)                       # el de delante, rojo
    s.ellipse(4, 6, 16, 19, RED_L)
    s.rect(6, 9, 7, 11, WHITE)                         # el brillo
    s.poly([(9, 22), (12, 22), (10, 24)], RED)         # el nudo
    s.line([(10, 24), (12, 27), (13, 29)], CREAM_D)


def draw_vip(s) -> None:
    """CLIENTE DE ORO: la chistera con la cinta dorada."""
    s.rect(9, 3, 22, 21, DARK_SOFT)
    s.rect(10, 3, 11, 20, STEEL_DD)
    s.rect(9, 3, 22, 4, STEEL_DD)
    s.rect(9, 16, 22, 19, GOLD)
    s.rect(9, 16, 22, 16, GOLD_HI)
    s.ellipse(2, 19, 29, 27, DARK_SOFT)               # el ala
    s.ellipse(4, 20, 27, 24, STEEL_DD)
    s.rect(9, 19, 22, 21, DARK_SOFT)


def draw_boss(s) -> None:
    """PRORROGA: el reloj de arena."""
    s.poly([(8, 5), (23, 5), (17, 15), (14, 15)], TEAL_D)        # cristal
    s.poly([(14, 16), (17, 16), (23, 26), (8, 26)], TEAL_D)
    s.poly([(10, 7), (21, 7), (16, 14), (15, 14)], GOLD_XL)      # arena
    s.poly([(9, 26), (22, 26), (16, 20), (15, 20)], GOLD_XL)
    s.rect(15, 14, 16, 22, GOLD_XL)
    s.dots([(10, 9), (11, 23)], WHITE)
    s.rect(5, 2, 26, 4, BROWN)                        # marco
    s.rect(5, 2, 26, 2, BROWN_L)
    s.rect(5, 27, 26, 29, BROWN)
    s.rect(5, 29, 26, 29, BROWN_D)
    s.rect(6, 5, 7, 26, BROWN_D)
    s.rect(24, 5, 25, 26, BROWN_D)


def draw_golden(s) -> None:
    """FIEBRE DEL ORO: un lingote de oro con su brillo."""
    s.poly([(3, 26), (22, 26), (25, 15), (8, 15)], GOLD)          # la cara de delante
    s.poly([(8, 15), (25, 15), (28, 9), (12, 9)], GOLD_XL)        # la de arriba
    s.poly([(22, 26), (25, 15), (28, 9), (28, 19)], GOLD_D)       # el canto
    s.rect(9, 19, 19, 21, GOLD_D)                                  # el sello
    s.line([(9, 10), (13, 10)], GOLD_HI)
    s.dots([(22, 3), (21, 4), (23, 4), (22, 5), (22, 2), (22, 6), (20, 4), (24, 4)], WHITE)


# --------------------------------------------------------------------------- #
# Los finales de camino (nodos grandes)
# --------------------------------------------------------------------------- #

def draw_cap_damage(s) -> None:
    """MARTILLO: el mazo de dos caras, enorme."""
    s.rect(14, 12, 17, 29, BROWN)                     # mango
    s.rect(14, 12, 14, 29, BROWN_L)
    s.rect(14, 23, 17, 28, RED)
    s.rect(14, 23, 14, 28, RED_L)
    s.rect(4, 4, 27, 12, STEEL_D)                     # cabeza
    s.rect(4, 4, 27, 7, STEEL)
    s.rect(6, 5, 25, 5, WHITE)
    s.rect(3, 3, 5, 13, STEEL_DD)
    s.rect(26, 3, 28, 13, STEEL_DD)


def draw_cap_speed(s) -> None:
    """TURBO: el cohete."""
    s.poly([(12, 24), (19, 24), (15, 30)], RED)       # la llama
    s.poly([(13, 24), (18, 24), (15, 28)], GOLD_XL)
    s.poly([(11, 15), (5, 25), (11, 22)], RED)        # aletas
    s.poly([(20, 15), (26, 25), (20, 22)], RED)
    s.ellipse(10, 2, 21, 25, WHITE)                   # el cuerpo
    s.rect(18, 8, 21, 22, STEEL)
    s.poly([(12, 6), (15, 1), (19, 6)], RED)          # la punta
    s.ellipse(12, 9, 19, 16, STEEL_D)                 # la ventanilla
    s.ellipse(13, 10, 18, 15, TEAL)
    s.dots([(14, 11), (15, 11)], TEAL_L)


def draw_cap_spikes(s) -> None:
    """ERIZO: un erizo de mar, una bola morada toda pinchos."""
    cx, cy = 15.5, 15.5
    for i in range(16):                               # los pinchos, largos y cortos
        a = i * math.pi / 8
        r = 14 if i % 2 == 0 else 11
        s.line([(round(cx), round(cy)), (round(cx + r * math.cos(a)), round(cy + r * math.sin(a)))],
               PURPLE_D if i % 2 else PURPLE, 2)
    s.ellipse(8, 8, 23, 23, PURPLE_D)                 # el cuerpo
    s.ellipse(9, 9, 21, 21, PURPLE)
    s.ellipse(11, 11, 16, 16, PURPLE_L)               # el brillo
    s.dots([(13, 18), (18, 13), (18, 18)], PURPLE_D)


def draw_cap_rebirth(s) -> None:
    """HUCHA DE ORO: el cerdito dorado con una moneda entrando por la ranura."""
    s.ellipse(3, 13, 7, 17, GOLD_D)                   # la cola
    s.rect(8, 25, 10, 29, GOLD_D)                     # patas
    s.rect(19, 25, 21, 29, GOLD_D)
    s.ellipse(5, 10, 26, 27, GOLD)                    # cuerpo
    s.ellipse(5, 10, 24, 24, GOLD_XL)
    s.arc(7, 12, 18, 20, 180, 260, GOLD_HI)
    s.poly([(18, 10), (21, 5), (23, 11)], GOLD)       # oreja
    s.ellipse(23, 14, 29, 21, GOLD)                   # morro
    s.dots([(25, 17), (27, 17)], GOLD_D)
    s.px(21, 14, OUTLINE)                             # ojo
    s.rect(11, 11, 17, 12, GOLD_D)                    # ranura
    s.rect(13, 3, 15, 10, GOLD_HI)                    # la moneda de canto
    s.rect(15, 3, 15, 10, GOLD)


def draw_cap_aim(s) -> None:
    """OJO DE HALCON: la cabeza del halcon de perfil."""
    s.rect(7, 21, 19, 29, BROWN)                      # cuello
    s.dots([(9, 24), (12, 26), (15, 23), (17, 27)], CREAM_D)
    s.ellipse(4, 3, 24, 25, BROWN)                    # cabeza
    s.ellipse(10, 9, 24, 24, CREAM)                   # mejilla clara
    s.poly([(21, 11), (29, 15), (27, 21), (21, 18)], GOLD_XL)    # pico
    s.poly([(27, 17), (29, 15), (28, 21)], GOLD_D)
    s.ellipse(14, 8, 20, 14, GOLD_XL)                 # el ojo
    s.rect(16, 10, 17, 12, OUTLINE)
    s.px(16, 10, WHITE)
    s.line([(12, 7), (21, 8)], BROWN_D, 2)            # la ceja
    s.arc(6, 5, 18, 17, 180, 250, BROWN_L)


def draw_cap_events(s) -> None:
    """IMAN: el iman de herradura atrayendo una moneda."""
    s.ellipse(4, 9, 27, 30, RED)
    s.ellipse(10, 15, 21, 24, TRANSPARENT)
    s.rect(10, 2, 21, 19, TRANSPARENT)
    s.rect(4, 7, 9, 19, RED)                          # brazos
    s.rect(22, 7, 27, 19, RED)
    s.rect(4, 7, 5, 24, RED_L)
    s.rect(26, 7, 27, 24, RED_D)
    s.rect(4, 3, 9, 7, STEEL)                         # puntas de acero
    s.rect(22, 3, 27, 7, STEEL)
    s.rect(4, 3, 9, 3, WHITE)
    s.rect(22, 3, 27, 3, WHITE)
    _coin(s, 13, 3, 5)
    s.dots([(12, 10), (19, 10), (11, 13), (20, 13)], TEAL_L)


def draw_qol_factory(s) -> None:
    """FABRICA: la nave con tejado de dientes de sierra, chimenea y humo."""
    s.ellipse(17, 1, 23, 6, CREAM_D)                  # humo
    s.ellipse(12, 2, 17, 7, CREAM_D)
    s.rect(21, 4, 25, 15, RUST_D)                     # chimenea
    s.rect(20, 4, 26, 5, STEEL_DD)
    for x in (3, 11, 19):                             # tejado
        s.poly([(x, 15), (x, 9), (x + 8, 15)], STEEL_D)
        s.line([(x, 9), (x + 7, 14)], STEEL)
    s.rect(3, 15, 28, 29, RUST_L)                     # la nave de ladrillo
    for y in range(17, 29, 3):
        for x in range(4 + (y % 2) * 2, 28, 5):
            s.rect(x, y, x + 1, y, RUST_D)
    for x in (6, 20):                                 # ventanas encendidas
        s.rect(x, 18, x + 4, 21, GOLD_XL)
        s.rect(x, 18, x + 4, 18, GOLD_HI)
    s.rect(12, 22, 18, 29, WOOD_D)                    # puerta
    s.rect(12, 22, 18, 22, BROWN)


# --------------------------------------------------------------------------- #
# La ascension (el arbol morado, ver AscensionPanel)
# --------------------------------------------------------------------------- #

def draw_asc_hex(s) -> None:
    """La chapa hexagonal de los nodos de la ascension (no es un nodo: es el marco)."""
    s.poly([(16, 1), (29, 8), (29, 23), (16, 30), (2, 23), (2, 8)], PURPLE)
    s.poly([(16, 4), (26, 10), (26, 21), (16, 27), (5, 21), (5, 10)], PURPLE_D)
    s.poly([(16, 6), (24, 11), (24, 20), (16, 25), (7, 20), (7, 11)], DARK_SOFT)
    s.line([(3, 8), (16, 1), (28, 8)], PURPLE_L)                 # el filo de luz


def draw_asc_hyper(s) -> None:
    """HYPER: una persona morada con los brazos arriba, cargada de energia."""
    s.line([(11, 13), (5, 4)], PURPLE, 3)              # brazos arriba
    s.line([(20, 13), (26, 4)], PURPLE, 3)
    s.line([(14, 21), (11, 29)], PURPLE_D, 3)          # piernas
    s.line([(17, 21), (20, 29)], PURPLE_D, 3)
    s.rect(11, 11, 20, 22, PURPLE)                     # cuerpo
    s.rect(11, 11, 12, 22, PURPLE_L)
    s.ellipse(12, 2, 19, 9, PURPLE_L)                  # cabeza
    s.dots([(14, 5), (17, 5)], WHITE)                  # ojos que brillan
    s.dots([(3, 2), (28, 2), (4, 11), (27, 11)], WHITE)  # chispas


def draw_asc_star(s) -> None:
    """El PUNTO DE ASCENSION: una estrella morada de cinco puntas (la moneda)."""
    pts = [(16, 1), (20, 11), (30, 11), (22, 18), (25, 29),
           (16, 22), (7, 29), (10, 18), (2, 11), (12, 11)]
    s.poly(pts, PURPLE_D)
    s.poly([(16, 4), (19, 13), (27, 13), (20, 18), (22, 26),
            (16, 21), (10, 26), (12, 18), (5, 13), (13, 13)], PURPLE)
    s.poly([(16, 4), (19, 13), (16, 16), (13, 13)], PURPLE_L)      # luz arriba
    s.dots([(15, 8), (16, 7)], WHITE)                              # brillo


# --------------------------------------------------------------------------- #
# La tienda de mascotas (el gachapon, ver PetPanel y PetDB)
# --------------------------------------------------------------------------- #

def draw_pet_dog(s) -> None:
    """PERRO: sentado de frente, orejas caidas y la lengua fuera."""
    s.ellipse(8, 16, 23, 29, BROWN)                   # cuerpo
    s.ellipse(11, 20, 20, 29, CREAM_D)                # pecho
    s.rect(4, 5, 8, 15, BROWN_D)                      # orejas
    s.rect(23, 5, 27, 15, BROWN_D)
    s.ellipse(7, 4, 24, 18, BROWN_L)                  # cabeza
    s.ellipse(11, 11, 20, 17, CREAM)                  # hocico
    s.rect(14, 11, 17, 12, DARK)                      # nariz
    s.rect(10, 7, 12, 9, DARK)                        # ojos
    s.rect(19, 7, 21, 9, DARK)
    s.dots([(10, 7), (19, 7)], WHITE)
    s.rect(15, 15, 16, 17, RED_L)                     # lengua


def draw_pet_cat(s) -> None:
    """GATO: gris, con la cola en gancho y los ojos verdes."""
    s.line([(22, 27), (28, 22), (28, 15)], STEEL_D, 2)  # cola
    s.ellipse(8, 17, 23, 29, STEEL_D)                 # cuerpo
    s.poly([(7, 12), (8, 2), (14, 7)], STEEL)         # orejas
    s.poly([(24, 12), (23, 2), (17, 7)], STEEL)
    s.ellipse(7, 6, 24, 20, STEEL)                    # cabeza
    s.poly([(9, 7), (9, 4), (11, 6)], RED_L)          # dentro de las orejas
    s.poly([(22, 7), (22, 4), (20, 6)], RED_L)
    s.rect(11, 11, 12, 13, GREEN_L)                   # ojos
    s.rect(19, 11, 20, 13, GREEN_L)
    s.rect(15, 15, 16, 15, RED_L)                     # nariz
    s.dots([(4, 14), (5, 15), (26, 15), (27, 14)], WHITE)  # bigotes


def draw_pet_frog(s) -> None:
    """RANA: rechoncha, con los ojos saltones."""
    s.rect(3, 26, 9, 29, GREEN_D)                     # patas
    s.rect(22, 26, 28, 29, GREEN_D)
    s.ellipse(5, 12, 26, 29, GREEN)                   # cuerpo
    s.ellipse(10, 20, 21, 29, GREEN_L)                # barriga
    s.ellipse(5, 5, 13, 13, GREEN)                    # ojos saltones
    s.ellipse(18, 5, 26, 13, GREEN)
    s.ellipse(7, 7, 11, 11, WHITE)
    s.ellipse(20, 7, 24, 11, WHITE)
    s.rect(9, 8, 10, 10, DARK)
    s.rect(22, 8, 23, 10, DARK)
    s.line([(10, 16), (15, 18), (21, 16)], GREEN_D)  # sonrisa


def draw_pet_fish(s) -> None:
    """PEZ: de lado, con su aleta y dos burbujas."""
    s.poly([(2, 8), (10, 16), (2, 24)], TEAL_D)       # cola
    s.poly([(13, 9), (19, 3), (22, 9)], TEAL_D)       # aleta de arriba
    s.ellipse(7, 7, 28, 25, TEAL)                     # cuerpo
    s.ellipse(10, 16, 26, 24, TEAL_L)                 # barriga
    s.ellipse(20, 11, 24, 15, WHITE)                  # ojo
    s.rect(22, 12, 23, 14, DARK)
    s.dots([(12, 12), (15, 10), (14, 14), (17, 12)], TEAL_D)  # escamas
    s.dots([(28, 4), (26, 2)], WHITE)                 # burbujas


def draw_pet_fox(s) -> None:
    """ZORRO: naranja, cara de triangulo y la punta de la cola blanca."""
    s.line([(22, 27), (28, 20), (28, 13)], RUST_L, 3)  # cola
    s.rect(27, 11, 29, 13, CREAM)
    s.ellipse(9, 17, 23, 29, RUST_L)                  # cuerpo
    s.ellipse(12, 21, 20, 29, CREAM)                  # pecho
    s.poly([(5, 9), (6, 1), (13, 6)], RUST_L)         # orejas
    s.poly([(26, 9), (25, 1), (18, 6)], RUST_L)
    s.poly([(7, 6), (7, 3), (10, 6)], DARK)
    s.poly([(24, 6), (24, 3), (21, 6)], DARK)
    s.poly([(4, 9), (16, 5), (27, 9), (16, 21)], RUST_L)  # cabeza
    s.poly([(7, 11), (16, 15), (24, 11), (16, 21)], CREAM)  # mejillas
    s.rect(15, 19, 16, 20, DARK)                      # nariz
    s.rect(10, 9, 12, 11, DARK)                       # ojos
    s.rect(19, 9, 21, 11, DARK)
    s.dots([(10, 9), (19, 9)], WHITE)


def draw_pet_dragon(s) -> None:
    """DRAGON: rojo y regordete, con alas, cuernos de oro y barriga dorada."""
    s.poly([(2, 7), (11, 15), (6, 21)], RED_D)        # alas
    s.poly([(29, 7), (20, 15), (25, 21)], RED_D)
    s.line([(20, 27), (27, 28), (29, 24)], RED, 2)    # cola
    s.ellipse(9, 15, 22, 29, RED)                     # cuerpo
    s.ellipse(12, 19, 19, 29, GOLD_L)                 # barriga
    s.poly([(10, 6), (9, 1), (13, 4)], GOLD)          # cuernos
    s.poly([(21, 6), (22, 1), (18, 4)], GOLD)
    s.ellipse(8, 3, 23, 17, RED_L)                    # cabeza
    s.rect(11, 8, 13, 10, WHITE)                      # ojos
    s.rect(18, 8, 20, 10, WHITE)
    s.px(12, 9, DARK)
    s.px(19, 9, DARK)
    s.dots([(14, 14), (17, 14)], RED_D)               # orificios de la nariz


def draw_pet_capsule(s) -> None:
    """La capsula del gachapon, cerrada: morada arriba y blanca abajo."""
    s.pie(4, 4, 27, 27, 0, 180, CREAM_L)
    s.pie(4, 4, 27, 27, 180, 360, PURPLE)
    s.rect(4, 15, 27, 16, PURPLE_D)                   # la junta
    s.ellipse(9, 7, 13, 10, PURPLE_L)                 # brillo
    s.px(10, 8, WHITE)


def draw_pet_machine(s) -> None:
    """La maquina del gachapon: la cupula llena de capsulas y la rueda."""
    s.ellipse(5, 1, 26, 19, TEAL_L)                   # la cupula de cristal
    for x, y, c in [(8, 10, PURPLE), (14, 11, GOLD), (19, 9, GREEN),
                    (11, 5, RED_L), (17, 4, PURPLE_L), (21, 13, CREAM_L)]:
        s.ellipse(x, y, x + 4, y + 4, c)
    s.line([(8, 6), (10, 4)], WHITE)                  # reflejo
    s.rect(7, 17, 24, 29, RED)                        # cuerpo
    s.rect(7, 17, 8, 29, RED_L)
    s.rect(23, 17, 24, 29, RED_D)
    s.rect(5, 16, 26, 17, RED_D)                      # el aro de la cupula
    s.ellipse(13, 19, 18, 24, STEEL)                  # la rueda
    s.rect(15, 19, 16, 24, STEEL_D)
    s.rect(12, 26, 19, 29, DARK)                      # la salida


# --- MAQUINA DE ORO (10 monedas) ---------------------------------------------

def draw_pet_hamster(s) -> None:
    """HAMSTER: una bola con mofletes llenos y orejitas."""
    s.ellipse(6, 8, 25, 28, LEATHER_L)                 # cuerpo
    s.ellipse(10, 16, 21, 28, CREAM)                   # barriga
    s.ellipse(6, 5, 11, 10, LEATHER)                   # orejas
    s.ellipse(20, 5, 25, 10, LEATHER)
    s.ellipse(7, 6, 10, 9, RED_L)
    s.ellipse(21, 6, 24, 9, RED_L)
    s.ellipse(4, 13, 11, 20, CREAM)                    # mofletes
    s.ellipse(20, 13, 27, 20, CREAM)
    s.rect(11, 11, 12, 13, DARK)                       # ojos
    s.rect(19, 11, 20, 13, DARK)
    s.dots([(11, 11), (19, 11)], WHITE)
    s.rect(15, 15, 16, 15, RED)                        # nariz
    s.rect(12, 27, 14, 29, LEATHER)                    # patitas
    s.rect(17, 27, 19, 29, LEATHER)


def draw_pet_bunny(s) -> None:
    """CONEJO: blanco, orejas largas de pie y un trebol en la mano."""
    s.ellipse(8, 2, 13, 15, TISSUE)                    # orejas
    s.ellipse(18, 2, 23, 15, TISSUE)
    s.rect(10, 4, 11, 12, RED_L)
    s.rect(20, 4, 21, 12, RED_L)
    s.ellipse(8, 18, 23, 30, TISSUE)                   # cuerpo
    s.ellipse(7, 9, 24, 22, WHITE)                     # cabeza
    s.rect(11, 14, 12, 16, DARK)                       # ojos
    s.rect(19, 14, 20, 16, DARK)
    s.rect(15, 17, 16, 18, RED_L)                      # nariz
    s.ellipse(22, 22, 27, 27, GREEN)                   # el trebol de la suerte
    s.ellipse(24, 20, 29, 25, GREEN_L)
    s.line([(24, 26), (22, 29)], GREEN_D)


def draw_pet_owl(s) -> None:
    """BUHO: marron, ojazos de oro que no fallan (critico)."""
    s.poly([(6, 4), (11, 9), (6, 11)], BROWN_D)        # penachos
    s.poly([(25, 4), (20, 9), (25, 11)], BROWN_D)
    s.ellipse(5, 6, 26, 29, BROWN)                     # cuerpo
    s.ellipse(10, 15, 21, 28, CREAM_D)                 # pecho
    s.dots([(13, 19), (17, 19), (15, 22), (12, 24), (18, 24)], BROWN_L)
    s.ellipse(6, 7, 15, 16, CREAM)                     # caras de los ojos
    s.ellipse(16, 7, 25, 16, CREAM)
    s.ellipse(8, 9, 13, 14, GOLD_XL)
    s.ellipse(18, 9, 23, 14, GOLD_XL)
    s.rect(10, 11, 11, 12, DARK)
    s.rect(20, 11, 21, 12, DARK)
    s.poly([(14, 14), (17, 14), (15, 18)], GOLD)       # pico
    s.rect(11, 28, 13, 29, GOLD)                       # patas
    s.rect(18, 28, 20, 29, GOLD)


def draw_pet_parrot(s) -> None:
    """LORO: verde con la cabeza roja, el pico de gancho y una moneda."""
    s.poly([(13, 22), (19, 22), (17, 30), (14, 30)], GREEN_D)   # cola
    s.ellipse(8, 10, 22, 26, GREEN)                    # cuerpo
    s.ellipse(14, 12, 22, 24, GREEN_L)                 # ala
    s.ellipse(7, 2, 21, 15, RED)                       # cabeza
    s.ellipse(9, 4, 15, 9, RED_L)
    s.ellipse(14, 6, 18, 10, WHITE)                    # ojo
    s.rect(16, 7, 17, 9, DARK)
    s.poly([(19, 7), (26, 9), (24, 14), (20, 12)], GOLD_XL)    # pico
    s.poly([(20, 12), (24, 14), (21, 15)], GOLD_D)
    s.ellipse(22, 19, 29, 26, GOLD_XL)                 # moneda
    s.rect(25, 21, 26, 24, GOLD_D)


def draw_pet_turtle(s) -> None:
    """TORTUGA: el caparazon lleno de pinchos."""
    s.ellipse(22, 14, 29, 21, GREEN_L)                 # cabeza
    s.rect(25, 16, 26, 17, DARK)
    s.rect(5, 23, 9, 27, GREEN_L)                      # patas
    s.rect(19, 23, 23, 27, GREEN_L)
    s.pie(2, 9, 26, 33, 180, 360, GREEN_D)             # caparazon
    s.pie(5, 12, 23, 30, 180, 360, GREEN)
    s.rect(2, 21, 26, 23, BROWN_L)                     # borde
    for x, y in [(6, 13), (13, 9), (20, 13)]:          # los pinchos
        s.poly([(x - 2, y + 2), (x, y - 4), (x + 2, y + 2)], STEEL)
        s.px(x, y - 3, WHITE)
    s.dots([(9, 17), (14, 15), (18, 17)], GREEN_L)


def draw_pet_bear(s) -> None:
    """OSO: marron, con guantes de boxeo rojos (pega fuerte)."""
    s.ellipse(5, 3, 11, 9, BROWN)                      # orejas
    s.ellipse(20, 3, 26, 9, BROWN)
    s.ellipse(7, 5, 9, 7, BROWN_L)
    s.ellipse(22, 5, 24, 7, BROWN_L)
    s.ellipse(7, 15, 24, 30, BROWN)                    # cuerpo
    s.ellipse(11, 19, 20, 29, BROWN_L)
    s.ellipse(6, 4, 25, 19, BROWN)                     # cabeza
    s.ellipse(11, 11, 20, 18, CREAM_D)                 # hocico
    s.rect(14, 12, 17, 13, DARK)
    s.rect(10, 8, 11, 10, DARK)                        # ojos de pelea
    s.rect(20, 8, 21, 10, DARK)
    s.line([(9, 6), (12, 7)], BROWN_D)
    s.line([(19, 7), (22, 6)], BROWN_D)
    s.ellipse(1, 17, 9, 25, RED)                       # guantes
    s.ellipse(22, 17, 30, 25, RED)
    s.ellipse(2, 18, 5, 21, RED_L)
    s.ellipse(23, 18, 26, 21, RED_L)


# --- MAQUINA DE HIELO (100 monedas) ------------------------------------------

def draw_pet_penguin(s) -> None:
    """PINGUINO: frac negro, barriga blanca y bufanda."""
    s.ellipse(7, 3, 24, 30, SLATE)                     # cuerpo
    s.ellipse(10, 11, 21, 29, WHITE)                   # barriga
    s.ellipse(10, 5, 21, 13, WHITE)                    # cara
    s.rect(12, 7, 13, 9, DARK)
    s.rect(18, 7, 19, 9, DARK)
    s.poly([(14, 10), (17, 10), (15, 13)], GOLD_L)     # pico
    s.rect(9, 14, 22, 15, RED_L)                       # bufanda
    s.rect(19, 15, 21, 20, RED_L)
    s.poly([(7, 14), (3, 22), (8, 21)], SLATE)         # aletas
    s.poly([(24, 14), (28, 22), (23, 21)], SLATE)
    s.rect(10, 29, 14, 30, GOLD_L)                     # patas
    s.rect(17, 29, 21, 30, GOLD_L)


def draw_pet_seal(s) -> None:
    """FOCA: gris, tumbada, con una pelota en la nariz."""
    s.ellipse(14, 2, 21, 9, RED_L)                     # pelota
    s.rect(17, 2, 18, 9, WHITE)
    s.poly([(3, 26), (1, 30), (8, 28)], STEEL_DD)      # cola
    s.ellipse(3, 16, 26, 30, STEEL_D)                  # cuerpo
    s.ellipse(9, 20, 24, 29, STEEL)
    s.ellipse(12, 8, 27, 21, STEEL_D)                  # cabeza
    s.ellipse(17, 14, 25, 20, STEEL)                   # hocico
    s.rect(15, 11, 16, 12, DARK)                       # ojos
    s.rect(22, 11, 23, 12, DARK)
    s.rect(20, 14, 21, 15, DARK)
    s.dots([(17, 17), (16, 18), (25, 17), (26, 18)], WHITE)  # bigotes
    s.poly([(10, 24), (6, 29), (13, 28)], STEEL_DD)    # aleta


def draw_pet_octopus(s) -> None:
    """PULPO: rosa, ocho patas que pinchan."""
    for x in (4, 9, 14, 19, 24):                       # patas
        s.line([(x + 2, 18), (x, 25), (x + 2, 29)], LEATHER, 3)
    s.ellipse(5, 2, 26, 22, LEATHER_L)                 # cabeza
    s.ellipse(9, 4, 15, 9, LEATHER_HI)                 # brillo
    s.ellipse(9, 11, 14, 16, WHITE)                    # ojos
    s.ellipse(17, 11, 22, 16, WHITE)
    s.rect(11, 13, 12, 15, DARK)
    s.rect(19, 13, 20, 15, DARK)
    s.line([(14, 18), (17, 18)], LEATHER_D)
    s.dots([(6, 27), (11, 26), (16, 27), (21, 26), (26, 27)], LEATHER_HI)  # ventosas


def draw_pet_wolf(s) -> None:
    """LOBO: gris de invierno, colmillos fuera y ojos azules."""
    s.poly([(5, 10), (7, 1), (13, 7)], STEEL_DD)       # orejas
    s.poly([(26, 10), (24, 1), (18, 7)], STEEL_DD)
    s.ellipse(8, 17, 23, 30, STEEL_DD)                 # cuerpo
    s.ellipse(12, 20, 19, 30, STEEL)
    s.poly([(4, 10), (16, 4), (27, 10), (22, 20), (9, 20)], STEEL_D)   # cabeza
    s.poly([(10, 14), (21, 14), (16, 23)], STEEL)      # hocico
    s.rect(15, 15, 16, 16, DARK)
    s.dots([(14, 20), (17, 20)], WHITE)                # colmillos
    s.dots([(14, 21), (17, 21)], WHITE)
    s.rect(10, 10, 12, 11, TEAL_L)                     # ojos
    s.rect(19, 10, 21, 11, TEAL_L)
    s.line([(9, 8), (13, 9)], DARK)                    # cejas de enfado
    s.line([(18, 9), (22, 8)], DARK)


def draw_pet_yeti(s) -> None:
    """YETI: bola de pelo blanco, cara azul y unos punos enormes."""
    s.ellipse(5, 4, 26, 29, WHITE)                     # cuerpo
    s.dots([(7, 9), (24, 9), (6, 16), (25, 16), (8, 24), (23, 25)], TISSUE)
    s.ellipse(9, 7, 22, 18, TEAL_L)                    # cara
    s.rect(11, 10, 13, 12, DARK)
    s.rect(18, 10, 20, 12, DARK)
    s.rect(12, 15, 19, 16, TEAL_D)                     # boca
    s.dots([(13, 15), (17, 15)], WHITE)
    s.ellipse(1, 18, 9, 27, TISSUE)                    # punos
    s.ellipse(22, 18, 30, 27, TISSUE)
    s.rect(9, 28, 13, 30, TEAL_L)                      # pies
    s.rect(18, 28, 22, 30, TEAL_L)


def draw_pet_whale(s) -> None:
    """BALLENA: azul, sonriente, echando un chorro."""
    s.line([(16, 9), (16, 4)], TEAL_L, 2)              # chorro
    s.dots([(13, 3), (19, 3), (12, 5), (20, 5)], TEAL_L)
    s.poly([(25, 16), (30, 10), (30, 23)], TEAL_D)     # cola
    s.ellipse(2, 9, 27, 27, TEAL)                      # cuerpo
    s.ellipse(4, 18, 24, 27, CREAM)                    # barriga
    for y in (20, 23):
        s.line([(7, y), (20, y)], CREAM_D)
    s.rect(8, 14, 9, 15, DARK)                         # ojo
    s.px(8, 14, WHITE)
    s.line([(4, 17), (7, 19), (11, 18)], TEAL_D)       # sonrisa
    s.poly([(12, 24), (17, 30), (19, 25)], TEAL_D)     # aleta


# --- MAQUINA COSMICA (1 punto de ascension) -----------------------------------

def draw_pet_robot(s) -> None:
    """ROBOT: caja de acero con pantalla y antena."""
    s.line([(16, 6), (16, 2)], STEEL_DD)               # antena
    s.ellipse(14, 0, 18, 3, RED_L)
    s.rect(6, 6, 25, 17, STEEL)                        # cabeza
    s.rect(8, 8, 23, 15, LCD_D)                        # pantalla
    s.rect(10, 10, 12, 12, LCD)                        # ojos
    s.rect(19, 10, 21, 12, LCD)
    s.line([(12, 14), (19, 14)], LCD_L)
    s.rect(9, 18, 22, 28, STEEL_D)                     # cuerpo
    s.rect(12, 20, 19, 24, STEEL_DD)
    s.dots([(13, 22), (16, 22)], GOLD_XL)
    s.rect(3, 19, 7, 25, STEEL_DD)                     # brazos
    s.rect(24, 19, 28, 25, STEEL_DD)
    s.rect(10, 28, 13, 30, DARK_SOFT)                  # ruedas
    s.rect(18, 28, 21, 30, DARK_SOFT)


def draw_pet_alien(s) -> None:
    """ALIEN: verde, cabezon, ojos negros enormes y dos antenas."""
    s.line([(10, 6), (7, 1)], LCD_D)                   # antenas
    s.line([(21, 6), (24, 1)], LCD_D)
    s.ellipse(5, 0, 9, 3, GOLD_XL)
    s.ellipse(22, 0, 26, 3, GOLD_XL)
    s.ellipse(11, 20, 20, 30, LCD_L)                   # cuerpo
    s.ellipse(4, 4, 27, 23, LCD)                       # cabeza
    s.poly([(7, 11), (14, 13), (13, 18), (8, 16)], DARK)     # ojos
    s.poly([(24, 11), (17, 13), (18, 18), (23, 16)], DARK)
    s.dots([(9, 13), (22, 13)], WHITE)
    s.line([(14, 20), (17, 20)], LCD_D)


def draw_pet_ghost(s) -> None:
    """FANTASMA: sabana blanca con bajo de ondas y ojos que miran de lado."""
    s.ellipse(5, 2, 26, 22, TISSUE)                    # cabeza
    s.rect(5, 12, 26, 26, TISSUE)
    for x in (5, 12, 19):                              # el bajo de ondas
        s.pie(x, 23, x + 7, 30, 0, 180, TISSUE)
    s.ellipse(8, 3, 14, 8, WHITE)                      # brillo
    s.ellipse(9, 10, 14, 16, DARK)                     # ojos
    s.ellipse(17, 10, 22, 16, DARK)
    s.rect(12, 11, 13, 12, WHITE)
    s.rect(20, 11, 21, 12, WHITE)
    s.ellipse(13, 18, 18, 22, DARK_SOFT)               # boca de "uuh"


def draw_pet_phoenix(s) -> None:
    """FENIX: pajaro de fuego, alas abiertas y cola de llamas."""
    s.poly([(12, 22), (8, 30), (16, 26), (24, 30), (20, 22)], RED)     # cola
    s.poly([(14, 24), (16, 30), (18, 24)], GOLD_XL)
    s.poly([(12, 14), (1, 5), (3, 14), (1, 20), (12, 20)], GOLD)      # alas
    s.poly([(20, 14), (30, 5), (28, 14), (30, 20), (20, 20)], GOLD)
    s.poly([(12, 15), (5, 10), (6, 17)], GOLD_XL)
    s.poly([(20, 15), (26, 10), (25, 17)], GOLD_XL)
    s.ellipse(10, 11, 21, 25, RED_L)                   # cuerpo
    s.ellipse(13, 15, 18, 24, GOLD_XL)
    s.ellipse(11, 3, 20, 13, RED_L)                    # cabeza
    s.poly([(14, 4), (15, 0), (17, 4)], GOLD_XL)       # cresta
    s.rect(13, 7, 14, 8, DARK)
    s.rect(17, 7, 18, 8, DARK)
    s.poly([(15, 9), (17, 9), (16, 12)], GOLD_HI)      # pico


def draw_pet_unicorn(s) -> None:
    """UNICORNIO: blanco, cuerno de oro y crin morada."""
    s.poly([(18, 7), (25, 0), (21, 9)], GOLD_XL)       # cuerno
    s.dots([(21, 5), (23, 3)], GOLD_D)
    s.ellipse(5, 16, 22, 28, WHITE)                    # cuerpo
    s.rect(7, 25, 9, 30, TISSUE)                       # patas
    s.rect(17, 25, 19, 30, TISSUE)
    s.poly([(4, 18), (1, 26), (5, 25)], PURPLE)        # cola
    s.ellipse(12, 5, 27, 18, WHITE)                    # cabeza
    s.ellipse(20, 12, 29, 19, TISSUE)                  # hocico
    s.poly([(10, 6), (15, 4), (14, 20), (9, 18)], PURPLE)    # crin
    s.poly([(12, 8), (15, 6), (14, 14)], PURPLE_L)
    s.rect(19, 10, 20, 11, DARK)                       # ojo
    s.px(26, 15, DARK_SOFT)


def draw_pet_golem(s) -> None:
    """GOLEM: piedra con cristales morados; el que mas pega."""
    s.rect(7, 4, 24, 17, STEEL_DD)                        # cabeza
    s.rect(9, 6, 22, 9, STEEL_D)
    s.rect(10, 11, 12, 13, PURPLE_L)                   # ojos de cristal
    s.rect(19, 11, 21, 13, PURPLE_L)
    s.rect(5, 17, 26, 28, STEEL_DD)                       # cuerpo
    s.poly([(12, 19), (16, 17), (19, 21), (15, 26)], PURPLE)  # cristal del pecho
    s.poly([(14, 19), (16, 18), (16, 23)], PURPLE_L)
    s.rect(1, 16, 6, 25, STEEL_D)                   # brazos de roca
    s.rect(25, 16, 30, 25, STEEL_D)
    s.rect(7, 28, 12, 30, STEEL_DD)                       # pies
    s.rect(19, 28, 24, 30, STEEL_DD)
    s.dots([(8, 20), (23, 22), (9, 25)], DARK_SOFT)    # grietas


# --------------------------------------------------------------------------- #
# Las maquinas caras del gachapon, en ORO, HIELO y COSMICO (cada una con sus
# mascotas propias, dibujadas arriba). La maquina no se dibuja otra vez: se
# repinta el dibujo de siempre cambiando cada color
# por el de la gama del tono que tenga (oscuro, medio, claro, muy claro). Los
# ojos y el contorno (DARK, WHITE, OUTLINE) se quedan, o no se leeria la cara.
# --------------------------------------------------------------------------- #

PET_VARIANTS = ("gold", "ice", "cosmic")


def _ramp(variant: str):
    return {"gold": (GOLD_D, GOLD, GOLD_L, GOLD_XL),
            "ice": (TEAL_D, TEAL, TEAL_L, CREAM_L),
            "cosmic": (PURPLE_D, PURPLE, PURPLE_L, CREAM_L)}[variant]


class _Recolor:
    """Hace de Sprite, pero cambia cada color RGBA que le pasan por el de la gama."""

    def __init__(self, s, ramp) -> None:
        self._s = s
        self._ramp = ramp

    def _map(self, a):
        if not (isinstance(a, tuple) and len(a) == 4 and all(isinstance(v, int) for v in a)):
            return a
        if a in (DARK, WHITE, OUTLINE, TRANSPARENT):
            return a
        lum = (0.299 * a[0] + 0.587 * a[1] + 0.114 * a[2]) / 255.0
        return self._ramp[0 if lum < 0.33 else 1 if lum < 0.5 else 2 if lum < 0.72 else 3]

    def __getattr__(self, name):
        attr = getattr(self._s, name)
        if not callable(attr):
            return attr
        return lambda *a, **k: attr(*[self._map(x) for x in a],
                                    **{n: self._map(v) for n, v in k.items()})


def _variant(fn: Callable, variant: str) -> Callable:
    return lambda s: fn(_Recolor(s, _ramp(variant)))


DRAWINGS: Dict[str, Callable] = {
    "money": draw_money, "damage": draw_damage, "speed": draw_speed,
    "locker": draw_locker, "spikes": draw_spikes,
    "damage_2": draw_damage_2, "damage_3": draw_damage_3,
    "speed_2": draw_speed_2, "speed_3": draw_speed_3,
    "spikes_2": draw_spikes_2, "spikes_3": draw_spikes_3,
    "require": draw_require, "coins": draw_coins, "legend": draw_legend,
    "qol_carry": draw_qol_carry, "qol_auto_tools": draw_qol_auto_tools,
    "qol_auto_luck": draw_qol_auto_luck, "qol_auto_crit": draw_qol_auto_crit,
    "qol_locker": draw_qol_locker, "qol_autostore": draw_qol_autostore,
    "abil_charge": draw_abil_charge, "abil_frenzy": draw_abil_frenzy,
    "abil_rain": draw_abil_rain, "abil_rain_plus": draw_abil_rain_plus,
    "combo": draw_combo, "streak": draw_streak, "sweet": draw_sweet,
    "happy": draw_happy, "vip": draw_vip, "boss": draw_boss, "golden": draw_golden,
    "cap_damage": draw_cap_damage, "cap_speed": draw_cap_speed,
    "cap_spikes": draw_cap_spikes, "cap_rebirth": draw_cap_rebirth,
    "cap_aim": draw_cap_aim, "cap_events": draw_cap_events,
    "qol_factory": draw_qol_factory,
    "asc_hex": draw_asc_hex, "asc_hyper": draw_asc_hyper, "asc_star": draw_asc_star,
    "pet_dog": draw_pet_dog, "pet_cat": draw_pet_cat, "pet_frog": draw_pet_frog,
    "pet_fish": draw_pet_fish, "pet_fox": draw_pet_fox, "pet_dragon": draw_pet_dragon,
    "pet_capsule": draw_pet_capsule, "pet_machine": draw_pet_machine,
    "pet_hamster": draw_pet_hamster, "pet_bunny": draw_pet_bunny, "pet_owl": draw_pet_owl,
    "pet_parrot": draw_pet_parrot, "pet_turtle": draw_pet_turtle, "pet_bear": draw_pet_bear,
    "pet_penguin": draw_pet_penguin, "pet_seal": draw_pet_seal,
    "pet_octopus": draw_pet_octopus, "pet_wolf": draw_pet_wolf, "pet_yeti": draw_pet_yeti,
    "pet_whale": draw_pet_whale, "pet_robot": draw_pet_robot, "pet_alien": draw_pet_alien,
    "pet_ghost": draw_pet_ghost, "pet_phoenix": draw_pet_phoenix,
    "pet_unicorn": draw_pet_unicorn, "pet_golem": draw_pet_golem,
}


def install(module) -> Dict[str, Callable]:
    """Lo llama make_sprites con su propio modulo. Devuelve {id del nodo: dibujo}."""
    global M, PURPLE_D, PURPLE, PURPLE_L
    M = module
    g = globals()
    for name in list(g):
        if name.isupper() and name not in ("M", "DRAWINGS") and hasattr(module, name):
            g[name] = getattr(module, name)
    # El morado del CARDO es el de la rareza epica, que el auditor ya admite.
    epic = module.RARITIES["epic"]
    PURPLE_D, PURPLE, PURPLE_L = epic.dark, epic.base, epic.light
    out = dict(DRAWINGS)
    for v in PET_VARIANTS:
        out[f"pet_machine_{v}"] = _variant(DRAWINGS["pet_machine"], v)
    return out
