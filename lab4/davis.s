@=============================================================================
@ File:    davis.s
@ Class:   CS 413-02
@ Term:    Fall 2026
@ Author:  Aaron Davis
@ Email:   amd0047@uah.edu
@ Date:    October 23, 2026
@
@ Purpose: Simulates a single serve coffee machine like a Keurig and shows
@          the state of the machine on the four LEDs wired to the GPIO.
@
@          The machine starts with a full 48 oz water reservoir.  The user
@          presses B to start a cup or T to turn the machine off, then picks
@          a cup size:
@
@              Small    6 oz
@              Medium   8 oz
@              Large   10 oz
@
@          If there is not enough water left for the size that was picked the
@          program says so and asks for a smaller size.  Otherwise it says it
@          is ready to brew, asks for a cup in the tray, and waits for B to be
@          pressed again before pouring.
@
@          After each cup the water is checked.  Once it drops below 6 oz the
@          machine cannot make even a small cup, so it prints a refill message
@          and shuts off.
@
@          Typing COFFEE at any prompt shows how much water is left and how
@          many cups of each size have been made.  It is not listed in any of
@          the menus, which is what makes it the hidden code.
@
@          The LEDs report what the machine is doing:
@
@              Red      power, on the whole time the program is running
@              Yellow   small coffee brewing    (6 seconds)
@              Green    medium coffee brewing   (8 seconds)
@              Blue     large coffee brewing   (10 seconds)
@
@          Running out of water blinks the red LED three times before the
@          program stops.  Turning the machine off with T just shuts the red
@          LED off.
@
@ Rev  Date         Purpose of change
@ ---  ----         -----------------
@  A   23-Oct-2026  Lab 4.  Added the wiringPi LED status, which is the only
@                   change from Lab 3.  The coffee maker itself behaves the
@                   same way it did before.
@
@ The program writes to the GPIO, so it has to be run as root.  Either run
@ "sudo su" first or put sudo in front of the program.
@
@ Assemble: as -g -o davis.o davis.s
@ Link:     gcc -o davis davis.o -lwiringPi
@ Run:      sudo ./davis
@ Debug:    sudo gdb ./davis
@=============================================================================

@ Machine sizes.  Kept together so they are easy to find and change.
        .equ    RESERVOIR_OZ, 48
        .equ    SMALL_OZ,      6
        .equ    MEDIUM_OZ,     8
        .equ    LARGE_OZ,     10
        .equ    BUFSZ,        64        @ one line of typing

@ wiringPi pin numbers for the LEDs on the lab board.  These are wiringPi
@ numbers, not the numbers printed on the Pi header.
        .equ    RED,           5        @ power
        .equ    YELLOW,        4        @ small
        .equ    GREEN,         3        @ medium
        .equ    BLUE,          2        @ large

@ Values wiringPi expects.
        .equ    OUTPUT,        1        @ pin direction for pinMode
        .equ    ON,            1        @ digitalWrite logic high
        .equ    OFF,           0        @ digitalWrite logic low

@ How long each LED stays lit, in milliseconds.
        .equ    SMALL_MS,   6000
        .equ    MEDIUM_MS,  8000
        .equ    LARGE_MS,  10000
        .equ    BLINK_MS,   5000        @ one half of an out of water blink
        .equ    BLINK_COUNT,   3

        .global main
        .text

@=============================================================================
@ main
@
@   r4 = oz of water left
@   r5 = small cups made
@   r6 = medium cups made
@   r7 = large cups made
@   r8 = size of the cup being ordered right now
@=============================================================================
main:
        push    {r4-r12, lr}            @ 10 registers keeps sp 8 byte aligned

@ Setup wiringPi
        bl      wiringPiSetup
        mvn     r1, #0                  @ -1
        cmp     r0, r1
        bne     ledSetup

        ldr     r0, =gpioErrMsg
        bl      printf
        b       exitProgram

@ Point all four pins at the LEDs and start them dark, then light the red one
@ to show the program is running.
ledSetup:
        mov     r0, #RED
        bl      initLed
        mov     r0, #YELLOW
        bl      initLed
        mov     r0, #GREEN
        bl      initLed
        mov     r0, #BLUE
        bl      initLed

        mov     r0, #RED
        mov     r1, #ON
        bl      digitalWrite

        mov     r4, #RESERVOIR_OZ       @ reservoir starts full
        mov     r5, #0
        mov     r6, #0
        mov     r7, #0

@-----------------------------------------------------------------------------
@ welcomeLoop
@ Where the machine waits between cups.  One pass per key typed.  It loops
@ back instead of falling through so the welcome message is always on the
@ screen when we are asking for input.
@-----------------------------------------------------------------------------
welcomeLoop:
        ldr     r0, =welcomeMsg
        bl      printf

        bl      getCommand              @ r0 = the key that was pressed
        cmp     r0, #0                  @ 0 means the hidden code was typed
        beq     welcomeLoop             @ and already handled

        cmp     r0, #'B'
        beq     sizeLoop
        cmp     r0, #'T'
        beq     machineOff

        ldr     r0, =errWelcomeMsg      @ error check: not B and not T
        bl      printf
        b       welcomeLoop

@-----------------------------------------------------------------------------
@ sizeLoop
@ Asks which size the user wants.
@-----------------------------------------------------------------------------
sizeLoop:
        ldr     r0, =sizeMsg
        bl      printf

        bl      getCommand
        cmp     r0, #0
        beq     sizeLoop

        cmp     r0, #'S'
        beq     pickSmall
        cmp     r0, #'M'
        beq     pickMedium
        cmp     r0, #'L'
        beq     pickLarge
        cmp     r0, #'T'                @ let them quit from here too so they
        beq     machineOff              @ are not stuck at this prompt

        ldr     r0, =errSizeMsg         @ error check: not S, M or L
        bl      printf
        b       sizeLoop

@ Turn the key into a number of ounces.
pickSmall:
        mov     r8, #SMALL_OZ
        b       checkWater

pickMedium:
        mov     r8, #MEDIUM_OZ
        b       checkWater

pickLarge:
        mov     r8, #LARGE_OZ
        b       checkWater

@-----------------------------------------------------------------------------
@ checkWater
@ Make sure the reservoir can cover the size that was ordered.
@-----------------------------------------------------------------------------
checkWater:
        cmp     r4, r8
        blt     notEnough               @ less water left than this cup needs

        ldr     r0, =readyMsg
        bl      printf

@-----------------------------------------------------------------------------
@ brewLoop
@ Wait for B to actually start the brew.  The order is already taken, so
@ nothing in here changes the water level.
@-----------------------------------------------------------------------------
brewLoop:
        bl      getCommand
        cmp     r0, #0
        beq     brewPrompt              @ hidden code pushed our message up

        cmp     r0, #'B'
        beq     dispense
        cmp     r0, #'T'
        beq     machineOff

        ldr     r0, =errBrewMsg         @ error check: the machine is loaded
        bl      printf                  @ and only takes B here
        b       brewLoop

@ Print the start instruction again after the status report scrolled it off
brewPrompt:
        ldr     r0, =pressBrewMsg
        bl      printf
        b       brewLoop

@-----------------------------------------------------------------------------
@ notEnough
@ Not enough water for that size, so say how much is left and go back to the
@ size prompt.
@-----------------------------------------------------------------------------
notEnough:
        ldr     r0, =errWaterMsg
        mov     r1, r4
        bl      printf
        b       sizeLoop

@-----------------------------------------------------------------------------
@ dispense
@ Pour the cup, take the water out of the reservoir and add one to the
@ counter for that size.  Each size lights its own LED for as long as that
@ size takes to brew, so the board shows what is being poured.
@-----------------------------------------------------------------------------
dispense:
        sub     r4, r4, r8

        cmp     r8, #SMALL_OZ
        beq     brewSmall
        cmp     r8, #MEDIUM_OZ
        beq     brewMedium

        add     r7, r7, #1              @ only large is left
        mov     r0, #BLUE
        ldr     r1, =LARGE_MS
        b       runBrew

brewSmall:
        add     r5, r5, #1
        mov     r0, #YELLOW
        ldr     r1, =SMALL_MS
        b       runBrew

brewMedium:
        add     r6, r6, #1
        mov     r0, #GREEN
        ldr     r1, =MEDIUM_MS

@ The message comes after the brew so it shows up when the cup is really
@ poured instead of while the LED is still lit.
runBrew:
        bl      brewLed

        ldr     r0, =dispensedMsg
        bl      printf

        cmp     r4, #SMALL_OZ
        blt     needRefill
        b       welcomeLoop

@ Not enough left for even a small cup, so a person has to refill it.  The
@ red LED blinks on the way out so someone looking at the board instead of
@ the screen can tell the machine quit on its own.
needRefill:
        ldr     r0, =refillMsg
        mov     r1, r4
        bl      printf
        bl      blinkPowerOff
        b       exitProgram

@ Normal power off.  Reached from T or from running out of input.
machineOff:
        ldr     r0, =offMsg
        bl      printf

        mov     r0, #RED
        mov     r1, #OFF
        bl      digitalWrite

exitProgram:
        mov     r0, #0
        pop     {r4-r12, pc}


@=============================================================================
@ Subroutines
@=============================================================================

@-----------------------------------------------------------------------------
@ initLed
@ Points one pin at an LED and makes sure it starts off.
@
@   r0 = wiringPi pin number
@-----------------------------------------------------------------------------
initLed:
        push    {r4, lr}                @ 2 registers keeps sp 8 byte aligned
        mov     r4, r0                  @ pinMode is about to take r0

        mov     r1, #OUTPUT
        bl      pinMode

        mov     r0, r4
        mov     r1, #OFF
        bl      digitalWrite

        pop     {r4, pc}

@-----------------------------------------------------------------------------
@ brewLed
@ Lights one LED for a while and then turns it back off.
@
@   r0 = wiringPi pin number
@   r1 = how many milliseconds to leave it on
@-----------------------------------------------------------------------------
brewLed:
        push    {r4, r5, r6, lr}        @ 4 registers keeps sp 8 byte aligned
        mov     r4, r0                  @ both arguments have to survive the
        mov     r5, r1                  @ calls below

        mov     r1, #ON
        bl      digitalWrite

        mov     r0, r5
        bl      delay

        mov     r0, r4
        mov     r1, #OFF
        bl      digitalWrite

        pop     {r4, r5, r6, pc}

@-----------------------------------------------------------------------------
@ blinkPowerOff
@ Blinks the red LED three times and leaves it off.  Only the out of water
@ shutdown uses this.  The LED is already on when we get here, so each pass
@ goes off first and then back on, and the last thing the subroutine does is
@ turn it off for good.
@
@   r4 = blinks left to do
@-----------------------------------------------------------------------------
blinkPowerOff:
        push    {r4, lr}                @ 2 registers keeps sp 8 byte aligned
        mov     r4, #BLINK_COUNT

@ One off and on pair per pass.
blinkLoop:
        mov     r0, #RED
        mov     r1, #OFF
        bl      digitalWrite
        ldr     r0, =BLINK_MS
        bl      delay

        mov     r0, #RED
        mov     r1, #ON
        bl      digitalWrite
        ldr     r0, =BLINK_MS
        bl      delay

        subs    r4, r4, #1
        bne     blinkLoop

@ Power is off now, so the light goes out and stays out.
        mov     r0, #RED
        mov     r1, #OFF
        bl      digitalWrite

        pop     {r4, pc}

@-----------------------------------------------------------------------------
@ getCommand
@ Reads one line and returns the single key that was typed.
@
@ Every prompt goes through this one subroutine.
@
@ Returns in r0:
@   0           the hidden code was typed, the report is already printed and
@               the caller should just ask again
@   1           more than one character or nothing was typed, which no prompt
@               accepts, so the caller falls through to its own error
@   a character the key that was pressed, in upper case
@
@ Running out of input returns 'T' so the machine shuts off normally instead
@ of looping forever on an empty read.
@-----------------------------------------------------------------------------
getCommand:
        push    {r4, lr}                @ 2 registers keeps sp 8 byte aligned

        ldr     r0, =inBuf              @ fgets(inBuf, BUFSZ, stdin)
        mov     r1, #BUFSZ
        ldr     r2, =stdin
        ldr     r2, [r2]
        bl      fgets
        cmp     r0, #0                  @ NULL means no more input is coming
        beq     gotEndOfInput

        bl      trimAndUpper

        ldr     r0, =inBuf              @ is this the hidden code?
        ldr     r1, =hiddenCode
        bl      strEquals
        cmp     r0, #1
        beq     gotHidden

        ldr     r2, =inBuf
        ldrb    r0, [r2]                @ the key they pressed
        cmp     r0, #0
        beq     gotBadEntry             @ they just hit enter
        ldrb    r1, [r2, #1]            @ a command is one character and then
        cmp     r1, #0                  @ the end of the line
        bne     gotBadEntry

        pop     {r4, pc}

gotHidden:
        bl      showStatus
        mov     r0, #0
        pop     {r4, pc}

gotBadEntry:
        mov     r0, #1
        pop     {r4, pc}

gotEndOfInput:
        mov     r0, #'T'
        pop     {r4, pc}

@-----------------------------------------------------------------------------
@ trimAndUpper
@ Cleans up the line in inBuf.  Cuts off the newline that fgets leaves on the
@ end and changes lower case to upper case, so b and coffee work the same as
@ B and COFFEE.
@
@   r0 = address of inBuf
@   r1 = how far along the line we are
@   r2 = character being looked at
@-----------------------------------------------------------------------------
trimAndUpper:
        ldr     r0, =inBuf
        mov     r1, #0

@ One character per pass.
trimLoop:
        ldrb    r2, [r0, r1]
        cmp     r2, #0                  @ end of the string
        beq     trimDone
        cmp     r2, #10                 @ newline
        beq     trimCut
        cmp     r2, #13                 @ carriage return, in case the input
        beq     trimCut                 @ came from a Windows file

        cmp     r2, #'a'
        blt     trimNext
        cmp     r2, #'z'
        bgt     trimNext
        sub     r2, r2, #32             @ 'a' - 'A' is 32
        strb    r2, [r0, r1]

trimNext:
        add     r1, r1, #1
        b       trimLoop

@ Write a 0 over the line ending so the rest of the program sees a normal
@ string.
trimCut:
        mov     r2, #0
        strb    r2, [r0, r1]

trimDone:
        bx      lr

@-----------------------------------------------------------------------------
@ strEquals
@ Compares two strings that end in 0.
@   r0 = first string
@   r1 = second string
@ Returns r0 = 1 if they match, 0 if they do not.
@
@   r2 = position in both strings
@   r3 and r4 = the two characters being compared
@-----------------------------------------------------------------------------
strEquals:
        push    {r4, lr}
        mov     r2, #0

@ One character from each string per pass.
eqLoop:
        ldrb    r3, [r0, r2]
        ldrb    r4, [r1, r2]
        cmp     r3, r4
        bne     eqNo                    @ characters differ, so no match
        cmp     r3, #0                  @ both ended in the same place, so
        beq     eqYes                   @ the strings are the same
        add     r2, r2, #1
        b       eqLoop

eqYes:
        mov     r0, #1
        pop     {r4, pc}

eqNo:
        mov     r0, #0
        pop     {r4, pc}

@-----------------------------------------------------------------------------
@ showStatus
@ Prints the hidden code report.
@
@ printf only takes 3 values in r1 to r3 and each of these lines has its own
@ label anyway, so it is easier to print one line at a time.  The counters are
@ in r4 to r7, which printf has to leave alone, so they are still good between
@ the calls.
@-----------------------------------------------------------------------------
showStatus:
        push    {r4, lr}

        ldr     r0, =waterMsg
        mov     r1, r4
        bl      printf
        ldr     r0, =smallMsg
        mov     r1, r5
        bl      printf
        ldr     r0, =mediumMsg
        mov     r1, r6
        bl      printf
        ldr     r0, =largeMsg
        mov     r1, r7
        bl      printf

        pop     {r4, pc}


@=============================================================================
@ Data
@ Every string the program prints is down here instead of being built in the
@ code, so the wording can be changed without touching the logic.
@=============================================================================
        .data

@ The hidden code.  It is only ever compared against, never printed, so there
@ is no way to find it from the menus.
hiddenCode:     .asciz  "COFFEE"

welcomeMsg:
        .ascii  "\nWelcome to the Coffee Maker\n\n"
        .ascii  "Insert K-cup and press B to begin making coffee.\n\n"
        .asciz  "Press T to turn off the machine.\n\n> "

sizeMsg:
        .ascii  "\nSelect your cup size:\n"
        .ascii  "  S  Small  (6 oz)\n"
        .ascii  "  M  Medium (8 oz)\n"
        .asciz  "  L  Large  (10 oz)\n\n> "

readyMsg:
        .ascii  "\nReady to Brew\n"
        .ascii  "Place cup in tray\n"
        .asciz  "Press B (and enter) to start brewing.\n\n> "

pressBrewMsg:   .asciz  "\nPress B (and enter) to start brewing.\n\n> "

dispensedMsg:   .asciz  "\nCoffee has been dispensed\n"

@ The hidden code report.
waterMsg:       .asciz  "\nWater level: %d\n"
smallMsg:       .asciz  "Small: %d\n"
mediumMsg:      .asciz  "Medium: %d\n"
largeMsg:       .asciz  "Large: %d\n"

@ Each prompt gets its own error message so the user is told what works where
@ they actually are.
errWelcomeMsg:  .asciz  "\nThat is not a valid choice. Press B to begin or T to turn the machine off.\n"
errSizeMsg:     .asciz  "\nThat is not a valid cup size. Enter S, M or L.\n"
errBrewMsg:     .asciz  "\nThe machine is waiting to brew. Press B to start.\n"
errWaterMsg:    .asciz  "\nThere is not enough water for that size. Only %d oz remain.\nPlease select a smaller cup size.\n"

refillMsg:      .asciz  "\nOnly %d oz of water remain, which is not enough for a small cup.\nPlease refill the reservoir. Turning off the machine.\n\n"
offMsg:         .asciz  "\nTurning off the machine. Goodbye!\n\n"

@ Run the program with sudo if this shows up.  wiringPi cannot open the GPIO
@ without root.
gpioErrMsg:     .asciz  "\nCould not set up the GPIO. Run this program as root.\n\n"

        .balign 4
inBuf:          .space  BUFSZ

@=============================================================================
@ These come from wiringPi.  The program has to be linked with -lwiringPi for
@ them to resolve.
@=============================================================================
        .extern wiringPiSetup
        .extern pinMode
        .extern digitalWrite
        .extern delay
