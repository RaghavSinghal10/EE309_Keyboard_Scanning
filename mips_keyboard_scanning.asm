.data

#declaring variables
Cur_St:	     .byte 0x00
Test_Result: .byte 0x00
Key_Code:    .byte 0x7E
Key_Buffer:  .space 16
Key_Index:   .byte 0
PortAddr:    .word 0x40000000

#arrays of tests, actions, and next state
Test_Tab:    .byte 0, 1, 1, 1
Yes_Actions: .byte 1, 2, 0, 0
No_Actions:  .byte 0, 0, 0, 0
Yes_Next:    .byte 1, 2, 2, 2
No_Next:     .byte 0, 0, 3, 0

#jump tables
Test_Jmp:    .word AnyKey, TheKey
Action_Jmp:  .word DoNothing, FindKey, ReportKey
	
.text
.globl main

main:
FSM:
    addi $sp,$sp,-4        # decrement stack pointer
    sw $ra,0($sp)          # save $ra on stack

    jal Do_Test
    nop
    jal Do_Action
    nop
    jal Set_Next
    nop

    lw $ra,0($sp)          # restore $ra
    addi $sp,$sp,4         # adjust stack pointer
    jr $ra                 # return to main program
    nop


Do_Test:
    lbu $t0, Cur_St        # store Cur_St in $t0
    la $t1, Test_Tab       # jump to Test_Tab
    addu $t1, $t1, $t0     # increment t1 aptly
    lbu $t1, ($t1)         # test number for this state
    la $t0, Test_Jmp       # jump table for tests
    sll $t1, $t1, 2        # multiply by 4 since 4 bytes = 1 word
    addu $t1, $t1, $t0     # add adjusted test number to base address
    lw  $t1,($t1)          # load address of test
    jr  $t1               # jump to the selected test
    nop

Do_Action:
    lbu $t0, Test_Result
    la $t1, Yes_Actions
    bgtz $t0, Sel_Action
    nop
    la $t1, No_Actions

    Sel_Action:
    lbu $t0, Cur_St        # store Cur_St in $t0
    addu $t1, $t1, $t0     # increment t1 aptly
    lbu $t1, ($t1)         # action number for this state
    la $t0, Action_Jmp     # jump table for actions
    sll $t1, $t1, 2        # multiply by 4 since 4 bytes = 1 word
    addu $t1, $t1, $t0     # add adjusted action number to base address
    lw  $t1,($t1)          # load address of action
    jr  $t1                # jump to the selected action
    nop


Set_Next:
    lbu $t0, Test_Result
    la $t1, Yes_Next
    bgtz $t0, Sel_Next
    nop
    la $t1, No_Next
	
    Sel_Next:
    lbu $t0, Cur_St        # store Cur_St in $t0
    addu $t1, $t1, $t0     # increment t1 aptly
    lbu $t1, ($t1)         # corresponding next state
    sb $t1, Cur_St         # update Cur_St    
    jr  $ra                # return to FSM
    nop

AnyKey:
    addi $t1, $zero, 0x0F  # set $t1 to 0FH
    sb $t1, PortAddr       # write 0 to all rows and 1 to all columns
    lbu $t1, PortAddr      # read the port
    slti $t2, $t1, 0x0F    # set $t2 as 1 if a key is pressed
    sb $t2, Test_Result    # store $t2 in Test_Result
    jr $ra                 # return to KeyScan
    nop

TheKey:
    addi $t1, $zero, 0x0F  # set $t1 to 0FH
    sb $t1, PortAddr       # write 0 to all rows and 1 to all columns
    lbu $t1, PortAddr      # read the port
    ori $t1, $t1, 0xF0     # write 1 to all rows and write back the read value to the columns
    sb $t1, PortAddr       
    lbu $t1, PortAddr      # get the key code

    lbu $t0, Key_Code      # Store Key_Code in $t0
    bne $t1, $t0, Not_Pressed
    nop
    addi $t2, $zero, 1     # set Test_Result
    sb $t2, Test_Result
    jr $ra                 # return
    nop
    Not_Pressed: 
    addi $t2, $zero, 0     # clear Test_Result
    sb $t2, Test_Result
    jr $ra                 # return
    nop

DoNothing:
    nop	
    jr $ra                 # return
    nop


FindKey:
    addi $t1, $zero, 0x0F  # set $t1 to 0FH
    sb $t1, PortAddr       # write 0 to all rows and 1 to all columns
    lbu $t1, PortAddr      # read the port
    ori $t1, $t1, 0xF0     # write 1 to all rows and write back the read value to the columns
    sb $t1, PortAddr       
    lbu $t1, PortAddr      # get the key code
    sb $t1, Key_Code       # store in Key_Code
    jr $ra                 # return
    nop

ReportKey:
    la $t0, Key_Buffer     # load starting address of circular queue in $t0
    lbu $t1, Key_Index     # load value of index in $t1
    lbu $t2, Key_Code      # load Key_Code in $t2
    addu $t0, $t1, $t0     # point to new address
    sb $t2, ($t0)          # store Key_Code in required address
    addi $t1, $t1, 1       # increment index
    andi $t1, $t1, 15      # reset to 0 if index crosses 15
    sb $t1, Key_Index      # store updated Key_Index
    jr  $ra                # return 
    nop