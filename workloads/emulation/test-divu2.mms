                LOC	#600000000

Traphandler 	PUSHJ	255,1F
		PUT	rJ,$255
        	SETL	$255,0
		RESUME	1

Main	   	SETML	$0,#e300
                SETMH	$1,6
                STTU	$0,$1,8
                SETMH	$255,6
        	PUT	rT,$255
        	SETL	$254,1729
        	SETL	$253,19
        	DIVU	$255,$254,$253
                INCL	$255,#1234
        	TRAP	0,0,0


1H		GET	$0,rXX
        	SRU	$1,$0,56
        	CMP	$1,$1,#02
                BNZ	$1,2F

                SRU	$0,$0,24
                AND	$1,$0,#FC
                CMP	$1,$1,#1C
                BZ	$1,3F

% Unknown trap
		POP	0,0

% Ordinary trap ("system call") handling
2H		SWYM
        	POP	0,0


% Div[u][i] emulation
3H		GET	$0,rYY
        	GET	$1,rZZ
        	ADD	$0,$0,$1   % This should be division emulation but ...
        	PUT	rZZ,$0
        	POP	0,0
