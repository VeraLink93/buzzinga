;
; mCP_ownProject.asm
; Created: 15.05.2021 14:31:24
; Author : Hannah, Sarah, Vera
;
; registers:
; r18:16 are used by the delay function
; r20:19 are used to set the tone frequency (good range: 5000-20000)
; r22:21 are used to manipulate the tone duration (is depending on the frequency as well!)
; r31 stores a 8bit melody

;TASKS:
	; Vera:
	; 1. Phase: Melodie, auf die der Pointer zeigt abspielen
		; play_high_tone und play_deep_tone (ruft dann play_tone mit bestimmten Parametern auf)
		; durch ein Wort/Byte durch iterieren und dann je nach dem ob 0 oder 1:
		;   -> play_high_tone oder play_deep_tone aufrufen

	; Hannah:
	; 2. Phase: Melodie einspielen. So lange wie die Melodie lang ist:
		; wenn Knopf 0 gedrückt wird
		;	-> eine 0 in den Speicher schreiben
		;   -> gleichzeitig einen tiefen Ton wiedergeben
		; wenn Knopf 1 gedrückt wird
		;	-> eine 1 in den Speicher schreiben
		;   -> gleichzeitig einen hohen Ton wiedergeben

	; Sarah:
	; 3. Phase: Melodien vergleichen
		; beide Melodien vergleichen (schon jetzt möglich)
		; (wenn die anderen fertig sind?:
		; wenn Melodien gleich: "Pointer" auf die nächste Melodie versetzen
		; beide Melodien mit einer Pause abspielen

; Generelles Arbeiten:
; USART (nutzen für debugging?)
; Speicheraufbau überlegen (dort mehrere 8-Byte-lange Melodien ablegen)
; 
; Upgrades:
; eine Startmelodie ("richtige" Melodie)



.equ buzz = 2

	sbi DDRD, buzz

main_loop:
	; for now just playing different 8-bit-melodies, initialisedd in r31 (demoversion for phase 1)
	ldi r31, 0B00101011
	rcall play_8bit_melody
	ldi r31, 0B10101010
	rcall play_8bit_melody
	ldi r31, 0B00100100
	rcall play_8bit_melody

	rjmp main_loop


play_8bit_melody:
; uses r23 for looping
; before calling store melody byte in r31  (in demo version)
	; to do: Befehl der Melodie aus SRAM in r31 lädt
	ldi r23, 8							; initialize loop counter to 8
	loop_8bit:
		sbrc r31, 0						; skip if last bit in r31 is 0
		rcall play_one_high_tone		; otherwise play one high tone
		sbrs r31, 0						; skip if last bit in r31 is 1
		rcall play_one_deep_tone		; otherwise play one deep tone
		; set parameters before calling the delay_function for a break after the played tone
		ldi r16, BYTE1(320000)
		ldi r17, BYTE2(320000)
		ldi r18, BYTE3(320000)
		rcall delay_function
		lsr r31					; shift right, so that in the next loop the next tone is played
		dec r23					; decrement loop counter (from 8 to 0)
		brne loop_8bit
	; set parameters before calling the delay_function for a break after the played melody
	ldi r16, BYTE1(1500000)
	ldi r17, BYTE2(1500000)
	ldi r18, BYTE3(1500000)
	rcall delay_function
	ret
	
play_one_high_tone:
	; set parameters (for frequenzy + duration) before calling the function play_tone
	ldi r19, BYTE1(5000)
	ldi r20, BYTE2(5000)
	ldi r21, BYTE1(170)
	ldi r22, BYTE2(170)
	rcall play_tone
	ret

play_one_deep_tone:
	; set parameters (for frequenzy + duration) before calling the function play_tone
	ldi r19, BYTE1(10000)
	ldi r20, BYTE2(10000)
	ldi r21, BYTE1(110)
	ldi r22, BYTE2(110)
	rcall play_tone
	ret

play_tone:
; before each call of this function set these parameters:
; param: in r20:19 number of loops determing the frequency of the tone (the higher, the lower)
; param: in r22:21 number of loops determing the duration of the tone (the higher, the longer)
	sbi PORTD, buzz			; turn buzzer on
	ldi r16, 100			; sets parameter before calling delay_function
	clr r17					; sets parameter before calling delay_function
	clr r18					; sets parameter before calling delay_function
	rcall delay_function	; delay while buzzer is on
	cbi PORTD, buzz			; turn buzzer of
	mov r16, r19			; sets parameter before calling delay_function				Frage von Vera: warum funktionierte hier nicht movw für [r17:16]<-[r20:19] ???
	mov r17, r20			; sets parameter before calling delay_function
	clr r18					; sets parameter before calling delay_function
	rcall delay_function	; delay while buzzer is off
	; decrement counter for loop (counting how long the tone is played):
	sez
	clc
	sbci r21, 1	
	sbci r22, 0
	brne play_tone
	ret

; before each call of this function set this parameter!
; param: in r18:16: number of loops this function makes, to cause a delay
; 1600 loops <=> 1 ms
delay_function:
	nop
	nop
	nop
	sez
	clc
	sbci r16, 1	
	sbci r17, 0
	sbci r18, 0
	brne delay_function
	ret