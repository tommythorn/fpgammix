#define IOSPACE $250

        .text
#if 1
/* Handler for TRIP		#0 */
	PUSHJ	255,TripHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
/* Handler for exception D	#10 integer Divide check */
	PUSHJ	255,ExcDHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
/* Handler for exception V	#20 integer oVerflow */
	PUSHJ	255,ExcVHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
/* Handler for exception W	#30 float-to-fix overfloW */
	PUSHJ	255,ExcWHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
/* Handler for exception I	#40 Invalid operation */
	PUSHJ	255,ExcIHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
/* Handler for exception O	#50 floating Overflow */
	PUSHJ	255,ExcOHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
/* Handler for exception U	#60 floating Underflow */
	PUSHJ	255,ExcUHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
/* Handler for exception Z	#70 floating division by Zero */
	PUSHJ	255,ExcZHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME
/* Handler for exception X	#80 floating ineXact */
	PUSHJ	255,ExcXHandler
	PUT	rJ,$255
	GET	$255,rB
	RESUME


/*	LOC	#10000 */

Main	SETH	IOSPACE,1		/* IOSPACE pointer */
        SETL	$0,TrapVector
        PUT	rT,$0
        /*SETL	$0,1234
        PUT	rTT,$0
	SETL	$1,'A'
        PUSHJ	$0,Putch*/

	TRAP	3,5,'B'

        POP	0,0

        SETL	$2,#23
        SETL	$7,#7777
        SETL	$11,#1111
        SETL	$13,#1313
	TRIP	7,11,13
        PUSHJ	255,Start
        TRIP	2,3

TripHandler	GET	$250,rA
                GET	$251,rX
                GET	$252,rY
                GET	$253,rZ
                ADDU	$250,$251,$252
		POP	0,0
ExcDHandler	GET	$250,rA
		POP	0,0
ExcVHandler	GET	$250,rA
		POP	0,0
ExcWHandler	GET	$250,rA
		POP	0,0
ExcIHandler	GET	$250,rA
		POP	0,0
ExcOHandler	GET	$250,rA
		POP	0,0
ExcUHandler	GET	$250,rA
		POP	0,0
ExcZHandler	GET	$250,rA
		POP	0,0
ExcXHandler	GET	$250,rA
		POP	0,0


Start	SETL	$0,#FF00  % #3FFFF is the most ones I can use in a PUT rA instruction
	INCML	$0,#0
        PUT	rA,$0
        SETL	$250,#16c1
        INCML	$250,#7777
        INCMH	$250,#7777
        INCH	$250,#7777
	SETL	$3,#1

L:2	MUL	$0,$250,2
        ADD	$3,$3,1
	ADD	$250,$0,$250
	CMP	$0,$3,3
	PBNZ	$0,L:2
	POP	1,0

TrapVector	PUSHJ	255,TrapHandler
		PUT	rJ,$255
		GET	$255,rBB
		RESUME	1


TrapHandler	GET	$1,rBB
        	GET	$1,rXX
        	GET	$1,rYY
		GET	$1,rZZ
                GET	$0,rJ
        	SETL	$2,'T'
        	PUSHJ	$1,Putch
                PUT	rJ,$0
        	POP	0,0

Putch	LDT	$1,IOSPACE,0
	PBOD	$1,Putch
	STBU	$0,IOSPACE
	POP	0,0
#else

Blah		JMP	Blah

Main		SETL	$0,TrapVector
		PUT	rT,$0
		TRAP	3,5,'B'
                POP	0,0
                SWYM

TrapVector	PUSHJ	255,TrapHandler
		PUT	rJ,$255
		GET	$255,rBB
		RESUME	1

TrapHandler	POP	0,0
#endif
