# El código

**14.410 bytes de código y 18.358 de datos**, que suman los 32.768 del
cartucho. Ni uno sin asignar. **931 rutinas con nombre** y **34,5 %** del
listado comentado, con **cero rutinas por debajo del 10 %**.

Que haya más datos que código dice bastante: esto es un cartucho de gráficos
comprimidos con un motor pequeño encima.

## La máquina de escenas

El juego entero es un contador y once tablas. `(0xE003)` reparte la escena
grande —logotipo, título, prueba, final— y cada prueba lleva su propia
subescena en su propia variable: el salto en `0xE09E`, el ciclismo en `0xE120`
y el curling en `0xE230`.

`(0xE06A)` lleva en los dos bits de abajo **la prueba** y en los de arriba **la
vuelta**, o sea cuántas veces se han dado ya las cuatro. Con eso el cartucho
sube la exigencia sin tener una tabla por prueba: `L_5443` saca la vuelta, la
recorta a siete y con ella indexa la tabla que le pasen.

## Cuatro descompresores, no uno

El formato RLE es siempre el mismo —un byte de mandato, el bit 7 distingue
copiar de repetir, el 0 cierra— pero el cartucho tiene cuatro puertas distintas
según a dónde vaya:

- `L_4442` / `L_4448`, a la VRAM, con el destino en la cabecera del bloque o
  dado aparte
- `L_4405`, **el mismo bloque en los tres tercios** de la pantalla, saltando
  0x0800 cada vez
- `L_74B1` / `L_74B5`, a la **RAM**: el ciclismo, el salto y el curling
  trabajan el dibujo en RAM antes de subirlo
- `L_69AF`, el que lleva dentro el motor de figuras, que escribe seguido por el
  puerto de datos sin cabecera de destino

## Dos intérpretes de rótulos

`L_4415` es el de siempre: `0xFE` cambia de destino con una dirección entera,
`0xFF` cierra. `L_676E` es el otro, y saca los saltos **en un solo byte**
relativo al sitio donde va. Con él caben dibujos de varias filas en muy pocos
bytes; la pértiga que el atleta lleva en la mano son doce casillas en un bloque
de quince bytes.

## El motor de figuras

`L_6992`. Un atleta no es un sprite: son de dos a siete sprites de 16x16, y
cada pieza son **cinco bytes** —fila y columna relativas, puntero al bloque de
patrón y color— con un `0x80` que cierra la figura.

Lo interesante es que el patrón **no está puesto de antes**: el bloque se
descomprime a la VRAM ahí mismo, en el momento, y los sprites lo cogen en
orden. Los 2 KB de patrones de sprite se rehacen enteros en cada fotograma, y
por eso el cartucho puede tener cientos de posturas.

Las figuras salen de cinco tablas, y **cada una acaba exactamente en su entrada
más baja**: eso es lo que fija cuántas figuras tiene cada una sin suponerlo.
Los 127 bloques de patrón a los que apuntan todas van seguidos.

Y el motor tiene dos puertas: `L_65FC`, que coge una figura de una tabla, y
`L_64E3`, que compone la figura de **dos bloques seguidos** compartiendo el
contador de patrones. La segunda es la que dibuja al atleta con la pértiga en
la mano.

## La tabla de noventa

`0x7346` son **noventa grados de seno**, un byte por grado. Que sean noventa y
no otra cosa lo dicen sus dos lectores: el segundo entra con `0x5A`, que es 90,
y `0x7346 + 90 = 0x73A0`, justo donde acaba.

## Los rectángulos con recorte

`L_AF7C` dibuja un rectángulo de la tabla de nombres teniendo en cuenta el
**desplazamiento de la pantalla**, que saca de `(0xE20D)` dividido por ocho.
Con la pista de curling en su sitio de arranque, la casa cae a la derecha del
borde y el `cp 020h / ret nc` no pinta ni una casilla: por eso la pantalla del
principio es hielo liso.

## Diez bytes que no son datos

Entre las figuras y los guiones relativos hay diez bytes que ninguna
instrucción del cartucho llama, y que **no son datos**: son una rutina. Divide
HL entre 32 sin perder por arriba, llevándose a A los tres bits que se salen.
Y eso es exactamente lo que hace a mano el reparto de la dirección de la
piedra del curling. Está ahí, entera, y nadie la usa.
