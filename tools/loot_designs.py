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
    """Doble LP: la funda con su arte y los DOS discos asomando por arriba a la
    derecha, en abanico. Es la forma de un doble disco que se reconoce de un
    vistazo (antes era una funda abierta en libro y no se leia)."""
    # los dos discos, detras de la funda
    _disc(s, 20, 9, 8, P("DARK"), P("DARK_SOFT"), P("RED"), P("RED_L"))
    _disc(s, 22, 16, 8, P("DARK"), P("DARK_SOFT"), P("GOLD"), P("GOLD_XL"))
    # la funda
    x0, y0, x1, y1 = 2, 9, 21, 29
    s.rect(x0, y0, x1, y1, P("CREAM_D"))
    s.rect(x0, y0, x1, y0, P("CREAM_L"))
    s.rect(x0, y0, x0, y1, P("CREAM_L"))
    s.rect(x1, y0, x1, y1, P("CRINKLE"))
    s.rect(x0, y1, x1, y1, P("CRINKLE"))
    # el arte: dos circulos que se cruzan (los dos discos) sobre azul
    s.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, P("TEAL_D"))
    s.rect(x0 + 2, y0 + 2, x1 - 2, y0 + 3, P("TEAL"))
    s.ellipse(5, 14, 14, 23, P("RED_L"))
    s.ellipse(9, 14, 18, 23, P("GOLD_XL"))
    s.ellipse(9, 16, 12, 21, P("GOLD_L"))
    # la pegatina "2 LP" de la esquina
    s.rect(4, 24, 9, 27, P("CREAM_L"))
    s.dots([(5, 25), (6, 25), (6, 26), (5, 26)], P("RED"))
    s.dots([(8, 25), (8, 26)], P("OUTLINE"))


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
             sole_l=None, tab=None) -> None:
    """Zapatilla BAJA de perfil, mirando a la derecha.

    La silueta es lo que la hace zapatilla: puntera redonda que se levanta, la
    lengueta asomando por encima de los cordones, el cuello bajo junto al tobillo,
    la pestana del talon y una suela gorda (media suela clara y goma debajo).
    La version de antes era un bloque con el talon alto y se leia como una bota.

    Todos los tonos son de la paleta y no derivados: el desgaste de las notas
    bajas ya oscurece y aclara, y un derivado de un derivado se sale de lo que
    acepta el auditor."""
    # --- la suela: media suela y goma, con la puntera curvada hacia arriba
    s.poly([(2, 20), (26, 20), (29, 21), (30, 23), (29, 25), (3, 25), (2, 24)], sole)
    s.line([(3, 20), (26, 20)], sole_l or P("WHITE"))
    s.poly([(3, 24), (29, 24), (28, 26), (4, 26)], sole_d)          # la goma
    s.dots([(x, 25) for x in range(6, 28, 3)], P("OUTLINE"))      # el dibujo de la goma
    # --- el empeine
    s.poly([(3, 20), (3, 13), (4, 11), (7, 11), (9, 13), (11, 13), (12, 10),
            (14, 8), (16, 9), (17, 11), (21, 13), (25, 15), (28, 17), (29, 19),
            (28, 20)], upper)
    s.poly([(4, 13), (4, 11), (7, 11), (9, 13), (12, 13), (16, 14), (16, 15),
            (5, 15)], upper_l)                                     # la luz de arriba
    s.line([(4, 19), (27, 19)], upper_d)                            # sombra junto a la suela
    # la puntera, de otro tono: es lo que redondea la punta
    s.poly([(23, 14), (25, 15), (28, 17), (29, 19), (28, 19), (23, 19)],
           toe if toe is not None else upper_l)
    # el cuello, por dentro: oscuro, que se vea que hay un hueco para el pie
    s.rect(7, 12, 10, 12, P("NIGHT"))
    s.px(8, 13, P("NIGHT"))
    # la pestana del talon
    s.rect(3, 12, 4, 16, tab if tab is not None else swoosh)
    # la lengueta, asomando por encima
    s.poly([(12, 11), (12, 9), (13, 8), (16, 8), (17, 9), (17, 11)], upper_l)
    s.rect(13, 8, 15, 8, upper)
    # los cordones: cruces en diagonal por el empeine
    for i, (x, y) in enumerate([(14, 10), (16, 11), (18, 12), (20, 13), (22, 14)]):
        s.px(x, y, lace)
        s.px(x + 1, y + (1 if i % 2 == 0 else 0), lace)
        s.px(x, y + 1, P("NIGHT"))                                  # el ojal
    # el logo del lateral: una curva rapida de talon a puntera
    s.line([(6, 18), (10, 17), (15, 16), (20, 14)], swoosh, 2)
    s.px(5, 17, swoosh)


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
    """Reloj de pulsera: caja cuadrada de oro con la esfera azul de noche, los
    indices dorados y la correa de piel con su hebilla. Cuadrado y oscuro a
    proposito: redondo y crema se confundia con el reloj de bolsillo."""
    # la correa: mas ancha junto a la caja, con su costura
    s.rect(11, 1, 20, 7, P("LEATHER"))
    s.rect(11, 1, 12, 7, P("LEATHER_L"))
    s.rect(19, 1, 20, 7, P("LEATHER_D"))
    s.rect(11, 22, 20, 30, P("LEATHER"))
    s.rect(11, 22, 12, 30, P("LEATHER_L"))
    s.rect(19, 22, 20, 30, P("LEATHER_D"))
    s.dots([(14, y) for y in (2, 4, 6)] + [(17, y) for y in (2, 4, 6)], P("LEATHER_D"))
    s.dots([(15, 24), (16, 24)], P("LEATHER_D"))         # el agujero de la hebilla
    s.rect(10, 26, 21, 28, P("STEEL_D"))                 # la hebilla
    s.rect(11, 27, 20, 27, P("LEATHER"))
    s.rect(10, 26, 21, 26, P("STEEL"))
    # la caja: cuadrada con las esquinas redondeadas
    s.rect(6, 7, 25, 22, P("GOLD_D"))
    s.rect(6, 7, 24, 21, P("GOLD"))
    s.rect(6, 7, 24, 8, P("GOLD_HI"))
    s.rect(6, 7, 7, 20, P("GOLD_L"))
    for x, y in ((6, 7), (25, 7), (6, 22), (25, 22)):
        s.img.putpixel((x, y), (0, 0, 0, 0))
    # la esfera
    s.rect(9, 10, 22, 19, P("NIGHT_LL"))
    s.rect(9, 10, 22, 10, P("TEAL_D"))
    s.rect(9, 10, 9, 19, P("TEAL_D"))
    for x, y in ((15, 11), (16, 11), (21, 14), (21, 15), (15, 18), (16, 18),
                 (10, 14), (10, 15)):
        s.px(x, y, P("GOLD_XL"))                        # los indices
    s.line([(15, 15), (15, 12)], P("CREAM"))            # las agujas
    s.line([(16, 15), (19, 16)], P("CREAM"))
    s.dots([(15, 15), (16, 15)], P("GOLD_HI"))
    s.px(18, 12, P("RED_L"))                            # el segundero
    s.dots([(11, 12), (12, 12)], P("TEAL_L"))           # el reflejo del cristal
    s.rect(26, 13, 27, 16, P("GOLD_L"))                 # la corona
    s.px(27, 13, P("GOLD_HI"))


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
# JUGUETES: peluche, robot de hojalata, figura en su blister y cohete de hojalata
# --------------------------------------------------------------------------- #

def draw_teddy(s) -> None:
    """Osito de peluche sentado, con la tripa y el hocico claros y pajarita."""
    for x0, y0, x1, y1 in ((4, 16, 10, 22), (21, 16, 27, 22)):      # brazos
        s.ellipse(x0, y0, x1, y1, P("BROWN"))
    s.ellipse(8, 15, 23, 28, P("BROWN"))                             # cuerpo
    s.ellipse(9, 16, 14, 21, P("BROWN_L"))
    s.ellipse(12, 18, 19, 26, P("CREAM_D"))                          # tripa
    s.ellipse(13, 19, 17, 23, P("CREAM"))
    for x0, x1 in ((6, 13), (18, 25)):                               # patas
        s.ellipse(x0, 24, x1, 30, P("BROWN"))
        s.ellipse(x0 + 2, 26, x1 - 2, 29, P("CREAM_D"))
    s.ellipse(6, 3, 11, 8, P("BROWN"))                               # orejas
    s.ellipse(20, 3, 25, 8, P("BROWN"))
    s.ellipse(8, 5, 10, 7, P("BROWN_L"))
    s.ellipse(21, 5, 23, 7, P("BROWN_L"))
    s.ellipse(8, 4, 23, 17, P("BROWN"))                              # cabeza
    s.arc(9, 5, 20, 15, 180, 260, P("BROWN_L"))
    s.ellipse(13, 10, 18, 15, P("CREAM"))                            # hocico
    s.rect(15, 11, 16, 11, P("OUTLINE"))
    s.px(15, 13, P("BROWN_D"))
    s.dots([(12, 8), (19, 8)], P("OUTLINE"))                         # ojos
    s.dots([(12, 7), (19, 7)], P("WHITE"))
    s.dots([(13, 16), (14, 17), (17, 17), (18, 16)], P("RED"))       # pajarita
    s.rect(15, 16, 16, 17, P("RED_L"))


def draw_tin_robot(s) -> None:
    """Robot de hojalata de cuerda: cabeza de lata, pecho rojo y la llave."""
    s.rect(27, 16, 29, 20, P("GOLD"))                                # la llave
    s.rect(27, 16, 29, 16, P("GOLD_XL"))
    s.rect(26, 18, 26, 18, P("GOLD_D"))
    s.px(15, 1, P("RED_L"))                                          # antena
    s.rect(15, 2, 15, 3, P("STEEL_D"))
    s.rect(10, 4, 21, 11, P("STEEL"))                                # cabeza
    s.rect(10, 4, 21, 4, P("WHITE"))
    s.rect(10, 5, 10, 11, P("WHITE"))
    s.rect(21, 5, 21, 11, P("STEEL_D"))
    s.rect(12, 6, 13, 7, P("RED_L"))
    s.rect(18, 6, 19, 7, P("RED_L"))
    s.dots([(x, 9) for x in range(13, 19)], P("STEEL_DD"))
    s.rect(14, 12, 17, 12, P("STEEL_DD"))                            # cuello
    for x0, x1 in ((5, 7), (24, 26)):                                # brazos
        s.rect(x0, 14, x1, 21, P("STEEL"))
        s.rect(x0, 14, x1, 14, P("WHITE"))
        s.dots([(x0, 22), (x1, 22)], P("STEEL_D"))                   # pinzas
    s.rect(8, 13, 23, 23, P("RED"))                                  # cuerpo
    s.rect(8, 13, 23, 13, P("RED_L"))
    s.rect(8, 14, 8, 23, P("RED_L"))
    s.rect(23, 14, 23, 23, P("RED_D"))
    s.rect(11, 15, 20, 20, P("STEEL"))                               # el panel
    s.rect(11, 15, 20, 15, P("WHITE"))
    s.dots([(13, 17), (16, 17)], P("GOLD_XL"))
    s.dots([(18, 18), (19, 18)], P("LCD"))
    s.rect(12, 19, 15, 19, P("STEEL_DD"))
    for x0, x1 in ((10, 14), (17, 21)):                              # piernas
        s.rect(x0, 24, x1, 28, P("STEEL"))
        s.rect(x0, 24, x0, 28, P("WHITE"))
        s.rect(x0 - 1, 29, x1, 30, P("STEEL_DD"))


def draw_action_figure(s) -> None:
    """Figura de accion en su blister: carton con colgador y la burbuja."""
    s.rect(6, 2, 25, 29, P("TEAL"))                                  # carton
    s.rect(6, 8, 7, 29, P("TEAL_L"))
    s.rect(24, 8, 25, 29, P("TEAL_D"))
    s.rect(6, 2, 25, 7, P("GOLD_XL"))                                # cabecera
    s.rect(6, 2, 25, 2, P("GOLD_HI"))
    s.rect(14, 3, 17, 4, P("NIGHT"))                                 # colgador
    s.dots([(x, 6) for x in range(8, 24, 2)], P("GOLD_D"))
    s.rect(9, 9, 22, 27, P("TISSUE"))                                # burbuja
    s.rect(9, 9, 22, 9, P("WHITE"))
    s.rect(22, 10, 22, 27, P("STEEL"))
    s.rect(12, 14, 19, 22, P("TEAL_D"))                              # capa
    s.rect(11, 14, 12, 19, P("RED"))                                 # brazos
    s.rect(19, 14, 20, 19, P("RED"))
    s.rect(13, 14, 18, 20, P("RED"))                                 # cuerpo
    s.rect(13, 14, 18, 14, P("RED_L"))
    s.px(15, 16, P("GOLD_XL"))
    s.px(16, 16, P("GOLD_HI"))
    s.rect(13, 19, 18, 19, P("GOLD_XL"))                             # cinturon
    s.rect(13, 21, 15, 25, P("DARK_SOFT"))                           # piernas
    s.rect(16, 21, 18, 25, P("DARK_SOFT"))
    s.rect(13, 21, 13, 25, P("SLATE"))
    s.ellipse(14, 10, 17, 13, P("LEATHER_HI"))                       # cabeza
    s.rect(14, 10, 17, 10, P("BROWN_D"))
    s.dots([(15, 12), (16, 12)], P("OUTLINE"))
    s.line([(10, 25), (13, 11)], P("WHITE"))                         # brillo


def draw_tin_rocket(s) -> None:
    """Cohete de hojalata con ojo de buey, aletas rojas y la llama."""
    s.poly([(12, 26), (19, 26), (16, 30), (15, 30)], P("GOLD_XL"))   # llama
    s.rect(14, 26, 17, 28, P("GOLD_HI"))
    s.dots([(12, 27), (19, 27)], P("RED_L"))
    s.poly([(11, 16), (6, 24), (11, 24)], P("RED"))                  # aletas
    s.poly([(20, 16), (25, 24), (20, 24)], P("RED_D"))
    s.rect(11, 9, 20, 23, P("CREAM"))                                # cuerpo
    s.rect(11, 9, 12, 23, P("WHITE"))
    s.rect(20, 9, 20, 23, P("CREAM_D"))
    s.poly([(16, 1), (11, 9), (20, 9)], P("RED"))                    # morro
    s.poly([(16, 1), (11, 9), (14, 9)], P("RED_L"))
    s.dots([(12, y) for y in range(11, 23, 3)], P("STEEL_D"))        # remaches
    s.dots([(19, y) for y in range(11, 23, 3)], P("STEEL_D"))
    s.ellipse(13, 11, 18, 16, P("STEEL_D"))                          # ojo de buey
    s.ellipse(14, 12, 17, 15, P("TEAL_L"))
    s.px(14, 12, P("WHITE"))
    s.rect(11, 18, 20, 19, P("RED"))                                 # franja
    s.rect(15, 20, 16, 25, P("RED"))                                 # aleta central
    s.rect(12, 24, 19, 25, P("STEEL_DD"))                            # tobera
    s.dots([(4, 6), (27, 4), (26, 12), (5, 14)], P("GOLD_HI"))       # destellos
    s.dots([(25, 5), (28, 4)], P("WHITE"))


# --------------------------------------------------------------------------- #
# LA TIENDA PRO: galeria, estudio, garaje y boveda (cuatro de cada)
# --------------------------------------------------------------------------- #

def _epic(i: int):
    return (M.RARITIES["epic"].dark, M.RARITIES["epic"].base, M.RARITIES["epic"].light)[i]


def draw_sketch(s) -> None:
    """Boceto: una hoja de papel con un retrato a lapiz y la pinza del caballete."""
    s.rect(6, 4, 25, 28, P("CREAM_L"))
    s.rect(6, 4, 7, 28, P("WHITE"))
    s.rect(24, 4, 25, 28, P("CREAM_D"))
    s.ellipse(11, 8, 20, 18, P("CREAM"))             # la cara, a lapiz
    s.ring(11, 8, 20, 18, P("SLATE"))
    s.dots([(14, 12), (17, 12)], P("SLATE"))
    s.line([(14, 15), (17, 15)], P("SLATE"))
    s.line([(9, 25), (12, 19), (19, 19), (22, 25)], P("SLATE"))     # hombros
    s.rect(13, 2, 18, 5, P("STEEL"))                  # la pinza
    s.line([(22, 22), (29, 29)], P("GOLD"), 2)       # el lapiz
    s.px(29, 29, P("SLATE"))


def draw_etching(s) -> None:
    """Grabado: una lamina enmarcada en negro con un paisaje a rayas."""
    s.rect(4, 5, 27, 27, P("NIGHT"))
    s.rect(4, 5, 27, 5, P("NIGHT_LL"))
    s.rect(7, 8, 24, 24, P("CREAM_L"))
    for y in range(10, 18, 2):                        # el cielo a rayas
        s.line([(8, y), (23, y)], P("CREAM_D"))
    s.poly([(8, 23), (13, 15), (17, 20), (20, 16), (23, 23)], P("SLATE"))  # montes
    s.ellipse(17, 9, 21, 13, P("CREAM"))
    s.dots([(5, 6), (6, 6)], P("WHITE"))


def draw_oil_painting(s) -> None:
    """Cuadro al oleo: marco dorado tallado y un bodegon de colores fuertes."""
    s.rect(3, 4, 28, 27, P("GOLD"))
    s.rect(3, 4, 28, 5, P("GOLD_XL"))
    s.rect(3, 26, 28, 27, P("GOLD_D"))
    s.dots([(x, 4) for x in range(5, 28, 4)], P("GOLD_HI"))
    s.rect(6, 7, 25, 24, P("RED_D"))                  # fondo
    s.ellipse(9, 13, 16, 20, P("RED_L"))              # manzana
    s.ellipse(15, 12, 22, 19, P("GOLD_XL"))           # limon
    s.rect(8, 20, 23, 23, P("BROWN"))                 # la mesa
    s.rect(18, 8, 20, 12, P("GREEN"))                 # botella
    s.px(10, 14, P("WHITE"))


def draw_masterpiece(s) -> None:
    """Obra maestra: el retrato famoso en marco barroco, con su cordon de museo."""
    s.rect(2, 2, 29, 29, P("GOLD"))
    s.rect(2, 2, 29, 3, P("GOLD_HI"))
    s.rect(2, 28, 29, 29, P("GOLD_D"))
    for x, y in ((2, 2), (26, 2), (2, 26), (26, 26)):
        s.rect(x, y, x + 3, y + 3, P("GOLD_XL"))     # esquinas talladas
    s.rect(6, 6, 25, 25, P("TEAL_D"))                 # el fondo del retrato
    s.ellipse(11, 8, 20, 17, P("LEATHER_HI"))         # cara
    s.rect(10, 7, 21, 10, P("BROWN_D"))               # pelo
    s.dots([(14, 12), (17, 12)], P("DARK"))
    s.line([(14, 15), (17, 15)], P("RED_D"))          # la sonrisa
    s.poly([(8, 25), (11, 18), (20, 18), (23, 25)], P("NIGHT_L"))
    s.dots([(1, 15), (30, 15)], _epic(2))


def draw_master_tape(s) -> None:
    """Cinta master: la bobina abierta de estudio, con la cinta marron."""
    s.ellipse(3, 3, 28, 28, P("STEEL"))
    s.ellipse(4, 4, 27, 27, P("STEEL_D"))
    s.ellipse(7, 7, 24, 24, P("BROWN_D"))             # la cinta enrollada
    s.ring(9, 9, 22, 22, P("BROWN"))
    s.ellipse(12, 12, 19, 19, P("STEEL"))             # el buje
    s.ellipse(14, 14, 17, 17, P("NIGHT"))
    for x, y in ((15, 6), (6, 15), (24, 15), (15, 24)):
        s.rect(x, y, x + 1, y + 1, P("STEEL_D"))     # agujeros
    s.rect(9, 27, 22, 29, P("CREAM"))                 # la etiqueta MASTER
    s.dots([(x, 28) for x in range(10, 22, 2)], P("RED"))


def draw_gold_record(s) -> None:
    """Disco de oro: el disco dorado en su placa enmarcada."""
    s.rect(2, 2, 29, 29, P("NIGHT_L"))
    s.rect(2, 2, 29, 2, P("NIGHT_LL"))
    s.ellipse(6, 4, 25, 23, P("GOLD"))
    s.ring(8, 6, 23, 21, P("GOLD_D"))
    s.ring(10, 8, 21, 19, P("GOLD_D"))
    s.ellipse(13, 11, 18, 16, P("RED"))
    s.px(15, 13, P("NIGHT"))
    s.dots([(9, 8), (10, 7)], P("WHITE"))
    s.rect(9, 25, 22, 27, P("GOLD_XL"))               # la plaquita


def draw_signed_guitar(s) -> None:
    """Guitarra firmada: la electrica roja con la firma en blanco."""
    s.line([(18, 13), (27, 3)], P("BROWN_L"), 3)     # mastil
    s.rect(25, 1, 29, 4, P("BROWN_D"))                # clavijero
    s.dots([(26, 1), (28, 1), (29, 3)], P("STEEL"))
    s.ellipse(3, 13, 16, 26, P("RED"))                # el cuerpo
    s.ellipse(9, 9, 20, 20, P("RED"))
    s.ellipse(4, 14, 9, 19, P("RED_L"))
    s.rect(9, 15, 14, 16, P("STEEL"))                 # pastillas
    s.rect(8, 19, 13, 20, P("STEEL"))
    s.line([(5, 23), (8, 21), (11, 23), (14, 20)], P("WHITE"))  # la firma
    s.px(17, 13, P("CREAM"))


def draw_platinum_record(s) -> None:
    """Disco de platino: plateado, con destellos y la estrella de la ascension."""
    s.ellipse(3, 3, 28, 28, P("STEEL"))
    s.ring(5, 5, 26, 26, P("WHITE"))
    s.ring(8, 8, 23, 23, P("STEEL_D"))
    s.ring(11, 11, 20, 20, P("WHITE"))
    s.ellipse(13, 13, 18, 18, _epic(1))
    s.px(15, 15, P("WHITE"))
    s.dots([(7, 6), (8, 5), (25, 24)], P("WHITE"))
    s.dots([(28, 3), (2, 27), (29, 15)], P("SHINE_HI"))


def draw_helmet(s) -> None:
    """Casco: de carreras, blanco con franja roja y la visera oscura."""
    s.ellipse(4, 5, 27, 28, P("CREAM_L"))
    s.ellipse(4, 5, 13, 20, P("WHITE"))
    s.rect(14, 5, 17, 28, P("RED"))                   # la franja
    s.poly([(10, 14), (27, 14), (27, 21), (12, 21)], P("NIGHT"))   # visera
    s.line([(13, 15), (24, 15)], P("TEAL_L"))
    s.rect(4, 25, 27, 28, P("CREAM_D"))
    s.dots([(8, 8), (9, 7)], P("WHITE"))


def draw_chrome_rim(s) -> None:
    """Llanta cromada: el neumatico negro y los radios brillando."""
    s.ellipse(2, 2, 29, 29, P("STEEL_DD"))
    s.ring(3, 3, 28, 28, P("NIGHT_LL"), 2)
    s.ellipse(7, 7, 24, 24, P("STEEL"))
    s.ellipse(9, 9, 22, 22, P("STEEL_D"))
    for a, b in (((16, 9), (16, 22)), ((9, 16), (22, 16)), ((11, 11), (21, 21)), ((21, 11), (11, 21))):
        s.line([a, b], P("WHITE"))
    s.ellipse(13, 13, 18, 18, P("STEEL"))
    s.px(15, 15, P("GOLD_XL"))
    s.dots([(9, 8), (8, 9)], P("WHITE"))


def draw_motorbike(s) -> None:
    """Moto clasica: de perfil, deposito rojo, cromados y dos ruedas de radios."""
    for cx in (7, 24):
        s.ellipse(cx - 6, 17, cx + 6, 29, P("STEEL_DD"))
        s.ring(cx - 6, 17, cx + 6, 29, P("NIGHT_LL"), 2)
        s.ellipse(cx - 3, 20, cx + 3, 26, P("STEEL"))
        s.ellipse(cx - 1, 22, cx + 1, 24, P("WHITE"))
    s.poly([(7, 23), (12, 14), (23, 14), (24, 23)], P("STEEL_D"))  # el cuadro
    s.rect(12, 18, 19, 22, P("STEEL"))                # motor
    s.dots([(13, 19), (15, 19), (17, 19)], P("STEEL_DD"))
    s.ellipse(10, 8, 22, 16, P("RED"))                # deposito
    s.ellipse(12, 9, 17, 12, P("RED_L"))
    s.rect(2, 12, 11, 14, P("BROWN_D"))               # asiento
    s.rect(2, 12, 11, 12, P("BROWN"))
    s.line([(21, 12), (25, 5)], P("STEEL"), 2)        # horquilla
    s.rect(22, 4, 29, 5, P("STEEL"))                  # manillar
    s.ellipse(26, 7, 29, 10, P("GOLD_XL"))            # faro
    s.line([(3, 21), (10, 21)], P("STEEL"))           # escape


def draw_classic_car(s) -> None:
    """Coche clasico: descapotable azul cielo con cromados y ruedas de banda blanca."""
    s.poly([(2, 18), (5, 12), (26, 12), (30, 18)], P("TEAL"))       # carroceria alta
    s.rect(2, 17, 30, 23, P("TEAL"))
    s.rect(2, 17, 30, 17, P("TEAL_L"))
    s.rect(9, 9, 19, 12, P("TEAL_L"))                 # parabrisas
    s.line([(10, 9), (18, 9)], P("WHITE"))
    s.rect(2, 21, 30, 22, P("STEEL"))                 # el cromado
    s.ellipse(27, 18, 30, 21, P("GOLD_XL"))           # faro
    for cx in (8, 24):
        s.ellipse(cx - 4, 20, cx + 4, 28, P("NIGHT"))
        s.ring(cx - 3, 21, cx + 3, 27, P("WHITE"))
        s.px(cx, 24, P("STEEL"))
    s.rect(13, 14, 18, 15, P("RED"))                  # los asientos


def draw_old_coin(s) -> None:
    """Moneda antigua: oro gastado con la cara de un rey de perfil."""
    s.ellipse(4, 4, 27, 27, P("GOLD_D"))
    s.ellipse(5, 5, 26, 26, P("GOLD"))
    s.ring(7, 7, 24, 24, P("GOLD_D"))
    s.ellipse(11, 9, 20, 21, P("GOLD_L"))             # la cabeza
    s.poly([(11, 9), (14, 6), (17, 9)], P("GOLD_XL"))  # corona
    s.px(17, 13, P("GOLD_D"))                         # el ojo
    s.line([(19, 15), (21, 16)], P("GOLD_D"))         # la nariz
    s.dots([(x, 24) for x in range(11, 21, 2)], P("GOLD_D"))  # la leyenda
    s.dots([(8, 7), (7, 8)], P("GOLD_HI"))


def draw_pearls(s) -> None:
    """Collar de perlas: una vuelta entera de perlas y el colgante de oro."""
    import math as _m
    for i in range(18):
        a = i * 2 * _m.pi / 18
        x = round(16 + 11 * _m.cos(a))
        y = round(14 + 10 * _m.sin(a))
        s.ellipse(x - 2, y - 2, x + 1, y + 1, P("CREAM_L"))
        s.px(x - 1, y - 1, P("WHITE"))
    s.rect(14, 2, 18, 5, P("GOLD"))                   # el cierre
    s.px(16, 3, P("GOLD_HI"))
    s.line([(16, 25), (16, 27)], P("GOLD_D"))         # el colgante
    s.poly([(16, 26), (19, 28), (16, 30), (13, 28)], _epic(1))
    s.px(15, 27, _epic(2))


def draw_jeweled_egg(s) -> None:
    """Huevo enjoyado: el huevo esmaltado de lujo con bandas de oro y joyas."""
    s.rect(11, 26, 20, 29, P("GOLD_D"))               # la peana
    s.rect(9, 28, 22, 29, P("GOLD"))
    s.ellipse(7, 2, 24, 27, _epic(1))
    s.ellipse(8, 3, 14, 15, _epic(2))
    s.rect(7, 13, 24, 14, P("GOLD"))                  # bandas de oro
    s.line([(16, 2), (16, 27)], P("GOLD"))
    s.dots([(11, 9), (20, 9), (11, 20), (20, 20)], P("RED_L"))     # joyas
    s.dots([(16, 7), (16, 21)], P("TEAL_L"))
    s.px(16, 13, P("WHITE"))
    s.dots([(10, 5), (9, 6)], P("WHITE"))


def draw_crown(s) -> None:
    """Corona: oro con picos, terciopelo morado y gemas."""
    s.rect(5, 12, 26, 22, _epic(0))                   # el terciopelo
    s.poly([(4, 24), (4, 10), (9, 16), (12, 6), (16, 14), (20, 6), (23, 16), (27, 10),
            (27, 24)], P("GOLD"))
    s.poly([(4, 24), (4, 10), (6, 13), (6, 24)], P("GOLD_XL"))
    s.rect(4, 22, 27, 26, P("GOLD_D"))                # la banda
    s.rect(4, 22, 27, 22, P("GOLD_XL"))
    for x, col in ((8, "RED_L"), (15, "TEAL_L"), (22, "GREEN_L")):
        s.rect(x, 23, x + 2, 25, P(col))
    s.dots([(12, 5), (20, 5), (4, 9), (27, 9)], P("WHITE"))       # perlas de las puntas
    s.dots([(15, 1), (29, 3), (2, 2)], P("GOLD_HI"))


# --------------------------------------------------------------------------- #
# EL MERCADO NEGRO (scripts/data/black_market.gd): dos de cada tipo y la
# falsificacion. Cada uno lleva algo que dice "esto no es de una tienda".
# --------------------------------------------------------------------------- #

def draw_bm_stolen_card(s) -> None:
    """Carta robada: la carta de lujo con la esquina arrancada de su funda y una
    pegatina roja de 'buscada'."""
    draw_card_foil(s)
    s.poly([(18, 2), (25, 2), (25, 9)], P("TRANSPARENT"))      # la esquina que falta
    s.rect(9, 22, 22, 27, P("RED"))                            # la pegatina
    s.rect(9, 22, 22, 22, P("RED_L"))
    s.dots([(x, 24) for x in range(11, 21, 2)], P("CREAM_L"))
    s.dots([(x, 26) for x in range(12, 20, 2)], P("CREAM_L"))


def draw_bm_misprint(s) -> None:
    """Carta mal impresa: el bicho y el marco salen dos veces, corridos."""
    r = M.RARITIES["rare"]
    _card_frame(s, r.base, r.light, r.dark, P("CREAM_D"))
    s.rect(9, 9, 22, 20, P("NIGHT_L"))
    _monster(s, 17, 15, P("RED_L"), P("RED_L"), P("RED_D"))   # la tinta corrida
    _monster(s, 14, 13, P("TEAL"), P("TEAL_L"), P("OUTLINE"))
    s.rect(9, 6, 22, 7, P("CREAM_L"))
    s.rect(12, 6, 21, 6, P("RED_L"))                           # el titulo, corrido
    s.rect(10, 7, 18, 7, P("TEAL_D"))
    _card_text(s, 22, P("RED_D"))


def draw_bm_bootleg(s) -> None:
    """Vinilo pirata: disco negro con la etiqueta blanca escrita a boli."""
    _disc(s, 16, 16, 13, P("DARK"), P("DARK_SOFT"), P("WHITE"), P("CREAM_L"))
    s.dots([(13, 14), (14, 15), (15, 14), (17, 15), (18, 14)], P("TEAL_D"))
    s.dots([(14, 17), (16, 18), (18, 17)], P("TEAL_D"))
    s.px(16, 16, P("OUTLINE"))


def draw_bm_lost_tape(s) -> None:
    """Cinta perdida: un casete sin caja con la etiqueta en blanco y un '?'."""
    s.rect(3, 7, 28, 24, P("DARK_SOFT"))
    s.rect(3, 7, 28, 7, P("SLATE"))
    s.rect(5, 9, 26, 16, P("CREAM_L"))                         # la etiqueta
    s.rect(14, 10, 17, 10, P("RED"))                           # el '?'
    s.dots([(17, 11), (16, 12), (15, 13), (15, 15)], P("RED"))
    s.ellipse(8, 17, 12, 21, P("STEEL"))                       # bobinas
    s.ellipse(19, 17, 23, 21, P("STEEL"))
    s.dots([(10, 19), (21, 19)], P("NIGHT"))
    s.rect(13, 18, 18, 20, P("BROWN_D"))                       # la cinta
    s.poly([(8, 24), (10, 21), (21, 21), (23, 24)], P("SLATE"))
    s.dots([(4, 8), (5, 8)], P("WHITE"))


def draw_bm_sample(s) -> None:
    """Zapatilla de muestra: gris, sin marca, con la etiqueta roja colgando."""
    _sneaker(s, P("STEEL"), P("WHITE"), P("STEEL_D"), P("CREAM_D"), P("SLATE"),
             P("STEEL_D"), P("CREAM"))
    s.line([(18, 11), (21, 6)], P("CREAM_D"))                  # el hilo
    s.rect(20, 3, 27, 7, P("RED"))                             # la etiqueta
    s.rect(20, 3, 27, 3, P("RED_L"))
    s.dots([(22, 5), (24, 5), (26, 5)], P("CREAM_L"))


def draw_bm_unreleased(s) -> None:
    """Zapatilla sin estrenar: negra y dorada, a medio sacar de su caja."""
    s.rect(2, 18, 29, 29, P("BROWN"))                          # la caja
    s.rect(2, 18, 29, 19, P("BROWN_L"))
    s.rect(2, 28, 29, 29, P("BROWN_D"))
    s.rect(12, 22, 19, 25, P("CREAM"))                         # la pegatina
    s.dots([(13, 23), (15, 23), (17, 23)], P("BROWN_D"))
    # la zapatilla, dibujada aparte y subida 7 filas: asoma por encima de la caja
    sub = M.Sprite()
    _sneaker(sub, P("DARK"), P("DARK_SOFT"), P("NIGHT"), P("GOLD"), P("GOLD_D"),
             P("GOLD_XL"), P("GOLD_L"))
    for y in range(8, 27):
        for x in range(1, 31):
            c = sub.img.getpixel((x, y))
            if c[3] > 0:
                s.px(x, y - 7, c)


def draw_bm_devkit(s) -> None:
    """Consola de desarrollo: la placa verde a la vista y cables sueltos."""
    s.rect(3, 9, 28, 21, P("GREEN_D"))                         # la placa
    s.rect(3, 9, 28, 9, P("GREEN"))
    s.rect(6, 12, 12, 17, P("NIGHT"))                          # chip
    s.dots([(x, 11) for x in range(6, 13, 2)] + [(x, 18) for x in range(6, 13, 2)],
           P("STEEL"))
    s.rect(15, 12, 19, 14, P("DARK_SOFT"))
    s.rect(22, 12, 26, 18, P("STEEL_D"))                       # ranura
    s.dots([(16, 17), (18, 17), (20, 19)], P("GOLD_XL"))       # soldaduras
    s.dots([(24, 20), (26, 20)], P("RED_L"))                   # leds
    s.line([(8, 21), (6, 25), (9, 28)], P("RED"), 1)           # cables
    s.line([(14, 21), (15, 26), (19, 28)], P("TEAL_L"), 1)
    s.rect(21, 23, 27, 27, P("CREAM_L"))                       # la pegatina DEV
    s.rect(22, 25, 26, 25, P("RED"))


def draw_bm_hot_watch(s) -> None:
    """Reloj caliente: un reloj de oro con las lineas de calor rojas."""
    draw_watch(s)
    for x in (4, 26):
        s.dots([(x, 6), (x + 1, 8), (x, 10), (x + 1, 12)], P("RED_L"))
    s.dots([(15, 1), (16, 2)], P("RED_L"))


def draw_bm_recalled(s) -> None:
    """Juguete retirado: el robot de hojalata con el triangulo de peligro."""
    draw_tin_robot(s)
    s.poly([(19, 30), (24, 21), (29, 30)], P("GOLD_XL"))       # el aviso
    s.rect(24, 24, 24, 27, P("OUTLINE"))
    s.px(24, 29, P("OUTLINE"))


def draw_bm_prototype(s) -> None:
    """Prototipo: una figura de arcilla gris sin pintar con cotas de medida."""
    s.ellipse(11, 3, 20, 12, P("STEEL"))                       # cabeza
    s.ellipse(12, 4, 16, 8, P("WHITE"))
    s.rect(9, 13, 22, 23, P("STEEL"))                          # cuerpo
    s.rect(9, 13, 22, 13, P("WHITE"))
    s.rect(22, 14, 22, 23, P("STEEL_D"))
    s.rect(6, 14, 8, 21, P("STEEL_D"))                         # brazos
    s.rect(23, 14, 25, 21, P("STEEL_D"))
    s.rect(10, 24, 14, 29, P("STEEL"))                         # piernas
    s.rect(17, 24, 21, 29, P("STEEL"))
    s.line([(27, 3), (27, 29)], P("RED"))                      # la cota
    s.dots([(26, 3), (28, 3), (26, 29), (28, 29)], P("RED"))
    s.dots([(14, 7), (17, 7)], P("SLATE"))                     # ojos marcados
    s.dots([(12, 16), (15, 18), (19, 16)], P("SLATE"))         # marcas de lapiz


def draw_bm_lead_ingot(s) -> None:
    """Lingote de plomo: el lingote de oro con la pintura saltada y el gris debajo."""
    draw_ingot(s)
    for (x, y) in [(12, 14), (13, 14), (14, 15), (6, 24), (7, 23), (7, 24), (19, 25),
                   (20, 25), (20, 24), (24, 18), (25, 19), (16, 11), (17, 11)]:
        s.px(x, y, P("SLATE"))
    s.rect(10, 17, 13, 19, P("STEEL_D"))
    s.rect(11, 18, 12, 18, P("SLATE"))


# --------------------------------------------------------------------------- #
# LOS MITICOS DE LA SUBASTA (scripts/data/auction.gd, prefijo myth_)
# --------------------------------------------------------------------------- #
# Uno por tipo, con sus diez notas. Son la pieza dorada de su tipo con la estrella
# morada de mitico en una esquina: dorados para que se lean como "lo mejor que hay"
# y la estrella para no confundirlos con los dorados de la tienda pro.

def _gild(s, keep=()) -> None:
    """Pasa a la rampa de oro todo lo pintado menos lo muy oscuro y `keep`."""
    golds = [P("GOLD_D"), P("GOLD"), P("GOLD_L"), P("GOLD_XL"), P("GOLD_HI")]
    img = s.img
    for y in range(s.h):
        for x in range(s.w):
            c = img.getpixel((x, y))
            if c[3] == 0 or c in keep:
                continue
            lum = (0.30 * c[0] + 0.59 * c[1] + 0.11 * c[2]) / 255.0
            if lum < 0.16:
                continue
            img.putpixel((x, y), golds[min(4, int(lum * 5.0))])


def _myth_star(s, x: int, y: int) -> None:
    """La estrella morada de los miticos (la rareza epica, que el auditor admite)."""
    epic = M.RARITIES["epic"]
    s.dots([(x, y - 2), (x - 2, y), (x + 2, y), (x, y + 2)], epic.base)
    s.dots([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], epic.light)
    s.px(x, y, P("WHITE"))


def draw_myth_cards(s) -> None:
    """Carta primigenia: la carta holo en oro, con un ojo morado en el centro."""
    draw_card_foil(s)
    _gild(s)
    epic = M.RARITIES["epic"]
    s.ellipse(11, 12, 20, 19, epic.dark)
    s.ellipse(13, 13, 18, 18, epic.base)
    s.rect(15, 14, 16, 17, P("OUTLINE"))
    s.px(14, 14, P("WHITE"))
    _myth_star(s, 26, 5)


def draw_myth_vinyls(s) -> None:
    """Master original: disco negro de surcos dorados y la galleta morada con corona."""
    epic = M.RARITIES["epic"]
    _disc(s, 15, 16, 13, P("DARK"), P("GOLD_D"), epic.base, epic.light)
    s.ellipse(11, 12, 19, 20, epic.base)
    s.ellipse(12, 13, 15, 16, epic.light)
    s.poly([(12, 17), (12, 14), (13, 15), (15, 13), (17, 15), (18, 14), (18, 17)], P("GOLD_XL"))
    s.rect(12, 17, 18, 18, P("GOLD"))
    s.px(15, 15, P("RED_L"))
    _myth_star(s, 27, 4)


def draw_myth_sneakers(s) -> None:
    """Par cero: la zapatilla limitada toda en oro, con alas blancas en el talon."""
    draw_sneaker_limited(s)
    _gild(s, keep=(P("WHITE"),))
    s.poly([(2, 10), (8, 12), (7, 15), (3, 14)], P("WHITE"))
    s.poly([(2, 14), (7, 16), (6, 18), (3, 17)], P("CREAM"))
    s.dots([(3, 11), (4, 15)], P("STEEL"))
    _myth_star(s, 26, 25)


def draw_myth_electronics(s) -> None:
    """Consola de oro: la portatil en oro macizo, con la pantalla encendida."""
    draw_handheld(s)
    _gild(s, keep=(P("LCD"), P("LCD_D"), P("LCD_L"), P("RED"), P("RED_L")))
    _myth_star(s, 27, 4)


def draw_myth_toys(s) -> None:
    """Osito numero uno: el osito con corona de oro y la medalla del 1."""
    draw_teddy(s)
    s.poly([(10, 5), (10, 2), (12, 4), (15, 1), (18, 4), (21, 2), (21, 5)], P("GOLD_XL"))
    s.rect(10, 4, 21, 5, P("GOLD"))
    s.dots([(15, 3), (12, 4), (19, 4)], P("RED_L"))
    s.ellipse(18, 19, 24, 25, P("GOLD_XL"))          # la medalla
    s.ellipse(19, 20, 23, 24, P("GOLD"))
    s.rect(21, 21, 21, 23, P("GOLD_D"))              # el 1
    s.px(20, 21, P("GOLD_D"))
    s.dots([(19, 17), (20, 18), (23, 17), (22, 18)], P("RED"))  # la cinta
    _myth_star(s, 27, 27)


# --------------------------------------------------------------------------- #
# Registro
# --------------------------------------------------------------------------- #

DRAWINGS: Dict[str, Callable] = {
    "teddy": draw_teddy,
    "tin_robot": draw_tin_robot,
    "action_figure": draw_action_figure,
    "tin_rocket": draw_tin_rocket,
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
    "sketch": draw_sketch,
    "etching": draw_etching,
    "oil_painting": draw_oil_painting,
    "masterpiece": draw_masterpiece,
    "master_tape": draw_master_tape,
    "gold_record": draw_gold_record,
    "signed_guitar": draw_signed_guitar,
    "platinum_record": draw_platinum_record,
    "helmet": draw_helmet,
    "chrome_rim": draw_chrome_rim,
    "motorbike": draw_motorbike,
    "classic_car": draw_classic_car,
    "old_coin": draw_old_coin,
    "pearls": draw_pearls,
    "jeweled_egg": draw_jeweled_egg,
    "crown": draw_crown,
    "bm_stolen_card": draw_bm_stolen_card,
    "bm_misprint": draw_bm_misprint,
    "bm_bootleg": draw_bm_bootleg,
    "bm_lost_tape": draw_bm_lost_tape,
    "bm_sample": draw_bm_sample,
    "bm_unreleased": draw_bm_unreleased,
    "bm_devkit": draw_bm_devkit,
    "bm_hot_watch": draw_bm_hot_watch,
    "bm_recalled": draw_bm_recalled,
    "bm_prototype": draw_bm_prototype,
    "bm_lead_ingot": draw_bm_lead_ingot,
    "myth_cards": draw_myth_cards,
    "myth_vinyls": draw_myth_vinyls,
    "myth_sneakers": draw_myth_sneakers,
    "myth_electronics": draw_myth_electronics,
    "myth_toys": draw_myth_toys,
}


def install(module) -> Dict[str, Callable]:
    """Lo llama make_sprites con su propio modulo. Devuelve los dibujos base."""
    global M
    M = module
    return dict(DRAWINGS)
