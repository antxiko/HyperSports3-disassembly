#!/usr/bin/env python3
"""Recorre las pistas de sonido y anota que semitonos usan de verdad.

Responde a una pregunta abierta del desensamblado: la tabla de periodos de
0x4DA2 tiene DIEZ valores, pero el reproductor la indexa con el nibble alto
del byte de nota, que llega hasta 0x0F. Con un 0x0A o un 0x0B leeria 0x4DAC y
0x4DAD, o sea los dos primeros bytes de la tabla de pistas; con un 0x0C el
volumen se pone a cero -es el silencio- y ya no se oye, pero la lectura se hace
igual.

Asi que la pregunta no es si el codigo puede salirse: es si alguna pista de las
que el cartucho arranca lo hace. Esto lo mide EJECUTANDO el formato: se parte
de los numeros de pista que el codigo pasa a arranca_una_pista, se reparte cada
uno en sus canales igual que L_4AEB, y se recorre cada canal mandato a mandato.

Uso: recorre_pistas.py <rom> [org]
"""
import sys

ORG_DEF = 0x4000
TABLA = 0x4DAC          # los 56 punteros
PERIODOS = 0x4DA2       # los diez semitonos

# Los numeros de sonido que el codigo pasa a arranca_una_pista con una
# constante. El bit 7 elige el formato: con el puesto, la pista lleva los
# mandatos largos de L_4D13; sin el, los cortos de L_4C46.
SONIDOS = (0x01, 0x04, 0x06, 0x07, 0x10, 0x16, 0x1A, 0x1E, 0x42, 0x43,
           0x48, 0x49, 0x4A, 0x4B, 0x58, 0x60, 0x6F, 0x8E, 0xA3, 0xA6,
           0xAC, 0xB2, 0xB5)


def canales(n):
    """Cuantos canales ocupa la pista n y por cual empieza, como L_4AEB."""
    p = n & 0x3F
    if p == 1:
        return 1, 0            # el barrido: no lee mandatos de ninguna parte
    if p >= 0x0C:
        b = 3 if p >= 0x20 else 2
        primero = 1 if p == 0x0C else 0
    else:
        b = 1
        primero = 1 if p < 4 else 0
    return b, primero


def recorre(rom, org, dire, vistos, hondo=0):
    """Un canal de pista LARGA, mandato a mandato.

    Solo las largas: en las cortas el periodo va LITERAL en la pista -doce
    bits repartidos entre el nibble bajo del byte de nota y el siguiente- y no
    pasa por la tabla, asi que no dicen nada de la pregunta.
    """
    if hondo > 4:
        return
    p = dire - org
    vueltas = {}
    pasos = 0
    while 0 <= p < len(rom) and pasos < 4000:
        pasos += 1
        b = rom[p]
        if b == 0xFF:                       # fin de pista
            return
        if b == 0xFE:                       # bucle: cuenta y destino
            cuenta = rom[p + 1]
            destino = rom[p + 2] | (rom[p + 3] << 8)
            visto = vueltas.get(p, 0)
            vueltas[p] = visto + 1
            if visto < 1 and org <= destino < org + len(rom):
                p = destino - org           # se sigue la vuelta una sola vez
                continue
            p += 4
            continue
        if b & 0xF0 == 0xD0:                # unidad de duracion
            p += 1
            continue
        if b >= 0xF0:                       # volumen y los dos del decaimiento
            p += 3
            continue
        if b >= 0xE0:                       # octava o desafine
            p += 1
            continue
        vistos.add(b >> 4)                  # el byte de nota: semitono y duracion
        p += 1
    return


def main(argv):
    if len(argv) < 2:
        return print(__doc__) or 2
    with open(argv[1], "rb") as f:
        rom = f.read()
    org = int(argv[2], 0) if len(argv) > 2 else ORG_DEF

    vistos = set()
    por_pista = {}
    for n in SONIDOS:
        if not n & 0x80:        # las cortas no usan la tabla de periodos
            continue
        b, primero = canales(n)
        if (n & 0x3F) == 1:
            continue
        propios = set()
        for k in range(b):
            i = (n & 0x3F) + k
            if i * 2 + 1 >= 0x70 * 2:
                continue
            d = TABLA + i * 2 - org
            dire = rom[d] | (rom[d + 1] << 8)
            if not (org <= dire < org + len(rom)):
                continue
            recorre(rom, org, dire, propios)
        por_pista[n] = propios
        vistos |= propios

    print("Semitonos de las pistas LARGAS, que son las que leen la tabla")
    print("=" * 56)
    for n in sorted(por_pista):
        s = "".join("%X" % x for x in sorted(por_pista[n])) or "-"
        print("  sonido 0x%02X  (%d canales)  nibbles: %s" % (n, len(
            [k for k in range(canales(n)[0])]), s))
    print("-" * 56)
    print("  en total: %s" % " ".join("0x%X" % x for x in sorted(vistos)))

    tabla = list(rom[PERIODOS - org:PERIODOS - org + 10])
    print("  la tabla de periodos tiene %d valores: %s"
          % (len(tabla), " ".join("%02X" % x for x in tabla)))
    fuera = sorted(x for x in vistos if x >= 10 and x != 0x0C)
    if fuera:
        print("  SE SALEN de la tabla: %s" % fuera)
    else:
        print("  NINGUN nibble se sale de la tabla (el 0x0C es el silencio)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
