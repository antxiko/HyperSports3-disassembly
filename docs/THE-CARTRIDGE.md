# The cartridge

**Hyper Sports 3**, Konami, 1985. Catalogue number **RC-733**. 32 KB of ROM in
an MSX1 cartridge, no mapper, no SCC and no RAM of its own.

## The map

    0x4000 .. 0xBFFF   the cartridge's 32 KB, pages 1 and 2
    0xE000 .. 0xE7FF   the 2 KB of work RAM, and it uses no more

The header is the sixteen bytes at `0x4000`: the `AB` signature, the INIT
address (`0x405A`) and everything else at zero —STATEMENT, DEVICE, TEXT and the
six reserved bytes—.

## The eight VDP registers

The loop at `0x4488` writes them in order, 0 to 7, taking each value from a
table. For the game they are:

    02 E2 0E 7F 07 76 03 E4

    R2 = 0x0E -> name table       0x3800
    R3 = 0x7F -> colour           base 0x0000, mask 0x3FF
    R4 = 0x07 -> patterns         base 0x2000
    R5 = 0x76 -> sprite attrs     0x3B00
    R6 = 0x03 -> sprite patterns  0x1800

**In SCREEN 2 R3 and R4 are not an address**, they are a base and a mask. With
these values the screen is split into the usual three thirds, each with its own
256 patterns and 256 rows of colour. Which is why the cartridge has a routine
(`L_4405`) that decompresses the same block into all three at once, skipping
0x0800 each time.

## What INIT copies to RAM

Of the 2 KB of work RAM, **twelve bytes** are the only ones that do not start
at zero. INIT copies them from `0x40CF` to `0xE053`, and they are **the world
records** for the four events, in BCD. They sit in RAM rather than ROM because
the game overwrites them as soon as they are beaten.

## The scene dispatch

The whole game is one counter and eleven tables, and all eleven sit glued right
behind their `call L_4050`:

    pop hl / add a,a / call L_4046 / ld e,(hl) / inc hl / ld d,(hl)
    ex de,hl / jp (hl)

The `pop hl` recovers its own return address, which is the start of the table.
It is the dispatcher shared across this family of Konami cartridges.

The entry count of each table is not estimated: it is fixed by the constraint
that no entry can point inside the table itself. All eleven are in
`src/hypersports3.entries` with their arithmetic down to the byte. The longest
is the one at `0xA934`, with thirteen entries; the topmost is `0x4109`, with
nine, which dispatches the logo, the title, the events and the ending.

## Sound

The whole player lives between `0x4AD2` and `0x4DA2`, with its data right
behind. The door is `L_4ADD`: you pass it the sound number in A. The track
table **ends exactly at its own lowest entry**, `0x4E1C`, which is what fixes
its length without having to guess.

The period table has **twelve values, not ten**, and the last two are hidden
inside the pointer table that follows. All twelve land within one unit of the
exact semitone: it is a chromatic octave.

## Konami's hidden mark

The last sixteen bytes —`0xBFF0` to `0xBFFF`— carry the game's title in
**katakana, backwards**: ハイパースポーツ3, its length (0x0D), the **0x33** of
RC-733 and an 0xAA to close. **Nothing reads it**: not one instruction in the
cartridge points there.

The mark was discovered by **Manuel Pazos**, and it is in many of Konami's
cartridges from these years.

## Credits

There are none. No initials, no names, no build dates anywhere in the 32 KB.
The only thing that signs is the hidden mark, and it signs for the company, not
for the people.
