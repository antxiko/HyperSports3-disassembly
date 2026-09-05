# In the emulator

The pictures on this site are **drawn from the ROM**, not captured. What the
emulator does here is something else: **decide whether those drawings are the
real thing**.

## Checking against VRAM

    make vram

launches openMSX with the cartridge and `tools/omsx_vram.tcl`, which at several
instants dumps **the whole 16 KB of VRAM**, the eight VDP registers and the 2
KB of work RAM. Then:

    python3 tools/coteja_vram.py hypersports3.rom 0x4000 work/omsx

compares byte for byte what Python builds against what the VDP actually holds,
and it does it per table, because they do not all mean the same thing:

| table | address | what it is |
|---|---|---|
| colour | `0x0000`–`0x17FF` | the eight colour bytes of each tile |
| sprite patterns | `0x1800`–`0x1FFF` | the sprite drawings |
| patterns | `0x2000`–`0x37FF` | the tile drawings |
| names | `0x3800`–`0x3AFF` | which tile goes in each cell |

The first three are **static**: built once and untouched until the screen
changes, so they have to come out at zero. The name table does move —the
athlete, the scoreboards, the labels that blink— and there what you look at is
how many cells wobble and whether they are the ones that should.

## Where it stands

| screen | colour | spr. patterns | patterns | names |
|---|---|---|---|---|
| title | 0 | 0 | 0 | 14 |
| cycling | **0** | **0** | **0** | **0** |
| triple jump | 0 | 77 | 0 | 0 |
| curling | 0 | 0 | 0 | 34 |
| pole vault | 0 | 0 | 0 | 0 |

**Cycling closes at zero across all four tables and on the 128 sprite attribute
bytes as well**: 15,104 bytes of VRAM identical to the emulator's.

The 14 on the title are the blinking cursor and the 34 on curling are the TEMP
readout and the scoreboard, both written after the screen is built. The 77 on
the triple jump and the pole vault's sprite patterns are **the athlete's
pose**: the build-time dump does not have him drawn yet, and the frame that
does has the runway already scrolled. Against that frame the pole vault comes
out at **zero of 2,048 pattern bytes** with all six sprites identical.

## No need to play it

The demo walks through all four events on its own, but you have to wait. There
is a faster trick: scene 4 is `call limpia_la_pantalla / call monta_la_prueba`,
and `monta_la_prueba` reads the event from `(0xE06A)` at `0x53CB`. A breakpoint
between the two that writes the event number there leaves the cartridge
building **and playing** that event. It is not a frozen screen.

    echo 2 > work/prueba.txt      # 0 cycling, 1 triple jump, 2 curling, 3 pole vault
    make vram

And it comes out better than playing: this way the event inherits the title
screen's VRAM, which is exactly what it inherits on the real machine. Between
screens the cartridge **does not clear the patterns or the colour** —it only
hides the sprites and clears the name table—, so what was underneath is still
there. Building an event from scratch introduces hundreds of differing bytes
that are not a misreading but the missing inheritance.

## And tracing the drawing calls

    "openmsx" -machine Philips_VG_8020 -cart hypersports3.rom -script tools/omsx_montaje.tcl

puts a breakpoint on **every** drawing routine in the cartridge and logs, in
order and with their arguments, every call that falls inside the build window.
Replaying that list in Python over the dumped inheritance gives a screen
identical to the emulator's. It is what separates "a block is missing" from
"the format is being read wrong" without eyeballing a single byte.
