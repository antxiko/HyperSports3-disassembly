#!/usr/bin/env python3
"""El CONTENIDO de la portada: los hallazgos y los pies de la galeria.

Va aparte de make_web.py a proposito. make_web.py es el generador -la
plantilla, la maquetacion, el HTML- y no cambia de un juego al siguiente; esto
es lo unico que hay que reescribir entero en cada cartucho. Teniendolo separado
no hay que ir buscando los textos del juego anterior dentro del generador, que
es justo como se han colado los nombres equivocados otras veces.

Cada hallazgo es (titulo, html) y cada entrada de galeria
(fichero, pie en castellano, pie en ingles).

Todas las cifras de aqui estan medidas sobre este cartucho, con las
herramientas de tools/, y no copiadas de ningun otro proyecto.
"""

HALLAZGOS = {
    "es": [
        ("Los records del mundo viven en la RAM, y por eso se pueden batir",
         "<p>Los doce bytes que INIT copia de <code>0x40CF</code> a "
         "<code>0xE053</code> son las cuatro marcas a batir: <b>1'45\"34</b> en "
         "el ciclismo, <b>17,97 m</b> en el triple salto, <b>100 puntos</b> en "
         "el curling y <b>5,90 m</b> en la pertiga. Son los unicos valores de "
         "toda la RAM de trabajo que no arrancan a cero.</p>"
         "<p>Estan en RAM y no en ROM porque el juego los <b>sobrescribe</b>: "
         "<code>0x93D1</code> mete el tiempo del ciclista encima del record en "
         "cuanto se mejora. La ROM no guarda ningun record: guarda el valor de "
         "salida, y a partir de ahi la marca a batir es la del jugador.</p>"),

        ("La demostracion es una partida GRABADA",
         "<p>La demostracion no la juega una maquina: la reproduce. Cada prueba "
         "tiene su cinta de mandos guardada en la ROM y el bucle la va soltando "
         "fotograma a fotograma como si fuera el mando. Por eso la "
         "demostracion hace siempre exactamente lo mismo, con las mismas "
         "marcas.</p>"
         "<p>Y hay una excepcion que se nota: <b>el ciclismo no tiene "
         "grabacion</b>. Ahi el rival se mueve con <code>ld a,r</code> -el "
         "registro de refresco de la DRAM, que va subiendo con cada "
         "instruccion- usado como dado. Es la unica prueba en la que la "
         "demostracion no sale igual dos veces.</p>"),

        ("Seno y coseno de verdad, en un cartucho de deportes",
         "<p>La tabla de <code>0x7346</code> no es una curva a ojo: son "
         "<b>noventa grados de seno</b>, un byte por grado, con el 0xFF en el "
         "noventa. Con ella y un desplazamiento de un cuarto de vuelta salen "
         "las dos componentes de cualquier angulo.</p>"
         "<p>Y en el curling ni siquiera se calcula el angulo: las dos curvas "
         "de la piedra <b>normalizan el vector</b> -lo dividen por su modulo "
         "aproximado- y se quedan con las dos componentes. La piedra sale "
         "recta sin que el cartucho sepa nunca cuantos grados lleva.</p>"),

        ("La tabla de periodos tiene DOCE valores, no diez",
         "<p>La tabla de periodos del sonido parecia tener diez entradas y "
         "sobraban dos indices que nadie sabia de donde salian. Los dos que "
         "faltaban estan <b>escondidos en la entrada [0] de la tabla de "
         "pistas</b>, la que se daba por muerta porque ninguna pista la usa: "
         "sus dos bytes son la continuacion de la tabla de al lado.</p>"
         "<p>Es el mismo truco que el de la tabla de listones de la pertiga, "
         "apuntada <b>dos bytes por debajo</b> para que el indice empiece en "
         "uno en vez de en cero. Dos bytes ahorrados, dos veces.</p>"),

        ("Tres trucos de desplazamiento distintos, uno por prueba",
         "<p>Las cuatro pruebas mueven la pantalla, y ninguna lo hace igual:</p>"
         "<p>El <b>ciclismo</b> no tiene el circuito en la VRAM. Vive en dos "
         "ventanas de la RAM -<code>0xE140</code> y <code>0xE260</code>, nueve "
         "filas de treinta y dos casillas- que se desplazan una columna por "
         "fotograma y se vuelcan enteras. Y el ciclista tampoco es un sprite: "
         "son <b>cuatro casillas</b> de la tabla de patrones, con <b>ocho "
         "copias del dibujo corridas un pixel cada una</b> generadas al "
         "arrancar la prueba rotando los bits.</p>"
         "<p>El <b>salto</b> -triple y pertiga- guarda la pista dos veces, en "
         "su sitio y corrida cuatro pixeles, y alterna: por eso se mueve de "
         "medio tile en medio tile. El corrimiento se hace en la RAM, con "
         "<code>sla</code> y <code>rl</code> encadenados sobre doce tiles "
         "seguidos.</p>"
         "<p>Y el <b>curling</b> no guarda media pista: la mitad derecha del "
         "hielo esta <b>espejada a mano</b>, bit a bit, al montarla.</p>"),

        ("La marca oculta de Konami, tambien aqui",
         "<p>Los ultimos dieciseis bytes del cartucho -<code>0xBFF0</code> a "
         "<code>0xBFFF</code>- llevan el titulo del juego en <b>katakana y del "
         "reves</b>: ハイパースポーツ3, su longitud (0x0D), el <b>0x33</b> del "
         "RC-733 y un 0xAA que cierra. <b>No lo lee nadie</b>: no hay una sola "
         "instruccion del cartucho que apunte ahi.</p>"
         "<p>La marca la descubrio <b>Manuel Pazos</b>, y esta en muchos de los "
         "cartuchos de Konami de estos anos. Aqui esta entera y cuadra con el "
         "numero de catalogo.</p>"),
    ],
    "en": [
        ("The world records live in RAM, which is why they can be beaten",
         "<p>The twelve bytes INIT copies from <code>0x40CF</code> to "
         "<code>0xE053</code> are the four marks to beat: <b>1'45\"34</b> for "
         "cycling, <b>17.97 m</b> for the triple jump, <b>100 points</b> for "
         "curling and <b>5.90 m</b> for the pole vault. They are the only "
         "values in the whole work RAM that do not start at zero.</p>"
         "<p>They sit in RAM rather than ROM because the game <b>overwrites "
         "them</b>: <code>0x93D1</code> writes the cyclist's time straight over "
         "the record as soon as it is improved. The ROM holds no record at all: "
         "it holds a starting value, and from then on the mark to beat is the "
         "player's own.</p>"),

        ("The demo is a RECORDED game",
         "<p>The demo is not played by a machine, it is replayed. Each event "
         "has its own tape of controller readings stored in ROM, and the loop "
         "feeds it frame by frame as if it were the joystick. That is why the "
         "demo always does exactly the same thing, down to the marks.</p>"
         "<p>And there is one exception you can see: <b>cycling has no "
         "recording</b>. There the rival moves off <code>ld a,r</code> -the "
         "DRAM refresh register, which climbs with every instruction- used as a "
         "die. It is the only event whose demo never comes out the same "
         "twice.</p>"),

        ("Real sine and cosine, in a sports cartridge",
         "<p>The table at <code>0x7346</code> is not a curve drawn by eye: it "
         "is <b>ninety degrees of sine</b>, one byte per degree, with 0xFF at "
         "ninety. With it and a quarter-turn offset you get both components of "
         "any angle.</p>"
         "<p>And in curling the angle is never worked out at all: the stone's "
         "two curves <b>normalise the vector</b> -divide it by its approximate "
         "modulus- and keep the two components. The stone travels straight "
         "without the cartridge ever knowing how many degrees it is on.</p>"),

        ("The period table has TWELVE values, not ten",
         "<p>The sound period table looked like it had ten entries, and two "
         "indices were left over that nobody could place. The two missing ones "
         "are <b>hidden inside entry [0] of the track table</b>, the one "
         "written off as dead because no track uses it: its two bytes are the "
         "continuation of the table next door.</p>"
         "<p>It is the same trick as the pole vault bar table, pointed at "
         "<b>two bytes low</b> so the index can start at one instead of zero. "
         "Two bytes saved, twice.</p>"),

        ("Three different scrolling tricks, one per event",
         "<p>All four events move the screen, and no two do it the same way:</p>"
         "<p><b>Cycling</b> does not keep the circuit in VRAM at all. It lives "
         "in two RAM windows -<code>0xE140</code> and <code>0xE260</code>, nine "
         "rows of thirty-two tiles- that shift one column per frame and are "
         "dumped whole. And the cyclist is not a sprite either: he is <b>four "
         "tiles</b> from the pattern table, with <b>eight copies of the drawing "
         "each shifted one pixel</b>, generated when the event starts by "
         "rotating the bits.</p>"
         "<p>The <b>jumps</b> -triple and pole vault- store the track twice, in "
         "place and shifted four pixels, and alternate: that is why it moves "
         "half a tile at a time. The shifting is done in RAM, with chained "
         "<code>sla</code> and <code>rl</code> across twelve consecutive "
         "tiles.</p>"
         "<p>And <b>curling</b> does not store half a rink: the right half of "
         "the ice is <b>mirrored by hand</b>, bit by bit, as it is built.</p>"),

        ("Konami's hidden mark, here too",
         "<p>The last sixteen bytes of the cartridge -<code>0xBFF0</code> to "
         "<code>0xBFFF</code>- carry the game's title in <b>katakana, "
         "backwards</b>: ハイパースポーツ3, its length (0x0D), the <b>0x33</b> "
         "of RC-733 and an 0xAA to close. <b>Nothing reads it</b>: not one "
         "instruction in the cartridge points there.</p>"
         "<p>The mark was discovered by <b>Manuel Pazos</b>, and it is in many "
         "of Konami's cartridges from these years. Here it is complete and it "
         "matches the catalogue number.</p>"),
    ],
}

GALERIA = [
    ("rotulo.png",
     "La pantalla de titulo, montada paso a paso como la monta el cartucho. El "
     "rotulo grande no es una imagen guardada aparte: son tres bloques "
     "comprimidos que se descomprimen a la tabla de patrones y una tira de "
     "casillas consecutivas encima. Cotejada contra la VRAM de openMSX: cero "
     "bytes distintos en color, patrones y patrones de sprite.",
     "The title screen, built step by step the way the cartridge builds it. "
     "The big lettering is not a picture stored on its own: it is three "
     "compressed blocks decompressed into the pattern table with a strip of "
     "consecutive tiles laid over them. Checked against openMSX's VRAM: zero "
     "bytes different in colour, patterns and sprite patterns."),

    ("ciclismo.png",
     "El ciclismo, la prueba 0, en el instante en que arranca la carrera. Es "
     "la unica pantalla del cartucho que cierra a <b>cero bytes distintos en "
     "las cuatro tablas Y en los atributos de sprite</b>: los 15.104 bytes de "
     "VRAM y los 128 de sprites, identicos a los del emulador. Los dos "
     "ciclistas son cuatro casillas cada uno mas cinco sprites; el circuito no "
     "esta en la VRAM sino en dos ventanas de la RAM.",
     "Cycling, event 0, at the instant the race starts. It is the only screen "
     "in the cartridge that closes at <b>zero bytes different across all four "
     "tables AND the sprite attributes</b>: 15,104 bytes of VRAM and 128 of "
     "sprites, identical to the emulator's. Each cyclist is four tiles plus "
     "five sprites; the circuit is not in VRAM at all but in two RAM windows."),

    ("triple-salto.png",
     "El triple salto, la prueba 1, con el atleta en la salida. El marcador de "
     "arriba dice la marca del mundo -17,97 m- y la del jugador. La pista se "
     "guarda dos veces, en su sitio y corrida cuatro pixeles, y el atleta son "
     "hasta siete sprites de 16x16 cuyos patrones se descomprimen a la VRAM en "
     "cada fotograma.",
     "The triple jump, event 1, with the athlete on the mark. The scoreboard "
     "up top shows the world record -17.97 m- and the player's own. The runway "
     "is stored twice, in place and shifted four pixels, and the athlete is up "
     "to seven 16x16 sprites whose patterns are decompressed into VRAM on "
     "every single frame."),

    ("curling.png",
     "El curling, la prueba 2, recien montado. La mitad derecha del hielo no "
     "esta guardada en ninguna parte: se <b>espeja a mano</b>, bit a bit, al "
     "montar la pantalla. Los circulos de la casa se dibujan con una rutina de "
     "rectangulos con recorte, y en el arranque quedan fuera de la vista.",
     "Curling, event 2, just built. The right half of the ice is stored "
     "nowhere: it is <b>mirrored by hand</b>, bit by bit, as the screen is put "
     "together. The house rings are drawn by a clipped-rectangle routine, and "
     "at the start they fall outside the view."),

    ("pertiga.png",
     "El salto con pertiga, la prueba 3, en el primer fotograma de la "
     "carrerilla. El atleta no sale de una tabla de figuras: se compone de DOS "
     "bloques -tres piezas de 0x6E15 y las de 0x6B6A- mas el sprite de la "
     "punta y las doce casillas de la propia pertiga. Los seis sprites y sus "
     "patrones son identicos byte a byte a los del emulador.",
     "The pole vault, event 3, on the first frame of the run-up. The athlete "
     "does not come out of a figure table: he is composed from TWO blocks "
     "-three pieces from 0x6E15 and the ones at 0x6B6A- plus the sprite for "
     "the tip and the twelve tiles of the pole itself. All six sprites and "
     "their patterns are byte-for-byte identical to the emulator's."),

    ("sprites-ciclista.png",
     "Las dieciseis versiones del ciclista, dibujadas desde la ROM: dos "
     "dibujos de 16x16 y, de cada uno, <b>ocho copias corridas un pixel</b>. No "
     "estan guardadas: las genera 0x9CC7 al arrancar la prueba, rotando los "
     "bits y metiendo unos por delante para sacar de paso la mascara. Asi el "
     "ciclista se mueve al pixel siendo casillas.",
     "The sixteen versions of the cyclist, drawn from the ROM: two 16x16 "
     "drawings and, from each, <b>eight copies shifted one pixel</b>. They are "
     "not stored: 0x9CC7 generates them when the event starts, rotating the "
     "bits and feeding ones in from the left to get the mask for free. That is "
     "how a tile-based cyclist moves pixel by pixel."),

    ("sprites-triple-salto.png",
     "Las catorce figuras del atleta del triple salto, sacadas de la tabla de "
     "0x6BD9. Cada figura son de dos a siete piezas de cinco bytes -fila y "
     "columna relativas, puntero al patron y color- con un 0x80 que cierra. El "
     "patron no esta puesto de antes: se descomprime a la VRAM en el momento.",
     "The fourteen figures of the triple jump athlete, taken from the table at "
     "0x6BD9. Each figure is two to seven five-byte pieces -relative row and "
     "column, pattern pointer and colour- closed by an 0x80. The pattern is "
     "not sitting there beforehand: it is decompressed into VRAM on the "
     "spot."),

    ("sprites-pertiga.png",
     "Las ocho figuras de la tabla de 0x6E33, la del salto propiamente dicho. "
     "La carrerilla no las usa: esa se compone de otros dos bloques. Y una de "
     "ellas tiene una pieza con color 0 -transparente- fuera de la pantalla, "
     "que sigue sin explicacion.",
     "The eight figures in the table at 0x6E33, the one for the vault itself. "
     "The run-up does not use them: that one is composed from two other "
     "blocks. And one of them has a piece with colour 0 -transparent- off the "
     "screen, still unexplained."),

    ("sprites-festejo.png",
     "Las seis figuras del festejo de 0x6D5C, las que salen cuando el salto "
     "vale. Son las unicas del atleta que no se dibujan durante la prueba.",
     "The six celebration figures at 0x6D5C, the ones that come out when the "
     "jump counts. They are the only athlete figures never drawn during the "
     "event itself."),

    ("fuente.png",
     "La fuente del cartucho, dibujada desde sus patrones. No es ASCII: el "
     "0x00 es el espacio, los digitos van del 0x10 al 0x19 y las letras "
     "arrancan en el 0x21. Por eso los rotulos del juego se leen como una "
     "sarta de bytes raros hasta que se traducen.",
     "The cartridge's font, drawn from its own patterns. It is not ASCII: 0x00 "
     "is the space, the digits run from 0x10 to 0x19 and the letters start at "
     "0x21. That is why the game's labels read as a string of odd bytes until "
     "you translate them."),
]
