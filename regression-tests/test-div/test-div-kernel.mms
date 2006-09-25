% Run some simple tests on DIV (signed)

% This depends on working GETA, LDOU, PUT
% TRAP, SETL, CMP, BZ

	LOC	#80000000

Main	GETA	$255,Traphandler
        BNN	$255,1F
	PUT	rT,$255                 % We only try this in supervisor mode
1H      GETA	$255,FailMsg
        GETA	$0,Numbers
Loop	PUT	rA,0			% clear current exception
        LDOU	$1,$0,0			% Quotent
	LDOU	$2,$0,8			% Divisor
	LDOU	$3,$0,16		% Expected result
        LDOU	$4,$0,24		% Expected remainder
        LDOU	$7,$0,32		% Expected exception

	DIV	$5,$1,$2		% check result
	CMPU	$6,$5,$3
	BNZ	$6,Done

        GET	$5,rR			% check remainder
	CMPU	$6,$5,$4
        BNZ	$6,Done

        GET	$5,rA			% check current exception
        AND	$5,$5,(1<<6)|(1<<7)	% keep only DV bits
        CMPU	$6,$5,$7
        BNZ	$6,Done

        ADDU	$0,$0,40		% move to next data tuple
        GETA	$1,End
        CMP	$1,$0,$1
        BNZ	$1,Loop

	GETA	$255,PassMsg

Done	TRAP	0,Fputs,StdOut
	TRAP	0,Halt,0

PassMsg	BYTE	"Passed",#a,0
FailMsg	BYTE	"Failed!",#a,0

Numbers	OCTA	-17092006
	OCTA	     2020
	OCTA	    -8462
	OCTA	     1234
	OCTA	#0

	OCTA	 17092006
	OCTA	    -2020
	OCTA	    -8462
	OCTA	    -1234
	OCTA	#0


        OCTA	#8000000000000017
	OCTA	#0
	OCTA	#0
	OCTA    #8000000000000017
        OCTA	1<<7			% expect the D divide exception

	OCTA	20060917
	OCTA	    1646
        OCTA	   12187
        OCTA	    1115
        OCTA	       0

        OCTA	-17092006
	OCTA	    -2020
	OCTA	     8461
	OCTA	     -786
	OCTA	#0

        OCTA	#8000000000000000
	OCTA	#FFFFFFFFFFFFFFFF
	OCTA    #8000000000000000
	OCTA	#0
	OCTA    1<<6			% expect the V integer overflow exception

	OCTA	#8000000000000017
	OCTA	#0
	OCTA	#0
	OCTA    #8000000000000017
        OCTA	1<<7			% expect the D divide exception

End	OCTA	       0

% XXX This should be a separate module prefixed to .txt files
% XXX I just need to pick a good address for the Traphandler
% This has no impact on mmix simulation, but is for RTL
Traphandler	GET	$255,rBB
                LDBU	$0,$255
		SETH	$1,1
1H		LDO	$2,$1
		PBOD	$2,1B
                STO	$0,$1
		PUT	255,255
