# Empezar

El repositorio trae el listado ya generado, pero lo que de verdad importa es
que se puede **rehacer entero desde el cartucho** y que el resultado vuelve a
ser la ROM byte a byte. Eso es lo que hace que las notas se puedan creer.

## Lo que hace falta

- **Python 3** (nada más: ni una dependencia)
- **pasmo**, el ensamblador de Z80, para la prueba del reensamblado
- **make**
- Para las comprobaciones contra la máquina, **openMSX**

## El cartucho

No viaja con el repositorio. Hay que ponerlo en la raíz como
`hypersports3.rom`, 32.768 bytes exactos:

    247a14766d3c64c88707ee0bfd1a0255182acab98006d2c2646085e00db29936

Para comprobar que es el mismo:

    make comprueba

## Rehacerlo todo

    make

Eso encadena las cuatro cosas que importan:

1. **`make listado`** traza el flujo desde los puntos de entrada declarados y
   escribe `src/hypersports3.asm`.
2. **`make verify`** lo reensambla con pasmo y compara el binario con la ROM.
   Si no salen 32.768 bytes idénticos, falla.
3. **`make sanity`** comprueba lo que el reensamblado no puede ver: que ningún
   byte declarado como datos se esté leyendo como código, que ningún punto de
   entrada caiga dentro de una zona de datos, y que **no quede un solo byte
   sin asignar**.
4. **`make test`** pasa los 33 tests del listado y de la web.

## Las cifras

    make densidad

Da las dos que se usan en toda la serie: cuántas rutinas quedan por debajo del
10 % de instrucciones comentadas, y la densidad global. Aquí son **0 de 931** y
**34,5 %**.

## Las imágenes

    make imagenes

Dibuja las pantallas desde los bytes de la ROM, ejecutando en Python el mismo
descompresor, el mismo motor de figuras y el mismo intérprete de rótulos que
corre el Z80. **No hay ni una captura de pantalla en el repositorio.**

Y para comprobar que esos dibujos son los de verdad:

    make vram

Deja correr el cartucho en openMSX, vuelca los 16 KB de VRAM en varios
instantes y `tools/coteja_vram.py` los compara **byte a byte** con lo que monta
Python. Mirar la imagen no basta; eso ya costó cuatro errores que habían pasado
el filtro del ojo.
