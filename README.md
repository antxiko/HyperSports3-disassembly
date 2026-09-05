# Hyper Sports 3 (Konami, 1985) — a commented disassembly

*(También [en castellano](README.es.md).)*

**The whole 32 KB cartridge explained, byte by byte.** Reassembling the listing
gives back the ROM byte for byte, and every picture on the site is drawn from
the ROM itself — there is not one screen capture in this repository.

📖 **[The site](https://antxiko.github.io/HyperSports3-disassembly/)**

## The numbers

| | |
|---|---|
| binary explained | **100 %** — 0 bytes unassigned of 32,768 |
| code / data | 14,410 / 18,358 bytes |
| named routines | **931** |
| listing commented | **34.5 %** — 2,528 comments over 7,328 instructions |
| routines below 10 % | **0** |
| tests | 37 |

## What turned up

- The **world records live in RAM**, not ROM, because the game overwrites them:
  1'45"34, 17.97 m, 100 points and 5.90 m. The two that can be checked match
  the cartridge's own year.
- **The demo is a recording.** Every event replays a stored tape of controller
  readings — except cycling, where the rival moves off `ld a,r` used as a die.
- **Real sine**: ninety degrees of it at `0x7346`, and a curling stone steered
  by normalising a vector rather than computing an angle.
- The sound **period table has twelve values, not ten**, and the last two hide
  inside the pointer table next door.
- **Three different scrolling tricks**, one per event, and half a sheet of ice
  mirrored by hand.
- **Konami's hidden mark** in the last sixteen bytes: the title in katakana,
  backwards, plus the 0x33 of RC-733. Nothing reads it. (The mark was
  discovered by **Manuel Pazos**.)

## Reproducing it

    make comprueba   # the ROM's sha256
    make             # listing + reassembly + sanity checks + tests
    make imagenes    # the screens, drawn from the ROM
    make vram        # and checked byte for byte against openMSX

The cartridge does not travel with the repository. Put it in the root as
`hypersports3.rom`, exactly 32,768 bytes,
`247a14766d3c64c88707ee0bfd1a0255182acab98006d2c2646085e00db29936`.

## Licence

The tools, comments, analysis and documentation are MIT. **The game is not
ours**: see [LEGAL-NOTICE.md](LEGAL-NOTICE.md).
