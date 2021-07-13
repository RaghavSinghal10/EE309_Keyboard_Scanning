; Assume a 24 MHZ crystal
; Counts for a 25 ms delay are:
TH0COUNT EQU 3CH
TL0COUNT EQU 0B0H
KEY_INDEX EQU 44H	    ; Location to store input index of circular buffer
CUR_ST EQU 40H          ; Location where current state will be stored:
PressedKey EQU 41H      ; Location key code for the pressed key will be stored here
						; F0 in PSW will be used to store the answer from tests

org 0000H
ljmp Init
org 000bh               ; T0 interrupt vector
LJMP T0_INTR            ; Jump to interrupt handler

org 0030H	
T0_INTR: 
CLR TR0        			; Stop the timer
MOV TH0, #TH0COUNT      ; Re-load counts for 25 ms delay
MOV TL0, #TL0COUNT
SETB TR0                ; Restart T0
SETB ET0                ; Re-enable interrupts from T0
LJMP FSM                ; Now manage the FSM

ORG 0080H
FSM: 
PUSH ACC
PUSH PSW
PUSH DPH
PUSH DPL
 
ACALL DO_TEST           ; Peform the test for this state
ACALL DO_ACTION         ; Perform the action based on test answer
ACALL SET_NEXT          ; Set current state = next state
						; and return, cleaning up as we go
POP DPL
POP DPH
POP PSW
POP ACC
RETI

DO_TEST:
MOV A, CUR_ST           ; Fetch the current state
MOV DPTR, #Test_Tab     ; Table of test numbers
MOVC A, @A + DPTR       ; Get the test number for this state
MOV DPTR, #Test_Jmp     ; Jump table for tests
ADD A, ACC              ; A = 2A: each entry is 2 bytes
jmp @A + DPTR           ; Jump to the selected test
						; Note that selected test will do ret.

DO_ACTION:
MOV DPTR, #Yes_Actions
JB F0, Sel_Action       ; If test answer = yes, DPTR is correct
MOV DPTR, #No_Actions   ; If Test returned no, modify DPTR
Sel_Action:             ; Now look up the action to be taken
MOV A, CUR_ST           ; Fetch the current state
MOVC A, @A+DPTR       ; and look up the action number
MOV DPTR, #Action_jmp   ; Jump table for actions
ADD A, ACC              ; A = 2A : offset in Action jump table
						; because each entry is 2 bytes
JMP @A + DPTR           ; Jump to the selected action
						; Note that the select action will do ret
                                            
SET_NEXT:
MOV DPTR, #Yes_Next     ; Array of next states for yes answer
JB F0, Sel_Next         ; If answer was yes, DPTR is correct
MOV DPTR, #No_Next  	; Else correct the DPTR to no answer
Sel_Next:
MOV A, CUR_ST           ; get the current state
MOVC A, @A+DPTR         ; get the next state
MOV CUR_ST, A           ; and save it as current state
RET 

Test_Tab:    DB 0, 1, 1, 1
Yes_Actions: DB 1, 2, 0, 0
No_Actions:  DB 0, 0, 0, 0
Yes_Next:    DB 1, 2, 2, 2
No_Next:     DB 0, 0, 3, 0
	
Test_Jmp:
AJMP AnyKey
AJMP TheKey

Action_Jmp:
AJMP DoNothing
AJMP FindKey
AJMP ReportKey

AnyKey:
MOV P0, #0FH             ; write 0 to all rows and 1 to all columns 
MOV A, P0                ; read the port
CJNE A, #0FH, KEY_PRESSED; if read value != 0F, then key has been pressed
CLR F0
AJMP FIN1
KEY_PRESSED: SETB F0
FIN1: RET

TheKey:
MOV P0, #0FH             ; write 0 to all rows and 1 to all columns
MOV A, P0                ; read the port
ORL A, #0F0H             ; write 1 to all rows and write back the read value to the columns
MOV P0, A
MOV A, P0                ; get the key code
CJNE A, PressedKey, THE_KEY_NOT_PRESSED
SETB F0
AJMP FIN2
THE_KEY_NOT_PRESSED: CLR F0
FIN2: RET

DoNothing:
RET

FindKey:
MOV P0, #0FH             ; write 0 to all rows and 1 to all columns
MOV A, P0                ; read the port
ORL A, #0F0H             ; write 1 to all rows and write back the read value to the columns
MOV P0, A
MOV A, P0
MOV PressedKey, A        ; store key code in PressedKey
RET

ReportKey:
SETB RS0                 ; activate register bank 1
CLR RS1
MOV A, #50H              ; initialise to starting of circular buffer
ADD A, KEY_INDEX         ; add index value
MOV R0, A                ; move to an indirectly addressable register
MOV @R0, PressedKey      ; move value of PressedKey to the address pointed by R0
INC KEY_INDEX            ; increment index
ANL KEY_INDEX, #07H      ; reset if crosses 7H
RET
  
ORG 0100H
Init:
MOV SP, #77H             ; SP to top of 8051 memory
MOV CUR_ST, #00H         ; Initialize current state to Idle
MOV KEY_INDEX, #00H      ; initialize input index of circular buffer to 0
CLR TR0 				 ; Stop the timer (if running)
MOV TH0, #TH0COUNT       ; Load T0 counts for 25 ms delay
MOV TL0, #TL0COUNT
SETB ET0                 ; Enable interrupts from T0
SETB EA                  ; Enable interrupts globally
SETB TR0                 ; Start T0 timer
LJMP T0_INTR			 ; place a jump to ISR here for testing purposes

L1: sjmp L1
END