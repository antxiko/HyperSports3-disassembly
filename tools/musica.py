#!/usr/bin/env python3
"""La musica del cartucho, ejecutando su motor de sonido (ver motor_musica.py).

Pide el sonido con `arranca_una_pista` (0x4ADD, A = numero; `suena_si_hay_partida`,
0x4AD2, solo suena en partida) y corre `reproduce_un_fotograma` (0x4BAB), que la
interrupcion llama cada cuadro. Tres voces de 14 bytes desde 0xE010; la copia
del registro 7 del PSG, en 0xE03A.
Uso:  musica.py registros 0xA6 [cuadros] | mp3 0xA6 f.mp3 | todas docs/audio
      musica.py barrido 0x80 0xBF | emu
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import motor_musica  # noqa: E402
from motor_musica import P  # noqa: E402

TABLA = "ninguna llamada directa: está en la tabla de pistas"

PIEZAS = [
    P(0x8C, "El ciclismo", "Cycling", "`escena_4_del_ciclismo`: la carrera"),
    P(0xA6, "La despedida", "The farewell",
      "`pantalla_de_resultados_7`: el rótulo de despedida"),
    P(0xA3, "El remate", "The finish",
      "`estado_del_remate` y `cierra_el_intento_de_pertiga`"),
    P(0xAC, "La pieza del 0x58D4", "The tune at 0x58D4", "`L_58D4`"),
    P(0x8E, "El intento", "The attempt",
      "`arranca_el_intento` y `curling_4_la_pista`"),
] + [P(n, "Pista 0x%02X de la tabla" % n, "Table track 0x%02X" % n, TABLA)
     for n in (0x8D, 0xA2, 0xA4, 0xA5, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xB2,
               0xB3, 0xB4)]

PAGINA = motor_musica.pagina_basica(
    "`reproduce_un_fotograma`, 0x4BAB, y `arranca_una_pista`, 0x4ADD, que "
    "reparte la pista por los canales; lo llama la interrupción",
    "`reproduce_un_fotograma`, 0x4BAB, and `arranca_una_pista`, 0x4ADD, which "
    "shares the track among the channels; the interrupt calls it",
    "C-BIOS MSX1 japonés",
    [("el ciclismo (0x8C), sus primeros 219 cuadros de 802",
      "cycling (0x8C), its first 219 frames of 802"),
     ("la despedida (0xA6) entera, 361 cuadros",
      "the farewell (0xA6), whole, 361 frames")],
    [("Cómo se pide una pieza",
      "`arranca_una_pista` recibe el número en A (`suena_si_hay_partida` "
      "hace lo mismo solo con partida, bit 6 de 0xE002) y cada pista sabe "
      "cuántos canales necesita por su número. Los números bajos son "
      "efectos y del 0x8C en adelante hay música. Cada voz ocupa catorce "
      "bytes desde 0xE010 y 0xE03A guarda la copia del mezclador del PSG, "
      "que el arranque deja en 0xB8. Las pistas «de la tabla» están en la "
      "tabla de pistas pero ninguna rutina las pide con un `ld a`; se "
      "omiten otras, casi sin notas y de minutos de duración.",
      "How a piece is asked for",
      "`arranca_una_pista` takes the number in A (`suena_si_hay_partida` "
      "does the same only in a game, bit 6 of 0xE002) and each track knows "
      "how many channels it needs from its number. Low numbers are effects "
      "and from 0x8C up there is music. Each voice takes fourteen bytes from "
      "0xE010 and 0xE03A holds the copy of the PSG mixer, which start-up "
      "leaves at 0xB8. The tracks marked «in the table» are in the track "
      "table but no routine asks for them with an `ld a`; others, nearly "
      "without notes and minutes long, are left out.")])

CFG = dict(rom="hypersports3.rom", org=0x4000, frame=0x4BAB, pide=0x4ADD,
           ram=(0xE010, 0xE03B), ram0=[(0xE03A, 0xB8)],
           excluye=[0xE019, 0xE027, 0xE035], hz=60, psg0={7: 0xB8},
           piezas=PIEZAS, pagina=PAGINA,
           cotejado=[(0x8C, 802, None), (0xA6, 362, None)])

if __name__ == "__main__":
    sys.exit(motor_musica.main(CFG, sys.argv[1:]))
