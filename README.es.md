# Hyper Sports 3 (Konami, 1985) — desensamblado comentado

*(Also available [in English](README.md).)*

**Los 32 KB del cartucho explicados, byte a byte.** El listado reensamblado
devuelve la ROM byte a byte, y todas las imágenes de la web están dibujadas
desde la propia ROM: en este repositorio no hay ni una captura de pantalla.

📖 **[La web](https://antxiko.github.io/HyperSports3-disassembly/es/)**

## Las cifras

| | |
|---|---|
| binario explicado | **100 %** — 0 bytes sin asignar de 32.768 |
| código / datos | 14.410 / 18.358 bytes |
| rutinas con nombre | **931** |
| listado comentado | **34,5 %** — 2.529 comentarios sobre 7.328 instrucciones |
| rutinas por debajo del 10 % | **0** |
| tests | 37 |

## Lo que apareció

- Los **récords del mundo viven en la RAM**, no en la ROM, porque el juego los
  sobrescribe: 1'45"34, 17,97 m, 100 puntos y 5,90 m. Los dos que se pueden
  cotejar cuadran con el año del cartucho.
- **La demostración está grabada.** Cada prueba reproduce una cinta de mandos
  guardada, menos el ciclismo, donde el rival se mueve con `ld a,r` usado como
  dado.
- **Seno de verdad**: noventa grados de él en `0x7346`, y una piedra de curling
  dirigida normalizando un vector en vez de calculando un ángulo.
- La tabla de periodos del sonido tiene **doce valores, no diez**, y los dos
  últimos están escondidos dentro de la tabla de punteros de al lado.
- **Tres trucos de desplazamiento distintos**, uno por prueba, y medio campo de
  hielo espejado a mano.
- **La marca oculta de Konami** en los últimos dieciséis bytes: el título en
  katakana, del revés, y el 0x33 del RC-733. No lo lee nadie. (La marca la
  descubrió **Manuel Pazos**.)

## Reproducirlo

    make comprueba   # el sha256 de la ROM
    make             # listado + reensamblado + comprobaciones + tests
    make imagenes    # las pantallas, dibujadas desde la ROM
    make vram        # y cotejadas byte a byte contra openMSX

El cartucho no viaja con el repositorio. Hay que ponerlo en la raíz como
`hypersports3.rom`, 32.768 bytes exactos,
`247a14766d3c64c88707ee0bfd1a0255182acab98006d2c2646085e00db29936`.

## Licencia

Las herramientas, los comentarios, el análisis y la documentación son MIT. **El
juego no es nuestro**: ver [AVISO-LEGAL.md](AVISO-LEGAL.md).
