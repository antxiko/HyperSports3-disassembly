# La música

Todo lo que suena aquí sale de ejecutar el motor de sonido del cartucho (`reproduce_un_fotograma`, 0x4BAB, y `arranca_una_pista`, 0x4ADD, que reparte la pista por los canales; lo llama la interrupción) en un Z80 emulado, cuadro a cuadro y a 60 por segundo, igual que lo llama el juego. Lo que el motor escribe en el PSG pasa a sonido con un AY-3-8910 (`tools/musica.py`). Cada MP3 es la pieza entera hasta donde vuelve a empezar, más 8 segundos de la vuelta apagándose; las que no se repiten acaban donde acaba el motor.

## Cotejado con openMSX

Las escrituras al PSG se han comparado cuadro a cuadro con las de openMSX (C-BIOS MSX1 japonés). En todos los cuadros el PSG queda igual:

- el ciclismo (0x8C), sus primeros 219 cuadros de 802;
- la despedida (0xA6) entera, 361 cuadros.

El timbre no está cotejado: es el de un AY-3-8910 de manual, no una grabación del emulador. Las sondas están en `tools/omsx_psg.tcl` y `tools/coteja_psg.py`.

## Cómo se pide una pieza

`arranca_una_pista` recibe el número en A (`suena_si_hay_partida` hace lo mismo solo con partida, bit 6 de 0xE002) y cada pista sabe cuántos canales necesita por su número. Los números bajos son efectos y del 0x8C en adelante hay música. Cada voz ocupa catorce bytes desde 0xE010 y 0xE03A guarda la copia del mezclador del PSG, que el arranque deja en 0xB8. Las pistas «de la tabla» están en la tabla de pistas pero ninguna rutina las pide con un `ld a`; se omiten otras, casi sin notas y de minutos de duración.

## Las músicas

**El ciclismo** (0x8C)

Lo pide `escena_4_del_ciclismo`: la carrera; dura 13,4 s.

<audio controls preload="none" src="../audio/musica_8C.mp3?v=bb87b339"></audio>

**La despedida** (0xA6)

Lo pide `pantalla_de_resultados_7`: el rótulo de despedida; dura 6,0 s.

<audio controls preload="none" src="../audio/musica_A6.mp3?v=3f0ed489"></audio>

**El remate** (0xA3)

Lo pide `estado_del_remate` y `cierra_el_intento_de_pertiga`; dura 2,8 s.

<audio controls preload="none" src="../audio/musica_A3.mp3?v=8c6a4aac"></audio>

**La pieza del 0x58D4** (0xAC)

Lo pide `L_58D4`; dura 6,0 s.

<audio controls preload="none" src="../audio/musica_AC.mp3?v=7d6447db"></audio>

**El intento** (0x8E)

Lo pide `arranca_el_intento` y `curling_4_la_pista`; dura 1,0 s.

<audio controls preload="none" src="../audio/musica_8E.mp3?v=6533468c"></audio>

**Pista 0x8D de la tabla** (0x8D)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 3,0 s y vuelve a empezar en el segundo 2,7.

<audio controls preload="none" src="../audio/musica_8D.mp3?v=3dcbd50d"></audio>

**Pista 0xA2 de la tabla** (0xA2)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 21,9 s.

<audio controls preload="none" src="../audio/musica_A2.mp3?v=e78624c4"></audio>

**Pista 0xA4 de la tabla** (0xA4)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,0 s.

<audio controls preload="none" src="../audio/musica_A4.mp3?v=2ea078c5"></audio>

**Pista 0xA5 de la tabla** (0xA5)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,0 s.

<audio controls preload="none" src="../audio/musica_A5.mp3?v=6e2ea69a"></audio>

**Pista 0xA7 de la tabla** (0xA7)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,0 s.

<audio controls preload="none" src="../audio/musica_A7.mp3?v=f4fecfee"></audio>

**Pista 0xA8 de la tabla** (0xA8)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,0 s.

<audio controls preload="none" src="../audio/musica_A8.mp3?v=8041c7ae"></audio>

**Pista 0xA9 de la tabla** (0xA9)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,3 s.

<audio controls preload="none" src="../audio/musica_A9.mp3?v=e1262dec"></audio>

**Pista 0xAA de la tabla** (0xAA)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,0 s.

<audio controls preload="none" src="../audio/musica_AA.mp3?v=3f54ec91"></audio>

**Pista 0xAB de la tabla** (0xAB)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,0 s.

<audio controls preload="none" src="../audio/musica_AB.mp3?v=e0373c72"></audio>

**Pista 0xB2 de la tabla** (0xB2)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,0 s.

<audio controls preload="none" src="../audio/musica_B2.mp3?v=f74b04ce"></audio>

**Pista 0xB3 de la tabla** (0xB3)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,0 s.

<audio controls preload="none" src="../audio/musica_B3.mp3?v=091bb64f"></audio>

**Pista 0xB4 de la tabla** (0xB4)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,0 s.

<audio controls preload="none" src="../audio/musica_B4.mp3?v=1906a871"></audio>
