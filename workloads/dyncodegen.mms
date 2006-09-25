* This is really just to test that we can execute code from SRAM, but
* it's also self-modifying code (SMC).

C	GREG
SRAM	GREG
IOSPACE	GREG
tmp	GREG

	LOC	#100
Main	SETH	IOSPACE,1
        SETH	SRAM,0

* Write SETL C,#1729  (e3fe1729)

        SETL	tmp,#1729
        INCML	tmp,#e3ff
        STTU	tmp,SRAM,0

* Write POP 0,0  (f8000000)

        SETML	tmp,#f800
        STTU	tmp,SRAM,4

        PUSHGO	$0,SRAM

        SETL	tmp,#1729
        CMP	tmp,tmp,$255
        BNZ	tmp,1F

	SETL	C,'Y'; PUSHJ $0,Putch
	SETL	C,'E'; PUSHJ $0,Putch
	SETL	C,'S'; PUSHJ $0,Putch
	SETL	C,'!'; PUSHJ $0,Putch
        SETL	C,13;  PUSHJ $0,Putch
        SETL	C,10;  PUSHJ $0,Putch
        JMP	Main

1H	SETL	C,'N'; PUSHJ $0,Putch
	SETL	C,'O'; PUSHJ $0,Putch
	SETL	C,'!'; PUSHJ $0,Putch
	SETL	C,'!'; PUSHJ $0,Putch
        SETL	C,13;  PUSHJ $0,Putch
        SETL	C,10;  PUSHJ $0,Putch
        JMP	Main


Putch	LDO	tmp,IOSPACE
	PBOD	tmp,Putch
	STBU	C,IOSPACE
	POP	0,0
