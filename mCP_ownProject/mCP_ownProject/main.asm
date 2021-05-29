;
; mCP_ownProject.asm
; Created: 15.05.2021 14:31:24
; Author : Hannah, Sarah, Vera
;

.equ BUZZ = 2
.equ LED = 5
.equ BUTTON0 = 3
.equ BUTTON1 = 4

.equ MELODY_LENGTH = 8

.def temp0 = r24
.def temp1 = r25
//.def counter = r26
.def recordedMelody = r27
.def originalMelody = r31

.def delayParam1 = r16 ; parmeter for delay_function, defining the loops that cause a delay (1600 <=> 1ms)
.def delayParam2 = r17 ; parmeter for delay_function, defining the loops that cause a delay (1600 <=> 1ms)
.def delayParam3 = r18 ; parmeter for delay_function, defining the loops that cause a delay (1600 <=> 1ms)
.def toneFreqParam1 = r19 ; parameter for play_tone function, defining the frequency of the tone (higher value -> deeper tone)
.def toneFreqParam2 = r20 ; parameter for play_tone function, defining the frequency of the tone (higher value -> deeper tone)
.def toneDurParam1 = r21 ; parameter for play_tone function, defining the duration of the tone (higher value + higher freq_params -> longer tone)
.def toneDurParam2 = r22 ; parameter for play_tone function, defining the duration of the tone (higher value + higher freq_params -> longer tone)
.def numberOfTones = r23 

	sbi DDRD, BUZZ
	sbi DDRD, LED

consts: .DB 0b10000001, 0b01010101, 0b11110000, 0b10011001, 0b00110111, 0b11011010

ldi ZH, HIGH(consts)		//consts<<1?
ldi ZL, LOW(consts)

;cbi DDRD , BUZZ

increment_pointer: 
	adiw Z, 1

main_loop:
    
	;LED blinks twice to indicate that a melody will be played
	rcall LED_blink_once
	rcall LED_blink_once

	;pause of 1s between LED and play melody
	ldi delayParam1, BYTE1(1600000)
	ldi delayParam2, BYTE2(1600000)
	ldi delayParam3, BYTE3(1600000)
	rcall delay_function

	lpm originalMelody, Z
	rcall play_8bit_melody

	ldi recordedMelody, 0b00000000
	clr numberOfTones
	sbi PORTD, LED						//turn LED on

	;as long as melody is long, check for input (buttons)
	while_melody:
		;check for buttons while (numberOfTones < numberOfBitsInRegister)
		rcall check_if_input_is_valid
		rcall set01_in_register_and_play_tone
		inc numberOfTones
		cpi numberOfTones, MELODY_LENGTH
		brlt while_melody
	cbi PORTD, LED						//turn LED off


	cpse originalMelody, recordedMelody 
    rcall play_failure_melody
	cpse originalMelody, recordedMelody
	rjmp main_loop


	rcall play_success_melody
	rjmp increment_pointer



play_8bit_melody:
; uses numberOfTones for looping
; before calling store melody byte in r31 = parameter
	ldi numberOfTones, MELODY_LENGTH				; initialize loop counter to 8
	loop_8bit:
		sbrc r31, 0						; skip if last bit in r31 is 0
		rcall play_one_high_tone		; otherwise play one high tone
		sbrs r31, 0						; skip if last bit in r31 is 1
		rcall play_one_deep_tone		; otherwise play one deep tone
		; set parameters before calling the delay_function for a break after the played tone
		ldi delayParam1, BYTE1(320000)
		ldi delayParam2, BYTE2(320000)
		ldi delayParam3, BYTE3(320000)
		rcall delay_function
		lsr r31					; shift right, so that in the next loop the next tone is played
		dec numberOfTones					; decrement loop counter (from 8 to 0)
		brne loop_8bit
	; set parameters before calling the delay_function for a break after the played melody
	ldi delayParam1, BYTE1(1500000)
	ldi delayParam2, BYTE2(1500000)
	ldi delayParam3, BYTE3(1500000)
	rcall delay_function
	ret

check_if_input_is_valid:

	//einfacher und weniger Register werden benötigt, aber cpi mit I/O Register möglich?
	;cpi BUTTON0, 1					//"Compare with Immediate"
	;breq
	;rcall set0_in_register

	;check if/ which buttons are pressed
	sbic PIND, BUTTON0				;if BUTTON0 = 1, then temp0 = 1		"Skip if Bit is Cleared"
	ldi temp0, 1						
	sbic PIND, BUTTON1				;if BUTTON1 = 1, then temp1 = 1			
	ldi temp1, 1

	sbis PIND, BUTTON0				;if BUTTON0 = 0, then temp0 = 0		"Skip if Bit is Set"
	ldi temp0, 0						
	sbis PIND, BUTTON1				;if BUTTON1 = 0, then temp1 = 0
	ldi temp1, 0
	
	;if no button or both buttons are pressed check again, else return
	cpse temp0, temp1
	ret
	rjmp check_if_input_is_valid

;set 0 or 1 in register recordedMelody
set01_in_register_and_play_tone:
	cpi temp0, 1
	breq deep_Tone 
	cpi temp1, 1
	breq high_Tone

	; set 1 in register recordedMelody and play tone
	high_Tone:
	//ldi recordedMelody, (1<<counter) // Problem: counter ist keine Zahl sondern registern?! Wie lösen?!
	lsr recordedMelody
	sbr recordedMelody , 0b10000000
	rcall play_one_high_tone
	ret

	deep_Tone:
	lsr recordedMelody
	rcall play_one_deep_tone
	ret
	
play_one_high_tone:
	; set parameters (for frequenzy + duration) before calling the function play_tone
	ldi toneFreqParam1, BYTE1(5000)
	ldi toneFreqParam2, BYTE2(5000)
	ldi toneDurParam1, BYTE1(170)
	ldi toneDurParam2, BYTE2(170)
	rcall play_tone
	ret

play_one_deep_tone:
	; set parameters (for frequenzy + duration) before calling the function play_tone
	ldi toneFreqParam1, BYTE1(10000)
	ldi toneFreqParam2, BYTE2(10000)
	ldi toneDurParam1, BYTE1(100)
	ldi toneDurParam2, BYTE2(100)
	rcall play_tone
	ret

play_tone:
; before each call of this function set these parameters:
; param: in toneFreqParam2:19 number of loops determing the frequency of the tone (the higher, the lower)
; param: in toneDurParam2:21 number of loops determing the duration of the tone (the higher, the longer)
	sbi PORTD, BUZZ			; turn BUZZer on
	ldi delayParam1, 100			; sets parameter before calling delay_function
	clr delayParam2					; sets parameter before calling delay_function
	clr delayParam3					; sets parameter before calling delay_function
	rcall delay_function	; delay while BUZZer is on
	cbi PORTD, BUZZ			; turn BUZZer of
	mov delayParam1, toneFreqParam1			; sets parameter before calling delay_function				Frage von Vera: warum funktionierte hier nicht movw für [delayParam2:16]<-[toneFreqParam2:19] ???
	mov delayParam2, toneFreqParam2			; sets parameter before calling delay_function
	clr delayParam3					; sets parameter before calling delay_function
	rcall delay_function	; delay while BUZZer is off
	; decrement counter for loop (counting how long the tone is played):
	sez
	clc
	sbci toneDurParam1, 1	
	sbci toneDurParam2, 0
	brne play_tone
	ret

play_success_melody:
	ldi delayParam1, BYTE1(1600000)
	ldi delayParam2, BYTE2(1600000)
	ldi delayParam3, BYTE3(1600000)
	rcall delay_function

	ldi toneFreqParam1, BYTE1(8000)
	ldi toneFreqParam2, BYTE2(8000)
	ldi toneDurParam1, BYTE1(35)
	ldi toneDurParam2, BYTE2(35)
	rcall play_tone
	
	ldi delayParam1, BYTE1(1600 * 20)
	ldi delayParam2, BYTE2(1600 * 20)
	ldi delayParam3, BYTE3(1600 * 20)
	rcall delay_function

	ldi toneFreqParam1, BYTE1(8000)
	ldi toneFreqParam2, BYTE2(8000)
	ldi toneDurParam1, BYTE1(35)
	ldi toneDurParam2, BYTE2(35)
	rcall play_tone
	
	ldi delayParam1, BYTE1(1600 * 10)
	ldi delayParam2, BYTE2(1600 * 10)
	ldi delayParam3, BYTE3(1600 * 10)
	rcall delay_function

	ldi toneFreqParam1, BYTE1(3000)
	ldi toneFreqParam2, BYTE2(3000)
	ldi toneDurParam1, BYTE1(180)
	ldi toneDurParam2, BYTE2(180)
	rcall play_tone
	
	ret

play_failure_melody:
	ldi delayParam1, BYTE1(1600000)
	ldi delayParam2, BYTE2(1600000)
	ldi delayParam3, BYTE3(1600000)
	rcall delay_function

	ldi toneFreqParam1, BYTE1(8000)
	ldi toneFreqParam2, BYTE2(8000)
	ldi toneDurParam1, BYTE1(50)
	ldi toneDurParam2, BYTE2(50)
	rcall play_tone
	
	ldi delayParam1, BYTE1(1600 * 10)
	ldi delayParam2, BYTE2(1600 * 10)
	ldi delayParam3, BYTE3(1600 * 10)
	rcall delay_function

	ldi delayParam1, BYTE1(1600 * 10)
	ldi delayParam2, BYTE2(1600 * 10)
	ldi delayParam3, BYTE3(1600 * 10)
	rcall delay_function

	ldi toneFreqParam1, BYTE1(12000)
	ldi toneFreqParam2, BYTE2(12000)
	ldi toneDurParam1, BYTE1(85)
	ldi toneDurParam2, BYTE2(85)
	rcall play_tone

	ret


LED_blink_once:
	sbi PORTD, LED
	ldi delayParam1, BYTE1(1300000)
	ldi delayParam2, BYTE2(1300000)
	ldi delayParam3, BYTE3(1300000)
	rcall delay_function
	cbi PORTD, LED
	ldi delayParam1, BYTE1(1300000)
	ldi delayParam2, BYTE2(1300000)
	ldi delayParam3, BYTE3(1300000)
	rcall delay_function
	ret

; before each call of this function set this parameter!
; param: in delayParam3:16: number of loops this function makes, to cause a delay
; 1600 loops <=> 1 ms
delay_function:
	nop
	nop
	nop
	sez
	clc
	sbci delayParam1, 1	
	sbci delayParam2, 0
	sbci delayParam3, 0
	brne delay_function
	ret



/*	; play-back the recorded melody
	mov originalMelody, recordedMelody		; set the recorded melody as parameter for the function play_8bit_melody
	rcall play_8bit_melody					
	*/
