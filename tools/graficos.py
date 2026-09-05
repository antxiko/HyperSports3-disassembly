#!/usr/bin/env python3
"""Dibuja las pantallas de Hyper Sports 3 EJECUTANDO los pasos del cartucho.

No hay ni una captura de pantalla en este repositorio. Cada imagen se monta
desde la ROM: se corre el descompresor de `tools/rle.py` sobre los mismos
bloques y en el mismo orden que el codigo del cartucho, se ejecutan sus
guiones de rotulo con `tools/guiones.py`, y lo que sale es una VRAM de 16 KB
que se pinta como la pintaria el VDP.

El modo es SCREEN 2, y el reparto de la VRAM sale de la tabla de registros de
0x4492, no de una plantilla:

    02 E2 0E 7F 07 76 03 E4

    R2 = 0x0E -> nombres          0x3800
    R3 = 0x7F -> color            base 0x0000, mascara 0x3FF -> 0x0000..0x17FF
    R4 = 0x07 -> patrones         base 0x2000            -> 0x2000..0x37FF
    R5 = 0x76 -> atributos sprite 0x3B00
    R6 = 0x03 -> patrones sprite  0x1800

En SCREEN 2 los R3 y R4 NO son una direccion: son una base y una mascara. Con
estos valores la pantalla queda partida en los tres tercios de siempre, cada
uno con sus 256 patrones y sus 256 filas de color, y por eso el cartucho tiene
una rutina (L_4405) que descomprime el MISMO bloque en los tres a la vez,
saltando 0x0800 cada vez.

Uso: graficos.py <rom> <org> <directorio de salida>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rle import descomprime                                   # noqa: E402

VRAM = 0x4000
NOMBRES = 0x3800
COLOR = 0x0000
PATRONES = 0x2000

# Los quince colores del MSX1 mas el transparente, en RGB. Son los del TMS9918
# tal como los da la documentacion de Texas Instruments.
PALETA = [
    (0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120),
    (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
    (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128),
    (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255),
]


def caracter(b):
    """La fuente del cartucho: 0x00 espacio, 0x10..0x19 digitos, 0x21.. letras."""
    if b == 0x00:
        return " "
    if 0x10 <= b <= 0x19:
        return chr(0x30 + b - 0x10)
    if 0x21 <= b <= 0x3A:
        return chr(ord("A") + b - 0x21)
    return None


class Pantalla:
    """Una VRAM de 16 KB sobre la que se van ejecutando los pasos del cartucho."""

    def __init__(self, rom, org):
        self.rom, self.org = rom, org
        self.vram = bytearray(VRAM)

    # -- los mismos pasos que el codigo ------------------------------------
    def rle(self, dato, destino=None):
        """L_4442 (destino None: va dentro del bloque) o L_4448 (destino dado)."""
        r = descomprime(self.rom, self.org, dato, destino)
        if r is None:
            raise ValueError("el bloque 0x%04X no cierra dentro de la ROM" % dato)
        fin, v, tocado, _ = r
        for i in range(VRAM):
            if tocado[i]:
                self.vram[i] = v[i]
        return fin

    def rle3(self, dato, destino):
        """L_4405: el mismo bloque en los tres tercios, saltando 0x0800."""
        for t in range(3):
            self.rle(dato, (destino & 0x3FFF) + 0x0800 * t)

    def llena3(self, destino, n, valor):
        """L_43F4: FILVRM en los tres tercios."""
        for t in range(3):
            d = (destino & 0x3FFF) + 0x0800 * t
            for i in range(n):
                self.vram[(d + i) & 0x3FFF] = valor

    # -- la RAM ------------------------------------------------------------
    #
    # Tres de las cuatro pruebas no montan la pantalla solo con bloques a la
    # VRAM: descomprimen a la RAM, trabajan alli -desplazan, espejan, rotan- y
    # solo entonces suben el resultado. Sin una RAM de 2 KB no se pueden
    # dibujar. Es la de 0xE000..0xE7FF, la unica que el cartucho usa.
    RAM0 = 0xE000

    def ram(self):
        if not hasattr(self, "_ram"):
            self._ram = bytearray(0x800)
        return self._ram

    def rle_ram(self, dato, destino=None):
        """L_74B1 / L_74B5: el mismo RLE, pero escribiendo en la RAM.

        Con destino None lo saca de los dos primeros bytes del bloque, que es
        lo que hace L_74B1. El formato es el de siempre: 0x00 cierra, el bit 7
        distingue copiar de repetir.
        """
        r = self.ram()
        p = dato - self.org
        if destino is None:
            destino = self.rom[p] | (self.rom[p + 1] << 8)
            p += 2
        d = destino - self.RAM0
        while True:
            n = self.rom[p]
            if not (n & 0x7F):
                return self.org + p + 1
            p += 1
            if n & 0x80:
                for _ in range(n & 0x7F):
                    r[d] = self.rom[p]
                    p += 1
                    d += 1
            else:
                v = self.rom[p]
                p += 1
                for _ in range(n):
                    r[d] = v
                    d += 1

    def ram_a_vram(self, origen, destino, n):
        """L_9830 y compania: los bytes de la RAM, a la VRAM."""
        r = self.ram()
        for i in range(n):
            self.vram[(destino + i) & 0x3FFF] = r[origen - self.RAM0 + i]

    # -- las figuras -------------------------------------------------------
    def rle_directo(self, dato, destino):
        """El RLE de 0x69AF: escribe seguido, sin cabecera de destino.

        Es el que lleva dentro el motor de figuras. Los patrones de sprite del
        atleta NO estan puestos de antes: cada pieza trae el puntero a su
        bloque y se descomprime aqui mismo, encima de los mismos 2 KB, en cada
        fotograma.
        """
        p = dato - self.org
        d = destino
        while True:
            n = self.rom[p]
            if not n:
                return d
            p += 1
            if n & 0x80:
                for _ in range(n & 0x7F):
                    self.vram[d & 0x3FFF] = self.rom[p]
                    p += 1
                    d += 1
            else:
                v = self.rom[p]
                p += 1
                for _ in range(n):
                    self.vram[d & 0x3FFF] = v
                    d += 1

    def figura(self, tabla, indice, fila, col, piezas=7, sprite0=0):
        """L_65FC y L_6992: una figura del atleta, pieza a pieza.

        Un atleta no es un sprite: son de dos a siete sprites de 16x16, y cada
        pieza son CINCO bytes -la fila y la columna relativas, el puntero al
        bloque de patron y el color-, con un 0x80 que cierra. El patron no va
        en la pieza: se descomprime aqui y los sprites lo cogen en orden.

            0x6995  ld a,(de) / cp 080h / add a,b / ld (hl),a
            0x699f  ld a,(de) / add a,c' / ld (hl),a
            0x69a9  ld e,(hl) / ld d,(hl)   el puntero al bloque
            0x69ce  ld a,(de) / ld (hl),a   el color
        """
        q = tabla - self.org + indice * 2
        de = self.rom[q] | (self.rom[q + 1] << 8)
        q = de - self.org
        pat = 0x1800
        s = sprite0
        for _ in range(piezas):
            dy = self.rom[q]
            if dy == 0x80:
                break
            y = (dy + fila) & 0xFF
            x = (self.rom[q + 1] + col) & 0xFF
            ptr = self.rom[q + 2] | (self.rom[q + 3] << 8)
            color = self.rom[q + 4]
            q += 5
            pat = self.rle_directo(ptr, pat)
            a = 0x3B00 + s * 4
            self.vram[a] = y
            self.vram[a + 1] = x
            self.vram[a + 2] = (s - sprite0) * 4
            self.vram[a + 3] = color
            s += 1
        return s

    def piezas(self, bloque, figura, fila, col, sprite0=0):
        """L_64E3: el atleta con pertiga, que sale de DOS bloques seguidos.

        No es una figura de la tabla de siempre: son tres piezas de un bloque
        dado -0x6E15 en la carrerilla, 0x6E24 cuando la pertiga esta plantada-
        y detras las que traiga 0x6B6A[figura]. Las dos tandas comparten el
        contador de patrones, porque los patrones se descomprimen seguidos a
        0x1800 y el numero de patron de cada sprite es su orden por cuatro.

            0x64e3  push de / call L_694B / pop de   la fila y la columna
            0x64e9  ld a,003h / call L_698C          tres piezas desde 0xE0C4
            0x64ef  ld hl,0e0d0h                     y las demas desde 0xE0D0
            0x64f6  ld hl,06b6ah / suma_a_hl         la tabla de la figura
        """
        q = 0x6B6A - self.org + figura * 2
        otra = self.rom[q] | (self.rom[q + 1] << 8)
        s = self.piezas_de(bloque, fila, col, sprite0, 3)
        # el segundo grupo arranca en el sprite 12 (0xE0D0), pase lo que pase
        self.piezas_de(otra, fila, col, sprite0 + 3, 4, patron0=3)
        return s

    def piezas_de(self, dato, fila, col, sprite0, cuantas, patron0=0):
        """L_6992 con el bloque dado a pelo, sin pasar por una tabla."""
        q = dato - self.org
        pat = 0x1800 + patron0 * 32
        for i in range(cuantas):
            dy = self.rom[q]
            if dy == 0x80:
                break
            ptr = self.rom[q + 2] | (self.rom[q + 3] << 8)
            a = 0x3B00 + (sprite0 + i) * 4
            self.vram[a] = (dy + fila) & 0xFF
            self.vram[a + 1] = (self.rom[q + 1] + col) & 0xFF
            self.vram[a + 2] = (patron0 + i) * 4
            self.vram[a + 3] = self.rom[q + 4]
            pat = self.rle_directo(ptr, pat)
            q += 5
        return sprite0 + i

    def copia(self, dato, destino, n):
        """L_43DD: LDIRVM a pelo."""
        p = dato - self.org
        for i in range(n):
            self.vram[(destino + i) & 0x3FFF] = self.rom[p + i]

    def guion(self, dato, destino=None):
        """L_4415: el interprete de rotulos. 0xFE cambia destino, 0xFF cierra."""
        p = dato - self.org
        d = destino
        while True:
            if d is None:
                d = (self.rom[p] | (self.rom[p + 1] << 8)) & 0x3FFF
                p += 2
            b = self.rom[p]
            p += 1
            if b == 0xFF:
                return self.org + p
            if b == 0xFE:
                d = None
                continue
            self.vram[d & 0x3FFF] = b
            d += 1

    def dibujo_relativo(self, dato):
        """L_676E: el cuarto interprete, con saltos CORTOS.

        Como el de los rotulos, pero el 0xFE no trae un destino nuevo sino
        cuanto hay que saltar desde donde va, en un solo byte. Asi cabe un
        dibujo de varias filas en muy pocos bytes, que es como se guarda la
        pertiga.

            0x676e  el destino, de la cabecera
            0x677a  0xFF termina, 0xFE trae un salto, y lo demas es la casilla
        """
        p = dato - self.org
        d = (self.rom[p] | (self.rom[p + 1] << 8)) & 0x3FFF
        p += 2
        while True:
            b = self.rom[p]
            p += 1
            if b == 0xFF:
                return self.org + p
            if b == 0xFE:
                d = (d + self.rom[p]) & 0x3FFF
                p += 1
                continue
            self.vram[d] = b
            d += 1

    def texto(self, fila, col, cadena, base=0x21):
        """Escribe una cadena en la tabla de nombres, con la fuente del cartucho."""
        d = NOMBRES + fila * 32 + col
        for ch in cadena:
            if ch == " ":
                v = 0x00
            elif ch.isdigit():
                v = 0x10 + int(ch)
            else:
                v = base + ord(ch.upper()) - ord("A")
            self.vram[d] = v
            d += 1

    # -- el pintado --------------------------------------------------------
    def imagen(self, filas=24, cols=32):
        """Los pixeles de la pantalla, 256x192, como lista de filas de RGB."""
        px = [[(0, 0, 0)] * (cols * 8) for _ in range(filas * 8)]
        for f in range(filas):
            tercio = f // 8
            for c in range(cols):
                tile = self.vram[NOMBRES + f * 32 + c]
                bp = PATRONES + tercio * 0x800 + tile * 8
                cp = COLOR + tercio * 0x800 + tile * 8
                for y in range(8):
                    b = self.vram[(bp + y) & 0x3FFF]
                    col = self.vram[(cp + y) & 0x3FFF]
                    tinta, fondo = col >> 4, col & 15
                    for x in range(8):
                        v = tinta if (b >> (7 - x)) & 1 else fondo
                        px[f * 8 + y][c * 8 + x] = PALETA[v]
        return px

    def sprites(self, px):
        """Pinta encima los sprites de 16x16 que haya en los atributos."""
        for s in range(32):
            a = 0x3B00 + s * 4
            y, x, patron, color = (self.vram[a], self.vram[a + 1],
                                   self.vram[a + 2], self.vram[a + 3])
            if y == 0xD0:                      # el 0xD0 corta la lista
                break
            if y > 0xC0:                       # fuera de pantalla
                continue
            y = (y + 1) & 0xFF
            ec = color & 0x80                  # bit de desplazamiento a la izq.
            if ec:
                x -= 32
            c = PALETA[color & 15]
            if not (color & 15):
                continue
            base = 0x1800 + (patron & 0xFC) * 8
            for cuarto in range(4):
                dx = 8 * (cuarto // 2)
                dy = 8 * (cuarto % 2)
                for fy in range(8):
                    b = self.vram[base + cuarto * 8 + fy]
                    for fx in range(8):
                        if not (b >> (7 - fx)) & 1:
                            continue
                        py_, px_ = y + dy + fy, x + dx + fx
                        if 0 <= py_ < len(px) and 0 <= px_ < len(px[0]):
                            px[py_][px_] = c
        return px


def png(ruta, px, escala=2):
    """Escribe un PNG sin depender de ninguna biblioteca."""
    import struct
    import zlib
    alto, ancho = len(px) * escala, len(px[0]) * escala
    crudo = bytearray()
    for f in px:
        fila = bytearray()
        for p in f:
            fila += bytes(p) * escala
        for _ in range(escala):
            crudo += b"\x00" + fila
    def trozo(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))
    with open(ruta, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0)))
        f.write(trozo(b"IDAT", zlib.compress(bytes(crudo), 9)))
        f.write(trozo(b"IEND", b""))


# ==========================================================================
# LAS PANTALLAS, cada una con los pasos que da el propio cartucho
# ==========================================================================
def base_de_texto(p):
    """L_4569: la rampa de color y los patrones de la fuente.

    Los dieciseis primeros tiles de cada tercio se llenan con un color solido
    cada uno, y el color va subiendo de 0x11 en 0x11:

        0x4569  xor a / ld hl,0 / ld de,8 / ld b,010h
        0x4572  push bc / ld bc,8 / push hl / call L_43F4  (FILVRM x3 con A)
                pop hl / add hl,de / add a,011h / pop bc / djnz

    Y despues la fuente en los patrones, la tabla de nombres del logotipo, y
    el color 0xF0 -blanco sobre transparente- para los tiles 0x10..0x3F:

        0x4581  ld de,0459bh / ld hl,02080h / call L_4405
        0x458A  ld de,0470ch / call L_4442
        0x4590  ld a,0f0h / ld hl,00080h / ld bc,00180h / jp L_43F4
    """
    a = 0
    for i in range(16):
        p.llena3(i * 8, 8, a)
        a = (a + 0x11) & 0xFF
    p.rle3(0x459B, 0x2080)                # la fuente, desde el tile 0x10
    p.rle(0x470C)                         # la tabla de nombres del logotipo
    p.llena3(0x0080, 0x180, 0xF0)         # blanco sobre transparente
    return p


def logotipo(rom, org):
    """La pantalla del logotipo de Konami, la escena 0.

    L_4569 monta la base y luego 0x486F pinta los rotulos:

        0x486F  ld de,04525h / call L_4415 / jp L_4415
    """
    p = base_de_texto(Pantalla(rom, org))
    p.rle(0x4514)                         # SOFTWARE
    p.guion(0x4525)                       # (c)KONAMI 1985, PLAY SELECT, 1PLAYER
    p.guion(0x454C)                       # 2PLAYERS
    p.guion(0x4557, 0x3A4A)               # el cursor, delante de 1PLAYER
    return p


def rotulo_del_titulo(p):
    """El rotulo grande de HYPER SPORTS 3, montado tile a tile.

    Sus patrones y su color llegan comprimidos, y encima se copian cuatro
    bloques repetidos que estan en la propia tabla de 0x4AA5:

        0x4815  ld de,048adh / ld hl,02580h / call L_4405
        0x481E  ld de,04a88h / ld hl,00580h / call L_4405
        0x4827  ld de,04aa5h ...   [n] [destino] [8 bytes], y n=0 cierra

    Y la tabla de nombres se escribe con la lista de 0x4878, que son pares
    [cuantos tiles] [cuanto saltar], con el indice de tile subiendo solo:

        0x4851  ld de,04878h / ld c,0b0h / ld hl,0386ch
    """
    p.rle3(0x48AD, 0x2580)
    p.rle3(0x4A88, 0x0580)
    q = 0x4AA5 - p.org
    while p.rom[q]:
        n = p.rom[q]
        d = (p.rom[q + 1] | (p.rom[q + 2] << 8)) & 0x3FFF
        for i in range(n):
            for t in range(3):
                p.copia(p.org + q + 3, d + i * 8 + 0x800 * t, 8)
        q += 3 + 8
    # la tabla de nombres
    q = 0x4878 - p.org
    c, hl = 0xB0, 0x386C
    while p.rom[q]:
        n = p.rom[q]
        hl = (hl + p.rom[q + 1]) & 0xFFFF
        q += 2
        for _ in range(n):
            p.vram[hl & 0x3FFF] = c
            hl += 1
            c = (c + 1) & 0xFF
    return p


def titulo(rom, org):
    """La pantalla del titulo: el logotipo de Konami mas el rotulo del juego.

        0x472D  ld de,04773h / ld hl,06200h / call L_4405
        0x4736  ld hl,00200h / ld bc,000d8h / ld a,0f0h / jp L_43F4
    """
    p = base_de_texto(Pantalla(rom, org))
    p.rle3(0x4773, 0x2200)                # los tiles grandes, desde el 0x40
    p.llena3(0x0200, 0xD8, 0xF0)
    rotulo_del_titulo(p)
    p.rle(0x4514)
    p.guion(0x4525)
    p.guion(0x454C)
    p.guion(0x4557, 0x3A4A)
    return p


# ==========================================================================
# LAS CUATRO PRUEBAS
# ==========================================================================
def sobre_el_titulo(rom, org, fn):
    """Monta una prueba ENCIMA de la pantalla del titulo, como hace el juego.

    Entre escena y escena el cartucho NO borra la VRAM entera: L_43C4 solo
    esconde los sprites y borra la tabla de nombres, asi que los patrones y el
    color de la pantalla anterior siguen debajo. Montar una prueba desde cero
    da miles de bytes distintos contra el emulador; montarla encima del titulo
    -que es de donde se viene al arrancar partida- los deja en cero.

    Que la herencia es EXACTAMENTE esta no es una suposicion: tools/omsx_vram.tcl
    vuelca la VRAM en el punto de ruptura de 0x41B5, o sea justo antes de que
    monta_la_prueba escriba su primer byte, y ese volcado sale identico al que
    monta `titulo()` -0 bytes de diferencia en color, patrones y sprites; solo
    las 116 casillas de nombres que L_43C4 borra-.

    La prueba se monta ENCIMA, pasandole la pantalla en `base`. Antes se montaba
    aparte y se fusionaba copiando los bytes que no coincidieran con una
    pantalla virgen, y eso perdia todos los CEROS que el montaje escribe de
    verdad: 319 bytes en el triple salto, que se achacaban a bloques que
    faltaban y no faltaba ninguno.
    """
    p = titulo(rom, org)
    for i in range(0x80):                 # L_43C4: los sprites, escondidos
        p.vram[0x3B00 + i] = 0xC3
    for i in range(0x300):                # y la tabla de nombres, a cero
        p.vram[0x3800 + i] = 0
    return fn(rom, org, base=p)


def marcador_de_arriba(p):
    """L_5420: la franja de arriba, que es igual en las cuatro pruebas.

        0x5420  ld hl,02200h / ld de,075abh / call L_4448
        0x5429  ld hl,00200h / ld de,0760ah / call L_4448
        0x5432  ld de,09fa7h / call L_4442
        0x5438  ld hl,002c0h / ld bc,00010h / ld a,0f0h / jp FILVRM
    """
    p.rle(0x75AB, 0x2200)
    p.rle(0x760A, 0x0200)
    p.rle(0x9FA7)
    for i in range(0x10):
        p.vram[0x02C0 + i] = 0xF0
    return p


def ciclismo(rom, org, base=None):
    """La pantalla del ciclismo, la prueba 0.

    Lo monta L_5402, y el circuito NO esta en la VRAM: vive en dos ventanas de
    la RAM -0xE140 y 0xE260, nueve filas de treinta y dos casillas cada una- que
    L_97C2 rellena y L_9827 vuelca a 0x3880 y a 0x39C0.

        0x5402  call L_9C9D          los ocho desplazamientos del ciclista
        0x5405  call L_546B          las variables
        0x5408  ld hl,02268h / ld de,09d5fh / call L_4405
        0x5411  ld hl,00268h / ld de,09f16h / call L_4405
        0x541a  ld de,09fb7h / call L_4442
        0x5420  ... el marcador de arriba

    Y el montaje NO se acaba ahi. La pantalla de la carrera la termina la
    ESCENA 0 (L_91F9), que trae el marco del marcador y los patrones de
    sprite, y detras de ella la escena 1 (L_921F) escribe el WORLD REC con la
    marca a batir y los dos cronos a cero:

        0x91f9  ld de,05519h / call L_4442        las casillas del marco
        0x91ff  ld de,0906dh / ld hl,01c00h       y los patrones de sprite
        0x9208  call L_93DF                       la pantalla entera
        0x920b  call L_9626                       los rotulos de las ventanas
    """
    p = base_de_texto(base if base is not None else Pantalla(rom, org))
    p.rle3(0x7658, 0x2030)                # 0x53B4: comun a las cuatro pruebas
    p.rle3(0x766C, 0x0030)
    ciclistas_en_ocho_pasos(p)            # 0x9C9D
    monta_a_los_dos_ciclistas(p)          # L_546B: las variables de los dos
    p.rle3(0x9D5F, 0x2268)
    p.rle3(0x9F16, 0x0268)
    p.rle(0x9FB7)
    marcador_de_arriba(p)
    p.rle(0x5519)                         # 0x91F9: el marco del marcador
    p.rle(0x906D, 0x1C00)                 # y los patrones de sprite
    # Las dos ventanas del circuito, a la RAM y de alli a la pantalla
    p.rle_ram(0x97D1, 0xE140)             # L_97C2
    p.rle_ram(0x97D1, 0xE260)
    sprites_de_los_dos_ciclistas(p)       # L_9AE7, que coloca las piezas
    pinta_a_los_dos_ciclistas(p)          # L_A36C, antes del volcado
    pinta_a_cada_uno_en_la_otra_ventana(p)  # L_A3B4: los rivales
    p.ram_a_vram(0xE140, 0x3880, 288)     # L_9819
    p.ram_a_vram(0xE260, 0x39C0, 288)
    vuelca_los_sprites_de_las_dos(p)      # L_A251
    marcos_de_las_ventanas(p)             # L_95F1
    barra_de_los_dos(p)                   # L_9987: las dos de velocidad
    p.guion(0x969E)                       # los rotulos de arriba
    p.guion(0x96BE)
    rotulos_de_los_dos_jugadores(p)       # L_A819: 1UP y 2UP, o CPU
    escribe_las_dos_distancias(p)         # L_9769: los 2000 m
    rotulos_de_los_dos_ciclistas(p)       # L_9626: los de dentro de la ventana
    marcador_del_ciclismo(p)              # L_921F: la escena 1
    return p


def monta_a_los_dos_ciclistas(p):
    """L_546B: los dos bloques de sesenta y cuatro bytes de los ciclistas.

    Sin esto no se puede dibujar nada del ciclismo: la posicion de cada uno, su
    carril, su velocidad y los 2000 m de la carrera salen de aqui, y las
    rutinas de pintado no hacen mas que leerlos. El bloque del ciclista 1
    empieza en 0xE0A0 y el del 2 en 0xE0E0, y el segundo es una COPIA del
    primero con cuatro bytes propios encima.

        0x5483  el borrado a cero de 0xE0A0 en adelante, 0x35E bytes
        0x548f  los cuatro bytes de 0x5511 a 0xE0B1, y 0x58 en 0xE0B0
        0x54a8  el bloque del 1, copiado entero sobre el del 2
        0x54b3  y encima, los cuatro de 0x5515
        0x54be  0x2000 en 0xE381 y en 0xE384: los metros de la carrera
        0x54cd  ld a,020h / ld (0e0e3h),a   la fila del ciclista 2
        0x54d2  y el que no este en la partida arranca con un 1

    El `ld (0e0e3h),a` de 0x54CD es el que coloca al ciclista 2 cuatro filas
    de casillas mas abajo dentro de su ventana. Con el, L_A427 da 0xE329, que
    es lo que el emulador tiene apuntado en 0xE0F5.

    Los 0xE070 y 0xE080 son de quien juega, y los pone 0x42FE al empezar la
    partida: 0xE070 a 1 siempre, y 0xE080 solo si el bit 5 de (0xE002) dice que
    juegan dos. Aqui se monta la partida de UN jugador, que es la que la
    demostracion y el volcado del emulador tienen en marcha.
    """
    r = p.ram()

    def w(a, v):
        r[a - p.RAM0] = v & 0xFF

    def ww(a, v):
        w(a, v)
        w(a + 1, v >> 8)

    ww(0xE096, 0x8669)                    # la primera figura de cada uno
    w(0xE098, 1)
    ww(0xE099, 0x8669)
    w(0xE09B, 1)
    w(0xE071, 0)
    w(0xE081, 0)
    for a in range(0xE0A0, 0xE0A0 + 0x35F):
        w(a, 0)
    for i in range(4):
        w(0xE0B1 + i, p.rom[0x5511 - p.org + i])
    w(0xE0B0, 0x58)
    ww(0xE0BE, 0x0101)
    ww(0xE0C0, 0x0101)
    for i in range(0x3F):
        w(0xE0E1 + i, r[0xE0A1 - p.RAM0 + i])
    for i in range(4):
        w(0xE0F1 + i, p.rom[0x5515 - p.org + i])
    ww(0xE381, 0x2000)
    ww(0xE384, 0x2000)
    ww(0xE10B, 0x2020)
    w(0xE0E3, 0x20)
    w(0xE070, 1)                          # 0x42FE: el jugador 1, dentro
    w(0xE080, 0)                          # y el 2 fuera: partida de uno
    if not r[0xE070 - p.RAM0]:
        w(0xE0A0, 1)
    if not r[0xE080 - p.RAM0]:
        w(0xE0E0, 1)
    ww(0xE113, 0x0101)
    w(0xE389, 0x9F)
    return p


def sprites_de_los_dos_ciclistas(p):
    """L_9AE7: la fila y el color de cada uno, y la pieza de atras.

    No pinta: COLOCA. Deja en (ix+0x0F) la fila con el color metido en los tres
    bits de abajo, y en (ix+0x1C) y (ix+0x1D) la pieza que va detras, que es la
    que L_A3B4 usa despues para poner al rival en la otra ventana.

        0x9ae7  ld c,02fh / ld ix,0e0a0h   el color del ciclista 1
        0x9af3  ld c,07fh / ld ix,0e0e0h   y el del 2
        0x9b36  (ix+0x0F) = (ix+3) & 0xF8 + c
        0x9afc  ld hl,0e0a3h / ld a,c / cp 02fh / jr nz / ld l,0e3h

    Y ese `cp 02fh` es lo bonito: con Z -o sea CON el ciclista 1- se queda con
    0xE0E3, la fila del OTRO. Cada uno lee la fila del contrario, que es lo que
    hace que el rival salga en su sitio. Sale (0xE0BC) = 0x4F y (0xE0FC) = 0x7F,
    que es exactamente lo que el emulador tiene ahi.
    """
    r = p.ram()
    for ix, c, otro in ((0xE0A0, 0x2F, 0xE0E3), (0xE0E0, 0x7F, 0xE0A3)):
        r[ix + 0x0F - p.RAM0] = ((r[ix + 3 - p.RAM0] & 0xF8) + c) & 0xFF
        r[ix + 0x1C - p.RAM0] = ((r[otro - p.RAM0] & 0xF8) + c) & 0xFF
        # la posicion de la pieza contra la propia, centrada en la ventana
        de = r[otro + 2 - p.RAM0] | (r[otro + 3 - p.RAM0] << 8)
        hl = r[ix + 5 - p.RAM0] | (r[ix + 6 - p.RAM0] << 8)
        v = (de - hl + 0x58) & 0xFFFF
        if v >> 8 or (v & 0xFF) >= 0xF0 or (v & 0xFF) < 0x10:
            r[ix + 0x1C - p.RAM0] = 0xD1  # fuera de la ventana, escondida
        else:
            r[ix + 0x1D - p.RAM0] = v & 0xFF
    return p


def pinta_a_cada_uno_en_la_otra_ventana(p):
    """L_A3B4: el rival, SEIS casillas, en la ventana del contrario.

    En la ventana de cada jugador se ve al otro, y no con cuatro casillas sino
    con seis -tres de ancho por dos de alto-, porque va mas lejos y se dibuja
    con la version comprimida.

        0xa3b4  ld ix,0e0a0h / ld hl,0e0e5h / ld de,0e0e0h
        0xa3c4  ld hl,0e0a5h / ld ix,0e0e0h / ld de,0e0c0h
        0xa407  c = 0xA0 o 0xD0 segun el carril, mas seis por desplazamiento
        0xa3d5  ld a,h / sub 010h    dos columnas a la izquierda
        0xa437  la casilla, con la fila en L y la columna en H

    Los dos DE parecen apuntar a las variables y no a una ventana, y es que van
    SESGADOS: 0xE0E0 + 0x129 cae en 0xE209, dentro de la ventana de arriba, y
    0xE0C0 + 0x1E9 en 0xE2A9, dentro de la de abajo. Las seis casillas salen
    en H, H+1, H+2 y en H+0x20, H+0x21, H+0x22, con los tiles c, c+2, c+4 y
    c+1, c+3, c+5.
    """
    r = p.ram()
    for ix, pos, de in ((0xE0A0, 0xE0E5, 0xE0E0), (0xE0E0, 0xE0A5, 0xE0C0)):
        c = 0xD0 if r[pos - p.RAM0] & 0x10 else 0xA0     # L_A407: el carril
        c = (c + (r[ix + 0x1D - p.RAM0] & 0x07) * 6) & 0xFF
        l = r[ix + 0x1C - p.RAM0]                        # L_A41C
        h = r[ix + 0x1D - p.RAM0]
        if l >= 0xD0:
            continue                                     # fuera de la ventana
        h = (h - 0x10) & 0xFF if h >= 0x10 else 0
        hl = ((l & 0xF8) * 4) & 0xFFFF                    # L_A437
        hl = (hl & 0xFF00) | ((hl & 0xFF) | ((h >> 3) & 0x1F))
        d = (hl + de) - p.RAM0
        for j, k in ((0, 0), (1, 2), (2, 4), (0x20, 1), (0x21, 3), (0x22, 5)):
            r[d + j] = (c + k) & 0xFF
    return p


def cifras_bcd(p, destino, de, n):
    """L_4358: N bytes en BCD leidos hacia atras, sin ceros a la izquierda.

    Los digitos son los tiles del 0x10 al 0x19, y la mascara de 0x4374 vale
    cero mientras solo hayan salido ceros: asi el 0 se convierte en el tile del
    espacio y el numero sale sin ceros delante. En el ultimo byte la mascara se
    fuerza a 0xFF, que es lo que hace que un cero pelado se vea.
    """
    r = p.ram()
    d, mask = destino, 0x00
    for i in range(n):
        v = r[de - p.RAM0 - i]
        alto = (v >> 4) & 0x0F
        if alto:
            mask = 0xFF
        if i == n - 1:
            mask = 0xFF
        p.vram[d & 0x3FFF] = (alto + 0x10) & mask
        d += 1
        bajo = v & 0x0F
        if bajo:
            mask = 0xFF
        p.vram[d & 0x3FFF] = (bajo + 0x10) & mask
        d += 1
    return p


def un_tiempo(p, destino, de):
    """L_A78C: minutos, segundos y centesimas, con sus dos separadores.

    Tres bytes en BCD leidos de mas peso a menos: los minutos en UNA cifra, y
    despues dos parejas con el tile 0x58 -los dos puntos- y el 0x59 -la coma-
    delante de cada una.
    """
    r = p.ram()
    d = destino
    p.vram[d & 0x3FFF] = 0x10 + (r[de - p.RAM0] & 0x0F)
    d += 1
    for k, sep in enumerate((0x58, 0x59)):
        v = r[de - 1 - k - p.RAM0]
        p.vram[d & 0x3FFF] = sep
        p.vram[(d + 1) & 0x3FFF] = 0x10 + ((v >> 4) & 0x0F)
        p.vram[(d + 2) & 0x3FFF] = 0x10 + (v & 0x0F)
        d += 3
    return p


def barra_de_los_dos(p):
    """L_9987: las dos barras de velocidad, y la cifra en km/h.

    La barra no tiene dibujo: son quince casillas y dos tiles. El nibble de
    arriba de la velocidad dice cuantas van llenas -el tile 8- y las que faltan
    hasta quince salen vacias, con el 7.

        0x998a  ld hl,039a7h / ld de,0e0adh   la del jugador 1
        0x999c  ld hl,03ae7h / ld de,0e0edh   y la del 2
        0x99cd  el nibble de arriba, y quince menos el
        0x99b6  y la cifra: dos bytes BCD desde 0xE0DF o desde 0xE11F
    """
    r = p.ram()
    for hl, vel, cifra in ((0x39A7, 0xE0AD, 0xE0DF), (0x3AE7, 0xE0ED, 0xE11F)):
        llenos = (r[vel - p.RAM0] >> 4) & 0x0F
        for i in range(15):
            p.vram[hl + i] = 0x08 if i < llenos else 0x07
        cifras_bcd(p, hl + 0x10, cifra, 2)
    return p


def rotulos_de_los_dos_jugadores(p):
    """L_A819: 1UP y 2UP, o el CPU del que no juega.

        0xa819  ld a,(0e0a0h) / ld de,09675h / ld hl,0380ch
        0xa825  ld de,09679h / ld hl,0384ch / ld a,(0e0e0h)
        0xa82e  and a / jr z / ld de,0967dh   si esta fuera, CPU
    """
    r = p.ram()
    for var, dato, destino in ((0xE0A0, 0x9675, 0x380C),
                               (0xE0E0, 0x9679, 0x384C)):
        p.guion(0x967D if r[var - p.RAM0] else dato, destino)
    return p


def sprites_de_un_ciclista(p, sat, ix, hl):
    """L_A26B: las CINCO piezas de un ciclista, por el puerto de datos.

    No hay tabla en RAM que valga: los cuatro bytes de cada sprite salen uno
    detras de otro por el puerto, y de tres sitios distintos a la vez. Los
    `push hl / pop hl` del listado no mueven nada, son esperas para que el VDP
    no se atragante.

        0xa271  el byte de estado; su nibble de arriba es la POSTURA
        0xa281  ld hl,0a2fch / postura*3   tres patrones por postura
        0xa28f  ld de,0a2e8h / 0a2f2h      y las filas y columnas de cada una
        0xa2a3  ld hl,0a311h / 0a314h      el patron de la cuarta pieza
        0xa2b6  ld hl,0a317h / +1          y el de la rueda, segun el carril
        0xa2c1  ld hl,0a319h               cuyo color es el 1, siempre
        0xa2c6  fila = byte + (hl+1), o 0xDF si el byte es 0xFF
        0xa2d5  columna = byte + (hl+2)

    Los cinco colores salen de los bytes que L_546B copio de 0x5511 y de
    0x5515, mas el 0x01 de 0xA319 para la ultima pieza.
    """
    r = p.ram()
    estado = r[hl - p.RAM0]
    postura = (estado >> 4) & 0x0F
    fila, col = r[hl + 1 - p.RAM0], r[hl + 2 - p.RAM0]
    de = 0xA2E8 if postura == 0 else 0xA2F2
    patrones = [p.rom[0xA2FC - p.org + postura * 3 + i] for i in range(3)]
    tabla = 0xA311 if not (estado & 0xF0) else 0xA314
    patrones.append(p.rom[tabla - p.org + (estado & 0x0F)])
    rueda = 0xA317 + (1 if r[ix + 5 - p.RAM0] & 0x10 else 0)
    patrones.append(p.rom[rueda - p.org])
    colores = [r[hl + 3 + i - p.RAM0] for i in range(4)] + [p.rom[0xA319 - p.org]]
    for s in range(5):
        y = p.rom[de - p.org + s * 2]
        x = p.rom[de - p.org + s * 2 + 1]
        y = 0xDF if y == 0xFF else (y + fila) & 0xFF
        a = sat + s * 4
        p.vram[a] = y
        p.vram[a + 1] = (x + col) & 0xFF
        p.vram[a + 2] = patrones[s]
        p.vram[a + 3] = colores[s]
    return p


def vuelca_los_sprites_de_las_dos(p):
    """L_A251: los cuatro ciclistas, dos en cada ventana.

    En la ventana de arriba va primero el ciclista 1 y detras el 2; en la de
    abajo, al reves. Son cinco sprites cada uno, o sea veinte en total, y no
    caben mas: el MSX1 solo tiene treinta y dos.

        0xa238  ld hl,03b00h / ld ix,0e0a0h / ld hl,0e0aeh
        0xa248  ld ix,0e0e0h / ld hl,0e0bbh
        0xa254  ld hl,03b28h / ld ix,0e0e0h / ld hl,0e0eeh
        0xa264  ld hl,0e0fbh / ld ix,0e0a0h
    """
    for sat, ix, hl in ((0x3B00, 0xE0A0, 0xE0AE), (0x3B14, 0xE0E0, 0xE0BB),
                        (0x3B28, 0xE0E0, 0xE0EE), (0x3B3C, 0xE0A0, 0xE0FB)):
        sprites_de_un_ciclista(p, sat, ix, hl)
    return p


def rotulos_de_los_dos_ciclistas(p):
    """L_9626: el mismo 1UP / 2UP / CPU, pero DENTRO de cada ventana.

        0x9626  ld hl,038e2h / ld a,(0e0a0h) / ld c,000h
        0x9631  ld hl,03a22h / ld a,(0e0e0h) / ld c,001h
        0x9639  ld de,0967dh   fuera de la partida, CPU
        0x9640  ld de,09675h   y dentro, el 1UP o el 2UP segun C
    """
    r = p.ram()
    for var, c, destino in ((0xE0A0, 0, 0x38E2), (0xE0E0, 1, 0x3A22)):
        if r[var - p.RAM0]:
            dato = 0x967D
        else:
            dato = 0x9675 if c == 0 else 0x9679
        p.guion(dato, destino)
    return p


def escribe_las_dos_distancias(p):
    """L_9769: los metros que faltan, cuatro cifras cada uno.

        0x9774  ld hl,03819h / ld de,0e382h   la del jugador 1
        0x977c  ld hl,03859h / ld de,0e385h   y la del 2
    """
    cifras_bcd(p, 0x3819, 0xE382, 2)
    cifras_bcd(p, 0x3859, 0xE385, 2)
    return p


def marcador_del_ciclismo(p):
    """L_921F: la escena 1, que es la que llena el marcador antes de arrancar.

    El montaje de L_93DF deja el marcador VACIO; lo que se ve en la pantalla
    cuando empieza la carrera lo escribe la escena de antes:

        0xa77d  ld hl,03810h / ld de,0e0d1h   el crono del jugador 1
        0xa786  ld de,0e111h / ld hl,03850h   y el del 2
        0x9210  ld hl,03823h / ld de,0e055h   la marca del mundo
        0x9219  ld de,0968ch                  y el rotulo WORLD REC

    Los tres bytes de la marca son los que INIT copia de 0x40CF a 0xE053, y
    para el ciclismo son 34 45 01, o sea 1'45"34: el record del mundo de los
    100 km contrarreloj por equipos, que es la prueba que el cartucho llama
    CYCLING.
    """
    r = p.ram()
    for i in range(12):                   # 0x4095: los doce valores de 0x40CF
        r[0xE053 + i - p.RAM0] = p.rom[0x40CF - p.org + i]
    un_tiempo(p, 0x3810, 0xE0D1)
    un_tiempo(p, 0x3850, 0xE111)
    un_tiempo(p, 0x3823, 0xE055)
    p.guion(0x968C)
    return p


def pinta_a_los_dos_ciclistas(p):
    """L_A36C: los dos ciclistas, CUATRO casillas cada uno, en su ventana.

    No son sprites. Son cuatro casillas de la tabla de patrones, y por eso hay
    que ponerlas en el buffer de RAM ANTES de volcarlo: la VRAM se rellena
    despues, con L_9819.

        0xa36c  ld ix,0e0a0h / ld de,0e140h    el ciclista 1 en su ventana
        0xa379  ld ix,0e0e0h / ld de,0e260h    y el 2 en la suya
        0xa427  H = ventana + ((ix+3) & 0xF8) * 4 + 0x49
        0xa383  c = 0xA0, o 0xD0 si el bit 4 de (ix+5): el carril
        0xa3a9  H <- c, H+1 <- c+2, H+0x20 <- c+1, H+0x21 <- c+3

    Los dos (ix+3) los deja L_546B: el 1 se queda a cero con el borrado de
    0x5483, y el 2 recibe el `ld a,020h / ld (0e0e3h),a` de 0x54CD, o sea que
    arranca cuatro filas de casillas mas abajo dentro de SU ventana. De ahi
    salen H=0xE189 y H=0xE329, que es exactamente lo que el emulador tiene
    apuntado en 0xE0B5 y en 0xE0F5 -donde el cartucho guarda el fondo que
    acaba de tapar-. Y los dos (ix+5) valen 0, asi que los dos van por el
    carril de 0xA0.
    """
    r = p.ram()
    for ix, ventana in ((0xE0A0, 0xE140), (0xE0E0, 0xE260)):
        fila = r[ix + 3 - p.RAM0]
        h = ventana + (fila & 0xF8) * 4 + 0x49 - p.RAM0   # L_A427
        c = 0xD0 if r[ix + 5 - p.RAM0] & 0x10 else 0xA0
        r[h] = c
        r[h + 1] = c + 2
        r[h + 0x20] = c + 1
        r[h + 0x21] = c + 3
    return p


def ciclistas_en_ocho_pasos(p):
    """L_9CC7: las ocho copias corridas de cada dibujo de 16x16.

    Es lo mas bonito del ciclismo: el ciclista no es un sprite, es un dibujo
    puesto en la tabla de patrones, y para moverlo al pixel se generan ocho
    versiones rotando los bits. De paso sale la mascara, que es el 0xFF al que
    se le van metiendo ceros por delante.

        0x9CD5  ld b,h / ld d,(ix+000h) / ld e,(ix+010h) / ld a,0ffh
        0x9CE4  scf / rr d / rr e / rra / djnz
    """
    for patron, destino in ((0x9D14, 0x24D0), (0x9D34, 0x2650)):
        # El destino se sube 0x30 ANTES de volcar, no despues (0x9CFA), asi que
        # la primera copia -la que no se rota- no cae en 0x24D0 sino en 0x2500.
        # De ahi que los tiles del ciclista empiecen en 0xA0 y en 0xD0, que es
        # justo lo que 0xA383 carga en C.
        hl = destino + 0x30
        for corrimiento in range(8):
            for fila in range(16):
                d = p.rom[patron - p.org + fila]
                e = p.rom[patron - p.org + 0x10 + fila]
                a = 0xFF
                for _ in range(corrimiento):
                    # entra un uno por delante y los bits bajan en cadena
                    nd = 0x80 | (d >> 1)
                    ne = ((d & 1) << 7) | (e >> 1)
                    na = ((e & 1) << 7) | (a >> 1)
                    d, e, a = nd, ne, na
                for t in range(3):
                    base = (hl & 0x3FFF) + 0x800 * t
                    p.vram[(base + fila) & 0x3FFF] = d
                    p.vram[(base + 0x10 + fila) & 0x3FFF] = e
                    p.vram[(base + 0x20 + fila) & 0x3FFF] = a
            hl += 0x30
    # y los dieciseis bloques de color de 0x9D54
    hl = 0x0500
    for _ in range(0x10):
        p.rle3(0x9D54, hl)
        hl += 0x30
    return p


def marcos_de_las_ventanas(p):
    """L_95F1: las tres filas del marco de cada ventana.

        0x95F1  ld hl,038c0h / call L_95FA / ld hl,03a00h
        0x95FF  ld bc,00007h / call L_43DD / ld a,020h / call L_4046
    """
    for hl in (0x38C0, 0x3A00):
        d = hl
        for i in range(3):
            p.copia(0x9611 + i * 7, d, 7)
            d += 0x20
    return p


def salto(rom, org, pertiga=False, base=None):
    """La pantalla del triple salto o la del salto con pertiga, la 1 y la 3.

    Las dos comparten motor y comparten pantalla; solo cambia un bloque -el
    liston- y la longitud de la pista. Lo monta L_53B1 y sigue en 0x73D9.

        0x53b4  ld de,07658h / ld hl,02030h / call L_4405
        0x73d9  ld de,075abh / ld hl,02748h / call L_4448
        0x73eb  ld de,07631h / ld hl,01200h / call L_4448
        0x73f4  ld de,076c7h / ld hl,02220h / ld b,002h / call L_4407
        0x7410  ld hl,0785fh / ld de,0e320h / call L_74B5
        0x741f  ... los cuatro pixeles a mano, rotando doce tiles seguidos
        0x7462  ld hl,02b90h / ld de,0e320h / ld bc,000c0h / call L_43DD
        0x7494  ld de,0799eh (triple salto) o 079cfh (pertiga)
    """
    p = base_de_texto(base if base is not None else Pantalla(rom, org))
    p.rle3(0x7658, 0x2030)                # los patrones comunes
    p.rle3(0x766C, 0x0030)
    # OJO: el salto NO monta el marcador de arriba de L_5420. Eso es del
    # ciclismo y del curling; aqui el marcador viene de los cuatro bloques
    # encadenados de 0x799E, mas abajo. Estaba puesto y sobraba: pintaba los
    # patrones de 0x75AB en 0x2200, que en esta prueba son otra cosa.
    p.rle(0x75AB, 0x2748)                 # los patrones de la pista
    p.rle(0x760A, 0x0748)
    p.rle(0x7631, 0x1200)
    for t in range(2):                    # L_4407 con b=2: DOS tercios
        p.rle(0x76C7, 0x2220 + 0x800 * t)
    for t in range(2):
        p.rle(0x775F, 0x0200 + 0x800 * t)
    p.rle(0x785D)
    corre_cuatro_pixeles(p)               # 0x7410..0x7462
    for i in range(0x180):
        p.vram[0x0AD0 + i] = 0xFE
    p.rle_ram(0x7818)                     # a la RAM, y de alli nadie lo sube
    p.rle(0x79FB)
    p.rle(0x84EF)
    p.rle(0x7671)
    p.rle(0x79CF if pertiga else 0x799E)  # el liston, solo en la pertiga
    suelo_del_salto(p, pertiga)
    atleta_en_la_salida(p, pertiga)
    # 0x74AB: con la prueba recien empezada, el rotulo de arriba es el RECORD
    # DEL MUNDO. El QUALIFY con la marca a batir lo pinta despues la escena 5,
    # ya fuera de monta_la_prueba, y por eso aqui no va.
    marcador_del_salto(p, pertiga)        # L_74CE y L_5777
    p.guion(0x57F1)                       # WORLD REC
    return p


def marca_del_liston(p, n):
    """L_5788: la altura del liston numero N, en BCD.

    Los nueve primeros salen de la tabla de 0x758D, apuntada DOS bytes por
    debajo para que el indice empiece en uno; del decimo en adelante ya no hay
    tabla y la altura se suma en BCD sobre la novena.
    """
    q = 0x758B - p.org + min(n, 9) * 2
    return p.rom[q] | (p.rom[q + 1] << 8)


def escribe_una_marca(p, destino, valor):
    """L_7566: dos cifras, el punto decimal en DOS tiles, y dos cifras.

        0x7566  ld b,001h / call L_4358      las dos primeras
        0x756d  ld a,01eh / WRTVRM / inc a   el punto, en el 0x1E y el 0x1F
        0x7578  ld b,001h / jp L_4358        y las dos ultimas
    """
    r = p.ram()
    r[0xE174 - p.RAM0] = valor & 0xFF
    r[0xE175 - p.RAM0] = (valor >> 8) & 0xFF
    cifras_bcd(p, destino, 0xE175, 1)
    p.vram[destino + 2] = 0x1E
    p.vram[destino + 3] = 0x1F
    cifras_bcd(p, destino + 4, 0xE174, 1)
    return p


def marcador_del_salto(p, pertiga):
    """L_74CE y L_5777: la marca a batir, el record del mundo y el 1UP.

    El montaje de 0x73D9 deja el marcador de arriba vacio. Lo llenan dos
    rutinas de fuera, y por eso hay que traerlas aqui:

        0x74ce  call es_la_pertiga            en el triple salto es otro
        0x74e5  call L_5788 / ld hl,03836h    la altura del liston de turno
        0x577c  ld hl,03846h                  el record del mundo, en la de abajo
        0x438f  ld hl,03832h / ld de,04561h   y el 1UP parpadeando, al lado

    El liston de turno es el (0xE073), que 0x4304 deja a UNO al empezar la
    partida, o sea la primera altura de la tabla: 5.65 m. Y el record del
    mundo de la pertiga son los tres bytes de 0xE05C, que INIT copia de
    0x40CF: 90 05 00, o sea 5.90 m -el de Sergei Bubka en 1985, que es el ano
    del cartucho-.
    """
    r = p.ram()
    for i in range(12):                   # 0x4095: los doce records de 0x40CF
        r[0xE053 + i - p.RAM0] = p.rom[0x40CF - p.org + i]
    if pertiga:
        escribe_una_marca(p, 0x3836, marca_del_liston(p, 1))
    record = 0xE05C if pertiga else 0xE056   # L_57AB
    cifras_bcd(p, 0x3846, record + 1, 1)     # L_577C, con su punto decimal
    p.vram[0x3848] = 0x1E
    p.vram[0x3849] = 0x1F
    cifras_bcd(p, 0x384A, record, 1)
    p.guion(0x4561, 0x3832)               # 0x43AA: el 1UP del jugador de turno
    return p


def corre_cuatro_pixeles(p):
    """0x7410..0x7460: el dibujo, corrido cuatro pixeles DENTRO de la RAM.

    Se descomprime a 0xE320 y alli se rotan los bits de doce tiles seguidos
    -de ocho en ocho bytes, que es la misma fila de tiles consecutivos- cuatro
    veces. Las dos versiones, la del sitio y la corrida, suben juntas a
    0x2B90: por eso la pista se mueve de medio tile en medio tile.

        0x7423  sla (ix+058h) / rl (ix+050h) / ... / rl (ix+000h)
    """
    p.rle_ram(0x785F, 0xE320)
    r = p.ram()
    base = 0xE320 - p.RAM0
    for bloque in range(2):
        ix = base + bloque * (0x58 + 0x8)
        for fila in range(8):
            for _ in range(4):
                acarreo = 0
                for k in range(11, -1, -1):        # de 0x58 hacia 0x00
                    o = ix + fila + k * 8
                    v = (r[o] << 1) | acarreo
                    acarreo = (v >> 8) & 1
                    r[o] = v & 0xFF
    p.ram_a_vram(0xE320, 0x2B90, 0xC0)


def casilla_de(h, l):
    """L_5FBC: de coordenadas de pixel a direccion de casilla.

    Son ocho rotaciones repartidas entre A y H, o sea dividir las dos
    coordenadas entre ocho a la vez, y el 0x38 del final es la base de la
    tabla de nombres. Se emula con su acarreo, que es lo que encadena las dos.
    """
    a, cy = l, 0
    for _ in range(4):
        a, cy = ((a >> 1) | (cy << 7)) & 0xFF, a & 1
    for _ in range(2):
        h, cy = ((h >> 1) | (cy << 7)) & 0xFF, h & 1
        a, cy = ((a >> 1) | (cy << 7)) & 0xFF, a & 1
    h, cy = ((h >> 1) | (cy << 7)) & 0xFF, h & 1
    return (((a & 3) + 0x38) << 8) | h


def franja(p, hl, n, tile):
    """L_5ED7: n casillas con el indice subiendo, y vuelta al principio de fila.

    Cuando los cinco bits de abajo de la direccion llegan a cero, la fila se ha
    acabado y se vuelve a su principio: por eso el suelo no se desborda a la
    fila de abajo.
    """
    d = hl
    for _ in range(n):
        p.vram[d & 0x3FFF] = tile & 0xFF
        tile += 1
        d += 1
        if not (d & 0x1F):
            d -= 0x20
    return d, tile


def suelo_del_salto(p, pertiga):
    """L_5DD5: las franjas de suelo, ejecutadas con el desplazamiento de salida.

    Se dibuja con (0xE129) en su valor de arranque, que es donde el atleta
    espera antes de correr. Y OJO al sentido: `es_la_pertiga` (0x5F0F) deja Z
    en el TRIPLE SALTO, asi que el 0x02BF de 0x53F4 es el del triple salto y
    el 0x017F de 0x53F9 el de la pertiga. Estaba al reves, y lo que se veia
    era el rotulo de la prueba y la grada corridos ocho casillas. Leido de la
    RAM del emulador: (0xE129) = 0x02BF en el triple salto y 0x017F en la
    pertiga.
    Son dos tramos, el segundo medio corrido respecto al primero:

        0x5DD5  ld a,(0e129h) / ld b,002h
        0x5DDD  ld b,051h / bit 2,a / jr z / ld b,046h
        0x5DEA  ld l,058h / ld c,003h   (triple salto)
        0x5DF0  ld l,030h / ld c,002h   (pertiga)
        0x5E13  add a,080h              el tramo siguiente
    """
    a = 0x7F if pertiga else 0xBF
    for _ in range(2):
        tile = 0x46 if (a >> 2) & 1 else 0x51
        h, l = a, (0x30 if pertiga else 0x58)
        c = 2 if pertiga else 3
        hl = casilla_de(h, l)
        while c:
            fin, tile = franja(p, hl, 3, tile)
            remate = (0x42 if pertiga else 0x43) - c
            p.vram[fin & 0x3FFF] = remate & 0xFF
            hl += 0x20
            c -= 1
        a = (a + 0x80) & 0xFF

    # El segundo grupo: cuatro tramos de dos casillas (0x5E18)
    a = 0x7F if pertiga else 0xBF
    for _ in range(4):
        tile = 0x44 if (a >> 2) & 1 else 0x4F
        hl = casilla_de(a, 0x28 if pertiga else 0x50)
        fin, tile = franja(p, hl, 2, tile)
        p.vram[fin & 0x3FFF] = 0x44
        a = (a + 0x40) & 0xFF

    # Y la tira larga de doce (0x5E46)
    a = ((0x7F if pertiga else 0xBF) + 0xA0) & 0xFF
    tile = 0x5A if (a >> 2) & 1 else 0x72
    if pertiga:
        tile = (tile + 0x0C) & 0xFF
    hl = casilla_de(a, 0x68 if pertiga else 0x78)
    fin, _ = franja(p, hl, 12, tile)
    p.vram[fin & 0x3FFF] = 0x0E

    # Y los patrones del suelo, que NO estan comprimidos en la ROM: se copian
    # de la RAM, y cual de los dos juegos lo decide el bit 2 del
    # desplazamiento, o sea a que altura de pixel ha quedado la pista.
    #
    #     0x5E75  ld a,(0e129h) / ld de,0e338h / bit 2,a / jr z / ld e,020h
    #     0x5E81  hl = 0x2A00 (triple salto) o 0x2200 (pertiga), bc = 0x18
    #     0x5E92  ld de,0e360h / bit 2,a / jr z / ld e,050h
    #     0x5E9E  hl = 0x3218, bc = 0x10
    a = 0x7F if pertiga else 0xBF
    medio = (a >> 2) & 1
    p.ram_a_vram(0xE320 if medio else 0xE338,
                 0x2200 if pertiga else 0x2A00, 0x18)
    p.ram_a_vram(0xE350 if medio else 0xE360, 0x3218, 0x10)
    return p


def atleta_en_la_salida(p, pertiga):
    """El atleta, montado con el motor de figuras de 0x6992.

    Los patrones se descomprimen a 0x1800 en el momento -por eso el cartucho
    puede tener cientos de posturas sin que quepan a la vez en la VRAM- y los
    atributos salen de las mismas piezas.

    Y cada prueba tiene su tabla, que es lo que las distingue. La posicion de
    salida no es inventada, son los cuatro bytes que L_5FD0 copia a 0xE131:

        0x6DE6  8A 31 00 00     fila 0x8A, columna 0x31, figura 0

    El triple salto arranca por 0x6BD9. La PERTIGA no: su primer estado es
    L_649B, la carrerilla con la pertiga en la mano, que compone el atleta de
    DOS tablas y le anade el sprite de la punta:

        0x64bb  ld de,06f7ah / ld b,083h     el dibujo de la pertiga
        0x64cf  el sprite 0: fila B, columna 0x33, patron 0x80, color 1
        0x64e0  ld de,06e15h                 y las piezas del atleta
        0x64e3  L_64E3: tres piezas desde el sprite 9, y las de 0x6B6A[figura]

    Las cinco piezas que salen -0x8CDD, 0x8CE9, 0x874B, 0x8614 y 0x8623, con
    colores A, A, 6, F y A- son exactamente las que el emulador tiene en los
    sprites 9 a 13 en el primer fotograma en que dibuja al atleta, y en las
    mismas filas y columnas. La tabla 0x6E33 es de otro estado, el del salto.
    """
    for i in range(32):                       # todos escondidos primero
        p.vram[0x3B00 + i * 4] = 0xC3
    q = 0x6DE6 - p.org
    fila, col, _, figura = p.rom[q:q + 4]
    if not pertiga:
        # L_65FC entra por 0x698C, o sea que las piezas van desde el SPRITE 9,
        # no desde el 0: los ocho primeros son de la pertiga y del festejo.
        p.figura(0x6BD9, figura, fila, col, sprite0=9)
        return p
    a = 0x3B00                                # 0x64CF: la punta de la pertiga
    p.vram[a] = 0x83
    p.vram[a + 1] = 0x33
    p.vram[a + 2] = 0x80
    p.vram[a + 3] = 0x01
    p.dibujo_relativo(0x6F7A)                 # 0x64DD: la pertiga, en casillas
    p.piezas(0x6E15, figura, fila, col, sprite0=9)
    return p


def curling(rom, org, base=None):
    """La pantalla del curling, la prueba 2.

    La monta L_A839, y es la mas cargada: el hielo de L_B6CD -con la mitad
    derecha ESPEJADA a mano, porque no esta guardada-, la casa dibujada con los
    rectangulos con recorte de L_AE8E y las tres piedras.

        0xa842  call L_B6CD          el hielo entero
        0xa8ae  ld hl,0afefh / ld de,0e400h / call L_74B5
        0xa8b1  ld de,05519h / call L_4442
        0xa8b7  ld de,0a919h / call L_4442
        0xa8bd  call L_AE8E          la casa y las rayas
    """
    p = base_de_texto(base if base is not None else Pantalla(rom, org))
    p.rle3(0x7658, 0x2030)                # 0x53B4: comun a las cuatro pruebas
    p.rle3(0x766C, 0x0030)
    marcador_de_arriba(p)
    p.rle(0xBB58)
    hielo(p)                              # L_B6CD
    p.rle_ram(0xAFEF, 0xE400)
    p.rle(0x5519)
    p.rle(0xA919)
    pista_de_hielo(p)                     # L_AE8E
    p.guion(0x96B5)
    p.guion(0xAC84)                       # TEMP
    p.guion(0xACA0)                       # SPEED, que aqui es la fuerza del tiro
    sprites_del_curling(p)
    return p


def hielo(p):
    """L_B6CD: los patrones de la pista, con las dos mitades espejadas.

        0xb6cd  ld hl,00880h / ld bc,00490h / ld a,05fh / FILVRM
        0xb6e1  ld de,0b754h / call L_4442
        0xb6e7  ld hl,02880h / ld de,0b772h / call L_4448
        0xb702  ld hl,02ac8h / ld de,0b772h / ld bc,00248h / call L_B72F
    """
    for i in range(0x490):
        p.vram[(0x0880 + i) & 0x3FFF] = 0x5F
    for i in range(0x3B8):
        p.vram[(0x1200 + i) & 0x3FFF] = 0x5F
    p.rle(0xB754)
    p.rle(0xB772, 0x2880)
    p.rle(0xB907, 0x3200)
    espejo(p, 0x2AC8, 0xB772, 0x248)      # L_B72F
    espejo(p, 0x3318, 0xB907, 0x118)
    p.rle3(0xBAC2, 0x2730)                # el circulo de la casa
    p.rle(0xB9C4)                         # con sus casillas
    p.rle3(0xBB4F, 0x0730)                # y su color
    p.rle(0xBB0E)
    return p


def espejo(p, destino, dato, n):
    """L_B72F: el bloque, con cada byte del reves.

    La pista de curling es simetrica, asi que la mitad derecha no esta
    guardada: se descomprime la izquierda a la RAM y se le da la vuelta a cada
    byte con ocho vueltas de `rl (hl) / rra`.

        0xb73d  ld b,008h / xor a
        0xb740  rl (hl) / rra / djnz
    """
    p.rle_ram(dato, 0xE400)
    r = p.ram()
    for i in range(n):
        b, a = r[0xE400 - p.RAM0 + i], 0
        for _ in range(8):
            a = ((a >> 1) | ((b & 0x80) and 0x80)) & 0xFF
            b = (b << 1) & 0xFF
        p.vram[(destino + i) & 0x3FFF] = a
    return p


def rectangulo_con_recorte(p, cab, otro, desp=0):
    """L_AF7C: un rectangulo de casillas, RECORTADO por los bordes de la vista.

    La cabecera son cinco bytes -columna en el mundo, ancho, alto y el destino
    de VRAM- y la figura trae dos juegos de datos del mismo tamano: el pegado
    detras de la cabecera y el `otro`, que llega en DE. Cual se usa lo decide
    el acarreo de `columna - desplazamiento`, o sea si esta cortada por la
    izquierda (0xAF9B).

    Y lo que importa: la columna es del MUNDO, no de la pantalla. La pista del
    curling es mucho mas ancha que las 32 casillas que se ven, asi que

        0xAFB7  cp 020h / ret nc          a la derecha del borde: NO se pinta
        0xAFAB  add a,c / ret nc / ret z  entera a la izquierda: tampoco

    Con la pista en su sitio -desplazamiento cero- la casa esta en la columna
    114 y el circulo grande en la 94: **ninguno de los dos se pinta**, y por
    eso la pantalla de arranque del curling es hielo liso. Estaban dibujados y
    era un error de lectura de esta rutina: 241 casillas de mas.
    """
    q = cab - p.org
    x, ancho, alto = p.rom[q], p.rom[q + 1], p.rom[q + 2]
    destino = (p.rom[q + 3] | (p.rom[q + 4] << 8)) & 0x3FFF
    # el juego de datos: el pegado si no esta cortada por la izquierda
    datos = (cab + 5 if x >= desp else otro) - p.org

    a = x - desp
    if a < 0:                             # cortada por la izquierda
        visible = a + ancho
        if visible <= 0:                  # fuera del todo
            return
        datos += ancho - visible          # el dibujo empieza mas alla
        ancho_ef = visible
    else:
        if a >= 0x20:                     # a la derecha de la vista
            return
        ancho_ef = min(ancho, 0x20 - a)
        destino = (destino + a) & 0x3FFF
    for f in range(alto):
        for c in range(ancho_ef):
            p.vram[(destino + f * 32 + c) & 0x3FFF] = p.rom[datos + c]
        datos += ancho
    return p


def pista_de_hielo(p):
    """L_AE8E: la casa y las rayas, con los rectangulos con recorte.

    Cada figura trae DOS juegos de datos del mismo tamano y se elige por el
    acarreo de la columna menos el desplazamiento. Con la pista en su sitio
    -desplazamiento cero- toca siempre el que va pegado a la cabecera.

        0xae98  ld hl,0b299h / ld de,0b2c8h / call L_AF78
        0xaea1  ld hl,0b07fh / ld de,0b174h / call L_AF78
        0xaeaa  ld hl,0b264h / ld de,0b281h / call L_AF78
    """
    for cab, otro in ((0xB299, 0xB2C8), (0xB07F, 0xB174), (0xB264, 0xB281)):
        rectangulo_con_recorte(p, cab, otro)
    fila_del_hielo(p)                     # L_AF51
    # La fila de arriba, que alterna dos tiles (0xAEB6)
    for c in range(32):
        p.vram[NOMBRES + 4 * 32 + c] = 0x80 + (c & 1)
    return p


def fila_del_hielo(p):
    """L_AF51: la franja que se desplaza, sacada del bloque de la RAM.

    Los tres bits de abajo del desplazamiento eligen entre DOS versiones del
    mismo dibujo, 0xE400 y 0xE478. Con la pista en su sitio toca la primera.

        0xaf51  ld hl,038c0h / call L_5EF0
        0xaf64  ld de,0e400h / jr nc / ld de,0e478h
        0xaf6f  ld b,020h / L_AF71: ld a,(de) / inc de / out (c),a / djnz
    """
    p.rle_ram(0xAFEF, 0xE400)
    p.ram_a_vram(0xE400, 0x38C0, 0x20)
    return p


def sprites_del_curling(p):
    """L_B40B y L_B453: los dos barrenderos y la piedra.

    Aqui las figuras no son las de cinco bytes del atleta: son las de la tabla
    de 0xB4AA, cuatro bytes por pieza -fila, columna, patron y color- y de
    cuatro a seis piezas segun la figura. Una fila de 0x80 en la tabla
    significa que la pieza no se pinta, y se le pone la 0xE0, que esta fuera.

    Y cada cosa va a SU hueco de la tabla, no una detras de otra: el jugador
    de arriba empieza en el sprite 5 y el de abajo en el 0, y entre medias
    quedan las escobas.

        0xb40b  ld de,0e194h / ld hl,0e240h   la figura del jugador 1
        0xb415  ld de,0e1a4h / ld hl,0e240h   y su escoba, dieciseis mas abajo
        0xb41e  ld de,0e180h / ld hl,0e250h   la figura del jugador 2
        0xb428  ld de,0e190h / ld hl,0e250h   y la suya
        0xa885  ld hl,0a911h / ld de,0e1a8h   los dos sprites de la raya
        0xb453  ld a,(0e233h) / ld de,0e1b0h / ld hl,0e260h   la piedra

    La escoba (L_B42E) no sale de la tabla de figuras: es UN sprite, con la
    fila del jugador mas 0x10, su misma columna, el patron que da 0xB5A2 y el
    color 0x0C fijo. Y solo se pinta mientras (0xE239) valga cero, o sea
    mientras la tirada no haya terminado.
    """
    for i in range(32):
        p.vram[0x3B00 + i * 4] = 0xC3
    r = p.ram()

    def pon(s, y, x, patron, color):
        a = 0x3B00 + s * 4
        p.vram[a], p.vram[a + 1] = y & 0xFF, x & 0xFF
        p.vram[a + 2], p.vram[a + 3] = patron, color

    # Los tres estados que monta_el_curling deja puestos, con su hueco:
    # 0xE240 -> sprites 5 y 9, 0xE250 -> 0 y 4, 0xE260 -> 12 (0xA864, 0xA86A,
    # 0xA87A y 0xA880).
    for fila, col, figura, s0, escoba in ((0x30, 0x40, 0x01, 5, 9),
                                          (0x80, 0x54, 0x04, 0, 4),
                                          (0x5C, 0x43, 0x06, 12, None)):
        a = (figura * 16) & 0xFF
        if a >= 0x80:
            a += 4
        q = 0xB4AA - p.org + a
        piezas = 4 + (figura == 0x0E) + (figura == 0x07)
        for i in range(piezas):
            f = p.rom[q]
            pon(s0 + i, 0xE0 if f == 0x80 else f + fila, p.rom[q + 1] + col,
                p.rom[q + 2], p.rom[q + 3])
            q += 4
        if escoba is not None:                 # L_B42E
            pon(escoba, fila + 0x10, col, p.rom[0xB5A2 - p.org], 0x0C)
    for i in range(8):                         # 0xA885: los dos de la raya
        p.vram[0x3B00 + 10 * 4 + i] = p.rom[0xA911 - p.org + i]
    return p


def lamina_del_ciclista(rom, org):
    """Los dos ciclistas del ciclismo, con sus OCHO copias corridas.

    El ciclista no es un sprite: son seis casillas de la tabla de patrones -dos
    columnas por tres filas, la tercera es la mascara- y para moverlo al pixel
    el cartucho genera ocho versiones del mismo dibujo, cada una corrida una
    posicion mas. Aqui se ponen las dieciseis en fila para verlas: arriba el
    dibujo de 0x9D14 y abajo el de 0x9D34.

    Se dibujan las cuatro casillas que el juego pinta de verdad (L_A3A9), o sea
    sin la fila de la mascara.
    """
    p = base_de_texto(Pantalla(rom, org))
    ciclistas_en_ocho_pasos(p)
    for i in range(0x300):
        p.vram[NOMBRES + i] = 0
    for i in range(32):
        p.vram[0x3B00 + i * 4] = 0xC3
    # los tiles: el primer dibujo arranca en 0x9A y el segundo en 0xCA, y cada
    # copia son seis tiles
    for dibujo in range(2):
        base = 0xA0 + dibujo * 0x30
        for copia in range(8):
            t = base + copia * 6
            f = 6 + dibujo * 6
            c = 2 + copia * 3
            p.vram[NOMBRES + f * 32 + c] = t
            p.vram[NOMBRES + f * 32 + c + 1] = t + 2
            p.vram[NOMBRES + (f + 1) * 32 + c] = t + 1
            p.vram[NOMBRES + (f + 1) * 32 + c + 1] = t + 3
    return p


def lamina_de_sprites(rom, org):
    """Las figuras del atleta, todas, puestas en rejilla.

    No es una pantalla del juego: es el contenido de las tres tablas de
    figuras -0x6BD9 el triple salto, 0x6E33 la pertiga y 0x6D5C el festejo-
    montado una al lado de otra con el mismo motor de 0x6992, para poder verlas
    de un vistazo. Cada una descomprime sus propios patrones, asi que en la
    pantalla de verdad nunca coinciden mas de una.
    """
    p = base_de_texto(Pantalla(rom, org))
    for i in range(0x300):
        p.vram[NOMBRES + i] = 0
    for i in range(32):
        p.vram[0x3B00 + i * 4] = 0xC3
    return p


def cuantas_figuras(rom, org, tabla):
    """Cuantas entradas tiene una tabla de figuras.

    No hay ningun byte que lo diga: la tabla ACABA justo donde empieza su
    entrada mas baja, o sea que los punteros se comen su propio final. Se lee
    hasta que la direccion alcanza a la primera figura.
    """
    q = tabla - org
    fin = rom[q] | (rom[q + 1] << 8)
    n = 0
    while tabla + n * 2 < fin:
        d = rom[q + n * 2] | (rom[q + n * 2 + 1] << 8)
        fin = min(fin, d)
        n += 1
    return n


def figuras_de_una_tabla(rom, org, tabla, cuantas, titulo_txt):
    """Una lamina con las figuras de UNA tabla, en filas de cinco.

    El VDP solo pinta cuatro sprites por linea, asi que la rejilla se dibuja a
    mano sobre los pixeles en vez de dejarsela al pintor de sprites: aqui no
    hay hardware que respetar, se trata de VER los datos.
    """
    px = [[(0, 0, 0)] * 256 for _ in range(192)]
    cols = 5
    for n in range(cuantas):
        p = Pantalla(rom, org)
        p.figura(tabla, n, 0x20, 0x20)
        fx, fy = (n % cols) * 48 + 10, (n // cols) * 60 + 30
        # se pinta cada pieza a mano, leyendo sus atributos
        for s in range(32):
            a = 0x3B00 + s * 4
            y, x, patron, color = (p.vram[a], p.vram[a + 1],
                                   p.vram[a + 2], p.vram[a + 3])
            if y in (0xC3, 0xD0) or not (color & 15):
                continue
            c = PALETA[color & 15]
            base = 0x1800 + (patron & 0xFC) * 8
            for cuarto in range(4):
                dx, dy = 8 * (cuarto // 2), 8 * (cuarto % 2)
                for f in range(8):
                    b = p.vram[base + cuarto * 8 + f]
                    for k in range(8):
                        if not (b >> (7 - k)) & 1:
                            continue
                        yy = fy + (y - 0x20) + dy + f
                        xx = fx + (x - 0x20) + dx + k
                        if 0 <= yy < 192 and 0 <= xx < 256:
                            px[yy][xx] = c
    return px


def fuente(rom, org):
    """Los 256 patrones del primer tercio, en rejilla, para verlos todos."""
    p = base_de_texto(Pantalla(rom, org))
    p.rle3(0x4773, 0x2200)
    p.rle3(0x48AD, 0x2580)
    p.rle3(0x4A88, 0x0580)
    for i in range(256):
        p.vram[NOMBRES + i] = i
    return p


def main():
    rom = open(sys.argv[1], "rb").read()
    org = int(sys.argv[2], 0)
    salida = sys.argv[3]
    os.makedirs(salida, exist_ok=True)
    pruebas = (
        ("logotipo", logotipo), ("titulo", titulo), ("fuente", fuente),
        ("ciclismo", lambda r, o: sobre_el_titulo(r, o, ciclismo)),
        ("curling", lambda r, o: sobre_el_titulo(r, o, curling)),
        ("triple-salto",
         lambda r, o: sobre_el_titulo(
             r, o, lambda a, b, base=None: salto(a, b, False, base))),
        ("sprites-ciclista", lamina_del_ciclista),
        ("pertiga",
         lambda r, o: sobre_el_titulo(
             r, o, lambda a, b, base=None: salto(a, b, True, base))),
    )
    for nombre, fn in pruebas:
        p = fn(rom, org)
        px = p.imagen()
        p.sprites(px)
        ruta = os.path.join(salida, nombre + ".png")
        png(ruta, px)
        print("  %-16s -> %s" % (nombre, ruta))
    # Las laminas de figuras, que no son pantallas del juego
    for nombre, tabla in (("sprites-triple-salto", 0x6BD9),
                          ("sprites-pertiga", 0x6E33),
                          ("sprites-festejo", 0x6D5C)):
        cuantas = cuantas_figuras(rom, org, tabla)
        px = figuras_de_una_tabla(rom, org, tabla, cuantas, nombre)
        ruta = os.path.join(salida, nombre + ".png")
        png(ruta, px)
        print("  %-16s -> %s  (%d figuras)" % (nombre, ruta, cuantas))


if __name__ == "__main__":
    main()
