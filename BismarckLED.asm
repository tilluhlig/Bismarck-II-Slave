.include "m644Pdef.inc"

.macro input
  .if @1 < 0x40
    in    @0, @1
  .else
      lds    @0, @1
  .endif
.endm

.macro output
  .if @0 < 0x40
    out    @0, @1
  .else
      sts    @0, @1
  .endif
.endm

.macro senden 
USART_Transmit:
input @1, UCSR0A
sbrs @1, UDRE0
rjmp USART_Transmit
output UDR0,@0
.endmacro

.macro empfangen
input @1, UCSR0A
sbrs @1, RXC0
rjmp USART_Receive
input @0,UDR0
lds @1, INP
cpi @1, 0
brne second
// erstes Byte
cpi temp, 0
breq fehler

sts INP, temp
ldi temp, 'A'
senden temp, temp2
rjmp end_second
second:
// zweites Byte
dec @1 // enthält adresse
cpi @1, 37
brsh fehler
ldi     zl,LOW(LED)  
ldi     zh,HIGH(LED)
add zl, @1
adc zh, NULL
st Z, @0
sts INP, NULL
ldi temp, 'B'
senden temp, temp2
rjmp end_second
fehler:
sts INP, NULL
ldi temp, 'F'
senden temp, temp2

end_second:
USART_Receive:
.endmacro


.macro schieberegister ; data0, data1, temp, temp2
cbi PORTD, 4

ldi @2, 0b00000001
data0:
cbi PORTD, 3
mov @3, @1
and @3, @2
cpi @3, 0
brne isteins
cbi PORTD, 2
rjmp over_isteins
isteins:
sbi PORTD, 2
over_isteins:
sbi PORTD, 3
lsl @2
cpi @2, 0
brne data0

ldi @2, 0b00000001
data1:
cbi PORTD, 3
mov @3, @0
and @3, @2
cpi @3, 0
brne isteins2
cbi PORTD, 2
rjmp over_isteins2
isteins2:
sbi PORTD, 2
over_isteins2:
sbi PORTD, 3
lsl @2
cpi @2, 0
brne data1

sbi PORTD, 4
.endmacro

.def NULL     = R13
.def EINS     = R14
.def ALL     = R15
.def temp = r16
.def temp2 = r17
.def temp3 = r23
.def temp4 = r19
.def SERV = r20
.def SERV2 = r21
.def SERV3 = r22
.def Counter = r18
.def temp5 = r24

.equ XTAL = 20000000
.equ F_CPU = XTAL                            ; Systemtakt in Hz
.equ BAUD  = 50000 ;28800    ;                           ; Baudrate

; Berechnungen
.equ UBRR_VAL   = ((F_CPU+BAUD*8)/(BAUD*16)-1)  ; clever runden
.equ BAUD_REAL  = (F_CPU/(16*(UBRR_VAL+1)))      ; Reale Baudrate
.equ BAUD_ERROR = ((BAUD_REAL*1000)/BAUD-1000)  ; Fehler in Promille

.if ((BAUD_ERROR>10) || (BAUD_ERROR<-10))       ; max. +/-10 Promille Fehler
  .error "Systematischer Fehler der Baudrate grösser 1 Prozent und damit zu hoch!"
.endif

.org 0x0000
rjmp reset
.org OC1Aaddr  
rjmp loop


reset:
; NULL                
    clr NULL
; EINS                
    ldi temp,1
    mov EINS,temp
; ALL
ldi temp,255
mov ALL,temp

          ldi      temp, HIGH(RAMEND)     ; Stackpointer initialisieren
          out      SPH, temp
          ldi      temp, LOW(RAMEND)
          out      SPL, temp

ldi temp, 0xFF
out DDRA, temp
out DDRB, temp
out DDRC, temp
out DDRD, temp
out PORTA, temp
out PORTB, temp
out PORTC, temp
out PORTD, temp

ldi     zl,LOW(LED)  
ldi     zh,HIGH(LED)
ldi temp,18
red:
st Z+, NULL
dec temp
brne red

ldi     zl,LOW(MOTOR)  
ldi     zh,HIGH(MOTOR)
ldi temp,3
red3:
st Z+, NULL
dec temp
brne red3

ldi     zl,LOW(SERVO)  
ldi     zh,HIGH(SERVO)
ldi temp,16
ldi temp2, 50
red2:
st Z+, temp2
dec temp
brne red2

sts INP, NULL

ldi SERV, 0
ldi SERV2, 0
ldi SERV3, 0

schieberegister ALL, ALL, temp, temp2

; Baudrate einstellen
    ldi     temp, HIGH(UBRR_VAL)
    output     UBRR0H, temp
    ldi     temp, LOW(UBRR_VAL)
    output     UBRR0L, temp

      ;RS232 initialisieren
    ldi r16, LOW(UBRR_VAL)
    output UBRR0L,r16
    ldi r16, HIGH(UBRR_VAL)
    output UBRR0H,r16


    ldi r16, (3<<UCSZ00) ; Frame-Format: 8 Bit ??? UMSEL0 geändert(1<<UMSEL0)|
    output UCSR0C,r16

    input temp, UCSR0B
    ori temp, (1<<RXEN0) | (1<<TXEN0)
    output UCSR0B, temp

// Timer 1
 ldi     temp, high( 400 - 1 ) // 16 * 250 = 4000 // 245
        output     OCR1AH, temp
        ldi     temp, low( 400 - 1 ) // 65,5 Khz
        output    OCR1AL, temp
         ldi     temp, ( 1 << WGM12 ) | ( 1 << CS10 )
        output     TCCR1B, temp

        input temp, TIMSK1
        ldi     temp2, 1 << OCIE1A  
        or temp, temp2
        output     TIMSK1, temp
sei

do: rjmp do


loop: 

// PORTA
ldi     zl,LOW(LED)  
ldi     zh,HIGH(LED)

ldi temp2, 0b11111111
ld temp, Z+
cp Counter, temp
brsh on_0
andi temp2, 0b11111110
on_0:
ld temp, Z+
cp Counter, temp
brsh on_1
andi temp2, 0b11111101
on_1:
ld temp, Z+
cp Counter, temp
brsh on_2
andi temp2, 0b11111011
on_2:
ld temp, Z+
cp Counter, temp
brsh on_3
andi temp2, 0b11110111
on_3:
ld temp, Z+
cp Counter, temp
brsh on_4
andi temp2, 0b11101111
on_4:
ld temp, Z+
cp Counter, temp
brsh on_5
andi temp2, 0b11011111
on_5:
ld temp, Z+
cp Counter, temp
brsh on_6
andi temp2, 0b10111111
on_6:
ld temp, Z+
cp Counter, temp
brsh on_7
andi temp2, 0b01111111
on_7:

out PORTA, temp2 


// PORTC
ldi temp2, 0b11111111
ld temp, Z+
cp Counter, temp
brsh on_8
andi temp2, 0b11111110
on_8:
ld temp, Z+
cp Counter,temp
brsh on_9
andi temp2, 0b11111101
on_9:
ld temp, Z+
cp Counter,temp
brsh on_10
andi temp2, 0b11111011
on_10:
ld temp, Z+
cp Counter,temp
brsh on_11
andi temp2, 0b11110111
on_11:
ld temp, Z+
cp Counter,temp
brsh on_12
andi temp2, 0b11101111
on_12:
ld temp, Z+
cp Counter,temp
brsh on_13
andi temp2, 0b11011111
on_13:
ld temp, Z+
cp Counter,temp
brsh on_14
andi temp2, 0b10111111
on_14:
ld temp, Z+
cp Counter,temp
brsh on_15
andi temp2, 0b01111111
on_15:

out PORTC, temp2


// PORTB
in temp2, PORTB
ldi temp3, 0b00000011
or temp2, temp3

ld temp, Z+
cp Counter, temp
brsh on_16
andi temp2, 0b11111110
on_16:
ld temp, Z+
cp Counter, temp
brsh on_17
andi temp2, 0b11111101
on_17:

out PORTB, temp2

inc Counter



// Werte = 50-100
// Servo steuerung // PORTD
add SERV , EINS
adc SERV2, NULL

cpi SERV2, 0
breq generate
rjmp no_generate
generate:
mov temp2, NULL
ldi     zl,LOW(SERVO)  
ldi     zh,HIGH(SERVO)
ld temp, Z+
cp SERV, temp
brsh no_0
ori temp2, 0b00000001
no_0:
ld temp, Z+
cp SERV, temp
brsh no_1
ori temp2, 0b00000010
no_1:
ld temp, Z+
cp SERV, temp
brsh no_2
ori temp2, 0b00000100
no_2:
ld temp, Z+
cp SERV, temp
brsh no_3
ori temp2, 0b00001000
no_3:
ld temp, Z+
cp SERV, temp
brsh no_4
ori temp2, 0b00010000
no_4:
ld temp, Z+
cp SERV, temp
brsh no_5
ori temp2, 0b00100000
no_5:
ld temp, Z+
cp SERV, temp
brsh no_6
ori temp2, 0b01000000
no_6:
ld temp, Z+
cp SERV, temp
brsh no_7
ori temp2, 0b10000000
no_7:

// Servo steuerung // PORTE
mov temp3, NULL

ld temp, Z+
cp SERV, temp
brsh no_02
ori temp3, 0b00000001
no_02:
ld temp, Z+
cp SERV, temp
brsh no_12
ori temp3, 0b00000010
no_12:
ld temp, Z+
cp SERV, temp
brsh no_22
ori temp3, 0b00000100
no_22:
ld temp, Z+
cp SERV, temp
brsh no_32
ori temp3, 0b00001000
no_32:
ld temp, Z+
cp SERV, temp
brsh no_42
ori temp3, 0b00010000
no_42:
ld temp, Z+
cp SERV, temp
brsh no_52
ori temp3, 0b00100000
no_52:
ld temp, Z+
cp SERV, temp
brsh no_62
ori temp3, 0b01000000
no_62:
ld temp, Z+
cp SERV, temp
brsh no_72
ori temp3, 0b10000000
no_72:

schieberegister temp2, temp3, temp, temp4

// Servo steuerung // PORTB Motoren
ldi     zl,LOW(MOTOR)  
ldi     zh,HIGH(MOTOR)
in temp2, PORTB
ldi temp3, 0b00011100
or temp2, temp3

ld temp, Z+
cp SERV, temp
brsh on_82
andi temp2, 0b11111011
on_82:
ld temp, Z+
cp SERV, temp
brsh on_92
andi temp2, 0b11110111
on_92:
ld temp, Z+
cp SERV, temp
brsh on_102
andi temp2, 0b11101111
on_102:

out PORTB, temp2



rjmp over_generate
no_generate:
cpi SERV2, 10
brlo no_zero
mov SERV, NULL
mov SERV2, NULL
no_zero:

schieberegister NULL, NULL, temp, temp2

over_generate:

// daten empfangen
empfangen temp, temp2

reti

.DSEG ; Arbeitsspeicher
LED:    .BYTE 18 // 1 - 18
MOTOR:  .BYTE 3 // 19 - 21
SERVO:  .BYTE 16 // 22 - 37

INP: .BYTE 1  // empfangenes Byte

