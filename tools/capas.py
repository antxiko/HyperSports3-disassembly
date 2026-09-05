#!/usr/bin/env python3
"""Separa en dos capas un volcado de VRAM: lo que son CASILLAS y lo que son SPRITES.

Para que sirve: mirando una pantalla del MSX no se sabe que parte del dibujo
esta hecha con la tabla de nombres y cual con los 32 sprites del VDP. Y la
diferencia importa, porque cada una se monta con un codigo distinto del
cartucho -y porque el MSX1 solo pinta cuatro sprites por linea, asi que lo que
se lleva a sprites es siempre una decision del programador-.

Con el volcado de tools/omsx_vram.tcl delante, esto saca tres PNG del mismo
instante:

    <nombre>-completa.png   lo que se ve, casillas y sprites
    <nombre>-casillas.png   solo la tabla de nombres, sin un solo sprite
    <nombre>-sprites.png    solo los sprites, sobre un fondo a cuadros

Y por la salida estandar, la lista de sprites activos con su patron y su
color, agrupados por figura: los que comparten Y y caen a menos de dieciseis
pixeles son el mismo dibujo en dos capas de color, que es como se hace un
sprite de dos colores en un MSX1.

Uso: capas.py <carpeta de volcados> <numero> <carpeta de salida> [nombre]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import graficos as g                                          # noqa: E402

CUADROS = ((255, 0, 255), (200, 0, 200))       # el fondo de la capa de sprites


def carga(carpeta, num):
    """La VRAM del volcado, dentro de una Pantalla para poder pintarla."""
    vram = open(os.path.join(carpeta, "vram_%s.bin" % num), "rb").read()
    p = g.Pantalla(b"\x00" * 0x8000, 0x4000)
    p.vram = bytearray(vram[:0x4000])
    return p


def lee_info(carpeta, num):
    d = {}
    ruta = os.path.join(carpeta, "info_%s.txt" % num)
    if os.path.exists(ruta):
        for linea in open(ruta, encoding="utf-8"):
            k, _, v = linea.strip().partition(" ")
            d[k] = v
    return d


def activos(p):
    """Los sprites que se ven, en orden de la tabla de atributos."""
    out = []
    for s in range(32):
        a = 0x3B00 + s * 4
        y, x, patron, color = (p.vram[a], p.vram[a + 1],
                               p.vram[a + 2], p.vram[a + 3])
        if y == 0xD0:
            break
        if y > 0xC0 or not (color & 15):
            continue
        out.append((s, y, x - 32 if color & 0x80 else x, patron, color & 15))
    return out


def figuras(lista):
    """Agrupa los sprites que son el mismo dibujo en varias capas de color."""
    grupos = []
    for s in lista:
        for gr in grupos:
            if abs(gr[0][1] - s[1]) <= 2 and abs(gr[0][2] - s[2]) <= 8:
                gr.append(s)
                break
        else:
            grupos.append([s])
    return grupos


def main(argv):
    if len(argv) < 4:
        return print(__doc__) or 2
    carpeta, num, salida = argv[1], argv[2], argv[3]
    nombre = argv[4] if len(argv) > 4 else "capas_%s" % num
    os.makedirs(salida, exist_ok=True)

    p = carga(carpeta, num)
    info = lee_info(carpeta, num)

    solo_casillas = p.imagen()
    completa = p.sprites(p.imagen())
    fondo = [[CUADROS[((f // 8) + (c // 8)) & 1] for c in range(256)]
             for f in range(192)]
    solo_sprites = p.sprites(fondo)

    for etiqueta, px in (("completa", completa), ("casillas", solo_casillas),
                         ("sprites", solo_sprites)):
        ruta = os.path.join(salida, "%s-%s.png" % (nombre, etiqueta))
        g.png(ruta, px)
        print("  %s" % ruta)

    print("\nvolcado %s  t=%s  escena %s  prueba %s"
          % (num, info.get("tiempo", "?")[:6], info.get("escena", "?"),
             info.get("prueba_y_vuelta", "?")))
    lista = activos(p)
    print("%d sprites activos, en %d figuras:" % (len(lista), len(figuras(lista))))
    for gr in figuras(lista):
        piezas = "  ".join("[%02d] patron 0x%02X color %X" % (s[0], s[3], s[4])
                           for s in gr)
        print("  y=%3d x=%3d  %s" % (gr[0][1], gr[0][2], piezas))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
