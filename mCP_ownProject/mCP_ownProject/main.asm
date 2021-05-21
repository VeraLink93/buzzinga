;
; mCP_ownProject.asm
; Created: 15.05.2021 14:31:24
; Author : Hannah, Sarah, Vera
;
; registers:
; r17:r16 are used by the delay function
; r19:r18 are used to set the tone frequency (good range: 5000-20000)
; r21:r20 are used to manipulate the tone duration (is depending on the frequency as well!)
;
; note: use the same amounts for x in byte1(x) and byte2(x) when setting values in register pairs
; tip: set shielt on 3V3 for quieter sound

.equ buzz = 2

	sbi DDRD, buzz

; Generelles Arbeiten:
; USART (nutzen für debugging?)
; Speicheraufbau überlegen, dort mehrere 8-Byte-lange Melodien ablegen
; 0B011010101
; 0B001110010
; 

main_loop

	; Vera:
	; 1. Phase: Melodie, auf die der Pointer zeigt abspielen
		; ldi r8, 0B00101000
		; play_high_tone (ruft dann play_tone mit bestimmten Parametern auf)
		; play_deep_tone
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


; Upgrades
; eine Startmelodie ("richtige" Melodie)

rjmp main_loop

play_one_high_tone:
	; set parameters before calling the function play_tone
	ldi r18, BYTE1(8000)
	ldi r19, BYTE2(8000)
	ldi r20, BYTE1(60)
	ldi r21, BYTE2(60)
	rcall play_tone
	ret

play_one_deep_tone:
	; set parameters before calling the function play_tone
	ldi r18, BYTE1(2000)
	ldi r19, BYTE2(20000)
	ldi r20, BYTE1(200)
	ldi r21, BYTE2(200)
	rcall play_tone
	ret


; before each call of this function set these parameters!
; param: in r19:18 number of loops determing the frequency of the tone (the higher, the lower)
; param: in r21:20 number of loops determing the duration of the tone (the higher, the longer)
play_tone:
	sbi PORTD, buzz			; turn buzzer on
	ldi r16, 100			; sets parameter before calling delay_function
	clr r17					; sets parameter before calling delay_function
	rcall delay_function	; delay while buzzer is on
	cbi PORTD, buzz			; turn buzzer of
	movw r16, r18			; sets parameter before calling delay_function; [r17:16]<-[r19:18]
	rcall delay_function	; delay while buzzer is of
	; decrement counter for loop:
	sez
	clc
	sbci r20, 1	
	sbci r21, 0
	brne play_tone
	ret

; before each call of this function set this parameter!
; param: in r17:16 number of loops this function makes, to cause a delay
delay_function:
	sez
	clc
	sbci r16, 1	
	sbci r17, 0
	brne delay_function
	ret
