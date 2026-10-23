"""Mockup del sobre de cartas a 128x128, en version SIMPLE.

Mismo PNG de salida (512) y mismo estilo, pero con cuatro veces mas pixeles de
arte que el juego: a tamaño de mesa (256 px) el bloque pasa de 8 a 2 px.

La version anterior llevaba etiqueta de codigo de barras, esquineras de foto,
remaches y veta: demasiadas piezas pequeñas compitiendo. Esta deja lo justo:
marco con bisel, papel con su degradado, UNA gema y la banda del pie. La sierra
del borde se queda porque es la silueta del sobre de cartas.

    python3 tools/mockup_pack_hd128.py

Deja los tres estados en tools/mockups/ y una hoja comparando el de ahora con
este, a tamaño de mesa y a zoom.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sprites as ms  # noqa: E402


D = 128
S = 512 // D         # 4
OUT = os.path.join("tools", "mockups")

# Cuerpo del sobre (el del juego x4: 9..22, 3..29).
X0, X1 = 36, 90
Y0, Y1 = 14, 116
# Interior de papel, con el marco de 6 px.
PX0, PX1 = X0 + 6, X1 - 6
PY0, PY1 = Y0 + 6, Y1 - 6


def _frame(s: ms.Sprite) -> None:
    """Marco de oro con un bisel limpio: luz arriba-izquierda, sombra abajo-derecha."""
    s.rect(X0, Y0, X1, Y1, ms.GOLD)
    s.rect(X0, Y0, X1, Y0 + 1, ms.GOLD_XL)
    s.rect(X0, Y0, X0 + 1, Y1, ms.GOLD_XL)
    s.rect(X0, Y1 - 1, X1, Y1, ms.GOLD_D)
    s.rect(X1 - 1, Y0, X1, Y1, ms.GOLD_D)
    s.rect(X0 + 5, Y0 + 5, X1 - 5, Y1 - 5, ms.GOLD_D)   # filete interior


def _serrated(s: ms.Sprite, skip: tuple = ()) -> None:
    """Dientes de 4 px: la silueta del sobre, sin adornos."""
    for x in range(X0, X1 + 1, 4):
        if any(a <= x <= b for a, b in skip):
            continue
        top = Y0 - 6 if ((x - X0) // 4) % 2 == 0 else Y0 - 4
        s.rect(x, top, x + 3, Y0 - 1, ms.GOLD_D)


def _paper(s: ms.Sprite) -> None:
    """Papel con tres tonos: luz arriba, base y sombra antes de la banda."""
    s.rect(PX0, PY0, PX1, PY1, ms.BROWN)
    s.rect(PX0, PY0, PX1, PY0 + 1, ms.BROWN_L)
    for y in (PY0 + 2, PY0 + 3):
        for x in range(PX0, PX1 + 1):
            if (x + y) % 2 == 0:
                s.px(x, y, ms.BROWN_L)
    s.rect(PX0, PY1 - 13, PX1, PY1 - 6, ms.BROWN_D)
    # canto derecho en sombra: es lo que le da volumen sin dibujar nada mas
    s.rect(PX1 - 1, PY0 + 2, PX1, PY1 - 14, ms.BROWN_D)
    # banda del pie y su filete dorado
    s.rect(PX0, PY1 - 6, PX1, PY1, ms.BROWN_D)
    s.rect(PX0, PY1 - 7, PX1, PY1 - 7, ms.GOLD_D)


def _gem(s: ms.Sprite, cx: int = 64, cy: int = 56, r: int = 16) -> None:
    """Una sola gema grande: rombo oscuro, rombo medio y media luz arriba."""
    s.poly([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], ms.TEAL_D)
    s.poly([(cx, cy - r + 2), (cx + r - 2, cy), (cx, cy + r - 2),
            (cx - r + 2, cy)], ms.TEAL)
    # media gema iluminada: triangulo de arriba, no facetas sueltas
    s.poly([(cx, cy - r + 2), (cx + r - 2, cy), (cx, cy),
            (cx - r + 2, cy)], ms.TEAL_L)
    s.line([(cx - r + 2, cy), (cx + r - 2, cy)], ms.TEAL_D)
    # destello
    s.rect(cx - 5, cy - 7, cx - 4, cy - 6, ms.WHITE)


def _cracks(s: ms.Sprite) -> None:
    s.line([(70, PY0 + 4), (76, PY0 + 16), (71, PY0 + 28)], ms.CRACK_D)
    s.line([(76, PY0 + 16), (82, PY0 + 22)], ms.CRACK_D)


def draw_closed(s: ms.Sprite) -> None:
    _serrated(s)
    _frame(s)
    _paper(s)
    _gem(s)


def draw_d2(s: ms.Sprite) -> None:
    """Un mordisco en la esquina de arriba a la derecha, con su borde de papel."""
    _serrated(s, skip=((76, X1),))
    _frame(s)
    _paper(s)
    _gem(s)
    _cracks(s)
    s.poly([(78, Y0), (X1, Y0), (X1, PY0 + 26)], ms.DARK)
    s.line([(78, Y0), (X1, PY0 + 26)], ms.CREAM_D, width=2)
    s.px(80, Y0 + 2, ms.CREAM)


def draw_open(s: ms.Sprite) -> None:
    """Rasgado del todo: dos cartas fuera y el borde doblado sobre ellas."""
    _serrated(s, skip=((44, 84),))
    _frame(s)
    _paper(s)
    _cracks(s)
    # interior
    s.poly([(PX0, Y0), (PX1, Y0), (PX1, 52), (80, 58), (64, 50),
            (48, 58), (PX0, 52)], ms.DARK)
    # carta izquierda
    s.rect(46, 22, 62, 54, ms.CREAM_D)
    s.rect(46, 20, 62, 52, ms.CREAM)
    s.line([(49, 22), (49, 50)], ms.GOLD_D)
    # carta derecha, algo girada
    s.poly([(62, 18), (80, 23), (82, 54), (66, 56)], ms.CREAM_D)
    s.poly([(64, 21), (78, 25), (80, 52), (67, 54)], ms.CREAM)
    s.line([(66, 23), (66, 51)], ms.GOLD_D)
    # el borde de arriba, doblado hacia fuera
    s.poly([(PX0, Y0), (PX1, Y0), (PX1, Y0 + 12), (76, Y0 + 18),
            (64, Y0 + 11), (52, Y0 + 17), (PX0, Y0 + 11)], ms.BROWN_D)
    s.line([(PX0, Y0 + 11), (52, Y0 + 17), (64, Y0 + 11), (76, Y0 + 18),
            (PX1, Y0 + 12)], ms.CREAM_D)


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


def sheet(now: list, new: list) -> None:
    W, H = 1600, 1020
    bg = Image.new("RGBA", (W, H), ms.NIGHT_L)
    d = ImageDraw.Draw(bg)
    d.rectangle([0, 0, W, 120], fill=ms.NIGHT_D)
    _label(d, (60, 40), "AHORA · rejilla de 32 (cada pixel = 16 px)", 30)
    _label(d, (860, 40), "PROPUESTA SIMPLE · rejilla de 128 (4 px)", 30,
           ms.GOLD_HI)

    def place(img, x, y, size, title):
        bg.alpha_composite(img.resize((size, size), Image.NEAREST), (x, y))
        _label(d, (x, y + size + 8), title, 22, ms.CREAM_D)

    for i, t in enumerate(("CERRADO", "AGRIETADO", "ABIERTO")):
        place(now[i], 70 + i * 248, 140, 232, "AHORA · " + t)
        place(new[i], 845 + i * 248, 140, 232, "NUEVA · " + t)

    d.line([(60, 470), (1540, 470)], fill=ms.GOLD_D, width=2)
    _label(d, (60, 492), "A 512 px (zoom)", 24, ms.CREAM_D)
    place(now[0], 300, 530, 400, "")
    place(new[0], 900, 530, 400, "")
    _label(d, (300, 940), "ahora: 16 px por bloque", 24, ms.CREAM_D)
    _label(d, (900, 940), "propuesta: 4 px por bloque, menos piezas",
           24, ms.GOLD_HI)
    bg.convert("RGB").save(os.path.join(OUT, "pack_detalle_128.png"))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    now = [Image.open(os.path.join("Sprites", "packs", n)).convert("RGBA")
           for n in ("pack_cards.png", "pack_cards_d1.png",
                     "pack_cards_open.png")]
    new = [render("pack_hd128_cards", draw_closed),
           render("pack_hd128_cards_d2", draw_d2),
           render("pack_hd128_cards_open", draw_open)]
    sheet(now, new)
    print("mockup en", os.path.join(OUT, "pack_detalle_128.png"))


if __name__ == "__main__":
    main()
