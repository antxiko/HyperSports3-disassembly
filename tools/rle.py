#!/usr/bin/env python3
"""El descompresor del cartucho, rehecho en Python para MEDIR y DIBUJAR.

La rutina es L_4442, y escribe DIRECTAMENTE en la VRAM: no deja el resultado
en memoria, lo saca por el puerto de datos del VDP. Traducida instruccion a
instruccion, con DE apuntando al flujo y HL a la direccion de VRAM:

    L_4442  ex de,hl / ld e,(hl) / inc hl / ld d,(hl) / ex de,hl / inc de
                               HL = la palabra leida del propio bloque, o sea
                               su destino de VRAM; DE = el flujo, ya pasada
    L_4448  call L_43D1        SETWRT con HL, y C' se queda con el puerto de
                               datos del VDP, que sale de (0x0006)
    L_444B  ld a,(de)
            and a / ret z      un 0x00 TERMINA el bloque
            inc de
            ld b,a             B se queda con el byte ENTERO
            and 07fh / cp b    si coinciden, el bit 7 estaba a cero
            jr z,L_4463        bit 7 = 0 -> repeticion
            and a / jr z,L_4442    el byte 0x80 -> vuelve a la cabecera, o sea
                               otro destino de VRAM y a seguir
            ld b,a
    L_4459  ld a,(de) / inc de / exx / out (c),a / exx / djnz   literal de B
            jr L_444B
    L_4463  ld a,(de) / inc de
    L_4465  exx / out (c),a / exx / djnz                        el byte, B veces
            jr L_444B

O sea, un mandato por byte:

    0x00           cierra el bloque
    0x01..0x7F     el byte que sigue, repetido esa cuenta
    0x80           los dos bytes que siguen son una direccion de VRAM NUEVA,
                   y a partir de ahi se escribe alli
    0x81..0xFF     copia tal cual los (mandato & 0x7F) bytes que siguen

Es, byte por byte, el MISMO formato que el de Konami's Ping Pong, Soccer y
Road Fighter. Lo que Road Fighter anadia -el espejo horizontal de cada byte,
para dibujar las dos mitades de una figura simetrica con un solo bloque- aqui
NO existe: los bytes de dato se leen con `ld a,(de)` a pelo y salen al VDP tal
cual, sin pasar por ninguna rutina que les de la vuelta.

Las direcciones van con los BITS DE ARRIBA puestos: el cartucho pide 0x6200
donde la VRAM tiene 0x2200, y 0x7818 donde tiene 0x3818. No es un error suyo
-SETWRT (0x0053) hace `and 03fh` sobre H antes de nada, asi que los dos bits
de arriba se tiran-, de modo que aqui hay que enmascarar igual con 0x3FFF o
los bloques caen fuera.

Ejecutarlo es la unica forma honesta de saber donde acaba cada bloque: el
tamano no esta escrito en ninguna parte, lo marca el propio 0x00 final.

Hay DOS puertas. Por L_4448 la direccion de VRAM llega en HL, puesta por quien
llama. Por L_4442 la direccion va DENTRO del bloque, en sus dos primeros
bytes. Aqui, `auto` para esa.

Uso: rle.py <rom> <org> <dir vram|auto> <dir dato> [<dir dato> ...]
     rle.py <rom> <org> --tramos <dir vram|auto> <dir dato>
"""
import sys

VRAM = 0x4000       # tamano de la VRAM de un MSX1


def descomprime(rom, org, inicio, vram_ini):
    """Ejecuta el bloque. Devuelve (fin, vram, tocado, tramos) o None.

    `vram` es una imagen de 16 KB con lo escrito, `tocado` marca que bytes se
    escribieron y `tramos` la lista de (direccion de vram, cuantos bytes) en
    el orden en que se escribieron.

    Con vram_ini a None se entra por L_4442: los dos primeros bytes del bloque
    son la direccion de destino.
    """
    p = inicio - org
    if p < 0 or p >= len(rom):
        return None
    if vram_ini is None:                      # puerta L_4442
        if p + 1 >= len(rom):
            return None
        vram_ini = rom[p] | (rom[p + 1] << 8)
        p += 2
    vram = bytearray(VRAM)
    tocado = bytearray(VRAM)
    tramos = []
    dst = vram_ini & 0x3FFF
    ini_tramo = dst
    escritos = 0

    def cierra_tramo():
        if escritos:
            tramos.append((ini_tramo, escritos))

    while True:
        if p >= len(rom):
            return None                       # se sale: no era un bloque
        ctrl = rom[p]
        p += 1
        if ctrl == 0x00:
            cierra_tramo()
            return org + p, vram, tocado, tramos
        if ctrl == 0x80:
            if p + 1 >= len(rom):
                return None
            cierra_tramo()
            dst = (rom[p] | (rom[p + 1] << 8)) & 0x3FFF
            p += 2
            ini_tramo, escritos = dst, 0
            continue
        if ctrl & 0x80:                       # literal
            n = ctrl & 0x7F
            if p + n > len(rom):
                return None
            for i in range(n):
                vram[dst & 0x3FFF] = rom[p + i]
                tocado[dst & 0x3FFF] = 1
                dst += 1
            p += n
            escritos += n
        else:                                 # repeticion
            if p >= len(rom):
                return None
            v = rom[p]
            p += 1
            for _ in range(ctrl):
                vram[dst & 0x3FFF] = v
                tocado[dst & 0x3FFF] = 1
                dst += 1
            escritos += ctrl


def main():
    rom = open(sys.argv[1], 'rb').read()
    org = int(sys.argv[2], 0)
    args = sys.argv[3:]
    detalle = False
    if args and args[0] == '--tramos':
        detalle = True
        args = args[1:]
    vram_ini = None if args[0] == 'auto' else int(args[0], 0)
    for a in args[1:]:
        d = int(a, 0)
        r = descomprime(rom, org, d, vram_ini)
        if r is None:
            print('0x%04X  NO cierra dentro de la ROM' % d)
            continue
        fin, vram, tocado, tramos = r
        n = sum(tocado)
        print('0x%04X..0x%04X  %5d bytes comprimidos -> %5d de VRAM, %d tramos'
              % (d, fin - 1, fin - d, n, len(tramos)))
        if detalle:
            for v, c in tramos:
                print('      vram 0x%04X  %5d bytes' % (v, c))


if __name__ == '__main__':
    main()
