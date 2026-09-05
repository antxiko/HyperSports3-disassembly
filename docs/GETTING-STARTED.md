# Getting started

The repository ships the listing already generated, but what really matters is
that it can be **rebuilt from the cartridge** and that the result is the ROM
byte for byte. That is what makes the notes worth believing.

## What you need

- **Python 3** (that is all: not one dependency)
- **pasmo**, the Z80 assembler, for the reassembly check
- **make**
- For the checks against the real machine, **openMSX**

## The cartridge

It does not travel with the repository. Put it in the root as
`hypersports3.rom`, exactly 32,768 bytes:

    247a14766d3c64c88707ee0bfd1a0255182acab98006d2c2646085e00db29936

To check it is the same one:

    make comprueba

## Rebuilding everything

    make

That chains the four things that matter:

1. **`make listado`** traces the flow from the declared entry points and writes
   `src/hypersports3.asm`.
2. **`make verify`** reassembles it with pasmo and compares the binary against
   the ROM. If it is not 32,768 identical bytes, it fails.
3. **`make sanity`** checks what reassembly cannot see: that no byte declared
   as data is being read as code, that no entry point falls inside a data
   region, and that **not one byte is left unassigned**.
4. **`make test`** runs the 33 tests over the listing and the site.

## The numbers

    make densidad

Gives the two used across the series: how many routines are below 10 % of
commented instructions, and the overall density. Here they are **0 out of 931**
and **34.5 %**.

## The pictures

    make imagenes

Draws the screens from the bytes of the ROM, running in Python the same
decompressor, the same figure engine and the same label interpreter the Z80
runs. **There is not one screen capture in this repository.**

And to check those drawings are the real thing:

    make vram

runs the cartridge in openMSX, dumps the 16 KB of VRAM at several instants, and
`tools/coteja_vram.py` compares them **byte for byte** against what Python
builds. Looking at the picture is not enough; that already cost four errors
that had passed the eye test.
