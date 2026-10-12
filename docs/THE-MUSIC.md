# The music

Everything you hear here comes from running the cartridge's own sound engine (`reproduce_un_fotograma`, 0x4BAB, and `arranca_una_pista`, 0x4ADD, which shares the track among the channels; the interrupt calls it) on an emulated Z80, frame by frame at 60 per second, just as the game calls it. What the engine writes to the PSG is turned into sound with an AY-3-8910 (`tools/musica.py`). Each MP3 is the whole piece up to where it starts again, plus 8 seconds of the repeat fading out; those that do not repeat end where the engine ends.

## Checked against openMSX

The PSG writes have been compared frame by frame with those of openMSX (C-BIOS MSX1 japonés). In every frame the PSG ends up the same:

- cycling (0x8C), its first 219 frames of 802;
- the farewell (0xA6), whole, 361 frames.

The timbre is not checked: it is a textbook AY-3-8910, not a recording of the emulator. The probes are `tools/omsx_psg.tcl` and `tools/coteja_psg.py`.

## How a piece is asked for

`arranca_una_pista` takes the number in A (`suena_si_hay_partida` does the same only in a game, bit 6 of 0xE002) and each track knows how many channels it needs from its number. Low numbers are effects and from 0x8C up there is music. Each voice takes fourteen bytes from 0xE010 and 0xE03A holds the copy of the PSG mixer, which start-up leaves at 0xB8. The tracks marked «in the table» are in the track table but no routine asks for them with an `ld a`; others, nearly without notes and minutes long, are left out.

## The tunes

**Cycling** (0x8C)

Asked for by `escena_4_del_ciclismo`: la carrera; lasts 13.4 s.

<audio controls preload="none" src="audio/musica_8C.mp3?v=bb87b339"></audio>

**The farewell** (0xA6)

Asked for by `pantalla_de_resultados_7`: el rótulo de despedida; lasts 6.0 s.

<audio controls preload="none" src="audio/musica_A6.mp3?v=3f0ed489"></audio>

**The finish** (0xA3)

Asked for by `estado_del_remate` y `cierra_el_intento_de_pertiga`; lasts 2.8 s.

<audio controls preload="none" src="audio/musica_A3.mp3?v=8c6a4aac"></audio>

**The tune at 0x58D4** (0xAC)

Asked for by `L_58D4`; lasts 6.0 s.

<audio controls preload="none" src="audio/musica_AC.mp3?v=7d6447db"></audio>

**The attempt** (0x8E)

Asked for by `arranca_el_intento` y `curling_4_la_pista`; lasts 1.0 s.

<audio controls preload="none" src="audio/musica_8E.mp3?v=6533468c"></audio>

**Table track 0x8D** (0x8D)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 3.0 s and starts again at second 2.7.

<audio controls preload="none" src="audio/musica_8D.mp3?v=3dcbd50d"></audio>

**Table track 0xA2** (0xA2)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 21.9 s.

<audio controls preload="none" src="audio/musica_A2.mp3?v=e78624c4"></audio>

**Table track 0xA4** (0xA4)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.0 s.

<audio controls preload="none" src="audio/musica_A4.mp3?v=2ea078c5"></audio>

**Table track 0xA5** (0xA5)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.0 s.

<audio controls preload="none" src="audio/musica_A5.mp3?v=6e2ea69a"></audio>

**Table track 0xA7** (0xA7)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.0 s.

<audio controls preload="none" src="audio/musica_A7.mp3?v=f4fecfee"></audio>

**Table track 0xA8** (0xA8)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.0 s.

<audio controls preload="none" src="audio/musica_A8.mp3?v=8041c7ae"></audio>

**Table track 0xA9** (0xA9)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.3 s.

<audio controls preload="none" src="audio/musica_A9.mp3?v=e1262dec"></audio>

**Table track 0xAA** (0xAA)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.0 s.

<audio controls preload="none" src="audio/musica_AA.mp3?v=3f54ec91"></audio>

**Table track 0xAB** (0xAB)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.0 s.

<audio controls preload="none" src="audio/musica_AB.mp3?v=e0373c72"></audio>

**Table track 0xB2** (0xB2)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.0 s.

<audio controls preload="none" src="audio/musica_B2.mp3?v=f74b04ce"></audio>

**Table track 0xB3** (0xB3)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.0 s.

<audio controls preload="none" src="audio/musica_B3.mp3?v=091bb64f"></audio>

**Table track 0xB4** (0xB4)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.0 s.

<audio controls preload="none" src="audio/musica_B4.mp3?v=1906a871"></audio>
