;
; Vergleichen.asm
;
; Created: 23.05.2021 10:03:16
; Author : STT
;



;Speicher SRAM
.equ zelle = 0x0060
.def ersteMelodie = r16
.def zweiteMelodie = r17
.def dritteMelodie = r18
.def vierteMelodie = r19
.def fuenfteMelodie = r20
    ldi XH, HIGH(zelle)
    ldi XL, LOW(zelle)
    ld ersteMelodie, X+
    ld zweiteMelodie, X+
    ld dritteMelodie, X+
	ld vierteMelodie, X+
	ld fuenfteMelodie, X

;testen
.equ output_bit = 5
sbi DDRD , output_bit

start:
    ldi ersteMelodie  , 0b10011001
	ldi zweiteMelodie , 0b10011001

	ldi dritteMelodie , 0b11011001
	ldi vierteMelodie , 0b11011000

	cpse ersteMelodie , zweiteMelodie ; Compare, Skip if Equal  
	;testen
	sbi PORTD , output_bit

	cpse dritteMelodie , vierteMelodie ; Compare, Skip if Equal
	;testen
	sbi PORTD , output_bit

	rjmp  start

   

