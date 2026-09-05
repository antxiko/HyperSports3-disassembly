# The code

**14,410 bytes of code and 18,358 of data**, adding up to the cartridge's
32,768. Not one unassigned. **931 named routines** and **34.5 %** of the
listing commented, with **zero routines below 10 %**.

That there is more data than code says a fair amount: this is a cartridge of
compressed graphics with a small engine on top.

## The scene machine

The whole game is a counter and eleven tables. `(0xE003)` picks the big scene
—logo, title, event, ending— and each event keeps its own sub-scene in its own
variable: the jumps in `0xE09E`, cycling in `0xE120` and curling in `0xE230`.

`(0xE06A)` holds **the event** in its bottom two bits and **the lap** in the
top ones, that is how many times the four have been played through. With that
the cartridge raises the difficulty without keeping a table per event: `L_5443`
pulls out the lap, clamps it to seven and indexes whatever table it is handed.

## Four decompressors, not one

The RLE format is always the same —one command byte, bit 7 tells copy from
repeat, 0 closes— but the cartridge has four different doors depending on where
the output goes:

- `L_4442` / `L_4448`, to VRAM, with the destination in the block header or
  given separately
- `L_4405`, **the same block into all three thirds** of the screen, skipping
  0x0800 each time
- `L_74B1` / `L_74B5`, to **RAM**: cycling, the jumps and curling all work the
  drawing in RAM before sending it up
- `L_69AF`, the one built into the figure engine, which writes straight out
  through the data port with no destination header

## Two label interpreters

`L_4415` is the usual one: `0xFE` changes destination with a full address,
`0xFF` closes. `L_676E` is the other, and it takes its jumps as **a single
byte** relative to where it is. With it a drawing several rows tall fits in
very few bytes; the pole the athlete carries is twelve tiles in a fifteen-byte
block.

## The figure engine

`L_6992`. An athlete is not a sprite: he is two to seven 16x16 sprites, and
each piece is **five bytes** —relative row and column, pointer to the pattern
block, and colour— closed by an `0x80`.

The interesting part is that the pattern is **not sitting there beforehand**:
the block is decompressed into VRAM right then, on the spot, and the sprites
pick it up in order. The 2 KB of sprite patterns are rebuilt in full on every
frame, and that is how the cartridge can hold hundreds of poses.

The figures come out of five tables, and **each one ends exactly at its own
lowest entry**: that is what fixes how many figures each holds without guessing
it. The 127 pattern blocks they all point at run consecutively.

And the engine has two doors: `L_65FC`, which takes one figure from one table,
and `L_64E3`, which composes the figure from **two consecutive blocks** sharing
the pattern counter. The second one is what draws the athlete with the pole in
his hand.

## The table of ninety

`0x7346` is **ninety degrees of sine**, one byte per degree. That it is ninety
and not something else is what its two readers say: the second enters with
`0x5A`, which is 90, and `0x7346 + 90 = 0x73A0`, exactly where it ends.

## Clipped rectangles

`L_AF7C` draws a rectangle into the name table taking the screen's **scroll**
into account, which it reads from `(0xE20D)` divided by eight. With the curling
sheet at its starting position, the house falls to the right of the edge and
the `cp 020h / ret nc` does not paint a single tile: that is why the opening
screen is plain ice.

## Ten bytes that are not data

Between the figures and the relative scripts there are ten bytes no instruction
in the cartridge ever calls, and that **are not data**: they are a routine. It
divides HL by 32 without losing anything off the top, taking into A the three
bits that fall off. Which is exactly what the curling stone's address
arithmetic does by hand a few lines below. It is there, complete, and nobody
uses it.
