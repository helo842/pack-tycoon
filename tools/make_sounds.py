#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_sounds.py - Generador procedural de los sonidos del juego.

No hay ni un WAV descargado: todos salen de aqui, con ondas cuadradas,
triangulares y ruido filtrado. Es la misma idea que make_sprites.py y por el
mismo motivo: los sonidos tienen que sonar a la misma familia entre si, y
cambiar el tono de todos a la vez tiene que ser cambiar una linea.

Estilo objetivo (chiptune de los 80, sin sintetizador real):
  - ondas duras (cuadrada y triangular), nada de samples orquestales
  - notas cortas, ataque de pocos milisegundos y caida rapida
  - 22050 Hz, mono, 16 bits: es lo que se usaba y ademas pesa poco
  - musica de fondo lenta y baja, para que no tape los efectos

Uso:
    python3 tools/make_sounds.py --all
    python3 tools/make_sounds.py --all --audit
    python3 tools/make_sounds.py --list
    python3 tools/make_sounds.py --only sfx_coin_chime
"""

from __future__ import annotations

import argparse
import math
import os
import random
import sys
import wave
from array import array
from typing import Callable, Dict, List, Optional, Sequence, Tuple

# --------------------------------------------------------------------------- #
# Configuracion
# --------------------------------------------------------------------------- #

SR = 22050          # muestras por segundo. Es el de los 80 y pesa la mitad que 44100
BITS = 16
OUT = "Sounds"      # carpeta en la raiz del proyecto
SFX_DIR = "sfx"
MUSIC_DIR = "music"
TOP = 32767

# --------------------------------------------------------------------------- #
# Ondas
#
# Todas reciben la FASE (no el tiempo) y devuelven -1..1. Trabajar con fase es
# lo que permite cambiar la frecuencia a mitad de nota (el barrido del error)
# sin que el sonido se rompa: si se calculara desde el tiempo habria saltos.
# --------------------------------------------------------------------------- #


def _square(ph: float, duty: float = 0.5) -> float:
    return 1.0 if (ph - math.floor(ph)) < duty else -1.0


def _triangle(ph: float) -> float:
    x = ph - math.floor(ph)
    return 4.0 * abs(x - 0.5) - 1.0


def _sine(ph: float) -> float:
    return math.sin(2.0 * math.pi * (ph - math.floor(ph)))


WAVES: Dict[str, Callable[[float], float]] = {
    "square": _square,
    "triangle": _triangle,
    "sine": _sine,
}


# --------------------------------------------------------------------------- #
# Envolventes: reciben t de 0 a 1 y devuelven la ganancia
# --------------------------------------------------------------------------- #


def env_perc(power: float = 3.0, attack: float = 0.006) -> Callable[[float], float]:
    """Caida rapida: el ataque y el golpe de un efecto corto."""
    def f(t: float) -> float:
        if t < attack:
            return t / attack
        u = (t - attack) / (1.0 - attack)
        return (1.0 - u) ** power
    return f


def env_adsr(a: float = 0.01, d: float = 0.08, s: float = 0.6,
             r: float = 0.3) -> Callable[[float], float]:
    """Sostenida: para la musica, que no puede caerse sola en cada nota."""
    def f(t: float) -> float:
        if t < a:
            return t / a
        if t < a + d:
            return 1.0 - (1.0 - s) * ((t - a) / d)
        if t < 1.0 - r:
            return s
        return s * max(0.0, (1.0 - t) / r)
    return f


def env_bumps(bumps: Sequence[Tuple[float, float]],
              power: float = 1.6) -> Callable[[float], float]:
    """
    Varios tirones seguidos. Es lo que hace que un rasgado suene a rasgado y no
    a un solo chasquido: el rugoso de una cinta que se despega a tirones.
    `bumps` son pares (centro, ancho).
    """
    def f(t: float) -> float:
        v = 0.0
        for c, w in bumps:
            v = max(v, math.exp(-((t - c) / w) ** 2))
        return v ** power
    return f


# --------------------------------------------------------------------------- #
# Voces: devuelven una lista de muestras que luego se colocan donde toque
# --------------------------------------------------------------------------- #


def _wave_value(wave: str, ph: float, duty: float) -> float:
    """La cuadrada acepta `duty`; las otras dos no, asi que se separan aqui."""
    if wave == "square":
        return _square(ph, duty)
    return WAVES.get(wave, _triangle)(ph)


def tone(dur: float, freq: float, wave: str = "square", duty: float = 0.5,
         amp: float = 0.25, env: Optional[Callable[[float], float]] = None,
         sweep: float = 1.0, vib_hz: float = 0.0,
         vib_cents: float = 0.0) -> List[float]:
    """
    Una nota.

    `sweep` < 1 la baja de tono segun avanza (el "no" del error) y > 1 la sube.
    `vib_*` le mete un temblor, que es lo que hace que una nota larga no suene a
    pitido de electrodomestico.
    """
    n = max(1, int(round(dur * SR)))
    env = env or env_perc()
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / (n - 1) if n > 1 else 0.0
        f = freq * (sweep ** t)
        if vib_hz > 0.0 and vib_cents != 0.0:
            f *= 2.0 ** ((vib_cents / 1200.0) * math.sin(2.0 * math.pi * vib_hz * i / SR))
        ph += f / SR
        out[i] = amp * env(t) * _wave_value(wave, ph, duty)
    return out


def noise(dur: float, amp: float = 0.3, lp0: float = 800.0, lp1: float = 4000.0,
          env: Optional[Callable[[float], float]] = None, seed: int = 1) -> List[float]:
    """
    Ruido filtrado. El filtro es un pasa-bajos de un polo que se va abriendo: en
    el rasgado eso suena a plastico que se estira y de repente cede.

    La semilla es fija por sonido: si no, regenerar daria un rasgado distinto
    cada vez y no se podria comparar uno con otro (igual que el desgaste de los
    sprites).
    """
    n = max(1, int(round(dur * SR)))
    env = env or env_perc()
    rnd = random.Random(seed)
    out = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / (n - 1) if n > 1 else 0.0
        cut = lp0 + (lp1 - lp0) * t
        a = 1.0 - math.exp(-2.0 * math.pi * cut / SR)
        y += a * (rnd.uniform(-1.0, 1.0) - y)
        # x2.6: el filtro de un polo se come casi toda la energia, y sin esto
        # habria que compensarlo a mano en cada sitio que lo use.
        out[i] = amp * env(t) * y * 2.6
    return out


# --------------------------------------------------------------------------- #
# Mezcla
# --------------------------------------------------------------------------- #


def blank(dur: float) -> List[float]:
    return [0.0] * max(1, int(round(dur * SR)))


def place(dst: List[float], at: float, src: Sequence[float],
          gain: float = 1.0) -> None:
    """Mezcla `src` dentro de `dst` empezando en el segundo `at`."""
    start = int(round(at * SR))
    for i, v in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += v * gain


def notes(dst: List[float], seq: Sequence[float], step: float, dur: float,
          **kwargs) -> None:
    """Una escalera de notas separadas siempre lo mismo. Media docena de efectos son esto."""
    for i, f in enumerate(seq):
        place(dst, i * step, tone(dur, float(f), **kwargs))


def fade_edges(buf: List[float], secs: float = 0.04) -> None:
    """Quita el chasquido del principio y del final (y deja el bucle limpio)."""
    n = max(1, int(round(secs * SR)))
    n = min(n, len(buf) // 2)
    for i in range(n):
        k = i / n
        buf[i] *= k
        buf[-1 - i] *= k


def normalize(buf: List[float], peak: float) -> None:
    """Deja el pico donde se pide. Sin esto cada efecto sale a un volumen distinto."""
    hi = max((abs(v) for v in buf), default=0.0)
    if hi <= 1e-9:
        return
    k = peak / hi
    for i in range(len(buf)):
        buf[i] *= k


# --------------------------------------------------------------------------- #
# Los efectos
#
# Cada uno es una funcion sin argumentos que devuelve el buffer entero. El
# volumen final lo fija normalize(): aqui se escribe la MEZCLA (que suena mas
# que que), no el volumen.
# --------------------------------------------------------------------------- #

def sfx_click() -> List[float]:
    """Pulsar cualquier boton. Cortisimo, para que se pueda repetir sin cansar."""
    b = blank(0.06)
    place(b, 0.0, tone(0.055, 1300.0, "square", 0.5, 0.30, env_perc(4.0, 0.003)))
    # Un armonico agudo encima: es lo que da la sensacion de "clic" y no de "bip".
    place(b, 0.0, tone(0.045, 2600.0, "square", 0.5, 0.10, env_perc(6.0, 0.002)))
    return b


def sfx_toggle() -> List[float]:
    """Encender y apagar las dos automatizaciones: sube, para que se note que va a mas."""
    b = blank(0.17)
    place(b, 0.0, tone(0.05, 780.0, "square", 0.5, 0.26, env_perc(3.0, 0.003)))
    place(b, 0.05, tone(0.10, 1170.0, "square", 0.5, 0.26, env_perc(3.0, 0.003)))
    return b


def sfx_buy() -> List[float]:
    """Comprar un paquete. Son las dos notas de la moneda de toda la vida (B5 y E6)."""
    b = blank(0.27)
    place(b, 0.0, tone(0.07, 987.77, "square", 0.5, 0.26, env_perc(2.0, 0.002)))
    place(b, 0.055, tone(0.20, 1318.51, "square", 0.5, 0.30, env_perc(2.5, 0.002)))
    return b


def sfx_rip() -> List[float]:
    """Empezar a abrir un paquete: cuatro tirones de cinta y un golpe grave al final."""
    b = blank(0.46)
    place(b, 0.0, noise(0.34, 0.30, 700.0, 4200.0,
                        env_bumps([(0.08, 0.055), (0.30, 0.05),
                                   (0.53, 0.045), (0.80, 0.10)]), seed=11))
    # El golpe es lo que dice "ya esta abierto" y no "se ha roto algo".
    place(b, 0.32, tone(0.11, 110.0, "triangle", 0.5, 0.30, env_perc(3.0, 0.003)))
    return b


def sfx_open() -> List[float]:
    """Termina la espera y sale la tarjeta. Cuatro notas subiendo (C E G C)."""
    b = blank(0.60)
    notes(b, [523.25, 659.26, 783.99, 1046.50], 0.075, 0.34,
          wave="square", duty=0.32, amp=0.17, env=env_perc(3.0, 0.005))
    place(b, 0.22, tone(0.34, 2093.00, "sine", amp=0.06, env=env_perc(3.5, 0.02)))
    return b


def sfx_sell() -> List[float]:
    """Vender un objeto de la mesa. Moneda corta, con la misma familia que sfx_buy."""
    b = blank(0.21)
    place(b, 0.0, tone(0.05, 1046.50, "square", 0.5, 0.24, env_perc(2.5, 0.002)))
    place(b, 0.045, tone(0.15, 1567.98, "square", 0.5, 0.26, env_perc(2.5, 0.002)))
    return b


def sfx_sell_all() -> List[float]:
    """VENDER TODO: la misma moneda, seis veces seguidas subiendo."""
    b = blank(0.64)
    notes(b, [523.25, 659.26, 783.99, 1046.50, 1318.51, 1567.98], 0.055, 0.18,
          wave="square", duty=0.5, amp=0.20, env=env_perc(3.0, 0.002))
    place(b, 0.30, tone(0.32, 2093.00, "sine", amp=0.07, env=env_perc(4.0, 0.01)))
    return b


def sfx_error() -> List[float]:
    """No te llega el dinero, la mesa esta llena... Un "no" grave que cae."""
    b = blank(0.32)
    place(b, 0.0, tone(0.24, 240.0, "square", 0.5, 0.26, env_perc(2.0, 0.003), sweep=0.62))
    place(b, 0.0, tone(0.24, 121.0, "triangle", 0.5, 0.16, env_perc(2.0, 0.003), sweep=0.62))
    return b


def sfx_tool() -> List[float]:
    """Comprar una herramienta: sube el nivel, asi que sube el sonido y remata con campana."""
    b = blank(0.74)
    notes(b, [659.26, 783.99, 987.77, 1318.51, 1567.98], 0.060, 0.26,
          wave="triangle", amp=0.16, env=env_perc(3.0, 0.004))
    place(b, 0.30, tone(0.40, 2093.00, "sine", amp=0.11, env=env_perc(3.0, 0.008)))
    place(b, 0.30, tone(0.36, 3135.96, "sine", amp=0.05, env=env_perc(4.0, 0.008)))
    return b


def sfx_rare() -> List[float]:
    """
    El aviso de que lo que ha salido vale la pena. Va ENCIMA de sfx_open, no en
    su lugar: primero se oye que se abre y luego el premio.
    """
    b = blank(1.10)
    notes(b, [783.99, 1046.50, 1318.51], 0.085, 0.22,
          wave="square", duty=0.35, amp=0.20, env=env_perc(3.0, 0.004))
    # El acorde aguanta; con notas sueltas sonaria a escala y no a premio.
    for f in (1046.50, 1318.51, 1567.98):
        place(b, 0.26, tone(0.74, f, "square", 0.28, 0.11,
                            env_adsr(0.01, 0.14, 0.55, 0.5)))
    place(b, 0.26, tone(0.78, 2093.00, "sine", amp=0.08, env=env_perc(3.0, 0.02)))
    return b


# --------------------------------------------------------------------------- #
# La musica
#
# Un bucle largo, lento y bajo. La regla es que no tiene que llamar la atencion:
# si se nota, esta alto. Por eso son tres voces muy separadas de volumen
# (bajo, colchon y arpegio) y nada de melodia que se pueda tararear mal.
# --------------------------------------------------------------------------- #

def music_backroom() -> List[float]:
    """Am - F - C - G, dos compases cada uno, con arpegio de tres notas del acorde."""
    bpm = 84.0
    beat = 60.0 / bpm
    bar = beat * 4.0
    bars = 8
    total = bar * bars

    # (bajo, [notas del colchon], [notas del arpegio, una octava arriba])
    prog = [
        (110.00, [220.00, 261.63, 329.63], [440.00, 523.25, 659.26]),   # Am
        (87.31, [174.61, 220.00, 261.63], [349.23, 440.00, 523.25]),    # F
        (130.81, [196.00, 261.63, 329.63], [392.00, 523.25, 659.26]),   # C
        (98.00, [196.00, 246.94, 293.66], [392.00, 493.88, 587.33]),    # G
    ]
    # Un patron de ocho corcheas por compas. El -1 es silencio: sin huecos el
    # arpegio se convierte en una escala que no para.
    pattern = [0, 2, 1, -1, 2, 0, 1, 2]

    b = blank(total)
    for i in range(bars):
        chord = prog[(i // 2) % len(prog)]
        at = i * bar
        root, pad, arp = chord

        # El bajo dura casi el compas entero: es lo que sostiene el bucle.
        place(b, at, tone(bar * 0.90, root, "triangle", amp=0.22,
                          env=env_adsr(0.04, 0.35, 0.55, 0.5)))
        # El colchon entra despacio (0,35 s de ataque) para que no golpee.
        for f in pad:
            place(b, at, tone(bar * 0.95, f, "triangle", amp=0.055,
                              env=env_adsr(0.35, 0.45, 0.62, 0.5),
                              vib_hz=4.5, vib_cents=6.0))
        # El arpegio, nota por nota, callado.
        for j, k in enumerate(pattern):
            if k < 0:
                continue
            place(b, at + j * beat * 0.5,
                  tone(beat * 0.45, arp[k], "square", 0.25, 0.075,
                       env_perc(3.5, 0.008)))

    # El bucle se cierra con las puntas fundidas: si no, entre la ultima muestra
    # y la primera hay un escalon y se oye un chasquido cada vuelta.
    fade_edges(b, 0.05)
    return b


# --------------------------------------------------------------------------- #
# Registro
# --------------------------------------------------------------------------- #

SFX: Dict[str, Callable[[], List[float]]] = {
    "sfx_click": sfx_click,
    "sfx_toggle": sfx_toggle,
    "sfx_buy": sfx_buy,
    "sfx_rip": sfx_rip,
    "sfx_open": sfx_open,
    "sfx_sell": sfx_sell,
    "sfx_sell_all": sfx_sell_all,
    "sfx_error": sfx_error,
    "sfx_tool": sfx_tool,
    "sfx_rare": sfx_rare,
}

MUSIC: Dict[str, Callable[[], List[float]]] = {
    "music_backroom": music_backroom,
}

# Volumen final de cada cosa. Los efectos van mas altos que la musica a
# proposito: la musica es fondo y el jugador la puede bajar aparte.
SFX_PEAK = 0.85
MUSIC_PEAK = 0.55


def rel_path(name: str) -> str:
    """La carpeta la decide el prefijo, igual que en los sprites."""
    return f"{MUSIC_DIR}/{name}.wav" if name.startswith("music_") else f"{SFX_DIR}/{name}.wav"


def write_wav(path: str, samples: Sequence[float]) -> None:
    data = array("h", (int(max(-1.0, min(1.0, s)) * TOP) for s in samples))
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(BITS // 8)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


def write_index(path: str, names: Sequence[str]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write("# Indice de sonidos: nombre corto<TAB>ruta dentro de Sounds/.\n")
        f.write("# Lo genera tools/make_sounds.py. No editar a mano.\n")
        f.write("# El juego lo lee en scripts/core/audio.gd.\n")
        for n in sorted(names):
            f.write(f"{n}\t{rel_path(n)}\n")


# --------------------------------------------------------------------------- #
# Auditoria
#
# No puede juzgar si un sonido es bonito, pero si cazar los cuatro fallos que
# se cuelan solos: que no suene nada, que sature, que el bucle chasquee y que el
# indice y los ficheros se desincronicen.
# --------------------------------------------------------------------------- #

def audit(name: str, samples: Sequence[float]) -> List[str]:
    avisos: List[str] = []
    n = len(samples)
    peak = max((abs(v) for v in samples), default=0.0)
    dur = n / SR

    if any(v != v for v in samples):            # NaN
        avisos.append("hay muestras que no son un numero")
    if peak > 0.999:
        avisos.append(f"satura (pico {peak:.3f})")
    if peak < 0.05:
        avisos.append(f"casi no suena (pico {peak:.3f})")
    if dur < 0.02:
        avisos.append(f"demasiado corto ({dur * 1000:.0f} ms)")
    if dur > 45.0:
        avisos.append(f"demasiado largo ({dur:.1f} s)")
    # Un sonido que empieza o acaba con la onda a media altura chasquea, tanto
    # al empezar como al repetirse en bucle.
    if abs(samples[0]) > 0.05 or abs(samples[-1]) > 0.05:
        avisos.append("empieza o acaba fuera de cero (chasquido)")
    return avisos


def main() -> None:
    ap = argparse.ArgumentParser(description="Genera los sonidos del juego.")
    ap.add_argument("--all", action="store_true", help="genera todos los sonidos")
    ap.add_argument("--only", nargs="+", metavar="NOMBRE",
                    help="solo estos (los efectos o la musica por su nombre corto)")
    ap.add_argument("--list", action="store_true", help="lista los sonidos disponibles")
    ap.add_argument("--audit", action="store_true",
                    help="revisa lo generado (silencio, saturacion, chasquidos) y sale "
                         "con codigo 1 si algo no cuadra")
    args = ap.parse_args()

    if args.list:
        print("Efectos:", ", ".join(sorted(SFX)))
        print("Musica :", ", ".join(sorted(MUSIC)))
        return

    if not args.all and not args.only:
        ap.print_help()
        print("\nUsa --all o --only <nombre> para generar.")
        return

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, OUT)

    todo: Dict[str, Tuple[Callable[[], List[float]], float]] = {}
    for k, v in SFX.items():
        todo[k] = (v, SFX_PEAK)
    for k, v in MUSIC.items():
        todo[k] = (v, MUSIC_PEAK)

    if args.only:
        desconocidos = [n for n in args.only if n not in todo]
        if desconocidos:
            print(f"No existe: {', '.join(desconocidos)}")
            sys.exit(1)
        todo = {n: todo[n] for n in args.only}

    problemas: List[Tuple[str, List[str]]] = []
    escritos: List[str] = []
    for name in sorted(todo):
        build, peak = todo[name]
        samples = build()
        normalize(samples, peak)
        rel = rel_path(name)
        path = os.path.join(out, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_wav(path, samples)
        escritos.append(name)
        print(f"  {len(samples) / SR:6.2f} s  {rel}")
        avisos = audit(name, samples)
        if avisos:
            problemas.append((rel, avisos))

    print(f"\n{len(escritos)} sonidos escritos en {OUT}/")

    names = list(SFX) + list(MUSIC)
    write_index(os.path.join(out, "index.tsv"), names)
    print(f"Indice: {OUT}/index.tsv ({len(names)} entradas)")

    if args.audit:
        print()
        for rel, avisos in problemas:
            print(f"  {rel}")
            for a in avisos:
                print(f"      - {a}")
        faltan = [n for n in names if not os.path.exists(os.path.join(out, rel_path(n)))]
        for n in faltan:
            print(f"  {n}: esta en el indice pero no hay fichero")
        if problemas or faltan:
            print(f"\nAUDITORIA: {len(problemas) + len(faltan)} problemas.")
            sys.exit(1)
        print(f"AUDITORIA: los {len(names)} sonidos estan bien.")


if __name__ == "__main__":
    main()
