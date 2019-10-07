

include 'include/ez80.inc'
include 'include/tiformat.inc'
include 'include/ti84pceg.inc'
format ti executable "BOSBASIC"

TI_Flags:=$D00080

init:
	call libload_load
	jr z,gfxInit
	call ti.HomeUp
	ld hl,.needlibload
	call ti.PutS
	xor a,a
	ld (ti.curCol),a
	inc a
	ld (ti.curRow),a
	call ti.PutS
	jr GetCSC
.needlibload:
	db "Need libLoad",0
	db "tiny.cc/clibs",0
GetCSC:
	call ti.GetCSC
	or a,a
	jr z,GetCSC
	ret
gfxInit:
	call ti.HomeUp
	call ti.RunIndicOff
	call gfx_Begin
	ld hl,(BB_flags+BB_f_bgc)
	push hl
	call gfx_FillScreen
	pop hl
main_init:
; load in the default palette
	ld ix,BB_flags
	lea de,ix+BB_f_bgc
	ld hl,default_palette
	ld bc,33
	ldir
; setup exec flags, text mode, etc
	xor a,a
	ld (de),a
	inc de
	ld (de),a
	inc de
	ld a,8
	ld (de),a
	inc de
	ex hl,de
	ld de,ArgStack
	ld (hl),de  ;BB_f_argsp
	inc hl
	inc hl
	inc hl
	ld de,ProgStack
	ld (hl),de ;BB_f_progsp
	inc hl
	inc hl
	inc hl
	ld de,TextStack
	ld (hl),de ;BB_f_textsp
	inc hl
	inc hl
	inc hl
	ld (hl),de ;BB_f_begtextsp
	ld hl,TextStack
	push hl
	inc hl
	xor a,a
	ld (hl),a
	push hl
	pop de
	inc de
	ld bc,62
	ldir
	pop hl
	ld bc,TextStackLen-64
	ldir
main:
	ld hl,120
	push hl
	call BB_Alloc
	ex (sp),hl
	call BB_Free
	pop hl
normal:
	ld hl,ti.pixelShadow
	push hl
	pop de
	inc de
	xor a,a
	ld (hl),a
	ld bc,69089
	ldir
	call gfx_End
	ld iy,TI_Flags
	call ti.DrawStatusBar
	jp ti.HomeUp



; Text block structure
; db size_byte ; block is in use unless it's zero.
; db size_byte ; if the previous was zero, this is the length of the free memory space


; Allocate space for data in the text stack
; sp + 3: length of desired space
; return HL pointer to space. HL is zero if not enough memory
BB_Alloc:
	ld a,$CD    ;call
	ld (.smc),a
	ld hl,checkBegTextSP
	ld (.smc+1),hl
	ld hl,(ix+BB_f_begtextsp)
.loop:
.smc:
	call checkBegTextSP
	ld de,TextStackEnd
	xor a,a
	sbc hl,de
	add hl,de
	jr c,.fail
	ld a,(hl)
	or a,a
	jr z,.maybeenough
	ld de,TextBlockLen
	add hl,de
	jr .loop
.maybeenough:
	pop de
	pop bc
	push bc
	push de
	ex hl,de
	inc de
	ld h,TextBlockLen
	ld a,(de)
	ld l,a
	mlt hl
	dec hl
	xor a,a
	sbc hl,bc
	ex hl,de
	jr c,.loop
.success:
	push hl
	ld a,c
	and a,TextBlockLen-1
	or a,a
	jr z,.setupnextblock
	add a,TextBlockLen
	ld c,a
	jr nc,.setupnextblock
	inc b
.setupnextblock:
	add hl,bc
	ld a,(hl)
	or a,a
	jr nz,.done
	inc hl
	ex hl,de
	sbc hl,bc
	ex hl,de
	rl e
	rl d
	rl e
	rl d
	ld (hl),d
.done:
	pop hl
	ret
.fail:
	xor a,a
	sbc hl,hl
	ret

checkBegTextSP:
	ld a,(hl)
	or a,a
	ret nz
	ld (ix+BB_f_begtextsp),hl ;this is where we start looking next time. First avalible memory block
	ex hl,de
	pop hl
	push hl
	dec hl
	ld (hl),0  ;don't call me again
	dec hl
	dec hl
	dec hl
	ld bc,0
	ld (hl),bc
	ex hl,de
	ret


; Free some allocated memory
; sp + 3: pointer to space
; Does nothing if the pointer is not within a valid range
BB_Free:
	pop de
	pop hl
	push hl
	push de
	ld de,TextStack
	sbc hl,de
	push hl
	pop bc
	add hl,de
	ret c
	ld de,TextStackEnd
	sbc hl,de
	add hl,de
	ret nc
	ld a,c
	and a,TextBlockLen-1
	jr z,.next ; already at the start of a block
	ld c,a     ; we need to move to the start
	ld b,0
	xor a,a
	sbc hl,bc
.next:
	ld c,(hl)  ; get the block size byte
	xor a,a
	ld (hl),a  ; zero it
	inc hl
	ld (hl),c  ; load the second byte with the original size
	ret        ; block is now free


BB_f_bgc       :=0
BB_f_pal       :=1
BB_f_execmode  :=33
BB_f_textmode  :=34
BB_f_textspace :=35
BB_f_argsp     :=36
BB_f_progsp    :=39
BB_f_textsp    :=42
BB_f_begtextsp :=45

TextBlockLen:=64

BB_static_code_loc:=ti.pixelShadow
BB_flags:=BB_static_code_loc+96
NameBuffer:=BB_flags+128
CmdBuffer:=NameBuffer+64
ArgStack:=CmdBuffer+64
ProgStack:=ArgStack+3072
TextStack:=ProgStack+3072
TextStackEnd:=ti.pixelShadow + 69090
TextStackLen:=TextStackEnd - TextStack

default_palette:
	db 0       ; console bg
; Text palette indexes
	db 255,0   ; index 0
	db 192,$40 ; index 1
	db 227,0   ; index 2
	db 144,0   ; index 3
	db 7,0     ; index 4
	db 15,0    ; index 5
	db $1A,0   ; index 6
	db $3F,0   ; index 7
	db 0,255   ; index 8
	db 0,192   ; index 9
	db 0,227   ; index A
	db 0,144   ; index B
	db 0,7     ; index C
	db 0,15    ; index D
	db 0,$1A   ; index E
	db 0,$3F   ; index F



include 'str.inc'
include 'load_libs.asm'

