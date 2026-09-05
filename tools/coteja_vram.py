#!/usr/bin/env python3
"""Compara la VRAM que monta tools/graficos.py con la del emulador, byte a byte.

Mirar el dibujo no basta. Las imagenes del repositorio se montan ejecutando en
Python los pasos del cartucho, y la unica forma de saber si el formato esta
bien leido es coger la VRAM que el VDP tiene DE VERDAD -volcada con
tools/omsx_vram.tcl- y restarle la de Python.

Se compara por tablas, porque no todas dicen lo mismo:

  color      0x0000..0x17FF   los 8 bytes de color de cada tile
  patrones   0x2000..0x37FF   los dibujos de los tiles
  nombres    0x3800..0x3AFF   que tile va en cada casilla
  spr patr   0x1800..0x1FFF   los patrones de sprite

Las tres primeras son ESTATICAS: se montan una vez y no se tocan hasta que
cambia la pantalla, asi que tienen que salir a cero. La tabla de nombres y los
patrones de sprite si se mueven -el atleta, los marcadores, los rotulos que
parpadean-, y ahi lo que se mira es cuantas casillas bailan y si son las que
deben.

Uso: coteja_vram.py <rom> <org> <carpeta de volcados> [pantalla=volcado ...]
"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import graficos as g                                          # noqa: E402

TABLAS = (
    ("color", 0x0000, 0x1800),
    ("spr patr", 0x1800, 0x0800),
    ("patrones", 0x2000, 0x1800),
    ("nombres", 0x3800, 0x0300),
)


def lee_info(ruta):
    d = {}
    for linea in open(ruta, encoding="utf-8"):
        k, _, v = linea.strip().partition(" ")
        d[k] = v
    return d


def compara(nuestra, suya):
    """Las diferencias por tabla: (nombre, cuantas, de cuantas)."""
    out = []
    for nombre, ini, n in TABLAS:
        d = sum(1 for i in range(n) if nuestra[ini + i] != suya[ini + i])
        out.append((nombre, d, n))
    return out


def main(argv):
    if len(argv) < 4:
        return print(__doc__) or 2
    rom = open(argv[1], "rb").read()
    org = int(argv[2], 0)
    carpeta = argv[3]

    # que pantalla de graficos.py se compara con que volcado
    pares = []
    for a in argv[4:]:
        k, _, v = a.partition("=")
        pares.append((k, v))
    if not pares:
        pares = [("logotipo", "00"), ("titulo", "02"), ("ciclismo", "03"),
                 ("triple-salto", "17"), ("curling", "25")]

    # Las cuatro pruebas se montan ENCIMA del titulo, igual que en main() de
    # graficos.py: entre escena y escena el cartucho no borra los patrones ni
    # el color (L_43C4 solo esconde los sprites y borra la tabla de nombres),
    # asi que lo de debajo sigue ahi. Compararlas montadas desde cero mete
    # cientos de bytes de diferencia que no son un error de lectura sino la
    # herencia que falta: en el triple salto, 650 patrones contra 336.
    monta = {
        "logotipo": g.logotipo, "titulo": g.titulo,
        "ciclismo": lambda r, o: g.sobre_el_titulo(r, o, g.ciclismo),
        "curling": lambda r, o: g.sobre_el_titulo(r, o, g.curling),
        "triple-salto":
            lambda r, o: g.sobre_el_titulo(
                r, o, lambda a, b, base=None: g.salto(a, b, False, base)),
        "pertiga":
            lambda r, o: g.sobre_el_titulo(
                r, o, lambda a, b, base=None: g.salto(a, b, True, base)),
    }

    print("%-14s %-8s  %s" % ("pantalla", "volcado", "bytes distintos por tabla"))
    print("=" * 74)
    total = 0
    for nombre, num in pares:
        vr = os.path.join(carpeta, "vram_%s.bin" % num)
        if not os.path.exists(vr):
            print("  %-14s %-8s  (no hay volcado)" % (nombre, num))
            continue
        suya = open(vr, "rb").read()
        info = lee_info(os.path.join(carpeta, "info_%s.txt" % num))
        p = monta[nombre](rom, org)
        res = compara(p.vram, suya)
        detalle = "  ".join("%s %d/%d" % (n, d, t) for n, d, t in res)
        print("  %-14s %-8s  %s" % (nombre, num, detalle))
        print("  %-14s %-8s  (prueba %s, escena %s, t=%s)"
              % ("", "", info.get("prueba_y_vuelta"), info.get("escena"),
                 info.get("tiempo", "?")[:6]))
        total += sum(d for _, d, _ in res)
    print("-" * 74)
    print("  total de bytes distintos: %d" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
