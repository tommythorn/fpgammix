foo	GREG

; Overflow handler
        LOC	#0
        GET	$8,rY
        GET	$9,rX
        GET	$10,rZ
	GET	$11,rW
; Change the result
        ADDU	$8,$8,$0
	ADDU	$8,$8,$10
	ADDU	$8,$8,$11
        PUT	rZ,$8
        ANDNH	$9,#FF00
        ORH	$9,#0200
        SETH    $9,1

1H      SETL    $11,'+'
        LDTU	$10,$9,4
	PBOD	$10,1B
	STBU	$11,$9,7

        RESUME

	LOC	#250
Main	SETL	$0,#FF00
        PUT	rA,$0
        TRIP
        SETL	foo,#16c1
        INCML	foo,#7777
        INCMH	foo,#7777
        INCH	foo,#7777
	SETL	$3,#1

L:2	MUL	$0,foo,2
        ADD	$3,$3,1
	ADD	foo,$0,foo
	CMP	$0,$3,30
	PBNZ	$0,L:2
	POP	1,0
