foo	GREG

	LOC	#0
; Handler for TRIP		#0
	PUSHJ	255,TripHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
; Handler for exception D	#10 integer Divide check
	PUSHJ	255,ExcDHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
; Handler for exception V	#20 integer oVerflow
	PUSHJ	255,ExcVHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
; Handler for exception W	#30 float-to-fix overfloW
	PUSHJ	255,ExcWHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
; Handler for exception I	#40 Invalid operation
	PUSHJ	255,ExcIHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
; Handler for exception O	#50 floating Overflow
	PUSHJ	255,ExcOHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
; Handler for exception U	#60 floating Underflow
	PUSHJ	255,ExcUHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
; Handler for exception Z	#70 floating division by Zero
	PUSHJ	255,ExcZHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
; Handler for exception X	#80 floating ineXact
	PUSHJ	255,ExcXHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME

Start	PUSHJ	255,Main
        TRIP	2,3
	TRAP	0,1

TripHandler	GET	foo,rA
		POP	0,0
ExcDHandler	GET	foo,rA
		POP	0,0
ExcVHandler	GET	foo,rA
		POP	0,0
ExcWHandler	GET	foo,rA
		POP	0,0
ExcIHandler	GET	foo,rA
		POP	0,0
ExcOHandler	GET	foo,rA
		POP	0,0
ExcUHandler	GET	foo,rA
		POP	0,0
ExcZHandler	GET	foo,rA
		POP	0,0
ExcXHandler	GET	foo,rA
		POP	0,0


	LOC	#10000
Main	SETL	$0,#0000  % #3FFFF is the most ones I can use in a PUT rA instruction
	INCML	$0,#0
        PUT	rA,$0
        TRAP    
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

; Overflow handler
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

