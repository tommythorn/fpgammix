* Fibonacci subroutines (exercise 1.4.1--13)

IOSPACE	GREG
C	GREG
tmp	GREG

	LOC	#100
Main	SETH	IOSPACE,1
	SETL	C,'B'; PUSHJ $0,Putch
	SETL	C,'E'; PUSHJ $0,Putch
	SETL	C,'G'; PUSHJ $0,Putch
	SETL	C,'I'; PUSHJ $0,Putch
	SETL	C,'N'; PUSHJ $0,Putch
        SETL	C,12;  PUSHJ $0,Putch
	JMP	Main

	PUSHJ	$0,Fib
        ADDU	C,$0,'A'; PUSHJ $0,Putch
	JMP	Main

Fib	CMP	$1,$0,2
	PBN	$1,1F
	GET	$1,rJ
        ADDU	C,$0,'0'; PUSHJ $2,Putch
	SUB	$3,$0,1
	PUSHJ	$2,Fib   $2=F_{n-1}
	SUB	$4,$0,2
	PUSHJ	$3,Fib   $3=F_{n-2}
	ADDU	$0,$2,$3
	PUT	rJ,$1
1H	POP	1,0

Putch	LDT	tmp,IOSPACE
	PBOD	tmp,Putch
	STBU	C,IOSPACE
	POP	0,0
