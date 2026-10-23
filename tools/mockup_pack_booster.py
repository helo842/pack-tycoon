"""Mockup de OTRO modelo de sobre: blíster de carton con ventana, a 128x128.

El modelo de ahora (y el de las dos pruebas anteriores) es un sobre dorado con
una gema. Este es otro arquetipo: una bolsa de foil con la parte de arriba
sellada y una VENTANA troquelada por la que se ve la carta de dentro. Sin gema,
sin marco dorado alrededor de todo y sin sierra: se distingue de un vistazo.

    python3 tools/mockup_pack_booster.py

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

# Cuerpo del blíster: mas ancho y mas corto que el sobre de ahora, con las
# esquinas rebajadas en dos pasos para que no sea un rectangulo duro.
X0, X1 = 30, 98
Y0, Y1 = 18, 112
R = 6                # rebaje de las esquinas

# Ventana troquelada.
WX0, WX1 = 42, 86
WY0, WY1 = 44, 96


def _body(s: ms.Sprite, top: int = Y0) -> None:
    """La bolsa de foil: azul de carta con las esquinas rebajadas.

    El cuerpo crema del primer intento se leia como una hoja de papel: sin un
    tono oscuro grande no hay contraste contra la mesa, y la ventana se perdia.
    """
    s.poly([(X0 + R, top), (X1 - R, top), (X1, top + R), (X1, Y1 - R),
            (X1 - R, Y1), (X0 + R, Y1), (X0, Y1 - R), (X0, top + R)], ms.TEAL_D)
    # luz arriba y a la izquierda
    s.rect(X0 + R, top, X1 - R, top + 1, ms.TEAL)
    s.rect(X0, top + R, X0 + 1, Y1 - R, ms.TEAL)
    s.rect(X0 + R, top + 2, X1 - R, top + 2, ms.TEAL)
    # sombra abajo y a la derecha
    s.rect(X1 - 1, top + R, X1, Y1 - R, ms.NIGHT_D)
    s.rect(X0 + R, Y1 - 1, X1 - R, Y1, ms.NIGHT_D)
    # el foil se apaga hacia el pie con tramado
    for y in range(Y1 - 24, Y1 - 6):
        for x in range(X0 + 2, X1 - 1):
            if (x + y) % 2 == 0:
                s.px(x, y, ms.NIGHT_D)
    # reflejos del foil: dos diagonales a la izquierda y una corta a la derecha
    for i in range(18):
        s.px(X0 + 6 + i // 3, 40 + i, ms.TEAL)
        s.px(X0 + 11 + i // 3, 40 + i, ms.TEAL)
    for i in range(10):
        s.px(X1 - 7 - i // 4, 62 + i, ms.TEAL)


def _crimp(s: ms.Sprite, broken: tuple = ()) -> None:
    """Sellado de arriba: banda de oro con rayas verticales prensadas."""
    s.rect(X0 + R - 2, Y0, X1 - R + 2, Y0 + 12, ms.GOLD)
    s.rect(X0 + R - 2, Y0, X1 - R + 2, Y0 + 1, ms.GOLD_XL)
    for x in range(X0 + R - 2, X1 - R + 2, 4):
        if any(a <= x <= b for a, b in broken):
            continue
        s.rect(x, Y0 + 2, x + 1, Y0 + 10, ms.GOLD_D)
    s.rect(X0 + R - 2, Y0 + 11, X1 - R + 2, Y0 + 12, ms.GOLD_D)
    # borde inferior del sellado, en sierra
    for x in range(X0 + R - 2, X1 - R + 2, 4):
        if any(a <= x <= b for a, b in broken):
            continue
        s.rect(x, Y0 + 12, x + 1, Y0 + 13, ms.GOLD_D)


def _window(s: ms.Sprite, card_y: int = 52) -> None:
    """Ventana con marco dorado y la carta de dentro a la vista."""
    # marco: bisel de oro y sombra interior
    s.rect(WX0, WY0, WX1, WY1, ms.GOLD_D)
    s.rect(WX0 + 2, WY0 + 2, WX1 - 2, WY1 - 2, ms.GOLD)
    s.rect(WX0 + 2, WY0 + 2, WX1 - 2, WY0 + 3, ms.GOLD_L)
    s.rect(WX0 + 4, WY0 + 4, WX1 - 4, WY1 - 4, ms.DARK)
    s.rect(WX0 + 4, WY0 + 4, WX1 - 4, WY0 + 6, ms.NIGHT_DD)
    # la carta: canto dorado, cuerpo crema y su ilustracion
    cx0, cx1 = WX0 + 10, WX1 - 10
    cy0, cy1 = card_y, WY1 - 6
    s.rect(cx0, cy0, cx1, cy1, ms.CREAM_D)
    s.rect(cx0 + 2, cy0 + 2, cx1 - 2, cy1 - 2, ms.CREAM)
    s.rect(cx0 + 6, cy0 + 8, cx1 - 6, cy0 + 26, ms.TEAL_D)
    s.rect(cx0 + 8, cy0 + 10, cx1 - 8, cy0 + 18, ms.TEAL)
    s.rect(cx0 + 10, cy0 + 12, cx1 - 10, cy0 + 14, ms.TEAL_L)
    for y in (cy0 + 32, cy0 + 36):
        s.rect(cx0 + 6, y, cx1 - 8, y, ms.BROWN_D)


def _ribbon(s: ms.Sprite) -> None:
    """Cinta dorada del pie, con tres marcas: lo unico que queda de 'etiqueta'."""
    s.rect(X0 + 8, Y1 - 18, X1 - 8, Y1 - 10, ms.GOLD_D)
    s.rect(X0 + 8, Y1 - 17, X1 - 8, Y1 - 12, ms.GOLD)
    s.rect(X0 + 8, Y1 - 17, X1 - 8, Y1 - 17, ms.GOLD_L)
    for x in (X0 + 14, X0 + 22, X0 + 30):
        s.rect(x, Y1 - 15, x + 3, Y1 - 14, ms.NIGHT_D)


def _cracks(s: ms.Sprite) -> None:
    s.line([(76, Y0 + 16), (81, Y0 + 30), (76, Y0 + 42)], ms.CRACK_D)
    s.line([(81, Y0 + 30), (88, Y0 + 36)], ms.CRACK_D)


def draw_closed(s: ms.Sprite) -> None:
    _body(s)
    _crimp(s)
    _window(s)
    _ribbon(s)


def draw_d2(s: ms.Sprite) -> None:
    """Agrietado: el sellado se abre por la derecha y el papel se raja."""
    _body(s)
    _crimp(s, broken=((80, X1),))
    _window(s)
    _ribbon(s)
    _cracks(s)
    # raja desde el sellado hasta la ventana
    s.poly([(74, Y0 + 13), (80, Y0 + 13), (86, Y0 + 26), (78, Y0 + 24)], ms.DARK)
    s.line([(74, Y0 + 13), (78, Y0 + 24), (86, Y0 + 26)], ms.CREAM_D)


def draw_open(s: ms.Sprite) -> None:
    """Abierto: el sellado se ha ido y la carta asoma por arriba."""
    _body(s, top=Y0 + 18)
    _window(s, card_y=60)
    _ribbon(s)
    _cracks(s)
    # carta sacada: asoma por encima de la boca del blíster
    s.rect(46, 14, 76, 62, ms.CREAM_D)
    s.rect(46, 12, 76, 60, ms.CREAM)
    s.rect(50, 18, 72, 40, ms.TEAL_D)
    s.rect(52, 20, 70, 32, ms.TEAL)
    s.rect(54, 22, 60, 24, ms.TEAL_L)
    for y in (46, 50):
        s.rect(50, y, 70, y, ms.BROWN_D)
    # boca del blíster, rasgada
    s.line([(X0 + R, Y0 + 18), (48, Y0 + 14), (64, Y0 + 20), (80, Y0 + 14),
            (X1 - R, Y0 + 18)], ms.CREAM_D)


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
    _label(d, (60, 40), "AHORA · sobre dorado con gema (32)", 30)
    _label(d, (860, 40), "OTRO MODELO · blíster con ventana (128)", 30,
           ms.GOLD_HI)

    def place(img, x, y, size, title):
        bg.alpha_composite(img.resize((size, size), Image.NEAREST), (x, y))
        _label(d, (x, y + size + 8), title, 22, ms.CREAM_D)

    for i, t in enumerate(("CERRADO", "AGRIETADO", "ABIERTO")):
        place(now[i], 70 + i * 248, 140, 232, "AHORA · " + t)
        place(new[i], 845 + i * 248, 140, 232, "NUEVO · " + t)

    d.line([(60, 470), (1540, 470)], fill=ms.GOLD_D, width=2)
    _label(d, (60, 492), "A 512 px (zoom)", 24, ms.CREAM_D)
    place(now[0], 300, 530, 400, "")
    place(new[0], 900, 530, 400, "")
    _label(d, (300, 940), "ahora", 24, ms.CREAM_D)
    _label(d, (900, 940), "blíster: ventana, sellado y carta dentro",
           24, ms.GOLD_HI)
    bg.convert("RGB").save(os.path.join(OUT, "pack_detalle_blister.png"))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    now = [Image.open(os.path.join("Sprites", "packs", n)).convert("RGBA")
           for n in ("pack_cards.png", "pack_cards_d1.png",
                     "pack_cards_open.png")]
    new = [render("pack_blister_cards", draw_closed),
           render("pack_blister_cards_d2", draw_d2),
           render("pack_blister_cards_open", draw_open)]
    sheet(now, new)
    print("mockup en", os.path.join(OUT, "pack_detalle_blister.png"))


if __name__ == "__main__":
    main()
