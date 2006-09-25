* Boot loader
* XXXXXXXX:	set the address
* XXXXXXXX	store datum at address & advance address
* XXXXXXXXG	Start executing

* Basically
*
* readvalue -> (value, {,G,:} )
*
* main
*   ptr = 0
*   loop
*     (value, cmd) <- readvalue
*     if cmd == ':' then
*       ptr = value
*     else if cmd == 'G' then
*       call value
*     else
*       *ptr++ = value
*   repeat loop

IOSPACE	GREG
C	GREG
tmp	GREG

	LOC	#100
Main	SETH	IOSPACE,1

1H	PUSHJ	$0,Getch
        SETL	$2,'<'; PUSHJ $1,Putch
        ADD	$2,$0,0; PUSHJ	$1,Putch
        SETL	$2,'>'; PUSHJ $1,Putch
        JMP	1B

Putch	LDTU	tmp,IOSPACE,4
	PBOD	tmp,Putch
	STBU	$0,IOSPACE,7
	POP	1,0

Getch	LDTU	$0,IOSPACE,12
	PBN	$0,Getch
	POP	1,0

Readvalue
        SETL    