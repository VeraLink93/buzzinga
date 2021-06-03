; 
; buzzinga.asm
; Created: 15.05.2021 14:31:24
; Authors : Hannah, Sarah, Vera

 
.equ BUZZ = 2
.equ LED = 5
.equ BUTTON0 = 3
.equ BUTTON1 = 4
.equ SWITCH = 6

.equ MELODY_LENGTH = 8

.def temp0 = r24
.def temp1 = r25
.def recordedMelody = r27
.def originalMelody = r28	; to be loaded from SRAM

.def delayParam1 = r16		; parmeter for delay_function, defining the loops that cause a delay (1600 <=> 1ms)
.def delayParam2 = r17		; parmeter for delay_function, defining the loops that cause a delay (1600 <=> 1ms)
.def delayParam3 = r18		; parmeter for delay_function, defining the loops that cause a delay (1600 <=> 1ms)
.def toneFreqParam1 = r19	; parameter for play_tone function, defining the frequency of the tone (higher value -> deeper tone)
.def toneFreqParam2 = r20	; parameter for play_tone function, defining the frequency of the tone (higher value -> deeper tone)
.def toneDurParam1 = r21	; parameter for play_tone function, defining the duration of the tone (higher value + higher freq_params -> longer tone)
.def toneDurParam2 = r22	; parameter for play_tone function, defining the duration of the tone (higher value + higher freq_params -> longer tone)
.def numberOfTones = r23	; used for loop variable in play_8bit_melody and in recording phase

	sbi DDRD, BUZZ
	sbi DDRD, LED

melodies: 
	.DB 0b01010101, 0b11110000, 0

wait_until_turned_on:
	sbis PIND, SWITCH	
	rjmp wait_until_turned_on
	rcall play_dummy_hello_melody	 
	
pointer_init:
	ldi ZH, HIGH(melodies<<1)
	ldi ZL, LOW(melodies<<1)

main_loop:
	rcall check_if_turned_off
	;LED blinks twice to indicate that a melody will be played
	rcall LED_blink_once
	rcall LED_blink_once
	rcall check_if_turned_off

	; Phase 1: play original melody
	lpm originalMelody, Z
	tst originalMelody				;test if the last level was alredy played. (End of .db entry is 0)
	breq finished_game
	
	; pause 1 sec for game flow purpose
	ldi delayParam1, BYTE1(1600*1000)
	ldi delayParam2, BYTE2(1600*1000)
	ldi delayParam3, BYTE3(1600*1000)
	rcall delay_function

	mov temp0, originalMelody
	rcall play_8bit_melody

	; Phase 2: record play-back
	ldi recordedMelody, 0b00000000		;optional?
	clr numberOfTones
	sbi PORTD, LED						;turn LED on to signalize that recording phase has started

	;as long as melody is long, check for input (buttons)
	while_melody:
		;check for buttons while (numberOfTones < numberOfBitsInRegister)
		rcall check_if_input_is_valid
		rcall set01_in_register_and_play_tone
		inc numberOfTones
		cpi numberOfTones, MELODY_LENGTH
		brlt while_melody
	cbi PORTD, LED						;turn LED off to signalize that recording phase has ended

	; Phase 3: compare melodies
	cp originalMelody, recordedMelody
	breq was_success
	rjmp was_failure

was_success:
	rcall play_success_melody
	adiw Z, 1					; increment Pointer so that in next round a new melody is loaded
	rjmp main_loop

was_failure:
    rcall play_failure_melody
	rjmp main_loop

finished_game:
	rcall play_success_melody
	rcall play_success_melody
	rcall play_success_melody
	wait_for_restart:
		rcall check_if_turned_off
		rjmp wait_for_restart

check_if_turned_off:
	sbic PIND, SWITCH
	ret								; returns if switch is still on 
	cbi PORTD, LED					; turn LED off it device was turned off in the middle of the recording phase
	rcall play_dummy_good_night_melody
	rjmp wait_until_turned_on
	
play_8bit_melody:
; uses numberOfTones for looping
; before calling move melody that shall be played to temp0 (because register temp0 is cleared afterwards)
	ldi numberOfTones, MELODY_LENGTH	; initialize loop counter to 8
	loop_8bit:
		rcall check_if_turned_off
		sbrc temp0, 0				; skip if last bit of melody is 0
		rcall play_one_high_tone	; otherwise play one high tone
		sbrs temp0, 0				; skip if last bit of melody is 1
		rcall play_one_deep_tone	; otherwise play one deep tone
		; set parameters before calling the delay_function for a break after the played tone
		ldi delayParam1, BYTE1(320000)
		ldi delayParam2, BYTE2(320000)
		ldi delayParam3, BYTE3(320000)
		rcall delay_function
		lsr temp0					; shift right, so that in the next loop the next tone is played
		dec numberOfTones			; decrement loop counter (from 8 to 0)
		brne loop_8bit
	; set parameters before calling the delay_function for a break after the played melody
	ldi delayParam1, BYTE1(1500000)
	ldi delayParam2, BYTE2(1500000)
	ldi delayParam3, BYTE3(1500000)
	rcall delay_function
	ret

check_if_input_is_valid:
	;check if/ which buttons are pressed
	rcall check_if_turned_off
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
	lsr recordedMelody
	sbr recordedMelody , 0b10000000
	rcall play_one_high_tone
	ret

	deep_Tone:
	lsr recordedMelody
	rcall play_one_deep_tone
	ret

play_dummy_hello_melody:
; just temporarily written for debuggin purpose, to be replaced with nicer melody
	ldi delayParam1, BYTE1(1600000)
	ldi delayParam2, BYTE2(1600000)
	ldi delayParam3, BYTE3(1600000)
	rcall delay_function
	ldi toneFreqParam1, BYTE1(8000)
	ldi toneFreqParam2, BYTE2(8000)
	ldi toneDurParam1, BYTE1(35)
	ldi toneDurParam2, BYTE2(35)
	rcall play_tone
	ldi toneFreqParam1, BYTE1(7000)
	ldi toneFreqParam2, BYTE2(7000)
	ldi toneDurParam1, BYTE1(35)
	ldi toneDurParam2, BYTE2(35)
	rcall play_tone
	ret

play_dummy_good_night_melody:
; just temporarily written for debuggin purpose, to be replaced with nicer melody
	ldi delayParam1, BYTE1(1600000)
	ldi delayParam2, BYTE2(1600000)
	ldi delayParam3, BYTE3(1600000)
	rcall delay_function
	ldi toneFreqParam1, BYTE1(7000)
	ldi toneFreqParam2, BYTE2(7000)
	ldi toneDurParam1, BYTE1(35)
	ldi toneDurParam2, BYTE2(35)
	rcall play_tone
	ldi toneFreqParam1, BYTE1(8000)
	ldi toneFreqParam2, BYTE2(8000)
	ldi toneDurParam1, BYTE1(35)
	ldi toneDurParam2, BYTE2(35)
	rcall play_tone
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
; before each call of this function set the parameters for toneFreqParam 1+2 and toneDurParam 1+2
	sbi PORTD, BUZZ			; turn BUZZer on
	ldi delayParam1, 100	; sets parameter before calling delay_function
	clr delayParam2			; sets parameter before calling delay_function
	clr delayParam3			; sets parameter before calling delay_function
	rcall delay_function	; delay while BUZZer is on
	cbi PORTD, BUZZ			; turn BUZZer of
	mov delayParam1, toneFreqParam1			; sets parameter before calling delay_function
	mov delayParam2, toneFreqParam2			; sets parameter before calling delay_function
	clr delayParam3			; sets parameter before calling delay_function
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

; before each call of this function set delayParam 1-3
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