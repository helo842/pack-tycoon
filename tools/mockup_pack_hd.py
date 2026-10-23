"""Mockup del sobre de cartas a 64x64: el doble de rejilla que el juego.

NO toca el catalogo ni el juego. Genera PNGs en tools/mockups/ para poder
decidir con la imagen delante si merece la pena subir la resolucion de los
sobres (hoy son de 32x32 y a 512 px cada pixel de arte ocupa 16).

    python3 tools/mockup_pack_hd.py

Salen tres estados del sobre nuevo y una hoja comparando el de ahora con el
propuesto, a tamaño de mesa (256) y a zoom (384).
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sprites as ms  # noqa: E402


D = 64               # rejilla del mockup (el juego usa 32)
S = 512 // D         # 8: mismo PNG de 512 de salida

OUT = os.path.join("tools", "mockups")

# Cuerpo del sobre en la rejilla de 64 (el del juego, x2: 9..22, 3..29).
X0, X1 = 18, 45
Y0, Y1 = 7, 58
# Interior de papel, dejando el marco dorado de 3 px.
PX0, PX1 = X0 + 3, X1 - 3
PY0, PY1 = Y0 + 3, Y1 - 3


def _frame(s: ms.Sprite) -> None:
    """Marco dorado de tres anillos: filo de luz, oro y bisel oscuro.

    Tres anillos y no dos: con solo luz y sombra el marco se queda plano y
    oscuro (era lo que pasaba en el primer intento del mockup).
    """
    s.rect(X0, Y0, X1, Y1, ms.GOLD)
    s.rect(X0, Y0, X1, Y0, ms.GOLD_XL)          # filo de luz arriba
    s.rect(X0, Y0, X0, Y1, ms.GOLD_XL)          # y a la izquierda
    s.rect(X0, Y1, X1, Y1, ms.GOLD_D)           # filo en sombra abajo
    s.rect(X1, Y0, X1, Y1, ms.GOLD_D)           # y a la derecha
    s.rect(X0 + 2, Y0 + 2, X1 - 2, Y1 - 2, ms.GOLD_D)   # bisel interior
    s.px(X0 + 1, Y0 + 1, ms.GOLD_HI)            # destello de la esquina


def _serrated(s: ms.Sprite, skip: tuple = ()) -> None:
    """Borde en sierra del sobre. `skip` deja un tramo roto (para el rasgado)."""
    for x in range(X0, X1 + 1):
        if any(a <= x <= b for a, b in skip):
            continue
        if ((x - X0) // 2) % 2 == 0:
            s.rect(x, Y0 - 3, x, Y0 - 1, ms.GOLD_D)
        else:
            s.rect(x, Y0 - 2, x, Y0 - 1, ms.GOLD_D)


def _paper(s: ms.Sprite) -> None:
    """Papel con degradado suave, veta y banda oscura de abajo.

    El degradado va con tramado en damero entre tonos y no con franjas: a esta
    resolucion una franja recta canta, y el tramado es lo que hace que el papel
    parezca papel y no una caja de color.
    """
    s.rect(PX0, PY0, PX1, PY1, ms.BROWN)
    # luz desde arriba: dos filas claras y tramado con el tono base
    s.rect(PX0, PY0, PX1, PY0 + 1, ms.BROWN_L)
    for y in (PY0 + 2, PY0 + 3):
        for x in range(PX0, PX1 + 1):
            if (x + y) % 2 == 0:
                s.px(x, y, ms.BROWN_L)
    # el papel se apaga justo antes de la banda del pie: el tramado se queda en
    # la franja de transicion, que en todo el papel se ve sucio
    for y in range(PY1 - 12, PY1 - 6):
        for x in range(PX0, PX1 + 1):
            if (x + y) % 2 == 0:
                s.px(x, y, ms.BROWN_D)
    # volumen: canto derecho en sombra y filo izquierdo iluminado
    s.rect(PX1 - 1, PY0 + 2, PX1, PY1 - 7, ms.BROWN_D)
    s.rect(PX0, PY0 + 2, PX0, PY1 - 7, ms.BROWN_L)
    # veta: motas deterministas (nada de ruido al azar, que cambia en cada tanda)
    for y in range(PY0 + 6, PY1 - 10, 4):
        s.px(PX0 + 4 + (y * 5) % (PX1 - PX0 - 8), y, ms.BROWN_L)
        s.px(PX1 - 5 - (y * 3) % (PX1 - PX0 - 8), y + 2, ms.BROWN_D)
    # banda del pie, mas oscura y con costura dorada
    s.rect(PX0, PY1 - 5, PX1, PY1, ms.BROWN_D)
    s.rect(PX0, PY1 - 6, PX1, PY1 - 6, ms.GOLD_D)
    s.dots([(PX0 + 3, PY1 - 3), (PX0 + 10, PY1 - 3), (PX1 - 4, PY1 - 3)],
           ms.CREAM_D)


def _corners(s: ms.Sprite) -> None:
    """Esquineras de foto arriba y dos remaches abajo.

    Las cuatro esquineras grandes no valian: las de abajo caian sobre la banda
    del pie, que es la parte que tiene que leerse como cierre del sobre.
    """
    for cx, sx in ((PX0, 1), (PX1, -1)):
        s.poly([(cx, PY0), (cx + 6 * sx, PY0), (cx, PY0 + 6)], ms.TEAL_D)
        s.poly([(cx + 1 * sx, PY0 + 1), (cx + 4 * sx, PY0 + 1),
                (cx + 1 * sx, PY0 + 4)], ms.TEAL)
    # remaches de la banda inferior
    for x in (PX0 + 3, PX1 - 3):
        s.rect(x - 1, PY1 - 3, x + 1, PY1 - 2, ms.TEAL_D)
        s.px(x, PY1 - 3, ms.TEAL_L)


def _gem(s: ms.Sprite, cx: int = 32, cy: int = 26, r: int = 7) -> None:
    """Gema facetada: el objeto que se busca dentro del sobre."""
    s.poly([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], ms.TEAL_D)
    s.poly([(cx, cy - r + 2), (cx + r - 2, cy), (cx, cy + r - 2),
            (cx - r + 2, cy)], ms.TEAL)
    # una sola faceta clara, no un mosaico: a 64 px las lineas internas de mas
    # convierten la gema en una mancha
    s.poly([(cx, cy - r + 3), (cx + 2, cy), (cx, cy + r - 3),
            (cx - 2, cy)], ms.TEAL_L)
    s.line([(cx - r, cy), (cx, cy - r + 2)], ms.TEAL_D)
    s.line([(cx + r, cy), (cx, cy + r - 2)], ms.TEAL_D)
    # destello
    s.px(cx - 2, cy - 3, ms.WHITE)
    s.px(cx - 3, cy - 2, ms.WHITE)
    s.px(cx - 2, cy - 2, ms.CREAM)


def _sticker(s: ms.Sprite) -> None:
    """Etiqueta con codigo de barras: el detalle que hace que parezca un sobre."""
    s.rect(23, 40, 34, 46, ms.CREAM_D)     # sombra, 1 px desplazada
    s.rect(23, 39, 34, 45, ms.CREAM)
    s.rect(23, 39, 34, 39, ms.WHITE)
    for x in (25, 27, 30, 32):
        s.rect(x, 41, x, 43, ms.BROWN_D)
    s.px(26, 41, ms.GOLD)


def _cracks(s: ms.Sprite, deep: bool = False) -> None:
    """Grietas del papel: siempre desde el borde de arriba, que es lo que se rompe."""
    s.line([(35, PY0 + 3), (38, PY0 + 9), (35, PY0 + 15)], ms.CRACK_D)
    s.line([(38, PY0 + 9), (41, PY0 + 12)], ms.CRACK_D)
    if deep:
        s.line([(24, PY0 + 4), (22, PY0 + 12), (26, PY0 + 16)], ms.CRACK_D)
        s.line([(30, PY0 + 20), (33, PY0 + 27), (30, PY0 + 32)], ms.CRACK_D)


def draw_closed(s: ms.Sprite) -> None:
    _serrated(s)
    _frame(s)
    _paper(s)
    _corners(s)
    _gem(s)
    _sticker(s)


def draw_d2(s: ms.Sprite) -> None:
    """Agrietado: el rasgon empieza por la esquina superior derecha."""
    _serrated(s, skip=((36, X1),))
    _frame(s)
    _paper(s)
    _corners(s)
    _gem(s)
    _cracks(s, deep=True)
    _sticker(s)
    # boquete: se lleva por delante el marco de la esquina y deja ver el interior
    s.poly([(33, Y0), (X1, Y0), (X1, PY0 + 14), (38, PY0 + 11),
            (34, PY0 + 4)], ms.DARK)
    # canto levantado del carton: es lo que dice "esto esta roto, no pintado"
    s.poly([(33, Y0), (34, PY0 + 4), (38, PY0 + 11), (X1, PY0 + 14),
            (X1, PY0 + 11), (39, PY0 + 8), (35, PY0 + 3)], ms.CREAM_D)
    s.px(35, Y0 + 2, ms.CREAM)
    s.px(37, PY0 + 7, ms.CREAM)


def draw_open(s: ms.Sprite) -> None:
    """Rasgado del todo: las cartas asoman por la abertura."""
    _serrated(s, skip=((23, 41),))
    _frame(s)
    _paper(s)
    _corners(s)
    _cracks(s)
    _sticker(s)
    # interior oscuro del sobre
    s.poly([(22, Y0), (42, Y0), (42, 27), (38, 30), (33, 27), (27, 31),
            (22, 28)], ms.DARK)
    # dos cartas, cada una con su canto: una masa sola se lee como un borron
    s.rect(24, 11, 31, 27, ms.CREAM_D)
    s.rect(24, 10, 31, 26, ms.CREAM)
    s.line([(25, 11), (25, 25)], ms.GOLD_D)
    s.poly([(31, 9), (39, 12), (40, 27), (32, 28)], ms.CREAM_D)
    s.poly([(32, 10), (38, 13), (39, 26), (33, 27)], ms.CREAM)
    s.line([(33, 11), (33, 26)], ms.GOLD_D)
    s.line([(34, 12), (39, 15)], ms.GOLD_HI)
    # el borde de arriba, doblado hacia fuera sobre las cartas
    s.poly([(21, Y0), (43, Y0), (43, Y0 + 7), (36, Y0 + 10),
            (30, Y0 + 6), (24, Y0 + 9), (21, Y0 + 6)], ms.BROWN_D)
    s.line([(21, Y0 + 6), (24, Y0 + 9), (30, Y0 + 6), (36, Y0 + 10),
            (43, Y0 + 7)], ms.CREAM_D)
    s.line([(22, Y0 + 2), (28, Y0 + 4), (35, Y0 + 3)], ms.GOLD_D)


def render(name: str, fn) -> Image.Image:
    s = ms.Sprite(D, D)
    fn(s)
    img = s.render(S)
    img.save(os.path.join(OUT, name + ".png"))
    return img


FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def _label(d: ImageDraw.ImageDraw, xy, text, size=26, fill=None) -> None:
    d.text(xy, text, font=ImageFont.truetype(FONT, size),
           fill=fill or (250, 232, 190, 255))


def sheet(now: Image.Image, new: Image.Image, now_dmg: Image.Image,
          new_dmg: Image.Image, now_open: Image.Image,
          new_open: Image.Image) -> None:
    W, H = 1600, 1020
    bg = Image.new("RGBA", (W, H), ms.NIGHT_L)
    d = ImageDraw.Draw(bg)
    # bandas de la mesa
    d.rectangle([0, 0, W, 120], fill=ms.NIGHT_D)
    _label(d, (60, 40), "AHORA · rejilla de 32 (cada pixel = 16 px)", 30)
    _label(d, (860, 40), "PROPUESTA · rejilla de 64 (cada pixel = 8 px)", 30,
           ms.GOLD_HI)

    def place(img, x, y, size, title):
        small = img.resize((size, size), Image.NEAREST)
        bg.alpha_composite(small, (x, y))
        _label(d, (x, y + size + 8), title, 22, ms.CREAM_D)

    # fila de arriba: los tres estados a tamaño de mesa (256 en el juego)
    for i, (a, b, t) in enumerate((
            (now, new, "CERRADO"), (now_dmg, new_dmg, "AGRIETADO"),
            (now_open, new_open, "ABIERTO"))):
        place(a, 70 + i * 248, 140, 232, "AHORA · " + t)
        place(b, 845 + i * 248, 140, 232, "NUEVA · " + t)

    # fila de abajo: el cerrado a zoom, para ver la diferencia de detalle
    d.line([(60, 470), (1540, 470)], fill=ms.GOLD_D, width=2)
    _label(d, (60, 492), "A 512 px (zoom)", 24, ms.CREAM_D)
    place(now, 300, 530, 400, "")
    place(new, 900, 530, 400, "")
    _label(d, (300, 940), "ahora: 16 px por bloque", 24, ms.CREAM_D)
    _label(d, (900, 940), "propuesta: 8 px por bloque, y más detalle",
           24, ms.GOLD_HI)
    bg.convert("RGB").save(os.path.join(OUT, "pack_detalle_comparativa.png"))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    now = Image.open(os.path.join("Sprites", "packs", "pack_cards.png")).convert("RGBA")
    now_dmg = Image.open(os.path.join("Sprites", "packs", "pack_cards_d1.png")).convert("RGBA")
    now_open = Image.open(os.path.join("Sprites", "packs", "pack_cards_open.png")).convert("RGBA")
    new = render("pack_hd_cards", draw_closed)
    new_dmg = render("pack_hd_cards_d2", draw_d2)
    new_open = render("pack_hd_cards_open", draw_open)
    sheet(now, new, now_dmg, new_dmg, now_open, new_open)
    print("mockup en", os.path.join(OUT, "pack_detalle_comparativa.png"))


if __name__ == "__main__":
    main()
