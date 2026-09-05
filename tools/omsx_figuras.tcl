# omsx_figuras.tcl - Con que tabla, figura y posicion se dibuja el atleta.
#
# El motor de figuras (0x65FC) recibe la tabla en HL y saca de la RAM la fila
# (0xE131), la columna (0xE132) y cual de las figuras toca (0xE134). Mirando
# los datos desde fuera no se acierta: la pertiga, por ejemplo, no dibuja al
# atleta con una sola figura de su tabla. Esto lo pregunta al cartucho.
#
# Vale igual para el ciclismo: 0xA383 pinta las casillas de un ciclista.
#
# La prueba sale de work/prueba.txt, como en tools/omsx_vram.tcl.

set ::RAIZ {C:/Users/Antxiko/Documents/DES_ASM/HYPERSPORTS3_DISAM}
set ::PRUEBA 0
if {[file exists $::RAIZ/work/prueba.txt]} {
    set f [open $::RAIZ/work/prueba.txt r]
    set l [string trim [read $f]] ; close $f
    if {[string is integer -strict $l] && $l >= 0 && $l <= 3} { set ::PRUEBA $l }
}
set ::LOG [open $::RAIZ/work/figuras-$::PRUEBA.txt w]
set ::forzada 0
set ::n 0

debug set_bp 0x41B5 {} {
    if {$::forzada == 0 && ([debug read memory 0xE002] & 0x40) != 0} {
        debug write memory 0xE06A $::PRUEBA
        set ::forzada 1
    }
}

# El motor de figuras del atleta: la tabla en HL, y el resto en la RAM.
debug set_bp 0x65FC {} {
    if {$::forzada == 1 && $::n < 24} {
        incr ::n
        set sp [reg SP]
        set volver [expr {[debug read memory $sp] | ([debug read memory [expr {$sp+1}]] << 8)}]
        puts $::LOG [format {t=%7.2f  dibuja_la_figura  tabla=%04X  fila=%3d col=%3d figura=%2d   <- %04X} \
            [machine_info time] [reg HL] [debug read memory 0xE131] \
            [debug read memory 0xE132] [debug read memory 0xE134] $volver]
        flush $::LOG
    }
}

# Y el del ciclismo: las casillas de un ciclista.
debug set_bp 0xA383 {} {
    if {$::forzada == 1 && $::n < 24} {
        incr ::n
        puts $::LOG [format {t=%7.2f  pinta_un_ciclista hl=%04X de=%04X bc=%04X a=%02X ix=%04X} \
            [machine_info time] [reg HL] [reg DE] [reg BC] [reg A] [reg IX]]
        flush $::LOG
    }
}

proc pulsa {} { keymatrixdown 8 0x01 ; after time 0.3 suelta }
proc suelta {} { keymatrixup 8 0x01 }
after time 12.0 { pulsa }
after time 13.0 { pulsa }
after time 20.0 { catch { close $::LOG } ; exit }
after realtime 300 { exit }
