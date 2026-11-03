#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""loot_designs.py - los dibujos del BOTIN: lo que sale de los paquetes.

Sustituye a los veintiun dibujos base que habia en make_sprites.py. Se dibujan
aqui solo los objetos ENTEROS (la nota 10): el desgaste de cada nota lo sigue
poniendo make_sprites encima (apply_wear para los objetos y apply_card_wear para
las cartas), asi que la nota 1 de una camara nueva sale rayada y comida igual
que salia la de antes.

LO QUE CAMBIA. Los de antes eran siluetas planas de dos tonos, y varios no se
leian: las cuatro cartas eran el mismo rectangulo marron con un dibujo distinto
dentro, el lingote era una caja naranja y el cable dos aros azules. Aqui cada
objeto lleva volumen (luz arriba a la izquierda, sombra abajo a la derecha, un
brillo especular) y un detalle que lo identifica de un vistazo:

  VINILOS       disco con surcos y reflejo; el doble asoma la funda, el numerado
                lleva su etiqueta con numero y el de color es traslucido
  ZAPATILLAS    perfil de zapatilla con suela, cordones y la marca; la de piel,
                la de restaurar (media limpia y media sucia) y la limitada
  ELECTRONICA   consola de sobremesa con mando, portatil, cartucho, auriculares,
                reloj de pulsera, reloj de bolsillo, camara, cable y lingote
  CARTAS        cuatro cartas de verdad: comun (monstruo azul), edicion limitada
                (sello dorado), vieja (sepia con marco ornamentado) y
                holografica (arcoiris en diagonal)

Las cartas respetan el marco de siempre (x 6..25, y 2..29): el desgaste de carta
dobla las esquinas y pliega sobre esas coordenadas.

Mismas reglas que el resto del arte: rejilla de 32, contorno de 1 px que pone el
generador, alfa binaria y colores de la paleta o derivados con shade() dentro
del +-45 %. Este modulo no importa make_sprites: lo recibe en install().
"""

from __future__ import annotations

from typing import Callable, Dict

M = None  # el modulo make_sprites, puesto por install()


def P(name: str):
    return getattr(M, name)


def sh(c, t: float):
    return M.shade(c, t)


# --------------------------------------------------------------------------- #
# VINILOS
# --------------------------------------------------------------------------- #

def _disc(s, cx: int, cy: int, r: int, body, groove, label, label_l,
          sheen=None) -> None:
    s.ellipse(cx - r, cy - r, cx + r, cy + r, body)
    for rr in range(r - 2, 4, -2):
        s.ring(cx - rr, cy - rr, cx + rr, cy + rr, groove)
    # el reflejo: un arco claro arriba a la izquierda, que es lo que hace que un
    # circulo negro se lea como un disco brillante
    s.arc(cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1, 200, 250,
          sheen or P("VINYL_SHEEN"), 2)
    s.arc(cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3, 205, 235, P("STEEL_DD"), 1)
    s.ellipse(cx - 4, cy - 4, cx + 4, cy + 4, label)
    s.ellipse(cx - 3, cy - 3, cx + 2, cy + 2, label_l)
    s.px(cx, cy, P("OUTLINE"))


def draw_vinyl(s) -> None:
    """Disco negro con etiqueta naranja."""
    _disc(s, 16, 16, 13, P("DARK"), P("DARK_SOFT"), P("GOLD"), P("GOLD_L"))
    s.dots([(14, 14), (15, 14)], P("GOLD_HI"))


def draw_vinyl_double(s) -> None:
    """Doble LP: la funda abierta en libro y dos discos asomando."""
    s.rect(2, 9, 17, 29, P("CARD"))                 # funda abierta
    s.rect(2, 9, 17, 9, P("CARD_L"))
    s.rect(9, 9, 10, 29, P("BROWN_D"))              # el lomo
    s.rect(3, 11, 8, 27, P("CARD_L"))
    s.rect(4, 13, 7, 16, P("GOLD_L"))               # el arte de la portada
    s.rect(4, 18, 7, 19, P("CREAM_D"))
    _disc(s, 22, 10, 8, P("DARK"), P("DARK_SOFT"), P("RED"), P("RED_L"))
    _disc(s, 20, 21, 9, P("DARK"), P("DARK_SOFT"), P("TEAL"), P("TEAL_L"))


def draw_vinyl_numbered(s) -> None:
    """Edicion numerada: disco con etiqueta crema y su numero de serie."""
    _disc(s, 16, 16, 13, P("DARK"), P("DARK_SOFT"), P("CREAM"), P("CREAM_L"))
    s.dots([(14, 13), (15, 13), (16, 13)], P("RED"))         # el numero
    s.dots([(14, 18), (15, 18), (17, 18), (18, 18)], P("BROWN_D"))
    # la pegatina dorada de la edicion
    s.ellipse(22, 3, 29, 10, P("GOLD_D"))
    s.ellipse(22, 3, 28, 9, P("GOLD_XL"))
    s.dots([(24, 5), (25, 5), (25, 6), (26, 7)], P("GOLD_D"))


def draw_vinyl_color(s) -> None:
    """Prensado en color: vinilo morado traslucido con vetas."""
    epic = M.RARITIES["epic"]
    _disc(s, 16, 16, 13, epic.base, epic.dark, P("CREAM"), P("CREAM_L"),
          sheen=epic.light)
    for x, y in [(8, 20), (9, 21), (22, 9), (23, 10), (24, 18), (8, 11)]:
        s.px(x, y, epic.light)
    s.dots([(15, 15), (16, 15)], P("GOLD_L"))


# --------------------------------------------------------------------------- #
# ZAPATILLAS
# --------------------------------------------------------------------------- #

def _sneaker(s, upper, upper_l, upper_d, sole, sole_d, swoosh, lace, toe=None,
             sole_l=None) -> None:
    """Zapatilla de perfil, mirando a la derecha, con suela, cordones y marca.

    Todos los tonos son de la paleta y no derivados: el desgaste de las notas
    bajas ya oscurece y aclara, y un derivado de un derivado se sale de lo que
    acepta el auditor."""
    # suela
    s.rect(2, 23, 30, 26, sole)
    s.rect(2, 26, 30, 27, sole_d)
    s.rect(2, 23, 30, 23, sole_l or P("WHITE"))
    s.dots([(x, 27) for x in range(4, 30, 3)], P("STEEL_DD"))   # la goma
    # empeine
    s.poly([(3, 23), (3, 13), (6, 9), (11, 9), (13, 12), (19, 14), (26, 17),
            (30, 20), (30, 23)], upper)
    s.poly([(3, 13), (6, 9), (11, 9), (11, 12), (4, 15)], upper_l)   # luz del talon
    s.line([(19, 22), (30, 22)], upper_d)
    s.rect(3, 20, 7, 22, upper_d)                                    # el talon
    if toe is not None:
        s.poly([(22, 16), (26, 17), (30, 20), (30, 22), (22, 22)], toe)
    # la marca: una curva rapida de punta a talon
    s.line([(7, 19), (13, 20), (20, 18), (25, 16)], swoosh, 2)
    # cordones y lengueta
    s.poly([(11, 9), (14, 8), (15, 12), (13, 12)], upper_l)
    for i, x in enumerate((13, 15, 17, 19)):
        s.line([(x, 12 + i // 2), (x + 2, 11 + i // 2)], lace)
    s.px(5, 11, P("WHITE"))


def draw_sneaker(s) -> None:
    """Zapatilla blanca con la marca naranja."""
    _sneaker(s, P("WHITE"), P("WHITE"), P("STEEL"), P("CREAM"), P("CREAM_D"),
             P("GOLD"), P("STEEL_DD"))


def draw_sneaker_leather(s) -> None:
    """Zapatilla de piel marron con suela crema."""
    _sneaker(s, P("LEATHER"), P("LEATHER_L"), P("LEATHER_D"), P("CREAM"),
             P("CREAM_D"), P("LEATHER_HI"), P("CREAM_D"))
    s.dots([(x, 21) for x in range(8, 28, 2)], P("LEATHER_D"))   # costura


def draw_sneaker_restore(s) -> None:
    """Zapatilla a restaurar: la mitad delantera limpia y la trasera sucia."""
    _sneaker(s, P("WHITE"), P("WHITE"), P("STEEL"), P("CREAM"), P("CREAM_D"),
             P("RED_L"), P("STEEL_DD"))
    # la mitad de atras, SUCIA: los mismos colores oscurecidos (no un color
    # liso encima, que se leia como una piedra pegada a la zapatilla)
    sucio = {P("WHITE"): P("CRINKLE"), P("STEEL"): P("CRINKLE"),
             P("STEEL_D"): P("CARD_L"), P("CREAM"): P("CARD_L"),
             P("CREAM_D"): P("CARD"), P("STEEL_DD"): P("BROWN_D"),
             P("RED_L"): P("RUST_D")}
    for y in range(s.h):
        for x in range(2, 15):
            c = s.img.getpixel((x, y))
            if c[3] > 0 and c in sucio:
                s.px(x, y, sucio[c])
    s.dots([(5, 14), (8, 17), (10, 12), (6, 20), (12, 19), (9, 24)], P("BROWN"))
    s.line([(15, 9), (15, 27)], P("CREAM_L"))        # la raya de lo limpio
    s.px(24, 18, P("WHITE"))


def draw_sneaker_limited(s) -> None:
    """Zapatilla limitada: roja y dorada, con destellos."""
    _sneaker(s, P("RED"), P("RED_L"), P("RED_D"), P("GOLD_XL"), P("GOLD_D"),
             P("GOLD_HI"), P("CREAM"), toe=P("RED_D"), sole_l=P("GOLD_HI"))
    s.dots([(27, 6), (29, 9), (25, 3)], P("GOLD_HI"))
    s.px(28, 7, P("WHITE"))


# --------------------------------------------------------------------------- #
# ELECTRONICA
# --------------------------------------------------------------------------- #

def draw_console(s) -> None:
    """Consola de sobremesa con su mando."""
    # la consola
    s.rect(2, 8, 29, 19, P("STEEL"))
    s.rect(2, 8, 29, 9, P("WHITE"))
    s.rect(2, 18, 29, 19, P("STEEL_D"))
    s.rect(4, 11, 15, 13, P("DARK_SOFT"))           # la ranura del cartucho
    s.rect(5, 12, 14, 12, P("NIGHT"))
    s.rect(18, 11, 20, 13, P("RED"))                # boton de encendido
    s.px(18, 11, P("RED_L"))
    s.rect(23, 11, 27, 12, P("STEEL_D"))
    s.dots([(24, 15), (26, 15)], P("LCD"))          # luces
    # el mando, delante y abajo
    s.rect(8, 21, 23, 28, P("DARK_SOFT"))
    s.rect(8, 21, 23, 21, P("SLATE"))
    s.rect(10, 24, 12, 24, P("STEEL_D"))            # cruceta
    s.rect(11, 23, 11, 25, P("STEEL_D"))
    s.dots([(19, 23), (21, 25)], P("RED_L"))
    s.dots([(19, 25), (21, 23)], P("TEAL_L"))
    s.line([(15, 20), (15, 19)], P("DARK"))         # el cable


def draw_handheld(s) -> None:
    """Consola portatil con la pantalla encendida."""
    s.rect(7, 2, 24, 29, P("STEEL"))
    s.rect(7, 2, 24, 3, P("WHITE"))
    s.rect(7, 2, 7, 29, P("WHITE"))
    s.rect(23, 3, 24, 29, P("STEEL_D"))
    s.rect(9, 5, 22, 15, P("DARK_SOFT"))            # marco de la pantalla
    s.rect(11, 7, 20, 14, P("LCD_D"))
    s.rect(12, 8, 19, 13, P("LCD"))
    s.dots([(13, 9), (14, 9), (13, 10)], P("LCD_L"))
    s.rect(15, 11, 17, 12, P("LCD_D"))              # un muñequito en pantalla
    s.px(10, 6, P("RED_L"))                         # led
    s.rect(10, 20, 14, 20, P("DARK_SOFT"))          # cruceta
    s.rect(12, 18, 12, 22, P("DARK_SOFT"))
    s.ellipse(17, 20, 19, 22, P("RED"))
    s.ellipse(20, 18, 22, 20, P("RED"))
    s.dots([(17, 20), (20, 18)], P("RED_L"))
    s.dots([(14, 25), (15, 25), (17, 25), (18, 25)], P("STEEL_DD"))
    s.dots([(19, 27), (20, 26), (21, 27), (22, 26)], P("STEEL_D"))   # altavoz


def draw_cartridge(s) -> None:
    """Cartucho de juego con su etiqueta de colores."""
    s.poly([(6, 3), (22, 3), (26, 7), (26, 29), (6, 29)], P("STEEL_D"))
    s.rect(6, 3, 21, 4, P("STEEL"))
    s.rect(6, 3, 7, 29, P("STEEL"))
    s.rect(9, 5, 22, 6, P("STEEL_DD"))              # estrias de arriba
    s.rect(9, 8, 23, 22, P("CREAM"))                # la etiqueta
    s.rect(10, 9, 22, 15, P("TEAL"))
    s.rect(10, 9, 22, 10, P("TEAL_L"))
    s.poly([(12, 15), (16, 11), (20, 15)], P("GOLD_XL"))   # montaña del arte
    s.ellipse(18, 10, 20, 12, P("GOLD_HI"))         # sol
    s.rect(10, 17, 21, 18, P("RED"))                # el titulo
    s.rect(10, 20, 17, 20, P("STEEL_DD"))
    s.dots([(x, 27) for x in range(10, 24, 2)], P("GOLD"))   # contactos
    s.rect(9, 26, 23, 26, P("STEEL_DD"))


def draw_headphones(s) -> None:
    """Auriculares de diadema con almohadillas."""
    s.arc(4, 3, 27, 26, 180, 360, P("DARK_SOFT"), 3)        # la diadema
    s.arc(4, 3, 27, 26, 200, 250, P("SLATE"), 1)
    s.rect(12, 3, 19, 5, P("GOLD"))                         # el acolchado
    s.rect(12, 3, 19, 3, P("GOLD_L"))
    for x0 in (2, 22):                                      # los dos cascos
        s.rect(x0, 15, x0 + 7, 27, P("DARK_SOFT"))
        s.rect(x0 + 1, 16, x0 + 6, 26, P("GOLD_D"))
        s.rect(x0 + 2, 17, x0 + 5, 25, P("GOLD"))
        s.rect(x0 + 2, 17, x0 + 3, 20, P("GOLD_L"))
        s.rect(x0, 15, x0 + 7, 15, P("SLATE"))
    s.dots([(5, 21), (25, 21)], P("GOLD_HI"))


def draw_watch(s) -> None:
    """Reloj de pulsera de oro con correa de piel."""
    s.rect(12, 1, 19, 8, P("LEATHER"))                      # correa
    s.rect(12, 23, 19, 30, P("LEATHER"))
    s.rect(12, 1, 13, 8, P("LEATHER_L"))
    s.rect(12, 23, 13, 30, P("LEATHER_L"))
    s.dots([(15, 27), (16, 27), (15, 28)], P("LEATHER_D"))  # agujeros
    s.ellipse(7, 7, 24, 24, P("GOLD_D"))                    # la caja
    s.ellipse(7, 7, 23, 23, P("GOLD"))
    s.arc(7, 7, 23, 23, 190, 260, P("GOLD_HI"), 2)
    s.ellipse(9, 9, 21, 21, P("CREAM"))                     # la esfera
    s.ellipse(10, 10, 20, 20, P("CREAM_L"))
    for x, y in ((15, 10), (20, 15), (15, 20), (10, 15)):
        s.px(x, y, P("BROWN_D"))                            # las horas
    s.line([(15, 15), (15, 11)], P("OUTLINE"))
    s.line([(15, 15), (18, 17)], P("OUTLINE"))
    s.px(15, 15, P("RED"))
    s.rect(24, 14, 25, 16, P("GOLD_L"))                     # la corona
    s.dots([(11, 11), (12, 11)], P("WHITE"))


def draw_pocket_watch(s) -> None:
    """Reloj de bolsillo de oro con su cadena."""
    s.line([(16, 2), (16, 5)], P("GOLD_D"), 2)              # la anilla
    s.ring(13, 1, 18, 5, P("GOLD"))
    for i, (x, y) in enumerate([(19, 4), (22, 3), (25, 5), (27, 8), (28, 11)]):
        s.px(x, y, P("GOLD_L") if i % 2 else P("GOLD_D"))   # la cadena
    s.ellipse(5, 6, 27, 28, P("GOLD_D"))
    s.ellipse(5, 6, 26, 27, P("GOLD"))
    s.arc(5, 6, 26, 27, 190, 260, P("GOLD_HI"), 2)
    s.ring(7, 8, 24, 25, P("GOLD_D"))                       # el bisel grabado
    s.ellipse(8, 9, 23, 24, P("CREAM"))
    s.ellipse(9, 10, 22, 23, P("CREAM_L"))
    for x, y in ((15, 10), (21, 16), (15, 22), (9, 16)):
        s.px(x, y, P("BROWN_D"))
    s.ellipse(13, 17, 17, 21, P("CREAM_D"))                 # el segundero
    s.line([(15, 16), (15, 11)], P("OUTLINE"))
    s.line([(15, 16), (19, 14)], P("OUTLINE"))
    s.dots([(10, 12), (11, 11)], P("WHITE"))


def draw_camera(s) -> None:
    """Camara de fotos con objetivo grande y flash."""
    s.rect(5, 6, 12, 9, P("SLATE"))                         # el visor
    s.rect(20, 5, 26, 9, P("CREAM"))                        # el flash
    s.rect(21, 6, 25, 8, P("WHITE"))
    s.rect(2, 9, 29, 27, P("DARK_SOFT"))                    # el cuerpo
    s.rect(2, 9, 29, 10, P("SLATE"))
    s.rect(2, 13, 29, 23, P("LEATHER_D"))                   # la piel
    s.dots([(x, y) for y in (15, 19) for x in range(3, 29, 2)], P("LEATHER"))
    s.rect(2, 26, 29, 27, P("NIGHT"))
    s.ellipse(9, 10, 24, 25, P("STEEL_DD"))                 # el objetivo
    s.ellipse(10, 11, 23, 24, P("STEEL_D"))
    s.ellipse(12, 13, 21, 22, P("NIGHT"))
    s.ellipse(13, 14, 20, 21, P("TEAL_D"))
    s.ellipse(14, 15, 18, 19, P("TEAL"))
    s.dots([(15, 15), (16, 16)], P("TEAL_L"))
    s.px(14, 16, P("WHITE"))
    s.rect(4, 7, 6, 8, P("RED"))                            # el disparador


def draw_cable(s) -> None:
    """Cable de datos enrollado con sus dos conectores."""
    for r, c in ((10, P("TEAL_D")), (7, P("TEAL")), (4, P("TEAL_D"))):
        s.ring(16 - r, 15 - r, 16 + r, 15 + r, c, 2)
    s.arc(6, 5, 26, 25, 200, 250, P("TEAL_L"), 1)
    # los dos conectores: el que sale por arriba y el que cuelga
    s.line([(24, 8), (28, 3)], P("TEAL"), 2)
    s.rect(26, 1, 30, 4, P("STEEL"))
    s.rect(26, 1, 30, 1, P("WHITE"))
    s.rect(29, 2, 30, 3, P("GOLD"))
    s.line([(8, 22), (5, 28)], P("TEAL"), 2)
    s.rect(2, 27, 7, 30, P("STEEL"))
    s.rect(2, 27, 7, 27, P("WHITE"))
    s.rect(3, 29, 5, 30, P("GOLD"))


def draw_ingot(s) -> None:
    """Lingote de oro: la cara de arriba estrecha, los cantos en rampa y el sello
    grabado. Es la forma de trapecio la que lo hace lingote y no caja."""
    s.poly([(3, 27), (8, 13), (24, 13), (29, 27)], P("GOLD"))   # el cuerpo
    s.poly([(3, 27), (8, 13), (10, 13), (6, 27)], P("GOLD_L"))  # rampa iluminada
    s.poly([(29, 27), (24, 13), (22, 13), (26, 27)], P("GOLD_D"))  # rampa en sombra
    s.rect(8, 11, 24, 15, P("GOLD_XL"))                         # la cara de arriba
    s.rect(8, 11, 24, 11, P("GOLD_HI"))
    s.rect(3, 27, 29, 28, P("GOLD_D"))                          # la base
    s.rect(11, 18, 21, 23, P("GOLD_D"))                         # el sello
    s.rect(12, 19, 20, 22, P("GOLD_L"))
    s.dots([(13, 20), (15, 20), (17, 20), (19, 20), (14, 21), (18, 21)], P("GOLD_D"))
    s.dots([(9, 12), (10, 12), (8, 16)], P("WHITE"))
    s.dots([(26, 6), (28, 9), (24, 4)], P("GOLD_HI"))           # destellos
    s.px(27, 7, P("WHITE"))


# --------------------------------------------------------------------------- #
# CARTAS (marco x 6..25, y 2..29, que es donde trabaja el desgaste de carta)
# --------------------------------------------------------------------------- #

def _card_frame(s, frame, frame_l, frame_d, inner) -> None:
    s.rect(6, 2, 25, 29, frame)
    s.rect(6, 2, 25, 3, frame_l)
    s.rect(6, 2, 7, 29, frame_l)
    s.rect(24, 4, 25, 29, frame_d)
    s.rect(6, 28, 25, 29, frame_d)
    s.rect(8, 5, 23, 26, inner)


def _monster(s, cx: int, cy: int, body, body_l, eye) -> None:
    """El bicho de la carta: una criatura redonda con cuernos."""
    s.ellipse(cx - 5, cy - 4, cx + 5, cy + 5, body)
    s.ellipse(cx - 4, cy - 3, cx + 1, cy + 1, body_l)
    s.dots([(cx - 4, cy - 5), (cx - 5, cy - 6), (cx + 4, cy - 5), (cx + 5, cy - 6)],
           body)                                            # cuernos
    s.dots([(cx - 2, cy - 1), (cx + 2, cy - 1)], eye)
    s.dots([(cx - 2, cy - 2), (cx + 2, cy - 2)], P("WHITE"))
    s.rect(cx - 1, cy + 2, cx + 1, cy + 2, P("OUTLINE"))   # boca


def _card_text(s, y0: int, color) -> None:
    s.rect(9, y0, 22, y0 + 4, P("CREAM_L"))
    s.rect(10, y0 + 1, 19, y0 + 1, color)
    s.rect(10, y0 + 3, 16, y0 + 3, color)


def draw_card_common(s) -> None:
    """Carta comun: marco gris, un bicho azul y su texto."""
    r = M.RARITIES["common"]
    _card_frame(s, r.base, r.light, r.dark, P("CREAM_D"))
    s.rect(9, 6, 22, 7, P("CREAM_L"))                       # la cabecera
    s.rect(10, 6, 16, 6, P("STEEL_DD"))
    s.rect(9, 9, 22, 20, P("TEAL_D"))                       # el arte
    s.rect(9, 18, 22, 20, P("GREEN_D"))
    _monster(s, 15, 14, P("TEAL"), P("TEAL_L"), P("OUTLINE"))
    _card_text(s, 22, P("STEEL_DD"))


def draw_card_edited(s) -> None:
    """Carta de edicion limitada: marco azul y el sello dorado de la tirada."""
    r = M.RARITIES["rare"]
    _card_frame(s, r.base, r.light, r.dark, P("CREAM_D"))
    s.rect(9, 6, 22, 7, P("CREAM_L"))
    s.rect(10, 6, 18, 6, r.dark)
    s.rect(9, 9, 22, 20, P("NIGHT_LL"))                     # el arte: de noche
    s.dots([(10, 10), (13, 11), (21, 10), (19, 12)], P("CREAM"))
    _monster(s, 15, 15, P("RED"), P("RED_L"), P("GOLD_HI"))
    _card_text(s, 22, r.dark)
    s.ellipse(18, 17, 23, 22, P("GOLD_D"))                  # el sello
    s.ellipse(18, 17, 22, 21, P("GOLD_XL"))
    s.dots([(20, 18), (19, 19), (20, 19), (21, 19), (20, 20)], P("GOLD_HI"))


def draw_card_vintage(s) -> None:
    """Carta vieja: sepia, con marco ornamentado y el retrato de antes."""
    _card_frame(s, P("BROWN"), P("BROWN_L"), P("BROWN_D"), P("CREAM_D"))
    s.dots([(x, 3) for x in range(9, 24, 3)], P("GOLD_L"))  # la orla
    s.dots([(x, 28) for x in range(9, 24, 3)], P("GOLD_D"))
    s.rect(9, 6, 22, 20, P("CRINKLE"))                      # el retrato, en sepia
    s.rect(9, 6, 22, 6, P("CRINKLE_L"))
    s.ellipse(12, 8, 19, 15, P("BROWN_L"))                  # la cabeza
    s.ellipse(13, 9, 16, 12, P("CARD_L"))
    s.rect(11, 15, 20, 20, P("BROWN"))                      # los hombros
    s.rect(14, 15, 17, 17, P("CREAM_D"))                    # el cuello de la camisa
    s.ring(9, 6, 22, 20, P("BROWN_D"))
    _card_text(s, 22, P("BROWN"))
    s.dots([(8, 5), (23, 5), (8, 26), (23, 26)], P("GOLD_XL"))


def draw_card_foil(s) -> None:
    """Carta holografica: marco dorado y el arte en arcoiris diagonal."""
    r = M.RARITIES["legendary"]
    _card_frame(s, r.base, r.light, r.dark, P("CREAM_L"))
    bands = [P("TEAL_L"), M.RARITIES["rare"].light, M.RARITIES["epic"].light,
             P("RED_L"), P("GOLD_HI"), P("LCD")]
    for y in range(5, 27):
        for x in range(8, 24):
            s.px(x, y, bands[((x + y) // 3) % len(bands)])
    # la estrella del medio, blanca, que es donde el holo brilla mas
    s.ellipse(11, 11, 20, 20, P("WHITE"))
    s.dots([(15, 9), (16, 9), (15, 22), (16, 22), (9, 15), (9, 16), (22, 15),
            (22, 16)], P("WHITE"))
    s.ellipse(13, 13, 18, 18, P("GOLD_HI"))
    s.dots([(15, 15), (16, 15)], P("WHITE"))


# --------------------------------------------------------------------------- #
# Registro
# --------------------------------------------------------------------------- #

DRAWINGS: Dict[str, Callable] = {
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
    "card_common": draw_card_common,
    "card_edited": draw_card_edited,
    "card_vintage": draw_card_vintage,
    "card_foil": draw_card_foil,
}


def install(module) -> Dict[str, Callable]:
    """Lo llama make_sprites con su propio modulo. Devuelve los dibujos base."""
    global M
    M = module
    return dict(DRAWINGS)
