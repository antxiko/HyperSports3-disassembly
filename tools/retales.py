#!/usr/bin/env python3
"""Los atletas, montados pieza a pieza EJECUTANDO el motor del cartucho.

Un atleta de Hyper Sports 3 no es un sprite: son dos o cuatro sprites de 16x16
puestos uno al lado del otro, y sus patrones NO estan en la VRAM esperando.
Cada cuadro se DESCOMPRIMEN otra vez encima de los mismos 2 KB de 0x1800, que
es donde el VDP busca los patrones de sprite (R6 = 0x03).

El motor es L_6992, y se le llama con DE apuntando a una figura y A diciendo
cuantas piezas tiene:

    L_6992  ld hl,(0e170h)          la copia en RAM de los atributos
    L_6995  push af
            ld a,(de) / cp 080h / jr z,L_69D7    un 0x80 CIERRA la figura
            add a,b / ld (hl),a / inc hl / inc de      Y  = dy + B
            ld a,(de) / exx / add a,c / exx            X  = dx + C'
            ld (hl),a / inc hl / inc hl                (el patron ya esta)
            push hl / inc de / ex de,hl
            ld e,(hl) / inc hl / ld d,(hl) / inc hl    DE = el bloque de patron
            ...  descomprime en la VRAM por `out (c),a`
            pop hl / ld a,(de) / ld (hl),a             el color

O sea que cada pieza son CINCO bytes:

    dy   dx   puntero al patron (word)   color

y un 0x80 en el sitio del dy cierra la figura -y ademas apaga los sprites que
queden, escribiendo 0xC3 en su Y-.

El descompresor de los patrones (L_69AF) es el mismo formato RLE que el de la
tabla de nombres, pero sin el mandato 0x80: 0x00 cierra, 0x01..0x7F repite el
byte que sigue esa cuenta, y con el bit 7 puesto copia (n & 0x7F) bytes.

Las tablas de figuras se sacan del listado, del patron
`ld hl,<tabla> / add a,a / call L_4046 / ld e,(hl) / inc hl / ld d,(hl)`, y
cuantas entradas tiene cada una lo fija su entrada MAS BAJA, que cae justo
donde acaba la tabla.

Uso: retales.py <rom> <org> <tabla> <piezas> [--dibuja <directorio>]
"""
import os
import sys


def descomprime_patron(rom, org, p):
    """L_69AF. Devuelve (bytes de patron, direccion donde acaba)."""
    q = p - org
    fuera = bytearray()
    while True:
        if q >= len(rom):
            return None, None
        ctrl = rom[q]
        q += 1
        if ctrl == 0x00:
            return bytes(fuera), org + q
        n = ctrl & 0x7F
        if n == ctrl:                          # bit 7 a cero: repeticion
            if q >= len(rom):
                return None, None
            fuera += bytes([rom[q]]) * n
            q += 1
        else:                                  # literal
            if q + n > len(rom):
                return None, None
            fuera += rom[q:q + n]
            q += n
    return None, None


def entradas_de_tabla(rom, org, tabla):
    """Cuantas entradas tiene: lo fija su entrada mas baja."""
    n, bajo = 0, 0xFFFF
    while True:
        a = tabla + n * 2
        if a >= bajo:
            break
        w = rom[a - org] | (rom[a + 1 - org] << 8)
        if not (org <= w < org + len(rom)):
            break
        bajo = min(bajo, w)
        n += 1
    return n, bajo


def figura(rom, org, p, piezas):
    """Las piezas de una figura: [(dy, dx, patron, color, bytes, fin)]."""
    q = p - org
    fuera = []
    for _ in range(piezas):
        if rom[q] == 0x80:
            q += 1
            break
        dy, dx = rom[q], rom[q + 1]
        ptr = rom[q + 2] | (rom[q + 3] << 8)
        color = rom[q + 4]
        datos, fin = descomprime_patron(rom, org, ptr)
        fuera.append((dy, dx, ptr, color, datos, fin))
        q += 5
    return fuera, org + q


def main():
    rom = open(sys.argv[1], "rb").read()
    org = int(sys.argv[2], 0)
    tabla = int(sys.argv[3], 0)
    piezas = int(sys.argv[4], 0)
    salida = None
    if "--dibuja" in sys.argv:
        salida = sys.argv[sys.argv.index("--dibuja") + 1]
        os.makedirs(salida, exist_ok=True)

    n, bajo = entradas_de_tabla(rom, org, tabla)
    print("tabla 0x%04X: %d entradas, acaba en 0x%04X (su entrada mas baja)"
          % (tabla, n, tabla + n * 2))
    if tabla + n * 2 != bajo:
        print("  OJO: la entrada mas baja es 0x%04X, no 0x%04X" % (bajo, tabla + n * 2))

    vistos, alto, patrones = {}, tabla + n * 2, {}
    for i in range(n):
        a = tabla + i * 2
        p = rom[a - org] | (rom[a + 1 - org] << 8)
        if p in vistos:
            print("  [%2d] 0x%04X  (la misma que [%d])" % (i, p, vistos[p]))
            continue
        vistos[p] = i
        piezas_, fin = figura(rom, org, p, piezas)
        alto = max(alto, fin)
        det = []
        for dy, dx, ptr, color, datos, f in piezas_:
            patrones[ptr] = f
            alto = max(alto, f)
            det.append("(%+d,%+d) 0x%04X..0x%04X %d B col %X"
                       % (dy if dy < 128 else dy - 256,
                          dx if dx < 128 else dx - 256, ptr, f - 1,
                          len(datos) if datos else -1, color))
        print("  [%2d] 0x%04X..0x%04X  %d piezas: %s"
              % (i, p, fin - 1, len(piezas_), "; ".join(det)))
    print("  las figuras llegan hasta 0x%04X" % alto)
    print("  %d bloques de patron distintos, de 0x%04X a 0x%04X"
          % (len(patrones), min(patrones) if patrones else 0,
             max(patrones.values()) - 1 if patrones else 0))


if __name__ == "__main__":
    main()
