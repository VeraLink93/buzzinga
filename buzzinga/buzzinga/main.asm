; 
; buzzinga.asm
; Created: 15.05.2021 14:31:24
; Authors : Hannah Seuring, Sarah Traore, Vera Link

 
.equ BUZZ = 2
.equ BUTTON0 = 3			; produces deep tone
.equ BUTTON1 = 4			; procuces high tone
.equ LED = 5				; LEDs shows the different phases of the game: blinking twice before playing original melody, stays on during recording phase
.equ SWITCH = 6				; used to turn the device on and off

.equ MELODY_LENGTH = 8		; the melodies (both original and recorded) are of length 8
.equ TIME = 30				; use this constant to change the time limit a player has to push a button (30: approx. 2s)

.def temp0 = r24
.def timeParam1 = r25		; parameter for time_limit function, defining the time a player has to  press a button
.def timeParam2 = r26		; parameter for time_limit function, defining the time a player has to  press a button
.def recordedMelody = r27	; stores the melody that the player recorded
.def originalMelody = r28	; stores the current melodies that the player needs to play back. Is to be loaded from SRAM each new round

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
	.DB 0b10101010, 0b11101110, 0b01010100, 0b11110101, 0b01001011, 0b10111001, 0b00101101, 0

; Loops as long as switch is turned off. 
; If turned on continue and play welcoming melody.
wait_until_turned_on:
	sbis PIND, SWITCH	
	rjmp wait_until_turned_on
	rcall power_on_melody	 

; Initialize pointer to the melodies
pointer_init:
	ldi ZH, HIGH(melodies<<1)
	ldi ZL, LOW(melodies<<1)

; Goes through 3 stages: playing the original melody, recording of the play-back, comparing both melodies
game_loop:
	; STAGE 1: play original melody
	rcall check_if_turned_off		
	;LED blinks twice to indicate that a melody will be played
	rcall LED_blink_once
	rcall LED_blink_once
	rcall check_if_turned_off

	lpm originalMelody, Z		; load current melody from SRAM
	tst originalMelody			; test if the last level was alredy played. (End of .db entry is 0)
	breq finished_game
	
	; pause 1 sec for game flow purpose
	ldi delayParam1, BYTE1(1600*1000)
	ldi delayParam2, BYTE2(1600*1000)
	ldi delayParam3, BYTE3(1600*1000)
	rcall delay_function

	; play the origional melody
	mov temp0, originalMelody
	rcall play_8bit_melody

	; STAGE 2: record play-back
	clr numberOfTones			; works as loop counter, checking how many tones are already recorded
	sbi PORTD, LED				; turn LED on to signalize that recording phase has started
	rcall timer_reset			; resets the counter for the timer that limits the time the player has for recording a tone

	; as long as not all 8 tones are recorded, check for input (buttons)
	; if button0 is pressed, set 0 to recordedMelody and play a deep tone
	; if button1 is pressed, set 1 to recordedMelody and play a high tone
	listen_to_buttons:	
		rcall check_if_turned_off						
		rcall time_limit

		sbic PIND, BUTTON0						;skip if button0 is not pressed
		rcall set0_in_register_and_play_tone	
		sbic PIND, BUTTON1						;skip if button1 is not pressed	
		rcall set1_in_register_and_play_tone
		
		cpi numberOfTones, MELODY_LENGTH		;checks if 8 tones were already recorded
		brlt listen_to_buttons					;if not repeat

	cbi PORTD, LED						;turn LED off to signalize that recording phase has ended

	; pause 1 sec for game flow purpose
	ldi delayParam1, BYTE1(1600000)
	ldi delayParam2, BYTE2(1600000)
	ldi delayParam3, BYTE3(1600000)
	rcall delay_function

	; STAGE 3: compare melodies
	cp originalMelody, recordedMelody
	breq was_success					; if melodies are equal
	rjmp was_failure					; if melodies are not equal

; jumps here if the melody was recorded correctly
was_success:
	rcall play_success_melody
	adiw Z, 1					; increment Pointer so that in next round a new melody is loaded
	rjmp game_loop				; start next round

; jumps here if the melody was not recorded correctly or the time for recording a tone is up
was_failure:
    rcall play_failure_melody
	rjmp game_loop				; repeat this round

; jumps here if all 7 melodies are played back correctly
; if device is turned of jump back to the very beginning of the code
finished_game:
	rcall play_success_melody
	rcall play_success_melody
	rcall play_success_melody
	wait_for_restart:
		rcall check_if_turned_off
		rjmp wait_for_restart

; checks if the switch was turned off.
; if so play a melody to say byebye and jump back to the beginning of the game.
; call this subroutine in different parts of the code so that the game can be interrupted any time.
check_if_turned_off:
	sbic PIND, SWITCH
	ret								; returns if switch is still on (nothing happens) 
	cbi PORTD, LED					; otherwise turn LED off if device was turned off in the middle of the recording phase
	rcall power_off_melody			; buzzer says byebye
	rjmp wait_until_turned_on		; jump back to the beginning of the code

; before calling store melody that shall be played in temp0 (because register temp0 is cleared afterwards)	
play_8bit_melody:
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

; is called when the player pressed button0 in recording stage.
; the current tone is always set at the most significant bit.
; shifts each time so that the first recorded tone is the least siginificant bit at the end of the recording.
set0_in_register_and_play_tone:
	lsr recordedMelody
	rcall play_one_deep_tone
	inc numberOfTones
	
	; before the next tone can be recorded, wait for button0 to be released. 
	; prevents that the player records several tones accidentally
	button0_release:
		rcall check_if_turned_off
		sbic PIND, BUTTON0
		rjmp button0_release
	
	rcall timer_reset		; resets the counter for the timer that limits the time the player has for recording a tone
	ret

; is called when the player pressed button1 in recording stage
; the current tone is always set at the most significant bit.
; shifts each time so that the first recorded tone is the least siginificant bit at the end of the recording.
set1_in_register_and_play_tone:
	lsr recordedMelody
	sbr recordedMelody , 0b10000000
	rcall play_one_high_tone
	inc numberOfTones

	; before the next tone can be recorded, wait for button1 to be released. 
	; prevents that the player records several tones accidentally
	button1_release:
		rcall check_if_turned_off						
		sbic PIND, BUTTON1
		rjmp button1_release
	
	rcall timer_reset		; resets the counter for the timer that limits the time the player has for recording a tone
	ret

; resets the parameters used by the time_limit subroutine
timer_reset:
	ldi timeParam1,	255 
	ldi timeParam2,	255					
	ldi temp0, 0
	ret

; functions as timer: a player has approximately 2s to push a button in the recording stage
; called at the beginning of each loop pass of listen_to_buttons to check if time is up
; if no button was pushed, jump to was_failure (start over with same melody)
; number of runs of time_limit before time runs out: (255+254)*29 -> 14 761  
;	 -> ((timeParam1 + (timeParam2-1)) * (TIME-1)
time_limit:
	dec timeParam1
	tst timeParam1
	breq dec_time_Param2
	cpi temp0, TIME				
	breq was_failure
	ret

	dec_time_Param2:
		dec timeParam2
		tst timeParam2
		breq inc_counter
		ret

		inc_counter:
			inc temp0
			ldi timeParam1, 255
			ldi timeParam2, 255
			ret	


; produces sound on the buzzer
; before each call of this subroutine set the parameters for toneFreqParam 1+2 and toneDurParam 1+2
play_tone:
	sbi PORTD, BUZZ			; turn buzzer on
	ldi delayParam1, 100	; sets parameter before calling delay_function
	clr delayParam2			; sets parameter before calling delay_function
	clr delayParam3			; sets parameter before calling delay_function
	rcall delay_function	; delay while buzzer is on
	cbi PORTD, BUZZ			; turn buzzer off
	mov delayParam1, toneFreqParam1			; sets parameter before calling delay_function
	mov delayParam2, toneFreqParam2			; sets parameter before calling delay_function
	clr delayParam3			; sets parameter before calling delay_function
	rcall delay_function	; delay while BUZZer is off
	; decrement the paramenters responsible for the durcation of the tone
	sez
	clc
	sbci toneDurParam1, 1	
	sbci toneDurParam2, 0
	brne play_tone				; if parameters didnt reach zero continue playing the tone
	ret

; used for the original and recorded melodies
play_one_high_tone:
	ldi toneFreqParam1, BYTE1(5000)
	ldi toneFreqParam2, BYTE2(5000)
	ldi toneDurParam1, BYTE1(170)
	ldi toneDurParam2, BYTE2(170)
	rcall play_tone
	ret

; used for the original and recorded melodies
play_one_deep_tone:
	ldi toneFreqParam1, BYTE1(10000)
	ldi toneFreqParam2, BYTE2(10000)
	ldi toneDurParam1, BYTE1(100)
	ldi toneDurParam2, BYTE2(100)
	rcall play_tone
	ret

; melody played to welcome the player when device is turned on
power_on_melody: 
    ldi delayParam1, BYTE1(1600000)
	ldi delayParam2, BYTE2(1600000)
	ldi delayParam3, BYTE3(1600000)
	rcall delay_function

	ldi toneFreqParam1, BYTE1(5230)
	ldi toneFreqParam2, BYTE2(5230)
	ldi toneDurParam1, BYTE1(95)
	ldi toneDurParam2, BYTE2(95)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(3920)
	ldi toneFreqParam2, BYTE2(3920)
	ldi toneDurParam1, BYTE1(127)
	ldi toneDurParam2, BYTE2(127)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(3300)
	ldi toneFreqParam2, BYTE2(3300)
	ldi toneDurParam1, BYTE1(151)
	ldi toneDurParam2, BYTE2(151)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(4400)
	ldi toneFreqParam2, BYTE2(4400)
	ldi toneDurParam1, BYTE1(113)
	ldi toneDurParam2, BYTE2(113)
	rcall play_tone
	
	ldi toneFreqParam1, BYTE1(4940)
	ldi toneFreqParam2, BYTE2(4940)
	ldi toneDurParam1, BYTE1(101)
	ldi toneDurParam2, BYTE2(101)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(4400)
	ldi toneFreqParam2, BYTE2(4400)
	ldi toneDurParam1, BYTE1(113)
	ldi toneDurParam2, BYTE2(113)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(3920)
	ldi toneFreqParam2, BYTE2(3920)
	ldi toneDurParam1, BYTE1(127)
	ldi toneDurParam2, BYTE2(127)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(4400)
	ldi toneFreqParam2, BYTE2(4400)
	ldi toneDurParam1, BYTE1(113)
	ldi toneDurParam2, BYTE2(113)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(3920)
	ldi toneFreqParam2, BYTE2(3920)
	ldi toneDurParam1, BYTE1(127)
	ldi toneDurParam2, BYTE2(127)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(3920)
	ldi toneFreqParam2, BYTE2(3920)
	ldi toneDurParam1, BYTE1(127)
	ldi toneDurParam2, BYTE2(127)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(2940)
	ldi toneFreqParam2, BYTE2(2940)
	ldi toneDurParam1, BYTE1(170)
	ldi toneDurParam2, BYTE2(170)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(3300)
	ldi toneFreqParam2, BYTE2(3300)
	ldi toneDurParam1, BYTE1(151)
	ldi toneDurParam2, BYTE2(151)
	rcall play_tone

	ret

; melody played to say goodbye to the player when device is turned off
power_off_melody:
	ldi toneFreqParam1, BYTE1(15000)
	ldi toneFreqParam2, BYTE2(15000)
	ldi toneDurParam1, BYTE1(30)
	ldi toneDurParam2, BYTE2(30)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(10000)
	ldi toneFreqParam2, BYTE2(10000)
	ldi toneDurParam1, BYTE1(30)
	ldi toneDurParam2, BYTE2(30)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(5000)
	ldi toneFreqParam2, BYTE2(5000)
	ldi toneDurParam1, BYTE1(30)
	ldi toneDurParam2, BYTE2(30)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(5000)
	ldi toneFreqParam2, BYTE2(5000)
	ldi toneDurParam1, BYTE1(30)
	ldi toneDurParam2, BYTE2(30)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(10000)
	ldi toneFreqParam2, BYTE2(10000)
	ldi toneDurParam1, BYTE1(30)
	ldi toneDurParam2, BYTE2(30)
	rcall play_tone

	ldi toneFreqParam1, BYTE1(15000)
	ldi toneFreqParam2, BYTE2(15000)
	ldi toneDurParam1, BYTE1(30)
	ldi toneDurParam2, BYTE2(30)
	rcall play_tone

	ret

; melody played to indicate that the player recorded the melody correctly.
; also called three times in a row then the player succeeded the whole game.
play_success_melody:
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

; melody played to indicate that the player failed to record the melody correctly or crossed the time limit
play_failure_melody:
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

; used to signalize the player that a new stage has begun
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