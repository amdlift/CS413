@ File: BlinkingLED3A.s
@ Author: R. Kevin Preston
@ Purpose: Provide enough assembly to allow students to complete an assignment. 
@          This code turns the four LEDs on then off several times. The LEDs are
@          connected to the GPIO on the Raspberry Pi. The details on the 
@          hardware and GPIO interface are in another document. 
@
@ Rev  Date        Purpose of change
@ ---  ----        -----------------
@  A   3-Mar-2020  Change the way the LEDs blink and document
@                  the colors of the LEDs on the board in the lab. 
@
@ Use these commands to assemble, link and run the program
@   First run the following to get superuser access. 
@   "sudo su" is the command to allow running without having to
@    use sudo. 
@
@  as -o BlinkingLED3A.o BlinkingLED3A.s -g
@  gcc -o BlinkingLED3A BlinkingLED3A.o -lwiringPi
@  ./BlinkingLED3A  !! Have to run under sudo su or proceed with sudo. 
@ 
@ gdb --args ./BlinkingLED3A !! Have to run under "sudo su". 
@
@ Define the constants for this code. 

OUTPUT = 1 @ Used to set the selected GPIO pins to output only. 
ON     = 1 @ Turn the LED on.
OFF    = 0 @ Turn the LED off.

RED    = 5 @ Pin number from wiringPi for red led
YELLOW = 4 @ Pin number from wiringPi for yellow led
GREEN  = 3 @ Pin number from wiringPi for green led
BLUE   = 2 @ Pin number from wiringPi for blue led

.text
.balign 4
.global main 
main:

@ Use the C library to print the hello strings. 
    LDR  r0, =string1 @ Put address of string in r0
    BL   printf       @ Make the call to printf

    LDR  r0, =string1a 
    BL   printf       @ Make the call to printf

@ check the setup of the GPIO to make sure it is working right. 
@ To use the wiringPiSetup function just call it on return:
@    r0 - contains the pass/fail code 

        bl      wiringPiSetup
        mov     r1,#-1
        cmp     r0, r1
        bne     init  @ Everything is OK so continue with code.
        ldr     r0, =ErrMsg
        bl      printf
        b       errorout  @ There is a problem with the GPIO exit code.      

@ set the blue LED mode to output
init:

        ldr     r0, =blue_LED
        ldr     r0, [r0]
        mov     r1, #OUTPUT
        bl      pinMode

@ set the green LED mode to output

        ldr     r0, =green_LED
        ldr     r0, [r0]
        mov     r1, #OUTPUT
        bl      pinMode

@ set the yellow LED mode to output

        ldr     r0, =yellow_LED
        ldr     r0, [r0]
        mov     r1, #OUTPUT
        bl      pinMode

@ set the red LED mode to output

        ldr     r0, =red_LED
        ldr     r0, [r0]
        mov     r1, #OUTPUT
        bl      pinMode
 
@ Turn the LED on/off 5 times. 

        mov     r5, #5
forLoop:
        cmp     r5, #0
        beq     done

@ To use the digialWrite function:
@    r0 - must contain the pin number for the GPIO per the header file info
@    r1 - set to 1 to turn the output on or to 0 to turn the output off.
@
@ Turn all four LEDs on. 
@
@ Write a logic one to turn pin2 to on.

        ldr     r0, =blue_LED
        ldr     r0, [r0]
        mov     r1, #ON
        bl      digitalWrite

@ Run the delay otherwise it blinks so fast you never see it!
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay


@ Write a logic one to turn pin3 to on.

        ldr     r0, =green_LED
        ldr     r0, [r0]
        mov     r1, #ON
        bl      digitalWrite

@ Run the delay otherwise it blinks so fast you never see it!
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay


@ Write a logic one to turn pin4 to on.

        ldr     r0, =yellow_LED
        ldr     r0, [r0]
        mov     r1, #ON
        bl      digitalWrite

@ Run the delay otherwise it blinks so fast you never see it!
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay


@ Write a logic one to turn pin5 to on.

        ldr     r0, =red_LED
        ldr     r0, [r0]
        mov     r1, #ON
        bl      digitalWrite

@ Run the delay otherwise it blinks so fast you never see it!
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay


@ Run the delay otherwise it blinks so fast you never see it!
@ To use the delay function:
@    r0 - must contains the number of miliseconds to delay. 

        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay
@
@ Turn all four LEDs off
@
@ Write a logic 0 to turn pin2 off. 
        ldr     r0, =blue_LED
        ldr     r0, [r0]
        mov     r1, #OFF
        bl      digitalWrite

@ Run the delay otherwise it blinks so fast you never see it!
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay


@ Write a logic 0 to turn pin3 off. 
        ldr     r0, =green_LED
        ldr     r0, [r0]
        mov     r1, #OFF
        bl      digitalWrite

@ Run the delay otherwise it blinks so fast you never see it!
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay


@ Write a logic 0 to turn pin4 off. 
        ldr     r0, =yellow_LED
        ldr     r0, [r0]
        mov     r1, #OFF
        bl      digitalWrite

@ Run the delay otherwise it blinks so fast you never see it!
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay

@ Write a logic 0 to turn pin5 off. 
        ldr     r0, =red_LED
        ldr     r0, [r0]
        mov     r1, #OFF
        bl      digitalWrite

@ Run the delay otherwise it blinks so fast you never see it!
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay

@ Decrement loop.  
        sub     r5, r5, #1
        b       forLoop

@ Exit the for loop
done:

@ Use the C library to print the goodbye string. 
    LDR  r0, =string2 @ Put address of string in r0
    BL   printf       @ Make the call to printf

@ Force the exit of this program and return command to OS
errorout:  @ Label only need if there is an error on board init. 

mov r0, r8
    MOV  r7, #0X01
    SVC  0

.data
.balign 4

@ Define the values for the pins

blue_LED   : .word BLUE
green_LED  : .word GREEN
yellow_LED : .word YELLOW
red_LED    : .word RED

delayMs: .word 1000  @ Set delay for one second. 

.balign 4
string1: .asciz "Raspberry Pi Blinking Light with Assembly. \n"
.balign 4
string1a: .asciz "This blinks the LEDs on the Board.  \n" 
.balign 4
string2: .asciz "The four LEDs should have blinked. \n"
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
