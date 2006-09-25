% Run some simple tests on MOR

% This depends on working GETA, LDOU, PUT
% TRAP, SETL, CMP, BZ

	LOC	#80000000

Main	GETA	$255,Traphandler
        BNN	$255,1F
	PUT	rT,$255                 % We only try this in supervisor mode
1H      GETA	$255,FailMsg
        GETA	$0,Numbers
Loop	LDOU	$1,$0,0			% Y
	LDOU	$2,$0,8			% Z
	LDOU	$3,$0,16		% Expected result

	MOR	$5,$1,$2		% check result
	CMPU	$6,$5,$3
	BNZ	$6,Done

        ADDU	$0,$0,24		% move to next data tuple
        GETA	$1,End
        CMP	$1,$0,$1
        BNZ	$1,Loop

	GETA	$255,PassMsg

Done	TRAP	0,Fputs,StdOut
	TRAP	0,Halt,0

PassMsg	BYTE	"Passed",#a,0
FailMsg	BYTE	"Failed!",#a,0

Numbers	OCTA	#7824317821437294
        OCTA	#9812189744372983
	OCTA	#797a79ff67ffb5fe

	OCTA	#1234567890ABCDEF
        OCTA	#0000000000000001
	OCTA	#00000000000000EF

	OCTA	#1234567890ABCDEF
        OCTA	#0000000000000002
	OCTA	#00000000000000CD

	OCTA	#1234567890ABCDEF
        OCTA	#0000000000000100
	OCTA	#000000000000EF00

        OCTA	20060917
	OCTA	    1646
        OCTA	#3a3b

        OCTA	#8000000000000000
	OCTA	#FFFFFFFFFFFFFFFF
	OCTA    #8080808080808080

	OCTA	#8000000000000017
	OCTA	#0
	OCTA	#0

	OCTA	-17092006
	OCTA	    -2020
	OCTA	#ffffffffffffffff

	OCTA	-17092006
	OCTA	     2020
	OCTA	#fbff

	OCTA	 17092006
	OCTA	    -2020
	OCTA	#efefefefefef0105

        OCTA	#8000000000000017
	OCTA	#0
	OCTA	#0

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
