; ==========================================================================
; HYPER SPORTS 3 - Konami - MSX1 - cartucho RC-733 de 32 KB en las paginas 1 y 2
; ==========================================================================
; Generado por tools/mkasm.py a partir del trazado de flujo real.
; Los comentarios provienen de tools/../src/*.notes y estan anclados a
; direccion, de modo que sobreviven a un retrazado.
; ==========================================================================

	org 0x04000


; ----------------------------------------------------------------------
; DATOS cabecera_del_cartucho: "AB" y la direccion de INIT (0x405A);
;   STATEMENT, DEVICE y TEXT a cero, y los seis bytes reservados tambien
;   0x4000..0x4010  (16 bytes)
DATA_cabecera_del_cartucho:
	defw 04241h,0405ah,00000h,00000h,00000h,00000h,00000h,00000h	; 4000

; ======================================================================
; CODIGO 0x4010..0x40cf  (191 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; La entrada de 0x4010, que en la cabecera del cartucho NO esta declarada como nada: STATEMENT, DEVICE y TEXT valen cero. Lo que hace es escribir 0xC9E1 -que es `pop hl / ret`- en 0x412F, y 0x412F ES ROM: la escritura no llega a ninguna parte. Ahi hubo una automodificacion de cuando el codigo vivia en RAM, y quedo el cadaver.
; ----------------------------------------------------------------------
L_4010:
	ld hl,0c9e1h		;4010   ; 0xC9E1 son, puestos en memoria, los bytes E1 C9: `pop hl` / `ret`
	ld (0412fh),hl		;4013   ; PROTECCION ANTICOPIA: los bytes 0xE1 0xC9 son `pop hl` y `ret`, y van encima del `djnz` de 0x412F. Desde ROM la escritura NO llega -la ROM no admite escritura- y por eso parece codigo muerto; en una copia cargada en RAM si cuela, y la cadena de la presentacion se corta ahi. Manuel Pazos la identifico en el RC-727, donde esta escrita byte a byte, como ReadKeys_AC
	jp monta_los_tiles_del_logotipo		;4016   ; lo unico que de verdad hace esta entrada

; ----------------------------------------------------------------------
; EL GANCHO DE H.KEYI (0xFD9B). De aqui cuelga el juego entero: un fotograma por vez. Lleva cerrojo de reentrada en (0xE005), porque un fotograma que se pase de largo puede pillar al anterior sin terminar, y al salir vuelve a mirar el estado del VDP por si mientras tanto ha entrado otra interrupcion.
; ----------------------------------------------------------------------
manejador_de_interrupcion:		; el gancho que INIT deja en H.KEYI
	call 0013eh		;4019   ; BIOS RDVDP - Reads VDP status register | RDVDP: leer el registro de estado es lo que desarma la interrupcion del VDP
	di			;401c   ; la musica se atiende con las interrupciones cerradas
	call reproduce_un_fotograma		;401d   ; el reproductor, que suena una vez por fotograma pase lo que pase
	ld hl,0e005h		;4020   ; el cerrojo de reentrada
	bit 0,(hl)		;4023   ; si ya hay un fotograma dentro, no se empieza otro
	jr nz,L_4033		;4025
	inc (hl)			;4027   ; echar el cerrojo
	ei			;4028   ; y de aqui en adelante ya se puede interrumpir: el fotograma es lo largo
	call lee_los_mandos		;4029   ; lee los dos mandos y los dos teclados
	call latido_del_fotograma		;402c   ; el latido: sube el contador y reparte por escena
	xor a			;402f   ; soltar el cerrojo
	ld (0e005h),a		;4030
L_4033:
	call 0013eh		;4033   ; BIOS RDVDP - Reads VDP status register | y volver a mirar el estado del VDP
	or a			;4036   ; el bit 7 dice si ha entrado otra interrupcion mientras
	di			;4037
	call m,reproduce_un_fotograma		;4038   ; y si ha entrado, otra pasada de musica antes de salir: asi no se pierde un tiempo
	ei			;403b
	ret			;403c
escribe_registro_del_vdp:		; WRTVDP con el mismo cadaver de automodificacion
	ld hl,00000h		;403d   ; HL a cero: es lo que va a escribir la linea siguiente
	ld (0413bh),hl		;4040   ; LA OTRA PROTECCION ANTICOPIA: el cero cae en 0x413B, que no es un dato sino el operando del `jp` de 0x413A. Desde ROM no llega; en RAM ese salto se queda en `jp 00000h`, o sea un reinicio en seco. Es la pareja de la de 0x4013, y en el RC-727 son VRAM_writeAC y ReadKeys_AC
	jp 00047h		;4043   ; BIOS WRTVDP - Writes data in the VDP-register | WRTVDP escribe B en el registro que diga C, y los dos vienen del que llama

; ----------------------------------------------------------------------
; HL += A, con el acarreo a H. Es la que indexa casi todas las tablas.
; ----------------------------------------------------------------------
suma_a_hl:		; HL += A
	add a,l			;4046
	ld l,a			;4047
	ret nc			;4048
	inc h			;4049
	ret			;404a

; ----------------------------------------------------------------------
; La misma, con DE.
; ----------------------------------------------------------------------
suma_a_de:		; DE += A
	add a,e			;404b
	ld e,a			;404c
	ret nc			;404d
	inc d			;404e
	ret			;404f

; ----------------------------------------------------------------------
; EL DESPACHADOR. Se llama con el indice en A y la tabla de punteros PEGADA DETRAS del `call`: el `pop hl` no recupera una direccion de retorno, recupera la tabla. Ninguna de estas tablas se puede seguir con un trazado estatico, y por eso van declaradas a mano en el .entries.
; ----------------------------------------------------------------------
despacha_por_indice:		; el despachador de la familia Konami
	pop hl			;4050   ; la direccion de retorno ES la tabla
	add a,a			;4051   ; dos bytes por entrada
	call suma_a_hl		;4052   ; hl = tabla + indice*2
	ld e,(hl)			;4055   ; la entrada, que es la direccion a la que hay que ir
	inc hl			;4056
	ld d,(hl)			;4057
	ex de,hl			;4058
	jp (hl)			;4059   ; y se va sin volver: quien llamo ya no vuelve aqui

; ----------------------------------------------------------------------
; EL INIT DE LA CABECERA (0x405A). Engancha la mitad de arriba del cartucho en la pagina 2, monta el gancho de la interrupcion, borra los 2 KB de variables, prepara la pantalla y se queda dando vueltas para siempre en el bucle de 0x40B0: de aqui en adelante el juego solo avanza dentro de la interrupcion.
; ----------------------------------------------------------------------
init_del_cartucho:		; el INIT que declara la cabecera
	di			;405a   ; el BIOS entra aqui con las interrupciones abiertas
	im 1		;405b   ; modo 1: el vector va al 0x0038 de la BIOS, que reparte por H.KEYI
	ld sp,0e800h		;405d   ; la pila, en lo alto de los 2 KB de RAM que el cartucho usa
	call 00138h		;4060   ; BIOS RSLREG - Reads the primary slot register | RSLREG: los ocho bits son la ranura primaria de las cuatro paginas, dos a dos
	rrca			;4063   ; dos rotaciones dejan abajo los de la pagina 1, que es donde esta este cartucho
	rrca			;4064
	and 003h		;4065   ; y esos dos bits son la ranura
	ld c,a			;4067
	ld b,000h		;4068
	ld hl,0fcc1h		;406a   ; 0xFCC1 es EXPTBL: su bit 7 dice si la ranura esta expandida
	add hl,bc			;406d
	or (hl)			;406e   ; con el bit 7 pegado, A ya tiene el formato que ENASLT espera
	ld c,a			;406f
	inc hl			;4070   ; cuatro sumas: de EXPTBL a SLTTBL, que esta 4 bytes mas arriba
	inc hl			;4071
	inc hl			;4072
	inc hl			;4073
	ld a,(hl)			;4074   ; la subranura de esa ranura
	and 00ch		;4075   ; y de ella solo cuentan los dos bits de la pagina 1
	or c			;4077
	ld h,080h		;4078   ; H = 0x80, o sea la pagina 2: la mitad de arriba de la ROM
	call 00024h		;407a   ; BIOS ENASLT - Switches to specified slot and page definitively | ENASLT, y DEFINITIVAMENTE: el cartucho entero queda visible de 0x4000 a 0xBFFF
	ld a,0c3h		;407d   ; 0xFD9A es el `jp` del gancho de la interrupcion
	ld (0fd9ah),a		;407f
	ld hl,manejador_de_interrupcion		;4082   ; y 0xFD9B su destino
	ld (0fd9bh),hl		;4085
	ld hl,0e000h		;4088   ; borra de un tiron los 2 KB de variables, de 0xE000 a 0xE7FF
	ld de,0e001h		;408b
	ld bc,007ffh		;408e
	ld (hl),000h		;4091
	ldir		;4093
	ld de,0e053h		;4095   ; y copia encima los doce valores de 0x40CF, que son los unicos que no arrancan a cero
	ld hl,040cfh		;4098
	ld bc,0000ch		;409b
	ldir		;409e
	ld a,001h		;40a0   ; el cerrojo echado mientras se prepara la pantalla
	ld (0e005h),a		;40a2
	call borra_la_vram		;40a5   ; borra la VRAM y pone los ocho registros del VDP
	xor a			;40a8
	ld (0e005h),a		;40a9   ; soltar el cerrojo
	call 0013eh		;40ac   ; BIOS RDVDP - Reads VDP status register | desarma la interrupcion que haya quedado pendiente
	ei			;40af   ; y ya

; ----------------------------------------------------------------------
; EL BUCLE OCIOSO. Lo unico del cartucho que corre FUERA de la interrupcion, y solo trabaja mientras la prueba en curso es la 0 -el ciclismo-: convierte a decimal el byte de cada jugador y guarda las cuatro cifras. Son dieciseis vueltas de `adc a,a / daa` por jugador, y hacerlo aqui es lo unico que las saca del fotograma.
; ----------------------------------------------------------------------
bucle_ocioso:		; lo unico que corre fuera de la interrupcion
	ld a,(0e06ah)		;40b0   ; los dos bits de abajo de 0xE06A son la prueba en curso
	and 003h		;40b3
	jr nz,bucle_ocioso		;40b5   ; y si no es la 0, aqui no hay nada que hacer
	ld a,(0e0ddh)		;40b7   ; el byte del jugador 1
	ld l,a			;40ba
	call a_decimal_8		;40bb   ; convertido a decimal: cuatro cifras en BCD
	ld (0e0deh),de		;40be   ; y el resultado se deja donde el fotograma lo va a encontrar hecho
	ld a,(0e11dh)		;40c2   ; lo mismo con el jugador 2
	ld l,a			;40c5
	call a_decimal_8		;40c6
	ld (0e11eh),de		;40c9
	jr bucle_ocioso		;40cd   ; y a esperar otra vez

; ----------------------------------------------------------------------
; DATOS records_del_mundo: 12 bytes que INIT copia a 0xE053: los cuatro
;   records, tres bytes en BCD cada uno
;   0x40cf..0x40db  (12 bytes)
DATA_records_del_mundo:
	defb 034h,045h,001h,097h,017h,000h,000h,000h,001h,090h,005h,000h	; 40cf  4E..........

; ======================================================================
; CODIGO 0x40db..0x4109  (46 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Baja el bit 6 de la COPIA en ROM del registro 1 del VDP -el byte 0x4493 de la tabla de 0x4492-, o sea deja la pantalla apagada para la proxima vez que se escriban los registros, y salta a L_4ADD con lo que traiga A.
; ----------------------------------------------------------------------
apaga_la_pantalla:		; baja el bit 6 del registro 1
	ld hl,04493h		;40db   ; 0x4493 es el registro 1 dentro de la tabla de los ocho
	res 6,(hl)		;40de   ; el bit 6 es el que enciende la pantalla
	jp arranca_una_pista		;40e0

; ----------------------------------------------------------------------
; EL LATIDO. Sube el contador de fotogramas y reparte por escena, con un detalle: antes de repartir APILA una rutina -0x4288 o 0x4388 segun el bit 6 de (0xE002)-, de modo que el `ret` de la escena caiga en ella. Ese `push` es la unica forma de llegar a las dos, y las escenas 3, 4 y de la 6 en adelante se lo saltan.
; ----------------------------------------------------------------------
latido_del_fotograma:		; sube el contador y reparte por escena
	ld hl,0e003h		;40e3   ; 0xE003 cuenta fotogramas, y de el salen todos los ritmos lentos del cartucho
	inc (hl)			;40e6
	ld a,(0e002h)		;40e7   ; el bit 6 de 0xE002 dice si hay partida en curso
	and 040h		;40ea
	ld hl,04388h		;40ec   ; con partida, la que parpadea el rotulo de la prueba
	jr nz,L_40F4		;40ef
	ld hl,04288h		;40f1   ; y sin ella, la que lee los mandos del menu
L_40F4:
	ld bc,(0e000h)		;40f4   ; de un tiron: C = la escena (0xE000) y B = el paso dentro de ella (0xE001)
	ld a,c			;40f8
	cp 006h		;40f9   ; de la escena 6 en adelante no se apila nada
	jr nc,L_4106		;40fb
	cp 003h		;40fd   ; ni en la 3
	jr z,L_4106		;40ff
	cp 004h		;4101   ; ni en la 4
	jr z,L_4106		;4103
	push hl			;4105   ; apilarla: el `ret` de la escena vendra a parar aqui
L_4106:
	call despacha_por_indice		;4106   ; y repartir por la tabla que va pegada detras

; ----------------------------------------------------------------------
; DATOS tabla_de_escenas: 9 entradas, la mas alta del juego: reparte segun
;   (0xE003) el logotipo, el titulo, las pruebas y el final
;   0x4109..0x411b  (18 bytes)
DATA_tabla_de_escenas:
	defw 0411bh,0414bh,04155h,04185h,041b2h,041cbh,041e4h,04209h	; 4109
	defw 0422eh	; 4119  -> L_422E

; ======================================================================
; CODIGO 0x411b..0x4492  (887 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LAS NUEVE ESCENAS. Todas entran con B = el paso dentro de la escena, que es (0xE001), y lo primero que hacen es una cadena de `djnz`: con B=1 se cae en el primer trozo, con B=2 en el segundo, y asi. Subir de paso es L_4180 y pasar a la escena siguiente es L_41C2. (0xE004) es la cuenta atras, en fotogramas.
; ----------------------------------------------------------------------
L_411B:
	djnz L_412F		;411b   ; con B=1 se sigue aqui; con mas, se salta
	ld a,(0e003h)		;411d   ; el bit 0 del contador de fotogramas
	rra			;4120
	ret nc			;4121   ; o sea que esto va a la mitad de velocidad, un fotograma si y otro no
	call sube_el_logotipo_una_fila		;4122
	ret nz			;4125   ; mientras no termine, no se avanza
	ld de,04514h		;4126   ; el bloque comprimido de 0x4514, ya a la VRAM
	call descomprime_a_vram		;4129
	xor a			;412c   ; sin espera
	jr espera_y_sube_el_paso		;412d
L_412F:
	djnz L_413D		;412f   ; el paso 2
	ld hl,0e004h		;4131   ; la cuenta atras
	dec (hl)			;4134
	ret nz			;4135   ; y hasta que no llega a cero, nada
	call monta_el_titulo_entero		;4136
	xor a			;4139
	jp espera_y_pasa		;413a
L_413D:
	call pon_los_registros_del_vdp		;413d   ; los ocho registros del VDP
	call limpia_la_pantalla		;4140   ; limpia la pantalla entera
	call monta_la_fuente		;4143
	call prepara_el_logotipo		;4146
	jr sube_el_paso		;4149
L_414B:
	ld hl,0e004h		;414b   ; la escena 1 es solo esperar
	dec (hl)			;414e
	jp nz,parpadea_el_cursor_del_menu		;414f   ; mientras corre la cuenta atras, L_4889
	jp espera_32_y_pasa		;4152   ; y al agotarse, a la escena siguiente
L_4155:
	djnz L_4175		;4155   ; la escena 2, paso 1
	call reproduce_la_grabacion		;4157
	call demostracion_de_la_prueba		;415a
	ld a,(0e069h)		;415d   ; 0xE069 en alto significa esperar a que algo termine
	or a			;4160
	ret nz			;4161
	ld hl,0e06ah		;4162   ; la prueba en curso, una mas, y da la vuelta a las cuatro
	ld a,(hl)			;4165
	inc a			;4166
	and 003h		;4167
	ld (hl),a			;4169
L_416A:
	xor a			;416a   ; de vuelta al paso 0
L_416B:
	ld (0e000h),a		;416b
	ld a,020h		;416e   ; 32 fotogramas de espera
	ld (0e004h),a		;4170
	jr L_41C6		;4173
L_4175:
	call limpia_la_pantalla		;4175   ; el paso 2 de la escena 2
	call arranca_la_demostracion		;4178
	ld a,020h		;417b   ; 32 fotogramas
espera_y_sube_el_paso:		; deja la cuenta atras en A y sube el paso
	ld (0e004h),a		;417d   ; la cuenta atras que traiga A
sube_el_paso:		; el siguiente `djnz` de la misma escena
	ld hl,0e001h		;4180   ; la escena sigue siendo la misma
	inc (hl)			;4183   ; pero el `djnz` de la cabecera caera un trozo mas alla
	ret			;4184
L_4185:
	djnz L_41A2		;4185   ; la escena 3, la de los rotulos
	ld hl,0e004h		;4187
	dec (hl)			;418a   ; la cuenta atras
	jr z,sube_el_paso		;418b   ; y al agotarse, al paso siguiente
	ld a,(0e002h)		;418d
	bit 5,a		;4190   ; el bit 5 de 0xE002 dice si juegan dos
	ld de,04542h		;4192   ; con uno, el guion de 0x4542
	jr z,L_419A		;4195
	ld de,0454ch		;4197   ; y con dos, el de 0x454C
L_419A:
	bit 2,(hl)		;419a   ; el bit 2 de la cuenta atras: se enciende y se apaga cada cuatro fotogramas
	jp z,pinta_guion_de_tiles		;419c   ; medio ciclo pintando
	jp borra_guion_de_tiles		;419f   ; y medio borrando: eso es el parpadeo
L_41A2:
	djnz L_41A9		;41a2   ; el paso 2
	call borra_las_variables_de_partida		;41a4
	jr espera_32_y_pasa		;41a7
L_41A9:
	ld a,0a6h		;41a9   ; 0xA6 es la melodia que suena aqui
	call arranca_una_pista		;41ab
	ld a,050h		;41ae   ; 80 fotogramas
	jr espera_y_sube_el_paso		;41b0
L_41B2:
	call limpia_la_pantalla		;41b2   ; la escena 4
	call monta_la_prueba		;41b5
	ld hl,0e069h		;41b8   ; y deja 0xE069 en alto, o sea a esperar
	ld (hl),001h		;41bb
espera_32_y_pasa:		; 32 fotogramas y a la escena siguiente
	ld a,020h		;41bd
espera_y_pasa:		; deja la cuenta atras en A y pasa de escena
	ld (0e004h),a		;41bf
pasa_a_la_escena_siguiente:		; sube (0xE000) y vuelve al paso 0
	ld hl,0e000h		;41c2   ; la escena siguiente
	inc (hl)			;41c5
L_41C6:
	xor a			;41c6   ; y siempre desde su primer paso
	ld (0e001h),a		;41c7
	ret			;41ca
L_41CB:
	call despacha_por_prueba		;41cb   ; la escena 5
	ld a,(0e069h)		;41ce
	or a			;41d1
	ret nz			;41d2
	ld a,(0e071h)		;41d3   ; los dos bytes de intentos, el del jugador 1 y el del 2
	ld hl,0e081h		;41d6
	or (hl)			;41d9
	jr z,espera_32_y_pasa		;41da   ; si ninguno de los dos tiene intentos, se acabo
	call cede_el_turno		;41dc   ; y si queda alguno, se le cede el turno
L_41DF:
	ld a,004h		;41df   ; la escena 4, que es la que monta la prueba
	jp L_416B		;41e1
L_41E4:
	call limpia_la_pantalla		;41e4   ; la escena 6: el recuento
	ld a,(0e070h)		;41e7   ; solo se suma si el jugador estaba jugando
	and a			;41ea
	ld de,0e096h		;41eb
	ld hl,0e066h		;41ee
	call nz,suma_a_la_puntuacion		;41f1   ; la marca del jugador 2 a su puntuacion
	ld a,(0e080h)		;41f4
	and a			;41f7
	ld de,0e099h		;41f8
	ld hl,0e063h		;41fb
	call nz,suma_a_la_puntuacion		;41fe   ; y la del jugador 1 a la suya
	ld hl,00100h		;4201   ; 0xE08E vuelve a 0x0001
	ld (0e08eh),hl		;4204
	jr pasa_a_la_escena_siguiente		;4207
L_4209:
	djnz L_421A		;4209   ; la escena 7, paso 1
	ld a,(0e012h)		;420b   ; hasta que 0xE012 no baje, no se sigue
	or a			;420e
	ret nz			;420f
	ld hl,0e002h		;4210
	ld a,(hl)			;4213
	and 0bfh		;4214   ; baja el bit 6: se acabo la partida
	ld (hl),a			;4216
	jp L_416A		;4217   ; y de vuelta a la escena 0
L_421A:
	call despacha_la_pantalla_de_resultados		;421a   ; el paso 2
	ld a,(0e08fh)		;421d
	and a			;4220
	ret nz			;4221
	ld a,(0e070h)		;4222   ; si a alguno de los dos jugadores le queda algo, no se pasa de escena
	ld hl,0e080h		;4225
	or (hl)			;4228
	jr nz,pasa_a_la_escena_siguiente		;4229
	jp sube_el_paso		;422b
L_422E:
	ld hl,0e06ah		;422e   ; la escena 8, la ultima de la tabla
	inc (hl)			;4231   ; una prueba mas
	xor a			;4232
	ld (0e06ch),a		;4233
	ld hl,0e110h		;4236   ; borra los dieciseis bytes de 0xE110
	ld de,0e111h		;4239
	ld bc,0000fh		;423c
	ld (hl),b			;423f
	ldir		;4240
	ld hl,0e090h		;4242   ; y los dieciseis de 0xE090
	ld de,0e091h		;4245
	ld c,00fh		;4248
	ld (hl),b			;424a
	ldir		;424b
	ld a,(0e06ah)		;424d   ; la prueba en curso, partida por dos
	rra			;4250
	and 07fh		;4251
	ld (0e073h),a		;4253   ; y el mismo valor a las cuatro parejas de bytes
	ld (0e074h),a		;4256
	ld (0e083h),a		;4259
	ld (0e084h),a		;425c
	xor a			;425f
	ld (0e072h),a		;4260
	ld (0e082h),a		;4263
	ld hl,0e002h		;4266   ; el bit 7 de 0xE002 es de quien es el turno
	set 7,(hl)		;4269
	ld a,(0e070h)		;426b   ; si el jugador 1 no juega, el turno es del 2
	and a			;426e
	jr z,L_4273		;426f
	res 7,(hl)		;4271
L_4273:
	ld hl,0e070h		;4273   ; los tres intentos del jugador 1
	call pone_los_tres_intentos		;4276
	ld l,080h		;4279   ; y los del 2
	call pone_los_tres_intentos		;427b
	jp L_41DF		;427e   ; a montar la prueba

; ----------------------------------------------------------------------
; Al jugador que apunte HL -0xE070 el uno, 0xE080 el otro- le deja un 3 en el byte siguiente, que es el que L_42CE mira antes de cederle el turno. Si el jugador no esta en la partida, no se toca nada.
; ----------------------------------------------------------------------
pone_los_tres_intentos:		; tres intentos al jugador que este en HL
	ld a,(hl)			;4281
	and a			;4282   ; si el jugador no juega, no hay intentos que poner
	ret z			;4283
	inc hl			;4284
	ld (hl),003h		;4285   ; tres
	ret			;4287

; ----------------------------------------------------------------------
; La rutina que el latido apila cuando NO hay partida en curso: lee el mando y el teclado del jugador 1 juntos, se queda con los botones recien pulsados y con ellos mueve el menu de PLAY SELECT.
; ----------------------------------------------------------------------
mandos_del_menu:		; lo que corre al terminar la escena cuando no hay partida
	ld e,08fh		;4288   ; 0x8F selecciona el mando 1 en el PSG
	call lee_el_mando_por_el_psg		;428a
	push af			;428d
	call teclado_del_jugador_1		;428e   ; el teclado, que sale con el MISMO formato que el mando
	pop bc			;4291   ; B trae lo del mando
	ld hl,0e051h		;4292   ; estado en 0xE051 y flancos en 0xE050
	call guarda_estado_y_flancos		;4295
	or a			;4298   ; si no hay nada recien pulsado, nada que hacer
	ret z			;4299
	ld hl,0e004h		;429a   ; la cuenta atras a cero: lo que se elija empieza ya
	ld (hl),000h		;429d
	ld l,(hl)			;429f   ; L = 0, o sea HL pasa a apuntar a 0xE000, la escena
	ld de,0e052h		;42a0
	ld b,(hl)			;42a3   ; B = la escena
	djnz L_42BF		;42a4   ; y solo la escena 1 hace caso al mando
	and 030h		;42a6   ; los bits 4 y 5 son los dos disparos
	jr z,L_42C9		;42a8
	ld a,(de)			;42aa   ; 0xE052 es la linea elegida del menu
	or a			;42ab
	ld a,040h		;42ac   ; arriba: un jugador
	jr z,L_42B2		;42ae
	ld a,060h		;42b0   ; abajo: dos
L_42B2:
	ld (0e002h),a		;42b2   ; y ese valor son los flags de la partida que empieza
	ld (hl),003h		;42b5   ; la escena 3
	inc hl			;42b7
	ld c,000h		;42b8   ; desde su paso 0
	ld (hl),c			;42ba
	dec c			;42bb
	jp L_4893		;42bc
L_42BF:
	ld (hl),001h		;42bf   ; en las demas escenas, el disparo lleva a la 1
	ld a,0b5h		;42c1   ; 0xB5 es la melodia del menu
	call arranca_una_pista		;42c3
	jp monta_el_titulo_entero		;42c6
L_42C9:
	ld a,(de)			;42c9   ; sin disparo, la flecha del menu cambia de linea
	xor 001h		;42ca   ; son dos: basta con darle la vuelta al bit 0
	ld (de),a			;42cc
	ret			;42cd

; ----------------------------------------------------------------------
; Mira los intentos del jugador que NO tiene el turno -0xE071 o 0xE081, elegido por el bit 7 de (0xE002)- y si le queda alguno le da la vuelta al bit 7, que es de quien es el turno. Si no le queda ninguno, el turno se queda donde esta.
; ----------------------------------------------------------------------
cede_el_turno:		; pasa el turno al otro jugador si le quedan intentos
	ld hl,0e071h		;42ce
	ld a,(0e002h)		;42d1   ; el bit 7 de 0xE002 se sube al acarreo
	add a,a			;42d4
	jr c,L_42D9		;42d5   ; con el turno del jugador 1, se miran los intentos del 2
	ld l,081h		;42d7
L_42D9:
	ld a,(hl)			;42d9   ; los intentos que le quedan al otro
	or a			;42da
	ret z			;42db   ; si no le queda ninguno, no hay relevo
	ld a,(0e002h)		;42dc
	xor 080h		;42df   ; y el relevo es dar la vuelta a ese bit
	ld (0e002h),a		;42e1
	ret			;42e4
apunta_al_jugador_de_turno:		; HL = 0xE071 o 0xE081
	ld hl,0e071h		;42e5
	ld a,(0e002h)		;42e8
	bit 7,a		;42eb   ; el bit 7 dice de quien es el turno
	ret z			;42ed   ; con el 1, HL ya esta
	ld l,081h		;42ee
	ret			;42f0

; ----------------------------------------------------------------------
; Borra de 0xE063 a 0xE120 -las puntuaciones, las marcas y todo lo del atleta- y deja montada la partida: el jugador 1 dentro con tres intentos, y el 2 tambien si el bit 5 de (0xE002) dice que juegan dos. El record de 0xE060 NO se toca: sobrevive a la partida.
; ----------------------------------------------------------------------
borra_las_variables_de_partida:		; y deja la partida montada
	ld hl,0e063h		;42f1   ; desde 0xE063, o sea justo por encima del record
	ld bc,000bdh		;42f4   ; 189 bytes
L_42F7:
	ld d,h			;42f7   ; el borrado a cero de toda la vida: (HL)=0 y ldir sobre si mismo
	ld e,l			;42f8
	inc e			;42f9
	ld (hl),000h		;42fa
	ldir		;42fc
	ld hl,00301h		;42fe   ; 0xE070 = 1 (esta dentro) y 0xE071 = 3 (intentos)
	ld (0e070h),hl		;4301
	ld de,00101h		;4304   ; y 0xE073 y 0xE074 a uno
	ld (0e073h),de		;4307
	ld a,(0e002h)		;430b
	and 020h		;430e   ; el bit 5 de 0xE002 es si juegan dos
	ret z			;4310   ; si juega uno, ya esta
	ld (0e080h),hl		;4311   ; y si juegan dos, lo mismo para el segundo
	ld (0e083h),de		;4314
	ret			;4318

; ----------------------------------------------------------------------
; Llena de 0xC3 los 128 bytes de la tabla de atributos de sprite (0x3B00). Un 0xC3 en el byte de la Y es una fila de la pantalla que no existe, asi que los 32 sprites quedan escondidos de golpe.
; ----------------------------------------------------------------------
esconde_los_sprites:		; los 128 bytes de atributos a 0xC3
	ld hl,03b00h		;4319   ; la tabla de atributos de sprite
	ld bc,00080h		;431c   ; 32 sprites por cuatro bytes
	ld a,0c3h		;431f   ; y un 0xC3 en la Y esconde el sprite
	jp 00056h		;4321   ; BIOS FILVRM - Fills VRAM with value

; ----------------------------------------------------------------------
; Suma en BCD los tres bytes de (DE) a los tres de (HL), de menos a mas peso. Si la suma se sale de 999999 clava el tope en 0xE060..0xE062. Y si no se sale, compara el resultado con el record y lo copia si lo ha batido.
; ----------------------------------------------------------------------
suma_a_la_puntuacion:		; tres bytes en BCD, con tope y record
	ld a,(0e002h)		;4324   ; el bit 6 de 0xE002 pasa al signo
	add a,a			;4327
	ret p			;4328   ; y sin partida en curso, no se suma nada
	ld b,003h		;4329   ; tres bytes
	and a			;432b   ; el acarreo, limpio antes de empezar
L_432C:
	ld a,(de)			;432c
	adc a,(hl)			;432d   ; el `adc` y el `daa` juntos: eso es sumar en decimal
	daa			;432e
	ld (hl),a			;432f
	inc hl			;4330
	inc de			;4331
	djnz L_432C		;4332
	jr nc,actualiza_el_record		;4334   ; y si no se ha desbordado, a mirar el record
	ld bc,09999h		;4336   ; 999999 en tres bytes, escritos con dos palabras que se solapan
	ld (0e060h),bc		;4339
	ld (0e061h),bc		;433d
	ret			;4341
actualiza_el_record:		; compara con 0xE060 y lo copia si se ha batido
	dec hl			;4342   ; HL vuelve al byte mas alto de la puntuacion
	ld b,003h		;4343
	ld de,0e062h		;4345   ; y DE al mas alto del record
	ld c,l			;4348   ; apunta el sitio, que despues hace falta para el ldd
L_4349:
	ld a,(de)			;4349   ; se compara de mas peso a menos
	sub (hl)			;434a
	jr c,L_4352		;434b   ; si el record es mayor, se acabo
	ret nz			;434d   ; y si son distintos y no ha habido acarreo, la puntuacion es la mayor
	dec l			;434e
	dec e			;434f
	djnz L_4349		;4350
L_4352:
	ld l,c			;4352   ; copiar hacia atras, de mas peso a menos
	ld bc,00003h		;4353
	ld e,062h		;4356
	lddr		;4358   ; y el record ya es este
	ret			;435a

; ----------------------------------------------------------------------
; Saca por el puerto de datos del VDP los digitos de un numero en BCD leido de (DE) hacia atras, B bytes o sea 2B digitos. L hace de mascara de ceros: mientras vale 0 todo digito sale como el tile 0x00 -el espacio-, y en cuanto aparece un digito distinto de cero se queda en 0xFF y ya salen todos. El ultimo byte siempre se pinta entero, para que un cero valga 0 y no un hueco.
; ----------------------------------------------------------------------
escribe_cifras_bcd:		; los digitos de un numero BCD, sin ceros a la izquierda
	call setwrt_corto		;435b   ; coloca el VDP donde toca y deja el puerto de datos a mano
	push hl			;435e
	ld l,000h		;435f   ; la mascara de ceros: de momento se comen todos
L_4361:
	ld a,(de)			;4361   ; el byte, que trae dos digitos
	rra			;4362
	rra			;4363
	rra			;4364
	rra			;4365
	and 00fh		;4366   ; el de arriba primero
	jr z,L_436C		;4368   ; mientras sean ceros, no se pinta
	ld l,0ffh		;436a   ; y en cuanto hay un digito, ya salen todos
L_436C:
	dec b			;436c   ; en el ultimo byte
	jr nz,L_4371		;436d
	ld l,0ffh		;436f   ; siempre se pinta, aunque sea un cero
L_4371:
	inc b			;4371
	add a,010h		;4372   ; los digitos son los tiles del 0x10 al 0x19
	and l			;4374   ; la mascara: 0 lo convierte en el tile del espacio
	out (c),a		;4375   ; y a la VRAM
	ld a,(de)			;4377
	and 00fh		;4378   ; el digito de abajo
	jr z,L_437E		;437a
	ld l,0ffh		;437c
L_437E:
	add a,010h		;437e
	and l			;4380
	out (c),a		;4381
	dec de			;4383   ; hacia atras: el numero se lee de mas peso a menos
	djnz L_4361		;4384
	pop hl			;4386
	ret			;4387

; ----------------------------------------------------------------------
; La rutina que el latido apila cuando SI hay partida: cada dieciseis fotogramas pinta o borra un rotulo de la tabla de nombres, y la cuenta la lleva el contador de fotogramas. Encendido cuarenta y ocho fotogramas, apagado dieciseis. En el ciclismo no hay rotulo que parpadear.
; ----------------------------------------------------------------------
parpadea_el_rotulo_de_la_prueba:		; lo que corre al terminar la escena con partida
	ld a,(0e06ah)		;4388   ; la prueba en curso
	and 003h		;438b
	or a			;438d
	ret z			;438e   ; la 0, el ciclismo, no tiene rotulo
	ld hl,03832h		;438f   ; la casilla 0x32 de la pantalla
	cp 002h		;4392   ; salvo en el curling
	jr nz,L_4399		;4394
	ld hl,03810h		;4396   ; que lo lleva en la 0x10
L_4399:
	ld de,(0e002h)		;4399   ; de un tiron: E = los flags y D = el contador de fotogramas
	ld a,d			;439d
	and 00fh		;439e   ; uno de cada dieciseis fotogramas
	ret nz			;43a0
	ld c,a			;43a1   ; A ya vale 0, o sea la mascara que BORRA
	ld a,d			;43a2
	and 030h		;43a3   ; los bits 4 y 5 del contador
	jr z,L_43A8		;43a5   ; con los dos a cero -dieciseis de cada sesenta y cuatro-, apagado
	dec c			;43a7   ; y el resto del tiempo, encendido
L_43A8:
	bit 7,e		;43a8   ; el bit 7 de los flags, de quien es el turno
	ld de,04561h		;43aa   ; el rotulo de un jugador
	jr z,L_43B2		;43ad
	ld de,04565h		;43af   ; y el del otro
L_43B2:
	jp L_441D		;43b2   ; el interprete de guiones, entrando con el destino ya puesto
resta_de_24_bits:		; CDE -= los tres bytes de (HL)
	ld hl,0e08bh		;43b5   ; los tres bytes que se restan salen de 0xE08B
L_43B8:
	ld a,e			;43b8
	sub (hl)			;43b9   ; el de menos peso, sin acarreo
	ld e,a			;43ba
	inc hl			;43bb
	ld a,d			;43bc
	sbc a,(hl)			;43bd   ; y los otros dos con el
	ld d,a			;43be
	inc hl			;43bf
	ld a,c			;43c0
	sbc a,(hl)			;43c1
	ld c,a			;43c2
	ret			;43c3
limpia_la_pantalla:		; esconde los sprites y borra la tabla de nombres
	call esconde_los_sprites		;43c4
	ld hl,03800h		;43c7   ; la tabla de nombres
	ld bc,00300h		;43ca   ; 768 casillas, o sea las tres pantallas de 32x8
	xor a			;43cd   ; el tile 0 es el espacio
	jp 00056h		;43ce   ; BIOS FILVRM - Fills VRAM with value

; ----------------------------------------------------------------------
; SETWRT, y ademas deja en C' el puerto de datos del VDP, que la BIOS guarda en 0x0006. Es lo que permite a las rutinas de abajo escribir a la VRAM con un `out (c),a` pelado, sin pasar por la BIOS en cada byte.
; ----------------------------------------------------------------------
setwrt_y_guarda_el_puerto:		; SETWRT dejando el puerto de datos en C'
	ex af,af'			;43d1
	call 00053h		;43d2   ; BIOS SETWRT - Enables VDP to write | SETWRT deja el VDP apuntando y en modo escritura
	exx			;43d5
	ld a,(00006h)		;43d6   ; la BIOS guarda ahi el puerto de datos del VDP
	ld c,a			;43d9   ; y se queda en C' para todo lo que venga
	exx			;43da
	ex af,af'			;43db
	ret			;43dc
ldirvm:		; LDIRVM con los registros al reves
	ex de,hl			;43dd
	jp 0005ch		;43de   ; BIOS LDIRVM - Block transfers to VRAM from memory

; ----------------------------------------------------------------------
; SCREEN 2 tiene la tabla de patrones partida en tres tercios de 2 KB, uno por cada tercio de la pantalla. Estas tres rutinas -copiar, llenar y descomprimir- hacen lo mismo tres veces subiendo 0x800 cada vez, que es como se pone un dibujo igual en toda la pantalla.
; ----------------------------------------------------------------------
ldirvm_en_los_tres_tercios:		; el mismo bloque en las tres pantallas
	exx			;43e1
	ld b,003h		;43e2   ; tres tercios
L_43E4:
	exx			;43e4   ; la fila que se copia
	push bc			;43e5
	push de			;43e6
	call ldirvm		;43e7   ; a la VRAM
	ld de,00800h		;43ea   ; 2 KB, que es lo que ocupa un tercio
	add hl,de			;43ed
	pop de			;43ee
	pop bc			;43ef
	exx			;43f0
	djnz L_43E4		;43f1
	ret			;43f3
filvrm_en_los_tres_tercios:		; el mismo relleno en las tres pantallas
	ld d,003h		;43f4   ; tres tercios
L_43F6:
	push bc			;43f6
	push de			;43f7
	call 00056h		;43f8   ; BIOS FILVRM - Fills VRAM with value
	ld de,00800h		;43fb
	add hl,de			;43fe
	pop de			;43ff
	pop bc			;4400
	dec d			;4401
	jr nz,L_43F6		;4402
	ret			;4404
descomprime_en_los_tres_tercios:		; el mismo bloque RLE en las tres pantallas
	ld b,003h		;4405   ; tres tercios
L_4407:
	push bc			;4407   ; el tercio de arriba, el de en medio y el de abajo
	push de			;4408
	call descomprime_a_vram_en		;4409
	ld de,00800h		;440c   ; 2 KB: lo que ocupa un tercio
	add hl,de			;440f
	pop de			;4410
	pop bc			;4411
	djnz L_4407		;4412   ; y el siguiente
	ret			;4414

; ----------------------------------------------------------------------
; EL INTERPRETE DE GUIONES DE ROTULO. Un guion son [destino de VRAM, word] y detras los tiles, uno por casilla; 0xFE cambia de destino y 0xFF termina. C es la mascara con la que sale cada tile: 0xFF lo pinta tal cual y 0x00 lo convierte en el tile del espacio, o sea BORRA el mismo rotulo sin necesidad de una segunda tabla. De aqui salen todos los rotulos del cartucho.
; ----------------------------------------------------------------------
pinta_guion_de_tiles:		; el interprete de guiones, pintando
	ld c,0ffh		;4415   ; la mascara que PINTA
L_4417:
	ex de,hl			;4417   ; el destino de VRAM, que va en la cabecera del guion
	ld e,(hl)			;4418
	inc hl			;4419
	ld d,(hl)			;441a
	ex de,hl			;441b
	inc de			;441c   ; y los tiles empiezan detras
L_441D:
	ld a,(de)			;441d   ; el tile
	inc de			;441e
	ld b,a			;441f
	inc b			;4420   ; 0xFF termina el guion
	ret z			;4421
	inc b			;4422
	jr z,L_4417		;4423   ; 0xFE trae otro destino
	and c			;4425   ; la mascara: con C=0 lo que sale es el tile del espacio
	call 0004dh		;4426   ; BIOS WRTVRM - Writes data in VRAM | y a la casilla
	inc hl			;4429   ; la de al lado
	jr L_441D		;442a
borra_guion_de_tiles:		; el mismo interprete, con la mascara a cero
	ld c,000h		;442c   ; la mascara que BORRA
	jr L_4417		;442e

; ----------------------------------------------------------------------
; El parpadeo: (0xE07D) baja un punto por llamada y su bit 4 decide si toca pintar o borrar, o sea dieciseis fotogramas encendido y dieciseis apagado. Cuando llega a cero devuelve Z, que es como el rotulo dice que ya ha parpadeado bastante.
; ----------------------------------------------------------------------
parpadea_guion_de_tiles:		; pinta o borra segun el bit 4 de (0xE07D)
	ld hl,0e07dh		;4430
	dec (hl)			;4433   ; la cuenta atras del parpadeo
	ret z			;4434   ; y al llegar a cero, Z: se acabo el parpadeo
	bit 4,(hl)		;4435   ; el bit 4: cambia cada dieciseis
	push af			;4437
	call nz,pinta_guion_de_tiles		;4438
	pop af			;443b
	call z,borra_guion_de_tiles		;443c
	or 0ffh		;443f   ; devuelve NZ, que es "sigo parpadeando"
	ret			;4441

; ----------------------------------------------------------------------
; EL DESCOMPRESOR RLE A VRAM. Un bloque es [destino de VRAM, word] y detras los mandatos, un byte cada uno: 0x00 cierra el bloque, 0x80 vuelve a la cabecera y cambia de destino, 0x01..0x7F repite esa cuenta de veces el byte siguiente, y 0x81..0xFF copia tal cual los (n & 0x7F) bytes que vengan detras. Es el mismo formato de Ping Pong, de Soccer y de Road Fighter, pero sin el espejo de aquel. Rehecho en tools/rle.py.
; ----------------------------------------------------------------------
descomprime_a_vram:		; el RLE, leyendo el destino de la cabecera
	ex de,hl			;4442   ; el destino, de la cabecera del bloque
	ld e,(hl)			;4443
	inc hl			;4444
	ld d,(hl)			;4445
	ex de,hl			;4446
	inc de			;4447
descomprime_a_vram_en:		; el mismo, con el destino ya en HL
	call setwrt_y_guarda_el_puerto		;4448   ; coloca el VDP y deja el puerto en C'
L_444B:
	ld a,(de)			;444b   ; el mandato
	and a			;444c
	ret z			;444d   ; 0x00 cierra el bloque
	inc de			;444e
	ld b,a			;444f
	and 07fh		;4450   ; quitarle el bit 7
	cp b			;4452   ; si no ha cambiado, es que no lo tenia: repeticion
	jr z,L_4463		;4453
	and a			;4455   ; y el 0x80 pelado
	jr z,descomprime_a_vram		;4456   ; vuelve a la cabecera: otro destino y a seguir
	ld b,a			;4458   ; los que se copian tal cual
L_4459:
	ld a,(de)			;4459
	inc de			;445a
	exx			;445b
	out (c),a		;445c   ; a la VRAM, sin pasar por la BIOS
	exx			;445e
	djnz L_4459		;445f
	jr L_444B		;4461
L_4463:
	ld a,(de)			;4463   ; el byte que se repite
	inc de			;4464
L_4465:
	exx			;4465
	out (c),a		;4466   ; y sale tantas veces como diga la cuenta
	exx			;4468
	djnz L_4465		;4469
	jr L_444B		;446b
borra_la_vram:		; los 16 KB a cero, con la pantalla apagada
	ld a,0b8h		;446d   ; 0xB8 al reproductor: callar
	call L_4BA2		;446f
	ld a,0b5h		;4472   ; y con la pantalla apagada
	call apaga_la_pantalla		;4474
	ld hl,00000h		;4477   ; desde el byte 0 de la VRAM
	ld bc,04000h		;447a   ; los 16 KB enteros
	xor a			;447d
	call 00056h		;447e   ; BIOS FILVRM - Fills VRAM with value
pon_los_registros_del_vdp:		; los ocho valores de 0x4492
	ld hl,04492h		;4481   ; la tabla de los ocho valores
	ld d,008h		;4484   ; ocho registros
	ld c,000h		;4486   ; empezando por el 0
L_4488:
	ld b,(hl)			;4488
	call 00047h		;4489   ; BIOS WRTVDP - Writes data in the VDP-register | WRTVDP: B al registro C
	inc hl			;448c
	inc c			;448d   ; el siguiente registro
	dec d			;448e
	jr nz,L_4488		;448f
	ret			;4491

; ----------------------------------------------------------------------
; DATOS registros_del_vdp: los ocho valores, en orden, que escribe el bucle de
;   0x4488
;   0x4492..0x449a  (8 bytes)
DATA_registros_del_vdp:
	defb 002h,0e2h,00eh,07fh,007h,076h,003h,0e4h	; 4492  .....v..

; ======================================================================
; CODIGO 0x449a..0x4514  (122 bytes)
; ======================================================================


pon_el_color_de_fondo:		; el registro 7
	ld c,007h		;449a   ; el registro 7 es el color del texto y el del fondo
	jp escribe_registro_del_vdp		;449c

; ----------------------------------------------------------------------
; Lee a los dos jugadores una vez por fotograma. Cada uno suma su mando y su teclado con un `or`, asi que las dos cosas valen a la vez y sin elegir, y de cada uno quedan dos bytes: el estado (0xE009 y 0xE007) y los botones RECIEN pulsados (0xE008 y 0xE006).
; ----------------------------------------------------------------------
lee_los_mandos:		; los dos jugadores, mando y teclado juntos
	ld e,08fh		;449f   ; 0x8F es el mando 1
	call lee_el_mando_por_el_psg		;44a1
	push af			;44a4
	call teclado_del_jugador_1		;44a5   ; y su teclado
	pop bc			;44a8
	ld hl,0e009h		;44a9   ; estado en 0xE009, flancos en 0xE008
	call guarda_estado_y_flancos		;44ac
	ld e,0cfh		;44af   ; 0xCF es el mando 2
	call lee_el_mando_por_el_psg		;44b1
	push af			;44b4
	call teclado_del_jugador_2		;44b5   ; y el teclado del jugador 2
	pop bc			;44b8
	ld hl,0e007h		;44b9   ; estado en 0xE007, flancos en 0xE006

; ----------------------------------------------------------------------
; El truco de los flancos, en siete instrucciones: A trae lo que esta pulsado ahora, (HL) lo que estaba pulsado antes. El `xor` da lo que ha cambiado, y el `and` con lo de ahora deja solo lo que se acaba de pulsar. Lo pulsado va a (HL) y lo recien pulsado a (HL-1). Sin esto, mantener un boton contaria una vez por fotograma.
; ----------------------------------------------------------------------
guarda_estado_y_flancos:		; deja el estado en (HL) y los flancos en (HL-1)
	or b			;44bc   ; lo del teclado mas lo del mando
	ld c,(hl)			;44bd   ; lo que estaba pulsado antes
	ld (hl),a			;44be   ; y lo de ahora ya es lo de antes
	xor c			;44bf   ; lo que ha cambiado
	and (hl)			;44c0   ; y de eso, lo que esta pulsado: lo RECIEN pulsado
	dec hl			;44c1
	ld (hl),a			;44c2   ; que se guarda un byte mas abajo
	ret			;44c3
lee_el_mando_por_el_psg:		; los seis bits del puerto de mandos
	ld a,00fh		;44c4   ; el registro 15 del PSG elige que mando se lee
	call 00093h		;44c6   ; BIOS WRTPSG - Writes data to PSG-register
	di			;44c9   ; y el 14 se lee con las interrupciones cerradas
	ld a,00eh		;44ca
	call 00096h		;44cc   ; BIOS RDPSG - Reads value from PSG-register
	ei			;44cf
	cpl			;44d0   ; el PSG da los bits al reves: pulsado es 0
	and 03fh		;44d1   ; y solo cuentan seis: cuatro direcciones y dos disparos
	ret			;44d3

; ----------------------------------------------------------------------
; El teclado del jugador 1, traducido bit a bit al MISMO formato que el mando -bit 0 arriba, 1 abajo, 2 izquierda, 3 derecha, 4 disparo A, 5 disparo B-, que es lo que permite sumarlos luego con un simple `or`. Las flechas son la fila 8 de la matriz, el espacio es el disparo A y SELECT, de la fila 7, el disparo B. Las rotaciones son acumulativas: cinco en total sobre el mismo byte, y de cada paso se sacan los bits que ya han caido en su sitio.
; ----------------------------------------------------------------------
teclado_del_jugador_1:		; las teclas, con el formato del mando
	ld a,007h		;44d4   ; la fila 7 de la matriz
	call 00141h		;44d6   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	cpl			;44d9   ; pulsado es 0: al derecho
	rrca			;44da   ; SELECT, del bit 6 al 5
	and 020h		;44db   ; y el bit 5 es el disparo B
	ld e,a			;44dd
	ld a,008h		;44de   ; la fila 8: las cuatro flechas, DEL, INS, HOME y el espacio
	call 00141h		;44e0   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	cpl			;44e3   ; al derecho
	rrca			;44e4
	rrca			;44e5
	ld b,a			;44e6   ; apuntar el byte rotado dos veces
	and 004h		;44e7   ; la izquierda ya ha caido en el bit 2
	or e			;44e9   ; y se suma a lo que traia SELECT
	ld c,a			;44ea
	ld a,b			;44eb
	rrca			;44ec   ; dos rotaciones mas, cuatro en total
	rrca			;44ed
	ld b,a			;44ee
	and 018h		;44ef   ; la derecha en el bit 3 y el espacio en el bit 4, que es el disparo A
	or c			;44f1
	ld c,a			;44f2
	ld a,b			;44f3
	rrca			;44f4   ; la quinta
	and 003h		;44f5   ; arriba en el bit 0 y abajo en el bit 1
	or c			;44f7
	ret			;44f8

; ----------------------------------------------------------------------
; El teclado del jugador 2, y es mucho mas corto que el del 1 porque solo tiene DOS teclas: SHIFT, que entra como si fuese la derecha del mando, y la Q, como el disparo A. Sale con el mismo formato que el mando para poder sumarse a el con un `or`.
; ----------------------------------------------------------------------
teclado_del_jugador_2:		; solo dos teclas, con el formato del mando
	ld a,006h		;44f9   ; la fila 6 de la matriz: SHIFT, CTRL, GRAPH, CAPS, CODE y las tres teclas de funcion
	call 00141h		;44fb   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	ld b,000h		;44fe   ; de momento, nada pulsado
	rra			;4500   ; el bit 0 de esa fila es el SHIFT
	jr c,L_4505		;4501   ; y pulsado es 0, asi que con acarreo NO esta pulsado
	ld b,008h		;4503   ; el bit 3 es la derecha del mando
L_4505:
	ld a,004h		;4505   ; la fila 4: de la K a la R
	call 00141h		;4507   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	bit 6,a		;450a   ; su bit 6 es la Q
	ld a,000h		;450c
	jr nz,L_4512		;450e   ; sin la Q, nada
	ld a,010h		;4510   ; y con ella, el bit 4, que es el disparo A
L_4512:
	or b			;4512   ; las dos juntas
	ret			;4513

; ----------------------------------------------------------------------
; DATOS rle_konami_software: 17 B -> 20 de VRAM: la raya de doce tiles de
;   0x394A y la palabra SOFTWARE en 0x396C
;   0x4514..0x4525  (17 bytes)
DATA_rle_konami_software:
	defb 04ah,039h,00ch,05ah,080h,06ch,039h,088h,033h,02fh,026h,034h,037h,021h,032h,025h,000h	; 4514  J9.Z.l9.3/&47!2%.

; ----------------------------------------------------------------------
; DATOS guion_del_menu: 39 B, tres destinos: (c)KONAMI 1985 en 0x396A, PLAY
;   SELECT en 0x39EB y 1PLAYER en 0x3A4D
;   0x4525..0x454c  (39 bytes)
DATA_guion_del_menu:
	defb 06ah,039h,01ah,02bh,02fh,02eh,021h,02dh,029h,000h,011h,019h,018h	; 4525  j9.+/.!-)....
	defb 015h,0feh,0ebh,039h,030h,02ch,021h,039h,000h,033h,025h,02ch,025h,023h	; 4532  ...90,!9.3%,%#
	defb 034h,0feh,04dh,03ah,011h,030h,02ch,021h,039h,025h,032h,0ffh	; 4540  4.M:.0,!9%2.

; ----------------------------------------------------------------------
; DATOS guion_2players: 11 B: 2PLAYERS en 0x3A8D
;   0x454c..0x4557  (11 bytes)
DATA_guion_2players:
	defb 08dh,03ah,012h,030h,02ch,021h,039h,025h,032h,033h,0ffh	; 454c  .:.0,!9%23.

; ----------------------------------------------------------------------
; DATOS guion_del_cursor: 3 B SIN cabecera: los dos tiles de la manita, con el
;   destino ya en HL; entra por L_441D desde 0x48AA
;   0x4557..0x455a  (3 bytes)
DATA_guion_del_cursor:
	defb 01bh,01ch,0ffh	; 4557

; ----------------------------------------------------------------------
; DATOS guion_foul: 7 B: FOUL en la casilla 0x3AAE de la pantalla; lo pinta
;   0xABC2 cuando la piedra del curling se sale de la pista
;   0x455a..0x4561  (7 bytes)
DATA_guion_foul:
	defb 0aeh,03ah,026h,02fh,035h,02ch,0ffh	; 455a

; ----------------------------------------------------------------------
; DATOS guion_1up: 4 B SIN cabecera: 1UP, con el destino ya en HL; lo carga
;   0x43AA
;   0x4561..0x4565  (4 bytes)
DATA_guion_1up:
	defb 011h,035h,030h,0ffh	; 4561

; ----------------------------------------------------------------------
; DATOS guion_2up: 4 B SIN cabecera: 2UP, con el destino ya en HL; lo carga
;   0x43AF
;   0x4565..0x4569  (4 bytes)
DATA_guion_2up:
	defb 012h,035h,030h,0ffh	; 4565

; ======================================================================
; CODIGO 0x4569..0x459b  (50 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Monta lo que hace falta para escribir: los dieciseis primeros tiles se pintan de un color plano cada uno -tinta y fondo iguales, o sea rectangulos macizos-, detras van los 48 patrones de la fuente en 0x2080 y en blanco, y por ultimo el trozo de tabla de nombres del logotipo. Los tres tercios de SCREEN 2 reciben lo mismo, asi que el texto se puede escribir en cualquier fila de la pantalla.
; ----------------------------------------------------------------------
monta_la_fuente:		; los 48 patrones del texto, en blanco, y el color plano
	xor a			;4569   ; el color del tile 0
	ld hl,00000h		;456a   ; la tabla de color empieza en el byte 0 de la VRAM
	ld de,00008h		;456d   ; ocho bytes por tile
	ld b,010h		;4570   ; los dieciseis primeros tiles
L_4572:
	push bc			;4572
	ld bc,00008h		;4573   ; los ocho bytes de un tile
	push hl			;4576
	call filvrm_en_los_tres_tercios		;4577   ; y en los tres tercios de la pantalla
	pop hl			;457a
	add hl,de			;457b   ; el color del tile siguiente
	add a,011h		;457c   ; 0x11 mas: tinta y fondo suben a la vez, asi que cada tile es un color macizo
	pop bc			;457e
	djnz L_4572		;457f
	ld de,0459bh		;4581   ; los patrones de la fuente
	ld hl,02080h		;4584   ; en 0x2080, o sea a partir del tile 0x10
	call descomprime_en_los_tres_tercios		;4587
	ld de,0470ch		;458a   ; y el trozo de tabla de nombres que el propio bloque situa
	call descomprime_a_vram		;458d
	ld a,0f0h		;4590   ; 0xF0: tinta blanca sobre fondo transparente
	ld hl,00080h		;4592   ; desde el color del tile 0x10
	ld bc,00180h		;4595   ; y los 48 de la fuente: toda ella sale en blanco
	jp filvrm_en_los_tres_tercios		;4598

; ----------------------------------------------------------------------
; DATOS rle_la_fuente: 369 B -> 384 de VRAM en 0x2080: los 48 patrones de la
;   fuente, del tile 0x10 al 0x3F
;   0x459b..0x470c  (369 bytes)
DATA_rle_la_fuente:
	defb 08bh,000h,01ch,022h,063h,063h,063h,022h,01ch,000h,018h,038h,004h,018h,0c9h,07eh	; 459b  ..."ccc"...8...~
	defb 000h,03eh,063h,003h,00eh,03ch,070h,07fh,000h,03eh,063h,003h,00eh,003h,063h,03eh	; 45ab  .>c..<p..>c...c>
	defb 000h,00eh,01eh,036h,066h,066h,07fh,006h,000h,07fh,060h,07eh,063h,003h,063h,03eh	; 45bb  ...6ff....`~c.c>
	defb 000h,03eh,063h,060h,07eh,063h,063h,03eh,000h,07fh,063h,006h,00ch,018h,018h,018h	; 45cb  .>c`~cc>..c.....
	defb 000h,03eh,063h,063h,03eh,063h,063h,03eh,000h,03eh,063h,063h,03fh,003h,063h,03eh	; 45db  .>cc>cc>.>cc?.c>
	defb 03ch,042h,099h,0a1h,0a1h,099h,042h,03ch,09ch,000h,000h,004h,06eh,084h,064h,014h	; 45eb  <B....B<....n.d.
	defb 066h,000h,000h,001h,001h,0a3h,0d5h,095h,097h,000h,000h,001h,041h,053h,065h,045h	; 45fb  f...........ASeE
	defb 047h,000h,000h,01bh,00dh,004h,009h,08ch,000h,000h,060h,0a0h,020h,020h,020h,030h	; 460b  G.........`.   0
	defb 000h,010h,028h,010h,005h,000h,0c1h,01ch,036h,063h,063h,07fh,063h,063h,000h,07eh	; 461b  ..(.....6cc.cc.~
	defb 063h,063h,07eh,063h,063h,07eh,000h,03eh,063h,060h,060h,060h,063h,03eh,000h,07ch	; 462b  cc~cc~.>c```c>.|
	defb 066h,063h,063h,063h,066h,07ch,000h,07fh,060h,060h,07eh,060h,060h,07fh,000h,07fh	; 463b  fcccf|..``~``...
	defb 060h,060h,07eh,060h,060h,060h,000h,03eh,063h,060h,067h,063h,063h,03fh,000h,063h	; 464b  ``~```.>c`gcc?.c
	defb 063h,063h,07fh,063h,063h,063h,000h,03ch,005h,018h,083h,03ch,000h,01fh,004h,006h	; 465b  cc.ccc.<...<....
	defb 08bh,066h,03ch,000h,063h,066h,06ch,078h,07ch,06eh,067h,000h,006h,060h,093h,07fh	; 466b  .f<.cflx|ng..`..
	defb 000h,063h,077h,07fh,07fh,06bh,063h,063h,000h,063h,073h,07bh,07fh,06fh,067h,063h	; 467b  .cw..kcc.cs{.ogc
	defb 000h,03eh,005h,063h,0a3h,03eh,000h,07eh,063h,063h,063h,07eh,060h,060h,000h,03eh	; 468b  .>.c.>.~ccc~``.>
	defb 063h,063h,063h,06fh,066h,03dh,000h,07eh,063h,063h,062h,07ch,066h,063h,000h,03eh	; 469b  cccof=.~ccb|fc.>
	defb 063h,060h,03eh,003h,063h,03eh,000h,07eh,006h,018h,001h,000h,006h,063h,082h,03eh	; 46ab  c`>.c>.~.....c.>
	defb 000h,004h,063h,0a3h,036h,01ch,008h,000h,063h,063h,06bh,06bh,07fh,077h,022h,000h	; 46bb  ..c.6...cckk.w".
	defb 063h,076h,03ch,01ch,01eh,037h,063h,000h,066h,066h,07eh,03ch,018h,018h,018h,000h	; 46cb  cv<..7c.ff~<....
	defb 07fh,007h,00eh,01ch,038h,070h,07fh,0a8h,000h,000h,00ch,012h,010h,010h,012h,00ch	; 46db  ....8p..........
	defb 000h,000h,0a8h,07ch,054h,054h,054h,056h,000h,000h,004h,008h,010h,020h,040h,080h	; 46eb  ...|TTTV..... @.
	defb 000h,000h,031h,04ah,023h,012h,04ah,031h,000h,000h,08ch,052h,0d0h,010h,012h,0cch	; 46fb  ..1J#.J1...R....
	defb 000h	; 470b

; ----------------------------------------------------------------------
; DATOS rle_nombres_del_logotipo: 19 B -> 16 casillas: el trozo de tabla de
;   nombres que el propio bloque situa
;   0x470c..0x471f  (19 bytes)
DATA_rle_nombres_del_logotipo:
	defb 0d8h,030h,083h,000h,00fh,01fh,004h,0ffh,089h,00fh,000h,000h,0feh,0e0h,0e0h,0c0h,0c0h,080h,000h	; 470c  .0.................

; ======================================================================
; CODIGO 0x471f..0x4773  (84 bytes)
; ======================================================================


prepara_el_logotipo:		; catorce pasos, empezando por la fila de abajo
	ld a,00eh		;471f   ; catorce pasos de cortina
	ld (0e00ah),a		;4721
	ld hl,03aaah		;4724   ; y la primera fila, la de mas abajo de la pantalla
	ld (0e00eh),hl		;4727
	jp L_4010		;472a   ; de paso pasa por el cadaver de 0x4010
monta_los_tiles_del_logotipo:		; los 27 patrones grandes, en blanco
	ld de,04773h		;472d   ; los patrones del logotipo
	ld hl,06200h		;4730   ; 0x6200 son los 0x2200 de la VRAM: SETWRT tira los dos bits de arriba de H
	call descomprime_en_los_tres_tercios		;4733
	ld hl,00200h		;4736   ; desde el color del tile 0x40
	ld bc,000d8h		;4739   ; los 27 patrones
	ld a,0f0h		;473c   ; y todos en blanco
	jp filvrm_en_los_tres_tercios		;473e

; ----------------------------------------------------------------------
; LA CORTINA DEL LOGOTIPO. El logotipo de Konami no se dibuja de golpe: se pinta tres filas de tiles y se borra la de debajo, y en la llamada siguiente todo eso sube una fila. Catorce llamadas -una cada dos fotogramas- y el dibujo entero ha recorrido la pantalla de abajo arriba. Los veintiseis tiles van seguidos, del 0x40 al 0x59, asi que basta con ir subiendo el indice: no hay tabla ninguna.
; ----------------------------------------------------------------------
sube_el_logotipo_una_fila:		; la cortina, un paso por llamada
	ld hl,(0e00eh)		;4741   ; la fila por la que va la cortina
	ld de,0ffe0h		;4744   ; restarle 0x20, que es una fila de la tabla de nombres
	add hl,de			;4747
	ld (0e00eh),hl		;4748   ; y la proxima vez sera una mas arriba
	ld a,040h		;474b   ; el primer tile del logotipo
	ld b,003h		;474d   ; tres en la fila de arriba
	call fila_de_tiles_seguidos		;474f
	ld bc,00b0ch		;4752   ; once en la de en medio
	call fila_de_tiles_seguidos		;4755
	ld b,c			;4758   ; y doce en la de abajo
	call fila_de_tiles_seguidos		;4759
	xor a			;475c   ; borra las doce casillas de mas abajo, que es por donde acaba de pasar
	call 00056h		;475d   ; BIOS FILVRM - Fills VRAM with value | B ha quedado a cero en el djnz: son los doce que dice C
	ld hl,0e00ah		;4760   ; un paso menos
	dec (hl)			;4763   ; y al llegar a cero devuelve Z, que es como dice que ya ha subido del todo
	ret			;4764
fila_de_tiles_seguidos:		; B tiles con el indice subiendo, y baja una fila
	push hl			;4765
L_4766:
	call 0004dh		;4766   ; BIOS WRTVRM - Writes data in VRAM | el tile, a la casilla
	inc hl			;4769
	inc a			;476a   ; el siguiente indice: los tiles del logotipo van seguidos
	djnz L_4766		;476b
	pop de			;476d   ; la fila por la que se empezo
	ld hl,00020h		;476e   ; y se devuelve la de debajo
	add hl,de			;4771
	ret			;4772

; ----------------------------------------------------------------------
; DATOS rle_tiles_grandes: 151 B -> 216 de VRAM en 0x2200: los 27 patrones del
;   tile 0x40 al 0x5A
;   0x4773..0x480a  (151 bytes)
DATA_rle_tiles_grandes:
	defb 00fh,000h,001h,001h,006h,000h,082h,0ffh,0feh,008h,00fh,084h,0c3h,0c7h,0cfh,0dfh	; 4773  ................
	defb 003h,0ffh,089h,0feh,0fch,0f8h,0f0h,0e0h,0c0h,080h,007h,007h,005h,000h,083h,003h	; 4783  ................
	defb 0cfh,0dfh,005h,000h,083h,0e1h,0f9h,07dh,005h,000h,083h,0efh,0ffh,0f7h,005h,000h	; 4793  .......}........
	defb 083h,007h,08fh,09eh,005h,000h,083h,0f0h,0f8h,078h,005h,000h,083h,0f7h,0ffh,0fbh	; 47a3  .........x......
	defb 005h,000h,08bh,08fh,0dfh,0f7h,00ch,01eh,01eh,00ch,000h,01eh,09eh,09eh,008h,00fh	; 47b3  ................
	defb 090h,0ffh,0ffh,0dfh,0cfh,0c7h,0c3h,0c1h,0c0h,007h,087h,0c7h,0efh,0ffh,0ffh,0ffh	; 47c3  ................
	defb 0fch,004h,0deh,084h,09eh,09fh,00fh,003h,005h,03dh,083h,07dh,0f9h,0e1h,008h,0e3h	; 47d3  .........=.}....
	defb 090h,0dch,0c0h,0c7h,0deh,0dch,0deh,0cfh,0c3h,03ch,07ch,0fch,03ch,03ch,07ch,0fch	; 47e3  .........<|.<<|.
	defb 0deh,008h,0f1h,008h,0e3h,008h,0deh,088h,038h,044h,0bah,0aah,0b2h,0aah,044h,038h	; 47f3  ........8D....D8
	defb 003h,000h,001h,0ffh,004h,000h,000h	; 4803

; ======================================================================
; CODIGO 0x480a..0x4878  (110 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LA PANTALLA DEL TITULO. Por orden: el color de fondo, la pantalla limpia, la fuente, los 66 patrones del rotulo HYPER SPORTS 3 con su color, y por ultimo los bloques repetidos, que son el ahorro: cuatro trozos del rotulo son el MISMO patron de ocho bytes puesto en diez, once, once y doce casillas seguidas, y para eso no hace falta comprimirlos, basta con una tabla que diga cuantos y donde.
; ----------------------------------------------------------------------
monta_la_pantalla_del_titulo:		; la fuente, el rotulo y sus bloques repetidos
	ld b,0e0h		;480a   ; el registro 7: el color del fondo
	call pon_el_color_de_fondo		;480c
	call limpia_la_pantalla		;480f   ; la pantalla, limpia
	call monta_la_fuente		;4812   ; la fuente
	ld de,048adh		;4815   ; los patrones del rotulo
	ld hl,02580h		;4818   ; en 0x2580, o sea a partir del tile 0xB0
	call descomprime_en_los_tres_tercios		;481b
	ld de,04a88h		;481e   ; y su color
	ld hl,00580h		;4821   ; en la tabla de color, en la misma posicion
	call descomprime_en_los_tres_tercios		;4824
	ld de,04aa5h		;4827   ; y la tabla de los bloques repetidos
bloques_repetidos_de_patron:		; el mismo patron en varias casillas seguidas
	ex de,hl			;482a   ; la tabla, a HL
	ld a,(hl)			;482b
	and a			;482c   ; el 0x00 cierra la tabla
	ret z			;482d
	ld b,a			;482e   ; cuantas casillas seguidas
	inc hl			;482f
	ld e,(hl)			;4830   ; el destino de VRAM
	inc hl			;4831
	ld d,(hl)			;4832
	inc hl			;4833
	ex de,hl			;4834   ; HL el destino, DE los ocho bytes del patron
L_4835:
	push bc			;4835
	push de			;4836
	push hl			;4837
	ld bc,00008h		;4838   ; un tile
	call ldirvm_en_los_tres_tercios		;483b   ; y en los tres tercios
	pop hl			;483e
	ld de,00008h		;483f   ; la casilla siguiente
	add hl,de			;4842
	pop de			;4843
	pop bc			;4844
	djnz L_4835		;4845   ; y otra vez el mismo patron
	ld hl,00008h		;4847   ; detras del patron viene la entrada siguiente
	add hl,de			;484a
	ex de,hl			;484b
	jr bloques_repetidos_de_patron		;484c   ; y a por ella
monta_el_titulo_entero:		; la pantalla, el rotulo en la tabla de nombres y el menu
	call monta_la_pantalla_del_titulo		;484e   ; los patrones y su color
	ld de,04878h		;4851   ; la lista de tramos del rotulo
	ld c,0b0h		;4854   ; el rotulo empieza en el tile 0xB0
	ld hl,0386ch		;4856   ; y en la casilla 0x6C de la pantalla

; ----------------------------------------------------------------------
; El rotulo HYPER SPORTS 3 son sesenta y seis tiles distintos que en la tabla de nombres van casi seguidos, asi que la tabla de 0x4878 no guarda los indices: guarda solo cuantos tiles seguidos y cuanto hay que saltar hasta el tramo siguiente. El indice sube solo desde 0xB0 y no se repite ninguno.
; ----------------------------------------------------------------------
escribe_los_tramos_del_rotulo:		; pares de cuantos tiles y cuanto saltar
	ld a,(de)			;4859   ; cuantos tiles seguidos
	and a			;485a
	jr z,L_486F		;485b   ; el 0x00 cierra la lista
	ld b,a			;485d
	inc de			;485e
	ld a,(de)			;485f   ; cuanto saltar desde donde se quedo
	call suma_a_hl		;4860
	inc de			;4863
	ld a,c			;4864   ; el indice del tile por el que iba
L_4865:
	call 0004dh		;4865   ; BIOS WRTVRM - Writes data in VRAM | y a la casilla
	inc hl			;4868
	inc a			;4869   ; el siguiente, que va pegado
	djnz L_4865		;486a
	ld c,a			;486c   ; el indice, apuntado para el tramo que viene
	jr escribe_los_tramos_del_rotulo		;486d
L_486F:
	ld de,04525h		;486f   ; el guion de (c)KONAMI 1985, PLAY SELECT y 1PLAYER
	call pinta_guion_de_tiles		;4872   ; al terminar en su 0xFF, DE ha quedado justo encima del guion siguiente
	jp pinta_guion_de_tiles		;4875   ; que es el de 2PLAYERS: dos guiones pegados, y el segundo sale gratis

; ----------------------------------------------------------------------
; DATOS lista_de_tiles_del_rotulo: 17 B: pares [cuantos tiles][cuanto saltar]
;   que escriben el rotulo HYPER SPORTS 3 en la tabla de nombres desde 0x386C,
;   con el indice de tile subiendo solo desde 0xB0; el 0x00 cierra
;   0x4878..0x4889  (17 bytes)
DATA_lista_de_tiles_del_rotulo:
	defb 002h,000h	; 4878
	defb 00ch,01dh	; 487a
	defb 00ch,013h	; 487c
	defb 00fh,013h	; 487e
	defb 010h,010h	; 4880
	defb 005h,010h	; 4882
	defb 002h,008h	; 4884
	defb 002h,012h	; 4886
	defb 000h	; 4888

; ======================================================================
; CODIGO 0x4889..0x48ad  (36 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL CURSOR DEL MENU. La manita son dos tiles que se pintan en la linea elegida y se borran en la otra, y el bit 3 de la cuenta atras de la escena hace el parpadeo: ocho fotogramas encendida y ocho apagada. El mismo guion sirve para las dos cosas porque el interprete lleva mascara: con 0xFF pinta y con 0x00 escribe el tile del espacio.
; ----------------------------------------------------------------------
parpadea_el_cursor_del_menu:		; la manita, encendida en una linea y borrada en la otra
	ld hl,0e004h		;4889   ; la cuenta atras de la escena
	bit 3,(hl)		;488c   ; su bit 3 cambia cada ocho fotogramas
	ld c,0ffh		;488e   ; la mascara que pinta
	jr nz,L_4893		;4890
	inc c			;4892   ; o la que borra
L_4893:
	ld hl,03a4ah		;4893   ; la linea de 1PLAYER
	ld de,03a8ah		;4896   ; y la de 2PLAYERS
	ld a,(0e052h)		;4899   ; la linea elegida
	or a			;489c
	jr z,L_48A0		;489d
	ex de,hl			;489f   ; con la de abajo elegida, se cambian
L_48A0:
	push de			;48a0   ; la otra linea, apuntada para despues
	call L_48A7		;48a1   ; en la elegida, la manita parpadeando
	pop hl			;48a4
	ld c,000h		;48a5   ; y en la otra, borrada siempre
L_48A7:
	ld de,04557h		;48a7   ; los dos tiles de la manita, que van sin cabecera
	jp L_441D		;48aa   ; el interprete, entrando con el destino ya en HL

; ----------------------------------------------------------------------
; DATOS rle_patrones_del_rotulo: 475 B -> 528 de VRAM en 0x2580: los 66
;   patrones del rotulo, del tile 0xB0 al 0xF1
;   0x48ad..0x4a88  (475 bytes)
DATA_rle_patrones_del_rotulo:
	defb 005h,000h,09dh,001h,003h,007h,000h,010h,020h,060h,0c0h,0c0h,080h,080h,001h,003h	; 48ad  ........ `......
	defb 007h,00fh,01fh,03fh,07fh,0ffh,00fh,01fh,03eh,07eh,0fch,0fch,0ffh,0ffh,01fh,01fh	; 48bd  ...?....>~......
	defb 003h,03fh,09bh,07eh,0feh,0feh,0bfh,0bfh,01fh,01fh,00fh,00fh,007h,007h,00fh,01fh	; 48cd  .?.~............
	defb 0bfh,0feh,0fch,0f8h,0f0h,0e0h,0dfh,09fh,03fh,03eh,03eh,07ch,07ch,07fh,003h,0ffh	; 48dd  ........?>>||...
	defb 002h,00fh,002h,01fh,089h,0feh,01fh,01fh,03fh,03fh,03eh,07eh,07fh,07fh,003h,0ffh	; 48ed  ........??>~....
	defb 003h,000h,0a1h,0feh,0fch,0bfh,03fh,07fh,07ch,07ch,0f8h,0f8h,0fbh,0ffh,0feh,0ffh	; 48fd  ......?.||......
	defb 01fh,01eh,03eh,03fh,0fch,0ffh,000h,000h,0f8h,000h,000h,0e0h,000h,001h,003h,007h	; 490d  ..>?............
	defb 00fh,01fh,03fh,07fh,007h,0ffh,002h,0fdh,08ch,0ffh,0f0h,0e0h,0e1h,0c1h,0c3h,083h	; 491d  ..?.............
	defb 087h,0fch,0fch,0f8h,0f8h,004h,0f0h,081h,007h,003h,00fh,003h,01fh,083h,03fh,0c0h	; 492d  ..............?.
	defb 0c0h,003h,081h,002h,003h,084h,007h,0ffh,0ffh,0f0h,003h,0e0h,002h,0c0h,082h,0feh	; 493d  ................
	defb 0fch,003h,001h,002h,003h,086h,007h,0ffh,0feh,0feh,0f8h,0f8h,003h,0ffh,082h,0fdh	; 494d  ................
	defb 001h,003h,003h,09ah,0f7h,0e7h,0efh,0f3h,0f7h,0f7h,0e3h,0e1h,0e0h,0c0h,0c0h,0fch	; 495d  ................
	defb 0f8h,0e0h,0f0h,0f8h,0fch,07eh,03fh,001h,003h,007h,00fh,01fh,03fh,07fh,009h,0ffh	; 496d  .....~?.....?...
	defb 002h,0f8h,088h,0f3h,0f7h,0e7h,0c7h,0cfh,08fh,000h,000h,003h,0ffh,082h,08fh,080h	; 497d  ................
	defb 003h,000h,090h,01fh,09fh,0bfh,03ch,03ch,078h,000h,000h,0f0h,0f9h,0fdh,03dh,03bh	; 498d  ......<<x.....=;
	defb 07bh,000h,000h,003h,0ffh,003h,0c7h,002h,000h,0a0h,08fh,0cfh,0dfh,09eh,09eh,0bch	; 499d  {...............
	defb 000h,000h,0f8h,0fch,0feh,01eh,01ch,03ch,000h,000h,07fh,07fh,0ffh,00fh,00fh,01fh	; 49ad  .......<........
	defb 000h,000h,0fdh,0fbh,0fbh,083h,007h,007h,000h,000h,003h,0ffh,083h,0c7h,0c0h,080h	; 49bd  ................
	defb 003h,000h,002h,080h,003h,000h,089h,03fh,07fh,07fh,0f0h,0f0h,000h,001h,00fh,0f0h	; 49cd  .......?........
	defb 004h,0f8h,003h,0f0h,087h,001h,003h,007h,00fh,01fh,03fh,07fh,00ch,0ffh,002h,0feh	; 49dd  ..........?.....
	defb 096h,0fch,0f8h,0f8h,09fh,00fh,000h,000h,03ch,03fh,07fh,03fh,0fch,0feh,03eh,03ch	; 49ed  ........<?.?..><
	defb 07ch,0f9h,0f9h,0f3h,07fh,07fh,0ffh,003h,0f0h,002h,0e0h,083h,0f3h,0f7h,0e7h,003h	; 49fd  |...............
	defb 00fh,002h,01fh,003h,08fh,002h,01eh,088h,0feh,0fch,0fch,03dh,03dh,07bh,07bh,079h	; 4a0d  ...........=={{y
	defb 003h,0f0h,002h,0f8h,09eh,0f0h,0c0h,0e0h,0f0h,078h,03ch,01eh,01eh,03eh,03ch,03ch	; 4a1d  .........x<..><<
	defb 07ch,078h,0f8h,00fh,007h,000h,000h,01eh,01fh,03fh,01fh,0feh,0ffh,01fh,03eh,03eh	; 4a2d  |x.......?....>>
	defb 0fch,0fch,0f8h,003h,000h,08ah,003h,007h,007h,00fh,00fh,01fh,01fh,003h,083h,087h	; 4a3d  ................
	defb 003h,0ffh,082h,0e0h,080h,004h,0c0h,002h,080h,088h,0ffh,07fh,03fh,01fh,00fh,007h	; 4a4d  ............?...
	defb 003h,001h,008h,0ffh,002h,0f8h,006h,0ffh,002h,000h,003h,0ffh,082h,0f8h,0c0h,003h	; 4a5d  ................
	defb 000h,082h,0feh,0e0h,004h,000h,081h,007h,007h,000h,081h,0ffh,007h,000h,084h,0ffh	; 4a6d  ................
	defb 07fh,03eh,018h,004h,000h,082h,0f8h,0c0h,006h,000h,000h	; 4a7d  .>.........

; ----------------------------------------------------------------------
; DATOS rle_color_del_rotulo: 29 B -> las mismas 528 posiciones en 0x0580, o
;   sea el color de esos 66 tiles
;   0x4a88..0x4aa5  (29 bytes)
DATA_rle_color_del_rotulo:
	defb 068h,0f0h,008h,0a0h,07fh,0f0h,049h,0f0h,010h,080h,068h,0f0h,087h,005h,000h,000h	; 4a88  h.....I...h.....
	defb 085h,080h,080h,085h,011h,080h,028h,0f0h,010h,080h,010h,0f0h,000h	; 4a98  ......(......

; ----------------------------------------------------------------------
; DATOS bloques_repetidos_del_rotulo: 45 B: cuatro entradas [cuantas
;   veces][destino de VRAM][8 bytes de patron] y el 0x00 que cierra; el bucle
;   de 0x4835 repite cada bloque de ocho bytes en casillas consecutivas de los
;   tres tercios
;   0x4aa5..0x4ad2  (45 bytes)
DATA_bloques_repetidos_del_rotulo:
	defb 00ah,098h,005h,0fah,0f0h,0f0h,0fah,0f0h,0f0h,0fah,0f0h	; 4aa5  ...........
	defb 00bh,0f8h,005h,0f0h,0fah,0f0h,0f0h,0fah,0f0h,0f0h,0fah	; 4ab0  ...........
	defb 00bh,060h,006h,0f0h,0f0h,0f5h,0f0h,0f0h,0f5h,0f0h,0f0h	; 4abb  .`.........
	defb 00ch,0d0h,006h,0f5h,0f0h,0f0h,0f5h,0f0h,0f0h,0f5h,0f0h	; 4ac6  ...........
	defb 000h	; 4ad1

; ======================================================================
; CODIGO 0x4ad2..0x4c26  (340 bytes)
; ======================================================================


suena_si_hay_partida:		; arranca la pista solo con el bit 6 de (0xE002)
	di			;4ad2
	push hl			;4ad3
	ld hl,0e002h		;4ad4   ; el bit 6 dice si hay partida en curso
	bit 6,(hl)		;4ad7
	jr z,L_4AE8		;4ad9   ; y sin partida, esta no suena
	jr L_4ADF		;4adb

; ----------------------------------------------------------------------
; La puerta de entrada del sonido: se llama con el numero de pista en A, y lo unico que hace es cerrar las interrupciones y guardar los registros, porque quien la llama esta a mitad de otra cosa. La de arriba es la misma con una condicion delante.
; ----------------------------------------------------------------------
arranca_una_pista:		; guarda los registros y llama al de verdad
	di			;4add   ; el reproductor toca el PSG: no puede interrumpirse a la mitad
	push hl			;4ade
L_4ADF:
	push de			;4adf   ; los registros, guardados: quien llama esta a mitad de otra cosa
	push bc			;4ae0
	push af			;4ae1
	call reparte_la_pista_por_canales		;4ae2   ; el reparto de verdad
	pop af			;4ae5
	pop bc			;4ae6
	pop de			;4ae7
L_4AE8:
	pop hl			;4ae8
	ei			;4ae9   ; y las interrupciones, abiertas otra vez
	ret			;4aea

; ----------------------------------------------------------------------
; REPARTE UNA PISTA. Cada pista sabe cuantos canales del PSG necesita, y lo sabe por su NUMERO: de la 0x04 a la 0x0B ocupa uno, de la 0x0C a la 0x1F dos, y de la 0x20 en adelante los tres. La 0x01 es el efecto de barrido y las de por debajo de la 0x04 empiezan en el canal 2. Antes de sonar hay una prueba de prioridad: la pista nueva solo entra si su numero es MAYOR que el de la que ya esta sonando en ese canal, con dos excepciones -la 0x09 y la 0x2F- que se conforman con empatar.
; ----------------------------------------------------------------------
reparte_la_pista_por_canales:		; cuantos canales ocupa y si tiene prioridad
	ld c,a			;4aeb   ; el numero de pista, apuntado con sus bits de arriba
	and 03fh		;4aec   ; y sin ellos, el numero pelado
	ld b,002h		;4aee   ; dos canales, que es lo mas comun
	ld hl,0e012h		;4af0   ; el byte de estado del canal 1
	cp 001h		;4af3   ; la pista 1 es el barrido
	jr nz,L_4B03		;4af5
	xor a			;4af7
	ld (0e040h),a		;4af8   ; y sus dos banderas, a cero
	ld (0e044h),a		;4afb
	ld a,c			;4afe
	and 03fh		;4aff
	jr L_4B31		;4b01
L_4B03:
	cp 00ch		;4b03   ; por debajo de la 0x0C
	jr c,L_4B13		;4b05
	jr nz,L_4B0C		;4b07   ; la 0x0C justa empieza en el canal 2
	ld hl,0e020h		;4b09
L_4B0C:
	cp 020h		;4b0c   ; de la 0x20 para arriba
	jr c,L_4B1B		;4b0e
	inc b			;4b10   ; hacen falta los tres canales
	jr L_4B1B		;4b11
L_4B13:
	dec b			;4b13   ; con un canal basta
	cp 004h		;4b14   ; y las de por debajo de la 4
	jr nc,L_4B1B		;4b16
	ld hl,0e020h		;4b18   ; empiezan en el canal 2
L_4B1B:
	ld a,(hl)			;4b1b   ; la pista que esta sonando ahi ahora
	and 03fh		;4b1c
	ld e,a			;4b1e
	ld a,c			;4b1f
	and 03fh		;4b20
	cp 009h		;4b22   ; la 0x09
	jr z,L_4B2F		;4b24
	cp 02fh		;4b26   ; y la 0x2F
	jr z,L_4B2F		;4b28
	cp e			;4b2a   ; las demas tienen que ser mayores
	ret c			;4b2b
	ret z			;4b2c   ; y ni siquiera vale empatar
	jr L_4B31		;4b2d
L_4B2F:
	cp e			;4b2f   ; estas dos si valen empatadas
	ret c			;4b30
L_4B31:
	add a,a			;4b31   ; dos bytes por entrada
	ld de,04dach		;4b32   ; la tabla de las 56 pistas
	call suma_a_de		;4b35
	dec hl			;4b38   ; atras dos, hasta el primer byte del canal
	dec hl			;4b39
monta_el_canal:		; deja el canal listo para sonar la pista
	ld (hl),001h		;4b3a   ; la cuenta atras de la nota: la primera entra ya
	inc hl			;4b3c
	ld (hl),001h		;4b3d   ; y su duracion
	inc hl			;4b3f
	ld (hl),c			;4b40   ; la pista, con sus bits de modo
	inc hl			;4b41
	ld a,(de)			;4b42   ; el puntero de lectura, de la tabla
	ld (hl),a			;4b43
	inc hl			;4b44
	inc de			;4b45
	ld a,(de)			;4b46
	ld (hl),a			;4b47
	ld a,005h		;4b48
	call suma_a_hl		;4b4a
	xor a			;4b4d   ; el bucle, sin vueltas dadas
	ld (hl),a			;4b4e
	inc hl			;4b4f
	inc hl			;4b50
	ld (hl),a			;4b51   ; y sin desafine
	ld a,003h		;4b52
	call suma_a_hl		;4b54   ; catorce bytes: el canal siguiente
	inc de			;4b57   ; con el puntero siguiente de la tabla
	djnz monta_el_canal		;4b58   ; y una pista puede ocupar hasta tres
	ret			;4b5a

; ----------------------------------------------------------------------
; El 0xFE de una pista es el bucle: detras van la cuenta de vueltas y la direccion a la que volver. (IX+9) lleva las que se han dado, y cuando llega a la cuenta se pone a cero y la pista sigue por detras del mandato. Una cuenta negativa no se agota nunca: ese es el bucle infinito de la musica de fondo.
; ----------------------------------------------------------------------
repite_o_termina_el_bucle:		; el mandato 0xFE de una pista
	inc hl			;4b5b
	ld a,(ix+009h)		;4b5c   ; las vueltas dadas
	inc a			;4b5f   ; una mas
	cp (hl)			;4b60   ; contra las que pide el mandato
	jr z,L_4B76		;4b61   ; y si son las que pide, se acabo el bucle
	jp m,L_4B67		;4b63   ; con una cuenta negativa esto no se cumple jamas: bucle sin fin
	dec a			;4b66
L_4B67:
	ld (ix+009h),a		;4b67   ; las vueltas que van
	inc hl			;4b6a   ; y a repetir desde donde diga
	ld a,(hl)			;4b6b
	ld (ix+003h),a		;4b6c
	inc hl			;4b6f
	ld a,(hl)			;4b70
	ld (ix+004h),a		;4b71
	jr L_4B7F		;4b74
L_4B76:
	inc hl			;4b76
	inc hl			;4b77
	xor a			;4b78   ; el bucle, a cero para la proxima
	ld (ix+009h),a		;4b79
	call apunta_el_mandato_siguiente		;4b7c   ; y la pista sigue por detras del mandato
L_4B7F:
	inc (ix+000h)		;4b7f   ; una unidad de duracion, que la nota que viene ya viene tarde
	jp sigue_la_nota		;4b82

; ----------------------------------------------------------------------
; El mezclador del PSG (registro 7), donde un bit a 1 APAGA. Los bits 3, 4 y 5 son el ruido de cada canal, y la copia de (0xE03A) evita tener que leerlo. Lo curioso es el remate: el tono del canal A se queda SIEMPRE igual que su ruido, encendido con el y apagado con el, asi que ese canal no suena solo.
; ----------------------------------------------------------------------
enciende_el_ruido_del_canal:		; el registro 7 del PSG
	ld a,(0e03ah)		;4b85   ; la copia del mezclador
	ld e,a			;4b88
	ld a,c			;4b89   ; C vale 1, 3 o 5 segun el canal
	cp 001h		;4b8a
	jr z,L_4B8F		;4b8c
	dec a			;4b8e
L_4B8F:
	rlca			;4b8f   ; tres rotaciones: los bits 3, 4 y 5 son el ruido de cada canal
	rlca			;4b90
	rlca			;4b91
	dec d			;4b92   ; con D=1 se apaga
	jr z,L_4B99		;4b93
	cpl			;4b95   ; y con D=0 se enciende: en el PSG un bit a 0 es lo que deja pasar
	and e			;4b96
	jr L_4B9A		;4b97
L_4B99:
	or e			;4b99
L_4B9A:
	set 0,a		;4b9a   ; el tono del canal A, apagado
	bit 3,a		;4b9c   ; salvo que su ruido este encendido
	jr z,L_4BA2		;4b9e
	res 0,a		;4ba0
L_4BA2:
	ld (0e03ah),a		;4ba2   ; la copia, para la proxima vez
	ld e,a			;4ba5
	ld a,007h		;4ba6
	jp 00093h		;4ba8   ; BIOS WRTPSG - Writes data to PSG-register | y al PSG

; ----------------------------------------------------------------------
; EL REPRODUCTOR. Se llama una vez por fotograma desde la interrupcion y recorre los tres canales, catorce bytes cada uno, desde 0xE010. De cada canal salen tres caminos: si esta sonando la pista 1 es el barrido, si el byte de estado es 0 esta callado y hay que callarlo del todo, y si no, a por la nota que toque.
; ----------------------------------------------------------------------
reproduce_un_fotograma:		; los tres canales, una vez por interrupcion
	ld a,(0e03ah)		;4bab   ; el mezclador, tal y como quedo
	call L_4BA2		;4bae
	ld c,001h		;4bb1   ; el canal A: los registros 0 y 1 del PSG
	ld ix,0e010h		;4bb3   ; el primero de los tres canales
	exx			;4bb7
	ld b,003h		;4bb8   ; tres canales
	ld de,0000eh		;4bba   ; catorce bytes cada uno
L_4BBD:
	exx			;4bbd
	ld a,(ix+002h)		;4bbe   ; la pista que suena en este canal
	cp 001h		;4bc1   ; la 1 es el barrido
	call z,barrido_de_frecuencia		;4bc3
	ld a,(ix+002h)		;4bc6
	or a			;4bc9   ; y el 0 es que no suena nada
	jr nz,L_4BD1		;4bca
	call calla_el_canal		;4bcc   ; callarlo
	jr L_4BD4		;4bcf
L_4BD1:
	call nota_del_canal		;4bd1   ; y si no, la nota
L_4BD4:
	inc c			;4bd4   ; el canal siguiente del PSG
	inc c			;4bd5
	exx			;4bd6
	add ix,de		;4bd7   ; y sus catorce bytes
	djnz L_4BBD		;4bd9
	ret			;4bdb

; ----------------------------------------------------------------------
; EL BARRIDO. La pista 1 no lee notas de ninguna parte: arranca con los cuatro parametros de 0x4C26 y de ahi en adelante le suma 9 al periodo en cada fotograma, o sea que el tono baja solo, hasta pasarse de 0x90 y callarse. Los cuatro bytes se copian con un `lddr`, hacia atras, porque van pegados al reves.
; ----------------------------------------------------------------------
barrido_de_frecuencia:		; el efecto de la pista 1
	ld hl,0e043h		;4bdc   ; los cuatro bytes del efecto, en el canal 3
	ld de,04c29h		;4bdf   ; y sus parametros
	ld a,c			;4be2
	cp 003h		;4be3
	jr z,L_4BF2		;4be5
	ld hl,0e047h		;4be7   ; o en los otros dos
	ld de,04c2dh		;4bea
	ld a,(0e044h)		;4bed
	jr L_4BF5		;4bf0
L_4BF2:
	ld a,(0e040h)		;4bf2
L_4BF5:
	or a			;4bf5   ; con el estado a cero, el efecto arranca
	jr z,L_4C18		;4bf6
	dec hl			;4bf8
	ld a,090h		;4bf9   ; el tope
	cp (hl)			;4bfb
	jr c,L_4C07		;4bfc   ; pasado el tope, se sigue bajando
	inc hl			;4bfe
	cp (hl)			;4bff
	dec hl			;4c00
	jr c,L_4C07		;4c01
	xor a			;4c03   ; y si no, a callar
	ld (hl),a			;4c04
	jr L_4C10		;4c05
L_4C07:
	inc hl			;4c07
	ld a,(hl)			;4c08   ; el periodo
	sub 009h		;4c09   ; nueve mas cada fotograma: el tono baja
	ld (hl),a			;4c0b
	dec hl			;4c0c
	jr nc,L_4C10		;4c0d
	dec (hl)			;4c0f   ; y el acarreo al byte de arriba
L_4C10:
	dec hl			;4c10
	ld (ix+003h),l		;4c11   ; el puntero del canal se queda apuntando a los parametros
	ld (ix+004h),h		;4c14
	ret			;4c17
L_4C18:
	push bc			;4c18   ; los cuatro bytes de arranque
	ex de,hl			;4c19
	ld bc,00004h		;4c1a
	lddr		;4c1d   ; hacia atras, que es como estan puestos
	ex de,hl			;4c1f
	pop bc			;4c20
	inc hl			;4c21
	inc hl			;4c22
	inc hl			;4c23
	jr L_4C10		;4c24

; ----------------------------------------------------------------------
; DATOS parametros_de_sonido: 8 B: dos grupos de cuatro que cargan 0x4BDF (`ld
;   de,04c29h`) y 0x4BEA (`ld de,04c2dh`)
;   0x4c26..0x4c2e  (8 bytes)
DATA_parametros_de_sonido:
	defb 001h,021h,093h,080h	; 4c26
	defb 001h,021h,093h,038h	; 4c2a

; ======================================================================
; CODIGO 0x4c2e..0x4da2  (372 bytes)
; ======================================================================


nota_del_canal:		; la nota que toque en este fotograma
	bit 6,a		;4c2e   ; el bit 6 del estado
	ld d,001h		;4c30   ; apagar
	call z,enciende_el_ruido_del_canal		;4c32   ; sin el, el ruido de este canal se apaga
sigue_la_nota:		; la cuenta atras, y si se agota la nota siguiente
	ld a,(ix+002h)		;4c35
	or a			;4c38   ; con el bit 7 puesto, la pista es de las largas
	jp m,decae_el_volumen		;4c39
	dec (ix+000h)		;4c3c   ; un fotograma menos de nota
	ret nz			;4c3f   ; y hasta que no se agota, no hay nota nueva
lee_el_mandato_siguiente:		; por donde iba la pista
	ld l,(ix+003h)		;4c40   ; el puntero de lectura
	ld h,(ix+004h)		;4c43
L_4C46:
	ld a,(hl)			;4c46   ; el mandato
	cp 0feh		;4c47   ; 0xFE es el bucle
	jp z,repite_o_termina_el_bucle		;4c49
	jp nc,calla_el_canal		;4c4c   ; y 0xFF el final: a callar
	bit 7,(ix+002h)		;4c4f   ; las pistas largas se leen aparte
	jp nz,mandato_de_pista_larga		;4c53
	and 0f0h		;4c56   ; 0x2n
	cp 020h		;4c58
	ld a,(hl)			;4c5a
	jr nz,L_4C64		;4c5b
	and 00fh		;4c5d   ; es la duracion de las notas que vengan
	ld (ix+001h),a		;4c5f
	inc hl			;4c62
	ld a,(hl)			;4c63
L_4C64:
	cp 0e8h		;4c64   ; 0xE8
	jr nz,L_4C70		;4c66
	inc hl			;4c68
	ld a,(hl)			;4c69
	ld (ix+00bh),a		;4c6a   ; trae el desafine, y detras sigue la pista
	inc hl			;4c6d
	jr L_4C46		;4c6e
L_4C70:
	ld b,a			;4c70
	and 0f0h		;4c71   ; 0x1n
	cp 010h		;4c73
	jr nz,L_4C98		;4c75
	ld a,(hl)			;4c77
	and 01fh		;4c78   ; es el periodo del ruido, cinco bits
	ld e,a			;4c7a
	ld a,c			;4c7b
	cp 001h		;4c7c   ; en el canal A el mandato trae un byte mas
	jr nz,L_4C8D		;4c7e
	inc hl			;4c80
	bit 4,(hl)		;4c81   ; cuyo bit 4 decide si el ruido va grave o agudo
	ld b,(hl)			;4c83
	jr nz,L_4C8A		;4c84
	ld a,e			;4c86
	sub 010h		;4c87
	ld e,a			;4c89
L_4C8A:
	res 4,b		;4c8a
	dec hl			;4c8c
L_4C8D:
	ld a,006h		;4c8d   ; el registro 6 del PSG es el ruido
	call 00093h		;4c8f   ; BIOS WRTPSG - Writes data to PSG-register
	ld d,000h		;4c92   ; y encender el ruido de este canal
	call enciende_el_ruido_del_canal		;4c94
	inc hl			;4c97
L_4C98:
	bit 6,(ix+002h)		;4c98   ; el bit 6 del estado
	jr z,L_4CAA		;4c9c
	ld a,c			;4c9e
	cp 001h		;4c9f
	ld a,(hl)			;4ca1
	jr nz,L_4CAA		;4ca2
	call apunta_el_mandato_siguiente		;4ca4
	ld a,b			;4ca7
	jr arranca_la_nota		;4ca8
L_4CAA:
	and 0f0h		;4caa   ; el nibble de arriba es el volumen
	ld b,a			;4cac
	xor (hl)			;4cad   ; y el de abajo, con el byte siguiente, la nota
	ld d,a			;4cae
	inc hl			;4caf
	ld e,(hl)			;4cb0
	call apunta_el_mandato_siguiente		;4cb1   ; la pista sigue detras
	ex de,hl			;4cb4
	ld a,(ix+00bh)		;4cb5   ; el desafine
	or a			;4cb8
	jr z,L_4CBE		;4cb9
	call suma_a_hl		;4cbb
L_4CBE:
	call saca_el_periodo		;4cbe   ; el periodo, al PSG
	ld a,b			;4cc1
	rrca			;4cc2   ; el volumen baja al nibble de abajo
	rrca			;4cc3
	rrca			;4cc4
	rrca			;4cc5
arranca_la_nota:		; el volumen, la duracion y la cuenta del decaimiento
	ld h,a			;4cc6
	ld e,(ix+001h)		;4cc7   ; la duracion que se dijo
	ld (ix+000h),e		;4cca
	ld a,(ix+00ch)		;4ccd   ; el sumando del decaimiento
	add a,e			;4cd0
	ld (ix+008h),a		;4cd1   ; y de ahi sale la cuenta que lo lleva
	jr saca_el_volumen		;4cd4
calla_el_canal:		; ruido apagado, estado a cero y volumen a cero
	ld d,001h		;4cd6   ; el ruido de este canal, apagado
	call enciende_el_ruido_del_canal		;4cd8
	xor a			;4cdb
	ld (ix+00bh),a		;4cdc   ; sin desafine
	ld (ix+002h),a		;4cdf   ; y sin pista
	ld h,a			;4ce2   ; volumen cero
	jr saca_el_volumen		;4ce3

; ----------------------------------------------------------------------
; El decaimiento: mientras la nota dura, su volumen baja de uno en uno cada vez que la cuenta de (IX+8) alcanza a la de (IX+0). Los dos bytes que gobiernan la caida -cuanto se suma y a partir de que punto- vienen en el propio mandato de la pista, asi que una nota puede apagarse deprisa o quedarse sostenida.
; ----------------------------------------------------------------------
decae_el_volumen:		; la nota que se apaga sola mientras dura
	dec (ix+000h)		;4ce5   ; un fotograma menos
	jp z,lee_el_mandato_siguiente		;4ce8   ; y al agotarse, a por el mandato siguiente
	dec (ix+008h)		;4ceb   ; la cuenta del decaimiento
	ld a,(ix+008h)		;4cee
	cp (ix+000h)		;4cf1   ; cuando alcanza a la de la nota
	jr nz,L_4CFF		;4cf4
	ld e,a			;4cf6
	ld a,(ix+00dh)		;4cf7   ; el umbral
	cp e			;4cfa
	ld a,e			;4cfb
	jr nc,L_4D02		;4cfc
	ret			;4cfe   ; por debajo del umbral ya no baja mas
L_4CFF:
	dec (ix+008h)		;4cff
L_4D02:
	ld a,(ix+007h)		;4d02   ; el volumen de ahora
	dec a			;4d05   ; uno menos
	ret m			;4d06   ; y de cero no pasa
	ld (ix+007h),a		;4d07
	ld h,a			;4d0a
saca_el_volumen:		; los registros 8, 9 y 10 del PSG
	ld a,c			;4d0b   ; C vale 1, 3 o 5
	rrca			;4d0c   ; y esta cuenta lo convierte en el 8, el 9 o el 10, que son los volumenes
	add a,088h		;4d0d
	ld e,h			;4d0f
	jp 00093h		;4d10   ; BIOS WRTPSG - Writes data to PSG-register

; ----------------------------------------------------------------------
; Los mandatos de las pistas largas, que se pueden encadenar todos antes de una nota: 0xDn fija la unidad de duracion, 0xFn el volumen de arranque y los dos bytes del decaimiento, 0xEn con el bit 3 puesto el desafine y sin el la octava. Detras viene siempre el byte de la nota: el nibble de arriba es el semitono y el de abajo cuantas unidades dura.
; ----------------------------------------------------------------------
mandato_de_pista_larga:		; los mandatos de las pistas con el bit 7 puesto
	ld a,(hl)			;4d13
	and 0f0h		;4d14
	cp 0d0h		;4d16   ; 0xDn
	ld a,(hl)			;4d18
	jr nz,L_4D22		;4d19
	and 00fh		;4d1b
	ld (ix+00ah),a		;4d1d   ; la unidad de duracion
	inc hl			;4d20
	ld a,(hl)			;4d21
L_4D22:
	cp 0f0h		;4d22   ; 0xFn
	jr c,L_4D37		;4d24
	and 00fh		;4d26
	ld (ix+006h),a		;4d28   ; el volumen de arranque
	inc hl			;4d2b
	ld a,(hl)			;4d2c
	ld (ix+00ch),a		;4d2d   ; cuanto se suma al decaimiento
	inc hl			;4d30
	ld a,(hl)			;4d31
	ld (ix+00dh),a		;4d32   ; y a partir de donde deja de bajar
	inc hl			;4d35
	ld a,(hl)			;4d36
L_4D37:
	cp 0e0h		;4d37   ; 0xEn
	jr c,L_4D4C		;4d39
	and 00fh		;4d3b
	bit 3,a		;4d3d   ; su bit 3
	jr z,L_4D47		;4d3f
	ld (ix+00bh),a		;4d41   ; con el, el desafine, y se sigue leyendo mandatos
	inc hl			;4d44
	jr mandato_de_pista_larga		;4d45
L_4D47:
	ld (ix+005h),a		;4d47   ; y sin el, la octava
	inc hl			;4d4a
	ld a,(hl)			;4d4b
L_4D4C:
	and 00fh		;4d4c   ; el nibble de abajo de la nota: cuantas unidades dura
	ld b,a			;4d4e
	ld a,(ix+00ah)		;4d4f   ; la unidad
	jr z,L_4D59		;4d52
L_4D54:
	add a,(ix+00ah)		;4d54   ; sumada tantas veces como diga
	djnz L_4D54		;4d57
L_4D59:
	ld (ix+001h),a		;4d59   ; esa es la duracion de la nota
	ld a,(hl)			;4d5c   ; el byte de la nota
	call apunta_el_mandato_siguiente		;4d5d   ; la pista sigue detras
	and 0f0h		;4d60   ; el nibble de arriba: el semitono
	rrca			;4d62
	rrca			;4d63
	rrca			;4d64
	rrca			;4d65
	ld b,a			;4d66
	sub 00ch		;4d67   ; el 0x0C es el silencio
	jr z,L_4D6E		;4d69
	ld a,(ix+006h)		;4d6b   ; y los demas suenan al volumen de arranque
L_4D6E:
	ld (ix+007h),a		;4d6e
	call arranca_la_nota		;4d71   ; la nota, ya sonando
	ld a,b			;4d74
	ld hl,04da2h		;4d75   ; la tabla de periodos
	call suma_a_hl		;4d78
	ld l,(hl)			;4d7b   ; el periodo del semitono, ocho bits
	ld h,000h		;4d7c
	ld a,(ix+005h)		;4d7e   ; la octava
	or a			;4d81
	jr z,saca_el_periodo		;4d82
	ld b,a			;4d84
L_4D85:
	add hl,hl			;4d85   ; y cada octava mas grave es el periodo por dos
	djnz L_4D85		;4d86
saca_el_periodo:		; los dos registros de tono del canal
	ld a,(ix+00bh)		;4d88   ; el desafine
	or a			;4d8b
	jr z,L_4D8F		;4d8c
	inc hl			;4d8e   ; que es un punto de periodo: lo justo para que dos canales batan
L_4D8F:
	ld a,c			;4d8f
	ld e,h			;4d90   ; el byte de arriba, al registro impar
	call 00093h		;4d91   ; BIOS WRTPSG - Writes data to PSG-register
	ld a,c			;4d94
	dec a			;4d95
	ld e,l			;4d96   ; y el de abajo al par
	jp 00093h		;4d97   ; BIOS WRTPSG - Writes data to PSG-register
apunta_el_mandato_siguiente:		; deja el puntero de la pista donde se quedo
	inc hl			;4d9a   ; el byte de detras del mandato
	ld (ix+003h),l		;4d9b
	ld (ix+004h),h		;4d9e
	ret			;4da1

; ----------------------------------------------------------------------
; DATOS tabla_de_periodos: los diez primeros de los DOCE semitonos de la
;   octava, cada uno 0,944 veces el anterior; los dos que faltan son los dos
;   primeros bytes del bloque de abajo
;   0x4da2..0x4dac  (10 bytes)
DATA_tabla_de_periodos:
	defb 06bh,065h,05fh,05ah,055h,050h,04ch,047h,043h,040h	; 4da2  ke_ZUPLGC@

; ----------------------------------------------------------------------
; DATOS tabla_de_pistas: 56 punteros de dos bytes que L_4B32 indexa con el
;   numero de sonido; su entrada [0] no es un puntero: sus dos bytes son los
;   semitonos 10 y 11 de la tabla de arriba, y por eso parece apuntar a 0x393C
;   0x4dac..0x4e1c  (112 bytes)
DATA_tabla_de_pistas:
	defw 0393ch,053b0h,04e21h,04e1ch,04e30h,04e44h,04e4eh,04e57h	; 4dac
	defw 04e5dh,04e6bh,04e7ah,04e8bh,04e8fh,04ed1h,04f57h,04f5eh	; 4dbc
	defw 04f72h,04f65h,04f7ch,04f72h,04f89h,04f7ch,05014h,05040h	; 4dcc
	defw 0507ah,0506ch,05083h,0508fh,05096h,050c5h,050d2h,050eeh	; 4ddc
	defw 05124h,0511ch,050f6h,05136h,05146h,05156h,05166h,05188h	; 4dec
	defw 051a0h,051bfh,051d7h,051efh,05204h,0521ch,05235h,05284h	; 4dfc
	defw 0529eh,05344h,05250h,05251h,0526ah,053b0h,053b0h,053b0h	; 4e0c

; ----------------------------------------------------------------------
; DATOS pistas_de_sonido: 1428 bytes de melodias y efectos; cada byte lleva la
;   nota en el nibble alto y la duracion en el bajo, y el nibble alto 0x0C es
;   el silencio
;   0x4e1c..0x53b0  (1428 bytes)
DATA_pistas_de_sonido:
	defb 021h,01fh,0b1h,0f0h,0ffh,021h,01ch,0b1h,000h,022h,000h,000h,021h,011h,0b1h,000h	; 4e1c  !....!..."..!...
	defb 022h,000h,000h,0ffh,022h,0f0h,078h,0e0h,078h,0d0h,078h,0c0h,078h,0b0h,078h,0a0h	; 4e2c  "...".x.x.x.x.x.
	defb 078h,090h,078h,080h,078h,070h,078h,0ffh,023h,0b0h,08fh,0b0h,0a0h,0feh,008h,044h	; 4e3c  x.x.xpx.#......D
	defb 04eh,0ffh,021h,080h,060h,0c0h,0c0h,023h,000h,000h,0ffh,024h,0b0h,040h,090h,030h	; 4e4c  N.!.`..#...$.@.0
	defb 0ffh,022h,01fh,01fh,012h,01eh,018h,01fh,01ch,01dh,018h,01bh,015h,01ah,0ffh,022h	; 4e5c  ."............."
	defb 01ch,008h,01ah,008h,018h,008h,017h,008h,028h,016h,008h,015h,008h,0ffh,023h,018h	; 4e6c  ........(.....#.
	defb 00ah,017h,00bh,028h,016h,00ch,015h,00ah,014h,009h,013h,008h,012h,007h,0ffh,023h	; 4e7c  ...(...........#
	defb 011h,00ch,0ffh,0d5h,0fch,002h,006h,0e1h,0c3h,011h,0e2h,0b5h,0e1h,021h,015h,0e2h	; 4e8c  .............!..
	defb 0b1h,0e1h,015h,0e2h,091h,041h,071h,071h,071h,071h,071h,061h,071h,0dah,048h,0d5h	; 4e9c  .....Aqqqqqaq.H.
	defb 0c3h,0e1h,011h,0e2h,0b5h,0e1h,021h,015h,0e2h,0b1h,0e1h,015h,0e2h,093h,0e1h,071h	; 4eac  ......!........q
	defb 071h,071h,071h,071h,061h,071h,095h,063h,041h,023h,0b5h,083h,061h,045h,0c3h,023h	; 4ebc  qqqqaq.cA#..aE.#
	defb 011h,0e2h,0b3h,091h,0ffh,0d5h,0fch,002h,006h,0e3h,091h,0e2h,041h,0e3h,041h,0e2h	; 4ecc  ............A.A.
	defb 041h,0feh,002h,0d5h,04eh,0e3h,091h,0e2h,021h,0e3h,041h,0e2h,021h,0e3h,091h,0e2h	; 4edc  A...N...!.A.!...
	defb 011h,0e3h,041h,0e2h,011h,091h,0b1h,0feh,004h,0f1h,04eh,091h,0e2h,011h,0e3h,041h	; 4eec  ..A.......N....A
	defb 0e2h,011h,0e3h,071h,0e2h,021h,0e3h,021h,0e2h,021h,0e3h,091h,0e2h,041h,0e3h,041h	; 4efc  ...q.!.!.!...A.A
	defb 0e2h,041h,0feh,002h,006h,04fh,0e3h,091h,0e2h,021h,0e3h,041h,0e2h,021h,0e3h,091h	; 4f0c  .A...O...!.A.!..
	defb 0e2h,011h,0e2h,041h,0e2h,011h,0e3h,071h,0e2h,021h,0e3h,021h,0e2h,021h,0feh,002h	; 4f1c  ...A...q.!.!.!..
	defb 022h,04fh,0e3h,021h,0e2h,021h,0e3h,061h,0e2h,021h,0e3h,091h,0e2h,021h,0e3h,021h	; 4f2c  "O.!.!.a.!...!.!
	defb 0e2h,021h,0e3h,041h,0e2h,041h,0e3h,081h,0e2h,041h,0e3h,0b1h,0e2h,041h,0e3h,041h	; 4f3c  .!.A.A...A...A.A
	defb 0e2h,041h,0e3h,003h,0e2h,023h,011h,0e3h,0b3h,091h,0ffh,0dah,0fdh,004h,002h,0e1h	; 4f4c  .A...#..........
	defb 075h,0ffh,0dah,0fdh,004h,002h,0e0h,005h,0ffh,021h,0b2h,020h,023h,000h,000h,021h	; 4f5c  u........!. #..!
	defb 0e8h,0c0h,0feh,002h,093h,04fh,024h,000h,000h,021h,0e8h,068h,0feh,002h,093h,04fh	; 4f6c  .....O$..!.h...O
	defb 021h,0b2h,020h,023h,000h,000h,021h,0e8h,040h,0feh,002h,093h,04fh,024h,000h,000h	; 4f7c  !. #..!.@...O$..
	defb 021h,0e8h,000h,0feh,002h,093h,04fh,0a1h,012h,0a1h,010h,0a1h,00eh,0a1h,00ch,0a1h	; 4f8c  !.....O.........
	defb 00ah,0a1h,008h,0a1h,002h,0a0h,0fah,0a0h,0f2h,0a0h,0eah,0a0h,0e2h,0a0h,0dah,0a0h	; 4f9c  ................
	defb 0d2h,0a0h,0cah,0a0h,0c2h,0a0h,0bah,0a0h,0b2h,0a0h,0aah,0a0h,0a2h,070h,0c2h,080h	; 4fac  .............p..
	defb 0bah,080h,0b2h,080h,0aah,080h,0a2h,080h,09ah,080h,092h,080h,08ah,080h,082h,080h	; 4fbc  ................
	defb 07ah,080h,072h,080h,06ah,080h,062h,080h,05ah,080h,05ah,060h,0c2h,060h,0bah,060h	; 4fcc  z.r.j.b.Z.Z`.`.`
	defb 0b2h,060h,0aah,060h,0a2h,060h,09ah,060h,092h,060h,08ah,060h,082h,060h,07ah,060h	; 4fdc  .`.`.`.`.`.`.`z`
	defb 072h,060h,06ah,060h,062h,060h,05ah,060h,052h,060h,0c2h,060h,0bah,060h,0b2h,060h	; 4fec  r`j`b`Z`R`.`.`.`
	defb 0aah,060h,0a2h,060h,09ah,060h,092h,060h,08ah,060h,082h,060h,07ah,060h,072h,060h	; 4ffc  .`.`.`.`.`.`z`r`
	defb 06ah,060h,062h,060h,05ah,060h,052h,0ffh,021h,060h,0a0h,0c0h,097h,0e0h,097h,0f0h	; 500c  j`b`Z`R.!`......
	defb 097h,0e0h,097h,0f0h,097h,0e0h,097h,0f0h,0a0h,0e0h,0a0h,0d0h,0b4h,0a0h,0beh,050h	; 501c  ...............P
	defb 0d6h,070h,0d6h,090h,0e3h,090h,0e3h,0a0h,0fdh,0a1h,00dh,091h,023h,091h,02eh,091h	; 502c  .p..........#...
	defb 040h,081h,063h,0ffh,021h,061h,040h,0c1h,02eh,0e1h,02eh,0f1h,02eh,0e1h,02eh,0f1h	; 503c  @.c.!a@.........
	defb 02eh,0e1h,02eh,0f1h,040h,0e1h,040h,0d1h,067h,0a1h,07dh,051h,0ach,071h,0ach,091h	; 504c  ....@.@.g.}Q.q..
	defb 0c5h,091h,0c5h,0a2h,03bh,0a2h,01bh,092h,04ch,092h,05dh,092h,081h,082h,0a7h,0ffh	; 505c  ....;...L.].....
	defb 021h,091h,0b0h,0a2h,0f0h,0a1h,0a0h,073h,0c0h,072h,070h,062h,0b0h,0ffh,021h,01ah	; 506c  !......s.rpb..!.
	defb 01bh,00ah,00bh,007h,006h,00ah,0ffh,022h,0b0h,05eh,0b0h,05ah,000h,000h,0b0h,04eh	; 507c  .......".^.Z...N
	defb 0b0h,04ah,0ffh,022h,0e8h,002h,0feh,0ffh,084h,050h,021h,0d3h,010h,0d2h,0f0h,0d3h	; 508c  .J.".....P!.....
	defb 000h,024h,000h,000h,021h,0d2h,0c0h,0c2h,0c0h,0b2h,0c0h,0a2h,0c0h,0b2h,0b0h,0a2h	; 509c  .$..!...........
	defb 0b0h,092h,0b0h,082h,0b0h,022h,092h,0a0h,082h,0a0h,072h,0a0h,062h,0a0h,072h,090h	; 50ac  ....."....r.b.r.
	defb 062h,090h,052h,090h,042h,090h,032h,090h,0ffh,022h,0d3h,050h,0d3h,030h,0d3h,040h	; 50bc  b.R.B.2..".P.0.@
	defb 0e8h,008h,0feh,002h,09dh,050h,022h,0d2h,0f0h,0c2h,0e0h,0b2h,0d0h,028h,000h,000h	; 50cc  .....P"......(..
	defb 023h,0a2h,0c0h,092h,0b0h,082h,0a0h,072h,090h,062h,080h,052h,070h,042h,060h,032h	; 50dc  #......r.b.RpB`2
	defb 050h,0ffh,022h,0e8h,00dh,0feh,0ffh,0d3h,050h,0ffh,021h,0f1h,030h,0f2h,020h,0f0h	; 50ec  P.".....P.!.0. .
	defb 0e0h,0e1h,0f0h,0e0h,0e0h,0d2h,020h,0d1h,030h,0c0h,0b0h,0b1h,060h,0b1h,0a0h,0a2h	; 50fc  ...... .0...`...
	defb 000h,0a0h,0e0h,091h,070h,091h,000h,081h,070h,061h,090h,051h,070h,051h,050h,0ffh	; 510c  ....p...pa.QpQP.
	defb 021h,01fh,0e8h,070h,0feh,0ffh,024h,051h,022h,01fh,01ch,00bh,00ah,009h,008h,01dh	; 511c  !..p..$Q".......
	defb 018h,01ch,017h,01bh,017h,01ah,016h,019h,016h,0ffh,0d6h,0fch,002h,005h,0e2h,0c5h	; 512c  ................
	defb 0b1h,071h,051h,032h,020h,001h,031h,0e3h,097h,0ffh,0d6h,0fch,002h,005h,0e1h,0c5h	; 513c  .qQ2 .1.........
	defb 021h,0e2h,0b1h,091h,072h,050h,031h,071h,067h,0ffh,0d6h,0fch,001h,005h,0e3h,0c3h	; 514c  !...rP1qg.......
	defb 071h,0c1h,021h,0c1h,051h,0c1h,001h,0c1h,027h,0ffh,0d6h,0fch,002h,008h,0e1h,009h	; 515c  q.!.Q...'.......
	defb 0e2h,090h,0a0h,0e1h,001h,021h,009h,0e2h,090h,0a0h,0e1h,001h,051h,032h,030h,025h	; 516c  .....!......Q20%
	defb 0e2h,0a0h,0e1h,000h,0d8h,030h,020h,0e2h,0a0h,0e1h,008h,0ffh,0d6h,0fch,002h,008h	; 517c  .....0 .........
	defb 0e2h,099h,050h,070h,091h,0a1h,099h,050h,070h,091h,091h,072h,070h,057h,0d8h,070h	; 518c  ..Pp...Pp..rpW.p
	defb 050h,020h,048h,0ffh,0d6h,0fch,001h,003h,0e3h,052h,000h,057h,0e4h,0a1h,0e3h,021h	; 519c  P H......R.W...!
	defb 052h,000h,057h,051h,051h,032h,030h,0e4h,0a2h,0e3h,050h,0a3h,0d8h,0a0h,0a0h,0a0h	; 51ac  R.WQQ20...P.....
	defb 0e2h,008h,0ffh,0d6h,0fch,002h,006h,0e2h,022h,020h,053h,052h,050h,0e1h,005h,000h	; 51bc  ........" SRP...
	defb 020h,0d8h,030h,020h,000h,022h,030h,020h,000h,0a7h,0ffh,0d6h,0fch,002h,006h,0e2h	; 51cc   .0 ."0 ........
	defb 052h,050h,0a3h,0e1h,002h,000h,055h,030h,050h,0d8h,070h,050h,030h,052h,070h,050h	; 51dc  RP....U0P.pP0RpP
	defb 030h,027h,0ffh,0d6h,0fch,002h,006h,0e3h,0a5h,051h,0a5h,051h,0a3h,0d8h,030h,030h	; 51ec  0'.......Q.Q..00
	defb 030h,0a2h,0e2h,030h,030h,030h,0a7h,0ffh,0d6h,0fbh,002h,004h,0e2h,0b5h,090h,0b0h	; 51fc  0..000..........
	defb 0e1h,003h,0e2h,093h,0b3h,093h,077h,075h,070h,070h,0d8h,091h,071h,091h,078h,0ffh	; 520c  ......wupp..q.x.
	defb 0d6h,0fbh,002h,004h,0e2h,025h,020h,020h,023h,023h,023h,023h,027h,0e3h,0a5h,0a0h	; 521c  .....%  ####'...
	defb 0a0h,0d8h,0e2h,001h,001h,001h,0e3h,0b8h,0ffh,0d6h,0fbh,002h,004h,0e3h,075h,060h	; 522c  ..............u`
	defb 070h,093h,063h,073h,063h,043h,023h,035h,030h,030h,0d8h,051h,051h,051h,0d6h,073h	; 523c  p.cscC#500.QQQ.s
	defb 023h,0e3h,073h,0ffh,0e8h,0d5h,0fch,002h,006h,0e1h,022h,020h,021h,041h,021h,001h	; 524c  #.s......." !A!.
	defb 022h,020h,021h,041h,021h,001h,052h,020h,051h,072h,040h,071h,09bh,0ffh,0d5h,0fch	; 525c  " !A!.R Qr@q....
	defb 002h,006h,0e3h,075h,0e2h,001h,021h,041h,0e3h,075h,0e2h,001h,021h,041h,0e3h,0a2h	; 526c  ...u..!A.u..!A..
	defb 0a0h,0a1h,0e2h,002h,000h,001h,02bh,0ffh,025h,01fh,004h,005h,004h,005h,006h,007h	; 527c  ......+.%.......
	defb 008h,028h,008h,007h,0feh,007h,08eh,052h,025h,006h,005h,006h,005h,004h,003h,002h	; 528c  .(.....R%.......
	defb 001h,0ffh,023h,01bh,0a0h,001h,0b0h,001h,014h,0b0h,001h,0a0h,001h,01ch,0b0h,001h	; 529c  ..#.............
	defb 0a0h,001h,015h,0b0h,001h,0a0h,001h,01dh,0b0h,001h,0a0h,001h,016h,0b0h,001h,0a0h	; 52ac  ................
	defb 001h,01eh,0b0h,001h,0a0h,001h,017h,0b0h,001h,0a0h,001h,01fh,0b0h,001h,0a0h,001h	; 52bc  ................
	defb 016h,0b0h,001h,0a0h,001h,01eh,0b0h,001h,0a0h,001h,015h,0b0h,001h,0a0h,001h,0feh	; 52cc  ................
	defb 002h,0c7h,052h,01dh,0b0h,001h,0a0h,001h,013h,0b0h,001h,0a0h,001h,01ch,0b0h,001h	; 52dc  ..R.............
	defb 0a0h,001h,013h,0b0h,001h,0a0h,001h,01bh,0b0h,001h,0a0h,001h,013h,0a0h,001h,090h	; 52ec  ................
	defb 001h,01ah,090h,001h,080h,001h,013h,090h,001h,080h,001h,019h,090h,001h,080h,001h	; 52fc  ................
	defb 013h,090h,001h,080h,001h,018h,080h,001h,070h,001h,013h,080h,001h,070h,001h,017h	; 530c  ........p....p..
	defb 080h,001h,070h,001h,013h,080h,001h,070h,001h,016h,070h,001h,060h,001h,013h,070h	; 531c  ..p....p..p.`..p
	defb 001h,060h,001h,015h,070h,001h,060h,001h,013h,070h,001h,060h,001h,014h,050h,001h	; 532c  .`..p.`..p.`..P.
	defb 040h,001h,013h,050h,001h,040h,001h,0ffh,02ah,000h,000h,022h,080h,022h,080h,023h	; 533c  @..P.@..*..".".#
	defb 080h,024h,021h,080h,025h,080h,027h,080h,029h,080h,02bh,080h,02ch,0feh,002h,047h	; 534c  .$!.%.'.).+.,..G
	defb 053h,022h,080h,020h,080h,021h,080h,022h,021h,080h,024h,080h,026h,080h,028h,080h	; 535c  S". .!."!.$.&.(.
	defb 02ah,026h,080h,024h,000h,000h,022h,080h,035h,080h,036h,080h,033h,021h,080h,032h	; 536c  *&.$..".5.6.3!.2
	defb 080h,030h,080h,02eh,080h,02ch,022h,070h,035h,070h,036h,060h,033h,021h,060h,032h	; 537c  .0...,"p5p6`3!`2
	defb 050h,030h,050h,02eh,040h,02ch,02fh,000h,000h,000h,000h,022h,080h,024h,080h,026h	; 538c  P0P.@,/....".$.&
	defb 080h,028h,023h,080h,02ah,080h,024h,080h,026h,022h,080h,028h,080h,02ah,080h,02ch	; 539c  .(#.*.$.&".(.*.,
	defb 080h,02eh,080h,02fh	; 53ac

; ----------------------------------------------------------------------
; DATOS fin_de_pista: un solo 0xFF, al que apuntan las tres ultimas entradas
;   de la tabla y la [1]: la pista muda
;   0x53b0..0x53b1  (1 bytes)
DATA_fin_de_pista:
	defb 0ffh	; 53b0

; ======================================================================
; CODIGO 0x53b1..0x545b  (170 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; MONTA LA PRUEBA. Lo comun -la fuente y un juego de patrones- lo pone para las cuatro, y a partir de ahi se separa: el ciclismo tiene su montaje aqui mismo, el curling se va entero a 0xA839 y el triple salto y la pertiga comparten el de 0x73D9, igual que comparten motor.
; ----------------------------------------------------------------------
monta_la_prueba:		; reparte segun cual de las cuatro toca
	call monta_la_fuente		;53b1   ; la fuente, que la usan las cuatro
	ld de,07658h		;53b4   ; los patrones comunes, a partir del tile 0x06
	ld hl,02030h		;53b7
	call descomprime_en_los_tres_tercios		;53ba
	ld de,0766ch		;53bd   ; y su color
	ld hl,00030h		;53c0
	call descomprime_en_los_tres_tercios		;53c3
	ld a,078h		;53c6   ; la cuenta del parpadeo del rotulo
	ld (0e07dh),a		;53c8
	ld a,(0e06ah)		;53cb   ; la prueba en curso
	and 003h		;53ce
	jr z,monta_el_ciclismo		;53d0   ; la 0 es el ciclismo
	cp 002h		;53d2   ; la 2 es el curling, que se monta entero aparte
	jp z,monta_el_curling		;53d4
	ld hl,0e120h		;53d7   ; quedan el triple salto y la pertiga: 512 bytes de variables, a cero
	ld de,0e121h		;53da
	ld bc,001ffh		;53dd
	ld (hl),000h		;53e0
	ldir		;53e2
	xor a			;53e4
	ld hl,01000h		;53e5   ; el estado de arranque del atleta
	ld (0e10dh),hl		;53e8
	ld (0e10fh),a		;53eb
	call prepara_al_atleta		;53ee   ; y las dos preparaciones que comparten
	call es_la_pertiga		;53f1   ; con el bit 1 de la prueba se distinguen: sin el, el triple salto
	ld hl,002bfh		;53f4   ; el desplazamiento de arranque de la pista, en el TRIPLE SALTO
	jr z,L_53FC		;53f7
	ld hl,0017fh		;53f9   ; y en la pertiga: `es_la_pertiga` deja Z en el triple salto, o sea que el 0x2BF es el suyo. Cotejado contra (0xE129) en la RAM del emulador
L_53FC:
	ld (0e129h),hl		;53fc
	jp monta_la_pista_del_salto		;53ff
monta_el_ciclismo:		; la unica prueba con su montaje aqui
	call monta_las_ruedas_en_ocho_pasos		;5402   ; la pista
	call monta_a_los_dos_ciclistas		;5405   ; las variables de la prueba
	ld hl,02268h		;5408   ; los patrones de la bicicleta y el circuito
	ld de,09d5fh		;540b
	call descomprime_en_los_tres_tercios		;540e
	ld hl,00268h		;5411   ; y su color
	ld de,09f16h		;5414
	call descomprime_en_los_tres_tercios		;5417
	ld de,09fb7h		;541a   ; la tabla de nombres
	call descomprime_a_vram		;541d
monta_el_marcador_de_arriba:		; la franja de arriba, comun a las cuatro
	ld hl,02200h		;5420   ; los patrones del marcador
	ld de,075abh		;5423
	call descomprime_a_vram_en		;5426
	ld hl,00200h		;5429   ; su color
	ld de,0760ah		;542c
	call descomprime_a_vram_en		;542f
	ld de,09fa7h		;5432   ; y sus casillas
	call descomprime_a_vram		;5435
	ld hl,002c0h		;5438   ; dos tiles mas, en blanco
	ld bc,00010h		;543b
	ld a,0f0h		;543e
	jp 00056h		;5440   ; BIOS FILVRM - Fills VRAM with value

; ----------------------------------------------------------------------
; (0xE06A) lleva en los dos bits de abajo la prueba y en los de arriba la vuelta, o sea cuantas veces se han dado ya las cuatro. Esta rutina saca la vuelta, la recorta a siete y con ella indexa la tabla que le pasen: asi es como suben las exigencias sin que haya una tabla por prueba.
; ----------------------------------------------------------------------
valor_de_la_vuelta:		; la entrada de la tabla que toca segun la vuelta
	ld a,(0e06ah)		;5443   ; la prueba y la vuelta, juntas
	rra			;5446   ; dos rotaciones dejan solo la vuelta
	rra			;5447
	and 03fh		;5448
	cp 007h		;544a   ; de la octava vuelta en adelante
	jr c,L_5450		;544c
	ld a,007h		;544e   ; no se sube mas
L_5450:
	add a,a			;5450   ; dos bytes por entrada
	call suma_a_hl		;5451
	ld e,(hl)			;5454   ; la entrada
	inc hl			;5455
	ld d,(hl)			;5456
	ld hl,0e08bh		;5457   ; y HL, en los tres bytes que la resta consume
	ret			;545a

; ----------------------------------------------------------------------
; DATOS tabla_de_words_545b: 8 words descendentes, de 0x0300 a 0x0130; los
;   recorre L_5443 desde 0x54F3
;   0x545b..0x546b  (16 bytes)
DATA_tabla_de_words_545b:
	defw 00300h,00245h,00230h,00215h,00200h,00150h,00140h,00130h	; 545b

; ======================================================================
; CODIGO 0x546b..0x5511  (166 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Monta a los dos ciclistas, y solo la llama el ciclismo. Borra de 0xE0A0 a 0xE3FF, deja listo el bloque del jugador 1 y lo COPIA entero sobre el del 2, sesenta y cuatro bytes mas arriba, con lo que los dos empiezan iguales; encima de cada uno van sus cuatro bytes propios, que son los dos grupos de 0x5511. Esos mismos bytes de 0xE0A0 son los atributos de sprite en el triple salto y en la pertiga: cada prueba usa la RAM a su manera. Al final descomprime a la RAM los dos bloques grandes de 0xE400 y 0xE600.
; ----------------------------------------------------------------------
monta_a_los_dos_ciclistas:		; los dos bloques de sesenta y cuatro bytes
	ld hl,08669h		;546b   ; la primera figura del ciclista
	ld a,001h		;546e
	ld (0e096h),hl		;5470   ; la del jugador 1
	ld (0e098h),a		;5473
	ld (0e099h),hl		;5476   ; y la del 2
	ld (0e09bh),a		;5479
	xor a			;547c
	ld (0e071h),a		;547d   ; los intentos de los dos, a cero
	ld (0e081h),a		;5480
	ld hl,0e0a0h		;5483   ; desde el bloque del ciclista 1
	ld (hl),a			;5486
	ld de,0e0a1h		;5487
	ld bc,0035eh		;548a   ; hasta el final de los 2 KB
	ldir		;548d
	ld hl,05511h		;548f   ; los cuatro bytes propios del ciclista 1
	ld de,0e0b1h		;5492
	ld bc,00004h		;5495
	ldir		;5498
	ld a,058h		;549a   ; y su sprite, en la fila 0x58
	ld (0e0b0h),a		;549c
	ld hl,00101h		;549f   ; dos parejas de unos
	ld (0e0beh),hl		;54a2
	ld (0e0c0h),hl		;54a5
	ld hl,0e0a1h		;54a8   ; el bloque del ciclista 1
	ld de,0e0e1h		;54ab   ; copiado entero sobre el del ciclista 2, que va 0x40 mas arriba
	ld bc,0003fh		;54ae
	ldir		;54b1
	ld hl,05515h		;54b3   ; y encima, los cuatro bytes propios del ciclista 2
	ld de,0e0f1h		;54b6
	ld bc,00004h		;54b9
	ldir		;54bc
	ld hl,02000h		;54be   ; dos punteros a los patrones
	ld (0e381h),hl		;54c1
	ld (0e384h),hl		;54c4
	ld hl,02020h		;54c7   ; y otro mas
	ld (0e10bh),hl		;54ca
	ld a,020h		;54cd
	ld (0e0e3h),a		;54cf
	ld a,(0e070h)		;54d2   ; el jugador 1, si no esta en la partida
	and a			;54d5
	jr nz,L_54DD		;54d6
	ld a,001h		;54d8
	ld (0e0a0h),a		;54da   ; arranca ya con un 1 en su primer byte
L_54DD:
	ld a,(0e080h)		;54dd   ; y lo mismo con el 2
	and a			;54e0
	jr nz,L_54E8		;54e1
	ld a,001h		;54e3
	ld (0e0e0h),a		;54e5
L_54E8:
	ld hl,00101h		;54e8
	ld (0e113h),hl		;54eb
	ld a,09fh		;54ee   ; el ultimo de los sprites
	ld (0e389h),a		;54f0
	ld hl,0545bh		;54f3   ; la tabla de las ocho vueltas
	call valor_de_la_vuelta		;54f6
	ld (hl),000h		;54f9   ; y sus dos bytes, en los tres que la resta consume
	inc hl			;54fb
	ld (hl),e			;54fc
	inc hl			;54fd
	ld (hl),d			;54fe
	ld hl,09b86h		;54ff   ; los dos bloques que van descomprimidos a la RAM, no a la VRAM
	ld de,0e400h		;5502
	call descomprime_a_la_ram_en		;5505   ; uno a 0xE400
	ld hl,09845h		;5508
	ld de,0e600h		;550b
	jp descomprime_a_la_ram_en		;550e   ; y el otro a 0xE600

; ----------------------------------------------------------------------
; DATOS tabla_de_bytes_5511: 8 B: 04 0B 07 04 06 0B 0F 06
;   0x5511..0x5519  (8 bytes)
DATA_tabla_de_bytes_5511:
	defb 004h,00bh,007h,004h,006h,00bh,00fh,006h	; 5511  ........

; ----------------------------------------------------------------------
; DATOS rle_5519: 39 B -> 128 de VRAM; lo cargan 0x91FC y 0xA8B4
;   0x5519..0x5540  (39 bytes)
DATA_rle_5519:
	defb 000h,038h,082h,050h,042h,009h,000h,001h,045h,013h,000h,083h,053h,050h,043h,009h	; 5519  .8.PB...E...SPC.
	defb 000h,001h,046h,013h,000h,083h,053h,050h,044h,009h,040h,001h,047h,013h,000h,082h	; 5529  ..F...SPD.@.G...
	defb 053h,051h,01eh,056h,001h,054h,000h	; 5539

; ======================================================================
; CODIGO 0x5540..0x5548  (8 bytes)
; ======================================================================


despacha_por_prueba:		; las cuatro, con el mismo indice de siempre
	ld a,(0e06ah)		;5540   ; la prueba en curso
	and 003h		;5543
	call despacha_por_indice		;5545   ; y su rutina, de la tabla de detras

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_5548: 4 entradas; el `and 003h` de 0x5542 dice que
;   son cuatro y no mas
;   0x5548..0x5550  (8 bytes)
DATA_tabla_de_subescenas_5548:
	defw 09105h,05550h,0a92eh,05550h	; 5548  -> despacha_la_escena_del_ciclismo despacha_por_subescena despacha_la_subescena_del_curling despacha_por_subescena

; ======================================================================
; CODIGO 0x5550..0x5558  (8 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Dentro de una prueba hay cuatro subescenas -el rotulo, el intento, el resultado y el cambio de turno- y este es su reparto. Vale para el triple salto y para la pertiga, que son las dos que apuntan aqui en la tabla de 0x5548.
; ----------------------------------------------------------------------
despacha_por_subescena:		; el nibble de abajo de (0xE09E)
	ld a,(0e09eh)		;5550   ; la subescena, en el nibble de abajo
	and 00fh		;5553
	call despacha_por_indice		;5555   ; y su rutina

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_5558: 4 entradas; detras sigue la primera de
;   ellas, 0x5560
;   0x5558..0x5560  (8 bytes)
DATA_tabla_de_subescenas_5558:
	defw 05560h,055b4h,056eeh,05720h	; 5558  -> subescena_del_rotulo subescena_del_intento subescena_del_resultado subescena_del_cambio_de_turno

; ======================================================================
; CODIGO 0x5560..0x57f1  (657 bytes)
; ======================================================================


subescena_del_rotulo:		; la marca a batir, y a esperar
	call rotulo_del_record_del_mundo		;5560   ; el record del mundo, parpadeando
	ret nz			;5563   ; mientras parpadee, aqui no se sigue
	call arranca_el_intento		;5564
	ld hl,0e09eh		;5567   ; a la subescena siguiente
	inc (hl)			;556a
L_556B:
	call es_la_pertiga		;556b   ; el bit 1 de la prueba: sin el, el triple salto
	rra			;556e
	jr z,L_5577		;556f
	inc a			;5571   ; en la pertiga, el liston que toque
	call marca_del_liston		;5572
	jr L_558A		;5575
L_5577:
	rra			;5577   ; y en el triple salto la vuelta manda
	and 00fh		;5578
	cp 007h		;557a   ; de la octava en adelante
	jr c,L_5580		;557c
	ld a,007h		;557e
L_5580:
	ld hl,0757dh		;5580   ; la tabla de las ocho marcas del triple salto
	add a,a			;5583
	call suma_a_hl		;5584
	ld e,(hl)			;5587
	inc hl			;5588
	ld d,(hl)			;5589
L_558A:
	ld hl,0e08bh		;558a   ; la marca a batir, en los tres bytes que la resta consume
	ld (hl),e			;558d
	inc hl			;558e
	ld (hl),d			;558f
	inc hl			;5590
	xor a			;5591
	ld (hl),a			;5592
	ld (0e004h),a		;5593   ; sin espera
	ld de,0e08ch		;5596   ; pintada con su punto decimal
	ld hl,03846h		;5599
	call escribe_una_marca		;559c
	ld de,075a1h		;559f   ; y el rotulo de al lado
	jp pinta_guion_de_tiles		;55a2
espera_y_arranca_el_intento:		; la cuenta atras, y al agotarse la pista
	dec (hl)			;55a5
	ld a,(hl)			;55a6
	or a			;55a7
	ret nz			;55a8
arranca_el_intento:		; la pantalla del intento y su musica
	ld de,076b3h		;55a9   ; el trozo de pantalla del intento
	call descomprime_a_vram		;55ac
	ld a,08eh		;55af   ; la pista 0x0E
	jp arranca_una_pista		;55b1

; ----------------------------------------------------------------------
; EL FOTOGRAMA DEL INTENTO. Por orden: el crono, el atleta, sus sprites a la VRAM, la comprobacion de si ha batido la marca y el remate. El intercambio de sprites de 0x57C7 se hace cuando la figura pide que el trozo de delante pase a estar detras, y va atado al bit 0 del contador de fotogramas para que no se note.
; ----------------------------------------------------------------------
subescena_del_intento:		; el fotograma del atleta mientras salta
	ld hl,0e004h		;55b4
	ld a,(hl)			;55b7   ; mientras quede cuenta atras, no se ha empezado
	or a			;55b8
	jr nz,espera_y_arranca_el_intento		;55b9
	ld a,(0e12dh)		;55bb   ; el crono, solo si esta a cero
	or a			;55be
	call z,crono_de_la_carrerilla		;55bf
	call mueve_al_atleta		;55c2   ; el atleta
	call L_6481		;55c5
	ld hl,0e172h		;55c8   ; sin intercambio de sprites, de momento
	ld (hl),000h		;55cb
	call es_la_pertiga		;55cd   ; el bit 1 de la prueba
	push af			;55d0
	jr z,L_55F2		;55d1
	ld a,(0e130h)		;55d3
	cp 003h		;55d6   ; en la pertiga, solo en dos de sus estados
	jr z,L_55DE		;55d8
	cp 006h		;55da
	jr nz,L_55F2		;55dc
L_55DE:
	ld a,(0e134h)		;55de   ; y con la figura entre la cuarta y la quinta
	sub 004h		;55e1
	cp 002h		;55e3
	jr nc,L_55F2		;55e5
	ld a,(0e003h)		;55e7   ; un fotograma si y otro no
	rra			;55ea
	jr c,L_55F2		;55eb
	ld (hl),0ffh		;55ed   ; marcado el intercambio
	call intercambia_dos_sprites		;55ef
L_55F2:
	call vuelca_los_sprites		;55f2   ; los sprites, a la VRAM
	ld a,(0e172h)		;55f5
	or a			;55f8
	call nz,intercambia_dos_sprites		;55f9   ; y si estaba marcado, el intercambio
	ld a,(0e09fh)		;55fc   ; si el intento ya esta juzgado, no se juzga otra vez
	or a			;55ff
	jr nz,remata_el_intento		;5600
	call es_la_pertiga		;5602
	jr z,L_5627		;5605
	ld b,002h		;5607   ; dos
	cp 003h		;5609   ; salvo en un estado, que es uno
	jr nz,L_560E		;560b
	dec b			;560d
L_560E:
	ld a,(0e130h)		;560e   ; la figura cuarta
	cp 004h		;5611
	jr nz,remata_el_intento		;5613
	call apunta_al_jugador_de_turno		;5615   ; los intentos del jugador de turno
	inc hl			;5618
	inc hl			;5619
	ld a,(hl)			;561a
	sub b			;561b   ; menos los que se ha gastado
	jr z,L_5620		;561c
	jr nc,L_5622		;561e
L_5620:
	ld a,001h		;5620   ; y de uno no se baja
L_5622:
	call marca_del_liston		;5622   ; la marca de ese liston
	jr L_562F		;5625
L_5627:
	ld de,(0e164h)		;5627   ; la distancia conseguida
	ld a,d			;562b
	inc a			;562c   ; con 0xFF arriba no hay marca que juzgar
	jr z,remata_el_intento		;562d
L_562F:
	ld c,000h		;562f   ; la marca conseguida
	call record_del_mundo_de_la_prueba		;5631
	call guarda_si_ha_superado		;5634   ; contra la que habia
	jr c,remata_el_intento		;5637   ; y si no llega, el intento no cuenta
	ld hl,0e09fh		;5639   ; juzgado
	ld (hl),001h		;563c
remata_el_intento:		; reparte segun le quede o no algo al jugador
	ld c,000h		;563e
	call apunta_al_jugador_de_turno		;5640   ; el jugador de turno
	ex af,af'			;5643
	pop de			;5644
	ld a,(hl)			;5645   ; su primer byte
	or a			;5646
	ret nz			;5647   ; y mientras no este a cero, aqui no se hace nada
	push de			;5648
	pop af			;5649
	jr nz,remata_el_intento_de_pertiga		;564a
	ex af,af'			;564c
	ld hl,0e110h		;564d   ; los tres saltos del triple, del jugador 1
	jr z,L_5654		;5650
	ld l,018h		;5652   ; o los del 2
L_5654:
	ld b,003h		;5654   ; tres
L_5656:
	ld c,000h		;5656
	ld e,(hl)			;5658   ; la distancia de cada uno
	inc hl			;5659
	ld d,(hl)			;565a
	inc hl			;565b
	push hl			;565c
	ld a,d			;565d
	inc a			;565e   ; la que vale 0xFF arriba no se dio
	jr z,L_5676		;565f
	push bc			;5661
	call marcas_del_jugador_de_turno		;5662   ; los tres bytes de la marca del jugador
	pop bc			;5665
	call guarda_si_ha_superado		;5666   ; la suma
	ld c,000h		;5669
	call resta_de_24_bits		;566b   ; contra la marca a batir
	jr c,L_5676		;566e   ; y si no llega, no califica
	call apunta_al_jugador_de_turno		;5670
	inc hl			;5673
	ld (hl),001h		;5674   ; calificado
L_5676:
	pop hl			;5676
	djnz L_5656		;5677
	call marcas_del_jugador_de_turno		;5679   ; la marca del jugador y su mejor marca
	ld e,(hl)			;567c
	inc hl			;567d
	ld d,(hl)			;567e
	ld a,e			;567f
	or d			;5680   ; sin marca no hay nada que apuntar
	ret z			;5681
	ex de,hl			;5682
	ld a,h			;5683
	sub 011h		;5684   ; 0x11 menos, en BCD
	daa			;5686
	ld h,a			;5687
	xor a			;5688
	add hl,hl			;5689   ; y por dieciseis: asi es como la cuenta interna se convierte en metros
	add hl,hl			;568a
	add hl,hl			;568b
	add hl,hl			;568c
	adc a,a			;568d
	ex de,hl			;568e
	ld h,b			;568f
	ld l,c			;5690
	ld (hl),e			;5691   ; la marca, ya en metros
	inc hl			;5692
	ld (hl),d			;5693
	inc hl			;5694
	ld (hl),a			;5695
	ret			;5696
remata_el_intento_de_pertiga:		; el liston superado o no
	inc hl			;5697
	inc hl			;5698
	ld a,(0e06ah)		;5699   ; la prueba
	cp 003h		;569c
	ld b,001h		;569e   ; en la 3, la pertiga, uno
	jr z,L_56A3		;56a0
	inc b			;56a2   ; y en las demas, dos
L_56A3:
	ld a,(hl)			;56a3
	inc hl			;56a4
	cp (hl)			;56a5   ; con los dos iguales, no hay nada
	jr z,L_56C3		;56a6
	sub b			;56a8   ; y por debajo, tampoco
	jr c,L_56C3		;56a9
	call marca_del_liston		;56ab   ; la marca de ese liston
	call marcas_del_jugador_de_turno		;56ae
	ld c,000h		;56b1
	call guarda_si_ha_superado		;56b3
	ld c,000h		;56b6
	call resta_de_24_bits		;56b8   ; contra la que habia
	jr c,L_56C3		;56bb   ; y si no llega, no califica
	call apunta_al_jugador_de_turno		;56bd
	inc hl			;56c0
	ld (hl),001h		;56c1   ; calificado
L_56C3:
	call marcas_del_jugador_de_turno		;56c3   ; la marca del jugador y su mejor marca
	ld e,(hl)			;56c6
	inc hl			;56c7
	ld d,(hl)			;56c8
	ld a,e			;56c9
	or d			;56ca
	ret z			;56cb   ; sin marca, nada que apuntar
	ex de,hl			;56cc
	ld de,00565h		;56cd   ; los 5.65 del primer liston
	sbc hl,de		;56d0
	add hl,hl			;56d2   ; por dos
	push bc			;56d3
	call a_decimal		;56d4   ; y a metros
	pop bc			;56d7
	ld h,b			;56d8
	ld l,c			;56d9
	ld b,000h		;56da
	ld a,005h		;56dc   ; cinco centimetros mas
	add a,e			;56de
	daa			;56df
	ld e,a			;56e0
	jr nc,L_56E8		;56e1
	ld a,001h		;56e3   ; con su acarreo en BCD
	add a,d			;56e5
	daa			;56e6
	ld d,a			;56e7
L_56E8:
	ld (hl),b			;56e8   ; los tres bytes de la marca, apuntados
	inc hl			;56e9
	ld (hl),e			;56ea
	inc hl			;56eb
	ld (hl),d			;56ec
	ret			;56ed
subescena_del_resultado:		; espera a que el sonido acabe y decide
	call rotulo_del_record_del_mundo		;56ee
	ld a,(0e012h)		;56f1   ; mientras suene algo, no se sigue
	or a			;56f4
	ret nz			;56f5
	ld a,(0e188h)		;56f6   ; el resultado del intento
	or a			;56f9
	jr nz,L_5706		;56fa
	ld (0e069h),a		;56fc   ; a esperar ya no
	ld hl,0e09eh		;56ff
	dec (hl)			;5702   ; la subescena anterior: otro intento
	inc hl			;5703
	ld (hl),a			;5704
	ret			;5705
L_5706:
	ld a,003h		;5706   ; la subescena 3, la del cambio
	ld (0e09eh),a		;5708
	ld hl,0e185h		;570b   ; la cuenta del parpadeo
	call es_la_pertiga		;570e
	ld (hl),032h		;5711   ; en la pertiga
	jr nz,L_5717		;5713
	ld (hl),074h		;5715   ; y en el triple salto
L_5717:
	inc hl			;5717
	ld (hl),0feh		;5718   ; el guion que parpadea
	ld de,0906bh		;571a   ; el trozo de pantalla del resultado
	jp descomprime_a_vram		;571d
subescena_del_cambio_de_turno:		; hasta que 0x5CA0 diga que ya
	call sube_el_cartel_del_resultado		;5720
	ret nc			;5723   ; mientras no termine, aqui no se sale
	xor a			;5724
	ld (0e069h),a		;5725   ; a esperar ya no
	ld hl,0e09eh		;5728
	ld (hl),001h		;572b   ; y de vuelta a la subescena 1
	inc hl			;572d
	ld (hl),a			;572e
	ret			;572f

; ----------------------------------------------------------------------
; El crono de la carrerilla: mientras el jugador de turno no toque ninguna de las teclas de correr, (0xE13B) baja de uno en uno desde 0x3FF, y en tres puntos concretos de esa cuenta -0x47 de diferencia entre ellos- suena un aviso. Al llegar a cero se acabo el intento, y el remate es distinto en cada prueba. El `pop de` del final tira la direccion de retorno: quien llamo ya no vuelve.
; ----------------------------------------------------------------------
crono_de_la_carrerilla:		; la cuenta que baja mientras nadie toca el mando
	call lo_recien_pulsado_por_el_de_turno		;5730   ; lo recien pulsado por el jugador de turno
	and 038h		;5733   ; si ha tocado algo
	jr z,L_573E		;5735
	ld hl,003ffh		;5737   ; el crono, entero otra vez
	ld (0e13bh),hl		;573a
	ret			;573d
L_573E:
	ld hl,(0e13bh)		;573e   ; y si no, un punto menos
	dec hl			;5741
	ld (0e13bh),hl		;5742
	ld a,h			;5745
	or l			;5746
	jr z,L_5758		;5747   ; al llegar a cero, se acabo
	ld b,003h		;5749
	ld de,00047h		;574b   ; los tres puntos donde suena el aviso
	ld a,005h		;574e
L_5750:
	sbc hl,de		;5750
	jp z,suena_si_hay_partida		;5752   ; y ahi suena
	djnz L_5750		;5755
	ret			;5757
L_5758:
	call es_la_pertiga		;5758   ; el bit 1 de la prueba
	jr nz,L_5767		;575b
	call marca_intento_nulo		;575d   ; en el triple salto
	ld a,04ch		;5760
	ld (0e13dh),a		;5762
	jr L_576D		;5765
L_5767:
	call termina_el_intento		;5767   ; y en la pertiga
	call cierra_el_intento_de_pertiga		;576a
L_576D:
	ld a,001h		;576d   ; se acabo el intento
	ld (0e12dh),a		;576f
	ld (0e128h),a		;5772
	pop de			;5775   ; y quien llamo no vuelve
	ret			;5776
rotulo_del_record_del_mundo:		; la marca y el rotulo, parpadeando
	call record_del_mundo_de_la_prueba		;5777   ; el record del mundo de esta prueba
	inc hl			;577a
	ex de,hl			;577b
	ld hl,03846h		;577c   ; en la casilla 0x46 de la pantalla
	call escribe_una_marca		;577f   ; con su punto decimal
	ld de,057f1h		;5782   ; y el rotulo WORLD RECORD
	jp parpadea_guion_de_tiles		;5785   ; parpadeando: mientras parpadee devuelve NZ

; ----------------------------------------------------------------------
; La altura de un liston de pertiga. Los nueve primeros salen de la tabla, que esta apuntada dos bytes por debajo para que el indice empiece en uno; del decimo en adelante ya no hay tabla y la altura se calcula sumando en BCD sobre la ultima.
; ----------------------------------------------------------------------
marca_del_liston:		; la altura del liston numero A
	ld c,a			;5788
	ld b,000h		;5789   ; el numero de liston, apuntado
	cp 009h		;578b   ; del noveno en adelante
	jr c,L_5792		;578d
	ld a,009h		;578f   ; se usa el noveno
	dec b			;5791   ; y se marca que hay que sumar
L_5792:
	add a,a			;5792
	ld hl,0758bh		;5793   ; la tabla, dos bytes por debajo
	call suma_a_hl		;5796
	ld e,(hl)			;5799
	inc hl			;579a
	ld d,(hl)			;579b
	bit 0,b		;579c   ; sin sumar, ya esta
	ret z			;579e
	ld a,c			;579f
	sub 009h		;57a0   ; cuantos pasa del noveno
	call parte_y_devuelve		;57a2   ; lo que hay que sumarle
	add a,e			;57a5   ; sumado en BCD
	daa			;57a6
	ld e,a			;57a7
	ret nc			;57a8
	inc d			;57a9
	ret			;57aa
record_del_mundo_de_la_prueba:		; HL a los bytes del record
	call es_la_pertiga		;57ab   ; el bit 1 de la prueba
	ld hl,0e056h		;57ae   ; el record del triple salto
	ret z			;57b1
	ld hl,0e05ch		;57b2   ; y el de la pertiga
	ret			;57b5
marcas_del_jugador_de_turno:		; HL la de ahora y BC la mejor
	call apunta_al_jugador_de_turno		;57b6
	ld hl,0e090h		;57b9   ; la marca de ahora del jugador 1
	ld bc,0e096h		;57bc   ; y su mejor marca
	ret z			;57bf
	ld hl,0e093h		;57c0   ; las del jugador 2
	ld bc,0e099h		;57c3
	ret			;57c6

; ----------------------------------------------------------------------
; Intercambia los cuatro bytes del sprite 3 con los del 13. En el VDP los sprites se tapan por orden de tabla, asi que este cambio es lo que hace que un trozo del atleta pase de estar delante a estar detras -o al reves- sin mover un pixel.
; ----------------------------------------------------------------------
intercambia_dos_sprites:		; cambia de orden los sprites 3 y 13
	ld hl,0e0ach		;57c7
	ld de,0e0d4h		;57ca
	ld b,004h		;57cd
L_57CF:
	ld c,(hl)			;57cf   ; los cuatro bytes de cada uno, uno a uno
	ld a,(de)			;57d0
	ld (hl),a			;57d1
	ld a,c			;57d2
	ld (de),a			;57d3
	inc hl			;57d4
	inc de			;57d5
	djnz L_57CF		;57d6
	ret			;57d8

; ----------------------------------------------------------------------
; La tabla de atributos de sprite se lleva entera en la RAM, en 0xE0A0, y se vuelca de un tiron cada fotograma. Son dieciocho sprites: el atleta se monta pieza a pieza en la RAM y solo entonces se manda al VDP, que es lo que evita verlo a medio montar.
; ----------------------------------------------------------------------
vuelca_los_sprites:		; los 72 bytes de 0xE0A0 a la tabla de atributos
	ld de,0e0a0h		;57d9
	ld hl,03b00h		;57dc   ; la tabla de atributos
	ld bc,00048h		;57df   ; dieciocho sprites de cuatro bytes
	jp ldirvm		;57e2
guarda_si_ha_superado:		; la resta, y solo se apunta si no hay acarreo
	push de			;57e5
	push hl			;57e6
	call L_43B8		;57e7   ; la resta de 24 bits
	pop hl			;57ea
	pop de			;57eb
	ret c			;57ec   ; y si se ha pasado, no se apunta nada
	ld (hl),e			;57ed   ; el resultado, apuntado
	inc hl			;57ee
	ld (hl),d			;57ef
	ret			;57f0

; ----------------------------------------------------------------------
; DATOS guion_world_record: 15 B: WORLD RECORD en 0x3823; lo pinta L_4430, o
;   sea PARPADEANDO
;   0x57f1..0x5800  (15 bytes)
DATA_guion_world_record:
	defb 023h,038h,037h,02fh,032h,02ch,024h,000h,032h,025h,023h,02fh,032h,024h,0ffh	; 57f1  #87/2,$.2%#/2$.

; ======================================================================
; CODIGO 0x5800..0x5876  (118 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LA DEMOSTRACION NO ES CODIGO: ES UNA PARTIDA GRABADA. El cartucho no lleva una inteligencia que juegue, lleva la lista de lo que se pulso y cuanto tiempo, y se la da al mismo motor que juega el jugador. Por eso la demostracion se comporta exactamente como una partida: es una partida. El triple salto y la pertiga tienen cada uno su grabacion -0x5876 y 0x5880-, y el ciclismo y el curling ni eso.
; ----------------------------------------------------------------------
arranca_la_demostracion:		; monta la prueba y engancha la grabacion
	ld hl,0e002h		;5800
	ld (hl),000h		;5803   ; sin flags: en la demostracion no hay partida ni turnos
	ld hl,0e06ch		;5805   ; borra las 180 variables de la prueba
	ld bc,000b4h		;5808
	call L_42F7		;580b
	call monta_la_prueba		;580e   ; y la monta como si fuese de verdad
	ld a,001h		;5811
	ld (0e069h),a		;5813   ; a esperar
	ld a,(0e06ah)		;5816
	rra			;5819   ; el bit 0 de la prueba: las pares no tienen grabacion
	ret nc			;581a
	ld hl,05880h		;581b   ; la del triple salto
	rra			;581e
	jr nc,L_5824		;581f
	ld hl,05876h		;5821   ; y la de la pertiga
L_5824:
	ld (0e00ch),hl		;5824   ; por donde va la grabacion
	ld a,0c0h		;5827   ; y los 192 fotogramas del primer tramo
	ld (0e00bh),a		;5829
	ret			;582c
demostracion_de_la_prueba:		; reparte por prueba, como en una partida
	ld a,(0e06ah)		;582d
	and 003h		;5830   ; en el ciclismo
	jr nz,L_583C		;5832
	ld a,001h		;5834
	ld (0e0a0h),a		;5836   ; el primer byte de los dos jugadores, a uno
	ld (0e0e0h),a		;5839
L_583C:
	jp despacha_por_prueba		;583c   ; y el mismo reparto que en una partida

; ----------------------------------------------------------------------
; Reproduce la grabacion: cada tramo son los botones que se mantienen pulsados y cuantos fotogramas duran, y el resultado se mete en (0xE009) por la MISMA puerta por la que entran el mando y el teclado de verdad, flancos incluidos, asi que de aqui para abajo nadie nota la diferencia. La derecha, ademas, no se mantiene: se convierte en un toque cada siete fotogramas, que es el machaqueo que un jugador tendria que hacer a mano. El tramo que trae 0xF7 termina la demostracion.
; ----------------------------------------------------------------------
reproduce_la_grabacion:		; los mandos, sacados de la lista en vez del PSG
	ld a,(0e06ah)		;583f
	rra			;5842   ; las pruebas pares no tienen grabacion
	ret nc			;5843
	ld hl,0e00bh		;5844   ; lo que le queda al tramo
	dec (hl)			;5847
	ex de,hl			;5848
	ld hl,(0e00ch)		;5849   ; por donde va la grabacion
	jr nz,L_5854		;584c   ; y mientras el tramo dure, los mismos botones
	inc hl			;584e   ; el tramo siguiente
	ldi		;584f   ; cuantos fotogramas dura, a la cuenta atras
	ld (0e00ch),hl		;5851
L_5854:
	ld b,(hl)			;5854   ; los botones de este tramo
	ld hl,0e00eh		;5855   ; el contador del machaqueo
	inc (hl)			;5858
	bit 3,b		;5859   ; el bit 3 es la derecha
	jr z,L_5868		;585b
	ld a,(hl)			;585d   ; y de mantenerla no sale nada
	res 3,b		;585e
	cp 007h		;5860   ; uno de cada siete fotogramas
	jr c,L_5868		;5862
	ld (hl),000h		;5864
	set 3,b		;5866   ; se da por pulsada
L_5868:
	ld a,b			;5868
	cp 0f7h		;5869   ; el tramo de 0xF7 cierra la grabacion
	ld hl,0e009h		;586b   ; y si no, a la misma puerta que el mando de verdad
	jp nz,guarda_estado_y_flancos		;586e
	xor a			;5871
	ld (0e069h),a		;5872   ; se acabo la demostracion
	ret			;5875

; ----------------------------------------------------------------------
; DATOS tabla_5876: 10 B; la carga 0x5821 en (0xE00C) cuando los dos bits de
;   abajo de (0xE06A) valen 3
;   0x5876..0x5880  (10 bytes)
DATA_tabla_5876:
	defb 000h,0f0h,008h,028h,008h,068h,018h,0f8h,000h,0f7h	; 5876  ...(.h....

; ----------------------------------------------------------------------
; DATOS tabla_5880: 22 B; la alternativa a la de arriba, desde 0x581B
;   0x5880..0x5896  (22 bytes)
DATA_tabla_5880:
	defb 000h,0f0h,008h,040h,008h,010h,010h,048h,000h,01fh,010h	; 5880  ...@...H...
	defb 040h,000h,028h,018h,048h,008h,0f0h,000h,080h,000h,0f7h	; 588b  @.(.H......

; ======================================================================
; CODIGO 0x5896..0x58a3  (13 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; La pantalla de resultados va por partes: cada subescena escribe una linea y espera sesenta fotogramas antes de la siguiente, que es lo que le da el aire de ir apareciendo sola. Salvo la primera, todas apilan 0x5A2F, o sea que al terminar cae en ella.
; ----------------------------------------------------------------------
despacha_la_pantalla_de_resultados:		; ocho subescenas, y una detras
	ld hl,05a2fh		;5896
	ld a,(0e08eh)		;5899   ; por que subescena va
	and a			;589c
	jr z,L_58A0		;589d   ; la primera no apila nada
	push hl			;589f
L_58A0:
	call despacha_por_indice		;58a0   ; y su rutina, de la tabla de detras

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_58a3: 8 entradas; detras sigue la primera, 0x58B3
;   0x58a3..0x58b3  (16 bytes)
DATA_tabla_de_subescenas_58a3:
	defw 058b3h,05913h,05967h,05988h,059adh,059fch,05a1ah,05a28h	; 58a3

; ======================================================================
; CODIGO 0x58b3..0x5a7d  (458 bytes)
; ======================================================================


pantalla_de_resultados_1:		; monta la pantalla
	call limpia_la_pantalla		;58b3
	call monta_la_fuente		;58b6   ; la fuente
	ld a,(0e06ah)		;58b9
	and 003h		;58bc   ; en el ciclismo
	jr nz,L_58D4		;58be
	ld de,09fa9h		;58c0   ; hacen falta unos patrones mas
	ld hl,022c0h		;58c3
	call descomprime_en_los_tres_tercios		;58c6
	ld hl,002c0h		;58c9
	ld bc,00030h		;58cc
	ld a,0f0h		;58cf
	call filvrm_en_los_tres_tercios		;58d1
L_58D4:
	ld hl,02400h		;58d4   ; el marco de la pantalla
	ld de,05c0fh		;58d7
	call descomprime_en_los_tres_tercios		;58da
	call L_646A		;58dd
	call L_622D		;58e0
	ld hl,0c88eh		;58e3   ; la primera figura
	ld (0e131h),hl		;58e6
	ld a,006h		;58e9
	ld (0e130h),a		;58eb   ; y su estado
	ld hl,00400h		;58ee   ; otro juego de patrones
	ld de,05c66h		;58f1
	call descomprime_en_los_tres_tercios		;58f4
	ld de,05b39h		;58f7   ; y las casillas
	call descomprime_a_vram		;58fa
	call alguno_ha_quedado_fuera		;58fd   ; si alguno de los dos ha quedado fuera
	ld a,0a9h		;5900   ; suena una musica
	jr nz,L_5906		;5902
	ld a,0ach		;5904   ; y si no, la otra
L_5906:
	call suena_si_hay_partida		;5906
espera_60_y_sigue:		; sesenta fotogramas hasta la subescena siguiente
	ld a,03ch		;5909   ; sesenta fotogramas, o sea un segundo
	ld (0e004h),a		;590b
sube_la_subescena:		; la siguiente linea de la pantalla
	ld hl,0e08eh		;590e   ; la subescena siguiente
	inc (hl)			;5911
	ret			;5912
pantalla_de_resultados_2:		; el nombre de la prueba y el record
	ld a,(0e06ah)		;5913   ; la prueba en curso
	and 003h		;5916
	add a,a			;5918
	ld hl,05a90h		;5919   ; la tabla de los cuatro nombres
	call suma_a_hl		;591c
	ld e,(hl)			;591f
	inc hl			;5920
	ld d,(hl)			;5921
	call pinta_guion_de_tiles		;5922   ; el nombre de la prueba
	ld de,05ac7h		;5925   ; y el rotulo de al lado
	call pinta_guion_de_tiles		;5928
	ld hl,038b2h		;592b   ; el record, tres bytes en BCD
	ld de,0e062h		;592e
	ld b,003h		;5931
	call escribe_cifras_bcd		;5933
	ld a,(0e06ah)		;5936
	and 003h		;5939
	ld c,a			;593b
	add a,a			;593c
	add a,c			;593d
	ld de,0e055h		;593e   ; las marcas del record, tres bytes por prueba
	call suma_a_de		;5941
	ld hl,038d1h		;5944   ; la del record de esta
	call escribe_la_marca_de_la_prueba		;5947
	ld hl,0390eh		;594a   ; el rotulo del jugador 1
	ld de,09675h		;594d
	ld c,0ffh		;5950
	call L_441D		;5952
	ld hl,03917h		;5955
	ld de,09679h		;5958
	ld a,(0e002h)		;595b
	and 020h		;595e   ; y el del 2, solo si juegan dos
	ld c,0ffh		;5960
	call nz,L_441D		;5962
L_5965:
	jr espera_60_y_sigue		;5965
pantalla_de_resultados_3:		; la marca de cada jugador
	ld hl,0e004h		;5967
	dec (hl)			;596a   ; sesenta fotogramas antes de esta linea
	ret nz			;596b
	ld de,0e092h		;596c
	ld hl,0394ch		;596f
	ld a,(0e070h)		;5972   ; el jugador 1, si esta en la partida
	and a			;5975
	call nz,escribe_la_marca_de_la_prueba		;5976
	ld de,0e095h		;5979
	ld hl,03956h		;597c
	ld a,(0e080h)		;597f   ; y el 2
	and a			;5982
	call nz,escribe_la_marca_de_la_prueba		;5983
	jr L_5965		;5986
pantalla_de_resultados_4:		; la mejor marca de cada uno
	ld hl,0e004h		;5988
	dec (hl)			;598b   ; la espera
	ret nz			;598c
	ld hl,0398dh		;598d
	ld de,0e098h		;5990
	ld a,(0e070h)		;5993   ; el jugador 1
	and a			;5996
	ld b,003h		;5997
	call nz,escribe_cifras_bcd		;5999
	ld hl,03997h		;599c
	ld de,0e09bh		;599f
	ld a,(0e080h)		;59a2   ; y el 2
	and a			;59a5
	ld b,003h		;59a6
	call nz,escribe_cifras_bcd		;59a8
	jr L_5965		;59ab
pantalla_de_resultados_5:		; las puntuaciones y quien queda fuera
	ld hl,0e004h		;59ad
	dec (hl)			;59b0   ; la espera
	ret nz			;59b1
	ld hl,039cdh		;59b2   ; la puntuacion del jugador 1
	ld b,003h		;59b5
	ld de,0e068h		;59b7
	call escribe_cifras_bcd		;59ba
	ld hl,039d7h		;59bd
	ld b,003h		;59c0
	ld de,0e065h		;59c2
	ld a,(0e002h)		;59c5   ; y la del 2, solo si juegan dos
	and 020h		;59c8
	call nz,escribe_cifras_bcd		;59ca
	ld a,(0e072h)		;59cd   ; si el jugador 1 no ha calificado
	and a			;59d0
	jr nz,L_59DE		;59d1
	ld (0e070h),a		;59d3   ; queda fuera de la partida
	ld hl,03aa7h		;59d6
	ld a,011h		;59d9   ; y el 1 de su rotulo
	call rotulo_de_game_over		;59db   ; PLAYER GAME OVER
L_59DE:
	ld a,(0e002h)		;59de
	and 020h		;59e1   ; con un solo jugador, aqui se acaba
	jr z,L_59F6		;59e3
	ld a,(0e082h)		;59e5   ; y si el 2 tampoco ha calificado
	and a			;59e8
	jr nz,L_59F6		;59e9
	ld (0e080h),a		;59eb
	ld hl,03ac7h		;59ee
	ld a,012h		;59f1   ; el 2 de su rotulo
	call rotulo_de_game_over		;59f3
L_59F6:
	call alguno_ha_quedado_fuera		;59f6
	jp sube_la_subescena		;59f9
pantalla_de_resultados_6:		; espera al sonido y decide si sigue
	ld a,(0e012h)		;59fc   ; mientras suene algo, no
	and a			;59ff
	ret nz			;5a00
	ld a,(0e08ah)		;5a01   ; y hasta que 0xE08A no se levante, tampoco
	and a			;5a04
	ret z			;5a05
	call alguno_ha_quedado_fuera		;5a06   ; si los dos siguen dentro
	jr z,L_5A15		;5a09
	ld a,(0e06ah)		;5a0b   ; y la prueba es la ultima de la vuelta
	and 003h		;5a0e
	cp 003h		;5a10
	jp z,sube_la_subescena		;5a12
L_5A15:
	xor a			;5a15   ; se acabo la pantalla
	ld (0e08fh),a		;5a16
	ret			;5a19
pantalla_de_resultados_7:		; el rotulo de despedida
	ld a,0a6h		;5a1a   ; la musica
	call suena_si_hay_partida		;5a1c
	ld de,05afah		;5a1f   ; y el rotulo
	call pinta_guion_de_tiles		;5a22
	jp sube_la_subescena		;5a25
pantalla_de_resultados_8:		; espera al sonido y cierra
	ld a,(0e012h)		;5a28   ; mientras suene algo, no se cierra
	and a			;5a2b
	ret nz			;5a2c
	jr L_5A15		;5a2d
anima_al_atleta_del_resultado:		; el atleta sigue moviendose entre linea y linea
	call alguno_ha_quedado_fuera		;5a2f   ; si los dos siguen dentro, no hay animacion
	jr z,L_5A48		;5a32
	ld a,(0e12ch)		;5a34   ; por que figura va
	push af			;5a37
	xor a			;5a38
	ld (0e08ah),a		;5a39   ; la pantalla, sin terminar
	call anima_al_atleta		;5a3c
	call vuelca_los_sprites		;5a3f   ; los sprites, a la VRAM
	pop af			;5a42
	ld hl,0e12ch		;5a43
	cp (hl)			;5a46   ; y mientras la figura cambie, la pantalla espera
	ret z			;5a47
L_5A48:
	ld a,001h		;5a48   ; cuando deja de cambiar, la pantalla puede seguir
	ld (0e08ah),a		;5a4a
	ret			;5a4d

; ----------------------------------------------------------------------
; Las cuatro pruebas no miden lo mismo, asi que su resultado tampoco se escribe igual: el ciclismo se va a 0xA78C, el curling son tres bytes de puntos en BCD y el triple salto y la pertiga llevan punto decimal, que es lo que hace 0x7566.
; ----------------------------------------------------------------------
escribe_la_marca_de_la_prueba:		; cada prueba, con su formato
	ld a,(0e06ah)		;5a4e   ; la prueba
	and 003h		;5a51
	jp z,escribe_un_tiempo		;5a53   ; el ciclismo, aparte
	cp 002h		;5a56   ; el curling son puntos
	ld b,003h		;5a58
	inc hl			;5a5a
	jp z,escribe_cifras_bcd		;5a5b   ; tres bytes en BCD, sin punto
	dec de			;5a5e
	jp escribe_una_marca		;5a5f   ; y las otras dos, metros con su punto decimal
alguno_ha_quedado_fuera:		; Z si los dos siguen en la partida
	ld a,(0e072h)		;5a62   ; el jugador 1
	ld hl,0e082h		;5a65   ; y el 2
	or (hl)			;5a68
	ret			;5a69
rotulo_de_game_over:		; el rotulo y el numero del jugador
	push af			;5a6a
	push hl			;5a6b
	ld de,05a7dh		;5a6c   ; PLAYER GAME OVER, sin cabecera: el destino ya viene en HL
	ld c,0ffh		;5a6f
	call L_441D		;5a71
	pop hl			;5a74
	ld de,00006h		;5a75   ; seis casillas mas alla
	add hl,de			;5a78
	pop af			;5a79
	jp 0004dh		;5a7a   ; BIOS WRTVRM - Writes data in VRAM | va el 1 o el 2 del jugador

; ----------------------------------------------------------------------
; DATOS guion_game_over: 19 B SIN cabecera: " PLAYER  GAME OVER "
;   0x5a7d..0x5a90  (19 bytes)
DATA_guion_game_over:
	defb 030h,02ch,021h,039h,025h,032h,000h,000h,027h,021h,02dh,025h,000h,02fh,036h,025h,032h,000h,0ffh	; 5a7d  0,!9%2..'!-%./6%2..

; ----------------------------------------------------------------------
; DATOS tabla_de_nombres_de_prueba: 4 punteros; el indice es (0xE06A) y 3
;   0x5a90..0x5a98  (8 bytes)
DATA_tabla_de_nombres_de_prueba:
	defw 05ab3h,05a98h,05abdh,05aa6h	; 5a90  -> DATA_guion_cycling DATA_guion_triple_jump DATA_guion_curling DATA_guion_pole_vault

; ----------------------------------------------------------------------
; DATOS guion_triple_jump: 14 B: TRIPLE JUMP en 0x386B
;   0x5a98..0x5aa6  (14 bytes)
DATA_guion_triple_jump:
	defb 06bh,038h,034h,032h,029h,030h,02ch,025h,000h,02ah,035h,02dh,030h,0ffh	; 5a98  k842)0,%.*5-0.

; ----------------------------------------------------------------------
; DATOS guion_pole_vault: 13 B: POLE VAULT en 0x386B
;   0x5aa6..0x5ab3  (13 bytes)
DATA_guion_pole_vault:
	defb 06bh,038h,030h,02fh,02ch,025h,000h,036h,021h,035h,02ch,034h,0ffh	; 5aa6  k80/,%.6!5,4.

; ----------------------------------------------------------------------
; DATOS guion_cycling: 10 B: CYCLING en 0x386B
;   0x5ab3..0x5abd  (10 bytes)
DATA_guion_cycling:
	defb 06bh,038h,023h,039h,023h,02ch,029h,02eh,027h,0ffh	; 5ab3  k8#9#,).'.

; ----------------------------------------------------------------------
; DATOS guion_curling: 10 B: CURLING en 0x386B
;   0x5abd..0x5ac7  (10 bytes)
DATA_guion_curling:
	defb 06bh,038h,023h,035h,032h,02ch,029h,02eh,027h,0ffh	; 5abd  k8#52,).'.

; ----------------------------------------------------------------------
; DATOS guion_de_marcadores: 51 B, cinco destinos: HI SCORE, WORLD RECORD,
;   RECORD, SCORE y TOTAL
;   0x5ac7..0x5afa  (51 bytes)
DATA_guion_de_marcadores:
	defb 0a4h,038h,028h,029h,000h,033h,023h,02fh,032h,025h,0feh	; 5ac7  .8().3#/2%.
	defb 0c4h,038h,037h,02fh,032h,02ch,024h,000h,032h,025h,023h,02fh	; 5ad2  .87/2,$.2%#/
	defb 032h,024h,0feh,044h,039h,032h,025h,023h,02fh,032h	; 5ade  2$.D92%#/2
	defb 024h,0feh,084h,039h,033h,023h,02fh,032h,025h	; 5ae8  $..93#/2%
	defb 0feh,0c4h,039h,034h,02fh,034h,021h,02ch,0ffh	; 5af1  ..94/4!,.

; ----------------------------------------------------------------------
; DATOS guion_you_did_it: 63 B, tres destinos: YOU DID IT y CONGRATULATIONS,
;   con su linea de borrado
;   0x5afa..0x5b39  (63 bytes)
DATA_guion_you_did_it:
	defb 06bh,038h,039h,02fh,035h,000h,024h,029h,024h,000h,029h,034h,0feh,0a4h,038h,000h,000h,000h,000h	; 5afa  k89/5.$)$.)4..8....
	defb 023h,02fh,02eh,027h,032h,021h,034h,035h,02ch,021h,034h,029h,02fh,02eh,033h,000h,000h,000h,000h,000h,0feh,0c4h,038h,000h,000h,000h,000h,000h,000h	; 5b0d  #/.'2!45,!4)/.3.......8......
	defb 000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,0ffh	; 5b2a  ...............

; ----------------------------------------------------------------------
; DATOS rle_nombres_del_resumen: 214 B -> 800 casillas de la tabla de nombres
;   0x5b39..0x5c0f  (214 bytes)
DATA_rle_nombres_del_resumen:
	defb 000h,038h,021h,005h,081h,080h,01ch,081h,084h,083h,005h,005h,082h,01ch,000h,084h	; 5b39  .8!.............
	defb 084h,005h,005h,082h,01ch,000h,084h,084h,005h,005h,082h,01ch,000h,084h,084h,005h	; 5b49  ................
	defb 005h,082h,01ch,000h,084h,084h,005h,005h,082h,01ch,000h,084h,084h,005h,005h,082h	; 5b59  ................
	defb 008h,085h,001h,086h,009h,085h,001h,086h,009h,085h,084h,084h,005h,005h,082h,008h	; 5b69  ................
	defb 000h,001h,092h,009h,000h,001h,092h,009h,000h,084h,084h,005h,005h,082h,008h,085h	; 5b79  ................
	defb 001h,087h,009h,085h,001h,087h,009h,085h,084h,084h,005h,005h,082h,008h,000h,001h	; 5b89  ................
	defb 092h,009h,000h,001h,092h,009h,000h,084h,084h,005h,005h,082h,008h,085h,001h,087h	; 5b99  ................
	defb 009h,085h,001h,087h,009h,085h,084h,084h,005h,005h,082h,008h,000h,001h,092h,009h	; 5ba9  ................
	defb 000h,001h,092h,009h,000h,084h,084h,005h,005h,082h,008h,085h,001h,087h,009h,085h	; 5bb9  ................
	defb 001h,087h,009h,085h,084h,084h,005h,005h,082h,008h,000h,001h,092h,009h,000h,001h	; 5bc9  ................
	defb 092h,009h,000h,084h,084h,005h,005h,082h,008h,088h,001h,089h,009h,088h,001h,089h	; 5bd9  ................
	defb 009h,088h,082h,084h,005h,006h,08ah,084h,08bh,08bh,08bh,08ch,00bh,08ah,084h,08bh	; 5be9  ................
	defb 08bh,08bh,08ch,007h,08ah,020h,08dh,020h,08eh,020h,08fh,020h,090h,020h,00eh,020h	; 5bf9  ..... . . . . . 
	defb 00eh,020h,091h,020h,000h,000h	; 5c09

; ----------------------------------------------------------------------
; DATOS rle_patrones_del_resumen: 87 B -> 152 de VRAM en 0x2400, o sea los 19
;   patrones desde el tile 0x80
;   0x5c0f..0x5c66  (87 bytes)
DATA_rle_patrones_del_resumen:
	defb 005h,000h,003h,00fh,005h,000h,003h,0ffh,008h,00fh,005h,0ffh,00bh,0f0h,003h,000h	; 5c0f  ................
	defb 002h,0ffh,006h,000h,002h,0ffh,006h,018h,081h,0ffh,004h,018h,003h,000h,005h,0ffh	; 5c1f  ................
	defb 003h,018h,009h,0ffh,003h,000h,081h,03ch,004h,0ffh,003h,000h,081h,03ch,004h,007h	; 5c2f  .......<.....<..
	defb 085h,000h,0ffh,000h,03ch,0ffh,003h,0b6h,081h,000h,003h,06dh,081h,0ffh,007h,000h	; 5c3f  ....<......m....
	defb 003h,0ffh,003h,000h,089h,0ffh,000h,000h,0ffh,0ffh,000h,0ffh,000h,0ffh,005h,000h	; 5c4f  ................
	defb 002h,0ffh,002h,000h,008h,018h,000h	; 5c5f

; ----------------------------------------------------------------------
; DATOS rle_color_del_resumen: 58 B -> las mismas 152 posiciones en 0x0400
;   0x5c66..0x5ca0  (58 bytes)
DATA_rle_color_del_resumen:
	defb 018h,0f5h,005h,055h,00bh,0feh,004h,0f0h,004h,0e0h,004h,0f0h,081h,0e0h,007h,0f0h	; 5c66  ...U............
	defb 081h,0feh,013h,0f0h,005h,059h,083h,056h,050h,050h,005h,0f9h,083h,0f6h,050h,050h	; 5c76  .....Y.VPP....PP
	defb 004h,05eh,002h,069h,002h,050h,002h,0e0h,086h,0e7h,0efh,0e2h,0e0h,0eah,0e6h,008h	; 5c86  .^.i.P..........
	defb 0feh,006h,0ech,007h,03ch,00ah,0feh,009h,0f0h,000h	; 5c96  ....<.....

; ======================================================================
; CODIGO 0x5ca0..0x5d23  (131 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Al acabar un intento sube por la pantalla una figura de dos sprites, de la fila 0xFE a la 0x78, un pixel cada dos fotogramas. A mitad de camino, en la 0x96, es cuando la marca se suma a la puntuacion: el jugador ve subir el cartel y ve subir los puntos a la vez. En el triple salto ademas se desplaza en diagonal y va soltando un pitido cada cuatro filas.
; ----------------------------------------------------------------------
sube_el_cartel_del_resultado:		; la figura que sube al acabar el intento
	ld a,(0e003h)		;5ca0   ; un fotograma si y otro no
	rra			;5ca3
	ret nc			;5ca4
	ld hl,0e185h		;5ca5
	ld d,(hl)			;5ca8   ; la columna
	inc hl			;5ca9
	dec (hl)			;5caa   ; una fila mas arriba
	ld e,(hl)			;5cab
	ld a,e			;5cac
	cp 096h		;5cad   ; la mitad del camino
	jr z,L_5CD5		;5caf   ; ahi es donde se suman los puntos
	jr c,L_5CFD		;5cb1
L_5CB3:
	ld hl,03b10h		;5cb3   ; los sprites 4 y 5
	call setwrt_corto		;5cb6
	bit 2,e		;5cb9   ; cada cuatro filas
	jr z,L_5CC4		;5cbb
	inc d			;5cbd   ; dos columnas a la derecha: sube en diagonal
	inc d			;5cbe
	ld a,042h		;5cbf   ; y un pitido
	call suena_si_hay_partida		;5cc1
L_5CC4:
	ld hl,05d23h		;5cc4   ; los desplazamientos de las dos piezas
	ld a,e			;5cc7
	and 004h		;5cc8
	add a,a			;5cca
	exx			;5ccb
	add a,040h		;5ccc
	ld b,a			;5cce
	exx			;5ccf
	call pon_la_figura_de_dos_sprites		;5cd0   ; y la figura, a la tabla de sprites
	jr L_5D02		;5cd3
L_5CD5:
	push de			;5cd5
	call apunta_al_jugador_de_turno		;5cd6   ; el jugador de turno
	ld hl,0e066h		;5cd9   ; su puntuacion
	jr z,L_5CE1		;5cdc
	ld hl,0e063h		;5cde
L_5CE1:
	ld de,0e10dh		;5ce1
	call suma_a_la_puntuacion		;5ce4   ; mas la marca que acaba de hacer
	ld a,01ah		;5ce7   ; con su sonido
	call suena_si_hay_partida		;5ce9
	pop de			;5cec
	ld hl,03b18h		;5ced   ; los sprites 6 y 7
	call setwrt_corto		;5cf0
	ld hl,05d29h		;5cf3
	exx			;5cf6
	ld b,050h		;5cf7
	exx			;5cf9
	call pon_la_figura_de_dos_sprites		;5cfa
L_5CFD:
	call es_la_pertiga		;5cfd   ; en la pertiga la figura no va en diagonal
	jr z,L_5CB3		;5d00
L_5D02:
	ld a,e			;5d02   ; y en la fila 0x78 se acabo
	cp 078h		;5d03
	ret			;5d05
pon_la_figura_de_dos_sprites:		; cuatro bytes por sprite, por el puerto
	ld b,002h		;5d06   ; dos sprites
L_5D08:
	ld a,d			;5d08   ; la fila, menos lo que diga la tabla
	sub (hl)			;5d09
	out (c),a		;5d0a
	inc hl			;5d0c
	ld a,e			;5d0d   ; y la columna
	sub (hl)			;5d0e
	inc hl			;5d0f
	out (c),a		;5d10
	exx			;5d12
	ld a,b			;5d13   ; el patron
	inc b			;5d14   ; cuatro mas, que es el patron siguiente de 16x16
	inc b			;5d15
	inc b			;5d16
	inc b			;5d17
	exx			;5d18
	out (c),a		;5d19
	ld a,(hl)			;5d1b   ; y el color
	inc hl			;5d1c
	nop			;5d1d
	out (c),a		;5d1e
	djnz L_5D08		;5d20
	ret			;5d22

; ----------------------------------------------------------------------
; DATOS tabla_5d23: 6 B; la carga 0x5CC4
;   0x5d23..0x5d29  (6 bytes)
DATA_tabla_5d23:
	defb 000h,000h,00fh,000h,000h,006h	; 5d23

; ----------------------------------------------------------------------
; DATOS tabla_5d29: 6 B; la carga 0x5CF3
;   0x5d29..0x5d2f  (6 bytes)
DATA_tabla_5d29:
	defb 00ch,009h,001h,010h,009h,00fh	; 5d29

; ======================================================================
; CODIGO 0x5d2f..0x5f7b  (588 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL FOTOGRAMA DEL ATLETA. Primero la velocidad, luego lo que esa velocidad ha comido de pista, y con eso la pantalla entera: el suelo, los numeros grandes, el marcador y las figuras. (0xE129) es lo que queda de carrerilla -0x2BF en el TRIPLE SALTO y 0x17F en la PERTIGA, leidos de la RAM del emulador: la pertiga tiene la carrerilla mas corta- y baja hasta cero.
; ----------------------------------------------------------------------
mueve_al_atleta:		; la velocidad, el desplazamiento y todo lo que se pinta
	ld a,(0e128h)		;5d2f   ; si el intento esta congelado, no se mueve nada
	rra			;5d32
	ret c			;5d33
	call acelera_al_atleta		;5d34   ; la velocidad de este fotograma
	ld hl,0e135h		;5d37
	ld a,c			;5d3a   ; por dos y por dos, mas uno: cinco veces
	add a,a			;5d3b
	add a,a			;5d3c
	add a,c			;5d3d
	rra			;5d3e   ; y entre cuatro
	rra			;5d3f
	and 03fh		;5d40
	add a,(hl)			;5d42
	ld b,a			;5d43
	and 03ch		;5d44
	rrca			;5d46
	rrca			;5d47
	cp 00dh		;5d48   ; pasado el trece
	jr c,L_5D50		;5d4a
	ld b,004h		;5d4c   ; se vuelve al cuarto
	ld a,001h		;5d4e
L_5D50:
	ld (hl),b			;5d50
	dec hl			;5d51
	ld b,(hl)			;5d52
	ld (hl),a			;5d53
	dec hl			;5d54
	ld (hl),b			;5d55
	ld b,000h		;5d56
	ld hl,(0e129h)		;5d58   ; lo que queda de pista
	or a			;5d5b
	sbc hl,bc		;5d5c   ; menos lo que se acaba de recorrer
	jr nc,L_5D62		;5d5e   ; y de cero no se baja
	ld h,b			;5d60
	ld l,b			;5d61
L_5D62:
	ld (0e129h),hl		;5d62
	ret c			;5d65   ; si se ha acabado la pista, aqui no se sigue
	call escribe_la_velocidad		;5d66
	call es_la_pertiga		;5d69
	jp z,pinta_el_suelo		;5d6c
	ld de,082e8h		;5d6f   ; los digitos grandes de la marca
	ld hl,082a3h		;5d72
	call rectangulo_de_la_pista_baja		;5d75
	ld bc,(0e129h)		;5d78   ; lo que queda
	ld hl,0017fh		;5d7c   ; y de 0x17F sale lo recorrido
	or a			;5d7f
	sbc hl,bc		;5d80
	ld b,h			;5d82
	ld a,l			;5d83
	rr b		;5d84   ; entre ocho: de pixeles a casillas
	rra			;5d86
	rr b		;5d87
	rra			;5d89
	rr b		;5d8a
	rra			;5d8c
	push af			;5d8d
	ld hl,082ech		;5d8e   ; la cabecera del bloque de los digitos
	ld c,a			;5d91
	ld a,(hl)			;5d92
	sub c			;5d93
	ex af,af'			;5d94
	inc hl			;5d95
	ld c,(hl)			;5d96
	inc hl			;5d97
	ld b,(hl)			;5d98
	inc hl			;5d99
	ld e,(hl)			;5d9a
	inc hl			;5d9b
	ld d,(hl)			;5d9c
	inc hl			;5d9d
	ld (0e2f0h),de		;5d9e
	ld de,08387h		;5da2
	push hl			;5da5
	call apunta_al_jugador_de_turno		;5da6   ; el jugador de turno
	inc hl			;5da9
	inc hl			;5daa
	ld a,(hl)			;5dab   ; el liston por el que va, tope nueve
	cp 00ah		;5dac
	jr c,L_5DB2		;5dae
	ld a,009h		;5db0
L_5DB2:
	ld l,a			;5db2
	add a,a			;5db3   ; por dieciseis menos uno, o sea por quince
	add a,a			;5db4
	add a,a			;5db5
	add a,a			;5db6
	sub l			;5db7
	ld l,a			;5db8   ; que es lo que ocupa un digito de 5x3 casillas
	call suma_a_de		;5db9
	ld a,l			;5dbc
	pop hl			;5dbd
	call suma_a_hl		;5dbe   ; y ese es su dibujo
	pop af			;5dc1
	jr c,L_5DC5		;5dc2   ; recortado por la izquierda o no
	ex de,hl			;5dc4
L_5DC5:
	ld hl,(0e2f0h)		;5dc5
	ex af,af'			;5dc8
	call dibuja_el_rectangulo		;5dc9   ; el rectangulo, ya en la pantalla
	ld de,082ach		;5dcc   ; y el otro bloque
	ld hl,08262h		;5dcf
	call rectangulo_de_la_pista_baja		;5dd2
pinta_el_suelo:		; las filas de la pista, con el desplazamiento
	ld a,(0e129h)		;5dd5   ; por donde va la pista
	ld b,002h		;5dd8   ; dos tramos
L_5DDA:
	push bc			;5dda
	push af			;5ddb
	exx			;5ddc
	ld b,051h		;5ddd   ; el tile del suelo
	bit 2,a		;5ddf   ; cada cuatro casillas cambia
	jr z,L_5DE5		;5de1
	ld b,046h		;5de3
L_5DE5:
	exx			;5de5
	ld h,a			;5de6
	call es_la_pertiga		;5de7   ; el bit 1 de la prueba
	ld l,058h		;5dea   ; la fila y el alto en el triple salto
	ld c,003h		;5dec
	jr z,L_5DF4		;5dee
	ld l,030h		;5df0   ; y en la pertiga
	ld c,002h		;5df2
L_5DF4:
	call casilla_de_la_posicion		;5df4
L_5DF7:
	push hl			;5df7
	ld b,003h		;5df8   ; tres casillas por fila
	call casillas_con_patrones_seguidos		;5dfa
	call es_la_pertiga		;5dfd
	ld a,043h		;5e00   ; el tile del borde
	jr z,L_5E05		;5e02
	dec a			;5e04
L_5E05:
	sub c			;5e05
	exx			;5e06
	out (c),a		;5e07
	exx			;5e09
	pop hl			;5e0a
	ld de,00020h		;5e0b   ; la fila de debajo
	add hl,de			;5e0e
	dec c			;5e0f
	jr nz,L_5DF7		;5e10
	pop af			;5e12
	add a,080h		;5e13   ; el tramo siguiente, media pantalla mas alla
	pop bc			;5e15
	djnz L_5DDA		;5e16
	ld a,(0e129h)		;5e18   ; otra vez por donde va la pista
	ld c,004h		;5e1b   ; cuatro tramos
L_5E1D:
	push af			;5e1d
	exx			;5e1e
	ld b,04fh		;5e1f   ; el tile
	bit 2,a		;5e21
	jr z,L_5E27		;5e23
	ld b,044h		;5e25
L_5E27:
	exx			;5e27
	ld h,a			;5e28   ; la fila
	call es_la_pertiga		;5e29
	ld l,050h		;5e2c
	jr z,L_5E32		;5e2e
	ld l,028h		;5e30
L_5E32:
	call casilla_de_la_posicion		;5e32
	ld b,002h		;5e35   ; dos casillas
	call casillas_con_patrones_seguidos		;5e37
	exx			;5e3a
	ld d,044h		;5e3b   ; y el remate
	out (c),d		;5e3d
	exx			;5e3f
	pop af			;5e40
	add a,040h		;5e41   ; el tramo siguiente
	dec c			;5e43
	jr nz,L_5E1D		;5e44
	ld a,(0e129h)		;5e46   ; y otra vez
	add a,0a0h		;5e49   ; corrido 0xA0
	exx			;5e4b
	ld b,072h		;5e4c   ; el tile
	bit 2,a		;5e4e
	jr z,L_5E54		;5e50
	ld b,05ah		;5e52
L_5E54:
	exx			;5e54
	ld h,a			;5e55
	call es_la_pertiga		;5e56
	ld l,078h		;5e59   ; la fila
	ld a,000h		;5e5b
	jr z,L_5E63		;5e5d
	ld l,068h		;5e5f
	ld a,00ch		;5e61
L_5E63:
	exx			;5e63
	add a,b			;5e64
	ld b,a			;5e65
	exx			;5e66
	call casilla_de_la_posicion		;5e67
	ld b,00ch		;5e6a   ; doce casillas de un tiron
	call casillas_con_patrones_seguidos		;5e6c
	ld a,00eh		;5e6f   ; y el remate
	exx			;5e71
	out (c),a		;5e72
	exx			;5e74
	ld a,(0e129h)		;5e75   ; por donde va la pista
	ld de,0e338h		;5e78   ; los patrones que se copian a la VRAM
	bit 2,a		;5e7b   ; y cual de los dos, segun el bit 2 del desplazamiento
	jr z,L_5E81		;5e7d
	ld e,020h		;5e7f
L_5E81:
	call es_la_pertiga		;5e81
	ld hl,02a00h		;5e84   ; su destino en el triple salto
	jr z,L_5E8C		;5e87
	ld hl,02200h		;5e89   ; y en la pertiga
L_5E8C:
	ld bc,00018h		;5e8c   ; veinticuatro bytes, o sea tres tiles
	call ldirvm		;5e8f
	ld a,(0e129h)		;5e92   ; otra vez
	ld de,0e360h		;5e95
	bit 2,a		;5e98
	jr z,L_5E9E		;5e9a
	ld e,050h		;5e9c
L_5E9E:
	ld hl,03218h		;5e9e   ; otros dos tiles
	ld bc,00010h		;5ea1
	call ldirvm		;5ea4
	call es_la_pertiga		;5ea7   ; lo que queda es solo del triple salto
	ret nz			;5eaa
	ld de,08448h		;5eab   ; uno de los rectangulos con recorte
	ld hl,0843dh		;5eae
	call rectangulo_de_la_pista_alta		;5eb1
	ld de,084a1h		;5eb4   ; y otro
	ld hl,0844eh		;5eb7
	call rectangulo_de_la_pista_alta		;5eba
	ld a,(0e12ah)		;5ebd   ; el bit 7 de 0xE12A
	rla			;5ec0
	jr nc,L_5ECE		;5ec1
	ld hl,03aa0h		;5ec3   ; borra seis casillas
	ld bc,00006h		;5ec6
	ld a,0c7h		;5ec9
	call 00056h		;5ecb   ; BIOS FILVRM - Fills VRAM with value
L_5ECE:
	ld de,08437h		;5ece   ; y el ultimo rectangulo
	ld hl,0842ch		;5ed1
	jp rectangulo_de_la_pista_alta		;5ed4

; ----------------------------------------------------------------------
; Pinta B casillas seguidas con el indice de tile subiendo de uno en uno, y cuando la fila se acaba -los cinco bits de abajo de la direccion a cero- vuelve al principio de la misma fila y coloca otra vez el VDP. Asi es como se dibuja una franja de suelo sin tener que llevar la cuenta por fuera.
; ----------------------------------------------------------------------
casillas_con_patrones_seguidos:		; B casillas, con el tile subiendo
	call setwrt_y_guarda_el_puerto		;5ed7
L_5EDA:
	exx			;5eda
	out (c),b		;5edb   ; el tile
	inc b			;5edd   ; y el siguiente va pegado
	exx			;5ede
	inc hl			;5edf
	ld a,l			;5ee0
	and 01fh		;5ee1   ; el final de la fila
	jr nz,L_5EED		;5ee3
	ld de,00020h		;5ee5   ; se vuelve al principio de la fila
	sbc hl,de		;5ee8
	call setwrt_y_guarda_el_puerto		;5eea   ; y hay que colocar el VDP otra vez
L_5EED:
	djnz L_5EDA		;5eed
	ret			;5eef
setwrt_corto:		; SETWRT dejando el puerto de datos en C
	call 00053h		;5ef0   ; BIOS SETWRT - Enables VDP to write
	ld a,(00006h)		;5ef3   ; la BIOS guarda ahi el puerto de datos del VDP
	ld c,a			;5ef6
	ret			;5ef7
rectangulo_de_la_pista_baja:		; el rectangulo, corrido por lo recorrido
	push hl			;5ef8
	ld hl,0017fh		;5ef9   ; la pista del triple salto
rectangulo_corrido:		; lo recorrido decide si el dibujo va recortado
	ld bc,(0e129h)		;5efc   ; lo que queda
	or a			;5f00
	sbc hl,bc		;5f01   ; y de ahi lo recorrido
	ld b,h			;5f03
	ld c,l			;5f04
	pop hl			;5f05
	jp rectangulo_con_recorte		;5f06   ; el rectangulo con recorte
rectangulo_de_la_pista_alta:		; la de la pertiga, que es mas larga
	push hl			;5f09
	ld hl,002bfh		;5f0a   ; la pista de la pertiga
	jr rectangulo_corrido		;5f0d

; ----------------------------------------------------------------------
; Las cuatro pruebas se reparten por los dos bits de abajo de (0xE06A), y el triple salto (1) y la pertiga (3) se distinguen solo por el bit 1. Esta rutina de tres instrucciones es la que se llama en TODO el motor compartido para saber en cual de las dos se esta.
; ----------------------------------------------------------------------
es_la_pertiga:		; Z en el triple salto, NZ en la pertiga
	ld a,(0e06ah)		;5f0f   ; la prueba en curso
	bit 1,a		;5f12   ; y el bit 1 las separa
	ret			;5f14

; ----------------------------------------------------------------------
; LA CARRERILLA. Cada toque de la tecla suma 0x1000 a la velocidad, que es de 16 bits, y cada fotograma le resta el rozamiento, que sale de la curva de 0x5F7B indexada por el nibble alto de la propia velocidad: cuanto mas rapido va el atleta, mas frena. De ahi que el machaqueo tenga que ser cada vez mas seguido para seguir subiendo, y que la velocidad tenga un techo natural. El otro par de bytes lleva la zancada, que es lo que decide que figura del atleta toca.
; ----------------------------------------------------------------------
acelera_al_atleta:		; la velocidad, el rozamiento y la zancada
	ld hl,0e123h		;5f15
	ld c,(hl)			;5f18
	add a,a			;5f19
	add a,a			;5f1a
	ret c			;5f1b   ; con ese bit puesto, ni se acelera ni se frena
	ld de,(0e120h)		;5f1c   ; la velocidad de ahora
	ld a,d			;5f20   ; su nibble de mas peso
	rra			;5f21
	rra			;5f22
	rra			;5f23
	rra			;5f24
	and 00fh		;5f25
	ld hl,05f7bh		;5f27   ; la curva del rozamiento
	call suma_a_hl		;5f2a
	ld l,(hl)			;5f2d
	ld h,000h		;5f2e
	add hl,hl			;5f30   ; por cuatro
	add hl,hl			;5f31
	ex de,hl			;5f32
	sbc hl,de		;5f33   ; y eso es lo que la velocidad pierde en este fotograma
	jr nc,L_5F39		;5f35   ; de cero no se baja
	ld h,000h		;5f37
L_5F39:
	call lo_recien_pulsado_por_el_de_turno		;5f39   ; lo recien pulsado por el jugador de turno
	ld de,00000h		;5f3c
	and 008h		;5f3f   ; el bit 3
	jr z,L_5F45		;5f41
	ld d,010h		;5f43   ; y cada toque son 0x1000 de velocidad
L_5F45:
	add hl,de			;5f45
	jr nc,L_5F4A		;5f46   ; con tope
	ld h,0ffh		;5f48
L_5F4A:
	ld (0e120h),hl		;5f4a   ; la velocidad, apuntada
	ld hl,0e121h		;5f4d   ; la zancada
	ld a,(hl)			;5f50
	push af			;5f51
	inc hl			;5f52
	ld e,a			;5f53
	ld d,000h		;5f54
	ld a,(hl)			;5f56
	call suma_a_de		;5f57   ; que avanza con la velocidad
	and 07fh		;5f5a   ; y da la vuelta a la media vuelta
	ld (hl),a			;5f5c
	ex de,hl			;5f5d
	add hl,hl			;5f5e   ; por dos
	ld c,h			;5f5f
	pop af			;5f60
	rra			;5f61   ; y el nibble de arriba de la zancada
	rra			;5f62
	rra			;5f63
	rra			;5f64
	and 00fh		;5f65
	inc a			;5f67   ; mas dos
	inc a			;5f68
	ex de,hl			;5f69
	inc hl			;5f6a
	ld (hl),c			;5f6b   ; los dos, apuntados: de ahi sale la figura que toca
	inc hl			;5f6c
	ld (hl),a			;5f6d
	ret			;5f6e
lo_recien_pulsado_por_el_de_turno:		; los flancos del jugador que juega
	ld a,(0e002h)		;5f6f   ; el bit 7 dice de quien es el turno
	add a,a			;5f72
	ld a,(0e008h)		;5f73   ; los del jugador 1
	ret nc			;5f76
	ld a,(0e006h)		;5f77   ; y los del 2
	ret			;5f7a

; ----------------------------------------------------------------------
; DATOS curva_5f7b: 16 B, creciente y con la pendiente cada vez mayor (02 14
;   20 28 32 3A 44 4C 50 54 60 78 8C A4 BA D0); la indexa 0x5F27 con el NIBBLE
;   ALTO del byte alto de (0xE120), y el valor sale multiplicado por cuatro
;   0x5f7b..0x5f8b  (16 bytes)
DATA_curva_5f7b:
	defb 002h,014h,020h,028h,032h,03ah,044h,04ch,050h,054h,060h,078h,08ch,0a4h,0bah,0d0h	; 5f7b  .. (2:DLPT`x....

; ======================================================================
; CODIGO 0x5f8b..0x600f  (132 bytes)
; ======================================================================


escribe_la_velocidad:		; el numero de SPEED, en la pantalla
	ld a,(0e121h)		;5f8b   ; la zancada
	ld l,a			;5f8e
	ld h,000h		;5f8f
	add hl,hl			;5f91   ; por dos
	ld b,h			;5f92
	ld c,l			;5f93
	add hl,hl			;5f94   ; y por seis en total
	add hl,bc			;5f95
	call a_decimal		;5f96   ; a decimal, que es como se puede escribir
	ld hl,03af6h		;5f99
	ld a,d			;5f9c   ; la parte de arriba
	push de			;5f9d
	call escribe_dos_cifras		;5f9e
	pop de			;5fa1
	inc hl			;5fa2
	inc hl			;5fa3
	ld a,e			;5fa4   ; y la de abajo
	call escribe_dos_cifras		;5fa5
	ld a,(0e121h)		;5fa8
	ld hl,03ae7h		;5fab   ; y el resto del indicador
	jp L_99CE		;5fae
escribe_dos_cifras:		; un byte BCD en la pantalla
	ld (0e173h),a		;5fb1   ; el byte, a un sitio donde se le pueda apuntar
	ld de,0e173h		;5fb4
	ld b,001h		;5fb7
	jp escribe_cifras_bcd		;5fb9

; ----------------------------------------------------------------------
; Convierte una posicion en pixeles -H la fila, L la columna- en la direccion de su casilla dentro de la tabla de nombres. Son ocho rotaciones repartidas entre A y H, o sea dividir las dos coordenadas entre ocho a la vez, y el 0x38 del final es la base de la tabla.
; ----------------------------------------------------------------------
casilla_de_la_posicion:		; de coordenadas de pixel a direccion de casilla
	ld a,l			;5fbc
	rra			;5fbd   ; cuatro rotaciones de la columna
	rra			;5fbe
	rra			;5fbf
	rra			;5fc0
	rr h		;5fc1   ; y de ahi en adelante van entrando los bits de la fila
	rra			;5fc3
	rr h		;5fc4
	rra			;5fc6
	rr h		;5fc7
	ld l,h			;5fc9
	and 003h		;5fca   ; la fila, de 0 a 3
	add a,038h		;5fcc   ; y la tabla de nombres empieza en 0x3800
	ld h,a			;5fce
	ret			;5fcf
prepara_al_atleta:		; la figura, el crono y la velocidad de arranque
	ld hl,06de6h		;5fd0   ; los cuatro bytes de arranque
	ld de,0e131h		;5fd3
	ld bc,00004h		;5fd6
	ldir		;5fd9
	call L_646A		;5fdb
	ld hl,002ffh		;5fde   ; el crono de la carrerilla
	ld (0e13bh),hl		;5fe1
	ld hl,01400h		;5fe4   ; y la velocidad de arranque
	ld (0e125h),hl		;5fe7
	ld a,h			;5fea
	ld (0e17ch),a		;5feb
	ret			;5fee

; ----------------------------------------------------------------------
; Los ocho estados del atleta en el triple salto: la carrerilla, los tres saltos, el nulo, el calculo de la marca, el remate y el aterrizaje. Mientras no se llega al sexto, la velocidad se escribe en la pantalla en cada fotograma, que es el numero de SPEED que el jugador mira mientras machaca.
; ----------------------------------------------------------------------
despacha_el_estado_del_atleta:		; ocho estados, y la velocidad a la vista
	ld a,(0e130h)		;5fef   ; el estado del atleta
	cp 006h		;5ff2   ; del sexto en adelante ya no se ensena la velocidad
	jr nc,L_6009		;5ff4
	ld a,(0e126h)		;5ff6   ; la velocidad
	call parte_y_devuelve		;5ff9   ; partida
	ld hl,03a42h		;5ffc   ; a la pantalla
	call escribe_dos_cifras		;5fff
	inc hl			;6002
	inc hl			;6003
	ld a,020h		;6004   ; con un espacio detras, por si antes habia tres cifras
	call 0004dh		;6006   ; BIOS WRTVRM - Writes data in VRAM
L_6009:
	ld a,(0e130h)		;6009   ; el estado
	call despacha_por_indice		;600c   ; y su rutina, de la tabla de detras

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_600f: 8 entradas; detras sigue la primera, 0x601F
;   0x600f..0x601f  (16 bytes)
DATA_tabla_de_subescenas_600f:
	defw 0601fh,06093h,060a5h,060bch,06119h,06155h,061e0h,06286h	; 600f

; ======================================================================
; CODIGO 0x601f..0x648d  (1134 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LA TABLA DE BATIDA es un tramo concreto de la pista: de 0x12F a 0x1FF de lo que queda. Antes de llegar, el disparo no hace nada; pasada, el intento es nulo. Ahi dentro, el disparo bate y el salto empieza.
; ----------------------------------------------------------------------
estado_de_la_carrerilla:		; corre, y el disparo bate
	ld hl,(0e129h)		;601f   ; lo que queda de pista
	ld bc,0012fh		;6022   ; pasada la tabla
	or a			;6025
	sbc hl,bc		;6026
	jr nc,L_602F		;6028
	call intento_nulo		;602a   ; nulo
	jr L_6040		;602d
L_602F:
	ld hl,(0e129h)		;602f
	ld bc,001ffh		;6032   ; y antes de llegar a ella
	sbc hl,bc		;6035
	jr nc,L_6040		;6037
	call lo_recien_pulsado_por_el_de_turno		;6039   ; lo recien pulsado por el jugador de turno
	bit 4,a		;603c   ; el disparo
	jr nz,L_604E		;603e
L_6040:
	call prepara_el_dibujo_del_atleta		;6040   ; el atleta corriendo
	push af			;6043
	call figura_de_la_tabla_6b00		;6044
	pop af			;6047
	ld hl,0e0cch		;6048
	jp monta_cuatro_piezas_mas		;604b
L_604E:
	ld hl,0e130h		;604e   ; el estado siguiente: ya esta en el aire
	inc (hl)			;6051
	ld hl,06e06h		;6052   ; los cuatro bytes de la figura que bate
	ld de,0e0e4h		;6055
	ld bc,00004h		;6058
	ldir		;605b
	ld a,001h		;605d
	ld (0e128h),a		;605f   ; la carrerilla, congelada
	ld hl,(0e129h)		;6062
	ld a,l			;6065
	ld (0e163h),a		;6066   ; por donde se ha batido, apuntado
	ld bc,00144h		;6069
	or a			;606c
	sbc hl,bc		;606d   ; contra el punto justo
	jr c,intento_nulo		;606f
	ld hl,0e124h		;6071   ; batir cerca de la raya sube el impulso
	ld a,(hl)			;6074
	add a,005h		;6075
	ld (hl),a			;6077
	ld hl,00000h		;6078
	ld (0e134h),hl		;607b
	ld a,010h		;607e
	call arranca_una_pista		;6080   ; y suena
	jr L_60BA		;6083
intento_nulo:		; el estado 4, que es el que no cuenta
	call marca_intento_nulo		;6085
	ld a,001h		;6088   ; congelado
	ld (0e128h),a		;608a
	ld a,00ch		;608d   ; y la cuenta del nulo
	ld (0e13dh),a		;608f
	ret			;6092
estado_del_segundo_salto:		; el segundo de los tres
	ld bc,00304h		;6093
	ld de,0e180h		;6096
	call fisica_del_salto_con_figura		;6099
L_609C:
	ld a,012h		;609c   ; la pista que suena en el segundo
	ld b,002h		;609e   ; y el estado 2
	call arranca_un_salto		;60a0
	jr L_60BA		;60a3
estado_del_tercer_salto:		; el ultimo
	ld bc,00708h		;60a5
	ld de,0e181h		;60a8
	call fisica_del_salto_con_figura		;60ab
L_60AE:
	ld a,014h		;60ae   ; su pista
	ld b,003h		;60b0   ; y el estado 3
	call arranca_un_salto		;60b2
	dec hl			;60b5
	ld a,(hl)			;60b6
	add a,005h		;60b7   ; con cinco de impulso mas
	ld (hl),a			;60b9
L_60BA:
	jr L_6116		;60ba
estado_en_el_aire:		; mientras vuela, hasta que toca el suelo
	ld de,0e182h		;60bc
	call impulso_del_salto		;60bf   ; la fisica del salto
	cp 010h		;60c2   ; segun por donde vaya la figura
	jr nz,L_60C7		;60c4
	inc (hl)			;60c6
L_60C7:
	cp 020h		;60c7
	jr nz,L_60CC		;60c9
	inc (hl)			;60cb
L_60CC:
	ld a,(0e136h)		;60cc   ; si aun no ha empezado a caer, nada
	or a			;60cf
	jr z,L_6116		;60d0
	ld a,(0e131h)		;60d2   ; la altura
	cp 07ch		;60d5
	jr c,L_60DB		;60d7
	ld (hl),00bh		;60d9   ; y la figura que toca segun lo bajo que este
L_60DB:
	cp 082h		;60db
	jr c,L_60E1		;60dd
	ld (hl),00ch		;60df
L_60E1:
	cp 087h		;60e1
	jr c,L_60E7		;60e3
	ld (hl),00dh		;60e5
L_60E7:
	ld hl,0e131h		;60e7   ; el suelo
	ld a,08eh		;60ea
	cp (hl)			;60ec
	jr nc,L_6116		;60ed   ; y hasta llegar a el, nada
	ld (hl),a			;60ef   ; clavado en el suelo
	dec hl			;60f0
	ld (hl),005h		;60f1
	ld a,040h		;60f3
	ld (0e13dh),a		;60f5   ; la cuenta del aterrizaje
	call que_hay_bajo_el_atleta		;60f8   ; lo que hay debajo del atleta
	ld a,043h		;60fb
	jr z,L_6113		;60fd
	ld de,0e0e0h		;60ff   ; fuera de la arena, otra figura
	ld hl,06e0ah		;6102
	ld bc,00004h		;6105
	ldir		;6108
	ld a,(0e132h)		;610a   ; y su patron
	dec a			;610d
	ld (0e0e1h),a		;610e
	ld a,058h		;6111
L_6113:
	call arranca_una_pista		;6113   ; con su sonido
L_6116:
	jp dibuja_al_atleta		;6116
estado_del_nulo:		; la espera, o el salto siguiente
	ld hl,0e13dh		;6119
	inc (hl)			;611c   ; la cuenta
	ld a,(hl)			;611d
	bit 6,a		;611e   ; con el bit 6 puesto, se acabo
	jp nz,remata_sin_marca		;6120
	ld b,a			;6123
	and 00fh		;6124
	cp 00ch		;6126   ; pasada la doceava
	jr nc,L_6138		;6128
	call lo_recien_pulsado_por_el_de_turno		;612a   ; lo recien pulsado
	bit 4,a		;612d   ; y sin disparo, a esperar
	ret z			;612f
	bit 7,b		;6130   ; el tercer salto
	jp nz,L_60AE		;6132
	jp L_609C		;6135   ; o el segundo
L_6138:
	ld a,007h		;6138   ; el estado 7
	ld (0e130h),a		;613a
limpia_el_salto:		; los contadores del salto, a cero
	xor a			;613d
	ld bc,0280bh		;613e
	ld (0e134h),a		;6141
pon_los_contadores_del_salto:		; los tres bytes de la fisica
	ld (0e136h),a		;6144   ; el estado de la caida
	ld hl,0e126h		;6147
	ld (hl),b			;614a   ; el angulo
	dec hl			;614b
	ld (hl),a			;614c   ; la velocidad
	dec hl			;614d
	ld (hl),c			;614e   ; y la aceleracion
	ld a,005h		;614f   ; la cuenta de la figura
	ld (0e152h),a		;6151
	ret			;6154

; ----------------------------------------------------------------------
; De donde ha caido el atleta salen los metros: se le resta el punto de batida, se pasa por la division de 0x73BF y se le suman los doce metros de la tabla, todo en BCD. Si el salto no llega a nada, la marca se apunta como 0xFF, que es lo que mas abajo se lee como que no hubo.
; ----------------------------------------------------------------------
calcula_la_marca:		; de la posicion del atleta a los metros
	ld hl,0e13dh		;6155
	dec (hl)			;6158   ; la cuenta
	ld a,(hl)			;6159
	or a			;615a
	ret nz			;615b
	call pasa_al_remate		;615c   ; el remate
	ld hl,0e161h		;615f
	ld a,(hl)			;6162   ; donde ha caido
	sub 002h		;6163
	inc hl			;6165
	sub 043h		;6166   ; menos el punto de batida
	ld (hl),a			;6168
	inc hl			;6169
	ld a,(hl)			;616a
	ld c,a			;616b
	dec hl			;616c
	sub 064h		;616d
	ld b,a			;616f
	ld a,(hl)			;6170
	sub b			;6171   ; y esa es la distancia
	ld (hl),a			;6172
	push af			;6173
	jr nc,L_617D		;6174
	ld a,c			;6176
	cp 065h		;6177
	jr c,L_617D		;6179
	ld (hl),000h		;617b
L_617D:
	pop af			;617d
	or a			;617e   ; sin distancia, no hay marca
	jr z,L_61CF		;617f
	cp 0f0h		;6181   ; ni pasando de 0xF0
	jr nc,L_61CF		;6183
	ld bc,00018h		;6185
	ld e,a			;6188
	ld d,b			;6189
	call divide_16		;618a   ; la distancia, dividida entre 0x18
	ld a,012h		;618d   ; doce metros de salida
	add a,e			;618f
	daa			;6190
	ld (0e165h),a		;6191   ; los metros
	ld h,l			;6194
	ld e,009h		;6195   ; y los centimetros
	call multiplica_8x8		;6197
	ld a,l			;619a
	rra			;619b
	call parte_y_devuelve		;619c
	jr z,L_61A3		;619f
	ld a,099h		;61a1
L_61A3:
	ld (0e164h),a		;61a3   ; apuntados
	call marcas_del_intento_del_de_turno		;61a6   ; la marca del jugador
	ld hl,0e164h		;61a9
	ldi		;61ac
	ldi		;61ae
	call que_hay_bajo_el_atleta		;61b0   ; lo que hay bajo el atleta
	jr z,L_61CF		;61b3
	ld de,(0e164h)		;61b5
	ld c,000h		;61b9
	ld a,d			;61bb
	inc a			;61bc
	jr z,L_61CC		;61bd
	call resta_de_24_bits		;61bf   ; contra la marca a batir
	jr c,L_61CC		;61c2   ; y si no llega, nada
	xor a			;61c4
	ld (0e13dh),a		;61c5
	inc a			;61c8
	ld (0e166h),a		;61c9   ; calificado
L_61CC:
	jp pinta_las_tres_marcas		;61cc
L_61CF:
	call marcas_del_intento_del_de_turno		;61cf   ; sin marca
	inc de			;61d2
	ld a,0ffh		;61d3   ; se apunta el 0xFF de que no hubo
	ld (de),a			;61d5
	ld (0e165h),a		;61d6
	ld a,043h		;61d9   ; y suena el fallo
	call suena_si_hay_partida		;61db
	jr L_61CC		;61de
estado_del_remate:		; lo que pasa despues de la marca
	ld a,(0e166h)		;61e0
	or a			;61e3   ; con marca o sin ella
	ld hl,0e13dh		;61e4
	jr nz,L_6218		;61e7
	ld de,0e17dh		;61e9
	ld a,(de)			;61ec
	or a			;61ed
	jr nz,L_61FB		;61ee
	ld a,(0e020h)		;61f0   ; mientras suene algo, no
	or a			;61f3
	ret nz			;61f4
	ld a,0a3h		;61f5   ; la musica del fallo
	ld (de),a			;61f7
	call suena_si_hay_partida		;61f8
L_61FB:
	xor a			;61fb
	bit 3,(hl)		;61fc   ; el bit 3 de la cuenta: la figura alterna
	jr nz,L_6201		;61fe
	inc a			;6200
L_6201:
	ld (0e134h),a		;6201
	push hl			;6204
	ld hl,06d5ch		;6205   ; las figuras del atleta
	call dibuja_la_figura		;6208
	pop hl			;620b
	dec (hl)			;620c   ; la cuenta
	ld a,(hl)			;620d
	or a			;620e
	ret nz			;620f
L_6210:
	ld (0e069h),a		;6210   ; a esperar ya no
gasta_un_intento:		; un intento menos al jugador de turno
	call apunta_al_jugador_de_turno		;6213
	dec (hl)			;6216
	ret			;6217
L_6218:
	ld a,(hl)			;6218   ; la cuenta
	or a			;6219
	jr nz,L_6234		;621a
	ld a,(0e020h)		;621c   ; mientras suene algo, no
	or a			;621f
	ret nz			;6220
	inc a			;6221
	ld (0e003h),a		;6222
	ld a,06fh		;6225   ; la musica de la marca buena
	call suena_si_hay_partida		;6227
	ld (0e13dh),a		;622a
L_622D:
	xor a			;622d   ; los contadores del salto
	ld bc,04611h		;622e
	jp pon_los_contadores_del_salto		;6231
L_6234:
	call dibujo_del_publico		;6234   ; el atleta celebrandolo
	call anima_al_atleta_parado		;6237
	ld a,(0e002h)		;623a   ; el bit 6: si hay partida
	bit 6,a		;623d
	jr z,L_627D		;623f
	ld a,(0e020h)		;6241   ; mientras suene algo, no
	or a			;6244
	ret nz			;6245
	ld a,02dh		;6246   ; los tres bytes de la figura del festejo
	ld b,003h		;6248
	ld hl,0e180h		;624a
L_624D:
	cp (hl)			;624d
	jr nz,L_6262		;624e
	inc hl			;6250
	djnz L_624D		;6251
	ld a,(0e165h)		;6253   ; y la marca
	inc a			;6256
	jr z,L_6262		;6257
	cp 018h		;6259   ; pasada de 0x18
	jr c,L_6262		;625b
	ld a,0ffh		;625d   ; se marca el final
	ld (0e188h),a		;625f
L_6262:
	ld hl,0e09fh		;6262   ; si el intento estaba juzgado
	ld a,(hl)			;6265
	or a			;6266
	jr z,L_6272		;6267
	dec hl			;6269
	inc (hl)			;626a   ; un intento mas gastado
	ld a,0b2h		;626b   ; y su sonido
	call suena_si_hay_partida		;626d
L_6270:
	jr gasta_un_intento		;6270
L_6272:
	ld a,(0e188h)		;6272   ; el final
	or a			;6275
	jr z,L_6210		;6276
	call L_5706		;6278   ; la subescena del cambio
	jr L_6270		;627b
L_627D:
	ld hl,0e13dh		;627d   ; la cuenta
	dec (hl)			;6280
	ld a,(hl)			;6281
	or a			;6282
	ret nz			;6283
	jr L_6272		;6284
estado_del_aterrizaje:		; hasta que el atleta se para
	ld a,(0e12ch)		;6286
	cp 002h		;6289   ; pasadas las dos
	jr nc,remata_sin_marca		;628b
	call fisica_del_atleta		;628d   ; la fisica
	ld a,(0e136h)		;6290   ; si aun no cae, nada
	or a			;6293
	jp z,dibuja_al_atleta		;6294
	ld hl,0e131h		;6297
	ld a,08ah		;629a   ; el suelo
	cp (hl)			;629c
	jp nc,dibuja_al_atleta		;629d
	ld (hl),a			;62a0   ; clavado en el
	ld hl,0e12ch		;62a1
	inc (hl)			;62a4   ; un rebote mas
	ld a,043h		;62a5   ; y su sonido
	call arranca_una_pista		;62a7
	jp limpia_el_salto		;62aa
remata_sin_marca:		; al remate directamente
	call pasa_al_remate		;62ad
	jp L_61CF		;62b0
anima_al_atleta_parado:		; la figura mientras no salta
	ld a,(0e12ch)		;62b3
	cp 002h		;62b6   ; pasadas las dos
	ld d,005h		;62b8
	jr nc,L_62BF		;62ba
anima_al_atleta:		; la figura que toque
	call figura_segun_la_altura		;62bc
L_62BF:
	ld a,d			;62bf
	ld (0e134h),a		;62c0   ; el estado de la figura
	ld hl,06d5ch		;62c3   ; y sus datos
	jp dibuja_la_figura		;62c6
figura_segun_la_altura:		; la que toca segun lo bajo que vaya
	call fisica_del_atleta		;62c9
	ld hl,0e131h		;62cc
	ld a,(hl)			;62cf   ; la altura
	ld d,004h		;62d0
	cp 07ch		;62d2   ; alto
	jr c,L_62D8		;62d4
	ld d,003h		;62d6
L_62D8:
	cp 087h		;62d8   ; y mas bajo
	jr c,L_62DE		;62da
	ld d,002h		;62dc
L_62DE:
	ld a,(0e136h)		;62de   ; si aun no cae, ya esta
	or a			;62e1
	ret z			;62e2
	ld a,08ah		;62e3   ; el suelo
	cp (hl)			;62e5
	ret nc			;62e6   ; y hasta llegar a el, nada
	ld (hl),a			;62e7
	ld hl,0e12ch		;62e8
	inc (hl)			;62eb   ; un rebote mas
	jp L_622D		;62ec
fisica_del_salto_con_figura:		; la fisica, y la figura que le toca
	push bc			;62ef
	call impulso_del_salto		;62f0   ; la fisica del salto
	pop bc			;62f3
	cp 00ch		;62f4   ; segun por donde vaya
	jr nz,L_62F9		;62f6
	inc (hl)			;62f8
L_62F9:
	cp 014h		;62f9
	jr nz,L_62FE		;62fb
	inc (hl)			;62fd
L_62FE:
	ld a,(0e136h)		;62fe   ; si aun no cae, nada
	or a			;6301
	jr z,L_633F		;6302
	ld a,(0e131h)		;6304   ; la altura
	cp 07ch		;6307
	jr c,L_630C		;6309
	ld (hl),b			;630b   ; la figura de mas alto
L_630C:
	cp 084h		;630c
	jr c,L_6311		;630e
	ld (hl),c			;6310   ; y la de mas bajo
L_6311:
	ld hl,0e131h		;6311   ; el suelo
	ld a,07ch		;6314
	cp (hl)			;6316
	jr nc,L_633F		;6317   ; y hasta el, nada
	call lo_recien_pulsado_por_el_de_turno		;6319   ; lo recien pulsado
	bit 4,a		;631c   ; el disparo, apuntado para el salto siguiente
	jr z,L_6325		;631e
	ld a,001h		;6320
	ld (0e160h),a		;6322
L_6325:
	ld a,08ah		;6325   ; clavado en el suelo
	cp (hl)			;6327
	jr nc,L_633F		;6328
	ld (hl),a			;632a
	ld a,(0e160h)		;632b   ; con el disparo pulsado, el salto siguiente
	or a			;632e
	ret nz			;632f
	call marca_intento_nulo		;6330   ; y sin el, nulo
	ld a,(0e134h)		;6333
	cp 004h		;6336   ; salvo en un estado
	jr z,L_633F		;6338
	ld hl,0e13dh		;633a
	set 7,(hl)		;633d   ; marcado
L_633F:
	pop hl			;633f
dibuja_al_atleta:		; la figura, de la tabla de 0x6BD9
	ld hl,06bd9h		;6340
	jp dibuja_la_figura		;6343
impulso_del_salto:		; el disparo mantiene la subida hasta el tope
	ld hl,0e127h		;6346
	ld a,(hl)			;6349   ; si ya se solto, no se sube mas
	or a			;634a
	jr nz,L_636F		;634b
	ld a,(0e002h)		;634d
	add a,a			;6350   ; el bit 7 dice de quien es el turno
	ld a,(0e009h)		;6351
	jr nc,L_6359		;6354
	ld a,(0e007h)		;6356
L_6359:
	bit 4,a		;6359   ; el disparo
	jr z,L_6379		;635b
	ld hl,(0e125h)		;635d   ; el impulso de ahora
	ld bc,00170h		;6360   ; mas 0x170 por fotograma
	add hl,bc			;6363
	ld a,050h		;6364   ; con tope
	cp h			;6366
	jr nc,L_636A		;6367
	ld h,a			;6369
L_636A:
	ld (0e125h),hl		;636a
	ld a,h			;636d
	ld (de),a			;636e   ; apuntado
L_636F:
	call fisica_del_atleta		;636f   ; la fisica
	ld hl,0e135h		;6372
	inc (hl)			;6375   ; y un fotograma mas de figura
	ld a,(hl)			;6376
	dec hl			;6377
	ret			;6378
L_6379:
	ld (hl),001h		;6379   ; soltado el disparo, ya no se sube mas
	jr L_636F		;637b
arranca_un_salto:		; la pista, el estado y los contadores a cero
	call arranca_una_pista		;637d   ; la pista que suena
	ld a,b			;6380
	ld (0e130h),a		;6381   ; el estado
	ld de,0e0e4h		;6384
	ld hl,06e06h		;6387   ; los cuatro bytes de la figura
	ld bc,00004h		;638a
	ldir		;638d
	xor a			;638f
	ld (0e160h),a		;6390
	ld (0e152h),a		;6393
	ld (0e136h),a		;6396
	ld (0e135h),a		;6399
	ld hl,0e127h		;639c
	ld (hl),a			;639f
	dec hl			;63a0
	ld (hl),014h		;63a1   ; y el impulso de arranque
	dec hl			;63a3
	ld (hl),a			;63a4
	ret			;63a5

; ----------------------------------------------------------------------
; LA FISICA, y solo se hace un fotograma de cada cuatro. La altura cae con una aceleracion que sale de (0xE154) y el avance se descuenta de lo que queda de pista, que es lo mismo que decir que la pantalla se desplaza. En el tercer salto, un toque de la tecla arriba da un empujon mas: el bit 3 se apunta en (0xE179) y se gasta ahi.
; ----------------------------------------------------------------------
fisica_del_atleta:		; la gravedad, el avance y lo que come de pista
	call lo_recien_pulsado_por_el_de_turno		;63a6   ; lo recien pulsado por el jugador de turno
	bit 3,a		;63a9   ; el bit 3
	jr z,L_63B2		;63ab
	ld a,001h		;63ad
	ld (0e179h),a		;63af   ; apuntado
L_63B2:
	ld a,(0e003h)		;63b2
	and 003h		;63b5   ; uno de cada cuatro fotogramas
	ret nz			;63b7
	call pasos_del_atleta		;63b8   ; el atleta
	ld hl,0e131h		;63bb
	ld a,(0e136h)		;63be   ; si aun sube o si ya cae
	or a			;63c1
	ld a,(0e154h)		;63c2
	jr nz,L_63C8		;63c5
	dec a			;63c7
L_63C8:
	add a,a			;63c8   ; por dos
	add a,(hl)			;63c9   ; y a la altura
	ld (hl),a			;63ca
	ld de,0e15bh		;63cb
	ld a,(de)			;63ce
	add a,a			;63cf   ; el avance, por dos
	inc de			;63d0
	ld (de),a			;63d1
	ld a,(0e130h)		;63d2
	cp 006h		;63d5   ; en el sexto estado ya no se avanza
	ret z			;63d7
	push hl			;63d8
	cp 003h		;63d9   ; el tercer salto
	push af			;63db
	jr nz,L_63EB		;63dc
	ld a,(0e179h)		;63de   ; con el empujon apuntado
	or a			;63e1
	jr z,L_63EB		;63e2
	xor a			;63e4
	ld (0e179h),a		;63e5   ; se gasta
	ex de,hl			;63e8
	inc (hl)			;63e9   ; y el avance sube un punto
	ex de,hl			;63ea
L_63EB:
	ld a,(de)			;63eb
	ld hl,0e161h		;63ec
	add a,(hl)			;63ef   ; lo recorrido
	ld (hl),a			;63f0
	pop af			;63f1
	pop hl			;63f2
	ld a,(de)			;63f3
	ld c,a			;63f4
	jr nz,L_640A		;63f5
	ld a,(0e178h)		;63f7   ; en el tercer salto y sin haber tocado el techo
	or a			;63fa
	jr nz,L_640A		;63fb
	inc hl			;63fd
	ld a,c			;63fe
	add a,(hl)			;63ff   ; se sube
	ld (hl),a			;6400
	cp 0d0h		;6401   ; hasta 0xD0
	ret c			;6403
	ld a,001h		;6404
	ld (0e178h),a		;6406   ; y ahi se para
	ret			;6409
L_640A:
	ld hl,0e0e5h		;640a   ; la columna del atleta
	ld a,(hl)			;640d
	sub c			;640e   ; menos lo avanzado
	ld (hl),a			;640f
	jr nc,L_6415		;6410
	dec hl			;6412
	ld (hl),0c3h		;6413   ; y si se sale, el sprite se esconde
L_6415:
	ld b,000h		;6415
	ld hl,(0e129h)		;6417   ; lo que queda de pista
	or a			;641a
	sbc hl,bc		;641b   ; menos lo avanzado
	ld (0e129h),hl		;641d
	jp pinta_el_suelo		;6420   ; y a repintar el suelo

; ----------------------------------------------------------------------
; Para saber si el atleta ha caido en la arena no hay tabla ninguna: se mira la pantalla. Se coge su posicion, se le suman 32 pixeles -o sea cuatro filas de casillas-, se calcula la casilla y se LEE de la VRAM. El tile 9 es la arena, y con eso basta.
; ----------------------------------------------------------------------
que_hay_bajo_el_atleta:		; lee la casilla de debajo, en la VRAM
	ld hl,(0e131h)		;6423
	ld a,020h		;6426   ; cuatro filas mas abajo
	add a,l			;6428
	ld l,a			;6429
	call casilla_de_la_posicion		;642a   ; la casilla
	call 0004ah		;642d   ; BIOS RDVRM - Reads the content of VRAM | y lo que hay pintado en ella
	cp 009h		;6430   ; el tile 9 es la arena
	ret			;6432
marca_intento_nulo:		; el estado 4, y la cuenta a cero
	ld a,004h		;6433   ; el estado del nulo
	ld (0e130h),a		;6435
	ld hl,00000h		;6438
	ld (0e13dh),hl		;643b
	ret			;643e
parte_y_devuelve:		; la division, con el resto en los flags
	push de			;643f
	ld l,a			;6440
	call a_decimal_8		;6441   ; a decimal
	ld a,d			;6444
	or a			;6445   ; Z si el resultado cabe en un byte
	ld a,e			;6446
	pop de			;6447
	ret			;6448
pasa_al_remate:		; el estado 6 y la altura del suelo
	ld hl,0e130h		;6449
	ld (hl),006h		;644c   ; el estado del remate
	inc hl			;644e
	ld (hl),08ah		;644f   ; el atleta, en el suelo
	ld a,0c0h		;6451   ; y la cuenta
	ld (0e13dh),a		;6453
	ret			;6456
marcas_del_intento_del_de_turno:		; DE a las tres del jugador que juega
	call apunta_al_jugador_de_turno		;6457
	ld de,0e110h		;645a   ; las del jugador 1
	jr z,L_6462		;645d
	ld de,0e118h		;645f   ; y las del 2
L_6462:
	ld a,003h		;6462
	sub (hl)			;6464
	add a,a			;6465
	call suma_a_de		;6466
	ret			;6469
L_646A:
	ld hl,0e0a0h		;646a   ; los sprites, escondidos
	ld de,0e0a1h		;646d
	ld c,05fh		;6470   ; los veinticuatro
	ld (hl),0c3h		;6472
	ldir		;6474
	ld hl,06deah		;6476   ; y los 28 bytes de las piezas de arranque
	ld de,0e0c4h		;6479
	ld c,01ch		;647c
	ldir		;647e
	ret			;6480
L_6481:
	call es_la_pertiga		;6481
	jp z,despacha_el_estado_del_atleta		;6484
	ld a,(0e130h)		;6487
	call despacha_por_indice		;648a

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_648d: 7 entradas; detras sigue la primera, 0x649B
;   0x648d..0x649b  (14 bytes)
DATA_tabla_de_subescenas_648d:
	defw 0649bh,06513h,0659fh,06672h,06793h,0684eh,068c9h	; 648d

; ======================================================================
; CODIGO 0x649b..0x6b00  (1637 bytes)
; ======================================================================


estado_de_la_carrerilla_con_pertiga:		; corre con la pertiga en la mano
	ld hl,(0e129h)		;649b   ; lo que queda de pista
	ld bc,00090h		;649e   ; el punto de plantar
	or a			;64a1
	sbc hl,bc		;64a2
	jr nc,L_64AD		;64a4
	call lo_recien_pulsado_por_el_de_turno		;64a6   ; lo recien pulsado por el jugador de turno
	bit 4,a		;64a9   ; el disparo planta la pertiga
	jr nz,planta_la_pertiga		;64ab
L_64AD:
	ld hl,(0e129h)		;64ad
	ld bc,00002h		;64b0   ; y al final de la pista
	or a			;64b3
	sbc hl,bc		;64b4
	jr nc,L_64BB		;64b6
	call se_acabo_el_intento		;64b8   ; se acabo el intento
L_64BB:
	ld de,06f7ah		;64bb   ; la figura de la pertiga
	ld b,083h		;64be
	ld a,(0e134h)		;64c0   ; segun por donde vaya el atleta
	cp 003h		;64c3
	jr z,L_64CB		;64c5
	cp 009h		;64c7
	jr nz,L_64CF		;64c9
L_64CB:
	ld de,06f89h		;64cb
	dec b			;64ce
L_64CF:
	ld hl,0e0a0h		;64cf   ; el primer sprite: la punta de la pertiga
	ld (hl),b			;64d2
	inc hl			;64d3
	ld (hl),033h		;64d4
	inc hl			;64d6
	ld (hl),080h		;64d7
	inc hl			;64d9
	ld (hl),001h		;64da
	ex de,hl			;64dc
	call interprete_de_dibujo_relativo		;64dd   ; el dibujo de la pertiga
	ld de,06e15h		;64e0   ; y las piezas del atleta
monta_al_atleta_y_su_sombra:		; las piezas, y las cuatro que van detras
	push de			;64e3
	call prepara_el_dibujo_del_atleta		;64e4   ; las piezas del atleta
	pop de			;64e7
	push af			;64e8
	ld a,003h		;64e9
	call monta_piezas_desde_e0c4		;64eb   ; tres piezas mas
	pop af			;64ee
	ld hl,0e0d0h		;64ef
monta_cuatro_piezas_mas:		; donde y de que tabla
	ld (0e170h),hl		;64f2   ; donde se dejan
	add a,a			;64f5   ; dos bytes por entrada
	ld hl,06b6ah		;64f6   ; la tabla de figuras
	call suma_a_hl		;64f9
	ld e,(hl)			;64fc
	inc hl			;64fd
	ld d,(hl)			;64fe
	ld a,004h		;64ff   ; y cuatro piezas
	jp monta_las_piezas_del_atleta		;6501
planta_la_pertiga:		; congela la carrerilla y pasa al estado siguiente
	ld a,080h		;6504   ; el bit 7 congela y marca
	ld (0e128h),a		;6506
	ld hl,0e130h		;6509
	inc (hl)			;650c   ; el estado siguiente
borra_la_pertiga:		; el dibujo, quitado de la pantalla
	ld hl,06f98h		;650d
	jp interprete_de_dibujo_relativo		;6510
estado_de_la_pertiga_plantada:		; la pertiga se dobla
	ld hl,0e140h		;6513
	inc (hl)			;6516   ; un fotograma mas
	ld b,(hl)			;6517
	inc hl			;6518
	ld a,(hl)			;6519
	cp 002h		;651a   ; pasada la segunda fase
	jr nc,L_6542		;651c
	ld c,a			;651e
	ld a,b			;651f
	and 007h		;6520   ; uno de cada ocho fotogramas
	jr nz,L_6525		;6522
	inc (hl)			;6524   ; la fase siguiente
L_6525:
	ld a,c			;6525
	inc hl			;6526
	ld b,(hl)			;6527
	ld (hl),a			;6528   ; la fase de antes, apuntada
dibuja_al_atleta_con_pertiga:		; el atleta y su pertiga, juntos
	call dibuja_la_pertiga_y_el_atleta		;6529   ; los dos dibujos
	ex de,hl			;652c
	ld de,0e0a0h		;652d
	ldi		;6530   ; la fila y la columna
	ldi		;6532
	add a,a			;6534   ; por cuatro, mas 0x84: el patron que toca
	add a,a			;6535
	add a,084h		;6536
	ld (de),a			;6538
	ld a,(hl)			;6539
	ld (0e132h),a		;653a   ; apuntado
	ld de,06e24h		;653d
	jr monta_al_atleta_y_su_sombra		;6540
L_6542:
	ld c,a			;6542   ; la fase
	push hl			;6543
	ld hl,(0e129h)		;6544   ; lo que queda de pista
	ld de,0000bh		;6547   ; la ventana buena para plantar: entre 0x0B y 0x20
	sbc hl,de		;654a
	jr c,L_655A		;654c
	ld de,00015h		;654e
	sbc hl,de		;6551
	jr nc,L_655A		;6553
	ld a,001h		;6555
	ld (0e12fh),a		;6557   ; plantada donde se debe
L_655A:
	pop hl			;655a
	ld a,(0e12fh)		;655b   ; si se planto bien
	or a			;655e
	jr nz,L_6574		;655f
	ld a,b			;6561
	and 007h		;6562   ; uno de cada ocho fotogramas
	jr nz,L_6525		;6564
se_acabo_el_intento:		; el intento, por terminado
	ld a,001h		;6566
	ld (0e176h),a		;6568   ; marcado
	call termina_el_intento		;656b
	ld a,040h		;656e
	ld (0e13dh),a		;6570   ; y la cuenta
	ret			;6573
L_6574:
	ld a,(0e129h)		;6574   ; lo que queda de pista
	cp 00ah		;6577   ; pasada de 0x0A
	jr c,L_658B		;6579
	cp 019h		;657b   ; y por debajo de 0x19
	jr nc,L_6525		;657d
	ld a,(0e121h)		;657f   ; si la velocidad no llega a 0x30
	cp 030h		;6582
	push hl			;6584
	call c,se_acabo_el_intento		;6585   ; no hay salto
	pop hl			;6588
	jr L_6525		;6589
L_658B:
	ld a,00ah		;658b   ; la pista, clavada en 0x0A
	ld (0e129h),a		;658d
	inc (hl)			;6590   ; la fase siguiente
	ld hl,0e130h		;6591
	inc (hl)			;6594   ; el estado siguiente
	ld a,001h		;6595
	ld (0e128h),a		;6597   ; congelado
	ld a,001h		;659a   ; y suena
	jp arranca_una_pista		;659c
estado_de_la_subida:		; el atleta sube colgado de la pertiga
	ld a,(0e142h)		;659f
	cp 004h		;65a2   ; antes de la cuarta fase no se puede soltar
	jr c,L_65B8		;65a4
	ld a,(0e002h)		;65a6
	bit 7,a		;65a9   ; el bit 7 dice de quien es el turno
	ld a,(0e009h)		;65ab
	jr z,L_65B3		;65ae
	ld a,(0e007h)		;65b0
L_65B3:
	bit 4,a		;65b3   ; y el disparo suelta la pertiga
	jp z,L_662B		;65b5
L_65B8:
	ld hl,0e140h		;65b8
	inc (hl)			;65bb   ; un fotograma mas
	ld a,(hl)			;65bc
	and 007h		;65bd   ; uno de cada ocho
	inc hl			;65bf
	ld a,(hl)			;65c0
	jr nz,L_65C8		;65c1
	cp 00eh		;65c3   ; pasada la catorceava
	jr nc,suelta_la_pertiga		;65c5
	inc (hl)			;65c7   ; la fase siguiente
L_65C8:
	inc hl			;65c8
	ld b,(hl)			;65c9
	ld (hl),a			;65ca   ; la de antes, apuntada
	cp 004h		;65cb   ; hasta la cuarta, el dibujo es el mismo de antes
	jp c,dibuja_al_atleta_con_pertiga		;65cd
	call dibuja_la_pertiga_y_el_atleta		;65d0   ; los dos dibujos
	ex de,hl			;65d3
	ld de,0e131h		;65d4
	ldi		;65d7
	ldi		;65d9
	inc de			;65db
	ldi		;65dc
	ex de,hl			;65de
	ld hl,0e0a0h		;65df
	ld a,003h		;65e2
	call esconde_a_sprites		;65e4   ; los sprites de la pertiga, escondidos
	ex de,hl			;65e7
	ld de,0e0a0h		;65e8
L_65EB:
	ldi		;65eb   ; y las piezas, una detras de otra
	ldi		;65ed
	ldi		;65ef
	ld a,001h		;65f1   ; con su color
	ld (de),a			;65f3
	inc de			;65f4
	ld a,(hl)			;65f5
	or a			;65f6   ; hasta el cero que cierra
	jr nz,L_65EB		;65f7
dibuja_al_atleta_de_pertiga:		; la tabla de figuras de la pertiga
	ld hl,06e33h		;65f9

; ----------------------------------------------------------------------
; La puerta comun de todo lo que se dibuja del atleta: (0xE131) es la fila, (0xE132) la columna y (0xE134) cual de las figuras toca. La tabla se le pasa en HL, asi que la misma rutina sirve para el atleta corriendo, saltando, celebrandolo o cayendose. El 0x1800 es la tabla de patrones de sprite: los patrones del atleta se rehacen ENTEROS en cada fotograma.
; ----------------------------------------------------------------------
dibuja_la_figura:		; la fila, la columna y la figura que toque
	ld de,0e131h		;65fc   ; la fila y la columna
	ld a,(de)			;65ff
	ld b,a			;6600
	inc de			;6601
	ld a,(de)			;6602
	exx			;6603
	ld c,a			;6604
	exx			;6605
	inc de			;6606
	inc de			;6607
	ld a,(de)			;6608   ; la figura que toca
	add a,a			;6609   ; dos bytes por entrada
	call suma_a_hl		;660a
	ld e,(hl)			;660d
	inc hl			;660e
	ld d,(hl)			;660f
	ld hl,01800h		;6610   ; los patrones de sprite
	call 00053h		;6613   ; BIOS SETWRT - Enables VDP to write
	ld a,(00006h)		;6616
	ld c,a			;6619
	ld a,007h		;661a   ; siete piezas
	jp monta_piezas_desde_e0c4		;661c
suelta_la_pertiga:		; arriba del todo, y a volar
	ld a,0b5h		;661f   ; la pista
	call arranca_una_pista		;6621
	dec hl			;6624
	ld a,(hl)			;6625
	inc hl			;6626
	or a			;6627
	ld a,(hl)			;6628
	jr nz,L_65C8		;6629
L_662B:
	ld hl,00020h		;662b   ; la caida
	ld (0e17bh),hl		;662e
	ld hl,0e130h		;6631
	inc (hl)			;6634   ; el estado siguiente
	ld a,(0e142h)		;6635
	cp 007h		;6638   ; en las fases de la 7 a la 11
	jr c,L_6649		;663a
	cp 00ch		;663c
	jr nc,L_6649		;663e
	ld hl,0e131h		;6640
	ex af,af'			;6643
	ld a,(hl)			;6644
	sub 012h		;6645   ; el atleta arranca mas alto
	ld (hl),a			;6647
	ex af,af'			;6648
L_6649:
	sub 004h		;6649
	ld b,004h		;664b   ; cuatro de impulso
	cp 00dh		;664d   ; salvo en la treceava
	jr nz,L_6653		;664f
	ld b,006h		;6651
L_6653:
	ld hl,06f1ch		;6653   ; la tabla del impulso
	call suma_a_hl		;6656
	ld a,(hl)			;6659
	ld hl,0e126h		;665a
	ld (hl),a			;665d   ; la velocidad de la caida
	dec hl			;665e
	dec hl			;665f
	ld a,(hl)			;6660
	add a,b			;6661   ; y el avance, con tope
	cp 014h		;6662
	jr nc,L_6667		;6664
	inc a			;6666
L_6667:
	ld (hl),a			;6667
	ld hl,0e17ah		;6668
	ld (hl),003h		;666b   ; la cuenta de la figura
	ld a,0b5h		;666d   ; y suena
	jp arranca_una_pista		;666f
estado_del_vuelo:		; el atleta pasa -o no- por encima del liston
	call caida_del_atleta		;6672   ; la caida
	ld a,(0e12ch)		;6675   ; si ya ha tocado el liston
	or a			;6678
	jr z,L_6688		;6679
	call lo_recien_pulsado_por_el_de_turno		;667b   ; lo recien pulsado
	and 010h		;667e
	jr z,L_66B3		;6680
	ld hl,0e184h		;6682
	inc (hl)			;6685   ; los toques, apuntados
	jr L_66B3		;6686
L_6688:
	ld a,(0e12bh)		;6688   ; si aun no se ha juzgado
	or a			;668b
	jr nz,L_669C		;668c
	call altura_del_liston		;668e   ; la altura del liston
	sub l			;6691
	jr c,L_669C		;6692
	ld a,093h		;6694
	sub h			;6696
	cp 003h		;6697   ; y si pasa a menos de tres, lo tira
	jp c,marca_el_liston_tocado		;6699
L_669C:
	call altura_del_liston		;669c   ; otra vez la altura del liston
	add a,00ch		;669f
	sub l			;66a1
	cp 00ah		;66a2   ; la ventana de por encima
	jr nc,L_66AD		;66a4
	ld a,09ch		;66a6
	sub h			;66a8
	cp 01bh		;66a9   ; y ahi es donde el salto se da por bueno
	jr c,tira_el_liston		;66ab
L_66AD:
	ld a,(0e136h)		;66ad   ; si aun no cae, nada
	or a			;66b0
	jr z,L_6703		;66b1
L_66B3:
	ld hl,0e132h		;66b3   ; la columna
	ld a,088h		;66b6
	cp (hl)			;66b8
	dec hl			;66b9
	jr c,L_66DB		;66ba   ; mas alla de 0x88
	ld a,068h		;66bc   ; y por encima de 0x68
	cp (hl)			;66be
	jr nc,L_6703		;66bf
	ld a,006h		;66c1   ; la figura de la caida
	ld (0e134h),a		;66c3
	ld a,08ah		;66c6
	jr nc,L_66D9		;66c8
	ld (hl),a			;66ca   ; clavado
	call se_acabo_el_intento		;66cb   ; se acabo el intento
	ld hl,06f4ah		;66ce   ; y las seis piezas de la colchoneta
	ld de,0e0ach		;66d1
	ld bc,00018h		;66d4
	ldir		;66d7
L_66D9:
	jr L_6703		;66d9
L_66DB:
	ld a,068h		;66db   ; por debajo de 0x68
	cp (hl)			;66dd
	jr nc,L_6703		;66de
	ld a,007h		;66e0   ; la otra figura de caida
	ld (0e134h),a		;66e2
	ld a,082h		;66e5
	cp (hl)			;66e7
	jr nc,L_6703		;66e8
	ld (hl),a			;66ea   ; clavado
	ld hl,0e12ch		;66eb
	ld a,(hl)			;66ee
	or a			;66ef
	jr nz,L_6706		;66f0
	inc (hl)			;66f2   ; juzgado
	call contadores_de_la_pertiga		;66f3
	ld a,(0e12bh)		;66f6   ; y suena una cosa u otra segun haya tirado el liston o no
	or a			;66f9
	ld a,01ch		;66fa
	jr nz,L_6700		;66fc
	ld a,01eh		;66fe
L_6700:
	call arranca_una_pista		;6700
L_6703:
	jp dibuja_al_atleta_de_pertiga		;6703
L_6706:
	ld hl,0e130h		;6706   ; el estado siguiente
	inc (hl)			;6709
	ld a,(0e12bh)		;670a   ; con el liston tirado
	or a			;670d
	jr nz,L_6715		;670e
	call termina_el_intento		;6710   ; se acabo el intento
	jr L_6703		;6713
L_6715:
	call apunta_al_jugador_de_turno		;6715
	inc hl			;6718
	inc hl			;6719
	inc (hl)			;671a   ; y si no, un liston mas superado
	jr L_6703		;671b
tira_el_liston:		; el liston cae, y con el el intento
	ld a,004h		;671d   ; el ruido del liston
	call arranca_una_pista		;671f
	xor a			;6722
	ld (0e12bh),a		;6723   ; juzgado
	ld hl,06f28h		;6726   ; el dibujo del liston cayendo
	ld (0e143h),hl		;6729
	call altura_del_liston		;672c   ; la altura a la que estaba
	add a,00ch		;672f
	ld hl,0e0e0h		;6731   ; y ahi cae, con su sprite
	ld (hl),a			;6734
	inc hl			;6735
	ld (hl),090h		;6736
	inc hl			;6738
	ld (hl),0d0h		;6739
	inc hl			;673b
	ld (hl),006h		;673c
	ld hl,0e130h		;673e
	ld (hl),006h		;6741   ; el estado 6
	ld de,0841dh		;6743   ; y el rotulo de tres filas por cinco
	ld hl,03910h		;6746
	ld b,003h		;6749
L_674B:
	push bc			;674b
	push hl			;674c
	ld b,005h		;674d
	call setwrt_corto		;674f   ; el VDP, en la fila
L_6752:
	ld a,(de)			;6752   ; los cinco tiles
	inc de			;6753
	out (c),a		;6754
	djnz L_6752		;6756
	pop hl			;6758
	ld bc,00020h		;6759   ; y la fila de abajo
	add hl,bc			;675c
	pop bc			;675d
	djnz L_674B		;675e
	ld a,(0e142h)		;6760   ; la fase
	ld hl,07132h		;6763   ; y su dibujo
dibujo_de_la_tabla:		; la entrada A de la tabla que venga en HL
	add a,a			;6766   ; dos bytes por entrada
	call suma_a_hl		;6767   ; la entrada que toca
	ld e,(hl)			;676a   ; su dibujo
	inc hl			;676b
	ld d,(hl)			;676c
	ex de,hl			;676d

; ----------------------------------------------------------------------
; EL CUARTO INTERPRETE DE ROTULOS, y no es el de 0x4415. La cabecera es igual -el destino de VRAM en una word- pero los tiles salen por `out (c),a` en vez de por la BIOS, y su 0xFE no trae una direccion nueva: trae UN SOLO BYTE que se suma a la posicion. Salta en relativo, que sale mas barato cuando el dibujo va por filas y solo hay que bajar una. Sus quince guiones estan en 0x7150..0x732E.
; ----------------------------------------------------------------------
interprete_de_dibujo_relativo:		; el cuarto interprete, con saltos cortos
	ld e,(hl)			;676e   ; el destino, de la cabecera
	inc hl			;676f
	ld d,(hl)			;6770
	inc hl			;6771
	ex de,hl			;6772
L_6773:
	call 00053h		;6773   ; BIOS SETWRT - Enables VDP to write | el VDP, colocado
	ld a,(00006h)		;6776
	ld c,a			;6779
L_677A:
	ld a,(de)			;677a   ; el tile
	inc de			;677b
	ld b,a			;677c
	inc b			;677d   ; 0xFF termina
	ret z			;677e
	inc b			;677f   ; 0xFE trae un salto
	jr z,L_6786		;6780
	out (c),a		;6782   ; y lo demas va a la casilla
	jr L_677A		;6784
L_6786:
	ld a,(de)			;6786   ; cuanto saltar
	inc de			;6787
	call suma_a_hl		;6788   ; sumado a la posicion
	jr L_6773		;678b   ; y a colocar el VDP otra vez
marca_el_liston_tocado:		; el liston, dado por tirado
	ld hl,0e12bh		;678d
	ld (hl),001h		;6790
	ret			;6792
estado_del_remate_de_pertiga:		; lo que pasa despues del salto
	ld hl,0e17ch		;6793   ; la cuenta del festejo
	ld a,(hl)			;6796   ; la cuenta
	or a			;6797   ; si aun no ha empezado
	jr nz,L_67A2		;6798
	dec hl			;679a
	dec (hl)			;679b
	ld a,(hl)			;679c
	or a			;679d
	ret nz			;679e
	inc hl			;679f
	ld (hl),001h		;67a0
L_67A2:
	ld a,(0e13dh)		;67a2   ; y si se agoto
	or a			;67a5
	jp z,L_6831		;67a6
	call dibujo_del_publico		;67a9   ; el atleta celebrandolo
	ld a,(0e12ch)		;67ac
	cp 003h		;67af   ; pasadas las tres
	ld d,005h		;67b1
	jr nc,L_67DD		;67b3
	call caida_del_atleta		;67b5   ; la caida
	ld hl,0e131h		;67b8
	ld a,(hl)			;67bb   ; la altura
	ld d,004h		;67bc
	cp 080h		;67be   ; y la figura que le toca
	jr c,L_67C4		;67c0
	ld d,003h		;67c2
L_67C4:
	cp 08bh		;67c4
	jr c,L_67CA		;67c6
	ld d,002h		;67c8
L_67CA:
	ld a,(0e136h)		;67ca   ; si aun no cae, nada
	or a			;67cd
	jr z,L_67DD		;67ce
	ld a,08eh		;67d0   ; el suelo
	cp (hl)			;67d2
	jr nc,L_67DD		;67d3
	ld (hl),a			;67d5   ; clavado
	ld hl,0e12ch		;67d6
	inc (hl)			;67d9
	call contadores_de_la_pertiga		;67da   ; los contadores
L_67DD:
	ld a,d			;67dd
	ld (0e134h),a		;67de   ; la figura
	ld hl,0e13dh		;67e1
	ld a,(hl)			;67e4
	cp 08eh		;67e5   ; en el fotograma 0x8E
	jr nz,L_67F5		;67e7
	inc (hl)			;67e9
	ld hl,03b24h		;67ea   ; nueve sprites, escondidos
	ld bc,00024h		;67ed
	ld a,0c3h		;67f0
	call 00056h		;67f2   ; BIOS FILVRM - Fills VRAM with value
L_67F5:
	ld hl,06d5ch		;67f5   ; el atleta, dibujado
	call dibuja_la_figura		;67f8
	ld a,(0e020h)		;67fb   ; mientras suene algo, no
	or a			;67fe
	ret nz			;67ff
	ld a,(0e184h)		;6800   ; tres toques
	cp 003h		;6803
	jr nz,L_680C		;6805
	ld a,0ffh		;6807   ; y se acabo
	ld (0e188h),a		;6809
L_680C:
	ld hl,0e09fh		;680c
	ld a,(hl)			;680f   ; si el intento estaba juzgado
	or a			;6810
	jr z,L_681A		;6811
	dec hl			;6813
	inc (hl)			;6814   ; un intento gastado
	ld a,0b2h		;6815   ; y su sonido
	jp suena_si_hay_partida		;6817
L_681A:
	ld a,(0e188h)		;681a   ; el final
	or a			;681d
	jr z,L_6825		;681e
	call L_5706		;6820   ; la subescena del cambio
	jr L_6829		;6823
L_6825:
	xor a			;6825
	ld (0e069h),a		;6826   ; y a esperar ya no
L_6829:
	call apunta_al_jugador_de_turno		;6829
	ld a,(hl)			;682c   ; si al jugador no le queda nada
	or a			;682d
	ret z			;682e
	jr esconde_a_todo_el_atleta		;682f
L_6831:
	ld a,(0e020h)		;6831   ; mientras suene algo, no
	or a			;6834
	ret nz			;6835
	inc a			;6836
	ld (0e003h),a		;6837
	ld a,06fh		;683a   ; la musica del salto bueno
	call suena_si_hay_partida		;683c
	ld a,08eh		;683f
	ld (0e13dh),a		;6841   ; y el atleta, en el suelo
	ld (0e131h),a		;6844
contadores_de_la_pertiga:		; los tres bytes de la fisica de la pertiga
	xor a			;6847
	ld bc,04614h		;6848
	jp pon_los_contadores_del_salto		;684b
estado_de_la_caida:		; el atleta que se ha caido
	ld hl,0e17ch		;684e
	ld a,(hl)			;6851   ; la cuenta
	or a			;6852
	jr nz,L_6862		;6853
	dec hl			;6855
	dec (hl)			;6856   ; un fotograma menos
	ld a,(hl)			;6857
	or a			;6858
	ret nz			;6859
	inc hl			;685a
	ld (hl),001h		;685b
	ld a,08eh		;685d
	ld (0e131h),a		;685f   ; y en el suelo
L_6862:
	ld a,(0e176h)		;6862   ; si el intento ya termino
	or a			;6865
	jr nz,L_6895		;6866
	ld a,(0e139h)		;6868   ; el sprite del liston
	or a			;686b
	jr z,L_6873		;686c
	ld hl,0e0ach		;686e
	ld (hl),074h		;6871   ; escondido
L_6873:
	ld a,(0e12bh)		;6873
	inc a			;6876   ; con el liston tirado
	call z,cae_el_liston		;6877
	ld hl,0e13dh		;687a
	xor a			;687d
	bit 3,(hl)		;687e   ; el bit 3: la figura alterna
	jr nz,L_6883		;6880
	inc a			;6882
L_6883:
	ld (0e134h),a		;6883
	push hl			;6886
	ld hl,06d5ch		;6887   ; el atleta
	call dibuja_la_figura		;688a
	pop hl			;688d
	dec (hl)			;688e   ; la cuenta
	ld a,(hl)			;688f
	or a			;6890
	ret nz			;6891
	jp L_6825		;6892
L_6895:
	ld hl,0e13dh		;6895   ; la otra cuenta
	dec (hl)			;6898
	ld a,(hl)			;6899
	or a			;689a
	ret nz			;689b
	ld (0e176h),a		;689c   ; y a esperar ya no
	ld a,080h		;689f
	ld (hl),a			;68a1
cierra_el_intento_de_pertiga:		; la cuenta, el sonido y los sprites
	ld a,0c0h		;68a2   ; la cuenta
	ld (0e13dh),a		;68a4
	ld a,0a3h		;68a7   ; y su sonido
	call suena_si_hay_partida		;68a9
esconde_a_todo_el_atleta:		; los doce primeros sprites, fuera
	ld hl,0e0a0h		;68ac
	ld de,0e0a1h		;68af
	ld bc,0000bh		;68b2
	ld (hl),0c3h		;68b5   ; un 0xC3 en la Y y no se ve
	ldir		;68b7
	ld a,(0e140h)		;68b9   ; si la pertiga no llego a plantarse
	or a			;68bc
	jp z,borra_la_pertiga		;68bd   ; nada mas que borrarla
	ld a,(0e142h)		;68c0   ; y si se planto, su dibujo
	ld hl,06fa7h		;68c3
	jp dibujo_de_la_tabla		;68c6
estado_del_aterrizaje_de_pertiga:		; hasta que el atleta se para
	call caida_del_atleta		;68c9   ; la caida
	call cae_el_liston		;68cc
	ld a,(0e12ch)		;68cf   ; si aun no se ha juzgado
	or a			;68d2
	jr nz,L_68DB		;68d3
	ld a,(0e136h)		;68d5   ; y aun no cae, nada
	or a			;68d8
	jr z,L_6909		;68d9
L_68DB:
	ld hl,0e131h		;68db
	ld a,06ch		;68de   ; por debajo de 0x6C
	cp (hl)			;68e0
	jr nc,L_6909		;68e1
	ld a,007h		;68e3   ; la figura de la caida
	ld (0e134h),a		;68e5
	ld a,082h		;68e8   ; y en el suelo
	cp (hl)			;68ea
	jr nc,L_6909		;68eb
	ld (hl),a			;68ed   ; clavado
	ld hl,0e12ch		;68ee
	ld a,(hl)			;68f1
	or a			;68f2
	jr nz,L_6901		;68f3
	ld (hl),001h		;68f5   ; juzgado
	call contadores_de_la_pertiga		;68f7
	ld a,01eh		;68fa   ; con su sonido
	call arranca_una_pista		;68fc
	jr L_6909		;68ff
L_6901:
	call termina_el_intento		;6901   ; se acabo el intento
	ld hl,0e12bh		;6904
	ld (hl),0ffh		;6907   ; y el liston, por tocado
L_6909:
	jp L_6703		;6909
altura_del_liston:		; la fila del liston por el que va el jugador
	call apunta_al_jugador_de_turno		;690c
	inc hl			;690f   ; el liston por el que va, tope nueve
	inc hl			;6910
	ld a,(hl)			;6911
	cp 00ah		;6912
	jr c,L_6918		;6914
	ld a,009h		;6916
L_6918:
	ld hl,06f40h		;6918   ; la tabla de sus alturas
	call suma_a_hl		;691b
	ld a,(hl)			;691e
	ld hl,(0e131h)		;691f   ; y la posicion del atleta
	ret			;6922
termina_el_intento:		; congela, estado 5 y un intento menos
	ld a,001h		;6923
	ld (0e128h),a		;6925   ; congelado
	ld a,005h		;6928
	ld (0e130h),a		;692a   ; el estado del calculo
	ld a,080h		;692d
	ld (0e13dh),a		;692f   ; la cuenta
	call apunta_al_jugador_de_turno		;6932
	dec (hl)			;6935   ; y un intento menos
	jp pinta_los_intentos_que_quedan		;6936
dibuja_la_pertiga_y_el_atleta:		; los dos dibujos, en su orden
	ex af,af'			;6939
	ld a,b			;693a
	ld hl,06fa7h		;693b   ; la pertiga
	call dibujo_de_la_tabla		;693e
	ex af,af'			;6941
	push af			;6942
	ld hl,07132h		;6943   ; y encima el atleta
	call dibujo_de_la_tabla		;6946
	pop af			;6949
	ret			;694a
prepara_el_dibujo_del_atleta:		; la fila, la columna y el VDP colocado
	ld hl,0e131h		;694b   ; la fila
	ld b,(hl)			;694e
	inc hl			;694f
	ld a,(hl)			;6950   ; y la columna, a la otra pareja de registros
	exx			;6951
	ld c,a			;6952
	exx			;6953
	inc hl			;6954
	inc hl			;6955
	ld a,(hl)			;6956   ; la figura
	cp 003h		;6957
	jr z,L_695F		;6959
	cp 009h		;695b
	jr nz,L_6960		;695d
L_695F:
	dec b			;695f   ; en dos de ellas, una fila mas arriba
L_6960:
	push af			;6960
	cp 005h		;6961   ; y en otras dos
	jr z,L_6969		;6963
	cp 00bh		;6965
	jr nz,L_6974		;6967
L_6969:
	dec hl			;6969
	sub (hl)			;696a   ; suena el paso
	cp 001h		;696b
	jr nz,L_6974		;696d
	ld a,043h		;696f
	call arranca_una_pista		;6971
L_6974:
	ld hl,01800h		;6974   ; los patrones de sprite
	call 00053h		;6977   ; BIOS SETWRT - Enables VDP to write
	ld a,(00006h)		;697a
	ld c,a			;697d   ; el puerto de datos, a mano
	pop af			;697e
	ret			;697f
figura_de_la_tabla_6b00:		; la entrada A, y dos piezas
	ld hl,06b00h		;6980   ; la tabla
	add a,a			;6983   ; dos bytes por entrada
	call suma_a_hl		;6984
	ld e,(hl)			;6987
	inc hl			;6988
	ld d,(hl)			;6989
	ld a,002h		;698a   ; dos piezas
monta_piezas_desde_e0c4:		; las piezas, a partir del sprite 9
	ld hl,0e0c4h		;698c   ; donde se dejan
	ld (0e170h),hl		;698f

; ----------------------------------------------------------------------
; EL MOTOR DE FIGURAS. Un atleta no es un sprite: son de dos a siete sprites de 16x16, y cada pieza son cinco bytes -la fila y la columna relativas, el puntero al bloque de patron y el color-, con un 0x80 que cierra la figura. Y el patron no esta puesto de antes: el bloque se DESCOMPRIME a la VRAM aqui mismo, con el mismo RLE de siempre, o sea que los 2 KB de patrones de sprite se rehacen enteros en cada fotograma. Por eso el atleta puede tener cientos de posturas sin que quepan a la vez en la VRAM.
; ----------------------------------------------------------------------
monta_las_piezas_del_atleta:		; cinco bytes por pieza, y el 0x80 cierra
	ld hl,(0e170h)		;6992
L_6995:
	push af			;6995
	ld a,(de)			;6996   ; la fila relativa
	cp 080h		;6997   ; el 0x80 cierra la figura
	jr z,L_69D7		;6999
	add a,b			;699b   ; mas la fila de la figura
	ld (hl),a			;699c
	inc hl			;699d
	inc de			;699e
	ld a,(de)			;699f   ; la columna relativa
	exx			;69a0
	add a,c			;69a1   ; mas la de la figura
	exx			;69a2
	ld (hl),a			;69a3
	inc hl			;69a4
	inc hl			;69a5
	push hl			;69a6
	inc de			;69a7
	ex de,hl			;69a8
	ld e,(hl)			;69a9   ; el puntero al bloque de patron
	inc hl			;69aa
	ld d,(hl)			;69ab
	inc hl			;69ac
	push hl			;69ad
	push bc			;69ae
L_69AF:
	ld a,(de)			;69af   ; el mandato
	and a			;69b0
	jr z,L_69CB		;69b1   ; el 0 cierra el bloque
	inc de			;69b3
	ld b,a			;69b4
	and 07fh		;69b5   ; sin el bit 7 es una repeticion
	cp b			;69b7
	jr z,L_69C3		;69b8
	ld b,a			;69ba
L_69BB:
	ld a,(de)			;69bb   ; los que van tal cual
	inc de			;69bc
	out (c),a		;69bd   ; a la VRAM, sin pasar por la BIOS
	djnz L_69BB		;69bf
	jr L_69AF		;69c1
L_69C3:
	ld a,(de)			;69c3   ; el byte que se repite
	inc de			;69c4
L_69C5:
	out (c),a		;69c5
	djnz L_69C5		;69c7
	jr L_69AF		;69c9
L_69CB:
	pop bc			;69cb
	pop de			;69cc
	pop hl			;69cd
	ld a,(de)			;69ce   ; y el color de la pieza
	ld (hl),a			;69cf
	inc hl			;69d0
	inc de			;69d1
	pop af			;69d2
	dec a			;69d3   ; hasta que se acaban las piezas
	jr nz,L_6995		;69d4
	ret			;69d6
L_69D7:
	pop af			;69d7
esconde_a_sprites:		; los que digan, con un 0xC3 en la Y
	ld (hl),0c3h		;69d8   ; un 0xC3 en la Y y el sprite no se ve
	inc hl			;69da   ; cuatro bytes por sprite
	inc hl			;69db
	inc hl			;69dc
	inc hl			;69dd
	dec a			;69de   ; y los que digan
	jr nz,esconde_a_sprites		;69df
	ret			;69e1
caida_del_atleta:		; la gravedad de la pertiga, con su figura
	call lo_recien_pulsado_por_el_de_turno		;69e2   ; lo recien pulsado
	bit 3,a		;69e5   ; el bit 3, apuntado
	jr z,L_69EE		;69e7
	ld a,001h		;69e9
	ld (0e179h),a		;69eb
L_69EE:
	ld hl,0e17ah		;69ee
	dec (hl)			;69f1   ; la cuenta de la figura
	ld a,(hl)			;69f2
	or a			;69f3
	ret nz			;69f4
	ld b,003h		;69f5
	ld a,(0e130h)		;69f7   ; en el cuarto estado va mas deprisa
	cp 004h		;69fa
	jr nz,L_69FF		;69fc
	dec b			;69fe
L_69FF:
	ld (hl),b			;69ff
	call pasos_del_atleta		;6a00   ; el atleta
	ld hl,0e139h		;6a03
	inc (hl)			;6a06   ; un fotograma mas de figura
	ld a,(hl)			;6a07
	ld c,006h		;6a08
	cp 020h		;6a0a   ; y la figura que le toca a cada tramo
	jr nc,L_6A19		;6a0c
	dec c			;6a0e
	cp 013h		;6a0f
	jr nc,L_6A19		;6a11
	dec c			;6a13
	cp 005h		;6a14
	jr nc,L_6A19		;6a16
	dec c			;6a18
L_6A19:
	ld a,c			;6a19
	ld (0e134h),a		;6a1a   ; apuntada
	ld a,(0e130h)		;6a1d
	cp 004h		;6a20
	ld hl,0e131h		;6a22
	ld a,(0e154h)		;6a25   ; la aceleracion
	jr z,L_6A5F		;6a28
	add a,a			;6a2a   ; por dos
	add a,(hl)			;6a2b   ; y a la fila
	ld (hl),a			;6a2c
	ld a,(0e12ch)		;6a2d
	or a			;6a30
	jr nz,L_6A43		;6a31
	ld a,(0e136h)		;6a33
	or a			;6a36
	jr nz,L_6A43		;6a37
	ld de,0e179h		;6a39   ; el empujon apuntado
	ld a,(de)			;6a3c
	or a			;6a3d
	jr z,L_6A43		;6a3e
	dec (hl)			;6a40   ; sube un punto
	xor a			;6a41
	ld (de),a			;6a42
L_6A43:
	inc hl			;6a43
	ld a,(0e15bh)		;6a44   ; el avance
	add a,(hl)			;6a47
	ld (hl),a			;6a48   ; a la columna
	cp 080h		;6a49   ; pasada de 0x80
	ret c			;6a4b
	cp 0a0h		;6a4c
	ld hl,06f4ah		;6a4e   ; las seis piezas de una colchoneta
	jr nc,L_6A56		;6a51
	ld hl,06f62h		;6a53   ; o las de la otra
L_6A56:
	ld de,0e0ach		;6a56
	ld bc,00018h		;6a59
	ldir		;6a5c
	ret			;6a5e
L_6A5F:
	dec a			;6a5f   ; y en el cuarto estado la aceleracion es otra
	add a,a			;6a60
	add a,(hl)			;6a61
	ld (hl),a			;6a62
	ret			;6a63
pasos_del_atleta:		; la zancada, y de ahi la columna y el paso
	ld hl,0e126h		;6a64
	ld a,(hl)			;6a67   ; la velocidad
	call seno		;6a68
	dec hl			;6a6b
	dec hl			;6a6c
	ld b,(hl)			;6a6d
	ld c,000h		;6a6e
	call multiplica_8x16		;6a70   ; multiplicada
	ex de,hl			;6a73
	ld hl,0e150h		;6a74
	ld (hl),e			;6a77   ; apuntada
	inc hl			;6a78
	ld (hl),d			;6a79
	ld c,d			;6a7a
	inc hl			;6a7b
	inc (hl)			;6a7c   ; un paso mas
	push hl			;6a7d
	ld h,(hl)			;6a7e
	srl h		;6a7f
	ld e,002h		;6a81
	call multiplica_8x8		;6a83   ; entre dos
	ld e,l			;6a86
	pop hl			;6a87
	inc hl			;6a88
	ld (hl),e			;6a89
	inc hl			;6a8a
	ld a,c			;6a8b
	sub e			;6a8c
	bit 7,a		;6a8d
	jr nz,L_6A9A		;6a8f
	rra			;6a91
	rra			;6a92
	rra			;6a93
	and 01fh		;6a94
	ld c,000h		;6a96
	jr L_6AA2		;6a98
L_6A9A:
	scf			;6a9a   ; hacia atras: se cuenta con signo
	rra			;6a9b
	scf			;6a9c
	rra			;6a9d
	scf			;6a9e
	rra			;6a9f
	ld c,001h		;6aa0   ; y se apunta el sentido
L_6AA2:
	neg		;6aa2   ; en positivo
	ld (hl),a			;6aa4   ; el paso, apuntado
	ld a,c			;6aa5
	ld (0e136h),a		;6aa6   ; y el sentido
	ld hl,0e126h		;6aa9   ; el angulo de la carrera
	ld a,(hl)			;6aac
	call coseno		;6aad   ; su coseno
	dec hl			;6ab0
	dec hl			;6ab1
	ld b,(hl)			;6ab2   ; por la velocidad
	ld c,000h		;6ab3
	call multiplica_8x16		;6ab5   ; y ese es el avance
	ex de,hl			;6ab8
	ld hl,0e158h		;6ab9
	ld (hl),e			;6abc   ; apuntado
	inc hl			;6abd
	ld (hl),d			;6abe
	inc hl			;6abf
	ld a,(hl)			;6ac0   ; la parte fina del avance
	add a,d			;6ac1
	ld d,a			;6ac2
	and 007h		;6ac3   ; que se guarda para el fotograma siguiente
	ld (hl),a			;6ac5
	inc hl			;6ac6
	ld a,d			;6ac7
	rra			;6ac8   ; y el resto, entre ocho: la casilla
	rra			;6ac9
	rra			;6aca
	and 01fh		;6acb
	ld (hl),a			;6acd
	ret			;6ace
cae_el_liston:		; el liston tirado, bajando por su curva
	ld hl,0e0e0h		;6acf   ; el sprite del liston
	ld a,(hl)			;6ad2
	cp 087h		;6ad3   ; pasada la fila 0x87, ya esta en el suelo
	ret nc			;6ad5
	ld de,(0e143h)		;6ad6   ; por donde va su curva de caida
	ld a,(de)			;6ada
	add a,(hl)			;6adb   ; lo que baja en este fotograma
	ld (hl),a			;6adc
	inc hl			;6add
	inc (hl)			;6ade   ; y una columna a la derecha
	ex de,hl			;6adf
	inc hl			;6ae0
	ld a,(hl)			;6ae1   ; el punto siguiente de la curva
	inc a			;6ae2
	inc a			;6ae3
	jr nz,L_6AE7		;6ae4   ; y el 0xFE la deja clavada en el ultimo
	dec hl			;6ae6
L_6AE7:
	ld (0e143h),hl		;6ae7
	ret			;6aea
dibujo_del_publico:		; dos versiones, alternando
	ld a,(0e003h)		;6aeb
	bit 1,a		;6aee   ; el bit 1 del contador de fotogramas
	ld de,0775fh		;6af0   ; una version
	jr nz,L_6AF8		;6af3
	ld de,078e5h		;6af5   ; y la otra
L_6AF8:
	ld hl,00200h		;6af8
	ld b,002h		;6afb   ; dos tercios nada mas
	jp L_4407		;6afd

; ----------------------------------------------------------------------
; DATOS tabla_de_figuras_6b00: 13 punteros; la mas baja es 0x6B1A, que es
;   donde acaba la tabla
;   0x6b00..0x6b1a  (26 bytes)
DATA_tabla_de_figuras_6b00:
	defw 06b1ah,06b38h,06b2eh,06b24h,06b2eh,06b38h,06b42h,06b4ch	; 6b00
	defw 06b56h,06b60h,06b56h,06b4ch,06b42h	; 6b10

; ----------------------------------------------------------------------
; DATOS figuras_6b1a: 80 B: ocho figuras de dos piezas de cinco bytes
;   0x6b1a..0x6b6a  (80 bytes)
DATA_figuras_6b1a:
	defb 000h,004h,037h,087h,00ah,000h,003h,022h,087h,006h	; 6b1a  ..7...."..
	defb 000h,000h,09bh,087h,00ah,000h,003h,04bh,087h,006h	; 6b24  .......K..
	defb 000h,000h,07ah,087h,00ah,000h,003h,04bh,087h,006h	; 6b2e  ..z....K..
	defb 000h,0fdh,05fh,087h,00ah,000h,003h,04bh,087h,006h	; 6b38  .._....K..
	defb 000h,004h,037h,087h,00ah,000h,003h,04bh,087h,006h	; 6b42  ..7....K..
	defb 000h,002h,0bch,087h,00ah,000h,003h,04bh,087h,006h	; 6b4c  .......K..
	defb 000h,000h,0dch,087h,00ah,000h,003h,04bh,087h,006h	; 6b56  .......K..
	defb 000h,000h,0fdh,087h,00ah,000h,003h,04bh,087h,006h	; 6b60  .......K..

; ----------------------------------------------------------------------
; DATOS tabla_de_figuras_6b6a: 13 punteros; acaba en 0x6B84
;   0x6b6a..0x6b84  (26 bytes)
DATA_tabla_de_figuras_6b6a:
	defw 06b84h,06b8fh,06b8fh,06b9fh,06bb3h,06bc3h,06bceh,06b8fh	; 6b6a
	defw 06b8fh,06b9fh,06bb3h,06bc3h,06bceh	; 6b7a

; ----------------------------------------------------------------------
; DATOS figuras_6b84: 85 B: siete figuras de hasta cuatro piezas, cada una
;   cerrada con su 0x80
;   0x6b84..0x6bd9  (85 bytes)
DATA_figuras_6b84:
	defb 010h,004h,014h,086h,00fh,014h,004h,023h,086h,00ah,080h	; 6b84  .......#...
	defb 010h,0f1h,02fh,086h,00fh,010h,002h,03ch,086h,00fh,010h,000h,04bh,086h,00ah,080h	; 6b8f  ../....<....K...
	defb 010h,0f8h,061h,086h,00fh,010h,007h,074h,086h,00fh,011h,0fdh,083h,086h,00ah,010h,005h,08eh,086h,00ah	; 6b9f  ..a....t............
	defb 010h,0fch,0a1h,086h,00fh,00fh,001h,0b4h,086h,00fh,011h,000h,0bdh,086h,00ah,080h	; 6bb3  ................
	defb 010h,0fbh,0d4h,086h,00fh,012h,000h,0eah,086h,00ah,080h	; 6bc3  ...........
	defb 010h,000h,0feh,086h,00fh,012h,003h,014h,087h,00ah,080h	; 6bce  ...........

; ----------------------------------------------------------------------
; DATOS tabla_de_figuras_6bd9: 14 punteros; acaba en 0x6BF5
;   0x6bd9..0x6bf5  (28 bytes)
DATA_tabla_de_figuras_6bd9:
	defw 06bf5h,06c0ah,06c24h,06c47h,06bf5h,06c6ah,06c84h,06ca7h	; 6bd9
	defw 06ccah,06cdfh,06cfeh,06d13h,06d2dh,06d47h	; 6be9

; ----------------------------------------------------------------------
; DATOS figuras_6bf5: 359 B: catorce figuras de hasta siete piezas
;   0x6bf5..0x6d5c  (359 bytes)
DATA_figuras_6bf5:
	defb 000h,000h,0bah,088h,00ah,000h,001h,04bh,087h,006h,010h,0fbh,065h,08ah,00fh	; 6bf5  .......K....e..
	defb 013h,0fbh,0cbh,089h,00ah,080h,000h,000h,0bah,088h,00ah,000h,001h,04bh,087h	; 6c04  .............K.
	defb 006h,010h,0eeh,02fh,086h,00fh,010h,0ffh,03ch,086h,00fh,010h,0fdh,04bh,086h	; 6c13  .../....<....K.
	defb 00ah,080h,0ffh,0fch,0dch,088h,00ah,0feh,0ffh,0fbh,088h,00ah,000h,001h,04bh	; 6c22  ..............K
	defb 087h,006h,010h,0f6h,061h,086h,00fh,010h,005h,074h,086h,00fh,011h,0fbh,083h	; 6c31  ....a....t.....
	defb 086h,00ah,010h,003h,08eh,086h,00ah,0ffh,0fch,0dch,088h,00ah,0feh,0ffh,0fbh	; 6c40  ...............
	defb 088h,00ah,000h,001h,04bh,087h,006h,010h,0f9h,07eh,08ah,00fh,00dh,003h,092h	; 6c4f  ....K....~.....
	defb 08ah,00fh,009h,0fah,0e0h,089h,00ah,014h,00ah,0f3h,089h,00ah,000h,000h,09bh	; 6c5e  ...............
	defb 087h,00ah,000h,003h,04bh,087h,006h,010h,0f1h,02fh,086h,00fh,010h,002h,03ch	; 6c6d  ....K..../....<
	defb 086h,00fh,010h,000h,04bh,086h,00ah,080h,0feh,0fdh,003h,089h,00ah,0fah,0ffh	; 6c7c  ....K..........
	defb 01ch,089h,00ah,000h,000h,01eh,088h,006h,010h,0f5h,061h,086h,00fh,010h,004h	; 6c8b  ..........a....
	defb 074h,086h,00fh,011h,0fah,083h,086h,00ah,010h,002h,08eh,086h,00ah,0ffh,0fbh	; 6c9a  t..............
	defb 023h,089h,00ah,000h,0fdh,03eh,089h,00ah,000h,001h,04bh,087h,006h,010h,0f9h	; 6ca9  #....>....K....
	defb 07eh,08ah,00fh,00dh,003h,092h,08ah,00fh,009h,0fah,0e0h,089h,00ah,014h,00ah	; 6cb8  ~..............
	defb 0f3h,089h,00ah,000h,0fdh,05fh,087h,00ah,000h,003h,04bh,087h,006h,010h,0fdh	; 6cc7  ....._....K....
	defb 065h,08ah,00fh,013h,0fdh,0cbh,089h,00ah,080h,010h,00ah,016h,08ah,00ah,004h	; 6cd6  e..............
	defb 002h,043h,089h,00ah,000h,000h,037h,088h,006h,010h,0f8h,09bh,08ah,00fh,010h	; 6ce5  .C....7........
	defb 0fbh,0ffh,089h,00ah,00ah,003h,0aeh,08ah,00fh,080h,000h,000h,05dh,089h,00ah	; 6cf4  ............]..
	defb 000h,000h,051h,088h,006h,010h,001h,0b8h,08ah,00fh,012h,004h,021h,08ah,00ah	; 6d03  ..Q.........!..
	defb 080h,0feh,005h,07ah,089h,00ah,000h,000h,06bh,088h,006h,010h,0ffh,0d0h,08ah	; 6d12  ...z....k......
	defb 00fh,013h,00fh,0dah,08ah,00fh,010h,000h,035h,08ah,00ah,080h,000h,003h,093h	; 6d21  ........5......
	defb 089h,00ah,000h,000h,084h,088h,006h,010h,000h,0d0h,08ah,00fh,012h,00eh,0e3h	; 6d30  ...............
	defb 08ah,00fh,010h,002h,046h,08ah,00ah,080h,000h,003h,0b1h,089h,00ah,000h,000h	; 6d3f  ....F..........
	defb 0a0h,088h,006h,010h,000h,0edh,08ah,00fh,010h,005h,056h,08ah,00ah,080h	; 6d4e  ..........V...

; ----------------------------------------------------------------------
; DATOS tabla_de_figuras_6d5c: 6 punteros; acaba en 0x6D68
;   0x6d5c..0x6d68  (12 bytes)
DATA_tabla_de_figuras_6d5c:
	defw 06d68h,06d7dh,06d92h,06da7h,06dbch,06dd1h	; 6d5c

; ----------------------------------------------------------------------
; DATOS figuras_6d68: 126 B: seis figuras de cuatro piezas, 21 bytes cada una
;   0x6d68..0x6de6  (126 bytes)
DATA_figuras_6d68:
	defb 000h,000h,001h,08bh,00ah,000h,002h,08eh,08bh,006h,010h,002h,020h,08ch,00fh,013h,003h,0a1h,08ch,00ah,080h	; 6d68  ............ ........
	defb 000h,000h,021h,08bh,00ah,000h,002h,08eh,08bh,006h,010h,002h,035h,08ch,00fh,013h,003h,0b4h,08ch,00ah,080h	; 6d7d  ..!.........5........
	defb 000h,001h,060h,08bh,00ah,000h,000h,0a1h,08bh,006h,010h,0ffh,0e6h,08bh,00fh,010h,001h,062h,08ch,00ah,080h	; 6d92  ..`..............b...
	defb 000h,000h,040h,08bh,00ah,000h,002h,0bdh,08bh,006h,010h,002h,0fch,08bh,00fh,013h,001h,079h,08ch,00ah,080h	; 6da7  ..@..............y...
	defb 000h,000h,040h,08bh,00ah,000h,002h,0bdh,08bh,006h,010h,002h,00bh,08ch,00fh,012h,002h,08eh,08ch,00ah,080h	; 6dbc  ..@..................
	defb 000h,001h,078h,08bh,00ah,000h,001h,0cch,08bh,006h,010h,000h,04ch,08ch,00fh,010h,000h,0c9h,08ch,00ah,080h	; 6dd1  ..x.........L........

; ----------------------------------------------------------------------
; DATOS estado_inicial_de_0xe131: 4 B que 0x5FD0 copia a 0xE131 con un `ldir`
;   0x6de6..0x6dea  (4 bytes)
DATA_estado_inicial_de_0xe131:
	defb 08ah,031h,000h,000h	; 6de6

; ----------------------------------------------------------------------
; DATOS atributos_de_sprite_iniciales: 28 B que 0x6476 copia a 0xE0C4: siete
;   sprites, con los patrones 0, 4, 8, 0x0C, 0x10, 0x14 y 0x18
;   0x6dea..0x6e06  (28 bytes)
DATA_atributos_de_sprite_iniciales:
	defb 000h,000h,000h,000h	; 6dea
	defb 000h,000h,004h,000h	; 6dee
	defb 000h,000h,008h,000h	; 6df2
	defb 000h,000h,00ch,000h	; 6df6
	defb 000h,000h,010h,000h	; 6dfa
	defb 000h,000h,014h,000h	; 6dfe
	defb 000h,000h,018h,000h	; 6e02

; ----------------------------------------------------------------------
; DATOS estado_inicial_de_0xe0e4: 4 B que 0x6052 y 0x6387 copian a 0xE0E4
;   0x6e06..0x6e0a  (4 bytes)
DATA_estado_inicial_de_0xe0e4:
	defb 0a9h,035h,0d8h,001h	; 6e06

; ----------------------------------------------------------------------
; DATOS estado_inicial_de_0xe0e4_bis: 4 B, el otro juego, desde 0x6102
;   0x6e0a..0x6e0e  (4 bytes)
DATA_estado_inicial_de_0xe0e4_bis:
	defb 0a7h,000h,0dch,001h	; 6e0a

; ----------------------------------------------------------------------
; DATOS guion_foul_en_juego: 7 B SIN cabecera: " FOUL ", con el destino ya en
;   HL; lo pintan 0x7528 y 0x754B
;   0x6e0e..0x6e15  (7 bytes)
DATA_guion_foul_en_juego:
	defb 000h,026h,02fh,035h,02ch,000h,0ffh	; 6e0e

; ----------------------------------------------------------------------
; DATOS figura_6e15: 15 B: tres piezas, desde 0x64E0
;   0x6e15..0x6e24  (15 bytes)
DATA_figura_6e15:
	defb 0fdh,0f5h,0ddh,08ch,00ah	; 6e15
	defb 0fdh,005h,0e9h,08ch,00ah	; 6e1a
	defb 000h,003h,04bh,087h,006h	; 6e1f

; ----------------------------------------------------------------------
; DATOS figura_6e24: 15 B: tres piezas, desde 0x653D
;   0x6e24..0x6e33  (15 bytes)
DATA_figura_6e24:
	defb 0fdh,0f5h,002h,08dh,00ah	; 6e24
	defb 0fdh,005h,0e9h,08ch,00ah	; 6e29
	defb 000h,003h,04bh,087h,006h	; 6e2e

; ----------------------------------------------------------------------
; DATOS tabla_de_figuras_6e33: 8 punteros; acaba en 0x6E43
;   0x6e33..0x6e43  (16 bytes)
DATA_tabla_de_figuras_6e33:
	defw 06e43h,06e62h,06e85h,06e9fh,06eb9h,06ed3h,06eedh,06f02h	; 6e33

; ----------------------------------------------------------------------
; DATOS figuras_6e43: 217 B: ocho figuras de hasta siete piezas, las mas
;   grandes del cartucho
;   0x6e43..0x6f1c  (217 bytes)
DATA_figuras_6e43:
	defb 0fbh,0fah,011h,08dh,00ah,0fbh,000h,029h,08dh,00ah,00eh,005h,035h,08dh,00ah	; 6e43  .......)....5..
	defb 000h,000h,04eh,08dh,006h,00eh,008h,06bh,08dh,00fh,010h,009h,079h,08dh,00fh	; 6e52  ..N....k....y..
	defb 080h,0f3h,003h,08dh,08dh,00ah,0e9h,005h,0afh,08dh,00ah,001h,002h,0b6h,08dh	; 6e61  ...............
	defb 00ah,000h,000h,0c1h,08dh,006h,003h,010h,0d7h,08dh,006h,0e7h,007h,0dfh,08dh	; 6e70  ...............
	defb 00fh,0feh,00dh,0efh,08dh,00fh,0ech,000h,0fah,08dh,00ah,0fch,002h,01bh,08eh	; 6e7f  ...............
	defb 00ah,000h,000h,02dh,08eh,006h,0e2h,003h,048h,08eh,00fh,0f2h,0ffh,059h,08eh	; 6e8e  ...-....H....Y.
	defb 00fh,080h,0edh,004h,062h,08eh,00ah,0feh,0f9h,07dh,08eh,00ah,000h,000h,090h	; 6e9d  ....b....}.....
	defb 08eh,006h,0eeh,002h,0a8h,08eh,00fh,0f1h,0feh,0b6h,08eh,00fh,080h,0f8h,00bh	; 6eac  ...............
	defb 0c4h,08eh,00ah,005h,0ffh,0dbh,08eh,00ah,000h,000h,0f7h,08eh,006h,0f5h,001h	; 6ebb  ...............
	defb 012h,08fh,00fh,0fch,00fh,01dh,08fh,00fh,080h,000h,000h,030h,08fh,00ah,004h	; 6eca  ...........0...
	defb 010h,049h,08fh,00ah,000h,000h,06ah,08fh,006h,072h,00fh,082h,08fh,000h,002h	; 6ed9  .I....j..r.....
	defb 00fh,082h,08fh,00fh,080h,0fdh,0feh,09ah,08fh,00ah,00ch,0fbh,0b9h,08fh,00ah	; 6ee8  ...............
	defb 000h,000h,0cfh,08fh,006h,00eh,0fch,0e4h,08fh,00fh,080h,0fch,0f7h,0feh,08fh	; 6ef7  ...............
	defb 00ah,000h,003h,01ch,090h,00ah,000h,000h,037h,090h,006h,0f8h,0eeh,04ch,090h	; 6f06  ........7....L.
	defb 00fh,000h,0f3h,063h,090h,00fh,080h	; 6f15

; ----------------------------------------------------------------------
; DATOS tabla_6f1c: 11 valores y el 0xFF que cierra: 75, 60, 50, 30, 30, 30,
;   35, 40, 45, 45 y 20; la indexa 0x6653 con `call L_4046 / ld a,(hl)`
;   0x6f1c..0x6f28  (12 bytes)
DATA_tabla_6f1c:
	defb 04bh,03ch,032h,01eh,01eh,01eh,023h,028h,02dh,02dh,014h,0ffh	; 6f1c  K<2...#(--..

; ----------------------------------------------------------------------
; DATOS tabla_6f28: 23 valores que solo suben, de 0 a 7, y el 0xFE que cierra;
;   0x6726 se la guarda entera en (0xE143)
;   0x6f28..0x6f40  (24 bytes)
DATA_tabla_6f28:
	defb 000h,000h,000h,001h,000h,001h,000h,001h,001h,001h,001h,002h,002h,002h,002h,003h,003h,003h,004h,004h,004h,005h,007h,0feh	; 6f28  ........................

; ----------------------------------------------------------------------
; DATOS tabla_6f40: 10 valores que solo bajan, de 0x44 a 0x36; la indexa
;   0x6918
;   0x6f40..0x6f4a  (10 bytes)
DATA_tabla_6f40:
	defb 044h,042h,040h,03eh,03ch,03ah,039h,038h,037h,036h	; 6f40  DB@><:9876

; ----------------------------------------------------------------------
; DATOS atributos_de_sprite_6f4a: 24 B que 0x66CE y 0x6A4E copian a 0xE0AC:
;   seis sprites iguales, todos con Y = 0xC3, o sea APAGADOS
;   0x6f4a..0x6f62  (24 bytes)
DATA_atributos_de_sprite_6f4a:
	defb 0c3h,09ch,0d4h,00ah	; 6f4a
	defb 0c3h,09ch,0d4h,00ah	; 6f4e
	defb 0c3h,09ch,0d4h,00ah	; 6f52
	defb 0c3h,09ch,0d4h,00ah	; 6f56
	defb 0c3h,09ch,0d4h,00ah	; 6f5a
	defb 0c3h,09ch,0d4h,00ah	; 6f5e

; ----------------------------------------------------------------------
; DATOS atributos_de_sprite_6f62: 24 B, la alternativa, desde 0x6A53: los
;   mismos seis sprites pero escalonados en Y, de 0x94 a 0x44
;   0x6f62..0x6f7a  (24 bytes)
DATA_atributos_de_sprite_6f62:
	defb 094h,09ch,0d4h,00ah	; 6f62
	defb 084h,09ch,0d4h,00ah	; 6f66
	defb 074h,09ch,0d4h,00ah	; 6f6a
	defb 064h,09ch,0d4h,00ah	; 6f6e
	defb 054h,09ch,0d4h,00ah	; 6f72
	defb 044h,09ch,0d4h,00ah	; 6f76

; ----------------------------------------------------------------------
; DATOS guion_6f7a: 15 B: doce tiles 0x67 seguidos en 0x3A44; lo carga 0x64BB
;   0x6f7a..0x6f89  (15 bytes)
DATA_guion_6f7a:
	defb 044h,03ah,067h,067h,067h,067h,067h,067h,067h,067h,067h,067h,067h,067h,0ffh	; 6f7a  D:gggggggggggg.

; ----------------------------------------------------------------------
; DATOS guion_6f89: 15 B: los mismos doce sitios con el tile 0x68; desde
;   0x64CB
;   0x6f89..0x6f98  (15 bytes)
DATA_guion_6f89:
	defb 044h,03ah,068h,068h,068h,068h,068h,068h,068h,068h,068h,068h,068h,068h,0ffh	; 6f89  D:hhhhhhhhhhhh.

; ----------------------------------------------------------------------
; DATOS guion_6f98: 15 B: y con el tile 0x41, que es la letra A de la fuente;
;   desde 0x650D
;   0x6f98..0x6fa7  (15 bytes)
DATA_guion_6f98:
	defb 044h,03ah,041h,041h,041h,041h,041h,041h,041h,041h,041h,041h,041h,041h,0ffh	; 6f98  D:AAAAAAAAAAAA.

; ----------------------------------------------------------------------
; DATOS tabla_de_guiones_relativos_6fa7: 15 punteros; acaba en 0x6FC5, que es
;   su entrada mas baja
;   0x6fa7..0x6fc5  (30 bytes)
DATA_tabla_de_guiones_relativos_6fa7:
	defw 06fc5h,06fdbh,06ff1h,07006h,07017h,07025h,07037h,07045h	; 6fa7
	defw 0705ch,0706eh,0708ch,070aeh,070d2h,070f5h,07114h	; 6fb7

; ----------------------------------------------------------------------
; DATOS guiones_relativos_6fc5: 365 B: los quince guiones de L_676E, con 0xFE
;   para saltar en relativo y 0xFF para cerrar. Dibujan una escalera de tiles
;   0x0E que se va estirando: es la barra que crece
;   0x6fc5..0x7132  (365 bytes)
DATA_guiones_relativos_6fc5:
	defb 024h,03ah,040h,040h,0feh,021h,041h,041h,041h,041h,041h,041h,041h,041h,041h,0feh	; 6fc5  $:@@.!AAAAAAAAA.
	defb 027h,042h,042h,042h,042h,0ffh,024h,03ah,040h,040h,040h,0feh,024h,041h,041h,041h	; 6fd5  'BBBB.$:@@@.$AAA
	defb 0feh,022h,042h,042h,042h,042h,042h,0feh,024h,043h,043h,0ffh,024h,03ah,040h,040h	; 6fe5  ."BBBBB.$CC.$:@@
	defb 040h,0feh,025h,041h,0feh,020h,042h,042h,042h,042h,0feh,023h,043h,043h,043h,043h	; 6ff5  @.%A. BBBB.#CCCC
	defb 0ffh,025h,03ah,040h,040h,0feh,044h,042h,042h,042h,0feh,022h,043h,043h,043h,043h	; 7005  .%:@@.DBBB."CCCC
	defb 043h,0ffh,026h,03ah,040h,040h,0feh,024h,041h,041h,041h,0feh,022h,042h,042h,0ffh	; 7015  C.&:@@.$AAA."BB.
	defb 0e7h,039h,00eh,00eh,00eh,0feh,024h,00eh,00eh,00eh,0feh,022h,040h,040h,0feh,062h	; 7025  .9....$...."@@.b
	defb 043h,0ffh,0c7h,039h,00eh,00eh,00eh,0feh,024h,00eh,00eh,00eh,0feh,0a4h,043h,0ffh	; 7035  C..9....$.....C.
	defb 0aah,039h,00eh,00eh,0feh,021h,00eh,00eh,0feh,021h,00eh,00eh,0feh,021h,00eh,00eh	; 7045  .9...!...!...!..
	defb 0feh,021h,040h,0feh,061h,043h,0ffh,08ch,039h,00eh,0feh,020h,00eh,00eh,0feh,021h	; 7055  .!@.aC..9.. ...!
	defb 00eh,0feh,020h,00eh,00eh,0feh,0a2h,043h,0ffh,06ah,039h,00eh,00eh,00eh,0feh,022h	; 7065  .. ....C.j9...."
	defb 00eh,00eh,0feh,021h,00eh,0feh,020h,00eh,00eh,0feh,021h,00eh,0feh,020h,00eh,0feh	; 7075  ...!.. ...!.. ..
	defb 020h,040h,040h,0feh,061h,043h,0ffh,04bh,039h,00eh,00eh,00eh,0feh,022h,00eh,00eh	; 7085   @@.aC.K9...."..
	defb 0feh,021h,00eh,0feh,020h,00eh,0feh,020h,00eh,00eh,0feh,020h,00eh,00eh,0feh,020h	; 7095  .!.. .. ... ... 
	defb 00eh,00eh,0feh,021h,040h,0feh,060h,043h,0ffh,02ch,039h,00eh,0feh,020h,00eh,00eh	; 70a5  ...!@.`C.,9.. ..
	defb 0feh,021h,00eh,00eh,0feh,021h,00eh,0feh,020h,00eh,0feh,020h,00eh,00eh,0feh,020h	; 70b5  .!...!.. .. ... 
	defb 00eh,00eh,0feh,020h,00eh,00eh,0feh,021h,040h,0feh,060h,043h,0ffh,02dh,039h,00eh	; 70c5  ... ...!@.`C.-9.
	defb 00eh,0feh,021h,00eh,0feh,020h,00eh,0feh,020h,00eh,0feh,020h,00eh,00eh,0feh,020h	; 70d5  ..!.. .. .. ... 
	defb 00eh,00eh,0feh,020h,00eh,00eh,0feh,021h,00eh,0feh,020h,040h,0feh,060h,043h,0ffh	; 70e5  ... ...!.. @.`C.
	defb 02fh,039h,00eh,0feh,020h,00eh,0feh,020h,00eh,0feh,020h,00eh,0feh,020h,00eh,0feh	; 70f5  /9.. .. .. .. ..
	defb 020h,00eh,0feh,020h,00eh,0feh,020h,00eh,0feh,020h,040h,0feh,060h,043h,0ffh,030h	; 7105   .. .. .. @.`C.0
	defb 039h,00eh,0feh,020h,00eh,0feh,020h,00eh,0feh,01fh,00eh,00eh,0feh,020h,00eh,00eh	; 7115  9.. .. ...... ..
	defb 0feh,020h,00eh,0feh,020h,00eh,0feh,020h,00eh,0feh,020h,040h,0ffh	; 7125  . .. .. .. @.

; ----------------------------------------------------------------------
; DATOS tabla_de_guiones_relativos: 15 punteros; acaba en 0x7150, que es su
;   entrada mas baja
;   0x7132..0x7150  (30 bytes)
DATA_tabla_de_guiones_relativos:
	defw 07150h,07169h,07182h,0719ah,071aeh,071c6h,071e2h,071fdh	; 7132
	defw 0721eh,0723dh,07262h,0728bh,072b6h,072e0h,07306h	; 7142

; ----------------------------------------------------------------------
; DATOS guiones_relativos: 478 B: los quince guiones que lee L_676E, con 0xFE
;   para saltar en relativo y 0xFF para cerrar
;   0x7150..0x732e  (478 bytes)
DATA_guiones_relativos:
	defb 024h,03ah,06dh,06eh,0feh,021h,06fh,069h,041h,070h,071h,072h,073h,06ah,06bh,0feh	; 7150  $:mn.!oiApqrsjk.
	defb 027h,074h,075h,076h,06ch,0ffh,083h,034h,031h,024h,03ah,077h,078h,079h,0feh,024h	; 7160  'tuvl..41$:wxy.$
	defb 07ah,07bh,07ch,0feh,022h,07dh,07eh,07fh,080h,081h,0feh,024h,082h,083h,0ffh,083h	; 7170  z{|."}~....$....
	defb 034h,031h,024h,03ah,084h,085h,086h,0feh,025h,087h,0feh,020h,088h,089h,08ah,08bh	; 7180  41$:....%.. ....
	defb 0feh,023h,08ch,08dh,08eh,08fh,0ffh,086h,038h,034h,025h,03ah,090h,091h,0feh,044h	; 7190  .#......84%:...D
	defb 092h,093h,094h,0feh,022h,095h,096h,097h,098h,099h,0ffh,089h,03ah,036h,026h,03ah	; 71a0  ....".......:6&:
	defb 09ah,09bh,0feh,024h,09ch,09dh,09eh,0feh,022h,09fh,0a0h,0ffh,08bh,042h,000h,081h	; 71b0  ...$...."....B..
	defb 040h,094h,099h,06ah,098h,000h,0e7h,039h,0abh,0ach,0adh,0feh,024h,0a9h,0aah,0abh	; 71c0  @..j...9....$...
	defb 0feh,022h,0a2h,0a1h,0feh,062h,0a6h,0ffh,07ah,04bh,000h,071h,04bh,09ch,08fh,074h	; 71d0  ."...b..zK.qK..t
	defb 0a8h,000h,0c7h,039h,0aeh,0afh,0b0h,0feh,024h,0b1h,0b2h,0b3h,0feh,0a4h,0a6h,0ffh	; 71e0  ...9....$.......
	defb 06fh,04bh,000h,068h,04bh,0a0h,07fh,066h,0a4h,08fh,06ah,0ach,000h,0aah,039h,0e2h	; 71f0  oK.hK..f..j...9.
	defb 0b4h,0feh,021h,0b5h,0b6h,0feh,021h,0b7h,0b8h,0feh,021h,0ach,0adh,0feh,021h,0a3h	; 7200  ..!...!...!...!.
	defb 0feh,061h,0a6h,0ffh,076h,04ch,001h,05ch,040h,0b0h,08fh,072h,0b8h,000h,08ch,039h	; 7210  .a..vL.\@..r...9
	defb 0e3h,0feh,020h,0e4h,0bah,0feh,021h,0bbh,0feh,020h,0bdh,0bch,0feh,0a2h,0a6h,0ffh	; 7220  .. ...!.. ......
	defb 071h,05bh,001h,057h,050h,0b4h,07fh,067h,0bch,08fh,072h,0c0h,000h,06ah,039h,0beh	; 7230  q[.WP..g..r..j9.
	defb 0bfh,0c0h,0feh,022h,0c1h,0c2h,0feh,021h,0c3h,0feh,020h,0c5h,0c4h,0feh,021h,0c6h	; 7240  ..."...!.. ...!.
	defb 0feh,020h,0aeh,0feh,020h,0a4h,0a5h,0feh,061h,0a6h,0ffh,068h,061h,002h,08fh,070h	; 7250  . .. ...a..ha..p
	defb 0c4h,000h,04bh,039h,0c7h,0c8h,0c9h,0feh,022h,0cah,0c9h,0feh,021h,0cbh,0feh,020h	; 7260  ..K9...."...!.. 
	defb 0cch,0feh,020h,0cdh,0b3h,0feh,020h,0ceh,0cfh,0feh,020h,0afh,0b0h,0feh,021h,0a7h	; 7270  .. ... ... ...!.
	defb 0feh,060h,0a6h,0ffh,05dh,065h,002h,08fh,070h,0c4h,000h,02ch,039h,0d0h,0feh,020h	; 7280  .`..]e..p..,9.. 
	defb 0b7h,0d1h,0feh,021h,0d2h,0d3h,0feh,021h,0d4h,0feh,020h,0cch,0feh,020h,0cdh,0b3h	; 7290  ...!...!.. .. ..
	defb 0feh,020h,0ceh,0cfh,0feh,020h,0afh,0b0h,0feh,021h,0a7h,0feh,060h,0a6h,0ffh,05ah	; 72a0  . ... ...!..`..Z
	defb 06bh,002h,08fh,070h,0c4h,000h,02dh,039h,0dah,0dbh,0feh,021h,0d9h,0feh,020h,0d8h	; 72b0  k..p..-9...!.. .
	defb 0feh,020h,0d7h,0feh,020h,0deh,0b3h,0feh,020h,0ceh,0cfh,0feh,020h,0d6h,0d5h,0feh	; 72c0  . .. ... ... ...
	defb 021h,0b1h,0feh,020h,0a7h,0feh,060h,0a6h,0ffh,044h,070h,003h,08fh,070h,0c4h,000h	; 72d0  !.. ..`..Dp..p..
	defb 02fh,039h,0dch,0feh,020h,0dch,0feh,020h,0dch,0feh,020h,0dch,0feh,020h,0dch,0feh	; 72e0  /9.. .. .. .. ..
	defb 020h,0dch,0feh,020h,0dch,0feh,020h,0b1h,0feh,020h,0a7h,0feh,060h,0a6h,0ffh,044h	; 72f0   .. .. .. ..`..D
	defb 078h,003h,08fh,070h,0c4h,000h,030h,039h,0e1h,0feh,020h,0e1h,0feh,020h,0dch,0feh	; 7300  x..p..09.. .. ..
	defb 01fh,0e0h,0ddh,0feh,020h,0ceh,0cfh,0feh,020h,0deh,0feh,020h,0dfh,0feh,020h,0b2h	; 7310  .... ... .. .. .
	defb 0feh,020h,0a8h,0ffh,045h,081h,003h,08fh,070h,0cch,09fh,078h,0c8h,000h	; 7320  . ..E...p..x..

; ======================================================================
; CODIGO 0x732e..0x7346  (24 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; SENO Y COSENO. La tabla de 0x7346 son noventa valores de 0 a 0xFF que crecen cada vez mas despacio: es el seno de 0 a 89 grados, con 0xFF por uno. El 30 vale 0x80, el 45 vale 0xB5 y el 60 vale 0xDD -128, 181 y 221 sobre 255, contra los 127,5, 180,3 y 220,8 de verdad-. Y el coseno no necesita tabla propia: es la misma leida por 90 menos el angulo, que es lo que hace la de abajo.
; ----------------------------------------------------------------------
seno:		; la tabla de 0x7346, indexada por el angulo
	push hl			;732e
	ld hl,07346h		;732f   ; la tabla del seno
	call suma_a_hl		;7332
	ld a,(hl)			;7335   ; el seno del angulo
	pop hl			;7336
	ret			;7337
coseno:		; la misma tabla, leida al reves
	push hl			;7338
	sub 05ah		;7339   ; noventa menos el angulo
	neg		;733b   ; y en positivo: eso es el coseno
	ld hl,07346h		;733d
	call suma_a_hl		;7340
	ld a,(hl)			;7343
	pop hl			;7344
	ret			;7345

; ----------------------------------------------------------------------
; DATOS tabla_de_noventa: 90 valores, leidos por 0x732F con el indice y por
;   0x733D con 90 menos el indice
;   0x7346..0x73a0  (90 bytes)
DATA_tabla_de_noventa:
	defb 000h,004h,008h,00dh,011h,016h,01ah,01fh,023h,028h,02ch,030h,035h,039h,03dh	; 7346  ........#(,059=
	defb 042h,046h,04ah,04fh,053h,057h,05bh,05fh,064h,068h,06ch,070h,074h,078h,07ch	; 7355  BFJOSW[_dhlptx|
	defb 080h,083h,087h,08bh,08fh,092h,096h,09ah,09dh,0a1h,0a4h,0a7h,0abh,0aeh,0b1h	; 7364  ...............
	defb 0b5h,0b8h,0bbh,0beh,0c1h,0c4h,0c6h,0c9h,0cch,0cfh,0d1h,0d4h,0d6h,0d9h,0dbh	; 7373  ...............
	defb 0ddh,0dfh,0e2h,0e4h,0e6h,0e8h,0e9h,0ebh,0edh,0eeh,0f0h,0f2h,0f3h,0f4h,0f6h	; 7382  ...............
	defb 0f7h,0f8h,0f9h,0fah,0fbh,0fch,0fch,0fdh,0feh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; 7391  ...............

; ======================================================================
; CODIGO 0x73a0..0x757d  (477 bytes)
; ======================================================================


multiplica_8x8:		; HL = H por E
	ld l,000h		;73a0
	ld d,l			;73a2
	ld b,008h		;73a3   ; ocho bits
L_73A5:
	add hl,hl			;73a5   ; el resultado, por dos
	jr nc,L_73A9		;73a6
	add hl,de			;73a8   ; y con el bit puesto, se suma
L_73A9:
	djnz L_73A5		;73a9
	ret			;73ab
multiplica_8x16:		; HL:C = A por BC
	ld e,b			;73ac
	ld d,c			;73ad
	ld hl,00000h		;73ae
	ld c,l			;73b1
	ld b,008h		;73b2   ; ocho bits
L_73B4:
	add hl,hl			;73b4
	rl c		;73b5
	add a,a			;73b7   ; el multiplicador, bit a bit
	jr nc,L_73BB		;73b8
	add hl,de			;73ba
L_73BB:
	djnz L_73B4		;73bb
	ld l,c			;73bd
	ret			;73be
divide_16:		; DE entre BC, con el resto en HL
	ld hl,00000h		;73bf
	exx			;73c2
	ld b,010h		;73c3   ; dieciseis bits
L_73C5:
	exx			;73c5
	sla e		;73c6   ; el dividendo, por dos, y el bit de arriba al resto
	rl d		;73c8
	adc hl,hl		;73ca
	sbc hl,bc		;73cc   ; contra el divisor
	jr c,L_73D3		;73ce   ; si no cabe, se devuelve
	inc e			;73d0   ; y si cabe, un bit al cociente
	jr L_73D4		;73d1
L_73D3:
	add hl,bc			;73d3
L_73D4:
	exx			;73d4
	djnz L_73C5		;73d5
	exx			;73d7
	ret			;73d8

; ----------------------------------------------------------------------
; Monta la pantalla que comparten el triple salto y la pertiga. En medio pasa lo mas curioso del cartucho: se descomprime un dibujo a la RAM y ALLI se desplaza cuatro pixeles a mano, rotando los bits de doce tiles seguidos, y las dos versiones -la del sitio y la corrida- se suben a la VRAM. Es lo que permite que la pista se mueva de medio tile en medio tile en vez de a saltos de ocho pixeles.
; ----------------------------------------------------------------------
monta_la_pista_del_salto:		; la pantalla del triple salto y la pertiga
	ld de,075abh		;73d9   ; los patrones de la pista
	ld hl,02748h		;73dc
	call descomprime_a_vram_en		;73df
	ld de,0760ah		;73e2   ; su color
	ld hl,00748h		;73e5
	call descomprime_a_vram_en		;73e8
	ld de,07631h		;73eb   ; y otro juego mas
	ld hl,01200h		;73ee
	call descomprime_a_vram_en		;73f1
	ld de,076c7h		;73f4   ; dos tercios nada mas
	ld hl,02220h		;73f7
	ld b,002h		;73fa
	call L_4407		;73fc
	ld de,0775fh		;73ff
	ld hl,00200h		;7402
	ld b,002h		;7405
	call L_4407		;7407
	ld de,0785dh		;740a   ; las casillas
	call descomprime_a_vram		;740d
	ld hl,0785fh		;7410   ; el dibujo que se desplaza, descomprimido a la RAM
	ld de,0e320h		;7413
	call descomprime_a_la_ram_en		;7416
	ld d,002h		;7419   ; dos bloques
	ld ix,0e320h		;741b   ; el primero
L_741F:
	ld c,008h		;741f   ; ocho filas de patron
L_7421:
	ld b,004h		;7421   ; cuatro pixeles
L_7423:
	sla (ix+058h)		;7423   ; los bits salen por arriba del ultimo tile
	rl (ix+050h)		;7427   ; y van entrando en el anterior
	rl (ix+048h)		;742b
	rl (ix+040h)		;742f
	rl (ix+038h)		;7433
	rl (ix+030h)		;7437
	rl (ix+028h)		;743b
	rl (ix+020h)		;743f
	rl (ix+018h)		;7443
	rl (ix+010h)		;7447
	rl (ix+008h)		;744b
	rl (ix+000h)		;744f   ; hasta el primero: doce tiles seguidos corridos a la vez
	djnz L_7423		;7453   ; cuatro veces, o sea cuatro pixeles
	inc ix		;7455   ; la fila siguiente del patron
	dec c			;7457
	jr nz,L_7421		;7458
	ld bc,00058h		;745a   ; y el bloque siguiente
	add ix,bc		;745d
	dec d			;745f
	jr nz,L_741F		;7460
	ld hl,02b90h		;7462   ; las dos versiones, a la VRAM
	ld de,0e320h		;7465
	ld bc,000c0h		;7468
	call ldirvm		;746b
	ld hl,00ad0h		;746e   ; su color
	ld bc,00180h		;7471
	ld a,0feh		;7474
	call 00056h		;7476   ; BIOS FILVRM - Fills VRAM with value
	ld hl,07818h		;7479   ; otro bloque a la RAM
	call descomprime_a_la_ram		;747c
	ld de,079fbh		;747f
	call descomprime_a_vram		;7482
	ld de,084efh		;7485
	call descomprime_a_vram		;7488
	ld de,07671h		;748b
	call descomprime_a_vram		;748e
	ld de,0799eh		;7491
	call es_la_pertiga		;7494   ; el liston, en el triple salto no
	jr z,L_749C		;7497
	ld de,079cfh		;7499   ; y en la pertiga si
L_749C:
	call descomprime_a_vram		;749c
	call marcador_de_intentos		;749f   ; el marcador de intentos
	ld a,(0e09eh)		;74a2   ; si la prueba ya iba empezada
	or a			;74a5
	push af			;74a6
	call nz,L_556B		;74a7   ; se recupera donde estaba
	pop af			;74aa
	call z,rotulo_del_record_del_mundo		;74ab   ; y si no, el record del mundo
	jp pinta_el_suelo		;74ae   ; y el suelo

; ----------------------------------------------------------------------
; El TERCER descompresor: el mismo formato RLE de siempre, pero escribiendo en la RAM en vez de en el VDP, y con el destino en los dos primeros bytes del bloque. Solo lo usa el bloque de 0x7818, que va a parar a 0xE320.
; ----------------------------------------------------------------------
descomprime_a_la_ram:		; el RLE, pero a la RAM y no al VDP
	ld e,(hl)			;74b1   ; el destino, de la cabecera
	inc hl			;74b2
	ld d,(hl)			;74b3
	inc hl			;74b4
descomprime_a_la_ram_en:		; el mismo, con el destino ya en DE
	ld a,(hl)			;74b5
	and 07fh		;74b6   ; el mandato, sin su bit 7
	ret z			;74b8   ; el 0 cierra
	ld c,a			;74b9
	ld a,(hl)			;74ba
	inc hl			;74bb
	cp c			;74bc   ; si no ha cambiado es que no tenia el bit: repeticion
	jr z,L_74C5		;74bd
	ld b,000h		;74bf
	ldir		;74c1   ; y si lo tenia, se copian tal cual
	jr descomprime_a_la_ram_en		;74c3
L_74C5:
	ld b,c			;74c5
	ld a,(hl)			;74c6   ; el byte que se repite
	inc hl			;74c7
L_74C8:
	ld (de),a			;74c8
	inc de			;74c9
	djnz L_74C8		;74ca
	jr descomprime_a_la_ram_en		;74cc
marcador_de_intentos:		; las marcas y los intentos que quedan
	call es_la_pertiga		;74ce   ; en el triple salto es otro
	jr z,pinta_las_tres_marcas		;74d1
	call apunta_al_jugador_de_turno		;74d3   ; el liston por el que va el jugador
	inc hl			;74d6
	inc hl			;74d7
	ld a,(0e06ah)		;74d8
	cp 003h		;74db
	ld a,(hl)			;74dd
	jr z,L_74E5		;74de
	sub 001h		;74e0
	jr nz,L_74E5		;74e2
	inc a			;74e4
L_74E5:
	call marca_del_liston		;74e5   ; su altura
	ld (0e174h),de		;74e8
	ld de,0e175h		;74ec
	ld hl,03836h		;74ef
	call escribe_una_marca		;74f2   ; escrita con su punto decimal
pinta_los_intentos_que_quedan:		; un tile por cada uno
	call apunta_al_jugador_de_turno		;74f5
	ld a,003h		;74f8   ; de tres
	sub (hl)			;74fa   ; menos los gastados
	ret z			;74fb   ; sin ninguno, no hay nada que pintar
	ld b,a			;74fc
	ld a,0f2h		;74fd   ; el tile de la marquita
	ld hl,03878h		;74ff
L_7502:
	call 0004dh		;7502   ; BIOS WRTVRM - Writes data in VRAM | y una casilla si y otra no
	inc hl			;7505
	inc hl			;7506
	djnz L_7502		;7507
	ret			;7509
pinta_las_tres_marcas:		; las tres del jugador de turno
	call apunta_al_jugador_de_turno		;750a   ; las del jugador 1
	ld de,0e115h		;750d
	jr z,L_7514		;7510
	ld e,01dh		;7512   ; o las del 2
L_7514:
	ld b,003h		;7514   ; tres
	ld hl,03878h		;7516
L_7519:
	push bc			;7519
	push hl			;751a
	push de			;751b
	ld a,(de)			;751c   ; la marca
	or a			;751d
	jr z,L_7558		;751e   ; sin marca, nada
	inc a			;7520   ; la de 0xFF es la que no se dio
	jr z,L_7528		;7521
	call escribe_una_marca		;7523   ; y la buena se escribe con su punto
	jr L_7558		;7526
L_7528:
	ld de,06e0eh		;7528   ; el guion del intento fallado
	ld c,0ffh		;752b
	call L_441D		;752d
	ld a,(0e000h)		;7530   ; si esto no es la escena 5
	cp 005h		;7533
	jr nz,L_7558		;7535
	ld a,(0e165h)		;7537   ; si el ultimo salto valio
	inc a			;753a
	jr nz,L_7558		;753b
	ld a,(0e177h)		;753d   ; y si ya sono
	or a			;7540
	jr nz,L_7558		;7541
	ld a,016h		;7543   ; la musica del fallo
	call arranca_una_pista		;7545
	ld hl,039edh		;7548   ; el rotulo
	ld de,06e0eh		;754b
	ld c,0ffh		;754e
	call L_441D		;7550
	ld a,001h		;7553
	ld (0e177h),a		;7555   ; y que no suene otra vez
L_7558:
	pop de			;7558
	dec de			;7559   ; la marca de arriba
	dec de			;755a
	pop hl			;755b
	ld bc,00020h		;755c   ; y una fila mas arriba
	or a			;755f
	sbc hl,bc		;7560
	pop bc			;7562
	djnz L_7519		;7563
	ret			;7565

; ----------------------------------------------------------------------
; Asi se escribe una marca: dos cifras en BCD, los dos tiles del punto decimal -el 0x1E y el 0x1F, que juntos hacen la coma- y otras dos cifras. Es lo que convierte los 0x1789 de la tabla en el 17.89 que se lee en la pantalla.
; ----------------------------------------------------------------------
escribe_una_marca:		; dos cifras, el punto y dos cifras
	ld b,001h		;7566   ; las dos primeras cifras
	call escribe_cifras_bcd		;7568
	inc hl			;756b
	inc hl			;756c
	ld a,01eh		;756d   ; el punto decimal, en dos tiles
	call 0004dh		;756f   ; BIOS WRTVRM - Writes data in VRAM
	inc hl			;7572
	inc a			;7573
	call 0004dh		;7574   ; BIOS WRTVRM - Writes data in VRAM
	inc hl			;7577
	ld b,001h		;7578   ; y las dos ultimas
	jp escribe_cifras_bcd		;757a

; ----------------------------------------------------------------------
; DATOS marcas_del_triple_salto: 8 words en BCD: 13.00, 14.00, 15.00, 16.00,
;   17.00, 17.89, 18.00 y 20.00 metros
;   0x757d..0x758d  (16 bytes)
DATA_marcas_del_triple_salto:
	defw 01300h,01400h,01500h,01600h,01700h,01789h,01800h,02000h	; 757d

; ----------------------------------------------------------------------
; DATOS marcas_de_la_pertiga: 10 words en BCD: de 5.65 a 5.94 metros
;   0x758d..0x75a1  (20 bytes)
DATA_marcas_de_la_pertiga:
	defw 00565h,00570h,00575h,00580h,00585h,00590h,00591h,00592h	; 758d
	defw 00593h,00594h	; 759d

; ----------------------------------------------------------------------
; DATOS guion_qualify: 10 B: QUALIFY en 0x3824
;   0x75a1..0x75ab  (10 bytes)
DATA_guion_qualify:
	defb 024h,038h,031h,035h,021h,02ch,029h,026h,039h,0ffh	; 75a1  $815!,)&9.

; ----------------------------------------------------------------------
; DATOS rle_patrones_de_la_pista: 95 B -> 168 de VRAM; lo cargan 0x5426 (en
;   0x2200) y 0x73DF (en 0x2748)
;   0x75ab..0x760a  (95 bytes)
DATA_rle_patrones_de_la_pista:
	defb 003h,000h,002h,0ffh,006h,000h,002h,03fh,006h,000h,083h,01ch,03ch,038h,00ch,030h	; 75ab  .......?....<8.0
	defb 083h,038h,03fh,01fh,006h,000h,083h,0f8h,0fch,01ch,00ch,00ch,083h,01ch,0fch,0f8h	; 75bb  .8?.............
	defb 003h,000h,082h,03ch,042h,004h,081h,084h,042h,03ch,03ch,07eh,004h,0ffh,096h,07eh	; 75cb  ...<B...B<<~...~
	defb 03ch,03ch,042h,099h,0bdh,0bdh,099h,042h,03ch,081h,042h,024h,018h,018h,024h,042h	; 75db  <<B....B<.B$..$B
	defb 081h,000h,000h,0ffh,0ffh,010h,03ch,087h,0ffh,0ffh,000h,000h,0c0h,080h,01fh,012h	; 75eb  ......<.........
	defb 00fh,086h,01fh,080h,0c0h,003h,001h,0f8h,012h,0f0h,083h,0f8h,001h,003h,000h	; 75fb  ...............

; ----------------------------------------------------------------------
; DATOS rle_color_de_la_pista: 39 B -> 184 de VRAM; el color de los mismos, en
;   0x0200 o en 0x0748
;   0x760a..0x7631  (39 bytes)
DATA_rle_color_de_la_pista:
	defb 048h,0f0h,018h,060h,004h,0feh,010h,0f0h,004h,0feh,002h,05eh,002h,0feh,010h,00eh	; 760a  H..`.......^....
	defb 002h,0feh,004h,05eh,002h,0feh,010h,00eh,002h,0feh,002h,05eh,002h,0eeh,002h,0ffh	; 761a  ...^.......^....
	defb 008h,011h,002h,0ffh,002h,0eeh,000h	; 762a

; ----------------------------------------------------------------------
; DATOS rle_patrones_7631: 39 B -> 40 de VRAM en 0x1200, o sea patrones de
;   SPRITE
;   0x7631..0x7658  (39 bytes)
DATA_rle_patrones_7631:
	defb 08bh,0cch,0cch,033h,0cch,033h,033h,0cch,033h,033h,033h,0cch,004h,033h,081h,0cch	; 7631  ...3.33.333..3..
	defb 005h,033h,093h,099h,088h,099h,0a9h,0a9h,069h,00fh,00fh,009h,009h,009h,00fh,00fh	; 7641  .3......i.......
	defb 009h,0a9h,069h,0a9h,079h,069h,000h	; 7651

; ----------------------------------------------------------------------
; DATOS rle_patrones_7658: 20 B -> 24 de VRAM en los tres tercios desde 0x2030
;   0x7658..0x766c  (20 bytes)
DATA_rle_patrones_7658:
	defb 002h,000h,006h,001h,083h,000h,000h,0ffh,004h,001h,084h,0ffh,000h,000h,0ffh,004h	; 7658  ................
	defb 001h,081h,0ffh,000h	; 7668

; ----------------------------------------------------------------------
; DATOS rle_color_7658: 5 B -> las mismas 24 posiciones en 0x0030
;   0x766c..0x7671  (5 bytes)
DATA_rle_color_7658:
	defb 013h,0f0h,005h,0fah,000h	; 766c

; ----------------------------------------------------------------------
; DATOS rle_7671: 66 B -> 160 de VRAM; lo carga 0x748B al montar la pista del
;   triple salto y de la pertiga, detras del liston y de las colchonetas
;   0x7671..0x76b3  (66 bytes)
DATA_rle_7671:
	defb 000h,038h,082h,005h,0f8h,00fh,0feh,081h,0f5h,00ch,0feh,085h,0fbh,005h,005h,0f9h	; 7671  .8..............
	defb 0ebh,00ch,000h,083h,0eah,0eeh,0f6h,00ch,000h,085h,0fch,005h,005h,0f9h,0ech,00dh	; 7681  ................
	defb 000h,082h,0efh,0f6h,00ch,000h,085h,0fch,005h,005h,0f9h,0edh,00dh,0e9h,082h,0f0h	; 7691  ................
	defb 0f6h,00ch,000h,084h,0fch,005h,005h,0fah,00fh,0ffh,081h,0f7h,00ch,0ffh,082h,0fdh	; 76a1  ................
	defb 005h,000h	; 76b1

; ----------------------------------------------------------------------
; DATOS rle_speed: 20 B -> 30 casillas de la tabla de nombres: el rotulo SPEED
;   del marcador
;   0x76b3..0x76c7  (20 bytes)
DATA_rle_speed:
	defb 0e1h,03ah,086h,033h,030h,025h,025h,024h,006h,00fh,007h,004h,010h,085h,03bh,03ch	; 76b3  .:.30%%$......;<
	defb 03dh,03eh,03fh,000h	; 76c3

; ----------------------------------------------------------------------
; DATOS rle_patrones_76c7: 152 B -> 176 de VRAM en DOS tercios desde 0x2220
;   (L_4407 con B=2)
;   0x76c7..0x775f  (152 bytes)
DATA_rle_patrones_76c7:
	defb 00dh,000h,003h,03ch,002h,000h,003h,060h,08dh,000h,0c0h,0c0h,000h,000h,081h,0bdh	; 76c7  ...<...`........
	defb 081h,0bdh,081h,0bdh,000h,000h,003h,003h,087h,000h,006h,006h,0c0h,0a0h,050h,000h	; 76d7  ..............P.
	defb 004h,030h,08ch,081h,0bdh,081h,0bdh,081h,0bdh,081h,0bdh,006h,004h,00bh,000h,004h	; 76e7  .0..............
	defb 006h,082h,030h,000h,004h,060h,08ch,020h,0d0h,081h,0bdh,081h,0bdh,081h,0bdh,081h	; 76f7  ..0..`. ........
	defb 0bdh,006h,000h,004h,003h,082h,009h,006h,005h,000h,003h,003h,005h,000h,003h,0c0h	; 7707  ................
	defb 002h,000h,090h,008h,00bh,008h,0fbh,008h,00bh,000h,000h,010h,0d0h,010h,0dfh,010h	; 7717  ................
	defb 0d0h,000h,000h,003h,036h,097h,000h,06ch,06ch,0f8h,0fbh,0f8h,0fbh,008h,00bh,008h	; 7727  ....6..ll.......
	defb 00bh,01fh,0dfh,01fh,0dfh,010h,0d0h,010h,0d0h,06ch,04ah,0b5h,000h,004h,063h,092h	; 7737  .........lJ...c.
	defb 0f8h,0fbh,008h,00bh,008h,00bh,0f8h,0fbh,01fh,0dfh,010h,0d0h,010h,0d0h,01fh,0dfh	; 7747  ................
	defb 063h,000h,004h,036h,082h,092h,06dh,000h	; 7757  c..6..m.

; ----------------------------------------------------------------------
; DATOS rle_color_76c7: 185 B -> 208 de VRAM en dos tercios desde 0x0200
;   0x775f..0x7818  (185 bytes)
DATA_rle_color_76c7:
	defb 002h,00ah,098h,00eh,06eh,03eh,004h,00eh,0aeh,0a2h,065h,065h,00ch,00eh,0aeh,06eh	; 775f  ....n>....ee...n
	defb 06eh,062h,00ch,00eh,09eh,0aeh,0feh,067h,067h,0ffh,0ffh,006h,0eeh,082h,009h,006h	; 776f  nb.....gg.......
	defb 003h,000h,002h,005h,083h,004h,009h,006h,003h,000h,002h,005h,08bh,004h,00ah,00ah	; 777f  ................
	defb 00eh,06eh,07eh,004h,00eh,0aeh,00ah,00ah,006h,04eh,002h,00ah,092h,00eh,06eh,07eh	; 778f  .n~......N....n~
	defb 004h,00eh,0aeh,0a2h,065h,065h,00ch,00eh,0aeh,06eh,06eh,02eh,05eh,05eh,0ceh,004h	; 779f  ....ee...nn.^^..
	defb 05eh,092h,0a2h,065h,065h,00ch,00eh,0aeh,06eh,06eh,062h,00ch,00eh,09eh,0aeh,0feh	; 77af  ^..ee...nnb.....
	defb 067h,067h,02eh,0ceh,006h,07eh,08ah,062h,00ch,00eh,09eh,0aeh,0feh,067h,067h,009h	; 77bf  gg...~.b.....gg.
	defb 006h,003h,000h,002h,005h,083h,004h,009h,006h,003h,000h,002h,005h,083h,004h,00ah	; 77cf  ................
	defb 00ah,006h,04eh,002h,00ah,006h,04eh,002h,00ah,08ah,00eh,06eh,07eh,004h,00eh,0aeh	; 77df  ..N...N....n~...
	defb 02eh,05eh,05eh,0ceh,004h,05eh,084h,02eh,05eh,05eh,0ceh,004h,05eh,08ah,0a2h,065h	; 77ef  .^^..^..^^..^..e
	defb 065h,00ch,00eh,0aeh,06eh,06eh,02eh,0ceh,006h,07eh,082h,02eh,0ceh,006h,07eh,088h	; 77ff  e...nn...~....~.
	defb 062h,00ch,00eh,09eh,0aeh,0feh,067h,067h,000h	; 780f  b.....gg.

; ----------------------------------------------------------------------
; DATOS rle_a_ram_e320: 69 B -> 80 bytes de RAM desde 0xE320; el destino son
;   sus dos primeros bytes y lo descomprime L_74B1, que escribe en memoria y
;   no en la VRAM
;   0x7818..0x785d  (69 bytes)
DATA_rle_a_ram_e320:
	defb 020h,0e3h,08ch,000h,000h,063h,063h,063h,000h,0c6h,0c6h,0c6h,0a4h,05bh,000h,005h	; 7818   ....ccc.....[..
	defb 036h,081h,000h,004h,063h,08eh,029h,0d6h,000h,000h,036h,036h,036h,000h,06ch,06ch	; 7828  6...c.)...666.ll
	defb 06ch,04ah,0b5h,000h,005h,063h,081h,000h,004h,036h,082h,092h,06dh,083h,040h,004h	; 7838  lJ...c...6..m.@.
	defb 020h,008h,000h,088h,004h,008h,040h,010h,001h,004h,040h,002h,008h,000h,085h,040h	; 7848   .....@...@....@
	defb 080h,004h,001h,010h,000h	; 7858

; ----------------------------------------------------------------------
; DATOS rle_785d: 136 B -> 192 de VRAM
;   0x785d..0x78e5  (136 bytes)
DATA_rle_785d:
	defb 0d0h,02ah,009h,000h,081h,07eh,006h,018h,08ah,000h,07eh,063h,063h,062h,07ch,066h	; 785d  .*...~....~ccb|f
	defb 063h,000h,03ch,005h,018h,083h,03ch,000h,07eh,003h,063h,084h,07eh,060h,060h,000h	; 786d  c.<...<.~.c.~``.
	defb 006h,060h,089h,07fh,000h,07fh,060h,060h,07eh,060h,060h,07fh,009h,000h,081h,01fh	; 787d  .`....``~``.....
	defb 004h,006h,083h,066h,03ch,000h,006h,063h,08bh,03eh,000h,063h,077h,07fh,07fh,06bh	; 788d  ...f<..c.>.cw..k
	defb 063h,063h,000h,07eh,003h,063h,083h,07eh,060h,060h,009h,000h,081h,07eh,003h,063h	; 789d  cc.~.c.~``...~.c
	defb 085h,07eh,060h,060h,000h,03eh,005h,063h,082h,03eh,000h,006h,060h,089h,07fh,000h	; 78ad  .~``.>.c.>..`...
	defb 07fh,060h,060h,07eh,060h,060h,07fh,009h,000h,004h,063h,08ch,036h,01ch,008h,000h	; 78bd  .``~``....c.6...
	defb 01ch,036h,063h,063h,07fh,063h,063h,000h,006h,063h,082h,03eh,000h,006h,060h,083h	; 78cd  .6cc.cc..c.>..`.
	defb 07fh,000h,07eh,006h,018h,008h,000h,000h	; 78dd  ..~.....

; ----------------------------------------------------------------------
; DATOS rle_color_78e5: 185 B -> 208 de VRAM en dos tercios desde 0x0200; es
;   la ALTERNATIVA a 0x775F, y elige el bit 1 de (0xE003)
;   0x78e5..0x799e  (185 bytes)
DATA_rle_color_78e5:
	defb 002h,00ah,08ch,002h,062h,032h,004h,002h,0a2h,0a2h,065h,065h,00ch,002h,0a2h,003h	; 78e5  ....b2....ee....
	defb 062h,089h,00ch,002h,092h,0a2h,0f2h,067h,067h,0ffh,0ffh,006h,0eeh,082h,009h,006h	; 78f5  b......gg.......
	defb 003h,000h,002h,005h,083h,004h,009h,006h,003h,000h,002h,005h,08bh,004h,00ah,00ah	; 7905  ................
	defb 002h,062h,072h,004h,002h,0a2h,00ah,00ah,006h,042h,002h,00ah,092h,002h,062h,072h	; 7915  .br......B....br
	defb 004h,002h,0a2h,0a2h,065h,065h,00ch,002h,0a2h,062h,062h,022h,052h,052h,0c2h,004h	; 7925  ....ee...bb"RR..
	defb 052h,086h,0a2h,065h,065h,00ch,002h,0a2h,003h,062h,089h,00ch,002h,092h,0a2h,0f2h	; 7935  R..ee....b......
	defb 067h,067h,022h,0c2h,006h,072h,08ah,062h,00ch,002h,092h,0a2h,0f2h,067h,067h,009h	; 7945  gg"..r.b.....gg.
	defb 006h,003h,000h,002h,005h,083h,004h,009h,006h,003h,000h,002h,005h,083h,004h,00ah	; 7955  ................
	defb 00ah,006h,042h,002h,00ah,006h,042h,002h,00ah,08ah,002h,062h,072h,004h,002h,0a2h	; 7965  ..B...B....br...
	defb 022h,052h,052h,0c2h,004h,052h,084h,022h,052h,052h,0c2h,004h,052h,08ah,0a2h,065h	; 7975  "RR..R."RR..R..e
	defb 065h,00ch,002h,0a2h,062h,062h,022h,0c2h,006h,072h,082h,022h,0c2h,006h,072h,088h	; 7985  e...bb"..r."..r.
	defb 062h,00ch,002h,092h,0a2h,0f2h,067h,067h,000h	; 7995  b.....gg.

; ----------------------------------------------------------------------
; DATOS rle_799e: 49 B -> 582 de VRAM en cuatro tramos
;   0x799e..0x79cf  (49 bytes)
DATA_rle_799e:
	defb 036h,038h,082h,011h,01bh,080h,056h,038h,082h,012h,01ch,080h,076h,038h,082h,013h	; 799e  68....V8....v8..
	defb 01dh,080h,0a0h,038h,060h,005h,040h,005h,020h,044h,020h,040h,020h,041h,020h,042h	; 79ae  ...8`.@. D @ A B
	defb 020h,043h,040h,00eh,020h,040h,020h,041h,020h,042h,020h,043h,020h,009h,020h,044h	; 79be   C@. @ A B C . D
	defb 000h	; 79ce

; ----------------------------------------------------------------------
; DATOS rle_79cf: 44 B -> 587 de VRAM en dos tramos; la alternativa a 0x799E,
;   y elige L_5F0F
;   0x79cf..0x79fb  (44 bytes)
DATA_rle_79cf:
	defb 072h,038h,08bh,026h,021h,035h,02ch,034h,000h,0f1h,000h,0f1h,000h,0f1h,080h,0a0h	; 79cf  r8.&!5,4........
	defb 038h,020h,044h,020h,040h,020h,041h,020h,043h,060h,00eh,060h,00eh,040h,00eh,020h	; 79df  8 D @ A C`.`.@. 
	defb 040h,020h,041h,020h,042h,020h,043h,020h,009h,020h,044h,000h	; 79ef  @ A B C . D.

; ----------------------------------------------------------------------
; DATOS rle_pantalla_del_salto: 2151 B -> 4048 de VRAM en SEIS tramos: el
;   bloque mas gordo del cartucho
;   0x79fb..0x8262  (2151 bytes)
DATA_rle_pantalla_del_salto:
	defb 098h,02ch,003h,000h,005h,00fh,003h,000h,005h,00fh,003h,000h,005h,00fh,003h,000h	; 79fb  .,..............
	defb 005h,00fh,003h,000h,005h,00fh,003h,000h,005h,00fh,003h,000h,005h,00fh,081h,000h	; 7a0b  ................
	defb 007h,00fh,081h,000h,007h,00fh,081h,000h,007h,00fh,081h,000h,007h,00fh,081h,000h	; 7a1b  ................
	defb 007h,00fh,081h,000h,007h,00fh,081h,000h,057h,00fh,005h,000h,002h,0ffh,006h,000h	; 7a2b  ........W.......
	defb 002h,0ffh,081h,001h,006h,000h,002h,0ffh,002h,000h,002h,07fh,006h,000h,083h,0fch	; 7a3b  ................
	defb 0ffh,007h,006h,000h,089h,0f0h,0ffh,01fh,001h,000h,0fch,01fh,007h,001h,006h,000h	; 7a4b  ................
	defb 086h,0c0h,0f0h,078h,01eh,007h,003h,007h,000h,081h,080h,005h,000h,086h,080h,0e0h	; 7a5b  ...x............
	defb 078h,01eh,007h,001h,006h,000h,089h,080h,0e0h,070h,038h,01ch,00eh,007h,003h,001h	; 7a6b  x........p8.....
	defb 006h,000h,088h,080h,0c0h,0e0h,070h,038h,018h,00ch,00ch,003h,000h,002h,07fh,008h	; 7a7b  ......p8........
	defb 000h,08eh,080h,0c0h,0e0h,070h,030h,038h,01ch,00ch,00eh,006h,007h,000h,080h,080h	; 7a8b  .....p08........
	defb 004h,0c0h,085h,060h,003h,003h,001h,001h,007h,000h,002h,001h,006h,000h,084h,0e0h	; 7a9b  ...`............
	defb 0fch,01fh,003h,007h,000h,088h,0c0h,0f0h,038h,01ch,00eh,007h,003h,001h,006h,000h	; 7aab  ........8.......
	defb 097h,080h,0c0h,0e0h,060h,030h,038h,01ch,00ch,00eh,006h,007h,003h,080h,080h,0c0h	; 7abb  ....`08.........
	defb 0c0h,0e0h,060h,060h,070h,003h,001h,001h,005h,000h,002h,030h,08ah,038h,018h,018h	; 7acb  ..``p......0.8..
	defb 01ch,00ch,00ch,000h,00fh,00fh,001h,006h,000h,086h,0e0h,0f8h,03eh,00fh,003h,001h	; 7adb  ............>...
	defb 006h,000h,093h,080h,0c0h,0e0h,070h,038h,01ch,00eh,007h,003h,001h,0c0h,060h,060h	; 7aeb  ......p8......``
	defb 030h,030h,038h,018h,018h,01ch,003h,00ch,081h,00eh,003h,006h,081h,007h,007h,003h	; 7afb  008.............
	defb 008h,001h,008h,080h,005h,000h,090h,00ch,00eh,007h,080h,0c0h,0e0h,070h,038h,01ch	; 7b0b  .............p8.
	defb 00ch,006h,007h,003h,003h,001h,001h,005h,000h,002h,080h,002h,0c0h,087h,0e0h,060h	; 7b1b  ...............`
	defb 060h,070h,030h,030h,038h,003h,018h,004h,080h,004h,0c0h,004h,001h,004h,000h,081h	; 7b2b  `p008...........
	defb 00eh,005h,006h,086h,007h,003h,038h,018h,018h,01ch,004h,00ch,002h,0c0h,08eh,0e0h	; 7b3b  ......8.........
	defb 060h,060h,070h,030h,030h,000h,018h,01ch,00eh,007h,003h,001h,001h,006h,000h,002h	; 7b4b  ``p00...........
	defb 080h,00dh,0c0h,003h,080h,00ch,003h,081h,007h,003h,006h,004h,000h,004h,001h,008h	; 7b5b  ................
	defb 060h,003h,000h,084h,0c0h,0fch,03fh,003h,007h,000h,08ah,0c0h,0e0h,070h,038h,01ch	; 7b6b  `.....?......p8.
	defb 00eh,007h,003h,001h,000h,080h,050h,032h,079h,00fh,083h,03fh,01fh,00fh,004h,000h	; 7b7b  ......P2y..?....
	defb 081h,09fh,003h,000h,081h,00fh,003h,000h,08ch,0ffh,07fh,03fh,01fh,00fh,007h,003h	; 7b8b  ...........?....
	defb 001h,00fh,007h,003h,001h,005h,000h,084h,080h,0c0h,0e0h,0f0h,003h,000h,081h,006h	; 7b9b  ................
	defb 008h,000h,084h,07fh,03fh,01fh,00fh,003h,000h,085h,0f0h,0f8h,0fch,0feh,0ffh,004h	; 7bab  ....?...........
	defb 000h,084h,040h,000h,0f0h,0f0h,003h,000h,002h,0f0h,083h,000h,040h,080h,003h,000h	; 7bbb  ..@.........@...
	defb 084h,00fh,007h,003h,001h,004h,000h,005h,0ffh,086h,07fh,03fh,01fh,00fh,003h,001h	; 7bcb  ...........?....
	defb 005h,000h,006h,0ffh,002h,0f0h,041h,000h,081h,001h,00ah,000h,081h,001h,008h,000h	; 7bdb  ......A.........
	defb 081h,001h,008h,000h,081h,001h,008h,000h,002h,001h,008h,000h,081h,001h,008h,000h	; 7beb  ................
	defb 081h,001h,007h,000h,084h,0f0h,0ffh,01fh,001h,006h,000h,084h,0f0h,0ffh,01fh,001h	; 7bfb  ................
	defb 00ah,000h,084h,0f0h,0ffh,01fh,001h,006h,000h,084h,0f0h,0ffh,01fh,001h,006h,000h	; 7c0b  ................
	defb 084h,0f0h,0ffh,01fh,001h,006h,000h,084h,0f0h,0ffh,01fh,001h,006h,000h,084h,0f0h	; 7c1b  ................
	defb 0ffh,01fh,001h,006h,000h,084h,0f0h,0ffh,01fh,001h,006h,000h,084h,0f0h,0ffh,01fh	; 7c2b  ................
	defb 001h,006h,000h,002h,0f0h,008h,000h,002h,00fh,006h,000h,085h,080h,0f0h,0feh,01fh	; 7c3b  ................
	defb 003h,006h,000h,083h,0c0h,0f8h,07fh,005h,000h,085h,0c0h,0f8h,0ffh,00fh,001h,006h	; 7c4b  ................
	defb 000h,084h,0e0h,0fch,03fh,007h,006h,000h,085h,080h,0f0h,0feh,01fh,003h,006h,000h	; 7c5b  ....?...........
	defb 085h,0c0h,0f8h,07fh,00fh,001h,006h,000h,084h,0e0h,0fch,03fh,007h,006h,000h,085h	; 7c6b  ...........?....
	defb 080h,0f0h,0feh,01fh,003h,006h,000h,083h,0c0h,0f8h,078h,003h,000h,083h,07ch,07fh	; 7c7b  ..........x...|.
	defb 007h,006h,000h,088h,0c0h,0f8h,07eh,00fh,0f8h,07eh,00fh,003h,006h,000h,085h,080h	; 7c8b  ......~..~......
	defb 0f0h,0feh,01fh,003h,006h,000h,085h,0c0h,0f0h,07eh,01fh,003h,006h,000h,085h,0c0h	; 7c9b  .........~......
	defb 0f8h,07fh,00fh,001h,006h,000h,084h,0f0h,0ffh,01fh,001h,006h,000h,083h,0f0h,0ffh	; 7cab  ................
	defb 01fh,006h,000h,082h,080h,0f0h,004h,000h,002h,0ffh,006h,000h,088h,0c0h,0ffh,07fh	; 7cbb  ................
	defb 000h,0e0h,0feh,01fh,001h,006h,000h,084h,0c0h,0f8h,03fh,007h,007h,000h,085h,0c0h	; 7ccb  ..........?.....
	defb 0f0h,03ch,007h,001h,006h,000h,085h,080h,0e0h,07ch,01fh,003h,003h,000h,08ah,080h	; 7cdb  .<.......|......
	defb 0c0h,0e0h,070h,038h,018h,01ch,00ch,003h,001h,006h,000h,088h,060h,030h,030h,018h	; 7ceb  ..p8........`00.
	defb 018h,01ch,00ch,00eh,003h,003h,005h,001h,002h,000h,005h,080h,011h,0c0h,008h,00ch	; 7cfb  ................
	defb 083h,0fch,0ffh,007h,006h,000h,084h,0e0h,0fch,03fh,007h,006h,000h,08ah,080h,0e0h	; 7d0b  .........?......
	defb 0f8h,03eh,00fh,006h,007h,003h,001h,001h,006h,000h,002h,080h,002h,0c0h,082h,060h	; 7d1b  .>.............`
	defb 00eh,004h,006h,083h,007h,003h,003h,008h,001h,007h,080h,009h,0c0h,007h,006h,081h	; 7d2b  ................
	defb 00eh,080h,000h,036h,009h,00fh,002h,000h,08dh,01fh,00fh,007h,003h,001h,0ffh,07fh	; 7d3b  ...6............
	defb 03fh,01fh,00fh,007h,003h,001h,003h,000h,086h,004h,008h,040h,010h,000h,000h,003h	; 7d4b  ?..........@....
	defb 001h,085h,010h,002h,000h,008h,000h,003h,080h,084h,008h,040h,000h,004h,004h,000h	; 7d5b  ...........@....
	defb 090h,008h,040h,000h,004h,040h,002h,020h,000h,004h,000h,008h,002h,000h,00fh,00fh	; 7d6b  ..@..@. ........
	defb 001h,008h,000h,088h,001h,07fh,03fh,01fh,00fh,007h,003h,001h,005h,000h,003h,018h	; 7d7b  ......?.........
	defb 084h,000h,024h,000h,080h,004h,000h,094h,080h,004h,000h,040h,004h,020h,002h,000h	; 7d8b  ..$........@. ..
	defb 040h,000h,080h,020h,004h,000h,002h,000h,0ffh,07fh,03fh,01fh,003h,00fh,084h,040h	; 7d9b  @.. ......?....@
	defb 080h,004h,001h,004h,000h,08eh,040h,080h,004h,001h,000h,040h,004h,020h,0ffh,0ffh	; 7dab  ......@....@. ..
	defb 00ch,006h,003h,001h,007h,000h,095h,080h,0c0h,060h,030h,018h,00ch,006h,003h,004h	; 7dbb  .........`0.....
	defb 040h,002h,0ffh,0ffh,0c0h,060h,030h,018h,00ch,006h,003h,001h,007h,000h,087h,080h	; 7dcb  @....`0.........
	defb 0c0h,060h,030h,000h,01ch,022h,003h,063h,085h,022h,01ch,000h,018h,038h,004h,018h	; 7ddb  .`0..".c."...8..
	defb 0aeh,07eh,000h,03eh,063h,003h,00eh,03ch,070h,07fh,000h,03eh,063h,003h,00eh,003h	; 7deb  .~.>c..<p..>c...
	defb 063h,03eh,000h,00eh,01eh,036h,066h,066h,07fh,006h,000h,07fh,060h,07eh,063h,003h	; 7dfb  c>...6ff....`~c.
	defb 063h,03eh,000h,03eh,063h,060h,07eh,063h,063h,03eh,000h,07fh,063h,006h,00ch,003h	; 7e0b  c>.>c`~cc>..c...
	defb 018h,093h,000h,03eh,063h,063h,03eh,063h,063h,03eh,000h,03eh,063h,063h,03fh,003h	; 7e1b  ...>cc>cc>.>cc?.
	defb 063h,03eh,000h,001h,003h,004h,001h,094h,007h,000h,083h,086h,080h,080h,083h,087h	; 7e2b  c>..............
	defb 0e7h,000h,0e0h,030h,030h,0e0h,0c0h,000h,0f0h,000h,083h,086h,003h,080h,095h,086h	; 7e3b  ...00...........
	defb 0e3h,000h,0e0h,030h,030h,0e0h,030h,030h,0e0h,000h,080h,081h,083h,086h,086h,087h	; 7e4b  ...00.00........
	defb 0e0h,000h,0e0h,0e0h,003h,060h,08eh,0f0h,060h,000h,087h,086h,087h,086h,080h,086h	; 7e5b  .....`..`.......
	defb 0e3h,000h,0f0h,000h,0e0h,003h,030h,09eh,0e0h,000h,083h,086h,086h,087h,086h,086h	; 7e6b  ......0.........
	defb 0e3h,000h,0e0h,030h,000h,0e0h,030h,030h,0e0h,000h,087h,086h,080h,080h,081h,081h	; 7e7b  ...0..00........
	defb 0e1h,000h,0f0h,030h,060h,0c0h,003h,080h,0b3h,000h,083h,086h,086h,083h,086h,086h	; 7e8b  ...0`...........
	defb 0e3h,000h,0e0h,030h,030h,0e0h,030h,030h,0e0h,000h,083h,086h,086h,083h,080h,086h	; 7e9b  ...00.00........
	defb 0e3h,000h,0e0h,030h,030h,0f0h,030h,030h,0e0h,000h,003h,006h,000h,000h,003h,007h	; 7eab  ...00.00........
	defb 007h,000h,0e1h,032h,036h,0e6h,0c6h,002h,0f1h,000h,0c0h,020h,003h,030h,08bh,020h	; 7ebb  ...26...... .0. 
	defb 0c0h,000h,0e1h,033h,031h,0e1h,0c1h,001h,0f7h,000h,006h,080h,0a1h,0e0h,000h,0e3h	; 7ecb  ...31...........
	defb 036h,030h,0e0h,0c3h,007h,0f7h,000h,0e0h,030h,030h,0e0h,0c0h,000h,0f0h,000h,0e3h	; 7edb  60......00......
	defb 036h,030h,0e0h,0c0h,006h,0f3h,000h,0e0h,030h,030h,0e0h,030h,030h,0e0h,080h,050h	; 7eeb  60......00.00..P
	defb 00ch,002h,0ffh,082h,0eeh,066h,004h,0eeh,002h,0ffh,002h,0eeh,081h,066h,003h,0eeh	; 7efb  .....f.......f..
	defb 002h,0ffh,003h,0eeh,085h,066h,0eeh,0eeh,0ffh,0ffh,004h,0eeh,084h,066h,0eeh,0ffh	; 7f0b  .....f.......f..
	defb 0ffh,005h,0eeh,002h,066h,009h,0eeh,081h,066h,009h,0eeh,081h,066h,009h,0eeh,087h	; 7f1b  ....f...f...f...
	defb 066h,0eeh,00fh,00fh,00eh,0aeh,01eh,003h,0aeh,002h,00fh,083h,00eh,0eah,0e1h,003h	; 7f2b  f...............
	defb 0eah,002h,00fh,083h,00eh,06ah,0e1h,003h,0eah,002h,00fh,083h,00eh,0eah,061h,003h	; 7f3b  .....j........a.
	defb 0eah,002h,00fh,099h,00eh,0eah,0e1h,06ah,0eah,0eah,00fh,00fh,00eh,0eah,0e1h,0eah	; 7f4b  .......j........
	defb 06ah,0eah,00fh,00fh,00eh,0eah,0e1h,0eah,0eah,06ah,00fh,0fah,0e1h,005h,0eah,083h	; 7f5b  j........j......
	defb 00fh,0afh,01eh,005h,0aeh,084h,00fh,0afh,01eh,0a6h,004h,0aeh,085h,00fh,0afh,01eh	; 7f6b  ................
	defb 0aeh,0a6h,003h,0aeh,08bh,00fh,0afh,01eh,0aeh,0aeh,0a6h,0aeh,0aeh,00fh,0afh,01eh	; 7f7b  ................
	defb 003h,0aeh,085h,0a6h,0aeh,00fh,0afh,01eh,004h,0aeh,081h,0a6h,008h,0eah,081h,06ah	; 7f8b  ...............j
	defb 009h,0eah,081h,06ah,009h,0eah,081h,06ah,009h,0eah,082h,06ah,0eah,008h,0aeh,081h	; 7f9b  ...j...j...j....
	defb 0a6h,009h,0aeh,081h,0a6h,009h,0aeh,081h,0a6h,009h,0aeh,082h,0a6h,0aeh,07fh,01eh	; 7fab  ................
	defb 07fh,01eh,07fh,01eh,053h,01eh,080h,028h,012h,002h,0cch,081h,033h,00bh,0cch,006h	; 7fbb  ....S..(....3...
	defb 022h,008h,099h,081h,088h,003h,099h,081h,0aah,003h,011h,081h,0aah,003h,099h,008h	; 7fcb  "...............
	defb 0aeh,002h,0ach,085h,0a3h,0ach,0a3h,0a3h,0ach,003h,0a3h,081h,0ach,004h,0a3h,081h	; 7fdb  ................
	defb 0ach,005h,0a3h,083h,0a9h,0a8h,0a9h,008h,02ch,008h,0eah,002h,0cah,081h,03ah,00bh	; 7feb  ........,.....:.
	defb 0cah,00eh,02ah,004h,09ah,008h,0cah,002h,0ach,081h,0a3h,00bh,0ach,00eh,0a2h,004h	; 7ffb  ..*.............
	defb 0a9h,081h,02ch,007h,029h,081h,09ah,007h,089h,008h,0c9h,081h,0a9h,00bh,019h,00ch	; 800b  ..,.)...........
	defb 0a9h,081h,00ah,003h,019h,005h,0a9h,003h,019h,004h,0a9h,082h,0c9h,0a9h,009h,0f9h	; 801b  ................
	defb 081h,0a9h,004h,069h,011h,0c9h,007h,029h,008h,0c2h,002h,003h,002h,001h,003h,003h	; 802b  ...i...)........
	defb 084h,00ch,003h,001h,001h,004h,003h,084h,00ch,001h,001h,00ch,004h,003h,084h,00ch	; 803b  ................
	defb 003h,003h,00ch,003h,003h,002h,001h,002h,003h,081h,00ch,004h,003h,09ch,001h,003h	; 804b  ................
	defb 001h,001h,003h,003h,009h,008h,009h,00ch,00ch,003h,00ch,003h,003h,001h,001h,00ch	; 805b  ................
	defb 00ch,003h,00ch,003h,003h,00ch,001h,001h,013h,00ch,004h,003h,0a1h,00ch,003h,003h	; 806b  ................
	defb 001h,001h,013h,003h,003h,00ch,003h,003h,00ch,001h,001h,013h,003h,00ch,003h,003h	; 807b  ................
	defb 00ch,003h,001h,001h,013h,00ch,003h,003h,00ch,003h,003h,001h,001h,01ch,005h,013h	; 808b  ................
	defb 084h,009h,008h,009h,001h,004h,013h,08dh,009h,008h,009h,001h,001h,013h,003h,003h	; 809b  ................
	defb 009h,008h,009h,00ch,00ch,004h,013h,095h,00ch,003h,00ch,00ch,003h,00ch,013h,013h	; 80ab  ................
	defb 01ch,013h,00ch,00ch,003h,00ch,003h,003h,001h,001h,003h,003h,01ch,004h,013h,084h	; 80bb  ................
	defb 00ch,003h,003h,00ch,004h,013h,084h,01ch,003h,003h,00ch,00ah,013h,083h,009h,008h	; 80cb  ................
	defb 009h,005h,013h,083h,009h,008h,009h,005h,013h,083h,019h,008h,009h,005h,013h,083h	; 80db  ................
	defb 019h,018h,019h,005h,003h,082h,009h,018h,004h,019h,002h,00fh,006h,019h,002h,00fh	; 80eb  ................
	defb 003h,009h,002h,00ch,0a0h,013h,01ch,003h,003h,00ch,003h,00ch,00ch,013h,01ch,013h	; 80fb  ................
	defb 013h,01ch,003h,00ch,00ch,003h,00ch,003h,013h,01ch,013h,003h,003h,00ch,003h,003h	; 810b  ................
	defb 013h,013h,01ch,013h,013h,003h,003h,083h,009h,008h,009h,004h,013h,086h,003h,009h	; 811b  ................
	defb 008h,009h,003h,003h,003h,013h,083h,019h,018h,009h,005h,003h,082h,019h,018h,004h	; 812b  ................
	defb 019h,002h,00fh,006h,019h,002h,01fh,006h,019h,002h,01fh,006h,019h,002h,00fh,003h	; 813b  ................
	defb 019h,002h,00ch,08dh,003h,01ch,013h,013h,00ch,003h,00ch,00ch,003h,00ch,013h,013h	; 814b  ................
	defb 01ch,006h,013h,083h,009h,008h,009h,005h,013h,083h,019h,018h,009h,005h,003h,082h	; 815b  ................
	defb 019h,018h,004h,019h,002h,00fh,006h,019h,002h,01fh,006h,009h,002h,01fh,006h,019h	; 816b  ................
	defb 002h,00fh,006h,019h,002h,00fh,003h,019h,002h,00ch,08dh,003h,00ch,003h,013h,01ch	; 817b  ................
	defb 003h,00ch,00ch,003h,00ch,003h,013h,01ch,003h,013h,081h,01ch,004h,013h,084h,00ch	; 818b  ................
	defb 003h,003h,01ch,003h,013h,08ah,003h,00ch,003h,003h,00ch,003h,003h,013h,013h,01ch	; 819b  ................
	defb 005h,013h,083h,009h,008h,009h,005h,013h,0abh,009h,008h,009h,01ch,01ch,013h,01ch	; 81ab  ................
	defb 013h,013h,01ch,013h,01ch,01ch,003h,00ch,003h,003h,00ch,003h,01ch,01ch,013h,01ch	; 81bb  ................
	defb 013h,013h,01ch,013h,01ch,01ch,013h,01ch,013h,013h,01ch,013h,00ch,00ch,013h,01ch	; 81cb  ................
	defb 013h,013h,01ch,013h,003h,019h,002h,01fh,003h,019h,002h,01ch,08eh,013h,01ch,013h	; 81db  ................
	defb 013h,01ch,013h,01ch,01ch,013h,01ch,013h,013h,01ch,013h,050h,01eh,080h,000h,016h	; 81eb  ...........P....
	defb 005h,0f3h,002h,0f8h,002h,0f9h,002h,006h,002h,0efh,00bh,0e9h,003h,006h,089h,0b9h	; 81fb  ................
	defb 069h,0b9h,079h,009h,00fh,016h,016h,01eh,004h,0beh,084h,00fh,016h,016h,01eh,004h	; 820b  i.y.............
	defb 0beh,083h,00fh,006h,006h,00dh,0beh,003h,069h,002h,0efh,003h,009h,085h,00fh,006h	; 821b  ........i.......
	defb 006h,0beh,0beh,00bh,0e9h,084h,00fh,016h,016h,01eh,004h,0beh,083h,00fh,006h,006h	; 822b  ................
	defb 011h,0beh,004h,0e9h,002h,06fh,086h,069h,0b9h,069h,0b9h,079h,009h,003h,006h,088h	; 823b  .....o.i.i.y....
	defb 0b9h,069h,0b9h,079h,009h,0b9h,0b9h,069h,015h,0f9h,002h,0b9h,081h,069h,015h,0f9h	; 824b  .i.y...i.....i..
	defb 07fh,01fh,07fh,01fh,022h,01fh,000h	; 825b

; ----------------------------------------------------------------------
; DATOS cabecera_rectangulo_8262: x=62, 5 de ancho por 12 de alto, a la
;   casilla 0x3960
;   0x8262..0x8267  (5 bytes)
DATA_cabecera_rectangulo_8262:
	defb 03eh,005h,00ch,060h,039h	; 8262

; ----------------------------------------------------------------------
; DATOS rectangulo_8262: 60 casillas, cinco por fila
;   0x8267..0x82a3  (60 bytes)
DATA_rectangulo_8262:
	defb 00eh,0a6h,00eh,00eh,0a1h	; 8267
	defb 00eh,0a6h,00eh,00eh,0a1h	; 826c
	defb 00eh,0a6h,00eh,00eh,0a1h	; 8271
	defb 00eh,0a6h,00eh,00eh,0a1h	; 8276
	defb 00eh,0a6h,00eh,00eh,0a1h	; 827b
	defb 00eh,04ah,00eh,00eh,04fh	; 8280
	defb 040h,04bh,045h,045h,050h	; 8285
	defb 041h,04ch,00ch,066h,051h	; 828a
	defb 042h,04dh,00ch,04eh,052h	; 828f
	defb 043h,009h,05bh,04eh,052h	; 8294
	defb 05dh,009h,009h,059h,053h	; 8299
	defb 044h,044h,009h,009h,05ah	; 829e

; ----------------------------------------------------------------------
; DATOS cabecera_rectangulo_82a3: x=59, 4 de ancho por 1 de alto, a la casilla
;   0x3AA0; la carga 0x5D72
;   0x82a3..0x82a8  (5 bytes)
DATA_cabecera_rectangulo_82a3:
	defb 03bh,004h,001h,0a0h,03ah	; 82a3

; ----------------------------------------------------------------------
; DATOS rectangulo_82a3: 4 casillas: la version que se usa cuando la figura NO
;   esta recortada por la izquierda
;   0x82a8..0x82ac  (4 bytes)
DATA_rectangulo_82a3:
	defb 05ch,049h,049h,05dh	; 82a8

; ----------------------------------------------------------------------
; DATOS rectangulo_8262_recortado: las otras 60 casillas del de 0x8262, para
;   cuando esta recortado por la izquierda
;   0x82ac..0x82e8  (60 bytes)
DATA_rectangulo_8262_recortado:
	defb 00eh,0a1h,00eh,0a6h,00eh	; 82ac
	defb 00eh,0a1h,00eh,0a6h,00eh	; 82b1
	defb 00eh,0a1h,00eh,0a6h,00eh	; 82b6
	defb 00eh,0a1h,00eh,0a6h,00eh	; 82bb
	defb 00eh,0a1h,00eh,0a6h,00eh	; 82c0
	defb 00eh,04fh,00eh,04ah,00eh	; 82c5
	defb 040h,050h,045h,055h,045h	; 82ca
	defb 041h,054h,00ch,056h,046h	; 82cf
	defb 042h,054h,00ch,057h,002h	; 82d4
	defb 061h,063h,064h,057h,002h	; 82d9
	defb 009h,009h,065h,058h,047h	; 82de
	defb 044h,062h,009h,05eh,048h	; 82e3

; ----------------------------------------------------------------------
; DATOS rectangulo_82a3_recortado: las otras 4 casillas, las de cuando la
;   figura si esta recortada; el `ex de,hl` de 0xAF9D elige entre las dos
;   0x82e8..0x82ec  (4 bytes)
DATA_rectangulo_82a3_recortado:
	defb 05fh,049h,060h,009h	; 82e8

; ----------------------------------------------------------------------
; DATOS cabecera_de_los_digitos: x, 5 de ancho por 3 de alto: quince casillas
;   por digito
;   0x82ec..0x82f1  (5 bytes)
DATA_cabecera_de_los_digitos:
	defb 03eh,005h,003h,000h,039h	; 82ec

; ----------------------------------------------------------------------
; DATOS digitos_grandes: 150 B: los diez digitos de la marca, de quince
;   casillas cada uno
;   0x82f1..0x8387  (150 bytes)
DATA_digitos_grandes:
	defb 043h,093h,043h,043h,09ah,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,08fh,08fh,0a1h	; 82f1  C.CC...........
	defb 043h,093h,043h,043h,09ah,00eh,0a6h,092h,092h,0a1h,00eh,0a6h,00eh,00eh,0a1h	; 8300  C.CC...........
	defb 043h,093h,043h,043h,09ah,00eh,0a6h,091h,091h,0a1h,00eh,0a6h,00eh,00eh,0a1h	; 830f  C.CC...........
	defb 043h,093h,043h,043h,09ah,00eh,0a6h,090h,090h,0a1h,00eh,0a6h,00eh,00eh,0a1h	; 831e  C.CC...........
	defb 043h,093h,043h,043h,09ah,00eh,0a6h,08fh,08fh,0a1h,00eh,0a6h,00eh,00eh,0a1h	; 832d  C.CC...........
	defb 043h,093h,08eh,08eh,09ah,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h	; 833c  C..............
	defb 043h,093h,08dh,08dh,09ah,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h	; 834b  C..............
	defb 043h,093h,08ch,08ch,09ah,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h	; 835a  C..............
	defb 043h,093h,08bh,08bh,09ah,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h	; 8369  C..............
	defb 043h,093h,08ah,08ah,09ah,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h	; 8378  C..............

; ----------------------------------------------------------------------
; DATOS digitos_grandes_recortados: los mismos diez digitos, para cuando el
;   marcador esta recortado por la izquierda
;   0x8387..0x841d  (150 bytes)
DATA_digitos_grandes_recortados:
	defb 043h,094h,043h,09bh,043h,00eh,0a1h,00eh,0a6h,00eh,00eh,0a2h,08fh,0a7h,00eh	; 8387  C.C.C..........
	defb 043h,094h,043h,09bh,043h,00eh,0a5h,092h,0aah,00eh,00eh,0a1h,00eh,0a6h,00eh	; 8396  C.C.C..........
	defb 043h,094h,043h,09bh,043h,00eh,0a4h,091h,0a9h,00eh,00eh,0a1h,00eh,0a6h,00eh	; 83a5  C.C.C..........
	defb 043h,094h,043h,09bh,043h,00eh,0a3h,090h,0a8h,00eh,00eh,0a1h,00eh,0a6h,00eh	; 83b4  C.C.C..........
	defb 043h,094h,043h,09bh,043h,00eh,0a2h,08fh,0a7h,00eh,00eh,0a1h,00eh,0a6h,00eh	; 83c3  C.C.C..........
	defb 043h,099h,08eh,0a0h,043h,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh	; 83d2  C...C..........
	defb 043h,098h,08dh,09fh,043h,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh	; 83e1  C...C..........
	defb 043h,097h,08ch,09eh,043h,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh	; 83f0  C...C..........
	defb 043h,096h,08bh,09dh,043h,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh	; 83ff  C...C..........
	defb 043h,095h,08ah,09ch,043h,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh	; 840e  C...C..........

; ----------------------------------------------------------------------
; DATOS bloque_841d: 15 B -una casilla mas de 5x3-; lo carga 0x6743
;   0x841d..0x842c  (15 bytes)
DATA_bloque_841d:
	defb 043h,094h,043h,09bh,043h,00eh,0a1h,00eh,0a6h,00eh,00eh,0a1h,00eh,0a6h,00eh	; 841d  C.C.C..........

; ----------------------------------------------------------------------
; DATOS cabecera_rectangulo_842c: x, 3 de ancho por 2 de alto, a la casilla
;   0x3AA0; la carga 0x5ECE, o sea el ultimo rectangulo que pinta el suelo
;   0x842c..0x8431  (5 bytes)
DATA_cabecera_rectangulo_842c:
	defb 058h,003h,002h,0a0h,03ah	; 842c

; ----------------------------------------------------------------------
; DATOS rectangulo_842c: 6 casillas: la version sin recortar
;   0x8431..0x8437  (6 bytes)
DATA_rectangulo_842c:
	defb 009h,0c2h,0c7h	; 8431
	defb 044h,044h,0c3h	; 8434

; ----------------------------------------------------------------------
; DATOS rectangulo_842c_recortado: las otras 6, las de cuando la figura entra
;   cortada por la izquierda
;   0x8437..0x843d  (6 bytes)
DATA_rectangulo_842c_recortado:
	defb 0cah,0ceh,0cdh	; 8437
	defb 044h,0cfh,0d0h	; 843a

; ----------------------------------------------------------------------
; DATOS cabecera_rectangulo_843d: x, 3 de ancho por 2 de alto, a la casilla
;   0x3A80; la carga 0x5EAE
;   0x843d..0x8442  (5 bytes)
DATA_cabecera_rectangulo_843d:
	defb 035h,003h,002h,080h,03ah	; 843d

; ----------------------------------------------------------------------
; DATOS rectangulo_843d: 6 casillas: la version sin recortar
;   0x8442..0x8448  (6 bytes)
DATA_rectangulo_843d:
	defb 0d1h,043h,043h	; 8442
	defb 0d2h,0d3h,009h	; 8445

; ----------------------------------------------------------------------
; DATOS rectangulo_843d_recortado: las otras 6, las de cuando la figura entra
;   cortada
;   0x8448..0x844e  (6 bytes)
DATA_rectangulo_843d_recortado:
	defb 0d4h,043h,043h	; 8448
	defb 0d5h,0d6h,009h	; 844b

; ----------------------------------------------------------------------
; DATOS cabecera_rectangulo_844e: x, 39 de ancho por 2 de alto: la tira mas
;   larga del cartucho
;   0x844e..0x8453  (5 bytes)
DATA_cabecera_rectangulo_844e:
	defb 057h,027h,002h,060h,03ah	; 844e

; ----------------------------------------------------------------------
; DATOS rectangulo_844e: 78 casillas, 39 por fila: es la tira de suelo mas
;   larga del cartucho
;   0x8453..0x84a1  (78 bytes)
DATA_rectangulo_844e:
	defb 042h,0c0h,0d8h,0d9h,00fh,0d8h,0dah,00fh,0d8h,0dbh,00fh,0d8h,0dch	; 8453  B............
	defb 00fh,0d8h,0ddh,00fh,0d8h,0deh,00fh,0d8h,0dfh,00fh,0d8h,0e0h,00fh	; 8460  .............
	defb 0d9h,0d7h,00fh,0d9h,0d8h,00fh,0d9h,0d9h,00fh,0d9h,0dah,00fh,00fh	; 846d  .............
	defb 043h,0c1h,0c4h,0c5h,0c6h,0c4h,0c5h,0c6h,0c4h,0c5h,0c6h,0c4h,0c5h	; 847a  C............
	defb 0c6h,0c4h,0c5h,0c6h,0c4h,0c5h,0c6h,0c4h,0c5h,0c6h,0c4h,0c5h,0c6h	; 8487  .............
	defb 0c4h,0c5h,0c6h,0c4h,0c5h,0c6h,0c4h,0c5h,0c6h,0c4h,0c5h,0c6h,0c6h	; 8494  .............

; ----------------------------------------------------------------------
; DATOS rectangulo_844e_recortado: las otras 78, las de cuando la tira entra
;   cortada por la izquierda
;   0x84a1..0x84ef  (78 bytes)
DATA_rectangulo_844e_recortado:
	defb 042h,0e1h,0e2h,0e3h,0e1h,0e4h,0e5h,0e1h,0e6h,0e7h,0e1h,0e8h,0e9h	; 84a1  B............
	defb 0e1h,0eah,0ebh,0e1h,0ech,0edh,0e1h,0eeh,0efh,0e1h,0f0h,0f1h,0f2h	; 84ae  .............
	defb 0f3h,0f4h,0f2h,0f5h,0f6h,0f2h,0f7h,0f8h,0f2h,0f9h,0fah,00fh,00fh	; 84bb  .............
	defb 0c8h,0c9h,0cbh,0cch,0cch,0cbh,0cch,0cch,0cbh,0cch,0cch,0cbh,0cch	; 84c8  .............
	defb 0cch,0cbh,0cch,0cch,0cbh,0cch,0cch,0cbh,0cch,0cch,0cbh,0cch,0cch	; 84d5  .............
	defb 0cbh,0cch,0cch,0cbh,0cch,0cch,0cbh,0cch,0cch,0cbh,0cch,0cch,0cch	; 84e2  .............

; ----------------------------------------------------------------------
; DATOS rle_84ef: 293 B -> 768 de VRAM
;   0x84ef..0x8614  (293 bytes)
DATA_rle_84ef:
	defb 000h,01ch,00eh,000h,002h,0ffh,00eh,000h,002h,0ffh,00ch,000h,083h,0f0h,0ffh,01fh	; 84ef  ................
	defb 00eh,000h,083h,0f0h,0ffh,01fh,00bh,000h,084h,0f0h,0ffh,01fh,001h,00eh,000h,083h	; 84ff  ................
	defb 0f0h,0ffh,01fh,009h,000h,084h,0e0h,0fch,03fh,007h,00eh,000h,085h,080h,0f0h,0feh	; 850f  ........?.......
	defb 01fh,003h,006h,000h,086h,0c0h,0f0h,07ch,01fh,007h,001h,00eh,000h,086h,0c0h,0f0h	; 851f  .......|........
	defb 07ch,01fh,007h,001h,00bh,000h,083h,0c0h,0ffh,07fh,00fh,000h,087h,0fch,0ffh,003h	; 852f  |...............
	defb 0f0h,07ch,00fh,003h,00fh,000h,08bh,080h,0e0h,070h,038h,01ch,00ch,00eh,006h,006h	; 853f  .|.......p8.....
	defb 003h,003h,00eh,000h,002h,0ffh,081h,001h,00eh,000h,083h,0f8h,0ffh,007h,00ah,000h	; 854f  ................
	defb 084h,080h,0f8h,0ffh,00fh,00eh,000h,08bh,080h,0f8h,0ffh,007h,070h,038h,01ch,00eh	; 855f  ............p8..
	defb 007h,003h,001h,00eh,000h,08eh,080h,0c0h,0e0h,070h,038h,01ch,00ch,006h,007h,003h	; 856f  .........p8.....
	defb 003h,0e0h,060h,070h,003h,030h,081h,010h,009h,018h,020h,000h,083h,038h,018h,01ch	; 857f  ..`p.0.... ..8..
	defb 005h,00ch,005h,006h,002h,007h,081h,003h,00dh,000h,002h,01fh,00eh,000h,083h,0fch	; 858f  ................
	defb 0ffh,003h,00bh,000h,002h,07fh,00eh,000h,088h,080h,0f8h,0ffh,00fh,001h,018h,018h	; 859f  ................
	defb 01ch,005h,00ch,005h,006h,083h,007h,003h,003h,020h,000h,002h,030h,081h,038h,003h	; 85af  ......... ..0.8.
	defb 018h,081h,01ch,003h,00ch,081h,00eh,003h,006h,085h,007h,003h,018h,018h,01ch,005h	; 85bf  ................
	defb 00ch,004h,006h,002h,007h,002h,003h,020h,000h,010h,0c0h,004h,060h,081h,0e0h,003h	; 85cf  ....... ....`...
	defb 0c0h,028h,000h,007h,018h,081h,038h,006h,030h,08ah,070h,060h,0c0h,060h,030h,018h	; 85df  .(....8.0.p`.`0.
	defb 00ch,006h,003h,001h,00fh,000h,085h,080h,0c0h,060h,030h,018h,004h,000h,010h,0f0h	; 85ef  .........`0.....
	defb 010h,000h,083h,0f8h,0fch,01ch,01dh,000h,085h,040h,010h,024h,00ah,081h,00fh,000h	; 85ff  .........@.$....
	defb 081h,080h,00bh,000h,000h	; 860f

; ----------------------------------------------------------------------
; DATOS patrones_de_sprite: 127 bloques comprimidos encadenados: los atletas
;   de las cuatro pruebas, que se descomprimen cada cuadro sobre los 2 KB de
;   0x1800
;   0x8614..0x906b  (2647 bytes)
DATA_patrones_de_sprite:
	defb 084h,0feh,0feh,0feh,07ch,008h,000h,084h,078h,038h,03ch,03fh,010h,000h,000h,088h	; 8614  ....|...x8<?....
	defb 07ch,07ch,07ch,07ch,03ch,07ch,078h,078h,018h,000h,000h,017h,000h,089h,002h,00eh	; 8624  ||||<|xx........
	defb 01fh,01fh,01eh,00ch,00ch,00ch,006h,000h,084h,03fh,07fh,07eh,03ch,012h,000h,084h	; 8634  .........?.~<...
	defb 078h,0f0h,0f8h,03ch,006h,000h,000h,003h,000h,087h,010h,03fh,07eh,0fch,0f8h,0f0h	; 8644  x..<.......?~...
	defb 060h,006h,000h,086h,03ch,03eh,07fh,0ffh,00fh,00eh,00ah,000h,000h,088h,000h,000h	; 8654  `...<>..........
	defb 030h,078h,0f8h,0f8h,0c8h,080h,008h,000h,084h,01fh,01fh,00fh,007h,00ch,000h,000h	; 8664  0x..............
	defb 083h,0e0h,0e0h,0c0h,013h,000h,085h,024h,07ch,0f8h,070h,060h,005h,000h,000h,087h	; 8674  .......$|.p`....
	defb 004h,00eh,0dfh,0ffh,0feh,0f8h,0f0h,019h,000h,000h,086h,006h,007h,00fh,01fh,087h	; 8684  ................
	defb 001h,00ch,000h,086h,0c0h,0e0h,0e0h,0f0h,0f0h,060h,008h,000h,000h,088h,001h,001h	; 8694  .........`......
	defb 031h,078h,070h,0f0h,0c0h,080h,008h,000h,084h,0fch,0fch,0f8h,070h,00ch,000h,000h	; 86a4  1xp.........p...
	defb 01bh,000h,085h,01dh,01fh,01fh,01eh,00ch,000h,087h,000h,020h,078h,0feh,0fch,0f8h	; 86b4  ........... x...
	defb 070h,009h,000h,089h,020h,070h,0f8h,0f8h,07ch,03eh,01eh,01eh,00eh,007h,000h,000h	; 86c4  p... p..|>......
	defb 086h,000h,00dh,01ch,03ch,078h,048h,00ah,000h,084h,0feh,0feh,0feh,070h,008h,000h	; 86d4  ....<xH......p..
	defb 084h,078h,070h,0f8h,0feh,000h,08ah,020h,071h,0fbh,0f3h,0e3h,003h,003h,003h,007h	; 86e4  .xp.... q.......
	defb 007h,007h,000h,007h,0c0h,081h,080h,007h,000h,000h,092h,01fh,01fh,01fh,07eh,0e0h	; 86f4  ..............~.
	defb 0e0h,0c0h,080h,000h,000h,030h,078h,0f8h,0f0h,038h,01ch,0c0h,0c0h,00eh,000h,000h	; 8704  .....0x..8......
	defb 08ah,0feh,0feh,0feh,0feh,0feh,07ch,07ch,0f8h,070h,020h,016h,000h,000h,082h,03eh	; 8714  ......||.p ....>
	defb 07fh,004h,0ffh,085h,07fh,07eh,01ch,01eh,01fh,004h,07fh,084h,03fh,000h,080h,0c0h	; 8724  .....~......?...
	defb 00dh,000h,000h,090h,000h,000h,004h,01ah,05ah,07fh,03eh,03ch,000h,070h,0f0h,0e0h	; 8734  ........Z.><.p..
	defb 0eeh,0feh,07eh,038h,010h,000h,000h,082h,03eh,07fh,004h,0ffh,083h,07fh,07eh,03ch	; 8744  ..~8....>.....~<
	defb 003h,07eh,004h,0feh,083h,000h,080h,0c0h,00dh,000h,000h,009h,000h,097h,003h,007h	; 8754  .~..............
	defb 00fh,00dh,00fh,007h,003h,000h,000h,008h,034h,0b4h,0feh,07ch,078h,000h,080h,080h	; 8764  ........4..|x...
	defb 003h,0c7h,0c7h,0c6h,000h,000h,003h,000h,09dh,001h,005h,007h,003h,003h,01ch,03ch	; 8774  ...............<
	defb 078h,0f0h,0ech,0fch,07ch,038h,000h,000h,040h,0a0h,0a0h,0f0h,0e0h,0c0h,000h,000h	; 8784  x...|8..@.......
	defb 01ch,01ch,03ch,038h,030h,000h,000h,003h,000h,09dh,001h,005h,007h,003h,003h,03ch	; 8794  ..<80..........<
	defb 07ch,0f8h,0e0h,0e0h,0f0h,070h,070h,000h,000h,040h,0a0h,0a0h,0f0h,0e0h,0c0h,000h	; 87a4  |....pp..@......
	defb 00eh,00eh,03eh,03ch,038h,030h,000h,000h,097h,000h,000h,001h,006h,016h,01fh,00fh	; 87b4  ..><80..........
	defb 00fh,000h,007h,04fh,0cfh,08fh,087h,007h,001h,000h,000h,000h,080h,080h,0c0h,080h	; 87c4  ...O............
	defb 005h,000h,084h,070h,0f0h,0f0h,0c0h,000h,003h,000h,09dh,001h,005h,007h,003h,003h	; 87d4  ...p............
	defb 000h,001h,013h,033h,063h,061h,020h,000h,000h,000h,040h,0a0h,0a0h,0f0h,0e0h,0c0h	; 87e4  ...3ca ...@.....
	defb 000h,000h,09ch,0dch,0fch,0f8h,0f0h,000h,000h,003h,000h,09dh,001h,005h,007h,003h	; 87f4  ................
	defb 003h,000h,011h,073h,0f3h,0e3h,061h,020h,000h,000h,000h,040h,0a0h,0a0h,0f0h,0e0h	; 8804  ...s..a ...@....
	defb 0c0h,000h,00eh,08eh,0deh,0fch,0f8h,0f0h,000h,000h,082h,007h,00fh,004h,01fh,003h	; 8814  ................
	defb 00fh,08ah,01fh,01fh,03fh,07fh,07fh,0ffh,0ffh,0c0h,0f0h,0f8h,005h,0c0h,006h,080h	; 8824  ....?...........
	defb 002h,000h,000h,084h,000h,000h,007h,00fh,004h,01fh,08dh,00fh,00fh,01fh,03fh,03fh	; 8834  ..............??
	defb 07fh,07fh,07fh,000h,000h,0c0h,0f0h,0f8h,009h,0e0h,002h,0c0h,000h,084h,000h,003h	; 8844  ................
	defb 007h,00fh,009h,003h,087h,001h,001h,000h,000h,0e0h,0f8h,0fch,005h,0e0h,087h,0c0h	; 8854  ................
	defb 0f8h,0f8h,0fch,0fch,0feh,0feh,000h,083h,000h,007h,00fh,004h,01fh,08dh,00fh,00fh	; 8864  ................
	defb 01fh,03fh,07fh,07fh,0ffh,0ffh,0ffh,000h,0c0h,0f0h,0f8h,006h,0c0h,006h,000h,000h	; 8874  .?..............
	defb 083h,000h,003h,007h,004h,00fh,085h,007h,01fh,03fh,07fh,07fh,004h,0ffh,084h,000h	; 8884  .........?......
	defb 0e0h,0f8h,0fch,004h,0e0h,004h,0c0h,081h,0e0h,003h,000h,000h,084h,000h,000h,007h	; 8894  ................
	defb 00fh,004h,01fh,08fh,00fh,00fh,01fh,03fh,03fh,07fh,07fh,07fh,000h,000h,0c0h,0f0h	; 88a4  .......??.......
	defb 0f8h,0c0h,0c0h,009h,000h,000h,0a0h,000h,000h,001h,006h,016h,01fh,00fh,00fh,006h	; 88b4  ................
	defb 076h,071h,0f1h,0e8h,0fch,03eh,01ch,000h,000h,000h,080h,080h,0c0h,080h,000h,000h	; 88c4  vq...>..........
	defb 080h,0c0h,0e0h,0f0h,07ch,01ch,01ch,000h,005h,000h,09bh,001h,001h,000h,000h,00eh	; 88d4  ....|...........
	defb 01eh,03eh,07ch,0f0h,0e0h,0e0h,000h,000h,000h,010h,068h,068h,0fch,0f8h,0f0h,070h	; 88e4  .>|.......hh...p
	defb 068h,01ch,01fh,00fh,007h,001h,000h,01ch,000h,084h,003h,007h,007h,006h,000h,00ah	; 88f4  h...............
	defb 000h,086h,007h,03ch,07ch,0f8h,0e0h,0e0h,004h,000h,08ch,008h,034h,0b4h,0feh,07ch	; 8904  ...<|.......4..|
	defb 07bh,00fh,01fh,03fh,01ch,000h,000h,000h,01ch,000h,003h,003h,081h,002h,000h,009h	; 8914  {..?............
	defb 000h,097h,003h,00eh,03eh,07eh,0fch,0f0h,0e0h,000h,000h,000h,008h,034h,0b4h,0feh	; 8924  ....>~.......4..
	defb 07ch,078h,088h,030h,03ch,03eh,01fh,007h,003h,000h,01dh,000h,003h,007h,000h,08ch	; 8934  |x.0<>..........
	defb 001h,006h,016h,01fh,00fh,00fh,003h,018h,03ch,07ch,07eh,03fh,005h,000h,087h,080h	; 8944  ........<|~?....
	defb 080h,0d8h,0f8h,0f8h,060h,040h,008h,000h,000h,08ch,00eh,00ch,0e0h,0f0h,0fch,03eh	; 8954  ....`@.........>
	defb 01fh,00fh,00fh,007h,007h,001h,007h,000h,08ah,020h,0d0h,0d0h,0f8h,0f0h,0f0h,0a0h	; 8964  ......... ......
	defb 0c0h,0c0h,080h,003h,000h,000h,005h,000h,08bh,008h,034h,0b4h,0feh,07ch,01bh,02fh	; 8974  ..........4..|./
	defb 07fh,07fh,07ch,030h,009h,000h,087h,0e0h,0f0h,0f0h,0e0h,080h,000h,000h,000h,003h	; 8984  ..|0............
	defb 000h,08dh,001h,006h,016h,01fh,00fh,00fh,076h,0f2h,0f0h,0f8h,0ffh,07fh,03fh,004h	; 8994  ........v.....?.
	defb 000h,084h,080h,080h,0c0h,080h,005h,000h,083h,080h,0c0h,0c0h,000h,004h,000h,08ch	; 89a4  ................
	defb 002h,00dh,02dh,03fh,01fh,01eh,005h,037h,07fh,0ffh,0feh,07ch,007h,000h,083h,080h	; 89b4  ..-?...7...|....
	defb 000h,000h,003h,0c0h,003h,000h,000h,086h,01fh,03fh,03fh,03fh,03bh,020h,00ah,000h	; 89c4  .........???; ..
	defb 004h,0fch,086h,0f8h,0f8h,0f0h,0f0h,0f0h,0e0h,006h,000h,000h,00bh,000h,082h,001h	; 89d4  ................
	defb 03dh,003h,03fh,008h,000h,088h,0feh,0feh,0ffh,0ffh,0ffh,0efh,0e7h,081h,000h,088h	; 89e4  =.?.............
	defb 080h,080h,0c0h,0e0h,0f0h,0f8h,078h,038h,018h,000h,000h,08ah,003h,003h,007h,007h	; 89f4  ......x8........
	defb 00fh,01fh,0ffh,0ffh,0ffh,0e0h,006h,000h,004h,0ffh,084h,0f9h,0f0h,0e0h,0e0h,008h	; 8a04  ................
	defb 000h,000h,087h,080h,0c0h,0e0h,0f0h,0f8h,07ch,030h,019h,000h,000h,08ah,00fh,00fh	; 8a14  ........|0......
	defb 01fh,03fh,07fh,0ffh,0ffh,07eh,038h,020h,006h,000h,006h,0e0h,081h,0c0h,009h,000h	; 8a24  .?...~8 ........
	defb 000h,006h,00fh,081h,00ch,009h,000h,087h,0c0h,0f8h,0fch,0feh,0ffh,03fh,00eh,009h	; 8a34  .............?..
	defb 000h,000h,005h,01fh,081h,018h,00ah,000h,086h,0e0h,0f0h,0f8h,0fch,07ch,03ch,00ah	; 8a44  .............|<.
	defb 000h,000h,08bh,0e0h,0f8h,0fch,0feh,0feh,0feh,0fch,078h,0f0h,0e0h,0f0h,015h,000h	; 8a54  ..........x.....
	defb 000h,089h,003h,003h,001h,01ch,030h,070h,0e0h,0c0h,0c0h,007h,000h,003h,0f8h,081h	; 8a64  ......0p........
	defb 0f0h,007h,000h,085h,080h,0c0h,0f0h,078h,03ch,000h,005h,000h,087h,040h,060h,0e0h	; 8a74  .......x<....@`.
	defb 0e0h,0e0h,0c0h,080h,004h,000h,003h,0feh,082h,03ch,008h,00bh,000h,000h,01bh,000h	; 8a84  .........<......
	defb 085h,006h,00eh,01ch,03ch,038h,000h,007h,000h,08dh,060h,0e0h,0e0h,0e0h,0c0h,080h	; 8a94  ....<8....`.....
	defb 080h,000h,000h,07eh,0ffh,07fh,00eh,00ch,000h,000h,01ah,000h,086h,006h,006h,01ch	; 8aa4  ...~............
	defb 078h,078h,030h,000h,094h,003h,003h,000h,00ch,01ch,038h,030h,020h,000h,030h,038h	; 8ab4  xx0.......80 .08
	defb 038h,01ch,01eh,00eh,000h,0fch,0fch,0f8h,078h,00ch,000h,000h,086h,0feh,0feh,07eh	; 8ac4  8.......x......~
	defb 07ch,03ch,018h,01ah,000h,000h,085h,018h,078h,078h,0f0h,0e0h,01bh,000h,000h,086h	; 8ad4  |<......xx......
	defb 010h,030h,030h,070h,0e0h,0c0h,01ah,000h,000h,08ch,0feh,0fch,07ch,078h,038h,018h	; 8ae4  .00p........|x8.
	defb 000h,000h,018h,01ch,00fh,003h,00fh,000h,081h,0e0h,004h,000h,000h,003h,000h,08bh	; 8af4  ................
	defb 003h,00ah,00fh,01fh,07fh,0f4h,0f8h,0fch,0fch,07ch,018h,004h,000h,08eh,080h,040h	; 8b04  .........|.....@
	defb 0c0h,0e0h,0c0h,080h,0e0h,070h,038h,038h,03ch,01ch,00eh,00eh,000h,003h,000h,08ah	; 8b14  .....p88<.......
	defb 00fh,01eh,03fh,07fh,07fh,0f4h,0f8h,0fch,07ch,018h,005h,000h,08eh,080h,040h,0c0h	; 8b24  ..?.....|.....@.
	defb 0e0h,0c0h,080h,000h,000h,000h,020h,030h,038h,038h,030h,000h,08ch,030h,060h,0c4h	; 8b34  ...... 0880..0`.
	defb 0fbh,0fbh,0ffh,0ffh,07fh,077h,064h,00dh,001h,005h,000h,08fh,00ch,03eh,03eh,05fh	; 8b44  .....wd......>>_
	defb 0cfh,08fh,09fh,03fh,0ffh,0feh,0fch,0f0h,040h,000h,000h,000h,090h,000h,000h,020h	; 8b54  ...?....@...... 
	defb 058h,05ah,0feh,07ch,03ch,01eh,008h,003h,007h,007h,00fh,00fh,01fh,00bh,000h,004h	; 8b64  XZ.|<...........
	defb 080h,081h,000h,000h,002h,000h,08eh,010h,02ch,02dh,07fh,03eh,01eh,00eh,008h,026h	; 8b74  ........,-.>...&
	defb 007h,047h,043h,043h,0c3h,00ch,000h,004h,080h,000h,082h,03eh,07fh,004h,0ffh,084h	; 8b84  .GCC.......>....
	defb 07eh,07eh,07ch,07eh,006h,07fh,083h,000h,080h,0c0h,00dh,000h,000h,083h,01fh,07fh	; 8b94  ~~|~............
	defb 0ffh,005h,01fh,082h,000h,003h,006h,007h,082h,000h,080h,004h,0c0h,08ah,080h,080h	; 8ba4  ................
	defb 0c0h,0e0h,0f0h,0f8h,0f8h,0fch,0fch,0feh,000h,082h,01fh,07fh,00eh,0ffh,082h,000h	; 8bb4  ................
	defb 080h,004h,0c0h,081h,080h,009h,000h,000h,083h,01fh,07fh,0ffh,005h,01fh,083h,001h	; 8bc4  ................
	defb 01fh,01fh,005h,03fh,082h,000h,080h,004h,0c0h,003h,080h,083h,000h,080h,080h,004h	; 8bd4  ...?............
	defb 0c0h,000h,084h,000h,000h,001h,002h,00ah,000h,087h,003h,007h,03fh,07fh,0ffh,0e7h	; 8be4  ............?...
	defb 002h,008h,000h,083h,0efh,0ffh,0ffh,000h,004h,0ffh,081h,07ch,014h,000h,087h,018h	; 8bf4  ...........|....
	defb 01ch,01ch,00ch,0cch,06ch,064h,000h,085h,0ffh,0ffh,0feh,07eh,01ch,00fh,000h,089h	; 8c04  ....ld.....~....
	defb 018h,01ch,01ch,00eh,006h,006h,006h,01ah,008h,003h,000h,000h,085h,0ffh,0ffh,07fh	; 8c14  ................
	defb 07eh,004h,007h,000h,084h,005h,07fh,07fh,03eh,00ch,000h,084h,0c0h,0c0h,0e0h,0f0h	; 8c24  ~.......>.......
	defb 000h,085h,0ffh,0ffh,07fh,07eh,004h,006h,000h,085h,001h,001h,078h,07ch,03eh,00bh	; 8c34  .....~......x|>.
	defb 000h,085h,0c0h,0e0h,0f0h,000h,000h,000h,084h,01ch,01eh,01fh,004h,009h,000h,087h	; 8c44  ................
	defb 03fh,07bh,0f7h,020h,020h,0e0h,020h,009h,000h,083h,0e0h,0e0h,0c0h,000h,08dh,07fh	; 8c54  ?{.  . .........
	defb 0ffh,0ffh,07fh,01fh,03fh,03fh,01fh,01fh,00fh,00fh,00fh,007h,006h,000h,004h,0f0h	; 8c64  ....??..........
	defb 004h,0f8h,005h,0fch,000h,007h,0ffh,082h,07fh,033h,008h,000h,084h,080h,0c0h,0e0h	; 8c74  .........3......
	defb 0e0h,004h,0f0h,083h,078h,018h,008h,004h,000h,000h,008h,0ffh,083h,07fh,03bh,001h	; 8c84  ....x.........;.
	defb 006h,000h,002h,080h,005h,0f8h,083h,0f0h,0c0h,080h,005h,000h,000h,081h,0feh,004h	; 8c94  ................
	defb 0ffh,081h,07fh,004h,0ffh,008h,000h,081h,080h,004h,0c0h,081h,080h,008h,000h,000h	; 8ca4  ................
	defb 005h,0ffh,085h,07fh,0fbh,0fbh,0f0h,0f0h,007h,000h,087h,080h,0c0h,0e0h,0e0h,0e0h	; 8cb4  ................
	defb 0c0h,080h,008h,000h,000h,081h,07fh,005h,01fh,084h,03fh,03dh,03bh,03bh,003h,03fh	; 8cc4  ..........?=;;.?
	defb 003h,000h,008h,0e0h,005h,0c0h,003h,000h,000h,018h,000h,088h,030h,070h,078h,07eh	; 8cd4  ............0px~
	defb 03fh,03fh,01fh,006h,000h,005h,000h,08bh,008h,034h,0b4h,0feh,07ch,078h,003h,00fh	; 8ce4  ??.......4..|x..
	defb 00fh,007h,006h,009h,000h,087h,030h,078h,0f8h,0f8h,0e0h,080h,000h,000h,015h,000h	; 8cf4  ......0x........
	defb 08bh,006h,00eh,01fh,01fh,03ch,03ch,01eh,01fh,00fh,00fh,006h,000h,006h,000h,089h	; 8d04  .....<<.........
	defb 0e0h,0f0h,078h,07ch,03eh,01fh,00fh,007h,001h,009h,000h,088h,004h,02ah,03bh,09eh	; 8d14  ..x|>........*;.
	defb 0cfh,0f2h,0c0h,060h,000h,018h,000h,088h,018h,03ch,01eh,00fh,01fh,01fh,00fh,006h	; 8d24  ...`.....<......
	defb 000h,004h,000h,083h,00fh,007h,001h,00ah,000h,08fh,004h,00eh,0feh,0feh,0fch,0fch	; 8d34  ................
	defb 0f8h,078h,03ch,03eh,01eh,00eh,00fh,00eh,004h,000h,083h,000h,01fh,03fh,007h,07fh	; 8d44  .x<>.........?..
	defb 08ah,007h,00fh,007h,003h,001h,001h,000h,000h,0c0h,0e0h,004h,000h,088h,060h,0f0h	; 8d54  ..............`.
	defb 0f8h,0fch,0feh,0ffh,0fch,0f0h,000h,084h,003h,00fh,0ffh,0f8h,00ch,000h,083h,080h	; 8d64  ................
	defb 0c0h,080h,00dh,000h,000h,006h,000h,085h,008h,00ch,00ch,006h,003h,00dh,000h,088h	; 8d74  ................
	defb 004h,00eh,01eh,00eh,01ch,03ch,038h,010h,000h,0a0h,000h,0feh,0ffh,07fh,07bh,03ah	; 8d84  .....<8.......{:
	defb 03ch,03ch,03eh,01eh,01eh,01eh,01fh,01fh,00fh,007h,000h,000h,011h,037h,06fh,0ffh	; 8d94  <<>..........7o.
	defb 0ffh,0feh,0fch,0fch,07eh,03ch,070h,0e0h,000h,000h,000h,01dh,000h,083h,002h,003h	; 8da4  ....~<p.........
	defb 002h,000h,087h,010h,078h,099h,078h,07ch,01eh,030h,019h,000h,000h,083h,020h,060h	; 8db4  ....x.x|.0.... `
	defb 061h,005h,0ffh,082h,07fh,03eh,006h,000h,083h,000h,018h,01eh,005h,0ffh,081h,07ch	; 8dc4  a....>.........|
	defb 007h,000h,000h,084h,080h,0c0h,0c0h,080h,01ch,000h,000h,00ah,000h,084h,006h,007h	; 8dd4  ................
	defb 007h,003h,00dh,000h,085h,0b8h,0fch,0feh,0cfh,006h,000h,087h,00ch,03ch,07eh,0ffh	; 8de4  .............<~.
	defb 03fh,00eh,004h,019h,000h,000h,003h,000h,09dh,007h,003h,003h,003h,006h,006h,007h	; 8df4  ?...............
	defb 00fh,00fh,077h,0fbh,0ffh,07dh,000h,000h,000h,080h,0c0h,070h,0f0h,0f8h,0f8h,0f8h	; 8e04  ..w..}.....p....
	defb 0f0h,0f0h,0f0h,0f8h,0f8h,0fch,000h,08eh,0f7h,0f8h,0f8h,07ch,078h,03ch,03ch,07eh	; 8e14  ...........|x<<~
	defb 09eh,07ch,074h,030h,018h,030h,012h,000h,000h,084h,001h,020h,060h,060h,005h,0ffh	; 8e24  .|t0.0..... ``..
	defb 083h,073h,03eh,018h,004h,000h,08ah,0e0h,0f8h,0fch,078h,078h,0f0h,0f0h,0e0h,0c0h	; 8e34  .s>.......xx....
	defb 080h,006h,000h,000h,00ah,000h,085h,0f7h,0ffh,03fh,003h,001h,00ch,000h,085h,080h	; 8e44  .........?......
	defb 0c0h,0e0h,0e0h,040h,000h,01ah,000h,081h,01eh,004h,0ffh,081h,002h,000h,004h,000h	; 8e54  ...@............
	defb 08ch,044h,044h,0e6h,0ffh,0ffh,07fh,03bh,03fh,01fh,01fh,007h,002h,007h,000h,082h	; 8e64  .DD....;?.......
	defb 080h,0c0h,004h,0e0h,081h,0c0h,002h,000h,000h,00dh,000h,003h,001h,005h,000h,08bh	; 8e74  ................
	defb 00eh,01fh,01eh,03ch,07ah,0feh,0feh,0eeh,0fch,0e8h,0e0h,000h,085h,007h,007h,00fh	; 8e84  ...<z...........
	defb 03fh,07fh,005h,0ffh,081h,00fh,005h,000h,088h,0c0h,0f8h,0f8h,0f0h,0f0h,0e0h,0c0h	; 8e94  ?...............
	defb 080h,008h,000h,000h,086h,01dh,03fh,077h,0eeh,0eeh,046h,00ah,000h,002h,080h,00eh	; 8ea4  ......?w..F.....
	defb 000h,000h,00ch,000h,002h,001h,00ch,000h,086h,063h,0f7h,0ffh,0ffh,0feh,00eh,000h	; 8eb4  .........c......
	defb 008h,000h,086h,002h,003h,007h,007h,00fh,00fh,008h,000h,08ah,008h,03ch,0feh,0feh	; 8ec4  .............<..
	defb 0fch,0f8h,0ffh,0ffh,0ffh,00fh,000h,098h,000h,001h,00ch,007h,001h,00fh,013h,00fh	; 8ed4  ................
	defb 00fh,06eh,0fch,0f8h,060h,000h,000h,000h,0e0h,0f0h,0f8h,038h,078h,0f0h,0f0h,0e0h	; 8ee4  .n..`......8x...
	defb 008h,000h,000h,087h,001h,003h,007h,007h,01fh,03fh,07fh,005h,0ffh,08dh,060h,060h	; 8ef4  .........?....``
	defb 020h,000h,000h,0c0h,0e0h,0f0h,0f8h,03eh,01ch,008h,080h,007h,000h,000h,00ah,000h	; 8f04   ......>........
	defb 002h,001h,00dh,000h,081h,07ch,006h,0ffh,000h,010h,000h,089h,020h,070h,078h,03ch	; 8f14  .....|...... px<
	defb 01ch,00eh,006h,000h,000h,004h,00eh,083h,006h,006h,002h,000h,08ah,070h,0e0h,0c4h	; 8f24  .............p..
	defb 07bh,03bh,03fh,01fh,00fh,007h,001h,00ah,000h,088h,04fh,0dfh,0dfh,0bfh,0bfh,09eh	; 8f34  {;?.......O.....
	defb 0c4h,040h,004h,000h,000h,08fh,080h,0c0h,0e1h,0e3h,0f7h,0ffh,06fh,007h,007h,00fh	; 8f44  .@..........o...
	defb 01fh,00fh,007h,007h,00eh,004h,000h,08dh,0c0h,0e0h,0c0h,080h,000h,070h,0f0h,0f8h	; 8f54  .............p..
	defb 0f0h,0c0h,080h,000h,000h,000h,081h,007h,004h,03fh,004h,000h,083h,002h,003h,001h	; 8f64  .........?......
	defb 004h,000h,082h,0c0h,0e0h,008h,0f0h,003h,0ffh,083h,07fh,01eh,006h,000h,008h,000h	; 8f74  ................
	defb 006h,0fch,092h,07ch,01ch,000h,000h,000h,078h,07ch,01eh,006h,000h,000h,006h,007h	; 8f84  ...|....x|......
	defb 007h,003h,003h,001h,000h,000h,005h,000h,09bh,002h,005h,005h,00fh,017h,033h,038h	; 8f94  ..............38
	defb 01ch,01ch,00ch,004h,000h,000h,000h,0c0h,0e0h,078h,0bch,0bch,0feh,0feh,0cfh,09fh	; 8fa4  .........x......
	defb 03eh,03eh,01ch,000h,000h,007h,000h,084h,001h,003h,003h,001h,00ah,000h,08bh,001h	; 8fb4  >>..............
	defb 087h,0feh,0fch,0f8h,0fch,0feh,0feh,0fch,0fch,060h,000h,083h,00fh,03fh,07fh,005h	; 8fc4  .........`...?..
	defb 00fh,081h,007h,005h,00fh,083h,00eh,000h,080h,00bh,0c0h,002h,0e0h,002h,000h,000h	; 8fd4  ................
	defb 002h,000h,002h,001h,008h,000h,088h,00eh,00fh,007h,001h,01eh,0ffh,0ffh,0fdh,005h	; 8fe4  ................
	defb 0f0h,087h,002h,003h,007h,007h,01eh,0fch,0f8h,000h,090h,004h,018h,038h,07ch,07ch	; 8ff4  .............8||
	defb 03eh,03eh,01fh,0ffh,0ffh,0ffh,07fh,01fh,00fh,00fh,004h,007h,000h,089h,080h,0c0h	; 9004  >>..............
	defb 0e0h,0e0h,0e0h,0c0h,000h,000h,080h,000h,08eh,018h,03ch,03ch,078h,078h,0f0h,0f0h	; 9014  ..........<<xx..
	defb 0f1h,0fbh,0fbh,07dh,03dh,01bh,001h,00ah,000h,088h,0c0h,020h,0c0h,0c0h,000h,080h	; 9024  ...}=...... ....
	defb 000h,000h,000h,00ah,000h,086h,010h,018h,03ch,03fh,03fh,07fh,006h,000h,083h,004h	; 9034  ........<??.....
	defb 006h,006h,005h,0ffh,082h,0feh,07ch,000h,009h,000h,081h,001h,004h,003h,08dh,001h	; 9044  ......|.........
	defb 000h,000h,000h,00eh,01fh,03ch,070h,060h,000h,000h,000h,080h,005h,0c0h,000h,018h	; 9054  .....<p`........
	defb 000h,006h,07fh,082h,03fh,01fh,000h	; 9064

; ----------------------------------------------------------------------
; DATOS rle_906b: 154 B -> 192 de VRAM; entra por las DOS puertas: 0x571D lee
;   la direccion del propio bloque y 0x9205 se la da en HL (0x1C00),
;   saltandose los dos primeros bytes
;   0x906b..0x9105  (154 bytes)
DATA_rle_906b:
	defb 000h,01ah,002h,000h,08ch,006h,00dh,00bh,006h,0e5h,093h,0a9h,0d0h,044h,038h,001h	; 906b  .............D8.
	defb 002h,004h,000h,08fh,0c0h,060h,0a0h,0c0h,04eh,092h,02ah,016h,044h,038h,000h,080h	; 907b  .....`..N.*.D8..
	defb 000h,000h,004h,004h,00fh,081h,007h,005h,07fh,082h,03fh,003h,003h,000h,081h,040h	; 908b  ..........?....@
	defb 004h,0e0h,081h,0c0h,005h,0fch,082h,0f8h,080h,005h,000h,08ch,006h,00dh,00bh,006h	; 909b  ................
	defb 005h,01bh,011h,01ch,016h,00ch,000h,006h,004h,000h,08fh,0c0h,060h,0a0h,0c0h,040h	; 90ab  ............`..@
	defb 0b0h,010h,070h,0d0h,060h,000h,0c0h,000h,000h,004h,004h,00fh,081h,007h,005h,00fh	; 90bb  ..p.`...........
	defb 002h,003h,003h,000h,081h,040h,004h,0e0h,081h,0c0h,005h,0e0h,002h,080h,003h,000h	; 90cb  .....@..........
	defb 081h,064h,004h,02ah,081h,024h,00ah,000h,081h,044h,004h,0aah,081h,044h,00ah,000h	; 90db  .d.*.$...D...D..
	defb 083h,00fh,03fh,07fh,008h,0ffh,089h,07fh,03fh,007h,001h,000h,0f0h,0fch,0feh,0feh	; 90eb  ..?.....?.......
	defb 006h,0ffh,086h,0feh,0fch,0f8h,0e0h,0c0h,0e0h,000h	; 90fb  ..........

; ======================================================================
; CODIGO 0x9105..0x9111  (12 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; El ciclismo lleva su propio reparto de escenas, ocho, en (0xE120), y dentro de la carrera hay otro de seis en (0xE122) que ademas elige de que ciclista se habla: el bloque del jugador 1 esta en 0xE0A0 y el del 2 en 0xE0E0, sesenta y cuatro bytes cada uno, y todo el motor los recorre con IX.
; ----------------------------------------------------------------------
despacha_la_escena_del_ciclismo:		; ocho, por (0xE120)
	ld a,(0e122h)		;9105   ; mientras el reparto de dentro este a cero
	and a			;9108
	jr nz,$+24		;9109
	ld a,(0e120h)		;910b   ; la escena del ciclismo
	call despacha_por_indice		;910e   ; y su rutina

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_9111: 8 entradas; detras NO sigue ninguna, sino
;   `ld c,a / ld a,(0e123h) / and a`
;   0x9111..0x9121  (16 bytes)
DATA_tabla_de_subescenas_9111:
	defw 091f9h,0921fh,09244h,0928eh,092aeh,092d9h,0931ah,0937ch	; 9111

; ======================================================================
; CODIGO 0x9121..0x9135  (20 bytes)
; ======================================================================


despacha_al_ciclista_de_turno:		; el mismo reparto, con IX en su bloque
	ld c,a			;9121
	ld a,(0e123h)		;9122   ; de que ciclista se habla
	and a			;9125
	ld ix,0e0a0h		;9126   ; el bloque del jugador 1
	jr z,L_9130		;912a
	ld ix,0e0e0h		;912c   ; y el del 2
L_9130:
	ld a,c			;9130
	dec a			;9131
	call despacha_por_indice		;9132   ; su rutina, de la tabla de detras

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_9135: 6 entradas; detras sigue la primera, 0x9141
;   0x9135..0x9141  (12 bytes)
DATA_tabla_de_subescenas_9135:
	defw 09141h,0914fh,09172h,0918bh,0919fh,091b8h	; 9135

; ======================================================================
; CODIGO 0x9141..0x95ee  (1197 bytes)
; ======================================================================


espera_a_que_calle:		; mientras suene la pista 0x60, nada
	ld hl,0e012h		;9141
	ld a,060h		;9144   ; la pista del adelantamiento
	cp (hl)			;9146
	ret z			;9147   ; mientras suene, aqui no se sigue
	call suena_si_hay_partida		;9148
	ld a,078h		;914b   ; 120 fotogramas
	jr espera_y_sube_el_sub_reparto		;914d
corre_y_espera:		; la carrera sigue mientras corre la cuenta
	call fotograma_del_ciclismo		;914f
	call vuelca_los_sprites_de_arriba		;9152
	ld hl,0e004h		;9155
	push hl			;9158
	ld a,(hl)			;9159
	ld hl,03b50h		;915a
	cp 060h		;915d   ; en el fotograma justo
	ld a,0e0h		;915f
	ld bc,00008h		;9161
	call z,00056h		;9164   ; BIOS FILVRM - Fills VRAM with value | se borran ocho bytes de atributos
	pop hl			;9167
	dec (hl)			;9168   ; la cuenta
	ret nz			;9169
espera_y_sube_el_sub_reparto:		; la cuenta atras, y el paso siguiente
	ld (0e004h),a		;916a   ; la cuenta que traiga A
	ld hl,0e122h		;916d
	inc (hl)			;9170   ; y un paso mas
	ret			;9171
rotulo_del_ciclista:		; el nombre del que va a hablar
	ld hl,038d0h		;9172   ; la casilla del jugador 1
	ld a,(0e123h)		;9175
	and a			;9178
	jr z,L_917E		;9179
	ld hl,03a90h		;917b   ; y la del 2
L_917E:
	ld de,09698h		;917e
	ld bc,00006h		;9181
	call ldirvm		;9184
	ld a,03ch		;9187   ; sesenta fotogramas
	jr espera_y_sube_el_sub_reparto		;9189
espera_al_tercer_toque:		; hasta que el ciclista lleva tres
	ld hl,0e004h		;918b
	dec (hl)			;918e
	ret nz			;918f
	ld a,(ix+039h)		;9190   ; los toques que lleva
	cp 003h		;9193   ; con tres
	jr nz,L_91C2		;9195
	ld (ix+000h),001h		;9197   ; se le da por fuera
	ld a,0b4h		;919b   ; y 180 fotogramas
	jr espera_y_sube_el_sub_reparto		;919d
corre_el_ciclista_solo:		; un ciclista, en su tramo
	ld (ix+037h),002h		;919f   ; su estado
	push ix		;91a3
	call sprites_de_los_dos_ciclistas		;91a5   ; el ciclista
	call vuelca_los_sprites_de_arriba		;91a8
	pop ix		;91ab
	call indicador_del_ciclista		;91ad   ; y su indicador
	ld hl,0e004h		;91b0
	dec (hl)			;91b3   ; la cuenta
	ret nz			;91b4
	xor a			;91b5
	jr espera_y_sube_el_sub_reparto		;91b6
rearranca_la_carrera:		; los dos siguen, y se vuelve a montar
	ld a,(0e0a0h)		;91b8   ; los dos primeros bytes de los dos ciclistas
	ld hl,0e0e0h		;91bb
	and (hl)			;91be
	jp nz,cierra_el_ciclismo		;91bf   ; si alguno esta fuera, se acabo
L_91C2:
	ld a,(0e0a0h)		;91c2   ; lo que hay que salvar antes de rehacerlo todo
	ld h,a			;91c5
	ld a,(0e0e0h)		;91c6
	ld l,a			;91c9
	ld a,(0e0d9h)		;91ca
	ld b,a			;91cd
	ld a,(0e119h)		;91ce
	ld c,a			;91d1
	push hl			;91d2
	push bc			;91d3
	call monta_a_los_dos_ciclistas		;91d4   ; los dos ciclistas, montados otra vez
	pop bc			;91d7
	pop hl			;91d8
	ld a,h			;91d9
	ld (0e0a0h),a		;91da   ; y lo salvado, devuelto a su sitio
	ld a,l			;91dd
	ld (0e0e0h),a		;91de
	ld a,b			;91e1
	ld (0e0d9h),a		;91e2
	ld a,c			;91e5
	ld (0e119h),a		;91e6
	call monta_la_carrera		;91e9   ; la pantalla
	xor a			;91ec
	ld (0e122h),a		;91ed   ; el reparto de dentro, a cero
	ld (0e004h),a		;91f0
	ld a,002h		;91f3   ; y la escena 2
	ld (0e120h),a		;91f5
	ret			;91f8
escena_0_del_ciclismo:		; monta la pantalla de la carrera
	ld de,05519h		;91f9   ; las casillas
	call descomprime_a_vram		;91fc
	ld de,0906dh		;91ff   ; los patrones
	ld hl,01c00h		;9202
	call descomprime_a_vram_en		;9205
	call monta_la_carrera		;9208   ; la pantalla entera
	call rotulos_de_los_dos_ciclistas		;920b   ; y el marcador
	jr sube_la_escena_del_ciclismo		;920e
escribe_el_record_del_ciclismo:		; el tiempo de 0xE055
	ld hl,03823h		;9210
	ld de,0e055h		;9213   ; los tres bytes del record
	call escribe_un_tiempo		;9216
parpadea_world_record:		; el rotulo, parpadeando
	ld de,0968ch		;9219
	jp parpadea_guion_de_tiles		;921c
escena_1_del_ciclismo:		; el record del mundo, parpadeando
	call rotulos_de_los_dos_jugadores		;921f
	call escribe_los_dos_tiempos		;9222
	call escribe_el_record_del_ciclismo		;9225
	ret nz			;9228   ; mientras parpadee, no se sigue
	call rotulo_de_la_prueba		;9229   ; el rotulo de al lado
	ld hl,03823h		;922c
	ld de,0e08dh		;922f   ; y el tiempo a batir
	call escribe_un_tiempo		;9232
	ld a,080h		;9235   ; 128 fotogramas
	jr espera_y_sube_la_escena		;9237
rotulo_de_la_prueba:		; el nombre, en la primera fila
	ld de,075a3h		;9239
	ld hl,03803h		;923c
	ld c,0ffh		;923f
	jp L_441D		;9241

; ----------------------------------------------------------------------
; LA SALIDA. Aqui no hay semaforo ninguno: los cuatro sprites de 0x3B50 son la FLECHA que senala a tu ciclista -parpadeando, azul en la ventana de arriba y roja en la de abajo- y, cuando la cuenta atras se agota, la PISTOLA que la sustituye. El fogonazo, que es una nube con la palabra GO dentro, va en los dos sprites de 0x3B58 y lo pone la escena siguiente. Los tres bloques estan en 0x965D, 0x9665 y 0x966D, y las cuatro ranuras las borra de golpe 0x9413 cuando se acaba el arranque.
; ----------------------------------------------------------------------
escena_2_del_ciclismo:		; la salida, con su cuenta atras
	call rotulos_de_los_dos_ciclistas		;9244
	ld hl,03b50h		;9247   ; los dos sprites de la flecha que senala a tu ciclista
	ld a,(0e003h)		;924a   ; uno de cada dieciseis fotogramas
	and 010h		;924d
	ld bc,00008h		;924f
	push af			;9252
	ld a,0e0h		;9253
	call z,00056h		;9255   ; BIOS FILVRM - Fills VRAM with value | apagado
	pop af			;9258
	ld de,0965dh		;9259
	call nz,ldirvm		;925c   ; y encendido
	ld hl,0e004h		;925f
	ld a,(hl)			;9262
	and a			;9263
	jr z,L_9268		;9264
	dec (hl)			;9266
	ret nz			;9267
L_9268:
	ld a,(0e012h)		;9268   ; mientras suene algo, no se sale
	and a			;926b
	ret nz			;926c
	ld a,08eh		;926d   ; la pista de la salida
	call arranca_una_pista		;926f
	ld de,09686h		;9272
	call rotulo_en_las_dos_ventanas		;9275
	ld hl,03b50h		;9278   ; y la flecha deja sitio a la pistola de salida
	ld de,09665h		;927b
	ld bc,00008h		;927e
	call ldirvm		;9281
	ld a,078h		;9284   ; y 120 fotogramas
espera_y_sube_la_escena:		; la cuenta atras, y la escena siguiente
	ld (0e004h),a		;9286
sube_la_escena_del_ciclismo:
	ld hl,0e120h		;9289
	inc (hl)			;928c
	ret			;928d
escena_3_del_ciclismo:		; la carrera arranca
	call pedalea		;928e   ; los mandos de la salida
	ld hl,0e004h		;9291
	dec (hl)			;9294   ; la cuenta
	ret nz			;9295
	ld hl,03b58h		;9296
	ld de,0966dh		;9299
	ld bc,00008h		;929c   ; el fogonazo del disparo, la nube con el GO
	call ldirvm		;929f
	ld a,060h		;92a2
	call arranca_una_pista		;92a4   ; la pista de la carrera
	ld a,01eh		;92a7
	ld (0e121h),a		;92a9   ; y treinta fotogramas de arranque
	jr sube_la_escena_del_ciclismo		;92ac
escena_4_del_ciclismo:		; la carrera
	ld hl,0e02eh		;92ae   ; la pista que suena
	ld a,060h		;92b1
	cp (hl)			;92b3
	jr z,L_92BC		;92b4
	ld a,08ch		;92b6
	cp (hl)			;92b8
	call nz,suena_si_hay_partida		;92b9   ; si no es la de la carrera, se pone
L_92BC:
	call fotograma_del_ciclismo		;92bc   ; el fotograma de los dos ciclistas
	call sprites_del_terreno		;92bf
	call juzga_la_llegada		;92c2
	call crono_de_los_dos_ciclistas		;92c5
	call vuelca_los_sprites_de_arriba		;92c8
	ld a,(0e0d7h)		;92cb   ; los dos han llegado
	ld c,a			;92ce
	ld a,(0e117h)		;92cf
	cp c			;92d2
	ret nz			;92d3   ; y si no, se sigue corriendo
	inc a			;92d4
	ret nz			;92d5
	jp espera_y_sube_la_escena		;92d6
escena_5_del_ciclismo:		; la meta y los tiempos
	call fotograma_del_ciclismo		;92d9
	call mueve_a_los_dos_ciclistas		;92dc
	call vuelca_los_sprites_de_arriba		;92df
	ld de,0e090h		;92e2   ; el tiempo del jugador 1
	ld hl,0e0cfh		;92e5
	ld bc,00003h		;92e8
	ldir		;92eb
	ld de,0e093h		;92ed   ; y el del 2
	ld hl,0e10fh		;92f0
	ld c,003h		;92f3
	ldir		;92f5
	ld ix,0e0a0h		;92f7   ; el ciclista 1 contra el record
	call compara_con_el_record		;92fb
	ld ix,0e0e0h		;92fe   ; y el 2
	call compara_con_el_record		;9302
	ld a,(0e124h)		;9305   ; si alguno lo ha batido
	and a			;9308
	jr z,L_9316		;9309
	ld a,0b2h		;930b   ; suena
	call suena_si_hay_partida		;930d
	ld a,007h		;9310   ; y se va a la escena 7
	ld (0e120h),a		;9312
	ret			;9315
L_9316:
	xor a			;9316
	jp espera_y_sube_la_escena		;9317
escena_6_del_ciclismo:		; el remate
	call fotograma_de_la_carrera		;931a
	ret nz			;931d
suma_los_puntos_de_la_carrera:		; treinta por cabeza, en BCD
	call quien_va_delante		;931e
	jr c,cierra_el_ciclismo		;9321   ; si no hay a quien sumarle, nada
	ld hl,0e097h		;9323
	dec c			;9326   ; al jugador 1 o al 2
	jr nz,L_932B		;9327
	ld l,09ah		;9329
L_932B:
	ld a,030h		;932b   ; treinta puntos
	add a,(hl)			;932d
	daa			;932e   ; en BCD
	ld (hl),a			;932f
	jr nc,cierra_el_ciclismo		;9330
	inc hl			;9332   ; con su acarreo
	inc (hl)			;9333
cierra_el_ciclismo:		; borra las marcas de los que han acabado
	ld a,0b5h		;9334   ; la pista del final
	call arranca_una_pista		;9336
	xor a			;9339
	ld (0e069h),a		;933a   ; a esperar ya no
	ld l,a			;933d
	ld h,a			;933e
	ld a,(0e0a0h)		;933f   ; el ciclista 1
	and a			;9342
	jr z,L_9355		;9343   ; si esta fuera, no se le borra nada
	ld (0e096h),hl		;9345
	ld (0e097h),hl		;9348
	ld (0e090h),hl		;934b
	ld (0e091h),hl		;934e
	xor a			;9351
	ld (0e072h),a		;9352
L_9355:
	ld a,(0e0e0h)		;9355   ; y lo mismo con el 2
	and a			;9358
	ret z			;9359
	ld (0e099h),hl		;935a
	ld (0e09ah),hl		;935d
	ld (0e093h),hl		;9360
	ld (0e094h),hl		;9363
	xor a			;9366
	ld (0e082h),a		;9367
	ret			;936a
fotograma_de_la_carrera:		; los dos ciclistas y el indicador
	call monta_el_fotograma_de_carrera		;936b
	call mueve_a_los_dos_ciclistas		;936e
	call vuelca_los_sprites_de_arriba		;9371
	call indicador_del_que_va_delante		;9374
	ld hl,0e004h		;9377   ; la cuenta
	dec (hl)			;937a
	ret			;937b
escena_7_del_ciclismo:		; el record batido
	call fotograma_de_la_carrera		;937c
	call escribe_el_record_del_ciclismo		;937f
	ld a,(0e012h)		;9382   ; mientras suene la pista 0xB2
	cp 0b2h		;9385
	ret z			;9387
	ld de,0968ch		;9388   ; el rotulo
	call pinta_guion_de_tiles		;938b
	jr suma_los_puntos_de_la_carrera		;938e
mueve_a_los_dos_ciclistas:		; el crono y los dos indicadores
	call sube_el_crono		;9390
	ld ix,0e0a0h		;9393   ; el ciclista 1
	call indicador_del_ciclista		;9397
	ld ix,0e0e0h		;939a   ; y el 2
	jp indicador_del_ciclista		;939e
sube_el_crono:		; una centesima mas, y suena cada segundo
	ld a,(0e0dbh)		;93a1   ; si los dos han llegado, el crono se para
	ld hl,0e11bh		;93a4
	and (hl)			;93a7
	ret nz			;93a8
	ld hl,0e389h		;93a9   ; una centesima mas
	inc (hl)			;93ac
	ld a,(hl)			;93ad
	cp 063h		;93ae   ; y cada cien
	ret c			;93b0
	ld (hl),000h		;93b1   ; vuelta a empezar
	ld a,06fh		;93b3   ; con su pitido
	jp suena_si_hay_partida		;93b5
tiempo_del_ciclista:		; los tres bytes de su crono
	ld e,(ix+02fh)		;93b8
	ld d,(ix+030h)		;93bb
	ld c,(ix+031h)		;93be
	ret			;93c1
compara_con_el_record:		; el tiempo contra el de 0xE053
	call tiempo_del_ciclista		;93c2
	ld hl,0e053h		;93c5   ; el record del mundo del ciclismo
	call L_43B8		;93c8   ; la resta
	jr c,L_93D1		;93cb   ; si no llega, no hay record
	ld a,e			;93cd
	or d			;93ce
	or c			;93cf
	ret nz			;93d0
L_93D1:
	call tiempo_del_ciclista		;93d1   ; el tiempo del ciclista
	ld (hl),c			;93d4   ; puesto de record
	dec hl			;93d5
	ld (hl),d			;93d6
	dec hl			;93d7
	ld (hl),e			;93d8
	ld a,001h		;93d9
	ld (0e124h),a		;93db   ; y marcado
	ret			;93de
monta_la_carrera:		; todo lo que se ve en la pantalla del ciclismo
	call monta_las_dos_ventanas		;93df
	call sprites_de_los_dos_ciclistas		;93e2
	call pinta_a_los_dos_ciclistas		;93e5
	call pinta_a_cada_uno_en_la_otra_ventana		;93e8
	call vuelca_las_dos_ventanas		;93eb
	call vuelca_los_sprites_de_las_dos		;93ee
	call barra_de_los_dos		;93f1
	ld de,0969eh		;93f4   ; el rotulo de arriba
	call pinta_guion_de_tiles		;93f7
	call rotulos_de_los_dos_jugadores		;93fa
	call monta_los_dos_marcos		;93fd
	ld de,096beh		;9400   ; y el de abajo
	call pinta_guion_de_tiles		;9403
	jp escribe_las_dos_distancias		;9406

; ----------------------------------------------------------------------
; El fotograma de la carrera: veinte llamadas seguidas, cada una a lo suyo -los dos ciclistas, los rivales, el publico, el marcador, la pista, los sprites-. No hay bucle ninguno, esta escrito una detras de otra, que es lo que hace que el orden de lo que se pinta sea siempre el mismo.
; ----------------------------------------------------------------------
fotograma_del_ciclismo:		; lo que corre en cada fotograma de carrera
	ld hl,0e121h		;9409   ; la cuenta del adelantamiento
	ld a,(hl)			;940c
	and a			;940d
	jr z,monta_el_fotograma_de_carrera		;940e
	dec (hl)			;9410
	jr nz,monta_el_fotograma_de_carrera		;9411
	ld hl,03b50h		;9413   ; y al agotarse, se borran las cuatro ranuras: las dos pistolas y los dos GO
	ld bc,00010h		;9416
	ld a,0e0h		;9419
	call 00056h		;941b   ; BIOS FILVRM - Fills VRAM with value
monta_el_fotograma_de_carrera:		; las veinte piezas, en su orden
	call mueve_a_los_dos		;941e   ; los dos ciclistas
	call choque_entre_los_dos		;9421   ; el choque entre ellos
	call avanza_a_los_ciclistas		;9424   ; lo que avanzan
	ld hl,0e386h		;9427
	ld a,(hl)			;942a   ; si no toca la de 0xA449
	and a			;942b
	ld (hl),000h		;942c
	call z,mira_el_terreno		;942e
	call chispas_del_choque		;9431   ; las chispas
	call mira_si_choca_de_frente		;9434   ; lo que tienen delante
	call cambia_de_carril_a_los_dos		;9437
	call choque_entre_ciclistas		;943a
	call pinta_a_los_rivales		;943d   ; los rivales
	call sprites_de_los_dos_ciclistas		;9440
	call devuelve_el_fondo_de_los_dos		;9443
	call desplaza_las_dos_ventanas		;9446   ; el circuito, una columna
	call pinta_a_los_dos_ciclistas		;9449
	call pinta_a_cada_uno_en_la_otra_ventana		;944c
	call escribe_una_distancia		;944f   ; la distancia
	jp vuelca_una_ventana		;9452   ; y la ventana, a la VRAM
juzga_la_llegada:		; quien llega primero y quien no llega
	ld ix,0e0a0h		;9455   ; el ciclista 1
	call mira_si_ha_llegado		;9459
	ld ix,0e0e0h		;945c   ; y el 2
	call mira_si_ha_llegado		;9460
	ld a,(0e0d2h)		;9463   ; los dos han llegado
	ld b,a			;9466
	ld c,(ix+032h)		;9467
	or c			;946a
	ret z			;946b   ; si ninguno, nada
	ld a,b			;946c
	cp c			;946d   ; empatados
	jr z,L_9478		;946e
	ld a,001h		;9470
	jr c,L_9480		;9472
	ld (0e0d6h),a		;9474   ; y si no, el primero
	ret			;9477
L_9478:
	cp 002h		;9478   ; con dos ya esta
	ret z			;947a
	ld a,001h		;947b
	ld (0e0d6h),a		;947d
L_9480:
	ld (0e116h),a		;9480
	ret			;9483
mira_si_ha_llegado:		; la meta esta en 0x190A
	ld a,(ix+032h)		;9484   ; si ya paso por meta
	and a			;9487
	jr nz,estado_del_ciclista_tras_la_meta		;9488
	ld l,(ix+005h)		;948a   ; por donde va
	ld h,(ix+006h)		;948d
	ld de,0190ah		;9490   ; la meta
	sbc hl,de		;9493
	ret c			;9495   ; y antes de ella, nada
	inc (ix+032h)		;9496   ; marcado como llegado
	call tiempo_del_ciclista		;9499   ; su tiempo
	call resta_de_24_bits		;949c   ; contra el limite
	jr c,L_94B2		;949f   ; pasado el limite, fuera
	ld a,e			;94a1
	or d			;94a2
	or c			;94a3
	jr z,L_94B2		;94a4
	ld a,(ix+000h)		;94a6   ; si ya estaba fuera
	and a			;94a9
	ret nz			;94aa
	ld (ix+03ah),001h		;94ab
	jp arranca_al_ciclista		;94af
L_94B2:
	bit 0,(ix+033h)		;94b2   ; el jugador 1 o el 2
	ld hl,0e072h		;94b6
	jr z,L_94BD		;94b9
	ld l,082h		;94bb
L_94BD:
	ld (hl),001h		;94bd   ; fuera de la carrera
	ret			;94bf
estado_del_ciclista_tras_la_meta:		; lo que hace despues de llegar
	call sube_el_crono		;94c0   ; el crono
	ld (ix+032h),002h		;94c3   ; llegado del todo
	ld de,0e0e3h		;94c7   ; el otro ciclista
	bit 0,(ix+033h)		;94ca
	jr z,L_94D3		;94ce
	ld de,0e0a3h		;94d0
L_94D3:
	ld a,(ix+037h)		;94d3   ; su estado
	and a			;94d6   ; negativo: el ciclista espera
	jp m,indicador_del_ciclista		;94d7
	dec a			;94da   ; el 1
	jr z,espera_a_que_llegue_el_otro		;94db
	dec a			;94dd   ; y el 2
	jr z,indicador_del_ciclista		;94de
	ex de,hl			;94e0
	ld a,(ix+036h)		;94e1   ; si aun no ha frenado
	and a			;94e4
	jr z,L_94FE		;94e5
	ld a,(ix+001h)		;94e7   ; y si no lleva figura
	and a			;94ea
	jr nz,L_94F1		;94eb
L_94ED:
	inc (ix+037h)		;94ed   ; el estado siguiente
	ret			;94f0
L_94F1:
	ld a,(ix+003h)		;94f1   ; su carril
	cp (hl)			;94f4   ; segun por donde vaya el otro
	ld a,001h		;94f5
	jr c,L_94FA		;94f7
	inc a			;94f9
L_94FA:
	ld (ix+001h),a		;94fa   ; la figura que le toca
	ret			;94fd
L_94FE:
	bit 0,(ix+033h)		;94fe
	ld a,(0e0a1h)		;9502   ; el primer byte del otro
	jr nz,L_950A		;9505
	ld a,(0e0e1h)		;9507
L_950A:
	and a			;950a
	ret nz			;950b   ; si el otro esta fuera, nada
	ld a,(hl)			;950c
	and a			;950d
	ld a,(ix+003h)		;950e
	jr z,L_951B		;9511
	and a			;9513
	jr z,L_94ED		;9514
	ld (ix+001h),001h		;9516
	ret			;951a
L_951B:
	cp 020h		;951b   ; y el 0x20
	jr z,L_94ED		;951d
	ld (ix+001h),002h		;951f
	ret			;9523
espera_a_que_llegue_el_otro:		; hasta 0x1A2A
	bit 0,(ix+033h)		;9524
	ld a,(0e117h)		;9528   ; si el otro ya llego
	jr z,L_9530		;952b
	ld a,(0e0d7h)		;952d
L_9530:
	and a			;9530
	jr nz,L_94ED		;9531
	ld l,(ix+005h)		;9533   ; por donde va
	ld h,(ix+006h)		;9536
	ld de,01a2ah		;9539   ; y el punto de espera
	sbc hl,de		;953c
	ret c			;953e
	jr L_94ED		;953f
indicador_del_ciclista:		; el color que parpadea
	ld (ix+037h),0ffh		;9541   ; el estado, a la espera
	bit 0,(ix+033h)		;9545   ; el jugador 1 o el 2
	ld a,(0e072h)		;9549
	jr z,L_9551		;954c
	ld a,(0e082h)		;954e
L_9551:
	and a			;9551
	ret z			;9552   ; si sigue en carrera, no parpadea
	ld a,(ix+036h)		;9553
	and a			;9556
	jr nz,L_955D		;9557
	ld c,050h		;9559   ; un color
	jr L_955F		;955b
L_955D:
	ld c,010h		;955d   ; o el otro
L_955F:
	ld a,c			;955f
	ld hl,0e003h		;9560
	bit 4,(hl)		;9563   ; el bit 4 del contador de fotogramas
	jr z,L_9569		;9565
	add a,010h		;9567   ; y ahi cambia: eso es el parpadeo
L_9569:
	ld c,a			;9569
	ld a,(ix+00eh)		;956a   ; el nibble de abajo se respeta
	and 00fh		;956d
	or c			;956f
	ld (ix+00eh),a		;9570
	ret			;9573

; ----------------------------------------------------------------------
; El pedaleo: cada toque de la tecla -el bit 3 de lo recien pulsado- cuenta uno, y al tercero el ciclista arranca. Los dos jugadores se leen aqui uno detras de otro, cada uno con su bloque en IX y con su byte de flancos.
; ----------------------------------------------------------------------
pedalea:		; machacar es lo que mueve la bicicleta
	ld ix,0e0a0h		;9574   ; el ciclista 1
	ld a,(0e008h)		;9578   ; y sus flancos
	ld c,000h		;957b
	call L_9589		;957d
	ld ix,0e0e0h		;9580   ; el ciclista 2
	ld a,(0e006h)		;9584
	ld c,001h		;9587
L_9589:
	bit 0,(ix+000h)		;9589   ; si esta fuera, no pedalea
	ret nz			;958d
	and 008h		;958e   ; el bit 3
	ret z			;9590
	ld hl,0e122h		;9591   ; si el reparto de dentro no esta a cero, no
	ld a,(hl)			;9594
	and a			;9595
	ret nz			;9596
	inc (hl)			;9597   ; marcado
	inc hl			;9598
	ld (hl),c			;9599
	inc (ix+039h)		;959a   ; un toque mas
	ld a,060h		;959d   ; con su sonido
	call suena_si_hay_partida		;959f
	ld a,(ix+039h)		;95a2
	cp 003h		;95a5   ; y al tercero
	ret c			;95a7
arranca_al_ciclista:		; el ciclista, en marcha
	inc (ix+03ah)		;95a8
	ret			;95ab
indicador_del_que_va_delante:		; los tres tiles del rotulo
	call quien_va_delante		;95ac
	ret c			;95af
	dec c			;95b0
	ld a,(0e0afh)		;95b1   ; el color del jugador 1
	jr nz,L_95B9		;95b4
	ld a,(0e0efh)		;95b6   ; o el del 2
L_95B9:
	ld hl,03b7ch		;95b9
	call 0004dh		;95bc   ; BIOS WRTVRM - Writes data in VRAM | el color, al sprite
	inc hl			;95bf
	ld de,095eeh		;95c0   ; y sus tres bytes
	ld bc,00003h		;95c3
	jp ldirvm		;95c6
quien_va_delante:		; C dice cual, y el acarreo que no hay
	ld a,(0e0d6h)		;95c9   ; los dos, comparados
	ld hl,0e116h		;95cc
	cp (hl)			;95cf
	scf			;95d0   ; empatados, no hay quien vaya delante
	ret z			;95d1
	ld c,000h		;95d2
	and a			;95d4
	ld hl,0e0a0h		;95d5   ; el bloque del que va delante
	jr nz,L_95DD		;95d8
	ld l,0e0h		;95da
	inc c			;95dc
L_95DD:
	ld a,(hl)			;95dd   ; y si esta fuera, tampoco cuenta
	and a			;95de
	scf			;95df
	ret nz			;95e0
	ld a,c			;95e1
	and a			;95e2
	ld a,(0e072h)		;95e3
	jr z,L_95EB		;95e6
	ld a,(0e082h)		;95e8
L_95EB:
	sub 001h		;95eb
	ret			;95ed

; ----------------------------------------------------------------------
; DATOS atributos_de_sprite_95ee: 3 B que 0x95C6 copia a 0x3B7C, o sea el
;   ULTIMO sprite de la tabla
;   0x95ee..0x95f1  (3 bytes)
DATA_atributos_de_sprite_95ee:
	defb 070h,070h,001h	; 95ee

; ======================================================================
; CODIGO 0x95f1..0x9611  (32 bytes)
; ======================================================================


monta_los_dos_marcos:		; las tres filas de cada ventana
	ld hl,038c0h		;95f1   ; la ventana del jugador 1
	call L_95FA		;95f4
	ld hl,03a00h		;95f7   ; y la del 2
L_95FA:
	ld b,003h		;95fa   ; tres filas
	ld de,09611h		;95fc
L_95FF:
	push bc			;95ff
	ld bc,00007h		;9600   ; siete casillas cada una
	push hl			;9603
	call ldirvm		;9604
	pop hl			;9607
	ld a,020h		;9608   ; y la fila de abajo
	call suma_a_hl		;960a
	pop bc			;960d
	djnz L_95FF		;960e
	ret			;9610

; ----------------------------------------------------------------------
; DATOS nombres_9611: 7 B que 0x9604 copia a 0x3A00
;   0x9611..0x9618  (7 bytes)
DATA_nombres_9611:
	defb 096h,070h,070h,070h,070h,070h,098h	; 9611

; ----------------------------------------------------------------------
; DATOS tabla_9618: 14 B en dos filas de siete: las dos filas de abajo del
;   marco de la ventana del ciclismo, que 0x95FF copia a la VRAM detras de la
;   de 0x9611
;   0x9618..0x9626  (14 bytes)
DATA_tabla_9618:
	defb 097h,000h,000h,000h,000h,000h,097h,06fh,070h,070h,070h,070h,070h,071h	; 9618  .......opppppq

; ======================================================================
; CODIGO 0x9626..0x965d  (55 bytes)
; ======================================================================


rotulos_de_los_dos_ciclistas:		; 1UP y 2UP, o el de fuera
	ld hl,038e2h		;9626
	ld a,(0e0a0h)		;9629   ; el ciclista 1
	ld c,000h		;962c
	call L_9639		;962e   ; su rotulo
	ld a,(0e0e0h)		;9631   ; y el 2
	ld c,001h		;9634
	ld hl,03a22h		;9636
L_9639:
	ld de,0967dh		;9639
	and a			;963c   ; si esta fuera, uno
	jr nz,L_9648		;963d
	dec c			;963f
	ld de,09675h		;9640   ; y si no, 1UP
	jr nz,L_9648		;9643
	ld de,09679h		;9645   ; o 2UP
L_9648:
	ld c,0ffh		;9648
	jp L_441D		;964a
rotulo_en_las_dos_ventanas:		; el mismo guion, en las dos
	ld hl,038e1h		;964d
	push de			;9650
	ld c,0ffh		;9651   ; la mascara que pinta
	call L_441D		;9653
	pop de			;9656
	ld hl,03a21h		;9657   ; y la otra ventana
	jp L_441D		;965a

; ----------------------------------------------------------------------
; DATOS sprites_de_la_flecha: 8 B a 0x3B50: la flecha que senala a tu
;   ciclista, una por ventana -patron 0x24, azul en la de arriba y roja en la
;   de abajo-, que 0x9247 enciende y apaga cada dieciseis fotogramas
;   0x965d..0x9665  (8 bytes)
DATA_sprites_de_la_flecha:
	defb 030h,038h,024h,004h	; 965d
	defb 0a0h,038h,024h,006h	; 9661

; ----------------------------------------------------------------------
; DATOS sprites_de_la_pistola: 8 B al mismo sitio: la PISTOLA de salida,
;   patron 0x1C en negro, en (84,14) y (164,14); sustituye a la flecha cuando
;   la cuenta atras se agota
;   0x9665..0x966d  (8 bytes)
DATA_sprites_de_la_pistola:
	defb 054h,00eh,01ch,001h	; 9665
	defb 0a4h,00eh,01ch,001h	; 9669

; ----------------------------------------------------------------------
; DATOS sprites_del_fogonazo: 8 B a 0x3B58: el humo del disparo con el GO
;   dentro, patron 0x20 en blanco, en (80,32) y (160,32) -o sea justo a la
;   derecha de la pistola-. Los tres bloques cotejados contra la VRAM del
;   emulador: la flecha sale a los 2,4 s de montarse la prueba, la pistola 2,9
;   s despues y el fogonazo otros 2,4 s mas tarde
;   0x966d..0x9675  (8 bytes)
DATA_sprites_del_fogonazo:
	defb 050h,020h,020h,00fh	; 966d
	defb 0a0h,020h,020h,00fh	; 9671

; ----------------------------------------------------------------------
; DATOS guion_1up_en_juego: 4 B SIN cabecera: 1UP
;   0x9675..0x9679  (4 bytes)
DATA_guion_1up_en_juego:
	defb 011h,035h,030h,0ffh	; 9675

; ----------------------------------------------------------------------
; DATOS guion_2up_en_juego: 4 B SIN cabecera: 2UP
;   0x9679..0x967d  (4 bytes)
DATA_guion_2up_en_juego:
	defb 012h,035h,030h,0ffh	; 9679

; ----------------------------------------------------------------------
; DATOS guion_cpu: 9 B SIN cabecera: CPU, y detras el " SET" que lo comparte
;   0x967d..0x9686  (9 bytes)
DATA_guion_cpu:
	defb 023h,030h,035h,0ffh,000h,033h,025h,034h,0ffh	; 967d  #05..3%4.

; ----------------------------------------------------------------------
; DATOS guion_ready: 6 B SIN cabecera: READY; lo carga 0x9272
;   0x9686..0x968c  (6 bytes)
DATA_guion_ready:
	defb 032h,025h,021h,024h,039h,0ffh	; 9686

; ----------------------------------------------------------------------
; DATOS guion_world_rec: 12 B: WORLD REC en 0x3802; lo pinta L_4430,
;   parpadeando
;   0x968c..0x9698  (12 bytes)
DATA_guion_world_rec:
	defb 002h,038h,037h,02fh,032h,02ch,024h,000h,032h,025h,023h,0ffh	; 968c  .87/2,$.2%#.

; ----------------------------------------------------------------------
; DATOS nombres_flying: 6 B que 0x9184 copia a 0x3A90: la palabra FLYING
;   0x9698..0x969e  (6 bytes)
DATA_nombres_flying:
	defb 026h,02ch,039h,029h,02eh,027h	; 9698

; ----------------------------------------------------------------------
; DATOS guion_speed: 32 B, cuatro destinos: el rotulo SPEED del marcador y sus
;   tres tramos
;   0x969e..0x96be  (32 bytes)
DATA_guion_speed:
	defb 0a1h,039h,033h,030h,025h,025h,024h,006h,0feh	; 969e  .930%%$..
	defb 0bbh,039h,04dh,04eh,03dh,04fh,0feh,0fbh,03ah	; 96a7  .9MN=O..:
	defb 04dh,04eh,03dh,04fh,0feh,0e1h,03ah	; 96b0
	defb 033h,030h,025h,025h,024h,006h,0ffh	; 96b7

; ----------------------------------------------------------------------
; DATOS guion_96be: 10 B, dos destinos de dos tiles cada uno
;   0x96be..0x96c8  (10 bytes)
DATA_guion_96be:
	defb 01dh,038h,01eh,01fh,0feh	; 96be
	defb 05dh,038h,01eh,01fh,0ffh	; 96c3

; ======================================================================
; CODIGO 0x96c8..0x9766  (158 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL CIRCUITO DEL CICLISMO SE DESPLAZA EN LA RAM. Cada jugador tiene su ventana -nueve filas de treinta y dos casillas- guardada en la RAM, en 0xE140 y en 0xE260, y para moverla no se toca el VDP: se copian las nueve filas UNA POSICION ATRAS con nueve `ldir`, se rellena la columna que queda libre y solo entonces se vuelca todo. Asi el circuito avanza sin que se vea romperse, y las dos ventanas pueden ir a velocidades distintas.
; ----------------------------------------------------------------------
desplaza_las_dos_ventanas:		; el circuito, una columna
	ld hl,0e0a9h		;96c8   ; la ventana del jugador 1
	ld ix,0e0a0h		;96cb
	call L_96D9		;96cf
	ld hl,0e0e9h		;96d2   ; y la del 2
	ld ix,0e0e0h		;96d5
L_96D9:
	ld a,(hl)			;96d9   ; si el ciclista esta parado, no se desplaza
	and a			;96da
	ret z			;96db
	inc l			;96dc
	ld a,(hl)			;96dd
	inc a			;96de   ; una columna mas
	cp 007h		;96df   ; de siete en siete
	jr nz,L_96E5		;96e1
	ld a,000h		;96e3
L_96E5:
	ld (hl),a			;96e5   ; apuntada
	inc hl			;96e6
	jr nz,L_96EA		;96e7
	inc (hl)			;96e9
L_96EA:
	ld a,(hl)			;96ea   ; la fila del circuito
	cp 070h		;96eb   ; con tope
	jr c,L_96F2		;96ed
	ld a,070h		;96ef
	ld (hl),a			;96f1
L_96F2:
	push hl			;96f2
	ld a,l			;96f3
	cp 0e0h		;96f4
	ld de,0e140h		;96f6   ; la ventana del jugador 1
	jr c,L_96FE		;96f9
	ld de,0e260h		;96fb   ; o la del 2
L_96FE:
	ld l,e			;96fe
	ld h,d			;96ff
	inc hl			;9700
	exx			;9701
	ld b,009h		;9702   ; nueve filas
L_9704:
	exx			;9704
	ld bc,0001fh		;9705   ; treinta y una casillas
	ldir		;9708   ; corridas una posicion
	inc hl			;970a   ; y la fila siguiente
	inc de			;970b
	exx			;970c
	djnz L_9704		;970d
	pop de			;970f
	ld a,(de)			;9710
	call nibble_del_mapa		;9711   ; el nibble del mapa que toca
	dec de			;9714
	ld h,000h		;9715
	ld b,h			;9717
	ld l,a			;9718
	ld c,a			;9719
	add hl,hl			;971a   ; por sesenta y cuatro
	add hl,hl			;971b
	add hl,hl			;971c
	add hl,hl			;971d
	add hl,hl			;971e
	add hl,hl			;971f
	sbc hl,bc		;9720
	ld a,(de)			;9722
	call suma_a_hl		;9723
	ld de,0e400h		;9726   ; el bloque de dibujos de 0xE400
	add hl,de			;9729
	bit 0,(ix+033h)		;972a
	ld de,0e15fh		;972e   ; la ultima columna de la ventana 1
	jr z,L_9736		;9731
	ld de,0e27fh		;9733   ; o la de la 2
L_9736:
	ld b,009h		;9736   ; nueve casillas
L_9738:
	ld a,(hl)			;9738
	ld (de),a			;9739
	ld a,007h		;973a
	call suma_a_hl		;973c   ; la fila siguiente del dibujo
	ld a,020h		;973f
	call suma_a_de		;9741   ; y la de la ventana
	djnz L_9738		;9744
	ld de,0e380h		;9746   ; la distancia que le queda al ciclista 1
	bit 0,(ix+033h)		;9749
	jr z,L_9751		;974d
	ld e,083h		;974f   ; o la del 2
L_9751:
	ld hl,09766h		;9751   ; lo que se le descuenta
	xor a			;9754
	ld b,003h		;9755   ; tres bytes
L_9757:
	ld a,(de)			;9757
	sbc a,(hl)			;9758   ; restado en BCD
	daa			;9759
	ld (de),a			;975a
	inc hl			;975b
	inc de			;975c
	djnz L_9757		;975d
	ret nc			;975f   ; y si se pasa de cero
	dec e			;9760
	xor a			;9761
	ld (de),a			;9762   ; se queda en cero
	dec e			;9763
	ld (de),a			;9764
	ret			;9765

; ----------------------------------------------------------------------
; DATOS tabla_9766: 3 B; la carga 0x9751
;   0x9766..0x9769  (3 bytes)
DATA_tabla_9766:
	defb 050h,002h,000h	; 9766

; ======================================================================
; CODIGO 0x9769..0x97ba  (81 bytes)
; ======================================================================


escribe_las_dos_distancias:		; las dos, sin mirar el fotograma
	call L_977C		;9769
	jr L_9774		;976c
escribe_una_distancia:		; una si y otra no, para no gastar el fotograma
	ld a,(0e003h)		;976e   ; el bit 0 del contador de fotogramas
	rra			;9771
	jr nc,L_977C		;9772
L_9774:
	ld hl,03819h		;9774   ; la del jugador 1
	ld de,0e382h		;9777
	jr L_9782		;977a
L_977C:
	ld hl,03859h		;977c   ; y la del 2
	ld de,0e385h		;977f
L_9782:
	ld b,002h		;9782   ; dos bytes, o sea cuatro cifras
	jp escribe_cifras_bcd		;9784
fila_del_circuito_o_llano:		; por encima de 0x70 el circuito se acaba
	cp 070h		;9787   ; pasada la fila 0x70
	jr nc,L_978F		;9789
	sub 003h		;978b   ; tres menos
	jr nc,nibble_del_mapa		;978d
L_978F:
	xor a			;978f
	ret			;9790

; ----------------------------------------------------------------------
; El mapa del circuito va empaquetado a CUATRO BITS por casilla: dos casillas en cada byte. El indice se parte por la mitad para dar con el byte, y el acarreo de esa division dice cual de los dos nibbles toca -el de abajo si es impar, el de arriba si es par-. Son 57 bytes por prueba, o sea 114 casillas de circuito.
; ----------------------------------------------------------------------
nibble_del_mapa:		; media casilla por byte
	call datos_de_la_prueba		;9791
	srl a		;9794   ; entre dos: dos casillas por byte
	push af			;9796
	call suma_a_hl		;9797   ; el byte
	pop af			;979a
	ld a,(hl)			;979b
	jr c,L_97A2		;979c   ; con el acarreo, el nibble de abajo
	rra			;979e   ; y sin el, el de arriba
	rra			;979f
	rra			;97a0
	rra			;97a1
L_97A2:
	and 00fh		;97a2
	ret			;97a4
datos_de_la_prueba:		; el bloque de RAM que le toca a esta prueba
	push de			;97a5
	ld hl,097bah		;97a6   ; los cuatro punteros
	ex af,af'			;97a9
	ld a,(0e06ah)		;97aa   ; la prueba en curso
	rra			;97ad
	and 006h		;97ae   ; por dos: son punteros
	call suma_a_hl		;97b0
	ld e,(hl)			;97b3
	inc hl			;97b4
	ld d,(hl)			;97b5
	ex de,hl			;97b6
	ex af,af'			;97b7
	pop de			;97b8
	ret			;97b9

; ----------------------------------------------------------------------
; DATOS tabla_de_datos_por_prueba: 4 punteros a RAM -0xE600, 0xE639, 0xE672 y
;   0xE6AB-, o sea cuatro bloques de 57 bytes seguidos, uno por prueba; el
;   indice lo saca 0x97AA de (0xE06A) con `rra / and 006h`
;   0x97ba..0x97c2  (8 bytes)
DATA_tabla_de_datos_por_prueba:
	defw 0e600h,0e639h,0e672h,0e6abh	; 97ba

; ======================================================================
; CODIGO 0x97c2..0x97d1  (15 bytes)
; ======================================================================


monta_las_dos_ventanas:		; el mismo dibujo, a las dos
	ld de,0e140h		;97c2   ; la del jugador 1
	call L_97CB		;97c5
	ld de,0e260h		;97c8   ; y la del 2
L_97CB:
	ld hl,097d1h		;97cb
	jp descomprime_a_la_ram_en		;97ce

; ----------------------------------------------------------------------
; DATOS rle_a_ram_e140: 72 B -> 288 en RAM; lo descomprime L_74B5 dos veces, a
;   0xE140 y a 0xE260
;   0x97d1..0x9819  (72 bytes)
DATA_rle_a_ram_e140:
	defb 0a0h,07bh,07eh,07bh,07bh,07eh,07bh,07bh,07eh,07bh,07bh,07bh,07eh,07bh,07bh,07eh	; 97d1  .{~{{~{{~{{{~{{~
	defb 07bh,07bh,07bh,07eh,07bh,07bh,07eh,07bh,07bh,07bh,07eh,07bh,07bh,07eh,07bh,07bh	; 97e1  {{{~{{~{{{~{{~{{
	defb 07bh,00dh,082h,001h,099h,012h,082h,00dh,00eh,001h,09ah,01fh,00eh,001h,09ah,01fh	; 97f1  {...............
	defb 00eh,001h,09ah,01fh,00eh,001h,09ah,01fh,00eh,001h,09ah,01fh,00eh,001h,09ah,012h	; 9801  ................
	defb 00eh,00dh,05fh,001h,072h,012h,05fh,000h	; 9811  .._.r._.

; ======================================================================
; CODIGO 0x9819..0x9845  (44 bytes)
; ======================================================================


vuelca_una_ventana:		; una si y otra no
	ld a,(0e003h)		;9819   ; el bit 0 del contador de fotogramas
	rra			;981c
	jr nc,L_982A		;981d
vuelca_la_ventana_de_arriba:
	ld hl,03880h		;981f   ; la ventana de arriba
	ld de,0e140h		;9822
	jr vuelca_288_bytes		;9825
vuelca_las_dos_ventanas:
	call vuelca_la_ventana_de_arriba		;9827
L_982A:
	ld hl,039c0h		;982a   ; y la de abajo
	ld de,0e260h		;982d

; ----------------------------------------------------------------------
; Vuelca una ventana entera -288 bytes, nueve filas de treinta y dos- de la RAM a la VRAM por el puerto de datos. Se hace en dos vueltas porque en un `djnz` no caben mas de 256: la primera con B a cero, que son los 256, y la segunda con los 32 que faltan.
; ----------------------------------------------------------------------
vuelca_288_bytes:		; de la RAM a la VRAM, sin pasar por la BIOS
	call 00053h		;9830   ; BIOS SETWRT - Enables VDP to write
	ld a,(00006h)		;9833
	ld c,a			;9836
	ld b,000h		;9837   ; con B a cero son 256
	call L_983E		;9839
	ld b,020h		;983c   ; y los 32 que faltan
L_983E:
	ld a,(de)			;983e
	out (c),a		;983f   ; a la VRAM, de un byte por vuelta
	inc de			;9841
	djnz L_983E		;9842
	ret			;9844

; ----------------------------------------------------------------------
; DATOS rle_a_ram_e600: 156 B -> 228 en RAM desde 0xE600: los cuatro bloques
;   por prueba a los que apunta la tabla de 0x97BA
;   0x9845..0x98e1  (156 bytes)
DATA_rle_a_ram_e600:
	defb 006h,000h,084h,002h,066h,066h,030h,003h,000h,083h,015h,055h,054h,00ah,000h,084h	; 9845  ....ff0....UT...
	defb 002h,066h,066h,030h,003h,000h,083h,015h,055h,054h,013h,000h,081h,007h,007h,000h	; 9855  .ff0....UT......
	defb 084h,026h,066h,066h,030h,006h,000h,084h,015h,055h,055h,040h,005h,000h,083h,015h	; 9865  .&ff0....UU@....
	defb 055h,054h,007h,000h,083h,026h,066h,063h,003h,000h,088h,015h,055h,040h,000h,000h	; 9875  UT...&fc....U@..
	defb 026h,066h,030h,006h,000h,081h,007h,004h,000h,083h,001h,055h,054h,003h,000h,088h	; 9885  &f0........UT...
	defb 026h,066h,030h,000h,000h,001h,055h,054h,003h,000h,088h,026h,066h,030h,000h,000h	; 9895  &f0...UT...&f0..
	defb 001h,055h,054h,003h,000h,088h,026h,066h,030h,000h,000h,001h,055h,054h,003h,000h	; 98a5  .UT...&f0...UT..
	defb 083h,026h,066h,030h,00ah,000h,081h,007h,015h,000h,083h,002h,066h,030h,003h,000h	; 98b5  .&f0........f0..
	defb 083h,015h,055h,040h,005h,000h,083h,001h,055h,054h,003h,000h,083h,026h,066h,030h	; 98c5  ..U@....UT...&f0
	defb 004h,000h,083h,001h,055h,054h,005h,000h,082h,007h,000h,000h	; 98d5  ....UT......

; ======================================================================
; CODIGO 0x98e1..0x9ad7  (502 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Los dos ciclistas se mueven aqui, uno detras de otro, y cada uno con el OTRO en IY: eso es lo que les permite mirarse -adelantar, dejarse ir, no chocar- sin tener que buscar nada. El bloque del jugador 1 esta en 0xE0A0 y el del 2 en 0xE0E0.
; ----------------------------------------------------------------------
mueve_a_los_dos:		; el ciclista de cada jugador, con el otro en IY
	ld ix,0e0a0h		;98e1   ; el ciclista 1, con el 2 de rival
	ld iy,0e0e0h		;98e5
	ld hl,0e0ach		;98e9
	call acelera_al_ciclista		;98ec
	call velocidad_a_avance		;98ef
	ld ix,0e0e0h		;98f2   ; y el 2, con el 1
	ld iy,0e0a0h		;98f6
	ld hl,0e0ech		;98fa
	call acelera_al_ciclista		;98fd
	call velocidad_a_avance		;9900
	call barra_de_uno_u_otro		;9903
	ld hl,0e0aeh		;9906   ; el color de uno
	ld de,0e0fbh		;9909
	ld a,(0e0d7h)		;990c
	call L_991B		;990f
	ld hl,0e0eeh		;9912   ; y el del otro
	ld de,0e0bbh		;9915
	ld a,(0e117h)		;9918
L_991B:
	ld c,0ffh		;991b   ; la mascara entera
	and a			;991d
	jr z,L_9922		;991e
	ld c,00fh		;9920   ; o solo el nibble de abajo
L_9922:
	ld a,(hl)			;9922
	and c			;9923
	ld (de),a			;9924
	ret			;9925
avanza_a_los_ciclistas:		; la posicion, con su parte fraccionaria
	ld hl,0e0a4h		;9926   ; el ciclista 1
	ld ix,0e0a0h		;9929
	call L_9937		;992d
	ld hl,0e0e4h		;9930   ; y el 2
	ld ix,0e0e0h		;9933
L_9937:
	ld a,(ix+002h)		;9937   ; si ya ha llegado, no se avanza
	and a			;993a
	jr z,L_9942		;993b
	ld (ix+009h),000h		;993d   ; ni se cambia de figura
	ret			;9941
L_9942:
	ld a,(hl)			;9942   ; la posicion, mas la velocidad
	add a,(ix+007h)		;9943
	ld (hl),a			;9946
	inc l			;9947
	ld a,(hl)			;9948
	ld c,a			;9949
	adc a,(ix+008h)		;994a   ; con su acarreo
	ld (hl),a			;994d
	inc l			;994e
	jr nc,L_9952		;994f
	inc (hl)			;9951
L_9952:
	and 0f8h		;9952   ; y si ha cambiado de casilla
	ld b,a			;9954
	ld a,c			;9955
	and 0f8h		;9956
	cp b			;9958
	ld a,000h		;9959
	jr z,L_995F		;995b
	ld a,001h		;995d
L_995F:
	ld (ix+009h),a		;995f   ; se apunta
	ret z			;9962
	ld a,(ix+00eh)		;9963   ; la figura de la bicicleta
	ld b,a			;9966
	and 00fh		;9967   ; de tres en tres
	inc a			;9969
	cp 003h		;996a   ; y vuelta a empezar: eso es el pedaleo
	jr nz,L_996F		;996c
	xor a			;996e
L_996F:
	ld c,a			;996f   ; la figura, en el nibble de abajo
	ld b,a			;9970
	and 0f0h		;9971   ; y el color, en el de arriba
	or c			;9973
	ld (ix+00eh),a		;9974
	ret			;9977
velocidad_a_avance:		; la velocidad por ocho
	xor a			;9978
	ld h,a			;9979
	ld l,(ix+00dh)		;997a
	add hl,hl			;997d   ; por dos, por dos y por dos
	add hl,hl			;997e
	add hl,hl			;997f
	ld (ix+008h),h		;9980   ; y ese es el avance por fotograma
	ld (ix+007h),l		;9983
	ret			;9986
barra_de_los_dos:		; las dos barras de velocidad
	call barra_del_jugador_2		;9987
barra_del_jugador_1:
	ld hl,039a7h		;998a
	ld de,0e0adh		;998d
	ld ix,0e0a0h		;9990
	jr L_99A6		;9994
barra_de_uno_u_otro:		; una si y otra no, para repartir el fotograma
	ld a,(0e003h)		;9996   ; el bit 0 del contador de fotogramas
	rra			;9999
	jr nc,barra_del_jugador_1		;999a
barra_del_jugador_2:
	ld de,0e0edh		;999c
	ld hl,03ae7h		;999f
	ld ix,0e0e0h		;99a2
L_99A6:
	ld a,(de)			;99a6   ; la velocidad
	push af			;99a7
	call barra_de_velocidad		;99a8   ; pintada como barra
	ld de,00010h		;99ab   ; la fila de debajo
	add hl,de			;99ae
	pop af			;99af
	rra			;99b0   ; entre dos
	and 07fh		;99b1
	ld (ix+03dh),a		;99b3
	ld de,0e0dfh		;99b6   ; la cifra del jugador 1
	bit 0,(ix+033h)		;99b9
	jr z,L_99C2		;99bd
	ld de,0e11fh		;99bf   ; o la del 2
L_99C2:
	ld b,002h		;99c2   ; dos bytes, o sea cuatro cifras
	jp escribe_cifras_bcd		;99c4
L_99C7:
	ld de,0e205h		;99c7
	ld hl,03ae7h		;99ca

; ----------------------------------------------------------------------
; La barra de velocidad son quince casillas: el nibble de arriba del valor dice cuantas van llenas -el tile 8- y las que faltan hasta quince se pintan vacias, con el tile 7. No hay dibujo ninguno de la barra: es una cuenta y dos tiles.
; ----------------------------------------------------------------------
barra_de_velocidad:		; la barra, en llenos y vacios
	ld a,(de)			;99cd
L_99CE:
	rra			;99ce   ; el nibble de arriba
	rra			;99cf
	rra			;99d0
	rra			;99d1
	and 00fh		;99d2
	ld b,a			;99d4
	sub 00fh		;99d5   ; y las que faltan hasta quince
	neg		;99d7
	ld c,a			;99d9
	jp pinta_llenos_y_vacios		;99da
a_decimal_8:		; el byte de L, en BCD
	ld h,000h		;99dd

; ----------------------------------------------------------------------
; BINARIO A DECIMAL, y no dividiendo: dieciseis vueltas de `add hl,hl` sacando el bit de arriba, y del otro lado un `adc a,a / daa` por cada byte del resultado, que es lo que corrige a decimal en cada paso. Es la unica manera de escribir un numero de 16 bits sin tener que dividir por diez cinco veces.
; ----------------------------------------------------------------------
a_decimal:		; HL en binario, DE en BCD
	ld de,00000h		;99df
	ld b,010h		;99e2
L_99E4:
	add hl,hl			;99e4   ; el bit de mas peso, al acarreo
	ld a,e			;99e5
	adc a,a			;99e6   ; y a la cuenta, por dos
	daa			;99e7   ; corregido a decimal
	ld e,a			;99e8
	ld a,d			;99e9
	adc a,a			;99ea
	daa			;99eb
	ld d,a			;99ec
	djnz L_99E4		;99ed   ; dieciseis bits
	ret			;99ef
pinta_llenos_y_vacios:		; B casillas del tile 8 y C del 7
	call setwrt_y_guarda_el_puerto		;99f0
	ld a,008h		;99f3   ; el tile lleno
	call L_99FB		;99f5
	ld b,c			;99f8
	ld a,007h		;99f9   ; y el vacio
L_99FB:
	dec b			;99fb   ; con cero, nada
	inc b			;99fc
	ret z			;99fd
L_99FE:
	exx			;99fe
	out (c),a		;99ff   ; a la casilla
	exx			;9a01
	nop			;9a02
	djnz L_99FE		;9a03
	ret			;9a05

; ----------------------------------------------------------------------
; La velocidad del ciclista funciona igual que la carrerilla del atleta: cada toque suma 0x1000 y la curva de 0x9AD7 -indexada por el nibble alto de la propia velocidad- se resta cada fotograma. Lo que cambia es quien pedalea: si el ciclista sigue en carrera lo hace el jugador, y si esta fuera lo hace la rutina de abajo.
; ----------------------------------------------------------------------
acelera_al_ciclista:		; la velocidad, el rozamiento y el pedaleo
	ld a,(ix+002h)		;9a06
	and a			;9a09   ; si ya llego, no acelera
	ret nz			;9a0a
	ld a,(ix+032h)		;9a0b
	and a			;9a0e
	ret nz			;9a0f
	ld a,(ix+03ch)		;9a10
	and a			;9a13
	ret nz			;9a14
	ld (0e128h),hl		;9a15   ; donde vive su velocidad, apuntado
	ld a,(ix+000h)		;9a18
	and a			;9a1b   ; si esta fuera, la lleva la maquina
	jr nz,pedalea_la_maquina		;9a1c
	ld a,(0e122h)		;9a1e
	and a			;9a21
	jr z,L_9A2F		;9a22
	ld a,(0e123h)		;9a24
	cp (ix+033h)		;9a27
	ret nz			;9a2a
	ld h,020h		;9a2b   ; y en el tramo de espera, a velocidad fija
	jr L_9A69		;9a2d
L_9A2F:
	ld e,(hl)			;9a2f   ; la velocidad de ahora
	inc hl			;9a30
	ld d,(hl)			;9a31
	ld a,d			;9a32
	rra			;9a33
	rra			;9a34
	rra			;9a35
	rra			;9a36
	and 00fh		;9a37   ; su nibble de mas peso
	ld hl,09ad7h		;9a39   ; la curva del rozamiento
	call suma_a_hl		;9a3c
	ld l,(hl)			;9a3f
	ld h,000h		;9a40
	add hl,hl			;9a42   ; por cuatro
	add hl,hl			;9a43
	ex de,hl			;9a44
	sbc hl,de		;9a45   ; y eso es lo que pierde
	jr nc,L_9A4B		;9a47
	ld h,000h		;9a49   ; de cero no se baja
L_9A4B:
	ld a,(ix+001h)		;9a4b   ; si va a rueda, tampoco pedalea
	and a			;9a4e
	jr nz,L_9A69		;9a4f
	ld a,(ix+033h)		;9a51
	and a			;9a54
	ld a,(0e008h)		;9a55   ; lo recien pulsado del jugador 1
	jr z,L_9A5D		;9a58
	ld a,(0e006h)		;9a5a   ; o del 2
L_9A5D:
	and 008h		;9a5d   ; el bit 3
	ld de,01000h		;9a5f
	jr z,L_9A69		;9a62
	add hl,de			;9a64   ; y cada toque son 0x1000, con tope
	jr nc,L_9A69		;9a65
	ld h,0ffh		;9a67
L_9A69:
	ex de,hl			;9a69
	ld hl,(0e128h)		;9a6a
	ld (hl),e			;9a6d   ; la velocidad, apuntada
	inc hl			;9a6e
	ld (hl),d			;9a6f
	ret			;9a70

; ----------------------------------------------------------------------
; Cuando un ciclista queda fuera de la carrera lo sigue moviendo el cartucho, y de dos maneras distintas: en partida se pega al otro -mira su posicion y su velocidad en IY y sube o baja de diez en diez para no descolgarse ni pasarse-, y en la DEMOSTRACION, donde no hay grabacion que reproducir, tira de azar puro: `ld a,r` toma el registro de refresco de la memoria, que a estas alturas del fotograma vale cualquier cosa, y con su bit 0 decide si acelera o si frena.
; ----------------------------------------------------------------------
pedalea_la_maquina:		; el ciclista que ya no lleva nadie
	ld a,(0e120h)		;9a71   ; solo mientras la carrera esta en marcha
	cp 004h		;9a74
	ret nz			;9a76
	ld a,(ix+001h)		;9a77   ; a rueda no se toca nada
	and a			;9a7a
	jr nz,L_9A2F		;9a7b
	ld a,(0e002h)		;9a7d
	and 040h		;9a80   ; el bit 6: si hay partida
	ld a,(0e003h)		;9a82
	jr z,L_9AC1		;9a85   ; y sin partida es la demostracion
	and 007h		;9a87   ; uno de cada ocho fotogramas
	ret nz			;9a89
	ld a,(ix+00dh)		;9a8a   ; su velocidad
	ld c,a			;9a8d
	cp 050h		;9a8e
	jr c,L_9AA9		;9a90
	ld a,(ix+00bh)		;9a92   ; su carril contra el del otro
	sub (iy+00bh)		;9a95
	inc a			;9a98
	cp 003h		;9a99
	ret c			;9a9b   ; si van juntos, no se toca
	dec a			;9a9c
	ld a,c			;9a9d
	jp p,L_9AB0		;9a9e
	sub (iy+00dh)		;9aa1   ; y su posicion contra la del otro
	jr c,L_9AA9		;9aa4
	cp 020h		;9aa6
	ret nc			;9aa8
L_9AA9:
	ld a,c			;9aa9   ; diez mas de velocidad
	add a,010h		;9aaa
	ret c			;9aac   ; con tope
	ld h,a			;9aad
	jr L_9A69		;9aae
L_9AB0:
	sub (iy+00dh)		;9ab0   ; la posicion del otro
	jr nc,L_9AB8		;9ab3
	cp 0e0h		;9ab5
	ret c			;9ab7
L_9AB8:
	ld a,c			;9ab8   ; diez menos
	sub 010h		;9ab9
	cp 050h		;9abb   ; con suelo
	ret c			;9abd
	ld h,a			;9abe
	jr L_9A69		;9abf
L_9AC1:
	and 007h		;9ac1   ; uno de cada ocho fotogramas
	ret nz			;9ac3
	ld a,(ix+00dh)		;9ac4
	ld c,a			;9ac7
	cp 0a8h		;9ac8   ; muy rapido, se frena
	jr nc,L_9AB8		;9aca
	cp 070h		;9acc   ; muy lento, se acelera
	jr c,L_9AA9		;9ace
	ld a,r		;9ad0   ; y en medio, el registro de refresco hace de dado
	rra			;9ad2
	jr c,L_9AA9		;9ad3   ; cara: acelerar; cruz: frenar
	jr L_9AB8		;9ad5

; ----------------------------------------------------------------------
; DATOS curva_9ad7: 16 B, creciente y acabada en 0xFF (04 28 40 50 64 74 88 98
;   A0 A8 B4 C0 D8 E8 F0 FF); la indexa 0x9A39 igual que la de 0x5F7B, con un
;   nibble alto
;   0x9ad7..0x9ae7  (16 bytes)
DATA_curva_9ad7:
	defb 004h,028h,040h,050h,064h,074h,088h,098h,0a0h,0a8h,0b4h,0c0h,0d8h,0e8h,0f0h,0ffh	; 9ad7  .(@Pdt..........

; ======================================================================
; CODIGO 0x9ae7..0x9b86  (159 bytes)
; ======================================================================


sprites_de_los_dos_ciclistas:		; el color de cada uno
	ld c,02fh		;9ae7   ; el color del ciclista 1
	ld ix,0e0a0h		;9ae9
	call color_del_ciclista		;9aed
	call sprite_de_la_rueda		;9af0
	ld c,07fh		;9af3   ; y el del 2
	ld ix,0e0e0h		;9af5
	call color_del_ciclista		;9af9
sprite_de_la_rueda:		; la pieza de atras, si cabe en la ventana
	ld hl,0e0a3h		;9afc
	ld a,c			;9aff   ; el ciclista 1
	cp 02fh		;9b00
	jr nz,L_9B06		;9b02
	ld l,0e3h		;9b04   ; o el 2
L_9B06:
	ld a,(hl)			;9b06
	inc hl			;9b07
	inc hl			;9b08
	and 0f8h		;9b09   ; la fila, a multiplo de ocho
	add a,c			;9b0b
	ld (ix+01ch),a		;9b0c   ; con su color
	ld e,(hl)			;9b0f
	inc hl			;9b10
	ld d,(hl)			;9b11
	ld l,(ix+005h)		;9b12   ; la posicion del ciclista
	ld h,(ix+006h)		;9b15
	ex de,hl			;9b18
	and a			;9b19
	sbc hl,de		;9b1a   ; contra la de la pieza
	ld de,00058h		;9b1c
	add hl,de			;9b1f   ; centrada en la ventana
	ld a,h			;9b20
	and a			;9b21
	jr nz,L_9B31		;9b22
	ld a,l			;9b24
	cp 0f0h		;9b25   ; fuera por arriba
	jr nc,L_9B31		;9b27
	cp 010h		;9b29   ; o por abajo
	jr c,L_9B31		;9b2b
	ld (ix+01dh),a		;9b2d   ; y dentro, su columna
	ret			;9b30
L_9B31:
	ld (ix+01ch),0d1h		;9b31   ; fuera de la ventana, escondida
	ret			;9b35
color_del_ciclista:		; la fila y el color, en un byte
	ld a,(ix+003h)		;9b36
	and 0f8h		;9b39   ; la fila, a multiplo de ocho
	add a,c			;9b3b   ; y el color en los tres bits de abajo
	ld (ix+00fh),a		;9b3c
	ret			;9b3f
choque_entre_ciclistas:		; si se pisan, uno se va al suelo
	ld ix,0e0a0h		;9b40
	ld hl,0e0d5h		;9b44
	ld de,0e115h		;9b47
	ld a,(ix+003h)		;9b4a   ; el carril de uno
	sub (ix+043h)		;9b4d   ; contra el del otro
	add a,009h		;9b50   ; dentro de nueve
	cp 012h		;9b52
	jr nc,L_9B6B		;9b54   ; y si no se tocan, nada
	ld a,058h		;9b56   ; quien va delante
	sub (ix+01dh)		;9b58
	jr c,L_9B5E		;9b5b
	ex de,hl			;9b5d   ; se cambian
L_9B5E:
	add a,038h		;9b5e
	cp 070h		;9b60   ; el que se lleva el golpe
	ld c,001h		;9b62
	jr c,L_9B67		;9b64
	dec c			;9b66
L_9B67:
	xor a			;9b67   ; marcado
	ld (de),a			;9b68
	ld (hl),c			;9b69
	ret			;9b6a
L_9B6B:
	ld a,(de)			;9b6b   ; si no habia golpe pendiente, nada
	or (hl)			;9b6c
	ret z			;9b6d
	ld a,(hl)			;9b6e
	and a			;9b6f
	jr nz,L_9B73		;9b70
	ex de,hl			;9b72
L_9B73:
	xor a			;9b73
	ld (hl),a			;9b74
	ld (de),a			;9b75
	ld de,0ffd8h		;9b76   ; la velocidad del que cayo
	add hl,de			;9b79
	ld a,(hl)			;9b7a
	cp 040h		;9b7b   ; por debajo de 0x40, ya esta parado
	ret c			;9b7d
	add a,050h		;9b7e   ; y si no, se le frena
	jr nc,L_9B84		;9b80
	ld a,0ffh		;9b82
L_9B84:
	ld (hl),a			;9b84
	ret			;9b85

; ----------------------------------------------------------------------
; DATOS rle_a_ram_e400: 279 B -> 504 en RAM desde 0xE400
;   0x9b86..0x9c9d  (279 bytes)
DATA_rle_a_ram_e400:
	defb 002h,07bh,085h,07eh,07bh,07bh,07eh,07bh,007h,082h,02ah,00eh,007h,05fh,002h,07bh	; 9b86  .{.~{{~{..*.._.{
	defb 085h,07eh,07bh,07bh,07eh,07bh,007h,082h,012h,00eh,083h,083h,05eh,05eh,003h,00eh	; 9b96  .~{{~{......^^..
	defb 096h,087h,084h,00eh,053h,00eh,00eh,088h,086h,085h,054h,057h,00eh,00eh,060h,00eh	; 9ba6  ....S.....TW..`.
	defb 06dh,075h,075h,05fh,05fh,089h,055h,003h,06ch,082h,07bh,07eh,005h,073h,083h,082h	; 9bb6  muu__.U.l.{~.s..
	defb 062h,078h,004h,074h,084h,00eh,064h,063h,079h,003h,075h,087h,00eh,066h,067h,065h	; 9bc6  bx.t..dcy.u..fge
	defb 079h,003h,07dh,003h,00eh,084h,068h,00eh,079h,058h,003h,00eh,081h,069h,003h,05eh	; 9bd6  y.}...h.yX...i.^
	defb 00eh,00eh,007h,05fh,005h,073h,082h,07eh,07bh,004h,074h,083h,076h,083h,082h,003h	; 9be6  ..._.s.~{.t.v...
	defb 075h,08fh,077h,087h,084h,00eh,07dh,003h,077h,088h,086h,085h,00eh,058h,077h,00eh	; 9bf6  u.w...}.w....Xw.
	defb 060h,003h,00eh,003h,05eh,081h,061h,011h,00eh,007h,05fh,002h,07bh,085h,07eh,07bh	; 9c06  `...^.a..._.{.~{
	defb 07bh,07eh,07bh,007h,082h,00eh,00eh,002h,05eh,081h,062h,004h,00eh,084h,050h,00eh	; 9c16  {~{.....^.b...P.
	defb 064h,063h,003h,00eh,08eh,057h,051h,066h,067h,065h,00eh,00eh,075h,075h,091h,00eh	; 9c26  dc...WQfge..uu..
	defb 068h,00eh,00eh,003h,06ch,08bh,052h,08ah,05fh,05fh,07bh,07bh,07eh,07bh,07bh,07eh	; 9c36  h...l.R.__{{~{{~
	defb 07bh,007h,082h,00eh,00eh,007h,05eh,007h,056h,007h,057h,007h,075h,007h,06ch,007h	; 9c46  {.....^.V.W.u.l.
	defb 073h,007h,074h,007h,075h,003h,07fh,081h,07dh,003h,07fh,003h,059h,081h,058h,003h	; 9c56  s.t.u...}...Y.X.
	defb 059h,007h,05eh,00eh,00eh,007h,05fh,002h,07bh,085h,07eh,07bh,07bh,07eh,07bh,004h	; 9c66  Y.^..._.{.~{{~{.
	defb 082h,083h,092h,082h,082h,003h,00eh,082h,095h,094h,005h,00eh,081h,09bh,006h,00eh	; 9c76  ................
	defb 081h,09ch,005h,00eh,082h,095h,094h,005h,00eh,081h,09bh,006h,00eh,081h,09ch,004h	; 9c86  ................
	defb 00eh,082h,05fh,093h,005h,05fh,000h	; 9c96

; ======================================================================
; CODIGO 0x9c9d..0x9d14  (119 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LOS OCHO DESPLAZAMIENTOS. Un ciclista esta repartido entre las dos capas de la pantalla, y esto monta la que va en CASILLAS: la rueda de atras con su sillin, un dibujo de 16x16 -dos por dos tiles- que se pone en la tabla de patrones a partir del 0xA0 y del 0xD0. El ciclista propiamente dicho, el cuadro, el manillar y la rueda de delante son SPRITES, y no pasan por aqui. Para que la rueda pueda moverse al pixel y no de ocho en ocho, se generan OCHO copias del mismo dibujo, cada una corrida un pixel mas que la anterior, rotando los bits en la RAM y subiendo cada version a la VRAM; de paso sale la mascara, porque el `ld a,0ffh` y su `rra` van dejando unos por donde el dibujo ya no llega. Los dos dibujos son las dos FASES del giro: en una misma pantalla se ve un ciclista con los tiles 0xA0 y otro con los 0xD0. Medido sobre la VRAM del emulador con tools/capas.py, que separa las dos capas.
; ----------------------------------------------------------------------
monta_las_ruedas_en_ocho_pasos:		; los dos dibujos, cada uno en ocho
	ld hl,024d0h		;9c9d   ; el primer dibujo de la rueda
	ld ix,09d14h		;9ca0
	call ocho_copias_corridas		;9ca4
	ld ix,09d34h		;9ca7   ; y el segundo
	ld hl,02650h		;9cab
	call ocho_copias_corridas		;9cae
	ld b,010h		;9cb1   ; dieciseis bloques
	ld hl,00500h		;9cb3
L_9CB6:
	ld de,09d54h		;9cb6
	push bc			;9cb9
	push hl			;9cba
	call descomprime_en_los_tres_tercios		;9cbb   ; el mismo relleno en los tres tercios
	pop hl			;9cbe
	ld de,00030h		;9cbf   ; y el bloque siguiente
	add hl,de			;9cc2
	pop bc			;9cc3
	djnz L_9CB6		;9cc4
	ret			;9cc6
ocho_copias_corridas:		; de una a ocho posiciones
	ld (0e128h),hl		;9cc7   ; donde va la primera
	ld h,000h		;9cca   ; sin corrimiento: la copia tal cual
L_9CCC:
	ld iy,0e140h		;9ccc   ; el buffer de la RAM
	ld c,010h		;9cd0   ; dieciseis filas
	push hl			;9cd2
	push ix		;9cd3
L_9CD5:
	ld b,h			;9cd5
	ld d,(ix+000h)		;9cd6   ; la fila izquierda del dibujo
	ld e,(ix+010h)		;9cd9   ; y la derecha
	inc ix		;9cdc
	ld a,0ffh		;9cde   ; la mascara, entera
	inc b			;9ce0
	dec b			;9ce1   ; en la primera copia no se rota nada
	jr z,L_9CEC		;9ce2
L_9CE4:
	scf			;9ce4   ; un uno por delante
	rr d		;9ce5   ; y las dos mitades y la mascara, corridas a la vez
	rr e		;9ce7
	rra			;9ce9
	djnz L_9CE4		;9cea
L_9CEC:
	ld (iy+000h),d		;9cec   ; la fila izquierda
	ld (iy+010h),e		;9cef   ; la derecha
	ld (iy+020h),a		;9cf2   ; y la mascara
	inc iy		;9cf5
	dec c			;9cf7
	jr nz,L_9CD5		;9cf8
	ld hl,(0e128h)		;9cfa   ; donde va la copia siguiente
	ld bc,00030h		;9cfd
	add hl,bc			;9d00
	ld (0e128h),hl		;9d01
	ld de,0e140h		;9d04
	call ldirvm_en_los_tres_tercios		;9d07   ; esta copia, a los tres tercios
	pop ix		;9d0a
	pop hl			;9d0c
	inc h			;9d0d   ; una posicion mas
	ld a,h			;9d0e
	cp 008h		;9d0f   ; hasta las ocho
	jr nz,L_9CCC		;9d11
	ret			;9d13

; ----------------------------------------------------------------------
; DATOS patron_9d14: 32 B, o sea un sprite de 16x16 entero; lo carga 0x9CA0
;   con `ld ix,09d14h`
;   0x9d14..0x9d34  (32 bytes)
DATA_patron_9d14:
	defb 0ffh,0ffh,0ffh,0f8h,0f3h,0e7h,0efh,0cbh	; 9d14  ........
	defb 0ddh,0deh,0deh,0cdh,0ebh,0e7h,0f3h,0c0h	; 9d1c  ........
	defb 080h,0c3h,0f0h,023h,0cbh,089h,0a5h,074h	; 9d24  ...#...t
	defb 038h,032h,040h,0a2h,0d2h,0e7h,0ceh,000h	; 9d2c  82@.....

; ----------------------------------------------------------------------
; DATOS patron_9d34: 32 B, el otro sprite de 16x16; desde 0x9CA7
;   0x9d34..0x9d54  (32 bytes)
DATA_patron_9d34:
	defb 0ffh,0ffh,0ffh,0f8h,0f3h,0e6h,0eeh,0ceh	; 9d34  ........
	defb 0deh,0d1h,0deh,0ceh,0eeh,0e6h,0f3h,0c0h	; 9d3c  ........
	defb 080h,0c3h,0f0h,023h,0cbh,089h,0a5h,054h	; 9d44  ...#...T
	defb 038h,032h,040h,0f2h,0f0h,0e4h,0cfh,000h	; 9d4c  82@.....

; ----------------------------------------------------------------------
; DATOS rle_9d54: 11 B -> 48 de VRAM en los tres tercios desde 0x0500
;   0x9d54..0x9d5f  (11 bytes)
DATA_rle_9d54:
	defb 010h,0e0h,002h,0ech,00eh,0e0h,002h,0ech,00eh,0e0h,000h	; 9d54  ...........

; ----------------------------------------------------------------------
; DATOS rle_patrones_9d5f: 439 B -> 640 de VRAM en los tres tercios desde
;   0x2268
;   0x9d5f..0x9f16  (439 bytes)
DATA_rle_patrones_9d5f:
	defb 088h,000h,020h,024h,029h,030h,030h,028h,024h,003h,000h,081h,050h,003h,0a8h,086h	; 9d5f  .. $)00($...P...
	defb 0ach,000h,040h,040h,050h,068h,003h,048h,0afh,0ffh,07fh,03fh,01fh,00fh,007h,003h	; 9d6f  ..@@Ph.H...?....
	defb 001h,0ffh,07fh,03fh,01fh,00fh,007h,003h,001h,0ffh,07fh,03fh,01fh,00fh,007h,003h	; 9d7f  ...?.......?....
	defb 000h,0ffh,0feh,0fch,0f8h,0f0h,0e0h,0c0h,080h,0ffh,0feh,0fch,0f8h,0f0h,0e0h,0c0h	; 9d8f  ................
	defb 080h,0ffh,0feh,0fch,0f8h,0f0h,0e0h,0c0h,003h,000h,081h,0ffh,004h,000h,081h,0ffh	; 9d9f  ................
	defb 004h,000h,081h,0ffh,003h,000h,083h,03ch,01ch,01ch,005h,03ch,083h,000h,0ffh,0ffh	; 9daf  .......<...<....
	defb 00eh,000h,083h,0ffh,000h,000h,004h,0ffh,010h,000h,004h,0ffh,002h,000h,006h,0ffh	; 9dbf  ................
	defb 002h,000h,002h,0ffh,082h,040h,041h,004h,043h,083h,013h,0b3h,087h,008h,0ffh,091h	; 9dcf  .....@A.C.......
	defb 0c3h,001h,04dh,04dh,00dh,001h,002h,07fh,0bfh,0dfh,06fh,037h,01bh,00dh,006h,003h	; 9ddf  ..MM......o7....
	defb 081h,003h,0c0h,08ch,0c8h,0cch,0cah,047h,083h,0dbh,09bh,003h,00dh,006h,000h,0e3h	; 9def  .......G........
	defb 007h,0ffh,08ah,003h,081h,0c0h,0e0h,0f0h,0f8h,0fch,0feh,002h,082h,004h,0c2h,083h	; 9dff  ................
	defb 0c8h,0cdh,0e1h,007h,0ffh,010h,000h,007h,0ffh,089h,000h,0ffh,0feh,0fch,0f8h,0f0h	; 9e0f  ................
	defb 0e0h,03fh,010h,008h,000h,002h,018h,083h,01ch,00fh,007h,006h,000h,002h,0ffh,003h	; 9e1f  .?..............
	defb 000h,002h,018h,083h,038h,0f0h,0e0h,003h,000h,004h,080h,002h,0ffh,002h,000h,002h	; 9e2f  ....8...........
	defb 0ffh,085h,000h,0ffh,000h,000h,0ffh,003h,000h,081h,0ffh,004h,000h,081h,0ffh,006h	; 9e3f  ................
	defb 000h,0a2h,0ffh,000h,001h,003h,007h,00fh,01fh,03fh,07fh,0ffh,001h,003h,007h,00fh	; 9e4f  .........?......
	defb 01fh,03fh,07fh,0ffh,080h,0c0h,0e0h,0f0h,0f8h,0fch,0feh,0ffh,080h,0c0h,0e0h,0f0h	; 9e5f  .?..............
	defb 0f8h,0fch,0feh,0ffh,00ah,000h,084h,0ffh,000h,000h,0ffh,00ah,000h,004h,03ch,002h	; 9e6f  ..............<.
	defb 01ch,002h,03ch,002h,00eh,086h,006h,00eh,00eh,006h,00eh,00eh,004h,000h,002h,0ffh	; 9e7f  ..<.............
	defb 012h,000h,005h,0ffh,081h,000h,003h,0ffh,089h,0c3h,080h,0b2h,0b2h,0b0h,080h,060h	; 9e8f  ...............`
	defb 0c0h,081h,003h,003h,084h,013h,033h,053h,0c7h,007h,0ffh,099h,0c0h,081h,003h,007h	; 9e9f  ......3S........
	defb 00fh,01fh,03fh,07fh,0feh,0fdh,0fbh,0f6h,0ech,0d8h,0b0h,060h,0e2h,0c1h,0dbh,0dah	; 9eaf  ..?........`....
	defb 0c0h,0b0h,060h,000h,087h,007h,0ffh,081h,0e1h,007h,0ffh,030h,000h,088h,0ffh,07fh	; 9ebf  ..`........0....
	defb 03fh,01fh,00fh,007h,0fch,001h,005h,0ffh,08ch,000h,07fh,07fh,0feh,0feh,0fch,0fdh	; 9ecf  ?...............
	defb 000h,000h,0ffh,0ffh,07fh,007h,0ffh,003h,0feh,085h,0fch,0fdh,0fdh,0f9h,0fbh,003h	; 9edf  ................
	defb 000h,083h,007h,00fh,01ch,00ah,018h,003h,000h,085h,0e0h,0f0h,038h,018h,018h,005h	; 9eef  ............8...
	defb 000h,081h,0ffh,00ah,080h,085h,0fbh,0f3h,0f7h,0f7h,0e7h,003h,0efh,002h,0dfh,086h	; 9eff  ................
	defb 09fh,0bfh,0bfh,03fh,07fh,07fh,000h	; 9f0f

; ----------------------------------------------------------------------
; DATOS rle_color_9d5f: 145 B -> las mismas 640 posiciones en 0x0268
;   0x9f16..0x9fa7  (145 bytes)
DATA_rle_color_9d5f:
	defb 018h,0f0h,002h,0e3h,081h,0ech,004h,0e3h,081h,0ech,004h,0e3h,081h,0ech,00ah,0e3h	; 9f16  ................
	defb 084h,0e0h,0e3h,0e3h,0ech,004h,0e3h,081h,0ech,004h,0e3h,081h,0ech,00ah,0e3h,081h	; 9f26  ................
	defb 0e0h,010h,0c3h,083h,0f3h,0f7h,0f1h,004h,0f3h,083h,013h,073h,073h,006h,013h,020h	; 9f36  ...........ss.. 
	defb 000h,00fh,0efh,081h,00eh,050h,0efh,010h,000h,008h,030h,006h,0e3h,082h,0ceh,0e3h	; 9f46  .....P....0.....
	defb 008h,000h,018h,06eh,007h,0feh,081h,0f1h,00ah,0c2h,00eh,0c3h,002h,0e2h,081h,0ech	; 9f56  ...n............
	defb 00dh,0e3h,002h,0e2h,081h,0ech,00dh,0e3h,008h,000h,008h,012h,008h,000h,090h,0f3h	; 9f66  ................
	defb 083h,0f3h,083h,0f7h,0f1h,0f3h,0f3h,0f2h,062h,0f1h,0f2h,0f2h,0f1h,0f2h,012h,005h	; 9f76  ........b.......
	defb 073h,003h,013h,010h,000h,03fh,0efh,081h,00fh,007h,0efh,081h,00fh,030h,0efh,006h	; 9f86  s....?.......0..
	defb 0e3h,082h,0ceh,0e3h,00fh,0efh,081h,01fh,010h,0efh,018h,06eh,010h,0feh,010h,0efh	; 9f96  ...........n....
	defb 000h	; 9fa6

; ----------------------------------------------------------------------
; DATOS rle_9fa7: 16 B -> 16 de VRAM. Es el mismo flujo que se usa DOS veces:
;   0x5435 entra por 0x9FA7, donde los dos primeros bytes traen el destino, y
;   0x58C6 entra por 0x9FA9 con el destino en HL (0x22C0) y en los tres
;   tercios
;   0x9fa7..0x9fb7  (16 bytes)
DATA_rle_9fa7:
	defb 0c0h,022h,084h,000h,020h,020h,040h,005h,000h,083h,024h,024h,048h,004h,000h,000h	; 9fa7  ."..  @...$$H...

; ----------------------------------------------------------------------
; DATOS rle_9fb7: 635 B -> 928 de VRAM de una tacada
;   0x9fb7..0xa232  (635 bytes)
DATA_rle_9fb7:
	defb 000h,018h,009h,000h,082h,0f8h,0feh,005h,0ffh,009h,000h,083h,03ch,07eh,07fh,004h	; 9fb7  ............<~..
	defb 0ffh,00ah,000h,086h,030h,070h,0f8h,0fch,0fch,0ffh,00bh,000h,08ah,060h,0e4h,0f6h	; 9fc7  ....0p.......`..
	defb 0ffh,07fh,0feh,07eh,03fh,01fh,00fh,003h,007h,08dh,00fh,01eh,01ch,01ch,00eh,006h	; 9fd7  ...~?...........
	defb 000h,000h,0efh,0f4h,07ch,03eh,08ch,003h,080h,008h,000h,08bh,0ffh,07fh,03fh,01fh	; 9fe7  ....|>........?.
	defb 01fh,03eh,07eh,0f8h,0f0h,078h,01ch,005h,000h,085h,0efh,0f4h,0feh,07eh,01ch,00bh	; 9ff7  .>~..x.......~..
	defb 000h,089h,0feh,07fh,01fh,007h,003h,003h,007h,007h,001h,007h,000h,089h,0efh,06ch	; a007  ...............l
	defb 0feh,0feh,0cch,0c0h,080h,0c0h,0f0h,007h,000h,0d2h,017h,008h,0ffh,01fh,034h,07ch	; a017  ..............4|
	defb 0d6h,0a6h,023h,0a1h,0a1h,0a2h,014h,018h,00ch,0ffh,080h,040h,0c0h,0e0h,030h,018h	; a027  ..#........@..0.
	defb 008h,02ch,044h,084h,084h,04ch,028h,018h,030h,0ffh,017h,008h,0ffh,01fh,03ch,07dh	; a037  .,D..L(.0.....<}
	defb 0d5h,0a7h,023h,02eh,0a1h,0a1h,011h,099h,00ch,0ffh,080h,040h,0c0h,0e0h,030h,018h	; a047  ..#........@..0.
	defb 008h,00ch,004h,0e4h,004h,00ch,008h,018h,030h,0ffh,000h,00eh,09fh,0ffh,0ffh,07fh	; a057  ........0.......
	defb 07fh,035h,023h,057h,06eh,054h,0fch,0beh,0c0h,000h,000h,002h,004h,0ffh,084h,0f8h	; a067  .5#WnT..........
	defb 090h,050h,0e0h,007h,000h,095h,006h,009h,012h,020h,00ch,092h,010h,017h,092h,00eh	; a077  .P....... ......
	defb 020h,012h,009h,006h,000h,000h,0e0h,01ch,022h,000h,038h,004h,044h,086h,038h,000h	; a087   .......".8.D.8.
	defb 022h,01ch,0e0h,000h,003h,001h,005h,0ffh,003h,001h,006h,000h,08ah,080h,0c0h,0e0h	; a097  "...............
	defb 0f0h,0f8h,0f8h,0f0h,0e0h,0c0h,080h,00ah,000h,088h,002h,050h,0f2h,0f1h,0f8h,0f8h	; a0a7  ...........P....
	defb 078h,030h,008h,000h,089h,080h,000h,080h,000h,02ch,03eh,03ch,03ch,018h,005h,000h	; a0b7  x0.......,><<...
	defb 088h,020h,077h,07fh,02fh,00fh,007h,003h,001h,009h,000h,086h,0c0h,0e0h,0e0h,0e6h	; a0c7  . w./...........
	defb 0c6h,082h,006h,000h,089h,03eh,07fh,0ffh,0ffh,0c1h,080h,080h,000h,03eh,005h,0ffh	; a0d7  .....>.......>..
	defb 084h,0feh,0fch,000h,000h,005h,080h,00ch,000h,085h,0c0h,0e2h,0f0h,072h,079h,003h	; a0e7  .............ry.
	defb 038h,081h,010h,008h,000h,084h,088h,00ch,09ch,03ch,003h,038h,002h,010h,003h,000h	; a0f7  8........<.8....
	defb 084h,0c0h,0e0h,0e0h,007h,003h,00fh,083h,007h,003h,001h,006h,000h,089h,004h,00ch	; a107  ................
	defb 01eh,0ceh,0e4h,0e0h,0e0h,0c0h,080h,00bh,000h,089h,0e0h,0e2h,0e0h,0f2h,071h,078h	; a117  ..............qx
	defb 038h,038h,010h,008h,000h,090h,080h,000h,080h,000h,030h,038h,03ch,01eh,00ch,004h	; a127  88........08<...
	defb 000h,000h,020h,070h,070h,007h,003h,00fh,083h,007h,003h,001h,009h,000h,081h,0c0h	; a137  .. pp...........
	defb 003h,0e0h,082h,0c0h,080h,003h,000h,083h,002h,003h,007h,045h,000h,08ah,002h,030h	; a147  ...........E...0
	defb 071h,0f2h,0e8h,0f8h,0f8h,078h,070h,020h,006h,000h,08ah,080h,000h,000h,080h,030h	; a157  q....xp .......0
	defb 038h,03ch,01eh,00ch,004h,005h,000h,081h,00fh,003h,01fh,083h,007h,003h,001h,009h	; a167  8<..............
	defb 000h,081h,0c0h,003h,0e0h,082h,0c0h,080h,003h,000h,091h,006h,007h,007h,0fch,0feh	; a177  ................
	defb 07fh,03fh,01fh,00fh,007h,007h,00fh,01eh,01ch,01ch,00eh,006h,006h,000h,004h,080h	; a187  .?..............
	defb 008h,000h,002h,0fch,08ah,07eh,03eh,01fh,00fh,01fh,07eh,0f8h,0f0h,078h,01ch,014h	; a197  .....~>...~..x..
	defb 000h,08ah,0fch,0feh,07fh,01fh,007h,003h,007h,00fh,00eh,007h,009h,000h,087h,080h	; a1a7  ................
	defb 0c0h,0c0h,080h,000h,000h,080h,00bh,000h,08bh,001h,003h,061h,0f2h,060h,090h,001h	; a1b7  ...........a.`..
	defb 051h,030h,018h,008h,005h,000h,09dh,080h,0c0h,086h,04fh,006h,009h,040h,0c5h,086h	; a1c7  Q0........O..@..
	defb 08ch,008h,03fh,040h,080h,082h,087h,08fh,09fh,08fh,087h,083h,081h,083h,087h,080h	; a1d7  ..?@............
	defb 040h,03fh,0fch,002h,003h,001h,082h,089h,0d9h,006h,0f9h,096h,001h,002h,0fch,03fh	; a1e7  @?.............?
	defb 040h,080h,087h,083h,081h,083h,087h,08fh,09fh,08fh,087h,082h,080h,040h,03fh,0fch	; a1f7  @............@?.
	defb 002h,001h,006h,0f9h,082h,0d9h,089h,003h,001h,084h,002h,0fch,03fh,03fh,00ch,0ffh	; a207  ............??..
	defb 002h,03fh,002h,0fch,00ch,0ffh,002h,0fch,009h,000h,087h,062h,095h,015h,025h,015h	; a217  .?.........b..%.
	defb 095h,062h,009h,000h,081h,022h,005h,055h,081h,022h,000h	; a227  .b...".U.".

; ======================================================================
; CODIGO 0xa232..0xa2e8  (182 bytes)
; ======================================================================


vuelca_los_sprites_de_arriba:		; una ventana si y otra no
	ld a,(0e003h)		;a232   ; el bit 0 del contador de fotogramas
	rra			;a235
	jr nc,L_A254		;a236
vuelca_los_sprites_de_la_ventana_1:
	ld hl,03b00h		;a238   ; la tabla de atributos
	call 00053h		;a23b   ; BIOS SETWRT - Enables VDP to write
	ld ix,0e0a0h		;a23e   ; el ciclista 1
	ld hl,0e0aeh		;a242
	call sprites_de_un_ciclista		;a245
	ld ix,0e0e0h		;a248   ; y el 2
	ld hl,0e0bbh		;a24c
	jr sprites_de_un_ciclista		;a24f
vuelca_los_sprites_de_las_dos:
	call vuelca_los_sprites_de_la_ventana_1		;a251
L_A254:
	ld hl,03b28h		;a254   ; los sprites de la ventana de abajo
	call 00053h		;a257   ; BIOS SETWRT - Enables VDP to write
	ld hl,0e0eeh		;a25a   ; en ella el ciclista 2 va primero
	ld ix,0e0e0h		;a25d
	call sprites_de_un_ciclista		;a261
	ld hl,0e0fbh		;a264
	ld ix,0e0a0h		;a267

; ----------------------------------------------------------------------
; Los sprites del ciclista salen por el puerto de datos uno detras de otro, sin tabla en RAM que valga: de la postura -el nibble de arriba del byte de estado- salen tres desplazamientos de la tabla de 0xA2FC, y de ahi las filas y los patrones de cada pieza. Los `push hl / pop hl` que hay mas abajo no mueven nada: son once tiempos de espera para que el VDP no se atragante.
; ----------------------------------------------------------------------
sprites_de_un_ciclista:		; tres piezas y sus remates, por el puerto
	exx			;a26b
	ld a,(00006h)		;a26c   ; el puerto de datos, a mano
	ld c,a			;a26f
	exx			;a270
	ld a,(hl)			;a271   ; el byte de estado
	ld (0e128h),a		;a272
	rra			;a275   ; su nibble de arriba: la postura
	rra			;a276
	rra			;a277
	rra			;a278
	and 00fh		;a279
	push af			;a27b
	ld c,a			;a27c
	add a,a			;a27d
	add a,c			;a27e   ; por tres: tres piezas por postura
	inc hl			;a27f
	exx			;a280
	ld hl,0a2fch		;a281   ; la tabla de las posturas
	call suma_a_hl		;a284
	ld b,003h		;a287   ; tres piezas
	exx			;a289
	ld c,(hl)			;a28a
	inc hl			;a28b
	ld b,(hl)			;a28c
	inc hl			;a28d
	pop af			;a28e
	ld de,0a2e8h		;a28f   ; los desplazamientos de una postura
	jr z,L_A297		;a292
	ld de,0a2f2h		;a294   ; o los de la otra
L_A297:
	exx			;a297
	call saca_un_sprite		;a298
	ld b,001h		;a29b
	ld a,(0e128h)		;a29d
	push af			;a2a0
	and 0f0h		;a2a1   ; el nibble de arriba
	ld hl,0a311h		;a2a3   ; unos patrones
	jr z,L_A2AB		;a2a6
	ld hl,0a314h		;a2a8   ; u otros
L_A2AB:
	pop af			;a2ab
	and 00fh		;a2ac
	call suma_a_hl		;a2ae
	call saca_un_sprite		;a2b1
	ld b,001h		;a2b4
	ld hl,0a317h		;a2b6
	bit 4,(ix+005h)		;a2b9   ; el bit 4 de la posicion
	jr z,L_A2C0		;a2bd
	inc hl			;a2bf   ; cambia el patron de la rueda
L_A2C0:
	exx			;a2c0
	ld hl,0a319h		;a2c1
	exx			;a2c4
saca_un_sprite:		; los cuatro bytes de un sprite, con sus esperas
	exx			;a2c5
	ld a,(de)			;a2c6   ; la fila
	inc a			;a2c7   ; el 0xFF esconde el sprite
	jr nz,L_A2CE		;a2c8
	ld a,0dfh		;a2ca   ; y 0xDF es una fila que no existe
	jr L_A2D0		;a2cc
L_A2CE:
	dec a			;a2ce
	add a,c			;a2cf   ; mas la fila de la figura
L_A2D0:
	exx			;a2d0
	out (c),a		;a2d1   ; a la VRAM
	exx			;a2d3
	inc de			;a2d4
	ld a,(de)			;a2d5   ; la columna
	inc de			;a2d6
	add a,b			;a2d7   ; mas la de la figura
	exx			;a2d8
	out (c),a		;a2d9
	ld a,(hl)			;a2db   ; el patron
	inc hl			;a2dc
	out (c),a		;a2dd
	exx			;a2df
	ld a,(hl)			;a2e0   ; y el color
	inc hl			;a2e1
	exx			;a2e2
	out (c),a		;a2e3
	djnz saca_un_sprite		;a2e5
	ret			;a2e7

; ----------------------------------------------------------------------
; DATOS tabla_a2e8: 10 B; la carga 0xA28F
;   0xa2e8..0xa2f2  (10 bytes)
DATA_tabla_a2e8:
	defb 0f0h,0fah,0ffh,000h,0f0h,0feh,000h,0fbh,000h,000h	; a2e8  ..........

; ----------------------------------------------------------------------
; DATOS tabla_a2f2: 10 B; la carga 0xA294
;   0xa2f2..0xa2fc  (10 bytes)
DATA_tabla_a2f2:
	defb 0f0h,0f8h,0f0h,0f8h,0f0h,0fbh,000h,0fbh,000h,000h	; a2f2  ..........

; ----------------------------------------------------------------------
; DATOS tabla_a2fc: 21 B; la carga 0xA281
;   0xa2fc..0xa311  (21 bytes)
DATA_tabla_a2fc:
	defb 004h,0ffh,000h,028h,02ch,030h,034h,038h,030h,03ch,040h,030h,044h,048h,030h,03ch,040h,030h,04ch,050h,030h	; a2fc  ...(,0480<@0DH0<@0LP0

; ----------------------------------------------------------------------
; DATOS tablas_a311: 9 B en cuatro trozos que cargan 0xA2A3, 0xA2A8, 0xA2B6 y
;   0xA2C1
;   0xa311..0xa31a  (9 bytes)
DATA_tablas_a311:
	defb 008h,00ch,010h	; a311
	defb 054h,058h,05ch	; a314
	defb 014h,018h	; a317
	defb 001h	; a319

; ======================================================================
; CODIGO 0xa31a..0xa484  (362 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; El ciclista se pinta METIENDO su tile en la ventana de la RAM, asi que antes hay que guardar lo que habia debajo para poder devolverlo en el fotograma siguiente. El puntero de las casillas tapadas se guarda con ellas, de modo que devolverlas es leer el puntero y soltar los bytes.
; ----------------------------------------------------------------------
devuelve_el_fondo_de_los_dos:		; lo que habia debajo de los ciclistas
	ld hl,0e0b5h		;a31a
	call devuelve_el_fondo		;a31d
	ld hl,0e0f5h		;a320
devuelve_el_fondo:		; las casillas guardadas, a su sitio
	ld e,(hl)			;a323   ; donde estaban
	inc hl			;a324
	ld d,(hl)			;a325
	inc hl			;a326
	call L_A32F		;a327
	ld a,01eh		;a32a   ; la fila de abajo
L_A32C:
	call suma_a_de		;a32c
L_A32F:
	ldi		;a32f
L_A331:
	ldi		;a331
	ret			;a333
pinta_a_los_rivales:		; el ciclista de cada ventana, en la del otro
	ld ix,0e0a0h		;a334   ; el ciclista 1, en la ventana del 2
	ld de,0e0e0h		;a338
	call L_A345		;a33b
	ld de,0e0c0h		;a33e   ; y el 2 en la del 1
	ld ix,0e0e0h		;a341
L_A345:
	call posicion_del_ciclista_en_la_ventana		;a345
	ret c			;a348   ; fuera de la ventana, nada
	ld a,h			;a349
	sub 010h		;a34a   ; diez y seis filas mas arriba
	jr nc,L_A34F		;a34c
	xor a			;a34e   ; y de cero no sube
L_A34F:
	ld h,a			;a34f
	call casilla_de_la_ventana_desde_hl		;a350   ; la casilla
	ex de,hl			;a353
	bit 0,(ix+033h)		;a354
	ld hl,0e0c4h		;a358   ; el hueco del fondo del jugador 1
	jr z,L_A360		;a35b
	ld hl,0e104h		;a35d   ; o el del 2
L_A360:
	call L_A32F		;a360
	ldi		;a363
	ld a,01dh		;a365
	call L_A32C		;a367
	jr L_A331		;a36a
pinta_a_los_dos_ciclistas:		; cada uno en su ventana
	ld ix,0e0a0h		;a36c   ; el ciclista 1
	ld de,0e140h		;a370   ; en su ventana
	call casilla_de_la_ventana		;a373
	call pinta_un_ciclista		;a376
	ld ix,0e0e0h		;a379   ; y el 2 en la suya
	ld de,0e260h		;a37d
	call casilla_de_la_ventana		;a380
pinta_un_ciclista:		; dos casillas, con el fondo guardado
	ld c,0a0h		;a383   ; los tiles de un carril
	bit 4,(ix+005h)		;a385   ; el bit 4 de la posicion
	jr z,L_A38D		;a389
	ld c,0d0h		;a38b   ; y los del otro
L_A38D:
	ex de,hl			;a38d
	ld hl,0e0b5h		;a38e   ; donde se apunta lo tapado del jugador 1
	bit 0,(ix+033h)		;a391
	jr z,L_A39A		;a395
	ld hl,0e0f5h		;a397   ; o del 2
L_A39A:
	ld (hl),e			;a39a   ; el puntero, guardado con el fondo
	inc hl			;a39b
	ld (hl),d			;a39c
	inc hl			;a39d
	ex de,hl			;a39e
	call pon_tile_y_guarda_el_fondo		;a39f
	dec c			;a3a2
	inc de			;a3a3
	ld a,01fh		;a3a4   ; y la fila de abajo
	call suma_a_hl		;a3a6
pon_tile_y_guarda_el_fondo:		; el tile entra, lo que habia sale
	ld a,(hl)			;a3a9   ; lo que habia
	ld (hl),c			;a3aa   ; el tile del ciclista
	inc c			;a3ab   ; y el de al lado
	inc c			;a3ac
	inc hl			;a3ad
	ld (de),a			;a3ae   ; lo tapado, apuntado
	inc de			;a3af
	ld a,(hl)			;a3b0
	ld (hl),c			;a3b1
	ld (de),a			;a3b2
	ret			;a3b3
pinta_a_cada_uno_en_la_otra_ventana:		; el rival, con cuatro casillas
	ld ix,0e0a0h		;a3b4   ; el ciclista 1
	ld hl,0e0e5h		;a3b8   ; con la posicion del 2
	call tile_del_rival		;a3bb
	ld de,0e0e0h		;a3be   ; en la ventana del 2
	call L_A3D1		;a3c1
	ld hl,0e0a5h		;a3c4   ; y al reves
	ld ix,0e0e0h		;a3c7
	call tile_del_rival		;a3cb
	ld de,0e0c0h		;a3ce
L_A3D1:
	call posicion_del_ciclista_en_la_ventana		;a3d1
	ret c			;a3d4   ; fuera de la ventana, nada
	ld a,h			;a3d5
	sub 010h		;a3d6   ; diez y seis filas mas arriba
	jr nc,L_A3DB		;a3d8
	xor a			;a3da
L_A3DB:
	ld h,a			;a3db
	call casilla_de_la_ventana_desde_hl		;a3dc   ; la casilla
	ld de,0e0c4h		;a3df
	bit 0,(ix+033h)		;a3e2   ; el hueco del jugador 1
	jr z,L_A3EB		;a3e6
	ld de,0e104h		;a3e8   ; o el del 2
L_A3EB:
	call pon_tile_y_guarda_el_fondo		;a3eb
	inc de			;a3ee
	inc hl			;a3ef
	inc c			;a3f0
	inc c			;a3f1
	ld a,(hl)			;a3f2   ; la casilla de al lado
	ld (hl),c			;a3f3
	ld (de),a			;a3f4
	inc de			;a3f5
	ld a,01eh		;a3f6   ; la fila de abajo
	call suma_a_hl		;a3f8
	dec c			;a3fb
	dec c			;a3fc
	dec c			;a3fd
	ld a,(hl)			;a3fe
	ld (hl),c			;a3ff   ; con su tile
	ld (de),a			;a400
	inc de			;a401
	inc hl			;a402
	inc c			;a403   ; y la de mas alla
	inc c			;a404
	jr pon_tile_y_guarda_el_fondo		;a405
tile_del_rival:		; el tile que le toca segun el desplazamiento
	ld a,(hl)			;a407
	ld c,0a0h		;a408   ; los tiles de un carril
	bit 4,a		;a40a
	jr z,L_A410		;a40c
	ld c,0d0h		;a40e   ; o los del otro
L_A410:
	ld a,(ix+01dh)		;a410   ; los tres bits de abajo son el desplazamiento fino
	and 007h		;a413
	add a,a			;a415   ; por seis: seis tiles por posicion
	ld b,a			;a416
	add a,a			;a417
	add a,b			;a418
	add a,c			;a419   ; y ese es el primer tile
	ld c,a			;a41a
	ret			;a41b
posicion_del_ciclista_en_la_ventana:		; con acarreo si no cabe
	ld l,(ix+01ch)		;a41c   ; la columna
	ld h,(ix+01dh)		;a41f   ; y la fila
	ld a,l			;a422
	cp 0d0h		;a423   ; la 0xD0 es la de fuera
	ccf			;a425
	ret			;a426
casilla_de_la_ventana:		; la direccion dentro del buffer de RAM
	ld a,(ix+003h)		;a427   ; la fila, a multiplo de ocho
	and 0f8h		;a42a
	ld l,a			;a42c
	ld h,000h		;a42d
	add hl,hl			;a42f   ; por cuatro: treinta y dos casillas por fila
	add hl,hl			;a430
	add hl,de			;a431   ; desde el buffer
	ld de,00049h		;a432   ; y el hueco del ciclista
	add hl,de			;a435
	ret			;a436
casilla_de_la_ventana_desde_hl:		; la misma, con la posicion en HL
	ld a,l			;a437
	and 0f8h		;a438   ; la columna, a multiplo de ocho
	ld l,a			;a43a
	ld a,h			;a43b
	ld h,000h		;a43c
	add hl,hl			;a43e   ; y la fila, por treinta y dos
	add hl,hl			;a43f
	rra			;a440
	rra			;a441
	rra			;a442
	and 01fh		;a443
	or l			;a445
	ld l,a			;a446
	add hl,de			;a447
	ret			;a448
mira_el_terreno:		; el circuito bajo cada ciclista
	ld ix,0e0a0h		;a449   ; el ciclista 1
	ld de,0e008h		;a44d   ; con sus flancos
	call L_A45A		;a450
	ld de,0e006h		;a453
	ld ix,0e0e0h		;a456   ; y el 2 con los suyos
L_A45A:
	ld a,(ix+032h)		;a45a   ; si ya llego, nada
	and a			;a45d
	ret nz			;a45e
	ld a,(ix+03ch)		;a45f   ; ni si esta cayendose
	and a			;a462
	ret nz			;a463
	ld a,(ix+00bh)		;a464   ; lo que hay bajo el ciclista
	call fila_del_circuito_o_llano		;a467
	ld (0e128h),a		;a46a
	ld a,(ix+000h)		;a46d   ; si esta fuera de carrera
	ld b,(ix+003h)		;a470
	ld c,(ix+034h)		;a473
	and a			;a476
	call nz,terreno_bajo_el_ciclista		;a477   ; se le mira aparte
	ld a,(de)			;a47a
	and 010h		;a47b   ; el disparo
	ret z			;a47d
	ld a,(0e128h)		;a47e   ; y segun el terreno, lo que toque
	call despacha_por_indice		;a481

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_a484: 8 entradas, simetricas dos a dos; detras
;   sigue `ld ix,0e0a0h`
;   0xa484..0xa494  (16 bytes)
DATA_tabla_de_subescenas_a484:
	defw 0a54bh,0a563h,0a56bh,0a562h,0a562h,0a563h,0a56bh,0a54bh	; a484

; ======================================================================
; CODIGO 0xa494..0xa588  (244 bytes)
; ======================================================================


chispas_del_choque:		; los cuatro bytes del sprite de la chispa
	ld ix,0e0a0h		;a494   ; la del ciclista 1
	ld hl,03b60h		;a498
	call L_A4A5		;a49b
	ld ix,0e0e0h		;a49e   ; y la del 2
	ld hl,03b64h		;a4a2
L_A4A5:
	ld a,(ix+03ch)		;a4a5   ; sin chispa que pintar, nada
	and a			;a4a8
	ret z			;a4a9
	call setwrt_y_guarda_el_puerto		;a4aa
	exx			;a4ad
	dec (ix+03ch)		;a4ae   ; una menos
	ld a,(ix+00fh)		;a4b1
	jr nz,L_A4B8		;a4b4
	ld a,0f8h		;a4b6   ; y al acabarse, fuera de la pantalla
L_A4B8:
	sub 018h		;a4b8   ; la fila
	out (c),a		;a4ba
	ld a,060h		;a4bc
	push hl			;a4be   ; espera de once tiempos: el VDP necesita respirar entre bytes
	pop hl			;a4bf
	out (c),a		;a4c0
	ld a,060h		;a4c2
	push hl			;a4c4
	pop hl			;a4c5
	out (c),a		;a4c6
	ld a,(ix+03ch)		;a4c8   ; al final la chispa cambia de color
	cp 010h		;a4cb
	ld a,00fh		;a4cd
	jr nc,L_A4D3		;a4cf
	ld a,006h		;a4d1
L_A4D3:
	out (c),a		;a4d3
	ret			;a4d5
terreno_bajo_el_ciclista:		; lo que hace segun por donde va
	xor a			;a4d6
	ld (de),a			;a4d7   ; los flancos, gastados
	ld a,(ix+00bh)		;a4d8   ; antes de la cuarta casilla, nada
	cp 004h		;a4db
	ret c			;a4dd
	ld a,(0e128h)		;a4de   ; el terreno
L_A4E1:
	and a			;a4e1
	jr z,mira_dos_casillas_mas_alla		;a4e2   ; el 0 es llano
	dec a			;a4e4
	jr z,esquiva_si_esta_libre		;a4e5   ; el 1
	dec a			;a4e7
	jr z,esquiva_si_esta_ocupado		;a4e8   ; el 2
	sub 003h		;a4ea   ; y los de mas alla
	jr z,esquiva_si_esta_libre		;a4ec
	dec a			;a4ee
	jr z,esquiva_si_esta_ocupado		;a4ef
	ret			;a4f1
mira_dos_casillas_mas_alla:		; lo que viene despues
	ld a,(ix+00bh)		;a4f2
	add a,002h		;a4f5   ; dos casillas mas alla
	call fila_del_circuito_o_llano		;a4f7
	and a			;a4fa   ; si eso tampoco es llano, se mira aquello
	jr nz,L_A4E1		;a4fb
	ld a,(ix+001h)		;a4fd   ; si va a rueda, nada
	and a			;a500
	ret nz			;a501
	ld hl,0e0abh		;a502   ; el ciclista 1
	bit 0,(ix+033h)		;a505
	jr nz,L_A50D		;a509
	ld l,0ebh		;a50b   ; o el 2
L_A50D:
	ld a,(hl)			;a50d
	push bc			;a50e   ; ocho bytes mas atras
	ld bc,0fff8h		;a50f
	add hl,bc			;a512
	pop bc			;a513
	sub (ix+00bh)		;a514   ; contra la casilla por la que va
	jr c,mira_si_esta_cerca		;a517
	cp 002h		;a519   ; a menos de dos, nada
	ret c			;a51b
	ld a,(ix+003h)		;a51c
	cp (hl)			;a51f   ; y en el mismo carril
	ret nz			;a520
	ld a,(0e002h)		;a521
	and 040h		;a524   ; el bit 6: si hay partida
	jr nz,pulsa_el_disparo		;a526
avisa_del_obstaculo:		; el disparo, dado por pulsado
	ld a,(0e003h)		;a528
	and 07fh		;a52b   ; uno de cada 128 fotogramas
	ret nz			;a52d
	jr pulsa_el_disparo		;a52e
mira_si_esta_cerca:		; a menos de 0x20 de distancia
	inc a			;a530
	ret z			;a531
	ld a,(ix+003h)		;a532   ; el carril de uno
	sub (hl)			;a535   ; contra el del otro
	jr nc,L_A53A		;a536
	neg		;a538   ; en positivo
L_A53A:
	cp 020h		;a53a   ; y solo a 0x20 justos
	ret nz			;a53c
pulsa_el_disparo:		; el bit 4, como si lo hubiese pulsado el jugador
	ld a,010h		;a53d   ; el bit 4 es el disparo
	ld (de),a			;a53f
	ret			;a540
esquiva_si_esta_libre:
	ld a,c			;a541   ; si el carril esta ocupado, no
	and a			;a542
	ret z			;a543
	jr pulsa_el_disparo		;a544
esquiva_si_esta_ocupado:
	ld a,c			;a546   ; si esta libre, no
	and a			;a547
	ret nz			;a548
	jr pulsa_el_disparo		;a549
decide_a_que_carril:		; el terreno de cada lado
	ld a,c			;a54b   ; lo que hay al lado
	and a			;a54c
	ld a,b			;a54d
	jr nz,L_A557		;a54e
	cp 020h		;a550   ; pegado al borde no se puede
	ret z			;a552
L_A553:
	ld a,002h		;a553   ; al carril de la derecha
	jr apunta_el_cambio_de_carril		;a555
L_A557:
	and a			;a557   ; y si esta libre, nada
	ret z			;a558
cambia_de_carril_1:		; hacia un lado
	ld a,001h		;a559
apunta_el_cambio_de_carril:		; el estado y su figura
	ld (ix+001h),a		;a55b   ; el estado del cambio
	dec a			;a55e
	ld (ix+034h),a		;a55f   ; y su figura
L_A562:
	ret			;a562
decide_a_la_izquierda:
	ld a,c			;a563   ; si el lado esta libre, nada
	and a			;a564
	ret z			;a565
	ld a,b			;a566   ; y si el otro esta ocupado, tampoco
	and a			;a567
	ret z			;a568
	jr cambia_de_carril_1		;a569
decide_a_la_derecha:
	ld a,c			;a56b   ; si el lado esta ocupado, no
	and a			;a56c
	ret nz			;a56d
	ld a,b			;a56e
	cp 020h		;a56f   ; y pegado al borde tampoco
	ret z			;a571
	jr L_A553		;a572
cambia_de_carril_a_los_dos:		; el cambio en marcha de cada ciclista
	ld ix,0e0a0h		;a574   ; el ciclista 1
	call L_A57F		;a578
	ld ix,0e0e0h		;a57b   ; y el 2
L_A57F:
	ld c,(ix+003h)		;a57f   ; su carril
	ld a,(ix+001h)		;a582   ; y el estado del cambio
	call despacha_por_indice		;a585

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_a588: 3 entradas; la cuarta seria 0xA779 pero
;   entonces la entrada [1] caeria dentro de la tabla
;   0xa588..0xa58e  (6 bytes)
DATA_tabla_de_subescenas_a588:
	defw 0a5afh,0a58eh,0a5b0h	; a588  -> L_A5AF cambia_hacia_la_izquierda cambia_hacia_la_derecha

; ======================================================================
; CODIGO 0xa58e..0xa751  (451 bytes)
; ======================================================================


cambia_hacia_la_izquierda:		; dos pixeles por fotograma
	ld a,c			;a58e   ; pegado al borde no se sigue
	and a			;a58f
	jr z,termina_el_cambio_de_carril		;a590
	call hay_algo_a_la_izquierda		;a592   ; si hay algo delante, se para
	jr c,$-66		;a595
	ld a,(ix+003h)		;a597
	sub 002h		;a59a   ; dos pixeles
	ld (ix+003h),a		;a59c
	ret nz			;a59f   ; y hasta llegar al borde, se sigue
termina_el_cambio_de_carril:		; el estado, a parado
	ld (ix+001h),000h		;a5a0   ; el cambio, terminado
	ld c,(ix+02bh)		;a5a4   ; y el carril de antes, apuntado
	cp c			;a5a7
	ret z			;a5a8
	ld (ix+02bh),a		;a5a9
	ld (ix+02ch),c		;a5ac
L_A5AF:
	ret			;a5af
cambia_hacia_la_derecha:		; dos pixeles por fotograma
	ld a,c			;a5b0
	cp 020h		;a5b1   ; pegado al borde no se sigue
	jr z,termina_el_cambio_de_carril		;a5b3
	call hay_algo_a_la_derecha		;a5b5   ; si hay algo delante, se para
	jr c,$-95		;a5b8
	ld a,(ix+003h)		;a5ba
	add a,002h		;a5bd   ; dos pixeles
	ld (ix+003h),a		;a5bf
	cp 020h		;a5c2   ; y hasta el borde
	ret nz			;a5c4
	jr termina_el_cambio_de_carril		;a5c5
hay_algo_a_la_izquierda:		; ocho pixeles hacia alla
	ld c,0f8h		;a5c7
	jr hay_algo_en_esa_casilla		;a5c9
hay_algo_a_la_derecha:
	ld c,010h		;a5cb
hay_algo_en_esa_casilla:		; mira el buffer de la ventana
	ld de,0e180h		;a5cd   ; la ventana del jugador 1
	ld a,(ix+033h)		;a5d0
	and a			;a5d3
	jr z,L_A5D9		;a5d4
	ld de,0e2a0h		;a5d6   ; o la del 2
L_A5D9:
	ld a,(ix+003h)		;a5d9   ; el carril, mas el desplazamiento
	add a,c			;a5dc
	ld l,a			;a5dd
	cp 040h		;a5de   ; fuera de la pista, se acabo
	ret nc			;a5e0
	ld h,060h		;a5e1   ; la fila de delante
	call que_hay_en_esa_casilla		;a5e3
	ret c			;a5e6
	dec hl			;a5e7   ; y tres casillas mas aca
	dec hl			;a5e8
	dec hl			;a5e9
	jr es_un_tile_que_para		;a5ea
mira_si_choca_de_frente:		; lo que hay delante de cada ciclista
	ld ix,0e0a0h		;a5ec   ; el ciclista 1
	ld de,0e180h		;a5f0
	call L_A5FD		;a5f3
	ld ix,0e0e0h		;a5f6   ; y el 2
	ld de,0e2a0h		;a5fa
L_A5FD:
	ld l,(ix+003h)		;a5fd   ; su carril
	ld h,060h		;a600
	call que_hay_en_esa_casilla		;a602
	jr c,L_A618		;a605   ; fuera de la pista, es choque
	ld de,00020h		;a607   ; la fila de delante
	add hl,de			;a60a
	ld a,(ix+003h)		;a60b
	cp 010h		;a60e   ; y a partir de 0x10, una casilla mas
	jr c,L_A613		;a610
	inc hl			;a612
L_A613:
	call es_un_tile_que_para		;a613
	jr nc,L_A639		;a616   ; si no hay nada, se sigue
L_A618:
	ld a,(ix+002h)		;a618
	and a			;a61b   ; si ya estaba chocando, no se repite
	jr nz,L_A627		;a61c
	ld a,048h		;a61e   ; el golpe
	call suena_si_hay_partida		;a620
	ld (ix+03ch),020h		;a623   ; con sus chispas
L_A627:
	ld (ix+002h),001h		;a627   ; chocando
	xor a			;a62b
	ld (ix+00ch),a		;a62c   ; y sin velocidad ninguna
	ld (ix+00dh),a		;a62f
	ld (ix+007h),a		;a632
	ld (ix+008h),a		;a635
	ret			;a638
L_A639:
	ld (ix+002h),000h		;a639   ; sin nada delante, no hay choque
	ret			;a63d

; ----------------------------------------------------------------------
; Los cuatro tiles con los que un ciclista choca: el 0x0E, el 0x5E, el 0x69 y el 0x90. No hay tabla de obstaculos ni lista de nada: la pista dibujada ES el mapa de choques, y se pregunta leyendo la casilla del buffer.
; ----------------------------------------------------------------------
que_hay_en_esa_casilla:		; Z si es uno de los cuatro tiles que paran
	call casilla_de_la_ventana_desde_hl		;a63e
es_un_tile_que_para:
	ld a,(hl)			;a641   ; lo que hay en la casilla
	cp 00eh		;a642   ; el borde
	ret z			;a644
	cp 05eh		;a645   ; la valla
	ret z			;a647
	cp 069h		;a648   ; el bache
	ret z			;a64a
	cp 090h		;a64b   ; y el ultimo de los cuatro
	ret			;a64d
choque_entre_los_dos:		; si se pisan, se apartan
	ld ix,0e0a0h		;a64e
	ld b,(ix+003h)		;a652   ; el carril del ciclista 1
	ld a,(ix+043h)		;a655   ; contra el del 2
	sub b			;a658
	add a,017h		;a659
	cp 02eh		;a65b   ; a mas de 0x2E, ni se rozan
	ret nc			;a65d
	ld a,(ix+010h)		;a65e   ; la posicion de uno
	add a,(ix+008h)		;a661
	ld b,a			;a664
	ld a,(ix+01dh)		;a665   ; contra la del otro
	add a,(ix+048h)		;a668
	sub b			;a66b
	add a,020h		;a66c
	cp 040h		;a66e   ; a mas de 0x40, tampoco
	ret nc			;a670
	ld d,(ix+003h)		;a671
	ld h,(ix+043h)		;a674
	ld a,d			;a677
	sub h			;a678
	add a,008h		;a679   ; y a menos de ocho estan encima
	cp 010h		;a67b
	jr c,se_pisan_de_verdad		;a67d
	call L_A687		;a67f   ; el que va detras
	ld ix,0e0e0h		;a682
	ex de,hl			;a686
L_A687:
	ld a,(ix+001h)		;a687   ; si no esta cambiando de carril, nada
	and a			;a68a
	ret z			;a68b
	ld a,d			;a68c
	cp h			;a68d   ; hacia el lado que le toque
	ld a,001h		;a68e
	jr c,L_A693		;a690
	inc a			;a692
L_A693:
	ld (ix+001h),a		;a693   ; el cambio, en marcha
	dec a			;a696
	ld (ix+034h),a		;a697   ; con su figura
	ld a,001h		;a69a
	ld (0e386h),a		;a69c   ; y marcado para el fotograma
	ret			;a69f
se_pisan_de_verdad:		; los dos, encima
	ld a,(ix+002h)		;a6a0
	or (ix+042h)		;a6a3   ; si alguno esta chocando ya
	jr nz,L_A6CB		;a6a6
	ld hl,(0e0ach)		;a6a8   ; los sprites de uno
	ld de,(0e0ech)		;a6ab   ; y los del otro
	call quien_va_delante_de_los_dos		;a6af   ; el que tiene que ir delante
	ld (0e0ach),hl		;a6b2
	ld (0e0ech),de		;a6b5
	ld hl,(0e0a7h)		;a6b9
	ld de,(0e0e7h)		;a6bc
	call quien_va_delante_de_los_dos		;a6c0
	ld (0e0a7h),hl		;a6c3
	ld (0e0e7h),de		;a6c6
	ret			;a6ca
L_A6CB:
	call L_A627		;a6cb   ; los dos, chocando
	ld ix,0e0e0h		;a6ce
	jp L_A627		;a6d2
quien_va_delante_de_los_dos:		; el de mas abajo tapa al otro
	push hl			;a6d5
	sbc hl,de		;a6d6   ; uno contra el otro
	pop hl			;a6d8
	jr nc,L_A6DC		;a6d9
	ex de,hl			;a6db   ; se cambian
L_A6DC:
	ld a,058h		;a6dc
	cp (ix+01dh)		;a6de   ; y por debajo de 0x58 manda el otro
	ret nc			;a6e1
	ex de,hl			;a6e2
	ret			;a6e3
sprites_del_terreno:		; los dos de la valla, uno por fotograma
	ld hl,03b68h		;a6e4   ; los sprites de la ventana 1
	ld ix,0e0a0h		;a6e7
	ld a,(0e003h)		;a6eb   ; el bit 0 del contador de fotogramas
	rra			;a6ee
	jr nc,L_A6F8		;a6ef
	ld ix,0e0e0h		;a6f1   ; y una ventana si y otra no
	ld hl,03b70h		;a6f5
L_A6F8:
	call setwrt_y_guarda_el_puerto		;a6f8   ; el puerto de datos, a mano
	exx			;a6fb
	ld a,(ix+00bh)		;a6fc   ; el terreno bajo el ciclista
	call fila_del_circuito_o_llano		;a6ff
	ld e,0e0h		;a702   ; el color de fondo
	and a			;a704
	jr nz,L_A73A		;a705
	ld a,(ix+00bh)		;a707   ; siete casillas mas adelante
	add a,007h		;a70a
	call fila_del_circuito_o_llano		;a70c
	ld hl,0a751h		;a70f   ; los dos patrones que le tocan
	call suma_a_hl		;a712
	ld a,(hl)			;a715
	ld hl,0a759h		;a716   ; unos
	ld e,0e0h		;a719
	and a			;a71b
	jr z,L_A73A		;a71c
	dec a			;a71e
	jr z,L_A724		;a71f
	ld hl,0a75dh		;a721   ; u otros
L_A724:
	ld a,(0e003h)		;a724
	bit 4,a		;a727   ; el bit 4 del contador: parpadean
	jr z,L_A73A		;a729
	ld e,010h		;a72b   ; el color de un jugador
	bit 0,(ix+033h)		;a72d
	jr z,L_A735		;a731
	ld e,060h		;a733   ; o el del otro
L_A735:
	ld a,007h		;a735   ; con su aviso sonoro
	call arranca_una_pista		;a737
L_A73A:
	ld d,070h		;a73a   ; la columna
	ld b,002h		;a73c   ; dos sprites
L_A73E:
	out (c),e		;a73e   ; la fila
	push hl			;a740   ; espera de once tiempos entre byte y byte
	pop hl			;a741
	out (c),d		;a742   ; la columna
	ld a,(hl)			;a744   ; el patron
	inc hl			;a745
	nop			;a746
	out (c),a		;a747
	ld a,(hl)			;a749   ; y el color
	inc hl			;a74a
	nop			;a74b
	out (c),a		;a74c
	djnz L_A73E		;a74e
	ret			;a750

; ----------------------------------------------------------------------
; DATOS tabla_a751: 8 B; la carga 0xA70F
;   0xa751..0xa759  (8 bytes)
DATA_tabla_a751:
	defb 000h,002h,001h,000h,000h,002h,001h,000h	; a751  ........

; ----------------------------------------------------------------------
; DATOS tabla_a759: 4 B; la carga 0xA716
;   0xa759..0xa75d  (4 bytes)
DATA_tabla_a759:
	defb 064h,00fh,06ch,004h	; a759

; ----------------------------------------------------------------------
; DATOS tabla_a75d: 4 B; la carga 0xA721
;   0xa75d..0xa761  (4 bytes)
DATA_tabla_a75d:
	defb 068h,00fh,06ch,004h	; a75d

; ======================================================================
; CODIGO 0xa761..0xa901  (416 bytes)
; ======================================================================


crono_de_los_dos_ciclistas:		; el tiempo de cada uno, si sigue corriendo
	ld ix,0e0a0h		;a761
	ld hl,0e0cfh		;a765   ; el crono del ciclista 1
	ld a,(0e0d2h)		;a768
	and a			;a76b
	call z,sube_el_crono_del_ciclista		;a76c   ; si no ha llegado, sigue contando
	ld hl,0e10fh		;a76f   ; y el del 2
	ld a,(0e112h)		;a772
	and a			;a775
	ld ix,0e0e0h		;a776
	call z,sube_el_crono_del_ciclista		;a77a
escribe_los_dos_tiempos:		; el de cada ventana
	ld hl,03810h		;a77d
	ld de,0e0d1h		;a780   ; el del jugador 1
	call escribe_un_tiempo		;a783
	ld de,0e111h		;a786   ; y el del 2
	ld hl,03850h		;a789

; ----------------------------------------------------------------------
; Un tiempo son tres bytes en BCD y se escribe de arriba abajo: los minutos en una cifra, y despues dos parejas de cifras con el tile 0x58 -los dos puntos- delante de la primera y el 0x59 -la coma- delante de la segunda. Los digitos son los tiles del 0x10 al 0x19, asi que basta sumarle 0x10 al nibble.
; ----------------------------------------------------------------------
escribe_un_tiempo:		; minutos, segundos y centesimas
	call setwrt_y_guarda_el_puerto		;a78c
	ld a,(de)			;a78f   ; los minutos
	dec de			;a790
	and 00fh		;a791   ; una sola cifra
	add a,010h		;a793   ; los digitos empiezan en el tile 0x10
	exx			;a795
	out (c),a		;a796
	exx			;a798
	ld b,002h		;a799   ; dos grupos: segundos y centesimas
	ld a,058h		;a79b   ; los dos puntos
L_A79D:
	exx			;a79d
	out (c),a		;a79e   ; el separador
	exx			;a7a0
	ld a,(de)			;a7a1   ; el nibble de arriba
	rra			;a7a2
	rra			;a7a3
	rra			;a7a4
	rra			;a7a5
	and 00fh		;a7a6
	add a,010h		;a7a8
	exx			;a7aa
	out (c),a		;a7ab
	exx			;a7ad
	ld a,(de)			;a7ae   ; y el de abajo
	dec de			;a7af
	and 00fh		;a7b0
	add a,010h		;a7b2
	exx			;a7b4
	out (c),a		;a7b5
	exx			;a7b7
	ld a,059h		;a7b8   ; la coma, para el grupo siguiente
	djnz L_A79D		;a7ba
	ret			;a7bc

; ----------------------------------------------------------------------
; El crono del ciclismo no cuenta de una en una: sube NUEVE centesimas por fotograma, que a cincuenta fotogramas por segundo son cuatro segundos y medio por cada segundo real. Al llegar a los cuatro minutos el ciclista queda fuera de carrera, y ademas se le descuentan puntos de siete en siete mientras corre.
; ----------------------------------------------------------------------
sube_el_crono_del_ciclista:		; nueve centesimas por fotograma, y el limite
	ld a,(ix+037h)		;a7bd
	and a			;a7c0   ; si ya esta parado, no cuenta
	ret nz			;a7c1
	ld a,(hl)			;a7c2
	add a,009h		;a7c3   ; nueve centesimas
	daa			;a7c5   ; en BCD
	ld (hl),a			;a7c6
	inc hl			;a7c7
	ld a,(hl)			;a7c8
	adc a,000h		;a7c9   ; con su acarreo a los segundos
	daa			;a7cb
	ld (hl),a			;a7cc
	cp 060h		;a7cd   ; sesenta segundos
	jr c,L_A7F7		;a7cf
	ld (hl),000h		;a7d1   ; vuelta a cero
	inc hl			;a7d3
	inc (hl)			;a7d4   ; y un minuto mas
	ld a,(hl)			;a7d5
	sub 004h		;a7d6   ; a los cuatro minutos
	jr nz,L_A7F7		;a7d8
	dec hl			;a7da
	ld (hl),a			;a7db
	dec hl			;a7dc
	ld (hl),a			;a7dd
	inc a			;a7de
	ld (ix+037h),0ffh		;a7df   ; el crono, parado
	ld (ix+032h),a		;a7e3   ; el ciclista, fuera
	ld (ix+03bh),a		;a7e6
	ld a,0a3h		;a7e9   ; con su sonido
	call suena_si_hay_partida		;a7eb
	bit 0,(ix+000h)		;a7ee
	jr nz,L_A7F7		;a7f2
	ld (ix+03ah),a		;a7f4
L_A7F7:
	bit 0,(ix+033h)		;a7f7   ; la puntuacion del jugador 1
	ld hl,0e096h		;a7fb
	jr z,L_A803		;a7fe
	ld hl,0e099h		;a800   ; o la del 2
L_A803:
	ld c,007h		;a803   ; siete puntos
	ld b,003h		;a805   ; tres bytes
resta_puntos:		; en BCD, y de cero no baja
	ld a,(hl)			;a807
	sub c			;a808   ; restados en BCD
	daa			;a809
	ld (hl),a			;a80a
	ret nc			;a80b   ; sin acarreo, ya esta
	inc hl			;a80c
	ld c,001h		;a80d   ; y del segundo byte en adelante, uno
	djnz resta_puntos		;a80f
	dec hl			;a811
	xor a			;a812   ; pasado de cero, se queda en cero
	ld (hl),a			;a813
	dec hl			;a814
	ld (hl),a			;a815
	dec hl			;a816
	ld (hl),a			;a817
	ret			;a818
rotulos_de_los_dos_jugadores:		; 1UP y 2UP, o el de fuera
	ld a,(0e0a0h)		;a819   ; el ciclista 1
	ld de,09675h		;a81c
	ld hl,0380ch		;a81f
	call L_A82E		;a822
	ld de,09679h		;a825   ; y el 2
	ld hl,0384ch		;a828
	ld a,(0e0e0h)		;a82b
L_A82E:
	and a			;a82e
	jr z,L_A834		;a82f   ; si esta fuera, el otro rotulo
	ld de,0967dh		;a831
L_A834:
	ld c,0ffh		;a834
	jp L_441D		;a836

; ----------------------------------------------------------------------
; EL CURLING SE MONTA ENTERO AQUI, y es la prueba mas cargada de las cuatro: media pantalla de estado en 0xE180, otra media en 0xE200, las tres piedras con su posicion y su color, la casa dibujada y el dibujo de 0xAFEF descomprimido a la RAM. Los intentos que le quedan al jugador deciden cuantas piedras se tiran.
; ----------------------------------------------------------------------
monta_el_curling:		; la pista de hielo y las tres piedras
	ld hl,0e06ch		;a839   ; la primera vez que se entra
	ld a,(hl)			;a83c
	inc (hl)			;a83d
	and a			;a83e
	call z,monta_la_primera_vez		;a83f   ; la pantalla de arriba
	call monta_el_hielo		;a842
	ld hl,0e180h		;a845   ; 128 bytes de estado
	ld de,0e181h		;a848
	ld bc,0007fh		;a84b
	ld (hl),0e0h		;a84e
	ldir		;a850
	ld hl,0e200h		;a852   ; y 256 mas
	ld de,0e201h		;a855
	ld (hl),000h		;a858
	ld bc,000ffh		;a85a
	ldir		;a85d
	ld a,070h		;a85f
	ld (0e209h),a		;a861
	ld hl,04030h		;a864   ; la primera piedra
	ld (0e240h),hl		;a867
	ld hl,05480h		;a86a   ; la segunda
	ld (0e250h),hl		;a86d
	ld a,001h		;a870
	ld (0e242h),a		;a872
	ld a,004h		;a875
	ld (0e252h),a		;a877
	ld hl,0435ch		;a87a   ; y la tercera
	ld (0e260h),hl		;a87d
	ld a,006h		;a880
	ld (0e262h),a		;a882
	ld hl,0a911h		;a885   ; los ocho bytes de arranque
	ld de,0e1a8h		;a888
	ld bc,00008h		;a88b
	ldir		;a88e
	call apunta_al_jugador_de_turno		;a890   ; los intentos del jugador de turno
	ld a,(hl)			;a893
	dec (hl)			;a894   ; uno menos
	sub 003h		;a895   ; con el tercero
	jr z,L_A89B		;a897
	ld a,004h		;a899
L_A89B:
	ld (0e230h),a		;a89b   ; la subescena de arranque
	ld a,020h		;a89e
	ld (0e004h),a		;a8a0
	ld a,040h		;a8a3   ; y la cuenta
	ld (0e233h),a		;a8a5
	ld hl,0afefh		;a8a8   ; el dibujo grande, a la RAM
	ld de,0e400h		;a8ab
	call descomprime_a_la_ram_en		;a8ae
	ld de,05519h		;a8b1   ; las casillas
	call descomprime_a_vram		;a8b4
	ld de,0a919h		;a8b7
	call descomprime_a_vram		;a8ba
	call pinta_la_pista_de_hielo		;a8bd   ; la casa
	ld de,096b5h		;a8c0
	call pinta_guion_de_tiles		;a8c3
	call L_99C7		;a8c6
	call marcador_del_curling		;a8c9
	call anima_a_los_dos_jugadores		;a8cc
	call sprites_del_curling		;a8cf
	call sprites_de_la_piedra		;a8d2
	jp vuelca_los_sprites_del_curling		;a8d5
monta_la_primera_vez:		; lo que solo se hace al entrar en el curling
	call monta_el_marcador_de_arriba		;a8d8   ; la franja de arriba
	ld de,0bb58h		;a8db   ; el marco
	call descomprime_a_vram		;a8de
	ld hl,0e100h		;a8e1   ; 256 bytes de estado
	ld de,0e101h		;a8e4
	ld bc,000ffh		;a8e7
	ld (hl),000h		;a8ea
	ldir		;a8ec
	ld hl,00404h		;a8ee
	ld (0e100h),hl		;a8f1
	ld hl,0a901h		;a8f4   ; las ocho marcas del curling
	call valor_de_la_vuelta		;a8f7   ; la de esta vuelta
	ld (hl),000h		;a8fa   ; y en los tres bytes que la resta consume
	inc hl			;a8fc
	ld (hl),e			;a8fd
	inc hl			;a8fe
	ld (hl),d			;a8ff
	ret			;a900

; ----------------------------------------------------------------------
; DATOS marcas_del_curling: 8 words en BCD, de 0.50 a 1.00; los recorre L_5443
;   desde 0xA8F4, el mismo que los de 0x545B
;   0xa901..0xa911  (16 bytes)
DATA_marcas_del_curling:
	defw 00050h,00060h,00070h,00080h,00085h,00090h,00095h,00100h	; a901

; ----------------------------------------------------------------------
; DATOS estado_inicial_de_0xe1a8: 8 B que 0xA885 copia a 0xE1A8 con un `ldir`
;   0xa911..0xa919  (8 bytes)
DATA_estado_inicial_de_0xe1a8:
	defb 070h,028h,024h,00eh,070h,028h,028h,001h	; a911  p($.p((.

; ----------------------------------------------------------------------
; DATOS rle_a919: 21 B -> 576 de VRAM de una tacada
;   0xa919..0xa92e  (21 bytes)
DATA_rle_a919:
	defb 0a0h,038h,040h,085h,020h,088h,060h,00fh,060h,00fh,060h,00fh,060h,00fh,020h,0f5h	; a919  .8@. .`.`.`.`. .
	defb 020h,00fh,020h,0f8h,000h	; a929

; ======================================================================
; CODIGO 0xa92e..0xa934  (6 bytes)
; ======================================================================


despacha_la_subescena_del_curling:		; trece, por (0xE230)
	ld a,(0e230h)		;a92e   ; la subescena
	call despacha_por_indice		;a931   ; y su rutina, de la tabla de detras

; ----------------------------------------------------------------------
; DATOS tabla_de_subescenas_a934: 13 entradas, la segunda mas larga; detras
;   sigue la primera, 0xA94E
;   0xa934..0xa94e  (26 bytes)
DATA_tabla_de_subescenas_a934:
	defw 0a94eh,0a976h,0a980h,0a99ch,0a9b5h,0a9d2h,0a9dah,0aa31h	; a934
	defw 0aa84h,0aabch,0aaf1h,0ab28h,0ab40h	; a944

; ======================================================================
; CODIGO 0xa94e..0xac84  (822 bytes)
; ======================================================================


curling_1_el_record:		; el record del mundo y la marca a batir
	ld a,(0e06ch)		;a94e
	dec a			;a951   ; solo la primera vuelta
	jr nz,L_A966		;a952
	call parpadea_world_record		;a954   ; el rotulo parpadeando
	ld de,0e05bh		;a957   ; el record del mundo del curling
	ld hl,03823h		;a95a
	ld b,003h		;a95d
	call escribe_cifras_bcd		;a95f
	call parpadea_world_record		;a962   ; y mientras parpadee, no se sigue
	ret nz			;a965
L_A966:
	call rotulo_de_la_prueba		;a966   ; el nombre de la prueba
	ld de,0e08dh		;a969   ; y la marca a batir
	ld b,003h		;a96c
	ld hl,03823h		;a96e
	call escribe_cifras_bcd		;a971
	jr sube_la_subescena_del_curling		;a974
espera_120_y_sigue:
	ld a,078h		;a976
espera_y_sube_la_subescena:
	ld (0e004h),a		;a978   ; la cuenta que traiga A
sube_la_subescena_del_curling:
	ld hl,0e230h		;a97b
	inc (hl)			;a97e   ; y la subescena siguiente
	ret			;a97f
curling_2_el_rotulo:		; el rotulo de arranque
	ld hl,0e004h		;a980
	dec (hl)			;a983   ; la cuenta
	ret nz			;a984
	ld de,0ac84h		;a985
	call pinta_guion_de_tiles		;a988   ; el rotulo
	xor a			;a98b
	ld (0e003h),a		;a98c   ; el contador de fotogramas, a cero
	ld a,(0e002h)		;a98f
	and 040h		;a992   ; el bit 6: si hay partida
	ld a,0f6h		;a994   ; con partida, 246 fotogramas
	jr nz,espera_y_sube_la_subescena		;a996
	ld a,020h		;a998   ; y en la demostracion, 32
	jr espera_y_sube_la_subescena		;a99a
curling_3_la_espera:		; un fotograma si y otro no
	ld hl,0e004h		;a99c
	ld a,(0e003h)		;a99f
	rra			;a9a2   ; el bit 0 del contador de fotogramas
	jr nc,L_A9A6		;a9a3
	dec (hl)			;a9a5
L_A9A6:
	ld a,(hl)			;a9a6
	and a			;a9a7
	jr z,L_A9AE		;a9a8
	call elige_la_fuerza		;a9aa   ; lo que el jugador toque
	ret z			;a9ad   ; y si toca algo, se sigue esperando
L_A9AE:
	call escribe_la_fuerza		;a9ae   ; el arranque
	ld a,03ch		;a9b1
	jr espera_y_sube_la_subescena		;a9b3
curling_4_la_pista:		; la musica, y la pista puesta
	ld a,(0e020h)		;a9b5
	and a			;a9b8   ; mientras suene algo, no
	ret nz			;a9b9
	call rotulos_del_curling		;a9ba
	ld hl,0e004h		;a9bd
	dec (hl)			;a9c0   ; la cuenta
	ret nz			;a9c1
	ld de,0ac96h		;a9c2
	call descomprime_a_vram		;a9c5   ; las casillas de la pista
	call fuerza_a_posicion		;a9c8
	ld a,08eh		;a9cb
	call arranca_una_pista		;a9cd   ; y la musica del curling
	jr sube_la_subescena_del_curling		;a9d0
curling_5_espera_a_la_musica:
	ld a,(0e020h)		;a9d2
	cp 08eh		;a9d5   ; mientras suene la 0x8E, no se sigue
	ret z			;a9d7
	jr sube_la_subescena_del_curling		;a9d8

; ----------------------------------------------------------------------
; El fotograma del curling: quince llamadas seguidas, una a cada cosa -las piedras, la escoba, el hielo, los marcadores, los sprites-, escritas una detras de otra y sin bucle, igual que el fotograma del ciclismo. El orden en que estan es el orden en que se pinta.
; ----------------------------------------------------------------------
curling_6_el_fotograma:		; las quince piezas del fotograma
	call vuelca_los_sprites_del_curling		;a9da
	call sprites_de_la_pista		;a9dd
	call acelera_la_piedra		;a9e0
	call avanza_la_piedra		;a9e3
	call anima_a_los_dos_jugadores		;a9e6
	call sprites_del_curling		;a9e9
	call anima_al_que_barre_la_izquierda		;a9ec
	call anima_la_piedra		;a9ef
	call sprites_de_la_piedra		;a9f2
	call arranca_la_tirada		;a9f5
	call pinta_la_pista_de_hielo		;a9f8
	call L_99C7		;a9fb
	call reparte_la_direccion		;a9fe
	call sprite_de_la_piedra_en_la_casa		;aa01
	call apaga_la_piedra_al_pararse		;aa04
	ld a,(0e231h)		;aa07   ; el estado de la tirada
	cp 002h		;aa0a   ; con dos, se acabo
	jp z,sube_la_subescena_del_curling		;aa0c
	ld c,a			;aa0f
	ld a,(0e002h)		;aa10
	and 040h		;aa13   ; el bit 6: si hay partida
	ld a,(0e20dh)		;aa15   ; por donde va la piedra
	jr z,mira_si_la_piedra_paso_la_raya		;aa18
	cp 0d0h		;aa1a
	ret c			;aa1c
	ld a,c			;aa1d
	and a			;aa1e
	ret nz			;aa1f
	jp tirada_nula		;aa20
mira_si_la_piedra_paso_la_raya:		; el tramo de 0xC8 a 0xCF
	ld hl,0e231h		;aa23
	ld c,a			;aa26
	cp 0c8h		;aa27   ; antes de 0xC8, nada
	ret c			;aa29
	cp 0cfh		;aa2a   ; y pasada la 0xCF, una mas
	jr c,L_AA2F		;aa2c
	inc c			;aa2e
L_AA2F:
	ld (hl),c			;aa2f   ; el estado de la tirada
	ret			;aa30
curling_7_la_piedra_rodando:		; el fotograma mientras la piedra va sola
	ld hl,0e233h		;aa31
	ld a,(hl)			;aa34   ; la cuenta del lanzamiento
	and a			;aa35
	jr z,L_AA42		;aa36
	dec (hl)			;aa38   ; una menos
	cp 020h		;aa39
	jr nz,L_AA42		;aa3b
	ld a,0e0h		;aa3d   ; y en el fotograma justo, la piedra cambia de color
	ld (0e260h),a		;aa3f
L_AA42:
	call vuelca_los_sprites_del_curling		;aa42
	call sprites_de_la_pista		;aa45
	call velocidad_de_la_piedra		;aa48
	call barre_el_hielo		;aa4b
	call acerca_a_los_barrenderos		;aa4e
	call barre_uno_u_otro		;aa51
	call anima_a_los_dos_jugadores		;aa54
	call anima_al_que_barre_la_izquierda		;aa57
	call sprites_del_curling		;aa5a
	call anima_la_piedra		;aa5d
	call apaga_la_piedra_al_pararse		;aa60
	call sprites_de_la_piedra		;aa63
	call frena_la_piedra		;aa66
	call avanza_la_piedra		;aa69
	call pinta_la_pista_de_hielo		;aa6c
	call L_99C7		;aa6f
	call mira_si_la_piedra_se_sale		;aa72
	call sprite_de_la_piedra_en_la_casa		;aa75
	ld hl,0e204h		;aa78   ; los tres bytes de la velocidad
	ld a,(hl)			;aa7b
	inc hl			;aa7c
	or (hl)			;aa7d
	inc hl			;aa7e
	or (hl)			;aa7f
	ret nz			;aa80   ; mientras alguno no sea cero, la piedra sigue
	jp espera_y_sube_la_subescena		;aa81   ; y parada del todo, la subescena siguiente
curling_8_los_puntos:		; lo que ha valido la tirada
	call puntos_de_la_tirada		;aa84
	ld a,(0e235h)		;aa87   ; si la piedra ha llegado a la casa
	and a			;aa8a
	ld a,01ah		;aa8b
	call nz,suena_si_hay_partida		;aa8d   ; suena
	call escribe_los_puntos_de_la_tirada		;aa90   ; los puntos, escritos
	call L_AC79		;aa93   ; la marca del jugador
	ld de,0e234h		;aa96
	ld b,003h		;aa99   ; tres bytes
	xor a			;aa9b
L_AA9C:
	ld a,(de)			;aa9c
	adc a,(hl)			;aa9d   ; sumados en BCD
	daa			;aa9e
	ld (hl),a			;aa9f
	inc hl			;aaa0
	inc de			;aaa1
	djnz L_AA9C		;aaa2
	ex de,hl			;aaa4
	dec de			;aaa5
	ld hl,03817h		;aaa6   ; y la marca, a la pantalla
	call escribe_tres_bytes_bcd		;aaa9
	ld a,040h		;aaac   ; con 64 fotogramas de espera
	jp espera_y_sube_la_subescena		;aaae
escribe_los_puntos_de_la_tirada:
	ld hl,03837h		;aab1
	ld de,0e236h		;aab4
escribe_tres_bytes_bcd:
	ld b,003h		;aab7   ; tres bytes, o sea seis cifras
	jp escribe_cifras_bcd		;aab9
curling_9_el_record:		; la marca contra el record del mundo
	ld hl,0e004h		;aabc
	dec (hl)			;aabf   ; la cuenta
	ret nz			;aac0
	ld a,(0e235h)		;aac1   ; sin puntos no hay record que batir
	and a			;aac4
	jp z,espera_y_sube_la_subescena		;aac5
	call L_AC79		;aac8   ; la marca del jugador
	ld e,(hl)			;aacb
	inc hl			;aacc
	ld d,(hl)			;aacd
	inc hl			;aace
	ld c,(hl)			;aacf
	ld hl,0e059h		;aad0   ; contra el record del mundo del curling
	call L_43B8		;aad3
	ld a,000h		;aad6
	jp c,espera_y_sube_la_subescena		;aad8   ; y si no llega, se sigue
	call L_AC79		;aadb   ; la marca
	ld de,0e059h		;aade   ; puesta de record
	ld bc,00003h		;aae1
	ldir		;aae4
	ld a,0b2h		;aae6   ; con su musica
	call suena_si_hay_partida		;aae8
	ld a,00ch		;aaeb
	ld (0e230h),a		;aaed   ; y a la subescena 12
	ret			;aaf0
curling_10_el_cierre:		; la marca, la mejor y si califica
	call apunta_al_jugador_de_turno		;aaf1   ; el jugador de turno
	ld a,(hl)			;aaf4
	and a			;aaf5   ; si le quedan intentos, no se cierra
	jr nz,L_AB24		;aaf6
	ld hl,(0e096h)		;aaf8   ; la mejor marca del jugador 1
	ld (0e090h),hl		;aafb
	ld a,(0e098h)		;aafe
	ld (0e092h),a		;ab01
	ld hl,(0e099h)		;ab04   ; y la del 2
	ld (0e093h),hl		;ab07
	ld a,(0e09bh)		;ab0a
	ld (0e095h),a		;ab0d
	call L_AC79		;ab10   ; la marca de esta tanda
	ld e,(hl)			;ab13
	inc hl			;ab14
	ld d,(hl)			;ab15
	inc hl			;ab16
	ld c,(hl)			;ab17
	call resta_de_24_bits		;ab18   ; contra la que habia que batir
	ex af,af'			;ab1b
	call intentos_del_jugador_de_turno		;ab1c   ; el jugador de turno
	ex af,af'			;ab1f
	jr c,L_AB24		;ab20   ; si no llega, no califica
	ld (hl),001h		;ab22   ; calificado
L_AB24:
	xor a			;ab24
	jp espera_y_sube_la_subescena		;ab25
curling_11_el_final:		; la despedida
	call vuelca_los_sprites_del_curling		;ab28
	call sprites_del_curling		;ab2b
	call anima_el_final		;ab2e
	ld hl,0e004h		;ab31
	dec (hl)			;ab34   ; la cuenta
	ret nz			;ab35
cierra_el_curling:		; la musica y a esperar ya no
	ld a,0b5h		;ab36   ; la musica del final
	call suena_si_hay_partida		;ab38
	xor a			;ab3b
	ld (0e069h),a		;ab3c
	ret			;ab3f
curling_12_el_record_batido:		; el rotulo, parpadeando
	call vuelca_los_sprites_del_curling		;ab40
	call sprites_del_curling		;ab43
	ld a,00ah		;ab46   ; el color de la piedra
	ld (0e23bh),a		;ab48
	call parpadea_la_piedra		;ab4b
	call parpadea_world_record		;ab4e   ; el rotulo del record
	ld de,0e05bh		;ab51   ; con el record del mundo al lado
	ld hl,03823h		;ab54
	ld b,003h		;ab57
	call escribe_cifras_bcd		;ab59
	ld a,(0e012h)		;ab5c   ; y mientras suene algo, no se cierra
	and a			;ab5f
	ret nz			;ab60
	call curling_10_el_cierre		;ab61
	jr cierra_el_curling		;ab64

; ----------------------------------------------------------------------
; Antes de tirar, el jugador elige la fuerza entre cinco valores: cada toque de arriba o de abajo sube uno y a la quinta vuelve a la primera. El numero que se ve en la pantalla no es el valor: es el valor multiplicado por cuatro EN BCD, con dos `add a,a / daa` seguidos.
; ----------------------------------------------------------------------
elige_la_fuerza:		; el jugador cambia entre cinco
	ld a,(0e002h)		;ab66
	add a,a			;ab69   ; el bit 7 dice de quien es el turno
	ld a,(0e008h)		;ab6a   ; los flancos del jugador 1
	ld hl,0e100h		;ab6d
	jr nc,L_AB76		;ab70
	ld a,(0e006h)		;ab72   ; o los del 2
	inc hl			;ab75
L_AB76:
	and 018h		;ab76   ; los bits 3 y 4
	ret nz			;ab78
	ld a,(hl)			;ab79
	inc a			;ab7a   ; una fuerza mas
	cp 005h		;ab7b   ; de cinco
	jr c,L_AB80		;ab7d
	xor a			;ab7f   ; y vuelta a la primera
L_AB80:
	ld (hl),a			;ab80
	call escribe_la_fuerza		;ab81
	ld a,006h		;ab84
	call suena_si_hay_partida		;ab86   ; con su sonido
	xor a			;ab89
	ret			;ab8a
fuerza_a_posicion:		; la fuerza elegida, en la columna de tiro
	call fuerza_del_jugador_de_turno		;ab8b
	ld a,(hl)			;ab8e
	add a,a			;ab8f   ; por dieciseis
	add a,a			;ab90
	add a,a			;ab91
	add a,a			;ab92
	add a,050h		;ab93   ; desde la columna 0x50
	ld (0e221h),a		;ab95
	ret			;ab98
fuerza_del_jugador_de_turno:		; HL al byte que la lleva
	ld a,(0e002h)		;ab99
	add a,a			;ab9c   ; el bit 7 dice de quien es el turno
	ld hl,0e100h		;ab9d
	ret nc			;aba0
	inc hl			;aba1
	ret			;aba2
escribe_la_fuerza:		; el numero que se ve
	ld hl,03a4fh		;aba3
escribe_la_fuerza_en:
	push hl			;aba6
	call fuerza_del_jugador_de_turno		;aba7
	ld a,(hl)			;abaa
	add a,a			;abab   ; por dos, en BCD
	daa			;abac
	add a,a			;abad   ; y por dos otra vez: por cuatro en total
	daa			;abae
	ld de,0e102h		;abaf
	ld (de),a			;abb2
	ld b,001h		;abb3
	pop hl			;abb5
	jp escribe_cifras_bcd		;abb6
mira_si_la_piedra_se_sale:		; fuera de la pista, nula
	ld a,(0e209h)		;abb9   ; por donde va la piedra
	sub 033h		;abbc   ; el tramo bueno
	cp 06dh		;abbe
	jr c,L_ABD5		;abc0
tirada_nula:		; FOUL, y a la subescena 10
	ld de,0455ah		;abc2   ; el rotulo FOUL
	call pinta_guion_de_tiles		;abc5
	call escribe_los_puntos_de_la_tirada		;abc8   ; los puntos, a la vista
	ld a,00ah		;abcb
	ld (0e230h),a		;abcd   ; la subescena 10
	ld a,016h		;abd0   ; y su sonido
	jp suena_si_hay_partida		;abd2
L_ABD5:
	ld hl,(0e20dh)		;abd5   ; por donde va a lo largo
	ld de,00367h		;abd8   ; y pasada de 0x367, se sale
	sbc hl,de		;abdb
	ret c			;abdd
	jr tirada_nula		;abde
intentos_del_jugador_de_turno:		; HL al byte
	call apunta_al_jugador_de_turno		;abe0
	inc hl			;abe3
	ret			;abe4
anima_el_final:		; la piedra que se para y su musica
	ld hl,0e23ah		;abe5
	ld a,(hl)			;abe8   ; si ya esta anunciado, nada
	and a			;abe9
	jr nz,parpadea_la_piedra		;abea
	ld a,(0e020h)		;abec   ; y mientras suene algo, tampoco
	and a			;abef
	ret nz			;abf0
	inc (hl)			;abf1   ; anunciado
	ld a,001h		;abf2
	ld (0e239h),a		;abf4
	ld a,(0e235h)		;abf7   ; con puntos
	and a			;abfa
	jr z,L_AC02		;abfb
	ld bc,06f0ah		;abfd   ; una musica
	jr L_AC05		;ac00
L_AC02:
	ld bc,0a30ch		;ac02   ; y sin ellos, otra
L_AC05:
	ld a,c			;ac05
	ld (0e23bh),a		;ac06   ; el color de la piedra
	ld a,b			;ac09
	jp suena_si_hay_partida		;ac0a
parpadea_la_piedra:		; el color, cada dieciseis fotogramas
	ld a,(0e003h)		;ac0d
	bit 4,a		;ac10   ; el bit 4 del contador de fotogramas
	ld a,(0e23bh)		;ac12
	jr z,L_AC18		;ac15
	inc a			;ac17
L_AC18:
	ld (0e242h),a		;ac18   ; el color de las dos piezas
	ld (0e252h),a		;ac1b
	ret			;ac1e
rotulos_del_curling:		; el nombre, la marca a batir y la fuerza
	call rotulo_de_la_prueba		;ac1f
	ld de,0e08dh		;ac22   ; la marca a batir
	ld b,003h		;ac25
	ld hl,03823h		;ac27
	call escribe_cifras_bcd		;ac2a
	ld de,0ac8fh		;ac2d   ; el rotulo de la fuerza
	ld hl,03858h		;ac30
	ld c,0ffh		;ac33
	call L_441D		;ac35
	ld hl,0385ah		;ac38
	call escribe_la_fuerza_en		;ac3b   ; y su numero
marcador_del_curling:		; los rotulos y la mejor marca
	ld de,0aca0h		;ac3e   ; el rotulo de arriba
	call pinta_guion_de_tiles		;ac41
	call intentos_del_turno_a_la_vista		;ac44   ; los intentos que quedan
	ld de,0e098h		;ac47
	ld a,(0e002h)		;ac4a
	add a,a			;ac4d   ; el bit 7 dice de quien es el turno
	jr nc,L_AC52		;ac4e
	ld e,09bh		;ac50
L_AC52:
	ld hl,03817h		;ac52   ; y la mejor marca del jugador
	ld b,003h		;ac55
	jp escribe_cifras_bcd		;ac57
intentos_del_turno_a_la_vista:
	call apunta_al_jugador_de_turno		;ac5a   ; los intentos del jugador de turno
	ld a,(hl)			;ac5d
	ld c,a			;ac5e
	ld hl,03814h		;ac5f   ; la casilla del marcador
	neg		;ac62   ; de tres
	add a,003h		;ac64
	ld b,a			;ac66
	ld a,0ach		;ac67   ; el tile del intento gastado
	call nz,L_AC72		;ac69
	ld b,c			;ac6c   ; los que quedan
	inc b			;ac6d
	dec b			;ac6e
	ret z			;ac6f
	ld a,0abh		;ac70   ; y el de la piedra que le queda
L_AC72:
	call 0004dh		;ac72   ; BIOS WRTVRM - Writes data in VRAM | a la casilla
	inc hl			;ac75
	djnz L_AC72		;ac76
	ret			;ac78
L_AC79:
	ld a,(0e002h)		;ac79   ; el bit 7 dice de quien es el turno
	ld hl,0e096h		;ac7c   ; la mejor marca del jugador 1
	add a,a			;ac7f
	ret nc			;ac80
	ld l,099h		;ac81   ; o la del 2
	ret			;ac83

; ----------------------------------------------------------------------
; DATOS guion_temp: 18 B, dos destinos: TEMP en 0x3A2D y dos tiles en 0x3A4D
;   0xac84..0xac96  (18 bytes)
DATA_guion_temp:
	defb 02dh,03ah,000h,034h,025h,02dh,030h,000h	; ac84  -:.4%-0.
	defb 0feh,04dh,03ah,000h,0e6h,000h,000h,0e7h,000h,0ffh	; ac8c  .M:.......

; ----------------------------------------------------------------------
; DATOS rle_ac96: 10 B -> 12 de VRAM en dos tramos
;   0xac96..0xaca0  (10 bytes)
DATA_rle_ac96:
	defb 02dh,03ah,006h,00fh,080h,04dh,03ah,006h,00fh,000h	; ac96  -:...M:...

; ----------------------------------------------------------------------
; DATOS guion_point_e_ice_temp: 19 B, dos destinos: POINT en 0x3830 e ICE TEMP
;   en 0x3850
;   0xaca0..0xacb3  (19 bytes)
DATA_guion_point_e_ice_temp:
	defb 030h,038h,030h,02fh,029h,02eh,034h,0feh,050h	; aca0  080/).4.P
	defb 038h,029h,023h,025h,000h,034h,025h,02dh,030h,0ffh	; aca9  8)#%.4%-0.

; ======================================================================
; CODIGO 0xacb3..0xae3a  (391 bytes)
; ======================================================================


velocidad_de_la_piedra:		; la fuerza, repartida en los dos ejes
	call reparte_la_direccion		;acb3
	ld (0e2f0h),a		;acb6   ; el reparto, apuntado
	ld a,(0e221h)		;acb9   ; la fuerza con la que se tira
	ld e,c			;acbc
	ld h,a			;acbd
	push hl			;acbe
	call multiplica_8x8		;acbf   ; por la componente de un eje
	ld (0e225h),hl		;acc2   ; y esa es la velocidad a lo largo
	pop hl			;acc5
	ld a,(0e2f0h)		;acc6
	ld e,a			;acc9
	call multiplica_8x8		;acca   ; por la del otro
	ld a,(0e228h)		;accd   ; si va hacia el otro lado
	and a			;acd0
	jr z,L_ACD5		;acd1
	ld a,0ffh		;acd3   ; en negativo
L_ACD5:
	ld (0e222h),hl		;acd5   ; y esa es la velocidad a lo ancho
	ld (0e224h),a		;acd8
	ret			;acdb

; ----------------------------------------------------------------------
; EL REPARTO DE LA DIRECCION, que es una normalizacion de vector hecha con dos tablas. Se toman las dos componentes, se apunta cual es la mayor y su signo, se divide la menor entre la mayor -corriendo la mayor cinco bits para que el cociente quepa en 0..32- y con ese cociente se leen LAS DOS curvas de 0xAE4C y 0xAE6D, cruzadas. Las dos juntas son un cuarto de vuelta: la que baja de 0xFF a 0xB5 y la que sube de 0x02 a 0xB5 se cortan justo en el 0xB5 de los cuarenta y cinco grados, que es 0,707 de 0xFF. O sea coseno y seno de un angulo que nunca llega a calcularse.
; ----------------------------------------------------------------------
reparte_la_direccion:		; normaliza el vector con las dos curvas
	ld de,(0e202h)		;acdc   ; una componente
	ld bc,(0e205h)		;ace0   ; y la otra
	ld a,(0e203h)		;ace4   ; su signo
	add a,a			;ace7
	ld a,000h		;ace8
	jr nc,L_ACF1		;acea
	call cambia_el_signo_de_de		;acec   ; en positivo
	ld a,001h		;acef   ; y el signo, apuntado
L_ACF1:
	ld (0e228h),a		;acf1
	ld h,d			;acf4
	ld l,e			;acf5
	xor a			;acf6
	sbc hl,bc		;acf7   ; la mayor de las dos
	jr c,L_AD01		;acf9
	ex de,hl			;acfb   ; se cambian, para que la mayor quede abajo
	ld d,b			;acfc
	ld e,c			;acfd
	ld b,h			;acfe
	ld c,l			;acff
	inc a			;ad00   ; y se apunta cual era
L_AD01:
	ld (0e229h),a		;ad01
	ld a,c			;ad04
	srl b		;ad05   ; la mayor, corrida cinco bits
	rra			;ad07
	srl b		;ad08
	rra			;ad0a
	srl b		;ad0b
	rra			;ad0d
	srl b		;ad0e
	rra			;ad10
	srl b		;ad11
	rra			;ad13
	ld c,a			;ad14
	call divide_16		;ad15   ; y la division da el angulo, de 0 a 32
	ld a,e			;ad18
	cp 020h		;ad19   ; con tope
	jr c,L_AD1F		;ad1b
	ld e,020h		;ad1d
L_AD1F:
	ld d,000h		;ad1f
	ld a,(0e229h)		;ad21
	ld hl,0ae4ch		;ad24   ; la curva que baja
	and a			;ad27
	jr z,L_AD2D		;ad28
	ld hl,0ae6dh		;ad2a   ; o la que sube, segun cual era la mayor
L_AD2D:
	add hl,de			;ad2d
	ld c,(hl)			;ad2e
	ld hl,0ae6dh		;ad2f   ; y la companera, para el otro eje
	and a			;ad32
	jr z,L_AD38		;ad33
	ld hl,0ae4ch		;ad35
L_AD38:
	add hl,de			;ad38
	ld a,(hl)			;ad39
	ld (0e237h),a		;ad3a   ; las dos componentes ya normalizadas
	ret			;ad3d
avanza_la_piedra:		; la velocidad, sumada a la posicion
	ld hl,0e207h		;ad3e   ; la velocidad
	ld de,0e201h		;ad41   ; a la posicion
	call suma_tres_bytes		;ad44
	inc hl			;ad47
	call suma_tres_bytes		;ad48   ; y el otro eje
	ret nc			;ad4b
	inc (hl)			;ad4c   ; con su acarreo
	ret			;ad4d
frena_la_piedra:		; el rozamiento del hielo
	ld hl,0e220h		;ad4e   ; la cuenta del frenado
	ld a,(hl)			;ad51
	and a			;ad52
	jr z,L_AD57		;ad53
	dec (hl)			;ad55
	ret nz			;ad56
L_AD57:
	ld a,(0e226h)		;ad57   ; lo que se le quita a lo largo
	ld hl,0e204h		;ad5a
	call resta_tres_bytes		;ad5d
	ld a,(0e224h)		;ad60   ; el signo del otro eje
	and a			;ad63
	ld a,(0e223h)		;ad64   ; y lo que se le quita a lo ancho
	ld hl,0e201h		;ad67
	jp z,resta_tres_bytes		;ad6a   ; con signo, se resta
	ld b,003h		;ad6d   ; tres bytes
	ld c,a			;ad6f
	xor a			;ad70
L_AD71:
	ld a,(hl)			;ad71
	adc a,c			;ad72   ; y sin el, se suma
	ld (hl),a			;ad73
	ret nc			;ad74
	ld c,000h		;ad75
	inc hl			;ad77
	djnz L_AD71		;ad78
	jp pon_tres_bytes_a_cero		;ad7a

; ----------------------------------------------------------------------
; La escoba: mientras la piedra rueda, machacar la tecla suma velocidad. En la DEMOSTRACION nadie machaca, asi que el propio cartucho se inventa el barrido -uno de cada ocho fotogramas, mas fuerte antes de la casilla 0x6C que despues-, que es como la piedra llega a alguna parte sin jugador.
; ----------------------------------------------------------------------
barre_el_hielo:		; la escoba, que es lo que la deja correr mas
	call flancos_del_jugador_de_turno		;ad7d   ; lo que el jugador esta tocando
	ld c,(hl)			;ad80
	ld a,(0e002h)		;ad81
	and 040h		;ad84   ; el bit 6: si hay partida
	jr nz,L_ADA3		;ad86
	ld a,(0e20eh)		;ad88   ; en la demostracion
	cp 003h		;ad8b   ; solo en dos tiradas
	ret nc			;ad8d
	ex de,hl			;ad8e
	ld hl,0e003h		;ad8f
	ld a,(hl)			;ad92
	and 007h		;ad93   ; uno de cada ocho fotogramas
	ret nz			;ad95
	ld c,010h		;ad96   ; barrido fuerte
	ld a,(0e209h)		;ad98
	cp 06ch		;ad9b   ; antes de la casilla 0x6C
	jr nc,L_ADA1		;ad9d
	ld c,008h		;ad9f   ; y flojo despues
L_ADA1:
	ex de,hl			;ada1
	ld (hl),c			;ada2
L_ADA3:
	ld a,(0e232h)		;ada3   ; si la piedra no esta rodando, no se barre
	and a			;ada6
	ret z			;ada7
	ld hl,(0e204h)		;ada8   ; ni si esta parada
	ld a,l			;adab
	or h			;adac
	ret z			;adad
	ld a,c			;adae
	and 018h		;adaf   ; los bits 3 y 4
	ret z			;adb1
	push af			;adb2
	ld a,04bh		;adb3   ; el sonido de la escoba
	call arranca_una_pista		;adb5
	ld a,(0e205h)		;adb8   ; la velocidad de ahora
	ld e,a			;adbb
	cp 020h		;adbc
	ld a,005h		;adbe   ; la cuenta del barrido
	jr nc,L_ADC4		;adc0
	ld a,003h		;adc2
L_ADC4:
	ld (0e220h),a		;adc4
	ld a,e			;adc7
	rra			;adc8   ; su nibble de arriba
	rra			;adc9
	rra			;adca
	rra			;adcb
	and 00fh		;adcc
	jr nz,L_ADD1		;adce
	inc a			;add0   ; y de cero no se queda
L_ADD1:
	ld e,a			;add1
	ld d,000h		;add2
	pop af			;add4
	and 010h		;add5   ; hacia atras
	call nz,cambia_el_signo_de_de		;add7
	ld hl,(0e202h)		;adda   ; la posicion
	add hl,de			;addd   ; mas lo barrido
	push hl			;adde
	ld de,00020h		;addf
	add hl,de			;ade2   ; con tope
	ld e,040h		;ade3
	and a			;ade5
	sbc hl,de		;ade6
	pop hl			;ade8
	ret nc			;ade9
	ld (0e202h),hl		;adea   ; apuntada
	ret			;aded
sprites_de_la_pista:		; los dos de la raya
	ld hl,(0e20dh)		;adee   ; por donde va la piedra
	ld de,002c0h		;adf1   ; el borde de la casa
	and a			;adf4
	sbc hl,de		;adf5
	jr nc,L_ADFB		;adf7
	ld l,000h		;adf9   ; y antes de el, cero
L_ADFB:
	ld a,028h		;adfb   ; desde la columna 0x28
	add a,l			;adfd
	ld c,a			;adfe
	ld hl,0e1a8h		;adff   ; los dos sprites de la raya
	ld a,(0e209h)		;ae02   ; la fila de la piedra
	ld (hl),a			;ae05
	inc hl			;ae06
	ld (hl),c			;ae07   ; con la columna que sale de la cuenta
	inc hl			;ae08
	inc hl			;ae09
	inc hl			;ae0a
	ld (hl),a			;ae0b   ; y el segundo, igual
	inc hl			;ae0c
	ld (hl),c			;ae0d
	ret			;ae0e
vuelca_los_sprites_del_curling:		; los 80 bytes de 0xE180
	ld de,0e180h		;ae0f
	ld hl,03b00h		;ae12   ; la tabla de atributos
	ld bc,00050h		;ae15   ; veinte sprites de cuatro bytes
	jp ldirvm		;ae18
resta_tres_bytes:		; de (HL), y de cero no baja
	ld b,003h		;ae1b
	ld c,a			;ae1d
	xor a			;ae1e
L_AE1F:
	ld a,(hl)			;ae1f   ; restado
	sbc a,c			;ae20
	ld (hl),a			;ae21
	ret nc			;ae22   ; sin acarreo, ya esta
	ld c,000h		;ae23
	inc hl			;ae25
	djnz L_AE1F		;ae26
pon_tres_bytes_a_cero:		; cuando la resta se pasa
	dec hl			;ae28   ; los tres, a cero
	ld (hl),c			;ae29
	dec hl			;ae2a
	ld (hl),c			;ae2b   ; y el de en medio
	dec hl			;ae2c
	ld (hl),c			;ae2d
	ret			;ae2e
suma_tres_bytes:		; los de (DE) a los de (HL)
	ld b,003h		;ae2f
	xor a			;ae31
L_AE32:
	ld a,(de)			;ae32   ; sumados con acarreo
	adc a,(hl)			;ae33
	ld (hl),a			;ae34
	inc hl			;ae35
	inc de			;ae36
	djnz L_AE32		;ae37
	ret			;ae39

; ----------------------------------------------------------------------
; DATOS rutina_muerta_de_dividir_por_32: 10 bytes de codigo Z80 al que no
;   salta nadie: HL/32, lo mismo que el desplegado de 0xAD04
;   0xae3a..0xae44  (10 bytes)
DATA_rutina_muerta_de_dividir_por_32:
	defb 0afh,029h,08fh,029h,08fh,029h,08fh,06ch,067h,0c9h	; ae3a  .).).).lg.

; ======================================================================
; CODIGO 0xae44..0xae4c  (8 bytes)
; ======================================================================


cambia_el_signo_de_de:		; en complemento a dos
	ld a,e			;ae44
	cpl			;ae45   ; los dos bytes, del reves
	ld e,a			;ae46
	ld a,d			;ae47
	cpl			;ae48
	ld d,a			;ae49
	inc de			;ae4a   ; y uno mas: eso es el complemento a dos
	ret			;ae4b

; ----------------------------------------------------------------------
; DATOS curva_descendente_ae4c: 33 B, de 0xFF a 0xB5, con la pendiente cada
;   vez mayor
;   0xae4c..0xae6d  (33 bytes)
DATA_curva_descendente_ae4c:
	defb 0ffh,0ffh,0ffh,0feh,0feh,0fch,0fbh,0fah,0f8h,0f6h,0f4h	; ae4c  ...........
	defb 0f2h,0efh,0edh,0eah,0e7h,0e4h,0e2h,0dfh,0dch,0d9h,0d6h	; ae57  ...........
	defb 0d2h,0cfh,0cch,0c9h,0c6h,0c3h,0c0h,0bdh,0bah,0b7h,0b5h	; ae62  ...........

; ----------------------------------------------------------------------
; DATOS curva_ascendente_ae6d: 33 B, de 0x02 a 0xB5, con la pendiente cada vez
;   menor; es la companera de la de arriba, y las dos juntas son un cuarto de
;   vuelta
;   0xae6d..0xae8e  (33 bytes)
DATA_curva_ascendente_ae6d:
	defb 002h,007h,00fh,017h,01fh,027h,02fh,036h,03eh,045h,04ch	; ae6d  .....'/6>EL
	defb 053h,059h,060h,066h,06ch,072h,078h,07dh,082h,087h,08ch	; ae78  SY`flrx}...
	defb 091h,095h,099h,09dh,0a1h,0a5h,0a8h,0abh,0afh,0b2h,0b5h	; ae83  ...........

; ======================================================================
; CODIGO 0xae8e..0xafef  (353 bytes)
; ======================================================================


pinta_la_pista_de_hielo:		; el hielo, la casa y las rayas
	ld hl,(0e20dh)		;ae8e   ; por donde va la pista
	ld de,002c1h		;ae91   ; pasada la 0x2C1, ya no se pinta
	and a			;ae94
	sbc hl,de		;ae95
	ret nc			;ae97
	ld hl,0b299h		;ae98   ; la casa
	ld de,0b2c8h		;ae9b
	call rectangulo_de_la_pista		;ae9e
	ld hl,0b07fh		;aea1   ; el circulo grande
	ld de,0b174h		;aea4
	call rectangulo_de_la_pista		;aea7
	ld hl,0b264h		;aeaa   ; y las rayas
	ld de,0b281h		;aead
	call rectangulo_de_la_pista		;aeb0
	call pinta_los_bordes		;aeb3
	ld hl,03880h		;aeb6   ; la fila de arriba
	call setwrt_y_guarda_el_puerto		;aeb9
	exx			;aebc
	ld a,(0e20dh)		;aebd   ; por donde va la pista
	ld l,080h		;aec0
	bit 2,a		;aec2   ; el bit 2 elige uno de los dos tiles
	jr z,L_AEC8		;aec4
	ld l,082h		;aec6
L_AEC8:
	ld b,020h		;aec8   ; treinta y dos casillas
L_AECA:
	ld a,b			;aeca
	and 001h		;aecb   ; alternando de una en una
	add a,l			;aecd
	out (c),a		;aece
	djnz L_AECA		;aed0
	ret			;aed2
pinta_los_bordes:		; las dos rayas de los lados
	call pinta_la_fila_del_hielo		;aed3
	ld de,0b067h		;aed6   ; la de un lado
	exx			;aed9
	ld de,0b05fh		;aeda
	ld hl,038e0h		;aedd
	call pinta_un_borde		;aee0
	ld de,0b077h		;aee3   ; y la del otro
	exx			;aee6
	ld de,0b06fh		;aee7
	ld hl,03a80h		;aeea
pinta_un_borde:		; con el trozo que asome, segun el desplazamiento
	ld (0e2f0h),hl		;aeed
	ld bc,(0e20dh)		;aef0   ; por donde va la pista
	ld a,c			;aef4   ; entre ocho: de pixeles a casillas
	rr b		;aef5
	rra			;aef7
	rr b		;aef8
	rra			;aefa
	rr b		;aefb
	rra			;aefd
	inc a			;aefe
	inc a			;aeff   ; dos mas
	ld (0e2f2h),a		;af00
	dec a			;af03
	dec a			;af04
	jr nc,L_AF08		;af05
	exx			;af07
L_AF08:
	ld hl,(0e2f0h)		;af08
	cp 01fh		;af0b   ; antes de la 0x1F
	jr c,L_AF1A		;af0d
	cp 04bh		;af0f   ; pasada la 0x4B
	jr c,L_AF2A		;af11
	neg		;af13
	add a,06bh		;af15   ; lo que quede hasta 0x6B
	ld b,a			;af17
	jr L_AF2C		;af18
L_AF1A:
	ld b,a			;af1a   ; lo que va desde el principio
	inc b			;af1b
	inc b			;af1c
	neg		;af1d
	add a,01eh		;af1f
	call suma_a_hl		;af21
	xor a			;af24
	ld (0e2f2h),a		;af25
	jr L_AF2C		;af28
L_AF2A:
	ld b,020h		;af2a   ; y en medio, la fila entera
L_AF2C:
	call setwrt_corto		;af2c
	ex de,hl			;af2f
	ld (0e2f0h),hl		;af30
	ld a,(0e2f2h)		;af33
	and 007h		;af36   ; los tres bits de abajo: por donde empieza el dibujo
	push af			;af38
	call suma_a_hl		;af39
	pop af			;af3c
	sub 008h		;af3d   ; ocho menos: lo que queda del tile
	neg		;af3f
	ld e,a			;af41
L_AF42:
	ld a,(hl)			;af42   ; la casilla
	inc hl			;af43
	out (c),a		;af44
	dec e			;af46
	jr nz,L_AF4E		;af47
	ld e,008h		;af49   ; y al acabarse el tile, se vuelve a empezar
	ld hl,(0e2f0h)		;af4b
L_AF4E:
	djnz L_AF42		;af4e
	ret			;af50

; ----------------------------------------------------------------------
; La pista de hielo se desplaza a lo largo, y la fila que la dibuja sale de un bloque descomprimido a la RAM en 0xE400: los tres bits de abajo del desplazamiento eligen entre DOS versiones del mismo dibujo -0xE400 y 0xE478-, y de ahi salen las treinta y dos casillas de la franja.
; ----------------------------------------------------------------------
pinta_la_fila_del_hielo:		; la franja que se desplaza
	ld hl,038c0h		;af51   ; la fila
	call setwrt_corto		;af54
	ld hl,(0e20dh)		;af57   ; por donde va la pista
	ld a,l			;af5a
	rr h		;af5b   ; entre ocho
	rra			;af5d
	rr h		;af5e
	rra			;af60
	rr h		;af61
	rra			;af63
	ld de,0e400h		;af64   ; una version del dibujo
	jr nc,L_AF6C		;af67
	ld de,0e478h		;af69   ; o la otra, segun el bit que se ha caido
L_AF6C:
	call suma_a_de		;af6c
	ld b,020h		;af6f   ; treinta y dos casillas
L_AF71:
	ld a,(de)			;af71
	inc de			;af72
	out (c),a		;af73
	djnz L_AF71		;af75
	ret			;af77
rectangulo_de_la_pista:		; con el desplazamiento de la pista
	ld bc,(0e20dh)		;af78

; ----------------------------------------------------------------------
; LOS RECTANGULOS CON RECORTE. La cabecera son cinco bytes -columna, ancho, alto y el destino de VRAM- y lo bonito es que cada figura trae DOS juegos de datos del mismo tamano: el que va pegado detras de la cabecera y otro aparte. Cual de los dos se usa lo decide el acarreo de la columna menos el desplazamiento de la pantalla, o sea si la figura esta cortada por la izquierda o no, y el `ex de,hl` de 0xAF9D es el que los intercambia. Hay ocho pares, y los dieciseis bloques encajan al byte.
; ----------------------------------------------------------------------
rectangulo_con_recorte:		; el dibujo pegado, o el de repuesto
	ld a,c			;af7c   ; el desplazamiento de la pantalla
	rr b		;af7d   ; entre ocho: de pixeles a casillas
	rra			;af7f
	rr b		;af80
	rra			;af82
	rr b		;af83
	rra			;af85
	push af			;af86
	push de			;af87
	ld c,a			;af88
	ld a,(hl)			;af89   ; la columna de la figura
	sub c			;af8a   ; menos el desplazamiento: ahi esta el recorte
	ex af,af'			;af8b
	inc hl			;af8c
	ld c,(hl)			;af8d   ; el ancho y el alto
	inc hl			;af8e
	ld b,(hl)			;af8f
	inc hl			;af90
	ld e,(hl)			;af91   ; y el juego de datos de repuesto
	inc hl			;af92
	ld d,(hl)			;af93
	inc hl			;af94
	ld (0e2f0h),de		;af95
	pop de			;af99
	pop af			;af9a
	jr c,L_AF9E		;af9b   ; si la figura no esta cortada
	ex de,hl			;af9d   ; se cambian los dos juegos
L_AF9E:
	ld hl,(0e2f0h)		;af9e
	ex af,af'			;afa1
dibuja_el_rectangulo:		; la parte que cabe, fila a fila
	ld (0e2f0h),bc		;afa2
	ld b,a			;afa6   ; la columna, apuntada
	and a			;afa7
	jp p,L_AFB7		;afa8   ; con la columna negativa
	add a,c			;afab   ; lo que se sale por la izquierda
	ret nc			;afac   ; fuera del todo, no se pinta nada
	ret z			;afad
	ld b,a			;afae
	ld a,c			;afaf
	sub b			;afb0   ; lo que queda de ancho
	call suma_a_de		;afb1   ; y el dibujo empieza mas alla
	ld c,b			;afb4
	jr L_AFCA		;afb5
L_AFB7:
	cp 020h		;afb7   ; pasada la columna 0x20
	ret nc			;afb9
	add a,c			;afba   ; lo que se sale por la derecha
	sub 020h		;afbb
	jr nc,L_AFC2		;afbd
	ld a,b			;afbf
	jr L_AFC6		;afc0
L_AFC2:
	sub c			;afc2   ; el ancho, recortado
	neg		;afc3
	ld c,a			;afc5
L_AFC6:
	ld a,b			;afc6
	call suma_a_hl		;afc7   ; y el destino, corrido
L_AFCA:
	ld (0e2f2h),de		;afca   ; el ancho y el alto, apuntados
	ld b,000h		;afce
filas_del_rectangulo:		; una fila por vuelta
	ld (0e2f4h),de		;afd0   ; donde va esta fila
	push bc			;afd4
	call ldirvm		;afd5   ; la fila, a la VRAM
	pop bc			;afd8
	ex de,hl			;afd9
	ld hl,0e2f1h		;afda
	dec (hl)			;afdd   ; una fila menos
	ret z			;afde
	dec hl			;afdf
	ld a,(hl)			;afe0   ; el ancho
	ex de,hl			;afe1
	ld de,00020h		;afe2   ; la fila de abajo en la pantalla
	add hl,de			;afe5
	ld de,(0e2f4h)		;afe6   ; y la siguiente del dibujo
	call suma_a_de		;afea
	jr filas_del_rectangulo		;afed

; ----------------------------------------------------------------------
; DATOS rle_a_ram_e400_curling: 112 B -> 240 en RAM desde 0xE400; lo
;   descomprime L_74B5 desde 0xA8A8
;   0xafef..0xb05f  (112 bytes)
DATA_rle_a_ram_e400_curling:
	defb 01fh,087h,082h,014h,015h,006h,087h,082h,014h,010h,006h,087h,082h,013h,015h,006h	; afef  ................
	defb 087h,082h,013h,010h,006h,087h,082h,012h,015h,006h,087h,082h,012h,010h,006h,087h	; afff  ................
	defb 082h,011h,015h,006h,087h,082h,011h,010h,006h,087h,082h,010h,015h,006h,087h,002h	; b00f  ................
	defb 010h,02dh,087h,083h,0aah,0a4h,09eh,005h,087h,083h,0aah,0a3h,09bh,005h,087h,083h	; b01f  .-..............
	defb 0a9h,0a2h,09eh,005h,087h,083h,0a9h,0a1h,09bh,005h,087h,083h,0a8h,0a0h,09eh,005h	; b02f  ................
	defb 087h,083h,0a8h,09fh,09bh,005h,087h,083h,0a7h,09dh,09eh,005h,087h,083h,0a7h,09ch	; b03f  ................
	defb 09bh,005h,087h,083h,0a6h,0a5h,09eh,005h,087h,083h,0a6h,09ah,09bh,00fh,087h,000h	; b04f  ................

; ----------------------------------------------------------------------
; DATOS tabla_b05f: 8 B; la carga 0xAEDA
;   0xb05f..0xb067  (8 bytes)
DATA_tabla_b05f:
	defb 088h,08ch,08dh,088h,088h,088h,088h,088h	; b05f  ........

; ----------------------------------------------------------------------
; DATOS tabla_b067: 8 B; la carga 0xAED6
;   0xb067..0xb06f  (8 bytes)
DATA_tabla_b067:
	defb 08eh,08fh,090h,088h,088h,088h,088h,088h	; b067  ........

; ----------------------------------------------------------------------
; DATOS tabla_b06f: 8 B; la carga 0xAEE7
;   0xb06f..0xb077  (8 bytes)
DATA_tabla_b06f:
	defb 0f5h,0f2h,0f3h,0f5h,0f5h,0f5h,0f5h,0f5h	; b06f  ........

; ----------------------------------------------------------------------
; DATOS tabla_b077: 8 B; la carga 0xAEE3
;   0xb077..0xb07f  (8 bytes)
DATA_tabla_b077:
	defb 0f5h,0f4h,0f5h,0f5h,0f5h,0f5h,0f5h,0f5h	; b077  ........

; ----------------------------------------------------------------------
; DATOS cabecera_rectangulo_b07f: x=94, 20 de ancho por 12 de alto, a la
;   casilla 0x3900
;   0xb07f..0xb084  (5 bytes)
DATA_cabecera_rectangulo_b07f:
	defb 05eh,014h,00ch,000h,039h	; b07f

; ----------------------------------------------------------------------
; DATOS rectangulo_b07f: 240 casillas, veinte por fila
;   0xb084..0xb174  (240 bytes)
DATA_rectangulo_b07f:
	defb 00fh,00fh,00fh,00fh,014h,013h,012h,011h,010h,005h,005h,059h,05ah,05bh,05ch,05dh,00fh,00fh,00fh,00fh	; b084  ...........YZ[\]....
	defb 00fh,00fh,00fh,016h,015h,005h,005h,005h,005h,005h,005h,005h,005h,005h,005h,05eh,05fh,00fh,00fh,00fh	; b098  ...............^_...
	defb 00fh,00fh,017h,005h,005h,005h,01fh,01eh,01dh,01ch,065h,066h,067h,068h,005h,005h,005h,060h,00fh,00fh	; b0ac  ..........efgh...`..
	defb 00fh,018h,005h,005h,005h,021h,020h,00fh,027h,026h,06fh,070h,00fh,069h,06ah,005h,005h,005h,061h,00fh	; b0c0  .....! .'&op.ij...a.
	defb 00fh,019h,005h,005h,023h,022h,00fh,029h,028h,005h,005h,071h,072h,00fh,06bh,06ch,005h,005h,062h,00fh	; b0d4  ....#".)(..qr.kl..b.
	defb 01ah,005h,005h,005h,024h,00fh,02ah,005h,02dh,02ch,075h,076h,005h,073h,00fh,06dh,005h,005h,005h,063h	; b0e8  ....$.*.-,uv.s.m...c
	defb 01bh,005h,005h,005h,025h,00fh,02bh,005h,02fh,02eh,077h,078h,005h,074h,00fh,06eh,005h,005h,005h,064h	; b0fc  ....%.+./.wx.t.n...d
	defb 00fh,050h,005h,005h,051h,052h,00fh,053h,054h,005h,005h,09dh,09ch,00fh,09bh,09ah,005h,005h,099h,00fh	; b110  .P..QR.ST...........
	defb 00fh,044h,005h,005h,005h,043h,042h,00fh,040h,041h,064h,063h,00fh,065h,066h,005h,005h,005h,067h,00fh	; b124  .D...CB.@Adc.ef...g.
	defb 00fh,00fh,049h,005h,005h,005h,048h,047h,046h,045h,068h,069h,06ah,06bh,005h,005h,005h,06ch,00fh,00fh	; b138  ..I...HGFEhijk...l..
	defb 00fh,00fh,00fh,04ah,04bh,005h,005h,005h,005h,005h,005h,005h,005h,005h,005h,06eh,06dh,00fh,00fh,00fh	; b14c  ...JK..........nm...
	defb 00fh,00fh,00fh,00fh,04ch,04dh,04eh,04fh,050h,005h,005h,073h,072h,071h,070h,06fh,00fh,00fh,00fh,00fh	; b160  ....LMNOP..srqpo....

; ----------------------------------------------------------------------
; DATOS rectangulo_b07f_recortado: las otras 240 casillas, las de cuando el
;   circulo de la casa entra cortado por la izquierda
;   0xb174..0xb264  (240 bytes)
DATA_rectangulo_b07f_recortado:
	defb 00fh,00fh,00fh,00fh,033h,032h,031h,030h,005h,005h,005h,079h,07ah,07bh,07ch,00fh,00fh,00fh,00fh,00fh	; b174  ....3210...yz{|.....
	defb 00fh,00fh,035h,034h,005h,005h,005h,005h,005h,005h,005h,005h,005h,005h,005h,07dh,07eh,00fh,00fh,00fh	; b188  ..54...........}~...
	defb 00fh,03bh,03ah,005h,005h,005h,039h,038h,037h,036h,080h,081h,082h,005h,005h,005h,083h,084h,00fh,00fh	; b19c  .;:...9876..........
	defb 041h,040h,005h,005h,03fh,03eh,00fh,00fh,03dh,03ch,086h,00fh,00fh,087h,088h,005h,005h,089h,08ah,00fh	; b1b0  A@..?>..=<..........
	defb 045h,005h,005h,005h,044h,00fh,043h,042h,005h,005h,005h,08bh,08ch,00fh,08dh,005h,005h,005h,08eh,00fh	; b1c4  E...D.CB............
	defb 04ah,005h,005h,049h,00fh,00fh,048h,005h,047h,046h,090h,005h,091h,00fh,00fh,092h,005h,005h,093h,00fh	; b1d8  J..I..H.GF..........
	defb 04fh,005h,005h,04eh,00fh,00fh,04dh,005h,04ch,04bh,095h,005h,096h,00fh,00fh,097h,005h,005h,098h,00fh	; b1ec  O..N..M.LK..........
	defb 058h,005h,005h,005h,057h,00fh,056h,055h,005h,005h,005h,09eh,09fh,00fh,0a0h,005h,005h,005h,0a1h,00fh	; b200  X...W.VU............
	defb 056h,055h,005h,005h,054h,053h,00fh,00fh,052h,051h,075h,00fh,00fh,076h,077h,005h,005h,078h,079h,00fh	; b214  VU..TS..RQu..vw..xy.
	defb 00fh,05ch,05bh,005h,005h,005h,05ah,059h,058h,057h,07bh,07ch,07dh,005h,005h,005h,07eh,07fh,00fh,00fh	; b228  .\[...ZYXW{|}...~...
	defb 00fh,00fh,05eh,05dh,005h,005h,005h,005h,005h,005h,005h,005h,005h,005h,005h,080h,081h,00fh,00fh,00fh	; b23c  ..^]................
	defb 00fh,00fh,00fh,00fh,062h,061h,060h,05fh,005h,005h,005h,082h,083h,084h,085h,00fh,00fh,00fh,00fh,00fh	; b250  ....ba`_............

; ----------------------------------------------------------------------
; DATOS cabecera_rectangulo_b264: x=31, 2 de ancho por 12 de alto, a la
;   casilla 0x3900; la carga 0xAEAA
;   0xb264..0xb269  (5 bytes)
DATA_cabecera_rectangulo_b264:
	defb 01fh,002h,00ch,000h,039h	; b264

; ----------------------------------------------------------------------
; DATOS rectangulo_b264: 24 casillas, dos por fila: el borde derecho de la
;   casa
;   0xb269..0xb281  (24 bytes)
DATA_rectangulo_b264:
	defb 0edh,0eeh	; b269
	defb 0edh,0eeh	; b26b
	defb 0edh,0eeh	; b26d
	defb 0edh,0eeh	; b26f
	defb 0edh,0eeh	; b271
	defb 0edh,0eeh	; b273
	defb 0edh,0eeh	; b275
	defb 0edh,0eeh	; b277
	defb 0edh,0eeh	; b279
	defb 0edh,0eeh	; b27b
	defb 0edh,0eeh	; b27d
	defb 0edh,0eeh	; b27f

; ----------------------------------------------------------------------
; DATOS rectangulo_b264_recortado: las otras 24, las de cuando el borde entra
;   cortado
;   0xb281..0xb299  (24 bytes)
DATA_rectangulo_b264_recortado:
	defb 0ech,00fh	; b281
	defb 0ech,00fh	; b283
	defb 0ech,00fh	; b285
	defb 0ech,00fh	; b287
	defb 0ech,00fh	; b289
	defb 0ech,00fh	; b28b
	defb 0ech,00fh	; b28d
	defb 0ech,00fh	; b28f
	defb 0ech,00fh	; b291
	defb 0ech,00fh	; b293
	defb 0ech,00fh	; b295
	defb 0ech,00fh	; b297

; ----------------------------------------------------------------------
; DATOS cabecera_rectangulo_b299: x, 3 de ancho por 14 de alto, a la casilla
;   0x38E0; la carga 0xAE98, la primera de las tres del hielo
;   0xb299..0xb29e  (5 bytes)
DATA_cabecera_rectangulo_b299:
	defb 072h,003h,00eh,0e0h,038h	; b299

; ----------------------------------------------------------------------
; DATOS rectangulo_b299: 42 casillas, tres por fila: la raya de la izquierda
;   de la pista
;   0xb29e..0xb2c8  (42 bytes)
DATA_rectangulo_b299:
	defb 088h,089h,00fh	; b29e
	defb 00fh,0ech,00fh	; b2a1
	defb 00fh,0ech,00fh	; b2a4
	defb 00fh,0ech,00fh	; b2a7
	defb 00fh,0ech,00fh	; b2aa
	defb 00fh,0ech,00fh	; b2ad
	defb 00fh,0ech,00fh	; b2b0
	defb 00fh,0ech,00fh	; b2b3
	defb 00fh,0ech,00fh	; b2b6
	defb 00fh,0ech,00fh	; b2b9
	defb 00fh,0ech,00fh	; b2bc
	defb 00fh,0ech,00fh	; b2bf
	defb 00fh,0ech,00fh	; b2c2
	defb 0f5h,0efh,00fh	; b2c5

; ----------------------------------------------------------------------
; DATOS rectangulo_b299_recortado: las otras 42, las de cuando la raya entra
;   cortada
;   0xb2c8..0xb2f2  (42 bytes)
DATA_rectangulo_b299_recortado:
	defb 08ah,08bh,00fh	; b2c8
	defb 0edh,0eeh,00fh	; b2cb
	defb 0edh,0eeh,00fh	; b2ce
	defb 0edh,0eeh,00fh	; b2d1
	defb 0edh,0eeh,00fh	; b2d4
	defb 0edh,0eeh,00fh	; b2d7
	defb 0edh,0eeh,00fh	; b2da
	defb 0edh,0eeh,00fh	; b2dd
	defb 0edh,0eeh,00fh	; b2e0
	defb 0edh,0eeh,00fh	; b2e3
	defb 0edh,0eeh,00fh	; b2e6
	defb 0edh,0eeh,00fh	; b2e9
	defb 0edh,0eeh,00fh	; b2ec
	defb 0f0h,0f1h,00fh	; b2ef

; ======================================================================
; CODIGO 0xb2f2..0xb36e  (124 bytes)
; ======================================================================


acelera_la_piedra:		; 0x98 mas por fotograma, con tope
	ld hl,(0e22ah)		;b2f2
	ld de,00098h		;b2f5   ; 0x98 mas
	add hl,de			;b2f8
	jr nc,L_B2FE		;b2f9
	ld hl,0ffffh		;b2fb   ; con tope
L_B2FE:
	ld (0e22ah),hl		;b2fe
	ld (0e204h),hl		;b301
	ret			;b304
flancos_del_jugador_de_turno:		; HL al byte que los lleva
	ld hl,0e008h		;b305
	ld a,(0e002h)		;b308   ; el bit 7 dice de quien es el turno
	add a,a			;b30b
	ret nc			;b30c
	ld l,006h		;b30d
	ret			;b30f
arranca_la_tirada:		; el disparo suelta la piedra
	call flancos_del_jugador_de_turno		;b310
	ld de,0e231h		;b313
	ld a,(de)			;b316   ; el estado de la tirada
	and a			;b317
	jr nz,suelta_la_piedra		;b318
	ld a,(hl)			;b31a
	and 010h		;b31b   ; el disparo
	ret z			;b31d
	ex de,hl			;b31e
	inc (hl)			;b31f   ; la tirada, en marcha
	ld hl,0ffe1h		;b320   ; y la velocidad de arranque
	ld (0e202h),hl		;b323
	ld a,h			;b326
	ld (0e201h),a		;b327
	ret			;b32a
suelta_la_piedra:		; el segundo disparo la deja ir
	inc hl			;b32b
	ld a,(hl)			;b32c   ; el disparo
	and 010h		;b32d
	jr z,L_B33E		;b32f
	ld hl,0e202h		;b331
	inc (hl)			;b334   ; dos mas de velocidad
	inc (hl)			;b335
	ld a,(hl)			;b336
	inc hl			;b337
	ret m			;b338   ; pasada de 0x80, se suelta sola
	ld (hl),000h		;b339
	cp 01fh		;b33b   ; y por debajo de 0x1F, aun no
	ret c			;b33d
L_B33E:
	ld a,002h		;b33e   ; la piedra, rodando
	ld (de),a			;b340
	ld a,04ah		;b341   ; con su sonido
	jp arranca_una_pista		;b343
anima_a_los_dos_jugadores:		; las figuras que se turnan
	ld hl,0e244h		;b346   ; el jugador de un lado
	ld de,0b36eh		;b349
	call L_B355		;b34c
	ld hl,0e254h		;b34f   ; y el del otro
	ld de,0b372h		;b352
L_B355:
	ld a,(hl)			;b355   ; la cuenta de la figura
	and a			;b356
	jr z,L_B36B		;b357
	dec a			;b359   ; una menos
	ld (hl),a			;b35a
	inc hl			;b35b
	jr nz,L_B35F		;b35c
	inc (hl)			;b35e   ; y al agotarse, la figura siguiente
L_B35F:
	ld a,(hl)			;b35f
	and 003h		;b360   ; de cuatro en cuatro
	call suma_a_de		;b362
	ld a,(de)			;b365
	dec hl			;b366
	dec hl			;b367
	dec hl			;b368
	ld (hl),a			;b369   ; la figura, apuntada
	ret			;b36a
L_B36B:
	inc hl			;b36b
	jr L_B35F		;b36c

; ----------------------------------------------------------------------
; DATOS tabla_b36e: 8 B: 01 02 01 00 04 05 04 03, o sea dos grupos simetricos
;   de cuatro
;   0xb36e..0xb376  (8 bytes)
DATA_tabla_b36e:
	defb 001h,002h,001h,000h,004h,005h,004h,003h	; b36e  ........

; ======================================================================
; CODIGO 0xb376..0xb4aa  (308 bytes)
; ======================================================================


anima_al_que_barre_la_izquierda:
	ld hl,0e247h		;b376
	ld c,000h		;b379
	call cambia_la_figura_del_barrendero		;b37b
	ld hl,0e257h		;b37e
	ld c,003h		;b381
cambia_la_figura_del_barrendero:		; cada cuatro pixeles de pista
	ld a,(0e20dh)		;b383   ; por donde va la pista
	rra			;b386   ; entre cuatro
	rra			;b387
	and 003h		;b388
	cp (hl)			;b38a   ; y mientras no cambie, la misma figura
	ret z			;b38b
	ld (hl),a			;b38c
	inc hl			;b38d
	ld a,(hl)			;b38e
	inc a			;b38f   ; la figura siguiente
	cp 003h		;b390   ; de tres en tres
	jr c,L_B395		;b392
	xor a			;b394
L_B395:
	ld (hl),a			;b395
	ld de,0fffbh		;b396
	add hl,de			;b399
	add a,c			;b39a
	ld (hl),a			;b39b   ; apuntada
	ret			;b39c
apaga_la_piedra_al_pararse:		; el color, quitado
	ld a,(0e231h)		;b39d   ; si la tirada no ha empezado, nada
	and a			;b3a0
	ret z			;b3a1
	ld hl,0e263h		;b3a2
	ld a,(0e20dh)		;b3a5   ; por donde va la pista
	and 001h		;b3a8
	cp (hl)			;b3aa   ; y mientras no cambie, nada
	ret z			;b3ab
	dec l			;b3ac
	dec l			;b3ad
	dec (hl)			;b3ae   ; una menos
	ld a,(hl)			;b3af
	cp 014h		;b3b0   ; por debajo de 0x14
	ret nc			;b3b2
	dec l			;b3b3
	ld (hl),0e0h		;b3b4   ; el sprite, escondido
	ret			;b3b6
anima_la_piedra:		; la figura, y el aviso al llegar
	ld a,(0e231h)		;b3b7   ; si la tirada no ha empezado
	and a			;b3ba
	ld hl,0e263h		;b3bb
	jr nz,L_B3DA		;b3be
	ld a,(0e20dh)		;b3c0   ; por donde va la pista
	and 0fch		;b3c3
	cp (hl)			;b3c5   ; y mientras no cambie, nada
	ret z			;b3c6
	ld (hl),a			;b3c7
	dec hl			;b3c8
	ld a,(hl)			;b3c9
	inc a			;b3ca   ; la figura siguiente
	cp 00ah		;b3cb   ; de nueve
	jr c,L_B3D1		;b3cd
	ld a,007h		;b3cf   ; y vuelta a la septima
L_B3D1:
	ld (hl),a			;b3d1
	cp 008h		;b3d2   ; en la octava
	ret nz			;b3d4
	ld a,049h		;b3d5   ; suena
	jp arranca_una_pista		;b3d7
L_B3DA:
	cp 002h		;b3da   ; con dos
	ld a,007h		;b3dc
	jr nz,L_B3E2		;b3de
	ld a,00eh		;b3e0   ; una figura
L_B3E2:
	dec hl			;b3e2
	ld (hl),a			;b3e3   ; y la otra
	ret			;b3e4
barre_uno_u_otro:		; las dos teclas, cada una a un lado
	call flancos_del_jugador_de_turno		;b3e5   ; lo recien pulsado por el jugador de turno
	ld a,(hl)			;b3e8
	push af			;b3e9
	and 010h		;b3ea   ; el bit 4
	ld hl,0e242h		;b3ec
	ld c,001h		;b3ef
	call nz,apunta_el_barrido		;b3f1
	ld hl,0e252h		;b3f4
	pop af			;b3f7
	and 008h		;b3f8   ; y el bit 3
	ret z			;b3fa
	ld c,004h		;b3fb
apunta_el_barrido:		; la figura del que barre
	ld a,(hl)			;b3fd
	inc hl			;b3fe
	inc hl			;b3ff
	ld (hl),008h		;b400   ; la cuenta
	inc hl			;b402
	cp c			;b403   ; hacia un lado
	jr nz,L_B408		;b404
	inc (hl)			;b406
	ret			;b407
L_B408:
	inc (hl)			;b408   ; o hacia el otro
	inc (hl)			;b409
	ret			;b40a
sprites_del_curling:		; las cuatro figuras, a la tabla de la RAM
	ld de,0e194h		;b40b   ; el primer hueco
	exx			;b40e
	ld hl,0e240h		;b40f   ; la figura de un jugador
	call figura_de_varias_piezas		;b412
	ld de,0e1a4h		;b415
	ld hl,0e240h		;b418   ; y la del otro
	call sprite_del_barrendero		;b41b
	ld de,0e180h		;b41e
	exx			;b421
	ld hl,0e250h		;b422
	call figura_de_varias_piezas		;b425
	ld de,0e190h		;b428
	ld hl,0e250h		;b42b
sprite_del_barrendero:		; los cuatro bytes de uno
	ld a,(0e239h)		;b42e   ; si la tirada ya termino
	and a			;b431
	ld a,0e0h		;b432   ; fuera de la pantalla
	jr nz,L_B437		;b434
	ld a,(hl)			;b436
L_B437:
	cp 0e0h		;b437   ; la fila, dieciseis mas abajo
	jr z,L_B43D		;b439
	add a,010h		;b43b
L_B43D:
	ld (de),a			;b43d   ; la fila
	inc de			;b43e
	inc hl			;b43f
	ld a,(hl)			;b440   ; la columna
	ld (de),a			;b441
	inc de			;b442
	inc hl			;b443
	inc hl			;b444
	ld a,(hl)			;b445
	ld hl,0b5a2h		;b446   ; el patron, de la tabla
	call suma_a_hl		;b449
	ld a,(hl)			;b44c
	ld (de),a			;b44d
	inc de			;b44e
	ld a,00ch		;b44f   ; y el color
	ld (de),a			;b451
	ret			;b452
sprites_de_la_piedra:		; si esta en el aire
	ld a,(0e233h)		;b453   ; si no hay tirada, nada
	and a			;b456
	ret z			;b457
	ld de,0e1b0h		;b458
	exx			;b45b
	ld hl,0e260h		;b45c

; ----------------------------------------------------------------------
; Las figuras del curling son varias piezas de cuatro bytes cada una, y salen de la tabla de 0xB4AA: la figura se multiplica por dieciseis para dar con su grupo, y de ahi salen cuatro piezas -cinco o seis en dos de ellas-, cada una con su fila, su columna, su patron y su color. Una fila de 0x80 en la tabla significa que la pieza no se pinta: se le pone la fila 0xE0, que esta fuera de la pantalla.
; ----------------------------------------------------------------------
figura_de_varias_piezas:		; las piezas de la tabla de 0xB4AA
	ld c,(hl)			;b45f   ; la fila de la figura
	inc hl			;b460
	ld b,(hl)			;b461
	inc hl			;b462
	ld a,(hl)			;b463   ; cual es
	push af			;b464
	inc hl			;b465
	add a,a			;b466   ; por dieciseis
	add a,a			;b467
	add a,a			;b468
	add a,a			;b469
	cp 080h		;b46a   ; pasada la mitad, cuatro mas
	jr c,L_B470		;b46c
	add a,004h		;b46e
L_B470:
	exx			;b470
	ld hl,0b4aah		;b471   ; la tabla de las piezas
	call suma_a_hl		;b474
	pop af			;b477
	cp 00eh		;b478   ; la figura 0x0E
	ld b,004h		;b47a   ; cuatro piezas
	jr nz,L_B47F		;b47c
	inc b			;b47e   ; y esa, una mas
L_B47F:
	cp 007h		;b47f   ; la 0x07
	jr nz,L_B484		;b481
	inc b			;b483
L_B484:
	exx			;b484
	ld a,c			;b485
	exx			;b486
	cp 0e0h		;b487   ; la fila 0xE0 no se pinta
	jr z,L_B48C		;b489
	add a,(hl)			;b48b   ; y las demas van sumadas
L_B48C:
	ld c,a			;b48c
	ld a,(hl)			;b48d
	cp 080h		;b48e   ; el 0x80 de la tabla
	jr nz,L_B494		;b490
	ld c,0e0h		;b492   ; tampoco se pinta
L_B494:
	ld a,c			;b494
	inc hl			;b495
	ld (de),a			;b496   ; la fila
	inc de			;b497
	ld a,(hl)			;b498
	inc hl			;b499
	exx			;b49a
	add a,b			;b49b   ; la columna, sumada
	exx			;b49c
	ld (de),a			;b49d
	inc de			;b49e
	ld a,(hl)			;b49f   ; el patron
	inc hl			;b4a0
	ld (de),a			;b4a1
	inc de			;b4a2
	ld a,(hl)			;b4a3   ; y el color
	inc hl			;b4a4
	ld (de),a			;b4a5
	inc de			;b4a6
	djnz L_B484		;b4a7
	ret			;b4a9

; ----------------------------------------------------------------------
; DATOS tabla_b4aa: 248 B; la indexa 0xB471 con `call L_4046`
;   0xb4aa..0xb5a2  (248 bytes)
DATA_tabla_b4aa:
	defb 000h,000h,000h,006h,000h,000h,010h,00ah,010h,0f6h,034h,001h,014h,0eeh,040h,004h	; b4aa  ..........4...@.
	defb 000h,000h,004h,006h,000h,000h,010h,00ah,010h,003h,030h,001h,080h,000h,0fch,000h	; b4ba  ..........0.....
	defb 000h,000h,008h,006h,000h,000h,010h,00ah,010h,008h,02ch,001h,014h,010h,044h,004h	; b4ca  ..........,...D.
	defb 000h,000h,00ch,006h,018h,0fbh,038h,001h,014h,0f0h,048h,004h,080h,000h,0fch,000h	; b4da  ......8...H.....
	defb 000h,000h,00ch,006h,080h,000h,0fch,000h,080h,000h,0fch,000h,080h,000h,0fch,000h	; b4ea  ................
	defb 000h,000h,00ch,006h,018h,007h,03ch,001h,014h,011h,04ch,004h,080h,000h,0fch,000h	; b4fa  ......<...L.....
	defb 000h,000h,050h,086h,000h,000h,060h,08ah,010h,000h,074h,08ah,010h,000h,080h,084h	; b50a  ..P...`...t.....
	defb 000h,002h,054h,086h,000h,002h,064h,08ah,004h,005h,078h,08ah,010h,0fah,084h,084h	; b51a  ..T...d...x.....
	defb 010h,008h,088h,084h,000h,003h,058h,086h,000h,003h,068h,08ah,010h,0ffh,07ch,08ah	; b52a  ......X...h...|.
	defb 010h,0ffh,08ch,084h,000h,001h,058h,086h,000h,001h,068h,08ah,010h,000h,074h,08ah	; b53a  ......X...h...t.
	defb 010h,000h,080h,084h,000h,000h,098h,006h,000h,000h,0a8h,00ah,010h,000h,020h,00ch	; b54a  .............. .
	defb 010h,0feh,030h,001h,000h,000h,09ch,006h,000h,000h,0ach,00ah,010h,000h,020h,00ch	; b55a  ..0........... .
	defb 010h,0feh,030h,001h,000h,000h,0a0h,006h,000h,000h,0b0h,00ah,0f4h,0f1h,0b8h,004h	; b56a  ..0.............
	defb 010h,000h,020h,00ch,000h,000h,0a4h,006h,000h,000h,0b4h,00ah,0f4h,00dh,0bch,004h	; b57a  .. .............
	defb 010h,000h,020h,00ch,000h,000h,05ch,086h,000h,0f0h,06ch,08ah,000h,000h,070h,08ah	; b58a  .. ...\...l...p.
	defb 010h,0edh,090h,084h,010h,0fdh,094h,084h	; b59a  ........

; ----------------------------------------------------------------------
; DATOS tabla_b5a2: 6 B; la indexa 0xB446
;   0xb5a2..0xb5a8  (6 bytes)
DATA_tabla_b5a2:
	defb 01ch,020h,018h,014h,020h,01ch	; b5a2

; ======================================================================
; CODIGO 0xb5a8..0xb666  (190 bytes)
; ======================================================================


acerca_a_los_barrenderos:		; los dos, siguiendo a la piedra
	ld a,(0e260h)		;b5a8   ; si el de abajo esta escondido, nada
	cp 0e0h		;b5ab
	ret nz			;b5ad
	ld hl,0e240h		;b5ae
	ld d,(hl)			;b5b1
	ld c,020h		;b5b2   ; la columna del de arriba
	ld e,018h		;b5b4
	call acerca_un_barrendero		;b5b6
	ld hl,(0e20dh)		;b5b9   ; por donde va la pista
	ld bc,0035ch		;b5bc
	and a			;b5bf
	sbc hl,bc		;b5c0   ; pasada la 0x35C
	ld hl,0e250h		;b5c2
	jr c,L_B5CA		;b5c5
	ld (hl),0e0h		;b5c7   ; el de abajo se esconde
	ret			;b5c9
L_B5CA:
	ld a,(hl)			;b5ca
	sub d			;b5cb   ; la distancia entre los dos
	cp 015h		;b5cc   ; a menos de 0x15
	jr nc,L_B5D5		;b5ce
	ld a,001h		;b5d0
	ld (0e232h),a		;b5d2   ; se acabo el barrido
L_B5D5:
	ld e,02ch		;b5d5
	ld c,00ch		;b5d7
acerca_un_barrendero:		; un pixel por fotograma hacia la piedra
	ld a,(0e209h)		;b5d9   ; la columna de la piedra
	ld b,a			;b5dc
	ld a,(hl)			;b5dd
	add a,c			;b5de   ; la del barrendero, mas su hueco
	cp b			;b5df
	jr z,L_B5EB		;b5e0   ; si esta donde debe, no se mueve
	ld c,001h		;b5e2   ; y si no, un pixel hacia alla
	jr c,L_B5E8		;b5e4
	ld c,0ffh		;b5e6
L_B5E8:
	ld a,(hl)			;b5e8
	add a,c			;b5e9
	ld (hl),a			;b5ea
L_B5EB:
	inc hl			;b5eb
	ld a,(0e1a9h)		;b5ec   ; la fila, la de la piedra
	add a,e			;b5ef
	ld (hl),a			;b5f0
	ret			;b5f1

; ----------------------------------------------------------------------
; LOS PUNTOS DEL CURLING, sin una sola multiplicacion. La distancia al centro se saca doblando las dos coordenadas sobre el eje de la casa -de ahi los dos `neg`- y con ellas se entra en la tabla TRIANGULAR de 0xB666, seis filas de cinco donde cada casilla trae ya los dos valores empaquetados en un byte. De ahi sale un indice de 0 a 7, y ese indice se convierte en puntos con la tabla de 0xB684: 0, 5, 10, 15, 20, 25, 30 y 40.
; ----------------------------------------------------------------------
puntos_de_la_tirada:		; la distancia al centro de la casa
	ld a,(0e209h)		;b5f2   ; la columna de la piedra
	sub 03ah		;b5f5   ; desde el borde de la casa
	ret c			;b5f7
	cp 060h		;b5f8   ; fuera de la casa, cero puntos
	ret nc			;b5fa
	ld c,a			;b5fb
	ld hl,(0e20dh)		;b5fc   ; por donde va la pista
	ld de,002c0h		;b5ff
	and a			;b602
	sbc hl,de		;b603
	ret c			;b605   ; antes de la casa, tampoco
	ld a,l			;b606
	cp 0a0h		;b607   ; pasada de 0xA0
	ret nc			;b609
	cp 050h		;b60a   ; la mitad de aca
	jr c,L_B612		;b60c
	neg		;b60e   ; y la de alla, doblada sobre el centro
	add a,09fh		;b610
L_B612:
	ld b,a			;b612
	ld a,c			;b613
	cp 030h		;b614   ; lo mismo con la otra coordenada
	jr c,L_B61C		;b616
	neg		;b618
	add a,05fh		;b61a
L_B61C:
	rra			;b61c   ; entre ocho: la fila de la tabla
	rra			;b61d
	rra			;b61e
	and 01fh		;b61f
	ld e,a			;b621
	add a,a			;b622   ; por cinco: cinco columnas por fila
	add a,a			;b623
	add a,e			;b624
	ld e,a			;b625
	ld a,b			;b626
	ld d,001h		;b627
	rra			;b629   ; entre dieciseis
	rra			;b62a
	rra			;b62b
	rra			;b62c
	jr nc,L_B630		;b62d   ; el bit que se cae dice que nibble
	dec d			;b62f
L_B630:
	and 00fh		;b630
	add a,e			;b632
	ld hl,0b666h		;b633   ; la tabla triangular
	call suma_a_hl		;b636
	ld a,(hl)			;b639
	dec d			;b63a   ; el nibble de arriba
	jr nz,L_B641		;b63b
	rra			;b63d
	rra			;b63e
	rra			;b63f
	rra			;b640
L_B641:
	and 00fh		;b641
	ld e,a			;b643
	ld a,(0e209h)		;b644   ; justo en el centro
	sub 069h		;b647
	cp 004h		;b649
	jr nc,L_B658		;b64b
	ld a,(0e20dh)		;b64d
	sub 010h		;b650   ; y en la fila justa
	cp 004h		;b652
	jr nc,L_B658		;b654
	ld e,007h		;b656   ; son los cuarenta puntos
L_B658:
	ld a,e			;b658
	ld hl,0b684h		;b659   ; la tabla de los ocho valores
	call suma_a_hl		;b65c
	ld h,(hl)			;b65f
	ld l,000h		;b660
	ld (0e234h),hl		;b662   ; y ese es el resultado de la tirada
	ret			;b665

; ----------------------------------------------------------------------
; DATOS tabla_triangular_b666: 30 B en seis filas de cinco, cada una mayor que
;   la anterior y en BCD: 00 00 01 11 11 / 00 01 11 12 22 / 00 11 12 23 33 /
;   01 11 22 33 34 / 01 12 23 34 45 / 01 12 33 44 56
;   0xb666..0xb684  (30 bytes)
DATA_tabla_triangular_b666:
	defb 000h,000h,001h,011h,011h	; b666
	defb 000h,001h,011h,012h,022h	; b66b
	defb 000h,011h,012h,023h,033h	; b670
	defb 001h,011h,022h,033h,034h	; b675
	defb 001h,012h,023h,034h,045h	; b67a
	defb 001h,012h,033h,044h,056h	; b67f

; ----------------------------------------------------------------------
; DATOS tabla_b684: 8 B en BCD: 00 05 10 15 20 25 30 40
;   0xb684..0xb68c  (8 bytes)
DATA_tabla_b684:
	defb 000h,005h,010h,015h,020h,025h,030h,040h	; b684  .... %0@

; ======================================================================
; CODIGO 0xb68c..0xb754  (200 bytes)
; ======================================================================


sprite_de_la_piedra_en_la_casa:		; la piedra, con su sombra
	ld a,(0e231h)		;b68c   ; si no hay tirada, nada
	and a			;b68f
	ret z			;b690
	call patron_de_la_piedra		;b691
	ld hl,0e1c4h		;b694
	ld de,(0e1a8h)		;b697   ; la posicion
	ld a,010h		;b69b   ; dieciseis mas abajo
	add a,e			;b69d
	ld (hl),a			;b69e
	inc hl			;b69f
	ld a,010h		;b6a0   ; y dieciseis a la derecha
	add a,d			;b6a2
	ld (hl),a			;b6a3
	inc hl			;b6a4
	ld (hl),c			;b6a5   ; con el patron que le toca
	inc hl			;b6a6
	ld (hl),001h		;b6a7   ; y su color
	ret			;b6a9
patron_de_la_piedra:		; segun lo deprisa que vaya
	ld hl,(0e202h)		;b6aa   ; la velocidad
	ld a,l			;b6ad
	or h			;b6ae
	ld c,000h		;b6af   ; parada, el primero
	jr z,L_B6C0		;b6b1
	ld a,(0e237h)		;b6b3   ; el reparto de la direccion
	cp 008h		;b6b6   ; pasado el ocho
	jr c,L_B6C0		;b6b8
	inc c			;b6ba
	cp 020h		;b6bb   ; y pasado el 0x20
	jr c,L_B6C0		;b6bd
	inc c			;b6bf
L_B6C0:
	ld a,h			;b6c0
	add a,a			;b6c1   ; si va hacia el otro lado
	ld a,c			;b6c2
	jr nc,L_B6C7		;b6c3
	neg		;b6c5   ; el patron se cuenta al reves
L_B6C7:
	add a,a			;b6c7   ; por cuatro: son patrones de 16x16
	add a,a			;b6c8
	add a,0c8h		;b6c9   ; desde el 0xC8
	ld c,a			;b6cb
	ret			;b6cc
monta_el_hielo:		; la pista de curling, patrones y color
	ld hl,00880h		;b6cd
	ld bc,00490h		;b6d0
	ld a,05fh		;b6d3   ; el color del hielo
	call 00056h		;b6d5   ; BIOS FILVRM - Fills VRAM with value
	ld hl,01200h		;b6d8
	ld bc,003b8h		;b6db
	call 00056h		;b6de   ; BIOS FILVRM - Fills VRAM with value
	ld de,0b754h		;b6e1   ; las casillas
	call descomprime_a_vram		;b6e4
	ld hl,02880h		;b6e7   ; los patrones
	ld de,0b772h		;b6ea
	call descomprime_a_vram_en		;b6ed
	ld hl,03200h		;b6f0   ; su color
	ld de,0b907h		;b6f3
	call descomprime_a_vram_en		;b6f6
	ld hl,02ac8h		;b6f9
	ld de,0b772h		;b6fc
	ld bc,00248h		;b6ff
	call espeja_un_dibujo		;b702   ; y las dos mitades que se repiten
	ld hl,03318h		;b705
	ld de,0b907h		;b708
	ld bc,00118h		;b70b
	call espeja_un_dibujo		;b70e
	ld hl,02730h		;b711   ; el circulo de la casa
	ld de,0bac2h		;b714
	call descomprime_en_los_tres_tercios		;b717
	ld de,0b9c4h		;b71a   ; con sus casillas
	call descomprime_a_vram		;b71d
	ld hl,00730h		;b720
	ld de,0bb4fh		;b723
	call descomprime_en_los_tres_tercios		;b726
	ld de,0bb0eh		;b729
	jp descomprime_a_vram		;b72c

; ----------------------------------------------------------------------
; EL ESPEJO. La pista de curling es simetrica, asi que la mitad de la derecha no esta guardada: se descomprime la de la izquierda a la RAM y se le da la vuelta a cada byte, bit a bit, con ocho vueltas de `rl (hl) / rra` -lo que sale por arriba de la casilla entra por abajo del acumulador-. Asi el dibujo ocupa la mitad.
; ----------------------------------------------------------------------
espeja_un_dibujo:		; el mismo bloque, del reves
	push hl			;b72f
	push bc			;b730
	ex de,hl			;b731
	ld de,0e400h		;b732   ; el bloque, descomprimido a la RAM
	call descomprime_a_la_ram_en		;b735
	pop de			;b738
	push de			;b739
	ld hl,0e400h		;b73a
L_B73D:
	ld b,008h		;b73d   ; ocho bits
	xor a			;b73f
L_B740:
	rl (hl)		;b740   ; el bit de arriba del byte
	rra			;b742   ; entra por abajo del resultado: eso es el espejo
	djnz L_B740		;b743
	ld (hl),a			;b745   ; el byte, ya del reves
	inc hl			;b746
	dec de			;b747   ; y el siguiente
	ld a,d			;b748
	or e			;b749
	jr nz,L_B73D		;b74a
	pop bc			;b74c
	ld de,0e400h		;b74d   ; el bloque espejado, a la VRAM
	pop hl			;b750
	jp ldirvm		;b751

; ----------------------------------------------------------------------
; DATOS rle_b754: 30 B -> 128 de VRAM en SEIS tramos
;   0xb754..0xb772  (30 bytes)
DATA_rle_b754:
	defb 060h,009h,020h,058h,080h,030h,00ah,010h,058h,080h,058h,00ah,010h,058h,080h,0a8h	; b754  `. X.0..X.X..X..
	defb 00bh,020h,058h,080h,078h,00ch,010h,058h,080h,0a0h,00ch,010h,058h,000h	; b764  . X.x..X....X.

; ----------------------------------------------------------------------
; DATOS rle_patrones_b772: 405 B -> 584 de VRAM en 0x2880
;   0xb772..0xb907  (405 bytes)
DATA_rle_patrones_b772:
	defb 081h,00fh,007h,0ffh,082h,000h,00fh,006h,0ffh,003h,000h,081h,00fh,004h,0ffh,005h	; b772  ................
	defb 000h,083h,00fh,0ffh,0ffh,007h,000h,084h,003h,00fh,01fh,07fh,005h,0ffh,003h,000h	; b782  ................
	defb 096h,001h,007h,00fh,01fh,03fh,000h,001h,007h,00fh,01fh,03fh,07fh,0ffh,001h,001h	; b792  .....?.....?....
	defb 003h,003h,007h,00fh,00fh,01fh,01fh,003h,03fh,004h,07fh,004h,000h,008h,001h,004h	; b7a2  ........?.......
	defb 000h,002h,0ffh,081h,0c0h,005h,000h,003h,0ffh,081h,0f0h,004h,000h,004h,0ffh,084h	; b7b2  ................
	defb 0fch,0c0h,000h,000h,007h,0ffh,083h,0fch,0f0h,0c0h,006h,000h,003h,0ffh,086h,0feh	; b7c2  ................
	defb 0fch,0f8h,0f0h,0c0h,080h,007h,000h,002h,0ffh,086h,0feh,0fch,0f8h,0f8h,0f0h,0f0h	; b7d2  ................
	defb 003h,0e0h,00ah,0c0h,003h,0e0h,005h,000h,083h,00fh,0ffh,0ffh,007h,000h,082h,00fh	; b7e2  ................
	defb 07fh,007h,0ffh,089h,000h,001h,007h,01fh,03fh,07fh,0ffh,0ffh,001h,003h,003h,008h	; b7f2  ........?.......
	defb 007h,003h,003h,083h,001h,0fch,0e0h,006h,000h,003h,0ffh,085h,0fch,0f8h,0f8h,0f0h	; b802  ................
	defb 0f0h,006h,000h,087h,0e0h,0fch,0f0h,0f0h,0f8h,0f8h,0fch,003h,0ffh,081h,000h,007h	; b812  ................
	defb 0ffh,002h,000h,081h,00fh,005h,0ffh,004h,000h,081h,00fh,003h,0ffh,006h,000h,087h	; b822  ................
	defb 00fh,03fh,000h,001h,007h,01fh,07fh,003h,0ffh,006h,000h,084h,001h,003h,0ffh,0ffh	; b832  .?..............
	defb 006h,000h,002h,0ffh,081h,0fch,005h,000h,004h,0ffh,081h,0c0h,003h,000h,005h,0ffh	; b842  ................
	defb 086h,0fch,0f0h,0c0h,00fh,01fh,07fh,005h,0ffh,004h,000h,084h,001h,003h,007h,00fh	; b852  ................
	defb 005h,000h,003h,0ffh,006h,000h,08ah,00fh,0ffh,0ffh,0fch,0f0h,0e0h,0c0h,080h,000h	; b862  ................
	defb 000h,007h,0ffh,086h,0fch,01fh,01fh,03fh,03fh,07fh,003h,0ffh,007h,000h,084h,001h	; b872  .......??.......
	defb 007h,01fh,07fh,005h,0ffh,003h,000h,08eh,001h,003h,007h,00fh,00fh,0f8h,0f0h,0e0h	; b882  ................
	defb 0c0h,080h,080h,000h,000h,001h,003h,003h,004h,007h,081h,0c3h,007h,000h,089h,0ffh	; b892  ................
	defb 0feh,0f0h,0c0h,080h,080h,000h,000h,01fh,003h,03fh,004h,07fh,003h,0feh,005h,0fch	; b8a2  .........?......
	defb 004h,00fh,004h,01fh,007h,000h,089h,003h,000h,000h,080h,080h,0c0h,0f0h,0feh,0ffh	; b8b2  ................
	defb 004h,07fh,004h,03fh,005h,0fch,003h,0feh,004h,01fh,004h,00fh,004h,07fh,003h,03fh	; b8c2  ...?...........?
	defb 089h,01fh,0f0h,0f0h,0f8h,0f8h,0fch,0feh,0ffh,0ffh,007h,000h,089h,080h,0ffh,0ffh	; b8d2  ................
	defb 07fh,03fh,01fh,007h,001h,000h,007h,0ffh,081h,07fh,005h,0ffh,082h,07fh,01fh,003h	; b8e2  .?..............
	defb 00fh,083h,007h,003h,001h,005h,000h,002h,080h,084h,0c0h,0e0h,0f0h,0f8h,004h,007h	; b8f2  ................
	defb 003h,003h,081h,001h,000h	; b902

; ----------------------------------------------------------------------
; DATOS rle_patrones_b907: 189 B -> 280 de VRAM en 0x3200, o sea patrones de
;   SPRITE
;   0xb907..0xb9c4  (189 bytes)
DATA_rle_patrones_b907:
	defb 081h,00fh,007h,000h,002h,0ffh,081h,00fh,00bh,000h,087h,0c0h,0f0h,0c0h,0f0h,0f8h	; b907  ................
	defb 0fch,0feh,003h,0ffh,088h,01fh,00fh,00fh,007h,003h,003h,001h,001h,005h,000h,083h	; b917  ................
	defb 0c0h,0ffh,0ffh,004h,000h,081h,0f0h,003h,0ffh,002h,000h,082h,0c0h,0fch,004h,0ffh	; b927  ................
	defb 081h,0fch,008h,0ffh,08ch,07fh,03fh,01fh,00fh,007h,001h,000h,03fh,01fh,00fh,007h	; b937  ......?.....?...
	defb 001h,003h,000h,005h,0ffh,084h,07fh,01fh,00fh,003h,007h,000h,002h,0ffh,081h,00fh	; b947  ................
	defb 005h,000h,004h,0ffh,081h,00fh,003h,000h,006h,0ffh,082h,00fh,000h,007h,0ffh,081h	; b957  ................
	defb 00fh,003h,0ffh,005h,000h,082h,0ffh,00fh,008h,000h,087h,080h,0c0h,0e0h,0f0h,0fch	; b967  ................
	defb 0ffh,0fch,00ah,0ffh,086h,07fh,03fh,03fh,01fh,01fh,001h,00dh,000h,002h,0ffh,005h	; b977  ......??........
	defb 000h,083h,0fch,0ffh,0ffh,003h,000h,081h,0c0h,004h,0ffh,083h,0c0h,0f0h,0fch,00ah	; b987  ................
	defb 0ffh,087h,07fh,01fh,00fh,00fh,007h,003h,001h,004h,000h,003h,0ffh,087h,07fh,01fh	; b997  ................
	defb 007h,001h,000h,003h,001h,006h,000h,007h,0ffh,081h,000h,005h,0ffh,083h,00fh,000h	; b9a7  ................
	defb 000h,003h,0ffh,081h,00fh,004h,000h,082h,03fh,00fh,006h,000h,000h	; b9b7  ........?....

; ----------------------------------------------------------------------
; DATOS rle_b9c4: 254 B -> 360 de VRAM
;   0xb9c4..0xbac2  (254 bytes)
DATA_rle_b9c4:
	defb 000h,024h,0a0h,07ch,0feh,0c6h,0bah,082h,044h,0bah,0efh,07ch,0feh,0c6h,0aah,082h	; b9c4  .$.|....D..|....
	defb 044h,0bah,0efh,0c7h,0efh,06ch,0aah,028h,044h,0abh,0ffh,0c7h,0efh,06ch,0abh,028h	; b9d4  D....l.(D....l.(
	defb 044h,0abh,0ffh,009h,000h,082h,0ffh,000h,00eh,0ffh,00ah,000h,002h,0ffh,006h,000h	; b9e4  D...............
	defb 002h,0f8h,003h,018h,003h,000h,002h,0ffh,003h,001h,003h,000h,005h,080h,002h,0ffh	; b9f4  ................
	defb 083h,001h,0ffh,0ffh,003h,001h,002h,0ffh,083h,080h,0ffh,0ffh,003h,080h,002h,00fh	; ba04  ................
	defb 083h,000h,0ffh,0ffh,003h,000h,002h,0ffh,083h,018h,0ffh,0ffh,003h,018h,002h,0f0h	; ba14  ................
	defb 083h,000h,0ffh,0ffh,04ch,000h,082h,0c1h,022h,003h,036h,085h,022h,0c1h,00fh,0cfh	; ba24  ....L...".6."...
	defb 02fh,003h,03fh,085h,02fh,0cfh,000h,081h,082h,003h,086h,08eh,082h,0e1h,000h,087h	; ba34  /.?./...........
	defb 086h,087h,086h,080h,086h,0e3h,00fh,0ffh,00fh,0efh,003h,03fh,0a4h,0efh,000h,0e1h	; ba44  ...........?....
	defb 032h,036h,0e6h,0c6h,002h,0f1h,000h,0e7h,036h,037h,0e6h,0c0h,006h,0f3h,000h,0e1h	; ba54  26......67......
	defb 032h,036h,0e6h,036h,032h,0e1h,000h,0e7h,036h,037h,0e6h,030h,036h,0e3h,000h,0e1h	; ba64  26.62...67.06...
	defb 0e2h,003h,066h,095h,0f2h,061h,000h,0e7h,0e6h,067h,066h,060h,0f6h,063h,000h,0c7h	; ba74  ..f..a...gf`.c..
	defb 026h,037h,036h,030h,026h,0c3h,0f0h,0f1h,0f2h,003h,0f6h,085h,0f2h,0f1h,0f0h,0f1h	; ba84  &760&...........
	defb 0f3h,004h,0f1h,08ch,0f7h,0f0h,0f3h,0f6h,0f0h,0f0h,0f3h,0f7h,0f7h,0f0h,0f3h,0f6h	; ba94  ................
	defb 003h,0f0h,08dh,0f6h,0f3h,0f0h,0f0h,0f1h,0f3h,0f6h,0f6h,0f7h,0f0h,000h,038h,044h	; baa4  ..............8D
	defb 003h,082h,08ah,044h,038h,000h,038h,07ch,07eh,0feh,0feh,07ch,038h,000h	; bab4  ...D8.8|~..|8.

; ----------------------------------------------------------------------
; DATOS rle_patrones_bac2: 76 B -> 152 de VRAM en los tres tercios desde
;   0x2730
;   0xbac2..0xbb0e  (76 bytes)
DATA_rle_patrones_bac2:
	defb 003h,000h,081h,03eh,004h,000h,088h,020h,050h,02eh,011h,010h,010h,011h,00eh,003h	; bac2  ...>... P.......
	defb 018h,002h,0ffh,003h,000h,003h,080h,002h,0ffh,013h,000h,008h,018h,008h,001h,008h	; bad2  ................
	defb 080h,003h,018h,002h,0f8h,003h,000h,003h,001h,002h,0ffh,003h,000h,005h,080h,003h	; bae2  ................
	defb 000h,003h,001h,002h,0ffh,003h,001h,003h,080h,002h,0ffh,003h,080h,003h,018h,002h	; baf2  ................
	defb 0ffh,003h,018h,003h,000h,002h,0ffh,019h,000h,002h,0ffh,000h	; bb02  ............

; ----------------------------------------------------------------------
; DATOS rle_bb0e: 65 B -> 360 de VRAM; es del monton de la pista de curling, y
;   sale de la cadena de bloques que 0xB6CD descomprime uno detras de otro
;   0xbb0e..0xbb4f  (65 bytes)
DATA_rle_bb0e:
	defb 000h,004h,02bh,013h,005h,0c3h,010h,09fh,020h,06fh,002h,0efh,006h,06fh,002h,0efh	; bb0e  ..+..... o...o..
	defb 006h,06fh,003h,0efh,005h,06fh,002h,0efh,006h,06fh,003h,0efh,01dh,06fh,038h,0f1h	; bb1e  .o...o...o...o8.
	defb 081h,091h,017h,0f1h,081h,091h,03fh,0f1h,081h,091h,007h,0f1h,081h,091h,007h,0f1h	; bb2e  ......?.........
	defb 081h,091h,007h,0f1h,081h,091h,007h,0f1h,081h,091h,007h,0f1h,008h,0f0h,008h,060h	; bb3e  ...............`
	defb 000h	; bb4e

; ----------------------------------------------------------------------
; DATOS rle_color_bac2: 9 B -> las mismas 152 posiciones en 0x0730
;   0xbb4f..0xbb58  (9 bytes)
DATA_rle_color_bac2:
	defb 010h,0f1h,070h,06fh,010h,000h,008h,01fh,000h	; bb4f  ..po.....

; ----------------------------------------------------------------------
; DATOS rle_bb58: 1159 B -> 1696 de VRAM; el segundo bloque mas gordo
;   0xbb58..0xbfdf  (1159 bytes)
DATA_rle_bb58:
	defb 000h,018h,0e2h,00fh,01fh,03fh,036h,029h,009h,000h,006h,000h,01ch,03bh,07bh,075h	; bb58  .....?6).....;{u
	defb 040h,021h,003h,080h,0c0h,0e0h,0e0h,020h,020h,060h,040h,010h,0b8h,0b8h,0bch,0bch	; bb68  @!.....  `@.....
	defb 0fch,0fch,0f8h,00fh,01fh,03fh,036h,029h,009h,000h,006h,000h,034h,073h,07bh,07ch	; bb78  .....?6)....4s{|
	defb 078h,078h,03ch,080h,0c0h,0e0h,0e0h,020h,020h,060h,040h,070h,0d8h,0b8h,0bch,0bch	; bb88  xx<....  `@p....
	defb 07ch,03ch,07ch,00fh,01fh,03fh,036h,029h,009h,000h,006h,000h,014h,03bh,07bh,07ah	; bb98  |<|..?6).....;{z
	defb 07ch,03eh,03fh,080h,0c0h,0e0h,0e0h,020h,020h,060h,040h,050h,0b8h,0b8h,0bch,0bch	; bba8  |>?....  `@P....
	defb 01ch,03ch,018h,007h,00fh,004h,01fh,002h,00fh,08ah,007h,00ch,01bh,03dh,07ch,07dh	; bbb8  .<...........=|}
	defb 07bh,03bh,0c0h,0e0h,004h,0f0h,002h,0e0h,088h,0c0h,060h,0b0h,078h,078h,07ch,0bch	; bbc8  {;........`.xx|.
	defb 0b8h,003h,000h,005h,01fh,002h,00fh,006h,03fh,003h,000h,005h,0c0h,008h,0e0h,081h	; bbd8  ........?.......
	defb 01fh,003h,03fh,002h,03eh,003h,01eh,088h,00fh,00dh,00fh,007h,003h,000h,000h,0f0h	; bbe8  ..?.>...........
	defb 005h,0f8h,003h,0f0h,002h,0e0h,002h,0c0h,087h,0e0h,000h,000h,01fh,01fh,03fh,03fh	; bbf8  ..............??
	defb 003h,03eh,081h,01eh,003h,01fh,087h,00eh,01fh,01fh,000h,000h,0f0h,0f0h,004h,0e0h	; bc08  .>..............
	defb 003h,0f0h,002h,0e0h,08bh,0c0h,040h,040h,000h,000h,01fh,03fh,03fh,07fh,07ch,07ch	; bc18  ......@@...??.||
	defb 004h,078h,08ch,038h,028h,07ch,07ch,000h,000h,0f0h,0f8h,0f8h,0fch,07ch,07ch,004h	; bc28  .x.8(||......||.
	defb 03ch,087h,038h,028h,07ch,07ch,000h,000h,01fh,003h,03fh,002h,03eh,081h,01eh,003h	; bc38  <.8(||....?.>...
	defb 01fh,087h,00eh,01eh,03fh,03eh,000h,000h,0f0h,005h,0f8h,004h,0f0h,084h,0e0h,0f0h	; bc48  ....?>..........
	defb 0f8h,0f8h,004h,000h,086h,069h,0f0h,0ffh,03fh,0c0h,07fh,00ah,000h,086h,060h,0f0h	; bc58  .....i..?.....`.
	defb 0f0h,0c0h,030h,0e0h,008h,000h,088h,03ch,006h,006h,000h,000h,0ffh,0ffh,07fh,00dh	; bc68  ..0....<........
	defb 000h,002h,0f0h,081h,0e0h,008h,000h,002h,040h,003h,060h,089h,020h,030h,03ch,026h	; bc78  ........@.`. 0<&
	defb 01bh,016h,00dh,00ah,005h,00ch,000h,086h,088h,050h,0a8h,050h,0a8h,010h,005h,008h	; bc88  .........P.P....
	defb 002h,01ch,089h,036h,02ah,03eh,02ah,014h,02ah,055h,02ah,055h,019h,000h,089h,008h	; bc98  ...6*>*.*U*U....
	defb 022h,015h,02ah,015h,02ah,010h,004h,004h,003h,00ch,093h,008h,018h,078h,0c8h,0b0h	; bca8  ".*.*........x..
	defb 0d0h,060h,0a0h,040h,000h,000h,003h,006h,08bh,055h,0aah,055h,0a8h,040h,009h,000h	; bcb8  .`.@.....U.U.@..
	defb 084h,080h,000h,080h,080h,00ch,000h,081h,001h,00eh,000h,088h,0c0h,060h,0d1h,0aah	; bcc8  .............`..
	defb 055h,02ah,015h,002h,00fh,000h,087h,080h,020h,004h,040h,009h,0a0h,002h,00eh,000h	; bcd8  U*...... .@.....
	defb 081h,040h,00fh,000h,081h,002h,009h,000h,088h,001h,000h,004h,020h,002h,090h,005h	; bce8  .@.......... ...
	defb 040h,003h,000h,087h,080h,020h,004h,040h,009h,0a0h,002h,00eh,000h,081h,040h,00fh	; bcf8  @.... .@......@.
	defb 000h,081h,002h,00ah,000h,087h,001h,004h,020h,002h,090h,005h,040h,008h,000h,095h	; bd08  ........ ...@...
	defb 007h,00fh,00fh,01eh,01ah,018h,018h,00ch,006h,00fh,01fh,039h,030h,030h,070h,078h	; bd18  ...........900px
	defb 0c0h,0e0h,0b0h,040h,040h,004h,000h,083h,0c0h,0e0h,0e0h,004h,0c0h,094h,000h,01fh	; bd28  ...@@...........
	defb 03fh,03eh,079h,069h,060h,060h,030h,018h,03fh,031h,060h,060h,061h,061h,000h,000h	; bd38  ?>yi``0.?1``aa..
	defb 080h,0c0h,007h,000h,005h,080h,094h,000h,01fh,03fh,03eh,079h,069h,060h,060h,030h	; bd48  .........?>yi``0
	defb 019h,03fh,031h,060h,060h,041h,043h,000h,000h,080h,0c0h,005h,000h,002h,080h,003h	; bd58  .?1``AC.........
	defb 0c0h,002h,080h,094h,00fh,01fh,01fh,03ch,034h,030h,030h,018h,01ch,03eh,03ch,078h	; bd68  .......<400..><x
	defb 078h,07ch,07fh,0ffh,080h,0c0h,060h,080h,00eh,000h,007h,007h,002h,000h,005h,00fh	; bd78  x|....`.........
	defb 002h,000h,003h,0e0h,08bh,0f0h,0e0h,0c0h,080h,000h,000h,006h,0f7h,0feh,0feh,0fch	; bd88  ................
	defb 003h,000h,006h,01fh,082h,01eh,000h,005h,01fh,003h,000h,003h,080h,082h,0c0h,080h	; bd98  ................
	defb 00bh,000h,007h,01fh,006h,03fh,003h,000h,003h,080h,082h,0c0h,080h,005h,000h,003h	; bda8  .....?..........
	defb 0e0h,018h,000h,085h,003h,00fh,01fh,01fh,008h,003h,000h,008h,00fh,004h,0ffh,004h	; bdb8  ................
	defb 07fh,002h,000h,003h,0c0h,08fh,0e0h,0c0h,080h,000h,080h,0fch,0feh,0feh,0f0h,000h	; bdc8  ................
	defb 000h,007h,007h,003h,003h,00ch,000h,002h,080h,002h,0c0h,018h,000h,084h,0f0h,0ffh	; bdd8  ................
	defb 07ch,038h,010h,000h,002h,003h,003h,001h,00bh,000h,002h,0c0h,003h,0e0h,00bh,000h	; bde8  |8..............
	defb 002h,07fh,003h,03fh,087h,01fh,007h,007h,00fh,00fh,01fh,01fh,004h,000h,083h,0e0h	; bdf8  ...?............
	defb 0f0h,0fch,003h,0feh,086h,0fch,0f8h,0f8h,0fch,0feh,0feh,007h,000h,088h,001h,007h	; be08  ................
	defb 00fh,00fh,01fh,01eh,01fh,007h,005h,000h,081h,07fh,004h,0ffh,086h,0f8h,0f0h,080h	; be18  ................
	defb 000h,000h,080h,005h,000h,08ch,0c0h,0e0h,0f0h,0f0h,0f8h,0f8h,079h,07fh,03fh,03fh	; be28  ............y.??
	defb 01eh,018h,014h,000h,002h,007h,082h,003h,05fh,003h,0ffh,085h,0c3h,087h,007h,00fh	; be38  ........_.......
	defb 00fh,004h,000h,082h,0f8h,0fch,003h,0feh,002h,0fch,085h,0f8h,0e0h,0c0h,080h,0c0h	; be48  ................
	defb 017h,000h,082h,001h,00fh,003h,01fh,082h,00eh,007h,006h,000h,002h,03fh,086h,07fh	; be58  .............?..
	defb 0ffh,0feh,0fch,0f0h,080h,008h,000h,002h,0f0h,002h,0f8h,082h,0fch,07ch,003h,03ch	; be68  .............|.<
	defb 082h,07eh,03fh,005h,000h,09ah,003h,007h,00fh,00dh,00ah,00ah,000h,001h,000h,00eh	; be78  .~?.............
	defb 01dh,01dh,03dh,03dh,00dh,00ah,0e0h,0f0h,0f8h,0a8h,048h,058h,010h,090h,010h,02eh	; be88  ..==......HX....
	defb 003h,0dfh,09dh,0deh,0d8h,0a8h,003h,007h,00fh,00dh,00ah,00ah,000h,002h,001h,00eh	; be98  ................
	defb 01dh,01dh,03dh,03dh,00dh,00ah,0e0h,0e0h,0f0h,0aeh,04eh,04eh,00eh,04eh,09eh,02eh	; bea8  ..==......NN.N..
	defb 003h,0dch,002h,0d8h,085h,0a8h,000h,007h,00fh,00fh,003h,01fh,08ch,08fh,0e4h,0f7h	; beb8  ................
	defb 0fbh,07dh,03ch,03dh,01bh,01bh,000h,0c0h,0e0h,004h,0f0h,08ch,0f8h,05ch,0dch,0bch	; bec8  .}<=.........\..
	defb 078h,070h,060h,0a0h,0a0h,000h,000h,00fh,005h,01fh,098h,008h,037h,03bh,03dh,03ch	; bed8  xp`.........7;=<
	defb 01dh,01bh,01bh,000h,000h,0c0h,0e0h,0f0h,0e0h,0e0h,0c0h,08ch,0deh,0beh,07eh,07ch	; bee8  ..............~|
	defb 070h,0b0h,0b0h,003h,000h,005h,007h,006h,003h,002h,07fh,003h,000h,003h,0ffh,084h	; bef8  p...............
	defb 0feh,0ffh,0feh,0feh,006h,0f0h,002h,000h,006h,007h,006h,003h,002h,07fh,083h,00eh	; bf08  ................
	defb 0ffh,0ffh,00dh,0f0h,005h,000h,083h,03fh,07fh,07fh,008h,01fh,008h,000h,002h,0e0h	; bf18  .......?........
	defb 006h,0c0h,008h,000h,008h,01fh,005h,000h,00bh,0f0h,019h,000h,087h,018h,004h,000h	; bf28  ................
	defb 0c0h,020h,006h,001h,009h,000h,087h,018h,020h,000h,003h,004h,060h,080h,010h,000h	; bf38  . ...... ...`...
	defb 084h,07fh,0c0h,080h,081h,003h,080h,092h,081h,083h,087h,08eh,09ch,098h,080h,0c0h	; bf48  ................
	defb 07fh,0feh,003h,001h,0f9h,0f9h,079h,0f9h,0d9h,089h,005h,001h,09ch,003h,0feh,07fh	; bf58  ......y.........
	defb 0c0h,080h,080h,081h,080h,080h,081h,087h,09fh,0bch,0b0h,080h,080h,0c0h,07fh,0feh	; bf68  ................
	defb 003h,001h,001h,0f9h,0f9h,079h,0f9h,0d9h,009h,004h,001h,084h,003h,0feh,07fh,0c0h	; bf78  .....y..........
	defb 005h,080h,002h,0bfh,005h,080h,0a4h,0c0h,07fh,0feh,003h,001h,001h,021h,031h,039h	; bf88  .............!19
	defb 0fdh,0fdh,039h,031h,021h,001h,001h,003h,0feh,07fh,0c0h,080h,080h,0b0h,0bch,09fh	; bf98  ..91!...........
	defb 087h,081h,080h,080h,081h,080h,080h,0c0h,07fh,0feh,003h,004h,001h,093h,009h,0d9h	; bfa8  ................
	defb 0f9h,079h,0f9h,0f9h,001h,001h,003h,0feh,07fh,0c0h,080h,098h,09ch,08eh,087h,083h	; bfb8  .y..............
	defb 081h,003h,080h,086h,081h,080h,0c0h,07fh,0feh,003h,005h,001h,089h,089h,0d9h,0f9h	; bfc8  ................
	defb 079h,0f9h,0f9h,001h,003h,0feh,000h	; bfd8

; ----------------------------------------------------------------------
; DATOS relleno: 17 bytes 0xFF, entre el ultimo bloque comprimido y la marca
;   de Konami
;   0xbfdf..0xbff0  (17 bytes)
DATA_relleno:
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bfdf  .................

; ----------------------------------------------------------------------
; DATOS marca_oculta_de_konami: ハイパースポーツ 3 al reves, su longitud 13, el 0x33
;   de RC-733 y el 0xAA que cierra; no lo lee nadie
;   0xbff0..0xc000  (16 bytes)
DATA_marca_oculta_de_konami:
	defb 033h,000h,091h,0bah,0b8h,09dh,08ch,000h,0bah,0b8h,099h,081h,099h	; bff0  3............
	defb 00dh,033h,0aah	; bffd
