@ File: ExampleButtons.s
@ Author: R. Kevin Preston
@ Purpose: Provide the assemble code on how to use the four 
@ buttons on the circuit boards in the Hardware Lab. 
@
@ There is not a graceful exit from this code. User must press
@          Ctrl-C to get the unix command prompt back.
@
@ Use these commands to assemble, link and run the program
@
@  as -o ExampleButtons.o ExampleButtons.s
@  gcc -o ExampleButtons ExampleButtons.o -lwiringPi
@  sudo ./ExampleButtons
@ 
@ gdb --args ./ExampleButtons does not work with sudo!
@
@ "sudo su" is the command to allow running without having to
@ use sudo. 
@

/* ----- Data section ------ */

@ Define the following from wiringPi.h header

OUTPUT = 1 
INPUT  = 0  

PUD_UP   = 2  
PUD_DOWN = 1 

LOW  = 0 
HIGH = 1

.text
.balign 4
.global main 
main:

@ Use the C library to print the hello string. 
    LDR  r0, =string1 @ Put address of string in r0
    BL   printf       @ Make the call to printf

    LDR  r0, =string1a @ Put address of string in r0
    BL   printf        @ Make the call to printf

    LDR  r0, =stringPressAny
    BL   printf

@ Check the setup of the GPIO to make sure it is working right. 

        bl      wiringPiSetup
        mov     r1,#-1
        cmp     r0, r1
        bne     init        @Board is good so continue 
        ldr     r0, =ErrMsg @If it is not working print error
                            @ message then exit.
        bl      printf
        b       done  

@ set the mode to input-BLUE
init:

        ldr     r0, =buttonBlue
        ldr     r0, [r0]
        mov     r1, #INPUT
        bl      pinMode

@ set the mode to input - GREEN

        ldr     r0, =buttonGreen
        ldr     r0, [r0]
        mov     r1, #INPUT
        bl      pinMode

@ set the mode to input- YELLOW

        ldr     r0, =buttonYellow
        ldr     r0, [r0]
        mov     r1, #INPUT
        bl      pinMode

@ set the mode to input - RED

        ldr     r0, =buttonRed
        ldr     r0, [r0]
        mov     r1, #INPUT
        bl      pinMode

 
@ Setup and read all the buttons. 
@ Set the buttons for pull-up and it is 0 when pressed. 
@    pullUpDnControl(buttonPin, PUD_UP)
@    digitalRead(buttonPin) == LOW button pressed
@
    ldr  r0, =buttonBlue
    ldr  r0, [r0]
    mov  r1, #PUD_UP
    BL   pullUpDnControl 

    ldr  r0, =buttonGreen
    ldr  r0, [r0]
    mov  r1, #PUD_UP
    BL   pullUpDnControl 

    ldr  r0, =buttonYellow
    ldr  r0, [r0]
    mov  r1, #PUD_UP
    BL   pullUpDnControl 

    ldr  r0, =buttonRed
    ldr  r0, [r0]
    mov  r1, #PUD_UP
    BL   pullUpDnControl 

@
@  Set the registers to debounce switches and handle buttons 
@  held down,.
@
    mov r8,  #0xff 
    mov r9,  #0xff
    mov r10, #0xff    
    mov r11, #0xff 


@ Start the loop to read all the buttons. 

ButtonLoop:

@ Delay a few miliseconds to help debounce the switches. 
@
    ldr  r0, =delayMs
    ldr  r0, [r0]
    BL   delay

ReadBLUE:
@ Read the value of the blue button. If it is HIGH (i.e., not
@ pressed) read the next button and set the previous reading
@ value to HIGH. 
@ Otherwise the current value is LOW (pressed). If it was LOW
@ that last time the button is still pressed down. Do not record
@ this as a new pressing.
@ If it was HIGH the last time and LOW now then record the 
@ button has been pressed.
@
    ldr    r0,  =buttonBlue
    ldr    r0,  [r0]
    BL     digitalRead 
    cmp    r0, #HIGH   @ Button is HIGH read next button
    moveq  r9, r0      @ Set last time read value to HIGH 
    beq    ReadGREEN

    @ The button value is LOW.
    @ If it was LOW the last time it is still down. 
    cmp    r9, #LOW    @ was the last time it was called also
                       @ down?
    beq    ReadGREEN   @ button is still down read next button
                       @ value. 
     
    mov    r9, r0  @ This is a new button press. 
    b      PedBLUE @ Branch to print the blue button was pressed. 

ReadGREEN:
@ See comments on BLUE button on how this code works. 
@
    ldr    r0,  =buttonGreen
    ldr    r0,  [r0]
    BL     digitalRead  
    cmp    r0, #HIGH
    moveq  r10, r0
    beq    ReadYELLOW   

    cmp    r10, #LOW
    beq    ReadYELLOW  

    mov    r10, r0
    b      PedGREEN 

ReadYELLOW:
@ See comments on BLUE button on how this code works. 
@
    ldr    r0,  =buttonYellow
    ldr    r0,  [r0]
    BL     digitalRead 
    cmp    r0, #HIGH
    moveq  r11, r0
    beq    ReadRED 
 
    cmp    r11, #LOW
    beq    ReadRED

    mov    r11, r0
    b      PedYELLOW 

ReadRED:
@ See comments on BLUE button on how this code works. 
@
    ldr    r0,  =buttonRed
    ldr    r0,  [r0]
    BL     digitalRead 
    cmp    r0, #HIGH
    moveq  r8, r0
    beq    ButtonLoop
 
    cmp    r8, #LOW
    beq    ButtonLoop
 
    mov    r8, r0
    b      PedRED

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Print out which button was pressed.
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

PedBLUE:
    LDR  r0, =PressedBLUE @ Put address of string in r0
    BL   printf           @ Make the call to printf
    B    ButtonLoop       @ Go read more buttons


PedGREEN:
    LDR  r0, =PressedGREEN @ Put address of string in r0
    BL   printf            @ Make the call to printf
    B    ButtonLoop        @ Go read more buttons

PedYELLOW:
    LDR  r0, =PressedYELLOW @ Put address of string in r0
    BL   printf             @ Make the call to printf
    B    ButtonLoop         @ Go read more buttons

PedRED:
    LDR  r0, =PressedRED  @ Put address of string in r0
    BL   printf           @ Make the call to printf
    B    ButtonLoop       @ Go read more buttons

done:

@ Use the C library to print the goodbye string. 
    LDR  r0, =string2 @ Put address of string in r0
    BL   printf       @ Make the call to printf

@ Force the exit of this program and return command to OS

mov r0, r8
    MOV  r7, #0X01
    SVC  0

.data
.balign 4

buttonBlue:   .word 7 @Blue button
buttonGreen:  .word 0 @Green button
buttonYellow: .word 6 @Yellow button
buttonRed:    .word 1 @Red button

delayMs: .word 250  @ Delay time in Miliseconds.

.balign 4
string1: .asciz "Raspberry Pi Button Example with Assembly. \n"
.balign 4
string1a: .asciz "Circuit Board Example. \n" 
.balign 4
stringPressAny: .asciz "Press any of the buttons (Blue, Green, Yellow, or Red. \n"
.balign 4
string2: .asciz "Hardware error in GPIO see GTA. \n"

.balign 4
PressedBLUE: .asciz "The BLUE button was pressed. \n"
.balign 4
PressedYELLOW: .asciz "The YELLOW button was pressed.\n"
.balign 4
PressedGREEN: .asciz "The GREEN button was pressed. \n"
.balign 4
PressedRED:  .asciz "The RED button was pressed. \n"
.balign 4 
ErrMsg: .asciz "Setup didn't work... Aborting...\n"

.global printf

@
@  The following are defined in wiringPi.h
@
.extern wiringPiSetup 
.extern delay
.extern digitalWrite
.extern pinMode

@end of code and end of file. Leave a blank line after this
