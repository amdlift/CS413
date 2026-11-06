@=============================================================================
@ File:    davis.s
@ Class:   CS 413-02
@ Term:    Fall 2026
@ Author:  Aaron Davis
@ Email:   amd0047@uah.edu
@ Date:    November 6, 2026
@
@ Purpose: Single serve coffee machine run from the four GPIO buttons, with
@          the four LEDs showing status.
@
@              Button   Function              LED
@              ------   --------              ---
@              Red      power on and off      power
@              Yellow   small coffee, 6 oz    on 6 seconds while brewing
@              Green    medium coffee, 8 oz   on 8 seconds while brewing
@              Blue     large coffee, 10 oz   on 10 seconds while brewing
@
@          Starts with a full 48 oz reservoir and the power off.  Below 6 oz
@          the machine prints a refill message, blinks red three times and
@          stops.
@
@          Hidden code: yellow and green together report the water level and
@          the cup counts.  No menu lists it.
@
@ Rev  Date         Purpose of change
@ ---  ----         -----------------
@  A   23-Oct-2026  Lab 4.  Added the wiringPi LED status.
@  B   06-Nov-2026  Lab 5.  Buttons replaced the keyboard.
@
@ Needs root for the GPIO.
@
@ Assemble: as -g -o davis.o davis.s
@ Link:     gcc -o davis davis.o -lwiringPi
@ Run:      sudo ./davis
@=============================================================================

@ Machine sizes
        .equ    RESERVOIR_OZ, 48
        .equ    SMALL_OZ,      6
        .equ    MEDIUM_OZ,     8
        .equ    LARGE_OZ,     10

@ wiringPi LED pins
        .equ    RED,           5
        .equ    YELLOW,        4
        .equ    GREEN,         3
        .equ    BLUE,          2

@ wiringPi button pins
        .equ    RED_BTN,       1
        .equ    YELLOW_BTN,    6
        .equ    GREEN_BTN,     0
        .equ    BLUE_BTN,      7

@ wiringPi values
        .equ    OUTPUT,        1
        .equ    INPUT,         0
        .equ    PUD_UP,        2
        .equ    ON,            1
        .equ    OFF,           0
        .equ    LOW,           0        @ pressed
        .equ    HIGH,          1        @ not pressed

@ Times in milliseconds
        .equ    SMALL_MS,   6000
        .equ    MEDIUM_MS,  8000
        .equ    LARGE_MS,  10000
        .equ    BLINK_MS,   5000        @ half of one blink
        .equ    BLINK_COUNT,   3
        .equ    DELAY_MS,    250        @ one pass of the button loop

        .global main
        .text

@=============================================================================
@ main
@   r4  = oz of water left
@   r5  = small cups made
@   r6  = medium cups made
@   r7  = large cups made
@   r8  = red button last pass
@   r9  = yellow button last pass
@   r10 = green button last pass
@   r11 = blue button last pass
@=============================================================================
main:
        push    {r4-r12, lr}            @ 10 registers keeps sp 8 byte aligned

        bl      wiringPiSetup
        mvn     r1, #0                  @ -1
        cmp     r0, r1
        bne     setupPins

        ldr     r0, =gpioErrMsg
        bl      printf
        b       exitProgram

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

        mov     r4, #RESERVOIR_OZ
        mov     r5, #0
        mov     r6, #0
        mov     r7, #0

        mov     r8,  #HIGH              @ no button is down yet
        mov     r9,  #HIGH
        mov     r10, #HIGH
        mov     r11, #HIGH

        ldr     r0, =welcomeMsg
        bl      printf

@-----------------------------------------------------------------------------
@ powerLoop - machine off, only red does anything.  The delay debounces.
@-----------------------------------------------------------------------------
powerLoop:
        mov     r0, #DELAY_MS
        bl      delay

        mov     r0, #RED_BTN
        bl      digitalRead
        cmp     r0, #HIGH               @ not pressed
        moveq   r8, r0
        beq     powerLoop
        cmp     r8, #LOW                @ already down last pass
        beq     powerLoop
        mov     r8, r0

        mov     r0, #RED                @ power LED stays on until we stop
        mov     r1, #ON
        bl      digitalWrite

        ldr     r0, =sizeMsg
        bl      printf

@-----------------------------------------------------------------------------
@ buttonLoop - machine on.  Read the buttons once per pass.
@-----------------------------------------------------------------------------
buttonLoop:
        mov     r0, #DELAY_MS
        bl      delay

@ Hidden code, read before the single buttons.  Only counts when one of the
@ two was up last pass, or a long press would report every pass.
readHidden:
        mov     r0, #YELLOW_BTN
        bl      digitalRead
        cmp     r0, #HIGH
        beq     readRed

        mov     r0, #GREEN_BTN
        bl      digitalRead
        cmp     r0, #HIGH
        beq     readRed

        orr     r0, r9, r10             @ HIGH if either was up last pass
        cmp     r0, #HIGH
        bne     readRed

        mov     r9,  #LOW               @ mark both seen so the release does
        mov     r10, #LOW               @ not brew
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
@ One block per size.  Each sets up the LED and brew time for runBrew.
@-----------------------------------------------------------------------------
largeCoffee:
        cmp     r4, #LARGE_OZ
        blt     notEnough
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

@ Message comes after the brew, not while the LED is still lit.
runBrew:
        bl      brewLed

        ldr     r0, =dispensedMsg
        bl      printf

        cmp     r4, #SMALL_OZ
        blt     needRefill

        ldr     r0, =sizeMsg
        bl      printf
        b       buttonLoop

notEnough:
        ldr     r0, =errWaterMsg
        mov     r1, r4
        bl      printf
        b       buttonLoop

@ Hidden code report.  One printf per line since each has its own label.
@ r4-r7 survive the calls, so the counters stay good.
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

        ldr     r0, =sizeMsg            @ report scrolled the menu off
        bl      printf
        b       buttonLoop

@ Out of water.  Blink on the way out so the board shows it quit on its own.
needRefill:
        ldr     r0, =refillMsg
        mov     r1, r4
        bl      printf
        bl      blinkPowerOff
        b       exitProgram

@ Red pressed a second time.  No blinking.
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
@ initLed - point a pin at an LED and start it off
@   r0 = wiringPi pin
@-----------------------------------------------------------------------------
initLed:
        push    {r4, lr}                @ 2 registers keeps sp 8 byte aligned
        mov     r4, r0                  @ pinMode takes r0

        mov     r1, #OUTPUT
        bl      pinMode

        mov     r0, r4
        mov     r1, #OFF
        bl      digitalWrite

        pop     {r4, pc}

@-----------------------------------------------------------------------------
@ initButton - point a pin at a button.  Pull up makes an open switch HIGH.
@   r0 = wiringPi pin
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
@ brewLed - light an LED, wait, turn it off
@   r0 = wiringPi pin
@   r1 = milliseconds
@-----------------------------------------------------------------------------
brewLed:
        push    {r4, r5, r6, lr}        @ 4 registers keeps sp 8 byte aligned
        mov     r4, r0                  @ both args must survive the calls
        mov     r5, r1

        mov     r1, #ON
        bl      digitalWrite

        mov     r0, r5
        bl      delay

        mov     r0, r4
        mov     r1, #OFF
        bl      digitalWrite

        pop     {r4, r5, r6, pc}

@-----------------------------------------------------------------------------
@ blinkPowerOff - blink red three times, leave it off.  The LED is already on
@ here, so each pass goes off then back on.
@   r4 = blinks left
@-----------------------------------------------------------------------------
blinkPowerOff:
        push    {r4, lr}                @ 2 registers keeps sp 8 byte aligned
        mov     r4, #BLINK_COUNT

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

        mov     r0, #RED                @ power is off, so leave it off
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

@ Hidden code report
waterMsg:       .asciz  "\nWater level: %d\n"
smallMsg:       .asciz  "Small: %d\n"
mediumMsg:      .asciz  "Medium: %d\n"
largeMsg:       .asciz  "Large: %d\n"

errWaterMsg:    .asciz  "\nThere is not enough water for that size. Only %d oz remain.\nPlease select a smaller cup size.\n"

refillMsg:      .asciz  "\nOnly %d oz of water remain, which is not enough for a small cup.\nPlease refill the reservoir. Turning off the machine.\n\n"

offMsg:         .asciz  "\nTurning off the machine. Goodbye!\n\n"

gpioErrMsg:     .asciz  "\nCould not set up the GPIO. Run this program as root.\n\n"

@ From wiringPi, link with -lwiringPi
        .extern wiringPiSetup
        .extern pinMode
        .extern pullUpDnControl
        .extern digitalRead
        .extern digitalWrite
        .extern delay
