# omsx_vram.tcl - Vuelca la VRAM de verdad del cartucho, para comprobar los PNG.
#
# Para que sirve: tools/graficos.py monta las imagenes ejecutando en Python los
# pasos del cartucho -el descompresor de L_4442, el que escribe en la RAM de
# L_74B5, el espejo de L_B72F, los cuatro pixeles a mano de 0x741F y el motor
# de figuras de 0x6992-. Mirar el dibujo no basta: hay que comparar sus bytes
# con los que el VDP tiene de verdad. Esto deja correr el cartucho y en varios
# instantes vuelca los 16 KB de VRAM, los ocho registros del VDP y las
# variables que dicen QUE se estaba dibujando.
#
# No hace falta jugar: LA DEMOSTRACION pasa sola por las cuatro pruebas, y las
# monta con la misma pantalla que la partida (la escena 2 llama a L_5800, que
# llama a monta_la_prueba). Asi que se deja correr sin tocar una tecla y se
# vuelca cada pocos segundos, anotando en cada volcado la prueba en curso.
#
# EL TRUCO PARA ARRANCAR EN LA PRUEBA QUE SE QUIERA
#
# La partida siempre empieza por la 0, el ciclismo: al elegir en el menu,
# 0x42F1 borra de 0xE063 a 0xE120 y ahi dentro esta (0xE06A). Para cotejar las
# otras tres habria que JUGAR el ciclismo entero y ganarlo.
#
# No hace falta. La escena 4 es `call limpia_la_pantalla / call monta_la_prueba`
# (0x41B2, 0x41B5), y monta_la_prueba lee la prueba de (0xE06A) en 0x53CB. Un
# punto de ruptura en 0x41B5 -DESPUES del borrado del menu y ANTES del montaje-
# que escriba ahi el numero de prueba deja al cartucho montando y JUGANDO esa
# prueba: no es una pantalla congelada, es la prueba de verdad, con su motor
# (0x5548), su rotulo y su atleta.
#
# Y sale mejor que jugando: asi la prueba hereda la VRAM del TITULO, que es la
# unica pantalla que ya cierra a cero, en vez de heredar la del ciclismo.
#
# El numero se lee de work/prueba.txt, no de una variable de entorno ni de la
# linea de ordenes: a un `-script` de openMSX no se le pasan argumentos, y
# `$::argv` y `$env(...)` llegan vacios (se pago en Mahjong con tres pasadas
# midiendo la misma tecla creyendo que eran tres).
#
#   0 ciclismo   1 triple salto   2 curling   3 pertiga
#
# Sin ese fichero no se toca nada y el volcado es el del ciclismo de siempre.
#
#   echo 2 > work/prueba.txt
#   "C:/Program Files/openMSX/openmsx.exe" -machine Philips_VG_8020 \
#       -cart hypersports3.rom -script tools/omsx_vram.tcl

set ::RAIZ {C:/Users/Antxiko/Documents/DES_ASM/HYPERSPORTS3_DISAM}

# --- que prueba se fuerza ---------------------------------------------------
set ::PRUEBA 0
set ::ruta_prueba $::RAIZ/work/prueba.txt
if {[file exists $::ruta_prueba]} {
    set f [open $::ruta_prueba r]
    set leido [string trim [read $f]]
    close $f
    if {[string is integer -strict $leido] && $leido >= 0 && $leido <= 3} {
        set ::PRUEBA $leido
    }
}
set ::NOMBRE [lindex {ciclismo triple-salto curling pertiga} $::PRUEBA]

if {$::PRUEBA == 0} {
    set ::SALIDA $::RAIZ/work/omsx
} else {
    set ::SALIDA $::RAIZ/work/omsx-$::PRUEBA
}
file mkdir $::SALIDA
set ::n 0

# El log es la unica prueba de lo que hizo el guion: con el renderizador
# apagado los `puts` no salen por stdout.
set ::LOG [open $::SALIDA/log.txt w]
proc apunta {txt} {
    puts $::LOG [format {t=%8.2f  %s} [machine_info time] $txt]
    flush $::LOG
}
apunta "prueba forzada: $::PRUEBA ($::NOMBRE), leida de $::ruta_prueba"

proc vuelca {etiqueta} {
    set i [format %02d $::n]
    incr ::n
    # los 16 KB de VRAM tal cual los ve el VDP: el cartucho pone R1 = 0xE2, o
    # sea modo de 16K, asi que por encima de 0x4000 no hay nada que mirar
    set datos [debug read_block VRAM 0 16384]
    set f [open $::SALIDA/vram_$i.bin w]
    fconfigure $f -translation binary
    puts -nonewline $f $datos
    close $f
    # y los 2 KB de RAM de trabajo, de 0xE000 a 0xE7FF, que es toda la que el
    # cartucho usa: ahi viven las dos ventanas del circuito del ciclismo
    # (0xE140 y 0xE260), el dibujo que se corre cuatro pixeles (0xE320) y los
    # bloques por prueba (0xE600)
    set ram [debug read_block memory 0xE000 2048]
    set f [open $::SALIDA/ram_$i.bin w]
    fconfigure $f -translation binary
    puts -nonewline $f $ram
    close $f
    # los ocho registros, que dicen donde esta cada tabla
    set r {}
    for {set k 0} {$k < 8} {incr k} {
        lappend r [format %02X [debug read {VDP regs} $k]]
    }
    set f [open $::SALIDA/info_$i.txt w]
    puts $f [format {etiqueta %s} $etiqueta]
    puts $f [format {forzada %d} $::PRUEBA]
    puts $f [format {truco %d} $::forzada]
    puts $f [format {tiempo %s} [machine_info time]]
    puts $f [format {regs %s} [join $r { }]]
    # Las variables de trabajo empiezan en 0xE000, y estos nombres son los del
    # listado de ESTE cartucho: 0xE000 es la escena que reparte el latido de
    # 0x40E3 y 0xE001 el escalon de la cadena de `djnz`; 0xE002 lleva en el bit
    # 5 si juegan dos, en el 6 si hay partida y en el 7 de quien es el turno;
    # 0xE003 es el contador de fotogramas y 0xE004 la cuenta atras.
    #
    # El que importa para cotejar es 0xE06A: sus dos bits de abajo son LA
    # PRUEBA -0 ciclismo, 1 triple salto, 2 curling, 3 pertiga- y los de arriba
    # la vuelta. Los otros tres son la subescena de cada prueba, cada una en su
    # sitio: el salto en 0xE09E, el ciclismo en 0xE120 y el curling en 0xE230.
    foreach {nombre dir} {escena 0xE000 subescena 0xE001 modo 0xE002
                          reloj 0xE003 espera 0xE004 linea_del_menu 0xE052
                          esperando 0xE069 prueba_y_vuelta 0xE06A
                          sub_salto 0xE09E sub_ciclismo 0xE120
                          sub_curling 0xE230 estado_atleta 0xE130} {
        puts $f [format {%s %d} $nombre [debug read memory $dir]]
    }
    close $f
    catch { screenshot -raw $::SALIDA/pant_$i.png }
}

# --- el truco: forzar la prueba antes de que la escena 4 la monte ------------
# Un solo disparo, y con dos cinturones: solo con partida en curso -el bit 6 de
# (0xE002), que 0x42B2 enciende al elegir en el menu- y solo la primera vez.
# Nada de `return` dentro del cuerpo: eso mata el punto de ruptura a la primera
# pasada. La bandera hace el mismo trabajo sin matarlo.
set ::forzada 0
proc fuerza_la_prueba {} {
    if {$::forzada == 0} {
        set flags [debug read memory 0xE002]
        if {($flags & 0x40) != 0} {
            # LA HERENCIA, volcada aqui mismo: es la VRAM que la prueba se
            # encuentra hecha, justo despues de limpia_la_pantalla (0x41B2) y
            # justo ANTES de que monta_la_prueba escriba su primer byte. Con
            # esto la comparacion deja de tener un cabo suelto: lo que no
            # cuadre ya no puede ser "algo que borro una escena de en medio".
            vuelca herencia
            debug write memory 0xE06A $::PRUEBA
            set ::forzada 1
            apunta [format {0xE06A <- %d  (0xE002 = 0x%02X, con partida)} \
                        $::PRUEBA $flags]
        } else {
            apunta [format {0x41B5 sin partida (0xE002 = 0x%02X): no se toca} \
                        $flags]
        }
    }
}

# --- el vigilante de sprites ------------------------------------------------
# Volcar cada medio segundo se pierde lo que dura menos: el fogonazo de la
# pistola de salida esta en pantalla un pestaneo. Esto mira la tabla de
# atributos (0x3B00) veinte veces por segundo emulado -128 bytes, que es
# barato- y en cuanto aparece un NUMERO DE PATRON que no estaba, lo apunta y
# vuelca la pantalla entera. Asi el instante lo elige el juego, no el reloj.
#
# La cadena se reprograma LO PRIMERO y el trabajo va dentro de un `catch`: una
# cadena `after` que falle una vez se para para siempre, y en Windows no
# escribe el error por ningun sitio.
set ::patrones_vistos {}
proc vigila_sprites {} {
    after time 0.05 vigila_sprites
    catch {
        set at [debug read_block VRAM 0x3B00 128]
        set nuevos {}
        for {set k 0} {$k < 32} {incr k} {
            set y [scan [string index $at [expr {$k * 4}]] %c]
            if {$y > 0xC0} { continue }
            set patron [scan [string index $at [expr {$k * 4 + 2}]] %c]
            set color [expr {[scan [string index $at [expr {$k*4+3}]] %c] & 15}]
            if {$color == 0} { continue }
            if {[lsearch -exact $::patrones_vistos $patron] < 0} {
                lappend ::patrones_vistos $patron
                lappend nuevos [format {0x%02X en (%d,%d) color %X} $patron $y \
                    [scan [string index $at [expr {$k * 4 + 1}]] %c] $color]
            }
        }
        if {[llength $nuevos] > 0} {
            apunta [format {patron de sprite NUEVO: %s} [join $nuevos {; }]]
            vuelca sprite_nuevo
        }
    }
}

# --- la barra de espacio, que es con lo que se arranca la partida -----------
proc pulsa {} {
    keymatrixdown 8 0x01
    after time 0.3 suelta
}
proc suelta {} {
    keymatrixup 8 0x01
}

# --- calendario -------------------------------------------------------------
# El cartucho arranca por el logotipo de Konami, que SUBE de abajo arriba en
# catorce pasos de dos fotogramas cada uno, y de ahi pasa al titulo con su
# menu. Antes de los 4 s la VRAM esta a medio pintar y no es comparable.
#
# Y AQUI SE ARRANCA PARTIDA, que es lo unico que da un cotejo limpio: al
# elegir en el menu, 0x42F1 borra de 0xE063 a 0xE120 -y ahi dentro esta
# (0xE06A)-, asi que la primera prueba es SIEMPRE la 0, el ciclismo, y la
# pantalla de la que hereda es la del titulo, que ya cierra a cero. En la
# demostracion la herencia es la prueba anterior y ademas se juega, que es lo
# que ensuciaba el cotejo.
#
# De 14 a 44 s se vuelca cada medio segundo: asi cae dentro alguno con la
# pantalla RECIEN montada, antes de que el atleta la pise.
#
# El punto de ruptura se registra al segundo, con la maquina ya en marcha: es
# de EJECUCION, que son los que no ahogan al emulador, y 0x41B5 es el principio
# de su instruccion (`call 053b1h`), no un byte de en medio.
#
# Y EL TITULO SE VUELCA DE VERDAD. Estaba puesto a los 9 s, y a los 9 s el
# cartucho sigue en el logotipo de Konami: ese volcado era el logotipo con otro
# nombre, y la herencia contra la que se coteja cada prueba -que es la del
# TITULO- no se habia comprobado nunca contra el emulador. Ahora se vuelca cada
# medio segundo entre los 6 y los 11,5 s, que es toda la ventana del titulo con
# su menu, y la etiqueta del info_NN.txt dice cual es cual.
after time  1.0 { debug set_bp 0x41B5 {} { fuerza_la_prueba } }
# Y el otro extremo: la VRAM RECIEN montada, en 0x41B8, la instruccion de
# vuelta del `call monta_la_prueba`. Ese es el instante contra el que hay que
# cotejar, porque lo que venga despues ya lo pinta la escena 5 -el rotulo con
# la marca a batir, el atleta, el marcador- y no monta_la_prueba.
set ::montada 0
after time  1.0 { debug set_bp 0x41B8 {} {
    if {$::forzada == 1 && $::montada == 0} { set ::montada 1 ; vuelca montada }
} }
after time  5.0 { vuelca logotipo }
for {set t 12} {$t < 24} {incr t} {
    after time [expr {$t * 0.5}] { vuelca titulo }
}
after time 12.0 { pulsa }
after time 13.0 { pulsa }
after time 13.8 { vigila_sprites }
for {set t 28} {$t < 88} {incr t} {
    after time [expr {$t * 0.5}] { vuelca partida }
}
after time 45.0 { exit }

# perro guardian de tiempo REAL: un guion roto no puede colgar el emulador
after realtime 300 {
    puts {PERRO GUARDIAN a los 300 s reales}
    exit
}
