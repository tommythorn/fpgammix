n	GREG
x	GREG

	LOC	#100
Main	SETL    x,0
2H      PUT     255,x
        INCL    x,1
        JMP     Pause

Pause   SETML   n,1
1H      SUB     n,n,1
        BNZ	n,1B
        JMP	2B