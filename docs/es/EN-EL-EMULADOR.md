# En el emulador

Las imágenes de esta web están **dibujadas desde la ROM**, no capturadas. Lo
que hace el emulador aquí es otra cosa: **decidir si esos dibujos son los de
verdad**.

## El cotejo contra la VRAM

    make vram

Lanza openMSX con el cartucho y `tools/omsx_vram.tcl`, que en varios instantes
vuelca **los 16 KB de VRAM enteros**, los ocho registros del VDP y los 2 KB de
RAM de trabajo. Después:

    python3 tools/coteja_vram.py hypersports3.rom 0x4000 work/omsx

compara byte a byte lo que monta Python con lo que el VDP tiene de verdad, y lo
hace por tablas, porque no todas dicen lo mismo:

| tabla | dirección | qué es |
|---|---|---|
| color | `0x0000`–`0x17FF` | los ocho bytes de color de cada *tile* |
| patrones de sprite | `0x1800`–`0x1FFF` | los dibujos de los sprites |
| patrones | `0x2000`–`0x37FF` | los dibujos de los *tiles* |
| nombres | `0x3800`–`0x3AFF` | qué *tile* va en cada casilla |

Las tres primeras son **estáticas**: se montan una vez y no se tocan hasta que
cambia la pantalla, así que tienen que salir a cero. La tabla de nombres sí se
mueve —el atleta, los marcadores, los rótulos que parpadean—, y ahí lo que se
mira es cuántas casillas bailan y si son las que deben.

## Cómo está

| pantalla | color | patr. sprite | patrones | nombres |
|---|---|---|---|---|
| título | 0 | 0 | 0 | 14 |
| ciclismo | **0** | **0** | **0** | **0** |
| triple salto | 0 | 77 | 0 | 0 |
| curling | 0 | 0 | 0 | 34 |
| pértiga | 0 | 0 | 0 | 0 |

El **ciclismo cierra a cero en las cuatro tablas y además en los 128 bytes de
atributos de sprite**: 15.104 bytes de VRAM idénticos a los del emulador.

Los 14 del título son el cursor parpadeando y los 34 del curling son el TEMP y
el marcador, que se escriben después del montaje. Los 77 del triple salto y los
patrones de sprite de la pértiga son **la postura del atleta**: el volcado del
montaje todavía no lo tiene dibujado, y el fotograma en que sí lo dibuja tiene
la pista ya desplazada. Contra ese fotograma, la pértiga sale a **cero de 2.048
bytes de patrón** y con los seis sprites idénticos.

## No hace falta jugar

La demostración pasa sola por las cuatro pruebas, pero hay que esperar. El
truco es más rápido: la escena 4 es `call limpia_la_pantalla / call
monta_la_prueba`, y `monta_la_prueba` lee la prueba de `(0xE06A)` en `0x53CB`.
Un punto de ruptura entre las dos que escriba ahí el número de prueba deja al
cartucho montando y **jugando** esa prueba. No es una pantalla congelada.

    echo 2 > work/prueba.txt      # 0 ciclismo, 1 triple salto, 2 curling, 3 pértiga
    make vram

Y sale mejor que jugando: así la prueba hereda la VRAM del título, que es
exactamente lo que hereda en la máquina de verdad. Entre pantalla y pantalla el
cartucho **no borra los patrones ni el color** —solo esconde los sprites y
borra la tabla de nombres—, así que lo de debajo sigue ahí. Montar una prueba
desde cero mete cientos de bytes de diferencia que no son un error de lectura
sino la herencia que falta.

## Y el trazado de las llamadas de dibujo

    "openmsx" -machine Philips_VG_8020 -cart hypersports3.rom -script tools/omsx_montaje.tcl

Pone un punto de ruptura en **cada** rutina de dibujo del cartucho y apunta, en
orden y con sus argumentos, todas las llamadas que caen dentro de la ventana
del montaje. Ejecutando esa lista en Python sobre la herencia volcada, la
pantalla sale idéntica al emulador. Es lo que separa «falta un bloque» de «el
formato está mal leído» sin mirar un solo byte a ojo.
