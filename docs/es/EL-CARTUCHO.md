# El cartucho

**Hyper Sports 3**, Konami, 1985. Catálogo **RC-733**. 32 KB de ROM en un
cartucho de MSX1, sin *mapper*, sin SCC y sin RAM propia.

## El mapa

    0x4000 .. 0xBFFF   los 32 KB del cartucho, páginas 1 y 2
    0xE000 .. 0xE7FF   los 2 KB de RAM de trabajo, y no usa más

La cabecera son los dieciséis bytes de `0x4000`: la firma `AB`, la dirección de
INIT (`0x405A`) y todo lo demás a cero —STATEMENT, DEVICE, TEXT y los seis
reservados—.

## Los ocho registros del VDP

El bucle de `0x4488` los escribe en orden, del 0 al 7, sacando cada valor de
una tabla. Para el juego son:

    02 E2 0E 7F 07 76 03 E4

    R2 = 0x0E -> nombres           0x3800
    R3 = 0x7F -> color             base 0x0000, máscara 0x3FF
    R4 = 0x07 -> patrones          base 0x2000
    R5 = 0x76 -> atributos sprite  0x3B00
    R6 = 0x03 -> patrones sprite   0x1800

**En SCREEN 2 los R3 y R4 no son una dirección**, son una base y una máscara.
Con estos valores la pantalla queda partida en los tres tercios de siempre,
cada uno con sus 256 patrones y sus 256 filas de color. De ahí que el cartucho
tenga una rutina (`L_4405`) que descomprime el mismo bloque en los tres a la
vez, saltando 0x0800 cada vez.

## Lo que INIT copia a la RAM

De los 2 KB de RAM de trabajo, **doce bytes** son los únicos que no arrancan a
cero. INIT los copia de `0x40CF` a `0xE053`, y son **los récords del mundo** de
las cuatro pruebas, en BCD. Están en RAM y no en ROM porque el juego los
sobrescribe en cuanto se mejoran.

## El reparto de escenas

Todo el juego lo reparten **once tablas de despacho**, y las once van pegadas
detrás de su `call L_4050`:

    pop hl / add a,a / call L_4046 / ld e,(hl) / inc hl / ld d,(hl)
    ex de,hl / jp (hl)

El `pop hl` recupera su propia dirección de retorno, o sea el principio de la
tabla. Es el despachador que comparten los cartuchos de esta familia de
Konami.

La cuenta de entradas de cada tabla no se estima: la fija el encaje de que
ninguna entrada puede apuntar dentro de la propia tabla. Las once están en
`src/hypersports3.entries` con su aritmética al byte. La más larga es la de
`0xA934`, con trece entradas; la más alta la de `0x4109`, con nueve, que es la
que reparte el logotipo, el título, las pruebas y el final.

## El sonido

El reproductor entero vive entre `0x4AD2` y `0x4DA2`, y sus datos justo detrás.
La puerta es `L_4ADD`: se le pasa en A el número de sonido. La tabla de pistas
**acaba exactamente en su entrada más baja**, `0x4E1C`, que es lo que fija su
longitud sin tener que suponerla.

La tabla de periodos tiene **doce valores, no diez**, y los dos últimos están
escondidos dentro de la tabla de punteros que viene detrás. Los doce caen a
menos de uno del semitono exacto: es una octava cromática.

## La marca oculta de Konami

Los últimos dieciséis bytes —`0xBFF0` a `0xBFFF`— llevan el título del juego en
**katakana y del revés**: ハイパースポーツ3, su longitud (0x0D), el **0x33** del
RC-733 y un 0xAA que cierra. **No lo lee nadie**: no hay una sola instrucción
del cartucho que apunte ahí.

La marca la descubrió **Manuel Pazos**, y está en muchos de los cartuchos de
Konami de estos años.

## Créditos

No hay ninguno. Ni iniciales, ni nombres, ni fechas de compilación en ninguna
parte de los 32 KB. Lo único que firma es la marca oculta, y firma la casa, no
a las personas.
