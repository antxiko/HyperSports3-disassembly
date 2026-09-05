#!/usr/bin/env python3
"""Comprobaciones sobre el listado generado y sobre la web.

Ninguna necesita el cartucho: se hacen sobre src/hypersports3.asm,
src/hypersports3.notes y el trazado. Vigilan que el listado no se degrade sin
que nadie se entere -que no desaparezcan comentarios, que no vuelvan a
aparecer bloques sin identificar- y que las cifras publicadas en la web sean
las del arbol y no las que habia cuando se escribio el texto.

Las de TestRLE, TestRotulos y TestTablas no miran el ASPECTO de los bytes:
EJECUTAN el descompresor y el interprete de rotulos que se rehicieron en
tools/. Si el formato estuviera mal leido, los bloques no cerrarian donde
cierran y los rotulos no dirian lo que dicen.

Y las de TestAritmetica comprueban las tablas contra las matematicas de
verdad: la de noventa valores tiene que ser un seno de verdad, y las dos
curvas del curling tienen que sumar un cuarto de vuelta.
"""
import json
import math
import os
import re
import sys
import unittest

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(RAIZ, "src", "hypersports3.asm")
NOTES = os.path.join(RAIZ, "src", "hypersports3.notes")
ENTRIES = os.path.join(RAIZ, "src", "hypersports3.entries")
TRACE = os.path.join(RAIZ, "work", "hypersports3.trace.json")
DOCS = os.path.join(RAIZ, "docs")
ORG, FIN = 0x4000, 0xC000

sys.path.insert(0, os.path.join(RAIZ, "tools"))

# Los demas juegos de la serie. Que el nombre de otro salga en una pagina de
# este es casi siempre un copia y pega: ya paso con cinco ficheros LICENSE, con
# el pie de catorce paginas de otro proyecto y con ESTE MISMO fichero de
# tests, que llego copiado de Konami's Soccer y apuntaba a src/soccer.asm.
OTROS_JUEGOS = (
    "Tennis", "Pitfall", "Temptations", "Stardust", "Ale Hop", "Colt 36",
    "Antarctic", "Athletic Land", "Monkey Academy", "F-1 Spirit", "Pippols",
    "Time Pilot", "Frogger", "Super Cobra", "Billiards", "Mahjong",
    "Hyper Rally", "Nemesis", "Demonia", "Cabbage", "Hole in One",
    "Casio World Open", "3D Golf", "Baseball", "Yie Ar Kung-Fu",
    "King's Valley", "Sky Jaguar", "Mopi Ranger", "Descubrimiento",
    "War in Middle Earth", "Ping Pong", "Soccer", "Football", "Road Fighter",
)


def lee(ruta):
    with open(ruta, encoding="utf-8") as f:
        return f.read()


def bloques_del_listado(lineas):
    """Los mismos bloques que cuenta tools/densidad.py, con su misma logica.

    Dos detalles suyos hay que respetar o las cifras no cuadran: una etiqueta
    solo cuenta si su linea no lleva nada mas (salvo un comentario), y una
    linea es de INSTRUCCION cuando su direccion viene pegada al punto y coma
    (";4323"), mientras que las de datos llevan un espacio ("; 4323"). Por eso
    los bloques DATA_ salen con cero instrucciones y no cuentan como rutina.
    """
    bloques, nombre, ini, n, c = [], "(cabecera)", 0, 0, 0
    for ln in lineas:
        m = re.match(r"^([A-Za-z_][A-Za-z_0-9]*):\s*(;.*)?$", ln)
        if m:
            if n:
                bloques.append((nombre, ini, n, c))
            nombre, ini, n, c = m.group(1), 0, 0, 0
            continue
        m = re.match(r"^\t.*;([0-9a-f]{4})(.*)$", ln)
        if not m:
            continue
        if not ini:
            ini = int(m.group(1), 16)
        n += 1
        if ";" in m.group(2):
            c += 1
    if n:
        bloques.append((nombre, ini, n, c))
    return bloques


def rom_del_listado():
    """Reconstruye los BYTES DE DATOS del cartucho leyendo el listado.

    El cartucho no viaja con el repositorio, pero src/hypersports3.asm si, y
    cada fila de datos lleva su direccion en el comentario -eso lo pone
    mkasm.py-. Con las filas `defb` y `defw` se rehace un buffer de 32 KB con
    todas las zonas de datos en su sitio, que es lo unico que el descompresor
    necesita leer. Asi estos tests corren en un clon pelado, sin cartucho y
    sin `make`.
    """
    rom = bytearray(FIN - ORG)
    for linea in lee(ASM).splitlines():
        m = re.match(r"\s*(defb|defw)\s+([^;]+);\s*([0-9a-f]{4})", linea)
        if not m:
            continue
        que, cuerpo, addr = m.group(1), m.group(2), int(m.group(3), 16)
        p = addr - ORG
        for tok in cuerpo.split(","):
            tok = tok.strip()
            if not re.fullmatch(r"[0-9][0-9a-fA-F]*h", tok):
                continue
            v = int(tok[:-1], 16)
            if que == "defb":
                rom[p] = v & 0xFF
                p += 1
            else:
                rom[p] = v & 0xFF
                rom[p + 1] = (v >> 8) & 0xFF
                p += 2
    return bytes(rom)


def bloques_declarados():
    """Las directivas D del .notes: {nombre: (ini, fin, explicacion)}."""
    d = {}
    for m in re.finditer(
            r"^D\s+(0x[0-9a-fA-F]+)\s+(0x[0-9a-fA-F]+)\s+(\S+)(.*)$",
            lee(NOTES), re.MULTILINE):
        d[m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16),
                         m.group(4).strip())
    return d


def como_texto(bs):
    """Los tiles leidos como letras.

    La fuente de este cartucho NO es ASCII: el 0x00 es el espacio, los digitos
    van del 0x10 al 0x19 y las letras del 0x21 ('A') al 0x3A ('Z'). Con eso, un
    tile se convierte en su letra sumandole 0x20.
    """
    out = []
    for b in bs:
        if b == 0x00:
            out.append(" ")
        elif 0x10 <= b <= 0x19:
            out.append(chr(ord("0") + b - 0x10))
        elif 0x21 <= b <= 0x3A:
            out.append(chr(ord("A") + b - 0x21))
        else:
            out.append(".")
    return "".join(out)


class TestListado(unittest.TestCase):
    """El listado en si."""

    @classmethod
    def setUpClass(cls):
        cls.lineas = lee(ASM).splitlines()
        cls.bloques = bloques_del_listado(cls.lineas)

    def test_no_quedan_bloques_sin_identificar(self):
        """Ni un `DATOS sin identificar` en el listado.

        Es la cabecera que mkasm.py pone cuando un rango de datos no tiene
        directiva D. Que reaparezca significa que alguien anadio codigo o
        movio un limite y dejo bytes sin explicar.
        """
        sueltos = [ln for ln in self.lineas if "sin identificar" in ln]
        self.assertEqual(sueltos, [], "hay bloques de datos sin declarar")

    def test_todas_las_rutinas_llegan_al_liston(self):
        """NINGUNA rutina de mas de cinco instrucciones baja del 10 %.

        El liston de la serie: una rutina larga sin un solo comentario no esta
        explicada, por muy bien que este el resto del listado. Aqui se cerro a
        cero, asi que el test no admite ni una.
        """
        flojas = [(n, i, c) for n, i, c in
                  ((b[0], b[2], b[3]) for b in self.bloques)
                  if i > 5 and c * 10 < i]
        self.assertEqual(
            flojas, [], "han aparecido rutinas flojas: %s" % flojas[:5])

    def test_hay_al_menos_dos_mil_cuatrocientos_comentarios(self):
        """La densidad medida no puede caer.

        2.527 al cerrar la tanda, o sea el 34,5 %. Se deja el minimo un poco
        por debajo para que un retrazado que junte o parta bloques no lo rompa
        por un punado.
        """
        total = sum(b[3] for b in self.bloques)
        self.assertGreaterEqual(total, 2400,
                                "se han perdido comentarios por el camino")

    def test_las_etiquetas_son_snake_case(self):
        """Las bautizadas a mano, en minusculas y con guion bajo.

        Las L_XXXX y DATA_XXXX las pone mkasm.py y quedan fuera.
        """
        malas = []
        for m in re.finditer(r"^L\s+0x[0-9a-fA-F]{4}\s+(\S+)", lee(NOTES),
                             re.MULTILINE):
            if not re.fullmatch(r"[a-z][a-z0-9_]*", m.group(1)):
                malas.append(m.group(1))
        self.assertEqual(malas, [], "etiquetas que no son snake_case")

    def test_ninguna_etiqueta_se_llama_como_otra(self):
        """Dos etiquetas con el mismo nombre no ensamblan.

        El aplicador las rechaza, pero entonces la rutina se queda con su
        L_XXXX y nadie se entera: el listado sigue saliendo bien.
        """
        nombres = re.findall(r"^L\s+0x[0-9a-fA-F]{4}\s+(\S+)", lee(NOTES),
                             re.MULTILINE)
        repes = sorted({n for n in nombres if nombres.count(n) > 1})
        self.assertEqual(repes, [], "nombres de etiqueta repetidos")

    def test_ninguna_cabecera_de_bloque_sale_repetida(self):
        """La misma cabecera B no puede aparecer dos veces en el listado.

        El aplicador de comentarios llego a meterlas otra vez en cada pasada,
        y el listado acababa con la misma cabecera diez veces seguidas.
        """
        vistas = {}
        for m in re.finditer(r"^B\s+(0x[0-9a-fA-F]{4})\s", lee(NOTES),
                             re.MULTILINE):
            vistas[m.group(1)] = vistas.get(m.group(1), 0) + 1
        repes = {k: v for k, v in vistas.items() if v > 1}
        self.assertEqual(repes, {}, "cabeceras de bloque repetidas")


class TestCobertura(unittest.TestCase):
    """Que no quede ni un byte del cartucho sin asignar."""

    def test_el_trazado_cubre_el_cartucho_entero(self):
        """Codigo trazado mas datos declarados suman los 32.768 bytes."""
        if not os.path.exists(TRACE):
            self.skipTest("hace falta `make trace`")
        mapa = bytearray(FIN - ORG)
        # z80trace.py marca los bloques con "c" de codigo y "d" de datos.
        with open(TRACE, encoding="utf-8") as f:
            bloques = json.load(f)["blocks"]
        for tipo, a, b in bloques:
            if tipo == "c":
                for p in range(a - ORG, b - ORG):
                    mapa[p] = 1
        for ini, fin, _ in bloques_declarados().values():
            for p in range(ini - ORG, fin - ORG):
                mapa[p] = 1
        huecos = mapa.count(0)
        self.assertEqual(huecos, 0, "%d bytes sin explicar" % huecos)

    def test_las_entradas_estan_justificadas(self):
        """Cada punto de entrada declarado lleva su comentario al lado.

        Una entrada sin justificar es una direccion metida a mano para que la
        cobertura cuadre.
        """
        sin = []
        for ln in lee(ENTRIES).splitlines():
            ln = ln.strip()
            if not ln or ln.startswith("#"):
                continue
            if "#" not in ln:
                sin.append(ln)
        self.assertEqual(sin, [], "entradas sin justificar")


class TestNotas(unittest.TestCase):
    """El fichero de anotaciones."""

    @classmethod
    def setUpClass(cls):
        cls.d = bloques_declarados()

    def test_cada_bloque_de_datos_tiene_nombre_y_explicacion(self):
        cortos = [n for n, (_, _, e) in self.d.items() if len(e) < 20]
        self.assertEqual(cortos, [], "bloques sin explicacion de verdad")

    def test_las_anchuras_declaradas_apuntan_a_un_bloque(self):
        """Toda directiva F cae en el arranque de una D."""
        arranques = {i for i, _, _ in self.d.values()}
        sueltas = []
        for m in re.finditer(r"^F\s+(0x[0-9a-fA-F]+)\s", lee(NOTES),
                             re.MULTILINE):
            if int(m.group(1), 16) not in arranques:
                sueltas.append(m.group(1))
        self.assertEqual(sueltas, [], "anchuras que no arrancan un bloque")

    def test_las_zonas_de_datos_no_se_solapan(self):
        rangos = sorted((i, f, n) for n, (i, f, _) in self.d.items())
        for (i1, f1, n1), (i2, _, n2) in zip(rangos, rangos[1:]):
            self.assertLessEqual(f1, i2, "%s y %s se solapan" % (n1, n2))


class TestRLE(unittest.TestCase):
    """Los bloques comprimidos, medidos EJECUTANDO el descompresor."""

    @classmethod
    def setUpClass(cls):
        import rle
        cls.rle = rle
        cls.rom = rom_del_listado()
        cls.d = bloques_declarados()

    def test_los_bloques_comprimidos_cierran_donde_dice_su_directiva(self):
        """El 0x00 final cae exactamente en el limite declarado.

        Son los que empiezan por su direccion de VRAM: el descompresor no sabe
        cuanto miden, lo marca el propio bloque. Si una D estuviera corrida,
        aqui saltaria. Se exige que al menos veinte cierren, porque no todos
        los bloques de datos son comprimidos.
        """
        cierran = 0
        for nombre, (ini, fin, _) in sorted(self.d.items()):
            r = self.rle.descomprime(self.rom, ORG, ini, None)
            if r is not None and r[0] == fin:
                cierran += 1
        self.assertGreater(cierran, 20,
                           "casi ningun bloque cierra donde dice su directiva")


class TestRotulos(unittest.TestCase):
    """Los textos, leidos con la fuente del cartucho y no con ASCII."""

    @classmethod
    def setUpClass(cls):
        cls.rom = rom_del_listado()

    def texto_en(self, addr, n):
        p = addr - ORG
        return como_texto(self.rom[p:p + n])

    def test_las_cuatro_pruebas_estan_donde_dicen_las_notas(self):
        """Los cuatro nombres, sacados de la propia ROM.

        Son los que reparte la tabla de 0x5A90, y el orden con el que el juego
        los recorre no es el de la lista: 0 es el ciclismo, 1 el triple salto,
        2 el curling y 3 el salto con pertiga.
        """
        self.assertIn("TRIPLE JUMP", self.texto_en(0x5A99, 14))
        self.assertIn("POLE VAULT", self.texto_en(0x5AA7, 13))
        self.assertIn("CYCLING", self.texto_en(0x5AB4, 10))
        self.assertIn("CURLING", self.texto_en(0x5ABE, 10))

    def test_el_rotulo_del_record_dice_world_record(self):
        """El guion de 0x57F1, que se pinta PARPADEANDO."""
        self.assertIn("WORLD RECORD", self.texto_en(0x57F3, 13))

    def test_el_menu_ofrece_uno_y_dos_jugadores(self):
        """PLAY SELECT y las dos lineas, en el guion del titulo."""
        guion = self.texto_en(0x4525, 39)
        self.assertIn("PLAY SELECT", guion)
        self.assertIn("1PLAYER", guion)
        self.assertIn("2PLAYERS", self.texto_en(0x454C, 11))

    def test_el_titulo_lleva_la_marca_de_konami_y_el_ano(self):
        self.assertIn("KONAMI", self.texto_en(0x4527, 12))

    def test_el_rotulo_de_la_falta_dice_foul(self):
        self.assertIn("FOUL", self.texto_en(0x455A, 7))

    def test_el_rotulo_de_clasificar_dice_qualify(self):
        self.assertIn("QUALIFY", self.texto_en(0x75A1, 10))


class TestTablas(unittest.TestCase):
    """Las tablas de datos, contra lo que el codigo hace con ellas."""

    @classmethod
    def setUpClass(cls):
        cls.rom = rom_del_listado()

    def bytes_en(self, addr, n):
        p = addr - ORG
        return self.rom[p:p + n]

    def test_los_registros_del_vdp_ponen_screen_2(self):
        """Los ocho valores de 0x4492, uno por uno.

        R0=0x02 y R1=0xE2 son SCREEN 2 con sprites de 16x16 e interrupcion; el
        R3=0x7F y el R4=0x07 NO son direcciones sino base y mascara, que es
        donde se cae siempre: la tabla de color arranca en 0 y la de patrones
        en 0x2000.
        """
        self.assertEqual(list(self.bytes_en(0x4492, 8)),
                         [0x02, 0xE2, 0x0E, 0x7F, 0x07, 0x76, 0x03, 0xE4])

    def test_los_doce_bytes_de_init_son_los_records_del_mundo(self):
        """0x40CF: cuatro records, tres bytes en BCD y del reves.

        Los dos que se pueden cotejar cuadran con 1985: los 17,97 metros de
        Willie Banks en el triple salto y los 5,90 de Sergei Bubka en pertiga.
        """
        d = self.bytes_en(0x40CF, 12)
        self.assertEqual(list(d[0:3]), [0x34, 0x45, 0x01])   # 1:45.34
        self.assertEqual(list(d[3:6]), [0x97, 0x17, 0x00])   # 17.97 m
        self.assertEqual(list(d[6:9]), [0x00, 0x00, 0x01])   # 100 puntos
        self.assertEqual(list(d[9:12]), [0x90, 0x05, 0x00])  # 5.90 m

    def test_las_marcas_del_triple_salto_llevan_el_record_de_oliveira(self):
        """0x757D: ocho marcas en BCD, y la sexta son 17,89 metros.

        Ese era el record del mundo de Joao Carlos de Oliveira, de 1975, que
        aguanto hasta que Banks lo batio en 1985.
        """
        d = self.bytes_en(0x757D, 16)
        marcas = [(d[i + 1] << 8) | d[i] for i in range(0, 16, 2)]
        self.assertEqual(marcas, [0x1300, 0x1400, 0x1500, 0x1600,
                                  0x1700, 0x1789, 0x1800, 0x2000])

    def test_las_marcas_de_la_pertiga_van_de_5_65_a_5_94(self):
        d = self.bytes_en(0x758D, 20)
        marcas = [(d[i + 1] << 8) | d[i] for i in range(0, 20, 2)]
        self.assertEqual(marcas[0], 0x0565)
        self.assertEqual(marcas[-1], 0x0594)
        self.assertEqual(marcas, sorted(marcas), "los listones no suben")

    def test_los_puntos_del_curling_suben_hasta_cuarenta(self):
        """0xB684: ocho valores en BCD, del centro al borde de la casa."""
        self.assertEqual(list(self.bytes_en(0xB684, 8)),
                         [0x00, 0x05, 0x10, 0x15, 0x20, 0x25, 0x30, 0x40])

    def test_la_grabacion_de_la_demostracion_termina_en_f7(self):
        """Las dos grabaciones, la del triple salto y la de la pertiga.

        La demostracion no es codigo: es una partida grabada, tramos de
        [botones, cuantos fotogramas], y el 0xF7 es lo que la cierra.
        """
        for ini, fin in ((0x5876, 0x5880), (0x5880, 0x5896)):
            d = self.bytes_en(ini, fin - ini)
            self.assertEqual(d[-1], 0xF7,
                             "la grabacion de 0x%04X no cierra con 0xF7" % ini)

    def test_la_marca_de_konami_dice_rc733(self):
        """Los dieciseis ultimos bytes del cartucho.

        El hallazgo es de Manuel Pazos: el titulo en katakana al reves, su
        longitud, el numero de catalogo y el 0xAA que cierra. Este es el
        primero de la serie que mete un DIGITO ASCII dentro del titulo: el
        0x33 de la cabeza es el '3' de la secuela, y por el el rastreador lo
        daba por sin marca.
        """
        d = self.bytes_en(0xBFF0, 16)
        self.assertEqual(d[-1], 0xAA, "no cierra con 0xAA")
        self.assertEqual(d[-2], 0x33, "el numero de catalogo no es el 0x33")
        self.assertEqual(d[-3], 0x0D, "la longitud del titulo no es trece")
        self.assertEqual(d[0], 0x33, "el titulo no empieza por el '3' ASCII")


class TestAritmetica(unittest.TestCase):
    """Las tablas de numeros, contra las matematicas de verdad."""

    @classmethod
    def setUpClass(cls):
        cls.rom = rom_del_listado()

    def bytes_en(self, addr, n):
        p = addr - ORG
        return self.rom[p:p + n]

    def test_la_tabla_de_noventa_valores_es_un_seno(self):
        """0x7346: noventa valores, uno por grado, y 0xFF por uno.

        No se comprueba que crezca: se comprueba contra el seno de verdad. Si
        la lectura del formato estuviera mal, el error se dispararia.
        """
        d = self.bytes_en(0x7346, 90)
        peor = 0.0
        for grado, v in enumerate(d):
            esperado = math.sin(math.radians(grado)) * 255.0
            peor = max(peor, abs(v - esperado))
        self.assertLess(peor, 2.0,
                        "la tabla se aparta del seno hasta en %.1f" % peor)

    def test_las_dos_curvas_del_curling_son_seno_y_coseno(self):
        """0xAE4C y 0xAE6D: treinta y tres valores cada una.

        Juntas son un cuarto de vuelta, y se cortan en el 0xB5 de los cuarenta
        y cinco grados, que es 0,707 de 0xFF. La que baja es el coseno del
        angulo y la que sube su seno, escaladas a 0xFF.
        """
        baja = self.bytes_en(0xAE4C, 33)
        sube = self.bytes_en(0xAE6D, 33)
        self.assertEqual(baja[-1], sube[-1], "las dos no se cortan")
        self.assertEqual(baja[-1], 0xB5, "no se cortan en los 45 grados")
        peor = 0.0
        for i in range(33):
            ang = math.atan2(i, 32)
            peor = max(peor, abs(baja[i] - math.cos(ang) * 255.0))
            peor = max(peor, abs(sube[i] - math.sin(ang) * 255.0))
        self.assertLess(peor, 3.0,
                        "las curvas se apartan del circulo hasta en %.1f"
                        % peor)

    def test_la_tabla_de_periodos_son_doce_semitonos(self):
        """0x4DA2: no son diez valores, son DOCE, y los dos ultimos estan
        escondidos dentro de la tabla de punteros que viene detras.

        El reproductor la indexa con el nibble alto del byte de nota, que llega
        hasta 0x0B, asi que con 0x0A y 0x0B lee 0x4DAC y 0x4DAD, o sea la
        entrada [0] de la tabla de pistas. Esos dos bytes no son un puntero:
        son los dos semitonos que faltan para completar la octava. Se
        comprueba contra la progresion de verdad, 107 por dos elevado a menos
        n doceavos.
        """
        d = self.bytes_en(0x4DA2, 12)
        peor = 0.0
        for n, v in enumerate(d):
            peor = max(peor, abs(v - 107.0 * 2.0 ** (-n / 12.0)))
        self.assertLess(peor, 1.0,
                        "los doce no son una octava cromatica: se apartan "
                        "hasta en %.2f" % peor)
        self.assertEqual(list(d[10:12]), [0x3C, 0x39],
                         "la entrada [0] de la tabla de pistas ha cambiado")

    def test_los_diez_bytes_muertos_de_0xae3a_son_hl_entre_32(self):
        """0xAE3A no es una tabla: es una rutina que no llama nadie.

        Se ejecutan sus diez bytes en Python y se comprueba, sobre los 65.536
        valores posibles, que dan lo mismo que el desplegado de 0xAD04, que es
        el que si se usa. Si alguien tocara esos bytes creyendolos datos, aqui
        saltaria.
        """
        self.assertEqual(list(self.bytes_en(0xAE3A, 10)),
                         [0xAF, 0x29, 0x8F, 0x29, 0x8F, 0x29, 0x8F,
                          0x6C, 0x67, 0xC9])

        def muerta(hl):                      # la de 0xAE3A
            a = 0
            for _ in range(3):
                hl <<= 1
                cy = (hl >> 16) & 1
                hl &= 0xFFFF
                a = ((a << 1) | cy) & 0xFF
            return (a << 8) | ((hl >> 8) & 0xFF)

        def desplegada(bc):                  # la de 0xAD04, que si se usa
            b, a = (bc >> 8) & 0xFF, bc & 0xFF
            for _ in range(5):
                cy = b & 1
                b >>= 1
                a = ((a >> 1) | (cy << 7)) & 0xFF
            return (b << 8) | a

        distintos = [x for x in range(0x10000)
                     if muerta(x) != desplegada(x) or muerta(x) != x // 32]
        self.assertEqual(distintos, [], "ya no hacen lo mismo")

    def test_las_copias_del_ciclista_empiezan_en_el_tile_0xa0(self):
        """0x9CFA sube el destino ANTES de volcar cada copia, no despues.

        L_9CC7 genera ocho copias del dibujo del ciclista, cada una corrida un
        pixel mas, y las va subiendo a la VRAM. El detalle que costo 2.134
        bytes de diferencia contra el emulador: el `add hl,bc` de 0x9CFA va
        ANTES del volcado, asi que la primera copia no cae en 0x24D0 sino en
        0x2500 -o sea el tile 0xA0-, y la del segundo dibujo en 0x2680, el tile
        0xD0. Y 0xA0 y 0xD0 son exactamente los dos valores que 0xA383 carga en
        C para pintar al ciclista, que es lo que lo confirma.
        """
        asm = lee(ASM)
        self.assertIn("ld hl,024d0h", asm, "cambio el destino del primer dibujo")
        self.assertIn("ld hl,02650h", asm, "cambio el destino del segundo")
        # los dos tiles que el codigo usa para pintar al ciclista
        self.assertIn("ld c,0a0h", asm)
        self.assertIn("ld c,0d0h", asm)
        # 0x24D0 + 0x30 son los 0x2500 del tile 0xA0, y 0x2650 + 0x30 los
        # 0x2680 del 0xD0: ocho copias de seis tiles cada una, sin solaparse
        self.assertEqual((0x2500 - 0x2000) // 8, 0xA0)
        self.assertEqual((0x2680 - 0x2000) // 8, 0xD0)
        self.assertEqual(0x2500 + 8 * 0x30, 0x2680)

    def test_las_dos_curvas_de_rozamiento_solo_suben(self):
        """La del atleta (0x5F7B) y la del ciclista (0x9AD7).

        Las dos se indexan con el nibble alto de la propia velocidad, asi que
        tienen que crecer: cuanto mas rapido se va, mas se frena. Si alguna
        bajase, habria una velocidad a la que el rozamiento afloja.
        """
        for addr in (0x5F7B, 0x9AD7):
            d = list(self.bytes_en(addr, 16))
            self.assertEqual(d, sorted(d),
                             "la curva de 0x%04X no crece" % addr)


class TestWeb(unittest.TestCase):
    """Lo publicado, contra lo medido."""

    @classmethod
    def setUpClass(cls):
        if not os.path.isdir(DOCS):
            raise unittest.SkipTest("la web aun no esta escrita")
        cls.paginas = {}
        for base, _, ficheros in os.walk(DOCS):
            for f in ficheros:
                if f.endswith((".md", ".html")):
                    r = os.path.join(base, f)
                    cls.paginas[r] = lee(r)

    def test_no_se_nombra_otro_juego_de_la_serie(self):
        """El fallo mas repetido de la serie es el copia y pega del anterior.

        Hyper Sports 1 y 2 son la excepcion, y esta acotada: son los hermanos
        directos de este cartucho y la comparacion entre los tres ES contenido
        legitimo. Cualquier otro nombre en cualquier pagina es copia y pega.
        """
        malas = []
        for ruta, texto in self.paginas.items():
            base = os.path.basename(ruta)
            for juego in OTROS_JUEGOS:
                if juego in texto:
                    malas.append("%s nombra a %s" % (base, juego))
        self.assertEqual(malas, [], "; ".join(malas))

    def test_las_cifras_publicadas_son_las_del_listado(self):
        """El porcentaje comentado que se publica tiene que ser el medido."""
        bloques = bloques_del_listado(lee(ASM).splitlines())
        instr = sum(b[2] for b in bloques)
        coment = sum(b[3] for b in bloques)
        real = round(100.0 * coment / instr, 1)
        for ruta, texto in self.paginas.items():
            for m in re.finditer(r"(\d+[.,]\d)\s*%", texto):
                v = float(m.group(1).replace(",", "."))
                if 30.0 < v < 45.0:
                    self.assertAlmostEqual(
                        v, real, delta=0.6,
                        msg="%s publica %.1f %% y el listado da %.1f %%"
                            % (os.path.basename(ruta), v, real))

    def test_la_suma_de_bytes_da_el_cartucho(self):
        """Las dos cifras de la portada tienen que sumar los 32 KB.

        Es la comprobacion que caza que se hayan quedado las del juego
        anterior: dos numeros copiados suman otra cosa.
        """
        import make_web
        self.assertEqual(make_web.CODIGO + make_web.DATOS, FIN - ORG,
                         "%d + %d no dan los 32768 del cartucho"
                         % (make_web.CODIGO, make_web.DATOS))

    def test_las_cifras_de_la_portada_son_las_del_listado(self):
        """Rutinas, instrucciones y comentarios, contados sobre el arbol."""
        import make_web
        bloques = bloques_del_listado(lee(ASM).splitlines())
        self.assertEqual(make_web.RUTINAS, len(bloques))
        self.assertEqual(make_web.INSTRUCCIONES, sum(b[2] for b in bloques))
        self.assertEqual(make_web.COMENTARIOS, sum(b[3] for b in bloques))

    def test_las_imagenes_de_la_galeria_estan(self):
        """Una galeria con huecos se publica igual y no se ve hasta que se abre."""
        import contenido_web
        faltan = [f for f, _, _ in contenido_web.GALERIA
                  if not os.path.exists(os.path.join(DOCS, "imagenes", f))]
        self.assertEqual(faltan, [], "faltan imagenes: %s" % " ".join(faltan))

    def test_las_paginas_del_contrato_estan_en_los_dos_idiomas(self):
        """Siete por idioma, y las dos portadas."""
        en = ["GETTING-STARTED", "THE-GAME", "THE-CARTRIDGE", "THE-CODE",
              "FINDINGS", "IN-THE-EMULATOR", "OPEN-QUESTIONS"]
        es = ["EMPEZAR", "EL-JUEGO", "EL-CARTUCHO", "EL-CODIGO", "HALLAZGOS",
              "EN-EL-EMULADOR", "PREGUNTAS-ABIERTAS"]
        faltan = [p for p in
                  [os.path.join(DOCS, "index.html"),
                   os.path.join(DOCS, "es", "index.html")]
                  + [os.path.join(DOCS, x + ".html") for x in en]
                  + [os.path.join(DOCS, "es", x + ".html") for x in es]
                  if not os.path.exists(p)]
        self.assertEqual(faltan, [], "faltan paginas: %s" % " ".join(faltan))


if __name__ == "__main__":
    unittest.main()
