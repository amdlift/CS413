@=============================================================================
@ File:    davis.s
@ Class:   CS 413-02
@ Term:    Fall 2026
@ Author:  Aaron Davis
@ Email:   amd0047@uah.edu
@ Date:    November 6, 2026
@
@ Purpose: Simulates a single serve coffee machine like a Keurig.  The four
@          buttons wired to the GPIO run the machine and the four LEDs show
@          what it is doing.
@
@              Button   Function              LED
@              ------   --------              ---
@              Red      power on and off      power
@              Yellow   small coffee, 6 oz    on while it brews, 6 seconds
@              Green    medium coffee, 8 oz   on while it brews, 8 seconds
@              Blue     large coffee, 10 oz   on while it brews, 10 seconds
@
@          The machine starts with a full 48 oz reservoir and the power off.
@          Pressing red turns it on and lights the red LED.  Pressing red
@          again turns the light off and stops the program.
@
@          If there is not enough water for the size that was picked the
@          program says so and waits for a smaller size.  Once the water
@          drops below 6 oz the machine cannot make even a small cup, so it
@          prints a refill message, blinks the red LED three times and stops.
@
@          Pressing yellow and green at the same time shows how much water is
@          left and how many cups of each size have been made.  No menu
@          mentions it, which is what makes it the hidden code.
@
@ Rev  Date         Purpose of change
@ ---  ----         -----------------
@  A   23-Oct-2026  Lab 4.  Added the wiringPi LED status, which is the only
@                   change from Lab 3.
@  B   06-Nov-2026  Lab 5.  The buttons took the place of the keyboard.  The
@                   prompts and the hidden code changed with them and nothing
@                   else did.
@
@ The program reads and writes the GPIO, so it has to be run as root.  Either
@ run "sudo su" first or put sudo in front of the program.
@
@ Assemble: as -g -o davis.o davis.s
@ Link:     gcc -o davis davis.o -lwiringPi
@ Run:      sudo ./davis
@=============================================================================

@ Machine sizes.
        .equ    RESERVOIR_OZ, 48
        .equ    SMALL_OZ,      6
        .equ    MEDIUM_OZ,     8
        .equ    LARGE_OZ,     10

@ wiringPi pin numbers for the LEDs.  These are wiringPi numbers, not the
@ numbers printed on the Pi header.
        .equ    RED,           5
        .equ    YELLOW,        4
        .equ    GREEN,         3
        .equ    BLUE,          2

@ wiringPi pin numbers for the buttons, in the same color order.
        .equ    RED_BTN,       1
        .equ    YELLOW_BTN,    6
        .equ    GREEN_BTN,     0
        .equ    BLUE_BTN,      7

@ Values wiringPi expects.
        .equ    OUTPUT,        1
        .equ    INPUT,         0
        .equ    PUD_UP,        2        @ pull the button pins up so an open
        .equ    ON,            1        @ switch reads HIGH
        .equ    OFF,           0
        .equ    LOW,           0        @ a pressed button reads LOW
        .equ    HIGH,          1

@ Times in milliseconds.
        .equ    SMALL_MS,   6000
        .equ    MEDIUM_MS,  8000
        .equ    LARGE_MS,  10000
        .equ    BLINK_MS,   5000        @ one half of an out of water blink
        .equ    BLINK_COUNT,   3
        .equ    DELAY_MS,    250        @ one pass of the button loop

        .global main
        .text

@=============================================================================
@ main
@
@   r4  = oz of water left
@   r5  = small cups made
@   r6  = medium cups made
@   r7  = large cups made
@   r8  = what the red button read last pass
@   r9  = what the yellow button read last pass
@   r10 = what the green button read last pass
@   r11 = what the blue button read last pass
@=============================================================================
main:
        push    {r4-r12, lr}            @ 10 registers keeps sp 8 byte aligned

@ Setup wiringPi
        bl      wiringPiSetup
        mvn     r1, #0                  @ -1
        cmp     r0, r1
        bne     setupPins

        ldr     r0, =gpioErrMsg
        bl      printf
        b       exitProgram

@ Point four pins at the LEDs and four at the buttons.
setupPins:
        mov     r0, #RED
        bl      initLed
        mov     r0, #YELLOW
        bl      initLed
        mov     r0, #GREEN
        bl      initLed
        mov     r0, #BLUE
        bl      initLed

        mov     r0, #RED_BTN
        bl      initButton
        mov     r0, #YELLOW_BTN
        bl      initButton
        mov     r0, #GREEN_BTN
        bl      initButton
        mov     r0, #BLUE_BTN
        bl      initButton

        mov     r4, #RESERVOIR_OZ       @ reservoir starts full
        mov     r5, #0
        mov     r6, #0
        mov     r7, #0

        mov     r8,  #HIGH              @ nobody is touching a button yet
        mov     r9,  #HIGH
        mov     r10, #HIGH
        mov     r11, #HIGH

        ldr     r0, =welcomeMsg
        bl      printf

@-----------------------------------------------------------------------------
@ powerLoop
@ The machine is off, so the red button is the only one that does anything.
@ One pass per polling interval.  The delay is what debounces the switch.
@-----------------------------------------------------------------------------
powerLoop:
        mov     r0, #DELAY_MS
        bl      delay

        mov     r0, #RED_BTN
        bl      digitalRead
        cmp     r0, #HIGH               @ not pressed, go look again
        moveq   r8, r0
        beq     powerLoop
        cmp     r8, #LOW                @ already down last pass, so this is
        beq     powerLoop               @ not a new press
        mov     r8, r0

@ The red LED comes on with the machine and stays on until it stops.
        mov     r0, #RED
        mov     r1, #ON
        bl      digitalWrite

        ldr     r0, =sizeMsg
        bl      printf

@-----------------------------------------------------------------------------
@ buttonLoop
@ The machine is on.  Read the buttons once per pass and brew whatever size
@ was pressed.
@-----------------------------------------------------------------------------
buttonLoop:
        mov     r0, #DELAY_MS
        bl      delay

@ The hidden code is yellow and green held down together, so the pair is read
@ before either button on its own.  It only counts when at least one of them
@ was up last pass, otherwise one long press would report over and over.
readHidden:
        mov     r0, #YELLOW_BTN
        bl      digitalRead
        cmp     r0, #HIGH
        beq     readRed                 @ yellow is up, so this is not the pair

        mov     r0, #GREEN_BTN
        bl      digitalRead
        cmp     r0, #HIGH
        beq     readRed                 @ green is up, so this is not the pair

        orr     r0, r9, r10             @ HIGH if either one was up last pass
        cmp     r0, #HIGH
        bne     readRed

        mov     r9,  #LOW               @ write both of them down as seen so
        mov     r10, #LOW               @ letting go does not brew a coffee
        b       showStatus

readRed:
        mov     r0, #RED_BTN
        bl      digitalRead
        cmp     r0, #HIGH
        moveq   r8, r0
        beq     readYellow
        cmp     r8, #LOW
        beq     readYellow
        mov     r8, r0
        b       machineOff

readYellow:
        mov     r0, #YELLOW_BTN
        bl      digitalRead
        cmp     r0, #HIGH
        moveq   r9, r0
        beq     readGreen
        cmp     r9, #LOW
        beq     readGreen
        mov     r9, r0
        b       smallCoffee

readGreen:
        mov     r0, #GREEN_BTN
        bl      digitalRead
        cmp     r0, #HIGH
        moveq   r10, r0
        beq     readBlue
        cmp     r10, #LOW
        beq     readBlue
        mov     r10, r0
        b       mediumCoffee

readBlue:
        mov     r0, #BLUE_BTN
        bl      digitalRead
        cmp     r0, #HIGH
        moveq   r11, r0
        beq     buttonLoop
        cmp     r11, #LOW
        beq     buttonLoop
        mov     r11, r0

@-----------------------------------------------------------------------------
@ smallCoffee, mediumCoffee, largeCoffee
@ Take the water out of the reservoir, add one to the counter for that size
@ and set up the LED that goes with it.
@-----------------------------------------------------------------------------
largeCoffee:
        cmp     r4, #LARGE_OZ
        blt     notEnough               @ less water left than this cup needs
        sub     r4, r4, #LARGE_OZ
        add     r7, r7, #1
        mov     r0, #BLUE
        ldr     r1, =LARGE_MS
        b       runBrew

smallCoffee:
        cmp     r4, #SMALL_OZ
        blt     notEnough
        sub     r4, r4, #SMALL_OZ
        add     r5, r5, #1
        mov     r0, #YELLOW
        ldr     r1, =SMALL_MS
        b       runBrew

mediumCoffee:
        cmp     r4, #MEDIUM_OZ
        blt     notEnough
        sub     r4, r4, #MEDIUM_OZ
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

        ldr     r0, =sizeMsg
        bl      printf
        b       buttonLoop

@ Not enough water for that size, so say how much is left and wait for a
@ smaller one.
notEnough:
        ldr     r0, =errWaterMsg
        mov     r1, r4
        bl      printf
        b       buttonLoop

@ The hidden code report.  Printing it scrolls the menu off the screen, so
@ the menu goes back up afterward.
@
@ printf only takes 3 values in r1 to r3 and each of these lines has its own
@ label anyway, so it is easier to print one line at a time.  The counters are
@ in r4 to r7, which printf has to leave alone, so they are still good between
@ the calls.
showStatus:
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

        ldr     r0, =sizeMsg
        bl      printf
        b       buttonLoop

@ Not enough left for even a small cup, so a person has to refill it.  The
@ red LED blinks on the way out so someone looking at the board instead of
@ the screen can tell the machine quit on its own.
needRefill:
        ldr     r0, =refillMsg
        mov     r1, r4
        bl      printf
        bl      blinkPowerOff
        b       exitProgram

@ The red button was pressed a second time.  The light goes out with no
@ blinking.
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
@ initButton
@ Points one pin at a button.  The pull up resistor is what makes a button
@ nobody is touching read HIGH, so a press is a LOW.
@
@   r0 = wiringPi pin number
@-----------------------------------------------------------------------------
initButton:
        push    {r4, lr}                @ 2 registers keeps sp 8 byte aligned
        mov     r4, r0

        mov     r1, #INPUT
        bl      pinMode

        mov     r0, r4
        mov     r1, #PUD_UP
        bl      pullUpDnControl

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


@=============================================================================
@ Data
@=============================================================================
        .data

welcomeMsg:
        .ascii  "\nWelcome to the Coffee Maker\n\n"
        .asciz  "Press the RED button to turn on the coffee maker.\n"

sizeMsg:
        .ascii  "\nPress a button to brew a cup of coffee:\n"
        .ascii  "  YELLOW  Small  (6 oz)\n"
        .ascii  "  GREEN   Medium (8 oz)\n"
        .ascii  "  BLUE    Large  (10 oz)\n"
        .asciz  "  RED     Turn the machine off\n"

dispensedMsg:   .asciz  "\nCoffee has been dispensed\n"

@ The hidden code report.
waterMsg:       .asciz  "\nWater level: %d\n"
smallMsg:       .asciz  "Small: %d\n"
mediumMsg:      .asciz  "Medium: %d\n"
largeMsg:       .asciz  "Large: %d\n"

errWaterMsg:    .asciz  "\nThere is not enough water for that size. Only %d oz remain.\nPlease select a smaller cup size.\n"

refillMsg:      .asciz  "\nOnly %d oz of water remain, which is not enough for a small cup.\nPlease refill the reservoir. Turning off the machine.\n\n"

offMsg:         .asciz  "\nTurning off the machine. Goodbye!\n\n"

@ Run the program with sudo if this shows up.  wiringPi cannot open the GPIO
@ without root.
gpioErrMsg:     .asciz  "\nCould not set up the GPIO. Run this program as root.\n\n"

@=============================================================================
@ These come from wiringPi.  The program has to be linked with -lwiringPi for
@ them to resolve.
@=============================================================================
        .extern wiringPiSetup
        .extern pinMode
        .extern pullUpDnControl
        .extern digitalRead
        .extern digitalWrite
        .extern delay
