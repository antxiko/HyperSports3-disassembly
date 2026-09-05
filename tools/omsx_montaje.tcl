# omsx_montaje.tcl - La lista de bloques que el cartucho sube al montar UNA prueba.
#
# Para que sirve: tools/graficos.py monta cada pantalla ejecutando en Python los
# pasos del cartucho, y cuando el cotejo contra la VRAM no cierra hay dos
# sospechosos -que un formato este mal leido, o que falte un bloque entero-.
# Distinguirlos mirando bytes es carisimo. Esto lo dice de una vez: pone un
# punto de ruptura en CADA rutina de dibujo del cartucho y apunta, en orden,
# con que argumentos la llaman mientras se monta la prueba.
#
# La ventana es exacta: se abre en 0x41B5 -el `call monta_la_prueba` de la
# escena 4- y se cierra en 0x41B8, la instruccion de vuelta. Todo lo que caiga
# dentro es el montaje de la pantalla, y nada mas.
#
# Y la prueba que se monta la elige work/prueba.txt, con el mismo truco que
# tools/omsx_vram.tcl: 0 ciclismo, 1 triple salto, 2 curling, 3 pertiga.
#
#   echo 1 > work/prueba.txt
#   "C:/Program Files/openMSX/openmsx.exe" -machine Philips_VG_8020 \
#       -cart hypersports3.rom -script tools/omsx_montaje.tcl
#
# Sale en work/montaje-N.txt.

set ::RAIZ {C:/Users/Antxiko/Documents/DES_ASM/HYPERSPORTS3_DISAM}

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

set ::SALIDA $::RAIZ/work/montaje-$::PRUEBA.txt
set ::LOG [open $::SALIDA w]
set ::traza 0
set ::pasos 0

# Las rutinas de dibujo del cartucho, con lo que hay que apuntar de cada una.
# El nombre es el del listado; los argumentos, los que dice su comentario.
set ::RUTINAS {
    0x4405 descomprime_en_los_tres_tercios  {de hl}
    0x4407 descomprime_en_n_tercios         {de hl bc}
    0x4415 pinta_guion_de_tiles             {de hl}
    0x442C borra_guion_de_tiles             {de hl}
    0x4430 guion_que_parpadea               {de hl}
    0x4442 descompr_a_vram                  {de}
    0x4448 descompr_a_vram_en               {de hl}
    0x43DD ldirvm                           {hl de bc}
    0x43E1 ldirvm_en_los_tres_tercios       {hl de bc}
    0x43F4 filvrm_en_los_tres_tercios       {hl bc a}
    0x4319 esconde_los_sprites              {}
    0x43C4 limpia_la_pantalla               {}
    0x74B1 rle_a_ram                        {hl de}
    0x676E guion_por_el_puerto              {de hl}
    0x0056 BIOS_FILVRM                      {hl bc a}
    0x005C BIOS_LDIRVM                      {hl de bc}
}

proc apunta_llamada {nombre campos} {
    if {$::traza == 0} { return }
    incr ::pasos
    set txt {}
    foreach c $campos {
        switch -- $c {
            hl { lappend txt [format {hl=%04X} [reg HL]] }
            de { lappend txt [format {de=%04X} [reg DE]] }
            bc { lappend txt [format {bc=%04X} [reg BC]] }
            a  { lappend txt [format {a=%02X} [reg A]] }
        }
    }
    # de donde la llaman: la direccion de retorno esta en la cima de la pila
    set sp [reg SP]
    set volver [expr {[debug read memory $sp] | ([debug read memory [expr {$sp+1}]] << 8)}]
    puts $::LOG [format {%3d  %-32s %-26s <- %04X} $::pasos $nombre [join $txt { }] $volver]
    flush $::LOG
}

foreach {dir nombre campos} $::RUTINAS {
    debug set_bp $dir {} "apunta_llamada $nombre {$campos}"
}

# La ventana: se abre justo antes del `call monta_la_prueba` y se cierra al
# volver de el. En la de apertura se escribe ademas la prueba forzada.
debug set_bp 0x41B5 {} {
    if {$::traza == 0 && ([debug read memory 0xE002] & 0x40) != 0} {
        debug write memory 0xE06A $::PRUEBA
        set ::traza 1
        puts $::LOG [format {== monta_la_prueba, prueba %d, t=%.2f} \
                         $::PRUEBA [machine_info time]]
        flush $::LOG
    }
}
debug set_bp 0x41B8 {} {
    if {$::traza == 1} {
        set ::traza 0
        puts $::LOG [format {== fin del montaje: %d llamadas} $::pasos]
        close $::LOG
        exit
    }
}

proc pulsa {} { keymatrixdown 8 0x01 ; after time 0.3 suelta }
proc suelta {} { keymatrixup 8 0x01 }
after time 12.0 { pulsa }
after time 13.0 { pulsa }
after time 30.0 { catch { close $::LOG } ; exit }
after realtime 300 { exit }
