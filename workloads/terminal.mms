% Grab bytes from rs232 input, echo them and store them in the frame buffer

iospace GREG
p	GREG
c	GREG
t	GREG

	LOC	#100
Main	SETH	iospace,#1
        SETMH   p,#1

1H      LDBU    t,iospace,7
        PBOD    t,1B
        SETL    t,'O'
        STBU	t,iospace,7

1H      LDBU    t,iospace,7
        PBOD    t,1B
        SETL    t,'k'
        STBU	t,iospace,7

1H      LDBU    t,iospace,7
        PBOD    t,1B
        SETL    t,'$'
        STBU	t,iospace,7

GetCh   LDT     c,iospace,12
        PBN     c,GetCh

        STBU    c,p,0
        INCL    p,#1


1H      LDBU    t,iospace,7
        PBOD    t,1B
        SETL    t,'<'
        STBU	t,iospace,7

1H      LDBU    t,iospace,7
        PBOD    t,1B
        STBU	c,iospace,7

1H      LDBU    t,iospace,7
        PBOD    t,1B
        SETL    t,'>'
        STBU	t,iospace,7

        JMP	GetCh
