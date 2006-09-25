% This is almost "hello world" simple

% This depends on working GETA, LDOU, PUT
% TRAP, SETL, CMP, BZ

	LOC	#100

Main	GETA	$255,FailMsg
        GETA	$0,Numbers
Loop	PUT	rD,0
	LDOU	$1,$0,0  % Quotent
	LDOU	$2,$0,8  % Divisor
	LDOU	$3,$0,16  % Expected result
        LDOU	$4,$0,24  % Expected remainder
	DIVU	$5,$1,$2

	CMPU	$6,$5,$3
	BNZ	$6,Done

        GET	$5,rR
	CMPU	$6,$5,$4
        BNZ	$6,Done

        ADDU	$0,$0,32
        GETA	$1,End
        CMP	$1,$0,$1
        BNZ	$1,Loop

	GETA	$255,PassMsg

Done	TRAP	0,Fputs,StdOut
	TRAP	0,Halt,0

PassMsg	BYTE	"Passed",#a,0
FailMsg	BYTE	"Failed!",#a,0

Numbers	OCTA	20060917
	OCTA	    1646
        OCTA	   12187
        OCTA	    1115

        OCTA	#8000000000000000
	OCTA	#FFFFFFFFFFFFFFFF
	OCTA	#0
	OCTA    #8000000000000000

        OCTA	#8000000000000017
	OCTA	#0
	OCTA	#0
	OCTA    #8000000000000017

End	OCTA	       0