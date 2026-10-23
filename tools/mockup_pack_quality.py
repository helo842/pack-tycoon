"""Prueba de CALIDAD de los sobres: mismo dibujo, tres densidades.

El problema no es el diseno del sobre sino cuantos pixeles de arte le caben y
cuantos tonos usa cada material. Este script dibuja el sobre UNA vez, en grande
y con sombreado suave (degradados, brillo, luz de borde, oclusion), y de esa
misma imagen saca las tres versiones que se pueden llevar al juego:

  - 128 de rejilla, plano ...... lo que ya probamos: bloques de 4 px y 2-3
                                 tonos por material.
  - 128 de rejilla, con volumen  el mismo bloque de 4 px pero con rampas de
                                 color dentro de cada material. Pasa el
                                 auditor del proyecto (se comprueba aqui).
  - 256 de rejilla ............. un pixel de arte por pixel de pantalla en la
                                 mesa: ya no se ve rejilla.

    python3 tools/mockup_pack_quality.py

Deja en tools/mockups/ los sprites sueltos y la hoja comparativa.
"""

import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sprites as ms  # noqa: E402


OUT = os.path.join("tools", "mockups")
SHEET = "pack_calidad_comparativa.png"

# El sobre se dibuja en una rejilla de 128 y con supersampling de 8: cada unidad
# de arte son 8 px de dibujo, o sea que un borde redondeado sale limpio.
GRID = 128
S = 8

# Geometria, en unidades de la rejilla de 128. El sobre ocupa lo mismo que el
# de ahora (26 de 32 de alto, 13 de 32 de ancho) para que la comparacion sea de
# calidad y no de tamano.
X0, X1 = 36, 90
Y0, Y1 = 12, 116
R = 6               # radio de la esquina
F = 2               # grosor del marco dorado
CRIMP = 12          # banda sellada de arriba

LW = (X1 - X0 + 1) * S
LH = (Y1 - Y0 + 1) * S


# --------------------------------------------------------------------------- #
# Utilidades de dibujo
# --------------------------------------------------------------------------- #

def _c(color):
    return color[:3]


def with_alpha(color, a):
    """El mismo tono con otra transparencia (shade() devuelve RGBA opaco)."""
    return (color[0], color[1], color[2], a)


def mix(a, b, t):
    """Mezcla lineal de dos colores RGBA (sin gamma: es arte, no fotografia)."""
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def mix_many(stops, t):
    """Mezcla por tramos: stops = [(0.0, color), (0.5, color), ...]."""
    if t <= stops[0][0]:
        return stops[0][1]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            return mix(c0, c1, (t - t0) / max(1e-6, (t1 - t0)))
    return stops[-1][1]


def rrect_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=max(0, radius), fill=255)
    return m


def vgrad(size, stops):
    """Degradado vertical de arriba abajo sobre toda la imagen."""
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    h = size[1]
    for y in range(h):
        d.line([(0, y), (size[0], y)], fill=mix_many(stops, y / max(1, h - 1)))
    return img


def diag_grad(size, stops):
    """Degradado en diagonal (arriba-izquierda -> abajo-derecha).

    Es el que hace de bisel en el marco: luz en el filo de arriba y de la
    izquierda, sombra en el de abajo y la derecha, sin dibujar cuatro lados.
    """
    img = Image.new("RGBA", size)
    px = img.load()
    w, h = size
    span = (w + h) or 1
    d = ImageDraw.Draw(img)
    for y in range(h):
        for x in range(0, w, 4):
            c = mix_many(stops, (x + y) / span)
            d.rectangle([x, y, x + 3, y], fill=c)
    return img


def hgrad(size, stops):
    """Degradado horizontal de izquierda a derecha."""
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    w = size[0]
    for x in range(w):
        d.line([(x, 0), (x, size[1])], fill=mix_many(stops, x / max(1, w - 1)))
    return img


def overlay(dst, layer, mask):
    """Compone una capa respetando SU alfa y recortandola a una mascara."""
    layer = layer.copy()
    layer.putalpha(ImageChops.multiply(layer.split()[3], mask))
    dst.alpha_composite(layer)


def star_points(cx, cy, r_out, r_in, n=5, rot=-90.0):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180.0 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# --------------------------------------------------------------------------- #
# Tres estilos del mismo sobre
#
# Comparten silueta, marco, precinto y sierra (lo que lo hace reconocible) y
# cambian el papel, la banda del pie y lo que va en el centro. Es la variable
# que de verdad se nota a tamano de mesa.
# --------------------------------------------------------------------------- #

STYLES = {
    "A": {
        "nombre": "MARRON, GEMA",
        "paper": [
            (0.00, ms.shade(ms.BROWN_L, 0.10)),
            (0.12, ms.BROWN),
            (0.55, ms.shade(ms.BROWN, -0.08)),
            (0.82, ms.shade(ms.BROWN, -0.20)),
            (1.00, ms.BROWN_D),
        ],
        "band": ms.BROWN_D,
        "ao": (40, 18, 8),
        "emblem": "gem",
        "rarity": "rare",
    },
    "B": {
        "nombre": "PERGAMINO, SELLO",
        "paper": [
            (0.00, ms.CREAM_L),
            (0.20, ms.CREAM),
            (0.62, ms.CREAM_D),
            (1.00, ms.shade(ms.CREAM_D, -0.20)),
        ],
        "band": ms.shade(ms.CREAM_D, -0.40),
        "ao": (58, 34, 10),
        "emblem": "seal",
        "rarity": "legendary",
    },
    "C": {
        "nombre": "FOIL AZUL, GEMA DE ORO",
        "paper": [
            (0.00, ms.shade(ms.TEAL, 0.20)),
            (0.22, ms.TEAL),
            (0.66, ms.TEAL_D),
            (1.00, ms.shade(ms.TEAL_D, 0.06)),
        ],
        "band": ms.shade(ms.TEAL_D, -0.50),
        "ao": (6, 8, 22),
        "emblem": "gem",
        "rarity": "legendary",
    },
}


def diamond(cx, cy, rx, ry):
    return [(cx, cy - ry), (cx + rx, cy), (cx, cy + ry), (cx - rx, cy)]


def emblem_gem(im, full, body_mask, cx, cy, r, rarity_id):
    """Gema tallada: seis facetas, halo detras, destello y reflejo."""
    rare = ms.RARITIES[rarity_id]
    halo = Image.new("RGBA", full, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    for i in range(9):
        k = 1.0 - i / 10.0
        hd.ellipse([cx - r * 2.2 * k, cy - r * 2.2 * k,
                    cx + r * 2.2 * k, cy + r * 2.2 * k],
                   fill=(rare.glow[0], rare.glow[1], rare.glow[2], 9))
    halo = halo.filter(ImageFilter.GaussianBlur(r * 0.27))
    overlay(im, halo, body_mask)

    gd = ImageDraw.Draw(im)
    gd.polygon(diamond(cx, cy, r * 0.86, r), fill=ms.shade(rare.dark, -0.15))
    gd.polygon(diamond(cx, cy, r * 0.74, r * 0.88), fill=rare.base)
    # cara de arriba a la izquierda: la que recibe la luz
    gd.polygon([(cx, cy - r * 0.80), (cx - r * 0.62, cy),
                (cx, cy + r * 0.10)], fill=rare.light)
    gd.polygon([(cx, cy - r * 0.80), (cx + r * 0.62, cy),
                (cx, cy + r * 0.10)], fill=ms.shade(rare.light, -0.22))
    # cara de abajo, en sombra
    gd.polygon([(cx - r * 0.62, cy), (cx, cy + r * 0.90),
                (cx, cy + r * 0.10)], fill=ms.shade(rare.base, -0.28))
    gd.polygon([(cx + r * 0.62, cy), (cx, cy + r * 0.90),
                (cx, cy + r * 0.10)], fill=ms.shade(rare.dark, 0.10))
    # destello alineado con la luz, y su reflejo pequeno abajo
    gd.polygon(diamond(cx - r * 0.30, cy - r * 0.34, r * 0.20, r * 0.34),
               fill=ms.shade(rare.light, 0.45))
    gd.polygon(diamond(cx + r * 0.34, cy + r * 0.36, r * 0.10, r * 0.18),
               fill=ms.shade(rare.light, 0.25))


def emblem_seal(im, full, cx, cy, r):
    """Sello grabado en seco: dos anillos, disco de papel y estrella.

    Es el emblema de un sobre de cromos de los de antes: sin gema, todo el
    protagonismo en el troquelado del oro.
    """
    shadow = Image.new("RGBA", full, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [cx - r + r * 0.10, cy - r + r * 0.18, cx + r + r * 0.10, cy + r + r * 0.18],
        fill=(38, 18, 6, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(r * 0.18))
    im.alpha_composite(shadow)

    gd = ImageDraw.Draw(im)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r],
               fill=ms.shade(ms.GOLD_D, -0.28))
    gd.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1],
               fill=ms.GOLD_D)
    # anillo exterior de oro con el bisel de siempre
    top = ms.GOLD_HI
    gd.arc([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2],
           start=150, end=330, fill=ms.GOLD_XL, width=max(1, int(r * 0.12)))
    gd.arc([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2],
           start=330, end=150, fill=ms.GOLD, width=max(1, int(r * 0.12)))
    # disco de papel, hundido
    ir = r * 0.74
    gd.ellipse([cx - ir, cy - ir, cx + ir, cy + ir],
               fill=ms.shade(ms.CREAM_D, -0.10))
    gd.ellipse([cx - ir, cy - ir, cx + ir, cy + ir],
               outline=ms.shade(ms.GOLD_D, -0.30),
               width=max(1, int(r * 0.07)))
    gd.polygon([(x, y) for x, y in star_points(cx, cy, ir * 0.80, ir * 0.34)],
               fill=ms.GOLD_D)
    gd.polygon([(x, y) for x, y in star_points(cx - r * 0.04, cy - r * 0.04,
                                               ir * 0.72, ir * 0.30)],
               fill=ms.GOLD)
    gd.polygon([(x, y) for x, y in star_points(cx - r * 0.06, cy - r * 0.06,
                                               ir * 0.52, ir * 0.22)],
               fill=ms.GOLD_XL)


# --------------------------------------------------------------------------- #
# El sobre
# --------------------------------------------------------------------------- #

def build_pack(style: str = "A") -> Image.Image:
    """El sobre entero, dibujado suave a 8 px por unidad de arte."""
    st = STYLES[style]
    im = Image.new("RGBA", (LW, LH), (0, 0, 0, 0))
    full = (LW, LH)

    def p(v):
        return v * S

    outer = (0, 0, LW - 1, LH - 1)
    body_box = (p(F), p(F), LW - 1 - p(F), LH - 1 - p(F))
    body_r = p(R - F)
    body_mask = rrect_mask(full, body_box, body_r)

    # --- papel del cuerpo --------------------------------------------------- #
    # No es un color plano: arriba entra luz, a media altura el tono base y al
    # pie se apaga. Sin esta rampa el sobre se lee como una pegatina.
    paper = vgrad(full, st["paper"])
    im.paste(paper, (0, 0), body_mask)

    # --- volumen del cuerpo ------------------------------------------------- #
    # Luz por la izquierda, sombra por la derecha. Es lo que convierte una placa
    # plana en una bolsa con bulto: sin esto, el sombreado vertical solo dice
    # "degradado", no "volumen".
    vol = hgrad(full, [
        (0.00, (255, 250, 232, 0)),
        (0.08, (255, 246, 220, 46)),
        (0.34, (255, 242, 214, 16)),
        (0.60, (0, 0, 0, 0)),
        (0.84, st["ao"] + (34,)),
        (1.00, st["ao"] + (86,)),
    ])
    overlay(im, vol, body_mask)

    # --- brillo del foil ---------------------------------------------------- #
    # Una franja fina en diagonal. Con una banda ancha el papel se mancha: en
    # un cuerpo de 55 unidades no hay sitio para un degradado de 20.
    gloss = Image.new("RGBA", full, (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.polygon([(p(-4), p(10)), (p(60), p(-70)), (p(60), p(-52)), (p(-4), p(28))],
               fill=(255, 248, 226, 26))
    gd.polygon([(p(-4), p(30)), (p(60), p(-50)), (p(60), p(-44)), (p(-4), p(36))],
               fill=(255, 250, 232, 30))
    gloss = gloss.filter(ImageFilter.GaussianBlur(p(2)))
    overlay(im, gloss, body_mask)

    # --- sombra del pie (oclusion) ----------------------------------------- #
    ao = vgrad(full, [
        (0.00, (0, 0, 0, 0)),
        (0.55, (0, 0, 0, 0)),
        (0.78, st["ao"] + (26,)),
        (1.00, st["ao"] + (84,)),
    ])
    overlay(im, ao, body_mask)

    # --- banda sellada de arriba ------------------------------------------- #
    crimp_box = (p(F), p(F), LW - 1 - p(F), p(F + CRIMP))
    crimp_mask = rrect_mask(full, crimp_box, p(2))
    crimp = vgrad(full, [
        (0.00, ms.GOLD_HI),
        (0.10, ms.GOLD_XL),
        (0.55, ms.GOLD),
        (0.92, ms.GOLD_D),
        (1.00, ms.shade(ms.GOLD_D, -0.18)),
    ])
    im.paste(crimp, (0, 0), crimp_mask)

    # Las rayas verticales del prensado: un surco oscuro y su filo claro. A 1
    # unidad de ancho, que es justo 1 pixel de arte.
    d = ImageDraw.Draw(im)
    for x in range(p(F) + p(4), LW - p(F) - p(2), p(4)):
        d.rectangle([x, p(F + 2), x + p(1) - 1, p(F + CRIMP - 2)],
                    fill=with_alpha(ms.shade(ms.GOLD_D, -0.12), 150))
        d.rectangle([x + p(1), p(F + 2), x + p(1), p(F + CRIMP - 2)],
                    fill=with_alpha(ms.GOLD_HI, 110))
    # y la linea de mordida entre el sellado y el cuerpo
    d.rectangle([p(F), p(F + CRIMP), LW - 1 - p(F), p(F + CRIMP)],
                fill=with_alpha(ms.shade(ms.GOLD_D, -0.25), 255))
    d.rectangle([p(F), p(F + CRIMP) + p(1), LW - 1 - p(F), p(F + CRIMP) + p(1)],
                fill=with_alpha(ms.shade(ms.GOLD_XL, 0.10), 90))
    # sombra que el precinto proyecta sobre el cuerpo: es lo que lo asienta
    # encima del papel en vez de dejarlo pegado como una calcomania
    cs = Image.new("RGBA", full, (0, 0, 0, 0))
    ImageDraw.Draw(cs).rectangle(
        [p(F), p(F + CRIMP), LW - 1 - p(F), p(F + CRIMP + 3)],
        fill=st["ao"] + (110,))
    cs = cs.filter(ImageFilter.GaussianBlur(p(1.6)))
    overlay(im, cs, body_mask)

    # --- emblema central ---------------------------------------------------- #
    # Lo que cambia de un estilo a otro: la gema tallada o el sello grabado.
    gx, gy = p((X0 + X1) / 2 - X0), p(57 - Y0)
    if st["emblem"] == "seal":
        emblem_seal(im, full, gx, gy, p(13.5))
    else:
        emblem_gem(im, full, body_mask, gx, gy, p(11), st["rarity"])

    # --- banda del pie ------------------------------------------------------ #
    # En marron oscuro con un filete de oro, como la del sobre de ahora: la
    # banda dorada entera se leia como el borde de una pantalla.
    band_y = 102 - Y0
    band = vgrad(full, [
        (0.00, ms.shade(st["band"], 0.16)),
        (0.45, st["band"]),
        (1.00, ms.shade(st["band"], -0.24)),
    ])
    band_mask = rrect_mask(full, (p(F), p(band_y), LW - 1 - p(F), p(band_y + 9)), p(1))
    im.paste(band, (0, 0), band_mask)
    bd = ImageDraw.Draw(im)
    bd.rectangle([p(F), p(band_y), LW - 1 - p(F), p(band_y)],
                 fill=ms.GOLD)
    bd.rectangle([p(F), p(band_y + 1), LW - 1 - p(F), p(band_y + 1)],
                 fill=with_alpha(ms.shade(ms.GOLD_D, -0.2), 150))
    # una hilera de muescas prensadas, a 1 unidad, para que no sea un liston liso
    for x in range(int(p(F) + p(3)), int(LW - p(F) - p(2)), int(p(5))):
        bd.rectangle([x, p(band_y + 4), x, p(band_y + 6)],
                     fill=with_alpha(ms.GOLD_D, 120))

    # --- esquineras turquesa ------------------------------------------------ #
    for cx, cy in ((X0 + 4, Y0 + 6), (X1 - 4, Y0 + 6),
                   (X0 + 4, Y1 - 10), (X1 - 4, Y1 - 10)):
        ex, ey = p(cx - X0), p(cy - Y0)
        bd.rectangle([ex - p(1.5), ey - p(1.5), ex + p(1.5), ey + p(1.5)],
                     fill=ms.TEAL_D)
        bd.rectangle([ex - p(1.5), ey - p(1.5), ex + p(0.5), ey + p(0.5)],
                     fill=ms.TEAL_L)

    # --- marco dorado con bisel -------------------------------------------- #
    ring_mask = ImageChops.subtract(
        rrect_mask(full, outer, p(R)), body_mask)
    frame = diag_grad(full, [
        (0.00, ms.GOLD_HI),
        (0.06, ms.GOLD_XL),
        (0.35, ms.GOLD),
        (0.70, ms.GOLD_D),
        (1.00, ms.shade(ms.GOLD_D, -0.25)),
    ])
    im.paste(frame, (0, 0), ring_mask)

    # filo exterior oscuro: sin el, el marco flota sobre la mesa
    edges = ImageChops.subtract(rrect_mask(full, outer, p(R)),
                                rrect_mask(full, (p(0.8), p(0.8),
                                                  LW - 1 - p(0.8),
                                                  LH - 1 - p(0.8)), p(R)))
    overlay(im, Image.new("RGBA", full, with_alpha(ms.shade(ms.GOLD_D, -0.35), 190)),
            edges)

    # luz de borde por dentro del marco, en la esquina de arriba a la izquierda
    rim = ImageChops.subtract(body_mask, rrect_mask(
        full, (body_box[0] + p(1.1), body_box[1] + p(1.1),
               body_box[2] - p(0.2), body_box[3] - p(0.2)), body_r))
    overlay(im, Image.new("RGBA", full, (255, 246, 224, 70)), rim)

    # --- grano del papel ---------------------------------------------------- #
    rnd = random.Random(7)
    grain = Image.new("RGBA", full, (0, 0, 0, 0))
    gdr = ImageDraw.Draw(grain)
    for _ in range(240):
        x = rnd.randrange(LW)
        y = rnd.randrange(LH)
        gdr.point((x, y), fill=(255, 246, 226, 13))
    im.alpha_composite(grain)

    return im


def compose_pack(style: str = "A") -> Image.Image:
    """El sobre centrado en el lienzo CUADRADO que espera el juego.

    build_pack() dibuja solo el rectangulo del sobre, que no es cuadrado. Si se
    escala eso a 128x128 el sobre sale aplastado y mas ancho: por eso se centra
    primero en un lienzo de 128x128.
    """
    local = build_pack(style)
    canvas = Image.new("RGBA", (GRID * S, GRID * S), (0, 0, 0, 0))
    ox = (GRID * S - local.width) // 2
    oy = (GRID * S - local.height) // 2
    canvas.alpha_composite(local, (ox, oy))

    # Borde en sierra del precinto. Va aqui y no en build_pack() porque los
    # dientes sobresalen del rectangulo del sobre, y build_pack() dibuja justo
    # ese rectangulo. Dos unidades por diente, que a 128 son 2 pixeles de arte.
    d = ImageDraw.Draw(canvas)
    step = 4 * S
    for i, x in enumerate(range(ox + S, ox + local.width - S, step)):
        d.rectangle([x, oy - 2 * S, x + 2 * S - 1, oy], fill=ms.GOLD)
        d.rectangle([x, oy - 2 * S, x + 2 * S - 1, oy - 2 * S + S - 1],
                    fill=ms.GOLD_HI)
        d.rectangle([x + 2 * S, oy - S + 1, x + 2 * S + S - 1, oy],
                    fill=ms.GOLD_D)
    return canvas


# --------------------------------------------------------------------------- #
# Las tres densidades
# --------------------------------------------------------------------------- #

def _palette_lookup():
    """Buscador de color permitido, por cajas de 8 para no recorrer 6000 tonos."""
    allowed = {(c[0], c[1], c[2]) for c in ms.allowed_colors()}
    boxes = {}
    for c in allowed:
        boxes.setdefault((c[0] // 8, c[1] // 8, c[2] // 8), []).append(c)
    cache = {}

    def nearest(rgb):
        if rgb in allowed:
            return rgb
        if rgb in cache:
            return cache[rgb]
        bx, by, bz = rgb[0] // 8, rgb[1] // 8, rgb[2] // 8
        best, best_d = None, None
        for rad in range(0, 32):
            for i in range(bx - rad, bx + rad + 1):
                for j in range(by - rad, by + rad + 1):
                    for k in range(bz - rad, bz + rad + 1):
                        if max(abs(i - bx), abs(j - by), abs(k - bz)) != rad:
                            continue
                        for c in boxes.get((i, j, k), ()):
                            d = ((c[0] - rgb[0]) ** 2 + (c[1] - rgb[1]) ** 2
                                 + (c[2] - rgb[2]) ** 2)
                            if best_d is None or d < best_d:
                                best, best_d = c, d
            if best is not None and best_d is not None and rad >= 2:
                break
        out = best or rgb
        cache[rgb] = out
        return out

    return nearest


def quantize_to_grid(master: Image.Image, grid: int, palette: bool,
                     tones: int = 0) -> Image.Image:
    """Baja el dibujo suave a la rejilla del juego.

    Con palette=True cada pixel se lleva al tono permitido mas cercano, que es lo
    que exige el auditor. Con tones>0 se posteriza antes (el aspecto "plano").
    """
    small = master.resize((grid, grid), Image.BOX)
    alpha = small.split()[3].point(lambda a: 255 if a > 110 else 0)
    small.putalpha(alpha)
    px = small.load()
    nearest = _palette_lookup() if palette else None
    for y in range(grid):
        for x in range(grid):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if tones:
                step = 255 // max(1, tones - 1)
                r, g, b = (min(255, int(round(v / step)) * step) for v in (r, g, b))
            if nearest is not None:
                r, g, b = nearest((r, g, b))
            px[x, y] = (r, g, b, 255)
    return small


def upscale(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.NEAREST)


# --------------------------------------------------------------------------- #
# Hoja comparativa
# --------------------------------------------------------------------------- #

def load_now() -> Image.Image:
    """El sobre que hay ahora en el juego, a 256 (como se ve en la mesa)."""
    return Image.open(os.path.join("Sprites", "packs", "pack_cards.png")
                      ).convert("RGBA").resize((256, 256), Image.NEAREST)


FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

BG = (28, 19, 16, 255)
INK = (252, 236, 196, 255)
INK_D = (176, 146, 112, 255)
WOOD = (82, 49, 29, 255)


def _font(path: str, size: int):
    from PIL import ImageFont
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def sheet(columns, titulo: str, subtitulo: str, pie: str) -> Image.Image:
    """Una columna por variante, a tamano de mesa y con el emblema a 2x."""
    cw, margin = 340, 24
    head, row1, row2, foot = 96, 300, 300, 44
    w = margin * 2 + cw * len(columns)
    h = head + row1 + row2 + foot
    sh = Image.new("RGBA", (w, h), BG)
    d = ImageDraw.Draw(sh)
    f_title = _font(FONT_B, 27)
    f_sub = _font(FONT, 15)
    f_col = _font(FONT_B, 17)
    f_note = _font(FONT, 13)

    d.text((margin, 20), titulo, font=f_title, fill=INK)
    d.text((margin, 56), subtitulo,
           font=f_sub, fill=INK_D)

    for i, (title, img, note) in enumerate(columns):
        x = margin + i * cw
        d.text((x + 26, head - 26), title, font=f_col, fill=INK)
        d.text((x + 26, head - 6), note, font=f_note, fill=INK_D)
        # la mesa, para juzgar el sobre donde va a estar de verdad
        panel = Image.new("RGBA", (272, 272), WOOD)
        pd = ImageDraw.Draw(panel)
        for y in range(0, 272, 34):
            pd.line([(0, y), (272, y + 8)], fill=(92, 56, 33, 255), width=1)
        sh.alpha_composite(panel, (x + 26, head + 22))
        sh.alpha_composite(img.resize((256, 256), Image.NEAREST), (x + 34, head + 30))

        k = img.width / 256.0
        half = 64 * k
        zoom = img.crop((128 * k - half, 113 * k - half,
                         128 * k + half, 113 * k + half)).resize(
            (256, 256), Image.NEAREST)
        zy = head + row1 + 26
        d.text((x + 26, zy - 22), "EL EMBLEMA A 2x", font=f_note, fill=INK_D)
        sh.alpha_composite(zoom, (x + 34, zy))
        d.rectangle([x + 25, head + 21, x + 25 + 274, head + 21 + 274],
                    outline=(120, 88, 56, 200))
        d.rectangle([x + 33, zy - 1, x + 33 + 258, zy + 257],
                    outline=(120, 88, 56, 200))

    d.text((margin, h - 30), pie,
           font=f_sub, fill=INK_D)
    return sh


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    shim = type("Shim", (), {"want_outline": False})()

    sprites = {}
    for key in ("A", "B", "C"):
        q256 = quantize_to_grid(compose_pack(key), 256, palette=True)
        q256.save(os.path.join(OUT, f"pack_style_{key}.png"))
        img = upscale(q256, 512)
        problems = ms.audit_sprite(shim, img, f"pack_style_{key}", 2)
        print(f"AUDITORIA {key}:", "todo correcto." if not problems else problems)
        sprites[key] = img

    # Hoja 1: los tres disenos, misma calidad.
    cols = [(STYLES[k]["nombre"], sprites[k], f"rejilla 256 - {STYLES[k]['emblem']}")
            for k in ("A", "B", "C")]
    sheet(cols,
          "TRES DISENOS DEL SOBRE, MISMA CALIDAD",
          "Rejilla de 256: 1 px de arte por px en la mesa. El emblema, a 2x.",
          "Misma silueta, mismo marco y mismo precinto: cambia el papel, la banda y el emblema."
          ).save(os.path.join(OUT, "pack_disenos_comparativa.png"))
    print("escrito:", os.path.join(OUT, "pack_disenos_comparativa.png"))

    # Hoja 2: la de calidad, con el diseno de siempre.
    q128 = quantize_to_grid(compose_pack("A"), 128, palette=True)
    q128.save(os.path.join(OUT, "pack_quality_128.png"))
    problems = ms.audit_sprite(shim, upscale(q128, 512), "pack_cards_hifi", 4)
    print("AUDITORIA 128:", "todo correcto." if not problems else problems)

    cols = [("AHORA", load_now(), "rejilla 32 - 11 colores - bloque de 8 px"),
            ("128 CON VOLUMEN", upscale(q128, 512),
             "rejilla 128 - 526 colores - bloque de 2 px"),
            ("256", sprites["A"], "rejilla 256 - 612 colores - 1 px, sin rejilla")]
    sheet(cols,
          "EL MISMO SOBRE, TRES CALIDADES",
          "Tamano de mesa (256 px) arriba; el emblema a 2x abajo.",
          "En la mesa, cada pixel de arte mide 8 px ahora y 2 px o 1 px en las dos propuestas."
          ).save(os.path.join(OUT, SHEET))
    print("escrito:", os.path.join(OUT, SHEET))


if __name__ == "__main__":
    main()
